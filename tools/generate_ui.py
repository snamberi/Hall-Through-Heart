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

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
SCALE = 2


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


BRONZE = {"out": C("120c08"), "dark": C("4a3218"), "mid": C("8a6234"), "light": C("c89a52"), "hi": C("f0d088")}
GOLD = {"out": C("1a1206"), "dark": C("7a5418"), "mid": C("c8902e"), "light": C("f2c14e"), "hi": C("fff0b0")}
IRON = {"out": C("0c0d12"), "dark": C("2c303c"), "mid": C("4a5062"), "light": C("6e7488"), "hi": C("9aa0b4")}
# Ordinary cards and buttons wear this quiet blue steel, so that gold only
# ever means "chosen".
STEEL = {"out": C("080a10"), "dark": C("222838"), "mid": C("39415a"), "light": C("4e5876"), "hi": C("6a7494")}
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


def panel():
    # The main window: deep navy cloth with a faint weave, a heavy bronze
    # frame with rivets along it and worked corner bosses with red gems.
    w = h = 44
    t = 7
    img = Image.new("RGBA", (w, h))
    # The cloth is nearly flat: a few faint threads, so text reads cleanly.
    fill(img, 0, 0, w, h, C("131929"), 1, 0.025, C("161d30"), C("111624"))
    frame(img, t, BRONZE, C("06080c"))
    for k in range(t + 6, w - t - 6, 6):
        rivet(img, k, 3, BRONZE)
        rivet(img, k, h - 4, BRONZE)
        rivet(img, 3, k, BRONZE)
        rivet(img, w - 4, k, BRONZE)
    corner_piece(img, t, BRONZE, C("c83a3a"))
    save(img, "panel")


def inset():
    # A recessed well: dark, shadowed along the top and left, catching a
    # little light along the bottom and right.
    w = h = 20
    img = Image.new("RGBA", (w, h))
    # A flat reading surface.
    fill(img, 0, 0, w, h, C("0c101a"), 2, 0.012, C("0e131f"), C("0b0e17"))
    for x in range(w):
        img.putpixel((x, 0), C("05070b"))
        img.putpixel((x, 1), C("080a10"))
        img.putpixel((x, h - 1), C("3a3020"))
        img.putpixel((x, h - 2), C("1c1a1e"))
    for y in range(h):
        img.putpixel((0, y), C("05070b"))
        img.putpixel((1, y), C("080a10"))
        img.putpixel((w - 1, y), C("3a3020"))
        img.putpixel((w - 2, y), C("1c1a1e"))
    for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        img.putpixel(p, C("000000", 0))
    save(img, "inset")


def card(name, metal, base, light, dark, gem=None):
    w = h = 24
    t = 4
    img = Image.new("RGBA", (w, h))
    fill(img, 0, 0, w, h, base, zlib.crc32(name.encode()) & 0xff, 0.015, light, dark)
    frame(img, t, metal, C("06080c"))
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
        img.putpixel((x, 3), C("05070b"))
    for y in range(3, h - 3):
        img.putpixel((3, y), C("05070b"))
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
    w = h = 24
    base = C("0b0e16")
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
    for x in range(3, w - 3):
        img.putpixel((x, 3), C("05070b"))
    for y in range(3, h - 3):
        img.putpixel((3, y), C("05070b"))
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
    fill(img, 0, 0, w, h, C("0e1220", 248), 13, 0.012, C("111627", 248), C("0c0f1a", 248))
    frame(img, 3, BRONZE)
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
                            col = C("06080c")
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
                            col = C("05070b")
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
    card("card", STEEL, C("151b2b"), C("182033"), C("121725"))
    card("card_hover", BRONZE, C("1c2338"), C("20283f"), C("181e30"))
    card("card_selected", GOLD, C("2a2414"), C("352d18"), C("221d10"), C("ffd860"))
    card("card_dim", IRON, C("0e1119"), C("121621"), C("0b0d14"))
    slot("slot", IRON, C("0b0e16"))
    slot("slot_hover", BRONZE, C("141a28"))
    slot("slot_active", GOLD, C("1e1a10"))
    for index in range(len(RARITY_SLOTS)):
        rarity_slot(index)
    button("button", C("242a3c"), STEEL, C("343c52"), C("171b27"))
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
    button("button_hover", C("323a52"), GOLD, C("4a5470"), C("1e2232"))
    button("button_pressed", C("4a3a20"), GOLD, C("5e4a28"), C("2e2414"))
    button("button_disabled", C("181b24"), IRON, C("20242e"), C("12141a"))
    tooltip()
    divider()
    wheel()


if __name__ == "__main__":
    main()
