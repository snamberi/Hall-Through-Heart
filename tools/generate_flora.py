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
def oak(seed=1, wide=1.0, lift=0):
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
    leaves = ramp("6a9a4a", "4a7a3a", "2f5a2a")
    deep = ramp("3f6a34", "2f5a2a", "1f3e1e")
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
            c.put(cx + math.cos(a) * (rr - 2), cy + math.sin(a) * (rr * 0.8 - 2), C("9aca6a"))
        # A shadowed underside to each clump separates it from the next.
        for k in range(-rr + 3, rr - 2, 2):
            if (cx + k, cy + int(rr * 0.75)) in c.filled:
                c.put(cx + k, cy + int(rr * 0.75), deep[2])
    for x in (16, 27, 44, 49):
        c.put(sx(x), 54 - lift + r.randint(0, 2), leaves[1])
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
        # An iron bowl on a stand, coals glowing in it; the flame is animated
        # in game (tools/generate_fire.py).
        iron = ramp("7a7680", "4e4a56", "2c2a32")
        c.shade("rect", (23, 58, 41, 61), iron)
        c.shade("poly", [(26, 58), (30, 48), (34, 48), (38, 58)], iron)
        c.shade("rect", (30, 46, 34, 50), iron)
        c.shade("poly", [(18, 39), (46, 39), (42, 47), (22, 47)], iron)
        c.fill("rect", (18, 38, 46, 39), C("9a96a2"))
        c.fill("ellipse", (21, 37, 43, 42), C("2a1a14"))
        for (x, y, col) in [(24, 39, "f08a2e"), (28, 38, "ffd86b"), (31, 39, "c8361a"), (35, 38, "f08a2e"), (39, 39, "ffd86b"), (33, 40, "fff2a8")]:
            c.put(x, y, C(col))
            c.put(x + 1, y, C(col))
        for x in (20, 44):
            c.fill("rect", (x - 1, 40, x, 44), C("9a96a2"))
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
        c.shade("poly", [(24, 62), (26, 12), (32, 4), (38, 12), (40, 62)], ramp("5a5668", "3a3748", "2a2836"))
        for y in range(18, 56, 9):
            c.fill("rect", (30, y, 34, y + 3), C("9a6cf0"))
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
    elif kind == "ballista":                      # a wooden bolt-thrower on a stand
        c.shade("poly", [(20, 60), (28, 40), (36, 40), (44, 60)], WOOD)
        c.shade("rect", (16, 58, 48, 62), WOOD)
        c.shade("rect", (14, 30, 50, 36), ramp("7a5a44", "5a4032", "3b2a22"))
        c.shade("poly", [(10, 26), (14, 30), (14, 36), (8, 40)], WOOD)
        c.shade("poly", [(54, 26), (50, 30), (50, 36), (56, 40)], WOOD)
        c.fill("line", (8, 40, 32, 34), C("d8d0c0"), 1)
        c.fill("line", (56, 40, 32, 34), C("d8d0c0"), 1)
        c.shade("rect", (30, 14, 34, 34), ramp("eef0f0", "b4bcc2", "7d8890"))
        c.shade("poly", [(28, 16), (32, 6), (36, 16)], ramp("eef0f0", "b4bcc2", "7d8890"))
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
    c.outline()
    return c.img


DECOR = ["floor", "rubble", "statue", "brazier", "banner", "bone_pile", "crate", "barrel", "well", "fence", "lantern",
         "stall", "signpost", "rug", "shelf", "plant_pot", "table", "chair", "candles", "cage", "tent", "obelisk",
         "palisade", "spike_trap", "ballista", "soil", "scarecrow", "torch", "fireplace", "waystone", "waystone_lit", "gravestone", "ruined_tower", "cart"]


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
