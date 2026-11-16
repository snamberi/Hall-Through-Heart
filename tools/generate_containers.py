#!/usr/bin/env python3
"""Draws the insides of containers for the screens that open them, so a
screen looks like what was opened: the bag is stitched leather with
pockets, a crafting table's screen is its planked top with carved wells,
a chest is dark boards held by iron, a furnace is soot-stained brick.

Each is a nine-slice frame (skin_<kind>.png, 48x48 art pixels) whose
middle and edges tile with a period of 32, plus its slots
(skin_<kind>_slot[_hover|_active].png, 16x16). Like the rest of the
interface they are drawn pixel by pixel at art size and each art pixel is
saved as 2x2 screen pixels (generate_ui.save).

Run from the project folder:  python3 tools/generate_containers.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
import generate_ui as U  # noqa: E402

C = U.C
W = 48          # panel size in art pixels
M = 8           # its nine-slice margin
P = 32          # the period every pattern repeats with (the middle's size)
S = 16          # slot size


def mixc(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def periodic_noise(seed, period=P):
    r = random.Random(seed)
    return [[r.random() for _ in range(period)] for _ in range(period)]


def wrap(x, y):
    """Pattern coordinates: aligned with the middle so the tiles meet."""
    return (x - M) % P, (y - M) % P


# ----------------------------------------------------------------- leather

LEATHER = {"deep": C("24160e"), "dark": C("3a2418"), "mid": C("553522"), "light": C("6a4630"), "hi": C("86603e")}
THREAD = {"dim": C("8a6234"), "lit": C("c89a52"), "gold": C("f2c14e")}


def leather_base(img, x, y, noise, crease):
    u, v = wrap(x, y)
    n = noise[v][u]
    c = LEATHER["mid"] if n > 0.07 else LEATHER["dark"]
    if n > 0.975:
        c = LEATHER["light"]
    if crease[v][u] < 0.025:
        c = LEATHER["dark"]
    return c


def pack_panel():
    img = Image.new("RGBA", (W, W))
    noise = periodic_noise(11)
    crease = periodic_noise(12)
    for y in range(W):
        for x in range(W):
            img.putpixel((x, y), leather_base(img, x, y, noise, crease))
    # The bag's mouth: a rolled lip lit on the top and left, then a seam
    # of bronze thread, then the shadow falling into the bag.
    for y in range(W):
        for x in range(W):
            d = min(x, y, W - 1 - x, W - 1 - y)
            lit = (x == d or y == d) and not (x == W - 1 - d or y == W - 1 - d)
            if d == 0:
                img.putpixel((x, y), U.BRONZE["out"])
            elif d == 1:
                img.putpixel((x, y), LEATHER["hi"] if lit else LEATHER["dark"])
            elif d == 2:
                img.putpixel((x, y), LEATHER["light"] if lit else LEATHER["mid"])
            elif d == 3:
                img.putpixel((x, y), LEATHER["deep"])
            elif d == 5:
                # Stitches: two on, two off, along the seam.
                along = x if y in (5, W - 6) else y
                if (along - M) % 4 < 2:
                    img.putpixel((x, y), THREAD["lit"] if lit else THREAD["dim"])
            elif d in (6, 7):
                img.putpixel((x, y), mixc(img.getpixel((x, y)), LEATHER["deep"], 0.45 if d == 6 else 0.25))
    # Brass rivets where the seams meet.
    for cx, cy in ((2, 2), (W - 4, 2), (2, W - 4), (W - 4, W - 4)):
        U.rivet(img, cx, cy, U.BRONZE)
    U.save(img, "skin_pack")


def pack_slot(name, thread):
    """A pocket sewn into the bag: a deeper well of leather, its stitched
    edge catching the light along the bottom and right."""
    img = Image.new("RGBA", (S, S))
    noise = periodic_noise(21, S)
    for y in range(S):
        for x in range(S):
            d = min(x, y, S - 1 - x, S - 1 - y)
            far = x == S - 1 - d or y == S - 1 - d
            n = noise[y][x]
            c = LEATHER["dark"] if n > 0.12 else LEATHER["deep"]
            if d == 0:
                c = U.BRONZE["out"]
            elif d == 1:
                c = LEATHER["light"] if far else LEATHER["deep"]
            elif d == 2 and not far:
                c = mixc(c, LEATHER["deep"], 0.6)
            elif d == 2 and (x + y) % 3 == 0:
                c = thread
            img.putpixel((x, y), c)
    U.save(img, name)


# ------------------------------------------------------------- table top

# An oiled, dark table top: light enough to read as wood, dark enough that
# the recipe text on it stays clear.
WOOD = {"deep": C("170e08"), "dark": C("2a1b10"), "mid": C("36241a"), "light": C("44301f"), "hi": C("5a4028")}
BEAM = {"deep": C("1e140c"), "dark": C("3a2616"), "mid": C("553820"), "light": C("70502e"), "hi": C("8e6a40")}


def plank(x, y, grain, joints, palette, vertical=False):
    """Boards eight pixels wide with streaky grain and staggered joints."""
    u, v = wrap(x, y)
    if vertical:
        u, v = v, u
    board = v // 8
    row = v % 8
    if row == 0:
        return palette["deep"]
    if row == 1:
        return palette["light"]
    if u == joints[board]:
        return palette["deep"]
    if u == (joints[board] + 1) % P:
        return palette["light"]
    g = grain[v][u]
    if g < 0.1:
        return palette["dark"]
    if g > 0.94:
        return palette["hi"]
    return palette["mid"]


def streaks(seed):
    """Grain that runs along a board: long dark lines and the odd knot."""
    r = random.Random(seed)
    grain = [[0.5] * P for _ in range(P)]
    for v in range(P):
        if v % 8 in (0, 1):
            continue
        u = r.randrange(P)
        for _ in range(r.randint(1, 2)):
            length = r.randint(6, 14)
            for i in range(length):
                grain[v][(u + i) % P] = 0.05
            u = (u + length + r.randint(4, 9)) % P
    for _ in range(2):
        u, v = r.randrange(P), r.randrange(P)
        if v % 8 not in (0, 1, 7):
            grain[v][u] = 0.05
            grain[v][(u + 1) % P] = 0.97
    return grain


def table_panel():
    img = Image.new("RGBA", (W, W))
    grain = streaks(31)
    joints = [5, 21, 13, 29]
    for y in range(W):
        for x in range(W):
            img.putpixel((x, y), plank(x, y, grain, joints, WOOD))
    # A heavy beam frame round the top, with iron nails at the joints.
    for y in range(W):
        for x in range(W):
            d = min(x, y, W - 1 - x, W - 1 - y)
            if d > 5:
                continue
            lit = (x == d or y == d) and not (x == W - 1 - d or y == W - 1 - d)
            side = x < 6 or x > W - 7
            u, v = wrap(x, y)
            if d == 0:
                c = U.BRONZE["out"]
            elif d == 1:
                c = BEAM["hi"] if lit else BEAM["dark"]
            elif d == 5:
                c = BEAM["deep"]
            else:
                g = grain[u][v] if side else grain[v][u]
                c = BEAM["light"] if lit and d == 2 else (BEAM["dark"] if g < 0.15 else BEAM["mid"])
            img.putpixel((x, y), c)
    for k in (M, M + 8, M + 16, M + 24):
        for x, y in ((k, 3), (k, W - 4), (3, k), (W - 4, k)):
            img.putpixel((x, y), U.IRON["light"])
            img.putpixel((x + 1, y), U.IRON["dark"])
    for cx, cy in ((1, 1), (W - 5, 1), (1, W - 5), (W - 5, W - 5)):
        for y in range(4):
            for x in range(4):
                edge = x in (0, 3) or y in (0, 3)
                img.putpixel((cx + x, cy + y), U.IRON["out"] if edge else (U.IRON["light"] if x + y < 3 else U.IRON["mid"]))
    U.save(img, "skin_table")


def table_slot(name, rim):
    """A well cut into the table top: shadowed along the top and left,
    the cut edge lit along the bottom and right."""
    img = Image.new("RGBA", (S, S))
    for y in range(S):
        for x in range(S):
            d = min(x, y, S - 1 - x, S - 1 - y)
            far = x == S - 1 - d or y == S - 1 - d
            c = WOOD["deep"] if (x * 3 + y) % 7 else WOOD["dark"]
            if d == 0:
                c = rim
            elif d == 1:
                c = WOOD["hi"] if far else C("140c08")
            elif d == 2 and not far:
                c = C("1c120a")
            img.putpixel((x, y), c)
    U.save(img, name)


# ----------------------------------------------------------------- chest

CHEST = {"deep": C("1a1210"), "dark": C("2e2018"), "mid": C("44301f"), "light": C("5a4028"), "hi": C("745434")}


def chest_panel():
    img = Image.new("RGBA", (W, W))
    grain = streaks(41)
    joints = [9, 25, 3, 17]
    for y in range(W):
        for x in range(W):
            img.putpixel((x, y), plank(x, y, grain, joints, CHEST, vertical=True))
    # Iron bands round the inside of the lid, riveted, and a dark gap
    # where the boards meet the band.
    for y in range(W):
        for x in range(W):
            d = min(x, y, W - 1 - x, W - 1 - y)
            lit = (x == d or y == d) and not (x == W - 1 - d or y == W - 1 - d)
            if d == 0:
                img.putpixel((x, y), U.IRON["out"])
            elif d in (1, 2, 3):
                img.putpixel((x, y), U.IRON["hi"] if lit and d == 1 else (U.IRON["light"] if lit else U.IRON["mid"]) if d < 3 else U.IRON["dark"])
            elif d == 4:
                img.putpixel((x, y), CHEST["deep"])
    for k in (M + 3, M + 11, M + 19, M + 27):
        for x, y in ((k, 2), (k, W - 3), (2, k), (W - 3, k)):
            img.putpixel((x, y), U.IRON["hi"])
    for cx, cy in ((0, 0), (W - 7, 0), (0, W - 7), (W - 7, W - 7)):
        for y in range(7):
            for x in range(7):
                if (x < 7 - y if cx == 0 and cy == 0 else True) and (x in (0, 6) or y in (0, 6)):
                    img.putpixel((cx + x, cy + y), U.IRON["out"])
                elif x < 7 and y < 7 and min(x, y, 6 - x, 6 - y) >= 1:
                    img.putpixel((cx + x, cy + y), U.BRONZE["light"] if x + y < 5 else U.BRONZE["mid"])
        U.rivet(img, cx + 2, cy + 2, U.BRONZE)
    U.save(img, "skin_chest")


def chest_slot(name, rim):
    img = Image.new("RGBA", (S, S))
    for y in range(S):
        for x in range(S):
            d = min(x, y, S - 1 - x, S - 1 - y)
            far = x == S - 1 - d or y == S - 1 - d
            c = CHEST["dark"] if x % 5 else CHEST["deep"]
            if d == 0:
                c = rim
            elif d == 1:
                c = CHEST["hi"] if far else C("0e0a08")
            elif d == 2 and not far:
                c = C("140e0a")
            img.putpixel((x, y), c)
    U.save(img, name)


# --------------------------------------------------------------- furnace

BRICK = {"mortar": C("141012"), "dark": C("2e2628"), "mid": C("3e3436"), "light": C("54484a"), "soot": C("1c1718"), "hot": C("c8642a")}


def stone_panel():
    img = Image.new("RGBA", (W, W))
    noise = periodic_noise(51)
    for y in range(W):
        for x in range(W):
            u, v = wrap(x, y)
            row = v // 4
            off = 4 if row % 2 else 0
            if v % 4 == 0 or (u + off) % 8 == 0:
                c = BRICK["mortar"]
            elif v % 4 == 1 or (u + off) % 8 == 1:
                c = BRICK["light"]
            else:
                c = BRICK["mid"] if noise[v][u] > 0.2 else BRICK["dark"]
            img.putpixel((x, y), c)
    # Soot darkening toward the top, as over a fire, and a thick stone rim.
    for y in range(W):
        for x in range(W):
            d = min(x, y, W - 1 - x, W - 1 - y)
            lit = (x == d or y == d) and not (x == W - 1 - d or y == W - 1 - d)
            if d == 0:
                img.putpixel((x, y), C("0a0808"))
            elif d < 4:
                img.putpixel((x, y), BRICK["light"] if lit and d == 1 else (BRICK["mid"] if lit else BRICK["dark"]))
            elif d == 4:
                img.putpixel((x, y), BRICK["soot"])
            elif y < 8 and d < 7:
                img.putpixel((x, y), mixc(img.getpixel((x, y)), BRICK["soot"], 0.5))
    U.save(img, "skin_stone")


def stone_slot(name, rim, glow):
    img = Image.new("RGBA", (S, S))
    for y in range(S):
        for x in range(S):
            d = min(x, y, S - 1 - x, S - 1 - y)
            far = x == S - 1 - d or y == S - 1 - d
            c = C("161214")
            if d == 0:
                c = rim
            elif d == 1:
                c = BRICK["light"] if far else C("0c0a0a")
            elif d == 2 and far and glow:
                c = glow
            img.putpixel((x, y), c)
    U.save(img, name)


def main():
    pack_panel()
    pack_slot("skin_pack_slot", THREAD["dim"])
    pack_slot("skin_pack_slot_hover", THREAD["lit"])
    pack_slot("skin_pack_slot_active", THREAD["gold"])
    table_panel()
    table_slot("skin_table_slot", BEAM["deep"])
    table_slot("skin_table_slot_hover", U.BRONZE["light"])
    table_slot("skin_table_slot_active", U.GOLD["light"])
    chest_panel()
    chest_slot("skin_chest_slot", U.IRON["out"])
    chest_slot("skin_chest_slot_hover", U.IRON["hi"])
    chest_slot("skin_chest_slot_active", U.GOLD["light"])
    stone_panel()
    stone_slot("skin_stone_slot", C("0a0808"), None)
    stone_slot("skin_stone_slot_hover", BRICK["light"], BRICK["hot"])
    stone_slot("skin_stone_slot_active", U.GOLD["light"], C("ffb040"))
    print("container skins written")


if __name__ == "__main__":
    main()
