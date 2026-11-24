"""Flowers, mushrooms and bushes redrawn (visual overhaul, phase 4).

Same sizes and sheet places as before (tools/generate_flora.py takes these
in place of its own): flowers and mushrooms 32 x 32, bushes 64 x 96 low in
the cell. More pixels of detail in each: a rosette of veined leaves under
every flower, two or three stems of different heights, blooms shaded in
four tones with lit petal edges; domed mushroom caps with spots, gills and
shaded stems; bushes of layered leaf clusters (the green ones in the
seasons' greens, so they still turn through the year).
"""
import math
import random

from generate_flora import Canvas, C, _outline_tinted
from generate_trees import cluster, SUMMER, finish as tree_finish

LEAF = [C("1e3a1c"), C("2e5a28"), C("447a34"), C("5e9a44"), C("8ac060")]


def tones(light, mid, dark):
    """Four tones from a three-colour ramp: a highlight above the light."""
    l, m, d = C(light) if isinstance(light, str) else light, C(mid) if isinstance(mid, str) else mid, C(dark) if isinstance(dark, str) else dark
    hi = tuple(min(255, int(v + (255 - v) * 0.45)) for v in l[:3]) + (255,)
    deep = tuple(int(v * 0.7) for v in d[:3]) + (255,)
    return [deep, d, m, l, hi]


def ground_shadow(c, cx, cy, rx, ry=2, alpha=70):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / max(ry, 1)) ** 2 <= 1.0 and 0 <= x < c.w and 0 <= y < c.h:
                c.img.putpixel((x, y), (0, 0, 0, alpha))


def leaf(c, x, y, length, angle, t=LEAF):
    """A pointed leaf with a pale midrib, lit on its upper edge."""
    for s in range(length):
        f = s / length
        w = math.sin(f * math.pi) * (length * 0.22)
        px, py = x + math.cos(angle) * s, y + math.sin(angle) * s
        nx, ny = -math.sin(angle), math.cos(angle)
        for d in range(-int(w + 0.5), int(w + 0.5) + 1):
            tone = 3 if d < 0 else 1 if d > 0 else 4
            c.put(px + nx * d, py + ny * d, t[tone])


def rosette(c, cx=16, base=29, n=4, size=7, seed=0):
    r = random.Random(seed)
    angles = [-2.8, -0.35, -2.2, -0.95, -1.6][:n]
    for a in angles:
        leaf(c, cx, base, size + r.randint(-1, 1), a + r.uniform(-0.12, 0.12))


def stem(c, x0, y0, x1, y1, t=LEAF):
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for s in range(steps + 1):
        f = s / steps
        x = x0 + (x1 - x0) * f + math.sin(f * math.pi) * 0.8
        y = y0 + (y1 - y0) * f
        c.put(x, y, t[2])
        if s % 4 == 2:
            c.put(x - 1, y, t[3])


def bloom(c, kind, x, y, p, centre):
    """One flower head at (x, y) in tones p (deep..highlight)."""
    if kind == "daisy":
        for k in range(8):
            a = k / 8 * math.tau
            for s in (1, 2, 3):
                px, py = x + math.cos(a) * s, y + math.sin(a) * s * 0.8
                lit = math.cos(a + 2.3)
                c.put(px, py, p[4] if (lit > 0.3 and s == 3) else p[3] if lit > -0.2 else p[2])
        c.put(x, y, centre[2]); c.put(x + 1, y, centre[1]); c.put(x, y - 1, centre[3]); c.put(x - 1, y, centre[2])
    elif kind == "tulip":
        for dy in range(-4, 2):
            half = 2 if dy < -2 else 3 if dy < 1 else 2
            for dx in range(-half, half + 1):
                tone = 4 if dx == -half + 1 and dy < -1 else 3 if dx < 0 else 2 if dx == 0 else 1
                c.put(x + dx, y + dy, p[tone])
        c.put(x, y - 4, p[1]); c.put(x - 2, y - 5, p[3]); c.put(x + 2, y - 5, p[2])
    elif kind == "bell":
        for k in range(3):
            bx, by = x + k * 2 - 2, y + k * 3
            for dy in range(3):
                for dx in range(-1 - (dy == 2), 2 + (dy == 2)):
                    c.put(bx + dx, by + dy, p[3] if dx < 0 else p[2] if dx == 0 else p[1])
            c.put(bx - 1, by, p[4])
            c.put(bx, by + 3, p[0])
    elif kind == "spike":
        for k in range(7):
            by = y + k * 2 - 6
            for dx in (-1, 0, 1):
                if k == 0 and dx != 0:
                    continue
                c.put(x + dx, by, p[3] if dx < 0 else p[2] if dx == 0 else p[1])
            c.put(x - 1, by - 1, p[4] if k % 2 else p[3])
    elif kind == "star":
        for k in range(5):
            a = k / 5 * math.tau - math.pi / 2
            for s in (1, 2, 3):
                c.put(x + math.cos(a) * s, y + math.sin(a) * s, p[4] if s == 1 else p[3] if math.cos(a + 2.3) > -0.3 else p[2])
        c.put(x, y, centre[3] if centre else p[0])
    elif kind == "cup":
        for dy in range(-3, 2):
            half = 3 if dy < 0 else 2
            for dx in range(-half, half + 1):
                inner = dy < -1 and abs(dx) < half
                tone = 1 if inner else 4 if dx < -1 and dy >= -1 else 3 if dx <= 0 else 2
                c.put(x + dx, y + dy, p[tone])
        if centre:
            c.put(x, y - 2, centre[3]); c.put(x + 1, y - 2, centre[2])
    elif kind == "rose":
        for dy in range(-3, 3):
            for dx in range(-3, 4):
                if dx * dx + dy * dy * 1.2 > 11:
                    continue
                ring = int(math.hypot(dx, dy * 1.1))
                tone = 4 if (dx < 0 and dy < 0 and ring == 2) else 3 if ring % 2 == 0 else 1
                c.put(x + dx, y + dy, p[tone])
        c.put(x, y, p[0]); c.put(x + 1, y - 1, p[2])
    elif kind == "sun":
        for k in range(12):
            a = k / 12 * math.tau
            for s in (3, 4):
                c.put(x + math.cos(a) * s, y + math.sin(a) * s * 0.9, p[4] if math.cos(a + 2.3) > 0.4 else p[3] if math.cos(a + 2.3) > -0.4 else p[2])
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if dx * dx + dy * dy <= 5:
                    c.put(x + dx, y + dy, C("5a3a18") if (dx + dy) % 2 else C("7a5222"))
        c.put(x - 1, y - 1, C("a07a3a"))
    elif kind == "poppy":
        for k in range(4):
            a = k / 4 * math.tau + 0.4
            px, py = x + math.cos(a) * 2, y + math.sin(a) * 1.8
            for dy in range(-1, 2):
                for dx in range(-2, 2):
                    c.put(px + dx, py + dy, p[4] if (dx < -1 and dy < 0 and math.cos(a + 2.3) > 0) else p[3] if math.cos(a + 2.3) > -0.3 else p[2])
        c.put(x, y, C("1a1010")); c.put(x + 1, y, C("2a1a18")); c.put(x, y - 1, C("3a2a20"))
    elif kind == "aster":
        for k in range(12):
            a = k / 12 * math.tau
            for s in (2, 3):
                c.put(x + math.cos(a) * s, y + math.sin(a) * s * 0.85, p[3] if math.cos(a + 2.3) > -0.2 else p[2])
            c.put(x + math.cos(a) * 3, y + math.sin(a) * 3 * 0.85, p[4] if math.cos(a + 2.3) > 0.5 else p[3])
        c.put(x, y, centre[2] if centre else p[0]); c.put(x + 1, y, centre[1] if centre else p[0])
        c.put(x, y - 1, centre[3] if centre else p[1])


def flower(kind, petals, centre=None, seed=0):
    c = Canvas(32, 32)
    r = random.Random(seed * 7 + hash(kind) % 97)
    ground_shadow(c, 16, 29, 9)
    rosette(c, 16, 29, n=5 if kind in ("sun", "spike", "bell") else 4, size=7, seed=seed)
    p = tones(*petals)
    ctr = tones(*centre) if isinstance(centre, list) else (tones(centre, centre, centre) if centre else None)
    heads = 1 if kind in ("sun",) else 2 if kind in ("bell", "spike", "rose") else 3
    spots = [(16, 9), (9, 14), (23, 13)][:heads] if heads > 1 else [(16, 8)]
    for k, (hx, hy) in enumerate(spots):
        hx += r.randint(-1, 1)
        hy += r.randint(-1, 2) + (k * 2)
        top_y = hy + (3 if kind in ("tulip", "cup") else 2)
        stem(c, 16 + (hx - 16) // 3, 28, hx, top_y)
        bloom(c, kind, hx, hy, p, ctr)
    _outline_tinted(c, (18, 26, 16))
    return c.img


def mushrooms(cap, seed=0, glow=False):
    c = Canvas(32, 32)
    r = random.Random(seed)
    t = tones(*cap)
    if glow:
        for y in range(8, 32):
            for x in range(2, 30):
                d = math.hypot((x - 16) / 13, (y - 22) / 10)
                if d < 1.0 and (x + y) % 2 == 0 and d > 0.55:
                    c.img.putpixel((x, y), t[3][:3] + (int(70 * (1 - d)),))
    ground_shadow(c, 16, 29, 11)
    # Moss at the foot.
    for x in range(7, 26):
        if r.random() < 0.6:
            c.put(x, 29, LEAF[2] if x % 3 else LEAF[3])
    for k, (mx, top, w, h) in enumerate(((16, 9, 7, 11), (8, 17, 5, 8), (24, 15, 5, 9))[:3 if seed % 2 == 0 else 2]):
        stem_t = [C("6a6050"), C("a89e88"), C("d8d0bc"), C("f2efe2")]
        for y in range(top + 3, 29):
            for dx in range(-1, 2):
                c.put(mx + dx, y, stem_t[3] if dx < 0 else stem_t[2] if dx == 0 else stem_t[1])
        # The cap: a dome lit from the top-left, gills dark underneath.
        for dy in range(0, 5):
            half = w - (4 - dy) * (w // 4) if dy < 4 else w
            half = max(2, int(w * math.sqrt(1 - ((4 - dy) / 5) ** 2)))
            for dx in range(-half, half + 1):
                lit = -dx / half * 0.6 - (4 - dy) / 4 * 0.8
                tone = 4 if lit < -0.75 and dy < 3 else 3 if lit < -0.2 else 2 if lit < 0.35 else 1
                c.put(mx + dx, top + dy, t[tone])
        for dx in range(-w + 1, w):
            c.put(mx + dx, top + 5, t[0] if dx % 2 else C("4a3a30"))
        # Spots on the bright caps.
        if not glow and k == 0:
            for sx, sy in ((-3, 1), (2, 2), (-1, 3), (4, 3)):
                c.put(mx + sx, top + sy, C("f4f0e8"))
        if glow:
            c.put(mx - 2, top + 1, C("ffffff"))
    _outline_tinted(c, (20, 16, 18))
    return c.img


def bush(leaves, berries=None, snow=False, seed=7, twiggy=False, thorns=False, spores=None):
    """A bush of layered leaf clusters, low in a 64 x 96 cell."""
    c = Canvas(64, 96)
    ground_shadow(c, 32, 90, 20, 4, 80)
    if twiggy or thorns:
        twig = [C("3a2a1e"), C("5a4030"), C("7a5a40")]
        r = random.Random(seed)
        for _ in range(9):
            x0 = 32 + r.randint(-6, 6)
            ang = r.uniform(-2.7, -0.45)
            for s in range(r.randint(10, 18)):
                px, py = x0 + math.cos(ang) * s, 89 + math.sin(ang) * s
                c.put(px, py, twig[1] if s % 3 else twig[2])
                if thorns and s % 4 == 2:
                    c.put(px + 1, py - 1, C("d8d0b8"))
    clusters = [(32, 80, 17, 10, 1), (19, 84, 10, 7, 0), (45, 84, 10, 7, 0), (30, 72, 11, 8, 0), (40, 76, 9, 7, 0)]
    if twiggy:
        clusters = [(24, 78, 7, 5, 0), (40, 74, 8, 5, 0), (32, 84, 9, 5, 1)]
    for k, (cx, cy, rx, ry, depth) in enumerate(sorted(clusters, key=lambda q: -q[4])):
        cluster(c, cx, cy, rx, ry, leaves, seed * 13 + k, depth)
    r = random.Random(seed + 1)
    if berries:
        b = tones(*berries) if isinstance(berries, (list, tuple)) else tones(berries, berries, berries)
        for _ in range(11):
            x, y = r.randrange(16, 48), r.randrange(66, 88)
            if (x, y) in c.filled and (x + 1, y + 1) in c.filled:
                c.put(x, y, b[3]); c.put(x + 1, y, b[2]); c.put(x, y + 1, b[1]); c.put(x + 1, y + 1, b[0])
                c.put(x, y, b[4])
    if spores:
        for _ in range(10):
            x, y = r.randrange(16, 48), r.randrange(64, 88)
            if (x, y) in c.filled:
                c.put(x, y, spores)
    if snow:
        for x in range(10, 54):
            for y in range(56, 90):
                if (x, y) in c.filled and (x, y - 1) not in c.filled:
                    c.put(x, y, C("ffffff"))
                    c.put(x, y + 1, C("dce6f0"))
                    if x % 3:
                        c.put(x, y + 2, C("b4c4d6"))
                    break
    return tree_finish(c)


def _five(light, mid, dark):
    return tones(light, mid, dark)


def redraw(small, tall):
    """Puts the redrawn flowers, mushrooms and bushes in their sheet places."""
    F = flower
    swaps = {
        0: F("daisy", ("f4f2ec", "d4d0c4", "a8a498"), "f0cf6a", 1), 1: F("tulip", ("f07070", "c0303a", "801820"), None, 2),
        2: F("bell", ("a8c0ff", "6a88d8", "4058a0"), None, 3), 3: F("spike", ("c8a0f0", "9a6cc8", "6a4290"), None, 4),
        4: F("star", ("ffe08a", "f0b030", "b07a18"), "c05a2a", 5), 5: F("cup", ("ff8a5a", "e05a2a", "a03a18"), None, 6),
        11: mushrooms(("e05a5a", "b0303a", "701820"), seed=6), 12: mushrooms(("8ff0ff", "4ab0c8", "2a7088"), seed=7, glow=True),
        24: F("star", ("d8f4ff", "a8d8f0", "70a8c8"), "ffffff", 7), 25: F("bell", ("ff8a8a", "c02a3a", "801820"), None, 8),
        26: mushrooms(("8ff0c0", "3ab088", "1a7050"), seed=14, glow=True), 27: F("spike", ("aac87a", "7a9a4a", "4a6a2a"), None, 9),
        28: F("cup", ("ffd86b", "f08a2e", "b8401e"), None, 10), 29: F("star", ("e0c0ff", "9a6cf0", "5c3690"), "ffffff", 11),
        30: F("tulip", ("f4f2ec", "d4d0c4", "a8a498"), None, 12), 31: F("daisy", ("ffb0d0", "e070a0", "a04070"), "ffe08a", 13),
        32: F("rose", ("f05a6a", "b0203a", "6a1020"), None, 14), 33: F("spike", ("c8b0ff", "8a6ae0", "5a42a0"), None, 15),
        34: F("sun", ("ffe060", "f0b020", "b07a10"), None, 16), 35: F("poppy", ("ff6a4a", "e0302a", "a01a18"), None, 17),
        36: F("aster", ("b8d0ff", "7a98e0", "4a68b0"), "ffe08a", 18), 37: F("bell", ("f0e8ff", "c8b8f0", "8a78c0"), None, 19),
        38: F("rose", ("4a3a50", "2a2030", "120c18"), None, 20), 39: F("cup", ("ffb0e0", "e070b8", "a04080"), "ffe08a", 21),
        40: F("poppy", ("ffe0a0", "f0b860", "b07a30"), None, 22), 41: F("aster", ("ff9a5a", "e05a2a", "a03a18"), "3a1a10", 23),
    }
    for index, image in swaps.items():
        small[index] = image
    tall[14] = bush(SUMMER, seed=7)
    tall[15] = bush(SUMMER, berries=("f05a5a", "c0303a", "701820"), seed=9)
    tall[16] = bush(_five("5a7c78", "3d5a58", "2a4040"), snow=True, seed=10)
    tall[17] = bush(_five("8a7a4a", "6a5a34", "4a3e24"), berries=("f0e8c0", "d8c890", "a89860"), seed=12, thorns=True)
    tall[18] = bush(_five("b8aa7a", "8a7a50", "64583a"), seed=13, twiggy=True)
    tall[19] = bush(_five("d080b0", "a04878", "6c2c52"), seed=14, spores=C("f8d8f0"))
