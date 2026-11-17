#!/usr/bin/env python3
"""Draws the ruins of the dead god (assets/sprites/ruins.png), each piece
in a 160 x 144 cell standing on the cell's bottom (y = 136), centred:

  0  the Colossus's face, fallen: a great serene face half sunk in the
     earth, eyes closed, a broken circlet on its brow and an empty socket
     where a heart of red stone was set; cracks, moss in them
  1  its hand: open on the ground, palm down, one finger snapped off and
     lying beside it
  2  a broken arch: two square piers, the arch standing on one side and
     fallen from the other at a jagged break, vines hanging
  3  the stumps of an arch's piers, one taller than the other
  4  a column drum toppled on its side, fluted, its broken end showing
  5  arch stones fallen in a heap

The stone is the god's: a pale, warm, weathered limestone, lit from the
upper left; crimson veins run through it here and there (the heart that
still beats under the land). Outlined in the game's near-black.

Run from the project folder:  python3 tools/generate_ruins.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "ruins.png")
CELL = (160, 144)
FOOT = 136
OUTLINE = (12, 10, 16, 255)


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


GOD = [C("e4dccb"), C("c4baa6"), C("9c9280"), C("756c5e"), C("514a40")]   # highlight, light, mid, shade, deep
SEAM = C("3a342e")
MOSS = [C("98bc54"), C("6a9a38"), C("44702a"), C("2c4a1e")]
VEIN = [C("f07070"), C("c0303e"), C("801a2a"), C("4a0c18")]
SOIL = [C("6a5038"), C("4e3a28"), C("33261a")]
GRASS = [C("7a9c48"), C("557a34"), C("3a5826")]
VINE = [C("7aa846"), C("4e7a2e"), C("2e4c1c")]


class Canvas:
    """A pixel canvas that remembers what it filled (to outline it after)."""

    def __init__(self):
        self.w, self.h = CELL
        self.img = Image.new("RGBA", CELL, (0, 0, 0, 0))
        self.filled = set()

    def put(self, x, y, c, solid=True):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), c)
            if solid:
                self.filled.add((x, y))

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.img.getpixel((x, y))
        return (0, 0, 0, 0)

    def mask(self, shape, coords, width=1):
        m = Image.new("L", CELL, 0)
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

    def stone(self, pts, ramp=GOD, light=(-0.62, -0.78), bands=(0.5, 0.15, -0.25, -0.6)):
        """Fills pixels as rounded stone, five tones from the light."""
        if not pts:
            return
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        rx, ry = max((max(xs) - min(xs)) / 2, 1), max((max(ys) - min(ys)) / 2, 1)
        for x, y in pts:
            t = (x - cx) / rx * light[0] + (y - cy) / ry * light[1]
            # Dither between bands so the turn of the stone is soft but whole-pixel.
            for b in bands:
                if abs(t - b) < 0.06:
                    t += 0.07 if (x + y) % 2 else -0.07
            k = 0 if t > bands[0] else 1 if t > bands[1] else 2 if t > bands[2] else 3 if t > bands[3] else 4
            self.put(x, y, ramp[k])

    def outline(self, colour=OUTLINE):
        add = []
        for (x, y) in list(self.filled):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in self.filled and 0 <= n[0] < self.w and 0 <= n[1] < self.h:
                    add.append(n)
        for x, y in add:
            self.img.putpixel((x, y), colour)

    def crack(self, r, x, y, length, angle, wobble=0.5, colour=SEAM, lip=True):
        """A crack running from (x, y): dark, with a lit lip on its upper side."""
        pts = []
        for _ in range(length):
            angle += r.uniform(-wobble, wobble)
            x += math.cos(angle)
            y += math.sin(angle)
            px, py = int(round(x)), int(round(y))
            if (px, py) not in self.filled:
                break
            pts.append((px, py))
        for px, py in pts:
            self.img.putpixel((px, py), colour)
            if lip and (px, py - 1) in self.filled and (px, py - 1) not in pts:
                self.img.putpixel((px, py - 1), GOD[0])
        return pts

    def moss(self, r, pts, chance=0.5):
        """Moss gathered along cracks and on top of the stone."""
        for (x, y) in pts:
            if r.random() < chance:
                for dx, dy in ((0, 0), (1, 0), (0, -1)):
                    if (x + dx, y + dy) in self.filled and r.random() < 0.7:
                        self.img.putpixel((x + dx, y + dy), MOSS[r.randint(1, 3)])

    def moss_cap(self, r, cover=0.55, depth=3):
        """Moss on every upward-facing edge, thicker in places."""
        tops = [(x, y) for (x, y) in self.filled if (x, y - 1) not in self.filled]
        for (x, y) in tops:
            if r.random() > cover:
                continue
            d = r.randint(1, depth)
            for k in range(d):
                if (x, y + k) in self.filled:
                    self.img.putpixel((x, y + k), MOSS[0] if k == 0 else MOSS[1] if k == 1 else MOSS[2])

    def ground(self, cx, half, depth=4):
        """The earth mounded where a piece sinks in, grass along it."""
        for x in range(int(cx - half), int(cx + half)):
            t = abs(x - cx) / half
            h = int(round((1 - t * t) * depth))
            for k in range(h + 1):
                y = FOOT - k
                self.put(x, y, SOIL[0] if k == h else SOIL[1] if k > h - 3 else SOIL[2])
            if (x * 7) % 5 < 3:
                top = FOOT - h - 1
                self.put(x, top, GRASS[(x * 3) % 3])
                if x % 3 == 0:
                    self.put(x, top - 1, GRASS[0])

    def shadow(self, cx, rx, ry=7, alpha=70):
        layer = Image.new("RGBA", CELL, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.ellipse((cx - rx, FOOT - ry + 2, cx + rx, FOOT + ry - 2), fill=(0, 0, 0, alpha))
        layer.alpha_composite(self.img)
        self.img = layer


def vein(c, r, x, y, length, angle):
    """A crimson vein in the stone, brighter where it catches the light."""
    pts = c.crack(r, x, y, length, angle, wobble=0.35, colour=VEIN[2], lip=False)
    for i, (px, py) in enumerate(pts):
        if i % 4 == 1:
            c.img.putpixel((px, py), VEIN[1])
        if i % 9 == 4:
            c.img.putpixel((px, py), VEIN[0])
    return pts


def colossus_face():
    c = Canvas()
    r = random.Random(11)
    cx = 80
    # The head: a long oval, sunk to the jaw in the earth. Shaded as one mass
    # first, then carved: hair, diadem, brow, sockets, lids, nose, lips.
    head = [p for p in c.mask("ellipse", (34, 20, 126, 140)) if p[1] <= FOOT - 1]
    hs = set(head)
    c.stone(head)

    def inside(x, y):
        return (int(x), int(y)) in hs

    # Hair: carved locks in waving ridges over the crown.
    for y in range(22, 46):
        for x in range(34, 127):
            if not inside(x, y):
                continue
            # Locks: each a few pixels wide, curling, offset from the next.
            lock = (x - 34) // 9
            wave = math.sin(x * 0.11 + lock * 1.7) * 3.0 + (lock % 2) * 2.5
            phase = (y + wave) % 6.0
            if phase < 1.0:
                c.put(x, y, GOD[4] if x > cx + 10 else GOD[3])
            elif phase < 2.0:
                c.put(x, y, GOD[0] if x < cx else GOD[1])
    # The diadem: a band across the brow, lit along its top, with rays
    # standing up from it, most broken.
    for y in range(45, 51):
        for x in range(34, 127):
            if inside(x, y):
                tone = 0 if y == 45 else 1 if x < cx - 8 else 2 if x < cx + 18 else 3
                c.put(x, y, GOD[tone] if y < 50 else GOD[4])
    for k, rx in enumerate(range(44, 120, 9)):
        height = [9, 4, 12, 2, 14, 3, 10, 5, 7][k % 9]
        for h in range(1, height):
            w = max(0, (height - h) // 4)
            for dx in range(-w, w + 1):
                if inside(rx + dx, 45 - h) or h < height:
                    c.put(rx + dx, 45 - h, GOD[0] if dx <= 0 and rx < cx + 20 else GOD[2])
        if height < 6:
            c.put(rx, 45 - height, GOD[4])
    # The setting in the diadem where the red stone was: an empty almond,
    # its rim still faintly red.
    socket = set(c.mask("poly", [(80, 43), (85, 47), (80, 52), (75, 47)]))
    for (x, y) in socket:
        c.put(x, y, C("1c0a0e"))
    for (x, y) in socket:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in socket and inside(*n):
                c.img.putpixel(n, VEIN[1] if dy < 0 or dx < 0 else VEIN[2])
    c.put(78, 46, VEIN[3])
    c.put(79, 47, VEIN[2])
    # The brow: a lit ridge with shade under it.
    for x in range(44, 117):
        y = 57 + int(round(abs(x - cx) / 14.0))
        if inside(x, y):
            c.put(x, y, GOD[0] if x < cx + 6 else GOD[1])
            c.put(x, y + 1, GOD[1] if x < cx else GOD[2])
    # Sockets: hollows under the brow, then the closed lids in them.
    for side in (-1, 1):
        ex = cx + side * 19
        hollow = c.mask("ellipse", (ex - 11, 61, ex + 11, 73))
        for (x, y) in hollow:
            if inside(x, y):
                c.put(x, y, GOD[3] if side < 0 else GOD[4])
        for i in range(-10, 11):
            y = 67 + int(round(i * i / 34.0))
            # The lid, swelling over the eye, lit on top.
            c.put(ex + i, y - 2, GOD[1] if side < 0 else GOD[2])
            c.put(ex + i, y - 1, GOD[2] if side < 0 else GOD[3])
            c.put(ex + i, y, SEAM)
            if abs(i) < 9:
                c.put(ex + i, y + 1, GOD[2] if side < 0 else GOD[3])
        # The corner of each eye, deeper.
        c.put(ex - 11 * side, 68, SEAM)
    # The nose: a lit plane on the left, a shaded one on the right, and the
    # shadow it throws on the cheek.
    for y in range(60, 98):
        w = 2 + max(0, y - 80) // 6
        for dx in range(-w, 1):
            c.put(cx + dx, y, GOD[0] if dx == -w else GOD[1])
        for dx in range(1, w + 2):
            c.put(cx + dx, y, GOD[3])
        shade = max(0, 9 - abs(y - 86) // 2)
        for dx in range(w + 2, w + 2 + shade):
            if inside(cx + dx, y):
                c.put(cx + dx, y, GOD[3] if dx < w + 2 + shade - 1 else GOD[2])
    for dx in range(-6, 8):
        c.put(cx + dx, 98, GOD[2] if dx < 0 else GOD[3])
    for side in (-1, 1):
        c.put(cx + side * 4, 97, SEAM)
        c.put(cx + side * 5, 97, SEAM)
        c.put(cx + side * 6, 98, SEAM)
    c.put(cx - 1, 99, GOD[4])
    # The groove above the lip.
    for y in range(100, 105):
        c.put(cx - 1, y, GOD[2])
        c.put(cx + 1, y, GOD[3])
    # Lips: the upper in shade, the lower catching the light, the corners deep.
    for i in range(-13, 14):
        bow = int(round(abs(i) / 7.0))
        c.put(cx + i, 106 + bow, GOD[3])
        c.put(cx + i, 107 + bow, SEAM)
        if abs(i) < 11:
            c.put(cx + i, 108 + bow, GOD[1] if i < 3 else GOD[2])
            c.put(cx + i, 109 + bow, GOD[2] if i < 3 else GOD[3])
    for side in (-1, 1):
        c.put(cx + side * 14, 108, SEAM)
    # The chin's lower edge in shadow.
    for i in range(-10, 11):
        c.put(cx + i, 118 + int(round(i * i / 40.0)), GOD[3])
    # Cracks: the great one from the crown through the left eye to the jaw,
    # and lesser ones, moss in them.
    cracks = c.crack(r, 58, 24, 92, 1.32, wobble=0.3)
    cracks += c.crack(r, 112, 40, 34, 1.9)
    cracks += c.crack(r, 44, 96, 18, -0.4)
    cracks += c.crack(r, 116, 104, 16, 2.7)
    # A red tear from the empty setting down between the eyes.
    vein(c, r, 80, 53, 16, 1.62)
    c.moss(r, cracks, 0.6)
    c.moss_cap(r, cover=0.5, depth=3)
    # A piece broken off the right side of the head.
    for (x, y) in c.mask("poly", [(118, 52), (127, 60), (126, 78), (119, 70)]):
        if inside(x, y):
            c.put(x, y, GOD[4] if (x + y) % 3 else SEAM)
    c.ground(cx, 56, depth=6)
    c.outline()
    c.shadow(cx, 60)
    return c.img


def colossus_hand():
    c = Canvas()
    r = random.Random(23)
    cx = 80
    # The back of the hand, palm down: a broad rounded slab.
    palm = [p for p in c.mask("ellipse", (42, 88, 116, 140)) if p[1] <= 129]
    c.stone(palm)
    # Fingers: long, tapering, rounded at the tips, reaching away.
    fingers = [(57, 94, -0.26, 40), (71, 91, -0.08, 47), (86, 91, 0.08, 43), (100, 95, 0.28, 33)]
    for i, (x0, y0, lean, length) in enumerate(fingers):
        broken = i == 2
        reach = length * (0.45 if broken else 1.0)
        steps = int(reach)
        pts = []
        for s_ in range(steps + 1):
            t = s_ / max(length, 1)
            width = 5.6 - t * 1.6
            x = x0 + math.sin(lean) * s_
            y = y0 - math.cos(lean) * s_
            pts += c.mask("ellipse", (x - width, y - width * 0.8, x + width, y + width * 0.8))
        c.stone(list(set(pts)))
        # Knuckle creases: short, on the lit side only.
        for t in (0.36, 0.7):
            if t * length > reach - 2:
                continue
            kx, ky = x0 + math.sin(lean) * length * t, y0 - math.cos(lean) * length * t
            for dx in range(-4, 1):
                c.put(kx + dx, ky, GOD[3])
                c.put(kx + dx, ky - 1, GOD[0])
        if broken:
            ex, ey = x0 + math.sin(lean) * reach, y0 - math.cos(lean) * reach
            for dx in range(-4, 5):
                c.put(ex + dx, ey, GOD[4] if dx % 2 else SEAM)
    # The thumb, folded under on the left.
    thumb = c.mask("line", (50, 120, 32, 104), width=11)
    c.stone(thumb)
    # The broken finger lying beside the hand.
    piece = c.mask("line", (118, 74, 134, 92), width=10)
    c.stone(piece)
    for dy in range(-4, 5):
        c.put(117 + dy // 3, 74 + dy, GOD[4])
    cracks = c.crack(r, 60, 108, 30, 0.2) + c.crack(r, 96, 104, 20, 1.9)
    vein(c, r, 72, 116, 18, -0.3)
    c.moss(r, cracks, 0.55)
    c.moss_cap(r, cover=0.4, depth=2)
    c.ground(cx, 46, depth=3)
    c.outline()
    c.shadow(cx, 52, ry=6)
    return c.img


def pier(c, r, x, top, width=18, base=FOOT - 1, capital=True):
    """A square pier: base, shaft in courses, a capital."""
    shaft = c.mask("rect", (x - width // 2, top, x + width // 2, base))
    c.stone(shaft, light=(-0.95, -0.2), bands=(0.55, 0.2, -0.2, -0.65))
    # Courses of stone.
    for y in range(top + 8, base, 9):
        for dx in range(-width // 2, width // 2 + 1):
            c.put(x + dx, y, SEAM)
            c.put(x + dx, y + 1, GOD[0] if dx < 0 else GOD[1])
    # Base and capital, wider.
    for y in range(base - 4, base + 1):
        for dx in range(-width // 2 - 3, width // 2 + 4):
            c.put(x + dx, y, GOD[1] if y == base - 4 else GOD[3] if dx > 0 else GOD[2])
    if capital:
        for y in range(top - 5, top + 1):
            for dx in range(-width // 2 - 4, width // 2 + 5):
                c.put(x + dx, y, GOD[0] if y == top - 5 else GOD[2] if dx < 0 else GOD[3])
    return shaft


def broken_arch():
    c = Canvas()
    r = random.Random(37)
    left, right = 46, 114
    pier(c, r, left, 54)
    pier(c, r, right, 62)
    # The arch: voussoirs from the left pier over to the keystone and on,
    # broken off past it, a jagged end.
    cx, cy, outer, inner = 80, 54, 42, 27
    stones = []
    for k in range(12):
        a0 = math.pi + k * math.pi / 11
        a1 = a0 + math.pi / 11 - 0.03
        if k >= 8:
            break
        poly = [(cx + math.cos(a0) * inner, cy + math.sin(a0) * inner), (cx + math.cos(a0) * outer, cy + math.sin(a0) * outer),
                (cx + math.cos(a1) * outer, cy + math.sin(a1) * outer), (cx + math.cos(a1) * inner, cy + math.sin(a1) * inner)]
        pts = c.mask("poly", poly)
        c.stone(pts, light=(-0.4, -0.9))
        stones.append(poly)
        # The joint after each stone.
        for t in range(inner, outer + 1):
            c.put(cx + math.cos(a1) * t, cy + math.sin(a1) * t, SEAM)
    # The break: chipped, uneven.
    a = math.pi + 8 * math.pi / 11 - 0.03
    for t in range(inner, outer + 1):
        jag = r.randint(0, 2)
        x, y = cx + math.cos(a) * t + jag, cy + math.sin(a) * t
        c.put(x, y, GOD[4])
    # A carved band along the arch's face.
    for k in range(80):
        ang = math.pi + k * (8 * math.pi / 11) / 80
        x, y = cx + math.cos(ang) * (outer - 4), cy + math.sin(ang) * (outer - 4)
        if (int(x), int(y)) in c.filled:
            c.put(x, y, GOD[3] if k % 6 < 3 else GOD[1])
    # Vines hanging from the arch, leaves on them.
    for vx in (52, 63, 74, 86):
        top = None
        for y in range(0, FOOT):
            if (vx, y) in c.filled and (vx, y + 1) not in c.filled and y > 20:
                top = y
                break
        if top is None:
            continue
        length = r.randint(14, 34)
        x = vx
        for y in range(top + 1, min(top + length, FOOT - 6)):
            x += r.choice((0, 0, 0, 1, -1)) * 0.5
            c.put(x, y, VINE[1])
            if r.random() < 0.3:
                side = r.choice((-1, 1))
                c.put(x + side, y, VINE[0])
                c.put(x + side, y + 1, VINE[2])
    cracks = c.crack(r, left - 4, 80, 26, 1.6) + c.crack(r, right + 3, 96, 18, 1.7)
    vein(c, r, left + 2, 104, 14, 1.4)
    c.moss(r, cracks, 0.5)
    c.moss_cap(r, cover=0.6, depth=3)
    c.ground(80, 54, depth=2)
    c.outline()
    c.shadow(80, 58, ry=6)
    return c.img


def arch_stumps():
    c = Canvas()
    r = random.Random(41)
    pier(c, r, 50, 92, capital=False)
    pier(c, r, 110, 112, capital=False)
    # Broken tops: rough and chipped.
    for x0, top in ((50, 92), (110, 112)):
        for dx in range(-9, 10):
            dy = r.randint(-3, 1)
            for k in range(dy, 2):
                c.put(x0 + dx, top + k, GOD[4] if k == dy else GOD[3])
            c.put(x0 + dx, top + dy - 1, GOD[0] if dx < 0 else GOD[2])
    cracks = c.crack(r, 46, 104, 20, 1.5) + c.crack(r, 114, 118, 12, 1.4)
    c.moss(r, cracks, 0.6)
    c.moss_cap(r, cover=0.75, depth=4)
    c.ground(80, 56, depth=2)
    c.outline()
    c.shadow(80, 56, ry=5)
    return c.img


def column_drum():
    c = Canvas()
    r = random.Random(53)
    # Lying on its side: a long cylinder, fluted along its length.
    body = c.mask("rect", (36, 106, 118, 132))
    c.stone(body, light=(-0.2, -0.98), bands=(0.6, 0.25, -0.2, -0.6))
    for y in range(109, 131, 4):
        for x in range(38, 118):
            c.put(x, y, GOD[3] if y > 118 else GOD[2])
            c.put(x, y - 1, GOD[0] if y < 118 else GOD[1])
    # The broken end: the cut face of the drum, rings of stone, chipped.
    end = c.mask("ellipse", (110, 104, 128, 134))
    for (x, y) in end:
        d = math.hypot((x - 119) / 9.0, (y - 119) / 15.0)
        c.put(x, y, GOD[1] if d > 0.8 else GOD[2] if d > 0.5 else GOD[3])
    for (x, y) in end:
        if r.random() < 0.12:
            c.put(x, y, GOD[4])
    # The far end sunk in the ground.
    c.ground(44, 16, depth=3)
    cracks = c.crack(r, 60, 112, 30, 0.1)
    c.moss(r, cracks, 0.6)
    c.moss_cap(r, cover=0.5, depth=2)
    c.outline()
    c.shadow(82, 48, ry=5)
    return c.img


def fallen_stones():
    c = Canvas()
    r = random.Random(61)
    blocks = [(58, 128, 14, 8, 0.2), (82, 132, 12, 7, -0.1), (100, 126, 10, 7, 0.35), (70, 118, 9, 6, -0.3), (90, 116, 7, 5, 0.1)]
    for x, y, w, h, lean in blocks:
        # A wedge of an arch: wider at the top.
        poly = [(x - w, y - h), (x + w, y - h + lean * 6), (x + w - 3, y + h), (x - w + 3, y + h)]
        pts = c.mask("poly", poly)
        c.stone(pts)
        for dx in range(-w + 1, w):
            c.put(x + dx, y - h + 1, GOD[0])
    for _ in range(18):
        x, y = r.randint(40, 120), r.randint(126, 135)
        if (x, y) not in c.filled:
            c.put(x, y, GOD[2] if r.random() < 0.5 else GOD[3])
    c.moss_cap(r, cover=0.45, depth=2)
    c.outline()
    c.shadow(80, 46, ry=5)
    return c.img


def main():
    pieces = [colossus_face(), colossus_hand(), broken_arch(), arch_stumps(), column_drum(), fallen_stones()]
    sheet = Image.new("RGBA", (CELL[0] * len(pieces), CELL[1]), (0, 0, 0, 0))
    for i, piece in enumerate(pieces):
        sheet.paste(piece, (i * CELL[0], 0))
    sheet.save(OUT)


if __name__ == "__main__":
    main()
