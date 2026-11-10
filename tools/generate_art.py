#!/usr/bin/env python3
"""Draws the game's placeholder pixel art (44px sprites and terrain tiles).

Run from the project folder:  python3 tools/generate_art.py
Needs Pillow (pip install pillow). Overwrites the PNGs in assets/.
Hand-drawn art can replace any of these files as long as the size and
layout stay the same.
"""
import math
import os
import random
from PIL import Image, ImageDraw

N = 44
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
OUTLINE = "08080c"


def rgba(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# --------------------------------------------------------------- sprites
# Each material has three shades: light, mid, shadow. Light comes from top-left.

PALETTE = {
    "skin": ["e8c4a0", "c99c7c", "9c7460"],
    "hair": ["6e4a33", "523625", "38241a"],
    "tunic": ["b9ad92", "968a72", "6e6454"],
    "belt": ["5a4032", "46312a", "32231f"],
    "trousers": ["4c4a5e", "383648", "272633"],
    "boot": ["4a3b33", "382b26", "261c1a"],
    "blade": ["eef0f0", "b4bcc2", "7d8890"],
    "guard": ["b89a52", "8e7338", "634f26"],
    "void": ["0b0a12"] * 3,
    "mouth": ["9c6a5a"] * 3,
    "flesh": ["5d6a78", "424d5b", "2c3440"],
    "rib": ["2c3440", "252c37", "1e242e"],
    "bone": ["f2efe2", "cfcbb8", "9b9889"],
    "eye": ["7dff9a"] * 3,
}


# Animated characters are rigs: named groups of parts, each rotating about a
# pivot and following its parent group. A pose gives each group
# (dx, dy, degrees); every animation is 12 poses. Coordinates are in a 44px
# box; frames are FRAME px so swings and falls have room around the body.

FRAMES = 12
FRAME = 64
FRAME_OFFSET = (10, 14)  # where the 44px box sits inside a frame
GROUND_Y = 41 + FRAME_OFFSET[1]


def R(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def E(x0, y0, x1, y1, n=28):
    cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    return [(cx + rx * math.cos(2 * math.pi * k / n), cy + ry * math.sin(2 * math.pi * k / n)) for k in range(n)]


HUMAN = {
    "root": dict(parent=None, pivot=(22, 41), parts=[]),
    "leg_l": dict(parent="root", pivot=(18.5, 34), parts=[("trousers", R(17, 34, 20, 39)), ("boot", R(16, 39, 20, 41))]),
    "leg_r": dict(parent="root", pivot=(25.5, 34), parts=[("trousers", R(24, 34, 27, 39)), ("boot", R(24, 39, 28, 41))]),
    "torso": dict(parent="root", pivot=(22, 35), parts=[("tunic", [(15, 25), (29, 25), (30, 35), (14, 35)]), ("belt", R(14, 31, 30, 32))]),
    "arm_l": dict(parent="torso", pivot=(12.5, 26), parts=[("tunic", R(11, 26, 14, 32)), ("skin", R(11, 33, 14, 34))]),
    "sword": dict(parent="arm_r", pivot=(35.5, 32), parts=[
        ("blade", R(34.5, 13.5, 36.5, 29.5)), ("blade", [(34.5, 14), (36.5, 14), (36.5, 10.5)]),
        ("guard", R(33, 30, 38, 31)), ("belt", R(35, 32, 36, 34))]),
    "arm_r": dict(parent="torso", pivot=(31.5, 26), parts=[("tunic", R(30, 26, 33, 30)), ("skin", R(32, 31, 36, 33))]),
    "head": dict(parent="torso", pivot=(22, 25), parts=[
        ("hair", E(10, 3, 34, 23)), ("skin", E(13, 10, 31, 26)),
        ("hair", [(13, 12), (18, 9), (24, 12), (28, 9), (31, 13), (30, 8), (14, 8)]),
        ("void", R(17, 17, 18, 19)), ("void", R(25, 17, 26, 19)), ("mouth", R(21, 23, 23, 23))]),
}
HUMAN_ORDER = ["leg_l", "leg_r", "torso", "arm_l", "sword", "arm_r", "head"]

HUSK = {
    "root": dict(parent=None, pivot=(22, 41), parts=[]),
    "back_arm": dict(parent="torso", pivot=(13, 22), parts=[("flesh", R(12, 22, 14, 38)), ("bone", [(11, 38), (15, 38), (13, 42)])]),
    "leg_l": dict(parent="root", pivot=(18.5, 34), parts=[("flesh", R(17, 34, 20, 41))]),
    "leg_r": dict(parent="root", pivot=(25.5, 34), parts=[("flesh", R(24, 34, 27, 41))]),
    "torso": dict(parent="root", pivot=(21, 37), parts=[
        ("flesh", E(11, 13, 31, 37)),
        ("rib", R(16, 24, 24, 24)), ("rib", R(16, 27, 25, 27)), ("rib", R(17, 30, 24, 30)),
        ("bone", [(13, 16), (11, 12), (16, 14)]), ("bone", [(17, 13), (17, 8), (21, 12)])]),
    "head": dict(parent="torso", pivot=(25, 17), parts=[
        ("flesh", E(21, 6, 37, 21)), ("void", E(28, 14, 35, 20)),
        ("bone", R(30, 14, 30, 15)), ("bone", R(33, 14, 33, 15)), ("bone", R(31, 19, 31, 20)),
        ("void", E(26, 9, 30, 13)), ("eye", R(28, 11, 28, 11))]),
    "front_arm": dict(parent="torso", pivot=(30, 23), parts=[("flesh", R(29, 23, 31, 37)), ("bone", [(28, 37), (32, 37), (31, 42)])]),
}
HUSK_ORDER = ["back_arm", "leg_l", "leg_r", "torso", "head", "front_arm"]


def _transform(rig, name, point, pose):
    while name is not None:
        group = rig[name]
        dx, dy, degrees = pose.get(name, (0, 0, 0))
        px, py = pose.get(name + "_pivot", group["pivot"])
        a = math.radians(degrees)
        x, y = point[0] - px, point[1] - py
        point = (px + x * math.cos(a) - y * math.sin(a) + dx, py + x * math.sin(a) + y * math.cos(a) + dy)
        name = group["parent"]
    return point


def draw_frame(rig, order, pose):
    ox, oy = FRAME_OFFSET
    pixels = {}
    for name in order:
        for material, polygon in rig[name]["parts"]:
            moved = [_transform(rig, name, pt, pose) for pt in polygon]
            mask = Image.new("L", (FRAME, FRAME), 0)
            ImageDraw.Draw(mask).polygon([(x + ox, y + oy) for x, y in moved], fill=255, outline=255)
            points = [(x, y) for y in range(FRAME) for x in range(FRAME) if mask.getpixel((x, y))]
            if not points:
                continue
            x0, x1 = min(p[0] for p in points), max(p[0] for p in points)
            y0, y1 = min(p[1] for p in points), max(p[1] for p in points)
            for x, y in points:
                t = 0.7 * (x - x0) / max(x1 - x0, 1) + 0.3 * (y - y0) / max(y1 - y0, 1)
                pixels[(x, y)] = PALETTE[material][0 if t < 0.3 else 1 if t < 0.68 else 2]

    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    shadow_x, shadow_w = pose.get("shadow", (22, 9))
    ImageDraw.Draw(img).ellipse((shadow_x + ox - shadow_w, GROUND_Y - 2, shadow_x + ox + shadow_w, GROUND_Y + 2), fill=(0, 0, 0, 90))
    for (x, y), colour in pixels.items():
        img.putpixel((x, y), rgba(colour))
    for y in range(FRAME):
        for x in range(FRAME):
            if (x, y) not in pixels and any(
                (x + dx, y + dy) in pixels for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            ):
                img.putpixel((x, y), rgba(OUTLINE))
    return img


def blend(a, b, t):
    """Pose between two poses, t from 0 to 1."""
    out = {}
    for key in set(a) | set(b):
        default = a.get(key, b.get(key)) if key.endswith("_pivot") or key == "shadow" else (0, 0, 0)
        va, vb = a.get(key, default), b.get(key, default)
        out[key] = tuple(x + (y - x) * t for x, y in zip(va, vb))
    return out


def keyframes(keys):
    """12 poses from [(frame, pose), ...], blending between neighbours."""
    poses = []
    for i in range(FRAMES):
        for (f0, p0), (f1, p1) in zip(keys, keys[1:]):
            if f0 <= i <= f1:
                poses.append(blend(p0, p1, (i - f0) / max(f1 - f0, 1)))
                break
    return poses


def wave(i):
    return math.sin(2 * math.pi * i / FRAMES)


# --- human animations
def human_idle(i):
    return {"torso": (0, 1 if 3 <= i <= 8 else 0, 0), "sword": (0, 0, 3 * wave(i))}


def human_run(i):
    s = wave(i)
    return {
        "root": (0, -round(abs(s) * 2), 0), "torso": (1, 0, 7), "head": (0, 0, -4),
        "leg_l": (0, 0, 38 * s), "leg_r": (0, 0, -38 * s),
        "arm_l": (0, 0, -35 * s), "arm_r": (0, 0, 18 * s),
    }


def human_attack(i):
    # (sword arm, sword, torso lean, step forward): wind back, slash, recover.
    arm, sword, lean, step = [
        (-20, -10, -3, 0), (-60, -25, -6, -1), (-95, -35, -8, -1), (-60, 0, 0, 1),
        (10, 40, 8, 3), (55, 70, 12, 4), (75, 85, 12, 4), (70, 80, 10, 3),
        (50, 60, 7, 2), (30, 35, 4, 1), (12, 15, 2, 0), (0, 0, 0, 0),
    ][i]
    return {"root": (step, 0, 0), "torso": (0, 0, lean), "arm_r": (0, 0, arm), "sword": (0, 0, sword), "arm_l": (0, 0, -lean * 2)}


def human_dodge(i):
    spin = [0, 20, 60, 110, 160, 200, 240, 280, 320, 345, 355, 0][i]
    drop = [0, 2, 4, 5, 5, 5, 5, 5, 4, 2, 1, 0][i]
    tuck = min(i, 11 - i, 2) / 2
    return {
        "root": (0, drop, spin), "root_pivot": (22, 27),
        "leg_l": (0, 0, 45 * tuck), "leg_r": (0, 0, -40 * tuck),
        "arm_l": (0, 0, -50 * tuck), "arm_r": (0, 0, 40 * tuck), "head": (0, 2 * tuck, 0),
    }


HUMAN_STAND = {"root_pivot": (16, 41), "shadow": (22, 9, 0)}
HUMAN_RECOIL = {"root_pivot": (16, 41), "shadow": (22, 9, 0), "root": (-1, 0, -6), "torso": (0, 0, -12), "head": (0, 0, -14),
                "arm_l": (0, 0, -70), "arm_r": (0, 0, 60), "sword": (0, 0, 40)}
HUMAN_KNEEL = {"root_pivot": (16, 41), "shadow": (22, 11, 0), "root": (0, 7, 0), "torso": (0, 0, 10), "head": (0, 0, 20),
               "arm_l": (0, 0, 10), "arm_r": (0, 0, 10), "sword": (3, 2, 95), "leg_l": (0, 0, 80), "leg_r": (0, 0, 75)}
HUMAN_LYING = {"root_pivot": (16, 41), "shadow": (34, 18, 0), "root": (0, -20, 90), "head": (0, 0, 10),
               "arm_l": (0, 0, 20), "arm_r": (0, 0, -20), "sword": (0, 0, 120), "leg_l": (0, 0, 10), "leg_r": (0, 0, -6)}
HUMAN_RISEN = {"root_pivot": (16, 41), "shadow": (22, 9, 0), "torso": (0, -1, -4), "head": (0, 0, -10),
               "arm_l": (0, 0, 150), "arm_r": (0, 0, -150), "sword": (0, 0, 0)}
HUMAN_KNEEL_UP = dict(HUMAN_KNEEL, sword=(0, 0, 0))

HUMAN_DEATH = keyframes([(0, HUMAN_STAND), (2, HUMAN_RECOIL), (5, HUMAN_KNEEL), (9, HUMAN_LYING), (11, HUMAN_LYING)])
HUMAN_REBIRTH = keyframes([(0, HUMAN_LYING), (2, HUMAN_LYING), (6, HUMAN_KNEEL_UP), (9, HUMAN_RISEN), (11, HUMAN_STAND)])


# --- husk animations
def husk_idle(i):
    return {"torso": (0, 1 if 3 <= i <= 8 else 0, 0), "front_arm": (0, 0, 4 * wave(i)), "back_arm": (0, 0, -4 * wave(i))}


def husk_walk(i):
    s = wave(i)
    return {
        "root": (0, -round(abs(s)), 0), "head": (0, 0, 4 * s),
        "leg_l": (0, 0, 28 * s), "leg_r": (0, 0, -28 * s),
        "back_arm": (0, 0, -22 * s), "front_arm": (0, 0, 22 * s),
    }


def husk_windup(i):
    t = i / 11
    shake = (i % 2) if i > 5 else 0
    return {
        "root": (-round(2 * t) + shake, round(3 * t), 0), "torso": (0, 0, -12 * t), "head": (0, 0, -22 * t),
        "front_arm": (0, 0, -120 * t), "back_arm": (0, 0, -100 * t),
    }


def husk_lunge(i):
    k = min(i / 3, 1) if i <= 8 else (11 - i) / 3
    return {
        "root": (round(5 * k), round(k), 0), "torso": (0, 0, 28 * k), "head": (0, 0, 12 * k),
        "front_arm": (0, 0, -95 * k), "back_arm": (0, 0, -80 * k),
        "leg_l": (0, 0, 30 * k), "leg_r": (0, 0, -25 * k),
    }


HUSK_STAND = {"root_pivot": (30, 41), "shadow": (22, 11, 0)}
HUSK_REEL = {"root_pivot": (30, 41), "shadow": (22, 11, 0), "torso": (0, 0, -15), "head": (0, 0, -30),
             "front_arm": (0, 0, -40), "back_arm": (0, 0, -40)}
HUSK_FALLEN = {"root_pivot": (30, 41), "shadow": (12, 18, 0), "root": (0, -19, -90), "head": (0, 0, -20),
               "front_arm": (0, 0, -60), "back_arm": (0, 0, 30), "leg_l": (0, 0, 15), "leg_r": (0, 0, -20)}
HUSK_DEATH = keyframes([(0, HUSK_STAND), (2, HUSK_REEL), (7, HUSK_FALLEN), (11, HUSK_FALLEN)])

# Row order here is the row order in the sheet; the game lists the same names.
HUMAN_ANIMATIONS = [
    ("idle", [human_idle(i) for i in range(FRAMES)]),
    ("run", [human_run(i) for i in range(FRAMES)]),
    ("attack", [human_attack(i) for i in range(FRAMES)]),
    ("dodge", [human_dodge(i) for i in range(FRAMES)]),
    ("death", HUMAN_DEATH),
    ("rebirth", HUMAN_REBIRTH),
]
HUSK_ANIMATIONS = [
    ("idle", [husk_idle(i) for i in range(FRAMES)]),
    ("walk", [husk_walk(i) for i in range(FRAMES)]),
    ("windup", [husk_windup(i) for i in range(FRAMES)]),
    ("lunge", [husk_lunge(i) for i in range(FRAMES)]),
    ("death", HUSK_DEATH),
]


def draw_sheet(rig, order, animations):
    sheet = Image.new("RGBA", (FRAMES * FRAME, len(animations) * FRAME), (0, 0, 0, 0))
    for row, (_name, poses) in enumerate(animations):
        for column, pose in enumerate(poses):
            pose = dict(pose)
            if "shadow" in pose:
                pose["shadow"] = (pose["shadow"][0], pose["shadow"][1])
            sheet.paste(draw_frame(rig, order, pose), (column * FRAME, row * FRAME))
    return sheet


# ----------------------------------------------------------------- tiles
# Row order must match the Type enum in scripts/world/terrain_tiles.gd.
# Each row: name, base, light, dark, accent.
TILES = [
    ("deep_water", "141b2b", "1f2a40", "0e1320", "2b3a55"),
    ("shallow_water", "23364a", "35506a", "1a2838", "4f7088"),
    ("mud", "3d342c", "51463a", "2b2420", "62574a"),
    ("ash", "4b4a4e", "5e5d66", "37363b", "d8d2c0"),
    ("dead_grass", "4a4d32", "6a6c42", "373a27", "86875a"),
    ("dark_grass", "26382c", "3a5540", "1a281f", "9c3b3b"),
    ("bog", "2e3528", "46503a", "1c2219", "7a8a4a"),
    ("rock", "3a3944", "55546a", "17161d", "6c6b82"),
]
VARIANTS = 8


def draw_tile(row, variant):
    name, base, light, dark, accent = TILES[row]
    base, light, dark, accent = rgba(base), rgba(light), rgba(dark), rgba(accent)
    r = random.Random(row * 31 + variant)
    img = Image.new("RGBA", (N, N), base)
    d = ImageDraw.Draw(img)

    def put(x, y, c):
        if 0 <= x < N and 0 <= y < N:
            img.putpixel((x, y), c)

    def tuft(c_low, c_tip):
        x, y = r.randrange(2, N - 4), r.randrange(5, N - 1)
        for dx, h in ((0, 3), (1, 4), (2, 2)):
            for k in range(h):
                put(x + dx, y - k, c_tip if k == h - 1 else c_low)

    def pebble():
        x, y = r.randrange(2, N - 5), r.randrange(2, N - 4)
        d.rectangle((x, y, x + 2, y + 1), fill=dark)
        put(x, y, light)

    def puddle():
        x, y = r.randrange(3, N - 12), r.randrange(3, N - 8)
        w, h = r.randrange(6, 10), r.randrange(3, 5)
        d.ellipse((x, y, x + w, y + h), fill=dark)
        d.line((x + 2, y + 1, x + w - 3, y + 1), fill=light)

    if name == "rock":
        img.paste(dark, (0, 0, N, N))
        y = 1
        while y < N - 2:
            h = min(r.choice((9, 10, 11)), N - 1 - y)
            x = 1
            while x < N - 2:
                w = min(r.choice((10, 13, 16)), N - 1 - x)
                d.rectangle((x, y, x + w - 2, y + h - 2), fill=base)
                d.line((x, y, x + w - 2, y), fill=light)
                d.line((x, y, x, y + h - 3), fill=light)
                if r.random() < 0.4:
                    put(x + r.randrange(2, max(3, w - 3)), y + r.randrange(2, max(3, h - 3)), accent)
                x += w
            y += h
        return img

    for _ in range(90):
        put(r.randrange(N), r.randrange(N), light if r.random() < 0.5 else dark)

    if name in ("deep_water", "shallow_water"):
        for _ in range(4):
            x, y, w = r.randrange(2, N - 9), r.randrange(3, N - 3), r.randrange(4, 8)
            d.line((x, y, x + w, y), fill=accent)
            d.line((x + 2, y + 1, x + w + 1, y + 1), fill=dark)
    elif name == "mud":
        for _ in range(3):
            pebble()
        puddle()
    elif name == "ash":
        for _ in range(3):
            pebble()
        x, y = r.randrange(6, N - 14), r.randrange(6, N - 10)
        d.line((x, y, x + 4, y + 3, x + 6, y + 2, x + 10, y + 6), fill=dark)   # crack
        if variant == 7:                                                       # a stray bone
            x, y = r.randrange(6, N - 12), r.randrange(6, N - 8)
            d.line((x, y, x + 5, y + 2), fill=accent)
            put(x - 1, y - 1, accent)
            put(x + 6, y + 3, accent)
    elif name == "dead_grass":
        for _ in range(8):
            tuft(dark, accent)
    elif name == "dark_grass":
        for _ in range(9):
            tuft(dark, light)
        if variant == 7:                                                       # a small mushroom
            x, y = r.randrange(6, N - 8), r.randrange(8, N - 6)
            d.rectangle((x, y, x + 3, y + 1), fill=accent)
            d.rectangle((x + 1, y + 2, x + 2, y + 3), fill=rgba("d8d2c0"))
    elif name == "bog":
        puddle()
        puddle()
        for _ in range(3):
            x, y = r.randrange(3, N - 3), r.randrange(8, N - 2)
            d.line((x, y, x, y - 5), fill=dark)
            put(x, y - 6, accent)
            put(x, y - 5, accent)
    return img


# ----------------------------------------------------------------- icons
# Item icons are 22px cells in one atlas, 8 per row. The order here is the
# icon index used in scripts/items/item_db.gd - only ever append.
ICON = 22
ICON_COLUMNS = 8
ICON_PALETTE = {
    "metal": ["eef0f0", "b4bcc2", "7d8890"],
    "steel": ["9aa7b8", "6f7c90", "4c5668"],
    "gold": ["f0cf6a", "c09a3c", "866a26"],
    "wood": ["8a6a48", "6b4f36", "4a3626"],
    "leather": ["7a5a44", "5a4032", "3b2a22"],
    "bone": ["f2efe2", "cfcbb8", "9b9889"],
    "flesh": ["5d6a78", "424d5b", "2c3440"],
    "green": ["a8ffb4", "5fe07c", "36b85a"],
    "red": ["e0555a", "b3242e", "7a1620"],
    "purple": ["c9a0f0", "8e5cc8", "5c3690"],
    "dark": ["0b0a12"] * 3,
}
ICONS = [
    ("sword", [("metal", "line", (6, 15, 17, 4), 3), ("gold", "line", (4, 13, 9, 18), 2), ("wood", "line", (3, 19, 5, 17), 2)]),
    ("greatsword", [("metal", "line", (7, 14, 18, 3), 5), ("gold", "line", (3, 12, 10, 19), 2), ("wood", "line", (2, 20, 5, 17), 3)]),
    ("axe", [("wood", "line", (5, 19, 15, 6), 2), ("metal", "poly", [(11, 3), (19, 4), (19, 12), (14, 9)])]),
    ("dagger", [("metal", "line", (9, 12, 15, 6), 3), ("gold", "line", (6, 11, 11, 16), 2), ("wood", "line", (5, 17, 7, 15), 2)]),
    ("spear", [("wood", "line", (3, 19, 15, 7), 2), ("metal", "poly", [(13, 6), (20, 2), (16, 9)])]),
    ("shield", [("steel", "poly", [(4, 3), (18, 3), (18, 11), (11, 19), (4, 11)]), ("gold", "ellipse", (9, 7, 13, 11))]),
    ("helmet", [("steel", "ellipse", (4, 3, 18, 17)), ("steel", "rect", (4, 10, 18, 16)), ("dark", "rect", (7, 10, 15, 11)), ("dark", "rect", (10, 12, 12, 16))]),
    ("chest", [("steel", "poly", [(5, 3), (9, 3), (11, 5), (13, 3), (17, 3), (20, 7), (17, 9), (17, 19), (5, 19), (5, 9), (2, 7)]), ("gold", "rect", (5, 14, 17, 15))]),
    ("legs", [("steel", "poly", [(5, 3), (17, 3), (18, 19), (13, 19), (11, 9), (9, 19), (4, 19)]), ("leather", "rect", (5, 3, 17, 4))]),
    ("boots", [("leather", "poly", [(7, 3), (12, 3), (12, 13), (18, 15), (18, 19), (6, 19)]), ("steel", "rect", (6, 18, 18, 19))]),
    ("necklace", [("gold", "ring", (5, 2, 17, 14), 1), ("red", "poly", [(11, 13), (14, 16), (11, 19), (8, 16)])]),
    ("ring", [("gold", "ring", (5, 8, 17, 20), 2), ("green", "rect", (9, 4, 13, 8))]),
    ("relic", [("purple", "poly", [(11, 2), (18, 11), (11, 20), (4, 11)]), ("bone", "rect", (10, 9, 12, 12))]),
    ("husk_fragment", [("flesh", "poly", [(4, 8), (10, 3), (17, 6), (18, 14), (11, 19), (5, 15)])]),
    ("bone", [("bone", "line", (6, 15, 15, 6), 3), ("bone", "ellipse", (3, 14, 8, 19)), ("bone", "ellipse", (13, 2, 18, 7))]),
    ("claw", [("bone", "poly", [(5, 18), (8, 8), (15, 3), (18, 4), (13, 9), (11, 18)])]),
    ("essence", [("green", "ellipse", (5, 5, 17, 17)), ("bone", "rect", (9, 8, 10, 9))]),
    ("gold", [("gold", "ellipse", (3, 9, 13, 18)), ("gold", "ellipse", (9, 5, 19, 14))]),
]


def draw_icon(parts):
    pixels = {}
    for part in parts:
        material, shape, coords = part[0], part[1], part[2]
        mask = Image.new("L", (ICON, ICON), 0)
        d = ImageDraw.Draw(mask)
        if shape == "rect":
            d.rectangle(coords, fill=255)
        elif shape == "ellipse":
            d.ellipse(coords, fill=255)
        elif shape == "ring":
            d.ellipse(coords, outline=255, width=part[3])
        elif shape == "line":
            d.line(coords, fill=255, width=part[3])
        else:
            d.polygon(coords, fill=255, outline=255)
        points = [(x, y) for y in range(ICON) for x in range(ICON) if mask.getpixel((x, y))]
        if not points:
            continue
        x0, x1 = min(p[0] for p in points), max(p[0] for p in points)
        y0, y1 = min(p[1] for p in points), max(p[1] for p in points)
        for x, y in points:
            t = 0.6 * (x - x0) / max(x1 - x0, 1) + 0.4 * (y - y0) / max(y1 - y0, 1)
            pixels[(x, y)] = ICON_PALETTE[material][0 if t < 0.3 else 1 if t < 0.68 else 2]
    img = Image.new("RGBA", (ICON, ICON), (0, 0, 0, 0))
    for (x, y), colour in pixels.items():
        img.putpixel((x, y), rgba(colour))
    for y in range(ICON):
        for x in range(ICON):
            if (x, y) not in pixels and any(
                (x + dx, y + dy) in pixels for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            ):
                img.putpixel((x, y), rgba(OUTLINE))
    return img


def main():
    os.makedirs(os.path.join(ROOT, "sprites"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "tiles"), exist_ok=True)
    draw_sheet(HUMAN, HUMAN_ORDER, HUMAN_ANIMATIONS).save(os.path.join(ROOT, "sprites", "player_sheet.png"))
    draw_sheet(HUSK, HUSK_ORDER, HUSK_ANIMATIONS).save(os.path.join(ROOT, "sprites", "husk_sheet.png"))
    atlas = Image.new("RGBA", (VARIANTS * N, len(TILES) * N))
    for row in range(len(TILES)):
        for variant in range(VARIANTS):
            atlas.paste(draw_tile(row, variant), (variant * N, row * N))
    atlas.save(os.path.join(ROOT, "tiles", "terrain.png"))

    os.makedirs(os.path.join(ROOT, "icons"), exist_ok=True)
    rows = (len(ICONS) + ICON_COLUMNS - 1) // ICON_COLUMNS
    icons = Image.new("RGBA", (ICON_COLUMNS * ICON, rows * ICON), (0, 0, 0, 0))
    for index, (_name, parts) in enumerate(ICONS):
        icons.paste(draw_icon(parts), (index % ICON_COLUMNS * ICON, index // ICON_COLUMNS * ICON))
    icons.save(os.path.join(ROOT, "icons", "items.png"))


if __name__ == "__main__":
    main()
