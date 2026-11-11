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
    "blade": ["ffffff", "c4ced6", "7f8c98"],
    "guard": ["b89a52", "8e7338", "634f26"],
    "void": ["0b0a12"] * 3,
    "mouth": ["9c6a5a"] * 3,
    "flesh": ["5d6a78", "424d5b", "2c3440"],
    "rib": ["2c3440", "252c37", "1e242e"],
    "bone": ["f2efe2", "cfcbb8", "9b9889"],
    "eye": ["7dff9a"] * 3,
    "wood": ["8a6a48", "6b4f36", "4a3626"],
    "fire": ["ffd86b", "f08a2e", "b8401e"],
    "fire_core": ["fff3c4"] * 3,
    "frost": ["e6fbff", "8fd6ee", "4a93bf"],
    "dark": ["5a4a82", "3b2f5c", "2a2142"],
    "dark_edge": ["c08cff", "9a5cf0", "6a38b8"],
    "obsidian": ["5a5668", "3a3748", "2a2836"],
    "blood": ["e0555a", "b3242e", "7a1620"],
    "poison": ["c8f08a", "7cc84a", "4a8a2c"],
    "wrap": ["8a2c37", "5c1c28", "3d1220"],
    # Single-tone details.
    "tunic_fold": ["7d7260"] * 3,
    "skin_shade": ["b98a6c"] * 3,
    "boot_cuff": ["6a554a"] * 3,
    # Armour layers are drawn in neutral steel and tinted by tier in game.
    # Monsters.
    "stone": ["8a8794", "66636f", "45434d"],
    "ember": ["ffd86b", "f08a2e", "b8401e"],
    "robe": ["5a3a6a", "3f2850", "2a1a38"],
    "cap": ["c05a8a", "8e3a68", "5c2446"],
    "stalk": ["e8e0c8", "bdb49c", "8c8470"],
    "hide": ["8a5a4a", "66403a", "44292a"],
    "chitin": ["4a5040", "33382c", "20241c"],
    "ghost": ["dfe6ee", "a8b4c2", "70808f"],
    "wing": ["5a4a5e", "3d3142", "281f2c"],
    "slime": ["b8f08a", "7cc84a", "4a8a2c"],
    "glow_red": ["ff5050"] * 3,
    "glow_cyan": ["8ff0ff"] * 3,
    "glow_orange": ["ffb347"] * 3,
    "plate": ["f4f6f8", "c2c9d0", "8c96a0"],
    "plate_dark": ["8c96a0", "6c7682", "4e5762"],
    "cape": ["f2f2f2", "c8c8c8", "9a9a9a"],
}


# Animated characters are rigs: named groups of parts, each rotating about a
# pivot and following its parent group. A pose gives each group
# (dx, dy, degrees); an animation is a list of poses. Coordinates are in a
# 44px box; frames are FRAME px so swings and falls have room around the body.
#
# Equipment is never baked into the body. The body sheet is the bare
# character, and each weapon, shield, helmet, and so on is drawn into its own
# sheet using the same poses, then layered over the body in game.

FRAME = 96
FRAME_OFFSET = (26, 30)  # where the 44px box sits inside a frame
GROUND_Y = 41 + FRAME_OFFSET[1]


def R(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def E(x0, y0, x1, y1, n=28):
    cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    return [(cx + rx * math.cos(2 * math.pi * k / n), cy + ry * math.sin(2 * math.pi * k / n)) for k in range(n)]


HUMAN = {
    "root": dict(parent=None, pivot=(22, 41), parts=[]),
    "leg_l": dict(parent="root", pivot=(18.5, 34), parts=[
        ("trousers", R(17, 34, 20, 39)), ("boot", R(16, 39, 20, 41)), ("boot_cuff", R(16, 38.6, 20, 39.2))]),
    "leg_r": dict(parent="root", pivot=(25.5, 34), parts=[
        ("trousers", R(24, 34, 27, 39)), ("boot", R(24, 39, 28, 41)), ("boot_cuff", R(24, 38.6, 28, 39.2))]),
    "torso": dict(parent="root", pivot=(22, 35), parts=[
        ("tunic", [(15, 25), (29, 25), (30, 35), (14, 35)]),
        ("tunic_fold", R(21.6, 25, 22.4, 28)),                      # collar slit
        ("tunic_fold", R(17.8, 27, 18.3, 30)), ("tunic_fold", R(26, 28, 26.5, 30.5)),  # folds
        ("tunic_fold", R(14.2, 34.3, 29.8, 35)),                    # hem
        ("belt", R(14, 31, 30, 32)), ("guard", R(21, 30.8, 23, 32.2))]),
    "arm_l": dict(parent="torso", pivot=(12.5, 26), parts=[("tunic", R(11, 26, 14, 32)), ("skin", R(11, 33, 14, 34))]),
    # The hands are empty here; held items are separate layers that follow
    # these groups (see WEAPONS and LAYERS).
    "sword": dict(parent="arm_r", pivot=(35.5, 32), parts=[]),
    "arm_r": dict(parent="torso", pivot=(31.5, 26), parts=[("tunic", R(30, 26, 33, 30)), ("skin", R(32, 31, 36, 33))]),
    "head": dict(parent="torso", pivot=(22, 25), parts=[
        ("hair", E(10, 3, 34, 23)), ("skin", E(13, 10, 31, 26)),
        ("hair", [(13, 13), (17, 9), (21, 12.5), (25, 9), (29, 12), (31, 14), (31, 8), (13, 8)]),  # fringe
        ("hair", [(10, 12), (13.5, 12), (13, 19), (11, 21)]),       # side lock
        ("void", R(17, 17, 18, 19)), ("void", R(25, 17, 26, 19)),
        ("skin_shade", R(21.6, 20.6, 22.4, 21.4))]),               # hint of a nose
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


# Weapon art, drawn as held upright in the right hand (grip at 35.5, 32).
# Keys are the "visual" names used in scripts/items/item_db.py; the order is
# also the order of the generated weapon icons, so only ever append.
WEAPONS = {
    "sword": [("blade", R(34, 12, 37, 29.5)), ("blade", [(34, 12), (37, 12), (35.5, 8)]),
              ("guard", R(32, 30, 39, 31.5)), ("belt", R(35, 32, 36, 34)), ("guard", R(34.8, 34.5, 36.2, 35.5))],
    "greatsword": [("blade", R(33, 5, 38, 29.5)), ("blade", [(33, 5), (38, 5), (35.5, 0)]),
                   ("obsidian", R(35.2, 7, 35.8, 28)),
                   ("guard", R(30, 30, 41, 31.8)), ("belt", R(35, 32, 36, 37)), ("guard", R(34.5, 37, 36.5, 38.5))],
    "axe": [("wood", R(35, 12, 36, 36)), ("blade", [(36, 12), (43, 9), (45.5, 17), (43, 25), (36, 22)]),
            ("blade", [(35, 14), (32, 16), (35, 18)])],
    "dagger": [("blade", [(34.2, 29.5), (36.8, 29.5), (36.6, 23), (35.5, 19)]),
               ("guard", R(33, 30, 38, 31)), ("belt", R(35, 31.5, 36, 33.5))],
    "spear": [("wood", R(35, 3, 36, 41)), ("blade", [(33, 6), (38, 6), (35.5, -4)]), ("wrap", R(34.6, 6, 36.4, 8))],
    "flame_sword": [("fire", [(34, 29.5), (33, 25), (34.6, 21), (33, 16), (35.5, 7), (38, 16), (36.4, 21), (38, 25), (37, 29.5)]),
                    ("fire_core", R(35, 14, 36, 29)), ("guard", R(32, 30, 39, 31.5)), ("belt", R(35, 32, 36, 34))],
    "frost_sword": [("frost", R(34, 12, 37, 29.5)), ("frost", [(34, 12), (37, 12), (35.5, 6)]),
                    ("frost", [(34, 19), (31, 16.5), (34, 23)]), ("frost", [(37, 23), (40, 20.5), (37, 27)]),
                    ("frost", [(31.5, 30), (39.5, 30), (37.5, 32), (33.5, 32)]), ("belt", R(35, 32, 36, 34))],
    "dark_sword": [("dark", R(33.5, 12, 37.5, 29.5)), ("dark", [(33.5, 12), (37.5, 12), (37.5, 7), (35.5, 10)]),
                   ("dark_edge", R(35, 11, 36, 29)), ("dark", [(30.5, 28.5), (40.5, 28.5), (38.5, 32), (32.5, 32)]),
                   ("dark_edge", R(34.8, 29.5, 36.2, 30.9)), ("belt", R(35, 32, 36, 34))],
    "katana": [("blade", [(34.6, 30), (37, 30), (37.6, 22), (38.8, 13), (40.6, 5), (38.4, 8), (36.8, 15), (35.4, 22)]),
               ("obsidian", R(33.5, 30, 38.5, 31)), ("wrap", R(35, 31, 36.5, 37))],
    "executioner": [("obsidian", R(32.5, 6, 38.5, 29.5)), ("obsidian", [(32.5, 6), (38.5, 6), (38.5, 1)]),
                    ("blood", R(37.4, 3, 38.6, 29)), ("guard", R(30.5, 30, 40.5, 31.8)), ("wrap", R(35, 32, 36, 37))],
    "reaver": [("wood", R(35, 11, 36, 36)), ("blade", [(36, 12), (43, 9), (45.5, 17), (43, 25), (36, 22)]),
               ("bone", [(35, 12), (28, 9), (25.5, 17), (28, 25), (35, 22)]), ("blood", R(44.2, 13, 45.2, 21)),
               ("blood", R(25.8, 13, 26.8, 21))],
    "fang": [("poison", [(34.2, 29.5), (36.8, 29.5), (38.6, 24), (38, 17), (36.2, 21), (35, 25.5)]),
             ("bone", R(33, 30, 38, 31)), ("belt", R(35, 31.5, 36, 33.5))],
    "bow": [("wood", [(35, 13), (38.4, 17), (40, 24), (40, 32), (38.4, 39), (35, 43), (36, 38.5), (37.8, 32), (37.8, 24), (36, 17.5)]),
            ("bone", R(34.6, 13.5, 35.2, 42.5)), ("wrap", R(37.4, 25.5, 40.2, 30.5))],
    "staff": [("wood", R(35, 6, 36, 41)), ("bone", [(33.4, 7), (31.6, 1.5), (34.6, 5.5)]), ("bone", [(37.6, 7), (39.4, 1.5), (36.4, 5.5)]),
              ("dark_edge", E(32.6, -2, 38.4, 4))],
    "ember_staff": [("wood", R(35, 6, 36, 41)), ("guard", [(33.4, 7), (31.6, 1.5), (34.6, 5.5)]), ("guard", [(37.6, 7), (39.4, 1.5), (36.4, 5.5)]),
                    ("fire", E(32.6, -2, 38.4, 4)), ("fire_core", E(34.6, 0, 36.4, 2))],
    "halberd": [("wood", R(35, 4, 36, 41)), ("blade", [(34, 5), (37, 5), (35.5, -4)]),
                ("blade", [(36, 6), (42, 4), (44, 11), (42, 18), (36, 15)]), ("blade", [(35, 8), (31, 9.5), (35, 12)])],
}


def _half_ellipse(cx, cy, rx, ry, n=16):
    """Upper half of an ellipse, as a polygon."""
    return [(cx + rx * math.cos(math.pi + math.pi * k / n), cy + ry * math.sin(math.pi + math.pi * k / n)) for k in range(n + 1)]


# Wearable layers: name -> parts per rig group. Each becomes its own sheet.
LAYERS = {
    "shield": {"arm_l": [
        ("plate", [(4, 23), (16, 23), (17, 31), (10.5, 39), (3, 31)]),
        ("plate_dark", [(6, 25), (14, 25), (14.8, 30.5), (10.5, 36), (5.2, 30.5)]),
        ("plate", E(8.5, 27, 12.5, 31))]},
    "helmet": {"head": [
        ("plate", _half_ellipse(22, 13.5, 12.6, 11.5)),
        ("plate_dark", R(9.5, 12.5, 34.5, 14.5)),
        ("plate", R(21, 14, 23, 20)),
        ("plate", R(9.5, 14, 12.5, 21)), ("plate", R(31.5, 14, 34.5, 21))]},
    "chest": {"torso": [
        ("plate", [(15, 25), (29, 25), (29.6, 30.6), (14.4, 30.6)]),
        ("plate_dark", R(21.6, 25.5, 22.4, 30)),
        ("plate_dark", [(14.2, 32.6), (29.8, 32.6), (30, 35), (14, 35)])]},
    "shoulders": {"torso": [("plate", E(10.5, 23.5, 16.5, 28)), ("plate", E(27.5, 23.5, 33.5, 28))]},
    "cape": {"torso": [("cape", [(14.5, 25), (29.5, 25), (34, 40), (10, 40)])]},
}


def _transform(rig, name, point, pose):
    while name is not None:
        group = rig[name]
        dx, dy, degrees = pose.get(name, (0, 0, 0))
        px, py = pose.get(name + "_pivot", group["pivot"])
        a = math.radians(degrees)
        sx, sy = pose.get(name + "_scale", (1, 1))
        x, y = (point[0] - px) * sx, (point[1] - py) * sy
        point = (px + x * math.cos(a) - y * math.sin(a) + dx, py + x * math.sin(a) + y * math.cos(a) + dy)
        name = group["parent"]
    return point


def draw_frame(rig, order, pose, shadow=True):
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
    shadow_x, shadow_w = pose.get("shadow", (22, 9))[:2]
    if shadow:
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
        default = (0, 0, 0)
        if key.endswith("_pivot") or key == "shadow":
            default = a.get(key, b.get(key))
        elif key.endswith("_scale"):
            default = (1, 1)
        va, vb = a.get(key, default), b.get(key, default)
        out[key] = tuple(x + (y - x) * t for x, y in zip(va, vb))
    return out


def keyframes(keys):
    """Poses from [(frame, pose), ...], blending between neighbours."""
    poses = []
    for i in range(keys[-1][0] + 1):
        for (f0, p0), (f1, p1) in zip(keys, keys[1:]):
            if f0 <= i <= f1:
                poses.append(blend(p0, p1, (i - f0) / max(f1 - f0, 1)))
                break
    return poses


def cycle(n, pose_at):
    """A looping animation: pose_at(sine of the phase) for each of n frames."""
    return [pose_at(math.sin(2 * math.pi * i / n)) for i in range(n)]


# --- human animations (frame counts follow the animation spec in the game)
HUMAN_IDLE = [{"torso": (0, bob, 0)} for bob in (0, 1, 1, 0)]
HUMAN_WALK = cycle(8, lambda s: {
    "root": (0, -round(abs(s)), 0),
    "leg_l": (0, 0, 22 * s), "leg_r": (0, 0, -22 * s), "arm_l": (0, 0, -18 * s), "arm_r": (0, 0, 10 * s)})
HUMAN_RUN = cycle(8, lambda s: {
    "root": (0, -round(abs(s) * 2), 0), "torso": (1, 0, 7), "head": (0, 0, -4),
    "leg_l": (0, 0, 38 * s), "leg_r": (0, 0, -38 * s), "arm_l": (0, 0, -35 * s), "arm_r": (0, 0, 18 * s)})


def _swing(arm, weapon, lean, step):
    return {"root": (step, 0, 0), "torso": (0, 0, lean), "arm_r": (0, 0, arm), "sword": (0, 0, weapon), "arm_l": (0, 0, -lean * 2)}


# Wind back, slash, recover.
HUMAN_ATTACK = [_swing(*k) for k in [
    (-60, -25, -6, -1), (-95, -35, -8, -1), (10, 40, 8, 3), (70, 85, 12, 4), (40, 50, 6, 2), (0, 0, 0, 0)]]
# A bigger wind-up and follow-through, for abilities.
HUMAN_HEAVY = [_swing(*k) for k in [
    (-40, -20, -6, -1), (-90, -40, -12, -2), (-125, -50, -15, -3), (-30, 20, 0, 2),
    (60, 80, 16, 6), (90, 100, 18, 6), (50, 60, 8, 3), (0, 0, 0, 0)]]
HUMAN_DODGE = [{
    "root": (0, drop, spin), "root_pivot": (22, 27),
    "leg_l": (0, 0, 45 * tuck), "leg_r": (0, 0, -40 * tuck),
    "arm_l": (0, 0, -50 * tuck), "arm_r": (0, 0, 40 * tuck), "head": (0, 2 * tuck, 0),
} for spin, drop, tuck in [(0, 0, 0), (45, 3, 1), (110, 5, 1), (180, 5, 1), (250, 5, 1), (320, 3, 1), (0, 0, 0)]]

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
HUMAN_FLINCH = {"root": (-3, 0, -5), "torso": (0, 0, -10), "head": (0, 0, -12), "arm_l": (0, 0, -40), "arm_r": (0, 0, 35)}

HUMAN_HURT = [blend({}, HUMAN_FLINCH, t) for t in (0.7, 1.0, 0.4)]
HUMAN_DEATH = keyframes([(0, HUMAN_STAND), (1, HUMAN_RECOIL), (3, HUMAN_KNEEL), (6, HUMAN_LYING), (7, HUMAN_LYING)])
HUMAN_REBIRTH = keyframes([(0, HUMAN_LYING), (1, HUMAN_LYING), (4, HUMAN_KNEEL_UP), (6, HUMAN_RISEN), (7, HUMAN_STAND)])

# --- husk animations
HUSK_IDLE = [{"torso": (0, bob, 0), "front_arm": (0, 0, 4 * bob), "back_arm": (0, 0, -4 * bob)} for bob in (0, 1, 1, 0)]
HUSK_WALK = cycle(8, lambda s: {
    "root": (0, -round(abs(s)), 0), "head": (0, 0, 4 * s),
    "leg_l": (0, 0, 28 * s), "leg_r": (0, 0, -28 * s), "back_arm": (0, 0, -22 * s), "front_arm": (0, 0, 22 * s)})
# Crouch, rear back, and shake before striking.
HUSK_WINDUP = [{
    "root": (-round(2 * t) + (i % 2 if i > 2 else 0), round(3 * t), 0), "torso": (0, 0, -12 * t), "head": (0, 0, -22 * t),
    "front_arm": (0, 0, -120 * t), "back_arm": (0, 0, -100 * t),
} for i, t in enumerate(k / 5 for k in range(6))]
HUSK_LUNGE = [{
    "root": (round(5 * k), round(k), 0), "torso": (0, 0, 28 * k), "head": (0, 0, 12 * k),
    "front_arm": (0, 0, -95 * k), "back_arm": (0, 0, -80 * k), "leg_l": (0, 0, 30 * k), "leg_r": (0, 0, -25 * k),
} for k in (0.5, 1.0, 1.0, 1.0, 0.6, 0.2)]

HUSK_STAND = {"root_pivot": (30, 41), "shadow": (22, 11, 0)}
HUSK_REEL = {"root_pivot": (30, 41), "shadow": (22, 11, 0), "torso": (0, 0, -15), "head": (0, 0, -30),
             "front_arm": (0, 0, -40), "back_arm": (0, 0, -40)}
HUSK_FALLEN = {"root_pivot": (30, 41), "shadow": (12, 18, 0), "root": (0, -19, -90), "head": (0, 0, -20),
               "front_arm": (0, 0, -60), "back_arm": (0, 0, 30), "leg_l": (0, 0, 15), "leg_r": (0, 0, -20)}
HUSK_HURT = [blend({}, dict(HUSK_REEL, root=(-2, 0, 0)), t) for t in (0.7, 1.0, 0.4)]
HUSK_DEATH = keyframes([(0, HUSK_STAND), (1, HUSK_REEL), (5, HUSK_FALLEN), (7, HUSK_FALLEN)])

# Row order here is the row order in every sheet. The game lists the same
# names and frame counts in player_animator.gd and enemy_animator.gd.
HUMAN_ANIMATIONS = [
    ("idle", HUMAN_IDLE), ("walk", HUMAN_WALK), ("run", HUMAN_RUN), ("attack", HUMAN_ATTACK),
    ("heavy", HUMAN_HEAVY), ("dodge", HUMAN_DODGE), ("hurt", HUMAN_HURT),
    ("death", HUMAN_DEATH), ("rebirth", HUMAN_REBIRTH),
]
HUSK_ANIMATIONS = [
    ("idle", HUSK_IDLE), ("walk", HUSK_WALK), ("windup", HUSK_WINDUP), ("lunge", HUSK_LUNGE),
    ("hurt", HUSK_HURT), ("death", HUSK_DEATH),
]


# --- more monsters. Two-legged ones share the husk's group names, so they
# reuse HUSK_ANIMATIONS; the others have their own rigs and poses.
def _biped(back_arm, leg_l, leg_r, torso, head, front_arm, pivots=None):
    pivots = pivots or {}
    return {
        "root": dict(parent=None, pivot=(22, 41), parts=[]),
        "back_arm": dict(parent="torso", pivot=pivots.get("back_arm", (13, 22)), parts=back_arm),
        "leg_l": dict(parent="root", pivot=(18.5, 34), parts=leg_l),
        "leg_r": dict(parent="root", pivot=(25.5, 34), parts=leg_r),
        "torso": dict(parent="root", pivot=(21, 37), parts=torso),
        "head": dict(parent="torso", pivot=pivots.get("head", (23, 18)), parts=head),
        "front_arm": dict(parent="torso", pivot=pivots.get("front_arm", (30, 23)), parts=front_arm),
    }


BONE_ARCHER = _biped(
    back_arm=[("bone", R(13, 20, 14.5, 32))],
    leg_l=[("bone", R(18, 33, 19.5, 41)), ("bone", R(17, 40, 20.5, 41))],
    leg_r=[("bone", R(24.5, 33, 26, 41)), ("bone", R(23.5, 40, 27, 41))],
    torso=[("bone", R(17, 19, 27, 33)), ("void", R(18.5, 22, 25.5, 22.6)), ("void", R(18.5, 25, 25.5, 25.6)),
           ("void", R(18.5, 28, 25.5, 28.6)), ("void", R(21.6, 21, 22.4, 32))],
    head=[("bone", E(16, 5, 30, 19)), ("bone", R(19, 17, 27, 20)), ("void", E(18.5, 9, 22.5, 14)), ("void", E(24, 9, 28, 14)),
          ("glow_red", R(25.6, 11, 26.4, 12)), ("void", R(21, 18, 21.6, 20)), ("void", R(24, 18, 24.6, 20))],
    front_arm=[("bone", R(29.5, 21, 31, 31)), ("wood", [(32, 14), (35.5, 18), (36.8, 25), (35.5, 32), (32, 36), (33, 32), (34.6, 25), (33, 18)]),
               ("bone", R(31.6, 14.5, 32.2, 35.5))],
)
CRAG_GOLEM = _biped(
    back_arm=[("stone", [(6, 20), (12, 19), (13, 34), (9, 40), (4, 37)])],
    leg_l=[("stone", R(14, 33, 20, 41))],
    leg_r=[("stone", R(24, 33, 30, 41))],
    torso=[("stone", [(10, 16), (20, 11), (32, 13), (36, 22), (33, 35), (11, 35), (8, 24)]),
           ("ember", [(18, 22), (22, 20), (26, 23), (23, 28), (19, 27)])],
    head=[("stone", [(20, 5), (30, 4), (34, 10), (31, 16), (21, 16), (18, 10)]), ("void", R(26, 9, 31, 11)), ("glow_orange", R(28, 9.4, 30, 10.6))],
    front_arm=[("stone", [(30, 19), (37, 19), (40, 34), (36, 41), (30, 38)])],
    pivots={"back_arm": (10, 21), "front_arm": (33, 21), "head": (26, 15)},
)
ROT_CULTIST = _biped(
    back_arm=[("robe", R(12, 21, 15, 32))],
    leg_l=[("robe", R(16, 33, 21, 41))],
    leg_r=[("robe", R(23, 33, 28, 41))],
    torso=[("robe", [(16, 19), (28, 19), (31, 36), (13, 36)]), ("bone", R(15, 29, 29, 30))],
    head=[("robe", E(14, 4, 30, 21)), ("robe", [(16, 8), (12, 3), (20, 5)]), ("void", E(18, 9, 28, 19)),
          ("eye", R(20, 13, 21, 14)), ("eye", R(25, 13, 26, 14))],
    front_arm=[("robe", R(29, 21, 32, 30)), ("wood", R(33, 8, 34, 41)), ("eye", E(31, 3, 36, 8))],
)
SPORE_SHAMBLER = _biped(
    back_arm=[("stalk", R(12, 25, 15, 34))],
    leg_l=[("stalk", R(16, 35, 21, 41))],
    leg_r=[("stalk", R(23, 35, 28, 41))],
    torso=[("stalk", [(15, 22), (29, 22), (31, 37), (13, 37)]), ("void", R(25, 27, 28, 29)), ("void", R(26, 32, 30, 33))],
    head=[("cap", _half_ellipse(22, 22, 17, 17)), ("cap", R(5, 21, 39, 23)), ("stalk", E(10, 10, 15, 14)), ("stalk", E(20, 7, 26, 11)),
          ("stalk", E(30, 12, 34, 16))],
    front_arm=[("stalk", R(29, 25, 32, 35))],
    pivots={"head": (22, 23)},
)

QUAD_ORDER = ["leg_fl", "leg_bl", "tail", "body", "head", "leg_br", "leg_fr"]


def _quad(body, head, tail, leg, head_pivot=(31, 24)):
    """A four-legged rig. `leg` builds one leg's parts from its x position."""
    return {
        "root": dict(parent=None, pivot=(22, 41), parts=[]),
        "body": dict(parent="root", pivot=(22, 30), parts=body),
        "head": dict(parent="body", pivot=head_pivot, parts=head),
        "tail": dict(parent="body", pivot=(10, 26), parts=tail),
        "leg_bl": dict(parent="body", pivot=(13, 31), parts=leg(11.5)),
        "leg_br": dict(parent="body", pivot=(16, 31), parts=leg(14.5)),
        "leg_fl": dict(parent="body", pivot=(27, 31), parts=leg(25.5)),
        "leg_fr": dict(parent="body", pivot=(30, 31), parts=leg(28.5)),
    }


ROT_HOUND = _quad(
    body=[("hide", E(8, 20, 34, 33)), ("rib", R(15, 25, 22, 25.6)), ("rib", R(15, 28, 22, 28.6)), ("bone", [(13, 21), (15, 17), (17, 21)]),
          ("bone", [(19, 20), (21, 16), (23, 20)])],
    head=[("hide", E(28, 15, 41, 27)), ("hide", [(38, 21), (44, 22), (44, 26), (37, 27)]), ("void", R(38, 25, 44, 26)),
          ("bone", R(40, 24, 40.6, 26)), ("bone", R(42.5, 24, 43.1, 26)), ("glow_red", R(35, 19, 36.4, 20.4)), ("hide", [(30, 16), (31, 11), (34, 16)])],
    tail=[("hide", [(10, 24), (4, 19), (3, 21), (9, 28)])],
    leg=lambda x: [("hide", R(x, 31, x + 3, 40)), ("bone", R(x, 40, x + 4, 41.4))],
)
THORN_STALKER = _quad(
    body=[("chitin", E(5, 16, 26, 32)), ("poison", E(10, 19, 15, 23)), ("poison", E(17, 22, 20, 25)), ("chitin", E(22, 21, 33, 31))],
    head=[("chitin", E(29, 20, 40, 30)), ("eye", R(35, 23, 36, 24)), ("eye", R(37.5, 24.5, 38.5, 25.5)), ("eye", R(34, 26, 35, 27)),
          ("bone", [(38, 28), (42, 31), (39, 30)]), ("bone", [(36, 29), (38, 33), (36.5, 31)])],
    tail=[("chitin", [(9, 20), (5, 14), (7, 13), (11, 19)])],
    leg=lambda x: [("chitin", [(x + 3, 29), (x - 3, 22), (x - 5, 40), (x - 3.5, 41), (x - 2, 25), (x + 4, 31)])],
    head_pivot=(30, 25),
)

FLOAT_ORDER = ["wing_b", "tail", "body", "head", "wing_f"]


def _floater(body, head, tail, wing_b, wing_f):
    return {
        "root": dict(parent=None, pivot=(22, 28), parts=[]),
        "body": dict(parent="root", pivot=(22, 26), parts=body),
        "head": dict(parent="body", pivot=(24, 16), parts=head),
        "tail": dict(parent="body", pivot=(20, 30), parts=tail),
        "wing_b": dict(parent="body", pivot=(18, 20), parts=wing_b),
        "wing_f": dict(parent="body", pivot=(26, 20), parts=wing_f),
    }


ASH_WRAITH = _floater(
    body=[("ghost", [(14, 16), (30, 16), (32, 30), (12, 30)])],
    head=[("ghost", E(14, 3, 32, 19)), ("void", E(18, 8, 30, 17)), ("glow_cyan", R(21, 11, 22.4, 12.4)), ("glow_cyan", R(26, 11, 27.4, 12.4))],
    tail=[("ghost", [(12, 29), (32, 29), (29, 35), (26, 31), (23, 38), (20, 31), (16, 36)])],
    wing_b=[("ghost", [(15, 18), (9, 22), (5, 30), (8, 30), (12, 25), (16, 22)])],
    wing_f=[("ghost", [(29, 18), (35, 22), (40, 29), (37, 30), (33, 25), (28, 22)]), ("bone", [(39, 28), (42, 31), (38, 31)])],
)
CARRION_BAT = _floater(
    body=[("wing", E(16, 15, 28, 29))],
    head=[("wing", E(18, 7, 31, 19)), ("wing", [(19, 9), (18, 3), (23, 8)]), ("wing", [(26, 8), (30, 3), (30, 10)]),
          ("glow_red", R(23, 12, 24.2, 13.2)), ("glow_red", R(27, 12, 28.2, 13.2)), ("bone", R(24, 16, 24.6, 18)), ("bone", R(27, 16, 27.6, 18))],
    tail=[("wing", [(19, 27), (25, 27), (22, 33)])],
    wing_b=[("wing", [(18, 18), (10, 9), (2, 12), (5, 17), (3, 22), (9, 21), (10, 26), (17, 23)])],
    wing_f=[("wing", [(26, 18), (34, 9), (42, 12), (39, 17), (41, 22), (35, 21), (34, 26), (27, 23)])],
)
EMBER_WISP = _floater(
    body=[("ember", E(13, 13, 31, 31)), ("fire_core", E(18, 17, 27, 26))],
    head=[("void", R(19, 20, 20.6, 22)), ("void", R(24, 20, 25.6, 22))],
    tail=[("ember", [(14, 26), (30, 26), (27, 33), (24, 29), (22, 37), (19, 29), (16, 34)])],
    wing_b=[("ember", [(15, 17), (9, 12), (11, 20), (7, 23), (14, 24)])],
    wing_f=[("ember", [(29, 17), (35, 11), (33, 20), (38, 22), (30, 24)])],
)

BOG_SLIME = {
    "root": dict(parent=None, pivot=(22, 41), parts=[]),
    "body": dict(parent="root", pivot=(22, 41), parts=[
        ("slime", E(8, 20, 36, 41)), ("slime", R(8, 31, 36, 41)), ("poison", E(13, 24, 20, 30)),
        ("void", R(24, 28, 26, 31)), ("void", R(30, 28, 32, 31)), ("void", R(25, 35, 31, 36))]),
}

# Four-legged poses.
QUAD_IDLE = [{"body": (0, bob, 0), "tail": (0, 0, 8 * bob)} for bob in (0, 1, 1, 0)]
QUAD_WALK = cycle(8, lambda s: {
    "root": (0, -round(abs(s)), 0), "head": (0, 0, 5 * s), "tail": (0, 0, -15 * s),
    "leg_bl": (0, 0, 30 * s), "leg_fr": (0, 0, 30 * s), "leg_br": (0, 0, -30 * s), "leg_fl": (0, 0, -30 * s)})
QUAD_WINDUP = [{
    "root": (-round(3 * t) + (i % 2 if i > 2 else 0), round(3 * t), 0), "body": (0, 0, -8 * t), "head": (0, 0, 14 * t),
    "leg_bl": (0, 0, -20 * t), "leg_br": (0, 0, -20 * t), "leg_fl": (0, 0, 20 * t), "leg_fr": (0, 0, 20 * t),
} for i, t in enumerate(k / 5 for k in range(6))]
QUAD_LUNGE = [{
    "root": (round(7 * k), -round(5 * k), 0), "body": (0, 0, -10 * k), "head": (0, 0, -8 * k), "tail": (0, 0, 25 * k),
    "leg_bl": (0, 0, 50 * k), "leg_br": (0, 0, 45 * k), "leg_fl": (0, 0, -55 * k), "leg_fr": (0, 0, -50 * k),
} for k in (0.5, 1.0, 1.0, 1.0, 0.6, 0.2)]
QUAD_STAND = {"root_pivot": (22, 41), "shadow": (22, 13, 0)}
QUAD_REEL = {"root_pivot": (22, 41), "shadow": (22, 13, 0), "root": (-2, 0, 0), "body": (0, 0, -10), "head": (0, 0, -25)}
QUAD_FALLEN = {"root_pivot": (22, 41), "shadow": (22, 15, 0), "root": (0, -9, 178), "root_pivot": (22, 34), "head": (0, 0, 20),
               "leg_bl": (0, 0, 25), "leg_br": (0, 0, -20), "leg_fl": (0, 0, 30), "leg_fr": (0, 0, -25)}
QUAD_HURT = [blend({}, QUAD_REEL, t) for t in (0.7, 1.0, 0.4)]
QUAD_DEATH = keyframes([(0, dict(QUAD_STAND, root_pivot=(22, 34))), (1, dict(QUAD_REEL, root_pivot=(22, 34))), (5, QUAD_FALLEN), (7, QUAD_FALLEN)])
QUAD_ANIMATIONS = [("idle", QUAD_IDLE), ("walk", QUAD_WALK), ("windup", QUAD_WINDUP), ("lunge", QUAD_LUNGE), ("hurt", QUAD_HURT), ("death", QUAD_DEATH)]

# Floating poses: the whole body rides HOVER px above the ground.
HOVER = -9


def _hover(dy=0, dx=0, turn=0, flap=0, sway=0, shadow=9):
    return {"root": (dx, HOVER + dy, turn), "wing_b": (0, 0, flap), "wing_f": (0, 0, -flap), "tail": (0, 0, sway), "shadow": (22, shadow, 0)}


FLOAT_IDLE = [_hover(dy, flap=f) for dy, f in ((0, 0), (-1, -18), (-2, -8), (-1, 14))]
FLOAT_WALK = cycle(8, lambda s: _hover(round(-2 * abs(s)), flap=28 * s, sway=-12 * s, turn=6))
FLOAT_WINDUP = [_hover(-round(6 * t), dx=-round(2 * t) + (i % 2 if i > 2 else 0), turn=-10 * t, flap=-45 * t, sway=15 * t)
                for i, t in enumerate(k / 5 for k in range(6))]
FLOAT_LUNGE = [_hover(round(4 * k) - 4, dx=round(8 * k), turn=22 * k, flap=40 * k, sway=-25 * k) for k in (0.5, 1.0, 1.0, 1.0, 0.6, 0.2)]
FLOAT_HURT = [_hover(dx=-round(3 * t), turn=-14 * t, flap=-25 * t) for t in (0.7, 1.0, 0.4)]
FLOAT_DEATH = keyframes([(0, _hover()), (1, _hover(dx=-2, turn=-14, flap=-30)), (5, _hover(dy=17, turn=80, flap=55, shadow=7)),
                         (7, _hover(dy=18, turn=86, flap=60, shadow=7))])
FLOAT_ANIMATIONS = [("idle", FLOAT_IDLE), ("walk", FLOAT_WALK), ("windup", FLOAT_WINDUP), ("lunge", FLOAT_LUNGE), ("hurt", FLOAT_HURT), ("death", FLOAT_DEATH)]


# Slime poses are all squash and stretch.
def _squash(sx, sy, dx=0, dy=0, shadow=12):
    return {"root": (dx, dy, 0), "body_scale": (sx, sy), "shadow": (22, shadow * sx, 0)}


SLIME_IDLE = [_squash(1.0, 1.0), _squash(1.05, 0.94), _squash(1.08, 0.9), _squash(1.04, 0.96)]
SLIME_WALK = [_squash(1.15, 0.8), _squash(0.9, 1.15, 1, -2), _squash(0.85, 1.2, 2, -6), _squash(0.9, 1.1, 3, -7),
              _squash(0.95, 1.05, 3, -5), _squash(1.0, 1.0, 2, -2), _squash(1.2, 0.78, 1), _squash(1.08, 0.92)]
SLIME_WINDUP = [_squash(1.0 + 0.35 * t, 1.0 - 0.35 * t, (i % 2 if i > 2 else 0)) for i, t in enumerate(k / 5 for k in range(6))]
SLIME_LUNGE = [_squash(1.0 + 0.3 * k, 1.0 - 0.2 * k, round(7 * k), -round(6 * k)) for k in (0.5, 1.0, 1.0, 1.0, 0.6, 0.2)]
SLIME_HURT = [_squash(1.15, 0.8, -1), _squash(1.25, 0.7, -2), _squash(1.1, 0.9, -1)]
SLIME_DEATH = [_squash(1.0 + 0.1 * i, max(1.0 - 0.13 * i, 0.12)) for i in range(8)]
SLIME_ANIMATIONS = [("idle", SLIME_IDLE), ("walk", SLIME_WALK), ("windup", SLIME_WINDUP), ("lunge", SLIME_LUNGE), ("hurt", SLIME_HURT), ("death", SLIME_DEATH)]

# id -> (rig, draw order, animations). Ids match scripts/enemies/enemy_db.gd.
MONSTERS = {
    "bone_archer": (BONE_ARCHER, HUSK_ORDER, HUSK_ANIMATIONS),
    "crag_golem": (CRAG_GOLEM, HUSK_ORDER, HUSK_ANIMATIONS),
    "rot_cultist": (ROT_CULTIST, HUSK_ORDER, HUSK_ANIMATIONS),
    "spore_shambler": (SPORE_SHAMBLER, HUSK_ORDER, HUSK_ANIMATIONS),
    "rot_hound": (ROT_HOUND, QUAD_ORDER, QUAD_ANIMATIONS),
    "thorn_stalker": (THORN_STALKER, QUAD_ORDER, QUAD_ANIMATIONS),
    "ash_wraith": (ASH_WRAITH, FLOAT_ORDER, FLOAT_ANIMATIONS),
    "carrion_bat": (CARRION_BAT, FLOAT_ORDER, FLOAT_ANIMATIONS),
    "ember_wisp": (EMBER_WISP, FLOAT_ORDER, FLOAT_ANIMATIONS),
    "bog_slime": (BOG_SLIME, ["body"], SLIME_ANIMATIONS),
}


# Townsfolk: the human rig in other clothes, standing idle.
#   name -> (palette changes, extra parts per rig group)
NPCS = {
    "merchant": (
        {"tunic": ["5f9a6a", "447a50", "2f5a3a"], "tunic_fold": ["2f5a3a"] * 3, "hair": ["c8c4b8", "9a968c", "6c6960"],
         "trousers": ["6a5a48", "4e4236", "362e26"]},
        {"head": [("guard", R(9, 6, 35, 8)), ("guard", _half_ellipse(22, 7, 9, 7))],
         "torso": [("belt", R(9, 24, 14, 34)), ("guard", R(10, 27, 13, 28))]},
    ),
    "warden": (
        {"tunic": ["8fa0b8", "6a7a94", "4a586e"], "tunic_fold": ["4a586e"] * 3, "hair": ["3a3038", "2a2228", "1c161a"],
         "trousers": ["3a3a4a", "2a2a38", "1e1e28"]},
        {"torso": [("blood", [(14, 25), (30, 25), (33, 38), (11, 38)]), ("tunic", [(15, 25), (29, 25), (30, 35), (14, 35)]),
                   ("guard", R(21, 26, 23, 30))]},
    ),
}


def draw_npc(changes, extras):
    saved = {key: PALETTE[key] for key in changes}
    PALETTE.update(changes)
    try:
        rig = {name: dict(group, parts=group["parts"] + extras.get(name, [])) for name, group in HUMAN.items()}
        return draw_sheet(rig, HUMAN_ORDER, [("idle", HUMAN_IDLE)])
    finally:
        PALETTE.update(saved)


def draw_sheet(rig, order, animations, shadow=True):
    columns = max(len(poses) for _name, poses in animations)
    sheet = Image.new("RGBA", (columns * FRAME, len(animations) * FRAME), (0, 0, 0, 0))
    for row, (_name, poses) in enumerate(animations):
        for column, pose in enumerate(poses):
            sheet.paste(draw_frame(rig, order, pose, shadow), (column * FRAME, row * FRAME))
    return sheet


def draw_layer_sheet(parts_by_group):
    """One piece of equipment alone, moving exactly as the body part it sits on."""
    rig = {name: dict(group, parts=parts_by_group.get(name, [])) for name, group in HUMAN.items()}
    return draw_sheet(rig, [name for name in HUMAN_ORDER if name in parts_by_group], HUMAN_ANIMATIONS, shadow=False)


def weapon_icon_parts(parts):
    """Turns weapon art into icon parts: tilted 45 degrees and fitted to the cell."""
    a = math.radians(45)
    turned = []
    for material, polygon in parts:
        turned.append((material, [((x - 35.5) * math.cos(a) - (y - 32) * math.sin(a),
                                   (x - 35.5) * math.sin(a) + (y - 32) * math.cos(a)) for x, y in polygon]))
    xs = [x for _m, poly in turned for x, _y in poly]
    ys = [y for _m, poly in turned for _x, y in poly]
    scale = min(1.0, (ICON - 4) / max(max(xs) - min(xs), max(ys) - min(ys)))
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    return [(material, "poly", [((x - cx) * scale + ICON / 2, (y - cy) * scale + ICON / 2) for x, y in poly])
            for material, poly in turned]


# ----------------------------------------------------------------- tiles
# Row order must match the Type enum in scripts/world/terrain_tiles.gd, so
# only ever append. Each row: name, style, base, light, dark, accent.
# Water rows are animated: columns 0-3 and 4-7 are the four frames of two
# variants. Every other row has eight look-alike variants.
TILES = [
    ("deep_water", "water", "141b2b", "1f2a40", "0e1320", "33466a"),
    ("shallow_water", "water", "23364a", "35506a", "1a2838", "5a7f9a"),
    ("mud", "mud", "3d342c", "51463a", "2b2420", "62574a"),
    ("ash", "ash", "4b4a4e", "5e5d66", "37363b", "d8d2c0"),
    ("dead_grass", "grass", "4a4d32", "6a6c42", "373a27", "86875a"),
    ("dark_grass", "grass", "26382c", "3a5540", "1a281f", "9c3b3b"),
    ("bog", "bog", "2e3528", "46503a", "1c2219", "7a8a4a"),
    ("mountain", "mountain", "5a5560", "77727e", "3a3640", "8f8a96"),
    ("snow", "snow", "c8d0d8", "e6ecf2", "9aa6b4", "ffffff"),
    ("frostpine", "grass", "3d5a58", "5a7c78", "2a4040", "e6ecf2"),
    ("salt", "cracked", "8c8a84", "a8a69e", "6a6862", "c8c6be"),
    ("thorn", "grass", "4a4030", "665a40", "332b20", "8a2c37"),
    ("crimson", "grass", "4a2830", "6a3a44", "321a20", "c0555a"),
    ("fungal", "spots", "3a2c4a", "523e66", "281e34", "c05a8a"),
    ("tar", "tar", "1c1a1e", "2e2a30", "100e12", "4a4450"),
    ("sand", "sand", "8a7650", "a48e62", "6c5c3e", "c0aa7a"),
    ("cinder", "cinder", "3a2a28", "503a36", "241a1a", "f08a2e"),
    ("voidscar", "void", "1a1428", "2a2040", "0e0a18", "9a6cf0"),
    ("plank", "plank", "6b4f36", "83634a", "4a3626", "523b28"),
    ("wall", "rock", "2a2630", "3e3848", "0c0a10", "4a4458"),
    ("cave_floor", "mud", "34323a", "45434c", "24222a", "55535e"),
    ("peak", "peak", "7c7986", "a4a2ae", "55525e", "eef2f6"),
]
VARIANTS = 8
WATER_FRAMES = 4


def draw_tile(row, variant, frame=0):
    name, style, base, light, dark, accent = TILES[row]
    base, light, dark, accent = rgba(base), rgba(light), rgba(dark), rgba(accent)
    r = random.Random(row * 31 + variant)
    img = Image.new("RGBA", (N, N), base)
    d = ImageDraw.Draw(img)

    def put(x, y, c):
        img.putpixel((int(x) % N, int(y) % N), c)

    def tuft(c_low, c_tip):
        x, y = r.randrange(2, N - 4), r.randrange(5, N - 1)
        for dx, h in ((0, 3), (1, 4), (2, 2)):
            for k in range(h):
                put(x + dx, y - k, c_tip if k == h - 1 else c_low)

    def pebble():
        x, y = r.randrange(2, N - 5), r.randrange(2, N - 4)
        d.rectangle((x, y, x + 2, y + 1), fill=dark)
        put(x, y, light)

    def puddle(rim=None):
        x, y = r.randrange(3, N - 12), r.randrange(3, N - 8)
        w, h = r.randrange(6, 10), r.randrange(3, 5)
        d.ellipse((x, y, x + w, y + h), fill=dark)
        d.line((x + 2, y + 1, x + w - 3, y + 1), fill=rim or light)

    def crack(colour):
        x, y = r.randrange(4, N - 14), r.randrange(4, N - 10)
        d.line((x, y, x + 4, y + 3, x + 6, y + 2, x + 10, y + 6), fill=colour)

    if style == "rock":
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
    if style in ("mountain", "peak"):
        # Broken rock in tilted strata, with scree and, up high, snow.
        for _ in range(110):
            put(r.randrange(N), r.randrange(N), light if r.random() < 0.45 else dark)
        for _ in range(4):
            x, y = r.randrange(0, N - 10), r.randrange(4, N - 4)
            w = r.randrange(8, 16)
            d.line((x, y, x + w, y - 3), fill=dark)
            d.line((x, y + 1, x + w, y - 2), fill=light)
        for _ in range(4):
            x, y = r.randrange(2, N - 5), r.randrange(2, N - 4)
            d.polygon([(x, y + 3), (x + 2, y), (x + 4, y + 3)], fill=light)
            put(x + 2, y + 3, dark)
        if style == "peak" and variant % 3 == 0:
            # Now and then a drift of snow lodged in the rock.
            x, y = r.randrange(4, N - 16), r.randrange(4, N - 8)
            d.polygon([(x, y + 5), (x + 4, y + 1), (x + 12, y), (x + 15, y + 4), (x + 9, y + 6)], fill=accent)
            d.line((x + 2, y + 6, x + 13, y + 6), fill=light)
        return img
    if style == "plank":
        for y in range(0, N, 11):
            d.line((0, y, N, y), fill=dark)
            d.line((0, y + 1, N, y + 1), fill=light)
            seam = r.randrange(6, N - 6)
            d.line((seam, y, seam, y + 10), fill=dark)
            for _ in range(3):
                put(r.randrange(N), y + r.randrange(3, 10), accent)
        return img

    for _ in range(90):
        put(r.randrange(N), r.randrange(N), light if r.random() < 0.5 else dark)

    if style == "water":
        # Wave crests drift sideways a few pixels each frame.
        for _ in range(5):
            x, y, w = r.randrange(0, N), r.randrange(3, N - 3), r.randrange(4, 9)
            x += frame * 3 + (2 if frame % 2 else 0)
            for k in range(w):
                put(x + k, y + (1 if (k + frame) % 5 == 0 else 0), accent)
                put(x + k + 2, y + 1, dark)
    elif style == "mud":
        for _ in range(3):
            pebble()
        puddle()
    elif style == "ash":
        for _ in range(3):
            pebble()
        crack(dark)
        if variant == 7:
            x, y = r.randrange(6, N - 12), r.randrange(6, N - 8)
            d.line((x, y, x + 5, y + 2), fill=accent)
    elif style == "grass":
        for _ in range(9):
            tuft(dark, light)
        if variant >= 6:
            x, y = r.randrange(6, N - 8), r.randrange(8, N - 6)
            d.rectangle((x, y, x + 2, y + 1), fill=accent)
            put(x + 1, y + 2, light)
    elif style == "bog":
        puddle()
        puddle()
        for _ in range(3):
            x, y = r.randrange(3, N - 3), r.randrange(8, N - 2)
            d.line((x, y, x, y - 5), fill=dark)
            put(x, y - 6, accent)
    elif style == "snow":
        for _ in range(5):
            x, y = r.randrange(2, N - 8), r.randrange(3, N - 4)
            d.line((x, y, x + r.randrange(3, 7), y), fill=accent)
            d.line((x + 1, y + 1, x + 5, y + 1), fill=dark)
        if variant >= 6:
            pebble()
    elif style == "cracked":
        for _ in range(4):
            crack(dark)
        for _ in range(8):
            put(r.randrange(N), r.randrange(N), accent)
    elif style == "spots":
        for _ in range(5):
            x, y, w = r.randrange(2, N - 8), r.randrange(2, N - 6), r.randrange(3, 6)
            d.ellipse((x, y, x + w, y + w - 1), fill=dark)
        for _ in range(3):
            x, y = r.randrange(4, N - 6), r.randrange(6, N - 4)
            d.rectangle((x, y, x + 3, y + 1), fill=accent)
            d.rectangle((x + 1, y + 2, x + 2, y + 3), fill=light)
    elif style == "tar":
        for _ in range(3):
            puddle(accent)
        for _ in range(4):
            x, y = r.randrange(3, N - 4), r.randrange(3, N - 4)
            d.ellipse((x, y, x + 2, y + 2), outline=accent)
    elif style == "sand":
        for _ in range(5):
            x, y, w = r.randrange(0, N - 12), r.randrange(4, N - 3), r.randrange(8, 16)
            d.line((x, y, x + w // 2, y - 1, x + w, y), fill=dark)
            d.line((x + 1, y + 1, x + w - 1, y + 1), fill=light)
        if variant >= 6:
            d.line((r.randrange(8, 30), r.randrange(8, 30)) * 2, fill=accent)
            pebble()
    elif style == "cinder":
        for _ in range(3):
            crack(dark)
        x, y = r.randrange(4, N - 14), r.randrange(4, N - 10)
        d.line((x, y, x + 3, y + 3, x + 7, y + 2), fill=accent)
        for _ in range(3):
            pebble()
    elif style == "void":
        for _ in range(7):
            put(r.randrange(N), r.randrange(N), accent)
        crack(light)
        x, y = r.randrange(6, N - 8), r.randrange(6, N - 8)
        d.line((x - 2, y, x + 2, y), fill=accent)
        d.line((x, y - 2, x, y + 2), fill=accent)
    return img


def draw_fringes():
    """Ragged borders: each terrain's texture cut to a rough strip along the
    top edge (column 0) and a rough corner at the top right (column 1). The
    game rotates these to blend one terrain over its neighbour."""
    sheet = Image.new("RGBA", (3 * N, len(TILES) * N), (0, 0, 0, 0))
    for row in range(len(TILES)):
        tile = draw_tile(row, 0)
        edge_colour = tuple(int(c * 0.62) for c in rgba(TILES[row][2])[:3]) + (255,)
        r = random.Random(row * 7 + 3)
        depth, depths = 9, []
        for x in range(N):
            depth = max(4, min(14, depth + r.choice((-2, -1, -1, 0, 0, 1, 1, 2))))
            depths.append(depth)
        # Ease the ends so strips meet neighbours of any depth without a step.
        for x in range(6):
            depths[x] = min(depths[x], 5 + x)
            depths[N - 1 - x] = min(depths[N - 1 - x], 5 + x)
        for x in range(N):
            for y in range(depths[x]):
                sheet.putpixel((x, row * N + y), tile.getpixel((x, y)) if y < depths[x] - 1 else edge_colour)
        for y in range(N):
            for x in range(N):
                reach = 9 + r.choice((-1, 0, 0, 1))
                dist = math.hypot(N - 1 - x, y)
                if dist < reach:
                    sheet.putpixel((N + x, row * N + y), tile.getpixel((x, y)) if dist < reach - 1.2 else edge_colour)
        # Column 2: the cliff face a high terrain shows on the tile below it.
        if TILES[row][1] in ("mountain", "peak"):
            face = [rgba(c) for c in ("4a4650", "3a3640", "2c2932", "201e25")]
            for x in range(N):
                height = 14 + int(3 * math.sin(x * 0.7 + row)) + r.choice((0, 0, 1))
                for y in range(height):
                    shade = face[min(3, y * 4 // height)]
                    if (x + y // 3) % 7 == 0:
                        shade = face[3]
                    sheet.putpixel((2 * N + x, row * N + y), shade)
                for y in range(height, height + 6):
                    sheet.putpixel((2 * N + x, row * N + y), (0, 0, 0, 90 - (y - height) * 14))
    return sheet


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
# Icons 18-25: the newer weapons, drawn from their in-hand art.
ICONS += [(name, None) for name in ["flame_sword", "frost_sword", "dark_sword", "katana", "executioner", "reaver", "fang", "halberd"]]
# Icons 26-31: ability shapes.
ICONS += [
    ("ability_slash", [("metal", "poly", [(4, 18), (8, 7), (18, 3), (12, 9), (9, 19)])]),
    ("ability_spin", [("metal", "ring", (4, 5, 17, 18), 2), ("metal", "poly", [(13, 2), (20, 6), (14, 10)])]),
    ("ability_slam", [("gold", "poly", [(11, 2), (13, 8), (20, 6), (15, 11), (20, 17), (13, 14), (11, 20), (9, 14), (2, 17), (7, 11), (2, 6), (9, 8)])]),
    ("ability_dash", [("green", "poly", [(2, 9), (12, 9), (12, 5), (20, 11), (12, 17), (12, 13), (2, 13)])]),
    ("ability_thrust", [("metal", "line", (3, 18, 16, 5), 2), ("metal", "poly", [(13, 3), (19, 3), (19, 9)])]),
    ("ability_flurry", [("metal", "line", (4, 8, 12, 3), 2), ("metal", "line", (5, 15, 16, 6), 2), ("metal", "line", (9, 19, 19, 11), 2)]),
]
# Icons 32-34: ranged weapons, from their in-hand art.
ICONS += [(name, None) for name in ["bow", "staff", "ember_staff"]]
# Icons 35-41: interface symbols.
ICONS += [
    ("heart", [("red", "ellipse", (3, 4, 11, 12)), ("red", "ellipse", (10, 4, 18, 12)), ("red", "poly", [(3, 9), (18, 9), (10.5, 19)])]),
    ("drop", [("frost", "ellipse", (5, 9, 16, 19)), ("frost", "poly", [(6, 12), (10.5, 2), (15, 12)])]),
    ("bolt", [("gold", "poly", [(12, 2), (5, 12), (10, 12), (8, 20), (16, 9), (11, 9)])]),
    ("fist", [("red", "ellipse", (4, 5, 17, 15)), ("red", "rect", (7, 13, 14, 19)), ("blood", "line", (8, 6, 8, 11), 1), ("blood", "line", (12, 6, 12, 11), 1)]),
    ("wing", [("green", "poly", [(3, 16), (8, 4), (19, 3), (15, 8), (18, 9), (13, 12), (15, 14), (9, 15), (6, 19)])]),
    ("clover", [("green", "ellipse", (4, 3, 11, 10)), ("green", "ellipse", (10, 3, 17, 10)), ("green", "ellipse", (4, 9, 11, 16)),
                ("green", "ellipse", (10, 9, 17, 16)), ("wood", "line", (11, 14, 14, 20), 2)]),
    ("book", [("purple", "rect", (4, 4, 17, 18)), ("bone", "rect", (6, 6, 15, 16)), ("purple", "rect", (10, 4, 11, 18))]),
]
# Icons 42-52: materials, consumables, and tools. The pale ones are tinted
# in game with each item's own colour.
ICONS += [
    ("ore", [("plate", "poly", [(3, 13), (6, 6), (12, 3), (18, 7), (19, 14), (14, 19), (6, 18)]), ("plate_dark", "rect", (8, 9, 10, 11)), ("plate_dark", "rect", (13, 12, 15, 14))]),
    ("log", [("plate", "poly", [(3, 8), (16, 4), (19, 10), (6, 15)]), ("plate_dark", "ellipse", (2, 8, 8, 15)), ("plate", "ellipse", (4, 10, 6, 13))]),
    ("herb", [("plate", "poly", [(10, 20), (10, 11), (4, 6), (5, 3), (11, 8), (11, 2), (13, 2), (13, 8), (18, 4), (19, 7), (13, 12), (13, 20)])]),
    ("fish", [("plate", "ellipse", (3, 6, 16, 16)), ("plate", "poly", [(14, 11), (20, 5), (20, 17)]), ("dark", "rect", (6, 9, 7, 10))]),
    ("ingot", [("plate", "poly", [(5, 8), (17, 8), (20, 16), (2, 16)]), ("plate", "poly", [(5, 8), (17, 8), (16, 6), (6, 6)])]),
    ("potion", [("plate", "ellipse", (4, 8, 17, 20)), ("bone", "rect", (9, 3, 12, 9)), ("wood", "rect", (8, 2, 13, 4))]),
    ("food", [("wood", "poly", [(2, 11), (20, 11), (17, 19), (5, 19)]), ("plate", "ellipse", (4, 7, 18, 13))]),
    ("pickaxe", [("wood", "line", (5, 19, 15, 7), 2), ("plate", "poly", [(8, 4), (14, 3), (20, 8), (19, 14), (16, 8), (11, 6)])]),
    ("hatchet", [("wood", "line", (5, 19, 15, 6), 2), ("plate", "poly", [(11, 3), (19, 4), (19, 12), (14, 9)])]),
    ("rod", [("wood", "line", (3, 19, 17, 3), 2), ("bone", "line", (17, 3, 18, 14), 1), ("red", "ellipse", (17, 13, 20, 16))]),
    ("dust", [("purple", "ellipse", (4, 11, 17, 19)), ("bone", "rect", (7, 8, 8, 9)), ("bone", "rect", (13, 6, 14, 7)), ("bone", "rect", (10, 3, 11, 4))]),
    # Icon 53.
    ("scroll", [("bone", "rect", (5, 4, 16, 18)), ("wood", "rect", (4, 3, 17, 5)), ("wood", "rect", (4, 17, 17, 19)),
                ("dark", "rect", (7, 8, 14, 8)), ("dark", "rect", (7, 11, 14, 11)), ("dark", "rect", (7, 14, 12, 14))]),
]

# Icons 54-57: things the player builds and places.
ICONS += [
    ("table", [("wood", "rect", (3, 8, 18, 11)), ("wood", "rect", (4, 11, 6, 19)), ("wood", "rect", (15, 11, 17, 19)), ("plate", "rect", (6, 4, 11, 8))]),
    ("chest", [("wood", "rect", (3, 9, 18, 18)), ("wood", "poly", [(3, 9), (5, 5), (16, 5), (18, 9)]), ("gold", "rect", (3, 11, 18, 12)), ("gold", "rect", (9, 10, 12, 14))]),
    ("house", [("wood", "rect", (4, 10, 17, 19)), ("red", "poly", [(2, 11), (10.5, 3), (19, 11)]), ("dark", "rect", (9, 14, 12, 19))]),
    ("bed", [("wood", "rect", (3, 8, 18, 18)), ("red", "rect", (4, 11, 17, 17)), ("bone", "rect", (5, 9, 10, 11))]),
]

# Things to gather in the world: 64px frames in one row. Pale parts are
# tinted in game. Order: rock, ore flecks, tree, herb, fishing ripple.
NODE = 64
NODE_PALETTE = {
    "rock": ["8a8794", "66636f", "45434d"],
    "fleck": ["ffffff", "e6e6e6", "c8c8c8"],
    "trunk": ["6b4f36", "523b28", "3b2a1c"],
    "canopy": ["e8e8e8", "bdbdbd", "8f8f8f"],
    "leaf": ["f0f0f0", "c4c4c4", "9a9a9a"],
}
NODES = [
    [("rock", "poly", [(12, 50), (10, 36), (18, 24), (30, 18), (44, 22), (54, 34), (54, 50), (40, 56), (22, 56)]),
     ("rock", "poly", [(18, 26), (30, 20), (38, 26), (30, 34), (20, 34)])],
    [("fleck", "rect", (20, 38, 24, 41)), ("fleck", "rect", (32, 28, 36, 31)), ("fleck", "rect", (42, 40, 46, 43)),
     ("fleck", "rect", (28, 46, 31, 48)), ("fleck", "rect", (44, 30, 46, 32))],
    [("trunk", "rect", (28, 36, 35, 58)), ("canopy", "ellipse", (10, 6, 54, 42)), ("canopy", "ellipse", (6, 18, 30, 44)),
     ("canopy", "ellipse", (34, 18, 58, 44))],
    [("leaf", "poly", [(31, 56), (31, 40), (20, 30), (22, 26), (32, 34), (32, 22), (36, 22), (36, 34), (44, 26), (46, 30), (35, 42), (35, 56)]),
     ("leaf", "ellipse", (29, 16, 39, 26))],
    [("fleck", "ring", (14, 26, 50, 44), 2), ("fleck", "ring", (24, 31, 40, 39), 1)],
]


# Structures and furniture: 64px frames in one row of assets/sprites/props.png.
# The order is the frame number used in scripts/world/prop.gd - only append.
PROP_PALETTE = {
    "pstone": ["a6a2b0", "7c7888", "56525e"],
    "pdark": ["3a3642", "26232c", "14121a"],
    "pwood": ["8a6a48", "6b4f36", "4a3626"],
    "pgold": ["f0cf6a", "c09a3c", "866a26"],
    "pfire": ["ffd86b", "f08a2e", "b8401e"],
    "pvoid": ["c9a0f0", "8e5cc8", "5c3690"],
    "pcloth": ["b3434a", "8a2c37", "5c1c28"],
    "pbone": ["f2efe2", "cfcbb8", "9b9889"],
    "pblack": ["0b0a12"] * 3,
}
PROPS = [
    # 0 pillar
    [("pstone", "rect", (24, 14, 40, 54)), ("pstone", "rect", (20, 8, 44, 15)), ("pstone", "rect", (20, 52, 44, 59)), ("pdark", "rect", (30, 16, 31, 51))],
    # 1 broken wall
    [("pstone", "poly", [(10, 58), (10, 34), (18, 30), (22, 38), (30, 26), (38, 32), (44, 24), (54, 36), (54, 58)]),
     ("pdark", "rect", (12, 44, 52, 45)), ("pdark", "rect", (30, 34, 31, 57))],
    # 2 chest, closed
    [("pwood", "rect", (14, 30, 50, 54)), ("pwood", "poly", [(14, 30), (18, 22), (46, 22), (50, 30)]), ("pgold", "rect", (14, 36, 50, 38)),
     ("pgold", "rect", (29, 33, 35, 42)), ("pdark", "rect", (31, 36, 33, 39))],
    # 3 chest, open
    [("pdark", "rect", (16, 26, 48, 36)), ("pwood", "poly", [(14, 26), (18, 12), (46, 12), (50, 26)]), ("pwood", "rect", (14, 34, 50, 54)),
     ("pgold", "rect", (14, 34, 50, 36)), ("pgold", "ellipse", (22, 28, 30, 34)), ("pgold", "ellipse", (33, 27, 42, 34))],
    # 4 altar with a flame: a place to rest
    [("pstone", "poly", [(16, 58), (20, 44), (44, 44), (48, 58)]), ("pstone", "rect", (22, 36, 42, 45)), ("pdark", "rect", (24, 34, 40, 37)),
     ("pfire", "poly", [(26, 35), (28, 24), (31, 30), (33, 16), (36, 28), (38, 22), (39, 35)])],
    # 5 cave mouth
    [("pstone", "poly", [(6, 58), (8, 34), (18, 20), (34, 14), (48, 20), (58, 36), (58, 58)]),
     ("pblack", "poly", [(18, 58), (19, 40), (26, 30), (36, 28), (44, 34), (46, 58)])],
    # 6 void portal
    [("pvoid", "ring", (14, 8, 50, 58), 5), ("pblack", "ellipse", (19, 13, 45, 53)), ("pvoid", "ellipse", (29, 28, 35, 38)),
     ("pvoid", "rect", (24, 20, 25, 21)), ("pvoid", "rect", (38, 42, 39, 43)), ("pvoid", "rect", (39, 24, 40, 25))],
    # 7 ladder up and out
    [("pwood", "rect", (22, 8, 25, 58)), ("pwood", "rect", (39, 8, 42, 58)), ("pwood", "rect", (22, 16, 42, 18)), ("pwood", "rect", (22, 28, 42, 30)),
     ("pwood", "rect", (22, 40, 42, 42)), ("pwood", "rect", (22, 52, 42, 54))],
    # 8 crafting table
    [("pwood", "rect", (12, 30, 52, 38)), ("pwood", "rect", (14, 38, 18, 56)), ("pwood", "rect", (46, 38, 50, 56)), ("pstone", "rect", (18, 24, 28, 30)),
     ("pstone", "line", (34, 28, 46, 20), 2), ("pwood", "line", (40, 30, 48, 24), 2)],
    # 9 bed
    [("pwood", "rect", (12, 26, 52, 54)), ("pcloth", "rect", (14, 34, 50, 52)), ("pbone", "rect", (16, 28, 34, 35)), ("pwood", "rect", (12, 22, 52, 27))],
    # 10 doorway (the way out of a house)
    [("pwood", "rect", (18, 12, 46, 58)), ("pdark", "rect", (22, 16, 42, 58)), ("pgold", "rect", (38, 36, 40, 38))],
    # 11 campfire
    [("pwood", "line", (16, 52, 46, 44), 4), ("pwood", "line", (18, 44, 48, 52), 4),
     ("pfire", "poly", [(22, 46), (25, 32), (29, 40), (32, 22), (36, 38), (40, 30), (43, 46)])],
    # 12 skull totem marking a lair
    [("pwood", "rect", (30, 26, 34, 58)), ("pbone", "ellipse", (22, 8, 42, 28)), ("pblack", "ellipse", (25, 14, 30, 20)), ("pblack", "ellipse", (34, 14, 39, 20)),
     ("pbone", "rect", (27, 26, 37, 30))],
    # 13 house, seen from outside (uses most of the frame)
    [("pwood", "rect", (6, 30, 58, 60)), ("pcloth", "poly", [(2, 32), (32, 6), (62, 32)]), ("pdark", "rect", (27, 42, 37, 60)),
     ("pgold", "rect", (34, 50, 35, 51)), ("pdark", "rect", (11, 38, 20, 46)), ("pdark", "rect", (44, 38, 53, 46)), ("pwood", "rect", (6, 30, 58, 32))],
]


def draw_icon(parts, size=None):
    global ICON
    saved = ICON
    if size:
        ICON = size
    try:
        return _draw_icon(parts)
    finally:
        ICON = saved


def _draw_icon(parts):
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
            shades = ICON_PALETTE.get(material) or PALETTE[material]
            pixels[(x, y)] = shades[0 if t < 0.3 else 1 if t < 0.68 else 2]
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
    for name, (changes, extras) in NPCS.items():
        draw_npc(changes, extras).save(os.path.join(ROOT, "sprites", "npc_%s.png" % name))
    os.makedirs(os.path.join(ROOT, "sprites", "enemies"), exist_ok=True)
    for name, (rig, order, animations) in MONSTERS.items():
        draw_sheet(rig, order, animations).save(os.path.join(ROOT, "sprites", "enemies", name + ".png"))
    os.makedirs(os.path.join(ROOT, "sprites", "weapons"), exist_ok=True)
    for name, parts in WEAPONS.items():
        draw_layer_sheet({"sword": parts}).save(os.path.join(ROOT, "sprites", "weapons", name + ".png"))
    os.makedirs(os.path.join(ROOT, "sprites", "layers"), exist_ok=True)
    for name, parts_by_group in LAYERS.items():
        draw_layer_sheet(parts_by_group).save(os.path.join(ROOT, "sprites", "layers", name + ".png"))
    atlas = Image.new("RGBA", (VARIANTS * N, len(TILES) * N))
    for row in range(len(TILES)):
        for column in range(VARIANTS):
            if TILES[row][1] == "water":
                tile = draw_tile(row, column // WATER_FRAMES, column % WATER_FRAMES)
            else:
                tile = draw_tile(row, column)
            atlas.paste(tile, (column * N, row * N))
    atlas.save(os.path.join(ROOT, "tiles", "terrain.png"))
    draw_fringes().save(os.path.join(ROOT, "tiles", "fringes.png"))

    os.makedirs(os.path.join(ROOT, "icons"), exist_ok=True)
    rows = (len(ICONS) + ICON_COLUMNS - 1) // ICON_COLUMNS
    icons = Image.new("RGBA", (ICON_COLUMNS * ICON, rows * ICON), (0, 0, 0, 0))
    for index, (_name, parts) in enumerate(ICONS):
        if parts is None:
            parts = weapon_icon_parts(WEAPONS[_name])
        icons.paste(draw_icon(parts), (index % ICON_COLUMNS * ICON, index // ICON_COLUMNS * ICON))
    icons.save(os.path.join(ROOT, "icons", "items.png"))

    ICON_PALETTE.update(NODE_PALETTE)
    nodes = Image.new("RGBA", (len(NODES) * NODE, NODE), (0, 0, 0, 0))
    for index, parts in enumerate(NODES):
        nodes.paste(draw_icon(parts, NODE), (index * NODE, 0))
    nodes.save(os.path.join(ROOT, "sprites", "nodes.png"))

    ICON_PALETTE.update(PROP_PALETTE)
    props = Image.new("RGBA", (len(PROPS) * NODE, NODE), (0, 0, 0, 0))
    for index, parts in enumerate(PROPS):
        props.paste(draw_icon(parts, NODE), (index * NODE, 0))
    props.save(os.path.join(ROOT, "sprites", "props.png"))


if __name__ == "__main__":
    main()
