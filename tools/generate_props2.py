"""The rest of the props redrawn at full detail (visual overhaul, phase 5).

Same canvas and conventions as tools/generate_props.py: 64 x 64,
three-quarter view, light from the top-left, foot near the bottom.
"""
import math
import random

from generate_flora import C, ramp, PLANK, PLANK_TOP, PLANK_SIDE, IRON, BRASS, _nails
from generate_props import (DARKWOOD, WOODTOP, GREY, GREYTOP, MOSS, FLAME, GOLDR, RED, box, flame, glow,
                            PALE, LEAFG, HIDE, SCRAP)

STONE_DARK = ramp("8a8694", "625e6c", "3e3a46")
BASALT = ramp("5a5664", "3e3a48", "24222c")
RUNE = C("8ae0ff")
RUNE_GLOW = (140, 220, 255)
GREEN = ramp("8ac060", "5a9a44", "34602a")
CLOTHB = ramp("6a8ac0", "4a6aa0", "2e4670")


def texture(c, pts, ramp_, seed, chips=0.07, lichen=0.0):
    """Chisel marks, chips of light and lichen over a stone's pixels."""
    r = random.Random(seed)
    for (x, y) in pts:
        v = r.random()
        if v < chips:
            c.put(x, y, ramp_[2])
        elif v > 1 - chips * 0.6:
            c.put(x, y, ramp_[0])
        elif lichen and v < chips + lichen:
            c.put(x, y, C("9aa860") if r.random() < 0.6 else C("c8b860"))


def stone_slab(c, poly, ramp_=GREY, seed=0, lichen=0.03, crack=True):
    pts = c.shade("poly", poly, ramp_)
    texture(c, pts, ramp_, seed, lichen=lichen)
    if crack and pts:
        r = random.Random(seed + 1)
        x, y = r.choice(pts)
        for _ in range(8):
            if (x, y) in set(pts):
                c.put(x, y, ramp_[2])
            x += r.choice((-1, 0, 1))
            y += 1
    return pts


def moss_foot(c, x0, x1, y):
    for x in range(x0, x1):
        if (x * 7) % 5 < 3:
            c.put(x, y, MOSS[1])
            c.put(x, y - 1, MOSS[0] if x % 3 == 0 else MOSS[1])


def runes(c, x, y0, y1, colour=RUNE, step=5):
    for k, y in enumerate(range(y0, y1, step)):
        shape = [(0, 0), (1, 1), (0, 2)] if k % 3 == 0 else [(0, 0), (2, 0), (1, 1), (1, 2)] if k % 3 == 1 else [(1, 0), (0, 1), (2, 1), (1, 2)]
        for dx, dy in shape:
            c.put(x + dx, y + dy, colour)


# --- stones ----------------------------------------------------------------------

def p_floor(c):
    r = random.Random(1)
    for row, y in enumerate(range(8, 60, 10)):
        x = -(row % 2) * 8
        while x < 64:
            w = r.choice((14, 16, 18))
            pts = c.shade("rect", (max(x + 1, 0), y + 1, min(x + w - 1, 63), y + 9), GREYTOP)
            texture(c, pts, GREYTOP, x * 13 + y, lichen=0.02)
            x += w


def p_rubble(c):
    c.shadow(32, 58, 22, 3, 80)
    for k, (x0, y0, w, h) in enumerate(((10, 44, 16, 12), (24, 38, 18, 14), (38, 46, 16, 10), (18, 52, 12, 7), (44, 40, 10, 8))):
        stone_slab(c, [(x0, y0 + h), (x0 + 2, y0 + 2), (x0 + w // 2, y0), (x0 + w, y0 + 3), (x0 + w, y0 + h)], GREY, 10 + k)
    moss_foot(c, 12, 52, 58)


def p_obelisk(c):
    c.shadow(32, 60, 14, 3, 90)
    stone_slab(c, [(22, 60), (42, 60), (40, 54), (24, 54)], GREY, 2, crack=False)
    stone_slab(c, [(25, 54), (39, 54), (36, 12), (32, 4), (28, 12)], STONE_DARK, 3)
    c.fill("line", (28, 12, 26, 54), GREYTOP[0], 1)
    runes(c, 31, 18, 50, C("b8c0d0"), 6)
    moss_foot(c, 22, 42, 59)


def p_palisade(c):
    c.shadow(32, 61, 28, 2, 90)
    for k, x in enumerate(range(6, 58, 8)):
        h = 46 + (k * 7) % 6
        c.shade("rect", (x, 60 - h + 6, x + 6, 60), DARKWOOD)
        c.shade("poly", [(x, 60 - h + 6), (x + 6, 60 - h + 6), (x + 3, 60 - h)], WOODTOP)
        for y in range(60 - h + 10, 58, 6):
            c.put(x + 2, y, DARKWOOD[2])
        c.put(x + 1, 60 - h + 7, WOODTOP[0])
    for y in (24, 46):
        c.shade("rect", (4, y, 60, y + 3), PLANK)
        _nails(c, [(x + 3, y + 1) for x in range(6, 58, 8)])


def p_spike_trap(c):
    c.shade("poly", [(6, 54), (54, 54), (60, 44), (12, 44)], IRON)
    c.fill("poly", [(10, 52), (52, 52), (56, 46), (14, 46)], C("1a1418"))
    for k in range(10):
        x = 14 + k * 4
        y = 51 - (k % 2) * 4
        c.shade("poly", [(x - 2, y), (x + 2, y), (x, y - 10)], ramp("e4e8f0", "a8acb8", "6a6e7a"))
        if k % 3 == 0:
            c.put(x, y - 9, C("a02a2a"))


def p_ballista(c):
    c.shadow(32, 60, 22, 3, 90)
    for x in (16, 46):
        c.fill("line", (32, 40, x, 60), DARKWOOD[1], 3)
    c.shade("rect", (28, 36, 36, 44), DARKWOOD)
    c.shade("rect", (8, 26, 56, 30), PLANK)
    c.fill("line", (8, 26, 56, 26), C("d8b080"), 1)
    for x, d in ((8, -1), (56, 1)):
        c.fill("line", (x, 28, x + d * -4, 16), DARKWOOD[1], 3)
    c.fill("line", (6, 16, 32, 24), C("d8d0b8"), 1)
    c.fill("line", (58, 16, 32, 24), C("d8d0b8"), 1)
    c.fill("line", (32, 34, 32, 10), IRON[1], 2)
    c.shade("poly", [(29, 12), (35, 12), (32, 4)], IRON)


def _waystone(c, lit):
    c.shadow(32, 60, 16, 3, 90)
    if lit:
        glow(c, 32, 34, 22, RUNE_GLOW, 80)
    stone_slab(c, [(18, 60), (46, 60), (44, 52), (20, 52)], GREY, 4, crack=False)
    stone_slab(c, [(21, 52), (43, 52), (42, 18), (38, 9), (32, 6), (26, 9), (22, 18)], STONE_DARK, 5, lichen=0.05)
    c.fill("line", (23, 18, 26, 9), GREYTOP[0], 1)
    colour = RUNE if lit else C("6a7488")
    # A great carved spiral with runes running down from it.
    for k in range(18):
        a = k * 0.6
        rr = 2 + k * 0.32
        c.put(32 + math.cos(a) * rr, 22 + math.sin(a) * rr, colour)
    runes(c, 31, 32, 50, colour, 6)
    if lit:
        for (x, y) in ((22, 30), (42, 26), (26, 44)):
            c.put(x, y, C("ffffff"))
    moss_foot(c, 18, 46, 59)


def p_waystone(c):
    _waystone(c, False)


def p_waystone_lit(c):
    _waystone(c, True)


def p_ruined_tower(c):
    c.shadow(32, 61, 24, 2, 90)
    pts = c.shade("poly", [(10, 60), (54, 60), (52, 20), (46, 14), (42, 22), (36, 10), (30, 18), (24, 12), (12, 22)], GREY)
    texture(c, pts, GREY, 7, lichen=0.04)
    for row, y in enumerate(range(22, 60, 7)):
        off = 0 if row % 2 else 5
        c.fill("line", (11, y, 53, y), GREY[2], 1)
        for x in range(12 + off, 53, 10):
            c.fill("line", (x, y, x, y + 6), GREY[2], 1)
            c.put(x + 1, y + 1, GREYTOP[0])
    c.fill("poly", [(26, 60), (38, 60), (38, 44), (32, 38), (26, 44)], C("140e10"))
    c.fill("rect", (40, 28, 44, 34), C("140e10"))
    for (x0, x1, y) in ((12, 22, 58), (44, 54, 57)):
        moss_foot(c, x0, x1, y)
    for y in range(24, 50, 3):
        c.put(12 + (y % 2), y, LEAFG[1])


def _root_stump(c, gem, seed):
    c.shadow(32, 60, 20, 3, 90)
    bark = DARKWOOD
    for k, (dx, l) in enumerate(((-14, 8), (14, 8), (-8, 6), (8, 6))):
        c.fill("line", (32 + dx // 2, 54, 32 + dx, 60), bark[1], 3)
    pts = c.shade("poly", [(18, 58), (46, 58), (44, 32), (20, 32)], bark)
    texture(c, pts, bark, seed, chips=0.1)
    c.shade("ellipse", (19, 28, 45, 36), ramp("caa474", "a8805a", "7a5a3c"))
    for k in range(3):
        c.put(32 + k * 3 - 3, 31 + (k % 2), C("8a6a48"))
    c.shade("ellipse", (28, 42, 36, 50), gem)
    c.put(30, 44, C("ffffff"))
    glow(c, 32, 46, 10, gem[0][:3], 50)


def p_root_cutter(c):
    _root_stump(c, ramp("a8f0a0", "58c060", "2a7a34"), 21)
    c.fill("line", (40, 30, 54, 10), DARKWOOD[1], 2)
    c.shade("poly", [(50, 8), (58, 4), (56, 14)], IRON)


def p_root_delver(c):
    _root_stump(c, ramp("ffe08a", "f0a030", "a86418"), 22)
    c.shade("ellipse", (8, 48, 18, 56), GREY)
    c.shade("ellipse", (46, 46, 56, 54), ramp("ffd880", "e0a040", "8a6020"))


def p_root_tender(c):
    _root_stump(c, ramp("ffb0e0", "e060b0", "8a2a6a"), 23)
    for k, x in enumerate((22, 32, 42)):
        c.fill("line", (x, 30, x + (k - 1) * 4, 12), GREEN[1], 1)
        c.shade("ellipse", (x + (k - 1) * 4 - 3, 6, x + (k - 1) * 4 + 3, 12), ramp("ffd0f0", "f080c8", "a04080") if k == 1 else GREEN)


def p_root_hollow(c):
    c.shadow(32, 60, 26, 3, 90)
    pts = c.shade("poly", [(6, 60), (58, 60), (54, 22), (10, 22)], DARKWOOD)
    texture(c, pts, DARKWOOD, 24, chips=0.1)
    c.shade("ellipse", (8, 16, 56, 28), MOSS)
    c.fill("poly", [(20, 60), (44, 60), (42, 40), (32, 32), (22, 40)], C("120c08"))
    for (x, y, col) in ((26, 54, "f0e060"), (34, 52, "60e0a0"), (38, 56, "e080c0")):
        c.shade("ellipse", (x - 2, y - 2, x + 2, y + 2), ramp(col, col, col))
        glow(c, x, y, 6, C(col)[:3], 50)


def p_farmhouse(c):
    c.shadow(32, 61, 28, 2, 90)
    box(c, 8, 30, 52, 60, 4, ramp("c04a3a", "9a3428", "6a2018"), ramp("d06050", "b04434", "7a2a20"))
    c.shade("poly", [(4, 32), (56, 32), (46, 12), (14, 12)], ramp("7a5a40", "5a4030", "3a2a20"))
    for y in range(16, 32, 4):
        c.fill("line", (10, y, 50, y), DARKWOOD[2], 1)
    c.fill("rect", (22, 40, 38, 60), C("f0e8d8"))
    c.fill("line", (22, 40, 38, 60), C("f0e8d8"), 2)
    c.fill("line", (38, 40, 22, 60), C("f0e8d8"), 2)
    c.fill("rect", (24, 42, 36, 58), C("8a2a20"))
    c.fill("line", (24, 42, 36, 58), C("f0e8d8"), 1)
    c.fill("line", (36, 42, 24, 58), C("f0e8d8"), 1)
    c.shade("rect", (26, 20, 34, 28), ramp("f0d878", "c8a448", "8a6c2c"))


def p_furnace(c):
    c.shadow(32, 61, 22, 2, 90)
    glow(c, 32, 44, 14)
    box(c, 12, 26, 50, 60, 4, GREY, GREYTOP)
    for row, y in enumerate(range(28, 60, 6)):
        off = 0 if row % 2 else 5
        c.fill("line", (13, y, 49, y), GREY[2], 1)
        for x in range(13 + off, 50, 10):
            c.fill("line", (x, y, x, y + 5), GREY[2], 1)
    c.shade("rect", (24, 4, 34, 26), GREY)
    c.fill("poly", [(20, 58), (42, 58), (42, 42), (31, 36), (20, 42)], C("1a0e08"))
    c.fill("poly", [(23, 58), (39, 58), (38, 48), (24, 48)], C("ff9a40"))
    c.fill("rect", (26, 52, 36, 58), C("ffe08a"))
    for k, x in enumerate((26, 31, 36)):
        flame(c, x, 50, 6, k + 9)
    c.shade("ellipse", (2, 52, 12, 60), ramp("4a4652", "2e2c34", "1a1820"))


def p_trophy_stand(c):
    c.shadow(32, 60, 14, 2, 90)
    box(c, 18, 52, 46, 60, 3, DARKWOOD, WOODTOP)
    c.shade("rect", (30, 22, 34, 52), DARKWOOD)
    c.shade("poly", [(20, 10), (44, 10), (40, 26), (24, 26)], GOLDR)
    c.fill("line", (22, 11, 42, 11), C("fff4c0"), 1)
    c.shade("rect", (26, 26, 38, 30), GOLDR)
    c.shade("ellipse", (14, 12, 22, 20), GOLDR)
    c.shade("ellipse", (42, 12, 50, 20), GOLDR)
    c.put(31, 15, C("e04040")); c.put(32, 15, C("ff7070"))


def p_standing_stone(c):
    c.shadow(32, 60, 14, 3, 90)
    stone_slab(c, [(20, 60), (44, 60), (46, 30), (40, 10), (30, 6), (22, 14), (18, 36)], GREY, 30, lichen=0.06)
    c.fill("line", (21, 34, 23, 14), GREYTOP[0], 1)
    moss_foot(c, 18, 46, 59)


def p_carved_pillar(c):
    c.shadow(32, 60, 14, 2, 90)
    box(c, 20, 52, 44, 60, 3, GREY, GREYTOP)
    pts = c.shade("rect", (24, 12, 40, 52), GREY)
    texture(c, pts, GREY, 31)
    for x in (27, 31, 35):
        c.fill("line", (x, 14, x, 50), GREY[2], 1)
        c.fill("line", (x + 1, 14, x + 1, 50), GREYTOP[0], 1)
    box(c, 20, 8, 44, 12, 3, GREY, GREYTOP)
    for y in (20, 34):
        c.fill("line", (24, y, 40, y), GREY[2], 1)
        c.fill("line", (24, y + 1, 40, y + 1), GREYTOP[0], 1)
    moss_foot(c, 20, 44, 59)


def p_rune_stele(c):
    c.shadow(32, 60, 14, 2, 90)
    glow(c, 32, 30, 14, RUNE_GLOW, 50)
    stone_slab(c, [(20, 60), (44, 60), (44, 16), (32, 8), (20, 16)], BASALT, 32)
    c.fill("line", (21, 16, 31, 9), GREYTOP[2], 1)
    for col in (26, 31, 36):
        runes(c, col, 18, 54, RUNE, 6)


def p_chime_stone(c):
    c.shadow(32, 60, 16, 2, 90)
    stone_slab(c, [(18, 60), (46, 60), (46, 22), (32, 10), (18, 22)], GREY, 33)
    c.fill("ellipse", (26, 22, 38, 34), C("1a1820"))
    c.shade("ellipse", (28, 24, 36, 32), ramp("c8f0ff", "8ac0e0", "4a7aa0"))
    c.put(30, 26, C("ffffff"))
    for k in range(3):
        c.fill("line", (24 + k * 8, 40, 24 + k * 8, 52), C("c8a040"), 1)
        c.shade("ellipse", (22 + k * 8, 52, 26 + k * 8, 56), GOLDR)


def p_stone_pedestal(c):
    c.shadow(32, 60, 14, 2, 90)
    box(c, 18, 54, 46, 60, 3, GREY, GREYTOP)
    pts = c.shade("poly", [(24, 54), (40, 54), (37, 32), (27, 32)], GREY)
    texture(c, pts, GREY, 34)
    box(c, 20, 28, 44, 32, 4, GREY, GREYTOP)
    c.fill("line", (21, 28, 43, 28), C("e0dce8"), 1)
    moss_foot(c, 18, 46, 59)


def p_stone_shard(c):
    c.shadow(32, 60, 18, 3, 90)
    for k, (x, top, w) in enumerate(((22, 18, 8), (32, 6, 10), (42, 24, 7))):
        stone_slab(c, [(x - w, 60), (x + w, 60), (x + 2, top), (x - 1, top + 2)], BASALT, 40 + k, crack=False)
        c.fill("line", (x - w + 2, 58, x - 1, top + 3), BASALT[0], 1)


def p_menhir(c):
    c.shadow(32, 60, 12, 3, 90)
    stone_slab(c, [(24, 60), (40, 60), (42, 20), (36, 6), (28, 8), (22, 22)], STONE_DARK, 41, lichen=0.08)
    c.fill("line", (23, 22, 28, 9), GREYTOP[0], 1)
    for y in (20, 32, 44):
        c.fill("line", (26, y, 38, y + 2), STONE_DARK[2], 1)
    moss_foot(c, 22, 42, 59)


def p_answer_tablet(c):
    c.shadow(32, 60, 14, 2, 90)
    stone_slab(c, [(18, 60), (46, 60), (46, 18), (40, 12), (24, 12), (18, 18)], GREY, 42, crack=False)
    c.fill("rect", (22, 18, 42, 54), C("4a4652"))
    c.shade("rect", (23, 19, 41, 53), GREYTOP)
    for y in range(22, 52, 4):
        c.fill("line", (25, y, 25 + (y * 7) % 14 + 2, y), GREY[2], 1)


# --- iron, wood and the rest ----------------------------------------------------------

def p_iron_gate(c):
    c.shadow(32, 61, 28, 2, 90)
    for x in (4, 52):
        box(c, x, 10, x + 8, 60, 3, GREY, GREYTOP)
        c.shade("ellipse", (x - 1, 2, x + 10, 12), GREYTOP)
    for x in range(14, 52, 4):
        c.fill("line", (x, 16, x, 60), IRON[1] if x < 32 else IRON[2], 1)
        c.shade("poly", [(x - 1, 16), (x + 1, 16), (x, 12)], IRON)
    for y in (24, 44):
        c.shade("rect", (12, y, 52, y + 2), IRON)
    c.shade("rect", (30, 32, 34, 38), BRASS)


def p_carriage(c):
    c.shadow(32, 61, 28, 2, 90)
    box(c, 10, 22, 52, 50, 4, ramp("3a3a5a", "28283e", "18182a"), ramp("4a4a6a", "3a3a5a", "28283e"))
    c.fill("rect", (16, 26, 28, 38), C("c8a040"))
    c.fill("rect", (17, 27, 27, 37), C("8a2a2a"))
    c.fill("rect", (34, 26, 46, 38), C("c8a040"))
    c.fill("rect", (35, 27, 45, 37), C("8a2a2a"))
    c.fill("line", (10, 22, 52, 22), GOLDR[0], 1)
    for cx in (16, 46):
        c.shade("ellipse", (cx - 8, 44, cx + 8, 60), DARKWOOD)
        c.fill("ellipse", (cx - 5, 47, cx + 5, 57), C("2a1e14"))
        for k in range(6):
            a = k / 6 * math.tau
            c.fill("line", (cx, 52, cx + math.cos(a) * 5, 52 + math.sin(a) * 5), C("8a6a48"), 1)
        c.shade("ellipse", (cx - 1, 51, cx + 1, 53), GOLDR)


def p_hatch(c):
    c.shade("ellipse", (8, 36, 56, 60), GREY)
    pts = c.shade("poly", [(14, 54), (50, 54), (54, 42), (18, 42)], PLANK)
    for x in range(20, 52, 6):
        c.fill("line", (x, 54, x + 4, 42), C("3a2818"), 1)
    for y in (45, 51):
        c.fill("line", (15, y, 52, y), IRON[1], 1)
    c.shade("ellipse", (32, 46, 38, 50), IRON)


def p_horn_post(c):
    c.shadow(32, 60, 10, 2, 90)
    c.shade("rect", (29, 20, 35, 60), DARKWOOD)
    c.shade("rect", (22, 18, 44, 22), DARKWOOD)
    pts = []
    for s in range(22):
        t = s / 22
        x = 26 + s
        y = 30 - math.sin(t * 2.2) * 6
        w = 1 + t * 4
        for d in range(int(-w), int(w) + 1):
            c.put(x, y + d, C("f0e8d0") if d < 0 else C("c8b898") if d == 0 else C("9a8a70"))
    for x in (30, 40):
        c.fill("line", (x, 22, x, 28), C("6a4a2a"), 1)
    c.shade("ellipse", (44, 22, 52, 38), ramp("4a3a2a", "2a1e14", "1a120c"))


def p_writing_desk(c):
    c.shadow(32, 60, 22, 2, 90)
    for x in (12, 48):
        c.shade("rect", (x, 40, x + 3, 59), DARKWOOD)
    box(c, 10, 36, 52, 42, 5, PLANK, PLANK_TOP)
    c.shade("rect", (32, 42, 50, 54), PLANK)
    c.shade("rect", (36, 46, 46, 50), PLANK_SIDE)
    c.put(41, 48, BRASS[0])
    c.shade("poly", [(16, 34), (30, 34), (32, 28), (18, 28)], ramp("f4ecd8", "e0d4b8", "b0a488"))
    for y in (30, 32):
        c.fill("line", (19, y, 28, y), C("6a5a48"), 1)
    c.shade("rect", (38, 28, 42, 34), ramp("3a3a4a", "22222e", "121218"))
    c.fill("line", (41, 28, 46, 18), C("f0f0f0"), 1)
    c.fill("rect", (46, 26, 48, 34), C("f0ead8"))
    flame(c, 47, 25, 3, 5)


def p_cauldron(c):
    c.shadow(32, 60, 20, 3, 90)
    glow(c, 32, 24, 16, (140, 255, 140), 50)
    for x in (16, 32, 48):
        c.fill("line", (x, 50, x + (x - 32) // 4, 60), IRON[2], 2)
    c.shade("ellipse", (10, 26, 54, 58), ramp("4a4652", "2e2c34", "1a1820"))
    c.shade("ellipse", (12, 24, 52, 34), IRON)
    c.shade("ellipse", (15, 26, 49, 32), ramp("b0ff8a", "60d050", "2a8a30"))
    for (x, y) in ((22, 28), (36, 27), (42, 29)):
        c.put(x, y, C("eaffd0")); c.put(x + 1, y - 1, C("eaffd0"))
    for k in range(4):
        flame(c, 22 + k * 7, 60, 4, k + 20)
    c.fill("line", (40, 26, 52, 8), DARKWOOD[1], 2)


def p_herb_rack(c):
    c.shadow(32, 60, 20, 2, 90)
    for x in (10, 52):
        c.shade("rect", (x, 10, x + 3, 60), DARKWOOD)
    c.shade("rect", (10, 10, 55, 13), DARKWOOD)
    r = random.Random(7)
    for k, x in enumerate(range(16, 50, 6)):
        col = [ramp("8ac060", "5a9a44", "34602a"), ramp("c8a0f0", "9a6cc8", "6a4290"), ramp("e8d070", "b89a40", "7a6420")][k % 3]
        c.fill("line", (x + 1, 13, x + 1, 18), C("c8b890"), 1)
        for y in range(18, 18 + r.randint(10, 16)):
            for dx in (-1, 0, 1, 2):
                if r.random() < 0.7:
                    c.put(x + dx + (y % 2), y, col[r.randrange(3)])
    c.shade("rect", (12, 46, 52, 50), PLANK)
    for x in range(16, 50, 8):
        c.shade("ellipse", (x, 40, x + 6, 46), ramp("d08a5a", "a8603a", "703c24"))


def p_jar_shelf(c):
    c.shadow(32, 61, 18, 2, 90)
    box(c, 12, 10, 52, 60, 3, DARKWOOD, WOODTOP)
    c.fill("rect", (15, 12, 49, 58), C("2a1c12"))
    r = random.Random(8)
    for shelf_y in (26, 42, 58):
        c.shade("rect", (14, shelf_y - 1, 50, shelf_y + 1), PLANK)
        x = 16
        while x < 46:
            h = r.randint(7, 11)
            col = C(r.choice(["e05a5a", "5ab0e0", "8ae07a", "e0c050", "c070e0", "f0a050"]))
            for xx in range(x, x + 4):
                for yy in range(shelf_y - 1 - h, shelf_y - 1):
                    glass = yy < shelf_y - 1 - h + 3
                    c.put(xx, yy, C("d8e0e8") if glass else col if xx > x else tuple(min(255, v + 60) for v in col[:3]) + (255,))
            c.fill("rect", (x + 1, shelf_y - 2 - h, x + 2, shelf_y - 1 - h), C("8a6a48"))
            x += 6


def p_loom(c):
    c.shadow(32, 60, 24, 2, 90)
    for x in (8, 52):
        c.shade("rect", (x, 10, x + 4, 60), DARKWOOD)
    for y in (10, 40):
        c.shade("rect", (8, y, 56, y + 3), DARKWOOD)
    for x in range(14, 52, 2):
        c.fill("line", (x, 13, x, 40), C("e8e0d0"), 1)
    for y in range(14, 34):
        col = C("b03a3a") if (y // 4) % 2 else C("c8a040")
        for x in range(14, 51):
            if (x + y) % 2 == 0:
                c.put(x, y, col)
    c.shade("rect", (12, 34, 52, 37), PLANK)
    c.shade("rect", (12, 52, 52, 55), PLANK)


def p_spinning_wheel(c):
    c.shadow(32, 60, 20, 2, 90)
    c.shade("rect", (10, 50, 52, 53), DARKWOOD)
    for x in (14, 46):
        c.fill("line", (x, 52, x - 2, 60), DARKWOOD[1], 2)
    for k in range(48):
        a = k / 48 * math.tau
        c.put(29 + math.cos(a) * 14, 31 + math.sin(a) * 14, DARKWOOD[1] if k % 6 else DARKWOOD[0])
        c.put(29 + math.cos(a) * 13, 31 + math.sin(a) * 13, DARKWOOD[2])
    for k in range(8):
        a = k / 8 * math.tau
        c.fill("line", (29, 31, 29 + math.cos(a) * 13, 31 + math.sin(a) * 13), C("8a6a48"), 1)
    c.shade("ellipse", (27, 29, 31, 33), BRASS)
    c.fill("line", (29, 31, 50, 18), DARKWOOD[1], 2)
    c.shade("ellipse", (46, 12, 56, 22), ramp("f8f4ec", "e0d8c8", "b0a898"))


def p_grain_sacks(c):
    c.shadow(32, 60, 22, 3, 90)
    sack = ramp("e8d8b0", "c8b088", "8a7a5a")
    for (x0, y0, w, h) in ((8, 34, 24, 26), (30, 30, 24, 30), (20, 18, 22, 22)):
        c.shade("poly", [(x0, y0 + h), (x0 + w, y0 + h), (x0 + w - 2, y0 + 6), (x0 + w // 2 + 3, y0), (x0 + w // 2 - 3, y0), (x0 + 2, y0 + 6)], sack)
        c.fill("line", (x0 + w // 2 - 3, y0 + 4, x0 + w // 2 + 3, y0 + 4), C("8a6a48"), 1)
        c.fill("rect", (x0 + 6, y0 + h - 12, x0 + 10, y0 + h - 8), C("a85a3a"))
    for (x, y) in ((24, 18), (26, 17), (28, 18)):
        c.put(x, y, C("f0d878"))


def p_tool_rack(c):
    c.shade("rect", (8, 14, 56, 18), DARKWOOD)
    _nails(c, [(12, 16), (52, 16)])
    c.fill("line", (16, 18, 16, 50), DARKWOOD[1], 2)
    c.shade("poly", [(12, 46), (20, 46), (18, 54), (14, 54)], IRON)
    c.fill("line", (30, 18, 30, 52), DARKWOOD[1], 2)
    for k in range(5):
        c.fill("line", (26 + k * 2, 52, 26 + k * 2, 58), IRON[1], 1)
    c.fill("line", (44, 18, 44, 44), DARKWOOD[1], 2)
    c.shade("poly", [(40, 42), (52, 42), (54, 46), (40, 46)], IRON)


def p_pelt_rug(c):
    pelt = ramp("a88a6a", "7a5e44", "4e3a28")
    c.shade("ellipse", (10, 34, 54, 58), pelt)
    for (x0, y0, x1, y1) in ((14, 38, 4, 30), (50, 38, 60, 30), (14, 54, 4, 62), (50, 54, 60, 62)):
        c.fill("line", (x0, y0, x1, y1), pelt[1], 3)
    c.shade("ellipse", (26, 24, 38, 36), pelt)
    c.put(29, 29, C("1a1414")); c.put(34, 29, C("1a1414"))
    for k in range(14):
        c.put(16 + k * 3, 46 + (k % 3) - 1, pelt[0])


def p_antler_mount(c):
    c.shade("ellipse", (22, 26, 42, 48), DARKWOOD)
    c.shade("ellipse", (26, 30, 38, 44), ramp("a88a6a", "7a5e44", "4e3a28"))
    for side in (-1, 1):
        pts = [(32 + side * 4, 30), (32 + side * 14, 14), (32 + side * 22, 6)]
        for a, b in zip(pts, pts[1:]):
            c.fill("line", (a[0], a[1], b[0], b[1]), C("e8dcc0"), 2)
        for (x, y) in ((32 + side * 12, 18), (32 + side * 18, 10)):
            c.fill("line", (x, y, x + side * 2, y - 8), C("d0c4a8"), 1)


def p_stool(c):
    c.shadow(32, 60, 10, 2, 90)
    for x in (24, 39):
        c.fill("line", (x + 1, 44, x - (1 if x < 32 else -1) * 2, 60), DARKWOOD[1], 2)
    c.fill("line", (32, 44, 32, 60), DARKWOOD[2], 2)
    c.shade("ellipse", (20, 38, 44, 48), WOODTOP)
    c.fill("line", (22, 41, 40, 41), C("d8b080"), 1)
    c.fill("line", (25, 52, 39, 52), DARKWOOD[1], 1)


def p_firewood(c):
    c.shadow(32, 60, 24, 2, 90)
    for row in range(4):
        for k in range(5 - (row % 2)):
            x = 10 + k * 10 + (row % 2) * 5
            y = 52 - row * 9
            c.shade("ellipse", (x, y, x + 10, y + 9), DARKWOOD)
            c.shade("ellipse", (x + 2, y + 2, x + 8, y + 7), ramp("e0b888", "c09a68", "8a6a48"))
            c.put(x + 5, y + 4, C("8a6a48"))


def p_dresser(c):
    c.shadow(32, 61, 20, 2, 90)
    box(c, 12, 30, 52, 60, 4, PLANK, PLANK_TOP)
    for y in (34, 43, 52):
        c.shade("rect", (15, y, 49, y + 7), PLANK_SIDE)
        c.fill("line", (15, y, 49, y), C("d8b080"), 1)
        c.shade("ellipse", (30, y + 2, 34, y + 5), BRASS)
    c.shade("rect", (36, 8, 48, 26), ramp("c8a060", "a07a40", "6a4c28"))
    c.fill("rect", (38, 10, 46, 24), C("a8c8e0"))
    c.fill("line", (39, 11, 41, 13), C("ffffff"), 1)
    c.shade("ellipse", (16, 22, 24, 28), ramp("f8f4ec", "e0d8c8", "b0a898"))


def p_cradle(c):
    c.shadow(32, 60, 20, 2, 90)
    for x in (16, 48):
        c.shade("poly", [(x - 6, 60), (x + 6, 60), (x, 54)], DARKWOOD)
    c.shade("poly", [(10, 32), (54, 32), (50, 54), (14, 54)], PLANK)
    for x in range(14, 52, 5):
        c.fill("line", (x, 34, x + 1, 52), C("5a4030"), 1)
    c.shade("ellipse", (14, 26, 50, 36), ramp("f0e0e8", "d8c0cc", "a88a98"))
    c.shade("ellipse", (18, 22, 30, 32), ramp("f8f0f4", "e0d0d8", "b0a0a8"))
    for (x, y) in ((24, 29), (38, 30)):
        c.put(x, y, C("e090b0"))


def p_pots_rack(c):
    c.shade("rect", (6, 10, 58, 14), DARKWOOD)
    _nails(c, [(10, 12), (54, 12)])
    for k, (x, kind) in enumerate(((14, "pan"), (28, "pot"), (42, "ladle"), (52, "pan"))):
        c.fill("line", (x, 14, x, 22), IRON[1], 1)
        if kind == "pan":
            c.shade("ellipse", (x - 7, 22, x + 7, 34), ramp("e09060", "b06838", "784024"))
        elif kind == "pot":
            c.shade("rect", (x - 7, 24, x + 7, 38), IRON)
            c.fill("line", (x - 7, 24, x + 7, 24), C("d0d4dc"), 1)
        else:
            c.fill("line", (x, 22, x, 34), IRON[0], 1)
            c.shade("ellipse", (x - 3, 34, x + 3, 40), IRON)


def p_yarn_basket(c):
    c.shadow(32, 60, 18, 2, 90)
    c.shade("poly", [(12, 42), (52, 42), (48, 60), (16, 60)], ramp("c8a060", "a07a40", "6a4c28"))
    for y in range(44, 60, 3):
        c.fill("line", (13, y, 51, y), C("6a4c28"), 1)
    for k, (x, col) in enumerate(((22, "d04848"), (32, "4a78d0"), (42, "e0c050"), (27, "6ac05a"))):
        y = 36 if k < 3 else 32
        c.shade("ellipse", (x - 6, y - 5, x + 6, y + 6), ramp(col, col, col))
        c.fill("line", (x - 3, y - 2, x + 3, y + 3), tuple(int(v * 0.7) for v in C(col)[:3]) + (255,), 1)
        c.put(x - 2, y - 3, C("ffffff"))
    c.fill("line", (40, 30, 52, 20), C("c8c8d0"), 1)


def p_lever(c):
    c.shadow(32, 60, 14, 2, 90)
    box(c, 20, 46, 44, 60, 4, GREY, GREYTOP)
    c.fill("rect", (26, 44, 38, 48), C("1a1820"))
    c.fill("line", (32, 46, 42, 22), IRON[1], 3)
    c.fill("line", (31, 46, 41, 22), C("d0d4dc"), 1)
    c.shade("ellipse", (38, 16, 48, 26), RED)


def p_manor(c):
    c.shadow(32, 61, 30, 2, 90)
    box(c, 6, 30, 58, 60, 4, ramp("f0e8d8", "d8ccb8", "a89a84"), ramp("f8f0e4", "e8dccc", "b8aa94"))
    c.shade("poly", [(2, 32), (62, 32), (52, 14), (12, 14)], ramp("4a4a6a", "34344e", "222236"))
    for y in range(18, 32, 4):
        c.fill("line", (8, y, 56, y), C("1a1a28"), 1)
    c.shade("rect", (28, 2, 36, 16), GREY)
    for x in (10, 20, 40, 50):
        c.fill("rect", (x, 38, x + 6, 46), C("ffe8a0"))
        c.fill("line", (x + 3, 38, x + 3, 46), C("5a4a3a"), 1)
        c.fill("line", (x, 42, x + 6, 42), C("5a4a3a"), 1)
    c.fill("rect", (28, 44, 36, 60), C("6a2a20"))
    c.shade("rect", (29, 45, 35, 60), ramp("8a3a2a", "6a2a20", "4a1a14"))
    for x in range(8, 58, 4):
        if x % 8 == 0:
            c.put(x, 58, LEAFG[1]); c.put(x + 1, 57, LEAFG[0])


PROPS = {
    "floor": p_floor, "rubble": p_rubble, "obelisk": p_obelisk, "palisade": p_palisade, "spike_trap": p_spike_trap,
    "ballista": p_ballista, "waystone": p_waystone, "waystone_lit": p_waystone_lit, "ruined_tower": p_ruined_tower,
    "root_cutter": p_root_cutter, "root_delver": p_root_delver, "root_tender": p_root_tender, "root_hollow": p_root_hollow,
    "farmhouse": p_farmhouse, "furnace": p_furnace, "trophy_stand": p_trophy_stand, "standing_stone": p_standing_stone,
    "carved_pillar": p_carved_pillar, "rune_stele": p_rune_stele, "chime_stone": p_chime_stone, "stone_pedestal": p_stone_pedestal,
    "stone_shard": p_stone_shard, "manor": p_manor, "iron_gate": p_iron_gate, "carriage": p_carriage, "hatch": p_hatch,
    "horn_post": p_horn_post, "writing_desk": p_writing_desk, "cauldron": p_cauldron, "herb_rack": p_herb_rack,
    "jar_shelf": p_jar_shelf, "loom": p_loom, "spinning_wheel": p_spinning_wheel, "grain_sacks": p_grain_sacks,
    "tool_rack": p_tool_rack, "pelt_rug": p_pelt_rug, "antler_mount": p_antler_mount, "stool": p_stool,
    "firewood": p_firewood, "dresser": p_dresser, "cradle": p_cradle, "pots_rack": p_pots_rack, "yarn_basket": p_yarn_basket,
    "menhir": p_menhir, "lever": p_lever, "answer_tablet": p_answer_tablet,
}
