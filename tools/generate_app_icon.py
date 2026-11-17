#!/usr/bin/env python3
"""Draws the game's own icon, pixel by pixel, for every place it is asked
for: the window and taskbar, the Windows .exe (an .ico holding 16 to 256
pixels), and the Android launcher (a plain icon and the adaptive layers).

The icon: a dark heart, shaded from its upper left, with a hall running
through it: an arched doorway of old bronze stone, a passage dropping away
inside to a far, warm light. Blood beads at its tip. Behind it, the navy
night of the title screen, a few stars, a bronze frame.

Every size from 16 to 64 is drawn at its own size, never shrunk: the small
ones keep only what still reads. The larger sizes are whole-number
enlargements of the 64 (each art pixel a clean square).

Run from the project folder:  python3 tools/generate_app_icon.py [preview.png]
"""
import io
import math
import os
import random
import struct
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "icon")


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


OUTLINE = C("0a0c16")
NAVY = [C("1c2448"), C("161d3c"), C("111731"), C("0d1226"), C("0a0e1e")]
BRONZE = [C("f0d8a0"), C("d4a858"), C("b07a38"), C("845426"), C("4e2e14")]   # hi, light, mid, shade, deep
HEART = [C("ff8f8f"), C("d63a4a"), C("b02436"), C("84182c"), C("58101f"), C("380a18")]
HALL = [C("05060c"), C("120c10"), C("2a1a14"), C("5a3a1e"), C("b07a38"), C("f0d8a0"), C("fff4d6")]
STAR = [C("fff4d6"), C("c8cce0"), C("7a84a8")]


def heart_inside(x, y):
    """The classic heart curve, x and y in about -1.3 .. 1.3."""
    return (x * x + y * y - 1.0) ** 3 - x * x * y ** 3 <= 0.0


def draw_heart(px, ox, oy, size, detail):
    """Heart with the hall through it, fitted in a size-by-size box at
    (ox, oy). `detail`: 0 for 16 px (shape and door only), 1 for 32,
    2 for 48 and up (stones, light, drips, shine)."""
    cells = set()
    for j in range(size):
        for i in range(size):
            x = ((i + 0.5) / size - 0.5) * 2.6
            y = -((j + 0.5) / size - 0.56) * 2.6
            if heart_inside(x, y):
                cells.add((i, j))
    # Shade: light from the upper left, darker toward the lower right and
    # the edge.
    def at(i, j):
        return (ox + i, oy + j)
    for (i, j) in cells:
        edge = sum((i + di, j + dj) not in cells for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        u = i / size - 0.5
        v = j / size - 0.5
        light = -(u * 0.7 + v * 0.9)
        tone = 2.4 - light * 4.0
        if edge:
            tone += 1.4
        tone = int(max(1, min(len(HEART) - 1, round(tone))))
        px[at(i, j)] = HEART[tone]
    # Outline round the heart.
    for (i, j) in list(cells):
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (i + di, j + dj)
            if n not in cells and 0 <= ox + n[0] < W and 0 <= oy + n[1] < H:
                if px[at(*n)][3] == 0 or px[at(*n)] != OUTLINE:
                    px[at(*n)] = OUTLINE
    # The shine on the left lobe.
    if detail >= 1:
        sx, sy = int(size * 0.27), int(size * 0.27)
        spots = [(0, 0), (1, 0), (0, 1)] if detail == 1 else [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (0, 2), (3, -1)]
        for dx, dy in spots:
            if (sx + dx, sy + dy) in cells:
                px[at(sx + dx, sy + dy)] = HEART[0] if (dx + dy) < 2 else HEART[1]
    # The hall: an arched doorway through the middle of the heart.
    cx = size // 2
    door_w = max(4, int(round(size * 0.30)))
    if door_w % 2:
        door_w += 1
    top = int(size * 0.30)
    bottom = int(size * 0.72)
    left = cx - door_w // 2
    radius = door_w / 2.0

    def in_arch(i, j, shrink=0.0):
        if not (left + shrink <= i + 0.5 <= left + door_w - shrink):
            return False
        if j + 0.5 > bottom - shrink * 0.2:
            return False
        spring = top + radius
        if j + 0.5 >= spring:
            return True
        return math.hypot(i + 0.5 - cx, j + 0.5 - spring) <= radius - shrink

    door = {(i, j) for j in range(size) for i in range(size) if in_arch(i, j)}
    inner = {(i, j) for (i, j) in door if in_arch(i, j, 1.6 if detail >= 2 else 1.0)}
    far = {(i, j) for (i, j) in door if in_arch(i, j, radius * 0.62)}
    # The stone rim of the arch.
    for (i, j) in door - inner:
        light = (i < cx) and j < bottom - 2
        if detail == 0:
            px[at(i, j)] = BRONZE[2]
        else:
            px[at(i, j)] = BRONZE[1] if light else BRONZE[3]
    if detail >= 2:
        # Joints between the rim stones.
        for (i, j) in door - inner:
            if (j - top) % 4 == 3 and (i <= left + 1 or i >= left + door_w - 2):
                px[at(i, j)] = BRONZE[4]
        key = (cx - 1, top)
        for k in (key, (cx, top)):
            if k in door:
                px[at(*k)] = BRONZE[0]
    # The passage: dark at the mouth, warmer as it goes, light at the end.
    for (i, j) in inner:
        depth = 0.0
        if far:
            fx = cx - 0.5
            depth = 1.0 - min(1.0, abs(i + 0.5 - fx) / (door_w / 2.0))
        tone = 0 if depth < 0.3 else (1 if depth < 0.6 else 2)
        px[at(i, j)] = HALL[tone]
    for (i, j) in far:
        if detail == 0:
            px[at(i, j)] = HALL[5]
            continue
        ring = (i, j) not in {(a, b) for (a, b) in far if in_arch(a, b, radius * 0.62 + 1.0)}
        px[at(i, j)] = HALL[4] if ring else (HALL[6] if j > top + radius * 1.6 else HALL[5])
    if detail >= 2:
        # Floor lines of the hall running in to the light.
        fb = max(j for (_, j) in far) if far else bottom
        for k in range(1, bottom - fb):
            for side in (-1, 1):
                x = cx - 0.5 + side * (door_w * 0.18 + k * 0.55)
                p = (int(round(x - 0.5)), fb + k)
                if p in inner:
                    px[at(*p)] = HALL[3]
        # Light spilling over the threshold.
        for i in range(left + 2, left + door_w - 2):
            if (i, bottom - 1) in inner:
                px[at(i, bottom - 1)] = HALL[2]
    # A sill of stone under the door.
    for i in range(left - (1 if detail else 0), left + door_w + (1 if detail else 0)):
        if (i, bottom) in cells:
            px[at(i, bottom)] = BRONZE[3] if detail else BRONZE[2]
            if detail >= 2 and (i, bottom + 1) in cells:
                px[at(i, bottom + 1)] = BRONZE[4]
    # Blood beading at the tip.
    if detail >= 1:
        tip = max(j for (i, j) in cells if abs(i - (cx - 1)) <= 1)
        drops = [(cx - 1, tip + 1), (cx - 1, tip + 2)] if detail == 1 else [(cx - 1, tip + 1), (cx - 1, tip + 2), (cx - 1, tip + 3), (cx, tip + 1)]
        for d in drops:
            if 0 <= oy + d[1] < H:
                px[at(*d)] = HEART[3] if d[1] < tip + 3 else HEART[2]
        if detail >= 2 and 0 <= oy + tip + 4 < H:
            px[at(cx - 1, tip + 4)] = OUTLINE


def background(px, n, frame):
    """The navy night: a rounded square, stars, a bronze frame."""
    corner = max(2, n // 10) if frame else 0
    r = random.Random(n)

    def inside(i, j):
        if not frame:
            return True
        for cxp, cyp in ((corner, corner), (n - 1 - corner, corner), (corner, n - 1 - corner), (n - 1 - corner, n - 1 - corner)):
            if (i < corner or i > n - 1 - corner) and (j < corner or j > n - 1 - corner):
                if (i - cxp) ** 2 + (j - cyp) ** 2 > corner ** 2 + 0.5:
                    return False
        return True

    for j in range(n):
        for i in range(n):
            if not inside(i, j):
                continue
            t = j / n
            band = min(len(NAVY) - 1, int(t * len(NAVY)))
            # Dither between bands.
            if (i + j) % 2 == 0 and band > 0 and (t * len(NAVY)) % 1.0 < 0.3:
                band -= 1
            px[i, j] = NAVY[band]
    if n >= 32:
        for k in range(n // 6):
            i, j = r.randrange(3, n - 3), r.randrange(3, n // 2)
            px[i, j] = STAR[r.randrange(1, 3)]
        for k in range(max(1, n // 32)):
            i, j = r.randrange(5, n - 5), r.randrange(4, n // 3)
            px[i, j] = STAR[0]
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                px[i + di, j + dj] = STAR[2]
    if not frame:
        return
    thick = 1 if n < 48 else 2
    for j in range(n):
        for i in range(n):
            if not inside(i, j):
                continue
            outer = not all(inside(i + di, j + dj) and 0 <= i + di < n and 0 <= j + dj < n for di in range(-1, 2) for dj in range(-1, 2))
            if outer:
                px[i, j] = OUTLINE
                continue
            ring = not all(0 <= i + di < n and 0 <= j + dj < n and inside(i + di, j + dj) for di in range(-1 - thick, 2 + thick) for dj in range(-1 - thick, 2 + thick))
            if ring:
                lit = i + j < n
                px[i, j] = BRONZE[1] if lit else BRONZE[3]
    # An inner dark line inside the frame.
    for j in range(n):
        for i in range(n):
            if not inside(i, j) or px[i, j] in (OUTLINE, BRONZE[1], BRONZE[3]):
                continue
            near = any(0 <= i + di < n and 0 <= j + dj < n and px[i + di, j + dj] in (BRONZE[1], BRONZE[3]) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if near:
                px[i, j] = BRONZE[4]


W = H = 0


def icon(n, frame=True, bg=True, heart_share=0.78):
    """The icon drawn at n x n pixels."""
    global W, H
    W = H = n
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    if bg:
        background(px, n, frame)
    size = int(round(n * heart_share))
    ox = (n - size) // 2
    oy = (n - size) // 2 + max(0, n // 32)
    detail = 0 if n < 24 else (1 if n < 44 else 2)
    draw_heart(px, ox, oy, size, detail)
    return img


def enlarge(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def write_ico(path, images):
    """An .ico holding each image as PNG (Windows Vista and later)."""
    blobs = []
    for im in images:
        b = io.BytesIO()
        im.save(b, "PNG")
        blobs.append(b.getvalue())
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries = b""
    for im, blob in zip(images, blobs):
        w = 0 if im.width >= 256 else im.width
        h = 0 if im.height >= 256 else im.height
        entries += struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    with open(path, "wb") as f:
        f.write(header + entries + b"".join(blobs))


def main():
    os.makedirs(ROOT, exist_ok=True)
    i16, i32, i48, i64 = icon(16), icon(32), icon(48), icon(64)
    enlarge(i64, 4).save(os.path.join(ROOT, "icon.png"))
    write_ico(os.path.join(ROOT, "icon.ico"), [i16, i32, i48, i64, enlarge(i64, 2), enlarge(i64, 4)])
    enlarge(i64, 3).save(os.path.join(ROOT, "android_192.png"))
    # Android adaptive layers: 72 art pixels at 6x = 432. The launcher masks
    # the outer third, so the heart keeps to the middle 44.
    fore = icon(72, frame=False, bg=False, heart_share=0.6)
    enlarge(fore, 6).save(os.path.join(ROOT, "android_foreground.png"))
    back = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
    global W, H
    W = H = 72
    background(back.load(), 72, False)
    enlarge(back, 6).save(os.path.join(ROOT, "android_background.png"))
    mono = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
    mp, fp = mono.load(), fore.load()
    for j in range(72):
        for i in range(72):
            r, g, b, a = fp[i, j]
            # Themed icons: one colour, the doorway cut out of the heart.
            if a and (r, g, b, a) != OUTLINE and not (r + g + b < 60):
                if (r, g, b, a) not in HALL[:3]:
                    mp[i, j] = (255, 255, 255, 255)
    enlarge(mono, 6).save(os.path.join(ROOT, "android_monochrome.png"))
    # A sheet to look at all of them together.
    sheet = Image.new("RGBA", (16 + 32 + 48 + 64 + 72 + 72 + 7 * 8, 80), (40, 40, 48, 255))
    x = 8
    for im in (i16, i32, i48, i64):
        sheet.paste(im, (x, 8), im)
        x += im.width + 8
    sheet.paste(back, (x, 4), back)
    sheet.paste(fore, (x, 4), fore)
    x += 80
    sheet.paste(mono, (x, 4), mono)
    if len(sys.argv) > 1:
        sheet.save(sys.argv[1])


if __name__ == "__main__":
    main()
