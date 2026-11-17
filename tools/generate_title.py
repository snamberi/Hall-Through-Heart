#!/usr/bin/env python3
"""Draws the title screen: the logo and the panorama behind it, pixel by
pixel, into assets/ui/.

The logo: chunky block letters in bronze, lit along their top and left,
with a deep face dropped below them so they stand like carved blocks; moss
and grass growing over their tops, a few vines hanging, and the O of
THROUGH a heart. HEART, below, is larger and laced with veins.

The panorama: a night over the dead god's land in layers that scroll at
their own pace and wrap round: the sky with its moon, far mountains with
snow, the hills where the Sanctuary stands, and dark woods in front. Every
layer is 240 art pixels tall and shown at a whole-number scale.

Run from the project folder:  python3 tools/generate_title.py
"""
import math
import os
import random

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


# ======================================================================
# The logo
# ======================================================================

# A heavy face: every stroke two cells thick, so the letters read as solid
# carved blocks even small.
GLYPHS = {
    "H": ["XX...XX", "XX...XX", "XX...XX", "XXXXXXX", "XXXXXXX", "XX...XX", "XX...XX", "XX...XX", "XX...XX"],
    "A": [".XXXXX.", "XXXXXXX", "XX...XX", "XX...XX", "XXXXXXX", "XXXXXXX", "XX...XX", "XX...XX", "XX...XX"],
    "L": ["XX.....", "XX.....", "XX.....", "XX.....", "XX.....", "XX.....", "XX.....", "XXXXXXX", "XXXXXXX"],
    "T": ["XXXXXXX", "XXXXXXX", "..XXX..", "..XXX..", "..XXX..", "..XXX..", "..XXX..", "..XXX..", "..XXX.."],
    "R": ["XXXXXX.", "XXXXXXX", "XX...XX", "XX...XX", "XXXXXX.", "XXXXX..", "XX.XXX.", "XX..XXX", "XX...XX"],
    "U": ["XX...XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", "XXXXXXX", ".XXXXX."],
    "G": [".XXXXX.", "XXXXXXX", "XX.....", "XX.....", "XX..XXX", "XX..XXX", "XX...XX", "XXXXXXX", ".XXXXX."],
    "E": ["XXXXXXX", "XXXXXXX", "XX.....", "XX.....", "XXXXXX.", "XXXXXX.", "XX.....", "XXXXXXX", "XXXXXXX"],
    "O": [".XXXXX.", "XXXXXXX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX", "XXXXXXX", ".XXXXX."],
    # The heart that takes the O's place.
    "♥": [".......", ".XX.XX.", "XXXXXXX", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X...", "......."],
    " ": [".......", ".......", ".......", ".......", ".......", ".......", ".......", ".......", "......."],
}
GLYPH_W, GLYPH_H = 7, 9

# Old, tarnished bronze: the hall is long dead.
BRONZE = [C("f0d8a0"), C("d4a858"), C("b07a38"), C("845426"), C("4e2e14")]   # hi, light, mid, shade, deep
DEPTH = [C("6a4220"), C("5a361a"), C("4a2c16"), C("3a2212"), C("2c1a0e"), C("22140c")]
HEART_FACE = [C("ffb0b8"), C("f05a6a"), C("d03848"), C("a02436"), C("6e1424")]
OUTLINE = C("0a0c16")
MOSS = [C("8aa850"), C("5e7a36"), C("3e5a2a"), C("283c1e")]
VINE = [C("4a5e30"), C("2e3c20")]
BLOOD = [C("e04050"), C("a01828"), C("6a0c18")]


def letters(text, block, gap):
    """The face pixels of a line of text: {(x, y): material}."""
    cells = {}
    x0 = 0
    for ch in text:
        rows = GLYPHS[ch]
        for gy, row in enumerate(rows):
            for gx, mark in enumerate(row):
                if mark == "X":
                    for dy in range(block):
                        for dx in range(block):
                            cells[(x0 + gx * block + dx, gy * block + dy)] = "heart" if ch == "♥" else "bronze"
        x0 += GLYPH_W * block + gap
    return cells, x0 - gap


def draw_line(img, text, block, gap, ox, oy, depth, seed, veins=False):
    r = random.Random(seed)
    cells, width = letters(text, block, gap)
    face = {(x + ox, y + oy): m for (x, y), m in cells.items()}
    height = GLYPH_H * block
    # The dropped face: the letters' bodies seen below their tops.
    for d in range(depth, 0, -1):
        for (x, y), m in face.items():
            p = (x, y + d)
            if p not in face:
                tone = DEPTH[min(d - 1 + (1 if m == "heart" else 0), len(DEPTH) - 1)]
                if m == "heart":
                    tone = mix(tone, C("6e1424"), 0.6)
                img.putpixel(p, tone)
    # The faces: lit from the upper left, a gradient from top to bottom,
    # worn chips here and there.
    for (x, y), m in face.items():
        ramp = HEART_FACE if m == "heart" else BRONZE
        t = (y - oy) / max(height - 1, 1)
        tone = 1 if t < 0.35 else 2 if t < 0.75 else 3
        if (x, y - 1) not in face or (x - 1, y) not in face:
            tone = 0 if tone <= 1 else 1
        elif (x + 1, y) not in face or (x, y + 1) not in face:
            tone = 3 if tone < 3 else 4
        c = ramp[tone]
        if tone in (1, 2) and r.random() < 0.06:
            c = ramp[tone + 1]
        img.putpixel((x, y), c)
    # Cracks in a few letters.
    for _ in range(3 if not veins else 0):
        x, y = r.choice(sorted(face))
        for _ in range(r.randint(2, 4)):
            if (x, y) in face and face[(x, y)] == "bronze":
                img.putpixel((x, y), BRONZE[4])
            x += r.choice((0, 1))
            y += 1
    if veins:
        # Crimson veins running through HEART.
        for _ in range(7):
            x, y = r.choice(sorted(p for p in face if face[p] == "bronze"))
            for _ in range(r.randint(3, 7)):
                if (x, y) in face and face[(x, y)] == "bronze":
                    img.putpixel((x, y), C("a83040") if r.random() < 0.7 else C("d85060"))
                x += r.choice((-1, 0, 1))
                y += r.choice((0, 1, 1))
    # The heart's shine.
    for (x, y), m in face.items():
        if m == "heart" and (x - 1, y) not in face and (x, y - 1) not in face:
            img.putpixel((x + 1, y + 1), HEART_FACE[0])
    return face, width


def grow_moss(img, face, seed, amount=0.55):
    """Moss over the letters' tops, grass blades standing up from it, and
    vines hanging down their fronts."""
    r = random.Random(seed)
    solid = set(face)
    tops = sorted(p for p in face if (p[0], p[1] - 1) not in face and face[p] == "bronze")
    blades = []
    for (x, y) in tops:
        if r.random() > amount:
            continue
        img.putpixel((x, y), MOSS[1] if r.random() < 0.6 else MOSS[2])
        if (x, y + 1) in face and r.random() < 0.5:
            img.putpixel((x, y + 1), MOSS[2])
        if r.random() < 0.45:
            h = r.randint(1, 3)
            for k in range(1, h + 1):
                blades.append(((x, y - k), MOSS[0] if k == h else MOSS[1]))
    vines = []
    bottoms = sorted(p for p in face if (p[0], p[1] + 1) not in face and face[p] == "bronze")
    for (x, y) in bottoms:
        if r.random() < 0.05:
            length = r.randint(4, 9)
            for k in range(length):
                vy = y + k
                vx = x + (1 if (k // 3) % 2 else 0)
                vines.append(((vx, vy), VINE[0] if k % 3 else VINE[1]))
                if k % 3 == 1:
                    vines.append(((vx + 1, vy), MOSS[1]))
    return blades, vines


def outline(img, keep_out=()):
    w, h = img.size
    solid = {(x, y) for y in range(h) for x in range(w) if img.getpixel((x, y))[3] > 0}
    for y in range(h):
        for x in range(w):
            if (x, y) in solid or (x, y) in keep_out:
                continue
            if any((x + dx, y + dy) in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                img.putpixel((x, y), OUTLINE)


def bleed(img, face1, face2):
    """Blood: drips running off the bottoms of the letters and the heart,
    each ending in a drop, and spatter across HEART."""
    r = random.Random(66)
    w, h = img.size
    faces = dict(face1)
    faces.update(face2)
    bottoms = sorted(p for p in faces if (p[0], p[1] + 1) not in faces)
    for (x, y) in bottoms:
        heart = faces[(x, y)] == "heart"
        if r.random() > (0.5 if heart else 0.09):
            continue
        # Below the dropped face of the letter.
        y0 = y + 1
        while y0 < h and img.getpixel((x, y0))[3] > 0:
            y0 += 1
        length = r.randint(2, 8 if not heart else 10)
        for k in range(length):
            if y0 + k < h:
                img.putpixel((x, y0 + k), BLOOD[1] if k < length - 1 else BLOOD[2])
        if y0 + length < h - 1:
            img.putpixel((x, y0 + length), BLOOD[1])
            if x + 1 < w:
                img.putpixel((x + 1, y0 + length), BLOOD[2])
        # The face it runs from is stained.
        img.putpixel((x, y), BLOOD[1])
        if (x, y - 1) in faces:
            img.putpixel((x, y - 1), BLOOD[0] if r.random() < 0.5 else BLOOD[1])
    for _ in range(14):
        x, y = r.choice(sorted(face2))
        for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 1), (2, -1))[:r.randint(2, 5)]:
            if (x + dx, y + dy) in faces:
                img.putpixel((x + dx, y + dy), BLOOD[r.randint(0, 2)])


def logo():
    w, h = 252, 92
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    top_block, top_gap = 2, 3
    _cells, top_width = letters("HALL THR♥UGH", top_block, top_gap)
    face1, _ = draw_line(img, "HALL THR♥UGH", top_block, top_gap, (w - top_width) // 2, 6, 5, 1)
    _cells, big_width = letters("HEART", 3, 4)
    face2, _ = draw_line(img, "HEART", 3, 4, (w - big_width) // 2, 36, 7, 2, veins=True)
    blades1, vines1 = grow_moss(img, face1, 3)
    blades2, vines2 = grow_moss(img, face2, 4, 0.45)
    for (p, c) in vines1 + vines2:
        if 0 <= p[0] < w and 0 <= p[1] < h and img.getpixel(p)[3] == 0:
            img.putpixel(p, c)
    bleed(img, face1, face2)
    outline(img)
    # Grass blades stand over the outline, thin and unoutlined.
    for (p, c) in blades1 + blades2:
        if 0 <= p[0] < w and 0 <= p[1] < h and img.getpixel(p) in (OUTLINE, (0, 0, 0, 0)):
            img.putpixel(p, c)
    # A soft shadow down and to the right, under everything.
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3] > 0 and x + 2 < w and y + 2 < h:
                shadow.putpixel((x + 2, y + 2), (0, 0, 0, 110))
    shadow.alpha_composite(img)
    shadow.save(os.path.join(ROOT, "logo.png"))


# ======================================================================
# The panorama
# ======================================================================

H = 240
SKY_W = 427
LAYER_W = 640


def periodic(x, waves, period=LAYER_W):
    """A height from a sum of waves whose wavelengths divide the period,
    so the layer wraps round without a seam."""
    return sum(a * math.sin(2 * math.pi * (k * x / period) + ph) for k, a, ph in waves)


def sky():
    img = Image.new("RGBA", (SKY_W, H))
    top, mid, low = C("05070e"), C("0e1222"), C("241a30")
    for y in range(H):
        t = y / (H - 1)
        c = mix(top, mid, t / 0.6) if t < 0.6 else mix(mid, low, (t - 0.6) / 0.4)
        # Hard bands, as a pixel artist would dither a sky: every few rows
        # the next tone, with a checker on the row between.
        for x in range(SKY_W):
            img.putpixel((x, y), c)
    # Dither the band edges a little.
    r = random.Random(5)
    for y in range(1, H):
        for x in range(SKY_W):
            if (x + y) % 2 == 0 and r.random() < 0.25:
                img.putpixel((x, y), img.getpixel((x, y - 1)))
    # Stars, more high up.
    for _ in range(170):
        x, y = r.randrange(SKY_W), int(r.random() ** 1.8 * H * 0.75)
        b = r.random()
        img.putpixel((x, y), C("e8e4f0") if b > 0.85 else C("8a8aa8") if b > 0.4 else C("4a4a68"))
        if b > 0.96 and 1 <= x < SKY_W - 1 and y >= 1:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img.putpixel((x + dx, y + dy), C("6a6a88"))
    # The moon: large and pale, its seas darker, a crimson cast low on it.
    mx, my, mr = 362, 40, 17
    for y in range(my - mr - 6, my + mr + 7):
        for x in range(mx - mr - 6, mx + mr + 7):
            d = math.hypot(x - mx, y - my)
            if d <= mr:
                lit = (x - mx) * -0.5 + (y - my) * -0.6
                c = C("efe2c0") if lit > 6 else C("d8c8a4") if lit > -8 else C("b8a488")
                if (y - my) > mr * 0.5:
                    c = mix(c, C("c86070"), 0.25)
                img.putpixel((x, y), c)
            elif d <= mr + 3 and (x + y) % 2 == 0:
                img.putpixel((x, y), mix(img.getpixel((x, y)), C("3a3448"), 0.6))
    for cx, cy, cr in ((356, 34, 4), (368, 46, 3), (359, 48, 2), (371, 33, 2)):
        for y in range(cy - cr, cy + cr + 1):
            for x in range(cx - cr, cx + cr + 1):
                if math.hypot(x - cx, y - cy) <= cr:
                    img.putpixel((x, y), mix(img.getpixel((x, y)), C("8a7a68"), 0.5))
    img.save(os.path.join(ROOT, "title_sky.png"))


def ridge_layer(name, base_y, waves, body, ridge, seed, snow=None, mist=None):
    img = Image.new("RGBA", (LAYER_W, H), (0, 0, 0, 0))
    r = random.Random(seed)
    tops = [round(base_y - periodic(x, waves)) for x in range(LAYER_W)]
    for x in range(LAYER_W):
        top = tops[x]
        left = tops[x - 1]
        right = tops[(x + 1) % LAYER_W]
        for y in range(max(top, 0), H):
            c = body
            # Moonlight on slopes that face up-left.
            if y - top < 3 and right >= left:
                c = ridge
            elif y - top < 2:
                c = mix(body, ridge, 0.5)
            # Snow on the high peaks, thinning (in a ragged edge) lower down.
            if snow and top < snow[0] and y - top < snow[1] + (snow[0] - top) // 3 - (x * 7 % 3):
                c = C("c8d0e0") if right >= left else C("8a94ac")
            if mist and y > mist[0]:
                c = mix(c, mist[1], min((y - mist[0]) / 40.0, 0.7))
            img.putpixel((x, y), c)
        # Crags: short dark gullies on the shaded slopes.
        if r.random() < 0.05 and right < left:
            for k, y in enumerate(range(top + 4, min(top + r.randint(6, 12), H))):
                if 0 <= x + k // 3 < LAYER_W:
                    img.putpixel((x + k // 3, y), mix(img.getpixel((x + k // 3, y)), C("000000"), 0.18))
    img.save(os.path.join(ROOT, name + ".png"))
    return tops


def tree(img, x, y, height, kind, colour, rim):
    if kind == "pine":
        for k in range(height):
            half = int((k / height) * height * 0.35) + 1 if k > 2 else 1
            for dx in range(-half, half + 1):
                p = ((x + dx) % LAYER_W, y - height + k)
                if 0 <= p[1] < H:
                    img.putpixel(p, rim if dx == -half and k % 3 == 0 else colour)
        for k in range(3):
            if 0 <= y + k < H:
                img.putpixel((x % LAYER_W, y + k), colour)
    else:
        rad = height // 2
        cx, cy = x, y - rad - 2
        for dy in range(-rad, rad + 1):
            for dx in range(-rad - 1, rad + 2):
                if (dx / (rad + 1)) ** 2 + (dy / rad) ** 2 <= 1.0:
                    p = ((cx + dx) % LAYER_W, cy + dy)
                    if 0 <= p[1] < H:
                        inside = ((dx - 1) / (rad + 1)) ** 2 + ((dy - 1) / rad) ** 2 <= 1.0
                        img.putpixel(p, colour if inside else rim)
        for k in range(rad + 3):
            if 0 <= cy + rad + k - 2 < H:
                img.putpixel((cx % LAYER_W, cy + rad + k - 2), colour)


def hills():
    """The hills, and the Sanctuary on them: walls, a hall, towers with
    stepped spires and lit windows, a banner."""
    img = Image.new("RGBA", (LAYER_W, H), (0, 0, 0, 0))
    waves = [(1, 10, 0.4), (2, 6, 1.3), (5, 3, 2.1), (9, 1.5, 0.2)]
    body, ridge = C("10141f"), C("1e2638")
    tops = [round(186 - periodic(x, waves)) for x in range(LAYER_W)]
    for x in range(LAYER_W):
        for y in range(tops[x], H):
            img.putpixel((x, y), ridge if y - tops[x] < 2 and tops[(x + 1) % LAYER_W] >= tops[x - 1] else body)
    # The Sanctuary.
    cx = 200
    ground = min(tops[cx - 60:cx + 60]) + 4
    wall, lit_wall, window = C("0c0f18"), C("1a2030"), C("ffb060")
    dim_window = C("a85a30")

    def block(x0, y0, x1, y1, lit=True):
        for y in range(y0, y1):
            for x in range(x0, x1):
                img.putpixel((x, y), lit_wall if lit and x == x0 else wall)

    block(cx - 56, ground - 22, cx + 56, ground + 12)
    for k in range(cx - 56, cx + 56, 4):
        block(k, ground - 25, k + 2, ground - 22)
    towers = [(0, 10, 66), (-30, 7, 46), (30, 7, 46), (-52, 6, 32), (52, 6, 32)]
    for dx, half, high in towers:
        x = cx + dx
        block(x - half, ground - high, x + half, ground)
        top = ground - high
        width = half
        while width > 1:
            width -= 2
            top -= 3
            block(x - width, top, x + width, top + 3)
        img.putpixel((x, top - 1), wall)
        img.putpixel((x, top - 2), wall)
        for wy in range(ground - high + 10, ground - 6, 18):
            img.putpixel((x - 1, wy), window)
            img.putpixel((x, wy), window)
            img.putpixel((x - 1, wy + 1), dim_window)
            img.putpixel((x, wy + 1), dim_window)
    # A banner on the keep.
    for y in range(ground - 98, ground - 88):
        img.putpixel((cx + 1, y), wall)
    for y in range(ground - 97, ground - 92):
        for x in range(cx + 2, cx + 7 - (y - (ground - 97)) // 2):
            img.putpixel((x, y), C("8e2c36"))
    for k in (cx - 42, cx - 18, cx + 14, cx + 40):
        img.putpixel((k, ground - 12), window)
        img.putpixel((k, ground - 11), dim_window)
    # A broken tower far off on another hill, and a few trees on the hills.
    rx = 470
    rg = tops[rx] + 2
    block(rx - 5, rg - 30, rx + 5, rg)
    for y in range(rg - 34, rg - 30):
        for x in range(rx - 5, rx + 1 - (y - (rg - 34))):
            img.putpixel((x, y), wall)
    r = random.Random(9)
    for _ in range(26):
        x = r.randrange(LAYER_W)
        if abs(x - cx) < 70 or abs(x - rx) < 10:
            continue
        tree(img, x, tops[x] + 2, r.randint(8, 14), r.choice(("pine", "oak")), C("0c1018"), C("1a2232"))
    img.save(os.path.join(ROOT, "title_hills.png"))


def woods():
    """Dark woods in front: a ragged line of pines and oaks with the moon
    catching their left edges, and grass at their feet."""
    img = Image.new("RGBA", (LAYER_W, H), (0, 0, 0, 0))
    r = random.Random(13)
    waves = [(2, 4, 0.9), (7, 2, 0.3)]
    tops = [round(222 - periodic(x, waves)) for x in range(LAYER_W)]
    colour, rim = C("06080c"), C("1a2236")
    for x in range(LAYER_W):
        for y in range(tops[x], H):
            img.putpixel((x, y), colour)
        if r.random() < 0.35:
            for k in range(1, r.randint(2, 4)):
                img.putpixel((x, tops[x] - k), colour)
    x = 0
    while x < LAYER_W:
        kind = r.choice(("pine", "pine", "oak"))
        height = r.randint(22, 46)
        tree(img, x, tops[x % LAYER_W] + 4, height, kind, colour, rim)
        x += r.randint(14, 40)
    img.save(os.path.join(ROOT, "title_woods.png"))


def main():
    os.makedirs(ROOT, exist_ok=True)
    logo()
    sky()
    ridge_layer("title_far", 158, [(1, 20, 0.0), (3, 15, 1.1), (5, 9, 2.6), (11, 5, 0.7), (17, 3, 1.9), (29, 2, 0.4), (43, 1.2, 2.2)], C("1a2034"), C("33405e"), 21,
                snow=(124, 2))
    hills()
    woods()
    print("title art written")


if __name__ == "__main__":
    main()
