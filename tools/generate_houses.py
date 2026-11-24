#!/usr/bin/env python3
"""The peoples' buildings, drawn pixel by pixel at the size they stand in
the world (128x128 frames, shown at scale 1, never stretched).

Three ways of building, fifteen houses each:
  human  timber frames over plaster on a stone footing, tiled, slated or
         thatched gables, chimneys, dormers, shutters, porches, flower boxes
  elf    pale birch and living branches curving up into the roof, curved
         roofs of leaf shingles, arched windows with a soft glow, vines,
         lanterns; domes, spires, tiers and houses up on their own roots
  dwarf  heavy blocks of dressed stone, iron-banded round-topped doors, deep
         warm windows, low slate or turf roofs, forge chimneys with embers,
         carved runes; some dug into the hillside
and the goblins' camp: four patchwork tents and the leader's great tent, and
a castle for the villages that have a king.

Writes assets/sprites/houses.png (one row per people: 15 houses; a fourth row
of tents) and assets/sprites/castle.png (one 256x224 frame).

Run from the repository root:  python3 tools/generate_houses.py
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_flora import Canvas, C, ramp  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
W = H = 128
GROUND = 124


# Where smoke leaves each chimney, by (people, variant), in frame pixels.
CHIMNEYS = {}


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (c[3],)


# ------------------------------------------------------------------ parts
def footing(c, x0, x1, y0, y1, stone):
    c.shade("rect", (x0, y0, x1, y1), stone, dither=False)
    for y in range(y0 + 2, y1, 3):
        off = 0 if (y // 3) % 2 else 3
        for x in range(x0 + off, x1, 6):
            c.put(x, y, shade(stone[2], 0.8))
    c.fill("rect", (x0, y0, x1, y0), stone[0])


def plaster_wall(c, x0, x1, y0, y1, plaster, beam):
    c.shade("rect", (x0, y0, x1, y1), plaster, dither=False)
    # Timber frame: posts, a rail and braces.
    for x in (x0, x1 - 2, (x0 + x1) // 2 - 1):
        c.fill("rect", (x, y0, x + 2, y1), beam)
    c.fill("rect", (x0, y0, x1, y0 + 1), beam)
    c.fill("rect", (x0, y1 - 1, x1, y1), beam)
    mid = (y0 + y1) // 2
    c.fill("line", (x0 + 2, y1 - 2, (x0 + x1) // 2 - 2, mid), beam, 2)
    c.fill("line", (x1 - 3, y1 - 2, (x0 + x1) // 2 + 2, mid), beam, 2)


def stone_wall(c, x0, x1, y0, y1, stone):
    c.shade("rect", (x0, y0, x1, y1), stone, dither=False)
    r = random.Random(x0 * 7 + y0)
    y = y0
    row = 0
    while y < y1:
        h = 4 if row % 2 else 5
        x = x0 - (r.randrange(0, 4) if row % 2 else 0)
        while x < x1:
            w = r.randrange(6, 11)
            c.fill("rect", (max(x, x0), y, min(x + w, x1), y), shade(stone[0], 1.05))
            c.fill("rect", (min(x + w, x1), y, min(x + w, x1), min(y + h - 1, y1)), shade(stone[2], 0.72))
            x += w + 1
        c.fill("rect", (x0, y + h - 1, x1, y + h - 1), shade(stone[2], 0.72))
        y += h
        row += 1


def plank_wall(c, x0, x1, y0, y1, wood):
    c.shade("rect", (x0, y0, x1, y1), wood, dither=False)
    for x in range(x0 + 3, x1, 4):
        c.fill("rect", (x, y0, x, y1), shade(wood[2], 0.85))


def window(c, x, y, w=8, h=9, frame=None, glow=C("f0c870"), arched=False, shutters=None, box=None):
    frame = frame or C("3a2a1e")
    if arched:
        c.fill("ellipse", (x - 1, y - 2, x + w + 1, y + 4), frame)
    c.fill("rect", (x - 1, y + (1 if arched else 0), x + w + 1, y + h + 1), frame)
    if arched:
        c.fill("ellipse", (x, y - 1, x + w, y + 5), glow)
    c.fill("rect", (x, y + 2, x + w, y + h), glow)
    c.fill("rect", (x + w // 2, y, x + w // 2, y + h), frame)
    c.fill("rect", (x, y + h // 2 + 1, x + w, y + h // 2 + 1), frame)
    c.put(x + 1, y + 3, shade(glow, 1.25))
    if shutters:
        c.shade("rect", (x - 4, y, x - 2, y + h + 1), shutters, dither=False)
        c.shade("rect", (x + w + 2, y, x + w + 4, y + h + 1), shutters, dither=False)
    if box:
        c.shade("rect", (x - 2, y + h + 2, x + w + 2, y + h + 4), ramp("8a5e3a", "6a4428", "4a2e1c"), dither=False)
        for k in range(x - 1, x + w + 2, 2):
            c.put(k, y + h + 1, box[k % len(box)])


def door(c, x, y1, w=10, h=16, wood=None, arched=True, iron=False, round_top=False):
    wood = wood or ramp("8a5a34", "6a4226", "48301a")
    top = y1 - h
    if arched or round_top:
        c.shade("ellipse", (x, top - 2, x + w, top + w // 2 + 2), wood, dither=False)
    c.shade("rect", (x, top + 2, x + w, y1), wood, dither=False)
    for k in range(x + 3, x + w, 3):
        c.fill("rect", (k, top + 1, k, y1), shade(wood[2], 0.85))
    if iron:
        for yy in (top + 4, y1 - 4):
            c.fill("rect", (x, yy, x + w, yy + 1), C("4a4e56"))
            c.put(x + 1, yy, C("9aa0aa"))
    c.put(x + w - 3, (top + y1) // 2 + 2, C("e8c060"))
    c.fill("rect", (x - 1, y1, x + w + 1, y1 + 1), C("6a6670"))


def gable_roof(c, x0, x1, base, peak, colours, kind="tile", overhang=4):
    """A roof seen from the front and a little above: a gable end in front
    and the roof's slope behind it, in rows of tiles, slates or thatch."""
    mid = (x0 + x1) // 2
    pts = [(x0 - overhang, base), (mid, peak), (x1 + overhang, base)]
    c.shade("poly", pts + [(x1 + overhang, base + 2), (x0 - overhang, base + 2)], colours, dither=False)
    r = random.Random(x0 + peak)
    for y in range(peak + 3, base + 2, 3 if kind != "thatch" else 2):
        span = (y - peak) / max(base - peak, 1)
        a = int(mid - (mid - x0 + overhang) * span)
        b = int(mid + (x1 + overhang - mid) * span)
        if kind == "thatch":
            for x in range(a + 1, b, 2):
                c.put(x, y, colours[0] if r.random() < 0.4 else colours[2])
        else:
            c.fill("rect", (a + 1, y, b - 1, y), shade(colours[2], 0.85))
            step = 5 if kind == "tile" else 4
            for x in range(a + 2 + (y // 3) % 2 * 2, b - 1, step):
                c.put(x, y - 1, shade(colours[2], 0.8))
    # The ridge and the bargeboards.
    c.fill("line", (x0 - overhang, base, mid, peak), shade(colours[2], 0.65), 1)
    c.fill("line", (mid, peak, x1 + overhang, base), shade(colours[2], 0.65), 1)
    c.fill("rect", (mid - 1, peak - 1, mid + 1, peak), shade(colours[0], 1.1))


def curved_roof(c, x0, x1, base, peak, colours, tip=True):
    """An elven roof: sweeping up to a point, its eaves curling out, laid in
    leaf-shaped shingles."""
    mid = (x0 + x1) // 2
    pts = []
    for k in range(21):
        t = k / 20
        x = x0 - 6 + (x1 - x0 + 12) * t
        lift = 1 - abs(t - 0.5) * 2
        y = base - (base - peak) * (lift ** 1.7) - (3 if t < 0.06 or t > 0.94 else 0)
        pts.append((x, y))
    pts += [(x1 + 6, base + 2), (x0 - 6, base + 2)]
    c.shade("poly", pts, colours, dither=False)
    scallops(c, x0 - 5, x1 + 6, peak + 4, base + 1, colours)
    if tip:
        c.fill("line", (mid, peak, mid, peak - 7), C("d8c890"), 1)
        c.put(mid, peak - 8, C("fff0b0"))


def scallops(c, x0, x1, y0, y1, colours):
    """Rows of rounded leaf shingles over whatever is already drawn there."""
    inside = set(c.filled)
    for row, y in enumerate(range(y0, y1, 4)):
        for x in range(x0 + (row % 2) * 2, x1, 4):
            for (dx, dy, tone) in ((0, 0, 2), (3, 0, 2), (1, 1, 2), (2, 1, 2), (1, -2, 0)):
                if (x + dx, y + dy) in inside:
                    c.put(x + dx, y + dy, shade(colours[2], 0.85) if tone == 2 else colours[0])


def flat_battlement(c, x0, x1, y, stone):
    c.shade("rect", (x0 - 2, y - 3, x1 + 2, y + 1), stone, dither=False)
    for x in range(x0 - 2, x1 + 1, 6):
        c.shade("rect", (x, y - 7, x + 3, y - 3), stone, dither=False)


def chimney(c, x, top, base, stone, smoke=True, ember=False):
    c.shade("rect", (x, top, x + 6, base), stone, dither=False)
    c.fill("rect", (x - 1, top - 1, x + 7, top + 1), shade(stone[2], 0.8))
    if ember:
        c.fill("rect", (x + 1, top + 2, x + 5, top + 3), C("ff8a30"))
        c.put(x + 3, top + 2, C("ffe080"))


def vines(c, x0, x1, y0, y1, seed):
    r = random.Random(seed)
    for _ in range(3):
        x = r.randrange(x0, x1)
        for y in range(y0, y0 + r.randrange((y1 - y0) // 2, y1 - y0)):
            x += r.choice((-1, 0, 0, 1))
            if x0 <= x <= x1:
                c.put(x, y, C("4e8a3a") if y % 3 else C("7ab050"))


def lantern(c, x, y, glow=C("ffd890")):
    c.fill("line", (x, y - 4, x, y), C("3a3430"))
    c.fill("rect", (x - 1, y, x + 1, y + 3), glow)
    c.put(x, y + 1, C("ffffff"))


# ------------------------------------------------------------------ humans
HUMAN_ROOFS = {
    "red": (ramp("d0705a", "a84e3c", "6e3024"), "tile"), "slate": (ramp("7a8496", "566074", "3a4252"), "slate"),
    "thatch": (ramp("d8b870", "b08c48", "7a5e2c"), "thatch"), "blue": (ramp("6a88b8", "4a6494", "30426a"), "tile"),
    "green": (ramp("7a9a5a", "56744a", "38502e"), "tile"), "brown": (ramp("a07a54", "7a5838", "4e3822"), "tile"),
}
HUMAN = [
    dict(w=56, storeys=1, roof="red", plaster="e8dcc4", chimney=True, box=True),
    dict(w=60, storeys=1, roof="thatch", plaster="e0d2b4", porch=True),
    dict(w=64, storeys=2, roof="slate", plaster="ece4d4", chimney=True, dormer=True),
    dict(w=52, storeys=1, roof="blue", plaster="dcd8c8", box=True, shutters="4a6494"),
    dict(w=72, storeys=2, roof="red", plaster="e4d4b8", chimney=True, sign="inn", porch=True),
    dict(w=58, storeys=1, roof="brown", plaster="d8c8a8", lean=True),
    dict(w=66, storeys=2, roof="green", plaster="e8e0cc", shutters="56744a", box=True),
    dict(w=54, storeys=1, roof="thatch", plaster="eadcc0", chimney=True, vines=True),
    dict(w=76, storeys=2, roof="slate", plaster="dcd4c4", sign="smith", chimney=True, ember=True),
    dict(w=60, storeys=1, roof="red", plaster="f0e6d2", tower=True),
    dict(w=62, storeys=2, roof="blue", plaster="e0d8c8", dormer=True, porch=True),
    dict(w=56, storeys=1, roof="brown", plaster="d4c4a4", shutters="8a4a3a", box=True, lean=True),
    dict(w=70, storeys=2, roof="thatch", plaster="e6d8bc", chimney=True, sign="bakery"),
    dict(w=50, storeys=1, roof="green", plaster="ece2d0", vines=True, box=True),
    dict(w=68, storeys=2, roof="red", plaster="e2d6be", tower=True, chimney=True),
]


def human_house(spec, seed):
    c = Canvas(W, H)
    w = spec["w"]
    x0, x1 = 64 - w // 2, 64 + w // 2
    storey = 22
    wall_top = GROUND - 6 - storey * spec["storeys"]
    c.shadow(64, GROUND, w // 2 + 8, 4)
    stone = ramp("a8a2ac", "86808c", "5e5866")
    roof, kind = HUMAN_ROOFS[spec["roof"]]
    if spec.get("lean"):
        plank_wall(c, x1 - 2, x1 + 14, GROUND - 18, GROUND - 1, ramp("9a7048", "7a5434", "56381e"))
        c.shade("poly", [(x1 - 2, GROUND - 20), (x1 + 16, GROUND - 14), (x1 + 16, GROUND - 12), (x1 - 2, GROUND - 17)], roof, dither=False)
    if spec.get("tower"):
        tx = x0 - 12
        stone_wall(c, tx, tx + 16, wall_top - 14, GROUND - 1, stone)
        c.shade("poly", [(tx - 3, wall_top - 14), (tx + 8, wall_top - 34), (tx + 19, wall_top - 14)], roof, dither=False)
        window(c, tx + 5, wall_top - 6, 6, 8, arched=True)
    footing(c, x0, x1, GROUND - 6, GROUND - 1, stone)
    lit = C(spec["plaster"])
    plaster_wall(c, x0, x1, wall_top, GROUND - 6, [lit, shade(lit, 0.9), shade(lit, 0.76)], C("4a3424"))
    if spec["storeys"] == 2:
        c.fill("rect", (x0 - 1, GROUND - 6 - storey - 1, x1 + 1, GROUND - 6 - storey + 1), C("4a3424"))
    peak = wall_top - (w // 2 + 4)
    if spec.get("chimney"):
        chimney(c, x1 - 14, peak + 8, wall_top, stone, ember=spec.get("ember", False))
        CHIMNEYS[(0, seed)] = (x1 - 11, peak + 6)
    gable_roof(c, x0, x1, wall_top, peak, roof, kind)
    if spec.get("dormer"):
        dx = 64 - 6
        c.shade("rect", (dx, wall_top - 14, dx + 12, wall_top - 2), ramp(spec["plaster"], "d8ccb0", "b0a488"), dither=False)
        c.shade("poly", [(dx - 2, wall_top - 14), (dx + 6, wall_top - 21), (dx + 14, wall_top - 14)], roof, dither=False)
        window(c, dx + 2, wall_top - 12, 8, 8)
    # Door, windows, the ground floor and the one above.
    door_x = 64 - 5 if not spec.get("sign") else x0 + 8
    door(c, door_x, GROUND - 6, 10, 16, arched=spec["roof"] != "thatch")
    box = [C("e08aa0"), C("f0d060"), C("c0a0f0"), C("f4f0e8")] if spec.get("box") else None
    for wx in ([x0 + 6, x1 - 15] if not spec.get("sign") else [x1 - 15]):
        window(c, wx, GROUND - 6 - 16, 9, 9, shutters=ramp(spec["shutters"], spec["shutters"], spec["shutters"]) if spec.get("shutters") else None, box=box)
    if spec["storeys"] == 2:
        for wx in (x0 + 8, 64 - 4, x1 - 16):
            window(c, wx, GROUND - 6 - storey - 15, 8, 9, box=box if wx != 64 - 4 else None)
    if spec.get("porch"):
        px0, px1 = door_x - 6, door_x + 16
        c.shade("poly", [(px0 - 2, GROUND - 25), (px1 + 2, GROUND - 25), (px1, GROUND - 21), (px0, GROUND - 21)], roof, dither=False)
        for px in (px0, px1 - 1):
            c.fill("rect", (px, GROUND - 21, px + 1, GROUND - 6), C("5a3e28"))
    if spec.get("sign"):
        sx = door_x + 14
        c.fill("line", (sx, GROUND - 28, sx + 10, GROUND - 28), C("3a2a1e"))
        c.shade("rect", (sx + 3, GROUND - 27, sx + 13, GROUND - 19), ramp("c8a070", "a07c50", "6e5434"), dither=False)
        mark = {"inn": C("e8c060"), "smith": C("9aa4b0"), "bakery": C("e8b070")}[spec["sign"]]
        c.fill("ellipse", (sx + 6, GROUND - 25, sx + 10, GROUND - 21), mark)
    if spec.get("vines"):
        vines(c, x0, x1, wall_top + 2, GROUND - 6, seed)
    c.outline()
    return c.img


# ------------------------------------------------------------------ elves
ELF_ROOFS = [ramp("8ac08a", "5e9a68", "3a6a48"), ramp("7ac0b8", "4e9a94", "2e6a6a"), ramp("c8d4dc", "9aa8b8", "6a7888"),
             ramp("e0b060", "c08a3a", "8a5a24"), ramp("a8c870", "7a9e4a", "4e7030")]
ELF = [dict(form=f, roof=r, w=w) for f, r, w in [
    ("hall", 0, 60), ("dome", 1, 50), ("spire", 2, 44), ("tiers", 0, 58), ("roots", 4, 52),
    ("hall", 3, 66), ("dome", 2, 46), ("spire", 1, 40), ("tiers", 4, 62), ("roots", 0, 48),
    ("crescent", 1, 64), ("hall", 2, 56), ("spire", 3, 46), ("dome", 4, 54), ("crescent", 0, 60)]]


def elf_house(spec, seed):
    c = Canvas(W, H)
    w = spec["w"]
    x0, x1 = 64 - w // 2, 64 + w // 2
    roof = ELF_ROOFS[spec["roof"]]
    birch = ramp("f4f0e6", "dcd6c8", "aca698")
    living = ramp("a88a62", "7e6444", "52402a")
    glow = C("b8f0e8")
    form = spec["form"]
    c.shadow(64, GROUND, w // 2 + 8, 4)
    base = GROUND
    if form == "roots":
        # Up on its own roots: a trunk below, roots splaying into the ground.
        base = GROUND - 22
        c.shade("rect", (60, base, 68, GROUND), living, dither=False)
        for dx in (-14, -7, 7, 14):
            c.shade("line", (64, base + 10, 64 + dx, GROUND), living, width=3, dither=False)
        c.fill("line", (54, base + 2, 54, GROUND - 2), C("8a6a44"), 1)
    wall_top = base - (26 if form != "spire" else 40)
    plank_wall(c, x0 + 3, x1 - 3, wall_top, base - 1, birch)
    # Living posts curving up the corners into the eaves.
    for side, x in ((-1, x0 + 2), (1, x1 - 4)):
        c.shade("line", (x, base, x + side * -1, wall_top - 2), living, width=3, dither=False)
        c.fill("line", (x, wall_top - 2, x + side * 5, wall_top - 7), living[1], 2)
    if form == "dome":
        c.shade("ellipse", (x0 - 2, wall_top - w // 2, x1 + 2, wall_top + 8), roof, dither=False)
        scallops(c, x0 - 2, x1 + 3, wall_top - w // 2 + 5, wall_top + 7, roof)
        for dx in (-w // 4, 0, w // 4):
            c.fill("line", (64 + dx // 3, wall_top - w // 2 + 1, 64 + dx, wall_top + 6), shade(roof[2], 0.7))
        c.fill("line", (64, wall_top - w // 2, 64, wall_top - w // 2 - 6), C("d8c890"))
    elif form == "tiers":
        curved_roof(c, x0, x1, wall_top + 2, wall_top - 14, roof, tip=False)
        curved_roof(c, x0 + 10, x1 - 10, wall_top - 12, wall_top - 28, roof)
    elif form == "crescent":
        # A roof like a leaf, its tip curling up over one end.
        pts = [(x0 - 8, wall_top + 2)]
        for k in range(13):
            t = k / 12
            pts.append((x0 - 4 + (x1 - x0 + 10) * t, wall_top - 4 - 22 * math.sin(t * math.pi * 0.85) - (8 * t ** 6)))
        pts += [(x1 + 8, wall_top + 2)]
        c.shade("poly", pts, roof, dither=False)
        scallops(c, x0 - 6, x1 + 8, wall_top - 24, wall_top + 2, roof)
        c.fill("line", (x0 - 2, wall_top - 2, x1 + 4, wall_top - 16), shade(roof[2], 0.7))
        lantern(c, x1 + 6, wall_top - 8, C("c8fff0"))
    else:
        curved_roof(c, x0, x1, wall_top + 2, wall_top - (34 if form == "spire" else 22), roof)
    # Arched windows with a soft glow, a round door of living wood.
    door(c, 64 - 5, base - 1, 10, 17, wood=living, round_top=True)
    for wx in (x0 + 7, x1 - 14):
        window(c, wx, base - 20, 7, 10, frame=living[2], glow=glow, arched=True)
    if form == "spire":
        window(c, 64 - 3, wall_top + 4, 6, 8, frame=living[2], glow=glow, arched=True)
    vines(c, x0 + 2, x1 - 2, wall_top, base - 2, seed)
    lantern(c, x0 - 2, base - 22, C("c8fff0"))
    lantern(c, x1 + 2, base - 22, C("c8fff0"))
    c.outline()
    # Glow spilling from the windows (unoutlined).
    for wx in (x0 + 7, x1 - 14):
        c.img.putpixel((wx + 3, base - 9), (200, 255, 240, 120))
    return c.img


# ------------------------------------------------------------------ dwarves
DWARF_STONES = [ramp("a8a4a0", "84807c", "5c5854"), ramp("b8a088", "94806a", "6a5a48"), ramp("b8846a", "94644e", "6a4434"),
                ramp("9a9aa8", "767684", "50505c")]
DWARF = [dict(form=f, stone=s, w=w) for f, s, w in [
    ("hall", 0, 70), ("hill", 1, 64), ("forge", 2, 66), ("tower", 3, 44), ("hall", 1, 60),
    ("turf", 0, 62), ("hill", 2, 58), ("forge", 0, 72), ("tower", 1, 48), ("turf", 3, 66),
    ("hall", 2, 74), ("hill", 3, 60), ("forge", 1, 62), ("turf", 2, 56), ("tower", 0, 50)]]


def dwarf_house(spec, seed):
    c = Canvas(W, H)
    w = spec["w"]
    x0, x1 = 64 - w // 2, 64 + w // 2
    stone = DWARF_STONES[spec["stone"]]
    form = spec["form"]
    iron = C("4a4e56")
    c.shadow(64, GROUND, w // 2 + 8, 4)
    if form == "hill":
        # Dug into the hillside: a grassy mound with a stone face.
        c.shade("ellipse", (x0 - 10, GROUND - 46, x1 + 10, GROUND + 14), ramp("7aa04e", "5a8040", "3c5c30"), dither=False)
        stone_wall(c, 64 - 18, 64 + 18, GROUND - 26, GROUND - 1, stone)
        c.shade("ellipse", (64 - 20, GROUND - 34, 64 + 20, GROUND - 18), stone, dither=False)
        door(c, 64 - 7, GROUND - 1, 14, 18, iron=True, round_top=True)
        window(c, 64 - 16, GROUND - 18, 5, 6, frame=iron)
        window(c, 64 + 11, GROUND - 18, 5, 6, frame=iron)
        chimney(c, x1 - 8, GROUND - 52, GROUND - 38, stone)
        CHIMNEYS[(2, seed)] = (x1 - 5, GROUND - 54)
        c.outline()
        return c.img
    height = 34 if form != "tower" else 58
    top = GROUND - height
    stone_wall(c, x0, x1, top, GROUND - 1, stone)
    # Heavy timber lintel and corner quoins.
    for x in (x0, x1 - 4):
        for y in range(top, GROUND, 6):
            c.shade("rect", (x, y, x + 4, y + 4), [stone[0], stone[0], stone[1]], dither=False)
    if form == "turf":
        c.shade("poly", [(x0 - 4, top + 2), (x0 + 6, top - 12), (x1 - 6, top - 12), (x1 + 4, top + 2)], ramp("8ab05a", "668a44", "466a30"), dither=False)
        for x in range(x0, x1, 3):
            c.put(x, top - 12 + (x % 2), C("a8cc6a"))
    elif form == "tower":
        flat_battlement(c, x0, x1, top, stone)
    else:
        c.shade("poly", [(x0 - 4, top + 2), (x0 + 10, top - 14), (x1 - 10, top - 14), (x1 + 4, top + 2)], ramp("6a6e7a", "4e525e", "343842"), dither=False)
        for y in range(top - 11, top + 2, 3):
            c.fill("rect", (x0, y, x1, y), C("2e3038"))
    if form == "forge":
        chimney(c, x1 - 16, top - 26, top, stone, ember=True)
        CHIMNEYS[(2, seed)] = (x1 - 13, top - 28)
        c.fill("rect", (x0 + 6, GROUND - 14, x0 + 16, GROUND - 6), C("2a1a14"))
        c.fill("rect", (x0 + 7, GROUND - 10, x0 + 15, GROUND - 7), C("ff8a30"))
        c.put(x0 + 10, GROUND - 9, C("ffe080"))
    door(c, 64 - 7, GROUND - 1, 14, 19, wood=ramp("7a5434", "5a3c24", "3a2616"), iron=True, round_top=True)
    for wx in ((x0 + 10, x1 - 16) if form != "forge" else (x1 - 16,)):
        window(c, wx, GROUND - 24, 6, 7, frame=iron, glow=C("ffb860"))
    if form == "tower":
        window(c, 64 - 3, top + 8, 6, 7, frame=iron, glow=C("ffb860"))
    # Carved runes over the door, a shield banner beside it.
    for k in range(5):
        c.put(64 - 4 + k * 2, GROUND - 23, C("e8c060") if k % 2 else shade(stone[2], 0.7))
    c.shade("poly", [(x1 - 8, GROUND - 30), (x1 - 2, GROUND - 30), (x1 - 2, GROUND - 22), (x1 - 5, GROUND - 19), (x1 - 8, GROUND - 22)], ramp("c04a3a", "9a3428", "6a2018"), dither=False)
    c.put(x1 - 5, GROUND - 26, C("e8c060"))
    c.outline()
    return c.img


# ------------------------------------------------------------------ goblins
def goblin_tent(kind, seed):
    c = Canvas(W, H)
    r = random.Random(seed)
    hides = [ramp("b89a6a", "947850", "6a5434"), ramp("8a7a5a", "6a5c42", "4a4030"), ramp("a0624a", "7e4836", "543024")]
    pole = ramp("8a6a44", "6a4e30", "4a3420")
    c.shadow(64, GROUND, 34 if kind != "leader" else 54, 5)
    if kind == "cone":
        c.shade("poly", [(36, GROUND), (64, GROUND - 56), (92, GROUND)], hides[0], dither=False)
        for (px, py) in ((48, GROUND - 22), (70, GROUND - 34), (78, GROUND - 12)):
            c.shade("rect", (px, py, px + 9, py + 7), hides[r.randrange(3)], dither=False)
            c.fill("rect", (px, py, px + 9, py), C("3a2a1a"))
        for dx in (-4, 0, 4):
            c.fill("line", (64, GROUND - 56, 64 + dx * 2, GROUND - 66), pole[1], 1)
        c.fill("poly", [(58, GROUND), (64, GROUND - 22), (70, GROUND)], C("1e1610"))
    elif kind == "ridge":
        c.shade("poly", [(30, GROUND), (44, GROUND - 38), (84, GROUND - 38), (98, GROUND)], hides[1], dither=False)
        c.shade("poly", [(30, GROUND), (44, GROUND - 38), (58, GROUND)], hides[0], dither=False)
        c.fill("poly", [(38, GROUND), (44, GROUND - 22), (50, GROUND)], C("1e1610"))
        for x in range(46, 84, 6):
            c.fill("line", (x, GROUND - 37, x + 3, GROUND - 2), C("3a2a1a"))
    elif kind == "lean":
        c.shade("poly", [(32, GROUND), (40, GROUND - 40), (96, GROUND - 28), (96, GROUND)], hides[2], dither=False)
        c.fill("line", (40, GROUND - 40, 40, GROUND), pole[1], 2)
        c.fill("line", (96, GROUND - 28, 96, GROUND), pole[1], 2)
        c.shade("ellipse", (54, GROUND - 14, 74, GROUND), ramp("6a6a6a", "4a4a4a", "2e2e2e"), dither=False)
        c.fill("rect", (60, GROUND - 10, 68, GROUND - 4), C("ff8a30"))
    elif kind == "yurt":
        c.shade("poly", [(28, GROUND), (30, GROUND - 22), (44, GROUND - 40), (64, GROUND - 46), (84, GROUND - 40), (98, GROUND - 22), (100, GROUND)], hides[0], dither=False)
        for x in range(34, 96, 8):
            c.fill("line", (x, GROUND - 40, x + 2, GROUND - 4), C("5a4030"))
        c.fill("rect", (58, GROUND - 22, 70, GROUND - 4), C("1e1610"))
    else:
        # The leader's tent: tall, striped, hung with skulls and a banner.
        c.shade("poly", [(8, GROUND), (32, GROUND - 52), (64, GROUND - 92), (96, GROUND - 52), (120, GROUND)], hides[2], dither=False)
        for k in range(4):
            c.fill("poly", [(14 + k * 28, GROUND), (64, GROUND - 92), (26 + k * 28, GROUND)], shade(C("6a3a2a"), 1.0))
        c.fill("poly", [(52, GROUND), (64, GROUND - 34), (76, GROUND)], C("1e1610"))
        c.fill("line", (64, GROUND - 92, 64, GROUND - 112), pole[1], 2)
        c.fill("poly", [(65, GROUND - 112), (82, GROUND - 106), (65, GROUND - 100)], C("4a8a3a"))
        for (sx, sy) in ((30, GROUND - 40), (98, GROUND - 40)):
            c.fill("ellipse", (sx - 3, sy - 3, sx + 3, sy + 3), C("e8e0cc"))
            c.put(sx - 1, sy, C("1a1410"))
            c.put(sx + 1, sy, C("1a1410"))
        for x in (6, 120):
            c.fill("line", (x, GROUND, x, GROUND - 30), pole[1], 2)
            c.fill("ellipse", (x - 3, GROUND - 34, x + 3, GROUND - 28), C("e8e0cc"))
    c.outline()
    return c.img


# ------------------------------------------------------------------ castle
def castle():
    cw, ch = 256, 224
    c = Canvas(cw, ch)
    ground = ch - 4
    stone = ramp("b4b0bc", "8e8a98", "64606e")
    roof = ramp("6a7ab8", "4a5a94", "303c6a")
    c.shadow(128, ground, 120, 6)
    # The keep behind.
    stone_wall(c, 84, 172, 40, ground - 40, stone)
    flat_battlement(c, 84, 172, 40, stone)
    for wx in (98, 122, 146):
        window(c, wx, 60, 8, 12, frame=C("3a3640"), arched=True)
    # Curtain wall and gatehouse in front.
    stone_wall(c, 30, 226, ground - 70, ground - 1, stone)
    flat_battlement(c, 30, 226, ground - 70, stone)
    c.shade("ellipse", (106, ground - 52, 150, ground - 20), ramp("3a3640", "2a2630", "1a1820"), dither=False)
    c.fill("rect", (106, ground - 36, 150, ground - 1), C("1a1820"))
    for x in range(108, 150, 5):
        c.fill("rect", (x, ground - 48, x + 1, ground - 10), C("5a5660"))
    for y in range(ground - 44, ground - 10, 6):
        c.fill("rect", (108, y, 148, y), C("5a5660"))
    # Two round towers with conical roofs and banners.
    for tx in (14, 210):
        stone_wall(c, tx, tx + 32, ground - 100, ground - 1, stone)
        c.shade("poly", [(tx - 4, ground - 100), (tx + 16, ground - 146), (tx + 36, ground - 100)], roof, dither=False)
        for y in range(ground - 140, ground - 100, 4):
            c.fill("rect", (tx + 16 - (y - (ground - 146)) // 2, y, tx + 16 + (y - (ground - 146)) // 2, y), shade(roof[2], 0.85))
        c.fill("line", (tx + 16, ground - 146, tx + 16, ground - 160), C("5a4a3a"), 1)
        c.fill("poly", [(tx + 17, ground - 160), (tx + 30, ground - 156), (tx + 17, ground - 151)], C("c03a3a"))
        window(c, tx + 12, ground - 80, 8, 12, frame=C("3a3640"), arched=True)
    # Banners on the curtain wall.
    for bx in (60, 186):
        c.shade("rect", (bx, ground - 64, bx + 10, ground - 38), ramp("d04a4a", "a8343a", "70202a"), dither=False)
        c.fill("ellipse", (bx + 2, ground - 58, bx + 8, ground - 52), C("e8c060"))
    c.outline()
    return c.img


def main():
    rows = [[human_house(s, i) for i, s in enumerate(HUMAN)],
            [elf_house(s, i) for i, s in enumerate(ELF)],
            [dwarf_house(s, i) for i, s in enumerate(DWARF)],
            [goblin_tent(k, i) for i, k in enumerate(["cone", "ridge", "lean", "yurt", "leader"])]]
    sheet = Image.new("RGBA", (W * 15, H * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for k, img in enumerate(row):
            sheet.paste(img, (k * W, r * H))
    sheet.save(os.path.join(ROOT, "houses.png"))
    castle().save(os.path.join(ROOT, "castle.png"))
    lines = ["extends RefCounted", "## Written by tools/generate_houses.py: where smoke rises from each house's", "## chimney, by \"people,variant\", in pixels from the frame's centre.", "", "const CHIMNEYS := {"]
    for (people, variant), (x, y) in sorted(CHIMNEYS.items()):
        lines.append('\t"%d,%d": Vector2(%d, %d),' % (people, variant, x - W // 2, y - H // 2))
    lines.append("}")
    with open(os.path.join(ROOT, "..", "..", "scripts", "world", "house_art.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("houses: 15 human, 15 elf, 15 dwarf, 5 goblin tents; a castle")


if __name__ == "__main__":
    main()
