#!/usr/bin/env python3
"""Draws the paving laid under structures (temple, ruins, shrines, arenas)
into assets/tiles/floors.png.

Run from the project folder:  python3 tools/generate_floors.py

One row per style, 44px tiles (one per world tile). Columns 0-3 are whole
tiles; columns 4-7 are worn tiles for the rim of a floor, with stones
missing or chipped so the ground shows through.

Each tile tiles seamlessly: mortar runs along its top and left edges only,
and two courses of stones fill the rest, so neighbours share one joint.
"""
import os
import random
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "tiles")
N = 44
COLUMNS = 8


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def shift(c, amount):
    return tuple(max(0, min(255, int(v + amount))) for v in c[:3]) + (c[3],)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


# name: (light, mid, dark, mortar, accent, accent chance)
STYLES = [
    ("temple", "d2c8b2", "b8ac94", "8e836c", "5a5244", "e8dcc0", 0.0),
    ("ruin", "a4a2aa", "86848e", "62606a", "3c3a42", "5d7a3f", 0.5),
    ("shrine", "767c96", "5c627c", "424860", "1e2236", "c8a050", 0.25),
    ("basalt", "585260", "443f4c", "322e38", "141218", "a83a1e", 0.3),
]


def draw(style, variant, worn):
    name, light, mid, dark, mortar, accent, accent_chance = style
    light, mid, dark, mortar, accent = C(light), C(mid), C(dark), C(mortar), C(accent)
    r = random.Random("%s:%d:%d" % (name, variant, worn))
    img = Image.new("RGBA", (N, N), mortar)
    px = img.load()
    stones = []
    for course, (y0, y1) in enumerate([(1, 21), (23, 43)]):
        # Each course split in one or two places, staggered between courses.
        if r.random() < 0.5:
            cuts = [r.randrange(12, 33)]
        else:
            first = r.randrange(9, 19)
            cuts = [first, r.randrange(first + 10, 37)]
        edges = [1] + [c + 1 for c in cuts] + [N]
        for x0, x1 in zip(edges, edges[1:]):
            stones.append((x0, y0, x1 - 2, y1))
    holes = set()
    if worn:
        # The rim: one or two stones gone, others chipped at the corners.
        for index in r.sample(range(len(stones)), r.choice([1, 1, 2])):
            holes.add(index)
    for index, (x0, y0, x1, y1) in enumerate(stones):
        if index in holes:
            for y in range(max(0, y0 - 1), min(N, y1 + 2)):
                for x in range(max(0, x0 - 1), min(N, x1 + 2)):
                    px[x, y] = (0, 0, 0, 0)
            # A few pebbles left where the stone was.
            for _ in range(r.randrange(1, 4)):
                x, y = r.randrange(x0, x1 + 1), r.randrange(y0, y1 + 1)
                px[x, y] = mid
                if x + 1 <= x1:
                    px[x + 1, y] = dark
            continue
        tone = shift(mid, r.randrange(-10, 11))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                c = tone
                if y == y0 or x == x0:
                    c = mix(tone, light, 0.6)
                elif y == y1 or x == x1:
                    c = mix(tone, dark, 0.65)
                elif r.random() < 0.07:
                    c = shift(tone, r.choice([-12, 10]))
                px[x, y] = c
        # Wear: a soft lighter patch, a crack, and for some styles moss,
        # gold inlay or a glowing seam.
        cx, cy = r.randrange(x0 + 3, max(x0 + 4, x1 - 2)), r.randrange(y0 + 3, max(y0 + 4, y1 - 2))
        for _ in range(6):
            x, y = cx + r.randrange(-2, 3), cy + r.randrange(-1, 2)
            if x0 < x < x1 and y0 < y < y1:
                px[x, y] = shift(tone, 8)
        if r.random() < 0.4:
            x, y = r.randrange(x0 + 2, max(x0 + 3, x1 - 1)), y0 + 1
            for _ in range(r.randrange(4, 9)):
                if y >= y1:
                    break
                px[x, y] = mix(tone, mortar, 0.7)
                x = max(x0 + 1, min(x1 - 1, x + r.choice([-1, 0, 1])))
                y += 1
        if worn:
            # Chip a corner or two away.
            for (cx, cy, sx, sy) in r.sample([(x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)], 2):
                size = r.randrange(2, 5)
                for dy in range(size):
                    for dx in range(size - dy):
                        px[cx + dx * sx, cy + dy * sy] = (0, 0, 0, 0)
        if r.random() < accent_chance:
            if name == "ruin":
                # Moss creeping out of the joint along one edge.
                y = y1 if r.random() < 0.5 else y0
                for x in range(x0, x1 + 1):
                    if r.random() < 0.55:
                        px[x, y] = accent if r.random() < 0.6 else shift(accent, 24)
            elif name == "shrine":
                # A small gold rune set into the stone.
                gx, gy = (x0 + x1) // 2, (y0 + y1) // 2
                for (dx, dy) in [(0, -2), (0, -1), (0, 0), (0, 1), (0, 2), (-1, -1), (1, 1)]:
                    px[gx + dx, gy + dy] = accent
            elif name == "basalt":
                # An ember-lit seam along the crack.
                x, y = r.randrange(x0 + 2, max(x0 + 3, x1 - 1)), r.randrange(y0 + 2, max(y0 + 3, y1 - 1))
                for _ in range(5):
                    if x0 < x < x1 and y0 < y < y1:
                        px[x, y] = accent
                    x += r.choice([1, 1, 0])
                    y += r.choice([-1, 0, 1])
    # Grit in the mortar.
    for y in range(N):
        for x in range(N):
            if px[x, y] == mortar and r.random() < 0.08:
                px[x, y] = shift(mortar, 10)
    return img


def main():
    sheet = Image.new("RGBA", (COLUMNS * N, len(STYLES) * N), (0, 0, 0, 0))
    for row, style in enumerate(STYLES):
        for column in range(COLUMNS):
            sheet.paste(draw(style, column, column >= 4), (column * N, row * N))
    sheet.save(os.path.join(ROOT, "floors.png"))
    print("floors", [s[0] for s in STYLES])


if __name__ == "__main__":
    main()
