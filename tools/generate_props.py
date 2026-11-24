"""Props redrawn at full detail (visual overhaul, phase 5).

Each is drawn on the 64 x 64 decor canvas the same way as the props in
generate_flora's PROPS_V2 (three-quarter view, light from the top-left,
foot near the bottom, a soft shadow under it), and replaces the older,
plainer drawing of the same name in the decor sheet.
"""
import math
import random

from generate_flora import C, ramp, PLANK, PLANK_TOP, PLANK_SIDE, IRON, STONE, WOOD, CLOTH, BRASS, _nails

DARKWOOD = ramp("7a5a40", "5a4030", "3a2a20")
WOODTOP = ramp("b08a60", "8e6a46", "6a4c32")
GREY = ramp("b4b0bc", "86828e", "5a5662")
GREYTOP = ramp("d0ccd8", "a8a4b0", "7c7884")
MOSS = ramp("7aa050", "5a8040", "3a5a2a")
FLAME = [C("fff2b0"), C("ffc850"), C("f08a2e"), C("b8401e")]
GOLDR = ramp("f6d886", "cc9c40", "8a6424")
RED = ramp("d0545a", "a02c36", "6a1820")
BOOKS = ["8a2c37", "2c5a8a", "3a7a3a", "8a6a2a", "5a3a7a", "a85a2a", "2a6a6a"]


def flame(c, x, y, h=7, seed=0):
    r = random.Random(seed)
    for k in range(h):
        w = max(0, int((h - k) * 0.45))
        for dx in range(-w, w + 1):
            t = k / h
            col = FLAME[0] if abs(dx) < w * 0.4 and t > 0.2 else FLAME[1] if t > 0.35 else FLAME[2]
            if k == 0 and abs(dx) == w:
                col = FLAME[3]
            c.put(x + dx + (r.choice((-1, 0, 0)) if k > h - 3 else 0), y - k, col)


def glow(c, x, y, radius, colour=(255, 200, 110), alpha=60):
    for yy in range(y - radius, y + radius + 1):
        for xx in range(x - radius, x + radius + 1):
            d = math.hypot(xx - x, yy - y) / radius
            if d < 1.0 and (xx + yy) % 2 == 0 and (xx, yy) not in c.filled and 0 <= xx < 64 and 0 <= yy < 64:
                c.img.putpixel((xx, yy), colour + (int(alpha * (1 - d)),))


def box(c, x0, y0, x1, y1, depth, front, top, side=None):
    """A box in three-quarter view: its top face above, front face below."""
    c.shade("poly", [(x0, y0), (x1, y0), (x1 + depth, y0 - depth), (x0 + depth, y0 - depth)], top)
    c.shade("rect", (x0, y0, x1, y1), front)
    if side:
        c.shade("poly", [(x1, y0), (x1 + depth, y0 - depth), (x1 + depth, y1 - depth), (x1, y1)], side)


def prop_lantern(c):
    # An iron lamp post: a stone foot, a fluted post, a crossarm, and a
    # glass lantern with a flame and its warm glow.
    c.shadow(32, 60, 10, 2, 90)
    glow(c, 32, 18, 14)
    c.shade("poly", [(26, 60), (38, 60), (36, 54), (28, 54)], GREY)
    c.shade("rect", (30, 22, 34, 54), IRON)
    for y in range(26, 54, 6):
        c.put(31, y, C("c4c8d4"))
    c.shade("rect", (27, 22, 37, 23), IRON)
    c.shade("poly", [(27, 10), (37, 10), (38, 21), (26, 21)], IRON)
    c.fill("rect", (28, 12, 36, 20), C("ffe29a"))
    c.fill("rect", (29, 13, 30, 19), C("fff6d8"))
    flame(c, 32, 19, 6, 1)
    for x in (28, 32, 36):
        c.fill("line", (x, 11, x, 20), IRON[2], 1)
    c.shade("poly", [(25, 10), (39, 10), (32, 4)], IRON)
    c.put(32, 3, C("c4c8d4"))


def prop_signpost(c):
    c.shadow(32, 60, 12, 2, 90)
    c.shade("rect", (30, 12, 34, 60), DARKWOOD)
    for y in range(16, 58, 7):
        c.put(31, y, DARKWOOD[2])
    for (y, left, w) in ((16, False, 22), (28, True, 20), (40, False, 16)):
        x0 = 34 if not left else 30 - w
        x1 = x0 + w
        tip = (x1 + 5, y + 3) if not left else (x0 - 5, y + 3)
        pts = [(x0, y), (x1, y), (tip[0], tip[1]), (x1, y + 7), (x0, y + 7)] if not left else [(x1, y), (x0, y), tip, (x0, y + 7), (x1, y + 7)]
        c.shade("poly", pts, WOODTOP)
        for k in range(3):
            xx = (x0 + 3 + k * 5) if not left else (x1 - 4 - k * 5)
            c.fill("line", (xx, y + 3, xx + 3, y + 3), C("3a2818"), 1)
        c.put(x0 + 1 if not left else x1 - 1, y + 1, C("d8b080"))
    _nails(c, [(32, 19), (32, 31), (32, 43)])


def prop_table(c):
    c.shadow(32, 60, 22, 3, 90)
    for x in (13, 47):
        c.shade("rect", (x, 40, x + 3, 59), DARKWOOD)
    c.shade("rect", (19, 44, 22, 56), DARKWOOD)
    box(c, 10, 36, 50, 41, 6, PLANK, PLANK_TOP)
    for x in range(18, 50, 8):
        c.fill("line", (x, 36, x + 6, 30), C("7a5636"), 1)
    # A cloth runner, a jug and a bowl.
    c.shade("poly", [(26, 36), (34, 36), (40, 30), (32, 30)], ramp("e8dcc0", "c4b494", "8e7e64"))
    c.shade("ellipse", (36, 26, 42, 34), ramp("d08a5a", "a8603a", "703c24"))
    c.put(37, 27, C("f0b890"))
    c.shade("ellipse", (16, 31, 24, 35), ramp("c4c8d4", "8a8e9a", "5a5e6a"))


def prop_chair(c):
    c.shadow(32, 60, 12, 2, 90)
    for x in (21, 40):
        c.shade("rect", (x, 44, x + 2, 60), DARKWOOD)
    box(c, 20, 40, 43, 44, 4, PLANK, PLANK_TOP)
    c.shade("rect", (22, 14, 25, 41), DARKWOOD)
    c.shade("rect", (38, 14, 41, 41), DARKWOOD)
    for y in (18, 25, 32):
        c.shade("rect", (25, y, 38, y + 3), PLANK)
    c.shade("ellipse", (21, 11, 26, 16), WOODTOP)
    c.shade("ellipse", (37, 11, 42, 16), WOODTOP)


def prop_bench(c):
    c.shadow(32, 60, 24, 2, 90)
    for x in (12, 48):
        c.shade("rect", (x, 46, x + 3, 60), DARKWOOD)
    box(c, 8, 42, 54, 46, 4, PLANK, PLANK_TOP)
    for x in range(14, 54, 10):
        c.fill("line", (x, 42, x + 3, 39), C("7a5636"), 1)
    c.shade("rect", (8, 28, 54, 33), PLANK)
    c.fill("line", (9, 28, 53, 28), C("d8b080"), 1)
    for x in (12, 48):
        c.shade("rect", (x, 33, x + 3, 42), DARKWOOD)


def prop_shelf(c):
    # A bookcase: dark frame, three shelves of books leaning every way, a
    # skull and a candle on top.
    c.shadow(32, 61, 18, 2, 90)
    box(c, 14, 10, 50, 60, 4, DARKWOOD, WOODTOP)
    c.fill("rect", (17, 13, 47, 58), C("2a1c12"))
    r = random.Random(5)
    for shelf_y in (26, 42, 58):
        c.shade("rect", (16, shelf_y - 1, 48, shelf_y + 1), PLANK)
        x = 18
        while x < 46:
            w = r.choice((2, 2, 3))
            h = r.randint(9, 12)
            col = C(r.choice(BOOKS))
            lean = 1 if r.random() < 0.15 else 0
            for xx in range(x, min(x + w, 47)):
                for yy in range(shelf_y - 1 - h, shelf_y - 1):
                    c.put(xx + (lean if yy < shelf_y - 1 - h // 2 else 0), yy, col if xx > x else tuple(min(255, v + 40) for v in col[:3]) + (255,))
            c.put(x + w // 2, shelf_y - 1 - h + 3, C("e8d890"))
            x += w + (1 if r.random() < 0.3 else 0)
    c.shade("ellipse", (19, 2, 27, 9), GREYTOP)
    c.put(21, 5, C("1a1414")); c.put(24, 5, C("1a1414"))
    c.fill("rect", (40, 2, 42, 9), C("f0ead8"))
    flame(c, 41, 1, 3, 2)


def prop_cupboard(c):
    c.shadow(32, 61, 18, 2, 90)
    box(c, 14, 12, 50, 60, 4, ramp("5a7aa0", "3e5a80", "2a3e5a"), ramp("7a9ac0", "5a7aa0", "3e5a80"))
    c.fill("line", (32, 14, 32, 58), C("1e2c40"), 1)
    for x0 in (16, 34):
        c.shade("rect", (x0 + 2, 16, x0 + 13, 34), ramp("6a8ab0", "4a6a90", "324a6a"))
        c.shade("rect", (x0 + 2, 38, x0 + 13, 56), ramp("6a8ab0", "4a6a90", "324a6a"))
    for x in (29, 35):
        c.fill("rect", (x, 34, x + 1, 37), BRASS[1])
        c.put(x, 34, BRASS[0])
    c.shade("ellipse", (18, 4, 26, 11), ramp("e8e0d0", "c0b8a8", "908878"))
    c.shade("ellipse", (38, 6, 44, 11), ramp("d08a5a", "a8603a", "703c24"))


def prop_anvil(c):
    c.shadow(32, 60, 18, 2, 90)
    c.shade("poly", [(20, 60), (44, 60), (40, 46), (24, 46)], ramp("8a6a48", "6a4e34", "4a3624"))
    for y in (50, 55):
        c.fill("line", (22, y, 42, y), C("3a2818"), 1)
    c.shade("rect", (27, 36, 37, 46), IRON)
    c.shade("poly", [(12, 30), (44, 30), (52, 33), (44, 37), (20, 37)], IRON)
    c.fill("line", (14, 30, 44, 30), C("e0e4ec"), 1)
    c.shade("poly", [(44, 30), (54, 31), (44, 35)], IRON)
    # A hammer resting on it and a glowing bar.
    c.shade("rect", (18, 24, 30, 26), ramp("a88a60", "7a5a40", "5a4030"))
    c.shade("rect", (16, 21, 20, 29), IRON)
    c.fill("rect", (32, 28, 42, 29), C("ff9a40"))
    c.fill("line", (33, 28, 41, 28), C("ffe08a"), 1)


def prop_brazier(c):
    c.shadow(32, 60, 14, 2, 90)
    glow(c, 32, 26, 16)
    for (x0, x1) in ((22, 26), (38, 42), (30, 34)):
        c.fill("line", (x0 + 2, 36, x0 - 2 if x0 < 30 else x1 + 2 if x0 > 30 else x0 + 2, 60), IRON[2], 2)
    c.shade("poly", [(18, 28), (46, 28), (42, 38), (22, 38)], IRON)
    for x in range(21, 44, 4):
        c.put(x, 30, C("c4c8d4"))
    c.shade("ellipse", (19, 25, 45, 31), ramp("3a2a22", "2a1e18", "1a120e"))
    for x in range(22, 43, 3):
        c.put(x, 28, FLAME[2] if x % 2 else FLAME[1])
    for k, x in enumerate((25, 32, 39)):
        flame(c, x, 27, 11 if k == 1 else 8, k)


def prop_torch(c):
    c.shadow(32, 60, 6, 2, 90)
    glow(c, 32, 16, 14)
    c.shade("rect", (30, 24, 34, 60), DARKWOOD)
    for y in range(28, 58, 5):
        c.put(31, y, DARKWOOD[0])
    c.shade("rect", (28, 20, 36, 26), ramp("a89070", "7a6448", "4a3a28"))
    c.fill("line", (28, 23, 36, 23), C("3a2818"), 1)
    flame(c, 32, 19, 12, 3)


def prop_gravestone(c):
    c.shadow(32, 60, 16, 3, 90)
    c.shade("poly", [(20, 60), (44, 60), (44, 22), (40, 15), (32, 12), (24, 15), (20, 22)], GREY)
    c.fill("line", (21, 22, 25, 15), C("d8d4e0"), 1)
    c.fill("rect", (31, 20, 33, 34), GREY[2])
    c.fill("rect", (27, 24, 37, 26), GREY[2])
    for y in (40, 44, 48):
        c.fill("line", (25, y, 39, y), GREY[2], 1)
    c.fill("line", (36, 16, 41, 30), C("4a4652"), 1)
    for (x, y) in ((21, 52), (22, 51), (23, 53), (42, 46), (43, 47), (24, 58)):
        c.put(x, y, MOSS[1])
    c.shade("ellipse", (16, 54, 26, 61), MOSS)
    c.shade("ellipse", (38, 56, 48, 61), MOSS)


def prop_statue(c):
    # A robed figure on a plinth, one hand on a sword, worn and mossy.
    c.shadow(32, 61, 18, 2, 90)
    box(c, 18, 50, 46, 60, 3, GREY, GREYTOP)
    c.fill("line", (19, 53, 45, 53), GREY[2], 1)
    c.shade("poly", [(24, 50), (40, 50), (38, 26), (26, 26)], GREY)
    for x in (28, 32, 36):
        c.fill("line", (x, 30, x - 1, 49), GREY[2], 1)
    c.shade("ellipse", (25, 22, 39, 30), GREY)
    c.shade("ellipse", (27, 8, 37, 20), GREYTOP)
    c.shade("poly", [(26, 13), (38, 13), (36, 6), (28, 6)], GREY)
    c.put(30, 15, GREY[2]); c.put(34, 15, GREY[2])
    c.fill("rect", (40, 18, 41, 48), GREYTOP[0])
    c.fill("rect", (37, 22, 44, 23), GREY[1])
    for (x, y) in ((25, 47), (26, 48), (38, 40), (27, 24), (30, 21)):
        c.put(x, y, MOSS[1])


def prop_hay_bale(c):
    c.shadow(32, 60, 20, 3, 90)
    straw = ramp("f0d878", "c8a448", "8a6c2c")
    straw_top = ramp("f8e8a0", "e0c068", "a8883c")
    box(c, 12, 32, 48, 58, 8, straw, straw_top)
    r = random.Random(4)
    for _ in range(70):
        x, y = r.randint(13, 47), r.randint(33, 57)
        c.put(x, y, straw[0] if r.random() < 0.5 else straw[2])
    for x in (22, 38):
        c.fill("line", (x, 32, x, 58), C("7a4a2a"), 1)
        c.fill("line", (x, 32, x + 8, 24), C("7a4a2a"), 1)
    for x in range(14, 47, 3):
        c.put(x, 59, straw[1])
        c.put(x + 1, 31 - (x % 2), straw[0])


def prop_rug(c):
    c.shade("poly", [(6, 52), (52, 52), (60, 40), (14, 40)], ramp("b84a4a", "903434", "602020"))
    c.fill("poly", [(12, 50), (50, 50), (55, 42), (18, 42)], C("7a2a2a"))
    c.fill("poly", [(16, 48), (48, 48), (51, 44), (20, 44)], C("c0a050"))
    c.fill("poly", [(30, 49), (38, 49), (40, 46), (33, 43)], C("2a4a6a"))
    for x in range(8, 52, 3):
        c.put(x, 53, C("e0c890"))
        c.put(x + 7, 39, C("e0c890"))


def prop_banner(c):
    c.shadow(32, 60, 8, 2, 90)
    c.shade("rect", (30, 4, 33, 60), DARKWOOD)
    c.shade("ellipse", (29, 1, 34, 6), GOLDR)
    c.shade("rect", (21, 8, 42, 10), DARKWOOD)
    c.shade("poly", [(22, 10), (42, 10), (42, 40), (32, 34), (22, 40)], RED)
    for x in range(23, 42, 2):
        c.put(x, 11, RED[0])
    c.shade("poly", [(27, 16), (37, 16), (32, 27)], GOLDR)
    c.fill("line", (24, 12, 24, 36), RED[0], 1)
    c.fill("line", (40, 12, 40, 38), RED[2], 1)


def prop_fireplace(c):
    # A stone hearth: blocks lit at their top-left, a dark opening with a
    # log fire and a pot, a mantel with candles.
    c.shadow(32, 61, 24, 2, 90)
    glow(c, 32, 46, 16)
    box(c, 8, 24, 56, 60, 4, GREY, GREYTOP)
    r = random.Random(7)
    for row, y in enumerate(range(26, 60, 6)):
        off = 0 if row % 2 else 5
        c.fill("line", (9, y, 55, y), GREY[2], 1)
        for x in range(9 + off, 56, 10):
            c.fill("line", (x, y, x, y + 5), GREY[2], 1)
            c.put(x + 1, y + 1, GREYTOP[0])
    c.fill("poly", [(18, 60), (46, 60), (46, 40), (42, 36), (22, 36), (18, 40)], C("140e0c"))
    c.shade("rect", (20, 56, 44, 59), ramp("7a5a40", "5a4030", "3a2a20"))
    for k, x in enumerate((25, 32, 39)):
        flame(c, x, 55, 9 if k == 1 else 7, k + 4)
    c.shade("rect", (6, 20, 58, 24), DARKWOOD)
    for x in (14, 50):
        c.fill("rect", (x, 13, x + 2, 19), C("f0ead8"))
        flame(c, x + 1, 12, 3, x)


def prop_fountain(c):
    c.shadow(32, 61, 26, 3, 90)
    c.shade("ellipse", (4, 38, 60, 60), GREY)
    c.shade("ellipse", (8, 40, 56, 56), ramp("5a8ab0", "3a6a90", "244a6a"))
    for x in range(12, 52, 6):
        c.put(x, 46 + (x % 3), C("c8e8f8"))
    c.shade("rect", (28, 20, 36, 48), GREY)
    c.shade("ellipse", (20, 16, 44, 24), GREY)
    c.shade("ellipse", (23, 17, 41, 22), ramp("7ab0d0", "4a88b0", "2a5a80"))
    for (x0, x1) in ((24, 14), (40, 50)):
        c.fill("line", (x0, 20, x1, 44), C("a8d8f0"), 1)
    c.fill("line", (32, 18, 32, 8), C("d8f0ff"), 1)
    c.put(32, 7, C("ffffff"))


def prop_candles(c):
    glow(c, 32, 40, 12)
    c.shade("ellipse", (18, 50, 46, 58), ramp("8a7a6a", "6a5a4a", "4a3a2a"))
    for (x, h) in ((24, 12), (31, 18), (38, 10), (28, 8)):
        c.shade("rect", (x - 1, 54 - h, x + 1, 54), ramp("f8f4e8", "e0d8c4", "b0a88e"))
        c.put(x - 1, 55 - h + 3, C("fffaf0"))
        flame(c, x, 53 - h, 4, x)
    for (x, y) in ((22, 54), (34, 55), (40, 53)):
        c.put(x, y, C("e8e0cc"))


def prop_weapon_rack(c):
    c.shadow(32, 60, 20, 2, 90)
    c.shade("rect", (12, 54, 52, 58), DARKWOOD)
    for x in (13, 49):
        c.shade("rect", (x, 18, x + 3, 58), DARKWOOD)
    c.shade("rect", (12, 22, 52, 25), DARKWOOD)
    # A sword, a spear and an axe resting in it.
    c.fill("rect", (22, 12, 23, 52), IRON[0]); c.fill("rect", (24, 12, 24, 52), IRON[2])
    c.fill("rect", (19, 40, 27, 41), BRASS[1]); c.fill("rect", (22, 42, 24, 50), DARKWOOD[1])
    c.fill("rect", (32, 8, 33, 54), WOOD[1])
    c.shade("poly", [(30, 10), (35, 10), (32.5, 2)], IRON)
    c.fill("rect", (42, 16, 43, 54), WOOD[1])
    c.shade("poly", [(43, 16), (49, 13), (49, 24), (43, 21)], IRON)


def prop_cage(c):
    c.shadow(32, 61, 18, 2, 90)
    c.shade("ellipse", (14, 54, 50, 62), IRON)
    c.shade("ellipse", (16, 10, 48, 18), IRON)
    for x in range(16, 49, 4):
        c.fill("line", (x, 14, x, 58), IRON[1] if x < 32 else IRON[2], 1)
        c.put(x, 16, C("d0d4dc"))
    c.fill("rect", (30, 4, 33, 10), IRON[1])
    # Something pale curled inside: an egg on straw.
    c.shade("ellipse", (24, 50, 40, 57), ramp("f0d878", "c8a448", "8a6c2c"))
    c.shade("ellipse", (28, 40, 36, 52), ramp("fbf6ea", "e0d8c4", "b0a88e"))


PROPS = {
    "lantern": prop_lantern, "signpost": prop_signpost, "table": prop_table, "chair": prop_chair, "bench": prop_bench,
    "shelf": prop_shelf, "cupboard": prop_cupboard, "anvil": prop_anvil, "brazier": prop_brazier, "torch": prop_torch,
    "gravestone": prop_gravestone, "statue": prop_statue, "hay_bale": prop_hay_bale, "rug": prop_rug, "banner": prop_banner,
    "fireplace": prop_fireplace, "fountain": prop_fountain, "candles": prop_candles, "weapon_rack": prop_weapon_rack,
    "cage": prop_cage,
}


# --- furnishings for the peoples (phase 5 interiors) ---------------------------

PALE = ramp("e8dcc0", "c8b490", "967e5a")
LEAFG = ramp("9ad070", "5a9a48", "34603a")
MOON = ramp("f0f8ff", "b8d8f0", "7aa0c8")
HIDE = ramp("b08a5a", "86643c", "5a4026")
SCRAP = ramp("9a9488", "6e6a60", "46423c")


def prop_elf_lamp(c):
    # A slender pale-wood stand twined with a vine, holding a moon-glass lamp.
    c.shadow(32, 60, 8, 2, 90)
    glow(c, 32, 16, 14, (190, 220, 255), 70)
    c.shade("poly", [(28, 60), (36, 60), (34, 56), (30, 56)], PALE)
    c.shade("rect", (31, 20, 33, 56), PALE)
    for y in range(22, 56, 3):
        c.put(30 + (y // 3) % 2 * 4, y, LEAFG[1])
        if y % 6 == 1:
            c.put(29 + (y // 3) % 2 * 6, y - 1, LEAFG[0])
    c.shade("ellipse", (26, 8, 38, 21), MOON)
    c.fill("ellipse", (29, 10, 35, 17), C("ffffff"))
    c.fill("line", (32, 4, 32, 9), PALE[1], 1)


def prop_elf_hanging(c):
    # A woven wall hanging of a great tree under a crescent moon.
    c.shade("rect", (14, 6, 50, 10), PALE)
    c.shade("rect", (16, 10, 48, 50), ramp("3a6a5a", "2a5048", "1c3832"))
    c.shade("ellipse", (24, 18, 40, 34), LEAFG)
    c.fill("rect", (31, 32, 33, 44), C("8a6a48"))
    c.fill("ellipse", (38, 13, 44, 19), C("f0f4e0"))
    c.fill("ellipse", (40, 12, 46, 18), C("2a5048"))
    for x in range(17, 48, 3):
        c.fill("line", (x, 50, x, 54), PALE[1], 1)


def prop_elf_basin(c):
    # A moonwell basin of pale stone holding still, silver water.
    c.shadow(32, 60, 18, 3, 90)
    c.shade("poly", [(24, 60), (40, 60), (37, 44), (27, 44)], GREY)
    c.shade("ellipse", (14, 34, 50, 48), GREYTOP)
    c.shade("ellipse", (18, 36, 46, 45), MOON)
    for x in (24, 30, 38):
        c.put(x, 39, C("ffffff"))
    for (x, y) in ((15, 41), (49, 40), (28, 47)):
        c.put(x, y, LEAFG[1])


def prop_dwarf_keg(c):
    # A great ale keg on a trestle, iron-hooped, with a brass tap.
    c.shadow(32, 61, 20, 2, 90)
    for x in (16, 44):
        c.shade("rect", (x, 46, x + 3, 60), DARKWOOD)
    c.shade("ellipse", (10, 22, 54, 50), ramp("a07a50", "7a5a3a", "54402a"))
    for x in (20, 30, 40):
        c.fill("line", (x, 24, x, 48), C("4a3420"), 1)
    for x in (14, 48):
        c.shade("rect", (x, 23, x + 2, 49), IRON)
    c.shade("ellipse", (8, 28, 18, 44), ramp("c09a70", "9a7a50", "6a5034"))
    c.shade("rect", (4, 34, 9, 37), BRASS)
    c.put(4, 38, BRASS[0])


def prop_dwarf_table(c):
    # A heavy table of dressed stone on two plinths, a tankard and a pick on it.
    c.shadow(32, 60, 22, 3, 90)
    for x in (12, 42):
        c.shade("rect", (x, 42, x + 9, 60), GREY)
        c.fill("line", (x, 51, x + 9, 51), GREY[2], 1)
    box(c, 8, 36, 54, 42, 6, GREY, GREYTOP)
    c.fill("line", (9, 36, 53, 36), C("e0dce8"), 1)
    c.shade("rect", (16, 26, 21, 34), ramp("c09a70", "9a7a50", "6a5034"))
    c.fill("rect", (16, 26, 21, 27), C("f8f0d8"))
    c.fill("line", (30, 32, 46, 28), DARKWOOD[1], 2)
    c.shade("poly", [(44, 22), (48, 22), (50, 34), (46, 30)], IRON)


def prop_dwarf_trophy(c):
    # Crossed axes over a round shield, hung on the wall.
    c.shade("ellipse", (20, 14, 44, 38), ramp("b08a5a", "86643c", "5a4026"))
    c.shade("ellipse", (28, 22, 36, 30), BRASS)
    for (x0, y0, x1, y1, side) in ((12, 8, 50, 44, 1), (52, 8, 14, 44, -1)):
        c.fill("line", (x0, y0, x1, y1), DARKWOOD[1], 2)
        hx, hy = x0 + side * 2, y0 + 2
        c.shade("poly", [(hx - 5, hy - 3), (hx + 5, hy - 3), (hx + 6 * side, hy + 6), (hx - 2 * side, hy + 3)], IRON)


def prop_goblin_totem(c):
    # A little totem of bones and a painted skull on a stick.
    c.shadow(32, 60, 8, 2, 90)
    c.shade("rect", (31, 22, 33, 60), HIDE)
    c.shade("ellipse", (25, 10, 39, 24), GREYTOP)
    c.put(29, 17, C("1a1414")); c.put(30, 17, C("1a1414")); c.put(34, 17, C("1a1414")); c.put(35, 17, C("1a1414"))
    c.fill("line", (27, 13, 37, 21), C("b03a2a"), 1)
    for (x, y) in ((26, 30), (37, 34)):
        c.shade("rect", (x, y, x + 2, y + 8), ramp("f0e8d0", "d0c8b0", "a09880"))
    for y in (28, 40):
        c.fill("line", (28, y, 36, y), C("6a4a2a"), 1)
    c.fill("line", (33, 26, 40, 46), C("c8a040"), 1)


def prop_goblin_scrap(c):
    # A heap of scavenged odds and ends: a dented pot, a cart wheel, rags.
    c.shadow(32, 60, 22, 3, 90)
    c.shade("ellipse", (10, 42, 54, 60), SCRAP)
    c.shade("ellipse", (14, 28, 32, 46), ramp("8a6a48", "6a4e34", "4a3624"))
    c.shade("ellipse", (18, 32, 28, 42), ramp("3a2a1e", "2a1e14", "1a120c"))
    for k in range(8):
        a = k / 8 * math.tau
        c.fill("line", (23, 37, 23 + math.cos(a) * 8, 37 + math.sin(a) * 8), C("6a4e34"), 1)
    c.shade("ellipse", (32, 34, 46, 46), IRON)
    c.fill("rect", (36, 33, 42, 35), IRON[2])
    c.shade("poly", [(40, 50), (54, 46), (56, 56), (44, 58)], ramp("8a3a34", "6a2a26", "4a1c18"))


def prop_goblin_bed(c):
    # A sleeping heap of hides and furs with a bone pillow.
    c.shadow(32, 60, 24, 3, 90)
    c.shade("ellipse", (6, 38, 58, 60), HIDE)
    c.shade("ellipse", (14, 36, 44, 52), ramp("8a7a6a", "6a5a4a", "4a3e32"))
    for x in range(10, 56, 4):
        c.put(x, 59, HIDE[2]); c.put(x + 1, 58, HIDE[0])
    c.shade("ellipse", (40, 36, 54, 44), ramp("f0e8d0", "d0c8b0", "a09880"))


PROPS.update({
    "elf_lamp": prop_elf_lamp, "elf_hanging": prop_elf_hanging, "elf_basin": prop_elf_basin,
    "dwarf_keg": prop_dwarf_keg, "dwarf_table": prop_dwarf_table, "dwarf_trophy": prop_dwarf_trophy,
    "goblin_totem": prop_goblin_totem, "goblin_scrap": prop_goblin_scrap, "goblin_bed": prop_goblin_bed,
})


# --- dungeon and ruin dressing (phase 5) -------------------------------------
# These hang on a wall: drawn high in the cell, so set a little above the
# floor's first row they sit on the wall's face.

def prop_wall_torch(c):
    glow(c, 32, 18, 16, (255, 190, 100), 70)
    c.shade("rect", (29, 30, 35, 44), IRON)
    c.fill("line", (30, 31, 34, 31), C("c4c8d4"), 1)
    c.shade("poly", [(28, 22), (36, 22), (34, 30), (30, 30)], IRON)
    c.shade("rect", (31, 16, 33, 24), DARKWOOD)
    c.shade("rect", (30, 14, 34, 18), ramp("a89070", "7a6448", "4a3a28"))
    flame(c, 32, 13, 10, 31)


def prop_cobweb(c):
    # A web hung across the top of the wall, sagging, with a spider.
    web = C("d8d8e0", 180)
    for k in range(-3, 4):
        x1 = 32 + k * 9
        c.fill("line", (32, 4, x1, 30 - abs(k) * 3), web, 1)
    for ring in (8, 14, 20):
        pts = []
        for k in range(-3, 4):
            t = ring / 26
            pts.append((32 + k * 9 * t, 4 + (26 - abs(k) * 3) * t + (2 if k % 2 else 0)))
        for a, b in zip(pts, pts[1:]):
            c.fill("line", (a[0], a[1], b[0], b[1]), web, 1)
    c.fill("rect", (40, 16, 42, 18), C("1a1418"))
    c.put(39, 15, C("1a1418")); c.put(43, 15, C("1a1418")); c.put(39, 19, C("1a1418")); c.put(43, 19, C("1a1418"))
    c.fill("line", (41, 4, 41, 15), web, 1)


def prop_wall_carving(c):
    # A carved relief in the wall: a round panel with a weeping face and runes.
    c.shade("ellipse", (18, 6, 46, 34), GREY)
    c.shade("ellipse", (21, 9, 43, 31), ramp("8e8a96", "6a6672", "4a4652"))
    c.shade("ellipse", (26, 12, 38, 26), GREYTOP)
    c.fill("rect", (28, 17, 30, 18), GREY[2]); c.fill("rect", (34, 17, 36, 18), GREY[2])
    c.fill("line", (29, 19, 29, 25), C("a03a3a"), 1)
    c.fill("line", (30, 22, 34, 22), GREY[2], 1)
    for k in range(8):
        a = k / 8 * math.tau
        x, y = 32 + math.cos(a) * 12, 20 + math.sin(a) * 12
        c.put(x, y, GREY[2]); c.put(x + 1, y, GREYTOP[0])


def prop_chains(c):
    for x0, length in ((24, 22), (38, 30)):
        for k in range(length // 3):
            y = 4 + k * 3
            if k % 2:
                c.fill("rect", (x0 - 1, y, x0 + 1, y + 2), IRON[1])
                c.put(x0, y + 1, C("1a1418"))
            else:
                c.fill("rect", (x0, y, x0, y + 2), IRON[0])
        c.shade("ellipse", (x0 - 3, 4 + length, x0 + 3, 9 + length), IRON)
        c.put(x0, 6 + length, C("1a1418"))


def prop_ivy_wall(c):
    # Ivy spilling down from the top of a wall or ruin.
    r = random.Random(9)
    for k in range(6):
        x = 12 + k * 8 + r.randint(-2, 2)
        length = r.randint(14, 34)
        for y in range(2, 2 + length):
            xx = x + int(math.sin(y * 0.35 + k) * 1.5)
            c.put(xx, y, C("3a5a2a"))
            if y % 3 == 0:
                side = 1 if (y // 3) % 2 else -1
                c.put(xx + side, y, LEAFG[1]); c.put(xx + side * 2, y - 1, LEAFG[0]); c.put(xx + side, y + 1, LEAFG[2])
    for x in range(8, 58):
        c.put(x, 2, LEAFG[1] if x % 2 else LEAFG[0])
        c.put(x, 3, LEAFG[2])


PROPS.update({"wall_torch": prop_wall_torch, "cobweb": prop_cobweb, "wall_carving": prop_wall_carving,
              "chains": prop_chains, "ivy_wall": prop_ivy_wall})
