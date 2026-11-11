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
def oak(seed=1):
    c = Canvas(64, 96)
    r = random.Random(seed)
    c.shadow(32, 90, 21, 5)
    trunk(c, 32, 50, 90, 9)
    # Branches reaching into the crown, seen through gaps.
    for (a, b) in [((32, 58), (18, 44)), ((32, 54), (46, 42)), ((32, 50), (30, 30))]:
        c.shade("line", (a[0], a[1], b[0], b[1]), BARK, width=3, dither=False)
    leaves = ramp("6a9a4a", "4a7a3a", "2f5a2a")
    deep = ramp("3f6a34", "2f5a2a", "1f3e1e")
    # A dark inner mass first, then lit clumps over it, for depth.
    canopy(c, [(32, 40, 22, 16), (20, 46, 11, 9), (44, 46, 11, 9)], deep, seed, highlights=False)
    jitter = lambda v: v + r.randint(-2, 2)
    canopy(c, [(jitter(30), 36, 18, 13), (jitter(17), 44, 10, 8), (jitter(47), 44, 10, 8), (jitter(23), 25, 12, 10),
               (jitter(41), 25, 12, 10), (jitter(32), 16, 11, 9)], leaves, seed)
    # Sunlit leaf tips along the top-left of each clump.
    for (cx, cy, rr) in [(23, 25, 12), (32, 16, 11), (17, 44, 10), (30, 36, 18)]:
        for k in range(6):
            a = math.pi * (1.1 + 0.08 * k)
            c.put(cx + math.cos(a) * (rr - 2), cy + math.sin(a) * (rr * 0.8 - 2), C("9aca6a"))
    # Gaps of shadow between clumps and a few hanging leaves.
    for (x, y) in [(26, 34), (38, 33), (31, 45), (22, 40)]:
        c.put(x, y, deep[2]); c.put(x + 1, y, deep[2])
    for x in (16, 27, 44, 49):
        c.put(x, 54 + r.randint(0, 2), leaves[1])
    c.outline()
    return c.img


def dead_tree():
    c = Canvas(64, 96)
    c.shadow(32, 90, 14, 4)
    trunk(c, 32, 30, 90, 7, ramp("8a7a68", "6a5a4a", "4a3e34"))
    for (a, b, w) in [((32, 52), (14, 34), 3), ((14, 34), (8, 22), 2), ((32, 44), (50, 26), 3), ((50, 26), (56, 14), 2),
                      ((32, 32), (26, 12), 2), ((32, 32), (40, 8), 2), ((50, 26), (44, 18), 1), ((14, 34), (20, 26), 1)]:
        c.shade("line", (a[0], a[1], b[0], b[1]), ramp("8a7a68", "6a5a4a", "4a3e34"), width=w, dither=False)
    c.outline()
    return c.img


def pine(snowy, seed=2):
    c = Canvas(64, 96)
    r = random.Random(seed)
    c.shadow(32, 90, 16, 4)
    trunk(c, 32, 70, 90, 6, roots=False)
    greens = ramp("4a7a6a", "2f5a50", "1f3e38")
    tiers = [(6, 7, 24), (14, 11, 36), (24, 15, 50), (35, 19, 64), (47, 23, 78)]
    for k, (top, half, base) in enumerate(tiers):
        # Each tier is a skirt of drooping boughs with a ragged hem.
        hem = []
        steps = 8
        for i in range(steps + 1):
            x = 32 - half + 2 * half * i / steps
            hem.append((x, base + (2 if i % 2 else -1)))
        c.shade("poly", [(32, top)] + hem[::-1][::-1] + [(32 + half, base - 2)][:0], greens)
        c.shade("poly", [(32, top), (32 + half, base), (32 - half, base)], greens)
        for i in range(0, steps + 1, 2):
            x = 32 - half + 2 * half * i / steps
            c.shade("poly", [(x - 2, base - 2), (x + 2, base - 2), (x, base + 2)], greens)
        # A dark band under each tier and needle highlights on the lit side.
        for x in range(int(32 - half + 3), int(32 + half - 2)):
            c.put(x, base - 3, greens[2])
        for i in range(half):
            c.put(32 - i * 0.7 - 1, top + i * (base - top) / half * 0.8, C("6a9a8a"))
        if snowy:
            for x in range(int(32 - half + 1), int(32 + half)):
                if (x + k) % 3 != 0:
                    c.put(x, base - 1 - (1 if (x * 7 + k) % 4 == 0 else 0), C("eef2f6"))
            for x in range(int(32 - half + 3), int(32 + half - 2)):
                if (x + k) % 4 == 0:
                    c.put(x, base - 2, C("dce6ee"))
            c.put(32, top, C("ffffff"))
    for _ in range(3 if not snowy else 0):
        x, y = r.randint(24, 40), r.randint(30, 70)
        c.put(x, y, C("8a5a3a"))
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


def mushrooms(cap, seed=0, glow=False):
    c = Canvas(32, 32)
    r = random.Random(seed)
    for _ in range(3):
        x, h, w = r.randrange(8, 24), r.randrange(4, 9), r.randrange(4, 7)
        c.shade("rect", (x - 1, 30 - h, x + 1, 30), ramp("f2efe2", "cfcbb8", "9b9889"))
        c.shade("ellipse", (x - w, 28 - h - w // 2, x + w, 30 - h + 1), cap)
        c.fill("line", (x - w + 1, 30 - h + 1, x + w - 1, 30 - h + 1), C("e8d8c8"), 1)
        for k in range(2):
            sx = x + r.randrange(-w + 2, w - 1)
            c.put(sx, 29 - h - w // 2 + r.randrange(1, 3), C("ffffff") if glow else C("f2efe2"))
        if glow:
            c.put(x, 29 - h - w // 2, C("ffffff"))
    c.outline()
    return c.img


def rocks(colours, seed=0, shards=False):
    c = Canvas(32, 32)
    r = random.Random(seed)
    for _ in range(3):
        x, y, w = r.randrange(6, 24), r.randrange(18, 28), r.randrange(3, 7)
        if shards:
            c.shade("poly", [(x - w // 2, 30), (x, y - w), (x + w // 2, 30)], colours)
        else:
            c.shade("ellipse", (x - w, y - w // 2, x + w, y + w // 2 + 1), colours)
            if colours[0] == C("a6a2b0") and r.random() < 0.6:
                c.fill("ellipse", (x - w + 1, y - w // 2, x + 1, y), C("6a8a3e"))
            c.put(x - w // 2, y - w // 2 + 1, C("ffffff") if shards else colours[0])
    c.outline()
    return c.img


def bones():
    c = Canvas(32, 32)
    bone = ramp("f2efe2", "cfcbb8", "9b9889")
    c.shade("line", (6, 26, 20, 20), bone, width=2, dither=False)
    c.shade("ellipse", (4, 24, 8, 28), bone)
    c.shade("ellipse", (18, 18, 22, 22), bone)
    c.shade("ellipse", (18, 22, 28, 30), bone)
    c.fill("rect", (21, 24, 22, 25), OUTLINE)
    c.fill("rect", (24, 24, 25, 25), OUTLINE)
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
    r = random.Random(hash(kind) & 0xffff)
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
    rocks(ramp("ffd86b", "f08a2e", "4a3030"), seed=9),                         # 14 embers
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
    c = Canvas(24, 24)
    if kind == "rabbit":
        fur = ramp("c8b8a0", "a08a70", "6a5a48")
        hop = 2 if frame else 0
        c.shade("ellipse", (5, 12 - hop, 17, 20 - hop), fur)
        c.shade("ellipse", (13, 8 - hop, 20, 15 - hop), fur)
        c.shade("rect", (15, 2 - hop, 16, 9 - hop), fur, dither=False)
        c.shade("rect", (18, 3 - hop, 19, 9 - hop), fur, dither=False)
        c.fill("ellipse", (3, 13 - hop, 6, 16 - hop), C("f4f2ec"))
        c.put(18, 11 - hop, OUTLINE)
    elif kind == "bird":
        body = ramp("8a7a6a", "5a4e44", "3a322c")
        c.shade("ellipse", (7, 10, 17, 17), body)
        c.shade("ellipse", (14, 7, 20, 13), body)
        c.put(21, 10, C("f0b030"))
        c.put(17, 9, OUTLINE)
        if frame:
            c.shade("poly", [(9, 11), (4, 2), (14, 10)], body)
        else:
            c.shade("poly", [(9, 12), (3, 16), (14, 14)], body)
    elif kind == "butterfly":
        wing = ramp("ffe08a", "f0a030", "a06018") if frame % 2 == 0 else ramp("ffe08a", "f0a030", "a06018")
        spread = 7 if frame else 3
        c.fill("rect", (11, 8, 12, 16), OUTLINE)
        c.shade("ellipse", (11 - spread - 3, 6, 11, 12), wing)
        c.shade("ellipse", (12, 6, 12 + spread + 3, 12), wing)
        c.shade("ellipse", (11 - spread, 12, 11, 17), wing)
        c.shade("ellipse", (12, 12, 12 + spread, 17), wing)
    elif kind == "frog":
        skin = ramp("8aca6a", "5a9a4a", "3a6a2a")
        sit = 1 if frame else 0
        c.shade("ellipse", (5, 11 - sit * 3, 19, 21 - sit * 3), skin)
        c.fill("ellipse", (7, 9 - sit * 3, 10, 12 - sit * 3), C("f0f0d0"))
        c.fill("ellipse", (14, 9 - sit * 3, 17, 12 - sit * 3), C("f0f0d0"))
        c.put(8, 10 - sit * 3, OUTLINE)
        c.put(15, 10 - sit * 3, OUTLINE)
    if kind != "butterfly":
        c.outline()
    return c.img


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
        r = random.Random(5)
        for _ in range(7):
            x, y, w = r.randrange(10, 54), r.randrange(40, 58), r.randrange(4, 9)
            c.shade("poly", [(x - w, y + 4), (x - w + 2, y - w), (x + w - 1, y - w + 2), (x + w, y + 4)], STONE)
    elif kind == "statue":
        c.shade("rect", (18, 50, 46, 60), STONE)
        c.shade("poly", [(24, 50), (26, 22), (38, 22), (40, 50)], STONE)
        c.shade("ellipse", (26, 8, 38, 22), STONE)
        c.shade("poly", [(38, 26), (48, 14), (50, 16), (40, 32)], STONE)
        c.fill("line", (24, 30, 22, 42), STONE[2], 2)
    elif kind == "brazier":
        c.shade("poly", [(20, 40), (44, 40), (40, 50), (24, 50)], ramp("8a7a68", "5a4a40", "3a3028"))
        c.shade("rect", (30, 50, 34, 60), ramp("8a7a68", "5a4a40", "3a3028"))
        c.shade("rect", (24, 58, 40, 61), ramp("8a7a68", "5a4a40", "3a3028"))
        c.shade("poly", [(22, 40), (26, 28), (30, 34), (32, 18), (35, 32), (38, 26), (42, 40)], ramp("ffd86b", "f08a2e", "b8401e"))
    elif kind == "banner":
        c.shade("rect", (30, 6, 33, 60), WOOD)
        c.shade("rect", (22, 8, 44, 10), WOOD)
        c.shade("poly", [(23, 11), (43, 11), (43, 40), (33, 34), (23, 40)], CLOTH)
        c.shade("poly", [(29, 18), (37, 18), (33, 28)], ramp("f0cf6a", "c09a3c", "866a26"))
    elif kind == "bone_pile":
        bone = ramp("f2efe2", "cfcbb8", "9b9889")
        for (a, b) in [((14, 56), (34, 48)), ((30, 58), (50, 50)), ((20, 50), (40, 56))]:
            c.shade("line", (a[0], a[1], b[0], b[1]), bone, width=3, dither=False)
        c.shade("ellipse", (36, 38, 50, 52), bone)
        c.fill("rect", (39, 43, 41, 45), OUTLINE)
        c.fill("rect", (45, 43, 47, 45), OUTLINE)
    elif kind == "crate":
        c.shade("rect", (16, 28, 48, 60), WOOD)
        c.fill("rect", (16, 28, 48, 30), WOOD[2])
        c.fill("line", (16, 30, 48, 60), WOOD[2], 2)
        c.fill("line", (48, 30, 16, 60), WOOD[2], 2)
    elif kind == "barrel":
        c.shade("ellipse", (18, 22, 46, 62), WOOD)
        for y in (30, 50):
            c.fill("rect", (18, y, 46, y + 2), ramp("8a8794", "6e6b78", "55525e")[1])
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
        c.shade("rect", (30, 14, 33, 62), ramp("4a4650", "33303a", "222028"))
        c.shade("rect", (33, 14, 42, 16), ramp("4a4650", "33303a", "222028"))
        c.shade("rect", (37, 17, 45, 28), ramp("ffe8a0", "f0c050", "a07020"))
        c.fill("rect", (36, 16, 46, 17), OUTLINE)
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
        c.shade("rect", (30, 20, 33, 62), WOOD)
        c.shade("poly", [(14, 18), (46, 18), (52, 24), (46, 30), (14, 30)], WOOD)
    elif kind == "rug":
        c.shade("rect", (4, 20, 60, 50), CLOTH, dither=False)
        c.fill("rect", (8, 24, 56, 46), ramp("f0cf6a", "c09a3c", "866a26")[1])
        c.fill("rect", (11, 27, 53, 43), CLOTH[1])
        c.fill("poly", [(32, 29), (42, 35), (32, 41), (22, 35)], ramp("f0cf6a", "c09a3c", "866a26")[0])
        return c.img
    elif kind == "shelf":
        c.shade("rect", (8, 10, 56, 60), WOOD)
        for y in (22, 38, 54):
            c.fill("rect", (10, y, 54, y + 2), WOOD[2])
        for (x, y, col) in [(14, 14, C("c0303a")), (24, 14, C("5a8af0")), (34, 30, C("f0cf6a")), (44, 46, C("6a9a4a")), (16, 46, C("e0c0ff"))]:
            c.fill("rect", (x, y, x + 5, y + 7), col)
    elif kind == "plant_pot":
        c.shade("poly", [(22, 46), (42, 46), (38, 60), (26, 60)], ramp("d08a5a", "a8643a", "7a4424"))
        canopy(c, [(32, 36, 12, 10), (24, 40, 7, 6), (40, 40, 7, 6)], ramp("6a9a4a", "4a7a3a", "2f5a2a"), 21)
    elif kind == "table":
        c.shade("rect", (10, 30, 54, 38), WOOD)
        c.shade("rect", (12, 38, 15, 58), WOOD)
        c.shade("rect", (49, 38, 52, 58), WOOD)
        c.shade("ellipse", (26, 24, 38, 31), ramp("f4f2ec", "d4d0c4", "a8a498"))
    elif kind == "chair":
        c.shade("rect", (22, 14, 42, 18), WOOD)
        c.shade("rect", (22, 18, 25, 58), WOOD)
        c.shade("rect", (39, 18, 42, 58), WOOD)
        c.shade("rect", (22, 38, 42, 42), WOOD)
    elif kind == "candles":
        for (x, h) in [(24, 14), (32, 20), (40, 11)]:
            c.shade("rect", (x - 2, 58 - h, x + 2, 58), ramp("f4f2ec", "d4d0c4", "a8a498"))
            c.fill("poly", [(x - 1, 57 - h), (x, 51 - h), (x + 1, 57 - h)], C("ffd86b"))
    elif kind == "cage":
        c.shade("rect", (14, 14, 50, 18), ramp("6a6670", "4a4650", "2a2830"))
        c.shade("rect", (14, 56, 50, 60), ramp("6a6670", "4a4650", "2a2830"))
        for x in range(16, 50, 6):
            c.fill("rect", (x, 18, x + 1, 56), C("4a4650"))
        c.shade("ellipse", (26, 42, 38, 56), ramp("f2efe2", "cfcbb8", "9b9889"))
    elif kind == "tent":
        c.shade("poly", [(4, 60), (32, 8), (60, 60)], ramp("b0a080", "8a7a5a", "5a4e3a"))
        c.fill("poly", [(26, 60), (32, 36), (38, 60)], C("201a1c"))
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
    c.outline()
    return c.img


DECOR = ["floor", "rubble", "statue", "brazier", "banner", "bone_pile", "crate", "barrel", "well", "fence", "lantern",
         "stall", "signpost", "rug", "shelf", "plant_pot", "table", "chair", "candles", "cage", "tent", "obelisk",
         "palisade", "spike_trap", "ballista", "soil", "scarecrow"]


def sheet(images, w, h):
    out = Image.new("RGBA", (w * len(images), h), (0, 0, 0, 0))
    for i, img in enumerate(images):
        out.paste(img, (i * w, 0))
    return out


if __name__ == "__main__":
    sheet(TALL, 64, 96).save(os.path.join(ROOT, "flora_tall.png"))
    sheet(SMALL, 32, 32).save(os.path.join(ROOT, "flora_small.png"))
    sheet([critter(k, f) for k in CRITTERS for f in (0, 1)], 24, 24).save(os.path.join(ROOT, "critters.png"))
    sheet([decor(k) for k in DECOR], 64, 64).save(os.path.join(ROOT, "decor.png"))
