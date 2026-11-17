#!/usr/bin/env python3
"""Draws trees, bushes, flowers, herbs, critters, and village and ruin props.

Run from the project folder:  python3 tools/generate_flora.py
Writes assets/sprites/flora_tall.png (64x96 cells), flora_small.png
(32x32 cells), critters.png (24x24 cells, 2 frames each), and decor.png
(64x64 cells). The cell order is the order of the lists below, which the
game refers to by index - only ever append.
"""
import math
import os
import random
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
OUTLINE = (12, 10, 16, 255)


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def ramp(light, mid, dark):
    return [C(light), C(mid), C(dark)]


class Canvas:
    """A small pixel canvas that remembers which pixels are filled, so it can
    be outlined afterwards, and shades shapes from a top-left light."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.filled = set()

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), c)
            self.filled.add((x, y))

    def mask(self, shape, coords, width=1):
        m = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(m)
        if shape == "ellipse":
            d.ellipse(coords, fill=255)
        elif shape == "rect":
            d.rectangle(coords, fill=255)
        elif shape == "poly":
            d.polygon(coords, fill=255, outline=255)
        elif shape == "line":
            d.line(coords, fill=255, width=width)
        return [(x, y) for y in range(self.h) for x in range(self.w) if m.getpixel((x, y))]

    def shade(self, shape, coords, colours, width=1, light=(-0.6, -0.8), dither=True):
        """Fills a shape, light on the side facing `light`, dark opposite."""
        pts = self.mask(shape, coords, width)
        if not pts:
            return pts
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        rx, ry = max((max(xs) - min(xs)) / 2, 1), max((max(ys) - min(ys)) / 2, 1)
        for x, y in pts:
            t = ((x - cx) / rx * light[0] + (y - cy) / ry * light[1])
            # t > 0.35 faces the light; < -0.35 is in shade.
            if dither and abs(t - 0.35) < 0.08:
                t += 0.1 if (x + y) % 2 else -0.1
            if dither and abs(t + 0.35) < 0.08:
                t += 0.1 if (x + y) % 2 else -0.1
            self.put(x, y, colours[0] if t > 0.35 else colours[2] if t < -0.35 else colours[1])
        return pts

    def fill(self, shape, coords, colour, width=1):
        for x, y in self.mask(shape, coords, width):
            self.put(x, y, colour)

    def outline(self, colour=OUTLINE):
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if (x, y) in self.filled:
                    continue
                if any((x + dx, y + dy) in self.filled for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    add.append((x, y))
        for x, y in add:
            self.img.putpixel((x, y), colour)

    def shadow(self, cx, cy, rx, ry, alpha=80):
        d = ImageDraw.Draw(self.img)
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(0, 0, 0, alpha))


BARK = ramp("7a5a40", "5a4030", "3a2a20")
DARK_BARK = ramp("4a3a34", "33282a", "201a1c")


def trunk(c, x, top, bottom, width, colours=BARK, roots=True):
    c.shade("poly", [(x - width / 2, bottom), (x - width / 2 + 1, top), (x + width / 2 - 1, top), (x + width / 2, bottom)], colours)
    if roots:
        c.shade("poly", [(x - width / 2 - 4, bottom), (x - width / 2, bottom - 5), (x - width / 2 + 2, bottom)], colours)
        c.shade("poly", [(x + width / 2 + 4, bottom), (x + width / 2, bottom - 5), (x + width / 2 - 2, bottom)], colours)
    # A few lines of bark.
    for k in range(3):
        yy = top + (bottom - top) * (k + 1) / 4
        c.put(x - 1 + k % 2, yy, colours[2])
        c.put(x - 1 + k % 2, yy + 1, colours[2])


def canopy(c, blobs, colours, seed, highlights=True):
    """A canopy built of overlapping leaf clumps, then leaf texture."""
    r = random.Random(seed)
    pts = []
    for (cx, cy, rx, ry) in blobs:
        pts += c.shade("ellipse", (cx - rx, cy - ry, cx + rx, cy + ry), colours)
    if highlights:
        for _ in range(len(pts) // 14):
            x, y = r.choice(pts)
            c.put(x, y, colours[0] if r.random() < 0.6 else colours[2])
            c.put(x + 1, y, colours[0] if r.random() < 0.6 else colours[2])


# ----------------------------------------------------------------- tall
def oak(seed=1, wide=1.0, lift=0, leaves=None, deep=None, tips="9aca6a", petals=None):
    """A broadleaf: a crown of leaf clumps over a dark inner mass, branches
    showing in the gaps. `wide` stretches the crown, `lift` raises it on a
    taller trunk, so a wood is not one tree repeated."""
    c = Canvas(64, 96)
    r = random.Random(seed)
    sx = lambda x: 32 + (x - 32) * wide
    c.shadow(32, 90, int(21 * wide), 5)
    trunk(c, 32, 50 - lift, 90, 9)
    # Branches reaching into the crown, seen through gaps.
    for (a, b) in [((32, 58), (18, 44)), ((32, 54), (46, 42)), ((32, 50), (30, 30)), ((32, 46), (40, 28))]:
        c.shade("line", (sx(a[0]), a[1] - lift, sx(b[0]), b[1] - lift), BARK, width=3 if a[1] > 50 else 2, dither=False)
    leaves = leaves or ramp("6a9a4a", "4a7a3a", "2f5a2a")
    deep = deep or ramp("3f6a34", "2f5a2a", "1f3e1e")
    # A dark inner mass first, then lit clumps over it, for depth.
    canopy(c, [(32, 40 - lift, int(22 * wide), 16), (sx(20), 46 - lift, 11, 9), (sx(44), 46 - lift, 11, 9)], deep, seed, highlights=False)
    jitter = lambda v: v + r.randint(-2, 2)
    clumps = [(jitter(sx(30)), 36 - lift, int(18 * wide), 13), (jitter(sx(17)), 44 - lift, 10, 8), (jitter(sx(47)), 44 - lift, 10, 8),
              (jitter(sx(23)), 25 - lift, 12, 10), (jitter(sx(41)), 25 - lift, 12, 10), (jitter(32), 16 - lift, 11, 9)]
    # Leave a gap or two between clumps so branches show: drop one side clump.
    if r.random() < 0.5:
        clumps.pop(1 if r.random() < 0.5 else 2)
    canopy(c, clumps, leaves, seed)
    # Sunlit leaf tips along the top-left of each clump.
    for (cx, cy, rr, _ry) in clumps:
        for k in range(6):
            a = math.pi * (1.1 + 0.08 * k)
            c.put(cx + math.cos(a) * (rr - 2), cy + math.sin(a) * (rr * 0.8 - 2), C(tips))
        # A shadowed underside to each clump separates it from the next.
        for k in range(-rr + 3, rr - 2, 2):
            if (cx + k, cy + int(rr * 0.75)) in c.filled:
                c.put(cx + k, cy + int(rr * 0.75), deep[2])
    for x in (16, 27, 44, 49):
        c.put(sx(x), 54 - lift + r.randint(0, 2), leaves[1])
    if petals:
        # Blossom: pale petals scattered over the crown and a few fallen.
        for _ in range(26):
            px, py = r.randint(10, 54), r.randint(6, 52) - lift
            if (int(px), int(py)) in c.filled:
                c.put(px, py, C(petals))
        for _ in range(8):
            c.put(r.randint(14, 50), r.randint(84, 92), C(petals))
    c.outline()
    return c.img


def _bough(c, x0, y0, x1, y1, w0, colours):
    """A branch that tapers from w0 pixels at its base to a point, bending
    a little halfway so it doesn't look ruled."""
    mx, my = (x0 + x1) / 2 + (y1 - y0) * 0.08, (y0 + y1) / 2 - abs(x1 - x0) * 0.08
    for (ax, ay, bx, by, wa, wb) in ((x0, y0, mx, my, w0, max(1.0, w0 * 0.6)), (mx, my, x1, y1, max(1.0, w0 * 0.6), 0.6)):
        dx, dy = bx - ax, by - ay
        length = max(math.hypot(dx, dy), 0.01)
        nx, ny = -dy / length, dx / length
        c.shade("poly", [(ax + nx * wa / 2, ay + ny * wa / 2), (bx + nx * wb / 2, by + ny * wb / 2),
                         (bx - nx * wb / 2, by - ny * wb / 2), (ax - nx * wa / 2, ay - ny * wa / 2)], colours)


def dead_tree():
    """A dead tree: a cracked grey trunk splitting into tapering limbs that
    fork again into twigs, with a knot hole and a broken stub."""
    c = Canvas(64, 96)
    grey = ramp("9a8a78", "6a5a4a", "463c32")
    c.shadow(32, 90, 14, 4)
    trunk(c, 32, 34, 90, 8, grey)
    limbs = [((31, 56), (13, 36), 4.0), ((33, 48), (51, 28), 4.0), ((32, 38), (27, 14), 3.0), ((33, 36), (41, 10), 3.0)]
    twigs = [((13, 36), (7, 24), 2.0), ((13, 36), (5, 38), 1.6), ((51, 28), (57, 16), 2.0), ((51, 28), (59, 32), 1.6),
             ((27, 14), (22, 5), 1.6), ((41, 10), (47, 3), 1.6), ((22, 45), (19, 39), 1.4), ((44, 37), (48, 33), 1.4)]
    for (a, b, w) in limbs + twigs:
        _bough(c, a[0], a[1], b[0], b[1], w, grey)
    # A knot hole and a snapped stub.
    c.fill("ellipse", (33, 62, 35, 65), C("2a221c"))
    c.shade("poly", [(29, 70), (24, 67), (24, 69), (29, 72)], grey)
    for y in range(40, 88, 7):
        c.put(31 + (y // 7) % 3, y, C("3a3028"))
        c.put(31 + (y // 7) % 3, y + 1, C("3a3028"))
    c.outline()
    return c.img


def pine(snowy, seed=2, tiers=5, wide=1.0):
    """A conifer of rounded, drooping boughs: each tier a row of needle
    clumps over a dark inner mass, wider tiers lower down, a shaded band
    under each, needle strokes lit from the left, and (snowy) snow lying
    along the tops of the clumps."""
    c = Canvas(64, 96)
    r = random.Random(seed)
    c.shadow(32, 90, int(16 * wide), 4)
    trunk(c, 32, 30, 90, 5, roots=False)
    greens = ramp("4f806e", "325e52", "20423a")
    deep = ramp("2a4c42", "1e3a32", "142a24")
    lit = C("74a690")
    top_y, bottom_y = 6 if tiers > 5 else 10, 80
    span = (bottom_y - top_y) / tiers
    tops = []
    for k in range(tiers - 1, -1, -1):
        cy = top_y + (k + 0.62) * span
        half = min((3.0 + (k + 1) * 21.0 / tiers) * wide, 27.0)
        # Fewer tiers overlap more, so a squat tree doesn't fall apart.
        h = span * (1.05 + max(0, 5 - tiers) * 0.2)
        # The inner mass of the tier: a fan wider at the bottom.
        c.shade("poly", [(32, cy - h * 0.55), (32 + half * 0.8, cy + h * 0.38), (32, cy + h * 0.5), (32 - half * 0.8, cy + h * 0.38)], deep)
        clumps = max(2, int(round(half / 4.0)))
        for i in range(clumps):
            t = (i + 0.5) / clumps
            x = 32 - half + 2 * half * t + r.uniform(-0.8, 0.8)
            out = abs(x - 32) / max(half, 1)
            # Clumps droop and thin toward the tips of the boughs.
            rx = half / clumps + 2.0 - out * 0.8
            ry = h * (0.3 - out * 0.06)
            y = cy - 1 + (out ** 1.6) * 6.5 + r.uniform(-0.5, 0.5)
            pts = c.shade("ellipse", (x - rx, y - ry, x + rx, y + ry), greens)
            tops.append((x, y - ry, rx))
            # Needle strokes: lit on the left of each clump, dark on the right.
            for _ in range(int(rx * 2)):
                px, py = r.choice(pts)
                if px < x:
                    c.put(px, py, lit)
                    c.put(px + 1, py + 1, greens[0])
                else:
                    c.put(px, py, greens[2])
        # A shadowed band under the tier, where the next tier tucks in.
        for x in range(int(32 - half * 0.8), int(32 + half * 0.8)):
            yy = int(cy + h * 0.46)
            if (x, yy) in c.filled and (x * 3 + k) % 4 != 0:
                c.put(x, yy, deep[2])
    # The leading shoot at the very top.
    c.shade("poly", [(32, top_y - 7), (34, top_y + 1), (33.5, top_y + 5), (30.5, top_y + 5), (30, top_y + 1)], greens)
    c.put(31, top_y - 3, lit)
    if snowy:
        snow, shade = C("f2f6fa"), C("cdd8e4")
        for (x, y, rx) in tops:
            for dx in range(int(-rx + 1), int(rx)):
                yy = int(y + 1 + (dx * dx) / max(rx * rx, 1) * 2.5)
                if (int(x + dx), yy) in c.filled:
                    c.put(x + dx, yy, snow)
                    if (int(x + dx), yy + 1) in c.filled and (dx % 3) == 0:
                        c.put(x + dx, yy + 1, shade)
        c.put(32, top_y - 6, C("ffffff"))
    c.outline()
    return c.img


def thorn_tree(seed=3):
    c = Canvas(64, 96)
    c.shadow(32, 90, 16, 4)
    c.shade("poly", [(28, 90), (30, 60), (24, 44), (30, 40), (34, 58), (36, 40), (40, 44), (36, 62), (38, 90)], DARK_BARK)
    canopy(c, [(22, 38, 13, 10), (42, 36, 13, 10), (32, 26, 14, 11)], ramp("7a6a3a", "5a4a2a", "3a301c"), seed)
    r = random.Random(seed)
    for _ in range(26):
        x, y = r.randrange(10, 54), r.randrange(16, 48)
        if (x, y) in c.filled:
            c.put(x, y - 1, C("c8b890"))
    for _ in range(9):
        x, y = r.randrange(12, 52), r.randrange(18, 46)
        if (x, y) in c.filled:
            c.fill("ellipse", (x, y, x + 2, y + 2), C("b02a3a"))
    c.outline()
    return c.img


def crimson_tree(seed=4):
    c = Canvas(64, 96)
    c.shadow(32, 90, 18, 5)
    trunk(c, 32, 50, 90, 8, DARK_BARK)
    canopy(c, [(32, 36, 22, 16), (20, 42, 11, 10), (44, 42, 11, 10), (32, 22, 14, 11)], ramp("c05a6a", "8e2c44", "5c1830"), seed)
    # Hanging fronds.
    r = random.Random(seed)
    for _ in range(8):
        x = r.randrange(14, 50)
        y = 46 + r.randrange(0, 6)
        for k in range(r.randrange(5, 11)):
            c.put(x, y + k, C("8e2c44") if k % 3 else C("c05a6a"))
    c.outline()
    return c.img


def giant_mushroom(seed=5):
    c = Canvas(64, 96)
    c.shadow(32, 90, 16, 4)
    c.shade("poly", [(26, 90), (28, 44), (36, 44), (38, 90)], ramp("e8e0c8", "c8bca0", "9a8e74"))
    c.shade("ellipse", (8, 22, 56, 54), ramp("d070a0", "a04878", "6c2c52"))
    c.fill("rect", (10, 44, 54, 48), C("4a2038"))
    for (x, y, w) in [(18, 30, 6), (34, 28, 7), (44, 36, 5), (26, 40, 4), (14, 40, 3)]:
        c.fill("ellipse", (x, y, x + w, y + w - 1), C("f0d0e8"))
    c.outline()
    return c.img


def bone_spire():
    c = Canvas(64, 96)
    c.shadow(32, 90, 16, 4)
    bone = ramp("f2efe2", "cfcbb8", "9b9889")
    c.shade("poly", [(16, 90), (20, 40), (14, 18), (22, 34), (26, 90)], bone)
    c.shade("poly", [(36, 90), (42, 30), (50, 10), (48, 34), (46, 90)], bone)
    for y in range(52, 86, 8):
        c.shade("rect", (24, y, 40, y + 2), bone, dither=False)
    c.outline()
    return c.img


def charred_tree():
    c = Canvas(64, 96)
    c.shadow(32, 90, 14, 4)
    char = ramp("4a4040", "2e2828", "1a1616")
    trunk(c, 32, 26, 90, 9, char)
    for (a, b, w) in [((32, 46), (16, 30), 3), ((32, 38), (48, 22), 3), ((16, 30), (12, 18), 2), ((48, 22), (52, 12), 2)]:
        c.shade("line", (a[0], a[1], b[0], b[1]), char, width=w, dither=False)
    for (x, y) in [(31, 50), (33, 62), (31, 74), (32, 82), (20, 32), (44, 26)]:
        c.put(x, y, C("f08a2e"))
        c.put(x, y + 1, C("ffd86b"))
    c.outline()
    return c.img


def void_crystal():
    c = Canvas(64, 96)
    c.shadow(32, 90, 16, 4, 60)
    purple = ramp("e0c0ff", "9a6cf0", "5c3690")
    for (x, top, w) in [(32, 20, 9), (20, 46, 7), (44, 40, 7), (26, 60, 5), (40, 62, 5)]:
        c.shade("poly", [(x, top), (x + w, top + 12), (x + w, 88), (x - w, 88), (x - w, top + 12)], purple)
        c.put(x, top + 4, C("ffffff"))
    c.outline()
    return c.img


def salt_pillar():
    c = Canvas(64, 96)
    c.shadow(32, 90, 14, 4)
    salt = ramp("f4f2ec", "d4d0c4", "a8a498")
    c.shade("poly", [(22, 90), (24, 40), (30, 22), (34, 36), (40, 30), (42, 90)], salt)
    c.shade("poly", [(40, 90), (44, 60), (50, 54), (52, 90)], salt)
    c.outline()
    return c.img


def willow(seed=6):
    c = Canvas(64, 96)
    c.shadow(32, 90, 20, 5)
    trunk(c, 32, 46, 90, 9, DARK_BARK)
    green = ramp("7a9a5a", "56784a", "3a5434")
    canopy(c, [(32, 30, 22, 14), (32, 18, 14, 10)], green, seed)
    r = random.Random(seed)
    for x in range(12, 54, 2):
        length = r.randrange(16, 36)
        for k in range(length):
            if (x, 34 + k) not in c.filled:
                c.put(x + (1 if k > length // 2 and x % 4 == 0 else 0), 34 + k, green[1] if k % 4 else green[2])
    c.outline()
    return c.img


def cactus():
    c = Canvas(64, 96)
    c.shadow(32, 90, 12, 4)
    green = ramp("8aaa5a", "6a8a44", "4a6430")
    c.shade("rect", (27, 30, 37, 90), green)
    c.shade("rect", (14, 50, 21, 66), green)
    c.shade("rect", (14, 62, 28, 67), green)
    c.shade("rect", (43, 40, 50, 58), green)
    c.shade("rect", (36, 54, 50, 59), green)
    c.fill("ellipse", (29, 26, 35, 32), C("e05a6a"))
    c.outline()
    return c.img


def big_bush(colours, berries=None, snow=False, seed=7):
    """Bushes sit low in the tall sheet so they sort with the trees."""
    c = Canvas(64, 96)
    c.shadow(32, 90, 18, 4)
    canopy(c, [(32, 78, 18, 11), (20, 82, 10, 8), (44, 82, 10, 8), (32, 70, 11, 8)], colours, seed)
    r = random.Random(seed)
    if berries:
        for _ in range(10):
            x, y = r.randrange(16, 48), r.randrange(66, 88)
            if (x, y) in c.filled:
                c.fill("ellipse", (x, y, x + 2, y + 2), berries)
    if snow:
        for x in range(16, 48):
            for y in range(60, 80):
                if (x, y) in c.filled and (x, y - 1) not in c.filled:
                    c.put(x, y, C("eef2f6"))
                    c.put(x, y + 1, C("eef2f6"))
                    break
    c.outline()
    return c.img


TALL = [
    oak(1), oak(11), dead_tree(), pine(False), pine(True), thorn_tree(), crimson_tree(), giant_mushroom(),
    bone_spire(), charred_tree(), void_crystal(), salt_pillar(), willow(), cactus(),
    big_bush(ramp("6a9a4a", "4a7a3a", "2f5a2a")),                                 # 14 green bush
    big_bush(ramp("6a9a4a", "4a7a3a", "2f5a2a"), C("c0303a"), seed=9),            # 15 berry bush
    big_bush(ramp("5a7c78", "3d5a58", "2a4040"), snow=True, seed=10),              # 16 snowy bush
    big_bush(ramp("7a6a3a", "5a4a2a", "3a301c"), C("e8d8a0"), seed=12),           # 17 thorn bush
    big_bush(ramp("a89a6a", "8a7a50", "64583a"), seed=13),                         # 18 dry shrub
    big_bush(ramp("c070a0", "a04878", "6c2c52"), C("f0d0e8"), seed=14),           # 19 fungal bush
    oak(21, wide=1.18, lift=-4),                                                  # 20 broad oak, short trunk
    oak(22, wide=0.86, lift=8),                                                   # 21 tall narrow oak
    pine(False, seed=23, tiers=6, wide=0.82),                                     # 22 slender pine
    pine(True, seed=24, tiers=6, wide=0.86),                                      # 23 slender snowy pine
    pine(False, seed=25, tiers=4, wide=1.12),                                     # 24 squat pine
    oak(31, wide=1.05, leaves=ramp("e8983a", "c06a2a", "8a4420"), deep=ramp("8a4a20", "6a361a", "4a2412"), tips="f8c868"),       # 25 autumn oak
    oak(32, wide=1.1, lift=-2, leaves=ramp("f4b4cc", "e084aa", "b0587a"), deep=ramp("a04870", "80385a", "5a2440"), tips="fff0f6",
        petals="fff4f8"),                                                                                                          # 26 cherry blossom
    oak(33, wide=0.95, lift=4, leaves=ramp("dc4a4c", "b02a34", "7a1a24"), deep=ramp("7a2228", "5a161e", "3c0e14"), tips="ff9a88"),  # 27 red maple
]


# ----------------------------------------------------------------- small
STEM = ramp("7aaa58", "4a7a3a", "2f5a2a")


def _outline_tinted(c, base=(18, 26, 16)):
    """Outline in a dark shade of the plant instead of black, so small
    plants read as soft shapes."""
    c.outline(C("%02x%02x%02x" % base))


def _leaves(c, x, y, r, count=4, colours=STEM, seed=0):
    """A rosette of pointed leaves at a plant's foot."""
    rnd = random.Random(seed)
    for k in range(count):
        a = math.pi + (k + 0.5) * math.pi / count + rnd.uniform(-0.2, 0.2)
        tip = (x + math.cos(a) * r, y + math.sin(a) * r * 0.7)
        side = (-math.sin(a) * 1.8, math.cos(a) * 1.8)
        c.shade("poly", [(x, y), (x + (tip[0] - x) * 0.5 + side[0], y + (tip[1] - y) * 0.5 + side[1]), tip,
                         (x + (tip[0] - x) * 0.5 - side[0], y + (tip[1] - y) * 0.5 - side[1])], colours)
        c.put((x + tip[0]) / 2, (y + tip[1]) / 2, colours[0])


def _stem(c, x0, y0, x1, y1, colours=STEM):
    c.fill("line", (x0, y0, x1, y1), colours[1], 1)
    c.put(x1, y1 + 1, colours[0])


def _bloom(c, kind, x, y, size, petals, centre):
    """One flower head of a kind, centred at x, y."""
    if kind in ("daisy", "aster"):
        n = 8 if kind == "daisy" else 10
        for a in range(n):
            ang = a * 2 * math.pi / n
            px, py = x + math.cos(ang) * size, y + math.sin(ang) * size * 0.85
            c.fill("ellipse", (px - 1.3, py - 1.3, px + 1.3, py + 1.3), petals[0] if math.sin(ang) < 0.3 else petals[1])
        c.shade("ellipse", (x - size * 0.5, y - size * 0.5, x + size * 0.5, y + size * 0.5), [centre, centre, C("8a5a20")])
    elif kind == "tulip":
        c.shade("poly", [(x - size, y - size), (x - size * 0.5, y - size * 0.2), (x, y - size * 1.3), (x + size * 0.5, y - size * 0.2),
                         (x + size, y - size), (x + size * 0.8, y + size * 0.6), (x, y + size * 0.9), (x - size * 0.8, y + size * 0.6)], petals)
        c.put(x - 1, y - 1, petals[0])
    elif kind == "bell":
        c.shade("poly", [(x - size, y + size), (x - size * 0.6, y - size * 0.6), (x, y - size), (x + size * 0.6, y - size * 0.6), (x + size, y + size),
                         (x + size * 0.4, y + size * 0.7), (x, y + size * 1.1), (x - size * 0.4, y + size * 0.7)], petals)
        c.put(x, y + size + 1, centre or petals[2])
    elif kind == "star":
        pts = []
        for k in range(10):
            ang = -math.pi / 2 + k * math.pi / 5
            rr = size * (1.0 if k % 2 == 0 else 0.45)
            pts.append((x + math.cos(ang) * rr, y + math.sin(ang) * rr))
        c.shade("poly", pts, petals)
        c.fill("ellipse", (x - 1.2, y - 1.2, x + 1.2, y + 1.2), centre)
    elif kind == "cup":
        c.shade("ellipse", (x - size, y - size * 0.7, x + size, y + size * 0.8), petals)
        c.fill("ellipse", (x - size * 0.6, y - size * 0.6, x + size * 0.6, y - size * 0.05), C("2a1a1c"))
        c.put(x, y - size * 0.35, centre or petals[0])
    elif kind == "rose":
        c.shade("ellipse", (x - size, y - size, x + size, y + size), petals)
        c.fill("line", (x - size * 0.5, y - size * 0.2, x + size * 0.4, y - size * 0.5), petals[2], 1)
        c.fill("line", (x - size * 0.3, y + size * 0.3, x + size * 0.5, y + size * 0.1), petals[2], 1)
        c.put(x - 1, y - 1, petals[0])
    elif kind == "poppy":
        for ang in (0.4, 2.0, 3.6, 5.2):
            px, py = x + math.cos(ang) * size * 0.6, y + math.sin(ang) * size * 0.5
            c.shade("ellipse", (px - size * 0.75, py - size * 0.7, px + size * 0.75, py + size * 0.7), petals)
        c.fill("ellipse", (x - 1.3, y - 1.3, x + 1.3, y + 1.3), C("1a1418"))
    elif kind == "sun":
        for a in range(12):
            ang = a * 2 * math.pi / 12
            px, py = x + math.cos(ang) * size, y + math.sin(ang) * size
            c.fill("ellipse", (px - 1.6, py - 1.6, px + 1.6, py + 1.6), petals[0] if a % 2 else petals[1])
        c.shade("ellipse", (x - size * 0.6, y - size * 0.6, x + size * 0.6, y + size * 0.6), ramp("8a5a2a", "5a3a1a", "3a2410"))
        c.put(x - 1, y - 1, C("c08a3a"))


def flower(kind, petals, centre=None, seed=0):
    """A clump of flowers: leaves at the foot, two or three stems of
    different heights, each with a shaded head."""
    c = Canvas(32, 32)
    rnd = random.Random(seed * 31 + len(kind))
    centre = centre or petals[0]
    if kind == "spike":
        # Lavender-like spikes: stacked tiny buds up each stem.
        _leaves(c, 16, 30, 7, 5, seed=seed)
        for dx, top in ((-5, 9), (0, 4), (5, 10), (-2, 12), (3, 7)):
            x = 16 + dx
            _stem(c, x, 30, x + dx * 0.2, top)
            for y in range(top, top + 10, 2):
                c.fill("ellipse", (x + dx * 0.2 - 1.4, y - 1, x + dx * 0.2 + 1.4, y + 1), petals[0] if (y // 2) % 2 else petals[1])
            c.put(x + dx * 0.2, top - 1, petals[0])
        _outline_tinted(c)
        return c.img
    if kind == "bell":
        _leaves(c, 14, 30, 6, 4, seed=seed)
        _stem(c, 14, 30, 15, 6)
        c.fill("line", (15, 6, 22, 5), STEM[1], 1)
        for k, (x, y) in enumerate([(22, 9), (18, 12), (22, 16), (17, 19), (20, 23)]):
            c.fill("line", (15, y - 3, x, y - 2), STEM[1], 1)
            _bloom(c, "bell", x, y, 2.3 - k * 0.15, petals, centre)
        _outline_tinted(c)
        return c.img
    _leaves(c, 16, 30, 8, 5, seed=seed)
    heads = [(16 + rnd.uniform(-1, 1), rnd.uniform(8, 10), 4.2), (10 + rnd.uniform(-1, 1), rnd.uniform(14, 16), 3.4), (22 + rnd.uniform(-1, 1), rnd.uniform(16, 18), 3.2)]
    for x, y, size in heads:
        _stem(c, 16 + (x - 16) * 0.3, 30, x, y + size)
        if rnd.random() < 0.7:
            mid = (y + 30) / 2
            c.shade("poly", [(16 + (x - 16) * 0.6, mid), (16 + (x - 16) * 0.6 + (3 if x > 16 else -3), mid - 3), (16 + (x - 16) * 0.6, mid + 1.5)], STEM)
    for x, y, size in heads:
        _bloom(c, kind, x, y, size, petals, centre)
    _outline_tinted(c)
    return c.img


def tufts(colours, tall=False, seed=0):
    c = Canvas(32, 32)
    r = random.Random(seed)
    for _ in range(7 if tall else 5):
        x = r.randrange(6, 26)
        h = r.randrange(10, 22) if tall else r.randrange(5, 11)
        lean = r.choice((-2, -1, 1, 2))
        c.fill("line", (x, 30, x + lean, 30 - h), colours[r.randrange(1, 3)], 1)
        c.put(x + lean, 30 - h, colours[0])
        c.put(x + lean * 0.5, 30 - h * 0.5, colours[0])
    if tall:
        for _ in range(2):
            x = r.randrange(8, 24)
            c.fill("ellipse", (x - 1, 8, x + 1, 13), C("6a4a30"))
            c.put(x, 8, C("8a6a48"))
    _outline_tinted(c, (20, 26, 16))
    return c.img


STEM = ramp("f2efe2", "d8d0bc", "a89e88")


def _glow(c, colour, reach=2, alpha=60):
    """A faint halo around everything drawn so far, for things that shine."""
    halo = []
    for y in range(c.h):
        for x in range(c.w):
            if (x, y) in c.filled or c.img.getpixel((x, y))[3] > 0:
                continue
            near = min((abs(dx) + abs(dy) for dx in range(-reach, reach + 1) for dy in range(-reach, reach + 1)
                        if (x + dx, y + dy) in c.filled), default=99)
            if near <= reach:
                halo.append((x, y, alpha // near))
    for x, y, a in halo:
        c.img.putpixel((x, y), colour[:3] + (a,))


def mushrooms(cap, seed=0, glow=False):
    """A little cluster: one grown cap and two young ones, each with a
    shaded dome, a pale gill rim underneath and a stem that flares at the
    foot."""
    c = Canvas(32, 32)
    r = random.Random(seed)
    spots = C("ffffff") if glow else C("f4eee0")
    sizes = [(r.randrange(13, 17), r.randrange(7, 10), 6), (r.randrange(20, 25), r.randrange(4, 6), 4), (r.randrange(6, 10), r.randrange(3, 5), 3)]
    for x, h, w in sorted(sizes, key=lambda v: v[1]):
        foot = 30
        top = foot - h
        lean = r.choice((-1, 0, 0, 1))
        c.shade("poly", [(x - 1, foot), (x - 1 + lean, top + 1), (x + 1 + lean, top + 1), (x + 2, foot)], STEM)
        c.put(x - 2, foot, STEM[1])
        c.put(x + 3, foot, STEM[2])
        cx = x + lean
        # The cap: a dome, a dark band under its rim, a pale gill line.
        c.shade("ellipse", (cx - w, top - w - 1, cx + w + 1, top + 2), cap)
        for k in range(-w + 1, w + 1):
            c.put(cx + k, top + 1, cap[2])
        for k in range(-w + 2, w):
            c.put(cx + k, top + 2, STEM[1] if k % 3 else STEM[2])
        # Spots, lit on the left of the dome.
        for k in range(max(1, w // 2)):
            sx = cx - w // 2 + k * 3 + r.randrange(0, 2)
            sy = top - w + 1 + r.randrange(1, max(2, w - 1))
            if (sx, sy) in c.filled:
                c.put(sx, sy, spots)
                if w >= 5:
                    c.put(sx + 1, sy, spots)
        c.put(cx - w // 2, top - w + 1, cap[0] if not glow else C("ffffff"))
    c.outline()
    if glow:
        _glow(c, cap[0], 2, 70)
    return c.img


def rocks(colours, seed=0, shards=False, coals=False):
    """Stones, crystals or coals in a little group, biggest at the back.
    Stones are faceted: a lit top face, a dark flank, a crack, perhaps moss.
    Crystals split light and dark down a ridge. Coals glow in their cracks."""
    c = Canvas(32, 32)
    r = random.Random(seed)
    grey = colours[0] == C("a6a2b0")
    pieces = [(r.randrange(12, 18), r.randrange(23, 25), 8, 6), (r.randrange(22, 26), r.randrange(26, 28), 5, 4),
              (r.randrange(5, 9), r.randrange(27, 29), 4, 3)]
    for x, y, w, h in pieces:
        if shards:
            # A crystal: two faces split by a ridge, the lit one on the left.
            tip = (x + r.randint(-1, 1), y - w * 2 + 1)
            c.fill("poly", [(x - w // 2 - 1, y + 1), tip, (x, y + 1)], colours[0])
            c.fill("poly", [(x, y + 1), tip, (x + w // 2 + 1, y + 1)], colours[2])
            c.fill("line", (tip[0], tip[1] + 1, x, y), colours[1])
            c.put(tip[0] - 1, tip[1] + 3, C("ffffff"))
            continue
        # A stone: an irregular many-sided lump.
        pts = []
        for k in range(7):
            a = math.pi * 2 * k / 7 + r.uniform(-0.25, 0.25)
            rad = r.uniform(0.82, 1.08)
            pts.append((x + math.cos(a) * w * rad, y + min(math.sin(a), 0.55) * h * rad))
        c.shade("poly", pts, colours)
        # The lit top face, flatter than the lump.
        c.fill("poly", [(x - w + 2, y - h + 2), (x - 1, y - h), (x + w - 3, y - h + 1), (x + w - 4, y - h + 3), (x - w + 3, y - h + 3)], colours[0])
        if coals:
            for k in range(-w + 2, w - 1, 2):
                c.put(x + k, y + r.randint(-1, 1), C("f08a2e") if k % 4 else C("ffd86b"))
            c.put(x - 1, y - 1, C("ffd86b"))
        else:
            c.fill("line", (x + 1, y - h + 2, x + 2, y + 1), colours[2])
            if grey and r.random() < 0.7:
                for k in range(r.randrange(3, 6)):
                    c.put(x - w + 3 + k, y - h + 1 + (k % 2), C("6a8a3e") if k % 2 else C("8aaa5a"))
    c.outline()
    if coals:
        _glow(c, C("f08a2e"), 1, 50)
    return c.img


def bones():
    """Old bones half sunk in the dirt: a skull turned three-quarters, a
    long bone with knuckled ends, and a curl of rib."""
    c = Canvas(32, 32)
    bone = ramp("f2efe2", "cfcbb8", "8f8b7c")
    # The long bone.
    c.shade("line", (4, 27, 15, 22), bone, width=2, dither=False)
    for ex, ey in ((3, 27), (16, 22)):
        c.shade("ellipse", (ex - 2, ey - 2, ex + 1, ey + 1), bone)
        c.shade("ellipse", (ex - 1, ey - 1, ex + 2, ey + 2), bone)
    # A rib.
    c.shade("line", (8, 30, 11, 29), bone, width=1, dither=False)
    c.shade("line", (11, 29, 13, 27), bone, width=1, dither=False)
    # The skull: a rounded crown, two deep sockets, a nose, teeth.
    c.shade("ellipse", (17, 17, 28, 27), bone)
    c.shade("rect", (19, 26, 26, 29), bone)
    for sx in (19, 23):
        c.fill("rect", (sx, 21, sx + 2, 23), C("1a1612"))
    c.put(22, 25, C("2a2420"))
    for tx in range(20, 26, 2):
        c.put(tx, 28, C("6a6658"))
    c.put(19, 18, C("ffffff"))
    c.fill("line", (24, 18, 26, 20), bone[2])
    c.outline()
    return c.img


def herb(kind):
    """The gatherable plants: bigger and brighter than scenery flowers."""
    c = Canvas(32, 32)
    leaf = ramp("8aca6a", "5a9a4a", "3a6a2a")
    if kind == "healing_herb":
        for (a, b) in [((16, 30), (8, 14)), ((16, 30), (24, 14)), ((16, 30), (16, 10)), ((16, 30), (10, 22)), ((16, 30), (22, 22))]:
            c.shade("poly", [a, (b[0] - 2, b[1] + 3), b, (b[0] + 2, b[1] + 3)], leaf)
        for (x, y) in [(8, 12), (24, 12), (16, 8)]:
            c.fill("ellipse", (x - 2, y - 2, x + 2, y + 2), C("f4f2ec"))
            c.put(x, y, C("f0cf6a"))
    elif kind == "mana_flower":
        c.fill("line", (16, 30, 16, 12), leaf[1], 1)
        c.shade("poly", [(16, 30), (9, 20), (14, 22)], leaf)
        c.shade("poly", [(16, 26), (23, 18), (18, 22)], leaf)
        c.shade("poly", [(10, 6), (16, 16), (22, 6), (19, 3), (16, 7), (13, 3)], ramp("a8d0ff", "5a8af0", "3050b0"))
        c.put(16, 10, C("ffffff"))
    elif kind == "poison_mushroom":
        return mushrooms(ramp("c070e0", "8a3aa8", "56206c"), seed=3)
    elif kind == "rare_root":
        c.shade("poly", [(8, 30), (12, 20), (16, 24), (18, 14), (22, 22), (26, 30)], ramp("c8a070", "9a7448", "6a4a2a"))
        c.shade("poly", [(16, 16), (10, 6), (16, 10), (22, 4), (18, 14)], leaf)
    else:
        return flower("star", ramp("f0f0f0", "c8c8c8", "9a9a9a"), C("f0cf6a"))
    c.outline()
    return c.img


def decal(kind, seed=0):
    """Flat ground detail drawn under everything: cracks, puddles, roots."""
    c = Canvas(32, 32)
    r = random.Random(sum(ord(ch) * (k + 1) for k, ch in enumerate(kind)))
    if kind == "cracks":
        for _ in range(3):
            x, y = r.randrange(4, 26), r.randrange(14, 28)
            pts = [(x, y)]
            for k in range(4):
                x += r.randrange(-3, 5); y += r.randrange(-2, 3)
                pts.append((x, y))
            c.fill("line", pts, C("1a1612", 170), 1)
            for (px, py) in pts[1:3]:
                c.img.putpixel((min(31, px + 1), py), C("6a6050", 120))
    elif kind == "puddle":
        c.fill("ellipse", (4, 20, 28, 29), C("1a2430", 200))
        c.fill("ellipse", (6, 21, 26, 28), C("30485a", 210))
        c.fill("line", (9, 23, 18, 23), C("8ab0c8", 200), 1)
        c.fill("line", (20, 25, 23, 25), C("8ab0c8", 160), 1)
    elif kind == "roots":
        for (a, b) in [((2, 24), (14, 22)), ((14, 22), (22, 26)), ((10, 23), (12, 29)), ((22, 26), (30, 24))]:
            c.fill("line", (a[0], a[1], b[0], b[1]), C("4a3426", 230), 2)
            c.fill("line", (a[0], a[1] - 1, b[0], b[1] - 1), C("6a5038", 200), 1)
    elif kind == "leaves":
        for _ in range(9):
            x, y = r.randrange(3, 28), r.randrange(16, 30)
            col = [C("8a6a2a", 220), C("6a4a1a", 220), C("a07a30", 220), C("5a6a2a", 220)][r.randrange(4)]
            c.fill("ellipse", (x - 2, y - 1, x + 2, y + 1), col)
    elif kind == "stones":
        for _ in range(5):
            x, y, w = r.randrange(4, 26), r.randrange(18, 28), r.randrange(2, 4)
            c.shade("ellipse", (x - w, y - w // 2, x + w, y + w // 2 + 1), ramp("8a8794", "66636f", "45434d"))
    elif kind == "ripples":
        for k in range(3):
            y = 18 + k * 4
            c.fill("line", [(3, y), (10, y - 1), (18, y + 1), (28, y)], C("c8b080", 160), 1)
            c.fill("line", [(3, y + 1), (10, y), (18, y + 2), (28, y + 1)], C("8a7650", 130), 1)
    elif kind == "drift":
        c.fill("ellipse", (2, 20, 30, 30), C("f4f8fc", 220))
        c.fill("ellipse", (6, 19, 22, 26), C("ffffff", 230))
        c.fill("line", (6, 28, 26, 28), C("b8c8d8", 200), 1)
    elif kind == "ash":
        for _ in range(26):
            x, y = r.randrange(2, 30), r.randrange(16, 31)
            c.img.putpixel((x, y), C("2a2828", 150) if r.random() < 0.6 else C("8a8480", 150))
        c.fill("ellipse", (8, 22, 24, 29), C("201e1e", 110))
    elif kind == "moss":
        for _ in range(16):
            x, y = r.randrange(4, 28), r.randrange(18, 30)
            c.fill("ellipse", (x - 2, y - 1, x + 2, y + 1), [C("4a6a30", 210), C("5a7a3a", 210), C("3a5a24", 210)][r.randrange(3)])
    elif kind == "prints":
        for k in range(4):
            x, y = 6 + k * 6, 20 + (k % 2) * 5
            c.fill("ellipse", (x, y, x + 3, y + 4), C("2a2018", 150))
            c.fill("rect", (x, y - 2, x, y - 2), C("2a2018", 150))
            c.fill("rect", (x + 3, y - 2, x + 3, y - 2), C("2a2018", 150))
    return c.img


GREEN = ramp("8aaa5a", "5a8a44", "3a5a2a")
SMALL = [
    flower("daisy", ramp("f4f2ec", "d4d0c4", "a8a498"), C("f0cf6a")),          # 0
    flower("tulip", ramp("f07070", "c0303a", "801820")),                       # 1
    flower("bell", ramp("a8c0ff", "6a88d8", "4058a0")),                        # 2
    flower("spike", ramp("c8a0f0", "9a6cc8", "6a4290")),                       # 3
    flower("star", ramp("ffe08a", "f0b030", "b07a18"), C("c05a2a")),           # 4
    flower("cup", ramp("ff8a5a", "e05a2a", "a03a18")),                         # 5
    tufts(GREEN, seed=1), tufts(GREEN, seed=2), tufts(GREEN, tall=True, seed=3),      # 6 7 8 grass, reeds
    tufts(ramp("c8b878", "a89858", "887840"), seed=4),                         # 9 dry grass
    tufts(ramp("eef2f6", "c8d0d8", "9aa6b4"), seed=5),                         # 10 frosted grass
    mushrooms(ramp("e05a5a", "b0303a", "701820"), seed=6),                     # 11 red caps
    mushrooms(ramp("8ff0ff", "4ab0c8", "2a7088"), seed=7, glow=True),          # 12 glowcaps
    rocks(ramp("a6a2b0", "7c7888", "56525e"), seed=8),                         # 13 pebbles
    rocks(ramp("5a4a48", "3a302e", "221c1c"), seed=9, coals=True),            # 14 embers
    rocks(ramp("e0c0ff", "9a6cf0", "5c3690"), seed=10, shards=True),           # 15 void shards
    rocks(ramp("f4f2ec", "d4d0c4", "a8a498"), seed=11, shards=True),           # 16 salt crystals
    bones(),                                                                    # 17
    tufts(ramp("8a6a3a", "6a4a2a", "4a301c"), seed=12),                        # 18 thorny twigs
    tufts(ramp("c05a6a", "8e2c44", "5c1830"), seed=13),                        # 19 crimson grass
    herb("healing_herb"), herb("mana_flower"), herb("poison_mushroom"), herb("rare_root"),  # 20-23
    flower("star", ramp("d8f4ff", "a8d8f0", "70a8c8"), C("ffffff")),           # 24 frost lily
    flower("bell", ramp("ff8a8a", "c02a3a", "801820")),                        # 25 bloodcap bells
    mushrooms(ramp("8ff0c0", "3ab088", "1a7050"), seed=14, glow=True),         # 26 glowshroom
    flower("spike", ramp("aac87a", "7a9a4a", "4a6a2a")),                       # 27 desert aloe
    flower("cup", ramp("ffd86b", "f08a2e", "b8401e")),                         # 28 emberbloom
    flower("star", ramp("e0c0ff", "9a6cf0", "5c3690"), C("ffffff")),           # 29 void bloom
    flower("tulip", ramp("f4f2ec", "d4d0c4", "a8a498")),                       # 30 saltweed
    flower("daisy", ramp("ffb0d0", "e070a0", "a04070"), C("ffe08a")),          # 31 pink daisy
    flower("rose", ramp("f05a6a", "b0203a", "6a1020")),                        # 32 wild rose
    flower("spike", ramp("c8b0ff", "8a6ae0", "5a42a0")),                       # 33 lavender
    flower("sun", ramp("ffe060", "f0b020", "b07a10")),                         # 34 sunflower
    flower("poppy", ramp("ff6a4a", "e0302a", "a01a18")),                       # 35 poppy
    flower("aster", ramp("b8d0ff", "7a98e0", "4a68b0"), C("ffe08a")),          # 36 blue aster
    flower("bell", ramp("f0e8ff", "c8b8f0", "8a78c0")),                        # 37 snowbell
    flower("rose", ramp("2a2030", "1a1420", "0a080e")),                        # 38 black rose
    flower("cup", ramp("ffb0e0", "e070b8", "a04080"), C("ffe08a")),            # 39 bog lotus
    flower("poppy", ramp("ffe0a0", "f0b860", "b07a30")),                       # 40 desert poppy
    flower("aster", ramp("ff9a5a", "e05a2a", "a03a18"), C("3a1a10")),          # 41 ember aster
    decal("cracks"), decal("puddle"), decal("roots"), decal("leaves"), decal("stones"),   # 42-46
    decal("ripples"), decal("drift"), decal("ash"), decal("moss"), decal("prints"),       # 47-51
]


# ----------------------------------------------------------------- critters
def critter(kind, frame):
    """One 24x24 frame. Frames 0-1 are at rest (1 is a small idle movement),
    frames 2-3 are in motion: a hop, a wingbeat, a leap."""
    c = Canvas(24, 24)
    if kind == "rabbit":
        fur = ramp("d2c2a8", "a8927a", "6e5c4a")
        belly = ramp("f4efe4", "ddd4c4", "b8ac9a")
        inner = C("e8a0a0")
        if frame < 2:
            # Sitting: round haunch, chest, head, long ears; frame 1 twitches an ear.
            c.shade("ellipse", (4, 12, 15, 21), fur)
            c.shade("ellipse", (10, 13, 17, 21), fur)
            c.shade("ellipse", (12, 16, 17, 21), belly)
            c.shade("ellipse", (13, 7, 20, 14), fur)
            lean = 1 if frame == 1 else 0
            c.shade("poly", [(14, 9), (13 - lean, 1), (15 - lean, 0), (16, 8)], fur, dither=False)
            c.shade("poly", [(17, 9), (17 + lean, 1), (19 + lean, 1), (19, 9)], fur, dither=False)
            c.put(14 - lean, 3, inner); c.put(14 - lean, 4, inner); c.put(18 + lean, 3, inner); c.put(18 + lean, 4, inner)
            c.fill("ellipse", (2, 14, 5, 17), C("f8f6f0"))
            c.fill("rect", (13, 20, 17, 21), fur[2]); c.fill("rect", (6, 20, 11, 21), fur[2])
            c.put(18, 10, OUTLINE); c.put(18, 9, C("ffffff")); c.put(20, 11, C("e08080"))
        else:
            # Leaping: stretched body, legs out; frame 3 gathers for landing.
            up = 3 if frame == 2 else 1
            c.shade("ellipse", (3, 11 - up, 16, 18 - up), fur)
            c.shade("ellipse", (12, 8 - up, 20, 14 - up), fur)
            c.shade("poly", [(13, 9 - up), (9, 4 - up), (11, 3 - up), (15, 8 - up)], fur, dither=False)
            c.shade("poly", [(15, 9 - up), (12, 3 - up), (14, 2 - up), (17, 8 - up)], fur, dither=False)
            c.fill("ellipse", (1, 11 - up, 4, 14 - up), C("f8f6f0"))
            if frame == 2:
                c.shade("poly", [(5, 16 - up), (1, 21 - up), (3, 22 - up), (8, 17 - up)], fur, dither=False)
                c.shade("poly", [(14, 15 - up), (19, 19 - up), (20, 18 - up), (16, 14 - up)], fur, dither=False)
            else:
                c.shade("poly", [(6, 16 - up), (7, 21 - up), (10, 21 - up), (9, 16 - up)], fur, dither=False)
                c.shade("poly", [(14, 15 - up), (15, 21 - up), (17, 21 - up), (16, 14 - up)], fur, dither=False)
            c.put(18, 10 - up, OUTLINE); c.put(20, 12 - up, C("e08080"))
    elif kind == "bird":
        body = ramp("8a7a6a", "5e5248", "3c3430")
        breast = ramp("e89060", "c06a40", "8a4428")
        wing = ramp("6a5c50", "463c36", "2c2624")
        beak = C("f0b030")
        if frame < 2:
            # Perched; frame 1 pecks at the ground.
            peck = 3 if frame == 1 else 0
            c.shade("ellipse", (6, 10, 17, 18), body)
            c.shade("ellipse", (10, 12, 17, 18), breast)
            c.shade("poly", [(7, 11), (15, 11), (12, 16), (5, 15)], wing)
            c.shade("poly", [(6, 13), (1, 15), (2, 17), (7, 16)], wing, dither=False)
            c.shade("ellipse", (13, 6 + peck, 19, 12 + peck), body)
            c.put(20, 9 + peck, beak); c.put(21, 9 + peck, beak); c.put(20, 10 + peck, C("b07818"))
            c.put(17, 8 + peck, OUTLINE); c.put(17, 7 + peck, C("ffffff"))
            c.fill("rect", (10, 19, 10, 21), beak); c.fill("rect", (13, 19, 13, 21), beak)
            c.put(11, 21, beak); c.put(14, 21, beak)
        else:
            # Flying: wings up, then down.
            c.shade("ellipse", (6, 10, 17, 16), body)
            c.shade("ellipse", (10, 12, 16, 16), breast)
            c.shade("ellipse", (14, 7, 20, 13), body)
            c.shade("poly", [(6, 12), (1, 11), (2, 14), (7, 15)], wing, dither=False)
            if frame == 2:
                c.shade("poly", [(8, 11), (5, 1), (11, 3), (15, 11)], wing)
                c.fill("rect", (7, 4, 8, 4), wing[0])
            else:
                c.shade("poly", [(8, 12), (4, 21), (11, 19), (15, 13)], wing)
            c.put(21, 10, beak); c.put(22, 10, beak)
            c.put(18, 9, OUTLINE)
    elif kind == "butterfly":
        wing = ramp("ffe08a", "f0a030", "a06018")
        spots = C("fff6d0")
        edge = C("5a3010")
        spread = [8, 6, 3, 6][frame]
        c.fill("rect", (11, 8, 12, 16), OUTLINE)
        c.put(10, 6, OUTLINE); c.put(9, 5, OUTLINE); c.put(13, 6, OUTLINE); c.put(14, 5, OUTLINE)
        for side in (-1, 1):
            x0 = 11 if side < 0 else 12
            c.shade("ellipse", (min(x0, x0 + side * (spread + 2)), 4, max(x0, x0 + side * (spread + 2)), 12), wing)
            c.shade("ellipse", (min(x0, x0 + side * spread), 11, max(x0, x0 + side * spread), 18), wing)
            if spread > 3:
                c.put(x0 + side * (spread - 1), 7, spots); c.put(x0 + side * (spread - 2), 8, spots)
                c.put(x0 + side * (spread - 2), 14, spots)
                c.put(x0 + side * (spread + 1), 6, edge); c.put(x0 + side * (spread + 1), 9, edge)
                c.put(x0 + side * (spread - 1), 16, edge)
    elif kind == "frog":
        skin = ramp("9ad870", "5aa048", "356a2a")
        belly = ramp("e8f0c0", "c8d8a0", "98b070")
        dark = C("2e5a24")
        if frame < 2:
            # Squatting, hind legs folded at the sides; frame 1 swells the throat.
            c.shade("ellipse", (5, 12, 18, 20), skin)
            c.shade("ellipse", (8, 15, 15, 20), belly)
            if frame == 1:
                c.shade("ellipse", (8, 16, 15, 22), belly)
            # Folded hind legs: thigh, shin, and a long splayed foot.
            for side in (-1, 1):
                kx = 5 if side < 0 else 18
                c.shade("ellipse", (kx - 3, 14, kx + 3, 20), skin)
                c.fill("rect", (min(kx, kx + side * 4), 20, max(kx, kx + side * 4), 21), skin[1])
                c.put(kx + side * 5, 21, skin[2]); c.put(kx + side * 4, 22, skin[2])
                # Front legs.
                fx = 9 if side < 0 else 14
                c.fill("rect", (fx, 19, fx, 21), skin[1]); c.put(fx + side, 22, skin[2]); c.put(fx, 22, skin[2])
            # Eyes on top of the head.
            c.shade("ellipse", (6, 8, 10, 12), skin, dither=False); c.shade("ellipse", (13, 8, 17, 12), skin, dither=False)
            c.fill("ellipse", (7, 9, 9, 11), C("f4e060")); c.fill("ellipse", (14, 9, 16, 11), C("f4e060"))
            c.put(8, 10, OUTLINE); c.put(15, 10, OUTLINE)
            c.fill("rect", (9, 15, 14, 15), dark)
            c.put(7, 14, dark); c.put(16, 14, dark)
            c.put(11, 12, dark); c.put(16, 16, dark)
        else:
            # Leaping: body stretched and tilted, hind legs trailing straight out.
            up = 5 if frame == 2 else 2
            c.shade("ellipse", (7, 9 - up + 4, 19, 16 - up + 4), skin)
            c.shade("ellipse", (10, 12 - up + 4, 17, 17 - up + 4), belly)
            c.shade("ellipse", (14, 7 - up + 4, 18, 11 - up + 4), skin, dither=False)
            c.fill("ellipse", (15, 8 - up + 4, 17, 10 - up + 4), C("f4e060")); c.put(16, 9 - up + 4, OUTLINE)
            if frame == 2:
                c.shade("poly", [(8, 14 - up + 4), (2, 19 - up + 4), (3, 21 - up + 4), (10, 16 - up + 4)], skin, dither=False)
                c.shade("poly", [(3, 20 - up + 4), (0, 22 - up + 4), (1, 23 - up + 4), (4, 21 - up + 4)], skin, dither=False)
                c.fill("rect", (17, 15 - up + 4, 20, 16 - up + 4), skin[1]); c.put(21, 17 - up + 4, skin[2])
            else:
                c.shade("poly", [(8, 15 - up + 4), (5, 20 - up + 4), (8, 21 - up + 4), (11, 16 - up + 4)], skin, dither=False)
                c.fill("rect", (4, 21 - up + 4, 8, 21 - up + 4), skin[2])
                c.fill("rect", (16, 16 - up + 4, 17, 20 - up + 4), skin[1]); c.fill("rect", (16, 21 - up + 4, 19, 21 - up + 4), skin[2])
    if kind != "butterfly":
        c.outline()
    return c.img


CRITTER_FRAMES = 4
CRITTERS = ["rabbit", "bird", "butterfly", "frog"]


# ----------------------------------------------------------------- decor
STONE = ramp("a6a2b0", "7c7888", "56525e")
WOOD = ramp("9a7a58", "6b4f36", "4a3626")
CLOTH = ramp("c05a5a", "8a2c37", "5c1c28")


def decor(kind):
    c = Canvas(64, 64)
    if kind == "floor":                           # flat stone slabs, laid under ruins
        r = random.Random(4)
        for y in range(4, 62, 10):
            for x in range(2 + (y // 10 % 2) * 6, 62, 12):
                if r.random() < 0.82:
                    c.shade("rect", (x, y, x + 10, y + 8), ramp("8a8794", "6e6b78", "55525e"))
        return c.img
    if kind == "rubble":
        # Fallen masonry: cut blocks with chipped corners, one broken in
        # two, chips and dust round them.
        r = random.Random(5)
        blocks = [(22, 46, 11, 7), (40, 50, 9, 6), (14, 56, 7, 5), (32, 58, 8, 5), (48, 59, 5, 4)]
        for x, y, w, h in blocks:
            chip = r.randrange(2, 4)
            c.shade("poly", [(x - w + chip, y - h), (x + w, y - h), (x + w, y + h - chip), (x + w - chip, y + h), (x - w, y + h), (x - w, y - h + chip)], STONE)
            c.fill("line", (x - w + chip, y - h + 1, x + w - 1, y - h + 1), C("c4c0cc"))
            c.fill("line", (x - w + 1, y + h - 1, x + w - chip, y + h - 1), STONE[2])
            if w > 8:
                c.fill("line", (x - 1, y - h, x + 1, y + h), C("3a3844"))
        for _ in range(14):
            x, y = r.randrange(8, 58), r.randrange(52, 63)
            if (x, y) not in c.filled:
                c.put(x, y, STONE[1] if r.random() < 0.5 else STONE[2])
    elif kind == "statue":
        # A knight on a plinth, weathered: helm, shield on the arm, a sword
        # point-down before it, moss in the cracks.
        stone = ramp("b4b0bc", "86828f", "57535f")
        c.shade("poly", [(14, 62), (50, 62), (48, 54), (16, 54)], ramp("9a96a4", "726e7c", "4e4a58"))
        c.fill("rect", (16, 54, 48, 54), C("c4c0cc"))
        c.shade("poly", [(19, 54), (21, 40), (24, 26), (32, 22), (40, 26), (43, 40), (45, 54)], stone)
        c.shade("poly", [(26, 54), (27, 42), (31, 42), (31, 54)], stone)
        c.shade("poly", [(33, 54), (33, 42), (37, 42), (38, 54)], stone)
        c.shade("ellipse", (26, 9, 38, 24), stone)
        c.fill("rect", (27, 15, 37, 16), C("3e3a46"))
        c.fill("rect", (31, 16, 32, 21), C("3e3a46"))
        c.shade("poly", [(15, 28), (24, 27), (24, 42), (19, 47), (14, 42)], ramp("a8a4b0", "7c7886", "54505e"))
        c.fill("rect", (18, 33, 20, 38), C("c4c0cc"))
        c.shade("rect", (39, 30, 42, 53), stone)
        c.shade("rect", (36, 30, 45, 32), stone)
        c.fill("line", (40, 34, 40, 50), C("d0ccd8"), 1)
        c.fill("line", (28, 30, 26, 46), C("4a4654"), 1)
        r = random.Random(17)
        for _ in range(16):
            x, y = r.randrange(16, 48), r.randrange(10, 60)
            if (x, y) in c.filled:
                c.put(x, y, C("5d7a3f") if r.random() < 0.5 else C("6e6a78"))
    elif kind == "brazier":
        # A wrought-iron brazier: a wide bowl with a bronze rim on three
        # curled legs, heaped with glowing coals; the flame is animated in
        # game (tools/generate_fire.py).
        iron = ramp("7e7a86", "4e4a56", "2c2a32")
        bronze = ramp("e8c070", "b8863a", "7a5626")
        c.shadow(32, 60, 14, 2, 70)
        for (x0, x1) in ((24, 18), (32, 32), (40, 46)):
            c.fill("line", (x0, 46, x1, 59), C("3a3842"), 2)
            c.put(x1 - 1 if x1 < 32 else x1 + 1, 59, C("6e6a76"))
        c.fill("line", (21, 52, 43, 52), C("3a3842"))
        c.shade("poly", [(14, 36), (50, 36), (45, 46), (19, 46)], iron)
        c.fill("line", (16, 41, 48, 41), C("2a2830"))
        c.shade("rect", (13, 34, 51, 37), bronze, dither=False)
        c.fill("line", (13, 34, 51, 34), C("f8dc98"))
        c.fill("ellipse", (16, 31, 48, 37), C("2a1a14"))
        for (x, y, col) in [(19, 34, "c8361a"), (22, 33, "f08a2e"), (26, 32, "ffd86b"), (29, 33, "c8361a"), (32, 32, "fff2a8"), (35, 33, "f08a2e"),
                            (38, 32, "ffd86b"), (41, 33, "c8361a"), (44, 34, "f08a2e"), (24, 35, "8a2a12"), (34, 35, "8a2a12"), (30, 31, "f08a2e")]:
            c.put(x, y, C(col))
            c.put(x + 1, y, C(col))
        for x in (17, 47):
            c.put(x, 38, C("c4c0cc"))
    elif kind == "banner":
        c.shade("rect", (30, 6, 33, 60), WOOD)
        c.shade("rect", (22, 8, 44, 10), WOOD)
        c.shade("poly", [(23, 11), (43, 11), (43, 40), (33, 34), (23, 40)], CLOTH)
        c.shade("poly", [(29, 18), (37, 18), (33, 28)], ramp("f0cf6a", "c09a3c", "866a26"))
    elif kind == "bone_pile":
        # A skull lying in the grass with its jaw beside it, a thigh bone,
        # ribs and finger bones scattered round.
        bone = ramp("f4f0e2", "d2cdb8", "9e9a88")
        for (a, b, w) in [((10, 58), (28, 52), 3), ((40, 60), (56, 54), 2), ((20, 61), (26, 59), 2)]:
            c.shade("line", (a[0], a[1], b[0], b[1]), bone, width=w, dither=False)
        for end in [(10, 58), (28, 52)]:
            c.shade("ellipse", (end[0] - 2, end[1] - 2, end[0] + 2, end[1] + 2), bone)
        for k in range(4):
            c.fill("line", (42 + k * 3, 50 - k, 45 + k * 3, 56 - k // 2), bone[1], 1)
        c.shade("ellipse", (24, 34, 44, 52), bone)
        c.shade("rect", (28, 48, 40, 54), bone)
        c.fill("ellipse", (27, 40, 32, 46), C("1a1418"))
        c.fill("ellipse", (36, 40, 41, 46), C("1a1418"))
        c.fill("poly", [(33, 47), (35, 47), (34, 50)], C("1a1418"))
        for x in (29, 32, 35, 38):
            c.fill("rect", (x, 52, x, 53), C("6a6458"))
        c.fill("line", (36, 35, 34, 39), C("8a8474"), 1)
        c.shade("poly", [(14, 52), (24, 52), (23, 55), (15, 55)], bone)
        for x in (16, 19, 22):
            c.put(x, 52, C("6a6458"))
    elif kind == "crate":
        # A crate in three-quarter view: plank front with a braced X, a lit
        # top, iron corner brackets and nail heads.
        wood = ramp("b08a5c", "84603e", "5a3e28")
        c.shade("poly", [(14, 30), (40, 30), (50, 24), (24, 24)], ramp("c8a272", "a07a4e", "7a5638"))
        c.shade("rect", (14, 30, 40, 60), wood)
        c.shade("poly", [(40, 30), (50, 24), (50, 54), (40, 60)], ramp("8a6440", "6a4a30", "4a3220"))
        for y in (37, 45, 53):
            c.fill("line", (15, y, 39, y), C("4a3220"), 1)
        for y in (34, 42, 50):
            c.fill("line", (41, y, 49, y - 6), C("3a2818"), 1)
        c.shade("line", (16, 32, 38, 58), wood, width=3, dither=False)
        c.shade("line", (38, 32, 16, 58), wood, width=3, dither=False)
        for (x, y) in ((14, 30), (37, 30), (14, 57), (37, 57)):
            c.fill("rect", (x, y, x + 3, y + 3), C("6a6670"))
            c.put(x + 1, y + 1, C("b0acb8"))
        for (x, y) in ((27, 33), (27, 56), (18, 44), (36, 44)):
            c.put(x, y, C("2a2220"))
    elif kind == "barrel":
        # A barrel in three-quarter view: bulging staves, the round lid
        # seen from above, two iron hoops catching the light, a tap bung.
        wood = ramp("b08a5c", "84603e", "5a3e28")
        c.shade("poly", [(20, 28), (44, 28), (47, 36), (48, 46), (46, 56), (42, 61), (22, 61), (18, 56), (16, 46), (17, 36)], wood)
        for x in (24, 29, 34, 39):
            c.fill("line", (x, 30, x + (1 if x > 32 else -1), 60), C("5a3e28"), 1)
        c.shade("ellipse", (20, 24, 44, 33), ramp("c8a272", "a07a4e", "7a5638"))
        c.fill("ellipse", (23, 26, 41, 31), C("8a6440"))
        c.fill("line", (24, 28, 40, 28), C("6a4a30"), 1)
        hoop = ramp("8a8694", "5e5a68", "3a3844")
        for (y, inset) in ((36, 1), (52, 0)):
            c.shade("poly", [(17 + inset, y), (47 - inset, y), (47 - inset, y + 3), (17 + inset, y + 3)], hoop)
            c.fill("line", (18 + inset, y, 46 - inset, y), C("c4c0cc"), 1)
        c.fill("ellipse", (30, 43, 34, 47), C("3a2818"))
        c.fill("rect", (31, 44, 32, 45), C("8a6440"))
    elif kind == "well":
        c.shade("ellipse", (10, 34, 54, 60), STONE)
        c.fill("ellipse", (16, 38, 48, 52), C("101824"))
        c.shade("rect", (12, 10, 15, 46), WOOD)
        c.shade("rect", (49, 10, 52, 46), WOOD)
        c.shade("poly", [(6, 14), (32, 2), (58, 14)], ramp("c05a5a", "8a2c37", "5c1c28"))
    elif kind == "fence":
        for x in (6, 30, 54):
            c.shade("rect", (x, 30, x + 4, 60), WOOD)
        c.shade("rect", (6, 36, 58, 39), WOOD)
        c.shade("rect", (6, 48, 58, 51), WOOD)
    elif kind == "lantern":
        # A lamp post: an iron cage of glass on a post; the flame inside is
        # animated in game.
        iron = ramp("4a4650", "33303a", "222028")
        c.shade("rect", (30, 22, 33, 60), iron)
        c.shade("rect", (26, 58, 37, 61), iron)
        c.shade("poly", [(25, 8), (38, 8), (36, 5), (27, 5)], iron)
        c.fill("rect", (31, 2, 32, 5), C("33303a"))
        c.fill("rect", (26, 9, 37, 20), C("3a3020"))
        c.fill("rect", (27, 10, 36, 19), C("f0d890", 120))
        c.fill("rect", (26, 9, 26, 20), C("222028"))
        c.fill("rect", (37, 9, 37, 20), C("222028"))
        c.fill("rect", (31, 9, 32, 20), C("33303a", 200))
        c.shade("rect", (25, 20, 38, 22), iron)
    elif kind == "stall":
        c.shade("rect", (8, 34, 56, 46), WOOD)
        c.shade("rect", (10, 46, 13, 62), WOOD)
        c.shade("rect", (51, 46, 54, 62), WOOD)
        c.shade("rect", (10, 6, 12, 34), WOOD)
        c.shade("rect", (52, 6, 54, 34), WOOD)
        for k in range(6):
            col = CLOTH if k % 2 == 0 else ramp("f4f2ec", "d4d0c4", "a8a498")
            c.shade("poly", [(4 + k * 9.3, 6), (13.3 + k * 9.3, 6), (13.3 + k * 9.3, 16), (4 + k * 9.3, 14)], col, dither=False)
        for (x, col) in [(16, C("c0303a")), (26, C("f0cf6a")), (36, C("6a9a4a")), (46, C("e08a3a"))]:
            c.fill("ellipse", (x - 3, 28, x + 3, 34), col)
    elif kind == "signpost":
        # A waymarker: a post sunk in a cairn of stones, two arrow boards
        # pointing different ways with carved letters, nails, a lantern hook.
        c.shade("ellipse", (24, 56, 40, 62), STONE)
        c.shade("rect", (30, 14, 34, 60), WOOD)
        c.shade("poly", [(32, 10), (35, 13), (29, 13)], WOOD)
        board = ramp("b08a5c", "84603e", "5a3e28")
        c.shade("poly", [(12, 18), (42, 18), (49, 23), (42, 28), (12, 28)], board)
        c.shade("poly", [(52, 32), (22, 32), (15, 37), (22, 42), (52, 42)], board)
        for (x0, x1, y) in ((16, 38, 21), (16, 30, 25), (26, 48, 35), (34, 48, 39)):
            c.fill("line", (x0, y, x1, y), C("3a2818"), 1)
        for (x, y) in ((31, 23), (33, 37)):
            c.put(x, y, C("c4c0cc"))
    elif kind == "rug":
        c.shade("rect", (4, 20, 60, 50), CLOTH, dither=False)
        c.fill("rect", (8, 24, 56, 46), ramp("f0cf6a", "c09a3c", "866a26")[1])
        c.fill("rect", (11, 27, 53, 43), CLOTH[1])
        c.fill("poly", [(32, 29), (42, 35), (32, 41), (22, 35)], ramp("f0cf6a", "c09a3c", "866a26")[0])
        return c.img
    elif kind == "shelf":
        # A bookshelf: a framed case of three shelves crowded with books of
        # many colours and heights, a few leaning, a jar and a scroll.
        frame = ramp("9a7450", "6e5034", "4a3422")
        c.shade("rect", (8, 6, 56, 62), frame)
        c.fill("rect", (11, 9, 53, 59), C("2a1e16"))
        for y in (24, 41, 58):
            c.shade("rect", (10, y, 54, y + 2), frame)
        colours = ["b03a3a", "3a6ab0", "c8a040", "4a8a4a", "8a4aa0", "c86a3a", "3a8a8a", "d8c8a0"]
        r = random.Random(31)
        for shelf_y in (24, 41, 58):
            x = 12
            while x < 51:
                w = r.choice((3, 3, 4, 2))
                h = r.randrange(9, 14)
                if r.random() < 0.12 and x < 46:
                    c.shade("ellipse", (x, shelf_y - 7, x + 5, shelf_y - 1), ramp("c8e0e8", "90b0c0", "607888"))
                    x += 7
                    continue
                col = C(r.choice(colours))
                lean = 2 if r.random() < 0.1 else 0
                c.fill("poly", [(x + lean, shelf_y - h), (x + w + lean, shelf_y - h), (x + w, shelf_y - 1), (x, shelf_y - 1)], col)
                c.fill("line", (x + lean, shelf_y - h, x, shelf_y - 1), C("ffffff", 90), 1)
                c.put(x + w // 2, shelf_y - h + 3, C("e8d090"))
                x += w + (1 if r.random() < 0.3 else 0)
        c.fill("rect", (8, 6, 56, 7), C("b8946a"))
    elif kind == "plant_pot":
        c.shade("poly", [(22, 46), (42, 46), (38, 60), (26, 60)], ramp("d08a5a", "a8643a", "7a4424"))
        canopy(c, [(32, 36, 12, 10), (24, 40, 7, 6), (40, 40, 7, 6)], ramp("6a9a4a", "4a7a3a", "2f5a2a"), 21)
    elif kind == "table":
        # A trestle table in three-quarter view: a planked top with its
        # front edge, braced legs, and a plate and cup on it.
        top = ramp("b08a5c", "84603e", "5a3e28")
        c.shade("poly", [(8, 34), (50, 34), (56, 28), (14, 28)], ramp("c8a272", "a07a4e", "7a5638"))
        for x in (20, 30, 40):
            c.fill("line", (x, 34, x + 6, 28), C("7a5638"), 1)
        c.shade("rect", (8, 34, 50, 38), top)
        c.shade("rect", (11, 38, 14, 58), top)
        c.shade("rect", (44, 38, 47, 58), top)
        c.shade("rect", (51, 32, 54, 52), ramp("8a6440", "6a4a30", "4a3220"))
        c.fill("line", (14, 50, 44, 50), C("5a3e28"), 2)
        c.shade("ellipse", (18, 28, 30, 33), ramp("f4f2ec", "d4d0c4", "a8a498"))
        c.shade("rect", (36, 25, 40, 31), ramp("c8c4d0", "9894a0", "6a6670"))
    elif kind == "chair":
        # A chair in three-quarter view: a slatted back, a seat seen from
        # above, four legs and a stretcher.
        wood = ramp("b08a5c", "84603e", "5a3e28")
        c.shade("rect", (22, 14, 25, 46), wood)
        c.shade("rect", (37, 14, 40, 46), wood)
        for y in (17, 23, 29):
            c.shade("rect", (25, y, 37, y + 3), wood)
        c.shade("poly", [(20, 44), (42, 44), (46, 38), (24, 38)], ramp("c8a272", "a07a4e", "7a5638"))
        c.shade("rect", (20, 44, 42, 47), wood)
        for x in (20, 39):
            c.shade("rect", (x, 47, x + 3, 61), wood)
        c.shade("rect", (43, 42, 45, 56), ramp("8a6440", "6a4a30", "4a3220"))
        c.fill("line", (22, 55, 40, 55), C("5a3e28"), 1)
    elif kind == "candles":
        # Wax candles with drips and wicks; the flames are animated in game.
        c.shade("ellipse", (16, 55, 48, 61), ramp("8a7a68", "6a5a4a", "4a3e34"))
        for (x, h) in [(24, 14), (32, 20), (40, 11)]:
            c.shade("rect", (x - 2, 58 - h, x + 2, 58), ramp("f4f2ec", "d4d0c4", "a8a498"))
            c.fill("rect", (x - 2, 58 - h, x - 2, 61 - h), C("fffbe8"))
            c.fill("rect", (x + 2, 59 - h, x + 2, 63 - h), C("e8e2d0"))
            c.put(x, 57 - h, C("2a2420"))
    elif kind == "cage":
        c.shade("rect", (14, 14, 50, 18), ramp("6a6670", "4a4650", "2a2830"))
        c.shade("rect", (14, 56, 50, 60), ramp("6a6670", "4a4650", "2a2830"))
        for x in range(16, 50, 6):
            c.fill("rect", (x, 18, x + 1, 56), C("4a4650"))
        c.shade("ellipse", (26, 42, 38, 56), ramp("f2efe2", "cfcbb8", "9b9889"))
    elif kind == "tent":
        # A canvas tent in three-quarter view: the front gable with its flap
        # tied open on a dark inside, the long side sloping away, stitched
        # seams, the ridge pole poking out, guy ropes and pegs.
        canvas = ramp("d0c09a", "a8946c", "7a6a4a")
        side = ramp("b8a680", "8e7a56", "62543a")
        c.shade("poly", [(26, 10), (56, 18), (62, 56), (40, 60)], side)
        c.shade("poly", [(4, 60), (26, 10), (44, 60)], canvas)
        c.fill("poly", [(17, 60), (26, 30), (33, 60)], C("1e1814"))
        c.fill("poly", [(26, 30), (21, 44), (17, 60), (14, 60)], canvas[1])
        c.fill("line", (26, 30, 21, 46), C("6a5a3e"), 1)
        for t in (0.3, 0.55, 0.8):
            c.fill("line", (int(26 + (56 - 26) * t), int(10 + 8 * t), int(40 + (62 - 40) * t), int(60 - 4 * t)), C("7a6a4a"), 1)
        c.fill("line", (26, 10, 56, 18), C("e8dcbc"), 1)
        c.shade("rect", (24, 5, 27, 11), WOOD)
        for (x0, y0, x1, y1) in ((10, 46, 2, 62), (58, 40, 63, 60)):
            c.fill("line", (x0, y0, x1, y1), C("c8b890"), 1)
            c.fill("rect", (x1 - 1, y1 - 2, x1, y1), C("6a4a30"))
    elif kind == "obelisk":
        # A granite needle on a stepped plinth: a lit face and a shaded
        # one, a capstone, glyphs cut into the stone (no paint, no glow),
        # chips, a crack and lichen.
        c.shade("rect", (19, 55, 45, 61), ramp("9a96a2", "76727e", "4e4a56"))
        c.fill("line", (19, 55, 45, 55), C("c4c0cc"))
        c.shade("rect", (22, 50, 42, 55), ramp("aaa6b2", "86828e", "5e5a66"))
        c.fill("line", (22, 50, 42, 50), C("cecad6"))
        c.shade("poly", [(25, 50), (27, 13), (32, 13), (32, 50)], ramp("c2beca", "a8a4b0", "908c98"), dither=False)
        c.shade("poly", [(32, 50), (32, 13), (37, 13), (39, 50)], ramp("86828e", "72707c", "5c5866"), dither=False)
        c.shade("poly", [(27, 13), (32, 4), (32, 13)], ramp("d2ced8", "bcb8c4", "a4a0ac"), dither=False)
        c.shade("poly", [(32, 13), (32, 4), (37, 13)], ramp("8e8a96", "7a7684", "66626e"), dither=False)
        groove, lip = C("5a5664"), C("d6d2dc")
        for i, y in enumerate(range(18, 47, 5)):
            w = 1 + (i * 3) % 3
            x0 = 28 + (i % 2)
            c.fill("line", (x0, y, x0 + w, y), groove)
            c.fill("line", (x0, y + 1, x0 + w, y + 1), lip)
            c.put(30 + (i + 1) % 2, y + 2, groove)
        c.fill("line", (35, 22, 34, 27), C("4a4654"))
        c.fill("line", (34, 27, 36, 31), C("4a4654"))
        r = random.Random(21)
        for _ in range(12):
            x, y = r.randrange(26, 39), r.randrange(30, 54)
            if (x, y) in c.filled:
                c.put(x, y, C("6d8a44") if r.random() < 0.6 else C("8aa65a"))
    elif kind == "standing_stone":
        # A rough menhir, leaning a touch: worn bumps, a spiral cut long
        # ago, lichen, grass and pebbles at its foot.
        stone = ramp("b4b0bc", "8a8694", "5e5a68")
        c.shade("ellipse", (16, 54, 48, 62), ramp("6a7a52", "56663e", "3e4a2e"))
        c.shade("poly", [(22, 58), (21, 40), (23, 22), (27, 12), (33, 8), (38, 11), (41, 22), (43, 40), (42, 58)], stone)
        c.fill("line", (24, 20, 23, 40), C("ccc8d4"))
        c.fill("line", (26, 13, 24, 19), C("ccc8d4"))
        for (x, y) in [(32, 26), (33, 26), (34, 27), (34, 28), (33, 29), (32, 29), (31, 28), (31, 27), (32, 25), (34, 25), (35, 26),
                       (36, 28), (35, 30), (33, 31), (31, 31), (30, 30), (29, 28), (30, 26)]:
            c.put(x, y, C("54505e"))
        c.fill("line", (39, 34, 38, 40), C("4a4654"))
        c.fill("line", (38, 40, 40, 45), C("4a4654"))
        r = random.Random(23)
        for _ in range(26):
            x, y = r.randrange(22, 43), r.randrange(30, 57)
            if (x, y) in c.filled:
                c.put(x, y, [C("6d8a44"), C("8aa65a"), C("c8c070")][r.randrange(3)])
        for x in range(18, 47, 2):
            if r.random() < 0.6:
                c.put(x, 57 - r.randrange(0, 3), C("6d8a44"))
                c.put(x, 58, C("4f6a34"))
        for (x, y) in [(17, 59), (45, 58), (47, 60)]:
            c.shade("ellipse", (x - 2, y - 1, x + 2, y + 1), STONE)
    elif kind == "carved_pillar":
        # A squared stone pillar: base, shaft with carved bands, capital.
        lit, dark = ramp("c0bcc8", "a6a2ae", "8e8a96"), ramp("86828e", "706c7a", "5a5664")
        c.shade("rect", (21, 55, 43, 61), ramp("9a96a2", "76727e", "4e4a56"))
        c.fill("line", (21, 55, 43, 55), C("c4c0cc"))
        c.shade("rect", (24, 14, 32, 55), lit, dither=False)
        c.shade("rect", (32, 14, 40, 55), dark, dither=False)
        c.shade("rect", (21, 8, 43, 14), ramp("c8c4d0", "a29eaa", "6e6a78"))
        c.fill("line", (21, 8, 43, 8), C("dcd8e2"))
        for y in (20, 34, 48):
            c.fill("line", (24, y, 40, y), C("5a5664"))
            c.fill("line", (24, y + 1, 40, y + 1), C("d0ccd8"))
        for y in range(23, 32, 3):
            c.put(28, y, C("5a5664"))
            c.put(36, y, C("4a4654"))
        c.fill("line", (38, 40, 36, 46), C("4a4654"))
        c.put(42, 9, C("6e6a78"))
        c.put(41, 9, C("6e6a78"))
        r = random.Random(29)
        for _ in range(10):
            x, y = r.randrange(24, 40), r.randrange(40, 55)
            c.put(x, y, C("6d8a44"))
    elif kind == "rune_stele":
        # A standing slab with a rounded head, lines of runes cut into its
        # face, set in a low stone footing; worn corners and moss.
        c.shade("rect", (18, 54, 46, 61), ramp("9a96a2", "76727e", "4e4a56"))
        c.fill("line", (18, 54, 46, 54), C("c4c0cc"))
        c.shade("poly", [(21, 54), (21, 16), (24, 10), (32, 7), (40, 10), (43, 16), (43, 54)], ramp("bcb8c4", "9894a2", "6a6676"))
        c.shade("rect", (40, 16, 43, 54), ramp("807c8a", "6c6876", "585462"), dither=False)
        r = random.Random(31)
        for y in range(17, 49, 5):
            x = 24
            while x < 37:
                w = r.randrange(1, 4)
                c.fill("line", (x, y, x + w, y), C("4e4a58"))
                c.fill("line", (x, y + 1, x + w, y + 1), C("d4d0da"))
                if r.random() < 0.5:
                    c.put(x, y - 1, C("4e4a58"))
                x += w + 2
        for _ in range(16):
            x, y = r.randrange(21, 43), r.randrange(42, 54)
            if (x, y) in c.filled:
                c.put(x, y, C("6d8a44") if r.random() < 0.7 else C("8aa65a"))
    elif kind == "chime_stone":
        # A singing stone: a flat round stone with a hole bored through,
        # stood in a slotted base, worn smooth where it has been struck.
        c.shade("rect", (16, 54, 48, 61), ramp("9a96a2", "76727e", "4e4a56"))
        c.fill("line", (16, 54, 48, 54), C("c4c0cc"))
        c.shade("ellipse", (17, 16, 47, 56), ramp("c4c0cc", "9894a2", "66626e"))
        c.shade("ellipse", (27, 26, 37, 36), ramp("3a3644", "2e2a36", "221f2a"), dither=False)
        for (x, y) in [(26, 31), (27, 28), (29, 26), (32, 25), (35, 26), (37, 28)]:
            c.put(x, y, C("dcd8e2"))
        for a in range(0, 360, 30):
            x = 32 + math.cos(math.radians(a)) * 12
            y = 36 + math.sin(math.radians(a)) * 15
            c.put(x, y, C("5a5664"))
        c.fill("rect", (29, 46, 35, 48), C("d8d4de"))
        c.shade("rect", (20, 50, 44, 54), ramp("8a8692", "6e6a78", "54505e"))
    elif kind == "stone_pedestal":
        # A short column with a square top, a shallow dish worn into it.
        c.shade("rect", (21, 55, 43, 61), ramp("9a96a2", "76727e", "4e4a56"))
        c.fill("line", (21, 55, 43, 55), C("c4c0cc"))
        c.shade("rect", (25, 34, 32, 55), ramp("c0bcc8", "a6a2ae", "8e8a96"), dither=False)
        c.shade("rect", (32, 34, 39, 55), ramp("86828e", "706c7a", "5a5664"), dither=False)
        c.shade("rect", (19, 27, 45, 34), ramp("c8c4d0", "a29eaa", "6e6a78"))
        c.fill("line", (19, 27, 45, 27), C("dcd8e2"))
        c.shade("ellipse", (25, 28, 39, 32), ramp("5a5664", "4a4654", "3a3644"), dither=False)
        for y in (40, 48):
            c.fill("line", (25, y, 39, y), C("5a5664"))
            c.fill("line", (25, y + 1, 39, y + 1), C("d0ccd8"))
    elif kind == "stone_shard":
        # A split spire of dark rock thrust up from the ground, cracked
        # through, with broken pieces about its foot.
        rock = ramp("8e8a9a", "65616f", "403d4a")
        c.shade("poly", [(20, 58), (24, 34), (29, 16), (33, 6), (36, 20), (41, 30), (44, 58)], rock)
        c.shade("poly", [(36, 58), (40, 40), (46, 28), (48, 40), (47, 58)], ramp("7e7a8a", "5a5664", "3a3744"))
        c.fill("line", (31, 16, 29, 30), C("aaa6b6"))
        c.fill("line", (29, 30, 26, 44), C("aaa6b6"))
        c.fill("line", (34, 14, 33, 26), C("2a2834"))
        c.fill("line", (33, 26, 36, 36), C("2a2834"))
        c.fill("line", (36, 36, 34, 50), C("2a2834"))
        for (x, y) in [(15, 59), (50, 60), (26, 61)]:
            c.shade("ellipse", (x - 3, y - 2, x + 3, y + 1), rock)
    elif kind == "palisade":                      # a section of sharpened log wall
        for x in range(6, 60, 9):
            top = 14 + (x * 7) % 6
            c.shade("rect", (x, top, x + 8, 60), WOOD)
            c.shade("poly", [(x, top), (x + 4, top - 8), (x + 8, top)], WOOD)
            c.put(x + 2, top + 10, WOOD[2])
        c.shade("rect", (4, 30, 60, 33), ramp("7a5a44", "5a4032", "3b2a22"))
        c.shade("rect", (4, 48, 60, 51), ramp("7a5a44", "5a4032", "3b2a22"))
    elif kind == "spike_trap":                    # a bed of stakes
        c.shade("rect", (8, 48, 56, 60), ramp("6a5a48", "4e4236", "362e26"))
        for x in range(12, 54, 7):
            for row, y in enumerate((50, 56)):
                xx = x + (3 if row else 0)
                c.shade("poly", [(xx - 2, y + 2), (xx, y - 10), (xx + 2, y + 2)], ramp("d8d0c0", "a8a090", "6a6458"))
                c.put(xx, y - 9, C("a0302a"))
    elif kind == "ballista":
        # A bolt-thrower: a heavy timber stock on a turned post and cross
        # feet, a bow of laminated wood with iron tips, the string drawn back
        # and a steel-headed bolt laid ready.
        wood_l = ramp("b08a5c", "84603e", "5a3e28")
        c.shadow(32, 60, 20, 3, 70)
        c.shade("rect", (14, 56, 50, 60), WOOD)
        c.shade("rect", (28, 40, 36, 57), wood_l)
        c.fill("line", (28, 40, 28, 56), C("c8a272"))
        c.shade("poly", [(14, 38), (50, 30), (52, 34), (16, 42)], wood_l)
        c.fill("line", (15, 38, 50, 30), C("c8a272"))
        for (x, y) in ((22, 37), (42, 33)):
            c.fill("rect", (x, y, x + 2, y + 2), C("6a6670"))
        c.fill("line", (6, 30, 20, 37), C("6b4f36"), 3)
        c.fill("line", (58, 22, 44, 33), C("6b4f36"), 3)
        c.fill("line", (6, 30, 20, 37), C("9a7a58"), 1)
        c.fill("line", (58, 22, 44, 33), C("9a7a58"), 1)
        c.fill("rect", (4, 28, 6, 31), C("8a8e98"))
        c.fill("rect", (58, 20, 60, 23), C("8a8e98"))
        c.fill("line", (5, 31, 18, 40), C("e8e0cc"))
        c.fill("line", (59, 23, 18, 40), C("e8e0cc"))
        c.fill("line", (18, 38, 48, 31), C("4a3626"), 2)
        c.shade("poly", [(46, 29), (54, 27), (48, 33)], ramp("eef0f0", "b4bcc2", "7d8890"))
        c.fill("line", (16, 39, 20, 41), C("b3434a"))
    elif kind == "soil":                          # tilled earth for a crop
        c.shade("rect", (6, 26, 58, 58), ramp("6a4a32", "4e3624", "362418"))
        for y in range(30, 56, 7):
            c.fill("line", (9, y, 55, y), C("2a1c12"), 1)
            c.fill("line", (9, y + 2, 55, y + 2), C("7a5a40"), 1)
    elif kind == "scarecrow":
        c.shade("rect", (30, 18, 34, 62), WOOD)
        c.shade("rect", (14, 26, 50, 29), WOOD)
        c.shade("poly", [(22, 28), (42, 28), (44, 48), (20, 48)], ramp("b89a5a", "8e7338", "634f26"))
        c.shade("ellipse", (25, 8, 39, 22), ramp("e8d8a0", "c8b47a", "9a8656"))
        c.shade("poly", [(20, 10), (44, 10), (38, 2), (26, 2)], ramp("6a5a48", "4e4236", "362e26"))
        c.fill("rect", (28, 13, 29, 14), OUTLINE)
        c.fill("rect", (34, 13, 35, 14), OUTLINE)
        c.fill("line", (16, 30, 12, 36), ramp("e8d8a0", "c8b47a", "9a8656")[1], 1)
    elif kind == "torch":
        # A standing torch: a pole with a bound, pitch-soaked head in an iron
        # cup, set in a few stones. The flame is animated in game.
        wood = ramp("8a6a48", "6b4f36", "4a3626")
        c.shade("ellipse", (24, 55, 40, 61), ramp("8a8794", "66636f", "45434d"))
        c.shade("rect", (30, 22, 33, 58), wood)
        for y in (30, 42):
            c.fill("rect", (30, y, 33, y + 1), C("4a3626"))
        c.shade("poly", [(27, 16), (36, 16), (35, 23), (28, 23)], ramp("6a6670", "4a4650", "2a2830"))
        c.fill("rect", (28, 14, 35, 17), C("3a2418"))
        c.fill("rect", (29, 13, 34, 14), C("1a1010"))
        for x in (29, 32):
            c.put(x, 15, C("f08a2e"))
    elif kind == "fireplace":
        # A stone hearth with a chimney and a wooden mantel; logs on the
        # grate, the fire animated in game.
        stone = ramp("a6a2b0", "7c7888", "56525e")
        c.shade("rect", (22, 2, 42, 30), stone)
        c.shade("rect", (10, 26, 54, 61), stone)
        for y in range(30, 60, 6):
            for x in range(11 + (y // 6 % 2) * 4, 53, 8):
                c.fill("rect", (x, y, x, y + 5), C("56525e"))
            c.fill("rect", (11, y, 53, y), C("56525e"))
        for y in range(6, 30, 6):
            c.fill("rect", (23, y, 41, y), C("56525e"))
        c.fill("rect", (16, 34, 48, 59), C("120c0c"))
        c.fill("rect", (17, 35, 47, 37), C("201414"))
        c.shade("rect", (8, 27, 56, 31), ramp("9a7a58", "6b4f36", "4a3626"))
        c.shade("line", (19, 57, 45, 55), ramp("8a6a48", "6b4f36", "4a3626"), width=3, dither=False)
        c.shade("line", (19, 55, 45, 57), ramp("8a6a48", "6b4f36", "4a3626"), width=3, dither=False)
        for x in range(20, 45, 3):
            c.put(x, 58, C("f08a2e") if x % 2 else C("c8361a"))
        c.fill("rect", (14, 59, 50, 61), C("3a3640"))
    elif kind in ("waystone", "waystone_lit"):
        # A rough menhir of granite: a jagged, leaning top, chipped facets
        # and cracks, runes cut down its face (glowing when the stone is
        # awake), lichen, and a few fallen stones and moss at its foot.
        glow = kind == "waystone_lit"
        granite = ramp("b4b0bc", "86828f", "57535f")
        # A stepped plinth of dressed stone blocks under it.
        plinth = ramp("a4a0ae", "7a7684", "524e5c")
        c.shade("poly", [(8, 62), (56, 62), (54, 56), (10, 56)], plinth)
        c.shade("poly", [(13, 57), (51, 57), (49, 51), (15, 51)], plinth)
        for x in (18, 28, 38, 48):
            c.fill("rect", (x, 57, x, 61), C("3e3a46"))
        for x in (22, 32, 42):
            c.fill("rect", (x, 52, x, 56), C("3e3a46"))
        c.fill("rect", (10, 56, 54, 56), C("c4c0cc"))
        c.fill("rect", (15, 51, 49, 51), C("c4c0cc"))
        c.shade("poly", [(19, 52), (18, 40), (20, 26), (22, 15), (26, 8), (29, 9), (32, 4), (36, 6), (40, 12),
                         (43, 22), (45, 36), (46, 46), (45, 52)], granite)
        # Facets: a lit left face, a shadowed right face.
        c.fill("poly", [(21, 56), (20, 30), (23, 15), (27, 10), (25, 30), (24, 56)], C("c2bec8"))
        c.fill("poly", [(40, 14), (43, 24), (45, 38), (45, 58), (41, 58), (41, 36)], C("5f5b68"))
        r = random.Random(41)
        for _ in range(70):
            x, y = r.randrange(20, 46), r.randrange(6, 58)
            if (x, y) in c.filled:
                c.put(x, y, C("6e6a78") if r.random() < 0.55 else C("a8a4b2"))
        # Cracks.
        for line in [((36, 7), (35, 13), (37, 18)), ((24, 40), (27, 44), (26, 49)), ((42, 30), (40, 35))]:
            for (x0, y0), (x1, y1) in zip(line, line[1:]):
                c.fill("line", (x0, y0, x1, y1), C("3e3a46"), 1)
        # Runes: each a different glyph, cut in and lit from the upper left.
        glyphs = [[(0, 0, 0, 6), (0, 0, 3, 2), (0, 3, 3, 5)], [(1, 0, 1, 6), (0, 2, 3, 2), (0, 5, 3, 4)],
                  [(0, 0, 3, 3), (3, 3, 0, 6), (0, 0, 0, 6)], [(0, 6, 1, 0), (1, 0, 3, 6), (0, 3, 3, 3)],
                  [(1, 0, 1, 6), (1, 2, 3, 0), (1, 2, -1, 0)]]
        for (gx, gy), glyph in zip([(31, 13), (31, 21), (30, 29), (32, 37), (31, 44)], glyphs):
            for (x0, y0, x1, y1) in glyph:
                c.fill("line", (gx + x0 + 1, gy + y0 + 1, gx + x1 + 1, gy + y1 + 1), C("b4e8f0") if glow else C("a8a4b2"), 1)
                c.fill("line", (gx + x0, gy + y0, gx + x1, gy + y1), C("4ad8f0") if glow else C("403c48"), 1)
        if glow:
            for (x, y) in [(28, 16), (37, 25), (27, 37), (37, 47), (33, 9)]:
                c.put(x, y, C("dffcff"))
        # Lichen and moss.
        for (x, y) in [(22, 24), (23, 25), (43, 44), (44, 45), (42, 46), (21, 50)]:
            c.put(x, y, C("9aa84e"))
        for x in range(10, 55):
            if r.random() < 0.35:
                c.put(x, 61 - r.randrange(0, 2), C("5d7a3f") if r.random() < 0.6 else C("8aaa5a"))
        # A socket cut into the crown, where the waystone's crystal floats.
        c.fill("ellipse", (29, 6, 35, 10), C("2a2834"))
        if glow:
            c.fill("rect", (31, 7, 33, 8), C("8ff0ff"))
    elif kind == "gravestone":
        # A weathered headstone, rounded at the top, a cross cut into it,
        # leaning a little, with a mound of earth and grass in front.
        stone = ramp("a8a4b0", "7e7a88", "56525e")
        c.shade("ellipse", (18, 52, 46, 61), ramp("6a5a44", "54463a", "3e342a"))
        c.shade("poly", [(22, 56), (22, 30), (25, 25), (32, 22), (39, 25), (42, 30), (42, 56)], stone)
        c.fill("line", (24, 31, 24, 54), C("c4c0cc"), 1)
        c.fill("rect", (31, 30, 33, 46), C("44414e"))
        c.fill("rect", (27, 34, 37, 36), C("44414e"))
        c.fill("line", (34, 31, 34, 46), C("9a96a4"), 1)
        r = random.Random(9)
        for _ in range(18):
            x, y = r.randrange(23, 42), r.randrange(28, 55)
            if (x, y) in c.filled:
                c.put(x, y, C("6e6a78") if r.random() < 0.6 else C("5d7a3f"))
        for x in range(20, 45):
            if r.random() < 0.5:
                c.put(x, 56 - r.randrange(0, 2), C("5d7a3f") if r.random() < 0.6 else C("8aaa5a"))
    elif kind == "ruined_tower":
        # The stump of a round watchtower: courses of stone, a broken
        # jagged top, an arrow slit, a dark doorway and fallen blocks.
        stone = ramp("aaa6b2", "7e7a88", "54505e")
        c.shade("ellipse", (8, 52, 56, 62), ramp("7a7686", "5a5664", "3e3a46"))
        c.shade("poly", [(12, 58), (12, 16), (16, 12), (20, 15), (24, 6), (29, 10), (33, 4), (38, 11), (42, 8), (47, 14), (52, 12), (52, 58)], stone)
        for y in range(18, 58, 6):
            c.fill("line", (13, y, 51, y), C("4a4654"), 1)
            for x in range(14 + (y // 6 % 2) * 5, 51, 10):
                c.fill("line", (x, y + 1, x, y + 5), C("4a4654"), 1)
        c.fill("rect", (13, 17, 16, 57), C("b8b4c0"))
        c.fill("rect", (47, 17, 51, 57), C("5e5a68"))
        c.fill("rect", (31, 22, 33, 30), C("16141c"))
        c.shade("poly", [(26, 58), (26, 44), (32, 39), (38, 44), (38, 58)], ramp("221e28", "18151c", "100e14"))
        c.fill("line", (26, 44, 32, 39), C("9a96a4"), 1)
        c.shade("rect", (4, 54, 11, 60), stone)
        c.shade("rect", (53, 52, 59, 58), stone)
        r = random.Random(13)
        for _ in range(16):
            x, y = r.randrange(14, 50), r.randrange(14, 56)
            if (x, y) in c.filled:
                c.put(x, y, C("5d7a3f"))
    elif kind == "cart":
        # A broken handcart tipped on one wheel, a plank missing, a sack
        # spilled out of it.
        wood = ramp("9a7a52", "6b4f36", "4a3626")
        c.shade("poly", [(10, 40), (46, 34), (48, 46), (12, 52)], wood)
        for x in (18, 28, 38):
            c.fill("line", (x, 38 + (46 - x) // 12, x + 1, 50 - (x - 10) // 8), C("4a3626"), 1)
        c.shade("line", (46, 40, 60, 30), wood, width=2, dither=False)
        c.shade("ellipse", (20, 44, 34, 58), ramp("8a6a48", "5a4230", "3a2a1e"))
        c.fill("ellipse", (24, 48, 30, 54), C("2a1e16"))
        c.fill("line", (27, 45, 27, 57), C("6b4f36"), 1)
        c.fill("line", (21, 51, 33, 51), C("6b4f36"), 1)
        c.shade("ellipse", (40, 48, 54, 58), ramp("d8c8a0", "b8a478", "8a7654"))
        c.fill("line", (46, 48, 48, 46), C("6a5a44"), 1)
        for (x, y) in [(55, 57), (57, 56), (52, 59)]:
            c.put(x, y, C("e0c870"))
    elif kind in ("root_cutter", "root_delver", "root_tender"):
        # Root-tech: a living stump whose roots have learned to work. Roots
        # spread into the soil, a knot of light beats in the bark, and a
        # root arm rises from the top, shaped for its trade: a thorn blade
        # for wood, a stone-gripping fist for ore, soft fingers and a bud
        # for herbs and crops.
        bark = ramp("7a5a3a", "54402a", "34261a")
        glow = {"root_cutter": ramp("e0ffb8", "8ae070", "3a9a40"), "root_delver": ramp("fff0b0", "ffc050", "c07a20"),
                "root_tender": ramp("ffe0f0", "f090c0", "a04880")}[kind]
        for (x0, y0, x1, y1, w) in [(30, 56, 6, 61, 3), (34, 57, 58, 60, 3), (26, 57, 14, 63, 2), (38, 58, 48, 63, 2), (32, 58, 31, 63, 2)]:
            c.shade("line", (x0, y0, x1, y1), bark, width=w, dither=False)
        c.shade("poly", [(19, 59), (18, 44), (21, 35), (27, 31), (35, 31), (42, 35), (45, 44), (45, 59)], bark)
        for x in (23, 29, 38, 42):
            c.fill("line", (x, 36, x - 1, 57), C("3a2a1c"), 1)
        c.fill("ellipse", (19, 30, 44, 37), C("9a7a52"))
        for r_ in (3, 6, 9):
            c.fill("ellipse", (31 - r_, 33 - r_ // 3, 32 + r_, 34 + r_ // 3), C("7a5a3a") if r_ % 2 else C("b8956a"))
        # Sap-veins glowing through the bark, from the knot to the roots and up.
        for vein in [[(28, 47), (24, 50), (22, 55), (19, 59)], [(35, 47), (39, 51), (41, 56), (44, 59)], [(31, 43), (30, 39), (32, 35)],
                     [(33, 51), (33, 55), (35, 59)]]:
            for (ax, ay), (bx, by) in zip(vein, vein[1:]):
                c.fill("line", (ax, ay, bx, by), glow[1], 1)
        c.fill("ellipse", (26, 42, 37, 52), C("2a1c12"))
        c.shade("ellipse", (27, 43, 36, 51), glow)
        c.fill("rect", (29, 45, 30, 46), C("ffffff"))
        r = random.Random({"root_cutter": 21, "root_delver": 22, "root_tender": 23}[kind])
        for _ in range(14):
            x, y = r.randrange(19, 45), r.randrange(37, 58)
            if (x, y) in c.filled and not (26 <= x <= 37 and 42 <= y <= 52):
                c.put(x, y, C("5d7a3f") if r.random() < 0.7 else C("8aaa5a"))
        if kind == "root_cutter":
            c.shade("line", (36, 33, 42, 22), bark, width=4, dither=False)
            c.shade("line", (42, 22, 50, 13), bark, width=3, dither=False)
            c.fill("line", (37, 31, 46, 17), C("9a7a52"), 1)
            c.shade("poly", [(47, 15), (52, 8), (61, 4), (59, 12), (54, 17)], ramp("f0e0b0", "c8b080", "8a7450"))
            c.fill("line", (52, 9, 60, 5), C("ffffff"), 1)
            for (x, y) in [(23, 30), (40, 28), (44, 20)]:
                c.shade("ellipse", (x - 3, y - 2, x + 3, y + 2), ramp("a8e070", "6aae44", "3a7a2a"))
        elif kind == "root_delver":
            c.shade("line", (37, 34, 46, 30), bark, width=4, dither=False)
            c.shade("line", (46, 30, 52, 40), bark, width=4, dither=False)
            c.shade("ellipse", (46, 38, 60, 50), ramp("a8a4b0", "7e7a88", "56525e"))
            for (x0, y0, x1, y1) in [(47, 40, 52, 50), (52, 38, 57, 49), (56, 41, 59, 48)]:
                c.shade("line", (x0, y0, x1, y1), bark, width=2, dither=False)
            c.shade("poly", [(50, 44), (53, 39), (56, 44), (53, 48)], ramp("fff0b0", "ffc050", "c07a20"))
            c.fill("rect", (52, 41, 52, 42), C("ffffff"))
            c.shade("ellipse", (8, 52, 16, 58), ramp("a8a4b0", "7e7a88", "56525e"))
        else:
            for (x0, y0, x1, y1) in [(25, 32, 17, 20), (32, 31, 32, 14), (39, 32, 47, 21)]:
                c.shade("line", (x0, y0, x1, y1), bark, width=2, dither=False)
            for (x, y) in [(17, 20), (47, 21)]:
                c.shade("ellipse", (x - 3, y - 3, x + 3, y + 2), ramp("a8e070", "6aae44", "3a7a2a"))
            c.shade("ellipse", (27, 6, 37, 16), ramp("ffd0e8", "f090c0", "a04880"))
            c.fill("ellipse", (30, 9, 34, 13), C("fff0a0"))
            c.shade("ellipse", (28, 14, 36, 18), ramp("a8e070", "6aae44", "3a7a2a"))
    elif kind == "root_hollow":
        # A great hollow stump the root-tech stores its harvest in: a dark
        # opening glinting with what has been gathered, roots, moss and
        # a ring of pale mushrooms.
        bark = ramp("7a5a3a", "54402a", "34261a")
        for (x0, y0, x1, y1, w) in [(14, 56, 3, 62, 3), (50, 56, 62, 61, 3), (24, 58, 18, 63, 2), (42, 58, 48, 63, 2)]:
            c.shade("line", (x0, y0, x1, y1), bark, width=w, dither=False)
        c.shade("poly", [(8, 60), (9, 34), (14, 22), (24, 17), (40, 17), (50, 22), (55, 34), (56, 60)], bark)
        c.fill("ellipse", (12, 14, 52, 26), C("9a7a52"))
        for r_ in (4, 8, 12, 16):
            c.fill("ellipse", (32 - r_ - 2, 20 - r_ // 4, 32 + r_ + 2, 20 + r_ // 4), C("7a5a3a") if r_ % 8 else C("b8956a"))
        c.fill("ellipse", (12, 13, 52, 18), C("5d7a3f"))
        for x in (14, 22, 42, 50):
            c.fill("line", (x, 28, x + 1, 58), C("3a2a1c"), 1)
        c.fill("poly", [(21, 58), (21, 40), (26, 32), (32, 30), (38, 32), (43, 40), (43, 58)], C("140e0a"))
        for (x, y, col) in [(26, 54, "f0c040"), (31, 52, "a8e070"), (36, 55, "c8c4d0"), (29, 56, "e0a050"), (34, 50, "f0c040")]:
            c.fill("ellipse", (x - 2, y - 1, x + 2, y + 2), C(col))
        c.put(27, 53, C("ffffff"))
        c.fill("line", (21, 41, 26, 32), C("b8956a"), 1)
        for (x, y) in [(10, 58), (52, 57), (47, 60), (15, 61)]:
            c.fill("rect", (x, y - 3, x, y), C("e8e0c8"))
            c.fill("ellipse", (x - 2, y - 5, x + 2, y - 2), C("d8b8a0"))
        r = random.Random(24)
        for _ in range(24):
            x, y = r.randrange(9, 56), r.randrange(24, 60)
            if (x, y) in c.filled and not (21 <= x <= 43 and 30 <= y <= 58):
                c.put(x, y, C("5d7a3f") if r.random() < 0.7 else C("8aaa5a"))
    elif kind == "furnace":
        # A squat stone furnace: courses of blocks, a chimney, an arched
        # mouth glowing with coals, a little fire spilling light, and a
        # heap of coal beside it.
        stone = ramp("a8a4b0", "7e7a88", "54505e")
        c.shade("poly", [(12, 60), (12, 26), (20, 18), (44, 18), (52, 26), (52, 60)], stone)
        c.shade("rect", (36, 4, 46, 20), stone)
        c.fill("rect", (35, 3, 47, 5), C("c4c0cc"))
        for y in range(24, 60, 6):
            c.fill("line", (13, y, 51, y), C("4a4654"), 1)
            for x in range(14 + (y // 6 % 2) * 6, 51, 12):
                c.fill("line", (x, y + 1, x, y + 5), C("4a4654"), 1)
        c.fill("poly", [(22, 58), (22, 42), (26, 36), (32, 34), (38, 36), (42, 42), (42, 58)], C("1a1012"))
        c.shade("ellipse", (24, 46, 40, 58), ramp("fff0a0", "ffa040", "c04a10"))
        for (x, y) in [(27, 51), (31, 49), (35, 52), (29, 54), (34, 55)]:
            c.fill("rect", (x, y, x + 1, y + 1), C("fff4c0"))
        c.fill("line", (22, 42, 26, 36), C("c4c0cc"), 1)
        c.fill("line", (26, 36, 32, 34), C("c4c0cc"), 1)
        c.shade("ellipse", (2, 52, 13, 61), ramp("5a5866", "34323e", "1a1820"))
        c.fill("rect", (5, 54, 6, 55), C("a8a6b8"))
        c.fill("ellipse", (38, 0, 44, 4), C("6a6a70"))
    elif kind == "farmhouse":
        # A small red farmhouse barn: a pitched shingle roof, white-trimmed
        # double doors braced with an X, a hay loft spilling straw, a
        # lantern by the door and a water trough.
        red = ramp("c85a48", "9a3a30", "6a2420")
        roof = ramp("8a7a6a", "5e5248", "3e3630")
        trim = ramp("f4efe2", "d8d0c0", "a8a090")
        c.shade("poly", [(8, 60), (8, 30), (56, 30), (56, 60)], red)
        for y in range(33, 60, 4):
            c.fill("line", (9, y, 55, y), C("7a2a24"), 1)
        c.shade("poly", [(4, 32), (32, 10), (60, 32), (56, 34), (32, 15), (8, 34)], roof)
        c.shade("poly", [(10, 31), (32, 13), (54, 31)], red)
        for y in range(16, 31, 3):
            c.fill("line", (32 - (y - 13) * 22 // 18, y, 32 + (y - 13) * 22 // 18, y), C("7a2a24"), 1)
        c.shade("poly", [(26, 28), (26, 20), (32, 16), (38, 20), (38, 28)], ramp("3a2a1c", "2a1e14", "1c140e"))
        c.shade("poly", [(27, 28), (28, 24), (31, 25), (34, 22), (37, 26), (37, 28)], ramp("f0d878", "d0b050", "9a7a30"))
        c.shade("rect", (21, 40, 43, 60), trim)
        c.shade("rect", (23, 42, 31, 59), red)
        c.shade("rect", (33, 42, 41, 59), red)
        for (x0, x1) in ((23, 31), (33, 41)):
            c.fill("line", (x0, 42, x1, 59), C("f4efe2"), 1)
            c.fill("line", (x1, 42, x0, 59), C("f4efe2"), 1)
        c.fill("rect", (31, 42, 33, 59), C("f4efe2"))
        c.fill("rect", (17, 42, 18, 45), C("3a3036"))
        c.fill("rect", (16, 45, 19, 49), C("ffd070"))
        c.shade("rect", (46, 54, 60, 60), ramp("9a7a52", "6b4f36", "4a3626"))
        c.fill("rect", (47, 55, 59, 56), C("6aa8d8"))
        r = random.Random(25)
        for _ in range(10):
            x = r.randrange(24, 40)
            c.fill("line", (x, 28, x + r.randrange(-2, 3), 30 + r.randrange(0, 3)), C("e8d070"), 1)
    elif kind == "anvil":
        # A smith's anvil on a stump: a dark iron horn and face with a bright
        # worn top, and a hammer leaning on the block.
        iron = ramp("8a8e9a", "5a5e6a", "34363e")
        wood = ramp("9a7450", "6e5034", "4a3422")
        c.shade("rect", (22, 44, 42, 62), wood)
        for y in (48, 54, 60):
            c.fill("line", (23, y, 41, y), C("3a2a1a"), 1)
        c.shade("poly", [(10, 30), (50, 30), (54, 34), (44, 38), (40, 44), (24, 44), (20, 38), (14, 36)], iron)
        c.fill("line", (12, 30, 50, 30), C("c8ccd6"), 1)
        c.shade("poly", [(50, 30), (60, 32), (54, 35)], iron)
        c.shade("rect", (44, 50, 46, 62), wood)
        c.shade("rect", (40, 46, 50, 51), iron)
    elif kind == "weapon_rack":
        # A wooden rack with a sword, a spear and an axe standing in it.
        wood = ramp("9a7450", "6e5034", "4a3422")
        steel = ramp("e4e8ee", "a8b0bc", "6a7280")
        c.shade("rect", (8, 50, 56, 56), wood)
        c.shade("rect", (8, 18, 12, 60), wood)
        c.shade("rect", (52, 18, 56, 60), wood)
        c.shade("rect", (8, 24, 56, 27), wood)
        c.fill("line", (20, 6, 20, 50), steel[1], 2)
        c.fill("line", (19, 6, 21, 4), steel[0], 1)
        c.fill("rect", (16, 22, 24, 23), C("c8a050"))
        c.fill("line", (32, 4, 32, 50), C("7a5634"), 1)
        c.shade("poly", [(29, 4), (32, 0), (35, 4), (32, 10)], steel)
        c.fill("line", (44, 12, 44, 50), C("7a5634"), 1)
        c.shade("poly", [(44, 12), (50, 10), (51, 18), (44, 18)], steel)
    elif kind == "bench":
        # A plain wooden bench: plank seat, two legs, a back rail.
        wood = ramp("b08a5c", "7e5c3a", "54402a")
        c.shade("rect", (6, 38, 58, 44), wood)
        c.fill("line", (7, 38, 57, 38), C("d0aa7a"), 1)
        c.shade("rect", (10, 44, 14, 58), wood)
        c.shade("rect", (50, 44, 54, 58), wood)
        c.shade("rect", (6, 26, 58, 30), wood)
        c.shade("rect", (10, 30, 13, 38), wood)
        c.shade("rect", (51, 30, 54, 38), wood)
    elif kind == "hay_bale":
        # A tied bale of hay in three-quarter view: a lit top of cut straw
        # ends, a shaded front of laid straw, two twine bands, loose wisps.
        top, front, side = ramp("f4e08a", "dcc062", "b89a42"), ramp("e2c45e", "c4a444", "97782a"), ramp("a88a36", "8a6e26", "6a521a")
        c.shade("poly", [(10, 34), (44, 34), (54, 27), (20, 27)], top, dither=False)
        c.shade("rect", (10, 34, 44, 59), front, dither=False)
        c.shade("poly", [(44, 34), (54, 27), (54, 52), (44, 59)], side, dither=False)
        r = random.Random(41)
        for y in range(36, 58, 2):
            x = 11 + r.randrange(0, 3)
            while x < 43:
                w = r.randrange(3, 8)
                c.fill("line", (x, y, min(x + w, 43), y), front[0] if r.random() < 0.5 else front[2])
                x += w + r.randrange(2, 5)
        for _ in range(40):
            x, y = r.randrange(12, 52), r.randrange(28, 34)
            if (x, y) in c.filled:
                c.put(x, y, top[2] if r.random() < 0.6 else C("fff4b8"))
        for x in (20, 34):
            c.fill("line", (x, 34, x, 59), C("6a3a1e"))
            c.fill("line", (x + 1, 34, x + 1, 59), C("a86a3a"))
            c.fill("line", (x, 34, x + 9, 28), C("6a3a1e"))
        for (x0, y0, x1, y1) in ((9, 40, 6, 44), (44, 45, 49, 49), (14, 59, 10, 62), (38, 59, 43, 62), (26, 27, 24, 23)):
            c.fill("line", (x0, y0, x1, y1), top[1])
    elif kind == "flower_bed":
        # A low wooden box of soil with flowers in three colours.
        wood = ramp("9a7450", "6e5034", "4a3422")
        c.shade("rect", (6, 46, 58, 60), wood)
        c.fill("rect", (8, 44, 56, 48), C("4a3020"))
        r = random.Random(43)
        for i, x in enumerate(range(11, 56, 6)):
            c.fill("line", (x, 46, x, 36), C("4a8a3a"), 1)
            c.fill("rect", (x - 1, 40, x, 41), C("5a9a4a"))
            colour = ["e05a6a", "f0d060", "a080f0", "f0f0f0"][i % 4]
            c.shade("ellipse", (x - 3, 31, x + 3, 37), ramp(colour, colour, "8a5a50"))
            c.put(x, 34, C("f8e8a0"))
    elif kind == "cupboard":
        # A tall painted cupboard: two doors with knobs, a drawer, plates on top.
        wood = ramp("6e8aa8", "4a6482", "2e4058")
        c.shade("rect", (12, 10, 52, 62), wood)
        c.fill("line", (32, 14, 32, 48), C("24324a"), 1)
        c.fill("rect", (15, 14, 29, 47), C("5a7896"))
        c.fill("rect", (35, 14, 49, 47), C("5a7896"))
        c.shade("rect", (15, 50, 49, 58), wood)
        for x, y in ((28, 30), (36, 30), (32, 54)):
            c.fill("rect", (x, y, x + 1, y + 1), C("e8c070"))
        c.shade("ellipse", (16, 4, 26, 10), ramp("f4f4f0", "c8c8c0", "8a8a84"))
        c.shade("ellipse", (36, 5, 46, 10), ramp("f0e8c8", "c8b890", "8a7a5a"))
    elif kind == "fountain":
        # A round stone fountain: a basin of water, a column and a spout,
        # water falling into the pool.
        stone = ramp("c4c0cc", "8e8a98", "5a5664")
        c.shade("ellipse", (4, 38, 60, 62), stone)
        c.shade("ellipse", (8, 40, 56, 58), ramp("8ad0f0", "4a90c8", "2a5a8a"))
        c.shade("rect", (28, 14, 36, 48), stone)
        c.shade("ellipse", (22, 10, 42, 18), stone)
        c.fill("ellipse", (25, 11, 39, 16), C("6ab0e0"))
        for x in (24, 40):
            c.fill("line", (x, 16, x + (-3 if x < 32 else 3), 44), C("bfe8ff"), 1)
        c.fill("rect", (14, 46, 16, 47), C("e8f8ff"))
        c.fill("rect", (46, 50, 48, 51), C("e8f8ff"))
    elif kind == "stone_planter":
        # A square stone planter with a small trimmed shrub.
        stone = ramp("b4b0bc", "86828f", "57535f")
        c.shade("rect", (14, 40, 50, 62), stone)
        c.fill("line", (14, 40, 50, 40), C("d4d0dc"), 1)
        c.fill("rect", (16, 38, 48, 42), C("3a2a1c"))
        c.shade("ellipse", (14, 12, 50, 44), ramp("6ab04a", "3e7a32", "24501e"))
        r = random.Random(47)
        for _ in range(30):
            x, y = r.randrange(17, 48), r.randrange(15, 41)
            c.put(x, y, C("8ad06a") if r.random() < 0.5 else C("2a5a22"))
    elif kind == "trophy_stand":
        # A trophy stand for a hall: a dark wooden plinth on a stepped
        # base, a navy cloth over its top edged in bronze, and a brass
        # plaque on its face. The trophy itself is drawn over it in-game.
        wood = ramp("7a5a40", "5a402c", "3a2a1e")
        cloth = ramp("3e4a78", "2a3258", "1a2040")
        bronze = ramp("e8c070", "b48a3c", "7a5a24")
        c.shade("rect", (16, 54, 48, 61), wood)
        c.fill("line", (16, 54, 48, 54), C("8e6c4c"), 1)
        c.shade("rect", (20, 34, 44, 54), wood)
        for x in (24, 32, 40):
            c.fill("line", (x, 36, x, 52), C("4a3626"), 1)
        c.shade("rect", (18, 30, 46, 35), cloth)
        c.fill("line", (18, 35, 46, 35), bronze[1], 1)
        for x in range(19, 46, 4):
            c.fill("rect", (x, 36, x + 1, 38), cloth[1])
        c.shade("rect", (26, 42, 38, 47), bronze)
        c.fill("line", (28, 44, 36, 44), C("5a4020"), 1)
    c.outline()
    return c.img


# ----------------------------------------------------------------- props
# Frames of assets/sprites/props.png redrawn here with the same canvas (the
# rest of that sheet is drawn by generate_art.py, which pastes these over).
CHEST_WOOD = ramp("b88a58", "8e6640", "61442a")
CHEST_SIDE = ramp("7a5636", "61442a", "45301c")
IRON = ramp("b0b4be", "767a86", "464a54")
BRASS = ramp("f6d886", "cc9c40", "8a6424")


def _chest_box(c):
    """The body of a chest in three-quarter view: planked front, darker
    side, iron bands and corner brackets, brass rivets."""
    c.shadow(34, 59, 25, 4, 70)
    c.shade("poly", [(46, 36), (54, 31), (54, 53), (46, 58)], CHEST_SIDE, dither=False)
    c.shade("rect", (11, 36, 46, 58), CHEST_WOOD, dither=False)
    for y in (43, 50):
        c.fill("line", (11, y, 46, y), C("3e2a18"))
        c.fill("line", (11, y + 1, 46, y + 1), C("c8a06a"))
        c.fill("line", (47, y - 5, 53, y - 9), C("2e1e10"))
    r = random.Random(61)
    for _ in range(14):
        x, y = r.randrange(13, 45), r.randrange(37, 57)
        c.fill("line", (x, y, x + r.randrange(2, 5), y), C("6e4e30"))
    for x in (16, 39):
        c.shade("rect", (x, 36, x + 3, 58), IRON, dither=False)
        c.fill("line", (x, 36, x, 58), C("d8dce2"))
        for y in (39, 47, 55):
            c.put(x + 1, y, BRASS[0])
            c.put(x + 2, y, BRASS[2])
    c.shade("poly", [(49, 34), (51, 33), (51, 54), (49, 56)], IRON, dither=False)
    for (x, y, dx) in ((11, 55, 1), (46, 55, -1)):
        c.fill("rect", (min(x, x + dx * 4), y, max(x, x + dx * 4), y + 3), IRON[1])
        c.fill("rect", (min(x, x + dx), y - 4, max(x, x + dx), y + 3), IRON[1])
        c.put(x + dx * 2, y + 1, BRASS[0])


def chest(open_lid):
    c = Canvas(64, 64)
    if not open_lid:
        _chest_box(c)
        # A rounded lid of curved planks, banded in iron, a brass lock.
        c.shade("poly", [(46, 36), (46, 27), (44, 23), (49, 19), (52, 21), (54, 25), (54, 31)], CHEST_SIDE, dither=False)
        c.shade("poly", [(11, 36), (11, 27), (13, 23), (17, 21), (41, 21), (44, 23), (46, 27), (46, 36)], ramp("cc9c66", "a47a4c", "70502e"), dither=False)
        c.shade("poly", [(17, 21), (22, 17), (46, 17), (49, 19), (44, 23), (41, 21)], ramp("dcb07a", "b88a58", "8e6640"), dither=False)
        for y in (26, 31):
            c.fill("line", (12, y, 45, y), C("4a3220"))
            c.fill("line", (12, y + 1, 45, y + 1), C("d8b080"))
        c.shade("rect", (11, 34, 46, 37), IRON, dither=False)
        c.fill("line", (11, 34, 46, 34), C("d8dce2"))
        c.shade("poly", [(46, 34), (54, 29), (54, 32), (46, 37)], IRON, dither=False)
        for x in (16, 39):
            c.shade("rect", (x, 21, x + 3, 34), IRON, dither=False)
            c.fill("line", (x, 21, x, 34), C("d8dce2"))
            c.fill("line", (x + 2, 21, x + 8, 17), IRON[1])
        # The lock plate: a brass shield with a keyhole and two bolts.
        c.shade("poly", [(25, 31), (33, 31), (33, 39), (29, 43), (25, 39)], BRASS, dither=False)
        c.fill("line", (25, 31, 33, 31), C("fff0b8"))
        c.fill("rect", (28, 34, 30, 35), C("1a120a"))
        c.fill("line", (29, 36, 29, 38), C("1a120a"))
        c.put(26, 32, BRASS[2])
        c.put(32, 32, BRASS[2])
        c.fill("ellipse", (50, 41, 54, 46), IRON[1])
        c.fill("ellipse", (51, 42, 53, 45), CHEST_SIDE[2])
    else:
        # The lid thrown back on its hinges, lined in red cloth; inside, a
        # heap of coins with gems and a cup, catching the light.
        c.shade("poly", [(11, 30), (13, 9), (46, 9), (46, 30)], ramp("cc9c66", "a47a4c", "70502e"), dither=False)
        c.shade("rect", (16, 12, 42, 28), ramp("c0444c", "8a2c37", "5c1c28"), dither=False)
        for x in (16, 39):
            c.shade("rect", (x, 9, x + 3, 30), IRON, dither=False)
        c.fill("line", (13, 9, 46, 9), C("d8dce2"))
        c.shade("poly", [(46, 9), (53, 6), (53, 27), (46, 30)], CHEST_SIDE, dither=False)
        _chest_box(c)
        c.shade("poly", [(11, 36), (46, 36), (54, 31), (46, 31), (11, 31)], ramp("2a1a10", "22140c", "160c06"), dither=False)
        gold = ramp("fff0a0", "f0c050", "a87a20")
        for (x0, y0, x1, y1) in ((13, 27, 27, 37), (23, 24, 39, 36), (34, 26, 50, 36), (19, 29, 31, 36)):
            c.shade("ellipse", (x0, y0, x1, y1), gold)
        # Single coins on the heap: a bright top edge and a dark rim each.
        r = random.Random(63)
        for _ in range(30):
            x, y = r.randrange(15, 47), r.randrange(25, 35)
            if (x, y) in c.filled and (x + 2, y + 1) in c.filled:
                c.fill("rect", (x, y, x + 2, y + 1), gold[1])
                c.fill("line", (x, y, x + 2, y), C("fff6c8"))
                c.fill("line", (x, y + 1, x + 2, y + 1), C("a87a20"))
        for (x, y, col) in ((20, 29, "ff6a7a"), (31, 26, "7ad0ff"), (41, 29, "8aff9a"), (26, 32, "ff6a7a")):
            c.fill("rect", (x, y, x + 1, y + 1), C(col))
            c.put(x, y, C("ffffff"))
        # A goblet half sunk in the coins.
        c.shade("ellipse", (35, 17, 42, 23), gold, dither=False)
        c.fill("line", (36, 18, 41, 18), C("6a4a14"))
        c.fill("line", (38, 23, 38, 26), C("c09030"))
        c.fill("line", (36, 26, 40, 26), C("c09030"))
        for (x, y) in ((24, 25), (33, 23), (45, 27)):
            c.put(x, y, C("ffffff"))
    c.outline()
    return c.img


def altar():
    # A stone altar: a carved block on a stepped base, a cloth runner in
    # deep red, a bronze offering bowl and two amber stones set in front.
    c = Canvas(64, 64)
    c.shadow(32, 60, 24, 3, 70)
    c.shade("rect", (8, 55, 56, 61), ramp("9a96a2", "76727e", "4e4a56"))
    c.fill("line", (8, 55, 56, 55), C("c4c0cc"))
    c.shade("rect", (13, 50, 51, 55), ramp("aaa6b2", "86828e", "5e5a66"))
    c.fill("line", (13, 50, 51, 50), C("cecad6"))
    c.shade("rect", (16, 34, 48, 50), ramp("bcb8c4", "9894a2", "6a6676"), dither=False)
    c.shade("rect", (14, 30, 50, 35), ramp("d2ced8", "b0acba", "7e7a88"), dither=False)
    c.fill("line", (14, 30, 50, 30), C("e6e2ea"))
    for x in (20, 44):
        c.fill("line", (x, 37, x, 47), C("6a6676"))
    c.shade("rect", (26, 30, 38, 49), ramp("c0444c", "8a2c37", "5c1c28"), dither=False)
    c.fill("line", (27, 44, 37, 44), C("e8c070"))
    for x in range(27, 38, 2):
        c.put(x, 49, C("e8c070"))
    c.shade("ellipse", (25, 23, 39, 31), ramp("e8c070", "b8863a", "7a5626"))
    c.fill("ellipse", (27, 24, 37, 27), C("2a1a14"))
    for (x, y) in ((22, 41), (41, 41)):
        c.fill("rect", (x - 1, y - 1, x + 1, y + 1), C("f0a83a"))
        c.put(x - 1, y - 1, C("fff0b8"))
    c.outline()
    return c.img


DECOR = ["floor", "rubble", "statue", "brazier", "banner", "bone_pile", "crate", "barrel", "well", "fence", "lantern",
         "stall", "signpost", "rug", "shelf", "plant_pot", "table", "chair", "candles", "cage", "tent", "obelisk",
         "palisade", "spike_trap", "ballista", "soil", "scarecrow", "torch", "fireplace", "waystone", "waystone_lit", "gravestone", "ruined_tower", "cart",
         "root_cutter", "root_delver", "root_tender", "root_hollow", "farmhouse", "furnace", "trophy_stand",
         "anvil", "weapon_rack", "bench", "hay_bale", "flower_bed", "cupboard", "fountain", "stone_planter",
         "standing_stone", "carved_pillar", "rune_stele", "chime_stone", "stone_pedestal", "stone_shard"]


def sheet(images, w, h):
    out = Image.new("RGBA", (w * len(images), h), (0, 0, 0, 0))
    for i, img in enumerate(images):
        out.paste(img, (i * w, 0))
    return out


if __name__ == "__main__":
    sheet(TALL, 64, 96).save(os.path.join(ROOT, "flora_tall.png"))
    sheet(SMALL, 32, 32).save(os.path.join(ROOT, "flora_small.png"))
    sheet([critter(k, f) for k in CRITTERS for f in range(CRITTER_FRAMES)], 24, 24).save(os.path.join(ROOT, "critters.png"))
    sheet([decor(k) for k in DECOR], 64, 64).save(os.path.join(ROOT, "decor.png"))
