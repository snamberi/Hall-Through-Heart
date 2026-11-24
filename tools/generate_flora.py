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
    """A canopy built of overlapping leaf clumps, then leaf texture: small
    tufts of leaves, each a little arc lit on top, so the crown reads as
    leaves and not as noise."""
    r = random.Random(seed)
    pts = []
    for (cx, cy, rx, ry) in blobs:
        pts += c.shade("ellipse", (cx - rx, cy - ry, cx + rx, cy + ry), colours)
    if highlights:
        have = set(pts)
        for (cx, cy, rx, ry) in blobs:
            for gy in range(int(cy - ry) + 2, int(cy + ry) - 1, 4):
                for gx in range(int(cx - rx) + 2 + (gy // 4) % 2 * 2, int(cx + rx) - 1, 4):
                    if (gx, gy) not in have or (gx, gy + 2) not in have:
                        continue
                    # Which side of the clump this tuft is on: lit or shaded.
                    t = (gx - cx) / rx * -0.6 + (gy - cy) / ry * -0.8
                    top = colours[0] if t > -0.1 else colours[1]
                    under = colours[2]
                    gx += r.randint(-1, 1)
                    gy += r.randint(-1, 0)
                    if r.random() < 0.72:
                        c.put(gx - 1, gy + 1, top)
                        c.put(gx, gy, top)
                        c.put(gx + 1, gy + 1, top)
                        c.put(gx, gy + 2, under)


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
    """A towering toadstool: a swollen, root-gripped foot in moss, a pale
    stalk with a torn gill skirt hanging from it, a domed cap in two tiers of
    violet-rose with raised warts, a gilled underside in shadow, and a few
    little ones sprouting at its foot."""
    rnd = random.Random(seed)
    c = Canvas(64, 96)
    c.shadow(32, 90, 20, 5)
    stalk = ramp("f0e8d4", "cfc2a4", "948664")
    # Roots splaying from the foot, then the swollen foot itself.
    root = ramp("b8a882", "8a7c5c", "5e5440")
    for (x0, x1, y1) in [(26, 15, 90), (29, 22, 92), (36, 44, 92), (38, 50, 89)]:
        c.shade("line", [(x0, 84), (x1, y1)], root, width=2, dither=False)
    c.shade("ellipse", (21, 74, 43, 91), stalk)
    # The stalk, a little bent, narrowing up to the cap.
    c.shade("poly", [(24, 82), (25, 64), (27, 50), (29, 42), (37, 42), (38, 50), (39, 64), (41, 82)], stalk)
    # Fibres along the stalk.
    for (x, y0, y1) in [(28, 50, 70), (31, 46, 78), (35, 52, 74), (38, 60, 80)]:
        for y in range(y0, y1, 3):
            c.put(x + (1 if y % 6 == 0 else 0), y, C("b8aa88"))
    # The skirt: a torn ring of gill-flesh hanging from under the cap.
    skirt = ramp("e8dcc0", "c4b490", "8a7a5a")
    c.shade("poly", [(25, 50), (39, 50), (42, 56), (39, 55), (37, 59), (34, 55), (31, 60), (29, 55), (26, 58), (22, 56)], skirt)
    c.fill("line", [(25, 51), (39, 51)], C("faf2e0"))
    # Moss on the foot.
    moss = ramp("8ab05a", "5a8040", "345030")
    for (x, y, r) in [(22, 86, 4), (40, 87, 4), (31, 89, 3), (19, 89, 2)]:
        c.shade("ellipse", (x - r, y - r + 1, x + r, y + r - 1), moss)
    # Under the cap: dark gills fanning from the stalk.
    c.fill("ellipse", (7, 36, 57, 50), C("4a1e3a"))
    gill = C("6e3456")
    for k in range(-11, 12):
        x = 32 + k * 2
        c.fill("line", [(32 + k // 3, 44), (x, 39 + abs(k) // 4)], gill)
    # The cap: a broad lower tier, then a higher dome over it.
    cap = ramp("e080b0", "b04e86", "6e2a56")
    c.shade("ellipse", (4, 22, 60, 46), cap)
    c.shade("ellipse", (12, 10, 52, 38), ramp("ec92bc", "bc5a90", "7a3060"))
    # A lip of shade where the dome sits on the brim, and a lit rim.
    for x in range(14, 51):
        dy = int(round(((x - 32) / 20.0) ** 2 * 5))
        c.put(x, 35 - dy + 2, C("8a3a68"))
    for x in range(10, 30):
        dy = int(round(((x - 32) / 28.0) ** 2 * 7))
        c.put(x, 25 + dy - 1, C("f6b4d4"))
    c.fill("line", [(20, 13), (30, 11)], C("fcd0e4"))
    c.fill("line", [(16, 17), (19, 14)], C("fcd0e4"))
    # The rim curls under: a band of darker flesh along the edge.
    for x in range(6, 59):
        t = (x - 32) / 27.0
        y = int(round(34 + (1 - t * t) ** 0.5 * 11))
        c.put(x, y, C("5a2246"))
        c.put(x, y - 1, C("8a3a68"))
    # Raised warts, each with a shadow, a body and a bright top.
    spots = [(20, 18, 4), (33, 15, 5), (44, 20, 4), (26, 27, 3), (39, 28, 3), (12, 33, 3), (51, 33, 3), (31, 35, 2), (22, 37, 2), (46, 38, 2)]
    for (x, y, r) in spots:
        c.fill("ellipse", (x - r + 1, y - r + 2, x + r + 1, y + r + 1), C("7a3060"))
        c.fill("ellipse", (x - r, y - r + 1, x + r, y + r), C("e8d4dc"))
        c.fill("ellipse", (x - r, y - r + 1, x + r - 1, y + r - 1), C("fff4f8"))
        if r >= 3:
            c.put(x + r - 1, y + r - 1, C("c0a8b8"))
    c.outline()
    # Two little ones at the foot (drawn after the outline: their own).
    for (x, h, w, col) in [(13, 9, 5, ("e080b0", "b04e86", "6e2a56")), (49, 7, 4, ("ec92bc", "bc5a90", "7a3060")), (54, 5, 3, ("e080b0", "b04e86", "6e2a56"))]:
        small = Canvas(64, 96)
        small.shade("rect", (x - 1, 91 - h, x + 1, 91), stalk, dither=False)
        small.shade("ellipse", (x - w, 91 - h - w, x + w, 91 - h + 2), ramp(*col))
        small.put(x - 1, 91 - h - w + 2, C("fff4f8"))
        small.put(x + 1, 91 - h - 1, C("fff4f8"))
        small.outline()
        c.img.alpha_composite(small.img)
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
    """The jungle's hanging tree: a mossy, twisted trunk, a broad crown, and
    leafy vines falling from it: each vine a wavering strand with leaves
    set left and right along it, some ending in a curl or a pale flower,
    and a liana looping between the boughs."""
    c = Canvas(64, 96)
    r = random.Random(seed)
    c.shadow(32, 90, 21, 5)
    trunk(c, 32, 46, 90, 10, DARK_BARK)
    # Moss on the trunk's lit side and a few buttress roots.
    moss = ramp("8ab05a", "5e8a40", "3c6030")
    for (y0, y1) in ((52, 60), (66, 72), (78, 84)):
        c.shade("ellipse", (27, y0, 31, y1), moss, dither=False)
    for (x0, x1) in ((20, 26), (38, 44)):
        c.shade("poly", [(x0, 91), (32, 76), (x1, 91)], DARK_BARK, dither=False)
    green = ramp("86a85e", "5e8048", "3a5834")
    deep = ramp("4e7040", "3a5834", "263e24")
    canopy(c, [(32, 30, 24, 15), (20, 22, 12, 9), (44, 22, 12, 9)], deep, seed, highlights=False)
    canopy(c, [(32, 26, 21, 12), (19, 20, 10, 8), (45, 20, 10, 8), (32, 14, 13, 8)], green, seed)
    vine = ramp("7ea85a", "4e7a3a", "2e4e26")
    leaf = C("9ac86a")
    # A liana slung between the boughs.
    for k in range(0, 31):
        x = 17 + k
        y = 40 + int(4 * math.sin(k / 30 * math.pi))
        c.put(x, y, vine[2])
        if k % 4 == 0:
            c.put(x, y + 1, leaf)
    # Hanging vines, each its own length and sway.
    for x in range(11, 55, 3):
        length = r.randrange(14, 40)
        phase = r.random() * 6.0
        top = 36 + r.randrange(-3, 3)
        for k in range(length):
            vx = x + int(round(math.sin(k * 0.35 + phase) * 1.0))
            vy = top + k
            c.put(vx, vy, vine[1] if k % 3 else vine[2])
            if k % 4 == 2:
                side = 1 if (k // 4) % 2 else -1
                c.put(vx + side, vy, leaf if k < length - 3 else vine[0])
                c.put(vx + side * 2, vy - 1, vine[0])
        end = (x + int(round(math.sin(length * 0.35 + phase))), top + length)
        if r.random() < 0.35:
            c.put(end[0], end[1], C("f0e4c8"))
            c.put(end[0] + 1, end[1], C("e8c0d0"))
        elif r.random() < 0.5:
            c.put(end[0] + 1, end[1] - 1, vine[2])
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


def calm(colour):
    """A flower colour toned down to sit with the land: less saturated,
    reds most of all, turned a touch toward rose and brick rather than
    shouting scarlet; whites and near-greys are left as they are."""
    import colorsys
    r, g, b, a = colour
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if s < 0.15:
        return colour
    red = h < 0.045 or h > 0.93
    s *= 0.6 if red else 0.78
    v *= 0.88 if red else 0.95
    if red:
        h = (h - 0.012) % 1.0
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255), a)


def flower(kind, petals, centre=None, seed=0):
    """A clump of flowers: leaves at the foot, two or three stems of
    different heights, each with a shaded head. Colours are calmed (see
    calm) so a meadow is gentle, not loud."""
    petals = tuple(calm(p) for p in petals)
    centre = calm(centre) if centre else None
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


# ----------------------------------------------------------------- phase 4 plants
def fern(colours, seed=0, frost=False):
    """A fern: arching fronds from one crown, each with paired leaflets,
    lit on the upper side."""
    c = Canvas(32, 32)
    r = random.Random(seed)
    base = (16, 29)
    for k, ang in enumerate((-2.95, -2.35, -1.62, -0.85, -0.2)):
        length = r.randint(13, 17)
        pts = []
        for s_ in range(length):
            t = s_ / length
            # Up and out from the crown, then arching over at the tip.
            a = ang + (-0.9 if ang < -1.57 else 0.9) * t * t
            x = base[0] + math.cos(a) * s_
            y = base[1] + math.sin(a) * s_ * 1.15
            pts.append((x, y))
            c.put(x, y, colours[1])
        # Paired leaflets along the stem, shorter toward the tip.
        for j, (x, y) in enumerate(pts[2:], 2):
            if j % 3 == 0:
                size = 1 if j > length * 0.6 else 2
                dx, dy = pts[j][0] - pts[j - 1][0], pts[j][1] - pts[j - 1][1]
                for d in range(1, size + 1):
                    c.put(x - dy * d, y + dx * d, colours[0])
                    c.put(x + dy * d, y - dx * d, colours[2])
        if frost:
            tx, ty = pts[-1]
            c.put(tx, ty, C("f4f8ff"))
    _outline_tinted(c, (16, 24, 14))
    return c.img


def bulrushes(seed=0):
    """Reeds with brown bulrush heads, a little water at their feet."""
    c = Canvas(32, 32)
    r = random.Random(seed)
    c.fill("ellipse", (6, 27, 26, 31), C("2a3a40", 150))
    for k in range(7):
        x = 7 + k * 3 + r.randint(-1, 1)
        h = r.randint(13, 22)
        lean = r.choice((-1, 0, 1))
        for y in range(30 - h, 30):
            t = (30 - y) / h
            c.put(x + (lean if t > 0.6 else 0), y, C("8aaa5a") if t > 0.7 else C("5a8a44") if t > 0.3 else C("3a5a2a"))
        if k % 2 == 0:
            hx, hy = x + lean, 30 - h
            for d in range(4):
                c.put(hx, hy + d, C("8a5a30") if d else C("b07a48"))
                c.put(hx + 1, hy + d, C("5e3a1e"))
    _outline_tinted(c, (18, 22, 14))
    return c.img


def ivy(seed=0):
    """Ivy creeping over the ground: a wandering vine with heart-shaped leaves."""
    c = Canvas(32, 32)
    r = random.Random(seed)
    x, y = 3.0, 24.0
    for s_ in range(30):
        x += 0.9
        y += r.choice((-1, 0, 0, 1)) * 0.6
        c.put(x, y, C("4a6a2a"))
        if s_ % 4 == 0:
            lx, ly = x + r.choice((-1, 1)), y - 2 if s_ % 8 == 0 else y + 2
            for dx, dy, col in ((0, 0, "6a9a44"), (1, 0, "8aba5a"), (-1, 0, "4a7a34"), (0, 1, "3a5a2a"), (0, -1, "8aba5a")):
                c.put(lx + dx, ly + dy, C(col))
    _outline_tinted(c, (16, 24, 14))
    return c.img


def leaf_litter(colours, seed=0):
    """Fallen leaves lying on the forest floor, each a tiny lit oval."""
    c = Canvas(32, 32)
    r = random.Random(seed)
    for _ in range(16):
        x, y = r.randint(3, 28), r.randint(14, 29)
        col = colours[r.randrange(3)]
        c.put(x, y, col)
        c.put(x + 1, y, col)
        c.put(x, y - 1, colours[0])
        c.put(x + 1, y + 1, colours[2])
    return c.img


def nettles(seed=0):
    c = Canvas(32, 32)
    r = random.Random(seed)
    for k in range(5):
        x = 8 + k * 4 + r.randint(-1, 1)
        h = r.randint(9, 15)
        for y in range(30 - h, 30):
            c.put(x, y, C("4a7a34"))
            if (y - (30 - h)) % 3 == 0:
                c.put(x - 1, y, C("6a9a44"))
                c.put(x + 1, y + 1, C("3a5a2a"))
                c.put(x - 2, y + 1, C("8aba5a"))
    _outline_tinted(c, (16, 24, 14))
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
    if not glow:
        cap = tuple(calm(x) for x in cap)
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
    fern(ramp("8aba5a", "5a8a3a", "34582a"), seed=21),                         # 52 fern
    fern(ramp("a8c8c0", "6a8a84", "3e5a56"), seed=22, frost=True),             # 53 frost fern
    bulrushes(seed=23),                                                        # 54 bulrushes
    ivy(seed=24),                                                              # 55 ivy
    leaf_litter(ramp("d89a4a", "b06a2a", "7a4420"), seed=25),                  # 56 fallen leaves
    leaf_litter(ramp("8a7a4a", "6a5a34", "4a3e24"), seed=26),                  # 57 dry leaf litter
    nettles(seed=27),                                                          # 58 nettles
]


# ----------------------------------------------------------------- critters
def critter(kind, frame):
    """One 24x24 frame. Frames 0-1 are at rest (1 is a small idle movement),
    frames 2-3 are in motion: a hop, a wingbeat, a leap. Frames 4-7 are a
    pet's fidgets (see critter_fidget): a scratch in two frames, a yawn,
    and curled up asleep."""
    if frame >= 4:
        return critter_fidget(kind, frame - 4)
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
        # Seen from above: a slim dark body, and four crisp wings with a dark
        # rim, a pale eye-spot and veins, beating open, half, shut, half.
        fore = (C("f4d08a"), C("e0a050"), C("9a6028"))
        hind = (C("e8b878"), C("c88a44"), C("7a4c20"))
        rim = C("3a2416")
        open_ = [4, 3, 1, 3][frame]
        for side in (-1, 1):
            x0 = 11 if side < 0 else 12
            if open_ >= 2:
                xa, xb = sorted((x0 + side * 1, x0 + side * (open_ + 4)))
                c.shade("poly", [(x0 + side, 9), (x0 + side * (open_ + 4), 5), (x0 + side * (open_ + 5), 8), (x0 + side * 2, 12)], fore, dither=False)
                c.shade("poly", [(x0 + side, 12), (x0 + side * (open_ + 3), 13), (x0 + side * (open_ + 2), 17), (x0 + side, 15)], hind, dither=False)
                c.put(x0 + side * (open_ + 2), 7, C("fff4dc"))
                c.put(x0 + side * (open_ + 4), 6, rim)
                c.put(x0 + side * (open_ + 5), 8, rim)
                c.put(x0 + side * (open_ + 2), 16, rim)
                c.fill("line", (x0 + side * 2, 10, x0 + side * (open_ + 3), 7), fore[2])
            else:
                # Wings shut: seen edge-on, a thin upright pair.
                c.fill("rect", (x0 + side, 6, x0 + side, 13), fore[1])
                c.put(x0 + side, 6, rim)
        c.fill("rect", (11, 8, 12, 16), C("2a1c14"))
        c.put(11, 8, C("5a4434"))
        c.put(10, 6, rim); c.put(9, 5, rim); c.put(13, 6, rim); c.put(14, 5, rim)
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


def critter_fidget(kind, step):
    """A pet at its ease: 0-1 a scratch (a hind foot at the ear, a beak in
    the wing, antennae cleaned, an eye rubbed), 2 a yawn, 3 asleep."""
    c = Canvas(24, 24)
    closed = C("3a2a22")
    if kind == "rabbit":
        fur = ramp("d2c2a8", "a8927a", "6e5c4a")
        belly = ramp("f4efe4", "ddd4c4", "b8ac9a")
        inner = C("e8a0a0")
        if step < 2:
            # Sitting, head tipped to the hind foot reaching up to scratch an ear.
            reach = 0 if step == 0 else 1
            c.shade("ellipse", (4, 12, 15, 21), fur)
            c.shade("ellipse", (10, 13, 17, 21), fur)
            c.shade("ellipse", (12, 16, 17, 21), belly)
            c.shade("ellipse", (12, 8, 19, 15), fur)
            c.shade("poly", [(13, 10), (10, 3), (12, 2), (15, 9)], fur, dither=False)
            c.shade("poly", [(16, 9), (17, 2), (19, 2), (18, 10)], fur, dither=False)
            c.put(12, 5, inner); c.put(12, 6, inner); c.put(18, 4, inner); c.put(18, 5, inner)
            # The hind leg, from the haunch up past the cheek to the ear,
            # quivering: drawn darker so it stands off the body.
            leg = ramp("b8a68c", "8e7a62", "5e4c3c")
            c.shade("poly", [(6, 18), (8, 12), (11, 7 + reach), (13, 6 + reach), (12, 9 + reach), (10, 14), (9, 18)], leg, dither=False)
            c.fill("rect", (12, 5 + reach, 14, 6 + reach), leg[2])
            c.put(14, 4 + reach, leg[2])
            c.fill("ellipse", (2, 14, 5, 17), C("f8f6f0"))
            c.fill("rect", (13, 20, 17, 21), fur[2])
            c.put(16, 11, closed); c.put(17, 11, closed); c.put(19, 12, C("e08080"))
        elif step == 2:
            # A yawn: head up, ears laid back, mouth wide.
            c.shade("ellipse", (4, 12, 15, 21), fur)
            c.shade("ellipse", (10, 13, 17, 21), fur)
            c.shade("ellipse", (12, 16, 17, 21), belly)
            c.shade("ellipse", (13, 6, 20, 13), fur)
            c.shade("poly", [(14, 7), (9, 3), (10, 2), (16, 6)], fur, dither=False)
            c.shade("poly", [(15, 7), (11, 1), (13, 1), (17, 6)], fur, dither=False)
            c.put(11, 3, inner); c.put(13, 2, inner)
            c.fill("ellipse", (2, 14, 5, 17), C("f8f6f0"))
            c.fill("rect", (13, 20, 17, 21), fur[2]); c.fill("rect", (6, 20, 11, 21), fur[2])
            c.put(17, 8, closed); c.put(18, 8, closed)
            c.fill("rect", (18, 10, 20, 12), C("5a2a2a")); c.put(19, 11, C("e87878")); c.put(20, 10, C("ffffff"))
        else:
            # Asleep: a round loaf, ears flat along the back, eyes shut.
            c.shade("ellipse", (3, 14, 18, 21), fur)
            c.shade("ellipse", (11, 17, 17, 21), belly)
            c.shade("ellipse", (12, 12, 19, 18), fur)
            c.shade("poly", [(13, 13), (5, 12), (5, 13), (13, 15)], fur, dither=False)
            c.shade("poly", [(14, 12), (6, 10), (6, 11), (14, 14)], fur, dither=False)
            c.put(7, 11, inner); c.put(8, 13, inner)
            c.fill("ellipse", (1, 15, 4, 18), C("f8f6f0"))
            c.put(16, 15, closed); c.put(17, 15, closed); c.put(19, 16, C("e08080"))
    elif kind == "bird":
        body = ramp("8a7a6a", "5e5248", "3c3430")
        breast = ramp("e89060", "c06a40", "8a4428")
        wing = ramp("6a5c50", "463c36", "2c2624")
        beak = C("f0b030")
        if step < 2:
            # Preening: head turned back into a lifted wing.
            lift = 1 if step == 1 else 0
            c.shade("ellipse", (6, 10, 17, 18), body)
            c.shade("ellipse", (10, 12, 17, 18), breast)
            c.shade("poly", [(7, 11 - lift), (15, 11), (12, 16), (4, 14 - lift)], wing)
            c.shade("poly", [(6, 13), (1, 15), (2, 17), (7, 16)], wing, dither=False)
            c.shade("ellipse", (8, 6, 14, 12), body)
            c.put(7, 10 + lift, beak); c.put(6, 11 + lift, beak)
            c.put(11, 8, OUTLINE)
            c.fill("rect", (10, 19, 10, 21), beak); c.fill("rect", (13, 19, 13, 21), beak)
            c.put(11, 21, beak); c.put(14, 21, beak)
        elif step == 2:
            # A yawn with a wing stretched out behind.
            c.shade("ellipse", (6, 10, 17, 18), body)
            c.shade("ellipse", (10, 12, 17, 18), breast)
            c.shade("poly", [(8, 11), (1, 6), (2, 9), (0, 11), (4, 13), (9, 14)], wing)
            c.shade("poly", [(6, 13), (1, 15), (2, 17), (7, 16)], wing, dither=False)
            c.shade("ellipse", (13, 4, 19, 10), body)
            c.put(20, 6, beak); c.put(21, 5, beak); c.put(20, 8, beak); c.put(21, 8, C("b07818")); c.put(20, 7, C("5a2a2a"))
            c.put(17, 6, closed)
            c.fill("rect", (10, 19, 10, 21), beak); c.fill("rect", (13, 19, 13, 21), beak)
            c.put(11, 21, beak); c.put(14, 21, beak)
        else:
            # Asleep: fluffed round, the head sunk in, the feet hidden.
            c.shade("ellipse", (5, 11, 18, 21), body)
            c.shade("ellipse", (10, 14, 17, 21), breast)
            c.shade("poly", [(6, 13), (14, 12), (12, 18), (5, 17)], wing)
            c.shade("poly", [(6, 15), (1, 17), (2, 19), (7, 18)], wing, dither=False)
            c.shade("ellipse", (12, 9, 18, 15), body)
            c.put(18, 13, beak); c.put(19, 13, beak)
            c.put(15, 12, closed); c.put(16, 12, closed)
    elif kind == "butterfly":
        if step == 2:
            # A stretch: the wings opened wide, as in flight.
            return critter("butterfly", 0)
        if step != 2:
            # Wings shut upright over the back, seen side on: the pale
            # undersides with their veins and an eye-spot; it cleans its
            # antennae in turn, or rests with them laid back (asleep).
            pale = ramp("f6e2a0", "dcb868", "a07c38")
            c.shade("poly", [(12, 16), (5, 4), (7, 2), (11, 3), (14, 9), (14, 16)], pale, dither=False)
            c.shade("poly", [(12, 16), (7, 12), (6, 17), (9, 19), (13, 18)], pale, dither=False)
            for x, y in ((8, 5), (9, 7), (10, 9), (11, 11)):
                c.put(x, y, C("b08a40"))
            c.put(8, 14, C("b08a40")); c.put(9, 16, C("b08a40"))
            c.fill("rect", (7, 4, 8, 5), C("6a4a1c")); c.put(8, 4, C("fff6d0"))
            c.outline()
            c.fill("rect", (13, 10, 14, 18), OUTLINE)
            if step == 0:
                c.put(15, 9, OUTLINE); c.put(16, 8, OUTLINE); c.put(17, 7, OUTLINE)
                c.put(15, 10, OUTLINE); c.put(16, 11, OUTLINE)
            elif step == 1:
                c.put(15, 9, OUTLINE); c.put(16, 9, OUTLINE); c.put(17, 8, OUTLINE)
                c.put(15, 10, OUTLINE); c.put(16, 10, OUTLINE); c.put(17, 11, OUTLINE)
            else:
                c.put(15, 10, OUTLINE); c.put(16, 11, OUTLINE); c.put(17, 12, OUTLINE)
            for x in (13, 15):
                c.put(x, 19, OUTLINE)
        elif step == 2:
            # A slow fan of the wings, half open.
            for side in (-1, 1):
                x0 = 11 if side < 0 else 12
                c.shade("ellipse", (min(x0, x0 + side * 6), 5, max(x0, x0 + side * 6), 12), wing)
                c.shade("ellipse", (min(x0, x0 + side * 4), 11, max(x0, x0 + side * 4), 17), wing)
            c.put(10, 7, OUTLINE); c.put(9, 6, OUTLINE); c.put(13, 7, OUTLINE); c.put(14, 6, OUTLINE)
    elif kind == "frog":
        skin = ramp("9ad870", "5aa048", "356a2a")
        belly = ramp("e8f0c0", "c8d8a0", "98b070")
        dark = C("2e5a24")
        low = 2 if step == 3 else 0
        c.shade("ellipse", (5, 12 + low, 18, 20), skin)
        c.shade("ellipse", (8, 15 + low, 15, 20), belly)
        for side in (-1, 1):
            kx = 5 if side < 0 else 18
            c.shade("ellipse", (kx - 3, 14 + low, kx + 3, 20), skin)
            c.fill("rect", (min(kx, kx + side * 4), 20, max(kx, kx + side * 4), 21), skin[1])
            c.put(kx + side * 5, 21, skin[2]); c.put(kx + side * 4, 22, skin[2])
        if step < 2:
            # A hind foot up to rub an eye.
            rub = 0 if step == 0 else 1
            c.shade("poly", [(16, 17), (19, 10 + rub), (21, 10 + rub), (19, 18)], skin, dither=False)
            c.fill("rect", (18, 9 + rub, 20, 9 + rub), skin[2])
        c.shade("ellipse", (6, 8 + low, 10, 12 + low), skin, dither=False)
        c.shade("ellipse", (13, 8 + low, 17, 12 + low), skin, dither=False)
        if step == 3 or (step < 2 and False):
            # Lids shut.
            c.fill("rect", (7, 10 + low, 9, 10 + low), dark); c.fill("rect", (14, 10 + low, 16, 10 + low), dark)
        elif step == 2:
            c.fill("rect", (7, 10, 9, 10), dark); c.fill("rect", (14, 10, 16, 10), dark)
        else:
            c.fill("ellipse", (7, 9, 9, 11), C("f4e060")); c.put(8, 10, OUTLINE)
            c.fill("rect", (14, 10, 16, 10), dark)
        if step == 2:
            # The yawn: the wide mouth open.
            c.fill("rect", (8, 13, 15, 15), C("6a2a2a")); c.fill("rect", (9, 14, 14, 14), C("e87878"))
        else:
            c.fill("rect", (9, 15 + low // 2, 14, 15 + low // 2), dark)
        front = [9, 14]
        for fx in front:
            c.fill("rect", (fx, 19, fx, 21), skin[1]); c.put(fx, 22, skin[2])
    if kind != "butterfly":
        c.outline()
    return c.img


CRITTER_FRAMES = 8
CRITTERS = ["rabbit", "bird", "butterfly", "frog"]


# ----------------------------------------------------------------- decor
STONE = ramp("a6a2b0", "7c7888", "56525e")
WOOD = ramp("9a7a58", "6b4f36", "4a3626")
CLOTH = ramp("c05a5a", "8a2c37", "5c1c28")




# ----------------------------------------------------------------------
# Props redrawn with more care: every plank, stone and stitch placed, a
# ground shadow under each, light from the upper left, and the outline the
# sheet gives everything. (They replace the older, plainer ones of the same
# name; the frame numbers do not change.)
# ----------------------------------------------------------------------

PLANK = ramp("c09468", "8e6640", "5e4028")
PLANK_TOP = ramp("d8b080", "a8805a", "7a5638")
PLANK_SIDE = ramp("8a6440", "64462c", "40301e")
IRON = ramp("9a98a4", "62606c", "3a3844")
SOILR = ramp("7a5636", "553a24", "3a2618")
STRAW_R = ramp("f0d878", "c8a448", "8a6c2c")
BURLAP = ramp("d8c098", "b09870", "7a6448")
CANVAS_R = ramp("e8dcc0", "c4b494", "8e7e64")
TERRA = ramp("e08a5a", "b0603a", "783c24")
LEAFR = ramp("8acc68", "58944a", "34602e")


def _nails(c, spots, colour="2a2220"):
    for (x, y) in spots:
        c.put(x, y, C(colour))


def prop_crate(c):
    # A shipping crate in three-quarter view: three wide planks a face with
    # dark gaps, a cross brace on the front, a lit top of boards, iron
    # corner straps with rivets, and a stencilled mark.
    c.shadow(33, 60, 20, 3, 90)
    c.shade("poly", [(12, 28), (40, 28), (52, 21), (24, 21)], PLANK_TOP)
    for x in (19, 26, 33):
        c.fill("line", (x - 2, 28, x + 10, 21), C("6a4a30"), 1)
    c.shade("rect", (12, 28, 40, 60), PLANK)
    for y in (38, 49):
        c.fill("line", (13, y, 39, y), C("3a2818"), 1)
        c.fill("line", (13, y + 1, 39, y + 1), C("caa070"), 1)
    c.shade("poly", [(40, 28), (52, 21), (52, 53), (40, 60)], PLANK_SIDE)
    for y in (37, 48):
        c.fill("line", (41, y, 51, y - 7), C("2e2014"), 1)
    c.shade("line", (14, 30, 38, 58), PLANK, width=3, dither=False)
    c.fill("line", (14, 30, 38, 58), C("d8ac78"), 1)
    for (x, y) in ((12, 28), (37, 28), (12, 57), (37, 57)):
        c.fill("rect", (x, y, x + 3, y + 3), IRON[1])
        c.put(x + 1, y + 1, C("d0ccd8"))
    c.fill("rect", (48, 21, 51, 24), IRON[1])
    c.fill("rect", (48, 50, 51, 53), IRON[2])
    _nails(c, [(25, 30), (25, 58), (15, 44), (37, 44), (46, 30), (46, 52)])
    # A painted mark: a ring with a stroke, in faded red.
    for (x, y) in ((22, 41), (23, 40), (24, 40), (25, 41), (25, 42), (24, 43), (23, 43), (22, 42), (28, 40), (28, 41), (28, 42), (28, 43)):
        c.put(x, y, C("8a3a34"))


def prop_barrel(c):
    # A cooper's barrel: bulging staves in three tones, the lid of boards
    # seen from above with its rim, two iron hoops catching the light, a
    # bung, and a damp dark ring where it meets the ground.
    c.shadow(32, 61, 16, 3, 90)
    body = [(20, 27), (44, 27), (47, 35), (48, 45), (46, 55), (42, 61), (22, 61), (18, 55), (16, 45), (17, 35)]
    c.shade("poly", body, PLANK)
    for x, tone in ((21, "d0a474"), (26, "a07850"), (31, "8e6640"), (36, "7a5636"), (41, "5e4028")):
        c.fill("line", (x, 29, x + (1 if x > 31 else -1) * 1, 60), C(tone), 2)
    for x in (24, 29, 34, 39):
        c.fill("line", (x, 29, x + (1 if x > 31 else -1), 60), C("3e2a1a"), 1)
    c.shade("ellipse", (19, 22, 45, 32), PLANK_TOP)
    c.fill("ellipse", (22, 24, 42, 30), C("9a7048"))
    for y in (26, 28):
        c.fill("line", (24, y, 40, y), C("6a4a30"), 1)
    hoop = IRON
    for (y, inset) in ((35, 1), (51, 0)):
        c.shade("poly", [(17 + inset, y), (47 - inset, y), (47 - inset, y + 3), (17 + inset, y + 3)], hoop)
        c.fill("line", (18 + inset, y, 46 - inset, y), C("dcd8e2"), 1)
        for x in (20, 44):
            c.put(x, y + 1, C("2a2830"))
    c.fill("ellipse", (29, 42, 35, 48), C("3a2818"))
    c.fill("rect", (31, 44, 33, 46), C("a07a4e"))
    c.put(31, 44, C("d0a474"))


def prop_well(c):
    # A village well: a ring of fitted stones (each its own, mortar between),
    # dark water with a glint, two posts and a beam with a windlass and its
    # crank, a rope down to a bucket, and a shingled roof with a ridge.
    c.shadow(32, 60, 26, 4, 90)
    c.shade("ellipse", (8, 36, 56, 62), ramp("b4b0bc", "86828f", "57535f"))
    r = random.Random(81)
    for row, (y0, y1) in enumerate(((44, 49), (49, 54), (54, 59))):
        x = 10 + (row % 2) * 4
        while x < 54:
            w = r.randrange(6, 10)
            c.fill("line", (x, y0, x, y1), C("4a4652"), 1)
            c.fill("line", (x + 1, y0, min(x + w - 1, 54), y0), C("c8c4d0"), 1)
            x += w
        c.fill("line", (10, y1, 54, y1), C("4a4652"), 1)
    c.fill("ellipse", (14, 37, 50, 48), C("1a2430"))
    c.fill("ellipse", (18, 40, 46, 47), C("0c121c"))
    c.fill("line", (26, 42, 32, 42), C("5a7a9a"), 1)
    c.shade("rect", (10, 12, 14, 46), PLANK)
    c.shade("rect", (50, 12, 54, 46), PLANK)
    c.shade("rect", (10, 17, 54, 20), PLANK_TOP)
    c.shade("ellipse", (26, 15, 38, 22), PLANK_SIDE)
    c.fill("line", (54, 18, 59, 18), IRON[1], 2)
    c.fill("line", (59, 18, 59, 24), IRON[1], 2)
    c.fill("line", (31, 22, 31, 33), C("c8b890"), 1)
    c.shade("poly", [(27, 33), (35, 33), (34, 40), (28, 40)], PLANK_SIDE)
    c.fill("line", (27, 34, 35, 34), IRON[0], 1)
    roof = ramp("8a5a3a", "6a3e28", "48281a")
    c.shade("poly", [(4, 16), (32, 3), (60, 16), (55, 18), (9, 18)], roof)
    for k, y in enumerate((8, 12, 16)):
        for x in range(8 + (k % 2) * 3, 58, 6):
            if abs(x - 32) < (y - 3) * 2.1:
                c.put(x, y, C("3a2014"))
    c.fill("line", (6, 16, 58, 16), C("a87048"), 1)
    c.fill("line", (31, 3, 33, 3), C("b88a5a"), 1)


def prop_fence(c):
    # A split-rail fence: three posts with cut tops sunk in grass, two rails
    # with their grain, darker beneath, and nails where they cross.
    c.shadow(32, 61, 28, 2, 70)
    for x in (5, 29, 53):
        c.shade("rect", (x, 28, x + 5, 61), PLANK)
        c.shade("poly", [(x, 28), (x + 5, 28), (x + 5, 26), (x + 2, 24), (x, 26)], PLANK_TOP)
        c.fill("line", (x + 1, 30, x + 1, 58), C("c09468"), 1)
    for y in (35, 47):
        c.shade("rect", (3, y, 61, y + 4), PLANK)
        c.fill("line", (3, y, 61, y), C("d4aa7a"), 1)
        c.fill("line", (3, y + 4, 61, y + 4), C("4a3220"), 1)
        for x in (12, 21, 40, 47):
            c.put(x, y + 2, C("6a4a30"))
            c.put(x + 2, y + 2, C("6a4a30"))
        for x in (7, 31, 55):
            c.put(x, y + 2, C("2a2220"))
    for x in range(2, 62, 3):
        c.put(x, 61 - (x * 7) % 3, C("5d7a3f"))
        c.put(x + 1, 61, C("86a456"))


def prop_soil(c):
    # A tilled plot, plainly farmland: a frame of boards, four raised rows of
    # dark earth with a lit crest and a shadowed furrow, green shoots coming
    # up along them, and a few pebbles.
    board = ramp("a07a4e", "7a5636", "54381f")
    c.shade("rect", (3, 18, 61, 60), board)
    c.fill("rect", (6, 21, 58, 57), C("3a2618"))
    for k, y in enumerate((23, 32, 41, 50)):
        c.shade("rect", (7, y, 57, y + 6), SOILR, dither=False)
        c.fill("line", (7, y, 57, y), C("9a7048"), 1)
        c.fill("line", (7, y + 6, 57, y + 6), C("24160e"), 1)
        for x in range(10 + (k % 2) * 4, 56, 7):
            c.put(x, y - 1, C("5ab04a"))
            c.put(x, y - 2, C("8ad868"))
            c.put(x + 1, y - 1, C("3e8034"))
    for (x, y) in ((14, 30), (44, 39), (28, 48), (50, 56)):
        c.put(x, y, C("8a8494"))
    c.fill("line", (3, 18, 61, 18), C("c49a68"), 1)


def prop_scarecrow(c):
    # A scarecrow: a post and crossbar; a burlap sack head stitched with
    # cross eyes and a crooked mouth; a wide straw hat with a red band; a
    # patched plaid shirt with straw sticking from the cuffs and collar;
    # a crow perched on one arm.
    c.shadow(32, 61, 10, 2, 80)
    c.shade("rect", (30, 22, 33, 61), PLANK)
    c.shade("rect", (8, 30, 56, 33), PLANK)
    c.shade("poly", [(22, 30), (42, 30), (44, 50), (20, 50)], ramp("b04a3a", "8a3028", "5a2018"))
    for x in (24, 30, 36, 42):
        c.fill("line", (x, 31, x - 1, 49), C("d8b060"), 1)
    for y in (36, 43):
        c.fill("line", (21, y, 43, y), C("d8b060"), 1)
    c.shade("rect", (33, 40, 39, 46), ramp("5a7ab0", "3e5a8a", "2a3e60"))
    _nails(c, [(34, 41), (38, 41), (34, 45), (38, 45)], "e8e0c8")
    for (x0, x1) in ((8, 14), (50, 56)):
        c.shade("rect", (x0, 29, x1, 34), ramp("b04a3a", "8a3028", "5a2018"))
    for (x, y) in ((6, 30), (5, 33), (7, 35), (58, 30), (59, 33), (57, 35), (26, 51), (30, 52), (35, 51), (39, 52)):
        c.fill("line", (x, y, x + (2 if x > 32 else -2), y + 2), STRAW_R[1], 1)
    c.shade("ellipse", (24, 13, 40, 30), BURLAP)
    for (x, y) in ((27, 19), (29, 21), (29, 19), (27, 21), (35, 19), (37, 21), (37, 19), (35, 21)):
        c.put(x, y, C("2a2018"))
    for x in range(27, 38, 2):
        c.put(x, 25 + (x // 2) % 2, C("2a2018"))
    c.fill("line", (24, 28, 40, 28), C("6a5438"), 1)
    c.shade("ellipse", (14, 10, 50, 17), STRAW_R)
    c.shade("poly", [(24, 12), (26, 3), (38, 3), (40, 12)], STRAW_R)
    c.fill("rect", (25, 9, 39, 11), C("a83030"))
    # The crow.
    c.shade("ellipse", (47, 22, 55, 29), ramp("4a4858", "2e2c38", "1a1820"))
    c.shade("ellipse", (52, 19, 57, 24), ramp("4a4858", "2e2c38", "1a1820"))
    c.put(55, 21, C("e8d070"))
    c.fill("line", (57, 22, 59, 22), C("d8a838"), 1)
    c.fill("line", (46, 27, 43, 30), C("2e2c38"), 1)


def prop_cart(c):
    # A farm cart: a plank bed with side boards, two shafts forward, a big
    # spoked wheel with an iron tyre and hub, and a load of sacks and hay.
    c.shadow(30, 61, 24, 3, 90)
    c.fill("line", (40, 40, 60, 30), PLANK[1], 2)
    c.fill("line", (40, 44, 60, 36), PLANK[2], 2)
    c.shade("poly", [(4, 30), (44, 30), (46, 44), (6, 44)], PLANK)
    for x in (12, 20, 28, 36):
        c.fill("line", (x, 31, x + 1, 43), C("4a3220"), 1)
    c.shade("poly", [(4, 26), (44, 26), (44, 31), (4, 31)], PLANK_TOP)
    # The load.
    c.shade("ellipse", (8, 14, 24, 30), BURLAP)
    c.fill("line", (13, 15, 19, 15), C("7a6448"), 1)
    c.shade("ellipse", (20, 12, 36, 28), BURLAP)
    c.fill("line", (25, 13, 31, 13), C("7a6448"), 1)
    c.shade("poly", [(32, 26), (34, 16), (42, 14), (46, 26)], STRAW_R)
    for x in range(34, 45, 2):
        c.fill("line", (x, 26, x - 1, 16), C("a8843a"), 1)
    # The wheel.
    c.shade("ellipse", (12, 36, 36, 60), IRON)
    c.fill("ellipse", (15, 39, 33, 57), C("2a2018"))
    hub = (24, 48)
    for k in range(8):
        a = k * math.pi / 4
        c.fill("line", (hub[0], hub[1], round(hub[0] + math.cos(a) * 8), round(hub[1] + math.sin(a) * 8)), PLANK[1], 1)
    c.shade("ellipse", (21, 45, 27, 51), IRON)
    c.put(23, 47, C("d0ccd8"))


def prop_tent(c):
    # A traveller's tent: a canvas A-frame with a ridge pole showing at both
    # ends, the near flap tied back on a dark inside, folds and a patch,
    # guy ropes out to pegs.
    c.shadow(32, 61, 28, 3, 90)
    c.shade("poly", [(32, 6), (60, 58), (4, 58)], CANVAS_R)
    c.shade("poly", [(32, 6), (60, 58), (46, 58)], ramp("b4a484", "948468", "6e604a"))
    c.shade("poly", [(32, 20), (42, 58), (22, 58)], ramp("2a2420", "1a1614", "0e0c0a"))
    c.shade("poly", [(32, 20), (22, 58), (16, 58), (28, 24)], ramp("f0e6cc", "d4c6a4", "a49474"))
    c.fill("line", (22, 40, 18, 44), C("8a6440"), 1)
    for (x0, y0, x1, y1) in ((32, 8, 12, 52), (32, 8, 52, 52), (32, 8, 40, 30)):
        c.fill("line", (x0, y0, x1, y1), C("b4a484"), 1)
    c.shade("rect", (46, 40, 52, 46), ramp("8a7a5a", "6e604a", "52483a"))
    _nails(c, [(46, 40), (52, 40), (46, 46), (52, 46)], "4a3a2a")
    c.fill("line", (32, 2, 32, 8), PLANK[1], 2)
    c.fill("line", (6, 56, 1, 61), C("c8b890"), 1)
    c.fill("line", (58, 56, 63, 61), C("c8b890"), 1)
    for (x, y) in ((1, 61), (62, 61)):
        c.fill("rect", (x - 1, y - 2, x, y), PLANK[1])


def prop_stall(c):
    # A merchant's stall: a striped awning of bronze and cream with a
    # scalloped edge, a counter under a blue cloth, crates of goods below,
    # hanging lamps and wares, and a little painted sign.
    c.shadow(32, 61, 28, 3, 90)
    for x in (8, 52):
        c.shade("rect", (x, 8, x + 3, 61), PLANK)
    for k in range(7):
        col = ramp("d8a050", "b07a34", "7a5020") if k % 2 == 0 else ramp("f0e6cc", "d4c6a4", "a49474")
        x0 = 4 + k * 8
        c.shade("poly", [(x0, 6), (x0 + 8, 6), (x0 + 8, 15), (x0, 15)], col, dither=False)
        c.shade("ellipse", (x0, 12, x0 + 8, 19), col, dither=False)
    c.fill("line", (4, 6, 60, 6), C("5a3a20"), 1)
    for x in (18, 44):
        c.fill("line", (x, 19, x, 23), C("4a4652"), 1)
        c.shade("rect", (x - 2, 23, x + 2, 28), ramp("f8e0a0", "e0b060", "a87830"))
    c.shade("rect", (6, 34, 58, 42), ramp("5a7ab0", "3e5a8a", "2a3e60"))
    c.fill("line", (6, 34, 58, 34), C("8aa8d8"), 1)
    for x in range(8, 58, 6):
        c.fill("line", (x, 42, x + 3, 45), C("2a3e60"), 1)
    for (x, col) in ((12, ("e05a4a", "b03a32", "702424")), (20, ("f0d060", "c8a038", "8a6c20")), (28, ("8ad068", "58944a", "34602e")),
                     (36, ("f0a060", "c87038", "8a4820")), (44, ("d080e0", "a058b8", "6a3a80"))):
        c.shade("ellipse", (x, 28, x + 6, 34), ramp(*col))
    c.shade("rect", (12, 46, 28, 60), PLANK)
    c.shade("rect", (34, 48, 50, 60), PLANK_SIDE)
    c.fill("line", (12, 53, 28, 53), C("3a2818"), 1)
    for (x, y) in ((15, 47), (19, 48), (23, 47), (37, 49), (42, 49), (46, 50)):
        c.shade("ellipse", (x - 2, y - 2, x + 2, y + 1), ramp("f0d060", "c8a038", "8a6c20"))
    c.shade("rect", (24, 20, 40, 26), PLANK_TOP)
    c.fill("rect", (27, 22, 37, 24), C("8a3a34"))


def prop_plant_pot(c):
    # A terracotta pot with a lit rim and a painted band, a bushy plant with
    # layered leaves and three little flowers.
    c.shadow(32, 61, 12, 2, 80)
    c.shade("poly", [(20, 44), (44, 44), (41, 61), (23, 61)], TERRA)
    c.shade("rect", (18, 40, 46, 45), ramp("f0a070", "c87040", "8a4a28"))
    c.fill("line", (18, 40, 46, 40), C("ffc898"), 1)
    c.fill("line", (22, 52, 42, 52), C("e8d0a0"), 1)
    c.fill("ellipse", (20, 38, 44, 43), C("3a2618"))
    for (x, y, r) in ((24, 30, 8), (38, 28, 8), (31, 22, 9), (29, 34, 7), (40, 36, 6), (21, 37, 5)):
        c.shade("ellipse", (x - r, y - r, x + r, y + r), LEAFR)
    for (x, y) in ((27, 24), (36, 23), (31, 31), (22, 32), (41, 33)):
        c.put(x, y, C("aee888"))
    for (x, y, col) in ((26, 20, "f0e070"), (37, 26, "e888c0"), (30, 30, "f0f0e8")):
        c.fill("rect", (x - 1, y - 1, x + 1, y + 1), C(col))
        c.put(x, y, C("c89030"))


def prop_flower_bed(c):
    # A raised bed of boards full of dark soil, rows of flowers of five kinds
    # on their stems, leaves at their feet.
    c.shadow(32, 61, 28, 2, 80)
    c.shade("rect", (4, 44, 60, 60), PLANK)
    c.fill("line", (4, 44, 60, 44), C("d4aa7a"), 1)
    c.fill("line", (4, 52, 60, 52), C("4a3220"), 1)
    c.fill("rect", (6, 40, 58, 45), C("3a2618"))
    r = random.Random(91)
    colours = [("f0e070", "c8a838"), ("e05a6a", "a83a48"), ("f0f0e8", "c8c8c0"), ("a070e0", "7048b0"), ("f0a050", "c07030")]
    for k, x in enumerate(range(8, 58, 5)):
        top = 24 + r.randrange(0, 10)
        c.fill("line", (x, 42, x, top + 3), C("3e8034"), 1)
        c.fill("line", (x, 40, x - 2, 38), C("5ab04a"), 1)
        c.fill("line", (x, 39, x + 2, 37), C("5ab04a"), 1)
        light, dark = colours[k % len(colours)]
        c.fill("rect", (x - 2, top, x + 2, top + 3), C(dark))
        c.fill("rect", (x - 1, top, x + 1, top + 2), C(light))
        c.put(x, top + 1, C("f8d040") if light != "f0e070" else C("a87830"))


def prop_stone_planter(c):
    # A carved stone planter: a squared trough with a lit lip, a carved band
    # of diamonds, and a clipped round shrub with berries.
    c.shadow(32, 61, 18, 3, 90)
    c.shade("rect", (14, 40, 50, 61), ramp("b4b0bc", "86828f", "57535f"))
    c.shade("rect", (12, 36, 52, 41), ramp("d0ccd8", "a8a4b0", "7a7684"))
    c.fill("line", (12, 36, 52, 36), C("e8e4ee"), 1)
    for x in range(18, 48, 7):
        for (dx, dy) in ((0, 0), (1, -1), (2, 0), (1, 1)):
            c.put(x + dx, 50 + dy, C("4a4652"))
    c.fill("line", (14, 56, 50, 56), C("4a4652"), 1)
    for (x, y, r) in ((32, 24, 14), (22, 30, 8), (42, 30, 8)):
        c.shade("ellipse", (x - r, y - r, x + r, y + r), ramp("6ab050", "40803a", "285428"))
    for (x, y) in ((26, 18), (35, 16), (40, 24), (28, 26), (22, 28), (36, 30)):
        c.put(x, y, C("8ad068"))
    for (x, y) in ((30, 20), (38, 22), (25, 30), (41, 31)):
        c.put(x, y, C("d83a4a"))


def prop_bone_pile(c):
    # Old bones in the grass: a skull turned a little, with a domed crown, a
    # brow ridge, deep sockets shaded inside, cheekbones, a nose hole and a
    # row of teeth with gaps; its jaw fallen beside it; a curve of ribs; a
    # thigh bone with knobbed ends; finger bones; a crack, a little moss.
    bone = ramp("f6f2e4", "d6d0bc", "a09a86")
    c.shadow(32, 58, 24, 4, 70)
    c.fill("ellipse", (8, 52, 58, 62), C("4a3a2a", 90))
    # The thigh bone.
    c.shade("line", (8, 57, 27, 51), bone, width=3, dither=False)
    for end in ((8, 57), (27, 51)):
        c.shade("ellipse", (end[0] - 3, end[1] - 3, end[0] + 3, end[1] + 2), bone)
    # Ribs, each a curve.
    for k in range(4):
        x0 = 40 + k * 4
        c.fill("line", (x0, 47 - k, x0 + 3, 52 - k), bone[1], 1)
        c.fill("line", (x0 + 3, 52 - k, x0 + 2, 57 - k), bone[1], 1)
        c.fill("line", (x0 + 1, 47 - k, x0 + 4, 52 - k), bone[2], 1)
    c.fill("line", (39, 46, 56, 41), bone[2], 1)
    # The skull: crown, face, cheekbones.
    c.shade("ellipse", (21, 26, 45, 48), bone)
    c.shade("poly", [(24, 42), (42, 42), (40, 52), (26, 52)], bone)
    c.fill("line", (23, 36, 43, 36), bone[0], 1)
    for (x0, x1) in ((25, 31), (35, 41)):
        c.fill("ellipse", (x0, 37, x1, 44), C("1c1418"))
        c.fill("line", (x0 + 1, 37, x1 - 1, 37), C("6a6252"), 1)
        c.put(x0 + 2, 40, C("3a2e30"))
    c.fill("poly", [(32, 45), (34, 45), (33, 48)], C("1c1418"))
    for (x, y) in ((24, 45), (42, 45)):
        c.fill("line", (x, y, x + (2 if x < 33 else -2), y + 1), bone[2], 1)
    c.fill("rect", (27, 50, 39, 52), C("e8e2d0"))
    for x in (28, 30, 32, 34, 36, 38):
        c.put(x, 51, C("5a5446") if x != 34 else C("1c1418"))
    c.fill("line", (37, 28, 35, 33), C("8a8474"), 1)
    c.fill("line", (35, 33, 36, 35), C("8a8474"), 1)
    for (x, y) in ((24, 30), (25, 29), (22, 34)):
        c.put(x, y, C("6d8a44"))
    # The jaw, fallen.
    c.shade("poly", [(12, 46), (22, 46), (21, 50), (13, 50)], bone)
    for x in (14, 16, 18, 20):
        c.put(x, 46, C("5a5446"))
    # Finger bones.
    for (x, y) in ((48, 58), (52, 60), (56, 57)):
        c.fill("line", (x, y, x + 2, y - 1), bone[1], 1)


def prop_waygate(c):
    """A waygate the player builds: a squared pillar of dressed stone on a
    round three-step dais, a band of bronze at its waist and crown, runes cut
    down its face and lit cold blue, and a shard of crystal hanging in the air
    over its top; four rune pebbles mark the dais."""
    stone = ramp("c2bed0", "8e8a9c", "5c5868")
    dark = C("3a3644")
    # The dais: three round steps.
    c.shadow(32, 58, 26, 5, 80)
    for (x0, y0, x1, y1) in [(5, 50, 59, 62), (10, 47, 54, 58), (15, 44, 49, 54)]:
        c.shade("ellipse", (x0, y0, x1, y1), ramp("aaa6b8", "7a7688", "504c5c"), dither=False)
        c.fill("line", [(x0 + 6, y0 + 1), (x1 - 6, y0 + 1)], C("d4d0de"))
    for (x, y) in [(10, 57), (54, 57), (19, 60), (45, 60)]:
        c.fill("ellipse", (x - 2, y - 1, x + 2, y + 1), C("6a6678"))
        c.put(x, y - 1, C("6ae0f8"))
    # The pillar: a lit front face and a shaded right side, tapering up.
    c.shade("poly", [(23, 49), (24, 14), (39, 14), (40, 49)], stone, dither=False)
    c.fill("poly", [(37, 14), (39, 14), (40, 49), (37, 49)], C("6a6678"))
    c.fill("line", [(24, 15), (23, 48)], C("d8d4e2"))
    # Mortar lines between its courses.
    for y in (24, 34, 43):
        c.fill("line", [(24, y), (39, y)], dark)
        c.fill("line", [(24, y + 1), (36, y + 1)], C("aaa6b8"))
    # The bronze bands and the crown.
    bronze = ramp("f0c878", "c8904a", "7a5226")
    c.shade("rect", (22, 29, 41, 31), bronze, dither=False)
    c.shade("poly", [(20, 14), (43, 14), (41, 9), (22, 9)], bronze, dither=False)
    c.fill("line", [(22, 9), (41, 9)], C("fff0b8"))
    c.fill("line", [(20, 14), (43, 14)], C("5a3a18"))
    for x in (24, 31, 38):
        c.fill("rect", (x, 6, x + 1, 9), bronze[1])
        c.put(x, 6, C("fff0b8"))
    # Runes cut down the face, each its own glyph, lit from within.
    glyphs = [[(0, 0, 3, 0), (1, 0, 1, 5), (3, 2, 0, 5)], [(0, 0, 0, 5), (0, 2, 3, 0), (0, 2, 3, 5)],
              [(0, 5, 2, 0), (2, 0, 3, 5), (1, 3, 3, 3)], [(0, 0, 3, 5), (3, 0, 0, 5)]]
    for (gx, gy), glyph in zip([(29, 17), (29, 35), (30, 23), (29, 41)], glyphs):
        if gy > 40:
            gy = 42
        for (x0, y0, x1, y1) in glyph:
            c.fill("line", (gx + x0 + 1, gy + y0 + 1, gx + x1 + 1, gy + y1 + 1), C("1a3a4a"), 1)
            c.fill("line", (gx + x0, gy + y0, gx + x1, gy + y1), C("6ae0f8"), 1)
    for (x, y) in [(29, 17), (32, 36), (31, 24)]:
        c.put(x, y, C("e8ffff"))
    # Moss in the joints, a chip off one corner.
    for (x, y) in [(25, 47), (26, 48), (38, 44), (24, 26)]:
        c.put(x, y, C("6a8a48"))
    c.fill("poly", [(39, 36), (40, 40), (38, 40)], C("4a4656"))
    # The crystal, floating: drawn last so it sits clear of the crown.
    crystal = ramp("e8ffff", "6ae0f8", "2a7aa8")
    c.shade("poly", [(31, 0), (35, 2), (34, 5), (31, 7), (28, 5), (28, 2)], crystal, dither=False)
    c.put(30, 1, C("ffffff"))
    c.put(31, 4, C("ffffff"))


PROPS_V2 = {
    "crate": prop_crate, "barrel": prop_barrel, "well": prop_well, "fence": prop_fence, "soil": prop_soil,
    "scarecrow": prop_scarecrow, "cart": prop_cart, "tent": prop_tent, "stall": prop_stall,
    "plant_pot": prop_plant_pot, "flower_bed": prop_flower_bed, "stone_planter": prop_stone_planter,
    "bone_pile": prop_bone_pile, "waygate": prop_waygate,
}


def decor(kind):
    c = Canvas(64, 64)
    if kind in PROPS_V2:
        PROPS_V2[kind](c)
        c.outline()
        return c.img
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
    elif kind == "menhir":
        # One stone of a ring: a broad, uncut slab of dark gneiss, flat-
        # topped and leaning, with banded grain, orange and grey lichen,
        # a split down one side and moss and fallen chips at its foot. No
        # plinth, no runes: nothing like a waystone.
        gneiss = ramp("9c98a6", "76727f", "4e4a58")
        c.shadow(32, 60, 15, 2, 80)
        c.shade("ellipse", (14, 55, 50, 62), ramp("5e7048", "4a5a38", "36422a"))
        c.shade("poly", [(17, 58), (16, 44), (18, 28), (21, 19), (27, 15), (37, 14), (43, 17), (46, 27), (47, 42), (47, 58)], gneiss)
        c.fill("poly", [(18, 56), (18, 30), (21, 20), (25, 17), (22, 32), (21, 56)], C("b4b0bc"))
        c.fill("poly", [(42, 18), (46, 28), (47, 44), (47, 57), (43, 57), (43, 32)], C("4a4654"))
        c.fill("line", (27, 15, 37, 14), C("c4c0cc"))
        # Banded grain running across the slab, slightly tilted.
        grain = random.Random(62)
        for y in (26, 37, 49):
            # Broken, wavering streaks of darker mineral, not courses of brick.
            x = 20
            while x < 44:
                run = grain.randrange(3, 8)
                if grain.random() < 0.65:
                    dy = 0 if grain.random() < 0.6 else 1
                    c.fill("line", (x, y + dy - (x - 20) // 12, min(x + run, 45), y + dy - (x - 20) // 12), C("68647a"), 1)
                x += run + grain.randrange(1, 4)
        # The split.
        for (x0, y0), (x1, y1) in zip([(40, 15), (38, 22), (40, 29), (39, 35)], [(38, 22), (40, 29), (39, 35), (41, 40)]):
            c.fill("line", (x0, y0, x1, y1), C("2e2b36"), 1)
        r = random.Random(61)
        for _ in range(40):
            x, y = r.randrange(18, 47), r.randrange(15, 58)
            if (x, y) in c.filled:
                c.put(x, y, C("6a6676") if r.random() < 0.6 else C("aeaab8"))
        # Lichen: rusty orange patches and grey-green crust.
        for (x, y, k) in [(24, 22, 0), (25, 22, 0), (24, 23, 0), (34, 36, 1), (35, 36, 1), (35, 37, 1), (28, 47, 0), (29, 47, 0),
                          (43, 24, 1), (21, 40, 1), (22, 40, 1), (31, 19, 0)]:
            c.put(x, y, C("d0883a") if k == 0 else C("9aa478"))
        for x in range(16, 48):
            if r.random() < 0.5:
                c.put(x, 57 - r.randrange(0, 3), C("5d7a3f") if r.random() < 0.6 else C("86a456"))
        for (x, y) in [(13, 59), (50, 58), (52, 61)]:
            c.shade("ellipse", (x - 2, y - 1, x + 2, y + 1), gneiss)
    elif kind == "lever":
        # A puzzle lever: a squat iron-banded stone block with a slot, an
        # iron arm with a worn wooden grip thrown forward, bolts at the
        # pivot, and wear on the stone where hands have rested.
        block = ramp("a29eac", "7a7684", "504c5a")
        iron = ramp("9a98a4", "5e5c68", "34323c")
        c.shadow(32, 60, 13, 2, 80)
        c.shade("poly", [(18, 60), (46, 60), (46, 40), (43, 37), (21, 37), (18, 40)], block)
        c.fill("line", (21, 37, 43, 37), C("c4c0cc"))
        c.fill("rect", (18, 45, 46, 47), iron[1])
        c.fill("line", (18, 45, 46, 45), iron[0])
        for x in (21, 31, 43):
            c.put(x, 46, C("d0ccd8"))
        c.fill("rect", (29, 37, 35, 40), C("2a2834"))
        # The arm, thrown forward and up to the right.
        c.fill("line", (32, 39, 41, 20), iron[1], 2)
        c.fill("line", (31, 39, 40, 20), iron[0], 1)
        c.shade("rect", (38, 14, 44, 22), ramp("a87c4c", "7a5432", "4e341e"))
        c.fill("line", (38, 14, 44, 14), C("c89a62"))
        c.shade("ellipse", (29, 36, 35, 42), iron)
        c.put(31, 38, C("d8d4e0"))
        for (x, y) in [(22, 52), (40, 55), (25, 41)]:
            c.put(x, y, C("6e6a78"))
        for x in range(18, 47):
            if (x * 7) % 5 < 2:
                c.put(x, 59, C("5d7a3f"))
    elif kind == "answer_tablet":
        # A low tablet to choose an answer at: a slanted slab of pale stone
        # on a short plinth, a blank recessed panel for the glyph the puzzle
        # lights, chipped corners, moss at the base.
        slab = ramp("c4c0cc", "9a96a4", "6a6676")
        c.shadow(32, 60, 14, 2, 80)
        c.shade("rect", (20, 50, 44, 60), ramp("8e8a98", "6a6676", "48444f"))
        c.fill("line", (20, 50, 44, 50), C("b4b0bc"))
        c.shade("poly", [(17, 50), (47, 50), (44, 24), (20, 24)], slab)
        c.fill("line", (20, 24, 44, 24), C("e0dce6"))
        c.fill("line", (17, 50, 20, 24), C("dcd8e2"))
        c.fill("line", (47, 50, 44, 24), C("5e5a68"))
        c.fill("rect", (24, 29, 40, 45), C("6a6676"))
        c.fill("rect", (25, 30, 40, 45), C("8a8694"))
        c.fill("line", (24, 29, 40, 29), C("4a4654"))
        c.fill("line", (24, 29, 24, 45), C("4a4654"))
        for (x, y) in [(44, 25), (45, 26), (18, 49)]:
            c.put(x, y, (0, 0, 0, 0))
        for x in range(19, 46):
            if (x * 5) % 7 < 3:
                c.put(x, 59, C("5d7a3f"))
                c.put(x, 58 - (x % 2), C("86a456"))
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
    elif kind == "manor":
        # Saint Lull's House: a long white house under a slate roof, two
        # gables, a bell tower between them, rows of warm windows, a red
        # door up three steps, ivy at one corner. Shown at twice size.
        plaster, slate = ramp("f2eee4", "d6d0c2", "a8a090"), ramp("5a6070", "3e4452", "262a36")
        c.shade("rect", (4, 30, 60, 60), plaster, dither=False)
        c.fill("line", (4, 30, 60, 30), C("fffaf0"))
        c.shade("poly", [(2, 31), (12, 18), (22, 31)], slate)
        c.shade("poly", [(42, 31), (52, 18), (62, 31)], slate)
        c.shade("poly", [(14, 31), (16, 25), (48, 25), (50, 31)], slate)
        c.shade("rect", (26, 8, 38, 26), plaster, dither=False)
        c.shade("poly", [(24, 9), (32, 1), (40, 9)], slate)
        c.fill("rect", (29, 12, 35, 18), C("1a1820"))
        c.shade("ellipse", (30, 13, 34, 17), ramp("e8c070", "b8863a", "7a5626"))
        for x in (8, 15, 45, 52):
            for y in (35, 46):
                c.fill("rect", (x, y, x + 4, y + 6), C("2a2630"))
                c.fill("rect", (x + 1, y + 1, x + 3, y + 5), C("f0c060"))
                c.fill("line", (x + 2, y + 1, x + 2, y + 5), C("8a6a3a"))
                c.fill("line", (x, y + 7, x + 4, y + 7), C("8a8478"))
        for x in (22, 38):
            c.fill("rect", (x, 34, x + 3, 39), C("2a2630"))
            c.fill("rect", (x + 1, 35, x + 2, 38), C("f0c060"))
        c.shade("rect", (28, 44, 36, 60), ramp("c04848", "8a2c37", "5c1c28"), dither=False)
        c.fill("rect", (31, 44, 33, 46), C("f0c060"))
        c.put(34, 52, C("e8c070"))
        for i, y in enumerate((60, 61, 62)):
            c.fill("line", (26 - i, y, 38 + i, y), C("b0aa9c") if i % 2 == 0 else C("8a8478"))
        r = random.Random(71)
        for _ in range(40):
            x, y = r.randrange(4, 11), r.randrange(32, 60)
            if (x, y) in c.filled:
                c.put(x, y, C("4f6a34") if r.random() < 0.6 else C("6d8a44"))
    elif kind == "iron_gate":
        # The back gate: two white pillars and a gate of black iron bars
        # with spear points, a chain and a padlock.
        plaster = ramp("f2eee4", "d6d0c2", "a8a090")
        for x in (6, 50):
            c.shade("rect", (x, 14, x + 8, 60), plaster, dither=False)
            c.shade("rect", (x - 1, 10, x + 9, 14), ramp("e0dace", "bab4a6", "8a8478"))
        iron = C("1e1c24")
        for x in range(16, 49, 4):
            c.fill("line", (x, 18, x, 60), iron)
            c.put(x, 17, C("6e6a78"))
            c.put(x, 16, iron)
        for y in (22, 40, 56):
            c.fill("line", (14, y, 50, y), iron)
        c.fill("line", (24, 30, 40, 30), C("6e6a78"))
        c.shade("rect", (29, 31, 35, 37), ramp("b8b4c0", "8a8692", "5a5664"), dither=False)
        c.fill("rect", (31, 28, 33, 31), C("5a5664"))
    elif kind == "carriage":
        # A black carriage with drawn curtains, gilt trim and tall wheels.
        black = ramp("3a3644", "24222c", "141218")
        c.shade("poly", [(10, 22), (52, 22), (55, 46), (8, 46)], black)
        c.shade("poly", [(8, 22), (31, 14), (54, 22)], black)
        c.fill("line", (8, 22, 54, 22), C("d8b070"))
        c.fill("line", (8, 46, 55, 46), C("d8b070"))
        for x in (16, 36):
            c.fill("rect", (x, 27, x + 11, 37), C("6a1a24"))
            c.fill("line", (x, 27, x + 11, 27), C("a8803e"))
            for k in range(x + 1, x + 11, 3):
                c.fill("line", (k, 28, k, 37), C("4a1018"))
        for (cx, cy, rr) in ((16, 50, 9), (47, 50, 9)):
            c.shade("ellipse", (cx - rr, cy - rr, cx + rr, cy + rr), ramp("4a4652", "2a2830", "18161c"))
            c.fill("ellipse", (cx - rr + 3, cy - rr + 3, cx + rr - 3, cy + rr - 3), (0, 0, 0, 0))
            for a in range(0, 360, 45):
                import math as _m
                c.fill("line", (cx, cy, cx + _m.cos(_m.radians(a)) * (rr - 2), cy + _m.sin(_m.radians(a)) * (rr - 2)), C("8a8692"))
            c.fill("ellipse", (cx - 2, cy - 2, cx + 2, cy + 2), C("d8b070"))
        c.fill("rect", (29, 10, 33, 14), C("d8b070"))
    elif kind == "hatch":
        # A hatch of old planks in a grassy mound, banded in iron, with a ring.
        c.shade("ellipse", (6, 34, 58, 62), ramp("6a7a52", "56663e", "3e4a2e"))
        c.shade("ellipse", (14, 38, 50, 58), ramp("6a5a44", "54463a", "3e342a"))
        c.shade("rect", (18, 40, 46, 56), ramp("a07a52", "7a5a3a", "54402a"), dither=False)
        for x in (25, 32, 39):
            c.fill("line", (x, 40, x, 56), C("3a2a1c"))
        for y in (43, 53):
            c.fill("line", (18, y, 46, y), C("4a4654"))
        c.shade("ellipse", (29, 46, 35, 52), ramp("b8b4c0", "8a8692", "5a5664"))
        c.fill("ellipse", (31, 48, 33, 50), C("54402a"))
    elif kind == "horn_post":
        # The Reserve's gate post: a weathered post with a crossbar, a long
        # ivory hunting horn hung on a red cord, a white ribbon, and a
        # porcelain plaque with one upright slit (the mark of the Court).
        wood = ramp("8a6a48", "6a5034", "463422")
        c.shade("rect", (29, 12, 35, 60), wood, dither=False)
        c.fill("line", (35, 12, 35, 60), C("33251a"))
        c.shade("rect", (16, 14, 48, 18), wood, dither=False)
        c.fill("line", (16, 18, 48, 18), C("33251a"))
        for x in (17, 47):
            c.put(x, 16, C("a8a4ae"))
        # The red cord, and the horn curling down from it.
        c.fill("line", (21, 18, 19, 33), C("8a2c37"))
        c.fill("line", (43, 18, 44, 30), C("8a2c37"))
        # The horn: a curve from a wide bell (left) to a gilt mouthpiece
        # (right), drawn as rings shrinking along it, lit from above.
        ivory = ramp("fbf4e0", "e2d6b4", "b0a07a")
        points = []
        for k in range(0, 41):
            t = k / 40.0
            x = (1 - t) ** 2 * 15 + 2 * (1 - t) * t * 30 + t * t * 47
            y = (1 - t) ** 2 * 33 + 2 * (1 - t) * t * 42 + t * t * 26
            points.append((round(x), round(y), 4.2 - 3.2 * t))
        for x, y, r in points:
            c.fill("ellipse", (x - r, y - r, x + r, y + r), C("7a6a4a"))
        for x, y, r in points:
            c.fill("ellipse", (x - r + 0.6, y - r + 0.6, x + r - 0.6, y + r - 0.6), C("e2d6b4"))
        for x, y, r in points:
            c.put(x, round(y - r + 1), C("fbf4e0"))
        for k in (8, 16, 24, 32):
            x, y, r = points[k]
            c.fill("line", (x, round(y - r + 1), x, round(y + r - 1)), C("b0a07a"))
        c.fill("ellipse", (12, 29, 18, 37), C("7a6a4a"))
        c.fill("ellipse", (13, 30, 17, 36), C("2a2226"))
        c.fill("rect", (46, 25, 49, 27), C("d8b070"))
        c.put(49, 26, C("f0d090"))
        # The ribbon, lifting in the wind.
        for i, (x, y) in enumerate(((36, 18), (38, 20), (39, 23), (41, 25), (42, 28))):
            c.put(x, y, C("f6f2ea") if i % 2 == 0 else C("d6d0c2"))
        # The porcelain plaque on the post.
        c.shade("ellipse", (27, 40, 37, 52), ramp("fbf8f0", "e8e2d6", "b8b0a2"))
        c.fill("line", (32, 42, 32, 49), C("1a1820"))
        c.put(31, 50, C("a83040"))
        c.put(33, 50, C("a83040"))
        c.put(31, 51, C("a83040"))
        c.put(33, 51, C("a83040"))
        # Trampled earth at its foot.
        c.shade("ellipse", (20, 57, 44, 62), ramp("6a5a44", "54463a", "3e342a"))
        c.shade("rect", (29, 52, 35, 60), wood, dither=False)
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
    elif kind == "writing_desk":
        # A scholar's desk: a slanted top with an open book, an inkpot and a
        # quill, a candle stub, a drawer, and papers piled to one side.
        wood = ramp("a07a54", "74563a", "4e3826")
        c.shade("rect", (8, 40, 56, 44), wood)
        c.fill("line", (8, 40, 56, 40), C("c49a6c"))
        for x in (10, 52):
            c.shade("rect", (x, 44, x + 3, 61), wood)
        c.shade("rect", (36, 45, 50, 52), wood)
        c.fill("rect", (42, 48, 43, 49), BRASS[0])
        # The open book: two pages, lines of writing.
        c.shade("poly", [(14, 38), (27, 35), (27, 39), (14, 41)], ramp("f6eedc", "e0d4b8", "b8a888"), dither=False)
        c.shade("poly", [(27, 35), (40, 38), (40, 41), (27, 39)], ramp("f0e6d0", "d8ccae", "b0a080"), dither=False)
        for y in (37, 39):
            c.fill("line", (16, y + 1, 25, y), C("6a5a4a"))
            c.fill("line", (29, y, 38, y + 1), C("6a5a4a"))
        # Inkpot and quill.
        c.shade("rect", (44, 34, 48, 39), ramp("4a4a5a", "2a2a36", "14141c"), dither=False)
        c.fill("line", (46, 34, 51, 24), C("f2f0ea"))
        c.fill("line", (47, 34, 52, 25), C("c8c4bc"))
        # Papers and a candle.
        c.shade("rect", (49, 36, 55, 39), ramp("f0e8d4", "d8ccb0", "a89a7c"), dither=False)
        c.shade("rect", (10, 31, 12, 39), ramp("f4ecd8", "dcd0b4", "b0a488"), dither=False)
        c.put(11, 29, C("ffd27a"))
        c.put(11, 30, C("ff9a3a"))
    elif kind == "cauldron":
        # A black iron cauldron on three legs over glowing coals, a green
        # brew in it, bubbles breaking, a ladle leaning out.
        iron = ramp("6a6a78", "3a3a46", "1e1e26")
        c.shadow(32, 60, 22, 3, 70)
        for x in (18, 31, 44):
            c.fill("rect", (x, 52, x + 2, 60), iron[2])
        for x in range(20, 45, 3):
            c.put(x, 59, C("ff7a2a") if x % 2 else C("c03a1a"))
        c.shade("ellipse", (12, 28, 52, 58), iron)
        c.fill("ellipse", (14, 26, 50, 36), iron[2])
        c.shade("ellipse", (16, 28, 48, 35), ramp("a6e070", "5ca838", "2e6a22"), dither=False)
        for (x, y) in ((24, 30), (36, 31), (30, 29)):
            c.fill("ellipse", (x - 1, y - 1, x + 2, y + 1), C("c8f090"))
        c.fill("line", (12, 31, 52, 31), iron[0])
        c.fill("line", (40, 30, 48, 14), C("8a6a4a"), 2)
        for (x, y) in ((22, 22), (30, 18), (38, 22)):
            c.put(x, y, C("b8e090"))
    elif kind == "herb_rack":
        # A wooden rack with bundles of herbs hung upside down to dry:
        # green, lavender, yellow flowers, each tied with twine.
        wood = ramp("a07a54", "74563a", "4e3826")
        for x in (8, 54):
            c.shade("rect", (x, 12, x + 3, 61), wood)
        c.shade("rect", (8, 12, 57, 15), wood)
        bundles = [(14, "7aa84a", "4e7a2e"), (22, "b090e0", "7a5aa8"), (30, "e0c050", "a88a2a"), (38, "8ab858", "5a8a34"), (46, "a080d0", "6e4ea0")]
        for x, light, dark in bundles:
            c.fill("line", (x, 15, x, 19), C("c8a870"))
            c.shade("poly", [(x - 1, 19), (x + 1, 19), (x + 4, 34), (x - 4, 34)], ramp(light, light, dark), dither=False)
            r = random.Random(x)
            for _ in range(8):
                px, py = x + r.randrange(-3, 4), r.randrange(24, 35)
                if (px, py) in c.filled:
                    c.put(px, py, C(dark))
            c.fill("line", (x - 1, 20, x + 1, 20), C("c8a870"))
        # A basket of cuttings at the foot.
        c.shade("ellipse", (18, 48, 42, 61), ramp("c49a5a", "94703c", "64482a"))
        for x in range(20, 41, 3):
            c.fill("line", (x, 50, x, 59), C("6a4a2a"))
        for (x, y) in ((24, 47), (30, 46), (36, 48)):
            c.fill("ellipse", (x - 2, y - 2, x + 2, y + 1), C("6a9a3a"))
    elif kind == "jar_shelf":
        # A low shelf of jars and bottles (amber, green, blue, with corks),
        # a mortar and pestle on top.
        wood = ramp("9a7450", "6e5034", "4a3422")
        c.shade("rect", (6, 26, 58, 61), wood)
        c.fill("rect", (9, 29, 55, 41), C("3a2a1c"))
        c.fill("rect", (9, 45, 55, 58), C("3a2a1c"))
        c.shade("rect", (6, 42, 58, 44), wood)
        glass = [("e8a840", "a86a1a"), ("70c070", "3a7a3a"), ("70a0e0", "3a5a9a"), ("e07070", "9a3a3a"), ("d0c8e8", "8a80a8")]
        x = 11
        for i, (light, dark) in enumerate(glass * 2):
            h = [9, 6, 10, 7, 8][i % 5]
            row = 41 if i < 5 else 58
            c.shade("rect", (x, row - h, x + 5, row), ramp("ffffff", light, dark), dither=False)
            c.fill("rect", (x + 1, row - h - 2, x + 4, row - h), C("b08a5a"))
            c.put(x + 1, row - h + 2, C("ffffff"))
            x += 9 if i != 4 else -36
        c.shade("ellipse", (36, 18, 50, 27), ramp("c4c0cc", "8e8a98", "5a5664"))
        c.fill("line", (45, 20, 50, 12), C("b8b4c0"), 2)
    elif kind == "loom":
        # A weaver's loom: a heavy frame, warp threads, cloth half woven in a
        # red pattern, a shuttle on the beam.
        wood = ramp("a07a54", "74563a", "4e3826")
        for x in (8, 52):
            c.shade("rect", (x, 8, x + 4, 61), wood)
        for y in (8, 30, 54):
            c.shade("rect", (8, y, 56, y + 3), wood)
        for x in range(14, 51, 2):
            c.fill("line", (x, 11, x, 30), C("e8e0cc"))
        cloth = ramp("e06a5a", "b03a3a", "7a2028")
        c.shade("rect", (13, 33, 51, 52), cloth, dither=False)
        for y in range(35, 52, 4):
            for x in range(14, 51, 4):
                c.put(x + (y // 4) % 2 * 2, y, C("f0c860"))
        c.shade("rect", (24, 27, 40, 30), ramp("d8b880", "a8844c", "7a5a30"), dither=False)
    elif kind == "spinning_wheel":
        # A spinning wheel: the wheel and its spokes, the treadle, a distaff
        # wound with wool.
        wood = ramp("a07a54", "74563a", "4e3826")
        c.shade("rect", (10, 50, 54, 54), wood)
        for x in (14, 48):
            c.shade("rect", (x, 54, x + 2, 61), wood)
        c.fill("ellipse", (8, 12, 40, 44), wood[1])
        c.fill("ellipse", (11, 15, 37, 41), (0, 0, 0, 0))
        img = c.img
        for (x, y) in list(c.filled):
            if 11 < x < 37 and 15 < y < 41 and (x - 24) ** 2 + (y - 28) ** 2 < 12 ** 2:
                img.putpixel((x, y), (0, 0, 0, 0))
                c.filled.discard((x, y))
        for a in range(0, 360, 45):
            ex, ey = 24 + math.cos(math.radians(a)) * 13, 28 + math.sin(math.radians(a)) * 13
            c.fill("line", (24, 28, ex, ey), wood[2])
        c.shade("ellipse", (21, 25, 27, 31), wood)
        c.fill("line", (24, 28, 24, 50), wood[2], 2)
        c.fill("line", (40, 50, 46, 22), wood[1], 2)
        c.shade("ellipse", (40, 10, 54, 26), ramp("f6f2ea", "dcd4c4", "aaa090"))
        c.fill("line", (36, 28, 44, 20), C("e8e0d0"))
    elif kind == "grain_sacks":
        # Three sacks of grain, tied at the neck, one slumped, a little
        # grain spilled before them.
        sack = ramp("d8c08a", "b09868", "7e6a44")
        for (x0, y0, x1, y1) in ((6, 30, 30, 61), (30, 26, 54, 61), (20, 40, 42, 62)):
            c.shade("ellipse", (x0, y0, x1, y1), sack)
            mid = (x0 + x1) // 2
            c.fill("rect", (mid - 3, y0 - 3, mid + 3, y0 + 1), sack[1])
            c.fill("line", (mid - 3, y0 + 1, mid + 3, y0 + 1), C("6a4a2a"))
            c.fill("line", (mid - 4, y0 - 4, mid + 4, y0 - 4), sack[0])
            c.fill("line", (x0 + 4, (y0 + y1) // 2, x1 - 4, (y0 + y1) // 2 + 1), sack[2])
        r = random.Random(71)
        for _ in range(20):
            x, y = r.randrange(16, 48), r.randrange(60, 64)
            c.put(x, y, C("e8d080") if r.random() < 0.5 else C("c0a050"))
    elif kind == "tool_rack":
        # A rack of farm tools against the wall: pitchfork, scythe, rake,
        # a hoe, on pegs.
        wood = ramp("a07a54", "74563a", "4e3826")
        c.shade("rect", (6, 12, 58, 16), wood)
        c.shade("rect", (6, 50, 58, 53), wood)
        for x in (14, 26, 38, 50):
            c.fill("line", (x, 12, x, 60), C("8e6a44"), 2)
            c.fill("line", (x - 1, 12, x - 1, 60), C("c49a6c"))
        # Pitchfork tines.
        for dx in (-3, 0, 3):
            c.fill("line", (14 + dx, 4, 14 + dx, 12), IRON[1])
        c.fill("line", (11, 12, 17, 12), IRON[2])
        # Scythe blade.
        c.shade("poly", [(26, 6), (40, 2), (44, 6), (30, 9)], IRON, dither=False)
        c.fill("line", (27, 7, 42, 4), C("e8ecf2"))
        # Rake head.
        c.fill("line", (33, 10, 43, 10), IRON[1], 2)
        for x in range(33, 44, 2):
            c.put(x, 12, IRON[2])
        # Hoe.
        c.shade("rect", (46, 6, 54, 10), IRON, dither=False)
    elif kind == "pelt_rug":
        # A bear's pelt laid flat, seen from above: a broad hide with ragged
        # edges, four legs splayed out to clawed paws, the head at the top
        # with its muzzle forward, fur in streaks.
        fur = ramp("8a6444", "5e4028", "3a2616")
        hide = [(16, 30), (24, 27), (40, 27), (48, 30), (52, 42), (48, 54), (38, 58), (26, 58), (16, 54), (12, 42)]
        c.shade("poly", hide, fur)
        for (x0, y0, x1, y1) in ((18, 32, 6, 24), (46, 32, 58, 24), (16, 52, 5, 60), (48, 52, 59, 60)):
            c.fill("line", (x0, y0, x1, y1), fur[1], 5)
            c.fill("line", (x0, y0 - 1, x1, y1 - 1), fur[0])
            for k in range(3):
                c.put(x1 + (k - 1), y1 + (1 if y1 > y0 else -1) * 2, C("e8dcc8"))
        # The head: smaller than the hide, the muzzle pointing up.
        c.shade("ellipse", (25, 14, 39, 30), fur)
        c.shade("ellipse", (29, 9, 35, 18), ramp("a8805a", "7e5a3a", "54382a"))
        c.put(31, 9, C("1a1010"))
        c.put(32, 9, C("1a1010"))
        c.put(28, 19, C("1a1010"))
        c.put(36, 19, C("1a1010"))
        for (x, y) in ((25, 16), (39, 16)):
            c.shade("ellipse", (x - 2, y - 2, x + 2, y + 2), fur)
        # Fur: short streaks running down the hide.
        r = random.Random(73)
        for _ in range(70):
            x, y = r.randrange(14, 51), r.randrange(30, 57)
            if (x, y) in c.filled and (x, y + 1) in c.filled:
                colour = fur[0] if r.random() < 0.35 else fur[2]
                c.put(x, y, colour)
                c.put(x, y + 1, colour)
    elif kind == "antler_mount":
        # Antlers on a carved wooden plaque, hung on the wall.
        c.shade("ellipse", (22, 26, 42, 46), ramp("a07a54", "74563a", "4e3826"))
        c.fill("ellipse", (26, 30, 38, 42), C("5a4028"))
        bone = ramp("f0e6cc", "c8b896", "8e7e60")
        for side in (-1, 1):
            base = (32 + side * 4, 30)
            tips = [(32 + side * 20, 6), (32 + side * 24, 18), (32 + side * 12, 4), (32 + side * 26, 28)]
            c.fill("line", (base[0], base[1], 32 + side * 18, 14), bone[1], 2)
            for tip in tips:
                mid = (32 + side * 16, 16)
                c.fill("line", (mid[0], mid[1], tip[0], tip[1]), bone[1])
                c.put(tip[0], tip[1], bone[0])
            c.fill("line", (base[0] + side, base[1] - 1, 32 + side * 17, 13), bone[0])
    elif kind == "stool":
        # A three-legged stool with a round seat.
        wood = ramp("a07a54", "74563a", "4e3826")
        c.shade("ellipse", (20, 38, 44, 46), wood)
        c.fill("line", (22, 40, 42, 40), C("c49a6c"))
        for (x0, x1) in ((24, 20), (32, 32), (40, 44)):
            c.fill("line", (x0, 46, x1, 60), wood[2], 2)
        c.fill("line", (22, 54, 42, 54), wood[2])
    elif kind == "firewood":
        # Split logs stacked between two posts, their ends showing rings.
        wood = ramp("a07a54", "74563a", "4e3826")
        for x in (8, 54):
            c.shade("rect", (x, 26, x + 3, 61), wood)
        rings = ramp("e0c08a", "c09a62", "8a6a40")
        for row, y in enumerate((52, 44, 36, 28)):
            for k in range(5 - (1 if row % 2 else 0)):
                x = 15 + k * 9 + (4 if row % 2 else 0)
                c.shade("ellipse", (x - 4, y - 4, x + 4, y + 4), ramp("6e5034", "4e3822", "34241a"))
                c.shade("ellipse", (x - 3, y - 3, x + 3, y + 3), rings)
                c.put(x, y, C("8a6a40"))
    elif kind == "dresser":
        # A chest of drawers with brass handles, a jug and a small mirror on top.
        wood = ramp("9a7450", "6e5034", "4a3422")
        c.shade("rect", (8, 26, 56, 61), wood)
        c.fill("line", (8, 26, 56, 26), C("c49a6c"))
        for y in (30, 40, 50):
            c.shade("rect", (11, y, 53, y + 8), ramp("a88460", "7a5a3e", "523c28"), dither=False)
            for x in (22, 42):
                c.fill("rect", (x, y + 3, x + 2, y + 4), BRASS[0])
        c.shade("ellipse", (14, 14, 24, 26), ramp("f0f0f0", "c8ccd8", "8890a0"))
        c.shade("rect", (36, 10, 48, 25), ramp("c0a060", "9a7a40", "6a5228"))
        c.fill("rect", (38, 12, 46, 23), C("9ab4c8"))
        c.put(39, 13, C("e8f4ff"))
    elif kind == "cradle":
        # A wooden rocking cradle with a quilted blanket.
        wood = ramp("a07a54", "74563a", "4e3826")
        c.fill("ellipse", (8, 52, 56, 64), wood[2])
        c.fill("ellipse", (10, 54, 54, 62), (0, 0, 0, 0))
        for (x, y) in list(c.filled):
            if 10 < x < 54 and y > 53 and ((x - 32) / 22.0) ** 2 + ((y - 58) / 4.0) ** 2 < 1.0:
                c.img.putpixel((x, y), (0, 0, 0, 0))
                c.filled.discard((x, y))
        c.shade("rect", (12, 30, 52, 54), wood)
        c.shade("rect", (10, 22, 16, 54), wood)
        for x in range(18, 50, 5):
            c.fill("line", (x, 32, x, 52), wood[2])
        quilt = ramp("f0c0c8", "c88a98", "8a5a68")
        c.shade("rect", (16, 30, 50, 38), quilt, dither=False)
        for x in range(18, 50, 6):
            c.put(x, 33, C("fff0f4"))
        c.shade("ellipse", (14, 26, 22, 32), ramp("f8f4ec", "e0d8c8", "b0a898"))
    elif kind == "pots_rack":
        # A rack on the wall with copper pots and pans hanging from hooks.
        wood = ramp("a07a54", "74563a", "4e3826")
        c.shade("rect", (6, 10, 58, 14), wood)
        copper = ramp("f0a070", "c06a3a", "7a3a1e")
        hangs = [(12, "pan"), (26, "pot"), (40, "pan"), (52, "ladle")]
        for x, what in hangs:
            c.fill("line", (x, 14, x, 18), IRON[1])
            if what == "pan":
                c.fill("line", (x, 18, x, 26), C("4a3a2a"), 2)
                c.shade("ellipse", (x - 7, 26, x + 7, 40), copper)
                c.fill("ellipse", (x - 4, 29, x + 4, 37), copper[2])
            elif what == "pot":
                c.shade("rect", (x - 7, 20, x + 7, 36), copper)
                c.fill("line", (x - 8, 20, x + 8, 20), copper[0])
                c.fill("line", (x - 6, 22, x + 6, 22), copper[2])
            else:
                c.fill("line", (x, 18, x, 32), IRON[1])
                c.shade("ellipse", (x - 3, 31, x + 3, 37), IRON)
    elif kind == "yarn_basket":
        # A wicker basket of wool: balls of yarn in three colours, a loose end.
        c.shade("ellipse", (12, 38, 52, 61), ramp("c49a5a", "94703c", "64482a"))
        for x in range(14, 51, 3):
            c.fill("line", (x, 42, x, 59), C("6a4a2a"))
        for (x, y, colour) in ((22, 38, "d06a6a"), (32, 35, "6a8ad0"), (42, 38, "e0c060")):
            c.shade("ellipse", (x - 6, y - 6, x + 6, y + 6), ramp(colour, colour, "5a4a5a"))
            c.fill("line", (x - 4, y - 2, x + 3, y + 3), C("ffffff"))
        c.fill("line", (46, 40, 54, 52), C("e0c060"))
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


def manor():
    """Saint Lull's House at its full size (128px, drawn pixel by pixel, never
    scaled): a long white house of two floors under a slate roof, a bell
    tower in the middle with a bronze bell, stone quoins and a stone plinth,
    shuttered windows lit warm with flower boxes, a red door under a little
    portico up three steps, and ivy up one corner."""
    c = Canvas(128, 128)
    plaster = ramp("f6f2e8", "dcd6c8", "aca496")
    plaster_dark = ramp("d6d0c2", "bab2a2", "8e8676")
    slate = ramp("6a7282", "4a5262", "2e3442")
    stone = ramp("c4c0b4", "9a968a", "6c685e")
    navy = ramp("4a5a8a", "34426a", "222c4a")
    c.shadow(64, 121, 58, 6, alpha=90)
    # The plinth and the two floors of wall.
    c.shade("rect", (8, 62, 119, 116), plaster, dither=False)
    c.fill("line", (8, 62, 119, 62), C("fffcf4"))
    c.shade("rect", (6, 112, 121, 120), stone, dither=False)
    for x in range(8, 120, 9):
        c.put(x, 116, C("6c685e"))
    c.fill("line", (6, 112, 121, 112), C("d8d4c8"))
    # A band between the floors.
    c.fill("rect", (8, 86, 119, 88), C("e8e2d4"))
    c.fill("line", (8, 89, 119, 89), C("aca496"))
    # Stone quoins up the corners.
    for x0 in (8, 114):
        for k, y in enumerate(range(64, 112, 6)):
            w = 6 if k % 2 == 0 else 4
            x = x0 if x0 == 8 else 119 - w + 1
            c.shade("rect", (x, y, x + w - 1, y + 4), stone, dither=False)
    # Faint weathering streaks under the sills.
    r = random.Random(13)
    for _ in range(60):
        x, y = r.randrange(12, 116), r.randrange(66, 110)
        if c.img.getpixel((x, y))[:3] == plaster[1][:3]:
            c.put(x, y, plaster_dark[1])
    # The roof: two slopes of slate in rows, the near face lit.
    c.shade("poly", [(2, 64), (16, 34), (112, 34), (126, 64)], slate)
    for row, y in enumerate(range(38, 64, 4)):
        c.fill("line", (16 - (y - 34) // 2, y, 112 + (y - 34) // 2, y), C("2a303c"))
        for x in range(18 - (y - 34) // 2 + (row % 2) * 3, 110 + (y - 34) // 2, 6):
            c.put(x, y + 1, C("2a303c"))
            c.put(x, y + 2, C("3a4252"))
    c.fill("line", (16, 34, 112, 34), C("8a92a2"))
    c.fill("line", (2, 64, 126, 64), C("1e222c"))
    c.fill("line", (3, 63, 125, 63), C("8a92a2"))
    # Two dormers in the roof.
    for x in (24, 92):
        c.shade("rect", (x, 44, x + 11, 58), plaster, dither=False)
        c.shade("poly", [(x - 2, 45), (x + 6, 38), (x + 14, 45)], slate, dither=False)
        c.fill("rect", (x + 3, 48, x + 8, 56), C("2a2630"))
        c.fill("rect", (x + 4, 49, x + 7, 55), C("f0c060"))
        c.fill("line", (x + 4, 52, x + 7, 52), C("8a6a3a"))
        c.fill("line", (x + 5, 49, x + 5, 55), C("8a6a3a"))
    # Chimneys, one at each end.
    for x in (12, 106):
        c.shade("rect", (x, 26, x + 7, 44), ramp("b45a4a", "8a4038", "5a2a26"), dither=False)
        c.fill("rect", (x - 1, 24, x + 8, 26), C("6c685e"))
        for y in (30, 35, 40):
            c.fill("line", (x, y, x + 7, y), C("5a2a26"))
    # The bell tower.
    c.shade("rect", (52, 14, 75, 64), plaster, dither=False)
    c.shade("rect", (50, 12, 77, 16), stone, dither=False)
    c.shade("poly", [(48, 13), (64, 0), (79, 13)], slate, dither=False)
    c.fill("line", (64, 0, 64, 4), C("c8904a"))
    c.put(65, 2, C("e8bc4a"))
    c.put(66, 2, C("e8bc4a"))
    # The belfry: an arched opening, a bronze bell hanging in the dark.
    c.fill("rect", (57, 20, 70, 34), C("1a1820"))
    c.fill("ellipse", (57, 16, 70, 26), C("1a1820"))
    c.fill("line", (57, 21, 70, 21), C("3a3644"))
    c.shade("poly", [(60, 30), (61, 24), (63, 22), (65, 22), (67, 24), (68, 30)], ramp("e8bc4a", "c8904a", "8a5a2a"), dither=False)
    c.fill("line", (59, 31, 69, 31), C("8a5a2a"))
    c.put(64, 32, C("c8904a"))
    # A round window, and a clock-face, in the tower.
    c.shade("ellipse", (58, 40, 69, 51), stone, dither=False)
    c.fill("ellipse", (60, 42, 67, 49), C("f6f2e8"))
    c.fill("line", (63, 43, 63, 46), C("1a1820"))
    c.fill("line", (63, 46, 65, 46), C("1a1820"))
    # Windows: two floors of them, shuttered in navy, lit warm, with boxes
    # of red flowers below the lower ones.
    for x in (16, 30, 86, 100):
        for y, tall in ((68, 13), (93, 14)):
            c.shade("rect", (x - 3, y, x - 1, y + tall), navy, dither=False)
            c.shade("rect", (x + 10, y, x + 12, y + tall), navy, dither=False)
            c.fill("rect", (x, y, x + 9, y + tall), C("2a2630"))
            c.fill("rect", (x + 1, y + 1, x + 8, y + tall - 1), C("f0c060"))
            c.fill("rect", (x + 1, y + 1, x + 8, y + 3), C("f8dc90"))
            c.fill("line", (x + 4, y + 1, x + 4, y + tall - 1), C("8a6a3a"))
            c.fill("line", (x + 1, y + tall // 2, x + 8, y + tall // 2), C("8a6a3a"))
            c.fill("line", (x - 1, y + tall + 1, x + 10, y + tall + 1), C("aca496"))
            if y > 80:
                c.fill("rect", (x, y + tall + 2, x + 9, y + tall + 4), C("6a4a30"))
                for k in range(x, x + 10, 2):
                    c.put(k, y + tall + 1, C("c83a3a") if k % 4 else C("e86a5a"))
                    c.put(k + 1, y + tall + 1, C("4f6a34"))
    # Two narrow lit windows by the tower.
    for x in (44, 79):
        for y in (70, 94):
            c.fill("rect", (x, y, x + 4, y + 10), C("2a2630"))
            c.fill("rect", (x + 1, y + 1, x + 3, y + 9), C("f0c060"))
    # The portico: two white columns, a pediment, the red door up three steps.
    c.shade("poly", [(50, 84), (64, 76), (77, 84)], plaster, dither=False)
    c.fill("line", (50, 84, 77, 84), C("aca496"))
    c.shade("rect", (51, 85, 76, 87), stone, dither=False)
    for x in (52, 72):
        c.shade("rect", (x, 88, x + 3, 112), ramp("fffcf4", "e8e2d4", "b8b0a2"), dither=False)
        c.fill("rect", (x - 1, 88, x + 4, 89), C("d8d4c8"))
        c.fill("rect", (x - 1, 110, x + 4, 112), C("d8d4c8"))
    c.fill("rect", (57, 90, 70, 112), C("2a1a1c"))
    c.fill("ellipse", (57, 86, 70, 96), C("2a1a1c"))
    c.shade("rect", (58, 92, 69, 112), ramp("c84848", "a03038", "6a1c28"), dither=False)
    c.shade("ellipse", (58, 88, 69, 98), ramp("c84848", "a03038", "6a1c28"), dither=False)
    c.fill("line", (63, 89, 63, 112), C("5c1c28"))
    c.fill("line", (64, 89, 64, 112), C("5c1c28"))
    for y in (97, 104):
        c.fill("line", (59, y, 68, y), C("7a2430"))
    c.put(61, 101, C("e8bc4a"))
    c.put(66, 101, C("e8bc4a"))
    c.fill("rect", (62, 92, 65, 93), C("e8bc4a"))
    for i, y in enumerate((113, 116, 119)):
        c.shade("rect", (54 - i * 2, y, 73 + i * 2, y + 2), stone, dither=False)
        c.fill("line", (54 - i * 2, y, 73 + i * 2, y), C("e0dcd0"))
    # Ivy up the west corner and over the first window.
    for _ in range(150):
        x = r.randrange(6, 26)
        y = r.randrange(66 + max(0, 20 - x) , 116)
        if (x, y) in c.filled and r.random() < 0.65 - (x - 6) * 0.025:
            c.put(x, y, C("4f6a34") if r.random() < 0.6 else C("6d8a44"))
            if r.random() < 0.3:
                c.put(x + 1, y, C("3a5228"))
    c.outline()
    return c.img



def ladder():
    """A sturdy ladder: two split rails with bark at the edges, six rungs
    pegged through them (the pegs showing), rope lashings at the top, and
    a little shadow on the wall behind."""
    c = Canvas(64, 64)
    rail = ramp("b08a5c", "84603e", "54381f")
    c.fill("rect", (20, 6, 46, 62), C("000000", 40))
    for x in (18, 40):
        c.shade("rect", (x, 2, x + 5, 62), rail)
        c.fill("line", (x + 1, 3, x + 1, 61), C("d0a474"), 1)
        c.fill("line", (x + 5, 3, x + 5, 61), C("40301e"), 1)
    for k, y in enumerate(range(8, 60, 9)):
        c.shade("rect", (23, y, 40, y + 3), ramp("c09468", "8e6640", "5e4028"))
        c.fill("line", (23, y, 40, y), C("e0b888"), 1)
        c.fill("line", (23, y + 3, 40, y + 3), C("3a2818"), 1)
        for x in (19, 43):
            c.put(x, y + 1, C("4a3220"))
            c.put(x + 1, y + 1, C("6a4a30"))
    for x in (18, 40):
        for y in (3, 5):
            c.fill("line", (x - 1, y, x + 6, y + 1), C("c8b890"), 1)
    c.outline()
    return c.img


def house():
    """A village cottage in three-quarter view, with depth: a timber-framed
    gable front, its plaster lit; a side wall falling back into shade; a
    shingled roof with a thick eave and the far slope showing; a stone
    chimney; a foundation of fitted stones; a door with its frame and step;
    shuttered windows lit warm; a flower box; and a shadow on the ground."""
    c = Canvas(64, 64)
    plaster = ramp("f0e4c8", "d8c8a4", "a8987a")
    plaster_side = ramp("c4b494", "a49474", "7a6c54")
    timber = ramp("7a5636", "5a3e28", "3a2818")
    roof = ramp("b0503c", "86382c", "5a241c")
    roof_far = ramp("8a3a2c", "6a2a22", "461a16")
    stone = ramp("a8a4b0", "7c7888", "52505e")
    c.shadow(34, 61, 30, 3, 90)
    # The side wall, going back to the right.
    c.shade("poly", [(42, 32), (58, 24), (58, 54), (42, 60)], plaster_side, dither=False)
    for y in (36, 46):
        c.fill("line", (42, y, 58, y - 8), timber[1], 1)
    c.fill("line", (50, 28, 50, 57), timber[1], 1)
    c.shade("rect", (51, 38, 55, 44), ramp("f8d888", "d8a050", "8a5a2a"))
    c.fill("line", (42, 32, 42, 60), timber[2], 1)
    # The front gable wall.
    c.shade("poly", [(6, 32), (24, 16), (42, 32), (42, 60), (6, 60)], plaster, dither=False)
    for (a, b) in (((6, 32), (42, 32)), ((6, 46), (42, 46)), ((6, 32), (6, 60)), ((42, 32), (42, 60)), ((24, 18), (24, 32))):
        c.fill("line", (a[0], a[1], b[0], b[1]), timber[1], 2)
    c.fill("line", (8, 32, 22, 46), timber[1], 1)
    c.fill("line", (40, 32, 26, 46), timber[1], 1)
    # Foundation stones.
    for k, x in enumerate(range(5, 58, 5)):
        y0 = 57 if x < 43 else 57 - (x - 42) * 8 // 16
        c.shade("rect", (x, y0, x + 4, y0 + 3), stone, dither=False)
    # The door, its frame and a step.
    c.shade("rect", (19, 47, 29, 59), timber)
    c.shade("rect", (20, 48, 28, 59), ramp("8a5a34", "6a4428", "4a2e1a"))
    c.fill("line", (24, 48, 24, 59), C("3a2414"), 1)
    c.put(26, 53, C("e8c060"))
    c.shade("rect", (17, 59, 31, 61), stone)
    # Windows with shutters, lit warm.
    for x in (9, 33):
        c.shade("rect", (x, 49, x + 6, 55), ramp("ffe8a0", "f0c060", "b08030"))
        c.fill("line", (x + 3, 49, x + 3, 55), timber[2], 1)
        c.fill("line", (x, 52, x + 6, 52), timber[2], 1)
        c.shade("rect", (x - 2, 49, x - 1, 55), ramp("5a7ab0", "3e5a8a", "2a3e60"))
        c.shade("rect", (x + 7, 49, x + 8, 55), ramp("5a7ab0", "3e5a8a", "2a3e60"))
        c.shade("rect", (x - 1, 56, x + 7, 57), timber)
        for k in range(4):
            c.put(x + k * 2, 55, C(["e05a6a", "f0e070", "f0f0e8", "a070e0"][k]))
    c.shade("rect", (21, 36, 27, 42), ramp("ffe8a0", "f0c060", "b08030"))
    c.fill("line", (24, 36, 24, 42), timber[2], 1)
    # The roof: far slope, near slope over the gable with a thick eave.
    c.shade("poly", [(24, 10), (40, 4), (62, 22), (46, 30)], roof_far)
    c.shade("poly", [(24, 10), (46, 30), (42, 34), (20, 14)], roof)
    c.shade("poly", [(24, 10), (2, 32), (6, 35), (24, 16), (42, 35), (46, 30)], roof)
    c.fill("line", (2, 32, 24, 10), C("e07a5a"), 1)
    c.fill("line", (6, 35, 24, 17), C("3a1610"), 1)
    c.fill("line", (24, 17, 42, 35), C("3a1610"), 1)
    for k in range(5):
        y = 14 + k * 4
        for x in range(28 + k * 3, 58, 5):
            c.put(x, y + (x - 28) // 6, C("5a241c"))
    # The chimney.
    c.shade("rect", (48, 6, 54, 20), stone)
    c.shade("rect", (47, 4, 55, 7), ramp("c4c0cc", "9a96a4", "6a6676"))
    for y in (10, 14, 18):
        c.fill("line", (48, y, 54, y), C("4a4652"), 1)
    c.outline()
    return c.img

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
         "standing_stone", "carved_pillar", "rune_stele", "chime_stone", "stone_pedestal", "stone_shard",
         "manor", "iron_gate", "carriage", "hatch", "horn_post",
         # Furnishings for the inside of houses, by who lives there.
         "writing_desk", "cauldron", "herb_rack", "jar_shelf", "loom", "spinning_wheel", "grain_sacks", "tool_rack",
         "pelt_rug", "antler_mount", "stool", "firewood", "dresser", "cradle", "pots_rack", "yarn_basket",
         # Each thing its own art: the ring of a henge is not made of waystones.
         "menhir", "lever", "answer_tablet",
         # The waygate the player builds, linked to the waystones.
         "waygate",
         # Furnishings of the peoples: elves, dwarves and goblins at home.
         "elf_lamp", "elf_hanging", "elf_basin", "dwarf_keg", "dwarf_table", "dwarf_trophy",
         "goblin_totem", "goblin_scrap", "goblin_bed",
         # Dressing for crypts, caves and ruins.
         "wall_torch", "cobweb", "wall_carving", "chains", "ivy_wall"]


def sheet(images, w, h):
    out = Image.new("RGBA", (w * len(images), h), (0, 0, 0, 0))
    for i, img in enumerate(images):
        out.paste(img, (i * w, 0))
    return out


def write_flora_sheets():
    """The tall and small flora sheets, with the redrawn flowers, mushrooms
    and bushes (tools/generate_plants.py) in their places."""
    import generate_plants
    generate_plants.redraw(SMALL, TALL)
    sheet(TALL, 64, 96).save(os.path.join(ROOT, "flora_tall.png"))
    sheet(SMALL, 32, 32).save(os.path.join(ROOT, "flora_small.png"))


def write_decor_sheet():
    """The decor sheet, with the props redrawn in phase 5
    (tools/generate_props.py) in place of their older drawings."""
    import generate_props
    PROPS_V2.update(generate_props.PROPS)
    sheet([decor(k) for k in DECOR], 64, 64).save(os.path.join(ROOT, "decor.png"))


if __name__ == "__main__":
    write_flora_sheets()
    # The critters are drawn at 32x32 by tools/generate_critters.py.
    import generate_critters
    generate_critters.main()
    write_decor_sheet()
    manor().save(os.path.join(ROOT, "manor.png"))
