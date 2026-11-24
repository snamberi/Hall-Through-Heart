"""The game's icon, drawn on a 48 x 48 pixel grid: a red heart on a navy
field inside a notched gold frame, a gold arched doorway set in the heart
with light pouring out of it (a hall through the heart).

Writes assets/icon/icon.png (256), icon.ico (16-256), android_192.png and
the Android adaptive layers (432), splash.png, every size scaled up by a
whole number from the 48-pixel picture (or 64 for the adaptive layers),
so the pixels stay square.

Run: python3 tools/generate_icon.py
"""
import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "icon")
N = 48


def C(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


NAVY = C("0b1027")
NAVY_EDGE = C("141a3a")
GOLD = [C("ffe08a"), C("eab452"), C("c8862e"), C("8a5418"), C("4e2c0c")]
HEART = [C("ff8a86"), C("e8203e"), C("c4102e"), C("980a26"), C("6a061c"), C("440312")]
GLOW = [C("fffbe6"), C("fff0b8"), C("ffdc84")]
DOOR_DARK = C("2a1408")


def heart_inside(x, y, cx=24.0, cy=23.5, s=15.8):
    """The classic heart curve, sized s, centred on (cx, cy)."""
    u = (x + 0.5 - cx) / s
    v = -(y + 0.5 - cy) / s + 0.25
    return (u * u + v * v - 1) ** 3 - u * u * v ** 3 <= 0


def draw(full_bleed=False):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0) if full_bleed else NAVY)
    px = img.load()
    if not full_bleed:
        # The notched gold frame, one pixel, two in from the edge.
        lo, hi, notch = 2, N - 3, 4
        for k in range(lo, hi + 1):
            for x, y in ((k, lo), (k, hi), (lo, k), (hi, k)):
                corner = (x < lo + notch or x > hi - notch) and (y < lo + notch or y > hi - notch)
                if not corner:
                    px[x, y] = GOLD[1]
        # Each corner stepped inward: a little square notch.
        for sx, sy in ((lo, lo), (hi, lo), (lo, hi), (hi, hi)):
            dx = 1 if sx == lo else -1
            dy = 1 if sy == lo else -1
            ix, iy = sx + dx * notch, sy + dy * notch
            for k in range(notch + 1):
                px[sx + dx * k, iy] = GOLD[1]
                px[ix, sy + dy * k] = GOLD[1]
            # Join the notch to the frame.
            for k in range(notch + 1):
                px[ix, sy + dy * k] = GOLD[1]
                px[sx + dx * k, iy] = GOLD[1]
    # The heart: shaded in diagonal bands from a light at the upper left,
    # a dark rim on the lower right, a gloss streak and glint.
    cells = [(x, y) for y in range(N) for x in range(N) if heart_inside(x, y)]
    for x, y in cells:
        t = (x * 0.62 + y * 0.78) / (N * 1.4)
        tone = 1 if t < 0.42 else 2 if t < 0.55 else 3 if t < 0.68 else 4
        edge = not heart_inside(x + 1, y) or not heart_inside(x, y + 1)
        if edge and tone >= 2:
            tone = min(tone + 1, 5)
        px[x, y] = HEART[tone]
    # The point drips a pixel below.
    bottom = max(y for _x, y in cells)
    tip = [x for x, y in cells if y == bottom]
    mid = tip[len(tip) // 2]
    px[mid, bottom + 1] = HEART[4]
    px[mid, bottom + 2] = HEART[5]
    # Gloss on the left lobe.
    for x, y in ((12, 10), (13, 10), (14, 10), (15, 10), (16, 10), (11, 11), (12, 11), (13, 11), (10, 12), (11, 12), (10, 13), (9, 14), (10, 14), (9, 16)):
        if heart_inside(x, y):
            px[x, y] = HEART[0]
    # The doorway: a pointed arch of gold stones round a dark reveal, light
    # pouring out of it, on two gold steps.
    cx = 24
    top, base = 14, 33
    for y in range(top, base + 1):
        for x in range(cx - 7, cx + 8):
            d = abs(x + 0.5 - (cx + 0.5))
            # The arch narrows to a point toward its top.
            arch = 6.0 if y > top + 6 else 6.0 - (top + 6 - y) * 0.95
            if d > arch:
                continue
            ring = arch - d
            if ring < 2.2:
                # Stones: lit on the left, joints every few rows.
                stone = GOLD[1] if x < cx else GOLD[2]
                if (y - top) % 4 == 0 and y > top + 6:
                    stone = GOLD[3]
                if ring < 0.9:
                    stone = GOLD[3] if x >= cx else GOLD[2]
                px[x, y] = stone
            elif ring < 3.2:
                px[x, y] = DOOR_DARK
            else:
                # The light inside, brightest in the middle.
                glow = GLOW[0] if d < 1.6 else GLOW[1] if d < 3.0 else GLOW[2]
                px[x, y] = glow
    # The finial on top of the arch.
    px[cx, top - 1] = GOLD[0]
    px[cx, top - 2] = GOLD[1]
    px[cx - 1, top - 1] = GOLD[2]
    # Two steps at its foot, lit along their top edges.
    for y, half in ((base - 1, 6), (base, 6), (base + 1, 8), (base + 2, 8)):
        for x in range(cx - half, cx + half + 1):
            px[x, y] = GOLD[0] if y in (base - 1, base + 1) else (GOLD[2] if x < cx + half - 1 else GOLD[3])
    # A dark outline round the door and steps, so they sit in the heart.
    solid = {(x, y) for y in range(top - 2, base + 3) for x in range(cx - 11, cx + 12)
             if px[x, y] in GOLD or px[x, y] in GLOW or px[x, y] == DOOR_DARK}
    for x, y in list(solid):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if p not in solid and px[p] in HEART:
                px[p] = HEART[5]
    return img


def scaled(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def main():
    icon = draw()
    # 256: 48 x 5 = 240, centred on navy.
    big = Image.new("RGBA", (256, 256), NAVY)
    big.paste(scaled(icon, 5), (8, 8))
    big.save(os.path.join(OUT, "icon.png"))
    big.save(os.path.join(OUT, "icon.ico"), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    # 192: 48 x 4.
    scaled(icon, 4).save(os.path.join(OUT, "android_192.png"))
    # Adaptive layers (432): the heart and door alone in the middle safe
    # zone, on a navy field; the monochrome one is its silhouette.
    fore = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    art = scaled(draw(full_bleed=True), 6)
    fore.paste(art, ((432 - art.width) // 2, (432 - art.height) // 2), art)
    fore.save(os.path.join(OUT, "android_foreground.png"))
    Image.new("RGBA", (432, 432), NAVY).save(os.path.join(OUT, "android_background.png"))
    mono = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    mask = fore.split()[3].point(lambda a: 255 if a > 0 else 0)
    mono.paste(Image.new("RGBA", (432, 432), (255, 255, 255, 255)), (0, 0), mask)
    mono.save(os.path.join(OUT, "android_monochrome.png"))


if __name__ == "__main__":
    main()
