#!/usr/bin/env python3
"""Draws every item's own 32x32 icon into assets/icons/items32.png and writes
scripts/items/item_icons.gd (item id -> its place in the sheet).

Every item has its own picture: a builder for its kind of thing (a sword, a
helmet, a fish, a pie...) given that item's own shape, materials and
details, all drawn straight onto the 32x32 grid with icon_kit.

Run from the project folder:  python3 tools/generate_item_icons.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from icon_kit import (Icon, ramp, hex_rgb, mix, blade, grip, guard, pommel, gem_dot, across, MID, SIZE)  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
COLUMNS = 16

# --- materials
STEEL, IRON, DARK_IRON = "c4ccd8", "8e96a4", "5a5e6c"
BRONZE, COPPER, GOLD, SILVER = "c8904a", "d07a4a", "e8bc4a", "e0e6ee"
MITHRIL, ADAMANT, OBSIDIAN = "8ae0e8", "d8605a", "4a3a5e"
WOOD, DARK_WOOD, PALE_WOOD = "9a6a40", "5e3e26", "d8c8a0"
LEATHER, DARK_LEATHER = "8e5e3a", "5a3a26"
HEART, HEART_DARK, VOID, FROST, EMBER = "d83a4c", "6e1a2a", "7a52c0", "9ad8f0", "f08a3a"
BONE, CLOTH_RED, CLOTH_BLUE, NAVY = "ece0c4", "b8404a", "4a6ab0", "2e3a5a"
TIER_METAL = {"worn": "8a8a92", "bronze": BRONZE, "iron": IRON, "mithril": MITHRIL, "adamantite": ADAMANT}


def c(value):
    return hex_rgb(value) if isinstance(value, str) else value


# ======================================================================
# Weapons and tools, on the diagonal (see icon_kit)
# ======================================================================

def sword_icon(steel=STEEL, hilt=GOLD, wrap=DARK_LEATHER, gem=None, tip_k=25, half=2.2, start=-9, guard_len=6, curl=2,
               grip_from=-21, curve=0.0, tip=6, extra=None, fuller=True):
    icon = Icon()
    tones = ramp(steel)
    blade(icon, tones, start, tip_k, half, tip=tip, curve=curve, fuller=(start + 2, tip_k - 9, tones[3]) if fuller else None)
    guard(icon, ramp(hilt), start - 2, guard_len, 1, curl=curl)
    grip(icon, ramp(wrap), grip_from, start - 4, 1, wrap=ramp(wrap)[3])
    pommel(icon, ramp(hilt), grip_from - 2, 1.9)
    if gem:
        gem_dot(icon, start - 2, c(gem), 1)
    if extra:
        extra(icon)
    return icon


def blade_pixels(icon, k0, k1, side=-1):
    """Pixels of the upper-left (side -1) or lower-right (+1) edge of a blade."""
    out = []
    for (x, y) in icon.colour:
        k, d = x - y, x + y - MID
        if k0 <= k <= k1 and ((side < 0 and (x - 1, y) not in icon.colour) or (side > 0 and (x + 1, y) not in icon.colour)):
            out.append((x, y))
    return out


def flames_along(colours, k0, k1, seed):
    def draw(icon):
        r = random.Random(seed)
        for k in range(k0, k1, 3):
            height = r.randint(2, 4)
            for h in range(height):
                d = -3 - h
                x = (k + d + MID) // 2
                y = x - k
                if (x + y - MID) == d:
                    icon.put(x, y, colours[min(h, len(colours) - 1)], part=False)
                    icon.no_outline.add((x, y))
    return draw


def frost_along(k0, k1, seed):
    def draw(icon):
        r = random.Random(seed)
        for k in range(k0, k1, 4):
            for (dx, dy) in ((0, 0), (1, -1), (-1, 1)):
                x = (k - 3 + MID) // 2 + dx
                y = x - k + dy
                icon.put(x, y, (232, 248, 255), part=False)
                icon.no_outline.add((x, y))
    return draw


def line_along(k0, k1, colour, d=0, zigzag=0):
    def draw(icon):
        for k in range(k0, k1 + 1):
            dd = d + (zigzag if (k // 3) % 2 else -zigzag)
            if (k + dd + MID) % 2:
                continue
            x = (k + dd + MID) // 2
            y = x - k
            if (x, y) in icon.colour:
                icon.colour[(x, y)] = c(colour)
    return draw


def notches(k0, k1, count, colour):
    def draw(icon):
        for i in range(count):
            k = k0 + i * (k1 - k0) // max(count - 1, 1)
            for d in (0, 1, -1):
                if (k + d + MID) % 2 == 0:
                    x = (k + d + MID) // 2
                    y = x - k
                    if (x, y) in icon.colour:
                        icon.colour[(x, y)] = c(colour)
    return draw


def chain(*draws):
    def draw(icon):
        for d in draws:
            if d:
                d(icon)
    return draw


def shaft(icon, k0, k1, wood=WOOD, half=1):
    pixels = icon.km(lambda k, d: k0 <= k <= k1 and abs(d) <= half, ramp(wood))
    across(icon, pixels, ramp(wood))
    return pixels


def axe_head(icon, tones, kc=16, reach=15, span=10, neck=3, beard=3, side=-1, edge=None):
    """A bearded axe head on one side of the haft: narrow where it grips the
    haft, flaring out to a long curved edge that drops a little (the beard)."""
    def test(k, d):
        s = -d * side
        if s < 1:
            return False
        t = min(s / reach, 1.0)
        centre = kc - beard * t
        half = neck + (span - neck) * t ** 1.6
        bulge = 1.6 * max(0.0, 1 - ((k - centre) / max(half, 1)) ** 2)
        return s <= reach + bulge and abs(k - centre) <= half
    pixels = icon.km(test, tones)
    # Shaded by distance from the haft: dark at the eye, the flat of the
    # blade in the middle tone, a bright bevel, and the ground edge.
    for (x, y) in pixels:
        k, d = x - y, x + y - MID
        s = -d * side
        outer = (x - side, y - side) not in pixels or ((x - side, y) not in pixels and (x, y - side) not in pixels)
        if outer:
            icon.colour[(x, y)] = c(edge) if edge else tones[0]
        elif (x - 2 * side, y - 2 * side) not in pixels:
            icon.colour[(x, y)] = tones[1]
        elif s < reach * 0.3:
            icon.colour[(x, y)] = tones[3]
        elif (x - 1, y) not in pixels or (x, y - 1) not in pixels:
            icon.colour[(x, y)] = tones[1]
        elif (x + 1, y) not in pixels or (x, y + 1) not in pixels:
            icon.colour[(x, y)] = tones[4]
        else:
            icon.colour[(x, y)] = tones[2]
    return pixels


def axe_icon(head=STEEL, haft=WOOD, double=False, spikes=False, edge=None, band=DARK_IRON):
    icon = Icon()
    shaft(icon, -25, 22, haft, 1)
    tones = ramp(head)
    axe_head(icon, tones, 15, 15, 10, 3, 3, -1, edge)
    if double:
        axe_head(icon, tones, 15, 12, 8, 3, 2, 1, edge)
    icon.km(lambda k, d: 11 <= k <= 19 and abs(d) <= 1, ramp(band))
    icon.km(lambda k, d: 20 <= k <= 23 and abs(d) <= 1.6, ramp(head))
    if spikes:
        icon.km(lambda k, d: 12 <= k <= 18 and 1 <= d <= 7 - abs(k - 15) * 1.6, ramp(spikes))
    grip(icon, ramp(LEATHER), -25, -16, 1, wrap=ramp(DARK_LEATHER)[2])
    return icon


def hatchet_icon(tier):
    metal = TIER_METAL[tier]
    icon = Icon()
    shaft(icon, -23, 19, WOOD if tier != "adamantite" else DARK_WOOD, 1)
    pixels = axe_head(icon, ramp(metal), 14, 11, 7, 2.5, 2, -1, None)
    icon.km(lambda k, d: 11 <= k <= 17 and 1 <= d <= 2, ramp(metal))
    if tier == "worn":
        icon.scatter(pixels, (120, 80, 60), 0.18, 3)
    if tier in ("mithril", "adamantite"):
        gem_dot(icon, 14, (255, 255, 255) if tier == "mithril" else (255, 200, 120), 0)
    if tier == "bronze":
        icon.km(lambda k, d: 13 <= k <= 15 and -9 <= d <= -2, ramp("a87038"))
    grip(icon, ramp(LEATHER if tier != "worn" else "6a5a4a"), -23, -15, 1, wrap=ramp(DARK_LEATHER)[2])
    return icon


def pickaxe_icon(tier):
    metal = TIER_METAL[tier]
    icon = Icon()
    shaft(icon, -22, 18, WOOD if tier != "adamantite" else DARK_WOOD, 1)

    def head(k, d):
        if abs(d) > 11:
            return False
        bend = (d / 11.0) ** 2 * 6.0
        thick = 1.6 - abs(d) / 11.0
        return abs(k - (16 - bend)) <= thick
    pixels = icon.km(head, ramp(metal))
    if tier == "worn":
        icon.scatter(pixels, (120, 80, 60), 0.18, 4)
    icon.km(lambda k, d: 14 <= k <= 18 and abs(d) <= 2, ramp(DARK_IRON if tier != "mithril" else "4a8a9a"))
    grip(icon, ramp(LEATHER), -22, -14, 1, wrap=ramp(DARK_LEATHER)[2])
    return icon


def spear_icon(head=STEEL, haft=WOOD, barbs=False, sun=False, tassel=None):
    icon = Icon()
    shaft(icon, -26, 12, haft, 1)

    def leaf(k, d):
        if not 10 <= k <= 27:
            return False
        t = (k - 10) / 17.0
        width = 3.2 * math.sin(math.pi * min(t * 1.25, 1.0)) if t < 0.8 else 3.2 * math.sin(math.pi * 0.8 * 1.25) * (1 - t) / 0.2
        return abs(d) <= max(width, 0.4)
    pixels = icon.km(leaf, ramp(head))
    across(icon, pixels, ramp(head))
    if barbs:
        for d in (-4, -5, 4, 5):
            k = 12
            if (k + d + MID) % 2 == 0:
                icon.put((k + d + MID) // 2, (k + d + MID) // 2 - k, ramp(head)[3])
    if sun:
        icon.km(lambda k, d: (k - 9) ** 2 + d * d <= 9, ramp(GOLD))
        gem_dot(icon, 9, (255, 240, 180), 0)
    if tassel:
        icon.km(lambda k, d: 6 <= k <= 9 and 1 <= d <= 4, ramp(tassel))
    return icon


def halberd_icon():
    icon = Icon()
    shaft(icon, -26, 22, DARK_WOOD, 1)

    def axe(k, d):
        if not 8 <= k <= 18:
            return False
        reach = 4 + 5 * (1 - ((k - 13) / 5.5) ** 2) ** 0.8
        return -reach <= d <= -1
    icon.km(axe, ramp(STEEL))
    icon.km(lambda k, d: 10 <= k <= 15 and 1 <= d <= 3 - (k - 10) * 0.4, ramp(STEEL))
    p = icon.km(lambda k, d: 18 <= k <= 28 and abs(d) <= 1.6 * (28 - k) / 10.0 + 0.1, ramp(STEEL))
    across(icon, p, ramp(STEEL))
    icon.km(lambda k, d: 12 <= k <= 16 and abs(d) <= 1, ramp(GOLD))
    return icon


def club_icon():
    icon = Icon()

    def body(k, d):
        if not -24 <= k <= 22:
            return False
        width = 1.0 + 3.2 * max(0.0, (k + 8) / 30.0)
        if k > 18:
            width *= (22 - k) / 4.0 + 0.3
        return abs(d) <= width
    pixels = icon.km(body, ramp("8a5a34"))
    across(icon, pixels, ramp("8a5a34"))
    for k, d in ((6, -2), (12, 2), (16, -3), (9, 3), (18, 1)):
        if (k + d + MID) % 2 == 0:
            x = (k + d + MID) // 2
            icon.put(x, x - k, (200, 204, 214))
    grip(icon, ramp(LEATHER), -24, -16, 1, wrap=ramp(DARK_LEATHER)[2])
    return icon


def staff_icon(wood=WOOD, orb=MITHRIL, cage=None, flame=None, rings=None):
    icon = Icon()
    shaft(icon, -27, 14, wood, 1)
    if cage:
        icon.km(lambda k, d: 13 <= k <= 15 and abs(d) <= 4, ramp(cage))
        icon.km(lambda k, d: 15 <= k <= 26 and abs(abs(d) - 4) <= 0.6, ramp(cage))
    icon.km(lambda k, d: (k - 20) ** 2 * 0.6 + d * d * 0.6 <= 11, ramp(orb))
    gem_dot(icon, 18, (255, 255, 255), 0)
    if flame:
        for k, d, col in ((25, -1, flame[0]), (26, 0, flame[1]), (27, -1, flame[1]), (24, 1, flame[0]), (27, 1, flame[2])):
            if (k + d + MID) % 2 == 0:
                x = (k + d + MID) // 2
                icon.put(x, x - k, c(col), part=False)
    if rings:
        icon.km(lambda k, d: abs(k - 20) <= 0.5 and 4 <= abs(d) <= 6, ramp(rings))
    return icon


def bow_icon(limb=WOOD, string="e8e0d0", grip_c=LEATHER, double=False, tips=None):
    icon = Icon()
    span = 22

    def limb_test(offset):
        def test(k, d):
            if abs(k) > span:
                return False
            curve = -7.0 * (1 - (k / span) ** 2) + offset
            return abs(d - curve) <= 1.0 + 0.6 * (1 - abs(k) / span)
        return test
    p = icon.km(limb_test(0), ramp(limb))
    across(icon, p, ramp(limb), lambda k: -7.0 * (1 - (k / span) ** 2))
    if double:
        icon.km(limb_test(-3), ramp(limb))
    for k in range(-span + 1, span):
        d = 1 if k % 2 == 0 else 0
        if (k + d + MID) % 2 == 0:
            x = (k + d + MID) // 2
            if (x, x - k) not in icon.colour:
                icon.put(x, x - k, c(string))
    icon.km(lambda k, d: abs(k) <= 2 and abs(d + 7) <= 1.6, ramp(grip_c))
    if tips:
        for k in (-span, span):
            icon.km(lambda kk, d, k=k: abs(kk - k) <= 1 and abs(d - 0) <= 1.5, ramp(tips))
    return icon


def fishing_rod_icon():
    icon = Icon()
    p = icon.km(lambda k, d: -24 <= k <= 26 and abs(d) <= (1.0 if k < 0 else 0.5), ramp("b88a4a"))
    across(icon, p, ramp("b88a4a"))
    grip(icon, ramp("3a5a8a"), -24, -14, 1, wrap=ramp("3a5a8a")[0])
    icon.ellipse((7, 18, 12, 23), ramp(SILVER))
    for y in range(4, 22):
        icon.put(28, y, (230, 230, 220), part=False)
    icon.put(27, 22, (200, 200, 210))
    icon.put(27, 23, (200, 200, 210))
    icon.put(28, 23, (200, 200, 210))
    return icon


# ======================================================================
# Armour, jewellery and things worn, seen from the front
# ======================================================================

def helmet_icon(metal=IRON, kind="plate", trim=None, plume=None):
    icon = Icon()
    if kind == "leather":
        icon.poly([(6, 18), (7, 10), (11, 6), (21, 6), (25, 10), (26, 18), (22, 17), (10, 17)], ramp(LEATHER))
        icon.rect((6, 17, 26, 20), ramp(DARK_LEATHER))
        icon.line([(16, 7), (16, 16)], 1, ramp(DARK_LEATHER))
        return icon
    if kind == "crown":
        icon.poly([(6, 22), (6, 12), (10, 16), (13, 8), (16, 14), (19, 8), (22, 16), (26, 12), (26, 22)], ramp(GOLD))
        icon.rect((6, 20, 26, 24), ramp("c8902a"))
        for x, col in ((10, "e04848"), (16, "48a0e0"), (22, "e04848")):
            icon.ellipse((x - 1, 20, x + 1, 23), ramp(col))
        for x in (13, 19):
            icon.put(x, 6, (255, 170, 60), part=False)
            icon.put(x, 5, (255, 230, 120), part=False)
        return icon
    icon.poly([(7, 26), (6, 12), (9, 6), (16, 4), (23, 6), (26, 12), (25, 26), (16, 28)], ramp(metal))
    icon.rect((8, 14, 24, 15), ramp(DARK_IRON if metal != HEART_DARK else "1a0a10"), flat=True)
    for x in range(10, 23, 3):
        icon.put(x, 19, ramp(metal)[4])
        icon.put(x, 20, ramp(metal)[4])
    icon.line([(16, 5), (16, 13)], 1, ramp(metal)[:1] * 5)
    if trim:
        icon.line([(7, 12), (9, 6), (16, 4), (23, 6), (25, 12)], 1, ramp(trim))
    if kind == "horned":
        icon.poly([(7, 10), (2, 4), (3, 1), (8, 7)], ramp(BONE))
        icon.poly([(25, 10), (30, 4), (29, 1), (24, 7)], ramp(BONE))
    if plume:
        icon.poly([(15, 4), (18, 0), (22, 1), (17, 5)], ramp(plume))
    return icon


def chest_icon(metal=IRON, kind="plate", trim=None):
    icon = Icon()
    if kind == "leather":
        icon.poly([(8, 6), (12, 4), (20, 4), (24, 6), (25, 27), (7, 27)], ramp(LEATHER))
        icon.poly([(12, 4), (16, 10), (20, 4)], ramp("e8d8b8"))
        for y in range(11, 26, 3):
            icon.put(15, y, (60, 40, 26))
            icon.put(17, y, (60, 40, 26))
            icon.put(16, y + 1, (230, 210, 170))
        return icon
    if kind == "fur":
        # A mantle: the cloak hanging from a thick fur collar, held by a clasp.
        icon.poly([(6, 10), (26, 10), (30, 29), (2, 29)], ramp("6a5a7a"))
        icon.line([(16, 14), (16, 28)], 1, ramp("3a3048"))
        icon.line([(10, 14), (7, 28)], 1, [ramp("6a5a7a")[3]] * 5)
        icon.line([(22, 14), (25, 28)], 1, [ramp("6a5a7a")[3]] * 5)
        hem = icon.rect((2, 27, 30, 30), ramp("e8ecf2"))
        collar = icon.ellipse((2, 3, 30, 16), ramp("eef0f6"))
        icon.ellipse((10, 5, 22, 11), ramp("4a4058"))
        icon.scatter(collar | hem, (196, 202, 218), 0.22, 9)
        icon.scatter(collar | hem, (255, 255, 255), 0.1, 10)
        icon.ellipse((13, 12, 19, 18), ramp(GOLD))
        icon.put(15, 14, (255, 250, 220))
        return icon
    icon.poly([(9, 7), (23, 7), (24, 26), (16, 29), (8, 26)], ramp(metal))
    icon.poly([(3, 7), (10, 5), (11, 13), (5, 14)], ramp(metal))
    icon.poly([(29, 7), (22, 5), (21, 13), (27, 14)], ramp(metal))
    icon.line([(16, 8), (16, 27)], 1, [ramp(metal)[3]] * 5)
    icon.line([(10, 17), (22, 17)], 1, [ramp(metal)[3]] * 5)
    if trim:
        icon.line([(9, 7), (23, 7)], 1, ramp(trim))
        icon.ellipse((14, 10, 18, 14), ramp(trim))
    return icon


def legs_icon(metal=IRON, kind="plate", trim=None):
    icon = Icon()
    base = LEATHER if kind == "leather" else metal
    icon.rect((7, 4, 25, 9), ramp(base if kind != "leather" else DARK_LEATHER))
    icon.poly([(7, 9), (15, 9), (14, 28), (8, 28)], ramp(base))
    icon.poly([(17, 9), (25, 9), (24, 28), (18, 28)], ramp(base))
    if kind != "leather":
        for y in (14, 20):
            icon.line([(8, y), (14, y)], 1, [ramp(metal)[3]] * 5)
            icon.line([(18, y), (24, y)], 1, [ramp(metal)[3]] * 5)
        icon.ellipse((9, 15, 13, 19), ramp(metal))
        icon.ellipse((19, 15, 23, 19), ramp(metal))
    if trim:
        icon.line([(7, 4), (25, 4)], 1, ramp(trim))
    return icon


def boots_icon(metal=IRON, kind="plate", trim=None, stars=False):
    icon = Icon()
    base = LEATHER if kind == "leather" else metal
    for x0 in (3, 17):
        icon.poly([(x0 + 2, 6), (x0 + 9, 6), (x0 + 9, 20), (x0 + 13, 22), (x0 + 13, 27), (x0 + 1, 27), (x0 + 2, 20)], ramp(base))
        icon.rect((x0 + 1, 25, x0 + 13, 28), ramp(DARK_LEATHER if kind == "leather" else DARK_IRON))
        if trim:
            icon.line([(x0 + 2, 7), (x0 + 9, 7)], 1, ramp(trim))
    if stars:
        icon.scatter(icon.colour.keys(), (230, 220, 255), 0.06, 5)
    return icon


def shield_icon(face=CLOTH_BLUE, metal=IRON, emblem=GOLD):
    icon = Icon()
    icon.poly([(4, 4), (28, 4), (28, 16), (16, 30), (4, 16)], ramp(metal))
    icon.poly([(7, 7), (25, 7), (25, 16), (16, 26), (7, 16)], ramp(face))
    icon.poly([(16, 9), (19, 14), (16, 22), (13, 14)], ramp(emblem))
    icon.put(16, 14, (255, 250, 220))
    return icon


def ring_icon(band=GOLD, gem="e04848", flame=False):
    icon = Icon()
    icon.ring((5, 9, 27, 29), 4, ramp(band))
    icon.ellipse((11, 2, 21, 12), ramp(gem))
    icon.put(14, 5, (255, 255, 255))
    if flame:
        for x, y, col in ((9, 6, "ffd060"), (8, 4, "f08a3a"), (23, 6, "ffd060"), (24, 4, "f08a3a")):
            icon.put(x, y, c(col), part=False)
    return icon


def necklace_icon(chain_c=GOLD, gem="48a0e0"):
    icon = Icon()
    icon.ring((4, -6, 28, 22), 2, ramp(chain_c))
    icon.poly([(16, 17), (21, 22), (16, 30), (11, 22)], ramp(gem))
    icon.put(15, 21, (255, 255, 255))
    for (x, y) in list(icon.colour):
        if y < 2:
            del icon.colour[(x, y)]
            icon.part.pop((x, y), None)
    return icon


def belt_icon(strap=LEATHER, buckle=GOLD, pouches=0, rope=False):
    icon = Icon()
    if rope:
        rope_c = "c8a870"
        icon.ring((2, 6, 30, 22), 3, ramp(rope_c))
        for a in range(0, 360, 24):
            x = round(16 + math.cos(math.radians(a)) * 13)
            y = round(14 + math.sin(math.radians(a)) * 7)
            if (x, y) in icon.colour:
                icon.colour[(x, y)] = ramp(rope_c)[3]
        icon.ellipse((12, 18, 19, 25), ramp(rope_c))
        icon.line([(14, 24), (11, 30)], 2, ramp(rope_c))
        icon.line([(17, 24), (21, 30)], 2, ramp(rope_c))
        for x, y in ((11, 30), (21, 30)):
            icon.put(x, y - 1, ramp(rope_c)[0])
        return icon
    icon.rect((1, 11, 31, 17), ramp(strap))
    for x in range(3, 30, 4):
        icon.put(x, 12, ramp(strap)[0])
    icon.rect((12, 9, 20, 19), ramp(buckle))
    icon.rect((14, 11, 18, 17), ramp(strap))
    icon.line([(16, 11), (16, 17)], 1, ramp(buckle))
    for i in range(pouches):
        x = 3 + i * 9 if pouches > 1 else 23
        if pouches > 1 and 10 <= x <= 20:
            x = 22
        icon.rect((x, 17, x + 6, 25), ramp(DARK_LEATHER))
        icon.rect((x, 17, x + 6, 19), ramp(LEATHER))
        icon.put(x + 3, 20, c(GOLD))
    return icon


def pack_icon(kind):
    icon = Icon()
    if kind == "bindle":
        icon.line([(3, 29), (26, 4)], 2, ramp(WOOD))
        icon.ellipse((15, 2, 30, 15), ramp(CLOTH_RED))
        for x, y in ((19, 6), (24, 9), (21, 11), (26, 5)):
            icon.put(x, y, (240, 230, 220))
        return icon
    body = {"satchel": LEATHER, "backpack": "6a7a4a", "explorers_pack": "4a5a7a"}[kind]
    icon.poly([(7, 9), (25, 9), (27, 29), (5, 29)], ramp(body))
    icon.poly([(6, 9), (26, 9), (24, 3), (8, 3)], ramp(DARK_LEATHER if kind != "satchel" else "6e4628"))
    icon.rect((14, 12, 18, 16), ramp(GOLD))
    if kind != "satchel":
        icon.rect((8, 18, 14, 26), ramp(mix(c(body), (0, 0, 0), 0.2)))
        icon.rect((18, 18, 24, 26), ramp(mix(c(body), (0, 0, 0), 0.2)))
    if kind == "explorers_pack":
        icon.ellipse((22, 0, 31, 8), ramp("d8c8a0"))
        icon.line([(3, 6), (3, 26)], 2, ramp(SILVER))
    return icon


# ======================================================================
# Gems, ores, ingots, wood
# ======================================================================

GEM_COLOURS = {"ruby": "e0303e", "sapphire": "3a6ae0", "emerald": "30b860", "topaz": "f0a830", "amethyst": "a050e0", "diamond": "e8f4ff", "garnet": "b02848"}


def gem_icon(kind, tier):
    """Tier 1 is a rough stone still in its rock; finer tiers are cut, bigger,
    with a bright table, more glints, and at the top a glow about them."""
    icon = Icon()
    col = GEM_COLOURS[kind]
    s = {1: 6, 2: 7, 3: 9, 4: 10, 5: 11}[tier]
    cx, cy = 16, 17 if tier > 1 else 13

    def shape(s, tones, **kw):
        if kind == "ruby":
            return icon.ellipse((cx - s, cy - s + 2, cx + s, cy + s - 2), tones, **kw)
        if kind == "sapphire":
            return icon.poly([(cx, cy - s - 1), (cx + s, cy + 1), (cx, cy + s + 1), (cx - s, cy + 1)], tones, **kw)
        if kind == "emerald":
            return icon.poly([(cx - s + 2, cy - s + 1), (cx + s - 2, cy - s + 1), (cx + s, cy - s + 3), (cx + s, cy + s - 3), (cx + s - 2, cy + s - 1),
                              (cx - s + 2, cy + s - 1), (cx - s, cy + s - 3), (cx - s, cy - s + 3)], tones, **kw)
        if kind == "topaz":
            return icon.poly([(cx - s // 2, cy - s), (cx + s // 2, cy - s), (cx + s, cy), (cx + s // 2, cy + s), (cx - s // 2, cy + s), (cx - s, cy)], tones, **kw)
        if kind == "amethyst":
            a = icon.poly([(cx - 3, cy + s), (cx - 4, cy - s + 3), (cx - 1, cy - s - 1), (cx + 1, cy - s + 3), (cx, cy + s)], tones, **kw)
            b = icon.poly([(cx, cy + s), (cx + 1, cy - s // 2), (cx + 4, cy - s // 2 - 3), (cx + 6, cy - s // 2), (cx + 4, cy + s)], tones, **kw)
            return a | b
        if kind == "diamond":
            return icon.poly([(cx - s, cy - 2), (cx - s // 2, cy - s + 1), (cx + s // 2, cy - s + 1), (cx + s, cy - 2), (cx, cy + s + 1)], tones, **kw)
        return icon.ellipse((cx - s + 1, cy - s + 1, cx + s - 1, cy + s - 1), tones, **kw)

    if tier == 1:
        rock(icon, ramp("6e6a78"), 3 + len(kind), (4, 15, 28, 29))
        body = shape(s, ramp(col))
        icon.scatter(body, ramp(col)[3], 0.25, len(kind))
        icon.put(cx - 2, cy - 2, (255, 255, 255))
        return icon
    body = shape(s, ramp(col))
    if tier >= 3 and kind != "amethyst":
        light = ramp(mix(c(col), (255, 255, 255), 0.25))
        table = shape(max(s // 2, 2), [light[1]] * 5, flat=True, rim=False)
        # Facet lines from the table to the girdle.
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            for step in range(max(s // 2, 2), s):
                p = (cx + dx * step, cy + dy * step)
                if p in body and p not in table:
                    icon.colour[p] = ramp(col)[3] if dx > 0 else ramp(col)[0]
    if kind == "diamond":
        icon.line([(cx - s, cy - 2), (cx + s, cy - 2)], 1, ramp("b8d8f0"))
    icon.dots([(cx - 2, cy - 2), (cx - 1, cy - 3), (cx - 3, cy - 1)], (255, 255, 255))
    if tier >= 4:
        icon.sparkle(cx + s - 1, cy - s + 1)
    if tier >= 5:
        icon.sparkle(cx - s + 1, cy + s - 1, (255, 240, 200))
        glow = mix(c(col), (255, 255, 255), 0.45)
        for a in range(0, 360, 30):
            x = round(cx + math.cos(math.radians(a)) * (s + 3))
            y = round(cy + math.sin(math.radians(a)) * (s + 2))
            if (x, y) not in icon.colour and 0 <= x < SIZE and 0 <= y < SIZE and a % 60 == 0:
                icon.put(x, y, glow, part=False)
                icon.no_outline.add((x, y))
    return icon


def rock(icon, tones, seed, box=(4, 8, 28, 28)):
    r = random.Random(seed)
    x0, y0, x1, y1 = box
    pts = []
    for i in range(9):
        a = math.tau * i / 9
        rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
        jitter = r.uniform(0.8, 1.05)
        pts.append((round((x0 + x1) / 2 + math.cos(a) * rx * jitter), round((y0 + y1) / 2 + math.sin(a) * ry * jitter)))
    return icon.poly(pts, tones)


def ore_icon(stone="8a8794", fleck="d07a4a", seed=1, kind="flecks", glow=None):
    icon = Icon()
    pixels = rock(icon, ramp(stone), seed)
    r = random.Random(seed * 7)
    if kind == "flecks":
        for _ in range(6):
            x, y = r.randint(8, 23), r.randint(12, 24)
            for dx, dy in ((0, 0), (1, 0), (0, 1)):
                if (x + dx, y + dy) in pixels:
                    icon.colour[(x + dx, y + dy)] = ramp(fleck)[1 if dx == 0 and dy == 0 else 2]
    elif kind == "veins":
        for _ in range(3):
            x, y = r.randint(8, 14), r.randint(12, 22)
            for step in range(8):
                if (x, y) in pixels:
                    icon.colour[(x, y)] = ramp(fleck)[1]
                x += 1
                y += r.choice((-1, 0, 1))
    elif kind == "nuggets":
        for x, y in ((10, 14), (18, 18), (13, 22), (21, 13)):
            icon.ellipse((x - 2, y - 2, x + 2, y + 2), ramp(fleck))
    elif kind == "crystals":
        for x, y, h in ((11, 20, 9), (17, 22, 12), (22, 19, 7)):
            icon.poly([(x - 2, y), (x - 2, y - h + 2), (x, y - h), (x + 2, y - h + 2), (x + 2, y)], ramp(fleck))
    if glow:
        icon.sparkle(*glow)
    return icon


def ingot_icon(metal, mark=None, shape="bar"):
    icon = Icon()
    tones = ramp(metal)
    if shape == "bar":
        icon.poly([(3, 22), (9, 13), (29, 13), (27, 22)], tones)
        icon.poly([(3, 22), (27, 22), (27, 26), (3, 26)], [tones[2], tones[3], tones[3], tones[4], tones[4]])
        icon.poly([(27, 22), (29, 13), (29, 17), (27, 26)], [tones[3]] * 4 + [tones[4]])
    else:
        icon.poly([(5, 24), (10, 11), (26, 11), (28, 24)], tones)
    icon.line([(10, 15), (24, 15)], 1, [tones[0]] * 5)
    if mark == "heart":
        for x, y in ((15, 17), (16, 18), (17, 17), (14, 16), (18, 16), (16, 19)):
            icon.put(x, y, (255, 120, 140))
    elif mark == "swirl":
        for x, y in ((14, 17), (15, 16), (17, 16), (18, 17), (17, 18), (15, 18), (16, 17)):
            icon.put(x, y, (200, 170, 255))
    elif mark == "rune":
        for x, y in ((14, 16), (15, 17), (16, 18), (17, 17), (18, 16)):
            icon.put(x, y, (255, 255, 255))
    elif mark == "crack":
        for x, y in ((12, 17), (13, 18), (14, 18), (15, 19), (20, 16), (21, 17)):
            icon.put(x, y, (255, 120, 60))
    elif mark == "stamp":
        icon.rect((14, 16, 18, 19), [tones[3]] * 5, flat=True)
    return icon


def log_icon(bark, inner, rings="7a5030", moss=None, glow=None, resin=False):
    icon = Icon()
    icon.poly([(4, 18), (20, 5), (28, 13), (12, 26)], ramp(bark))
    icon.ellipse((2, 15, 13, 27), ramp(inner))
    icon.ring((4, 17, 11, 25), 1, [c(rings)] * 5)
    icon.put(7, 21, c(rings))
    icon.line([(10, 13), (20, 7)], 1, [ramp(bark)[4]] * 5)
    icon.line([(14, 18), (25, 10)], 1, [ramp(bark)[4]] * 5)
    if moss:
        icon.scatter([p for p in icon.colour if p[1] < 12], c(moss), 0.35, 5)
    if glow:
        icon.ring((4, 17, 11, 25), 1, [c(glow)] * 5)
        icon.sparkle(24, 6, c(glow))
    if resin:
        icon.ellipse((18, 13, 21, 17), ramp("f0b040"))
    return icon


# ======================================================================
# Plants, fish, hides, monster parts and other materials
# ======================================================================

def stem(icon, points, col="4a8a3a", width=1):
    icon.line(points, width, ramp(col))


def leaf(icon, x, y, dx, dy, col="5aa040", size=4):
    icon.poly([(x, y), (x + dx * size // 2 - dy, y + dy * size // 2 + dx), (x + dx * size, y + dy * size), (x + dx * size // 2 + dy, y + dy * size // 2 - dx)], ramp(col))


def flower(icon, x, y, petal, centre="f8e070", r=3, petals=5):
    for i in range(petals):
        a = math.tau * i / petals - math.pi / 2
        px, py = x + round(math.cos(a) * r), y + round(math.sin(a) * r)
        icon.ellipse((px - 2, py - 2, px + 2, py + 2), ramp(petal))
    icon.ellipse((x - 1, y - 1, x + 1, y + 1), ramp(centre))


def mushroom(icon, cap, stalk="e8dcc0", spots=None, x=16, w=11, h=8, y=16, glow=False):
    icon.rect((x - 2, y, x + 2, y + 10), ramp(stalk))
    icon.poly([(x - w, y + 2), (x - w + 2, y - h + 3), (x - 3, y - h), (x + 3, y - h), (x + w - 2, y - h + 3), (x + w, y + 2)], ramp(cap))
    if spots:
        for sx, sy in ((x - 5, y - 2), (x + 2, y - 5), (x + 5, y - 1), (x - 1, y - 1)):
            icon.ellipse((sx - 1, sy - 1, sx + 1, sy + 1), ramp(spots))
    if glow:
        icon.sparkle(x + w - 3, y - h + 1, c(glow))


def plant_icon(kind):
    icon = Icon()
    if kind == "healing_herb":
        stem(icon, [(16, 29), (16, 8)])
        for y, side in ((24, -1), (20, 1), (16, -1), (12, 1)):
            leaf(icon, 16, y, side, -1, "5ab04a", 6)
        flower(icon, 16, 7, "f4f4f0", "f8e070", 2)
    elif kind == "mana_flower":
        stem(icon, [(16, 29), (15, 14)])
        leaf(icon, 16, 24, -1, -1, "4a9a5a", 6)
        leaf(icon, 16, 21, 1, -1, "4a9a5a", 6)
        flower(icon, 15, 11, "5a8af0", "e0f0ff", 4, 6)
        icon.sparkle(24, 5, (180, 210, 255))
    elif kind == "frost_lily":
        stem(icon, [(16, 29), (16, 16)], "6aa0a0")
        icon.poly([(16, 6), (21, 14), (16, 18), (11, 14)], ramp("e8f6ff"))
        icon.poly([(9, 9), (15, 15), (11, 17), (6, 12)], ramp("c8e8ff"))
        icon.poly([(23, 9), (17, 15), (21, 17), (26, 12)], ramp("c8e8ff"))
        icon.put(16, 13, (120, 190, 255))
    elif kind == "bloodcap":
        mushroom(icon, "c8283a", spots="f4e8e0")
    elif kind == "poison_mushroom":
        mushroom(icon, "8a4ab0", spots="b8f060", w=9, h=10)
    elif kind == "spore_cap":
        mushroom(icon, "a0905a", spots="d8d080", w=12, h=6, y=18)
        icon.scatter({(x, y) for x in range(4, 28) for y in range(2, 9)}, (220, 220, 140), 0.0, 1)
        for x, y in ((8, 6), (14, 3), (22, 5), (26, 9)):
            icon.put(x, y, (220, 210, 130), part=False)
    elif kind == "glowshroom":
        mushroom(icon, "30c0b0", stalk="c8f0e8", w=8, h=7, x=12, y=18, glow="b0fff0")
        mushroom(icon, "40d0c0", stalk="c8f0e8", w=6, h=5, x=22, y=20)
    elif kind == "desert_aloe":
        for pts in ([(16, 28), (8, 8), (14, 26)], [(16, 28), (24, 6), (19, 27)], [(16, 28), (16, 4), (18, 28)], [(16, 28), (4, 16), (12, 27)], [(16, 28), (28, 14), (21, 28)]):
            icon.poly(pts, ramp("7ab86a"))
        icon.rect((10, 26, 22, 30), ramp("c8a060"))
    elif kind == "emberbloom":
        stem(icon, [(16, 29), (16, 14)], "6a7a3a")
        for i, col in enumerate(("f05a2a", "f08a3a", "ffc050")):
            icon.poly([(16 - 7 + i * 2, 16 - i), (16, 4 + i * 3), (16 + 7 - i * 2, 16 - i), (16, 19 - i)], ramp(col))
        icon.put(16, 10, (255, 250, 200))
    elif kind == "void_bloom":
        stem(icon, [(16, 29), (16, 15)], "4a3a6a")
        for i in range(4):
            a = math.tau * i / 4 + math.pi / 4
            icon.poly([(16, 12), (16 + round(math.cos(a - 0.3) * 6), 12 + round(math.sin(a - 0.3) * 6)), (16 + round(math.cos(a) * 10), 12 + round(math.sin(a) * 10)),
                       (16 + round(math.cos(a + 0.3) * 6), 12 + round(math.sin(a + 0.3) * 6))], ramp("7a4ac8"))
        icon.ellipse((14, 10, 18, 14), ramp("f0d8ff"))
        icon.sparkle(25, 4, (220, 190, 255))
    elif kind == "saltweed":
        for x, h in ((10, 18), (15, 24), (20, 20), (24, 14)):
            icon.line([(x, 29), (x - 2, 29 - h // 2), (x + 1, 29 - h)], 2, ramp("6a9a7a"))
            icon.put(x + 1, 29 - h, (245, 245, 240))
            icon.put(x, 30 - h, (245, 245, 240))
    elif kind == "rare_root":
        icon.line([(16, 4), (14, 12), (18, 18), (13, 24), (16, 30)], 4, ramp("8a6a4a"))
        icon.line([(14, 12), (7, 16)], 2, ramp("8a6a4a"))
        icon.line([(18, 18), (26, 21)], 2, ramp("8a6a4a"))
        leaf(icon, 16, 4, -1, -1, "5aa040", 5)
        leaf(icon, 16, 4, 1, -1, "5aa040", 5)
    elif kind == "sunroot":
        icon.poly([(10, 10), (22, 10), (20, 22), (16, 30), (12, 22)], ramp("f0c040"))
        for y in (14, 18, 22):
            icon.line([(12, y), (20, y)], 1, [ramp("f0c040")[3]] * 5)
        leaf(icon, 16, 10, -1, -1, "6ab040", 6)
        leaf(icon, 16, 10, 1, -1, "6ab040", 6)
        icon.sparkle(25, 6, (255, 240, 160))
    elif kind == "wheat":
        for x, lean in ((11, -2), (16, 0), (21, 2)):
            icon.line([(x, 30), (x + lean, 10)], 1, ramp("c8a848"))
            for i in range(5):
                y = 4 + i * 3
                icon.ellipse((x + lean - 2, y, x + lean, y + 2), ramp("f0d070"))
                icon.ellipse((x + lean, y + 1, x + lean + 2, y + 3), ramp("e8c060"))
        icon.rect((9, 22, 23, 24), ramp("a0703a"))
    elif kind == "potato":
        icon.ellipse((5, 9, 27, 26), ramp("c8a070"))
        for x, y in ((10, 14), (18, 12), (22, 20), (13, 21)):
            icon.put(x, y, (110, 80, 50))
    elif kind == "pumpkin":
        icon.ellipse((3, 9, 29, 29), ramp("f08a2a"))
        for x in (10, 16, 22):
            icon.line([(x, 11), (x, 27)], 1, [ramp("f08a2a")[3]] * 5)
        icon.rect((14, 4, 17, 10), ramp("6a7a3a"))
        leaf(icon, 17, 6, 1, 0, "6ab040", 6)
    elif kind == "carrot":
        icon.poly([(9, 8), (23, 8), (17, 30), (15, 30)], ramp("f08a30"))
        for y in (13, 18, 23):
            icon.line([(12, y), (16, y)], 1, [ramp("f08a30")[3]] * 5)
        for x, lean in ((12, -3), (16, 0), (20, 3)):
            icon.line([(x, 8), (x + lean, 1)], 2, ramp("5ab040"))
    return icon


FISH = {
    "minnow": ("b8c8d0", None, 0.6, 6, None),
    "perch": ("a0b850", "4a6a2a", 0.85, 8, "stripes"),
    "trout": ("d8a8a0", "6a6a6a", 0.9, 8, "spots"),
    "pike": ("7a9a5a", "c8d890", 1.15, 6, "dots"),
    "salmon": ("f09070", "c85a4a", 1.0, 9, "belly"),
    "eel": ("5a6a4a", "3a4a2a", 1.25, 4, "eel"),
    "catfish": ("8a7a5a", "5a4a34", 1.0, 9, "whiskers"),
    "glowfin": ("4a8ac8", "a0f0ff", 0.9, 8, "glow"),
    "golden_carp": ("f0c040", "c88a20", 0.95, 10, "scales"),
}


def fish_icon(kind):
    body, mark, length, depth, style = FISH[kind]
    icon = Icon()
    half = round(11 * length)
    cx, cy = 15, 16
    if style == "eel":
        icon.line([(3, 22), (9, 14), (15, 18), (21, 11), (28, 13)], 4, ramp(body))
        icon.ellipse((25, 10, 30, 15), ramp(body))
        icon.put(28, 12, (20, 20, 20))
        return icon
    icon.ellipse((cx - half, cy - depth // 2 - 1, cx + half - 2, cy + depth // 2 + 1), ramp(body))
    icon.poly([(cx - half + 1, cy), (cx - half - 4, cy - depth // 2 - 2), (cx - half - 3, cy), (cx - half - 4, cy + depth // 2 + 2)], ramp(mark or body))
    icon.poly([(cx - 2, cy - depth // 2), (cx + 3, cy - depth // 2 - 4), (cx + 5, cy - depth // 2)], ramp(mark or body))
    eye = (cx + half - 6, cy - 2)
    icon.put(eye[0], eye[1], (20, 20, 30))
    icon.put(eye[0] - 1, eye[1] - 1, (240, 240, 240))
    if style == "stripes":
        for x in range(cx - 6, cx + 6, 3):
            icon.line([(x, cy - depth // 2), (x, cy + depth // 2)], 1, [c(mark)] * 5)
    elif style == "spots":
        icon.scatter({(x, y) for x in range(cx - 8, cx + 6) for y in range(cy - 3, cy + 2)}, c(mark), 0.2, 5)
    elif style == "dots":
        icon.scatter({(x, y) for x in range(cx - 10, cx + 8) for y in range(cy - 2, cy + 2)}, c(mark), 0.3, 6)
    elif style == "belly":
        icon.line([(cx - 8, cy + depth // 2 - 1), (cx + 6, cy + depth // 2 - 1)], 1, [c("f8d8c8")] * 5)
    elif style == "whiskers":
        for dy in (-1, 1, 2):
            icon.line([(eye[0] + 3, cy + dy), (eye[0] + 7, cy + dy + dy)], 1, [c(mark)] * 5)
    elif style == "glow":
        icon.sparkle(cx - half - 2, cy - depth // 2 - 2, c(mark))
        icon.line([(cx - 8, cy), (cx + 6, cy)], 1, [c(mark)] * 5)
    elif style == "scales":
        for x in range(cx - 8, cx + 6, 3):
            for y in range(cy - 2, cy + 3, 3):
                icon.put(x, y, c("fff0a0"))
    return icon


def pelt_icon(fur, pattern=None, accent=None, big=False, small=False):
    icon = Icon()
    s = 2 if big else (-2 if small else 0)
    pts = [(9 - s, 4 - s), (23 + s, 4 - s), (26 + s, 9), (30 + s, 10), (27 + s, 15), (26 + s, 25 + s), (29 + s, 28 + s), (21, 27 + s),
           (16, 30 + s), (11, 27 + s), (3 - s, 28 + s), (6 - s, 25 + s), (5 - s, 15), (2 - s, 10), (6 - s, 9)]
    p = icon.poly(pts, ramp(fur))
    if pattern == "spots":
        for x, y in ((11, 11), (19, 14), (14, 20), (21, 22), (10, 24)):
            icon.ellipse((x - 1, y - 1, x + 1, y + 1), ramp(accent))
    elif pattern == "patches":
        icon.ellipse((9, 8, 17, 16), ramp(accent))
        icon.ellipse((17, 18, 25, 26), ramp(accent))
    elif pattern == "stripe":
        icon.line([(16, 5), (16, 28)], 3, ramp(accent))
    elif pattern == "tail":
        icon.poly([(16, 26), (21, 30), (12, 31)], ramp(accent))
    elif pattern == "warts":
        icon.scatter(p, c(accent), 0.12, 7)
    elif pattern == "frost":
        icon.scatter(p, c(accent), 0.18, 8)
    icon.scatter(p, ramp(fur)[0], 0.08, 11)
    return icon


def leather_icon():
    icon = Icon()
    icon.poly([(4, 10), (26, 6), (28, 22), (6, 26)], ramp("a06a3e"))
    icon.poly([(6, 22), (26, 18), (28, 22), (6, 26)], ramp("7a4a2a"))
    for x in range(8, 26, 3):
        icon.put(x, 12 + (x % 2), (200, 150, 100))
    return icon


def wool_icon():
    icon = Icon()
    for x, y, r in ((11, 18, 8), (20, 16, 8), (15, 11, 7), (18, 22, 6)):
        icon.ellipse((x - r, y - r, x + r, y + r), ramp("f0ece4"))
    return icon


def feather_icon(colour, tip=None, bars=None, long=False):
    icon = Icon()
    end = (27, 2) if long else (25, 5)
    icon.line([(4, 29), end], 1, ramp("f0e8d8"))
    pts = [(8, 25), (12, 15), (20, 6), (end[0], end[1]), (22, 12), (14, 22)]
    icon.poly(pts, ramp(colour))
    if bars:
        for i in range(4):
            x, y = 12 + i * 3, 18 - i * 3
            icon.line([(x - 2, y), (x + 2, y + 2)], 1, [c(bars)] * 5)
    if tip:
        icon.poly([(20, 6), (end[0], end[1]), (22, 10)], ramp(tip))
    return icon


def horn_icon(colour, kind):
    icon = Icon()
    if kind == "curved":
        icon.line([(6, 27), (8, 18), (14, 10), (22, 6), (27, 7)], 5, ramp(colour))
        icon.line([(22, 6), (28, 5)], 2, ramp(colour))
    elif kind == "spiral":
        icon.line([(5, 26), (10, 14), (18, 8), (26, 10), (25, 18), (20, 17)], 4, ramp(colour))
        for x, y in ((9, 18), (13, 12), (18, 9), (23, 9)):
            icon.put(x, y, ramp(colour)[4])
    elif kind == "tusk":
        icon.line([(4, 24), (12, 18), (21, 12), (28, 4)], 4, ramp(colour))
        icon.rect((2, 22, 7, 28), ramp("8a6a4a"))
    elif kind == "antler":
        icon.line([(8, 29), (11, 18), (16, 8), (20, 2)], 3, ramp(colour))
        icon.line([(11, 18), (4, 12)], 2, ramp(colour))
        icon.line([(14, 12), (22, 10), (27, 5)], 2, ramp(colour))
        icon.line([(16, 8), (13, 2)], 2, ramp(colour))
    return icon


def bone_icon():
    icon = Icon()
    icon.line([(8, 24), (24, 8)], 4, ramp(BONE))
    for x, y in ((5, 23), (9, 27), (23, 5), (27, 9)):
        icon.ellipse((x - 3, y - 3, x + 3, y + 3), ramp(BONE))
    return icon


def claw_icon(colour="d8d0c0", count=3, base=None):
    icon = Icon()
    for i in range(count):
        x = 8 + i * 6
        icon.poly([(x, 28), (x + 4, 28), (x + 6, 14), (x + 3, 4), (x + 1, 12)], ramp(colour))
    if base:
        icon.rect((5, 24, 27, 30), ramp(base))
    return icon


def blob_icon(colour, jar=False, bubbles=True, seed=1):
    icon = Icon()
    if jar:
        icon.rect((7, 6, 25, 29), ramp("c8e0e8"))
        icon.rect((9, 12, 23, 27), ramp(colour))
        icon.rect((6, 3, 26, 7), ramp(WOOD))
    else:
        icon.poly([(4, 26), (6, 16), (11, 10), (17, 8), (24, 11), (28, 19), (27, 27), (16, 29)], ramp(colour))
    if bubbles:
        r = random.Random(seed)
        for _ in range(3):
            x, y = r.randint(10, 22), r.randint(13, 24)
            icon.put(x, y, ramp(colour)[0])
            icon.put(x + 1, y, (255, 255, 255))
    return icon


def shard_icon(colour, glow=None, count=1):
    icon = Icon()
    if count == 1:
        icon.poly([(16, 2), (24, 12), (20, 29), (11, 29), (8, 12)], ramp(colour))
        icon.line([(16, 4), (15, 26)], 1, [ramp(colour)[0]] * 5)
    else:
        for x, h in ((9, 16), (16, 24), (23, 18)):
            icon.poly([(x - 3, 29), (x - 3, 29 - h + 4), (x, 29 - h), (x + 3, 29 - h + 4), (x + 3, 29)], ramp(colour))
    if glow:
        icon.sparkle(24, 6, c(glow))
    return icon


def cloth_icon(colour, tatters=False, roll=False):
    icon = Icon()
    if roll:
        icon.ellipse((3, 10, 15, 26), ramp(colour))
        icon.poly([(9, 10), (28, 14), (28, 28), (9, 26)], ramp(colour))
        icon.ring((5, 12, 13, 24), 1, [ramp(colour)[3]] * 5)
        return icon
    pts = [(5, 4), (27, 4), (26, 22), (23, 28), (20, 23), (17, 29), (13, 23), (9, 28), (6, 21)] if tatters else [(5, 4), (27, 4), (28, 27), (4, 27)]
    icon.poly(pts, ramp(colour))
    icon.line([(8, 8), (24, 8)], 1, [ramp(colour)[0]] * 5)
    return icon


def coins_icon():
    icon = Icon()
    for i, (x, y) in enumerate(((9, 22), (21, 22), (15, 18), (15, 13), (15, 8))):
        icon.ellipse((x - 6, y - 4, x + 6, y + 4), ramp(GOLD))
        icon.line([(x - 4, y), (x + 4, y)], 1, [ramp(GOLD)[3]] * 5)
    icon.sparkle(24, 6)
    return icon


def key_icon():
    icon = Icon()
    icon.ring((3, 3, 15, 15), 3, ramp(IRON))
    icon.line([(13, 13), (27, 27)], 3, ramp(IRON))
    icon.line([(22, 22), (26, 18)], 2, ramp(IRON))
    icon.line([(25, 25), (29, 21)], 2, ramp(IRON))
    return icon


def coal_icon():
    icon = Icon()
    for x, y, r in ((10, 20, 7), (21, 21, 6), (16, 12, 6)):
        rock(icon, ramp("3a3a44"), x * y, (x - r, y - r, x + r, y + r))
    icon.dots([(9, 16), (19, 9), (21, 18)], (140, 140, 160))
    return icon


def jug_icon(liquid="f4f4f0"):
    icon = Icon()
    icon.poly([(9, 10), (23, 10), (26, 18), (24, 29), (8, 29), (6, 18)], ramp("c8a070"))
    icon.rect((11, 4, 21, 10), ramp("c8a070"))
    icon.ellipse((11, 2, 21, 6), ramp(liquid))
    icon.ring((22, 12, 30, 22), 2, ramp("c8a070"))
    return icon


def piece_icon(kind):
    """The nine pieces of the Ninefold Blade."""
    icon = Icon()
    if kind == "pommel_hollow":
        icon.ellipse((7, 7, 25, 25), ramp(BONE))
        icon.ring((6, 6, 26, 26), 2, ramp(GOLD))
        icon.ellipse((13, 13, 19, 19), ramp("7a52c0"))
    elif kind == "guard_cinder":
        icon.poly([(2, 13), (30, 13), (26, 20), (6, 20)], ramp(GOLD))
        icon.poly([(6, 14), (26, 14), (23, 18), (9, 18)], ramp(EMBER))
        icon.ellipse((13, 12, 19, 21), ramp("e04848"))
    elif kind == "edge_frost":
        p = icon.km(lambda k, d: -22 <= k <= 24 and abs(d) <= 2.2 * min(1.0, (24 - k) / 6.0), ramp(FROST))
        across(icon, p, ramp(FROST))
        icon.sparkle(24, 7, (230, 250, 255))
    elif kind == "grip_pale":
        icon.rect((12, 3, 20, 29), ramp(SILVER))
        for y in range(5, 28, 4):
            icon.line([(12, y), (20, y + 2)], 1, ramp(LEATHER))
        icon.rect((10, 2, 22, 5), ramp(GOLD))
        icon.rect((10, 27, 22, 30), ramp(GOLD))
    elif kind == "wrap_briar":
        icon.rect((11, 3, 21, 29), ramp(DARK_LEATHER))
        icon.line([(10, 5), (22, 11), (10, 17), (22, 23), (11, 28)], 2, ramp("4a8a3a"))
        for x, y in ((22, 11), (10, 17), (22, 23)):
            icon.put(x + (1 if x > 16 else -1), y, (230, 220, 200))
    elif kind == "fuller_dune":
        p = icon.km(lambda k, d: -20 <= k <= 22 and abs(d) <= 2.6, ramp("d8c890"))
        across(icon, p, ramp("d8c890"))
        for k in range(-18, 20, 2):
            d = 0
            if (k + d + MID) % 2 == 0:
                x = (k + MID) // 2
                icon.put(x, x - k, c("f0a830"))
    elif kind == "core_molten":
        icon.ellipse((5, 5, 27, 27), ramp("3a2a2a"))
        icon.ellipse((9, 9, 23, 23), ramp("f06a2a"))
        icon.ellipse((13, 12, 19, 18), ramp("ffd060"))
        for x, y in ((7, 16), (16, 6), (25, 15), (16, 26)):
            icon.put(x, y, (255, 120, 40))
    elif kind == "gem_eye":
        icon.poly([(16, 2), (27, 14), (16, 30), (5, 14)], ramp(GOLD))
        icon.poly([(16, 6), (23, 14), (16, 26), (9, 14)], ramp("6a3ab0"))
        icon.ellipse((13, 11, 19, 17), ramp("e8e0ff"))
        icon.put(16, 14, (20, 10, 30))
    elif kind == "heart_blade":
        icon.ellipse((4, 6, 17, 19), ramp(HEART))
        icon.ellipse((15, 6, 28, 19), ramp(HEART))
        icon.poly([(5, 15), (27, 15), (16, 29)], ramp(HEART))
        icon.line([(16, 2), (16, 26)], 2, ramp(SILVER))
        icon.sparkle(10, 10)
    return icon


# ======================================================================
# Food and drink
# ======================================================================

def raw_meat_icon(colour="d8505a", fat="f4d8d0", bone=False, shape="steak", size=0):
    icon = Icon()
    tones = ramp(colour)
    if shape == "leg":
        s = size
        icon.ellipse((4 - s, 4 - s, 22 + s, 22 + s), tones)
        icon.line([(18 + s, 18 + s), (27, 27)], 3, ramp(BONE))
        icon.ellipse((24, 24, 30, 30), ramp(BONE))
        icon.line([(8 - s, 10), (15, 6 - s)], 1, [c(fat)] * 5)
        return icon
    if shape == "claw":
        icon.poly([(4, 24), (10, 10), (20, 6), (27, 10), (22, 16), (14, 18), (12, 27)], tones)
        icon.poly([(20, 6), (29, 3), (26, 12)], tones)
        icon.line([(8, 20), (13, 12), (20, 9)], 1, [c("f8e8e0")] * 5)
        return icon
    if shape == "chop":
        icon.poly([(3, 14), (9, 6), (20, 5), (26, 10), (24, 20), (14, 26), (5, 22)], tones)
        icon.line([(4, 13), (9, 7), (20, 6), (25, 10)], 2, [c(fat)] * 5)
        icon.rect((22, 17, 29, 20), ramp(BONE))
        icon.ellipse((26, 15, 31, 21), ramp(BONE))
        return icon
    if shape == "ribs":
        icon.poly([(3, 12), (28, 10), (29, 26), (4, 28)], tones)
        for x in (8, 15, 22):
            icon.rect((x, 5, x + 2, 12), ramp(BONE))
            icon.line([(x + 1, 13), (x + 1, 26)], 1, [c(fat)] * 5)
        return icon
    if shape == "chunk":
        icon.poly([(3, 10), (10, 4), (22, 3), (29, 9), (29, 22), (22, 29), (8, 28), (3, 21)], tones)
        icon.poly([(3, 10), (10, 4), (22, 3), (29, 9), (22, 11), (9, 12)], ramp(mix(c(colour), (255, 255, 255), 0.1)))
        icon.scatter({(x, y) for x in range(5, 28) for y in range(12, 27)}, c(fat), 0.12, 6)
        return icon
    if shape == "tail":
        icon.line([(4, 26), (10, 16), (18, 10), (27, 7)], 6, tones)
        icon.ellipse((1, 22, 10, 31), tones)
        icon.ellipse((3, 24, 8, 29), [c(fat)] * 5)
        for x, y in ((11, 16), (15, 12), (19, 10), (23, 8)):
            icon.put(x, y, tones[3])
        return icon
    icon.poly([(4, 12), (12, 5), (24, 5), (29, 12), (27, 24), (16, 28), (5, 24)], tones)
    icon.line([(7, 14), (14, 10), (22, 12)], 1, [c(fat)] * 5)
    icon.line([(10, 20), (20, 19)], 1, [c(fat)] * 5)
    if bone:
        icon.ellipse((14, 13, 19, 18), ramp(BONE))
        icon.put(16, 15, ramp(BONE)[3])
    return icon


def cooked_icon(colour="a0502a", kind="steak", garnish=None):
    icon = Icon()
    tones = ramp(colour)
    if kind == "drumstick":
        icon.ellipse((3, 3, 21, 21), tones)
        icon.line([(17, 17), (26, 26)], 3, ramp(BONE))
        icon.ellipse((23, 23, 30, 30), ramp(BONE))
        icon.dots([(8, 7), (12, 6), (7, 11)], tones[0])
    elif kind == "whole":
        icon.ellipse((3, 9, 25, 27), tones)
        icon.line([(20, 12), (27, 5)], 3, tones)
        icon.line([(22, 16), (29, 11)], 3, tones)
        icon.ellipse((25, 2, 30, 7), ramp(BONE))
        icon.ellipse((27, 8, 31, 13), ramp(BONE))
        icon.dots([(8, 13), (11, 12), (7, 16), (14, 14)], tones[0])
        icon.ellipse((1, 24, 27, 31), ramp(SILVER), under=True)
    elif kind == "shank":
        icon.poly([(3, 10), (12, 3), (20, 6), (22, 16), (16, 22), (6, 20)], tones)
        icon.line([(18, 18), (27, 27)], 4, ramp(BONE))
        icon.ellipse((24, 23, 31, 30), ramp(BONE))
        icon.dots([(8, 8), (12, 6), (6, 13)], tones[0])
    elif kind == "skewer":
        icon.line([(2, 30), (29, 3)], 1, ramp(PALE_WOOD))
        for x, y, col in ((8, 23, colour), (14, 17, "6ab040" if not garnish else garnish), (20, 11, colour)):
            icon.ellipse((x - 4, y - 4, x + 4, y + 4), ramp(col))
        return icon
    elif kind == "fish":
        icon.ellipse((3, 10, 25, 22), tones)
        icon.poly([(24, 16), (30, 10), (30, 22)], tones)
        for x in (8, 13, 18):
            icon.line([(x, 11), (x + 3, 21)], 1, [tones[4]] * 5)
        icon.line([(1, 16), (31, 16)], 1, ramp(PALE_WOOD), under=True)
    elif kind == "strips":
        for i in range(3):
            icon.poly([(4 + i * 8, 4), (10 + i * 8, 4), (12 + i * 8, 28), (6 + i * 8, 28)], tones)
            icon.line([(6 + i * 8, 8), (9 + i * 8, 24)], 1, [tones[0]] * 5)
    elif kind == "legs":
        for x in (8, 18):
            icon.line([(x, 4), (x + 2, 18), (x - 2, 28)], 4, tones)
    elif kind == "grilled":
        icon.poly([(4, 12), (12, 5), (24, 5), (29, 12), (27, 24), (16, 28), (5, 24)], tones)
        for i in range(4):
            icon.line([(6 + i * 6, 7), (12 + i * 6, 26)], 1, [c("3a1e14")] * 5)
        icon.line([(6, 22), (27, 10)], 1, [c("3a1e14")] * 5)
    else:
        icon.poly([(4, 12), (12, 5), (24, 5), (29, 12), (27, 24), (16, 28), (5, 24)], tones)
        for x in (10, 16, 22):
            icon.line([(x - 3, 9), (x + 2, 24)], 1, [tones[4]] * 5)
    if garnish:
        stem(icon, [(23, 10), (28, 2)], "3a7a3a")
        for x, y in ((24, 7), (26, 4), (27, 6), (25, 9)):
            icon.put(x, y, c(garnish))
    return icon


def bowl_icon(soup, chunks=(), bowl="8a6a4a", steam=True, rim=None, pot=False):
    icon = Icon()
    if pot:
        icon.ellipse((3, 11, 29, 30), ramp(bowl))
        icon.rect((1, 13, 4, 16), ramp(bowl))
        icon.rect((28, 13, 31, 16), ramp(bowl))
        icon.line([(7, 30), (5, 31)], 1, ramp(bowl))
        icon.line([(25, 30), (27, 31)], 1, ramp(bowl))
    else:
        icon.poly([(3, 15), (29, 15), (25, 26), (7, 26)], ramp(bowl))
        icon.rect((10, 26, 22, 29), ramp(bowl))
    icon.ellipse((3, 11, 29, 19), ramp(soup))
    for i, col in enumerate(chunks):
        x = 8 + (i * 7) % 16
        y = 13 + (i % 2) * 2
        icon.rect((x, y, x + 2, y + 1), ramp(col))
    if rim:
        icon.line([(4, 20), (28, 20)], 1, ramp(rim))
    if steam:
        for x in (10, 16, 22):
            for y, dx in ((8, 0), (6, 1), (4, 0)):
                icon.put(x + dx, y - (x % 3), (230, 236, 244), part=False)
                icon.no_outline.add((x + dx, y - (x % 3)))
    return icon


def pie_icon(filling, crust="e0b070", lattice=True, slice_=False, topping=None):
    icon = Icon()
    icon.ellipse((2, 10, 30, 28), ramp(crust))
    icon.ellipse((5, 11, 27, 24), ramp(filling))
    if lattice:
        for x in range(8, 26, 5):
            icon.line([(x, 11), (x + 3, 23)], 1, ramp(crust))
        for y in (14, 19):
            icon.line([(6, y), (26, y)], 1, ramp(crust))
    if topping:
        for x, y in ((10, 15), (16, 13), (21, 17), (14, 20)):
            icon.ellipse((x - 1, y - 1, x + 1, y + 1), ramp(topping))
    if slice_:
        for (x, y) in list(icon.colour):
            if x > 16 and y < 19 and x - 16 > (19 - y) * 0.8:
                del icon.colour[(x, y)]
                icon.part.pop((x, y), None)
    return icon


def bread_icon(colour="d8a050", kind="loaf", glaze=None):
    icon = Icon()
    if kind == "roll":
        icon.ellipse((5, 10, 27, 27), ramp(colour))
        icon.line([(8, 18), (16, 14), (24, 18)], 1, [ramp(colour)[0]] * 5)
        if glaze:
            icon.line([(9, 14), (23, 14)], 2, ramp(glaze))
        return icon
    icon.poly([(3, 22), (6, 12), (14, 8), (22, 9), (29, 15), (28, 24), (5, 26)], ramp(colour))
    for x in (11, 17, 23):
        icon.line([(x - 2, 12), (x + 1, 17)], 1, [ramp(colour)[0]] * 5)
    if glaze:
        icon.scatter({(x, y) for x in range(8, 26) for y in range(9, 14)}, c(glaze), 0.3, 3)
    return icon


def berries_icon(colour, count=5, leaf_c="5aa040", candied=False):
    icon = Icon()
    spots = [(10, 18), (17, 21), (22, 15), (14, 12), (19, 26), (8, 25), (24, 23)]
    for x, y in spots[:count]:
        icon.ellipse((x - 4, y - 4, x + 4, y + 4), ramp(colour))
        icon.put(x - 1, y - 2, (255, 255, 255) if not candied else (255, 250, 230))
    leaf(icon, 14, 8, 1, -1, leaf_c, 6)
    if candied:
        icon.scatter(set(icon.colour), (255, 255, 255), 0.12, 2)
    return icon


def jam_icon(colour):
    icon = Icon()
    icon.rect((7, 9, 25, 29), ramp("d0e0e8"))
    icon.rect((9, 13, 23, 27), ramp(colour))
    icon.rect((6, 5, 26, 10), ramp(CLOTH_RED))
    icon.line([(6, 10), (26, 10)], 1, ramp("e8d8b0"))
    return icon


def egg_icon():
    icon = Icon()
    icon.ellipse((8, 4, 24, 29), ramp("f4ecdc"))
    icon.put(12, 10, (255, 255, 255))
    return icon


def cheese_icon():
    icon = Icon()
    icon.poly([(3, 20), (18, 6), (29, 14), (29, 24), (3, 28)], ramp("f0c850"))
    icon.poly([(3, 20), (18, 6), (29, 14), (14, 22)], ramp("f8dc70"))
    for x, y in ((9, 24), (20, 21), (24, 25), (14, 26)):
        icon.ellipse((x - 1, y - 1, x + 1, y + 1), ramp("c89a30"))
    return icon


def omelette_icon(herbs=False):
    icon = Icon()
    icon.ellipse((2, 16, 30, 28), ramp("e8e8f0"))
    icon.poly([(5, 21), (10, 12), (22, 11), (27, 19), (16, 24)], ramp("f4d050"))
    if herbs:
        icon.dots([(12, 16), (17, 14), (21, 17), (14, 20)], (80, 160, 60))
    return icon


def platter_icon(items):
    icon = Icon()
    icon.ellipse((1, 14, 31, 30), ramp(SILVER if items != "feast" else WOOD))
    if items == "feast":
        icon.ellipse((4, 8, 16, 20), ramp("a0502a"))
        icon.line([(13, 17), (18, 22)], 2, ramp(BONE))
        icon.ellipse((17, 10, 27, 20), ramp("d8a050"))
        icon.ellipse((22, 18, 28, 24), ramp("e0303e"))
    else:
        icon.ellipse((5, 9, 15, 19), ramp(GOLD))
        icon.ellipse((14, 7, 26, 18), ramp("f0c040"))
        icon.ellipse((18, 17, 25, 23), ramp("30b860"))
        icon.sparkle(25, 5)
    return icon


def cakes_icon(colour="d89050"):
    icon = Icon()
    for x, y in ((10, 21), (22, 21), (16, 13)):
        icon.ellipse((x - 7, y - 4, x + 7, y + 4), ramp(colour))
        icon.dots([(x - 2, y - 1), (x + 2, y)], (230, 140, 90))
    return icon


def baked_potato_icon():
    icon = Icon()
    icon.ellipse((3, 9, 29, 27), ramp("a07040"))
    icon.poly([(9, 13), (23, 13), (21, 19), (11, 19)], ramp("f8e8a0"))
    icon.rect((13, 12, 17, 15), ramp("fff4c0"))
    return icon


def custard_icon():
    icon = pie_icon("f4d870", lattice=False)
    icon.sparkle(16, 16, (255, 250, 220))
    return icon


# --- potions and drinks

def bottle_icon(liquid, shape="round", cork=WOOD, glass="d8eef4", label=None, extra=None):
    icon = Icon()
    if shape == "round":
        icon.ellipse((5, 10, 27, 30), ramp(glass))
        icon.ellipse((7, 15, 25, 29), ramp(liquid))
        icon.rect((12, 3, 20, 11), ramp(glass))
    elif shape == "vial":
        icon.rect((10, 6, 22, 29), ramp(glass))
        icon.rect((11, 12, 21, 28), ramp(liquid))
        icon.rect((12, 2, 20, 6), ramp(glass))
    elif shape == "square":
        icon.rect((6, 9, 26, 29), ramp(glass))
        icon.rect((8, 13, 24, 27), ramp(liquid))
        icon.rect((12, 3, 20, 9), ramp(glass))
    elif shape == "flask":
        icon.poly([(12, 6), (20, 6), (20, 12), (28, 28), (4, 28), (12, 12)], ramp(glass))
        icon.poly([(9, 18), (23, 18), (26, 27), (6, 27)], ramp(liquid))
    elif shape == "gourd":
        icon.ellipse((10, 4, 22, 14), ramp(glass))
        icon.ellipse((5, 11, 27, 30), ramp(glass))
        icon.ellipse((7, 15, 25, 29), ramp(liquid))
    elif shape == "jar":
        icon.rect((5, 10, 27, 29), ramp(glass))
        icon.rect((7, 14, 25, 27), ramp(liquid))
        icon.rect((4, 6, 28, 11), ramp(WOOD))
        return icon
    elif shape == "mushroom":
        icon.ellipse((7, 12, 25, 30), ramp(glass))
        icon.ellipse((9, 16, 23, 28), ramp(liquid))
        icon.poly([(5, 10), (10, 3), (22, 3), (27, 10)], ramp("c8283a"))
        icon.dots([(11, 6), (18, 5), (22, 8)], (245, 235, 225))
        return icon
    icon.rect((13, 0, 19, 4), ramp(cork))
    icon.put(10, 16, (255, 255, 255))
    icon.put(10, 17, (240, 250, 255))
    if label:
        icon.rect((10, 19, 22, 24), ramp(label))
    if extra:
        extra(icon)
    return icon


def mug_icon(drink, mug=WOOD, foam=None, kind="mug", steam=False, garnish=None):
    icon = Icon()
    if kind == "cup":
        icon.poly([(5, 13), (25, 13), (22, 27), (8, 27)], ramp(mug))
        icon.ellipse((5, 11, 25, 16), ramp(drink))
        icon.ring((22, 15, 30, 23), 2, ramp(mug))
        icon.ellipse((3, 26, 27, 30), ramp(mug))
    elif kind == "teapot":
        icon.ellipse((5, 10, 25, 29), ramp(mug))
        icon.poly([(24, 16), (31, 10), (30, 13), (25, 21)], ramp(mug))
        icon.ring((1, 13, 9, 23), 2, ramp(mug))
        icon.ellipse((11, 6, 19, 11), ramp(mug))
        icon.dots([(12, 17), (18, 20), (15, 23)], c(drink))
    else:
        icon.rect((5, 9, 23, 29), ramp(mug))
        icon.rect((7, 11, 21, 15), ramp(drink))
        icon.ring((20, 12, 30, 25), 3, ramp(mug))
        for y in (17, 23):
            icon.line([(5, y), (23, y)], 1, ramp(DARK_IRON))
    if foam:
        icon.ellipse((4, 5, 24, 13), ramp(foam))
    if steam:
        for x in (11, 15, 19):
            for y in (4, 2, 0):
                icon.put(x + (y % 2), y + 2, (230, 236, 244), part=False)
                icon.no_outline.add((x + (y % 2), y + 2))
    if garnish:
        leaf(icon, 18, 12, 1, -1, garnish, 5)
    return icon


# --- runes, seeds, whistles

RUNE_GLYPHS = {
    "ember": ("ff8a40", [[(20, 9), (12, 16), (20, 23)]]),
    "rime": ("8ad8ff", [[(16, 8), (16, 24)], [(11, 12), (21, 20)], [(21, 12), (11, 20)]]),
    "venom": ("8ae060", [[(16, 24), (16, 13)], [(11, 8), (16, 13), (21, 8)]]),
    "gloom": ("a080e0", [[(12, 8), (12, 24)], [(20, 8), (20, 24)], [(12, 12), (20, 20)]]),
    "dawn": ("ffe08a", [[(19, 8), (12, 14), (20, 18), (13, 24)]]),
    "gale": ("c8f0e8", [[(10, 11), (21, 11)], [(10, 16), (23, 16)], [(10, 21), (19, 21)], [(19, 13), (23, 16), (19, 19)]]),
    "stone": ("d8d0c8", [[(16, 8), (21, 14), (16, 20), (11, 14), (16, 8)], [(13, 19), (11, 25)], [(19, 19), (21, 25)]]),
    "blood": ("e04858", [[(16, 25), (16, 8)], [(11, 13), (16, 8), (21, 13)]]),
}


def rune_icon(kind):
    colour, strokes = RUNE_GLYPHS[kind]
    icon = Icon()
    icon.poly([(7, 3), (25, 3), (29, 7), (29, 25), (25, 29), (7, 29), (3, 25), (3, 7)], ramp("8a8794"))
    icon.poly([(8, 5), (24, 5), (27, 8), (27, 24), (24, 27), (8, 27), (5, 24), (5, 8)], ramp("a8a4b0"))
    for stroke in strokes:
        icon.line(stroke, 2, [mix(c(colour), (255, 255, 255), 0.3), c(colour), c(colour), ramp(colour)[3], ramp(colour)[3]])
    return icon


def seed_icon(picture):
    icon = Icon()
    icon.poly([(6, 4), (26, 4), (27, 29), (5, 29)], ramp("e0c890"))
    icon.line([(6, 8), (26, 8)], 1, ramp("b89860"))
    icon.rect((9, 11, 23, 25), ramp("f4e8c8"))
    picture(icon)
    return icon


def whistle_icon(body, emblem=None, kind="bone"):
    """A pea whistle: the mouthpiece to the left, the round chamber with its
    window on the right, a ring and a cord."""
    icon = Icon()
    icon.rect((2, 15, 18, 20), ramp(body))
    icon.ellipse((12, 9, 29, 26), ramp(body))
    icon.rect((2, 15, 4, 20), ramp(mix(c(body), (40, 30, 30), 0.3)))
    icon.rect((13, 12, 17, 14), [c("2a1e1a")] * 5, flat=True, rim=False)
    icon.line([(13, 14), (17, 14)], 1, [ramp(body)[0]] * 5)
    icon.ring((24, 4, 30, 10), 1, ramp(GOLD))
    icon.line([(25, 5), (18, 2), (9, 4), (4, 10)], 1, ramp(CLOTH_RED))
    if emblem:
        emblem(icon)
    return icon


# ======================================================================
# Furniture, buildings and blocks: small objects seen from the front and a
# little above
# ======================================================================

STONE, DARK_STONE, MOSS, ROOF_RED, STRAW = "a8a4b0", "6e6a78", "5a8a3a", "b04a3a", "e0c060"


def legs(icon, xs, y0, y1, col=DARK_WOOD, w=1):
    for x in xs:
        icon.rect((x, y0, x + w, y1), ramp(col))


def fire(icon, x, y, h=6, w=3):
    """A small flame rising from (x, y)."""
    for dy in range(h):
        half = max(0, round(w * (1 - dy / h) ** 0.8))
        for dx in range(-half, half + 1):
            t = abs(dx) / max(half, 1)
            col = (255, 240, 170) if t < 0.34 and dy < h - 2 else (255, 170, 60) if t < 0.75 else (220, 80, 40)
            icon.put(x + dx, y - dy, col, part=False)
    icon.put(x, y - h, (255, 120, 50), part=False)


def furniture_icon(kind):
    icon = Icon()
    if kind == "anvil":
        icon.poly([(3, 9), (24, 9), (29, 11), (24, 14), (7, 14)], ramp(DARK_IRON))
        icon.rect((11, 14, 20, 21), ramp("4a4e5a"))
        icon.poly([(7, 21), (24, 21), (27, 27), (4, 27)], ramp(DARK_IRON))
        icon.line([(5, 10), (24, 10)], 1, ramp("b8c0cc"))
    elif kind == "ballista":
        legs(icon, (6, 24), 18, 29, DARK_WOOD, 1)
        icon.rect((4, 16, 28, 19), ramp(WOOD))
        icon.line([(3, 5), (16, 12), (29, 5)], 2, ramp(DARK_WOOD))
        icon.line([(3, 5), (16, 15), (29, 5)], 1, [c("e8e0d0")] * 5)
        icon.line([(16, 3), (16, 18)], 1, ramp(PALE_WOOD))
        icon.poly([(14, 4), (16, 0), (18, 4)], ramp(STEEL))
    elif kind == "barrel":
        icon.ellipse((6, 4, 26, 30), ramp(WOOD))
        icon.rect((6, 7, 26, 27), ramp(WOOD))
        icon.ellipse((7, 3, 25, 9), ramp(DARK_WOOD))
        for y in (11, 22):
            icon.line([(6, y), (26, y)], 2, ramp(DARK_IRON))
        for x in (11, 16, 21):
            icon.line([(x, 9), (x, 28)], 1, [ramp(WOOD)[3]] * 5)
    elif kind == "bench":
        icon.poly([(2, 14), (28, 14), (30, 17), (4, 17)], ramp(PALE_WOOD))
        icon.rect((3, 17, 29, 19), ramp(WOOD))
        legs(icon, (5, 25), 19, 27, DARK_WOOD, 1)
        icon.line([(6, 24), (26, 24)], 1, ramp(DARK_WOOD))
    elif kind == "bookshelf":
        icon.rect((4, 2, 28, 30), ramp(DARK_WOOD))
        cols = ["b8404a", "4a6ab0", "5a9a4a", "c8904a", "7a52c0", "e0d0a0"]
        for row, y in enumerate((4, 13, 22)):
            icon.rect((6, y, 26, y + 7), [c("2a1e1a")] * 5, flat=True, rim=False)
            x = 6
            i = row * 2
            while x < 25:
                w = 2 + (i % 2)
                h = 6 - (i % 3 == 0)
                icon.rect((x, y + 7 - h, x + w - 1, y + 7), ramp(cols[i % len(cols)]))
                x += w + (1 if i % 4 == 3 else 0)
                i += 1
    elif kind == "brazier":
        icon.line([(10, 18), (6, 29)], 1, ramp(DARK_IRON))
        icon.line([(22, 18), (26, 29)], 1, ramp(DARK_IRON))
        icon.line([(16, 18), (16, 29)], 1, ramp(DARK_IRON))
        icon.poly([(5, 13), (27, 13), (23, 19), (9, 19)], ramp(DARK_IRON))
        icon.ellipse((7, 11, 25, 15), ramp("e05a2a"))
        fire(icon, 12, 12, 7, 3)
        fire(icon, 19, 12, 9, 3)
    elif kind == "candles":
        icon.ellipse((3, 23, 29, 29), ramp(GOLD))
        for x, top in ((9, 13), (16, 8), (23, 15)):
            icon.rect((x - 2, top, x + 1, 25), ramp("f0e8d8"))
            fire(icon, x, top - 1, 4, 1)
            icon.put(x - 1, top + 1, (230, 220, 200))
    elif kind == "chair":
        icon.rect((8, 3, 22, 16), ramp(WOOD))
        icon.rect((10, 5, 20, 14), ramp(CLOTH_RED))
        icon.poly([(6, 16), (24, 16), (26, 20), (8, 20)], ramp(PALE_WOOD))
        legs(icon, (8, 23), 20, 29, DARK_WOOD, 1)
    elif kind == "crate":
        icon.rect((4, 6, 28, 29), ramp(PALE_WOOD))
        icon.rect((7, 9, 25, 26), ramp("c8a870"))
        icon.line([(7, 26), (25, 9)], 2, ramp(PALE_WOOD))
        for x, y in ((5, 7), (26, 7), (5, 27), (26, 27)):
            icon.put(x, y, c(DARK_IRON))
    elif kind == "cupboard":
        icon.rect((5, 2, 27, 30), ramp(WOOD))
        icon.rect((7, 5, 15, 27), ramp("b08050"))
        icon.rect((17, 5, 25, 27), ramp("b08050"))
        icon.rect((4, 1, 28, 3), ramp(DARK_WOOD))
        icon.put(14, 16, c(GOLD))
        icon.put(18, 16, c(GOLD))
    elif kind == "dining_table":
        icon.poly([(6, 8), (26, 8), (30, 18), (2, 18)], ramp(WOOD))
        icon.poly([(10, 9), (22, 9), (25, 17), (7, 17)], ramp("e8e0d0"))
        icon.rect((2, 18, 30, 20), ramp(DARK_WOOD))
        legs(icon, (3, 27), 20, 29, DARK_WOOD, 1)
        icon.ellipse((13, 11, 19, 15), ramp("d8a050"))
    elif kind == "farm_plot":
        icon.poly([(16, 6), (30, 15), (16, 26), (2, 15)], ramp("6a4a2e"))
        for i in range(-2, 3):
            icon.line([(9 + i * 3 + 7, 9 + i * 2 - 1), (2 + i * 3 + 7, 15 + i * 2 - 1)], 1, [c("4a3220")] * 5)
        for x, y in ((12, 12), (17, 15), (21, 18), (14, 19), (19, 11)):
            icon.put(x, y - 1, (110, 190, 70), part=False)
            icon.put(x - 1, y - 2, (130, 210, 80), part=False)
            icon.put(x + 1, y - 2, (90, 170, 60), part=False)
    elif kind in ("farmhouse_kit", "house_kit"):
        if kind == "farmhouse_kit":
            icon.rect((6, 15, 26, 29), ramp("c8a870"))
            icon.poly([(3, 16), (16, 4), (29, 16)], ramp(STRAW))
            icon.rect((14, 21, 18, 29), ramp(DARK_WOOD))
            icon.rect((8, 18, 11, 21), ramp(FROST))
            icon.rect((21, 18, 24, 21), ramp(FROST))
            icon.line([(2, 29), (30, 29)], 1, ramp(MOSS))
        else:
            icon.rect((6, 15, 26, 29), ramp(STONE))
            icon.rect((6, 15, 26, 18), ramp(WOOD))
            icon.poly([(3, 16), (16, 5), (29, 16)], ramp(NAVY))
            icon.rect((21, 4, 24, 11), ramp(DARK_STONE))
            icon.rect((14, 21, 18, 29), ramp(DARK_WOOD))
            icon.rect((9, 20, 12, 23), ramp("ffd070"))
            icon.put(16, 9, c(GOLD))
    elif kind == "fence":
        for x in (5, 15, 25):
            icon.poly([(x - 2, 9), (x, 6), (x + 2, 9), (x + 2, 29), (x - 2, 29)], ramp(WOOD))
        icon.rect((3, 12, 29, 14), ramp(PALE_WOOD))
        icon.rect((3, 21, 29, 23), ramp(PALE_WOOD))
    elif kind == "fireplace":
        icon.rect((2, 5, 30, 30), ramp(STONE))
        icon.rect((1, 3, 31, 7), ramp(DARK_STONE))
        icon.poly([(7, 30), (7, 16), (11, 12), (21, 12), (25, 16), (25, 30)], [c("24181a")] * 5, flat=True, rim=False)
        for x, y in ((4, 10), (26, 18), (5, 22), (27, 26), (12, 9), (20, 9)):
            icon.put(x, y, ramp(STONE)[3])
        icon.line([(10, 29), (22, 27)], 2, ramp(DARK_WOOD))
        fire(icon, 13, 27, 8, 3)
        fire(icon, 19, 27, 10, 3)
    elif kind == "flower_bed":
        icon.rect((2, 19, 30, 29), ramp(WOOD))
        icon.rect((3, 16, 29, 20), ramp("5a3e26"))
        for x, col in ((6, "e04858"), (11, "f0c040"), (16, "a050e0"), (21, "f4f4f0"), (26, "e88ab0")):
            stem(icon, [(x, 18), (x, 12)], "4a8a3a")
            flower(icon, x, 10 + (x % 3), col, "f8e070", 2, 4)
    elif kind == "fountain":
        icon.ellipse((1, 18, 31, 30), ramp(STONE))
        icon.ellipse((4, 19, 28, 26), ramp("4a8ac8"))
        icon.rect((14, 9, 18, 22), ramp(STONE))
        icon.ellipse((9, 8, 23, 13), ramp(STONE))
        for x, y in ((16, 2), (16, 4), (13, 6), (19, 6), (11, 9), (21, 9), (16, 6)):
            icon.put(x, y, (170, 220, 250), part=False)
            icon.no_outline.add((x, y))
        icon.dots([(8, 22), (22, 23), (12, 24)], (200, 236, 255))
    elif kind == "furnace":
        icon.rect((3, 6, 29, 30), ramp(DARK_STONE))
        icon.rect((12, 1, 20, 7), ramp(DARK_STONE))
        icon.poly([(8, 30), (8, 18), (12, 14), (20, 14), (24, 18), (24, 30)], ramp("e05a2a"))
        icon.poly([(11, 30), (11, 20), (14, 17), (18, 17), (21, 20), (21, 30)], ramp("ffc050"))
        for x, y in ((5, 9), (24, 9), (6, 13), (26, 15), (5, 25), (27, 25)):
            icon.put(x, y, ramp(DARK_STONE)[0])
    elif kind == "hay_bale":
        icon.rect((2, 9, 30, 29), ramp(STRAW))
        icon.poly([(2, 9), (8, 4), (31, 4), (30, 9)], ramp("f0d880"))
        for x in (10, 22):
            icon.line([(x, 9), (x, 29)], 1, ramp("8a5a34"))
            icon.line([(x, 9), (x + 5, 4)], 1, ramp("8a5a34"))
        for x, y in ((5, 13), (14, 17), (26, 21), (6, 24), (17, 26), (25, 12)):
            icon.put(x, y, ramp(STRAW)[3])
            icon.put(x + 1, y - 1, ramp(STRAW)[0])
    elif kind == "lantern_post":
        icon.rect((14, 4, 17, 30), ramp(DARK_IRON))
        icon.line([(17, 6), (25, 6)], 1, ramp(DARK_IRON))
        icon.rect((21, 9, 28, 18), ramp(DARK_IRON))
        icon.rect((22, 10, 27, 17), ramp("ffd070"))
        icon.put(24, 13, (255, 250, 220))
        icon.rect((11, 27, 20, 30), ramp(DARK_STONE))
    elif kind == "palisade_wall":
        for i, x in enumerate((4, 10, 16, 22, 28)):
            top = 3 + (i % 2) * 2
            icon.poly([(x - 3, top + 4), (x, top), (x + 3, top + 4), (x + 3, 30), (x - 3, 30)], ramp(WOOD if i % 2 else "8a5e38"))
        icon.rect((1, 18, 31, 20), ramp(DARK_IRON))
    elif kind == "potted_plant":
        icon.poly([(8, 18), (24, 18), (22, 30), (10, 30)], ramp("c86a3a"))
        icon.rect((7, 16, 25, 19), ramp("d87a4a"))
        for x, y, dx in ((16, 4, 0), (10, 8, -1), (22, 8, 1), (12, 13, -1), (20, 13, 1)):
            leaf(icon, 16, 16, dx if dx else 0.2, -1, "5aa040", 6)
            icon.ellipse((x - 3, y - 2, x + 3, y + 3), ramp("5aa040"))
    elif kind == "root_hollow":
        icon.poly([(1, 30), (5, 20), (6, 8), (12, 3), (20, 3), (26, 8), (27, 20), (31, 30)], ramp("6a4a2e"))
        icon.poly([(11, 30), (11, 20), (14, 15), (18, 15), (21, 20), (21, 30)], [c("1e1418")] * 5, flat=True, rim=False)
        icon.dots([(15, 22), (17, 22)], (255, 210, 120))
        for pts in ([(5, 20), (1, 26)], [(27, 20), (31, 25)], [(9, 6), (6, 2)], [(22, 5), (26, 1)]):
            icon.line(pts, 2, ramp("5a3e26"))
        icon.scatter({(x, y) for x in range(6, 26) for y in range(3, 9)}, c(MOSS), 0.3, 5)
    elif kind.startswith("rootling"):
        icon.ellipse((7, 12, 23, 29), ramp("8a6040"))
        icon.dots([(12, 19), (18, 19)], (255, 220, 120))
        icon.line([(10, 28), (8, 31)], 1, ramp("6a4a2e"))
        icon.line([(20, 28), (22, 31)], 1, ramp("6a4a2e"))
        leaf(icon, 15, 12, -1, -1, "6ab040", 5)
        leaf(icon, 15, 12, 1, -1, "5aa040", 5)
        if kind == "rootling_delver":
            icon.line([(22, 26), (29, 12)], 1, ramp(WOOD))
            icon.line([(24, 11), (30, 15)], 2, ramp(IRON))
            icon.put(14, 11, (255, 230, 120))
        elif kind == "rootling_tender":
            icon.poly([(21, 18), (28, 18), (27, 26), (22, 26)], ramp(COPPER))
            icon.line([(28, 19), (31, 15)], 1, ramp(COPPER))
            for y in (17, 20, 23):
                icon.put(31, y, (120, 190, 240), part=False)
        else:
            icon.line([(22, 27), (28, 10)], 1, ramp(WOOD))
            icon.poly([(26, 9), (31, 8), (31, 15), (27, 13)], ramp(STEEL))
    elif kind == "rug":
        icon.poly([(6, 6), (30, 6), (26, 27), (2, 27)], ramp(CLOTH_RED))
        icon.poly([(9, 9), (26, 9), (23, 24), (6, 24)], ramp(NAVY))
        icon.poly([(16, 11), (20, 16), (16, 22), (12, 16)], ramp(GOLD))
        for x in range(3, 26, 3):
            icon.put(x, 28, c(GOLD))
            icon.put(x + 5, 5, c(GOLD))
    elif kind == "scarecrow":
        icon.line([(16, 10), (16, 31)], 2, ramp(WOOD))
        icon.line([(3, 15), (29, 15)], 2, ramp(WOOD))
        icon.poly([(9, 13), (23, 13), (21, 24), (11, 24)], ramp("4a6a9a"))
        icon.rect((12, 15, 14, 17), ramp(CLOTH_RED))
        icon.ellipse((11, 5, 21, 14), ramp("e0c890"))
        icon.poly([(6, 7), (26, 7), (20, 4), (12, 4)], ramp(STRAW))
        icon.poly([(11, 4), (21, 4), (19, 0), (13, 0)], ramp(STRAW))
        icon.dots([(14, 9), (18, 9)], (40, 30, 30))
        for x in (3, 29):
            icon.put(x, 17, c(STRAW))
            icon.put(x, 18, c(STRAW))
    elif kind == "spike_trap":
        icon.poly([(4, 18), (28, 18), (31, 28), (1, 28)], ramp(DARK_IRON))
        for x in (6, 11, 16, 21, 26):
            icon.poly([(x - 2, 21), (x, 9 + (x % 3)), (x + 2, 21)], ramp(STEEL))
    elif kind == "stone_planter":
        icon.rect((3, 17, 29, 29), ramp(STONE))
        icon.rect((2, 15, 30, 18), ramp("c0bcc8"))
        icon.ellipse((5, 5, 27, 19), ramp("4a8a3a"))
        icon.scatter({(x, y) for x in range(6, 26) for y in range(6, 17)}, c("6ab04a"), 0.25, 9)
        icon.dots([(10, 9), (20, 11), (15, 7)], (240, 120, 140))
    elif kind == "stone_statue":
        icon.rect((7, 25, 25, 30), ramp(DARK_STONE))
        icon.rect((10, 12, 22, 25), ramp(STONE))
        icon.ellipse((12, 3, 20, 12), ramp(STONE))
        icon.line([(22, 25), (26, 4)], 1, ramp(STONE))
        icon.poly([(7, 13), (11, 12), (11, 22), (7, 20)], ramp("c0bcc8"))
        icon.scatter({(x, y) for x in range(7, 25) for y in range(3, 25)}, c(MOSS), 0.06, 3)
    elif kind == "trophy_stand":
        icon.rect((8, 24, 24, 30), ramp(DARK_WOOD))
        icon.rect((14, 14, 18, 24), ramp(WOOD))
        icon.ellipse((9, 4, 23, 17), ramp(BONE))
        icon.line([(10, 7), (3, 2), (5, 9)], 2, ramp("d8c8a0"))
        icon.line([(22, 7), (29, 2), (27, 9)], 2, ramp("d8c8a0"))
        icon.dots([(13, 10), (19, 10)], (40, 24, 30))
        icon.put(16, 26, c(GOLD))
    elif kind == "wall_banner":
        icon.line([(4, 3), (28, 3)], 2, ramp(DARK_WOOD))
        icon.poly([(7, 4), (25, 4), (25, 28), (16, 23), (7, 28)], ramp(NAVY))
        icon.poly([(16, 9), (21, 14), (16, 19), (11, 14)], ramp(BRONZE))
        icon.line([(8, 6), (24, 6)], 1, ramp(BRONZE))
    elif kind == "weapon_rack":
        icon.rect((3, 6, 29, 9), ramp(WOOD))
        icon.rect((3, 24, 29, 27), ramp(WOOD))
        legs(icon, (4, 27), 6, 30, DARK_WOOD, 1)
        icon.line([(10, 2), (10, 29)], 1, ramp(STEEL))
        icon.line([(8, 22), (12, 22)], 1, ramp(GOLD))
        icon.line([(17, 3), (17, 29)], 1, ramp(WOOD))
        icon.poly([(15, 5), (17, 0), (19, 5)], ramp(STEEL))
        icon.line([(23, 10), (23, 29)], 1, ramp(WOOD))
        icon.poly([(20, 10), (23, 8), (27, 12), (24, 16)], ramp(STEEL))
    # --- the buildings and the house's own things
    elif kind == "bed":
        icon.poly([(3, 12), (27, 12), (30, 22), (6, 22)], ramp("e8e0d0"))
        icon.poly([(9, 13), (27, 13), (30, 22), (12, 22)], ramp(CLOTH_RED))
        icon.ellipse((4, 12, 10, 17), ramp("f8f4ec"))
        icon.rect((2, 6, 5, 28), ramp(WOOD))
        icon.rect((6, 22, 30, 25), ramp(WOOD))
        legs(icon, (6, 28), 25, 29, DARK_WOOD, 1)
    elif kind == "crafting_table":
        icon.poly([(4, 8), (28, 8), (31, 15), (1, 15)], ramp(PALE_WOOD))
        icon.rect((1, 15, 31, 18), ramp(WOOD))
        legs(icon, (2, 28), 18, 30, DARK_WOOD, 1)
        icon.line([(4, 24), (28, 24)], 1, ramp(DARK_WOOD))
        icon.line([(7, 11), (14, 9)], 1, ramp(DARK_WOOD))
        icon.rect((12, 8, 15, 10), ramp(DARK_IRON))
        icon.poly([(18, 13), (25, 9), (27, 11), (20, 14)], ramp(STEEL))
        icon.rect((14, 25, 18, 29), ramp(STEEL))
    elif kind == "storage_chest":
        icon.rect((3, 13, 29, 29), ramp(WOOD))
        icon.poly([(3, 13), (5, 6), (27, 6), (29, 13)], ramp("b07848"))
        for x in (6, 25):
            icon.rect((x, 6, x + 1, 29), ramp(BRONZE))
        icon.line([(3, 13), (29, 13)], 1, ramp(BRONZE))
        icon.rect((14, 12, 18, 17), ramp(GOLD))
        icon.put(16, 15, (40, 30, 30))
    elif kind == "torch":
        icon.line([(6, 29), (20, 12)], 2, ramp(WOOD))
        icon.line([(17, 15), (21, 11)], 3, ramp("6a4a2e"))
        fire(icon, 22, 11, 10, 4)
    return icon


# --- wall blocks: a front face with the material's own pattern under a
# lighter top face

WALLS = {
    "stone_wall_block": ("a8a5b2", "blocks"),
    "brick_wall": ("b8584a", "bricks"),
    "cobble_wall": ("a89e8e", "cobbles"),
    "dark_brick_wall": ("6a5868", "bricks"),
    "glass_wall": ("6a8ab0", "glass"),
    "heartstone_wall": ("c8404e", "veins"),
    "ice_wall": ("bfe8ff", "ice"),
    "marble_wall": ("ece8f0", "marble"),
    "mossy_wall": ("9a98a0", "moss"),
    "obsidian_wall": ("4a3e62", "obsidian"),
    "rootwood_wall": ("7a5236", "roots"),
    "ruined_wall_block": ("7d7986", "ruin"),
    "sandstone_wall": ("e0c088", "layers"),
    "timber_wall": ("e8dcc0", "timber"),
    "wooden_wall": ("8a6238", "planks"),
}


def wall_icon(kind):
    base, pattern = WALLS[kind]
    icon = Icon()
    tones = ramp(base)
    top = [(2, 7), (8, 2), (30, 2), (30, 7)] if pattern == "ruin" else [(2, 7), (8, 2), (30, 2), (30, 7)]
    front = icon.rect((2, 7, 30, 30), tones, gradient=0.5)
    icon.poly(top, [tones[0]] * 2 + [tones[1]] * 3, flat=True)
    mortar = tones[4]
    if pattern in ("bricks", "blocks", "layers"):
        h = 4 if pattern == "bricks" else 7 if pattern == "blocks" else 5
        w = 8 if pattern == "bricks" else 12
        for row, y in enumerate(range(7 + h, 30, h)):
            icon.line([(2, y), (30, y)], 1, [mortar] * 5)
        for row, y in enumerate(range(7, 30, h)):
            for x in range(2 + (row % 2) * (w // 2), 30, w):
                if x > 2:
                    icon.line([(x, y + 1), (x, min(y + h - 1, 29))], 1, [mortar] * 5)
                icon.put(x + 1, y + 1, tones[0])
        if pattern == "layers":
            icon.scatter(front, tones[3], 0.08, 4)
    elif pattern == "cobbles":
        r = random.Random(7)
        for y in range(8, 29, 6):
            x = 2 - r.randint(0, 3)
            while x < 30:
                w = r.randint(5, 8)
                icon.ellipse((x, y, x + w, y + 5), ramp(mix(c(base), (255, 255, 255) if r.random() < 0.4 else (60, 50, 60), r.random() * 0.2)))
                x += w + 1
    elif pattern == "glass":
        icon.rect((2, 7, 30, 30), ramp(DARK_IRON))
        cols = ["c8404a", "4a6ab0", "e8bc4a", "5a9a4a", "7a52c0", "4a6ab0"]
        i = 0
        for y in (9, 20):
            for x in (4, 13, 22):
                icon.rect((x, y, x + 6, y + 8), ramp(cols[i % 6]))
                icon.put(x + 1, y + 1, (255, 255, 255))
                i += 1
    elif pattern == "veins":
        icon.line([(4, 12), (12, 18), (10, 26)], 1, ramp("ff8a9a"))
        icon.line([(18, 9), (24, 16), (28, 14)], 1, ramp("ff8a9a"))
        icon.line([(16, 22), (26, 27)], 1, ramp("ff8a9a"))
        icon.sparkle(22, 20, (255, 200, 210))
    elif pattern == "ice":
        for x, y in ((4, 9), (16, 9), (10, 18), (22, 18), (4, 26)):
            icon.line([(x, y), (x + 8, y + 7)], 1, [c("ffffff")] * 5)
        icon.line([(2, 18), (30, 18)], 1, [tones[3]] * 5)
        icon.line([(15, 7), (15, 18)], 1, [tones[3]] * 5)
        icon.line([(9, 18), (9, 30)], 1, [tones[3]] * 5)
        icon.line([(21, 18), (21, 30)], 1, [tones[3]] * 5)
    elif pattern == "marble":
        icon.line([(3, 10), (10, 16), (8, 22), (14, 29)], 1, [c("a8a4b8")] * 5)
        icon.line([(20, 8), (24, 15), (30, 18)], 1, [c("b8b4c8")] * 5)
        icon.line([(16, 18), (2, 18)], 1, [c("c8c4d0")] * 5)
        icon.line([(16, 7), (16, 30)], 1, [tones[3]] * 5)
    elif pattern == "moss":
        for row, y in enumerate(range(13, 30, 6)):
            icon.line([(2, y), (30, y)], 1, [mortar] * 5)
        for row, y in enumerate(range(7, 30, 6)):
            for x in range(2 + (row % 2) * 5, 30, 10):
                if x > 2:
                    icon.line([(x, y + 1), (x, min(y + 5, 29))], 1, [mortar] * 5)
        moss = {(x, y) for x in range(2, 31) for y in range(2, 31) if y < 12 + 4 * math.sin(x * 0.7) or (x < 8 and y > 22)}
        icon.scatter(moss, c(MOSS), 0.7, 3)
        icon.scatter(moss, c("7ab04a"), 0.2, 4)
    elif pattern == "obsidian":
        for pts in ([(2, 14), (12, 10), (20, 16), (30, 12)], [(8, 30), (12, 20)], [(22, 30), (20, 16)]):
            icon.line(pts, 1, [c("2a2038")] * 5)
        icon.dots([(6, 10), (16, 22), (25, 9), (26, 25)], (160, 130, 220))
    elif pattern == "roots":
        for x in range(2, 30, 5):
            icon.line([(x, 7), (x, 30)], 1, [tones[4]] * 5)
        for pts in ([(2, 12), (10, 16), (18, 13), (30, 17)], [(4, 26), (14, 22), (26, 25)]):
            icon.line(pts, 2, ramp("5a3e26"))
        icon.dots([(9, 15), (22, 15), (14, 23)], (110, 180, 80))
    elif pattern == "ruin":
        for (x, y) in list(icon.colour):
            if y < 7 + max(0, 10 - abs(x - 22)) * 0.0 + (12 if x > 20 and y < 14 + (x - 20) else 0):
                pass
        cut = {(x, y) for (x, y) in icon.colour if x > 18 and y < 4 + (x - 18) * 1.2}
        for p in cut:
            del icon.colour[p]
            icon.part.pop(p, None)
        for row, y in enumerate(range(13, 30, 6)):
            icon.line([(2, y), (30, y)], 1, [mortar] * 5)
        icon.line([(10, 8), (13, 16), (11, 24)], 1, [c("2a2430")] * 5)
        icon.scatter(set(icon.colour), c(MOSS), 0.05, 2)
    elif pattern == "timber":
        for x in (2, 15, 28):
            icon.rect((x, 7, x + 2, 30), ramp(DARK_WOOD))
        icon.rect((2, 17, 30, 19), ramp(DARK_WOOD))
        icon.line([(4, 29), (14, 19)], 2, ramp(DARK_WOOD))
        icon.line([(18, 8), (27, 16)], 2, ramp(DARK_WOOD))
    elif pattern == "planks":
        for x in range(2, 31, 6):
            icon.line([(x, 7), (x, 30)], 1, [tones[4]] * 5)
        for x, y in ((5, 10), (11, 26), (17, 14), (23, 22), (28, 10)):
            icon.put(x, y, tones[4])
        for y in (11, 25):
            icon.line([(2, y), (30, y)], 1, ramp(DARK_IRON))
    return icon


# --- ground: a block of earth with the surface on top; floors: flat tiles

def turf_icon(top, soil="7a5434", kind="grass", detail=None):
    icon = Icon()
    icon.poly([(2, 14), (16, 22), (16, 31), (2, 23)], ramp(soil))
    icon.poly([(16, 22), (30, 14), (30, 23), (16, 31)], ramp(mix(c(soil), (20, 14, 30), 0.25)))
    face = icon.poly([(16, 6), (30, 14), (16, 22), (2, 14)], ramp(top))
    edge = {(x, y) for (x, y) in face if (x, y + 1) not in face}
    r = random.Random(hash(kind) & 0xffff)
    if kind == "grass":
        for x in range(3, 30, 2):
            y = 14 + round(abs(x - 16) * -0.57 + 8) if True else 0
        hang = {(x, y + dy) for (x, y) in edge for dy in (1, 2) if r.random() < 0.5}
        for p in hang:
            icon.put(*p, ramp(top)[2 if p[1] % 2 else 3], part=False)
        icon.scatter(face, ramp(top)[0], 0.18, 3)
        icon.scatter(face, ramp(top)[3], 0.12, 4)
    elif kind == "dots":
        icon.scatter(face, c(detail), 0.2, 5)
        icon.scatter(face, ramp(top)[0], 0.12, 6)
    elif kind == "mushrooms":
        icon.scatter(face, ramp(top)[3], 0.18, 7)
        for x, y in ((11, 12), (19, 11), (16, 16), (22, 15)):
            icon.put(x, y, c("e8dcc0"))
            icon.put(x, y - 1, c(detail))
            icon.put(x - 1, y - 1, c(detail))
            icon.put(x + 1, y - 1, c(detail))
    elif kind == "stones":
        for x, y in ((11, 12), (18, 10), (16, 16), (22, 14), (9, 15)):
            icon.ellipse((x - 2, y - 1, x + 2, y + 1), ramp(detail))
    elif kind == "flags":
        icon.line([(9, 10), (23, 18)], 1, [ramp(top)[4]] * 5)
        icon.line([(9, 18), (23, 10)], 1, [ramp(top)[4]] * 5)
        icon.line([(16, 6), (16, 22)], 1, [ramp(top)[4]] * 5)
        icon.scatter(face, ramp(top)[0], 0.1, 4)
    elif kind == "planks":
        for i in range(-3, 4):
            icon.line([(9 + i * 2 + 7, 6 + i * 2 + 4), (2 + i * 2 + 7, 10 + i * 2 + 4)], 1, [ramp(top)[4]] * 5)
    elif kind == "smooth":
        icon.scatter(face, ramp(top)[0], 0.15, 8)
        icon.scatter(face, ramp(top)[3], 0.06, 9)
    elif kind == "cracks":
        icon.line([(8, 12), (14, 15), (12, 18)], 1, [ramp(top)[4]] * 5)
        icon.line([(19, 10), (24, 14)], 1, [ramp(top)[4]] * 5)
        icon.scatter(face, ramp(top)[0], 0.1, 10)
    elif kind == "embers":
        icon.scatter(face, c("3a2a2a"), 0.2, 11)
        icon.dots([(10, 13), (18, 11), (21, 16), (14, 17)], (255, 130, 50))
    return icon


def floor_icon(base, kind):
    icon = Icon()
    tones = ramp(base)
    icon.rect((2, 2, 29, 29), tones, gradient=0.4)
    line = [tones[4]] * 5
    if kind == "plank":
        for y in range(2, 30, 5):
            icon.line([(2, y), (29, y)], 1, line)
        for row, y in enumerate(range(2, 30, 5)):
            x = 8 + (row * 11) % 20
            icon.line([(x, y), (x, y + 4)], 1, line)
            icon.put((x + 9) % 26 + 3, y + 2, tones[3])
    elif kind == "stone":
        for x, y in ((2, 15), (15, 2)):
            pass
        icon.line([(2, 15), (29, 15)], 1, line)
        icon.line([(15, 2), (15, 15)], 1, line)
        icon.line([(10, 15), (10, 29)], 1, line)
        icon.line([(22, 15), (22, 29)], 1, line)
        icon.scatter(set(icon.colour), tones[0], 0.08, 3)
    elif kind == "cobble":
        r = random.Random(5)
        for y in range(3, 28, 6):
            x = 2 - r.randint(0, 3)
            while x < 29:
                w = r.randint(4, 7)
                icon.ellipse((max(x, 2), y, min(x + w, 29), y + 5), ramp(mix(c(base), (255, 255, 255), r.random() * 0.2)))
                x += w + 1
    elif kind == "sand":
        icon.line([(2, 11), (29, 11)], 1, line)
        icon.line([(2, 20), (29, 20)], 1, line)
        for row, y in enumerate((2, 11, 20)):
            for x in range(2 + (row % 2) * 7, 29, 14):
                icon.line([(x, y), (x, y + 9)], 1, line)
        icon.scatter(set(icon.colour), tones[3], 0.07, 4)
    elif kind == "moss":
        icon.line([(2, 15), (29, 15)], 1, line)
        icon.line([(15, 2), (15, 29)], 1, line)
        icon.scatter(set(icon.colour), c("7ab04a"), 0.25, 5)
        icon.dots([(6, 6), (22, 9), (9, 22), (24, 24)], (240, 230, 140))
    elif kind == "snow":
        icon.line([(2, 15), (29, 15)], 1, [tones[3]] * 5)
        icon.line([(15, 2), (15, 29)], 1, [tones[3]] * 5)
        icon.scatter(set(icon.colour), (255, 255, 255), 0.2, 6)
    return icon


def sack_icon(colour="c8b080", fill="e0c890"):
    icon = Icon()
    icon.poly([(8, 9), (24, 9), (28, 20), (26, 29), (6, 29), (4, 20)], ramp("b89a6a"))
    icon.poly([(11, 3), (21, 3), (19, 9), (13, 9)], ramp("b89a6a"))
    icon.line([(11, 9), (21, 9)], 1, ramp(DARK_LEATHER))
    icon.ellipse((10, 1, 22, 6), ramp(fill))
    icon.line([(10, 18), (22, 18)], 1, ramp("8a7050"))
    return icon


def bucket_icon(liquid="5a8ac8"):
    icon = Icon()
    icon.ring((5, 2, 27, 22), 1, ramp(DARK_IRON))
    icon.poly([(5, 11), (27, 11), (24, 29), (8, 29)], ramp(WOOD))
    for y in (15, 25):
        icon.line([(6, y), (26, y)], 1, ramp(DARK_IRON))
    icon.ellipse((5, 9, 27, 14), ramp(liquid))
    icon.put(10, 11, (220, 240, 255))
    return icon


# ======================================================================
# Relics, charms, pet and mount gear
# ======================================================================

def relic_icon(kind):
    icon = Icon()
    if kind == "bloodvine":
        icon.line([(16, 1), (16, 7)], 1, ramp(GOLD))
        icon.ellipse((5, 8, 17, 20), ramp(GOLD))
        icon.ellipse((15, 8, 27, 20), ramp(GOLD))
        icon.poly([(6, 16), (26, 16), (16, 29)], ramp(GOLD))
        icon.ellipse((9, 11, 16, 18), ramp(HEART))
        icon.ellipse((16, 11, 23, 18), ramp(HEART))
        icon.poly([(10, 16), (22, 16), (16, 24)], ramp(HEART))
        icon.line([(3, 22), (8, 14), (6, 8), (12, 4)], 1, ramp("4a7a3a"))
        icon.line([(29, 22), (24, 27), (19, 28)], 1, ramp("4a7a3a"))
        icon.put(4, 15, c("e05060"))
        icon.put(27, 25, c("e05060"))
    elif kind == "ember_heart":
        icon.ellipse((5, 9, 17, 21), ramp(EMBER))
        icon.ellipse((15, 9, 27, 21), ramp(EMBER))
        icon.poly([(6, 17), (26, 17), (16, 30)], ramp(EMBER))
        icon.ellipse((11, 13, 21, 22), ramp("ffd060"))
        icon.dots([(9, 14), (22, 15), (16, 25), (13, 19)], (60, 30, 30))
        fire(icon, 11, 9, 6, 2)
        fire(icon, 21, 9, 8, 2)
    elif kind == "frostbound_eye":
        icon.poly([(16, 1), (27, 8), (30, 20), (22, 30), (10, 30), (2, 20), (5, 8)], ramp(FROST))
        icon.ellipse((7, 10, 25, 22), ramp("f4f8ff"))
        icon.ellipse((12, 11, 20, 21), ramp("3a7ac8"))
        icon.ellipse((14, 13, 18, 19), [c("101828")] * 5, rim=False)
        icon.put(13, 12, (255, 255, 255))
        for x, y in ((5, 8), (27, 8), (16, 1), (10, 30)):
            icon.sparkle(x, y, (230, 250, 255))
    elif kind == "gale_feather":
        feather = icon.poly([(5, 29), (10, 20), (18, 9), (27, 2), (24, 12), (16, 22), (8, 29)], ramp("b8e8e0"))
        icon.line([(5, 29), (25, 5)], 1, ramp("6ab0b0"))
        for x, y in ((12, 17), (16, 12), (20, 8)):
            icon.put(x + 2, y + 2, ramp("b8e8e0")[3])
        for pts in ([(2, 10), (8, 8), (12, 10)], [(19, 24), (26, 22), (30, 25)], [(1, 17), (5, 16)]):
            icon.line(pts, 1, [c("e8fff8")] * 5)
            for p in pts:
                icon.no_outline.add(p)
    elif kind == "gilded_idol":
        icon.rect((8, 25, 24, 30), ramp(DARK_STONE))
        icon.poly([(11, 13), (21, 13), (23, 25), (9, 25)], ramp(GOLD))
        icon.ellipse((11, 3, 21, 13), ramp(GOLD))
        icon.poly([(9, 6), (12, 1), (13, 5)], ramp(GOLD))
        icon.poly([(23, 6), (20, 1), (19, 5)], ramp(GOLD))
        icon.dots([(14, 8), (18, 8)], (200, 40, 60))
        icon.line([(7, 15), (11, 19)], 2, ramp(GOLD))
        icon.line([(25, 15), (21, 19)], 2, ramp(GOLD))
        icon.sparkle(25, 3)
    elif kind == "grave_lantern":
        icon.ring((11, 0, 21, 8), 1, ramp(DARK_IRON))
        icon.rect((8, 6, 24, 9), ramp(DARK_IRON))
        icon.rect((9, 9, 23, 26), ramp(DARK_IRON))
        icon.rect((11, 11, 21, 24), ramp("8affb0"))
        icon.ellipse((13, 13, 19, 21), ramp("e0fff0"))
        icon.dots([(15, 16), (17, 16)], (30, 60, 40))
        icon.rect((7, 26, 25, 29), ramp(DARK_IRON))
        icon.line([(16, 9), (16, 26)], 1, ramp(DARK_IRON))
    elif kind == "hearthstone":
        icon.poly([(16, 1), (25, 9), (27, 22), (17, 30), (6, 24), (5, 10)], ramp("e08a4a"))
        icon.poly([(16, 1), (25, 9), (16, 15), (5, 10)], ramp("f0b070"))
        icon.line([(12, 15), (16, 11), (20, 15), (16, 23), (12, 15)], 1, [c("fff0c0")] * 5)
        icon.put(16, 16, (255, 250, 220))
    elif kind == "ironroot":
        icon.ellipse((9, 4, 23, 20), ramp(IRON))
        icon.line([(16, 4), (16, 19)], 1, ramp(DARK_IRON))
        for pts in ([(12, 18), (8, 24), (3, 26)], [(16, 19), (16, 25), (13, 30)], [(20, 18), (24, 23), (29, 24)]):
            icon.line(pts, 1, ramp("8a6a4a"))
        leaf(icon, 16, 4, 1, -1, "6ab040", 5)
        icon.put(12, 8, (230, 236, 244))
    elif kind == "moonlit_bell":
        icon.poly([(10, 8), (22, 8), (25, 22), (28, 25), (4, 25), (7, 22)], ramp(SILVER))
        icon.ellipse((10, 4, 22, 12), ramp(SILVER))
        icon.ring((13, 0, 19, 6), 1, ramp(SILVER))
        icon.ellipse((13, 24, 19, 30), ramp(DARK_IRON))
        icon.ellipse((12, 12, 20, 20), ramp("c8d8ff"))
        icon.ellipse((15, 11, 21, 18), ramp(SILVER))
        icon.sparkle(27, 6, (220, 230, 255))
    elif kind == "stormheart":
        for i, y in enumerate(range(6, 27, 4)):
            icon.ellipse((7, y, 25, y + 4), ramp(COPPER))
        icon.rect((14, 2, 18, 30), ramp(DARK_IRON))
        icon.line([(20, 1), (14, 9), (19, 12), (11, 22), (15, 24), (9, 31)], 1, [c("fff4a0")] * 5)
        icon.sparkle(25, 6, (255, 250, 200))
    elif kind == "tidewalker":
        icon.poly([(16, 2), (28, 10), (26, 22), (16, 30), (6, 22), (4, 10)], ramp("3ab0a0"))
        icon.poly([(16, 6), (24, 11), (23, 20), (16, 25), (9, 20), (8, 11)], ramp("4ac8c0"))
        for y in (12, 17, 22):
            icon.line([(9, y), (12, y - 2), (15, y), (18, y - 2), (21, y), (23, y - 2)], 1, [c("d8fff8")] * 5)
        icon.put(11, 8, (255, 255, 255))
    elif kind == "void_lens":
        icon.ring((4, 4, 26, 26), 3, ramp(GOLD))
        icon.ellipse((7, 7, 23, 23), ramp("3a2a6a"))
        icon.ellipse((10, 10, 20, 20), ramp(VOID))
        icon.ellipse((13, 13, 17, 17), [c("e8d8ff")] * 5, rim=False)
        icon.line([(24, 24), (30, 30)], 2, ramp(GOLD))
        icon.put(10, 9, (255, 255, 255))
    return icon


def charm_icon(kind):
    icon = Icon()
    icon.line([(6, 1), (16, 8), (26, 1)], 1, ramp(CLOTH_RED if kind == "heart" else "c8a870"))
    icon.ring((13, 6, 19, 12), 1, ramp(GOLD))
    if kind == "heart":
        icon.ellipse((6, 11, 17, 22), ramp("f07080"))
        icon.ellipse((15, 11, 26, 22), ramp("f07080"))
        icon.poly([(7, 18), (25, 18), (16, 29)], ramp("f07080"))
        icon.put(10, 14, (255, 230, 235))
    elif kind == "lucky":
        for x, y in ((11, 15), (21, 15), (11, 24), (21, 24)):
            icon.ellipse((x - 5, y - 5, x + 5, y + 5), ramp("6ac050"))
        icon.line([(16, 20), (22, 30)], 1, ramp("4a8a3a"))
        icon.ellipse((14, 18, 18, 22), ramp(GOLD))
    else:
        icon.poly([(16, 12), (29, 13), (25, 18), (28, 22), (16, 24)], ramp("9ad0f0"))
        icon.poly([(16, 12), (3, 13), (7, 18), (4, 22), (16, 24)], ramp("b8e0f8"))
        icon.ellipse((13, 12, 19, 26), ramp(SILVER))
    return icon


def collar_icon(band, buckle=GOLD, tag=None, spikes=False):
    icon = Icon()
    icon.ring((2, 5, 30, 27), 4, ramp(band))
    icon.rect((13, 22, 19, 28), ramp(buckle))
    icon.rect((15, 24, 17, 26), [c("2a1e1a")] * 5, flat=True)
    if tag:
        icon.ring((14, 26, 18, 30), 1, ramp(buckle))
        icon.ellipse((12, 28, 20, 32), ramp(tag))
    if spikes:
        for x, y in ((4, 9), (2, 16), (5, 22), (28, 9), (30, 16), (27, 22), (10, 4), (22, 4), (16, 3)):
            icon.put(x, y, c(STEEL))
            icon.put(x + (1 if x < 16 else -1 if x > 16 else 0), y, ramp(STEEL)[3])
    return icon


def saddle_icon(leather, trim, emblem=None, light=False):
    """A saddle from the side: a low horn at the front, the seat dipping to
    the raised cantle, the skirt hanging below with the stirrup."""
    icon = Icon()
    icon.rect((1, 15, 31, 19), ramp(trim if light else CLOTH_BLUE))
    skirt = icon.poly([(6, 17), (26, 17), (25, 27), (7, 27)], ramp(mix(c(leather), (30, 20, 20), 0.2)))
    for (x, y) in skirt:
        if (x - 1, y) not in skirt or (x + 1, y) not in skirt or (x, y + 1) not in skirt:
            continue
        if (x - 2, y) not in skirt or (x + 2, y) not in skirt or (x, y + 2) not in skirt:
            if (x + y) % 2 == 0:
                icon.colour[(x, y)] = ramp(trim)[1]
    icon.poly([(2, 15), (3, 11), (6, 9), (8, 12), (16, 14), (23, 12), (27, 7), (30, 7), (30, 12), (27, 16), (3, 17)], ramp(leather))
    icon.line([(8, 13), (16, 15), (23, 13)], 1, [ramp(leather)[0]] * 5)
    icon.line([(3, 16), (28, 16)], 1, ramp(trim))
    if light:
        icon.line([(12, 19), (12, 25)], 1, ramp(DARK_LEATHER))
        icon.ring((9, 24, 15, 30), 1, ramp(SILVER))
    else:
        icon.line([(12, 19), (12, 26)], 1, ramp(DARK_LEATHER))
        icon.poly([(9, 26), (15, 26), (16, 31), (8, 31)], ramp(STEEL))
        icon.rect((10, 28, 14, 30), [c("1a1420")] * 5, flat=True, rim=False)
    if emblem:
        icon.ellipse((17, 19, 23, 25), ramp(emblem))
        icon.put(19, 21, (255, 220, 220))
    return icon


def barding_icon(kind):
    icon = Icon()
    if kind == "padded":
        icon.poly([(3, 5), (29, 5), (29, 22), (24, 27), (8, 27), (3, 22)], ramp("c8b48a"))
        for x in range(7, 28, 5):
            icon.line([(x, 6), (x - 3, 26)], 1, [ramp("c8b48a")[3]] * 5)
        for y in (11, 17, 23):
            icon.line([(4, y), (28, y)], 1, [ramp("c8b48a")[3]] * 5)
        icon.rect((3, 5, 29, 8), ramp(CLOTH_RED))
        for x in (6, 12, 20, 26):
            icon.put(x, 29, c(CLOTH_RED))
            icon.put(x, 28, c(CLOTH_RED))
        return icon
    metal = IRON if kind == "iron" else "e0606a"
    # a chanfron: the plate over a horse's face
    icon.poly([(10, 2), (22, 2), (25, 8), (22, 26), (16, 31), (10, 26), (7, 8)], ramp(metal))
    icon.poly([(7, 8), (2, 2), (4, 12)], ramp(metal))
    icon.poly([(25, 8), (30, 2), (28, 12)], ramp(metal))
    icon.line([(16, 3), (16, 28)], 1, ramp(DARK_IRON if kind == "iron" else HEART_DARK))
    icon.ellipse((9, 10, 13, 14), [c("1a1420")] * 5, rim=False)
    icon.ellipse((19, 10, 23, 14), [c("1a1420")] * 5, rim=False)
    if kind == "heartsteel":
        icon.ellipse((13, 15, 19, 21), ramp(GOLD))
        icon.ellipse((14, 16, 18, 20), ramp(HEART))
        icon.poly([(14, 2), (18, 2), (17, 0), (15, 0)], ramp(GOLD))
    else:
        for x, y in ((10, 5), (22, 5), (12, 24), (20, 24)):
            icon.put(x, y, ramp(IRON)[0])
    return icon


# ======================================================================
# Everything else
# ======================================================================

def token_icon(face, emblem):
    icon = Icon()
    icon.ellipse((3, 3, 29, 29), ramp(face))
    icon.ring((5, 5, 27, 27), 1, [ramp(face)[3]] * 5)
    emblem(icon)
    return icon


def satchel_bottomless():
    icon = Icon()
    icon.poly([(5, 11), (27, 11), (29, 28), (3, 28)], ramp(NAVY))
    icon.ring((9, 1, 23, 15), 2, ramp(BRONZE))
    icon.ellipse((6, 8, 26, 16), ramp("120c22"))
    icon.ring((9, 9, 23, 15), 1, ramp(VOID))
    icon.put(16, 12, (230, 210, 255))
    icon.rect((13, 18, 19, 23), ramp(BRONZE))
    icon.put(16, 20, c(VOID))
    for x, y in ((4, 6), (28, 6), (25, 2)):
        icon.sparkle(x, y, (200, 170, 255))
    return icon


def map_icon():
    icon = Icon()
    icon.poly([(3, 6), (12, 3), (20, 6), (29, 3), (29, 26), (20, 29), (12, 26), (3, 29)], ramp("e8d8a8"))
    icon.line([(12, 4), (12, 26)], 1, [ramp("e8d8a8")[3]] * 5)
    icon.line([(20, 6), (20, 28)], 1, [ramp("e8d8a8")[3]] * 5)
    for x, y in ((6, 23), (8, 20), (11, 18), (14, 17), (17, 15), (19, 12)):
        icon.put(x, y, (140, 90, 60))
    for d in (-2, -1, 0, 1, 2):
        icon.put(23 + d, 10 + d, (200, 40, 50))
        icon.put(23 + d, 10 - d, (200, 40, 50))
    icon.dots([(6, 9), (7, 9), (6, 10), (25, 22), (26, 21)], (90, 140, 70))
    return icon


def boat_icon():
    icon = Icon()
    icon.poly([(1, 16), (31, 16), (26, 25), (6, 25)], ramp(WOOD))
    icon.line([(2, 16), (30, 16)], 1, ramp(PALE_WOOD))
    icon.line([(4, 20), (28, 20)], 1, [ramp(WOOD)[3]] * 5)
    icon.rect((14, 13, 18, 16), ramp(DARK_WOOD))
    icon.line([(8, 6), (20, 26)], 1, ramp(PALE_WOOD))
    icon.ellipse((18, 24, 23, 30), ramp(PALE_WOOD))
    icon.line([(29, 27), (23, 29)], 1, [c("8ac8f0")] * 5)
    icon.line([(2, 28), (8, 27)], 1, [c("8ac8f0")] * 5)
    return icon


def bandage_icon():
    icon = Icon()
    icon.poly([(4, 24), (16, 16), (24, 24), (12, 30)], ramp("f4f0e8"))
    icon.ellipse((14, 4, 30, 20), ramp("f4f0e8"))
    icon.ellipse((19, 9, 25, 15), ramp("d8d0c0"))
    icon.rect((7, 21, 12, 25), ramp(CLOTH_RED))
    icon.line([(16, 16), (6, 22)], 1, [c("d8d0c0")] * 5)
    return icon


# ======================================================================
# Things added with the comforts, the orphanage, the monster town and the
# gates (one builder for all of them, by item id)
# ======================================================================

def new_thing_icon(kind):
    icon = Icon()
    if kind == "bedroll":
        # A blanket rolled tight, tied with two leather straps, a carry loop.
        icon.ellipse((3, 11, 13, 25), ramp(CLOTH_RED))
        icon.poly([(8, 11), (25, 9), (29, 17), (26, 25), (8, 25)], ramp(CLOTH_RED))
        icon.ellipse((24, 9, 30, 25), ramp("d86a6a"))
        icon.ellipse((25, 13, 29, 21), ramp("8a2c37"))
        for x in (12, 20):
            icon.rect((x, 10, x + 2, 26), ramp(DARK_LEATHER))
            icon.put(x + 1, 18, c(BRONZE))
        icon.line([(13, 10), (16, 4), (21, 4), (21, 10)], 1, ramp(LEATHER))
        icon.line([(6, 14), (6, 22)], 1, [c("f0c8b0")] * 5)
    elif kind == "lull_doll":
        # A rag doll: yarn hair in two plaits, button eyes, a stitched
        # mouth, a white smock with an apron, and "31" stitched on it.
        icon.line([(9, 17), (4, 22)], 3, ramp("f0e6d2"))
        icon.line([(23, 17), (28, 22)], 3, ramp("f0e6d2"))
        icon.poly([(10, 15), (22, 15), (25, 29), (7, 29)], ramp("f4f0e8"))
        icon.rect((11, 20, 21, 28), ramp("e0dccf"), rim=False)
        icon.line([(12, 29), (12, 31)], 2, ramp("f0e6d2"))
        icon.line([(19, 29), (19, 31)], 2, ramp("f0e6d2"))
        icon.ellipse((9, 2, 23, 16), ramp("f0e0c8"))
        icon.line([(9, 6), (7, 14), (8, 18)], 2, ramp("8a5a34"))
        icon.line([(23, 6), (25, 14), (24, 18)], 2, ramp("8a5a34"))
        icon.poly([(9, 7), (12, 2), (20, 2), (23, 7), (16, 5)], ramp("8a5a34"))
        for x in (12, 19):
            icon.put(x, 9, c("2a2226"))
            icon.put(x + 1, 9, c("2a2226"))
            icon.put(x, 10, c("2a2226"))
            icon.put(x + 1, 10, c("4a4652"))
        icon.put(15, 13, c("a83040"))
        icon.put(16, 13, c("a83040"))
        icon.put(17, 12, c("a83040"))
        icon.put(14, 12, c("a83040"))
        # "31", stitched in red on the apron.
        for x, y in ((13, 22), (14, 22), (15, 23), (14, 24), (15, 25), (13, 26), (14, 26), (18, 22), (18, 23), (18, 24), (18, 25), (18, 26), (17, 23)):
            icon.put(x, y, c("a83040"))
        icon.dots([(10, 17), (21, 17)], c("b0aa9c"))
    elif kind == "noble_mask":
        # A Court mask: smooth white porcelain, one upright slit for an eye,
        # red tears painted beneath, gilt at the brow, black ribbons.
        icon.line([(4, 13), (1, 22)], 2, ramp("2a2632"))
        icon.line([(28, 13), (31, 22)], 2, ramp("2a2632"))
        icon.ellipse((5, 2, 27, 31), ramp("f4f0ea"))
        icon.ellipse((9, 5, 23, 15), ramp("fbf8f2"), rim=False, flat=True)
        icon.line([(10, 4), (16, 3), (22, 4)], 1, ramp(GOLD))
        icon.put(16, 4, c("f8e6a0"))
        icon.line([(16, 9), (16, 19)], 2, [c("141218")] * 5, rim=False)
        icon.put(16, 8, c("2a2632"))
        icon.put(16, 20, c("2a2632"))
        for x, top, bottom in ((12, 18, 26), (20, 18, 25), (14, 21, 28)):
            icon.line([(x, top), (x, bottom)], 1, [c("b82838")] * 5, rim=False)
            icon.put(x, bottom + 1, c("8a1c2a"))
        icon.line([(11, 27), (16, 29), (21, 27)], 1, [c("d8d2c6")] * 5, rim=False)
        icon.dots([(8, 10), (9, 8)], c("ffffff"))
    elif kind == "matron_lantern":
        # The Matron's lantern: a brass cage with four panes, a white-hot
        # flame, a ring and hook above, and a white ribbon tied on.
        icon.ring((11, 0, 21, 8), 2, ramp(BRONZE))
        icon.poly([(8, 9), (24, 9), (21, 6), (11, 6)], ramp(BRONZE))
        icon.rect((9, 10, 23, 26), ramp("fff0c0"))
        icon.ellipse((12, 13, 20, 24), ramp("ffe080"), rim=False)
        icon.poly([(16, 12), (19, 19), (16, 23), (13, 19)], [c("ffffff"), c("fffbe8"), c("fff4c8"), c("ffe8a0"), c("f0c060")], rim=False)
        icon.put(16, 18, c("ffffff"))
        for x in (9, 23):
            icon.line([(x, 10), (x, 26)], 1, ramp(BRONZE))
        icon.line([(10, 17), (12, 17)], 1, ramp(BRONZE))
        icon.line([(20, 17), (22, 17)], 1, ramp(BRONZE))
        icon.rect((7, 25, 25, 29), ramp(BRONZE))
        icon.line([(8, 26), (24, 26)], 1, [c("f0c878")] * 5, rim=False)
        icon.line([(23, 11), (28, 15), (27, 20)], 1, ramp("f4f0ea"))
        icon.line([(23, 11), (26, 17)], 1, ramp("e0dccf"))
        for x, y in ((4, 14), (28, 5), (5, 27)):
            icon.sparkle(x, y, (255, 230, 160))
    elif kind.startswith("gate_key_"):
        # A gate key: a long black-iron key, its bow a ring holding a cut
        # crystal in the rank's colour, light coming off the crystal.
        crystal = {"e": "a8a8b0", "d": "7ad07a", "c": "6aa8f0", "b": "b07af0", "a": "f0a050", "s": "f05a4a"}[kind[-1]]
        icon.line([(13, 18), (27, 4)], 3, ramp("3a3644"))
        icon.line([(14, 17), (26, 5)], 1, ramp("6a6478"))
        icon.rect((22, 6, 26, 8), ramp("3a3644"))
        icon.rect((24, 9, 28, 11), ramp("3a3644"))
        icon.ring((2, 15, 17, 30), 3, ramp("4a4652"))
        icon.poly([(9, 18), (13, 22), (9, 27), (5, 22)], ramp(crystal))
        icon.put(8, 20, c("ffffff"))
        icon.put(9, 21, c("ffffff"))
        for x, y in ((3, 13), (17, 14), (16, 29)):
            icon.sparkle(x, y, tuple(min(255, v + 60) for v in c(crystal)))
    elif kind == "benefactor_pen":
        # The Benefactor's pen: a long black quill with a cut gilt nib, a
        # drop of ink, and a little brass key tied on with thread.
        icon.poly([(26, 2), (29, 3), (18, 17), (11, 22), (9, 21), (14, 14)], ramp("3a3644"))
        icon.line([(27, 3), (11, 21)], 1, ramp("6a6478"))
        for k in range(4):
            icon.put(24 - k * 3, 8 + k * 3, c("5a5664"))
        icon.line([(11, 21), (5, 27)], 2, ramp(GOLD))
        icon.put(4, 28, c("2a2226"))
        icon.put(5, 28, c("6a5a2a"))
        icon.ellipse((2, 28, 6, 32), ramp("1e2a4a"))
        icon.line([(14, 20), (19, 25)], 1, [c("c8b890")] * 5, rim=False)
        icon.ring((18, 23, 23, 28), 1, ramp(BRONZE))
        icon.line([(22, 27), (27, 29)], 2, ramp(BRONZE))
        icon.put(26, 30, c("8a6030"))
        icon.put(27, 30, c("8a6030"))
    return icon


def treat_icon():
    icon = Icon()
    icon.ellipse((2, 6, 13, 17), ramp("d8a060"))
    icon.ellipse((2, 15, 13, 26), ramp("d8a060"))
    icon.ellipse((19, 6, 30, 17), ramp("d8a060"))
    icon.ellipse((19, 15, 30, 26), ramp("d8a060"))
    icon.rect((7, 10, 25, 22), ramp("d8a060"))
    icon.dots([(12, 14), (17, 13), (21, 17), (15, 18)], (150, 90, 50))
    return icon


def dust_icon():
    icon = Icon()
    icon.poly([(10, 14), (22, 14), (27, 22), (24, 29), (8, 29), (5, 22)], ramp("8a6ab0"))
    icon.rect((12, 10, 20, 15), ramp("8a6ab0"))
    icon.line([(11, 14), (21, 14)], 1, ramp(GOLD))
    for x, y in ((8, 6), (16, 3), (23, 7), (13, 8), (19, 10)):
        icon.put(x, y, (240, 220, 255), part=False)
        icon.no_outline.add((x, y))
    icon.sparkle(25, 3, (240, 220, 255))
    icon.sparkle(6, 2, (240, 220, 255))
    return icon


def essence_icon():
    icon = Icon()
    icon.ellipse((6, 8, 26, 28), ramp("7ae0c8"))
    icon.ellipse((10, 12, 22, 24), ramp("c8fff0"))
    icon.poly([(12, 9), (16, 1), (20, 9)], ramp("7ae0c8"))
    icon.ellipse((14, 15, 18, 19), [c("ffffff")] * 5, rim=False)
    for x, y in ((3, 6), (28, 10), (4, 26), (27, 27)):
        icon.sparkle(x, y, (200, 255, 240))
    return icon


def crystal_cluster(colour, glow, small=False):
    icon = Icon()
    shards = [(16, 2, 4, 29), (9, 9, 3, 29), (23, 10, 3, 29), (4, 18, 2, 29), (28, 19, 2, 29)]
    if small:
        shards = shards[:3]
    icon.ellipse((3, 25, 29, 31), ramp(DARK_STONE))
    for x, top, w, bottom in sorted(shards, key=lambda s: -abs(s[0] - 16)):
        icon.poly([(x - w, bottom - 2), (x - w, top + w + 2), (x, top), (x + w, top + w + 2), (x + w, bottom - 2)], ramp(colour))
        icon.line([(x - 1, top + 3), (x - 1, bottom - 4)], 1, [c(glow)] * 5)
    return icon


def heart_stone_icon(colour, cracks=None, facets=True):
    icon = Icon()
    icon.ellipse((3, 5, 17, 19), ramp(colour))
    icon.ellipse((15, 5, 29, 19), ramp(colour))
    icon.poly([(4, 14), (28, 14), (16, 29)], ramp(colour))
    if facets:
        icon.line([(7, 9), (12, 15), (16, 11), (20, 15), (25, 9)], 1, [ramp(colour)[0]] * 5)
        icon.line([(12, 15), (16, 25), (20, 15)], 1, [ramp(colour)[3]] * 5)
        icon.put(8, 8, (255, 255, 255))
    if cracks:
        icon.line([(10, 8), (13, 14), (11, 19)], 1, [c(cracks)] * 5)
        icon.line([(21, 9), (19, 16), (23, 20)], 1, [c(cracks)] * 5)
    return icon


def trophy_cup_icon():
    icon = Icon()
    icon.poly([(7, 3), (25, 3), (23, 13), (18, 17), (14, 17), (9, 13)], ramp(GOLD))
    icon.ring((1, 4, 10, 13), 2, ramp(GOLD))
    icon.ring((22, 4, 31, 13), 2, ramp(GOLD))
    icon.rect((14, 17, 18, 23), ramp(GOLD))
    icon.rect((8, 23, 24, 29), ramp(DARK_WOOD))
    icon.ellipse((13, 6, 19, 12), ramp(HEART))
    icon.put(14, 7, (255, 220, 220))
    icon.sparkle(5, 1, (255, 250, 220))
    return icon


def sigil_icon():
    icon = Icon()
    icon.line([(8, 1), (16, 6), (24, 1)], 1, ramp("4a3a5e"))
    icon.poly([(16, 5), (28, 17), (16, 30), (4, 17)], ramp("4a3a5e"))
    icon.poly([(16, 9), (24, 17), (16, 26), (8, 17)], ramp("c08cff"))
    icon.ellipse((11, 14, 21, 20), ramp("f0e0ff"))
    icon.ellipse((14, 14, 18, 20), [c("2a1040")] * 5, rim=False)
    return icon


def plate_fragment_icon():
    icon = Icon()
    icon.poly([(4, 6), (22, 3), (29, 12), (26, 27), (14, 30), (6, 22), (9, 15)], ramp("b83040"))
    icon.line([(6, 9), (22, 6), (27, 13)], 1, ramp("e8707a"))
    for x, y in ((9, 10), (21, 9), (24, 22), (13, 25)):
        icon.put(x, y, c(GOLD))
    icon.line([(15, 12), (18, 20), (15, 26)], 1, [c("4a1020")] * 5)
    return icon


def silk_icon():
    icon = Icon()
    icon.ellipse((6, 8, 26, 28), ramp("e8e8f4"))
    for i in range(5):
        icon.line([(7 + i * 4, 9 + i), (24 - i * 2, 27 - i * 3)], 1, [ramp("e8e8f4")[3]] * 5)
    icon.line([(25, 12), (30, 4)], 1, [c("f4f4ff")] * 5)
    icon.line([(8, 25), (2, 30)], 1, [c("f4f4ff")] * 5)
    return icon


def wing_icon():
    icon = Icon()
    icon.poly([(3, 6), (12, 4), (29, 10), (25, 15), (27, 19), (21, 20), (22, 26), (15, 23), (12, 28), (8, 20)], ramp("5a4a5e"))
    for pts in ([(3, 6), (25, 15)], [(4, 7), (21, 20)], [(5, 8), (15, 23)]):
        icon.line(pts, 1, ramp("3a2e40"))
    icon.poly([(1, 3), (5, 3), (4, 8)], ramp("3a2e40"))
    return icon


def scales_icon(colour):
    icon = Icon()
    for row, y in enumerate((5, 12, 19)):
        for x in range(4 + (row % 2) * 5, 26, 10):
            icon.ellipse((x, y, x + 10, y + 10), ramp(colour))
            icon.put(x + 3, y + 2, ramp(colour)[0])
    return icon


def carapace_icon(colour, segments=4, claw=False):
    icon = Icon()
    if claw:
        icon.ellipse((3, 8, 29, 28), ramp(colour))
        icon.poly([(3, 12), (6, 2), (12, 8)], ramp(colour))
        icon.poly([(29, 12), (26, 2), (20, 8)], ramp(colour))
        icon.dots([(11, 15), (21, 15), (16, 21), (9, 22), (23, 22)], ramp(colour)[0])
        return icon
    for i in range(segments):
        y = 4 + i * 6
        w = 12 - abs(i - segments / 2.0 + 0.5) * 2
        icon.ellipse((16 - w, y, 16 + w, y + 9), ramp(colour))
    icon.line([(16, 5), (16, 28)], 1, [ramp(colour)[0]] * 5)
    return icon


def tongue_icon():
    icon = Icon()
    icon.line([(4, 28), (8, 18), (16, 14), (24, 18), (24, 25), (18, 26), (17, 21)], 4, ramp("c05a6a"))
    icon.line([(6, 25), (9, 18), (16, 15)], 1, [c("e88a9a")] * 5)
    icon.ellipse((14, 18, 20, 24), ramp("c05a6a"))
    return icon


def stinger_icon():
    icon = Icon()
    pts = [(4, 28), (8, 22), (10, 14), (14, 8), (21, 5), (26, 8)]
    for i, (x, y) in enumerate(pts):
        r = 4 - i * 0.4
        icon.ellipse((x - r, y - r, x + r, y + r), ramp("d8b070"))
    icon.poly([(25, 6), (30, 11), (26, 12)], ramp("4a3a2a"))
    icon.put(29, 12, (200, 240, 120))
    return icon


def husk_icon():
    icon = Icon()
    icon.poly([(4, 10), (14, 3), (27, 7), (29, 20), (20, 29), (8, 25)], ramp("b8a070"))
    icon.poly([(9, 12), (15, 8), (22, 11), (21, 20), (13, 22)], ramp("4a3a2a"))
    icon.line([(4, 10), (13, 14)], 1, ramp("e0d0a0"))
    icon.line([(27, 7), (22, 13)], 1, ramp("e0d0a0"))
    icon.scatter(set(icon.colour), c("7a6040"), 0.08, 4)
    return icon


def core_icon(shell, glow, hot):
    icon = Icon()
    icon.ellipse((4, 4, 28, 28), ramp(shell))
    for pts in ([(8, 10), (14, 14), (12, 22)], [(22, 6), (18, 13), (25, 18)], [(14, 26), (18, 19)]):
        icon.line(pts, 2, ramp(glow))
    icon.ellipse((12, 12, 20, 20), ramp(hot))
    icon.put(15, 14, (255, 250, 220))
    return icon


def whistle_emblem(colour, shape):
    def draw(icon):
        if shape == "horse":
            icon.dots([(19, 16), (20, 15), (21, 15), (22, 16), (21, 17), (20, 18), (20, 19), (22, 19)], colour)
        elif shape == "star":
            icon.dots([(20, 16), (21, 15), (21, 17), (22, 16), (19, 16), (21, 16)], colour)
        elif shape == "sun":
            icon.dots([(20, 17), (21, 17), (20, 18), (21, 18), (19, 15), (22, 15), (19, 20), (22, 20), (18, 17), (23, 18)], colour)
    return draw


def elk_horn_icon():
    icon = Icon()
    icon.poly([(3, 24), (8, 18), (17, 12), (25, 5), (29, 3), (28, 10), (20, 18), (11, 25), (5, 28)], ramp("c0e8ff"))
    icon.ellipse((24, 1, 31, 10), ramp("e0f4ff"))
    icon.ellipse((26, 3, 29, 7), [c("2a3a50")] * 5, rim=False)
    for x, y in ((10, 21), (16, 16), (21, 11)):
        icon.line([(x - 1, y - 1), (x + 2, y + 2)], 1, ramp(SILVER))
    icon.line([(4, 25), (2, 30)], 1, ramp("c8a870"))
    icon.sparkle(6, 6, (230, 250, 255))
    return icon


def nightmare_bell_icon():
    icon = Icon()
    icon.poly([(10, 9), (22, 9), (25, 22), (28, 25), (4, 25), (7, 22)], ramp("6a3a8a"))
    icon.ellipse((10, 5, 22, 13), ramp("6a3a8a"))
    icon.ring((13, 1, 19, 7), 1, ramp(DARK_IRON))
    icon.ellipse((13, 24, 19, 30), ramp(DARK_IRON))
    icon.line([(8, 20), (24, 20)], 1, ramp(GOLD))
    fire(icon, 6, 9, 6, 1)
    fire(icon, 26, 9, 6, 1)
    for p in ((6, 9), (26, 9)):
        icon.put(*p, (200, 120, 255), part=False)
    icon.dots([(13, 14), (19, 14)], (255, 90, 120))
    return icon


def gravecaller_icon():
    icon = Icon()
    shaft(icon, -27, 10, "4a4458", 1)
    icon.km(lambda k, d: (k - 17) ** 2 * 0.5 + d * d * 0.7 <= 22, ramp(BONE))
    for k, d in ((16, -2), (16, 2)):
        if (k + d + MID) % 2 == 0:
            x = (k + d + MID) // 2
            icon.put(x, x - k, (90, 255, 160))
    for k, d in ((24, -2), (26, 0), (27, -3), (25, 3)):
        if (k + d + MID) % 2 == 0:
            x = (k + d + MID) // 2
            icon.put(x, x - k, (138, 255, 176), part=False)
            icon.no_outline.add((x, x - k))
    return icon


def relic_artifact_icon():
    icon = Icon()
    icon.rect((6, 22, 26, 29), ramp(DARK_STONE))
    icon.poly([(16, 2), (24, 12), (16, 22), (8, 12)], ramp("c8b8e8"))
    icon.poly([(16, 2), (24, 12), (16, 12)], ramp("e8e0ff"))
    icon.line([(8, 12), (24, 12)], 1, [c("8a7ab0")] * 5)
    icon.sparkle(26, 4, (240, 230, 255))
    return icon


# ======================================================================
# Every item and its picture
# ======================================================================

def _veg(kind, x=16, y=19):
    def draw(icon):
        if kind == "carrot":
            icon.poly([(13, 14), (19, 14), (16, 25)], ramp("f08a2e"))
            leaf(icon, 16, 14, -1, -1, "5aa040", 3)
            leaf(icon, 16, 14, 1, -1, "6ab040", 3)
        elif kind == "potato":
            icon.ellipse((10, 14, 22, 23), ramp("c8a878"))
            icon.dots([(13, 17), (18, 19)], (140, 110, 70))
        elif kind == "pumpkin":
            icon.ellipse((10, 14, 22, 24), ramp("ff9a2e"))
            icon.line([(16, 15), (16, 23)], 1, [ramp("ff9a2e")[3]] * 5)
            icon.rect((15, 12, 17, 14), ramp("5a8a3a"))
        elif kind == "wheat":
            for x in (13, 16, 19):
                icon.line([(x, 25), (x, 15)], 1, ramp("8a7030"))
                icon.ellipse((x - 1, 12, x + 1, 19), ramp("d8a840"))
        elif kind == "frostberry":
            for x, y in ((13, 18), (19, 18), (16, 22)):
                icon.ellipse((x - 2, y - 2, x + 2, y + 2), ramp("8ad0f0"))
            leaf(icon, 16, 15, 1, -1, "5aa040", 3)
        elif kind == "sunroot":
            icon.line([(16, 15), (16, 25)], 2, ramp("e8c050"))
            icon.line([(16, 20), (12, 24)], 1, ramp("e8c050"))
            flower(icon, 16, 14, "ffe060", "f08a2e", 2, 5)
    return draw


def _token_blood(icon):
    icon.ellipse((12, 12, 20, 22), ramp("8a1a2a"))
    icon.poly([(12, 16), (16, 8), (20, 16)], ramp("8a1a2a"))
    icon.put(14, 14, (255, 160, 170))


def _token_festival(icon):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 8 if i % 2 == 0 else 3.5
        pts.append((16 + math.cos(a) * r, 16 + math.sin(a) * r))
    icon.poly(pts, ramp("fff0b0"))


HEARTSWORN = "c8404e"


ITEMS = {
    # --- weapons
    "sword": lambda: sword_icon(),
    "dark_sword": lambda: sword_icon(steel="5a4e72", hilt="7a52c0", wrap="2a2038", gem="c08cff", curl=3,
                                     extra=line_along(-7, 18, "b080ff", 0, 1)),
    "flame_sword": lambda: sword_icon(steel="e0c8b8", hilt=GOLD, wrap=CLOTH_RED, gem="ff6a2a",
                                      extra=flames_along([(255, 220, 120), (255, 140, 50), (220, 70, 40), (160, 40, 40)], -6, 22, 3)),
    "frost_sword": lambda: sword_icon(steel=FROST, hilt=SILVER, wrap=NAVY, gem="8ad8ff", curl=-1, extra=frost_along(-6, 20, 4)),
    "ninefold_blade": lambda: sword_icon(steel="f0ecff", hilt=GOLD, wrap=HEART_DARK, gem=HEART, tip_k=27, half=2.8, start=-10,
                                         guard_len=8, curl=3, grip_from=-23, extra=line_along(-6, 18, GOLD, 0, 0)),
    "stormcaller": lambda: sword_icon(steel="c8d8f0", hilt="4a6ab0", wrap=NAVY, gem="fff4a0", extra=line_along(-7, 20, "fff4a0", 0, 1)),
    "greatsword": lambda: sword_icon(half=3.0, tip_k=27, start=-11, guard_len=8, grip_from=-25, tip=7, hilt=IRON),
    "executioner": lambda: sword_icon(steel="9aa2ae", hilt=DARK_IRON, wrap="3a2a2a", half=3.6, tip_k=26, start=-11, tip=2,
                                      guard_len=7, curl=0, grip_from=-25, fuller=False, extra=notches(0, 20, 4, "4a4e5a")),
    "pulsebrand": lambda: sword_icon(steel="eccacc", hilt=HEART_DARK, wrap=DARK_LEATHER, gem=HEART, half=3.0, tip_k=27, start=-11,
                                     guard_len=8, curl=4, grip_from=-25, tip=7, extra=line_along(-8, 18, HEART, 0, 0)),
    "katana": lambda: sword_icon(steel="dce4ec", hilt="3a3a4a", wrap="e8e0d0", half=1.6, tip_k=27, start=-8, guard_len=3, curl=0,
                                 grip_from=-24, curve=0.6, tip=5, fuller=False, extra=line_along(-6, 22, "f4f8ff", -1, 0)),
    "dagger": lambda: sword_icon(tip_k=20, start=-4, half=2.2, guard_len=5, curl=2, grip_from=-16, tip=6, fuller=True),
    "fang": lambda: sword_icon(steel="f0e8d0", hilt=DARK_LEATHER, wrap=LEATHER, tip_k=21, start=-4, half=2.6, guard_len=3, curl=0,
                               grip_from=-16, tip=8, curve=0.9, fuller=False, extra=notches(2, 14, 3, "c8b898")),
    "frostbite": lambda: sword_icon(steel=FROST, hilt=SILVER, wrap=NAVY, gem="dff4ff", tip_k=20, start=-4, half=2.0, guard_len=5,
                                    curl=-2, grip_from=-16, tip=6, fuller=False, extra=frost_along(-2, 18, 7)),
    "axe": lambda: axe_icon(),
    "bloodthirst": lambda: axe_icon(head="a83040", edge="ff8a9a", double=True, band=GOLD),
    "reaver": lambda: axe_icon(head=DARK_IRON, haft=DARK_WOOD, edge=STEEL, spikes=STEEL),
    "spear": lambda: spear_icon(),
    "heartpiercer": lambda: spear_icon(head=HEART, haft=DARK_WOOD, barbs=True, tassel=HEART_DARK),
    "sunfang": lambda: spear_icon(head=GOLD, haft=PALE_WOOD, sun=True, tassel=CLOTH_RED),
    "halberd": halberd_icon,
    "club": club_icon,
    "staff": lambda: staff_icon(),
    "altar_staff": lambda: staff_icon(wood=PALE_WOOD, orb="f0e0ff", cage=GOLD),
    "ember_staff": lambda: staff_icon(wood=DARK_WOOD, orb=EMBER, flame=("ff8a3a", "ffd060", "ff4a2a")),
    "wispkeeper": lambda: staff_icon(wood="6a8a7a", orb="8affd0", rings=SILVER),
    "bow": lambda: bow_icon(),
    "heartstring": lambda: bow_icon(limb="a83040", string="ff9aa8", grip_c=DARK_LEATHER, tips=GOLD),
    "splitshot": lambda: bow_icon(limb=DARK_WOOD, double=True, tips=STEEL),
    "fishing_rod": fishing_rod_icon,
    # --- armour and things worn
    "helmet": lambda: helmet_icon(IRON),
    "heartsworn_helm": lambda: helmet_icon(HEARTSWORN, "horned", trim=GOLD),
    "ember_crown": lambda: helmet_icon(GOLD, "crown", trim=EMBER),
    "leather_cap": lambda: helmet_icon(kind="leather"),
    "chestplate": lambda: chest_icon(IRON),
    "heartsworn_cuirass": lambda: chest_icon(HEARTSWORN, trim=GOLD),
    "leather_vest": lambda: chest_icon(kind="leather"),
    "fur_cloak": lambda: chest_icon(kind="fur"),
    "greaves": lambda: legs_icon(IRON),
    "heartsworn_greaves": lambda: legs_icon(HEARTSWORN, trim=GOLD),
    "leather_leggings": lambda: legs_icon(kind="leather"),
    "boots": lambda: boots_icon(IRON),
    "heartsworn_sabatons": lambda: boots_icon(HEARTSWORN, trim=GOLD),
    "voidwalker": lambda: boots_icon(VOID, stars=True),
    "leather_boots": lambda: boots_icon(kind="leather"),
    "shield": lambda: shield_icon(),
    "ring": lambda: ring_icon(),
    "phoenix_ring": lambda: ring_icon(GOLD, "ff8a2a", flame=True),
    "necklace": lambda: necklace_icon(),
    "leather_belt": lambda: belt_icon(LEATHER, GOLD, pouches=1),
    "reliquary_belt": lambda: belt_icon(DARK_LEATHER, GOLD, pouches=3),
    "rope_belt": lambda: belt_icon(rope=True),
    "backpack": lambda: pack_icon("backpack"),
    "bindle": lambda: pack_icon("bindle"),
    "explorers_pack": lambda: pack_icon("explorers_pack"),
    "satchel": lambda: pack_icon("satchel"),
    "bottomless_satchel": satchel_bottomless,
    # --- raw stuff
    "stone": lambda: ore_icon("9a98a0", "c8c4d0", 2, "veins"),
    "coal": coal_icon,
    "copper_ore": lambda: ore_icon("8a7a74", COPPER, 3, "flecks"),
    "tin_ore": lambda: ore_icon("7a7884", "d8e0e4", 4, "flecks"),
    "iron_ore": lambda: ore_icon("7a6e6a", "b8a49a", 5, "veins"),
    "silver_ore": lambda: ore_icon("6a6878", SILVER, 6, "nuggets"),
    "gold_ore": lambda: ore_icon("7a7068", "f0cf6a", 7, "nuggets", (21, 12)),
    "mithril_ore": lambda: ore_icon("5a6a78", MITHRIL, 8, "crystals"),
    "adamantite_ore": lambda: ore_icon("5a4a50", ADAMANT, 9, "crystals"),
    "obsidian_ore": lambda: ore_icon("3a3448", "8a7ab0", 10, "veins", (19, 15)),
    "ember_core": lambda: core_icon("4a3a3a", EMBER, "ffd060"),
    "magma_core": lambda: core_icon("2a1e1e", "ff5a2a", "ffb040"),
    "core_molten": lambda: piece_icon("core_molten"),
    "spore_cap": lambda: plant_icon("spore_cap"),
    "copper_ingot": lambda: ingot_icon(COPPER),
    "bronze_ingot": lambda: ingot_icon(BRONZE, "stamp"),
    "iron_ingot": lambda: ingot_icon(IRON),
    "silver_ingot": lambda: ingot_icon(SILVER, "stamp", "trapezoid"),
    "gold_ingot": lambda: ingot_icon(GOLD, None, "trapezoid"),
    "mithril_ingot": lambda: ingot_icon(MITHRIL, "rune"),
    "adamantite_ingot": lambda: ingot_icon(ADAMANT, "rune"),
    "obsidian_ingot": lambda: ingot_icon(OBSIDIAN, "crack"),
    "heartstone_ingot": lambda: ingot_icon(HEART, "heart"),
    "void_ingot": lambda: ingot_icon(VOID, "swirl"),
    "oak_wood": lambda: log_icon("7a5434", "d8b078"),
    "pine_wood": lambda: log_icon("5e4430", "e8cc90", resin=True),
    "ancient_wood": lambda: log_icon("4a3a2e", "b89060", moss=MOSS),
    "heartwood": lambda: log_icon("5a3424", "c85a5a", rings="7a2030", glow="ff8a9a"),
    "spiritwood": lambda: log_icon("6a8a8a", "d8f0e8", rings="8ac8c0", glow="c8fff0"),
    # --- gems
    **{f"{g}_{t}": (lambda g=g, t=t: gem_icon(g, t)) for g in GEM_COLOURS for t in range(1, 6)},
    # --- plants, crops and herbs
    **{k: (lambda k=k: plant_icon(k)) for k in ("healing_herb", "mana_flower", "frost_lily", "bloodcap", "poison_mushroom",
                                                "glowshroom", "desert_aloe", "emberbloom", "void_bloom", "saltweed",
                                                "rare_root", "sunroot", "wheat", "potato", "pumpkin", "carrot")},
    # --- fish
    **{k: (lambda k=k: fish_icon(k)) for k in FISH},
    # --- hides
    "leather": leather_icon,
    "wool": wool_icon,
    "feather": lambda: feather_icon("f4f0e8", tip="c8c0b0"),
    "pheasant_feather": lambda: feather_icon("c86a3a", tip="2a5a4a", bars="f0d8b0", long=True),
    "harpy_feather": lambda: feather_icon("a8b8d0", tip="5a6a8a", bars="e8f0ff"),
    "cow_hide": lambda: pelt_icon("f0ece4", "patches", "3a3030"),
    "pig_hide": lambda: pelt_icon("f0b8b0", small=True),
    "deer_hide": lambda: pelt_icon("b8804a", "spots", "f4e8d0"),
    "hare_pelt": lambda: pelt_icon("c8b8a0", "tail", "f8f4ec", small=True),
    "fox_pelt": lambda: pelt_icon("e07a3a", "tail", "f8f0e8"),
    "hound_pelt": lambda: pelt_icon("7a6a5a", "stripe", "4a4038"),
    "bear_pelt": lambda: pelt_icon("6a4a34", big=True),
    "frost_pelt": lambda: pelt_icon("dce8f4", "frost", "a8d0f0", big=True),
    "troll_hide": lambda: pelt_icon("6a8a5a", "warts", "4a6a3a", big=True),
    # --- monster parts
    "bone": bone_icon,
    "claw": lambda: claw_icon(),
    "antler": lambda: horn_icon("e8dcc0", "antler"),
    "boar_tusk": lambda: horn_icon("f0e8d0", "tusk"),
    "goat_horn": lambda: horn_icon("6a5040", "curved"),
    "fiend_horn": lambda: horn_icon("e05a3a", "spiral"),
    "gem_eye": lambda: piece_icon("gem_eye"),
    "chitin": lambda: carapace_icon("4a5040", 4),
    "crab_shell": lambda: carapace_icon("d84a3a", claw=True),
    "lizard_scale": lambda: scales_icon("d8b878"),
    "spider_silk": silk_icon,
    "venom_sac": lambda: blob_icon("b06ad0", seed=3),
    "slime_gel": lambda: blob_icon("b8f08a", seed=4),
    "toad_slime": lambda: blob_icon("a8d070", jar=True, seed=5),
    "husk_fragment": husk_icon,
    "bat_wing": wing_icon,
    "lurker_tongue": tongue_icon,
    "scorpion_stinger": stinger_icon,
    "mummy_wrap": lambda: cloth_icon("e0d4b4", roll=True),
    "wraith_cloth": lambda: cloth_icon("dfe6ee", tatters=True),
    "crimson_plate": plate_fragment_icon,
    "heartblood": lambda: bottle_icon("c8203a", "vial", glass="f0d8dc", extra=lambda i: i.sparkle(25, 5, (255, 160, 170))),
    "stone_heart": lambda: heart_stone_icon("8a8794", cracks="4a4652", facets=False),
    "heart_shard": lambda: shard_icon("ff6a7a", glow="ffd0d8"),
    "rift_shard": lambda: shard_icon("c83a5a", glow="b080ff", count=3),
    "cultist_sigil": sigil_icon,
    "boss_trophy": trophy_cup_icon,
    "milk": lambda: jug_icon(),
    "toad_legs": lambda: cooked_icon("8aa85a", "legs"),
    "gold_coins": coins_icon,
    "dungeon_key": key_icon,
    "blood_token": lambda: token_icon("e05060", _token_blood),
    "festival_token": lambda: token_icon("f0c860", _token_festival),
    # --- the Ninefold pieces
    **{k: (lambda k=k: piece_icon(k)) for k in ("pommel_hollow", "guard_cinder", "edge_frost", "grip_pale", "wrap_briar",
                                                "fuller_dune", "heart_blade")},
    # --- arcane
    "enchanted_dust": dust_icon,
    "essence": essence_icon,
    "heartstone": lambda: heart_stone_icon("e0506a"),
    "void_crystal": lambda: crystal_cluster("9a6cf0", "e0d0ff"),
    "void_shard": lambda: shard_icon("a070f0", glow="e8d8ff"),
    # --- food
    "beef": lambda: raw_meat_icon("d8505a", bone=True),
    "pork": lambda: raw_meat_icon("f09a98", fat="fff0ec", shape="chop"),
    "mutton": lambda: raw_meat_icon("d06060", shape="leg", size=2),
    "goat_meat": lambda: raw_meat_icon("c85a5a", fat="f0d0c0", shape="ribs"),
    "venison": lambda: raw_meat_icon("a83a3a", fat="e0b0a8", bone=True),
    "bear_meat": lambda: raw_meat_icon("8e3038", fat="e8c8c0", shape="chunk"),
    "chicken_meat": lambda: raw_meat_icon("f4c0b0", shape="leg"),
    "pheasant_meat": lambda: raw_meat_icon("e8a090", fat="f8e0d8", shape="leg", size=-2),
    "hare_meat": lambda: raw_meat_icon("d88080", shape="leg", size=-3),
    "lizard_meat": lambda: raw_meat_icon("c89878", fat="e8d0b0", shape="tail"),
    "crab_meat": lambda: raw_meat_icon("e8705a", shape="claw"),
    "egg": egg_icon,
    "cheese": cheese_icon,
    "bread": lambda: bread_icon(),
    "beef_steak": lambda: cooked_icon("8a4426", garnish="5aa040"),
    "grilled_pork": lambda: cooked_icon("c07a44", "grilled"),
    "roast_mutton": lambda: cooked_icon("9a5430", "shank", garnish="5aa040"),
    "roast_chicken": lambda: cooked_icon("d08a40", "whole"),
    "roast_pheasant": lambda: cooked_icon("a85a2a", "drumstick", garnish="e04040"),
    "roast_venison": lambda: cooked_icon("6e3424", garnish="e0303e"),
    "salmon_steak": lambda: cooked_icon("f09070", garnish="f0e060"),
    "jerky": lambda: cooked_icon("6a3020", "strips"),
    "goat_skewer": lambda: cooked_icon("9a5430", "skewer"),
    "spiced_lizard": lambda: cooked_icon("c06a30", "skewer", garnish="e04030"),
    "grilled_minnow": lambda: cooked_icon("c89a6a", "fish"),
    "fried_toad_legs": lambda: cooked_icon("c0883a", "legs"),
    "baked_potato": baked_potato_icon,
    "bear_stew": lambda: bowl_icon("7a3e24", ("a0502a", "f08a2e", "a0502a"), DARK_WOOD),
    "carrot_stew": lambda: bowl_icon("e08a3a", ("f08a2e", "5aa040", "f8e0a0"), "c86a3a"),
    "hare_stew": lambda: bowl_icon("a8743a", ("d88080", "f08a2e", "c8a878")),
    "trout_stew": lambda: bowl_icon("c8a87a", ("d8a8a0", "5aa040"), "4a6ab0", rim="e8f0f8"),
    "ember_stew": lambda: bowl_icon("d8442a", ("ffb040", "8a2a1a"), DARK_IRON, pot=True),
    "pike_chowder": lambda: bowl_icon("ece0c4", ("7a9a5a", "c8a878", "5aa040"), "e8e4ec", rim="4a6ab0"),
    "glowfin_soup": lambda: bowl_icon("4ac8c8", ("a0f0ff", "4a8ac8"), "3a5a8a", rim=GOLD),
    "glowshroom_soup": lambda: bowl_icon("8a7ad0", ("c8f0ff", "e8dcc0"), "5a4a7a"),
    "omelette": lambda: omelette_icon(),
    "herb_omelette": lambda: omelette_icon(True),
    "crab_cakes": lambda: cakes_icon(),
    "eel_pie": lambda: pie_icon("6a7a5a", crust="d8a860"),
    "pork_pie": lambda: pie_icon("b8703a", lattice=False),
    "pumpkin_pie": lambda: pie_icon("e8903a", lattice=False, slice_=True),
    "custard_tart": custard_icon,
    "golden_platter": lambda: platter_icon("gold"),
    "hunters_feast": lambda: platter_icon("feast"),
    "wild_berries": lambda: berries_icon("c83a5a"),
    "thornberries": lambda: berries_icon("7a1a3a", 6, "3a6a3a"),
    "frostberry": lambda: berries_icon("8ad0f0", 5, "5a9aa0"),
    # --- treats
    "berry_tart": lambda: pie_icon("c83a5a", topping="ff8a9a", lattice=False),
    "frostberry_tart": lambda: pie_icon("8ad0f0", topping="e8f8ff", lattice=False),
    "harvest_pie": lambda: pie_icon("e8a050"),
    "candied_frostberries": lambda: berries_icon("a8d8f0", 6, "5a9aa0", candied=True),
    "pumpkin_bread": lambda: bread_icon("e09a40", glaze="ffd890"),
    "sweet_roll": lambda: bread_icon("e0b070", "roll", glaze="fff4e0"),
    "thornberry_jam": lambda: jam_icon("8a1a2a"),
    # --- potions
    "health_potion": lambda: bottle_icon("e0303e"),
    "mana_potion": lambda: bottle_icon("3a7ae8", "flask"),
    "stamina_tonic": lambda: bottle_icon("f0c040", "vial"),
    "might_elixir": lambda: bottle_icon("f07a2a", "square", label="e8d8b0"),
    "aloe_salve": lambda: bottle_icon("9ac870", "jar"),
    "bloodcap_draught": lambda: bottle_icon("a01a2a", "mushroom"),
    "sunroot_elixir": lambda: bottle_icon("ffe060", "gourd", cork=GOLD, extra=lambda i: i.sparkle(25, 6, (255, 250, 200))),
    "void_tonic": lambda: bottle_icon("8a5ae0", "flask", cork=OBSIDIAN, extra=lambda i: i.sparkle(24, 8, (220, 200, 255))),
    # --- drinks
    "ember_ale": lambda: mug_icon("f08a2e", foam="fff4e0"),
    "hunters_brew": lambda: mug_icon("7a4a2a", mug=DARK_WOOD, foam="e8d8c0"),
    "mulled_cider": lambda: mug_icon("c86a30", mug="b8584a", steam=True, garnish="f0a030"),
    "frost_tea": lambda: mug_icon("a8d8f0", mug="e8f0f8", kind="cup", steam=True),
    "swiftfoot_tea": lambda: mug_icon("8ad0a0", mug="f4ece0", kind="cup", steam=True, garnish="5aa040"),
    "ironbark_tonic": lambda: mug_icon("5a4430", mug=IRON, kind="cup"),
    "sages_infusion": lambda: mug_icon("7aa8ff", mug="4a6ab0", kind="teapot"),
    "sunroot_cordial": lambda: bottle_icon("ffd040", "round", cork=GOLD, label="fff4d0"),
    # --- runes, seeds, whistles, charms, collars, tack
    **{f"rune_{k}": (lambda k=k: rune_icon(k)) for k in RUNE_GLYPHS},
    **{f"{k}_seeds": (lambda k=k: seed_icon(_veg(k))) for k in ("carrot", "frostberry", "potato", "pumpkin", "sunroot", "wheat")},
    "horse_whistle": lambda: whistle_icon("b08050", whistle_emblem((240, 220, 180), "horse")),
    "pony_whistle": lambda: whistle_icon("e0c8a0", whistle_emblem((140, 90, 60), "star")),
    "sand_strider_whistle": lambda: whistle_icon("f0c070", whistle_emblem((200, 90, 40), "sun")),
    "frost_elk_whistle": elk_horn_icon,
    "nightmare_whistle": nightmare_bell_icon,
    "heart_charm": lambda: charm_icon("heart"),
    "lucky_charm": lambda: charm_icon("lucky"),
    "swift_charm": lambda: charm_icon("swift"),
    "leather_collar": lambda: collar_icon("9a6a40", BRONZE),
    "silver_collar": lambda: collar_icon(SILVER, SILVER, tag="4a8ae0"),
    "spiked_collar": lambda: collar_icon("3a3640", DARK_IRON, spikes=True),
    "riding_saddle": lambda: saddle_icon("8a5a34", BRONZE),
    "racing_saddle": lambda: saddle_icon("c8a870", SILVER, light=True),
    "heartwood_saddle": lambda: saddle_icon("8a3a30", GOLD, emblem=HEART),
    "padded_barding": lambda: barding_icon("padded"),
    "iron_barding": lambda: barding_icon("iron"),
    "heartsteel_barding": lambda: barding_icon("heartsteel"),
    # --- relics and artifacts
    **{f"relic_{k}": (lambda k=k: relic_icon(k)) for k in ("bloodvine", "ember_heart", "frostbound_eye", "gale_feather", "gilded_idol",
                                                           "grave_lantern", "hearthstone", "ironroot", "moonlit_bell", "stormheart",
                                                           "tidewalker", "void_lens")},
    "gravecaller": gravecaller_icon,
    "relic": relic_artifact_icon,
    # --- tools
    **{f"{t}_hatchet": (lambda t=t: hatchet_icon(t)) for t in TIER_METAL},
    **{f"{t}_pickaxe": (lambda t=t: pickaxe_icon(t)) for t in TIER_METAL},
    # --- furniture and buildings
    **{k: (lambda k=k: furniture_icon(k)) for k in (
        "anvil", "ballista", "barrel", "bench", "bookshelf", "brazier", "candles", "chair", "crate", "cupboard", "dining_table",
        "farm_plot", "farmhouse_kit", "fence", "fireplace", "flower_bed", "fountain", "furnace", "hay_bale", "lantern_post",
        "palisade_wall", "potted_plant", "root_hollow", "rootling_delver", "rootling_tender", "rootling_woodcutter", "rug",
        "scarecrow", "spike_trap", "stone_planter", "stone_statue", "trophy_stand", "wall_banner", "weapon_rack",
        "bed", "crafting_table", "house_kit", "storage_chest", "torch")},
    "treasure_map": map_icon,
    "rowboat": boat_icon,
    "bandage": bandage_icon,
    "bedroll": lambda: new_thing_icon("bedroll"),
    "lull_doll": lambda: new_thing_icon("lull_doll"),
    "noble_mask": lambda: new_thing_icon("noble_mask"),
    "matron_lantern": lambda: new_thing_icon("matron_lantern"),
    "benefactor_pen": lambda: new_thing_icon("benefactor_pen"),
    "gate_key_e": lambda: new_thing_icon("gate_key_e"),
    "gate_key_d": lambda: new_thing_icon("gate_key_d"),
    "gate_key_c": lambda: new_thing_icon("gate_key_c"),
    "gate_key_b": lambda: new_thing_icon("gate_key_b"),
    "gate_key_a": lambda: new_thing_icon("gate_key_a"),
    "gate_key_s": lambda: new_thing_icon("gate_key_s"),
    "taming_treat": treat_icon,
    # --- walls
    **{k: (lambda k=k: wall_icon(k)) for k in WALLS},
    # --- ground and floors
    "grass_turf": lambda: turf_icon("4e8a4a", kind="grass"),
    "dry_grass_turf": lambda: turf_icon("b0a060", kind="grass"),
    "crimson_moss": lambda: turf_icon("b04454", "5a3a34", "grass"),
    "mushroom_turf": lambda: turf_icon("6a5a8a", "5a4434", "mushrooms", "c08cff"),
    "packed_snow": lambda: turf_icon("eef4ff", "8a8a9a", "smooth"),
    "salt_flat": lambda: turf_icon("f0ecd8", "b8a888", "cracks"),
    "ash_heap": lambda: turf_icon("8a8a90", "4a4448", "dots", "5a5458"),
    "cinder_path": lambda: turf_icon("5a4a4a", "3a2e2e", "embers"),
    "clay_mud": lambda: turf_icon("8a6a4a", "6a4a34", "dots", "6a4e36"),
    "flagstones": lambda: turf_icon("8f8a90", "6a6070", "flags"),
    "stone_path": lambda: turf_icon("8a7a5a", "6a5038", "stones", "b8aa90"),
    "wooden_decking": lambda: turf_icon("b08a5a", DARK_WOOD, "planks"),
    "sand_sack": lambda: sack_icon(),
    "water_bucket": lambda: bucket_icon(),
    "floor_plank": lambda: floor_icon("b08a5a", "plank"),
    "floor_stone": lambda: floor_icon("8f8a90", "stone"),
    "floor_cobble": lambda: floor_icon("a39478", "cobble"),
    "floor_sand": lambda: floor_icon("d8c08a", "sand"),
    "floor_moss": lambda: floor_icon("6a7a64", "moss"),
    "floor_snow": lambda: floor_icon("e6eef6", "snow"),
}


def build_sheet(ids):
    rows = (len(ids) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGBA", (COLUMNS * SIZE, rows * SIZE), (0, 0, 0, 0))
    for index, item_id in enumerate(ids):
        sheet.paste(ITEMS[item_id]().image(), ((index % COLUMNS) * SIZE, (index // COLUMNS) * SIZE))
    return sheet


GD_HEAD = '''class_name ItemIcons
extends RefCounted
## Every item's own 32x32 picture, drawn pixel by pixel by
## tools/generate_item_icons.py into one sheet. INDEX gives an item's place.
## (Generated: change the tool, not this file.)

const SIZE := 32
const COLUMNS := 16
const SHEET := "res://assets/icons/items32.png"

static var _sheet: Texture2D
static var _cache := {}

'''

GD_TAIL = '''

static func has(id: String) -> bool:
	return INDEX.has(id)


## The biggest square that fits in `rect`, centred, at which the pictures
## stay crisp: 16, 32, 64 or 96 pixels (a whole number of screen pixels for
## each of theirs, or exactly half).
static func snap(rect: Rect2) -> Rect2:
	var side := minf(rect.size.x, rect.size.y)
	var fit := 96.0 if side >= 96.0 else 64.0 if side >= 64.0 else 32.0 if side >= 32.0 else 16.0
	return Rect2((rect.position + (rect.size - Vector2(fit, fit)) / 2.0).round(), Vector2(fit, fit))


## A side for a picture shown in a box about `wanted` pixels across.
static func crisp_side(wanted: float) -> float:
	return 96.0 if wanted >= 90.0 else 64.0 if wanted >= 56.0 else 32.0 if wanted >= 28.0 else 16.0


static func texture(id: String) -> Texture2D:
	if not INDEX.has(id):
		return null
	if _cache.has(id):
		return _cache[id]
	if _sheet == null:
		_sheet = load(SHEET)
	var index: int = INDEX[id]
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	atlas.region = Rect2((index % COLUMNS) * SIZE, (index / COLUMNS) * SIZE, SIZE, SIZE)
	_cache[id] = atlas
	return atlas
'''


def main():
    ids = sorted(ITEMS)
    order_file = os.path.join(ROOT, "tools", "item_icon_order.txt")
    # Keep every item in the place it had: new items go on the end.
    if os.path.exists(order_file):
        old = [line.strip() for line in open(order_file) if line.strip()]
        ids = [i for i in old if i in ITEMS] + [i for i in ids if i not in old]
    with open(order_file, "w") as f:
        f.write("\n".join(ids) + "\n")
    out = os.path.join(ROOT, "assets", "icons", "items32.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    build_sheet(ids).save(out)
    lines = ["const INDEX := {"]
    for i, item_id in enumerate(ids):
        lines.append('\t"%s": %d,' % (item_id, i))
    lines.append("}")
    with open(os.path.join(ROOT, "scripts", "items", "item_icons.gd"), "w") as f:
        f.write(GD_HEAD + "\n".join(lines) + GD_TAIL)
    print("%d item icons -> %s" % (len(ids), out))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--preview":
        # A big preview sheet with names, for looking the icons over.
        pass
    main()
