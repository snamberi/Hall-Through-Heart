#!/usr/bin/env python3
"""Draws an icon for every ability and spell into assets/icons/abilities.png.

Run from the project folder:  python3 tools/generate_ability_icons.py

Each icon is 24x24 pixel art: a bevelled badge in the colour of the
ability's weapon, class or school, a glow behind, the motif (weapons,
flames, bolts, shields...) drawn flat and then lit from the upper left and
outlined automatically, and effects (slashes, sparks, speed lines) on top.

The order of the icons is the order of the ids in
scripts/abilities/ability_db.gd, read from that file, so AbilityDB.icon(id)
finds an ability's icon by its place in ABILITIES.
"""
import math
import os
import re
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
SIZE = 24
COLUMNS = 8


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (a[3],)


OUT = C("120e18")
WHITE = C("ffffff")

# Badge colours: [deep, glow].
THEMES = {
    "swords": ("1e2a44", "6a8ac8"), "greatswords": ("2e2214", "c8903e"), "axes": ("3a1414", "c84a3a"),
    "daggers": ("261836", "8a5ac8"), "spears": ("12302e", "3aa89a"), "unarmed": ("3a2410", "e08a3a"),
    "bows": ("1a2e16", "6aa846"), "staves": ("24183e", "8a6ae0"),
    "warrior": ("3a1612", "d0523a"), "guardian": ("1a2638", "7a9ac0"), "ranger": ("1c2e18", "7ab04e"),
    "assassin": ("1e1428", "9a52b0"), "mage": ("16204a", "5a8ae8"), "spellblade": ("341438", "c85ab8"),
    "fire": ("3a160c", "f0702a"), "lightning": ("2e2a10", "f0d040"), "dark": ("1e1030", "a050e0"),
    "light": ("38300e", "f8d860"), "frost": ("12283a", "70d0f0"),
}

# Materials: flat colours, lit and shaded automatically.
STEEL = C("b8c2d0")
STEEL_HI = C("eef4fa")
IRON = C("6e7484")
GOLD = C("e0b048")
BRONZE = C("b07a3a")
WOOD = C("8a5a32")
LEATHER = C("6a4028")
RED = C("c83a2a")
BLOOD = C("a01818")
BONE = C("e8e0c8")
SKIN = C("e8a878")
FIRE_Y = C("ffe070")
FIRE_O = C("f88a20")
FIRE_R = C("d03818")
ICE = C("a8e8ff")
ICE_D = C("58b0e0")
BOLT = C("fff27a")
VOID = C("6a2aa8")
VOID_L = C("c88aff")
HOLY = C("fff0a0")
GREEN = C("6ab04a")
ARCANE = C("8ab0ff")
SMOKE = C("8a8898")


class Layer:
    """A transparent 24x24 sheet to draw a motif on; `finish` lights and
    outlines it."""

    def __init__(self):
        self.img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def poly(self, pts, col):
        self.d.polygon([tuple(p) for p in pts], fill=col)

    def line(self, pts, col, w=1):
        self.d.line([tuple(p) for p in pts], fill=col, width=w)

    def rect(self, box, col):
        self.d.rectangle(box, fill=col)

    def ellipse(self, box, col):
        self.d.ellipse(box, fill=col)

    def put(self, x, y, col):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.img.putpixel((int(x), int(y)), col)

    def finish(self, outline=True, light=True):
        img = self.img
        px = img.load()
        solid = lambda x, y: 0 <= x < SIZE and 0 <= y < SIZE and px[x, y][3] > 0
        out = img.copy()
        po = out.load()
        if light:
            for y in range(SIZE):
                for x in range(SIZE):
                    if not solid(x, y):
                        continue
                    c = px[x, y]
                    if not solid(x - 1, y - 1) or not solid(x, y - 1):
                        po[x, y] = mix(c, WHITE, 0.32)
                    elif not solid(x + 1, y + 1) or not solid(x + 1, y):
                        po[x, y] = mix(c, OUT, 0.34)
        if outline:
            for y in range(SIZE):
                for x in range(SIZE):
                    if solid(x, y):
                        continue
                    if solid(x - 1, y) or solid(x + 1, y) or solid(x, y - 1) or solid(x, y + 1):
                        po[x, y] = OUT
        return out


def tf(pts, cx, cy, ang):
    """Turns points drawn pointing up (y negative) by `ang` degrees
    clockwise and moves them to (cx, cy)."""
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    return [(round(cx + x * ca - y * sa), round(cy + x * sa + y * ca)) for (x, y) in pts]


# --- motifs ------------------------------------------------------------------

def sword(L, cx, cy, ang, length=17, blade=STEEL, hilt=GOLD):
    b = length * 0.68
    L.poly(tf([(-1.5, 0), (1.5, 0), (1.5, -b + 2), (0, -b), (-1.5, -b + 2)], cx, cy, ang), blade)
    L.line(tf([(0, -1), (0, -b + 2)], cx, cy, ang), mix(blade, WHITE, 0.5))
    L.line(tf([(-3.5, 0.5), (3.5, 0.5)], cx, cy, ang), hilt, 2)
    L.line(tf([(0, 1), (0, 4)], cx, cy, ang), LEATHER, 2)
    L.ellipse(_box(tf([(0, 5)], cx, cy, ang)[0], 1), hilt)


def greatsword(L, cx, cy, ang, length=21):
    b = length * 0.72
    L.poly(tf([(-2.5, 0), (2.5, 0), (2.5, -b + 3), (0, -b), (-2.5, -b + 3)], cx, cy, ang), STEEL)
    L.line(tf([(0, -1), (0, -b + 3)], cx, cy, ang), IRON)
    L.line(tf([(-5, 0.5), (5, 0.5)], cx, cy, ang), BRONZE, 2)
    L.line(tf([(0, 1), (0, 5)], cx, cy, ang), LEATHER, 2)
    L.ellipse(_box(tf([(0, 6)], cx, cy, ang)[0], 1), BRONZE)


def axe(L, cx, cy, ang, length=19, head=STEEL):
    L.line(tf([(0, 5), (0, -length * 0.7)], cx, cy, ang), WOOD, 2)
    h = -length * 0.62
    L.poly(tf([(1, h - 2), (6, h - 5), (8, h + 1), (6, h + 6), (1, h + 3)], cx, cy, ang), head)
    L.line(tf([(7, h - 3), (8, h + 1), (7, h + 4)], cx, cy, ang), mix(head, WHITE, 0.6))
    L.poly(tf([(-1, h - 1), (-4, h - 2), (-4, h + 2), (-1, h + 2)], cx, cy, ang), IRON)


def dagger(L, cx, cy, ang, length=12, blade=STEEL):
    b = length * 0.62
    L.poly(tf([(-1, 0), (1, 0), (1, -b + 2), (0, -b), (-1, -b + 2)], cx, cy, ang), blade)
    L.line(tf([(-2.5, 0.5), (2.5, 0.5)], cx, cy, ang), GOLD, 1)
    L.line(tf([(0, 1), (0, 3.5)], cx, cy, ang), LEATHER, 2)


def spear(L, cx, cy, ang, length=22):
    L.line(tf([(0, length * 0.45), (0, -length * 0.3)], cx, cy, ang), WOOD, 2)
    t = -length * 0.3
    L.poly(tf([(-2.5, t), (2.5, t), (0, t - 7)], cx, cy, ang), STEEL)
    L.line(tf([(-2, t + 1), (2, t + 1)], cx, cy, ang), BRONZE, 1)


def bow(L, cx, cy, ang):
    pts = [tf([(math.sin(t) * 6 - 3, -math.cos(t) * 9)], cx, cy, ang)[0] for t in [i / 10 * math.pi for i in range(11)]]
    L.line(pts, WOOD, 2)
    L.line([pts[0], pts[-1]], C("e8e0d0"), 1)


def arrow(L, cx, cy, ang, length=16, head=STEEL, flight=RED):
    L.line(tf([(0, length / 2), (0, -length / 2 + 2)], cx, cy, ang), WOOD, 1)
    t = -length / 2
    L.poly(tf([(-2, t + 3), (2, t + 3), (0, t)], cx, cy, ang), head)
    L.poly(tf([(0, length / 2 - 4), (-2, length / 2 - 1), (-2, length / 2 + 1), (0, length / 2 - 1)], cx, cy, ang), flight)
    L.poly(tf([(0, length / 2 - 4), (2, length / 2 - 1), (2, length / 2 + 1), (0, length / 2 - 1)], cx, cy, ang), flight)


def staff(L, cx, cy, ang, gem=ARCANE, length=20):
    L.line(tf([(0, length / 2), (0, -length / 2 + 3)], cx, cy, ang), WOOD, 2)
    top = tf([(0, -length / 2 + 1)], cx, cy, ang)[0]
    L.ellipse(_box(top, 2.5), gem)
    L.line(tf([(-2, -length / 2 + 5), (2, -length / 2 + 5)], cx, cy, ang), GOLD, 1)


def fist(L, cx, cy, open_hand=False):
    crease = mix(SKIN, OUT, 0.45)
    if open_hand:
        # An open palm, fingers apart and up, thumb out to the side.
        L.rect((cx - 5, cy - 1, cx + 5, cy + 6), SKIN)
        for i, h in enumerate([5, 7, 7, 6]):
            x = cx - 5 + i * 3
            L.rect((x, cy - 1 - h, x + 1, cy), SKIN)
        L.poly([(cx + 5, cy + 4), (cx + 9, cy - 1), (cx + 10, cy), (cx + 6, cy + 6)], SKIN)
        L.line([(cx - 3, cy + 2), (cx + 1, cy + 4), (cx + 4, cy + 2)], crease)
        L.rect((cx - 5, cy + 7, cx + 5, cy + 9), LEATHER)
        L.line([(cx - 5, cy + 8), (cx + 5, cy + 8)], BRONZE)
    else:
        # A clenched fist seen from the front: four knuckles, the thumb
        # across them, a leather wrap at the wrist.
        for i in range(4):
            x = cx - 6 + i * 3
            L.rect((x, cy - 5, x + 2, cy - 1), SKIN)
        L.rect((cx - 6, cy - 2, cx + 5, cy + 3), SKIN)
        for i in range(1, 4):
            L.line([(cx - 6 + i * 3, cy - 4), (cx - 6 + i * 3, cy - 2)], crease)
        L.poly([(cx - 6, cy + 1), (cx + 1, cy - 1), (cx + 2, cy + 1), (cx - 5, cy + 3)], mix(SKIN, WHITE, 0.12))
        L.line([(cx - 5, cy + 3), (cx + 2, cy + 1)], crease)
        L.rect((cx - 5, cy + 4, cx + 4, cy + 7), LEATHER)
        L.line([(cx - 5, cy + 5), (cx + 4, cy + 5)], BRONZE)


def chestplate(L, cx, cy):
    steel = C("9aa4b8")
    L.poly([(cx - 7, cy - 7), (cx - 3, cy - 8), (cx, cy - 5), (cx + 3, cy - 8), (cx + 7, cy - 7), (cx + 8, cy - 3),
            (cx + 6, cy), (cx + 6, cy + 7), (cx, cy + 9), (cx - 6, cy + 7), (cx - 6, cy), (cx - 8, cy - 3)], steel)
    L.line([(cx - 5, cy - 1), (cx, cy + 1), (cx + 5, cy - 1)], mix(steel, OUT, 0.4))
    L.line([(cx, cy - 4), (cx, cy + 8)], mix(steel, WHITE, 0.45))
    L.line([(cx - 5, cy + 4), (cx + 5, cy + 4)], mix(steel, OUT, 0.3))
    for x in (cx - 6, cx + 6):
        L.put(x, cy - 5, GOLD)


def footprints(L, steps, col):
    for (x, y) in steps:
        L.ellipse((x - 2, y - 4, x + 1, y + 1), col)
        L.ellipse((x - 1, y + 2, x + 1, y + 4), col)


def hooded(L, cx, cy, robe):
    L.poly([(cx, cy - 9), (cx + 4, cy - 6), (cx + 5, cy - 2), (cx + 7, cy + 9), (cx - 7, cy + 9), (cx - 5, cy - 2), (cx - 4, cy - 6)], robe)
    L.ellipse((cx - 2, cy - 6, cx + 2, cy - 2), C("140806"))
    L.put(cx - 1, cy - 4, FIRE_Y)
    L.put(cx + 1, cy - 4, FIRE_Y)
    L.line([(cx, cy), (cx - 1, cy + 8)], mix(robe, OUT, 0.4))
    L.line([(cx + 3, cy + 1), (cx + 4, cy + 8)], mix(robe, OUT, 0.4))


def boot(L, cx, cy):
    L.poly([(cx - 3, cy - 8), (cx + 2, cy - 8), (cx + 2, cy + 1), (cx + 7, cy + 3), (cx + 7, cy + 6), (cx - 3, cy + 6)], LEATHER)
    L.rect((cx - 3, cy + 5, cx + 7, cy + 6), C("3a2416"))
    L.rect((cx - 4, cy - 9, cx + 3, cy - 7), C("8a5a3a"))


def shield(L, cx, cy, face=C("4a6aa8"), rim=STEEL, w=7, h=9, boss=GOLD):
    pts = [(cx - w, cy - h), (cx + w, cy - h), (cx + w, cy + 1), (cx, cy + h + 1), (cx - w, cy + 1)]
    L.poly(pts, rim)
    L.poly([(cx - w + 2, cy - h + 2), (cx + w - 2, cy - h + 2), (cx + w - 2, cy), (cx, cy + h - 1), (cx - w + 2, cy)], face)
    if boss:
        L.ellipse((cx - 2, cy - 3, cx + 2, cy + 1), boss)


def flame(L, cx, cy, s=1.0):
    def tongue(scale, col):
        pts = [(cx - 6 * s * scale, cy), (cx - 5 * s * scale, cy - 6 * s * scale), (cx - 2 * s * scale, cy - 4 * s * scale),
               (cx, cy - 12 * s * scale), (cx + 3 * s * scale, cy - 5 * s * scale), (cx + 5 * s * scale, cy - 8 * s * scale),
               (cx + 6 * s * scale, cy), (cx, cy + 3 * s * scale)]
        L.poly(pts, col)
    tongue(1.0, FIRE_R)
    tongue(0.72, FIRE_O)
    tongue(0.42, FIRE_Y)


def bolt(L, pts_x0, y0, scale=1.0, col=BOLT):
    s = scale
    x = pts_x0
    L.poly([(x + 2 * s, y0), (x + 8 * s, y0), (x + 5 * s, y0 + 7 * s), (x + 9 * s, y0 + 7 * s),
            (x + 1 * s, y0 + 19 * s), (x + 3 * s, y0 + 10 * s), (x - 1 * s, y0 + 10 * s)], col)


def orb(L, cx, cy, r, col, core=WHITE):
    L.ellipse((cx - r, cy - r, cx + r, cy + r), col)
    L.ellipse((cx - r + 1, cy - r + 1, cx - r + 1 + max(1, r // 2), cy - r + 1 + max(1, r // 2)), mix(col, core, 0.6))


def skull(L, cx, cy):
    L.ellipse((cx - 6, cy - 7, cx + 6, cy + 4), BONE)
    L.rect((cx - 4, cy + 2, cx + 4, cy + 6), BONE)
    L.rect((cx - 4, cy - 2, cx - 1, cy + 1), OUT)
    L.rect((cx + 1, cy - 2, cx + 4, cy + 1), OUT)
    L.put(cx, cy + 2, OUT)
    for x in (cx - 3, cx - 1, cx + 1, cx + 3):
        L.put(x, cy + 5, mix(BONE, OUT, 0.6))


def snowflake(L, cx, cy, r=8, col=ICE):
    for k in range(3):
        a = math.radians(k * 60)
        dx, dy = math.sin(a) * r, math.cos(a) * r
        L.line([(cx - dx, cy - dy), (cx + dx, cy + dy)], col, 1)
        for sgn in (-1, 1):
            bx, by = cx + sgn * dx * 0.6, cy + sgn * dy * 0.6
            for t in (-1, 1):
                b = a + t * math.radians(45)
                L.line([(bx, by), (bx + sgn * math.sin(b) * 3, by + sgn * math.cos(b) * 3)], col, 1)


def star(L, cx, cy, r, col, points=4, inner=0.4):
    pts = []
    for i in range(points * 2):
        a = math.pi * i / points - math.pi / 2
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    L.poly(pts, col)


def crystal(L, cx, cy, h, w, col=ICE, ang=0):
    L.poly(tf([(-w, 0), (-w, -h * 0.7), (0, -h), (w, -h * 0.7), (w, 0)], cx, cy, ang), col)
    L.line(tf([(0, -1), (0, -h + 1)], cx, cy, ang), mix(col, WHITE, 0.6))


def cloud(L, cx, cy, col=C("6a6a80")):
    for (dx, dy, r) in [(-5, 1, 4), (0, -1, 5), (5, 1, 4), (0, 2, 4)]:
        L.ellipse((cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r), col)


def horn(L, cx, cy):
    L.poly([(cx - 8, cy + 3), (cx - 2, cy - 1), (cx + 5, cy - 6), (cx + 8, cy - 5), (cx + 6, cy + 1), (cx - 2, cy + 5), (cx - 8, cy + 5)], BONE)
    L.rect((cx - 9, cy + 2, cx - 7, cy + 6), BRONZE)
    L.line([(cx, cy - 1), (cx + 1, cy + 4)], BRONZE, 1)


def tower(L, cx, cy):
    L.rect((cx - 6, cy - 6, cx + 6, cy + 8), C("8a8a9a"))
    for x in (cx - 6, cx - 2, cx + 2):
        L.rect((x, cy - 9, x + 2, cy - 6), C("8a8a9a"))
    L.rect((cx - 2, cy + 2, cx + 2, cy + 8), C("2a2030"))
    for y in (cy - 3, cy + 1, cy + 5):
        L.line([(cx - 5, y), (cx + 5, y)], C("6a6a7a"))


def bomb(L, cx, cy):
    L.ellipse((cx - 5, cy - 4, cx + 5, cy + 6), C("3a3a48"))
    L.rect((cx - 1, cy - 6, cx + 1, cy - 4), IRON)
    L.line([(cx + 1, cy - 6), (cx + 4, cy - 9)], C("c8a070"))


def heart(L, cx, cy, col):
    L.ellipse((cx - 6, cy - 5, cx, cy + 1), col)
    L.ellipse((cx, cy - 5, cx + 6, cy + 1), col)
    L.poly([(cx - 6, cy - 1), (cx + 6, cy - 1), (cx, cy + 7)], col)


def _box(p, r):
    return (p[0] - r, p[1] - r, p[0] + r, p[1] + r)


# --- effects (not outlined) ---------------------------------------------------

def slash_arc(F, cx, cy, r, a0, a1, col=WHITE, w=2):
    pts = [(cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r) for a in range(a0, a1 + 1, 8)]
    F.line(pts, mix(col, C("000000", 0), 0) if False else col, w)
    tip = pts[-1]
    F.put(tip[0], tip[1], WHITE)


def swirl(F, cx, cy, r, col=WHITE, turns=1.4, w=1):
    pts = []
    for i in range(40):
        t = i / 39
        a = t * turns * math.tau
        rr = r * (0.35 + 0.65 * t)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    F.line(pts, col, w)


def speed_lines(F, x0, y0, n, length, col=WHITE, gap=3, dx=1):
    for i in range(n):
        y = y0 + i * gap
        x = x0 + (i % 2) * 2
        F.line([(x, y), (x + length * dx - (i % 2) * 2 * dx, y)], col, 1)


def burst(F, cx, cy, r, col, rays=8, inner=2):
    for i in range(rays):
        a = math.tau * i / rays
        F.line([(cx + math.cos(a) * inner, cy + math.sin(a) * inner), (cx + math.cos(a) * r, cy + math.sin(a) * r)], col, 1)


def cracks(F, cx, cy, col=C("1a1010")):
    for pts in [[(cx, cy), (cx - 4, cy + 2), (cx - 8, cy + 1)], [(cx, cy), (cx + 3, cy + 3), (cx + 8, cy + 3)],
                [(cx, cy), (cx - 1, cy + 4)], [(cx, cy), (cx + 5, cy - 1)]]:
        F.line(pts, col, 1)


def ring(F, cx, cy, r, col, ry=None, w=1):
    ry = r if ry is None else ry
    F.ellipse((cx - r, cy - ry, cx + r, cy + ry), None) if False else F.d.ellipse((cx - r, cy - ry, cx + r, cy + ry), outline=col, width=w)


def sparkle(F, x, y, col=WHITE):
    F.put(x, y, col)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        F.put(x + dx, y + dy, mix(col, C("000000"), 0.15))


def drops(F, pts, col=BLOOD):
    for (x, y) in pts:
        F.put(x, y, col)
        F.put(x, y + 1, col)
        F.put(x, y - 1, mix(col, WHITE, 0.3))


# --- badge --------------------------------------------------------------------

def badge(theme):
    deep, glow = (C(h) for h in THEMES[theme])
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if (x in (0, SIZE - 1) and y in (0, 1, SIZE - 2, SIZE - 1)) or (y in (0, SIZE - 1) and x in (1, SIZE - 2)):
                continue
            d = math.hypot(x - 11.5, y - 10.0) / 13.0
            t = max(0.0, 1.0 - d)
            band = 0.0 if t < 0.25 else 0.25 if t < 0.5 else 0.5 if t < 0.72 else 0.72
            c = mix(deep, glow, band * 0.75)
            px[x, y] = c
    # Bevel: a dark rim, a lit top-left edge and a shaded bottom-right one.
    for i in range(SIZE):
        for (x, y, col) in [(i, 0, None), (i, SIZE - 1, None), (0, i, None), (SIZE - 1, i, None)]:
            if px[x, y][3]:
                px[x, y] = OUT
    for i in range(2, SIZE - 2):
        px[i, 1] = mix(C(THEMES[theme][1]), WHITE, 0.25)
        px[1, i] = mix(C(THEMES[theme][1]), WHITE, 0.1)
        px[i, SIZE - 2] = mix(deep, OUT, 0.5)
        px[SIZE - 2, i] = mix(deep, OUT, 0.5)
    return img


def compose(theme, motif, under=None, over=None):
    img = badge(theme)
    if under:
        F = Layer()
        under(F)
        img.alpha_composite(F.img)
    L = Layer()
    motif(L)
    img.alpha_composite(L.finish())
    if over:
        F = Layer()
        over(F)
        img.alpha_composite(F.img)
    # Keep the badge's rounded corners clean.
    for (x, y) in [(0, 0), (1, 0), (0, 1), (SIZE - 1, 0), (SIZE - 2, 0), (SIZE - 1, 1),
                   (0, SIZE - 1), (1, SIZE - 1), (0, SIZE - 2), (SIZE - 1, SIZE - 1), (SIZE - 2, SIZE - 1), (SIZE - 1, SIZE - 2)]:
        img.putpixel((x, y), (0, 0, 0, 0))
    for i in range(1, SIZE - 1):
        for (x, y) in [(i, 0), (i, SIZE - 1), (0, i), (SIZE - 1, i)]:
            if img.getpixel((x, y))[3]:
                img.putpixel((x, y), OUT)
    return img


# --- the icons ------------------------------------------------------------------

def ICONS():
    W = WHITE
    return {
        # swords
        "heavy_slash": ("swords", lambda L: sword(L, 9, 15, 45, 18), None,
                        lambda F: slash_arc(F, 8, 16, 11, -80, 10, W, 2)),
        "whirlwind": ("swords", lambda L: sword(L, 12, 13, 30, 16), lambda F: swirl(F, 12, 12, 10, C("c8d8ff")), None),
        "blade_dance": ("swords", lambda L: (sword(L, 8, 15, 35, 15), sword(L, 16, 15, -35, 15)),
                        lambda F: swirl(F, 12, 11, 10, C("d8e0ff"), 1.0), None),
        # greatswords
        "ground_breaker": ("greatswords", lambda L: greatsword(L, 12, 7, 180, 20), None,
                           lambda F: (cracks(F, 12, 19, C("2a1808")), burst(F, 12, 18, 6, FIRE_Y, 6, 3))),
        "cleaving_storm": ("greatswords", lambda L: greatsword(L, 12, 15, 40, 20), lambda F: (swirl(F, 12, 12, 10, C("f0d090"), 1.3),
                           speed_lines(F, 2, 5, 3, 5, C("f0e0b0"))), None),
        "earthshatter": ("greatswords", lambda L: (L.poly([(3, 20), (8, 14), (12, 17), (16, 12), (21, 20)], C("8a6a4a")),
                                                    L.poly([(4, 8), (7, 6), (8, 9)], C("8a6a4a")), L.poly([(16, 5), (19, 4), (19, 7), (16, 8)], C("8a6a4a")),
                                                    L.poly([(10, 4), (12, 3), (12, 5)], C("8a6a4a"))), None,
                         lambda F: (cracks(F, 12, 16, C("f8c050")), burst(F, 12, 16, 3, FIRE_Y, 4, 1))),
        # axes
        "rend": ("axes", lambda L: axe(L, 10, 14, -30, 18), None,
                 lambda F: [F.line([(13 + i * 3, 7 + i), (17 + i * 3, 18 + i)], BLOOD, 1) for i in range(3)]),
        "leap_slam": ("axes", lambda L: axe(L, 14, 14, 40, 17), lambda F: (F.line([(2, 20), (5, 8), (10, 4)], W, 1), cracks(F, 13, 20, C("2a1010"))), None),
        "bloodbath": ("axes", lambda L: (axe(L, 9, 15, -20, 17), axe(L, 15, 15, 20, 17)), None,
                      lambda F: drops(F, [(5, 19), (19, 18), (12, 21), (7, 5), (17, 6)])),
        # daggers
        "shadow_dash": ("daggers", lambda L: dagger(L, 15, 12, 90, 13), lambda F: (speed_lines(F, 2, 8, 4, 7, C("b090e0")),
                         F.ellipse((3, 15, 9, 20), C("3a2050", 200))), None),
        "blade_flurry": ("daggers", lambda L: (dagger(L, 7, 16, -30, 12), dagger(L, 12, 15, 0, 13), dagger(L, 17, 16, 30, 12)), None,
                         lambda F: (sparkle(F, 5, 5), sparkle(F, 19, 5), sparkle(F, 12, 3))),
        "fan_of_knives": ("daggers", lambda L: [dagger(L, 12 + math.sin(math.radians(a)) * 4, 15 - math.cos(math.radians(a)) * 4, a, 10) for a in (-70, -35, 0, 35, 70)],
                          None, lambda F: F.ellipse((10, 15, 14, 19), C("c8b0ff"))),
        # spears
        "piercing_thrust": ("spears", lambda L: spear(L, 9, 12, 90, 22), None,
                            lambda F: (sparkle(F, 21, 12), F.line([(2, 8), (6, 8)], W), F.line([(2, 16), (6, 16)], W))),
        "sweeping_arc": ("spears", lambda L: spear(L, 12, 13, 50, 22), lambda F: slash_arc(F, 12, 13, 10, 140, 330, C("b0f0e8"), 1), None),
        "impale": ("spears", lambda L: (spear(L, 12, 9, 180, 18), L.poly([(3, 21), (6, 15), (8, 21)], C("8a8a9a")), L.poly([(16, 21), (18, 14), (21, 21)], C("8a8a9a"))),
                   None, lambda F: drops(F, [(10, 19), (14, 20)])),
        # unarmed
        "palm_strike": ("unarmed", lambda L: fist(L, 11, 13, True), None, lambda F: burst(F, 17, 7, 5, FIRE_Y, 6, 2)),
        "rapid_blows": ("unarmed", lambda L: (fist(L, 9, 9), fist(L, 15, 15)), lambda F: speed_lines(F, 1, 6, 4, 5, W, 4), None),
        "dragon_kick": ("unarmed", lambda L: boot(L, 11, 12), lambda F: swirl(F, 12, 12, 10, FIRE_O, 1.2, 2), lambda F: (sparkle(F, 19, 18, FIRE_Y), sparkle(F, 4, 5, FIRE_Y))),
        # bows
        "piercing_arrow": ("bows", lambda L: arrow(L, 12, 12, 90, 20), lambda F: ring(F, 15, 12, 3, C("d8f0c0"), 6), None),
        "rapid_volley": ("bows", lambda L: [arrow(L, 12, y, 90, 16) for y in (6, 12, 18)], lambda F: speed_lines(F, 1, 4, 3, 3, W, 6), None),
        "explosive_arrow": ("bows", lambda L: arrow(L, 9, 15, 45, 15), lambda F: (F.ellipse((12, 2, 22, 12), FIRE_O), F.ellipse((14, 4, 20, 10), FIRE_Y)),
                            lambda F: burst(F, 17, 7, 6, FIRE_Y, 8, 4)),
        # staves
        "arcane_barrage": ("staves", lambda L: (staff(L, 7, 13, 0, ARCANE, 20), orb(L, 14, 8, 2, ARCANE), orb(L, 19, 12, 2, ARCANE), orb(L, 15, 17, 2, ARCANE)), None, None),
        "frost_nova": ("staves", lambda L: snowflake(L, 12, 12, 7), lambda F: ring(F, 12, 12, 10, C("a8e8ff")), None),
        "meteor": ("staves", lambda L: orb(L, 14, 14, 5, C("b05a2a")), lambda F: (F.line([(3, 3), (12, 12)], FIRE_O, 4), F.line([(4, 3), (11, 10)], FIRE_Y, 2)),
                   lambda F: (sparkle(F, 18, 9, FIRE_Y), sparkle(F, 20, 19, FIRE_O))),
        # warrior
        "battle_cry": ("warrior", lambda L: horn(L, 10, 14), None,
                       lambda F: [F.d.arc((17 - r, 7 - r, 17 + r, 7 + r), -110, 20, fill=C("ffd8b0"), width=1) for r in (3, 6, 9)] and None),
        "crushing_leap": ("warrior", lambda L: boot(L, 11, 10), lambda F: (F.line([(12, 2), (12, 0)], W), ring(F, 12, 19, 9, C("ffd0a0"), 3)), lambda F: cracks(F, 12, 20, C("2a1010"))),
        "war_stomp": ("warrior", lambda L: boot(L, 10, 9), lambda F: (ring(F, 12, 18, 10, C("ffd0a0"), 3), ring(F, 12, 18, 6, C("ffb070"), 2)), None),
        "blade_storm": ("warrior", lambda L: [sword(L, 12 + math.cos(math.radians(a)) * 6, 12 + math.sin(math.radians(a)) * 6, a + 90, 11) for a in (0, 120, 240)],
                        lambda F: swirl(F, 12, 12, 10, C("ffc0a0"), 1.1), None),
        # guardian
        "shield_bash": ("guardian", lambda L: shield(L, 10, 11), None, lambda F: (burst(F, 19, 8, 4, W, 6, 1), speed_lines(F, 1, 20, 1, 4, W))),
        "iron_skin": ("guardian", lambda L: chestplate(L, 12, 12), lambda F: ring(F, 12, 12, 10, C("9ab0d0")),
                      lambda F: (sparkle(F, 4, 4), sparkle(F, 19, 18), sparkle(F, 20, 5))),
        "guardian_charge": ("guardian", lambda L: shield(L, 15, 11, w=6, h=8), lambda F: speed_lines(F, 1, 5, 5, 6, W, 3), None),
        "bastion": ("guardian", lambda L: tower(L, 12, 12), None, lambda F: F.line([(12, 1), (12, 3)], GOLD)),
        # ranger
        "hunters_mark": ("ranger", lambda L: (L.d.ellipse((4, 4, 20, 20), outline=RED, width=2), L.rect((11, 2, 13, 8), RED), L.rect((11, 16, 13, 22), RED),
                                              L.rect((2, 11, 8, 13), RED), L.rect((16, 11, 22, 13), RED)), None, lambda F: F.rect((11, 11, 12, 12), W)),
        "shadow_step": ("ranger", lambda L: footprints(L, [(6, 18), (11, 12), (17, 6)], C("b0a8c8")),
                        lambda F: (cloud(F, 5, 19, C("3a4a38")), cloud(F, 18, 6, C("4a5a48"))), None),
        "multishot": ("ranger", lambda L: [arrow(L, 12 + math.sin(math.radians(a)) * 2, 13 - math.cos(math.radians(a)) * 2, a, 15) for a in (-30, 0, 30)], None, None),
        "rain_of_arrows": ("ranger", lambda L: [arrow(L, x, y, 180, 10) for (x, y) in ((5, 7), (12, 12), (19, 8), (8, 17), (16, 18))],
                           lambda F: cloud(F, 12, 2, C("3a4a38")), None),
        # assassin
        "backstab": ("assassin", lambda L: (L.poly([(4, 8), (14, 6), (17, 22), (5, 22)], C("4a3a5a")), dagger(L, 15, 12, -150, 13)), None,
                     lambda F: drops(F, [(9, 17), (11, 20)])),
        "execution": ("assassin", lambda L: (skull(L, 12, 13), axe(L, 15, 10, 50, 12)), None, None),
        "smoke_bomb": ("assassin", lambda L: bomb(L, 10, 14), lambda F: (cloud(F, 15, 6, SMOKE), cloud(F, 18, 14, C("6a687a"))), lambda F: sparkle(F, 14, 5, FIRE_Y)),
        "death_mark": ("assassin", lambda L: skull(L, 12, 12), lambda F: (F.d.ellipse((2, 2, 21, 21), outline=RED, width=1),
                       F.line([(12, 0), (12, 4)], RED), F.line([(12, 19), (12, 23)], RED), F.line([(0, 11), (4, 11)], RED), F.line([(19, 11), (23, 11)], RED)), None),
        # mage
        "fireball": ("mage", lambda L: flame(L, 13, 15, 1.0), lambda F: (F.line([(2, 20), (8, 14)], FIRE_O, 2), F.line([(3, 22), (6, 19)], FIRE_Y)), None),
        "lightning_chain": ("mage", lambda L: (orb(L, 4, 18, 2, C("c8d8ff")), orb(L, 12, 6, 2, C("c8d8ff")), orb(L, 20, 17, 2, C("c8d8ff"))),
                            lambda F: (F.line([(4, 18), (7, 11), (9, 13), (12, 6)], BOLT, 1), F.line([(12, 6), (15, 12), (17, 10), (20, 17)], BOLT, 1)), None),
        "arcane_missiles": ("mage", lambda L: [orb(L, x, y, 2, ARCANE) for (x, y) in ((16, 5), (19, 12), (15, 19))],
                            lambda F: [F.line([(3, 12), (9, 10), (16, 5)], C("6a80d0")), F.line([(3, 12), (11, 12), (19, 12)], C("6a80d0")), F.line([(3, 12), (9, 15), (15, 19)], C("6a80d0"))] and None, None),
        "blizzard": ("mage", lambda L: cloud(L, 12, 7, C("b8c8e0")), None, lambda F: [snowflake(F, x, y, 2, W) for (x, y) in ((6, 15), (12, 19), (18, 15), (9, 21))] and None),
        # spellblade
        "enchanted_strike": ("spellblade", lambda L: sword(L, 10, 16, 35, 19, C("d8b8f8"), GOLD), lambda F: F.line([(9, 15), (18, 3)], C("f0a0ff"), 3), lambda F: (sparkle(F, 5, 6, C("ffc8ff")), sparkle(F, 20, 14, C("ffc8ff")))),
        "elemental_burst": ("spellblade", lambda L: (orb(L, 7, 7, 3, FIRE_O), orb(L, 17, 7, 3, ICE), orb(L, 7, 17, 3, BOLT), orb(L, 17, 17, 3, VOID_L)),
                            lambda F: burst(F, 12, 12, 10, C("f8d8ff"), 8, 2), None),
        "arcane_dash": ("spellblade", lambda L: star(L, 15, 12, 7, C("f0b0ff")), lambda F: speed_lines(F, 1, 6, 4, 7, C("e0a0f0"), 4), None),
        "storm_blade": ("spellblade", lambda L: sword(L, 10, 17, 30, 19), None, lambda F: (F.line([(14, 2), (11, 7), (15, 8), (12, 13)], BOLT), F.line([(19, 6), (17, 9), (20, 10)], BOLT))),
        # fire
        "spell_fire_bolt": ("fire", lambda L: (orb(L, 16, 9, 4, FIRE_O), orb(L, 16, 9, 2, FIRE_Y)), lambda F: (F.line([(2, 21), (14, 10)], FIRE_R, 4), F.line([(4, 20), (13, 11)], FIRE_O, 2)), None),
        "spell_flame_ring": ("fire", lambda L: [flame(L, 12 + math.cos(a) * 7, 15 + math.sin(a) * 5, 0.45) for a in [i * math.tau / 6 + 0.3 for i in range(6)]], None, None),
        "spell_meteor": ("fire", lambda L: (star(L, 15, 15, 6, FIRE_Y, 5, 0.5)), lambda F: (F.line([(2, 2), (13, 13)], FIRE_R, 5), F.line([(3, 2), (12, 11)], FIRE_O, 3), F.line([(4, 3), (11, 10)], FIRE_Y, 1)), None),
        "spell_inferno_cloak": ("fire", lambda L: hooded(L, 12, 12, C("8a2a18")),
                                lambda F: (flame(F, 5, 21, 0.8), flame(F, 19, 21, 0.8), flame(F, 12, 8, 1.0)), lambda F: (flame(F, 7, 22, 0.45), flame(F, 17, 22, 0.45))),
        # lightning
        "spell_spark": ("lightning", lambda L: star(L, 12, 12, 8, BOLT, 4, 0.3), None, lambda F: (sparkle(F, 5, 6), sparkle(F, 19, 18), sparkle(F, 18, 5))),
        "spell_chain_lightning": ("lightning", lambda L: (bolt(L, 4, 2, 0.75), bolt(L, 13, 5, 0.75)), None, lambda F: F.line([(9, 15), (14, 9)], C("fff8c0"))),
        "spell_thunderclap": ("lightning", lambda L: (cloud(L, 12, 6, C("8a8aa0")), bolt(L, 9, 8, 0.6)), lambda F: ring(F, 12, 20, 10, BOLT, 2), None),
        "spell_storm_rush": ("lightning", lambda L: bolt(L, 11, 2, 1.0), lambda F: speed_lines(F, 1, 5, 4, 7, C("fff0a0"), 4), None),
        # dark
        "spell_shadow_bolt": ("dark", lambda L: (orb(L, 15, 9, 4, VOID), orb(L, 15, 9, 2, VOID_L)), lambda F: (F.line([(2, 21), (13, 10)], C("3a1a5a"), 4), F.line([(4, 20), (12, 12)], VOID, 2)), None),
        "spell_umbral_burst": ("dark", lambda L: star(L, 12, 12, 9, VOID, 8, 0.45), None, lambda F: F.ellipse((10, 10, 14, 14), C("f0d0ff"))),
        "spell_void_rift": ("dark", lambda L: (L.poly([(12, 2), (16, 12), (12, 22), (8, 12)], C("1a0a28")), L.poly([(12, 5), (14, 12), (12, 19), (10, 12)], VOID)),
                            lambda F: (ring(F, 12, 12, 10, C("8a4ac0"), 6), ring(F, 12, 12, 7, C("5a2a90"), 4)), lambda F: F.rect((11, 11, 12, 13), VOID_L)),
        "spell_dark_pact": ("dark", lambda L: heart(L, 12, 11, C("8a1a3a")), lambda F: [F.line([(1 + i * 4, 18 + (i % 2)), (4 + i * 4, 18 + ((i + 1) % 2))], C("9a8aa8")) for i in range(6)] and None,
                            lambda F: drops(F, [(12, 20), (12, 22)], C("c02050"))),
        # light
        "spell_holy_lance": ("light", lambda L: spear(L, 12, 13, 45, 24), lambda F: F.line([(3, 21), (19, 5)], C("fff4c0"), 3), lambda F: sparkle(F, 19, 4, HOLY)),
        "spell_radiant_burst": ("light", lambda L: orb(L, 12, 12, 4, HOLY), lambda F: burst(F, 12, 12, 10, C("ffe890"), 12, 5), None),
        "spell_smite": ("light", lambda L: (L.rect((7, 3, 17, 8), C("c8b070")), L.rect((11, 8, 13, 16), WOOD)), lambda F: (F.rect((10, 16, 14, 23), C("fff0a0", 200)), burst(F, 12, 21, 6, HOLY, 6, 2)), None),
        "spell_blessing": ("light", lambda L: (L.poly([(11, 14), (3, 8), (2, 12), (5, 16), (11, 17)], C("f8f0e0")), L.poly([(13, 14), (21, 8), (22, 12), (19, 16), (13, 17)], C("f8f0e0"))),
                           lambda F: F.d.ellipse((7, 2, 17, 7), outline=HOLY, width=1), None),
        # frost
        "spell_ice_shard": ("frost", lambda L: (crystal(L, 9, 20, 14, 2, ICE, 30), crystal(L, 15, 19, 11, 2, ICE, 55)), None, lambda F: sparkle(F, 19, 5)),
        "spell_frost_ring": ("frost", lambda L: [crystal(L, 12 + math.cos(a) * 7, 15 + math.sin(a) * 5, 6, 1.5, ICE) for a in [i * math.tau / 6 for i in range(6)]],
                             lambda F: ring(F, 12, 14, 9, C("6ac0e8"), 6), None),
        "spell_glacial_spike": ("frost", lambda L: (crystal(L, 12, 22, 20, 4, ICE), crystal(L, 6, 22, 8, 2, ICE_D), crystal(L, 18, 22, 10, 2, ICE_D)), None, lambda F: sparkle(F, 16, 5)),
        "spell_ice_armor": ("frost", lambda L: shield(L, 12, 11, face=C("8ad8f8"), rim=C("d8f4ff"), boss=None), None,
                            lambda F: (snowflake(F, 12, 10, 3, W), sparkle(F, 4, 4), sparkle(F, 20, 19))),
    }


# --- effects (buffs and statuses), on a round badge ---------------------------
# Order matters: scripts/combat/buffs.gd lists the same ids in EFFECT_ICONS.
EFFECT_IDS = ["buff", "torchlight", "heart_racing", "heart_steady", "bloodthirst", "blessing", "henge",
              "perfect_dodge", "chill", "burn", "poison", "bleed", "well_fed", "debuff",
              "tidestride", "bulwark", "fortune", "night_veil"]

THEMES.update({
    "e_warm": ("3a2410", "f0a040"), "e_red": ("3a1018", "e04050"), "e_green": ("12301a", "60c070"),
    "e_gold": ("38300e", "f8d860"), "e_cyan": ("12283a", "70d0f0"), "e_violet": ("24183e", "a080f0"),
    "e_grey": ("1e2030", "8890a8"),
})


def round_badge(theme):
    deep, glow = (C(h) for h in THEMES[theme])
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x - 11.5, y - 11.5)
            if d > 11.6:
                continue
            if d > 10.4:
                px[x, y] = OUT
                continue
            t = max(0.0, 1.0 - math.hypot(x - 10.5, y - 9.5) / 11.0)
            band = 0.0 if t < 0.25 else 0.25 if t < 0.5 else 0.5 if t < 0.72 else 0.72
            px[x, y] = mix(deep, glow, band * 0.75)
            if 9.4 < d <= 10.4:
                lit = (x - 11.5) + (y - 11.5) < 0
                px[x, y] = mix(glow, WHITE, 0.3) if lit else mix(deep, OUT, 0.4)
    return img


def compose_round(theme, motif, under=None, over=None):
    img = round_badge(theme)
    for fn, finish in ((under, False), (motif, True), (over, False)):
        if fn is None:
            continue
        L = Layer()
        fn(L)
        img.alpha_composite(L.finish() if finish else L.img)
    return img


def torch(L, cx, cy):
    L.line([(cx, cy + 8), (cx, cy - 1)], WOOD, 2)
    L.rect((cx - 2, cy - 3, cx + 2, cy), IRON)
    flame(L, cx, cy - 3, 0.6)


def EFFECTS():
    return {
        "buff": ("e_gold", lambda L: L.poly([(12, 4), (19, 12), (15, 12), (15, 19), (9, 19), (9, 12), (5, 12)], HOLY), None, None),
        "torchlight": ("e_warm", lambda L: torch(L, 12, 11), lambda F: F.ellipse((5, 2, 19, 15), C("ffd070", 70)), lambda F: (sparkle(F, 7, 5, FIRE_Y), sparkle(F, 17, 7, FIRE_Y))),
        "heart_racing": ("e_red", lambda L: heart(L, 13, 11, C("e03848")), lambda F: speed_lines(F, 2, 7, 3, 4, C("ffb0b8"), 4), None),
        "heart_steady": ("e_green", lambda L: heart(L, 12, 10, C("e03848")), None, lambda F: F.line([(3, 18), (8, 18), (10, 14), (12, 21), (14, 17), (20, 17)], C("90f090"), 1)),
        "bloodthirst": ("e_red", lambda L: (L.poly([(12, 4), (17, 12), (17, 15), (12, 19), (7, 15), (7, 12)], BLOOD), L.poly([(9, 6), (11, 6), (10, 11)], BONE), L.poly([(13, 6), (15, 6), (14, 11)], BONE)), None, None),
        "blessing": ("e_gold", lambda L: star(L, 12, 13, 7, HOLY, 4, 0.4), lambda F: F.d.ellipse((6, 3, 18, 8), outline=C("fff0a0"), width=1), None),
        "henge": ("e_cyan", lambda L: (L.rect((5, 9, 8, 19), C("9a96a4")), L.rect((16, 9, 19, 19), C("9a96a4")), L.rect((4, 6, 20, 9), C("aaa6b2")), L.rect((11, 12, 13, 19), C("8a8694"))),
                  None, lambda F: (F.rect((12, 14, 12, 16), C("8ff0ff")), sparkle(F, 12, 4, C("dffcff")))),
        "perfect_dodge": ("e_violet", lambda L: L.ellipse((12, 6, 16, 10), C("e0d8ff")), lambda F: (F.ellipse((4, 6, 8, 10), C("a080f0", 120)), F.ellipse((8, 6, 12, 10), C("c0a8ff", 170)),
                          speed_lines(F, 3, 13, 3, 12, C("d0c0ff"), 3)), None),
        "chill": ("e_cyan", lambda L: snowflake(L, 12, 12, 7), None, None),
        "burn": ("e_warm", lambda L: flame(L, 12, 18, 1.1), None, lambda F: (sparkle(F, 5, 8, FIRE_Y), sparkle(F, 19, 6, FIRE_Y))),
        "poison": ("e_green", lambda L: (L.poly([(12, 4), (17, 13), (17, 16), (12, 20), (7, 16), (7, 13)], C("70d050")), L.rect((10, 12, 14, 14), C("20401a"))),
                   None, lambda F: (F.ellipse((15, 4, 18, 7), C("90f070")), F.ellipse((5, 7, 7, 9), C("90f070")))),
        "bleed": ("e_red", lambda L: (L.poly([(8, 5), (11, 11), (11, 13), (8, 15), (5, 13), (5, 11)], BLOOD), L.poly([(16, 9), (19, 15), (19, 17), (16, 19), (13, 17), (13, 15)], BLOOD)), None, None),
        "well_fed": ("e_warm", lambda L: (L.ellipse((5, 11, 19, 19), C("c8a060")), L.rect((5, 14, 19, 15), C("8a6030"))), None, lambda F: [F.line([(x, 9), (x + 1, 6), (x, 3)], C("e0e0e0", 160)) for x in (8, 12, 16)] and None),
        "debuff": ("e_grey", lambda L: L.poly([(12, 19), (19, 11), (15, 11), (15, 4), (9, 4), (9, 11), (5, 11)], C("e05050")), None, None),
        "tidestride": ("e_cyan", lambda L: L.poly([(3, 17), (6, 12), (10, 9), (15, 9), (18, 12), (15, 12), (12, 14), (15, 17), (20, 16), (20, 20), (3, 20)], C("3aa0d8")),
                       None, lambda F: (F.line([(6, 12), (10, 9), (15, 9), (18, 12)], C("e8fcff"), 1), sparkle(F, 7, 5, C("dffcff")))),
        "bulwark": ("e_grey", lambda L: shield(L, 12, 12, face=C("6a7a9a"), rim=C("d8e0f0"), w=7, h=8, boss=None), None, lambda F: sparkle(F, 18, 5, C("ffffff"))),
        "fortune": ("e_gold", lambda L: (L.ellipse((6, 7, 18, 19), C("f0c040")), L.ellipse((8, 9, 16, 17), C("c89020")), L.rect((11, 10, 13, 16), C("f8e070"))),
                    None, lambda F: (sparkle(F, 18, 5, C("fff0a0")), sparkle(F, 5, 6, C("fff0a0")))),
        "night_veil": ("e_violet", lambda L: L.poly([(14, 4), (9, 6), (7, 11), (9, 16), (14, 19), (10, 19), (5, 16), (3, 11), (5, 6), (10, 3)], C("e8e4ff")),
                       None, lambda F: (sparkle(F, 16, 9, C("d0c8ff")), sparkle(F, 18, 16, C("d0c8ff")))),
    }


# --- menu icons: no badge, just the thing, outlined --------------------------
# Order matters: scripts/ui/menu_icons.gd lists the same ids.
MENU_IDS = ["inventory", "abilities", "class", "magic", "build", "professions", "journal", "map",
            "attributes", "talents", "mastery", "evolution", "codex", "pets", "wardrobe", "pause", "relics"]
PARCHMENT = C("e8d8b0")
INK = C("5a4630")


def backpack(L):
    L.poly([(6, 7), (18, 7), (19, 20), (5, 20)], C("8a5a32"))
    L.rect((7, 4, 17, 8), C("6e4426"))
    L.poly([(6, 8), (18, 8), (17, 13), (7, 13)], C("a06a3a"))
    L.rect((11, 11, 13, 14), GOLD)
    L.rect((7, 15, 17, 19), C("7a4c2a"))
    L.rect((8, 16, 16, 16), C("5a3a20"))
    L.line([(9, 4), (10, 2), (14, 2), (15, 4)], C("4a2e18"), 1)


def crossed_swords(L):
    sword(L, 5, 19, 45, 24)
    sword(L, 19, 19, -45, 24)


def crest(L):
    shield(L, 12, 11, face=C("3a5aa0"), rim=GOLD, w=8, h=9, boss=None)
    L.poly([(12, 6), (14, 10), (12, 14), (10, 10)], C("e0d0a0"))
    L.rect((8, 10, 16, 11), C("c83a3a"))


def spellbook(L):
    L.poly([(2, 8), (11, 6), (12, 19), (3, 20)], PARCHMENT)
    L.poly([(13, 6), (22, 8), (21, 20), (12, 19)], PARCHMENT)
    L.rect((11, 6, 13, 20), C("6a3a7a"))
    for y in (10, 13, 16):
        L.line([(4, y), (9, y - 1)], INK)
    L.ellipse((14, 9, 20, 15), C("8a5aff"))
    L.put(16, 11, C("ffffff"))


def hammer_brick(L):
    L.rect((3, 14, 13, 20), C("b0583a"))
    L.line([(3, 17), (13, 17)], C("7a3a26"))
    L.line([(8, 14), (8, 17)], C("7a3a26"))
    L.line([(9, 21), (19, 7)], WOOD, 2)
    L.poly([(14, 3), (21, 8), (19, 11), (12, 6)], IRON)


def anvil(L):
    L.poly([(3, 9), (20, 9), (20, 12), (15, 13), (15, 16), (18, 19), (6, 19), (9, 16), (9, 13), (5, 12)], C("5a5e6a"))
    L.poly([(20, 9), (23, 10), (20, 12)], C("5a5e6a"))
    L.line([(6, 8), (13, 2)], WOOD, 2)
    L.poly([(11, 1), (16, 4), (15, 6), (9, 3)], IRON)


def scroll_quill(L):
    L.rect((4, 6, 16, 19), PARCHMENT)
    L.ellipse((2, 4, 6, 8), C("c8b088"))
    L.ellipse((14, 17, 18, 21), C("c8b088"))
    for y in (9, 12, 15):
        L.line([(6, y), (14, y)], INK)
    L.poly([(13, 13), (21, 2), (22, 4), (15, 14)], C("f0f0f0"))
    L.line([(13, 14), (11, 18)], INK)


def folded_map(L):
    L.poly([(2, 6), (8, 4), (8, 19), (2, 21)], PARCHMENT)
    L.poly([(8, 4), (15, 6), (15, 21), (8, 19)], C("d8c49c"))
    L.poly([(15, 6), (22, 4), (22, 19), (15, 21)], PARCHMENT)
    L.ellipse((4, 9, 9, 13), C("7aa860"))
    L.ellipse((16, 12, 20, 16), C("6a9ad0"))
    for (x, y) in ((5, 16), (7, 15), (9, 14), (11, 13), (13, 11)):
        L.put(x, y, C("8a3a2a"))
    L.line([(16, 7), (19, 10)], C("d03030"), 1)
    L.line([(19, 7), (16, 10)], C("d03030"), 1)


def bust(L):
    L.ellipse((8, 3, 16, 11), SKIN)
    L.poly([(3, 21), (5, 14), (9, 12), (15, 12), (19, 14), (21, 21)], C("4a6aa8"))
    L.rect((8, 3, 16, 5), C("6a4a30"))
    L.rect((11, 13, 13, 16), GOLD)


def talent_tree(L):
    L.line([(12, 21), (12, 10)], WOOD, 2)
    L.line([(12, 14), (6, 8)], WOOD, 1)
    L.line([(12, 12), (18, 6)], WOOD, 1)
    L.line([(12, 10), (12, 4)], WOOD, 1)
    for (x, y, c) in ((6, 7, C("60d070")), (18, 5, C("60a0ff")), (12, 3, GOLD), (4, 13, C("e05050")), (20, 12, C("b070f0"))):
        L.ellipse((x - 2, y - 2, x + 2, y + 2), c)
    L.line([(12, 16), (4, 13)], WOOD, 1)
    L.line([(12, 15), (20, 12)], WOOD, 1)


def mastery_sword(L):
    sword(L, 12, 18, 0, 20)
    star(L, 18, 6, 4, GOLD, 5, 0.45)


def evolution_crystal(L):
    crystal(L, 12, 21, 18, 4, C("b080ff"))
    for y in (8, 13):
        L.line([(3, y + 3), (5, y), (7, y + 3)], C("90f0a0"), 1)
        L.line([(17, y + 3), (19, y), (21, y + 3)], C("90f0a0"), 1)


def tome(L):
    L.rect((5, 3, 19, 21), C("5a2a2a"))
    L.rect((17, 4, 19, 20), PARCHMENT)
    L.rect((5, 3, 7, 21), C("3a1a1a"))
    skull(L, 12, 11)


def paw(L):
    L.ellipse((7, 12, 17, 21), C("c89a6a"))
    for (x, y) in ((4, 9), (9, 5), (15, 5), (20, 9)):
        L.ellipse((x - 2, y - 2, x + 1, y + 2), C("c89a6a"))


def tunic_hanger(L):
    L.line([(12, 1), (12, 4)], IRON)
    L.line([(4, 7), (12, 4), (20, 7)], C("8a6a48"), 1)
    L.poly([(5, 7), (19, 7), (22, 12), (18, 13), (18, 21), (6, 21), (6, 13), (2, 12)], C("3a7a5a"))
    L.rect((6, 15, 18, 16), C("8a6a30"))
    L.line([(12, 8), (12, 14)], C("2a5a40"))


def cog(L):
    for k in range(8):
        a = math.tau * k / 8
        L.poly(tf([(-2, -10), (2, -10), (2, -6), (-2, -6)], 12, 12, math.degrees(a)), C("8a92a8"))
    L.ellipse((5, 5, 19, 19), C("8a92a8"))
    L.ellipse((9, 9, 15, 15), C("1a1a24"))


def relic_locket(L):
    L.line([(7, 2), (12, 6), (17, 2)], C("c8a050"), 1)
    L.ellipse((5, 5, 19, 21), C("e0b850"))
    L.ellipse((7, 7, 17, 19), C("b02a3a"))
    L.poly([(12, 9), (15, 13), (12, 17), (9, 13)], C("ff7a8a"))
    L.rect((9, 9, 10, 10), C("ffe0e8"))


MENU_ICONS = {
    "inventory": backpack, "abilities": crossed_swords, "class": crest, "magic": spellbook, "build": hammer_brick,
    "professions": anvil, "journal": scroll_quill, "map": folded_map, "attributes": bust, "talents": talent_tree,
    "mastery": mastery_sword, "evolution": evolution_crystal, "codex": tome, "pets": paw, "wardrobe": tunic_hanger, "pause": cog, "relics": relic_locket,
}


def ability_ids():
    text = open(os.path.join(ROOT, "scripts", "abilities", "ability_db.gd")).read()
    body = text[text.index("const ABILITIES := {"):]
    body = body[:body.index("\n}\n")]
    return re.findall(r'^\t"([a-z_]+)": \{', body, re.M)


def main():
    ids = ability_ids()
    icons = ICONS()
    missing = [i for i in ids if i not in icons]
    if missing:
        raise SystemExit("no icon drawn for: " + ", ".join(missing))
    rows = (len(ids) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGBA", (COLUMNS * SIZE, rows * SIZE), (0, 0, 0, 0))
    for index, ability in enumerate(ids):
        theme, motif, under, over = icons[ability]
        sheet.paste(compose(theme, motif, under, over), (index % COLUMNS * SIZE, index // COLUMNS * SIZE))
    sheet.save(os.path.join(ROOT, "assets", "icons", "abilities.png"))
    print("abilities", len(ids))
    effects = EFFECTS()
    sheet = Image.new("RGBA", (len(EFFECT_IDS) * SIZE, SIZE), (0, 0, 0, 0))
    for index, effect in enumerate(EFFECT_IDS):
        theme, motif, under, over = effects[effect]
        sheet.paste(compose_round(theme, motif, under, over), (index * SIZE, 0))
    sheet.save(os.path.join(ROOT, "assets", "icons", "effects.png"))
    print("effects", len(EFFECT_IDS))
    sheet = Image.new("RGBA", (len(MENU_IDS) * SIZE, SIZE), (0, 0, 0, 0))
    for index, menu in enumerate(MENU_IDS):
        L = Layer()
        MENU_ICONS[menu](L)
        sheet.paste(L.finish(), (index * SIZE, 0))
    sheet.save(os.path.join(ROOT, "assets", "icons", "menus.png"))
    print("menus", len(MENU_IDS))


if __name__ == "__main__":
    main()
