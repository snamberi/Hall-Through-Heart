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
        x, y = point[0] - px, point[1] - py
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
        default = a.get(key, b.get(key)) if key.endswith("_pivot") or key == "shadow" else (0, 0, 0)
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
    os.makedirs(os.path.join(ROOT, "sprites", "weapons"), exist_ok=True)
    for name, parts in WEAPONS.items():
        draw_layer_sheet({"sword": parts}).save(os.path.join(ROOT, "sprites", "weapons", name + ".png"))
    os.makedirs(os.path.join(ROOT, "sprites", "layers"), exist_ok=True)
    for name, parts_by_group in LAYERS.items():
        draw_layer_sheet(parts_by_group).save(os.path.join(ROOT, "sprites", "layers", name + ".png"))
    atlas = Image.new("RGBA", (VARIANTS * N, len(TILES) * N))
    for row in range(len(TILES)):
        for variant in range(VARIANTS):
            atlas.paste(draw_tile(row, variant), (variant * N, row * N))
    atlas.save(os.path.join(ROOT, "tiles", "terrain.png"))

    os.makedirs(os.path.join(ROOT, "icons"), exist_ok=True)
    rows = (len(ICONS) + ICON_COLUMNS - 1) // ICON_COLUMNS
    icons = Image.new("RGBA", (ICON_COLUMNS * ICON, rows * ICON), (0, 0, 0, 0))
    for index, (_name, parts) in enumerate(ICONS):
        if parts is None:
            parts = weapon_icon_parts(WEAPONS[_name])
        icons.paste(draw_icon(parts), (index % ICON_COLUMNS * ICON, index // ICON_COLUMNS * ICON))
    icons.save(os.path.join(ROOT, "icons", "items.png"))


if __name__ == "__main__":
    main()
