#!/usr/bin/env python3
"""Draws pixel-art fire: looping flame animations at the game's own pixel
size, one sheet per size, into assets/effects/fire_<size>.png (frames in a
row). Used by scripts/effects/flame_fx.gd for candles, torches, lanterns,
braziers, campfires, hearths and altars.

Run from the project folder:  python3 tools/generate_fire.py
"""
import math
import os
import random
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "effects")


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


# Outer to inner: deep red rim, red, orange, yellow, pale core.
FIRE = [C("7a1c10"), C("c8361a"), C("f07a22"), C("ffc23a"), C("fff2a8")]
EMBER = [C("ffc23a"), C("f07a22"), C("c8361a")]

# name: (width, height, frames, base width share, tongues)
SIZES = {
    "candle": (7, 11, 6, 0.8, 1),
    "torch": (11, 17, 8, 0.7, 2),
    "brazier": (19, 25, 8, 0.85, 3),
    "campfire": (25, 27, 8, 0.95, 4),
    "hearth": (29, 23, 8, 1.0, 5),
}


def flame(width, height, frame, frames, base_share, tongues, seed):
    """One frame: a body of fire built from a few tongues that sway and
    stretch in their own rhythms. Their heat adds up, hottest low in the
    middle, and is banded from a deep red rim to a pale core, with sparks
    lifting off the top."""
    img = Image.new("RGBA", (width, height))
    phase = frame / frames * math.tau
    cx = (width - 1) / 2.0
    heat = [[0.0] * width for _ in range(height)]
    for k in range(tongues):
        offset = 0.0 if tongues == 1 else (k / (tongues - 1) - 0.5) * width * 0.5 * base_share
        middle = 1.0 - abs(offset) / (width * 0.5 + 0.01)
        tall = height * (0.55 + 0.45 * middle) * (0.85 + 0.15 * math.sin(phase * (1 + k % 2) + k * 1.9))
        half = width * 0.5 * base_share * (0.5 + 0.35 * middle)
        for y in range(height):
            t = y / max(tall, 1.0)
            if t >= 1.0:
                continue
            lean = math.sin(phase + t * 3.0 + k * 2.3) * (0.8 + 0.5 * k % 2) * t * 1.6
            w = half * (1.0 - t) ** 0.8 * (0.75 + 0.25 * math.sin(math.pi * min(1.0, t * 2.0)))
            x_mid = cx + offset + lean
            for x in range(width):
                d = (x - x_mid) / max(w, 0.4)
                heat[height - 1 - y][x] += math.exp(-d * d * 1.6) * (1.0 - t) ** 0.6 / (0.6 + 0.4 * tongues ** 0.5)
    for y in range(height):
        rise = 1.0 - 0.45 * (height - 1 - y) / height
        for x in range(width):
            v = heat[y][x] * rise
            if v < 0.14:
                continue
            band = 0 if v < 0.24 else 1 if v < 0.42 else 2 if v < 0.68 else 3 if v < 1.02 else 4
            img.putpixel((x, y), FIRE[band])
    # Sparks rising above the flame.
    for s in range(1 + tongues // 2):
        life = ((frame + s * 3) % frames) / frames
        sx = int(round(cx + math.sin(s * 2.3 + frame * 0.9) * width * 0.28))
        sy = int(round(height * 0.3 - life * height * 0.35))
        if 0 <= sx < width and 0 <= sy < height and img.getpixel((sx, sy))[3] == 0:
            img.putpixel((sx, sy), EMBER[min(2, int(life * 3))])
    return img


def main():
    os.makedirs(ROOT, exist_ok=True)
    for seed, (name, (w, h, frames, share, tongues)) in enumerate(SIZES.items()):
        sheet = Image.new("RGBA", (w * frames, h))
        for f in range(frames):
            sheet.paste(flame(w, h, f, frames, share, tongues, seed), (f * w, 0))
        sheet.save(os.path.join(ROOT, "fire_%s.png" % name))
        print(name, sheet.size)


if __name__ == "__main__":
    main()
