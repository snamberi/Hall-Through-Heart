#!/usr/bin/env python3
"""Draws the interface art: panel frames, cards, slots, buttons, tooltips
and the menu wheel, as pixel art at twice size (each art pixel is 2x2
screen pixels), into assets/ui/.

Run from the project folder:  python3 tools/generate_ui.py

Frames are nine-slice: the game stretches the edges and tiles the middle,
so each middle is drawn to tile seamlessly. Margins (in texture pixels,
already doubled) are listed in scripts/ui/ui_theme.gd.
"""
import math
import os
import random
import zlib
from PIL import Image

ROOT = os.environ.get("UI_OUT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
SCALE = 2


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


BRONZE = {"out": C("120c08"), "dark": C("4a3218"), "mid": C("8a6234"), "light": C("c89a52"), "hi": C("f0d088")}
GOLD = {"out": C("1a1206"), "dark": C("7a5418"), "mid": C("c8902e"), "light": C("f2c14e"), "hi": C("fff0b0")}
IRON = {"out": C("0c0a08"), "dark": C("2e2924"), "mid": C("4a433a"), "light": C("6e6558"), "hi": C("9a8f7e")}
# Ordinary cards and buttons are rimmed in dark oak, so that gold only ever
# means "chosen". (The name is kept from the old steel skin.)
STEEL = {"out": C("0c0805"), "dark": C("2e1f14"), "mid": C("4a3424"), "light": C("664a32"), "hi": C("8a6a48")}
WOOD = {"dark": C("2a1a10"), "mid": C("3a2616"), "light": C("4a321e"), "grain": C("22150c"), "knot": C("1a1008")}

# The skin in use (tools/ui_themes.py); UI_THEME=<name> draws another.
import sys  # noqa: E402
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ui_themes  # noqa: E402
THEME_NAME = os.environ.get("UI_THEME", "walnut")
T = ui_themes.THEMES[THEME_NAME]


def _metal(m):
    return {k: C(v) for k, v in m.items()}


def _shift(hexc, k):
    c = C(hexc)
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


FRAME = _metal(T["frame"])
TRIM = _metal(T["trim"])
RIM = _metal(T["rim"])
STEEL = RIM
BRONZE = FRAME
GOLD = TRIM if THEME_NAME != "walnut" else GOLD
SURFACE_KIND, _surf = T["surface"]
SURF = {k: C(v) for k, v in _surf.items()}
RED = {"out": C("14060a"), "dark": C("5a1c24"), "mid": C("8e2c36"), "light": C("c0444e"), "hi": C("e8747c")}


def save(img, name):
    img = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
    img.save(os.path.join(ROOT, name + ".png"))


def fill(img, x0, y0, x1, y1, base, seed, specks=0.08, light=None, dark=None, pattern=None):
    """A tileable textured fill: base colour with scattered lighter and
    darker pixels (wrapping, so the middle of a frame tiles cleanly)."""
    r = random.Random(seed)
    w, h = x1 - x0, y1 - y0
    for y in range(h):
        for x in range(w):
            c = base
            v = r.random()
            if dark and v < specks:
                c = dark
            elif light and v > 1.0 - specks * 0.6:
                c = light
            if pattern and pattern(x, y):
                c = dark if dark else c
            img.putpixel((x0 + x, y0 + y), c)


def frame(img, t, metal, inner_line=None):
    """A bevelled metal frame of thickness t round the image: outline, a lit
    top-left edge, a shaded bottom-right edge, and an inner outline."""
    w, h = img.size
    for d in range(t):
        for x in range(d, w - d):
            for y in (d, h - 1 - d):
                img.putpixel((x, y), _band(metal, d, t, y == d))
        for y in range(d, h - d):
            for x in (d, w - 1 - d):
                img.putpixel((x, y), _band(metal, d, t, x == d))
    if inner_line:
        for x in range(t, w - t):
            img.putpixel((x, t), inner_line)
        for y in range(t, h - t):
            img.putpixel((t, y), inner_line)


def _band(metal, d, t, lit):
    if d == 0 or d == t - 1:
        return metal["out"]
    if d == 1:
        return metal["hi"] if lit else metal["dark"]
    if d == t - 2:
        return metal["dark"]
    return metal["light"] if lit else metal["mid"]


def rivet(img, x, y, metal):
    for dx, dy, c in ((0, 0, "light"), (1, 0, "mid"), (0, 1, "mid"), (1, 1, "dark")):
        img.putpixel((x + dx, y + dy), metal[c])
    img.putpixel((x, y), metal["hi"])


def corner_piece(img, t, metal, gem=None):
    """Ornate corners: a small square boss over each corner with a gem."""
    w, h = img.size
    s = t + 3
    for cx, cy in ((0, 0), (w - s, 0), (0, h - s), (w - s, h - s)):
        for y in range(s):
            for x in range(s):
                edge = x in (0, s - 1) or y in (0, s - 1)
                lit = x <= 1 or y <= 1
                img.putpixel((cx + x, cy + y), metal["out"] if edge else (metal["light"] if lit else metal["mid"]))
        m = s // 2
        if gem:
            img.putpixel((cx + m, cy + m), gem)
            img.putpixel((cx + m - 1, cy + m), gem)
            img.putpixel((cx + m, cy + m - 1), gem)
            img.putpixel((cx + m - 1, cy + m - 1), C("ffffff"))
        else:
            rivet(img, cx + m - 1, cy + m - 1, metal)


def wood_grain(img, x0, y0, x1, y1, seed, palette=None):
    """Dark walnut planks: long wavy grain lines running across, a seam
    between planks every 11 pixels, the odd knot. Tiles cleanly."""
    pal = palette or WOOD
    r = random.Random(seed)
    w, h = x1 - x0, y1 - y0
    for y in range(h):
        plank = y // 11
        seam = y % 11 == 10
        for x in range(w):
            wave = math.sin((x / w) * math.tau * 2 + plank * 1.7) * 1.2
            band = (y + wave + plank * 3) % 4
            c = pal["mid"] if band < 2 else pal["dark"] if band < 3 else pal["light"] if r.random() < 0.15 else pal["mid"]
            if r.random() < 0.025:
                c = pal["grain"]
            if seam:
                c = pal["knot"]
            img.putpixel((x0 + x, y0 + y), c)


def surface(img, x0, y0, x1, y1, seed):
    """The window's surface, in the theme's material; every pattern repeats
    every 11 pixels so the middle of the frame tiles cleanly."""
    pal = SURF
    if SURFACE_KIND == "wood":
        wood_grain(img, x0, y0, x1, y1, seed, pal)
        return
    r = random.Random(seed)
    w, h = x1 - x0, y1 - y0
    for y in range(h):
        for x in range(w):
            c = pal["mid"]
            v = r.random()
            if SURFACE_KIND == "cloth":
                # A fine weave: alternate threads a shade apart.
                c = pal["light"] if (x + y) % 2 == 0 and y % 2 == 0 else pal["mid"] if (x + y) % 2 == 0 else pal["dark"] if v < 0.4 else pal["mid"]
                if v < 0.012:
                    c = pal["knot"]
            elif SURFACE_KIND == "stone":
                # Dressed blocks 22 wide and 11 high, offset each course, with mortar.
                row = y // 11
                bx = (x + (11 if row % 2 else 0)) % 22
                if y % 11 == 10 or bx == 21:
                    c = pal["grain"] if v > 0.03 else pal["knot"]
                else:
                    c = pal["light"] if (y % 11 < 2 or bx < 2) else pal["dark"] if (y % 11 > 7 or bx > 18) else pal["mid"]
                    if v < 0.05:
                        c = pal["dark"]
            elif SURFACE_KIND == "leather":
                # Tooled leather: soft mottling and pores.
                n = (math.sin(x * 0.57) + math.sin(y * 0.57 + 1.3) + math.sin((x + y) * 0.285))
                c = pal["light"] if n > 1.2 else pal["dark"] if n < -1.2 else pal["mid"]
                if v < 0.03:
                    c = pal["grain"]
            elif SURFACE_KIND == "glass":
                # Frosted glass: faint diagonal streaks and the odd glint.
                band = (x + y) % 11
                c = pal["light"] if band == 0 else pal["mid"] if band < 6 else pal["dark"]
                if v < 0.01:
                    c = pal["knot"]
            img.putpixel((x0 + x, y0 + y), c)


def gold_trim(img, t):
    """A gold inner rule just inside a frame of thickness t, with small
    leaf flourishes at the corners."""
    w, h = img.size
    for x in range(t + 1, w - t - 1):
        img.putpixel((x, t + 1), TRIM["mid"])
        img.putpixel((x, h - t - 2), TRIM["dark"])
    for y in range(t + 1, h - t - 1):
        img.putpixel((t + 1, y), TRIM["mid"])
        img.putpixel((w - t - 2, y), TRIM["dark"])
    for (cx, cy, sx, sy) in ((t + 1, t + 1, 1, 1), (w - t - 2, t + 1, -1, 1), (t + 1, h - t - 2, 1, -1), (w - t - 2, h - t - 2, -1, -1)):
        # (Kept within the nine-slice margin, so it never repeats.)
        img.putpixel((cx, cy), TRIM["hi"])
        img.putpixel((cx + sx, cy), TRIM["light"])
        img.putpixel((cx, cy + sy), TRIM["light"])


def panel():
    # The main window: a book's board of dark walnut, bound in a heavy
    # bronze frame with brass studs, a gold rule inside it, and worked gold
    # corner bosses set with red gems.
    w = h = 44
    t = 7
    img = Image.new("RGBA", (w, h))
    surface(img, 0, 0, w, h, 1)
    frame(img, t, FRAME, C("0a0604"))
    for k in range(t + 6, w - t - 6, 6):
        rivet(img, k, 3, TRIM)
        rivet(img, k, h - 4, TRIM)
        rivet(img, 3, k, TRIM)
        rivet(img, w - 4, k, TRIM)
    gold_trim(img, t)
    corner_piece(img, t, TRIM, C(T["gem"]))
    save(img, "panel")


def inset():
    # A page of the book: aged, smoke-darkened vellum (dark enough that the
    # cream ink of the text reads at a glance), with faint fibres, its edge
    # sunk into the board and a thin gilt rule round it.
    w = h = 20
    img = Image.new("RGBA", (w, h))
    base, fibre_light, fibre_dark, rule, lip = T["page"]
    fill(img, 0, 0, w, h, C(base), 2, 0.03, C(fibre_light), C(fibre_dark))
    for x in range(w):
        img.putpixel((x, 0), C("0a0604"))
        img.putpixel((x, 1), _shift(base, 0.5))
        img.putpixel((x, 2), C(rule))
        img.putpixel((x, h - 1), C(lip))
        img.putpixel((x, h - 2), _shift(base, 0.5))
        img.putpixel((x, h - 3), _shift(rule, 0.85))
    for y in range(h):
        img.putpixel((0, y), C("0a0604"))
        img.putpixel((1, y), _shift(base, 0.5))
        img.putpixel((2, y), C(rule))
        img.putpixel((w - 1, y), C(lip))
        img.putpixel((w - 2, y), _shift(base, 0.5))
        img.putpixel((w - 3, y), _shift(rule, 0.85))
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        img.putpixel(p, C("000000", 0))
    save(img, "inset")


def card(name, metal, base, light, dark, gem=None):
    w = h = 24
    t = 4
    img = Image.new("RGBA", (w, h))
    fill(img, 0, 0, w, h, base, zlib.crc32(name.encode()) & 0xff, 0.015, light, dark)
    frame(img, t, metal, C("0a0604"))
    if gem:
        corner_piece(img, t - 1, metal, gem)
    save(img, name)


def slot(name, metal, base):
    # An item slot: a sunken square with a thin metal lip.
    w = h = 16
    img = Image.new("RGBA", (w, h))
    fill(img, 0, 0, w, h, base, 7, 0.05, None, C("080a10"))
    frame(img, 3, metal)
    for x in range(3, w - 3):
        img.putpixel((x, 3), C("0a0604"))
    for y in range(3, h - 3):
        img.putpixel((3, y), C("0a0604"))
    save(img, name)


# One slot per rarity (common .. mythic): the lip is worked in that
# rarity's metal, the well glows its colour from the middle out in hard
# pixel bands, and finer things get gems and filigree in the corners.
RARITY_SLOTS = [
    # (glow colour, metal, glow strength, corner style)
    ("c8c4b8", IRON, 0.0, None),
    ("5fd068", {"out": C("0c120c"), "dark": C("24402a"), "mid": C("3a6a40"), "light": C("5a9a5e"), "hi": C("9ad89a")}, 0.22, None),
    ("4f9dff", {"out": C("0a0e18"), "dark": C("223a64"), "mid": C("33589a"), "light": C("5a86d0"), "hi": C("a8c8ff")}, 0.3, "pips"),
    ("b565f0", {"out": C("120a18"), "dark": C("3e2460"), "mid": C("5e3a8e"), "light": C("8e62c8"), "hi": C("d4b0ff")}, 0.36, "gems"),
    ("ff9a2e", GOLD, 0.42, "filigree"),
    ("ff4d6d", {"out": C("1a0608"), "dark": C("6a1a26"), "mid": C("a0283c"), "light": C("e05a6a"), "hi": C("ffc0c8")}, 0.48, "filigree"),
]


def rarity_slot(index):
    glow, metal, strength, corners = RARITY_SLOTS[index]
    glow = C(glow)
    if index == 0:
        # Plain things sit in the style's own quiet rim.
        metal = RIM
    w = h = 24
    base = C(T["slot"])
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            d = max(abs(x - 11.5), abs(y - 11.5) * 1.05) / 11.5
            r = (((x - 11.5) ** 2 + (y - 11.5) ** 2) ** 0.5) / 12.0
            t = max(0.0, 1.0 - min(d, r * 1.1))
            band = 0.0 if t < 0.25 else 0.35 if t < 0.5 else 0.65 if t < 0.75 else 1.0
            a = strength * band
            c = tuple(int(base[i] + (glow[i] - base[i]) * a) for i in range(3)) + (255,)
            if strength > 0.0 and (x * 7 + y * 13) % 29 == 0 and band > 0.3:
                c = tuple(min(255, int(v + 18)) for v in c[:3]) + (255,)
            img.putpixel((x, y), c)
    frame(img, 3, metal)
    # The well's shadow under the lip, in the slot's own darkest tone.
    shadow = tuple(int(v * 0.35) for v in base[:3]) + (255,)
    for x in range(3, w - 3):
        img.putpixel((x, 3), shadow)
    for y in range(3, h - 3):
        img.putpixel((3, y), shadow)
    if strength >= 0.3:
        # Finer things: a lit rim of their colour inside the well, brightest
        # on the far edges where the glow catches it.
        lit = tuple(min(255, int(base[i] + (glow[i] - base[i]) * 0.8)) for i in range(3)) + (255,)
        for k in range(5, w - 4):
            img.putpixel((k, h - 4), lit)
            img.putpixel((w - 4, k), lit)
    if index >= 4:
        # A set stone at the top of the frame.
        cx = w // 2 - 2
        for y in range(0, 3):
            for x in range(4):
                edge = x in (0, 3) or y == 0
                img.putpixel((cx + x, y), metal["out"] if edge and y == 0 else (glow if not edge else metal["dark"]))
        img.putpixel((cx + 1, 1), C("ffffff"))
    if corners == "pips":
        for (x, y) in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
            img.putpixel((x, y), metal["hi"])
    elif corners == "gems":
        for (cx, cy) in ((0, 0), (w - 4, 0), (0, h - 4), (w - 4, h - 4)):
            for y in range(4):
                for x in range(4):
                    edge = x in (0, 3) or y in (0, 3)
                    img.putpixel((cx + x, cy + y), metal["out"] if edge else glow)
            img.putpixel((cx + 1, cy + 1), C("ffffff"))
    elif corners == "filigree":
        for (cx, cy, sx, sy) in ((0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)):
            for k in range(6):
                img.putpixel((cx + k * sx, cy), metal["hi"] if k < 3 else metal["light"])
                img.putpixel((cx, cy + k * sy), metal["hi"] if k < 3 else metal["light"])
            for (dx, dy) in ((1, 1), (2, 1), (1, 2)):
                img.putpixel((cx + dx * sx, cy + dy * sy), glow)
            img.putpixel((cx + 4 * sx, cy + 1 * sy), metal["mid"])
            img.putpixel((cx + 1 * sx, cy + 4 * sy), metal["mid"])
        for k in range(8, w - 8, 3):
            if not w // 2 - 3 <= k <= w // 2 + 2:
                img.putpixel((k, 1), metal["hi"])
            img.putpixel((k, h - 2), metal["mid"])
    save(img, "slot_r%d" % index)


def button(name, face, metal, edge_lit, edge_dark):
    # A stone button with a bevel and a metal rim.
    w, h = 20, 16
    img = Image.new("RGBA", (w, h))
    fill(img, 0, 0, w, h, face, 11, 0.0, edge_lit, edge_dark)
    frame(img, 2, metal)
    for x in range(2, w - 2):
        img.putpixel((x, 2), edge_lit)
        img.putpixel((x, h - 3), edge_dark)
    for y in range(2, h - 2):
        img.putpixel((2, y), edge_lit)
        img.putpixel((w - 3, y), edge_dark)
    save(img, name)


def tab(name, face, metal, lit, dark):
    """A folder tab for a page: chamfered top corners, a metal lip along
    the top and sides, open at the bottom where it meets its page."""
    w, h = 20, 14
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            corner = (x + y < 3) or (w - 1 - x + y < 3)
            if corner:
                continue
            edge_top = y == 0 or (x + y == 3) or (w - 1 - x + y == 3)
            edge_side = x == 0 or x == w - 1
            if edge_top or edge_side:
                c = metal["out"]
            elif y == 1 or x == 1:
                c = metal["light"] if y == 1 else metal["mid"]
            elif x == w - 2:
                c = metal["dark"]
            elif y == 2:
                c = lit
            elif y >= h - 2:
                c = dark
            else:
                c = face
            img.putpixel((x, y), c)
    save(img, name)


def cursor():
    """The pointer: an arrowhead in the style's trim metal, outlined, lit
    along its left edge (art 11x16, hotspot at its tip)."""
    rows = [
        "O..........",
        "OO.........",
        "OhO........",
        "OhLO.......",
        "OhLLO......",
        "OhLLMO.....",
        "OhLLMMO....",
        "OhLLMMMO...",
        "OhLLMMMDO..",
        "OhLLMMMDDO.",
        "OhLLMOOOOOO",
        "OhLOLMO....",
        "OhO.OLMO...",
        "OO..OLMO...",
        "O....OLMO..",
        ".....OOO...",
    ]
    keys = {"O": TRIM["out"], "h": TRIM["hi"], "L": TRIM["light"], "M": TRIM["mid"], "D": TRIM["dark"]}
    img = Image.new("RGBA", (11, 16))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in keys:
                img.putpixel((x, y), keys[ch])
    save(img, "cursor")


def focus_ring():
    # Keyboard focus: a bright double line round a control, clear in the
    # middle so it can be laid over anything.
    w = h = 16
    img = Image.new("RGBA", (w, h))
    for x in range(w):
        for y in range(h):
            edge = min(x, y, w - 1 - x, h - 1 - y)
            if edge == 0:
                img.putpixel((x, y), C("fff6d0"))
            elif edge == 1:
                img.putpixel((x, y), C("f2c14e"))
            elif edge == 2:
                img.putpixel((x, y), C("06080c", 200))
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        img.putpixel(p, C("000000", 0))
    save(img, "focus")


def check(name, on, lit=False):
    # A tick box: a dark well with a clear lip; ticked, it holds a gold mark.
    w = h = 12
    img = Image.new("RGBA", (w, h))
    rim = GOLD if lit else STEEL
    for x in range(w):
        for y in range(h):
            edge = min(x, y, w - 1 - x, h - 1 - y)
            if edge == 0:
                img.putpixel((x, y), rim["out"])
            elif edge == 1:
                img.putpixel((x, y), rim["hi"] if (x == 1 or y == 1) else rim["light"])
            else:
                img.putpixel((x, y), C("0a0d15"))
    if on:
        for x, y in ((3, 6), (4, 7), (5, 8), (6, 7), (7, 6), (8, 5), (9, 4), (3, 7), (4, 8), (5, 9), (6, 8), (7, 7), (8, 6), (9, 5)):
            img.putpixel((x, y), GOLD["light"] if y < 8 else GOLD["mid"])
    save(img, name)


def grabber(name, metal):
    # The handle of a slider: a tall stud, big enough to catch.
    w, h = 8, 12
    img = Image.new("RGBA", (w, h))
    for x in range(w):
        for y in range(h):
            edge = min(x, y, w - 1 - x, h - 1 - y)
            c = metal["out"] if edge == 0 else (metal["hi"] if (x == 1 or y == 1) else metal["mid"] if edge == 1 else metal["light"])
            img.putpixel((x, y), c)
    for y in range(4, 8):
        img.putpixel((3, y), metal["dark"])
        img.putpixel((4, y), metal["hi"])
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        img.putpixel(p, C("000000", 0))
    save(img, name)


def lock_icon():
    # A small padlock for locked things.
    w = h = 12
    img = Image.new("RGBA", (w, h))
    body, lit, dark = C("8a90a4"), C("c0c6d8"), C("3a4052")
    for x in range(2, 10):
        for y in range(5, 11):
            img.putpixel((x, y), dark if x in (2, 9) or y in (5, 10) else body)
    for x in range(3, 9):
        img.putpixel((x, 6), lit)
    for x, y in ((4, 4), (4, 3), (4, 2), (5, 1), (6, 1), (7, 2), (7, 3), (7, 4)):
        img.putpixel((x, y), body)
    for x, y in ((3, 4), (3, 3), (3, 2), (4, 1), (5, 0), (6, 0), (7, 1), (8, 2), (8, 3), (8, 4)):
        img.putpixel((x, y), dark)
    img.putpixel((5, 7), C("0a0d15"))
    img.putpixel((6, 7), C("0a0d15"))
    img.putpixel((5, 8), C("0a0d15"))
    img.putpixel((6, 8), C("0a0d15"))
    save(img, "lock")


def tick_icon():
    # A green tick in a ring, for done and owned things.
    w = h = 12
    img = Image.new("RGBA", (w, h))
    for x, y in ((2, 6), (3, 7), (4, 8), (5, 7), (6, 6), (7, 5), (8, 4), (9, 3)):
        img.putpixel((x, y), C("a8f080"))
        img.putpixel((x, y + 1), C("5fb040"))
        if y + 2 < h:
            img.putpixel((x, y + 2), C("1a2a14"))
    save(img, "tick")


def tooltip():
    w = h = 20
    img = Image.new("RGBA", (w, h))
    tip = T["tooltip"]
    fill(img, 0, 0, w, h, C(tip, 250), 13, 0.03, _shift(tip, 1.15)[:3] + (250,), _shift(tip, 0.85)[:3] + (250,))
    frame(img, 3, TRIM)
    for p in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        img.putpixel(p, BRONZE["hi"])
    save(img, "tooltip")


def divider():
    # A worked rule for under headings: a line with a diamond in the middle.
    w, h = 64, 5
    img = Image.new("RGBA", (w, h))
    for x in range(2, w - 2):
        img.putpixel((x, 2), BRONZE["mid"] if abs(x - w // 2) > 4 else BRONZE["light"])
        img.putpixel((x, 3), BRONZE["out"])
    m = w // 2
    for dy, span in ((0, 0), (1, 1), (2, 2), (3, 1), (4, 0)):
        for dx in range(-span, span + 1):
            img.putpixel((m + dx, dy), GOLD["light"] if dx <= 0 and dy <= 2 else GOLD["mid"])
    save(img, "divider")


def wheel():
    """The menu wheel: eight wedges in a bronze ring round a dark hub, with
    a round socket in each wedge for its icon. Drawn once whole, then once
    more per wedge lit gold for when it is pointed at."""
    size = 280
    c = size / 2.0
    # A slim rim: the wedges and the one that is lit carry the weight.
    outer, rim, inner, hub = 134, 129, 52, 48
    sockets = 88
    r = random.Random(5)
    noise = [[r.random() for _ in range(size)] for _ in range(size)]

    def wedge_of(dx, dy):
        a = (math.atan2(dy, dx) + math.pi / 2.0) % (2 * math.pi)
        return int((a + math.pi / 8.0) % (2 * math.pi) / (math.pi / 4.0)) % 8, a

    def draw(lit_index):
        img = Image.new("RGBA", (size, size))
        for y in range(size):
            for x in range(size):
                dx, dy = x + 0.5 - c, y + 0.5 - c
                d = math.hypot(dx, dy)
                if d > outer + 1:
                    continue
                index, a = wedge_of(dx, dy)
                n = noise[y][x]
                lit = (dx + dy) < 0
                if lit_index is not None and index != lit_index:
                    continue
                if d > rim:
                    # The rim: bronze, lit on the top-left.
                    band = d - rim
                    if band > outer - rim - 1:
                        col = BRONZE["out"]
                    elif band < 1:
                        col = BRONZE["out"]
                    else:
                        col = BRONZE["mid"] if lit else BRONZE["dark"]
                    if lit_index is not None:
                        col = GOLD["hi"] if band > 1 and band < outer - rim - 1 else GOLD["mid"]
                elif d > inner:
                    # Wedge bodies, split by bronze spokes.
                    spoke = abs(((a + math.pi / 8.0) % (math.pi / 4.0)) - 0) * d
                    spoke2 = abs((math.pi / 4.0) - ((a + math.pi / 8.0) % (math.pi / 4.0))) * d
                    if min(spoke, spoke2) < 1.6:
                        col = BRONZE["out"]
                    elif min(spoke, spoke2) < 2.8:
                        col = BRONZE["mid"]
                    else:
                        if lit_index is None:
                            base = C("161c2e")
                            if d > rim - 6:
                                base = C("1c2338")
                        else:
                            base = C("4e3c1c")
                            if d > rim - 6:
                                base = C("7a5c26")
                        col = base
                        if d < inner + 3:
                            col = C("0a0d16")
                elif lit_index is None:
                    if d > hub:
                        col = BRONZE["light"] if lit else BRONZE["mid"]
                        if d > inner - 1 or d < hub + 1:
                            col = BRONZE["out"]
                    else:
                        col = C("0c101a") if n > 0.08 else C("10151f")
                        if d > hub - 3:
                            col = C("0a0604")
                else:
                    continue
                img.putpixel((x, y), col)
        # A socket for each icon.
        for index in range(8):
            if lit_index is not None and index != lit_index:
                continue
            a = -math.pi / 2.0 + index * math.pi / 4.0
            sx, sy = c + math.cos(a) * sockets, c + math.sin(a) * sockets - 6
            for y in range(int(sy - 22), int(sy + 23)):
                for x in range(int(sx - 22), int(sx + 23)):
                    d = math.hypot(x + 0.5 - sx, y + 0.5 - sy)
                    if d < 21:
                        lit = (x - sx + y - sy) < 0
                        if d > 19.5:
                            col = BRONZE["out"]
                        elif d > 17.5:
                            if lit_index is None:
                                col = BRONZE["light"] if lit else BRONZE["dark"]
                            else:
                                col = GOLD["hi"] if lit else GOLD["mid"]
                        elif d > 16.5:
                            col = C("0a0604")
                        else:
                            col = C("0a0e18") if lit_index is None else C("2a2210")
                        img.putpixel((x, y), col)
        return img

    img = draw(None)
    img.resize((size * SCALE, size * SCALE), Image.NEAREST).save(os.path.join(ROOT, "wheel.png"))
    sheet = Image.new("RGBA", (size * 8, size))
    for index in range(8):
        sheet.paste(draw(index), (index * size, 0))
    sheet.resize((size * 8 * SCALE, size * SCALE), Image.NEAREST).save(os.path.join(ROOT, "wheel_lit.png"))


def main():
    os.makedirs(ROOT, exist_ok=True)
    panel()
    inset()
    for name, metal in (("card", RIM), ("card_hover", FRAME), ("card_selected", TRIM), ("card_dim", IRON)):
        base = T[name]
        card(name, metal, C(base), _shift(base, 1.15), _shift(base, 0.85), C("ffd860") if name == "card_selected" else None)
    slot("slot", FRAME, C(T["slot"]))
    slot("slot_hover", TRIM, _shift(T["slot"], 1.5))
    slot("slot_active", TRIM, _shift(T["slot"], 2.0))
    for index in range(len(RARITY_SLOTS)):
        rarity_slot(index)
    face, lit, dark = T["button"]
    button("button", C(face), RIM, C(lit), C(dark))
    button("button_primary", C("c8902e"), GOLD, C("f2c14e"), C("8a6220"))
    button("button_primary_hover", C("dca43a"), GOLD, C("ffe08a"), C("9a6e24"))
    button("button_primary_pressed", C("a8761f"), GOLD, C("c8902e"), C("6e4c14"))
    button("button_danger", C("2e1c22"), RED, C("46262e"), C("1c1014"))
    button("button_danger_hover", C("46222a"), RED, C("68323c"), C("281418"))
    focus_ring()
    check("check_off", False)
    check("check_on", True)
    check("check_off_hover", False, True)
    check("check_on_hover", True, True)
    grabber("grabber", BRONZE)
    grabber("grabber_hover", GOLD)
    lock_icon()
    tick_icon()
    for name in ("button_hover", "button_pressed"):
        button(name, C(T[name]), TRIM, _shift(T[name], 1.3), _shift(T[name], 0.7))
    button("button_disabled", C(T["button_disabled"]), IRON, _shift(T["button_disabled"], 1.2), _shift(T["button_disabled"], 0.8))
    tooltip()
    divider()
    face, lit, dark = T["button"]
    tab("tab", _shift(face, 0.85), RIM, C(lit), _shift(face, 0.6))
    tab("tab_hover", C(T["button_hover"]), TRIM, _shift(T["button_hover"], 1.3), _shift(T["button_hover"], 0.7))
    base = T["page"][0]
    tab("tab_active", C(base), TRIM, _shift(base, 1.08), C(base))
    cursor()
    # The menu wheel is shared by every style; it is drawn only with the base set.
    if not os.environ.get("UI_OUT"):
        wheel()


if __name__ == "__main__":
    main()
