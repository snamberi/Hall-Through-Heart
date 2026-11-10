#!/usr/bin/env python3
"""Draws the interface frames, combat effects, and projectile sprites.

Run from the project folder:  python3 tools/generate_ui_fx.py
Needs Pillow. Overwrites PNGs in assets/ui and assets/effects.
"""
import math
import os
import random
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

NAVY = (15, 19, 31, 244)
NAVY_LIGHT = (27, 32, 48, 255)
BRONZE_DARK = (64, 47, 28, 255)
BRONZE = (138, 104, 58, 255)
GOLD = (222, 184, 106, 255)


def frame(size, fill, outer, inner, ornament=None, inset=3):
    """A bordered box meant to be stretched as a nine-patch."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((1, 1, size - 2, size - 2), fill=fill)
    d.rectangle((0, 0, size - 1, size - 1), outline=outer)
    d.rectangle((1, 1, size - 2, size - 2), outline=outer)
    d.rectangle((inset, inset, size - 1 - inset, size - 1 - inset), outline=inner)
    if ornament:
        # Corner brackets with a small diamond, like worked metal fittings.
        for sx, sy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            def pt(x, y):
                return (size - 1 - x if sx else x, size - 1 - y if sy else y)
            for k in range(0, 11):
                img.putpixel(pt(k, 0), ornament)
                img.putpixel(pt(0, k), ornament)
                img.putpixel(pt(k, 1), outer)
                img.putpixel(pt(1, k), outer)
            for k in range(5, 12):
                img.putpixel(pt(k, 5), ornament)
                img.putpixel(pt(5, k), ornament)
            for x, y in ((7, 7), (8, 7), (7, 8), (6, 7), (7, 6), (8, 8), (9, 8), (8, 9)):
                img.putpixel(pt(x, y), ornament)
            img.putpixel(pt(0, 0), outer)
    return img


def make_ui():
    out = os.path.join(ROOT, "ui")
    os.makedirs(out, exist_ok=True)
    frame(64, NAVY, BRONZE_DARK, BRONZE, GOLD).save(os.path.join(out, "panel.png"))
    frame(48, (20, 24, 37, 255), BRONZE_DARK, (96, 76, 48, 255), BRONZE).save(os.path.join(out, "inset.png"))
    frame(32, (30, 34, 49, 255), BRONZE_DARK, (104, 84, 56, 255), inset=2).save(os.path.join(out, "button.png"))
    frame(32, (44, 48, 66, 255), BRONZE_DARK, GOLD, inset=2).save(os.path.join(out, "button_hover.png"))
    frame(32, (78, 58, 26, 255), (40, 28, 12, 255), (250, 214, 130, 255), inset=2).save(os.path.join(out, "button_pressed.png"))
    frame(32, (24, 26, 34, 255), (40, 38, 40, 255), (58, 56, 60, 255), inset=2).save(os.path.join(out, "button_disabled.png"))
    frame(32, (21, 24, 35, 255), (8, 9, 14, 255), (58, 62, 80, 255), inset=2).save(os.path.join(out, "slot.png"))


# ---------------------------------------------------------------- effects
# Effects are white with alpha so the game can tint them. They are drawn
# small and with only a few alpha steps so they stay pixel art when scaled.

def quantize(a):
    return 0 if a < 0.12 else 110 if a < 0.4 else 190 if a < 0.75 else 255


def sheet(frames, size, pixel):
    img = Image.new("RGBA", (frames * size, size), (0, 0, 0, 0))
    for f in range(frames):
        for y in range(size):
            for x in range(size):
                a = pixel(f, x - size / 2 + 0.5, y - size / 2 + 0.5)
                if a > 0:
                    img.putpixel((f * size + x, y), (255, 255, 255, quantize(a)))
    return img


def slash_pixel(f, x, y):
    """A crescent sweeping clockwise through 130 degrees, pointing right."""
    lead = (0.4, 0.75, 1.0, 1.0, 1.0, 1.0)[f]
    tail = (0.0, 0.0, 0.0, 0.3, 0.62, 0.9)[f]
    span = math.radians(130)
    r, angle = math.hypot(x, y), math.atan2(y, x)
    u = (angle + span / 2) / span          # 0 at the start of the swing, 1 at the end
    if not tail <= u <= lead:
        return 0
    thickness = 11 * math.sin(math.pi * u) ** 0.6 + 1
    outer = 29
    if not outer - thickness <= r <= outer:
        return 0
    depth = (outer - r) / thickness        # 0 on the bright outer edge
    freshness = (u - tail) / max(lead - tail, 0.01)
    return (1 - depth) ** 1.3 * (0.35 + 0.65 * freshness)


def spin_pixel(f, x, y):
    """A swoosh chasing its own tail around a full circle."""
    r, angle = math.hypot(x, y), math.atan2(y, x) % (2 * math.pi)
    head = (f + 1) / 6 * 2 * math.pi
    behind = (head - angle) % (2 * math.pi)
    length = math.radians(250)
    if behind > length:
        return 0
    fresh = 1 - behind / length
    thickness = 2 + 9 * fresh
    outer = 29
    if not outer - thickness <= r <= outer:
        return 0
    return (1 - (outer - r) / thickness) ** 1.2 * (0.3 + 0.7 * fresh) * (1.0 if f < 4 else 0.6)


def ring_pixel(f, x, y):
    """A shockwave ring that grows, thins, and breaks up."""
    r = math.hypot(x, y)
    radius = 7 + f * 4.4
    thickness = max(6 - f, 1.4)
    if abs(r - radius) > thickness / 2:
        return 0
    gaps = random.Random(int(math.atan2(y, x) * 9) * 31 + f).random()
    if f >= 3 and gaps < 0.12 * (f - 2):
        return 0
    return (1 - abs(r - radius) / (thickness / 2) * 0.6) * (1 - f * 0.13)


def spark_pixel(f, x, y):
    """A four-point star that flashes and scatters."""
    reach = (5, 9, 12, 14)[f]
    width = (2.2, 1.6, 1.0, 0.7)[f]
    best = 0
    for turn in (0, math.pi / 4):
        rx = abs(x * math.cos(turn) + y * math.sin(turn))
        ry = abs(-x * math.sin(turn) + y * math.cos(turn))
        for along, across in ((rx, ry), (ry, rx)):
            limit = reach * (1.0 if turn == 0 else 0.6)
            if along <= limit and across <= width * (1 - along / limit) + 0.5:
                if f < 3 or along > limit * 0.55:
                    best = max(best, 1 - along / limit * 0.5)
    return best * (1 - f * 0.15)


def make_projectiles():
    """32x16 sprites pointing right: arrow, arcane bolt, fireball, frost shard."""
    img = Image.new("RGBA", (32 * 4, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    dark = (8, 8, 12, 255)
    # arrow
    d.line((5, 8, 25, 8), fill=dark, width=3)
    d.line((5, 8, 24, 8), fill=(138, 106, 72, 255))
    d.polygon([(24, 4), (31, 8), (24, 12)], fill=dark)
    d.polygon([(25, 6), (29, 8), (25, 10)], fill=(238, 240, 240, 255))
    d.polygon([(2, 4), (8, 8), (2, 12)], fill=dark)
    d.polygon([(3, 6), (6, 8), (3, 10)], fill=(224, 85, 90, 255))
    # the three magic bolts share a shape: a bright head with a fading tail
    for index, (core, body, tail) in enumerate([
        ((240, 225, 255), (176, 124, 255), (106, 56, 184)),
        ((255, 243, 196), (240, 138, 46), (184, 64, 30)),
        ((255, 255, 255), (143, 214, 238), (74, 147, 191)),
    ]):
        ox = 32 * (index + 1)
        d.polygon([(ox + 2, 8), (ox + 18, 3), (ox + 18, 13)], fill=tail + (150,))
        d.polygon([(ox + 9, 8), (ox + 20, 4), (ox + 20, 12)], fill=body + (220,))
        d.ellipse((ox + 16, 2, ox + 29, 14), fill=dark)
        d.ellipse((ox + 17, 3, ox + 28, 13), fill=body + (255,))
        d.ellipse((ox + 20, 5, ox + 26, 11), fill=core + (255,))
    return img


def make_effects():
    out = os.path.join(ROOT, "effects")
    os.makedirs(out, exist_ok=True)
    sheet(6, 64, slash_pixel).save(os.path.join(out, "slash.png"))
    sheet(6, 64, spin_pixel).save(os.path.join(out, "spin.png"))
    # The ring is drawn at double size because it is shown much larger.
    sheet(6, 128, lambda f, x, y: ring_pixel(f, x / 2, y / 2)).save(os.path.join(out, "ring.png"))
    sheet(4, 32, spark_pixel).save(os.path.join(out, "spark.png"))
    make_projectiles().save(os.path.join(out, "projectiles.png"))


if __name__ == "__main__":
    make_ui()
    make_effects()
