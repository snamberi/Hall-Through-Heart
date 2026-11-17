#!/usr/bin/env python3
"""Draws the marks fights leave on the ground (assets/sprites/marks.png),
pixel by pixel, each family in a palette of its own:

  Row 0 (32 x 32 frames):
     0-5   blood splats: a pool of a few joined blobs, darker at the rim, a
           wet glint, droplets and streaks thrown outward
     6-9   blood trails: drops flung one way, smaller as they go
     10-12 slime goo (green), 13-14 void ichor (violet), 15 bone dust
  Row 1 (64 x 64 frames):
     0-2   scorch marks: charcoal heart, burnt ring, singed edge dithered
           out, blast rays and ash flecks
     3-5   the embers glowing in each scorch, drawn over it while it cools
     6-7   cracked ground where something heavy struck
  Row 2 (64 x 64 frames):
     0-1   frost bursts: a patch of rime with ice crystals spiking out

Light falls from the upper left, as everywhere in the game. Nothing is
smoothed: every edge is a whole pixel.

Run from the project folder:  python3 tools/generate_marks.py
"""
import math
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "marks.png")


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

# Liquids: [rim (darkest), body, inner, glint].
BLOOD = [C("3c0810"), C("641019"), C("861a24"), C("c0383e")]
GOO = [C("1c3510"), C("33601a"), C("4f8c26"), C("a6dc58")]
ICHOR = [C("1e0c34"), C("3e1c66"), C("6234a0"), C("b48cf0")]
DUST = [C("5e574a", 150), C("8a826e", 175), C("b4aa92", 190), C("e2dac2", 210)]
CHAR = [C("0f0b09"), C("1c1410"), C("2c1e16"), C("3e2b1c"), C("54391f")]
ASH = [C("6e6964"), C("9a948c")]
EMBER = [C("8c2a0e"), C("d2501a"), C("ff8e2c"), C("ffd27c")]
CRACK = C("110c0a")
CRACK_LIP_DARK = C("2a2018", 150)
CRACK_LIP_LIGHT = C("a08a6c", 120)
RUBBLE = [C("4a3e32"), C("6c5c48"), C("948066")]
FROST = [C("6a96bc", 170), C("9cc6e2", 200), C("d0eaf6", 215), C("f6fdff", 235)]


def blobs(r, cx, cy, count, rx, ry):
    """A pool: several ellipses joined. Returns a set of pixels."""
    parts = []
    for k in range(count):
        ox = r.uniform(-rx * 0.55, rx * 0.55) if k else 0.0
        oy = r.uniform(-ry * 0.5, ry * 0.5) if k else 0.0
        parts.append((cx + ox, cy + oy, rx * r.uniform(0.55, 1.0), ry * r.uniform(0.55, 1.0)))
    cells = set()
    for y in range(64):
        for x in range(64):
            for px, py, ax, ay in parts:
                dx, dy = (x + 0.5 - px) / ax, (y + 0.5 - py) / ay
                if dx * dx + dy * dy <= 1.0:
                    cells.add((x, y))
                    break
    return cells


def shade_pool(img, ox, oy, cells, ramp, r, glint=True):
    """Rim dark, body, a lighter inner, and a wet glint at the upper left."""
    for (x, y) in cells:
        edge = sum((x + dx, y + dy) not in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        deep = all((x + dx, y + dy) in cells for dx in (-2, -1, 0, 1, 2) for dy in (-1, 0, 1))
        colour = ramp[0] if edge else (ramp[2] if deep else ramp[1])
        # The near (lower) rim lies a little darker still.
        if edge and (x, y + 1) not in cells:
            colour = ramp[0]
        img.putpixel((ox + x, oy + y), colour)
    if glint and cells:
        top = min(cells, key=lambda c: (c[0] + c[1] * 1.3))
        gx, gy = top[0] + 2, top[1] + 1
        for dx, dy in ((0, 0), (1, 0), (0, 1)):
            if (gx + dx, gy + dy) in cells and r.random() < 0.9:
                img.putpixel((ox + gx + dx, oy + gy + dy), ramp[3])


def spatter(img, ox, oy, r, cx, cy, ramp, count, reach, size, bias=None):
    """Droplets thrown out from the pool: dots, and streaks pointing out."""
    for _ in range(count):
        if bias is None:
            angle = r.uniform(0, math.tau)
        else:
            angle = bias + r.uniform(-0.55, 0.55)
        dist = r.uniform(reach * 0.55, reach)
        x = int(round(cx + math.cos(angle) * dist))
        y = int(round(cy + math.sin(angle) * dist * 0.62))
        if not (1 <= x < size - 2 and 1 <= y < size - 2):
            continue
        img.putpixel((ox + x, oy + y), ramp[1])
        roll = r.random()
        if roll < 0.45:
            # A streak: the drop skidded outward.
            sx = 1 if math.cos(angle) >= 0 else -1
            if 0 <= x + sx < size:
                img.putpixel((ox + x + sx, oy + y), ramp[0])
        elif roll < 0.7 and x + 1 < size and y + 1 < size:
            img.putpixel((ox + x + 1, oy + y), ramp[1])
            img.putpixel((ox + x, oy + y + 1), ramp[0])
            img.putpixel((ox + x + 1, oy + y + 1), ramp[0])


def splat(img, ox, oy, ramp, seed, big=True):
    r = random.Random(seed)
    cx, cy = 16.0 + r.uniform(-1, 1), 17.0 + r.uniform(-1, 1)
    cells = blobs(r, cx, cy, r.randint(3, 5) if big else 2, r.uniform(6.5, 9.0) if big else 4.5, r.uniform(3.8, 5.2) if big else 2.8)
    cells = {c for c in cells if 1 <= c[0] < 31 and 1 <= c[1] < 31}
    shade_pool(img, ox, oy, cells, ramp, r)
    spatter(img, ox, oy, r, cx, cy, ramp, r.randint(8, 13), 14.0, 32)


def trail(img, ox, oy, ramp, seed):
    """Drops flung toward the right, getting smaller, with a skid at the end."""
    r = random.Random(seed)
    x, y = 4.0, 16.0 + r.uniform(-2, 2)
    size = 3.2
    while x < 28 and size > 0.6:
        cells = blobs(r, x, y, 1, size, size * 0.65)
        cells = {c for c in cells if 0 <= c[0] < 32 and 0 <= c[1] < 32}
        shade_pool(img, ox, oy, cells, ramp, r, glint=size > 2.4)
        step = size * 2.2 + r.uniform(0.5, 2.0)
        x += step
        y += r.uniform(-1.4, 1.4)
        size *= r.uniform(0.62, 0.8)
    spatter(img, ox, oy, r, 20.0, y, ramp, 5, 9.0, 32, bias=0.0)


def dust(img, ox, oy, seed):
    """A puff of bone dust settled on the ground: dithered, paler inside."""
    r = random.Random(seed)
    for y in range(32):
        for x in range(32):
            dx, dy = (x - 16) / 11.0, (y - 17) / 6.5
            d = math.hypot(dx, dy) + r.uniform(-0.12, 0.12)
            if d > 1.0:
                continue
            level = BAYER[y % 4][x % 4] / 16.0
            if level > (1.0 - d) * 1.3:
                continue
            tone = 3 if d < 0.35 and r.random() < 0.5 else 2 if d < 0.6 else 1 if d < 0.85 else 0
            img.putpixel((ox + x, oy + y), DUST[tone])
    for _ in range(9):
        x, y = r.randint(3, 28), r.randint(8, 26)
        img.putpixel((ox + x, oy + y), DUST[3])


def scorch(img, ox, oy, seed, ember_ox, ember_oy):
    r = random.Random(seed)
    cx, cy = 32.0, 33.0
    rx, ry = r.uniform(22, 26), r.uniform(13, 16)
    wobble = [r.uniform(0.85, 1.12) for _ in range(16)]
    rays = [r.uniform(0, math.tau) for _ in range(r.randint(6, 9))]

    def reach(angle):
        k = (angle % math.tau) / math.tau * 16
        i = int(k)
        t = k - i
        return wobble[i % 16] * (1 - t) + wobble[(i + 1) % 16] * t

    embers = []
    for y in range(64):
        for x in range(64):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            angle = math.atan2(dy, dx)
            d = math.hypot(dx, dy) / reach(angle)
            # Blast rays run further out.
            ray = max(0.0, max(math.cos(angle - a) for a in rays))
            d -= max(0.0, (ray - 0.96) / 0.04) * 0.25
            if d > 1.0:
                if d < 1.35 and r.random() < 0.05:
                    img.putpixel((ox + x, oy + y), CHAR[3])
                continue
            level = BAYER[y % 4][x % 4] / 16.0
            if d < 0.38:
                tone = 0 if r.random() < 0.7 else 1
            elif d < 0.66:
                tone = 1 if level < 0.6 else 2
            elif d < 0.86:
                tone = 2 if level < 0.55 else 3
            else:
                if level > (1.0 - d) / 0.14 * 0.8:
                    continue
                tone = 3 if level < 0.5 else 4
            img.putpixel((ox + x, oy + y), CHAR[tone])
            if d < 0.55 and r.random() < 0.035:
                img.putpixel((ox + x, oy + y), ASH[r.randint(0, 1)])
            if d < 0.7 and r.random() < 0.05:
                embers.append((x, y, d))
    # Embers: little clusters, hottest in the middle.
    for (x, y, d) in embers:
        heat = 3 if d < 0.25 else 2 if d < 0.45 else 1 if d < 0.6 else 0
        img.putpixel((ember_ox + x, ember_oy + y), EMBER[heat])
        if heat >= 2 and x + 1 < 64 and r.random() < 0.5:
            img.putpixel((ember_ox + x + 1, ember_oy + y), EMBER[heat - 1])


def cracks(img, ox, oy, seed):
    r = random.Random(seed)
    cx, cy = 32, 33
    lines = set()

    def walk(x, y, angle, length, depth):
        for _ in range(length):
            angle += r.uniform(-0.45, 0.45)
            x += math.cos(angle)
            y += math.sin(angle) * 0.62
            px, py = int(round(x)), int(round(y))
            if not (1 <= px < 63 and 1 <= py < 63):
                return
            lines.add((px, py))
            if depth < 2 and r.random() < 0.08:
                walk(x, y, angle + r.choice((-1, 1)) * r.uniform(0.5, 1.0), r.randint(4, 10), depth + 1)

    for k in range(r.randint(5, 7)):
        base = k * math.tau / 6 + r.uniform(-0.3, 0.3)
        walk(cx, cy, base, r.randint(14, 24), 0)
    # Lips: dark on the far side of a crack, catching light on the near.
    for (x, y) in lines:
        for dx, dy, colour in ((0, -1, CRACK_LIP_DARK), (0, 1, CRACK_LIP_LIGHT), (-1, 0, CRACK_LIP_DARK)):
            n = (x + dx, y + dy)
            if n not in lines and img.getpixel((ox + n[0], oy + n[1]))[3] == 0:
                img.putpixel((ox + n[0], oy + n[1]), colour)
    for (x, y) in lines:
        img.putpixel((ox + x, oy + y), CRACK)
    # The pit where it struck, and broken stones round it.
    for y in range(64):
        for x in range(64):
            dx, dy = (x + 0.5 - cx) / 5.5, (y + 0.5 - cy) / 3.4
            if dx * dx + dy * dy <= 1.0:
                img.putpixel((ox + x, oy + y), CRACK if dy > -0.4 else CRACK_LIP_DARK)
    for _ in range(r.randint(7, 11)):
        angle = r.uniform(0, math.tau)
        dist = r.uniform(7, 15)
        x, y = int(cx + math.cos(angle) * dist), int(cy + math.sin(angle) * dist * 0.62)
        img.putpixel((ox + x, oy + y), RUBBLE[1])
        img.putpixel((ox + x + 1, oy + y), RUBBLE[0])
        img.putpixel((ox + x, oy + y - 1), RUBBLE[2])


def frost(img, ox, oy, seed):
    r = random.Random(seed)
    cx, cy = 32.0, 33.0
    # The rime: a dithered patch, densest in the middle.
    for y in range(64):
        for x in range(64):
            dx, dy = (x + 0.5 - cx) / 17.0, (y + 0.5 - cy) / 10.0
            d = math.hypot(dx, dy) + r.uniform(-0.08, 0.08)
            if d > 1.0:
                continue
            level = BAYER[y % 4][x % 4] / 16.0
            if level > (1.0 - d) * 1.6:
                continue
            img.putpixel((ox + x, oy + y), FROST[1] if d > 0.5 else FROST[2])
    # Crystals spiking out, lit along their upper edge, a bright tip.
    for k in range(r.randint(9, 13)):
        angle = k * math.tau / 11 + r.uniform(-0.2, 0.2)
        length = r.uniform(12, 24)
        steps = int(length)
        for s in range(steps):
            x = int(round(cx + math.cos(angle) * s))
            y = int(round(cy + math.sin(angle) * s * 0.62))
            if not (0 <= x < 64 and 0 <= y < 64):
                break
            img.putpixel((ox + x, oy + y), FROST[3] if s >= steps - 2 else FROST[2])
            if y + 1 < 64 and s < steps - 3:
                img.putpixel((ox + x, oy + y + 1), FROST[0])
            # Side spurs, like frost feathers.
            if s > 4 and s % 4 == 0:
                for side in (-1, 1):
                    sx = int(round(x + math.cos(angle + side * 0.9) * 2))
                    sy = int(round(y + math.sin(angle + side * 0.9) * 1.3))
                    if 0 <= sx < 64 and 0 <= sy < 64:
                        img.putpixel((ox + sx, oy + sy), FROST[2])
    for _ in range(14):
        x, y = r.randint(8, 56), r.randint(14, 52)
        img.putpixel((ox + x, oy + y), FROST[3])


def main():
    sheet = Image.new("RGBA", (512, 32 + 64 + 64), (0, 0, 0, 0))
    for k in range(6):
        splat(sheet, k * 32, 0, BLOOD, 100 + k)
    for k in range(4):
        trail(sheet, (6 + k) * 32, 0, BLOOD, 200 + k)
    for k in range(3):
        splat(sheet, (10 + k) * 32, 0, GOO, 300 + k)
    for k in range(2):
        splat(sheet, (13 + k) * 32, 0, ICHOR, 400 + k)
    dust(sheet, 15 * 32, 0, 500)
    for k in range(3):
        scorch(sheet, k * 64, 32, 600 + k, (3 + k) * 64, 32)
    for k in range(2):
        cracks(sheet, (6 + k) * 64, 32, 700 + k)
    for k in range(2):
        frost(sheet, k * 64, 96, 800 + k)
    sheet.save(OUT)


if __name__ == "__main__":
    main()
