"""The ground, hand-drawn per biome (visual overhaul, phase 2).

Every land terrain gets a five-tone ramp built from its colours (shadows a
little cooler, highlights a little warmer, light from the top-left) and a
painter of its own: grass in layered blades with clover, soil with roots and
stones, sand in ripples with shells, snow in drifts with blue shadow, salt in
bevelled plates, cinders with glowing cracks, the void with a starry rift...

Tiles are 44 px and sit next to any variant of the same ground, so each one
is seamless: the broad mottling is drawn from a field that every variant of
a terrain shares near the tile's edges and that only becomes the variant's
own further in, and features (tufts, stones, shells) keep inside the tile.
Variants 0-5 are plain ground; 6-11 each carry one larger feature.

Called by tools/generate_art.py (draw_tile) for every land row.
"""
import colorsys
import math
import random

N = 44


# --- colour ------------------------------------------------------------------

def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hsv_shift(c, dh=0.0, ds=0.0, dv=0.0, k=1.0):
    h, s, v = colorsys.rgb_to_hsv(*(x / 255.0 for x in c[:3]))
    h = (h + dh) % 1.0
    s = max(0.0, min(1.0, s + ds))
    v = max(0.0, min(1.0, v * k + dv))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def toward(c, hue, amount):
    """Moves a colour's hue a little toward `hue` (0..1), the short way."""
    h, s, v = colorsys.rgb_to_hsv(*(x / 255.0 for x in c[:3]))
    d = ((hue - h + 0.5) % 1.0) - 0.5
    r, g, b = colorsys.hsv_to_rgb((h + d * amount) % 1.0, s, v)
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def ramp(base, light, dark):
    """Five tones, deepest shadow to highlight: shadows lean blue and a
    touch more saturated, highlights lean warm."""
    b, l, d = rgb(base) + (255,), rgb(light) + (255,), rgb(dark) + (255,)
    t0 = toward(hsv_shift(d, ds=0.06, k=0.72), 0.66, 0.18)
    t1 = toward(hsv_shift(d, ds=0.03), 0.66, 0.08)
    t2 = b
    t3 = toward(l, 0.12, 0.06)
    t4 = toward(hsv_shift(l, ds=-0.04, k=1.16, dv=0.03), 0.13, 0.14)
    return [t0, t1, t2, t3, t4]


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


# --- seamless noise -----------------------------------------------------------

def _table(seed, n):
    r = random.Random(seed)
    return [[r.random() for _ in range(n)] for _ in range(n)]


def _smooth(t):
    return t * t * (3 - 2 * t)


def vnoise(table, x, y):
    """Value noise that repeats every tile (the lattice divides 44)."""
    n = len(table)
    cell = N / n
    gx, gy = x / cell, y / cell
    i0, j0 = int(math.floor(gx)), int(math.floor(gy))
    fx, fy = _smooth(gx - i0), _smooth(gy - j0)
    i0, j0 = i0 % n, j0 % n
    i1, j1 = (i0 + 1) % n, (j0 + 1) % n
    a = table[j0][i0] + (table[j0][i1] - table[j0][i0]) * fx
    b = table[j1][i0] + (table[j1][i1] - table[j1][i0]) * fx
    return a + (b - a) * fy


def hash2(x, y, seed=0):
    h = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def edge_weight(x, y, inner=3.0, outer=11.0):
    """0 at the tile's edges (where every variant agrees), 1 well inside."""
    d = min(x, y, N - 1 - x, N - 1 - y)
    return _smooth(max(0.0, min(1.0, (d - inner) / (outer - inner))))


class Field:
    """Broad mottling for one tile: shared by a terrain's variants at the
    edges, the variant's own inside."""

    def __init__(self, row, variant, scales=(11, 22)):
        self.shared = [_table(row * 977 + k, n) for k, n in enumerate(scales)]
        self.own = [_table(row * 977 + 500 + variant * 31 + k, n) for k, n in enumerate(scales)]
        self.weights = [0.75, 0.25][:len(scales)]

    def at(self, x, y):
        w = edge_weight(x, y)
        total = 0.0
        for k, wt in enumerate(self.weights):
            a = vnoise(self.shared[k], x, y)
            b = vnoise(self.own[k], x, y)
            total += wt * (a + (b - a) * w)
        return total


# --- canvas -------------------------------------------------------------------

class Tile:
    def __init__(self, img, tones, seed):
        self.img = img
        self.t = tones
        self.r = random.Random(seed)

    def put(self, x, y, c, margin=1):
        x, y = int(x), int(y)
        if margin <= x < N - margin and margin <= y < N - margin:
            self.img.putpixel((x, y), c)

    def get(self, x, y):
        return self.img.getpixel((int(x) % N, int(y) % N))

    def darken(self, x, y, k=0.78, margin=1):
        x, y = int(x), int(y)
        if margin <= x < N - margin and margin <= y < N - margin:
            c = self.img.getpixel((x, y))
            self.img.putpixel((x, y), toward(hsv_shift(c, k=k), 0.66, 0.1))

    def spot(self, lo=3, hi=None):
        hi = N - lo if hi is None else hi
        return self.r.randrange(lo, hi), self.r.randrange(lo, hi)


def base_fill(tile, field, levels=(0.38, 0.62), grain=0.0, seed=0, soft=True):
    """Fills the tile from its field in three tones (dark, base, light),
    with the odd grain of a fourth, and no lone pixels. Soft ground keeps
    its patches close in tone (half-steps), leaving the full ramp for what
    lies on it."""
    t = list(tile.t)
    if soft:
        t = [t[0], mix(t[1], t[2], 0.55), t[2], mix(t[2], t[3], 0.45), t[4]]
    q = [[0] * N for _ in range(N)]
    for y in range(N):
        for x in range(N):
            v = field.at(x, y) + (hash2(x, y, seed) - 0.5) * 0.06
            q[y][x] = 1 if v < levels[0] else 2 if v < levels[1] else 3
    # Tidy: a pixel unlike all four neighbours takes their tone.
    for y in range(N):
        for x in range(N):
            n = [q[(y - 1) % N][x], q[(y + 1) % N][x], q[y][(x - 1) % N], q[y][(x + 1) % N]]
            if q[y][x] not in n and n.count(n[0]) >= 3:
                q[y][x] = n[0]
    for y in range(N):
        for x in range(N):
            c = t[q[y][x]]
            if grain and hash2(x, y, seed + 9) < grain:
                c = t[max(0, q[y][x] - 1)] if hash2(x, y, seed + 4) < 0.6 else t[min(4, q[y][x] + 1)]
            tile.img.putpixel((x, y), c)
    return q


def stone(tile, x, y, w, h, tones=None, moss=None):
    """A small rounded stone lit from the top-left, with its shadow."""
    t = tones or tile.t
    for dy in range(h + 1):
        for dx in range(w + 1):
            u, v = (dx - w / 2) / (w / 2 + 0.5), (dy - h / 2) / (h / 2 + 0.5)
            if u * u + v * v <= 1.0:
                tile.darken(x + dx + 1, y + dy + 1, 0.7)
    for dy in range(h):
        for dx in range(w):
            u, v = (dx + 0.5 - w / 2) / (w / 2), (dy + 0.5 - h / 2) / (h / 2)
            if u * u + v * v > 1.0:
                continue
            lit = -u - v
            c = t[4] if lit > 0.9 else t[3] if lit > 0.1 else t[2] if lit > -0.7 else t[1]
            if moss and v < -0.2 and tile.r.random() < 0.5:
                c = moss
            tile.put(x + dx, y + dy, c)


def blade(tile, x, y, h, lean, low, mid, tip):
    """One grass blade rising from (x, y), h pixels tall."""
    for k in range(h):
        px = x + (lean if k >= h - 1 and h > 2 else 0)
        c = low if k == 0 else tip if k == h - 1 else mid
        tile.put(px, y - k, c)


def tuft(tile, x, y, tones, size=3):
    """A tuft of 3-5 blades fanning out, lit on the left, with a shadow."""
    t0, t1, t2, t3, t4 = tones
    tile.darken(x + 1, y + 1, 0.72)
    tile.darken(x + 2, y + 1, 0.8)
    heights = {2: [2, 3, 2], 3: [2, 4, 3, 2], 4: [3, 5, 4, 3, 2]}[size]
    for i, h in enumerate(heights):
        lean = -1 if i == 0 else 1 if i == len(heights) - 1 else 0
        lit = i <= len(heights) // 2
        blade(tile, x + i - 1, y, h, lean, t1, t3 if lit else t2, t4 if lit else t3)


def clover(tile, x, y, leaf, hi):
    for dx, dy in ((0, 0), (1, 0), (0, 1), (2, 1), (1, 2)):
        tile.put(x + dx, y + dy, leaf)
    tile.put(x + 1, y + 1, hi)
    tile.darken(x + 2, y + 3)


def flower(tile, x, y, petal, centre, stem):
    tile.put(x, y + 2, stem)
    tile.put(x, y + 1, stem)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        tile.put(x + dx, y + dy - 1, petal)
    tile.put(x, y - 1, centre)
    tile.darken(x + 1, y + 3)


def root(tile, x, y, length, tones):
    """A root snaking over the ground, lit on top with a shadow below."""
    t = tones
    dx, cy = 1, float(y)
    for k in range(length):
        cy += tile.r.choice((-0.6, 0, 0, 0.6))
        px, py = x + k * dx, int(round(cy))
        tile.put(px, py - 1, t[3])
        tile.put(px, py, t[2])
        tile.darken(px, py + 1, 0.7)
        if tile.r.random() < 0.12:
            tile.put(px, py + 1, t[1])
            tile.put(px, py + 2, t[1])


def crack(tile, x, y, length, colour, lit=None):
    cx, cy = x, y
    for _ in range(length):
        tile.put(cx, cy, colour)
        if lit:
            tile.put(cx, cy - 1, lit)
        step = tile.r.choice(((1, 0), (1, 1), (1, -1), (0, 1)))
        cx, cy = cx + step[0], cy + step[1]


def bone(tile, x, y, length, white, shade):
    for k in range(length):
        tile.put(x + k, y, white)
        tile.darken(x + k, y + 1, 0.7)
    for (dx, dy) in ((-1, -1), (-1, 1), (length, -1), (length, 1)):
        tile.put(x + dx, y + dy, white)
    tile.put(x + length // 2, y, shade)


def puddle(tile, x, y, w, h, water, deep, rim, sky):
    """A puddle: a dark rim, deeper water to the bottom-right, a glint of
    sky on the top-left."""
    for dy in range(-1, h + 1):
        for dx in range(-1, w + 1):
            u, v = (dx + 0.5 - w / 2) / (w / 2 + 1), (dy + 0.5 - h / 2) / (h / 2 + 1)
            if u * u + v * v <= 1.0:
                tile.put(x + dx, y + dy, rim)
    for dy in range(h):
        for dx in range(w):
            u, v = (dx + 0.5 - w / 2) / (w / 2), (dy + 0.5 - h / 2) / (h / 2)
            if u * u + v * v <= 1.0:
                tile.put(x + dx, y + dy, deep if u + v > 0.3 else water)
    for k in range(max(1, w // 3)):
        tile.put(x + 1 + k, y + 1, sky)


# --- painters ---------------------------------------------------------------

def paint_grass(tile, field, kind, variant):
    t = tile.t
    base_fill(tile, field, (0.34, 0.68), seed=variant)
    r = tile.r
    # Kinds: the grass's own touches.
    flower_colours = {
        "dead_grass": [((214, 186, 92, 255), (240, 222, 150, 255)), ((196, 160, 110, 255), (230, 206, 150, 255))],
        "dark_grass": [((220, 226, 236, 255), (250, 230, 140, 255)), ((140, 160, 220, 255), (240, 240, 250, 255))],
        "frostpine": [((210, 230, 240, 255), (255, 255, 255, 255))],
        "thorn": [((150, 40, 52, 255), (214, 80, 90, 255))],
        "crimson": [((200, 70, 80, 255), (250, 170, 170, 255))],
    }[kind]
    # Little ground shading under the grass: darker clumps of soil peeking.
    for _ in range(10):
        x, y = tile.spot(3)
        tile.put(x, y, t[1])
        tile.put(x + 1, y, t[1])
    # Clover patches (not on frost or thorn).
    if kind in ("dead_grass", "dark_grass", "crimson"):
        for _ in range(r.randrange(1, 4)):
            x, y = tile.spot(4, N - 6)
            clover(tile, x, y, t[3], t[4])
    # Tufts in layers: back rows small, front rows tall.
    count = {"dead_grass": 20, "dark_grass": 26, "frostpine": 18, "thorn": 16, "crimson": 20}[kind]
    spots = sorted((r.randrange(3, N - 5), r.randrange(7, N - 3)) for _ in range(count))
    spots.sort(key=lambda p: p[1])
    for x, y in spots:
        tuft(tile, x, y, t, r.choice((2, 3, 3, 4)))
    if kind == "frostpine":
        # Frost on the tips and fallen needles.
        for _ in range(26):
            x, y = tile.spot(2)
            if tile.get(x, y) in (t[3], t[4]):
                tile.put(x, y, (226, 236, 242, 255))
        for _ in range(6):
            x, y = tile.spot(3)
            tile.put(x, y, (70, 58, 44, 255))
            tile.put(x + 1, y + 1, (70, 58, 44, 255))
    if kind == "thorn":
        for _ in range(3):
            x, y = tile.spot(5, N - 8)
            twig = (78, 58, 40, 255)
            for k in range(5):
                tile.put(x + k, y - (k // 2), twig)
                if k % 2:
                    tile.put(x + k, y - (k // 2) - 1, (120, 96, 70, 255))
            tile.put(x + 2, y - 2, flower_colours[0][1])
    # Wild flowers, rarely, on plain tiles.
    if variant < 6 and r.random() < 0.45:
        petal, centre = r.choice(flower_colours)
        x, y = tile.spot(5, N - 6)
        flower(tile, x, y, petal, centre, t[1])
    if variant >= 6:
        feature = variant % 4
        if feature == 0:
            # A patch of flowers.
            petal, centre = r.choice(flower_colours)
            cx, cy = tile.spot(12, N - 12)
            for _ in range(5):
                flower(tile, cx + r.randrange(-6, 7), cy + r.randrange(-5, 6), petal, centre, t[1])
        elif feature == 1:
            # A stone half sunk in the turf, moss on its crown.
            x, y = tile.spot(12, N - 16)
            stone(tile, x, y, 8, 5, [(50, 48, 56, 255), (78, 76, 86, 255), (104, 102, 112, 255), (136, 134, 144, 255), (170, 168, 176, 255)], moss=t[3])
            tuft(tile, x - 1, y + 6, t, 3)
            tuft(tile, x + 7, y + 6, t, 2)
        elif feature == 2:
            # A tree root breaking the surface.
            x, y = tile.spot(6, N - 22)
            root(tile, x, y + 8, 16, [(40, 30, 22, 255), (64, 46, 32, 255), (92, 68, 46, 255), (122, 94, 66, 255), (150, 120, 88, 255)])
        else:
            # A fairy ring of small mushrooms (or a clump of taller grass).
            cx, cy = tile.spot(14, N - 14)
            for k in range(7):
                a = k / 7.0 * math.tau
                x, y = cx + int(round(math.cos(a) * 7)), cy + int(round(math.sin(a) * 4))
                cap = (196, 176, 150, 255) if kind != "crimson" else (170, 60, 70, 255)
                tile.put(x, y, cap)
                tile.put(x + 1, y, hsv_shift(cap, k=0.8))
                tile.put(x, y + 1, (226, 218, 200, 255))
                tile.darken(x + 1, y + 2)


def paint_mud(tile, field, variant, cave=False):
    t = tile.t
    base_fill(tile, field, (0.42, 0.6), grain=0.04, seed=variant)
    r = tile.r
    # Wet sheen streaks on the light patches.
    for _ in range(5):
        x, y = tile.spot(4)
        if tile.get(x, y) == t[3]:
            for k in range(r.randrange(2, 5)):
                tile.put(x + k, y, t[4])
    # Pebbles.
    for _ in range(r.randrange(3, 6)):
        x, y = tile.spot(4, N - 6)
        stone(tile, x, y, r.choice((2, 3)), 2, [hsv_shift(c, k=1.15) for c in t])
    # Little cracks where it has dried.
    for _ in range(2):
        x, y = tile.spot(5, N - 10)
        crack(tile, x, y, r.randrange(4, 7), t[0], t[3])
    if variant >= 6:
        feature = variant % 3
        if feature == 0:
            x, y = tile.spot(8, N - 18)
            puddle(tile, x, y, 11, 6, (52, 66, 80, 255), (36, 46, 58, 255), t[0], (120, 140, 160, 255))
        elif feature == 1:
            x, y = tile.spot(6, N - 22)
            root(tile, x, y + 6, 15, [hsv_shift(c, k=0.9, ds=0.05) for c in t])
        else:
            if cave:
                x, y = tile.spot(10, N - 16)
                bone(tile, x, y, 6, (214, 206, 186, 255), (170, 160, 140, 255))
                stone(tile, x + 9, y - 3, 4, 3, [hsv_shift(c, k=1.2) for c in t])
            else:
                # A worm's track and a few bigger stones.
                x, y = tile.spot(8, N - 20)
                for k in range(14):
                    tile.put(x + k, y + int(round(math.sin(k * 0.8) * 1.5)), t[1])
                stone(tile, x + 3, y + 5, 4, 3, [hsv_shift(c, k=1.2) for c in t])


def paint_ash(tile, field, variant):
    t = tile.t
    base_fill(tile, field, (0.42, 0.62), seed=variant)
    r = tile.r
    # Drifted ash: soft lit crests over shaded hollows.
    for _ in range(4):
        x, y = tile.spot(5, N - 14)
        w = r.randrange(6, 11)
        for k in range(w):
            tile.put(x + k, y, t[3])
            tile.put(x + k, y + 1, t[1])
        tile.put(x + w // 2, y - 1, t[4])
    # Flecks of soot and the odd pale fleck.
    for _ in range(14):
        x, y = tile.spot(2)
        tile.put(x, y, t[0] if r.random() < 0.7 else t[4])
    # Faint embers.
    if r.random() < 0.4:
        x, y = tile.spot(4)
        tile.put(x, y, (220, 110, 40, 255))
    if variant >= 6:
        feature = variant % 3
        if feature == 0:
            x, y = tile.spot(10, N - 16)
            bone(tile, x, y, 7, (220, 214, 196, 255), (170, 164, 150, 255))
        elif feature == 1:
            # A charred branch.
            x, y = tile.spot(8, N - 20)
            for k in range(13):
                py = y + k // 4
                tile.put(x + k, py, (30, 26, 26, 255))
                tile.put(x + k, py - 1, (66, 60, 60, 255))
                tile.darken(x + k, py + 1, 0.7)
            tile.put(x + 6, y, (230, 120, 50, 255))
        else:
            # Embers still glowing in a little heap.
            cx, cy = tile.spot(12, N - 12)
            for k in range(7):
                x, y = cx + r.randrange(-3, 4), cy + r.randrange(-2, 3)
                tile.put(x, y, (240, 140, 50, 255) if k % 2 else (190, 70, 30, 255))
            tile.put(cx, cy, (255, 220, 140, 255))


def paint_bog(tile, field, variant):
    t = tile.t
    base_fill(tile, field, (0.44, 0.64), seed=variant)
    r = tile.r
    water, deep, rim, sky = (34, 44, 40, 255), (22, 30, 28, 255), (20, 24, 18, 255), (90, 110, 100, 255)
    for _ in range(r.randrange(1, 3)):
        x, y = tile.spot(6, N - 12)
        puddle(tile, x, y, r.randrange(4, 7), r.randrange(2, 4), water, deep, rim, sky)
    # Moss clumps, lit on top.
    for _ in range(6):
        x, y = tile.spot(4, N - 5)
        for dx, dy, c in ((0, 0, t[3]), (1, 0, t[4]), (2, 0, t[3]), (0, 1, t[2]), (1, 1, t[2]), (2, 1, t[1])):
            tile.put(x + dx, y + dy, c)
    # Reeds.
    for _ in range(r.randrange(2, 5)):
        x, y = tile.spot(5, N - 3)
        for k in range(r.randrange(4, 7)):
            tile.put(x, y - k, (98, 110, 60, 255) if k else (54, 62, 36, 255))
        tile.put(x, y - 6, (110, 80, 50, 255))
        tile.darken(x + 1, y + 1)
    if variant >= 6:
        feature = variant % 3
        if feature == 0:
            x, y = tile.spot(8, N - 18)
            puddle(tile, x, y, 12, 6, water, deep, rim, sky)
            # A lily pad.
            tile.put(x + 7, y + 3, (80, 120, 64, 255))
            tile.put(x + 8, y + 3, (100, 140, 70, 255))
            tile.put(x + 7, y + 2, (100, 140, 70, 255))
        elif feature == 1:
            cx, cy = tile.spot(10, N - 6)
            for k in range(6):
                x = cx + k * 2 - 5
                for j in range(r.randrange(6, 10)):
                    tile.put(x, cy - j, (110, 120, 66, 255) if j > 1 else (60, 66, 40, 255))
                tile.put(x, cy - 9, (122, 86, 52, 255))
        else:
            # A rotten log half sunk.
            x, y = tile.spot(6, N - 24)
            for k in range(16):
                tile.put(x + k, y, (90, 70, 50, 255))
                tile.put(x + k, y + 1, (66, 50, 36, 255))
                tile.put(x + k, y + 2, (44, 34, 26, 255))
                tile.darken(x + k, y + 3, 0.7)
                if k % 4 == 1:
                    tile.put(x + k, y - 1, t[3])


def paint_snow(tile, field, variant):
    t = tile.t
    base_fill(tile, field, (0.3, 0.7), seed=variant)
    r = tile.r
    shadow = (150, 168, 196, 255)
    deep = (126, 144, 178, 255)
    # Drifts: a bright crest with blue shadow on its lee (bottom-right).
    for _ in range(r.randrange(1, 3)):
        x, y = tile.spot(4, N - 16)
        w = r.randrange(8, 14)
        for k in range(w):
            arc = int(round(math.sin(k / (w - 1) * math.pi) * 2))
            tile.put(x + k, y - arc, (252, 253, 255, 255))
            tile.put(x + k, y - arc + 1, shadow)
            if 2 < k < w - 2:
                tile.put(x + k, y - arc + 2, deep if k > w // 2 else shadow)
    # Sparkles.
    for _ in range(8):
        x, y = tile.spot(2)
        tile.put(x, y, (255, 255, 255, 255))
    if variant >= 6:
        feature = variant % 3
        if feature == 0:
            # A patch of ice.
            x, y = tile.spot(8, N - 18)
            puddle(tile, x, y, 12, 6, (176, 206, 226, 255), (150, 186, 212, 255), (130, 150, 180, 255), (240, 250, 255, 255))
        elif feature == 1:
            # A rock poking through, snow on its crown.
            x, y = tile.spot(12, N - 16)
            stone(tile, x, y, 8, 5, [(40, 42, 52, 255), (66, 70, 82, 255), (92, 96, 108, 255), (120, 124, 136, 255), (150, 154, 166, 255)])
            for k in range(1, 7):
                tile.put(x + k, y, (250, 252, 255, 255))
                tile.put(x + k, y + 1, (230, 236, 244, 255) if k < 5 else shadow)
        else:
            # Animal tracks wandering across.
            x, y = tile.spot(6, N - 16)
            for k in range(6):
                px, py = x + k * 5, y + (2 if k % 2 else 0) + k // 2
                tile.put(px, py, deep)
                tile.put(px + 1, py, shadow)
                tile.put(px, py + 1, shadow)


def paint_salt(tile, field, variant):
    """Pale flats: bevelled plates of crust between dark cracks."""
    t = tile.t
    r = tile.r
    # Plates from a shared tiling set of points (Voronoi on a torus); the
    # variant moves only the inner points, so the edges agree.
    pts = []
    base_r = random.Random(1010)
    for gy in range(3):
        for gx in range(3):
            # A jittered grid, so plates are even in size.
            pts.append(((gx + 0.5 + base_r.uniform(-0.3, 0.3)) * N / 3, (gy + 0.5 + base_r.uniform(-0.3, 0.3)) * N / 3))
    own = random.Random(2020 + variant)
    own.random()
    for y in range(N):
        for x in range(N):
            best = []
            for i, (px, py) in enumerate(pts):
                dx = min(abs(x - px), N - abs(x - px))
                dy = min(abs(y - py), N - abs(y - py))
                best.append((dx * dx + dy * dy, i))
            best.sort()
            d0, d1 = math.sqrt(best[0][0]), math.sqrt(best[1][0])
            gap = d1 - d0
            if gap < 1.0:
                c = t[0]
            elif gap < 2.0:
                c = t[1]
            else:
                c = t[2] if best[0][1] % 3 else t[3]
            tile.img.putpixel((x, y), c)
    # Bevel: a lit pixel above each crack, a shade below.
    for y in range(1, N - 1):
        for x in range(N):
            if tile.img.getpixel((x, y)) == t[0]:
                above = tile.img.getpixel((x, y - 1))
                if above in (t[2], t[3]):
                    tile.img.putpixel((x, y - 1), t[4])
    for _ in range(10):
        x, y = tile.spot(2)
        tile.put(x, y, (240, 238, 228, 255))
    if variant >= 6:
        x, y = tile.spot(12, N - 12)
        # A crystal cluster.
        for k, h in ((0, 3), (1, 5), (2, 4), (3, 2)):
            for j in range(h):
                tile.put(x + k, y - j, (250, 250, 246, 255) if k < 2 else (200, 200, 196, 255))
        tile.darken(x + 4, y + 1)
        tile.darken(x + 3, y + 1)


def paint_fungal(tile, field, variant):
    t = tile.t
    base_fill(tile, field, (0.42, 0.64), seed=variant)
    r = tile.r
    # Mycelium threads.
    for _ in range(4):
        x, y = tile.spot(3, N - 12)
        crack(tile, x, y, r.randrange(5, 9), hsv_shift(t[3], ds=-0.15, k=1.25))
    # Spore dots.
    for _ in range(12):
        x, y = tile.spot(2)
        tile.put(x, y, (220, 120, 180, 255) if r.random() < 0.3 else t[4])
    # Little caps.
    for _ in range(r.randrange(2, 5)):
        x, y = tile.spot(4, N - 5)
        cap = r.choice(((192, 92, 140, 255), (150, 110, 200, 255)))
        tile.put(x, y, cap)
        tile.put(x + 1, y, hsv_shift(cap, k=1.25))
        tile.put(x + 2, y, cap)
        tile.put(x + 1, y + 1, (220, 210, 200, 255))
        tile.darken(x + 2, y + 2)
    if variant >= 6:
        cx, cy = tile.spot(12, N - 12)
        # A glowing pod.
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                if dx * dx + dy * dy <= 9:
                    tile.put(cx + dx, cy + dy, (230, 120, 190, 255) if dx + dy < 0 else (170, 70, 140, 255))
        tile.put(cx - 1, cy - 1, (255, 220, 240, 255))
        for k in range(4):
            tile.darken(cx + k, cy + 4, 0.7)


def paint_tar(tile, field, variant):
    t = tile.t
    base_fill(tile, field, (0.45, 0.66), seed=variant)
    r = tile.r
    # Glossy streaks.
    for _ in range(5):
        x, y = tile.spot(4, N - 10)
        for k in range(r.randrange(3, 7)):
            tile.put(x + k, y, t[4] if k == 1 else t[3])
    # Bubbles.
    for _ in range(r.randrange(2, 4)):
        x, y = tile.spot(4, N - 6)
        tile.put(x, y, t[3])
        tile.put(x + 1, y, t[3])
        tile.put(x, y + 1, t[1])
        tile.put(x + 1, y + 1, t[0])
        tile.put(x, y, t[4])
    if variant >= 6:
        x, y = tile.spot(10, N - 14)
        bone(tile, x, y, 6, (160, 150, 130, 255), (110, 100, 86, 255))
        for k in range(8):
            tile.put(x - 1 + k, y + 2, t[3])


def paint_sand(tile, field, variant):
    t = tile.t
    base_fill(tile, field, (0.3, 0.7), seed=variant)
    r = tile.r
    # Ripples: wavy lines, a lit crest over a shaded trough. Their rows
    # repeat each tile so they run on across neighbours.
    for row in (7, 21, 35):
        phase = row * 0.7
        for x in range(N):
            y = row + int(round(math.sin(x / N * math.tau * 2 + phase) * 1.5))
            # Broken here and there (the same breaks on every tile, so the
            # ripple runs on into the next).
            if hash2(x // 5, row, 11) < 0.25:
                continue
            tile.put(x, y, t[3], margin=0)
            tile.put(x, y + 1, t[1], margin=0)
    # Grains.
    for _ in range(20):
        x, y = tile.spot(2)
        tile.put(x, y, t[4] if r.random() < 0.5 else t[1])
    # A small stone or two.
    for _ in range(r.randrange(0, 3)):
        x, y = tile.spot(4, N - 6)
        stone(tile, x, y, 2, 2, [hsv_shift(c, ds=-0.2, k=0.85) for c in t])
    if variant >= 6:
        feature = variant % 3
        if feature == 0:
            # A shell.
            x, y = tile.spot(10, N - 12)
            shell = [(214, 190, 170, 255), (240, 224, 206, 255), (190, 160, 140, 255)]
            for dy in range(4):
                for dx in range(-dy, dy + 1):
                    tile.put(x + dx, y + dy, shell[1] if dx % 2 == 0 else shell[0])
            for dx in range(-3, 4):
                tile.put(x + dx, y + 4, shell[2])
                tile.darken(x + dx + 1, y + 5)
        elif feature == 1:
            x, y = tile.spot(10, N - 16)
            bone(tile, x, y, 8, (236, 228, 208, 255), (190, 180, 160, 255))
        else:
            x, y = tile.spot(10, N - 16)
            stone(tile, x, y, 7, 4, [hsv_shift(c, ds=-0.25, k=0.8) for c in t])


def paint_cinder(tile, field, variant):
    t = tile.t
    base_fill(tile, field, (0.44, 0.66), grain=0.05, seed=variant)
    r = tile.r
    glow_hot, glow_mid, glow_dim = (255, 200, 110, 255), (240, 120, 40, 255), (150, 50, 30, 255)
    # Glowing cracks: a hot core with a dim rim.
    for _ in range(r.randrange(0, 2)):
        x, y = tile.spot(6, N - 14)
        cx, cy = x, y
        for k in range(r.randrange(4, 8)):
            tile.put(cx, cy + 1, glow_dim)
            tile.put(cx, cy, glow_mid if k % 3 else glow_hot)
            step = r.choice(((1, 0), (1, 1), (1, -1)))
            cx, cy = cx + step[0], cy + step[1]
    # Cinder chunks.
    for _ in range(r.randrange(3, 6)):
        x, y = tile.spot(4, N - 6)
        stone(tile, x, y, 3, 2, [(20, 16, 16, 255), (34, 28, 28, 255), (52, 42, 40, 255), (76, 60, 56, 255), (100, 80, 74, 255)])
    if variant >= 6 and variant % 2 == 0:
        # A pool of cooling lava, crusted over at the edge.
        x, y = tile.spot(10, N - 18)
        puddle(tile, x, y, 8, 4, glow_mid, glow_dim, (30, 20, 20, 255), glow_hot)
    elif variant >= 6:
        x, y = tile.spot(10, N - 16)
        stone(tile, x, y, 7, 5, [(20, 16, 16, 255), (34, 28, 28, 255), (52, 42, 40, 255), (76, 60, 56, 255), (100, 80, 74, 255)])
        tile.put(x + 3, y + 4, glow_mid)
        tile.put(x + 4, y + 4, glow_hot)


def paint_void(tile, field, variant):
    t = tile.t
    base_fill(tile, field, (0.46, 0.66), seed=variant)
    r = tile.r
    accent = (154, 108, 240, 255)
    # Star specks.
    for _ in range(14):
        x, y = tile.spot(2)
        tile.put(x, y, (200, 180, 255, 255) if r.random() < 0.3 else t[4])
    # Faint rifts.
    for _ in range(2):
        x, y = tile.spot(5, N - 12)
        crack(tile, x, y, r.randrange(5, 9), hsv_shift(accent, k=0.6), None)
    if variant >= 6:
        x, y = tile.spot(8, N - 16)
        cx, cy = x, y
        for k in range(14):
            tile.put(cx, cy - 1, hsv_shift(accent, k=0.55))
            tile.put(cx, cy + 1, hsv_shift(accent, k=0.55))
            tile.put(cx, cy, accent if k % 4 else (230, 210, 255, 255))
            cx += 1
            cy += r.choice((-1, 0, 0, 1))


def paint_rock(tile, field, variant, peak=False):
    """High ground seen from above: fractured stone plates with lichen."""
    t = tile.t
    base_fill(tile, field, (0.4, 0.64), seed=variant)
    r = tile.r
    # Fractures with lit upper lips.
    for _ in range(r.randrange(1, 3)):
        x, y = tile.spot(4, N - 12)
        crack(tile, x, y, r.randrange(4, 8), t[0], t[3])
    # Lichen.
    if not peak:
        for _ in range(r.randrange(2, 5)):
            x, y = tile.spot(4, N - 6)
            lichen = r.choice(((140, 150, 90, 255), (170, 150, 90, 255)))
            for dx, dy in ((0, 0), (1, 0), (0, 1), (2, 1)):
                tile.put(x + dx, y + dy, lichen)
    else:
        # Snow lying in the hollows, in broad patches with a blue rim.
        drifts = Field(tile.r.randrange(10 ** 6), variant)
        drifts.shared = Field(4242, 0).shared
        for y in range(N):
            for x in range(N):
                v = drifts.at(x, y)
                if v < 0.38:
                    tile.put(x, y, (236, 242, 248, 255) if v < 0.35 else (190, 204, 224, 255), margin=0)
    for _ in range(r.randrange(2, 4)):
        x, y = tile.spot(4, N - 6)
        stone(tile, x, y, 3, 2, t)
    if variant >= 6:
        x, y = tile.spot(10, N - 16)
        stone(tile, x, y, 7, 5, t, moss=None if peak else (120, 136, 80, 255))


def paint_path(tile, field, variant):
    """A village road: rounded cobbles set in packed earth, worn smooth
    along the middle."""
    t = tile.t
    earth = [(54, 42, 30, 255), (72, 56, 40, 255), (92, 74, 54, 255), (110, 90, 66, 255), (130, 108, 80, 255)]
    for y in range(N):
        for x in range(N):
            tile.img.putpixel((x, y), earth[1] if hash2(x, y, 7) < 0.5 else earth[2])
    stones = [(68, 64, 70, 255), (96, 92, 98, 255), (124, 120, 126, 255), (150, 146, 150, 255), (180, 176, 178, 255)]
    # Cobbles in staggered courses that repeat each tile, so roads run on.
    for row in range(4):
        y0 = row * 11 + 1
        offset = 5 if row % 2 else 0
        x = -offset
        k = 0
        while x < N:
            w = 6 + int(hash2(row, k, 3) * 6)
            if x + w > N - offset + 1 and x + 4 < N:
                w = max(4, N - offset - x - 1) if offset else w
            h = 7 + int(hash2(row, k, 8) * 3)
            yo = int(hash2(row, k, 9) * 2)
            warm = hash2(row, k, 6) < 0.3
            tones = [hsv_shift(c, k=0.88 + hash2(row, k, 5) * 0.24) for c in stones]
            if warm:
                tones = [toward(hsv_shift(c, ds=0.12), 0.1, 0.9) for c in tones]
            for dy in range(h):
                for dx in range(w):
                    u = (dx + 0.5 - w / 2) / (w / 2)
                    v = (dy + 0.5 - h / 2) / (h / 2)
                    if abs(u) ** 2.4 + abs(v) ** 2.4 > 1.0:
                        continue
                    lit = -u - v
                    c = tones[4] if lit > 1.0 else tones[3] if lit > 0.2 else tones[2] if lit > -0.8 else tones[1]
                    tile.img.putpixel(((x + dx) % N, (y0 + yo + dy) % N), c)
            # A shadow along the bottom of each cobble.
            for dx in range(1, w - 1):
                tile.img.putpixel(((x + dx) % N, (y0 + yo + h) % N), earth[0])
            x += w + 2
            k += 1
    r = tile.r
    # Dirt and grit in the joints; a missing cobble on featured tiles.
    for _ in range(10):
        x, y = tile.spot(2)
        tile.put(x, y, earth[3])
    if variant >= 6:
        x, y = tile.spot(8, N - 14)
        for dy in range(6):
            for dx in range(7):
                tile.put(x + dx, y + dy, earth[2] if (dx + dy) % 3 else earth[1])
        tuft(tile, x + 2, y + 5, [(30, 44, 30, 255), (44, 64, 40, 255), (60, 86, 52, 255), (84, 112, 66, 255), (120, 144, 86, 255)], 2)


def paint_track(tile, field, variant):
    """A wayfarers' track across the country: earth trodden hard and pale,
    scuffed with prints, pebbles kicked aside, the odd sprig of grass."""
    t = tile.t
    base_fill(tile, field, (0.3, 0.72), grain=0.03, seed=variant)
    r = tile.r
    # Prints: little dark ovals where feet and hooves have pressed in.
    for _ in range(r.randrange(3, 7)):
        x, y = tile.spot(4, N - 6)
        tile.put(x, y, t[1])
        tile.put(x + 1, y, t[1])
        tile.put(x, y + 1, t[1])
        tile.put(x + 1, y + 1, t[0] if r.random() < 0.4 else t[1])
        tile.put(x, y - 1, t[3])
    # Scuffs: short pale streaks where the ground is worn smooth.
    for _ in range(4):
        x, y = tile.spot(4, N - 10)
        for k in range(r.randrange(3, 6)):
            tile.put(x + k, y, t[3])
    for _ in range(r.randrange(2, 5)):
        x, y = tile.spot(4, N - 6)
        stone(tile, x, y, 2, 2, [hsv_shift(c, ds=-0.25, k=1.05) for c in t])
    grass = [(30, 44, 30, 255), (44, 64, 40, 255), (60, 86, 52, 255), (84, 112, 66, 255), (120, 144, 86, 255)]
    if r.random() < 0.5:
        x, y = tile.spot(5, N - 4)
        tuft(tile, x, y, grass, 2)
    if variant >= 6:
        feature = variant % 3
        if feature == 0:
            x, y = tile.spot(8, N - 16)
            puddle(tile, x, y, 10, 5, (60, 72, 84, 255), (44, 52, 62, 255), t[0], (130, 150, 170, 255))
        elif feature == 1:
            x, y = tile.spot(10, N - 16)
            stone(tile, x, y, 6, 4, [hsv_shift(c, ds=-0.3, k=1.0) for c in t])
            tuft(tile, x + 6, y + 5, grass, 3)
        else:
            # A lost horseshoe.
            x, y = tile.spot(10, N - 12)
            iron = (120, 120, 128, 255)
            for dx, dy in ((0, 0), (0, 1), (0, 2), (1, 3), (2, 3), (3, 3), (4, 2), (4, 1), (4, 0)):
                tile.put(x + dx, y + dy, iron)
                tile.darken(x + dx + 1, y + dy + 1)
            tile.put(x, y, (170, 170, 178, 255))


def paint_floor(tile, field, variant):
    """Plain floor for anything else: the old tile, mottled."""
    base_fill(tile, field, (0.4, 0.62), grain=0.05, seed=variant)


PAINTERS = {
    "dead_grass": lambda tl, f, v: paint_grass(tl, f, "dead_grass", v),
    "dark_grass": lambda tl, f, v: paint_grass(tl, f, "dark_grass", v),
    "frostpine": lambda tl, f, v: paint_grass(tl, f, "frostpine", v),
    "thorn": lambda tl, f, v: paint_grass(tl, f, "thorn", v),
    "crimson": lambda tl, f, v: paint_grass(tl, f, "crimson", v),
    "mud": paint_mud,
    "cave_floor": lambda tl, f, v: paint_mud(tl, f, v, cave=True),
    "ash": paint_ash,
    "bog": paint_bog,
    "snow": paint_snow,
    "salt": paint_salt,
    "fungal": paint_fungal,
    "tar": paint_tar,
    "sand": paint_sand,
    "cinder": paint_cinder,
    "voidscar": paint_void,
    "mountain": paint_rock,
    "peak": lambda tl, f, v: paint_rock(tl, f, v, peak=True),
    "path": paint_path,
    "track": paint_track,
}


def draw(row, name, base, light, dark, variant):
    """The tile for one terrain and variant, or None if this painter does
    not draw that terrain (water, floorboards, walls)."""
    from PIL import Image
    if name not in PAINTERS:
        return None
    tones = ramp(base, light, dark)
    img = Image.new("RGBA", (N, N), tones[2])
    tile = Tile(img, tones, row * 131 + variant * 17 + 5)
    field = Field(row, variant)
    PAINTERS[name](tile, field, variant)
    return img
