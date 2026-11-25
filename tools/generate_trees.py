"""Grand trees (visual overhaul, phase 4): larger trees drawn a pixel at a
time, three to five kinds for every biome.

Each is 96 x 128 with its foot near the bottom (the same place as on the
small tall sheet, so they stand on their tile the same way): a tapering
trunk with bark fissures, lit on the left; roots that flare out over the
ground; boughs that show between the layers of the crown; and a crown
built of leaf clusters in layers, the back ones in shade, each cluster
covered in small lit leaf scales.

The broadleaf crowns are painted in exactly the five greens of the
seasons' summer ramp (scripts/effects/seasons.gd), so the season shader
can turn them; bark, fruit and blossom keep their own colours (the
shader leaves anything not green alone for these trees).

Run: python3 tools/generate_trees.py -> assets/sprites/flora_grand.png
"""
import math
import os
import random

from PIL import Image

from generate_flora import Canvas, C

W, H = 96, 128
FOOT = 122
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")

# The seasons' summer greens, darkest to lightest (the shader's ramp).
SUMMER = [(62, 106, 48, 255), (90, 146, 62, 255), (124, 180, 76, 255), (162, 210, 96, 255), (210, 238, 140, 255)]
OAK_BARK = [C("2a1e18"), C("443024"), C("5e4232"), C("7a5a42"), C("967458")]
BIRCH_BARK = [C("3a3634"), C("8a8680"), C("c8c4b8"), C("e4e0d4"), C("f6f4ec")]
DARK_BARK = [C("1c1618"), C("2e2426"), C("443438"), C("5a4648"), C("70585a")]
PALM_BARK = [C("3e2e1e"), C("5e4628"), C("806238"), C("a2804a"), C("c0a066")]
PINE = [C("2a564e"), C("3c7266"), C("52907e"), C("6eac96"), C("98ccb6")]
CRIMSON = [C("3a0e16"), C("5e1a24"), C("8a2a34"), C("b03e44"), C("d8706a")]
THORN = [C("2a2a16"), C("3e3e20"), C("56542c"), C("6e6a3a"), C("8c8650")]
SPORE = [C("2a1838"), C("442a5a"), C("64407e"), C("8a5ca4"), C("b488cc")]
SNOW = [C("8ea0b8"), C("b4c4d6"), C("d6e0ea"), C("eef2f8"), C("ffffff")]


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def hash2(x, y, seed=0):
    h = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


# --- parts -------------------------------------------------------------------

def trunk(c, x, top, bottom, w_bottom, w_top, bark, seed, lean=0.0, fissures=True, rings=False):
    """A trunk tapering from bottom to top, lit on the left, with fissures."""
    r = random.Random(seed)
    for y in range(int(top), int(bottom) + 1):
        t = (bottom - y) / max(bottom - top, 1)
        w = w_bottom + (w_top - w_bottom) * t
        cx = x + lean * (bottom - y)
        x0, x1 = int(round(cx - w / 2)), int(round(cx + w / 2))
        for xx in range(x0, x1 + 1):
            u = (xx - x0) / max(x1 - x0, 1)
            tone = 4 if u < 0.16 else 3 if u < 0.38 else 2 if u < 0.68 else 1 if u < 0.88 else 0
            if fissures and 0.2 < u < 0.85 and hash2(xx // 2, y // 5 + (xx % 3), seed) < 0.16:
                tone = max(tone - 2, 0)
            if rings and y % 6 == 0:
                tone = max(tone - 1, 0)
            c.put(xx, y, bark[tone])
    # Knots.
    for _ in range(2):
        ky = r.randint(int(top) + 6, int(bottom) - 8) if bottom - top > 16 else int(top)
        kx = int(x + lean * (bottom - ky)) + r.choice((-1, 1))
        c.put(kx, ky, bark[0])
        c.put(kx + 1, ky, bark[1])
        c.put(kx, ky - 1, bark[3])


def roots(c, x, foot, w, bark, seed, count=4, reach=12):
    """Roots flaring out over the ground from the trunk's foot."""
    r = random.Random(seed)
    for k in range(count):
        side = -1 if k % 2 == 0 else 1
        start = x + side * (w / 2 - 1 - r.random() * 2)
        length = reach * (0.6 + 0.5 * r.random())
        for s in range(int(length)):
            t = s / length
            px = start + side * s
            py = foot - 4 + t * 5 + math.sin(t * 3 + k) * 0.6
            thick = max(1, int(round(3 * (1 - t))))
            for d in range(thick):
                c.put(px, py + d, bark[3] if d == 0 else bark[1] if d == thick - 1 else bark[2])


def bough(c, x0, y0, x1, y1, w0, w1, bark):
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for s in range(steps + 1):
        t = s / max(steps, 1)
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        w = w0 + (w1 - w0) * t
        for d in range(int(-w / 2), int(w / 2) + 1):
            tone = 3 if d < 0 else 1 if d > 0 else 2
            c.put(x + d, y, bark[tone])


def cluster(c, cx, cy, rx, ry, tones, seed, depth=0, light=(-0.62, -0.78)):
    """A bushy clump of leaves: a lumpy rounded mass shaded from the top-left,
    its edge broken by leaf tufts poking out, its face built of small round
    leaf clumps, each lit along its upper left and shaded along its lower
    right, so it reads as foliage rather than a smooth ball. `depth`
    darkens clumps further back in the crown."""
    r = random.Random(seed)
    pts = {}
    for y in range(int(cy - ry - 3), int(cy + ry + 4)):
        for x in range(int(cx - rx - 3), int(cx + rx + 4)):
            a = math.atan2(y - cy, x - cx)
            wob = 1.0 + 0.16 * math.sin(a * 6 + seed) + 0.1 * math.sin(a * 11 + seed * 2)
            u, v = (x - cx) / (rx * wob), (y - cy) / (ry * wob)
            if u * u + v * v <= 1.0:
                pts[(x, y)] = (u, v)

    def tone_at(u, v, bias=0):
        lit = u * light[0] + v * light[1]
        tone = 3 if lit > 0.45 else 2 if lit > -0.15 else 1 if lit > -0.6 else 0
        return max(0, min(4, tone + bias - depth))

    for (x, y), (u, v) in pts.items():
        c.put(x, y, tones[tone_at(u, v)])
    # Leaf tufts: along the top and sides of the edge, little points of
    # leaves stand out a pixel or two (never along the shaded bottom).
    edge = [(x, y) for (x, y) in pts if any((x + dx, y + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in edge:
        u, v = pts[(x, y)]
        if v > 0.55 or r.random() > 0.42:
            continue
        nx, ny = (x - cx), (y - cy)
        n = math.hypot(nx, ny) or 1.0
        step = (round(nx / n), round(ny / n))
        for k in range(1, 1 + (2 if r.random() < 0.35 else 1)):
            p = (x + step[0] * k, y + step[1] * k)
            c.put(p[0], p[1], tones[tone_at(u, v, 1 if v < -0.3 else 0)])
            pts.setdefault(p, (u, v))
    # The face: small round leaf clumps in staggered rows.
    for gy in range(int(cy - ry) + 1, int(cy + ry) + 1, 4):
        for gx in range(int(cx - rx) + (gy // 4) % 2 * 3, int(cx + rx) + 1, 5):
            if (gx, gy) not in pts or r.random() < 0.15:
                continue
            u, v = pts[(gx, gy)]
            base = tone_at(u, v)
            hi = min(4, base + 1)
            lo = max(0, base - 1)
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    if dx * dx + dy * dy > 5 or (gx + dx, gy + dy) not in pts:
                        continue
                    if dx + dy <= -2:
                        c.put(gx + dx, gy + dy, tones[hi])
                    elif dx + dy >= 3 or (dy == 2 and dx >= 0):
                        c.put(gx + dx, gy + dy, tones[lo])
            # A bright leaf tip on the most lit clumps.
            if base >= 2 and r.random() < 0.6:
                c.put(gx - 1, gy - 1, tones[min(4, base + 2)])
    return set(pts)


def crown(c, clusters, tones, seed):
    """A crown from (cx, cy, rx, ry, depth) clusters, back ones first, each
    a good deal fuller than given, with two low clumps hanging at either
    side of its foot, so the crown reads thick and leafy and comes down
    over the top of the trunk."""
    left = min(cx - rx for cx, _cy, rx, _ry, _d in clusters)
    right = max(cx + rx for cx, _cy, rx, _ry, _d in clusters)
    bottom = max(cy + ry for _cx, cy, _rx, ry, _d in clusters)
    ry_mean = sum(ry for *_r, ry, _d in clusters) / len(clusters)
    mid = (left + right) / 2
    width = right - left
    skirts = [(mid - width * 0.27, bottom - ry_mean * 0.55, width * 0.2, ry_mean * 0.7, 1),
              (mid + width * 0.27, bottom - ry_mean * 0.5, width * 0.2, ry_mean * 0.7, 1)]
    for k, (cx, cy, rx, ry, depth) in enumerate(sorted(list(clusters) + skirts, key=lambda q: -q[4])):
        cluster(c, cx, cy, rx * 1.2 + 0.8, ry * 1.2 + 0.8, tones, seed * 31 + k, depth)


def shadow(c, cx, cy, rx, ry, alpha=70):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            u, v = (x - cx) / rx, (y - cy) / ry
            if u * u + v * v <= 1.0 and 0 <= x < c.w and 0 <= y < c.h:
                c.img.putpixel((x, y), (0, 0, 0, alpha))


def fruit(c, spots, colour, hi):
    for x, y in spots:
        c.put(x, y, colour)
        c.put(x + 1, y, colour)
        c.put(x, y + 1, mix(colour, (0, 0, 0, 255), 0.35))
        c.put(x + 1, y + 1, mix(colour, (0, 0, 0, 255), 0.35))
        c.put(x, y, hi)


def finish(c):
    c.outline()
    # Round a crown the outline is its own darkest green, not black, so the
    # season shader takes it with the leaves (a bare tree leaves no ghost).
    greens = set(SUMMER)
    px = c.img.load()
    for y in range(c.h):
        for x in range(c.w):
            if (x, y) in c.filled or px[x, y][3] == 0:
                continue
            if any(0 <= x + dx < c.w and 0 <= y + dy < c.h and px[x + dx, y + dy] in greens
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = SUMMER[0]
    return c.img


# --- trees ---------------------------------------------------------------------

def great_oak():
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 30, 5)
    roots(c, 48, FOOT, 14, OAK_BARK, 1, count=6, reach=14)
    trunk(c, 48, 62, FOOT, 14, 9, OAK_BARK, 1)
    bough(c, 46, 74, 30, 56, 5, 2, OAK_BARK)
    bough(c, 50, 70, 68, 52, 5, 2, OAK_BARK)
    bough(c, 48, 66, 50, 44, 4, 2, OAK_BARK)
    crown(c, [(30, 52, 15, 11, 1), (66, 50, 16, 11, 1), (48, 36, 20, 13, 1),
              (24, 40, 12, 10, 0), (72, 40, 12, 10, 0), (40, 26, 15, 11, 0), (60, 28, 14, 11, 0),
              (48, 50, 14, 9, 0), (34, 58, 10, 7, 0), (62, 58, 10, 7, 0)], SUMMER, 11)
    return finish(c)


def birch():
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 18, 4)
    roots(c, 48, FOOT, 7, BIRCH_BARK, 2, count=3, reach=7)
    trunk(c, 48, 34, FOOT, 7, 4, BIRCH_BARK, 2, fissures=False)
    # The birch's black marks.
    r = random.Random(2)
    for _ in range(14):
        y = r.randint(40, FOOT - 6)
        x = 48 + r.randint(-2, 1)
        for k in range(r.randint(1, 3)):
            c.put(x + k, y, BIRCH_BARK[0])
    bough(c, 47, 64, 36, 50, 2, 1, BIRCH_BARK)
    bough(c, 49, 56, 60, 44, 2, 1, BIRCH_BARK)
    # An airy crown of small clumps with sky between them.
    crown(c, [(36, 48, 9, 7, 1), (60, 42, 9, 7, 1), (48, 30, 11, 9, 0), (40, 38, 8, 7, 0), (57, 30, 8, 7, 0),
              (48, 18, 8, 7, 0), (34, 56, 6, 5, 0), (62, 52, 6, 5, 0)], SUMMER, 22)
    return finish(c)


def apple():
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 24, 4)
    roots(c, 48, FOOT, 10, OAK_BARK, 3, count=4, reach=9)
    trunk(c, 48, 76, FOOT, 10, 7, OAK_BARK, 3, lean=0.04)
    bough(c, 46, 84, 32, 70, 3, 2, OAK_BARK)
    bough(c, 50, 82, 64, 70, 3, 2, OAK_BARK)
    crown(c, [(32, 66, 13, 10, 1), (64, 66, 13, 10, 1), (48, 54, 19, 13, 0), (36, 56, 11, 9, 0), (60, 56, 11, 9, 0),
              (48, 70, 12, 8, 0)], SUMMER, 33)
    fruit(c, [(36, 62), (44, 70), (58, 60), (62, 70), (50, 58), (30, 68), (54, 74), (40, 52)], C("c83a30"), C("ff9a80"))
    return finish(c)


def beech():
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 22, 4)
    roots(c, 48, FOOT, 11, DARK_BARK[:1] + OAK_BARK[1:], 4, count=5, reach=11)
    trunk(c, 48, 40, FOOT, 11, 7, [C("2e2a28"), C("4a4642"), C("6a645c"), C("847c72"), C("a0988a")], 4, fissures=False)
    bough(c, 47, 58, 34, 40, 3, 1, OAK_BARK)
    bough(c, 49, 52, 62, 36, 3, 1, OAK_BARK)
    crown(c, [(34, 36, 13, 11, 1), (62, 34, 13, 11, 1), (48, 22, 17, 13, 0), (38, 30, 11, 9, 0), (58, 28, 11, 9, 0),
              (48, 42, 12, 8, 0)], SUMMER, 44)
    return finish(c)


def great_willow():
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 30, 5)
    roots(c, 48, FOOT, 13, OAK_BARK, 5, count=6, reach=12)
    trunk(c, 48, 60, FOOT, 13, 9, OAK_BARK, 5, lean=-0.03)
    crown(c, [(48, 40, 26, 14, 1), (34, 46, 14, 10, 0), (62, 44, 14, 10, 0), (48, 30, 18, 10, 0)], SUMMER, 55)
    # Curtains of hanging leaves.
    r = random.Random(5)
    for x in range(20, 77, 2):
        top = 44 + int(abs(x - 48) * 0.2)
        length = r.randint(26, 46)
        for y in range(top, min(top + length, FOOT - 4)):
            t = (y - top) / length
            tone = 3 if (x // 2) % 3 == 0 and t < 0.6 else 2 if t < 0.7 else 1
            if hash2(x, y, 5) < 0.12:
                continue
            c.put(x, y, SUMMER[tone])
        c.put(x, min(top + length, FOOT - 4), SUMMER[4])
    return finish(c)


def cypress():
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 22, 4)
    bark = [C("2a2018"), C("443428"), C("5c4834"), C("745c42"), C("8e7452")]
    # A buttressed foot with knees rising from the mire round it.
    for k, (dx, h) in enumerate(((-18, 6), (-12, 9), (14, 8), (20, 5))):
        trunk(c, 48 + dx, FOOT - h, FOOT, 3, 2, bark, 60 + k, fissures=False)
    for y in range(FOOT - 18, FOOT + 1):
        t = (FOOT - y) / 18
        w = 22 - 12 * t
        for x in range(int(48 - w / 2), int(48 + w / 2) + 1):
            u = (x - (48 - w / 2)) / max(w, 1)
            c.put(x, y, bark[4 if u < 0.15 else 3 if u < 0.35 else 2 if u < 0.7 else 1])
    trunk(c, 48, 50, FOOT - 17, 10, 6, bark, 6)
    # A tall, narrow crown with moss hanging.
    tones = [C("1e2e20"), C("2c4230"), C("3e5a40"), C("547452"), C("6e8e66")]
    crown(c, [(48, 30, 13, 18, 1), (42, 46, 10, 9, 0), (54, 40, 10, 10, 0), (48, 18, 9, 10, 0), (48, 56, 12, 7, 0)], tones, 66)
    r = random.Random(6)
    for _ in range(10):
        x, y = r.randint(38, 58), r.randint(48, 62)
        for k in range(r.randint(4, 9)):
            c.put(x, y + k, C("8a9a6a") if k % 3 else C("6a7a4a"))
    return finish(c)


def fir(snowy=False):
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 22, 4)
    roots(c, 48, FOOT, 8, OAK_BARK, 7, count=3, reach=7)
    trunk(c, 48, 30, FOOT, 7, 3, OAK_BARK, 7)
    tiers = 7
    for k in range(tiers):
        y = 30 + k * 12
        half = 8 + k * 3.4
        # A drooping tier of boughs: lit along the top, a dark underside,
        # needle tips catching light, snow along the upper face.
        for x in range(int(48 - half), int(48 + half) + 1):
            u = (x - 48) / half
            droop = int(abs(u) ** 1.6 * 6)
            top_y = y - 6 + droop - int((1 - abs(u)) * 3)
            # A ragged hem: boughs hang in points of different lengths.
            hem = y + 6 + droop // 2 + int(hash2(x // 2, k, 7) * 4) - (1 if x % 3 == 0 else 0)
            for yy in range(top_y, hem):
                t = (yy - top_y) / max(hem - top_y, 1)
                tone = 3 if t < 0.25 and u < 0.3 else 2 if t < 0.55 else 1 if t < 0.85 else 0
                if u > 0.5 and tone > 1:
                    tone -= 1
                # Needle texture: short dark strokes slanting down.
                if 0.2 < t < 0.85 and (x + yy * 2) % 5 == 0:
                    tone = max(tone - 1, 0)
                c.put(x, yy, PINE[tone])
            if snowy and abs(u) < 0.92:
                c.put(x, top_y, SNOW[4] if u < 0.2 else SNOW[2])
                if hash2(x, k, 9) < 0.5:
                    c.put(x, top_y + 1, SNOW[1])
        # Needle tips.
        for x in range(int(48 - half), int(48 + half) + 1, 3):
            c.put(x, y + 1, PINE[4] if x < 48 else PINE[3])
    # The leader at the very top.
    for k in range(6):
        c.put(48, 20 + k, PINE[2])
        c.put(47, 22 + k, PINE[3])
    if snowy:
        c.put(48, 20, SNOW[4])
    return finish(c)


def mountain_pine():
    c = Canvas(W, H)
    shadow(c, 46, FOOT, 22, 4)
    roots(c, 46, FOOT, 9, OAK_BARK, 8, count=5, reach=12)
    # A crooked trunk leaning with the wind, and flat clouds of needles.
    trunk(c, 46, 84, FOOT, 9, 7, OAK_BARK, 8, lean=0.12)
    trunk(c, 50, 58, 86, 7, 5, OAK_BARK, 9, lean=0.18)
    bough(c, 49, 80, 66, 66, 3, 2, OAK_BARK)
    bough(c, 46, 64, 24, 54, 3, 2, OAK_BARK)
    for (cx, cy, rx, ry) in ((66, 62, 16, 5), (24, 50, 14, 5), (46, 50, 15, 5), (40, 38, 12, 5), (52, 66, 10, 4)):
        cluster(c, cx, cy, rx, ry, PINE, cx * 7 + cy)
    return finish(c)


def palm():
    c = Canvas(W, H)
    shadow(c, 50, FOOT, 18, 4)
    # A curved trunk in rings.
    pts = []
    for s in range(0, 81):
        t = s / 80
        x = 50 - 14 * math.sin(t * 1.4)
        y = FOOT - s
        pts.append((x, y))
        w = 7 - 3 * t
        for d in range(int(-w / 2), int(w / 2) + 1):
            u = (d + w / 2) / max(w, 1)
            tone = 4 if u < 0.2 else 3 if u < 0.45 else 2 if u < 0.75 else 1
            if s % 5 == 0:
                tone = max(tone - 2, 0)
            c.put(x + d, y, PALM_BARK[tone])
    tx, ty = pts[-1]
    # Fronds arching out from the top.
    fronds = [C("1e3a1c"), C("2e5a28"), C("447a34"), C("5e9a44"), C("8ac060")]
    for k, ang in enumerate((-2.9, -2.4, -1.9, -1.3, -0.8, -0.25, 0.3)):
        length = 26 + (k % 3) * 4
        for s in range(length):
            t = s / length
            a = ang + t * (0.9 if ang > -1.57 else -0.9) * 0.6
            x = tx + math.cos(a) * s
            y = ty + math.sin(a) * s * 0.8 + t * t * 14
            c.put(x, y, fronds[3 if t < 0.5 else 2])
            # Leaflets hanging off the rib.
            if s % 2 == 0 and t > 0.1:
                for d in range(1, int(4 * (1 - t)) + 2):
                    c.put(x + (1 if ang > -1.57 else -1) * (d // 3), y + d, fronds[2 if d < 2 else 1])
    fruit(c, [(tx - 3, ty + 2), (tx + 1, ty + 3), (tx - 1, ty + 5)], C("6a4220"), C("a87040"))
    return finish(c)


def bloodwood():
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 26, 4)
    roots(c, 48, FOOT, 12, DARK_BARK, 10, count=5, reach=13)
    trunk(c, 48, 60, FOOT, 12, 8, DARK_BARK, 10, lean=0.03)
    bough(c, 46, 72, 30, 56, 4, 2, DARK_BARK)
    bough(c, 50, 70, 66, 54, 4, 2, DARK_BARK)
    crown(c, [(30, 52, 14, 10, 1), (66, 50, 14, 10, 1), (48, 38, 19, 13, 0), (34, 42, 11, 9, 0), (62, 40, 11, 9, 0),
              (48, 54, 13, 8, 0)], CRIMSON, 77)
    # Red tendrils hanging from the crown.
    r = random.Random(10)
    for _ in range(12):
        x = r.randint(24, 72)
        top = 54 + r.randint(0, 6)
        for k in range(r.randint(6, 16)):
            c.put(x + (k // 5) % 2, top + k, CRIMSON[2] if k % 4 else CRIMSON[3])
    return finish(c)


def thornwood():
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 22, 4)
    roots(c, 48, FOOT, 10, DARK_BARK, 11, count=5, reach=12)
    # A trunk twisted from several strands, with thorns.
    for k, lean in enumerate((-0.08, 0.06, -0.02)):
        trunk(c, 46 + k * 2, 52, FOOT, 5, 3, DARK_BARK, 11 + k, lean=lean)
    bough(c, 44, 60, 26, 44, 3, 1, DARK_BARK)
    bough(c, 52, 58, 72, 42, 3, 1, DARK_BARK)
    bough(c, 48, 54, 46, 32, 3, 1, DARK_BARK)
    r = random.Random(11)
    for _ in range(26):
        x, y = r.randint(26, 72), r.randint(36, FOOT - 6)
        if (x, y) in c.filled:
            c.put(x + r.choice((-1, 1)), y - 1, C("c8c0a8"))
    crown(c, [(28, 42, 9, 6, 1), (70, 40, 9, 6, 1), (46, 30, 11, 7, 0), (36, 36, 7, 5, 0), (58, 34, 7, 5, 0)], THORN, 88)
    fruit(c, [(32, 40), (64, 38), (46, 26), (52, 34)], C("8a1c2a"), C("d04858"))
    return finish(c)


def spore_tree():
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 20, 4)
    stalk = [C("4a3a4e"), C("6a5670"), C("8e7a92"), C("b0a0b0"), C("cec2cc")]
    trunk(c, 48, 34, FOOT, 10, 6, stalk, 12, fissures=False, rings=True)
    # Shelf caps stacked up the stalk, each with glowing spots.
    for k, (y, half) in enumerate(((84, 18), (64, 22), (44, 26), (26, 18))):
        for x in range(48 - half, 48 + half + 1):
            u = (x - 48) / half
            h = int(6 * (1 - u * u)) + 2
            for yy in range(y - h, y + 2):
                t = (yy - (y - h)) / max(h + 2, 1)
                tone = 4 if t < 0.2 and u < 0.1 else 3 if t < 0.5 else 2 if t < 0.8 else 1
                c.put(x, yy, SPORE[tone])
            c.put(x, y + 2, SPORE[0])
            if hash2(x, k, 12) < 0.12:
                c.put(x, y - h + 2, C("f0b8f8"))
        for x in range(48 - half + 3, 48 + half - 2, 4):
            c.put(x, y + 3, SPORE[1])
    return finish(c)


def ash_husk():
    c = Canvas(W, H)
    shadow(c, 48, FOOT, 22, 4)
    char = [C("100c0c"), C("1e1818"), C("2e2626"), C("403636"), C("564a48")]
    roots(c, 48, FOOT, 12, char, 13, count=5, reach=12)
    trunk(c, 48, 40, FOOT, 12, 6, char, 13)
    bough(c, 46, 62, 26, 40, 4, 1, char)
    bough(c, 50, 56, 70, 34, 4, 1, char)
    bough(c, 48, 50, 54, 26, 3, 1, char)
    bough(c, 34, 50, 28, 30, 2, 1, char)
    # Embers still glowing in the cracks.
    r = random.Random(13)
    for _ in range(10):
        x, y = 48 + r.randint(-4, 4), r.randint(50, FOOT - 6)
        for k in range(r.randint(2, 5)):
            c.put(x, y + k, C("e86a20") if k % 2 else C("ffb050"))
    return finish(c)


def fallen_log():
    """A felled trunk lying on the ground (shown when a tree comes down)."""
    c = Canvas(W, H)
    shadow(c, 48, FOOT + 1, 34, 4)
    for x in range(14, 82):
        for y in range(FOOT - 9, FOOT + 1):
            t = (y - (FOOT - 9)) / 9
            tone = 4 if t < 0.15 else 3 if t < 0.4 else 2 if t < 0.75 else 1
            if hash2(x // 3, y, 14) < 0.12:
                tone = max(0, tone - 2)
            c.put(x, y, OAK_BARK[tone])
    # The cut end, showing rings.
    for y in range(FOOT - 9, FOOT + 1):
        for x in range(10, 15):
            d = math.hypot(x - 12, y - (FOOT - 4.5))
            c.put(x, y, C("d8b080") if int(d) % 2 == 0 else C("b08858"))
    return finish(c)


TREES = [great_oak(), birch(), apple(), beech(), great_willow(), cypress(), fir(False), fir(True), mountain_pine(),
         palm(), bloodwood(), thornwood(), spore_tree(), ash_husk(), fallen_log()]


def grand_sway(i):
    """How each grand tree sways (tools/sway.py): the fallen log lies still,
    the spore tree's stiff stalk barely moves, the rest lean two pixels at
    the top of the crown."""
    if i == len(TREES) - 1:
        return "still", 0
    if i == 12:
        return "tree", 1
    return "tree", 2


def main():
    import sway
    sway.stacked(TREES, W, H, grand_sway).save(os.path.join(ROOT, "flora_grand.png"))


if __name__ == "__main__":
    main()
