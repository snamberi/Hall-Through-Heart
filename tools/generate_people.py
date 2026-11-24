"""People, drawn pixel by pixel.

The player, villagers and every look and piece of armour worn over them are
hand-placed pixel maps: a head, a torso, arms in a handful of drawn poses,
and legs built row by row. A frame is made only by moving those maps by
whole pixels and, for rolls and falls, turning the whole figure by exact
quarter turns, so no pixel is ever resampled, rotated off the grid or
scaled. Every layer sheet is made from the same frame plan as the body, so
hair, hats and armour sit on the same pixels in every frame.

Heights and builds are real pixel differences too: longer or shorter legs,
a narrower or broader body. The body has one sheet per height and build;
the game shifts the other layers by whole pixels to match (see
scripts/player/body_frames.gd, which this script writes).

Run from the repository root:  python3 tools/generate_people.py
(tools/generate_art.py calls it as part of the full rebuild.)
"""
import json
import os

from PIL import Image, ImageDraw

import generate_art as GA

ROOT = GA.ROOT
FRAME = GA.FRAME
OX, OY = GA.FRAME_OFFSET
GROUND = 41
OUTLINE = GA.OUTLINE

# --------------------------------------------------------------- colours
# Body colours are the palette-swap keys the game recolours (Appearance.SOURCE).
BODY = {
    "o": OUTLINE,
    "S": "e8c4a0", "s": "c99c7c", "k": "9c7460", "h": "b98a6c",
    "T": "b9ad92", "t": "968a72", "u": "6e6454", "f": "7d7260",
    "P": "4c4a5e", "p": "383648", "q": "272633",
    "B": "4a3b33", "b": "382b26", "n": "261c1a", "c": "6a554a",
    "L": "5a4032", "l": "46312a", "G": "b89a52", "g": "8e7338",
    "e": "0b0a12", "w": "f4f4f0",
}
# Layers drawn in pale greys are tinted in the game (hair colour, skin, dye,
# metal); named materials keep their own colours.
GREY = {"M": "f4f6f8", "m": "c2c9d0", "d": "8c96a0", "D": "6c7682", "x": "4e5762", "o": OUTLINE}


def mat(name, shade=0):
    return GA.PALETTE[name][shade]


# Extra single letters for coloured details in layer maps.
ACCENT = {
    "y": mat("guard", 0), "Y": mat("guard", 1), "j": mat("guard", 2),          # gold
    "r": mat("ruby", 0), "R": mat("ruby", 1),                                   # ruby
    "a": mat("sapphire", 0), "A": mat("sapphire", 1),                           # sapphire
    "v": mat("bone", 0), "V": mat("bone", 1), "z": mat("bone", 2),              # bone / horn
    "i": mat("tooth", 0),
    "g": mat("leaf_dark", 0), "G": mat("leaf_dark", 1),                         # leaf
    "w": "ffffff", "e": mat("void", 0),
    "c": mat("crystal", 0), "C": mat("crystal", 1), "K": mat("crystal", 2),
    "f": mat("fire", 0), "F": mat("fire", 1),
    "b": mat("blood", 0), "B": mat("blood", 1),
    "p": mat("gill", 0), "P": mat("gill", 1),
    "u": mat("glow_cyan", 0), "U": mat("glow_purple", 0),
    "l": mat("leather_v", 0), "L": mat("leather_v", 1), "n": mat("leather_d", 1), "N": mat("leather_b", 1),
    "s": mat("stitch", 0),
    "h": mat("fur_m", 0), "H": mat("fur_m", 1), "k": mat("fur_m", 2),
    "t": "e8d27a", "T": "c8a850", "q": "9a7a34",                               # straw
    "z": mat("bone", 2),
    "1": mat("hplate", 0) if "hplate" in GA.PALETTE else "c83040",
    "2": mat("hplate", 1) if "hplate" in GA.PALETTE else "a02030",
    "3": mat("hplate", 2) if "hplate" in GA.PALETTE else "701824",
    "4": mat("htrim", 0) if "htrim" in GA.PALETTE else "ffd060",
    "5": mat("heart", 0) if "heart" in GA.PALETTE else "ff4060",
    "6": mat("heart_glow", 0) if "heart_glow" in GA.PALETTE else "ffb0c0",
    "7": mat("moss", 0), "8": mat("moss", 1),
    "9": mat("feather", 0), "0": mat("feather", 1),
    "#": mat("dark", 0), "$": mat("dark", 1),
    "%": mat("petal", 0) if "petal" in GA.PALETTE else "f080a0",
    "&": mat("petal_y", 0) if "petal_y" in GA.PALETTE else "f8d860",
    "*": mat("petal_w", 0) if "petal_w" in GA.PALETTE else "fff8f0",
    "!": mat("wound", 0),
    "+": mat("shine", 0),
    "~": "b98a6c",                                                              # skin shade
    "^": mat("dark", 2),
}


def grid(rows, x0, y0, legend):
    """A pixel map: each character of each row is one pixel at (x0+col,
    y0+row) in the 44-pixel box, coloured from `legend`; '.' is empty."""
    out = {}
    for row, line in enumerate(rows):
        for col, ch in enumerate(line):
            if ch == "." or ch == " ":
                continue
            out[(x0 + col, y0 + row)] = legend[ch]
    return out


def layer_grid(rows, x0, y0):
    legend = dict(ACCENT)
    legend.update(GREY)
    return grid(rows, x0, y0, legend)


def mirror(pixels, axis=43):
    """The same pixels reflected about the box's middle (x -> 43 - x)."""
    return {(axis - x, y): c for (x, y), c in pixels.items()}


def merged(*maps):
    out = {}
    for m in maps:
        out.update(m)
    return out


# --------------------------------------------------------------- the body
# Box columns 14..29 hold the head; the body is centred on x 21.5.
SKULL = [
    "....oooooooo....",
    "..ooSSSSSSSSoo..",
    ".oSSSSSSSSSSSso.",
    "oSSSSSSSSSSSSsso",
    "oSSSSSSSSSSSSsso",
    "oSSSSSSSSSSSSsso",
    "oSSSSSSSSSSSSsso",
    "oSSSSeSSSSeSSsso",
    "oSSSSeSSSSeSSsso",
    "oSSSSSSSSSSSssso",
    ".oSSSSSSSSSssso.",
    "..oosSSSSsssoo..",
    "....oooooooo....",
]
# Eyes: columns 19 and 24, rows 19 and 20 (the eye layer colours the lower).
EYES = [(19, 20), (24, 20)]
# From behind: the same round head, no face.
SKULL_BACK = [row.replace("e", "S") for row in SKULL]
# In profile, facing right: one eye near the front, the nose past the
# outline, an ear in the middle of the side of the head.
SKULL_SIDE = [
    "....oooooooo.....",
    "..ooSSSSSSSSoo...",
    ".oSSSSSSSSSSSso..",
    "oSSSSSSSSSSSSsso.",
    "oSSSSSSSSSSSSsso.",
    "oSSSSShSSSSSSsso.",
    "oSSSShSSSSSSSsso.",
    "oSSSShSSSSSSeSso.",
    "oSSSShSSSSSSeSSSo",
    "oSSSSShSSSSSsssoo",
    ".oSSSSSSSSSssso..",
    "..oosSSSSsssoo...",
    "....oooooooo.....",
]
# The eye's place in profile.
EYE_SIDE_SHIFT = 2
# Three-quarter front (walking down and to the right): the face turned a
# pixel toward the near side, the far eye closer to the edge, a cheek shade.
SKULL_FQ = ["oSSSSSSeSSSeSsso" if "e" in row else row for row in SKULL]
SKULL_FQ[9] = SKULL_FQ[9][:12] + "h" + SKULL_FQ[9][13:]


def fq_shift(x):
    """Where a face pixel moves in three-quarter front: the far half two
    pixels toward the near side, the near half one."""
    return x + (2 if x < HEAD_X + 8 else 1)


def _turned_details(rows):
    """A front torso turned a little: its collar folds and buckle (f, G, g)
    moved a pixel toward the near side, cloth or belt filling behind them."""
    out = []
    for row in rows:
        cells = list(row)
        for i in range(len(cells) - 2, 0, -1):
            if cells[i] in "fGg" and cells[i + 1] not in "o.":
                cells[i + 1] = cells[i]
                cells[i] = "L" if cells[i] in "Gg" else "T"
        out.append("".join(cells))
    return out
# Three-quarter back (walking up and to the right): the back of the head,
# an ear and a sliver of cheek on the near side.
SKULL_BQ = [row[:13] + "h" + row[14:] if i in (7, 8) else row for i, row in enumerate(SKULL_BACK)]
# The views drawn facing right that the game mirrors for the left.
QUARTER_VIEWS = ("fq", "bq")
HEAD_X, HEAD_Y = 14, 12

# The torso by build: slight, average, broad. Belt with a buckle, a skirt
# with folds and a dark hem.
TORSOS = [
    [
        ".oooooooo.",
        "oTTffffTto",
        "oTTTffTtto",
        "oTTTTTTfto",
        "oTTTTTTfto",
        "oLLLGgLllo",
        "oTfTTTLlto",
        "ouuuuuLluo",
        "oooooooooo",
    ],
    [
        ".oooooooooo.",
        "oTTTffffTtto",
        "oTTTTffTTtto",
        "oTTTTTTTftto",
        "oTTTTTTTftto",
        "oLLLLGgLLllo",
        "oTTfTTTTLlto",
        "ouuuuuuuLluo",
        "oooooooooooo",
    ],
    [
        ".oooooooooooo.",
        "oTTTTffffTTtto",
        "oTTTTTffTTTtto",
        "oTTTTTTTTTftto",
        "oTTTTTTTTTftto",
        "oLLLLLGgLLLllo",
        "oTTTfTTTTTLlto",
        "ouuuuuuuuuLluo",
        "oooooooooooooo",
    ],
]
# Left edge of the torso by build, and how far each arm moves out.
TORSO_X = [17, 16, 15]
# From behind: the belt runs round without its buckle, no collar folds.
TORSOS_BACK = [[row.replace("G", "L").replace("g", "l").replace("f", "T") for row in torso] for torso in TORSOS]
# In profile the torso is narrower: its back three columns and its front
# (two to four, by build) are kept, the middle taken out (whole columns,
# nothing resampled), and it stands centred over the legs.
SIDE_KEEP_FRONT = [4, 5, 6]
SIDE_TORSO_X = 18
# Shoulder joints in profile: the far arm behind the body, the near one over it.
JOINT_L_SIDE = (21, 24)
JOINT_R_SIDE = (23, 24)


def side_columns(pixels, build):
    """A torso piece (body or worn) narrowed to its profile: the back three
    columns and the front ones, closed up, from the build's own torso box."""
    x0 = TORSO_X[build]
    width = len(TORSOS[build][0])
    keep_front = SIDE_KEEP_FRONT[build]
    out = {}
    for (x, y), c in pixels.items():
        col = x - x0
        if col < 3:
            out[(SIDE_TORSO_X + col, y)] = c
        elif col >= width:
            out[(SIDE_TORSO_X + 3 + keep_front + col - width, y)] = c
        elif col >= width - keep_front:
            out[(SIDE_TORSO_X + 3 + col - (width - keep_front), y)] = c
    return out
ARM_OUT = [-1, 0, 1]
TORSO_Y = 24

# Arms: a few drawn poses. Each is (rows, anchor col, anchor row, hand col,
# hand row): the anchor pixel sits on the shoulder joint, and the hand point
# is where a held weapon's grip goes.
ARMS = {
    "down": ([
        ".oo.",
        "oTto",
        "oTto",
        "oTto",
        "ouuo",
        "oSso",
        "oSso",
        ".oo.",
    ], 1, 0, 2, 6),
    "fwd": ([
        ".oooooo.",
        "oTTTuSSo",
        "ottuusso",
        ".oooooo.",
    ], 0, 1, 6, 2),
    "up": ([
        ".oo.",
        "oSso",
        "oSso",
        "ouuo",
        "oTto",
        "oTto",
        "oTto",
        ".oo.",
    ], 1, 7, 2, 2),
    "fwd_down": ([
        ".oo....",
        "oTTo...",
        "otTTo..",
        ".ottuo.",
        "..ouSSo",
        "...oSso",
        "....oo.",
    ], 1, 1, 5, 5),
    "fwd_up": ([
        "....oo.",
        "...oSSo",
        "..ouSso",
        ".oTTuo.",
        "oTTto..",
        "oTto...",
        ".oo....",
    ], 1, 5, 5, 2),
    "out": ([
        ".oooooo.",
        "oSSuTTTo",
        "ossuttto",
        ".oooooo.",
    ], 7, 1, 2, 2),
}
# Shoulder joints at average build.
JOINT_L = (14, 24)
JOINT_R = (28, 24)
# Raised arms stand clear of the head.
UP_SHIFT = {"up": 1, "fwd_up": 0}

# Legs are built row by row: a trouser column, then a boot a pixel wider on
# the outside. HEIGHT_ROWS is how many trouser rows each height has.
HEIGHT_ROWS = [2, 3, 4, 5, 6]
BASE_ROWS = 5
LEG_X = {"l": 17, "r": 23}
# In profile the legs stand one before the other under the body.
LEG_X_SIDE = {"l": 19, "r": 21}
# In three-quarter the far leg stands a pixel nearer the near one.
LEG_X_Q = {"l": 18, "r": 23}


DEFAULT_BOOT = ["occco", "oBBbo", "oBbbo", "ooooo"]


def leg(side, trouser_rows, lift=0, dx=0, trouser=None, boot=None, parts=("trouser", "boot"), view="front"):
    """One leg standing on the ground (or lifted `lift` pixels), its foot
    moved `dx` sideways: a trouser column (rows from `trouser(index, n)`,
    default plain) and a boot a pixel wider on the outside (`boot` rows).
    In profile both legs stand under the body and the toes point ahead."""
    x = LEG_X_SIDE[side] if view == "side" else LEG_X_Q[side] if view in QUARTER_VIEWS else LEG_X[side]
    if view == "side":
        side = "r"
    out = {}
    bottom = GROUND - lift
    boot_top = bottom - 3
    top = boot_top - trouser_rows
    if "trouser" in parts:
        for index, y in enumerate(range(top, boot_top)):
            # The lower half carries the step's sideways shift.
            shift = dx if index >= trouser_rows // 2 else (dx // 2 if dx else 0)
            row = trouser(index, trouser_rows) if trouser else ("oPpo" if index < trouser_rows - 1 else "oppo")
            for col, ch in enumerate(row):
                if ch != ".":
                    out[(x + col + shift, y)] = ch
    if "boot" in parts:
        bx = x - 1 if side == "l" else x
        for row, line in enumerate(boot or DEFAULT_BOOT):
            for col, ch in enumerate(line):
                if ch != ".":
                    out[(bx + col + dx, boot_top + row)] = ch
    return out


def colour_body(pixels):
    return {p: BODY[ch] for p, ch in pixels.items()}


# Kneeling and sitting legs are drawn whole.
KNEEL = [
    "..oooo....",
    "..oPpo....",
    "..oPpooooo",
    "..oPPPPppo",
    ".occcooooo",
    "oBBbo.....",
    "ooooo.....",
]


# --------------------------------------------------------------- frames
# A frame plan says where each part is: offsets in whole pixels, which arm
# pose, how each leg steps, the weapon's angle (multiples of 45 degrees, so
# blades stay clean stair-steps) and a quarter-turn for the whole figure.
def F(body=(0, 0), head=None, arm_l=("down", 0, 0), arm_r=("down", 0, 0), leg_l=(0, 0), leg_r=(0, 0),
      weapon=45, turn=0, crouch=0, legs=None, shadow=9, ground_shift=0, view="front", trail=0):
    """`view`: "front" (the usual three-quarter front), "back" (walking up,
    away from us) or "side" (in profile, walking sideways). `trail`: how
    far a cape's hem and long hair swing behind (whole pixels; negative is
    back, in profile)."""
    return {"body": body, "head": head if head is not None else body, "arm_l": arm_l, "arm_r": arm_r,
            "leg_l": leg_l, "leg_r": leg_r, "weapon": weapon, "turn": turn, "crouch": crouch, "legs": legs,
            "shadow": shadow, "ground_shift": ground_shift, "view": view, "trail": trail}


# Twelve frames a stride (phase 6): contact, passing and the held lift
# between, the arms swinging a frame behind the legs.
WALK_STEPS = [0, 1, 1, 1, 0, 0, 0, -1, -1, -1, 0, 0]
RUN_STEPS = [0, 1, 2, 2, 1, 0, 0, -1, -2, -2, -1, 0]


def _walk():
    frames = []
    n = len(WALK_STEPS)
    for i in range(n):
        step = WALK_STEPS[i]
        arm = WALK_STEPS[(i - 1) % n]
        # The foot lifts only while it passes (the middle of a held step).
        lift_l = 1 if step > 0 and WALK_STEPS[(i - 1) % n] > 0 else 0
        lift_r = 1 if step < 0 and WALK_STEPS[(i - 1) % n] < 0 else 0
        bob = -1 if lift_l or lift_r else 0
        frames.append(F(body=(0, bob), head=(0, bob if i % 2 else 0), arm_l=("down", -arm, 0), arm_r=("down", arm, 0),
                        leg_l=(lift_l, step), leg_r=(lift_r, -step), trail=1 if step > 0 else -1 if step < 0 else 0))
    return frames


def _run():
    frames = []
    n = len(RUN_STEPS)
    for i in range(n):
        step = RUN_STEPS[i]
        arm = RUN_STEPS[(i - 1) % n]
        lift_l = 2 if step >= 2 else (1 if step == 1 else 0)
        lift_r = 2 if step <= -2 else (1 if step == -1 else 0)
        bob = -1 if abs(step) == 2 else 0
        front = "fwd_down" if arm > 0 else "down"
        frames.append(F(body=(1, bob), arm_l=("down", -arm, -1 if arm < 0 else 0), arm_r=(front, 0, 0),
                        leg_l=(lift_l, step), leg_r=(lift_r, -step), weapon=90 if arm > 0 else 45,
                        trail=1 if step > 0 else -1 if step < 0 else 0))
    return frames


ANIMATIONS = [
    # Breathing: the chest rises and settles, the head following a beat behind.
    ("idle", [F(body=(0, b), head=(0, h)) for b, h in ((0, 0), (0, 0), (0, 0), (1, 0), (1, 1), (1, 1), (1, 1), (0, 1))]),
    ("walk", _walk()),
    ("run", _run()),
    ("attack", [
        F(body=(-1, 0), arm_r=("up", 0, 0), weapon=-45),
        F(body=(-1, 0), arm_r=("up", 0, 0), weapon=-10, leg_l=(0, -1)),
        F(body=(0, 0), arm_r=("up", 0, 0), weapon=20, leg_l=(0, -1)),
        F(body=(1, 0), arm_r=("fwd_up", 0, 0), weapon=50),
        F(body=(2, 0), arm_r=("fwd", 0, 0), weapon=90, leg_r=(0, 1), arm_l=("down", -1, 0)),
        F(body=(2, 0), arm_r=("fwd", 0, 0), weapon=115, leg_r=(0, 1), arm_l=("down", -1, 0)),
        F(body=(1, 0), arm_r=("fwd_down", 0, 0), weapon=135, leg_r=(0, 1)),
        F(body=(0, 0), arm_r=("down", 0, 0), weapon=70),
    ]),
    ("heavy", [
        F(body=(-1, 0), arm_r=("up", 0, 0), weapon=-45),
        F(body=(-1, 1), arm_r=("up", 0, 0), weapon=-45, crouch=1),
        F(body=(-2, 1), arm_r=("up", 0, 0), weapon=0, crouch=1, leg_l=(0, -1)),
        F(body=(0, 0), arm_r=("fwd_up", 0, 0), weapon=0),
        F(body=(2, 0), arm_r=("fwd", 0, 0), weapon=90, leg_r=(0, 2), arm_l=("out", 0, 0)),
        F(body=(2, 1), arm_r=("fwd_down", 0, 0), weapon=135, crouch=1, leg_r=(0, 2), arm_l=("out", 0, 0)),
        F(body=(1, 1), arm_r=("fwd_down", 0, 0), weapon=135, crouch=1, leg_r=(0, 1)),
        F(body=(0, 0), arm_r=("down", 0, 0), weapon=45),
    ]),
    ("dodge", [
        F(crouch=2, body=(0, 2), arm_r=("fwd_down", 0, 0), weapon=90),
        F(crouch=3, body=(0, 3), arm_r=("fwd_down", 0, 0), weapon=90, turn=1),
        F(crouch=3, body=(0, 3), arm_r=("fwd_down", 0, 0), weapon=90, turn=2),
        F(crouch=3, body=(0, 3), arm_r=("fwd_down", 0, 0), weapon=90, turn=3),
        F(crouch=3, body=(0, 3), arm_r=("fwd_down", 0, 0), weapon=90),
        F(crouch=1, body=(0, 1), arm_r=("down", 0, 0), weapon=45),
        F(),
    ]),
    ("hurt", [
        F(body=(-1, 0), head=(-2, 0), arm_l=("down", -1, 0), arm_r=("down", -1, 0), weapon=0),
        F(body=(-2, 0), head=(-3, 1), arm_l=("out", 0, 0), arm_r=("fwd_up", -1, 0), weapon=-45, leg_l=(0, -1)),
        F(body=(-1, 0), head=(-1, 0), arm_r=("down", 0, 0), weapon=0),
    ]),
    ("death", [
        F(),
        F(body=(-1, 0), head=(-3, 1), arm_l=("out", 0, 0), arm_r=("fwd_up", -1, 0), weapon=-45),
        F(crouch=2, body=(0, 2), head=(0, 3), weapon=135, arm_r=("fwd_down", 0, 0)),
        F(body=(0, 4), head=(0, 5), legs="kneel", weapon=180, arm_r=("fwd_down", 0, 0), arm_l=("down", 0, 1)),
        F(body=(0, 4), head=(0, 5), legs="kneel", weapon=180, arm_r=("fwd_down", 0, 0), arm_l=("down", 0, 1)),
        F(turn=3, weapon=45, shadow=16, ground_shift=1),
        F(turn=3, weapon=45, shadow=16, ground_shift=1),
        F(turn=3, weapon=45, shadow=16, ground_shift=1),
    ]),
    ("rebirth", [
        F(turn=3, weapon=45, shadow=16, ground_shift=1),
        F(turn=3, weapon=45, shadow=16, ground_shift=1),
        F(body=(0, 4), head=(0, 4), legs="kneel", weapon=0, arm_r=("down", 0, 0)),
        F(body=(0, 4), head=(0, 3), legs="kneel", weapon=0, arm_l=("up", 0, 0), arm_r=("up", 0, 0)),
        F(crouch=1, body=(0, 1), arm_l=("up", 0, 0), arm_r=("up", 0, 0), weapon=0),
        F(arm_l=("up", 0, 0), arm_r=("up", 0, 0), weapon=0),
        F(arm_l=("up", 0, 0), arm_r=("up", 0, 0), weapon=0, body=(0, -1)),
        F(),
    ]),
    ("ride", [F(body=(0, 2 + b), crouch=2, legs="ride", arm_r=("fwd_down", 0, 0), weapon=90) for b in (0, 1, 1, 0)]),
    # Each weapon family's own attack (the plain swing is "attack" above).
    # A thrust: drawn back, then a lunge with the point straight ahead.
    ("thrust", [
        F(body=(-1, 0), arm_r=("fwd", -2, 0), weapon=90, leg_l=(0, -1)),
        F(body=(-1, 0), arm_r=("fwd", -2, 0), weapon=90, leg_l=(0, -1), arm_l=("fwd_down", -1, 0)),
        F(body=(2, 0), arm_r=("fwd", 2, 0), weapon=90, leg_r=(0, 1)),
        F(body=(3, 0), arm_r=("fwd", 3, 0), weapon=90, leg_r=(0, 2), arm_l=("out", 0, 0)),
        F(body=(1, 0), arm_r=("fwd", 1, 0), weapon=90, leg_r=(0, 1)),
        F(arm_r=("down", 0, 0), weapon=60),
    ]),
    # A smash: raised high overhead in both hands, then brought down hard.
    ("smash", [
        F(body=(-1, 0), arm_r=("up", 0, 0), arm_l=("up", 0, 0), weapon=-40),
        F(body=(-2, -1), arm_r=("up", -1, -1), arm_l=("up", -1, -1), weapon=-80),
        F(body=(-1, -1), arm_r=("up", 0, -1), arm_l=("up", 0, -1), weapon=-20),
        F(body=(1, 0), arm_r=("fwd_up", 0, 0), arm_l=("fwd_up", 0, 0), weapon=50),
        F(body=(2, 2), arm_r=("fwd_down", 0, 1), arm_l=("fwd_down", 0, 1), weapon=140, crouch=2, leg_r=(0, 1)),
        F(body=(2, 2), arm_r=("fwd_down", 0, 1), arm_l=("fwd_down", 0, 1), weapon=150, crouch=2, leg_r=(0, 1)),
        F(arm_r=("down", 0, 0), weapon=45),
    ]),
    # A shot: the bow held out, the string drawn to the cheek, loosed.
    ("shoot", [
        F(arm_r=("fwd", 0, 0), arm_l=("fwd", 0, 0), weapon=8),
        F(body=(-1, 0), arm_r=("fwd", 0, 0), arm_l=("fwd", -2, 0), weapon=8),
        F(body=(-1, 0), arm_r=("fwd", 0, 0), arm_l=("fwd", -4, 0), weapon=8),
        F(body=(-1, 0), arm_r=("fwd", 0, 0), arm_l=("fwd", -4, 0), weapon=8),
        F(body=(1, 0), arm_r=("fwd", 1, 0), arm_l=("out", 0, 0), weapon=8),
        F(arm_r=("down", 0, 0), weapon=15),
    ]),
    # A cast: the staff raised high, then swept forward to send the spell.
    ("cast", [
        F(arm_r=("fwd_up", 0, 0), arm_l=("fwd_up", 0, 0), weapon=0),
        F(body=(0, -1), arm_r=("up", 0, 0), arm_l=("up", 0, 0), weapon=-8),
        F(body=(0, -1), arm_r=("up", 0, -1), arm_l=("up", 0, -1), weapon=-8),
        F(body=(1, 0), arm_r=("fwd", 0, 0), arm_l=("fwd", 0, 0), weapon=60),
        F(body=(1, 0), arm_r=("fwd", 1, 0), arm_l=("out", 0, 0), weapon=75),
        F(arm_r=("down", 0, 0), weapon=10),
    ]),
]

# Each class at rest, its own way (4 frames, breathing).
def _breathe(make):
    return [make(b) for b in (0, 0, 1, 1)]


CLASS_IDLES = [
    # Weapon resting on the shoulder, feet planted wide.
    ("idle_warrior", _breathe(lambda b: F(body=(0, b), arm_r=("fwd_up", -1, 1), weapon=-50, leg_l=(0, -1), leg_r=(0, 1)))),
    # Shield arm braced forward, low and square.
    ("idle_guardian", _breathe(lambda b: F(body=(1, 1 + b), crouch=1, arm_l=("fwd", 0, 0), weapon=70, leg_l=(0, -1), leg_r=(0, 1)))),
    # Bow held low and ready, the head turning to look about.
    ("idle_ranger", [F(body=(0, 0), head=(h, 0), arm_r=("fwd_down", 0, 0), weapon=100, leg_l=(0, -1))
                     for h in (1, 1, 0, -1)]),
    # Crouched, blade low in a reverse grip, the free hand out.
    ("idle_assassin", _breathe(lambda b: F(body=(1, 1 + b), crouch=1, arm_r=("fwd_down", 0, 0), arm_l=("out", 0, 0), weapon=150,
                                           leg_l=(0, -2), leg_r=(0, 1)))),
    # Both hands raised, drawing on the arcane; light on the feet.
    ("idle_mage", [F(body=(0, b), arm_l=("fwd_up", 0, 0), arm_r=("fwd_up", 0, 0), weapon=0) for b in (0, -1, -1, 0)]),
    # The blade upright before the face, the free hand low.
    ("idle_spellblade", _breathe(lambda b: F(body=(0, b), arm_r=("fwd", -2, -1), arm_l=("fwd_down", 0, 0), weapon=0, leg_l=(0, -1),
                                             leg_r=(0, 1)))),
    # Hunched, head bowed, a clawed hand held out over the ground.
    ("idle_necromancer", _breathe(lambda b: F(body=(1, 1 + b), head=(2, 2 + b), crouch=1, arm_l=("fwd", 0, 0), weapon=10))),
    # One palm raised, a spell held ready in it.
    ("idle_spellcaster", [F(body=(0, b), arm_l=("fwd_up", 0, 0), weapon=30) for b in (0, -1, -1, 0)]),
]


def _walk_view(view):
    frames = []
    n = len(WALK_STEPS)
    for i in range(n):
        step = WALK_STEPS[i]
        arm = WALK_STEPS[(i - 1) % n]
        lift_l = 1 if step > 0 and WALK_STEPS[(i - 1) % n] > 0 else 0
        lift_r = 1 if step < 0 and WALK_STEPS[(i - 1) % n] < 0 else 0
        bob = -1 if lift_l or lift_r else 0
        if view == "side":
            # In profile the legs stride ahead and behind, the arms swing,
            # and the cape and hair stream back.
            frames.append(F(body=(0, bob), arm_l=("down", -arm, 0), arm_r=("down", arm, 0),
                            leg_l=(lift_l, 2 * step), leg_r=(lift_r, -2 * step), view=view, trail=-1 - (1 if bob else 0)))
        else:
            frames.append(F(body=(0, bob), arm_l=("down", 0, -abs(arm)), arm_r=("down", 0, -abs(arm) if arm < 0 else 0),
                            leg_l=(lift_l, 0), leg_r=(lift_r, 0), view=view, trail=1 if step > 0 else -1 if step < 0 else 0))
    return frames


def _run_view(view):
    frames = []
    for i in range(len(RUN_STEPS)):
        step = RUN_STEPS[i]
        lift_l = 2 if step >= 2 else (1 if step == 1 else 0)
        lift_r = 2 if step <= -2 else (1 if step == -1 else 0)
        bob = -1 if abs(step) == 2 else 0
        if view == "side":
            frames.append(F(body=(1, bob), arm_l=("down", -step, 0), arm_r=("fwd_down" if step > 0 else "down", 0, 0),
                            leg_l=(lift_l, 2 * step), leg_r=(lift_r, -2 * step), view=view, weapon=90 if step > 0 else 45,
                            trail=-2 - (1 if bob else 0)))
        else:
            frames.append(F(body=(0, bob), arm_l=("down", 0, -1 if step > 0 else 0), arm_r=("down", 0, -1 if step < 0 else 0),
                            leg_l=(lift_l, 0), leg_r=(lift_r, 0), view=view, trail=1 if step > 0 else -1 if step < 0 else 0))
    return frames


VIEWS = [
    ("idle_back", [F(body=(0, b), view="back") for b in (0, 0, 1, 1)]),
    ("idle_side", [F(body=(0, b), view="side") for b in (0, 0, 1, 1)]),
    ("walk_back", _walk_view("back")), ("run_back", _run_view("back")),
    ("walk_side", _walk_view("side")), ("run_side", _run_view("side")),
    # The diagonals: three-quarter front and back.
    ("idle_fq", [F(body=(0, b), view="fq") for b in (0, 0, 1, 1)]),
    ("idle_bq", [F(body=(0, b), view="bq") for b in (0, 0, 1, 1)]),
    ("walk_fq", _walk_view("fq")), ("run_fq", _run_view("fq")),
    ("walk_bq", _walk_view("bq")), ("run_bq", _run_view("bq")),
]
# Every blow in every view, so a swing, a shot or a spell faces the way
# it goes: the front frames redrawn from behind, in profile and in the
# two three-quarter views.
BLOWS = ("attack", "heavy", "thrust", "smash", "shoot", "cast")
BLOW_VIEWS = ("back", "side", "fq", "bq")
_front = dict(ANIMATIONS)
VIEWED_BLOWS = [("%s_%s" % (blow, view), [dict(frame, view=view) for frame in _front[blow]]) for view in BLOW_VIEWS for blow in BLOWS]
ANIMATIONS += CLASS_IDLES + VIEWS + VIEWED_BLOWS
# Where each animation sits in a sheet: [row, first column]. The first
# fourteen keep their rows; short ones after them share a row in pairs
# (sheets stay small), matching PlayerAnimator.ROWS.
LAYOUT = {name: (row, 0) for row, (name, _frames) in enumerate(ANIMATIONS[:14])}
for k, (name, _frames) in enumerate(CLASS_IDLES):
    LAYOUT[name] = (14 + k // 2, 4 * (k % 2))
LAYOUT.update({"idle_back": (18, 0), "idle_side": (18, 4), "walk_back": (19, 0), "run_back": (20, 0), "walk_side": (21, 0), "run_side": (22, 0)})
LAYOUT.update({"idle_fq": (23, 0), "idle_bq": (23, 4), "walk_fq": (24, 0), "run_fq": (25, 0), "walk_bq": (26, 0), "run_bq": (27, 0)})
for k, (name, _frames) in enumerate(VIEWED_BLOWS):
    LAYOUT[name] = (28 + k, 0)
SHEET_ROWS = 28 + len(VIEWED_BLOWS)
# A sheet stays eight frames wide; an animation longer than its row
# carries on in a row of its own at the bottom (the twelve-frame strides).
COLUMNS = 8
WRAP = {}
for name, frames in ANIMATIONS:
    row, first = LAYOUT[name]
    if first + len(frames) > COLUMNS:
        WRAP[name] = SHEET_ROWS
        SHEET_ROWS += 1

# How each family carries its weapon when not attacking: [weapon angle].
# 0 points straight up, 90 ahead, 180 down.
GRIPS = {
    "upright": (8, ["spear", "heartpiercer", "sunfang", "halberd", "staff", "ember_staff", "wispkeeper", "rod"]),
    "bow": (14, ["bow", "heartstring", "splitshot"]),
    "dagger": (140, ["dagger", "fang", "frostbite"]),
    # Heavy arms hang low at the side, head down, ready to swing up.
    "low": (158, ["greatsword", "executioner", "pulsebrand", "axe", "reaver", "bloodthirst", "club"]),
}
GRIP_ROWS = ("idle", "walk", "run", "hurt", "idle_back", "walk_back", "run_back", "idle_side", "walk_side", "run_side",
             "idle_fq", "walk_fq", "run_fq", "idle_bq", "walk_bq", "run_bq")


def grip_angle(name):
    for _family, (angle, names) in GRIPS.items():
        if name in names:
            return angle
    return None


# --------------------------------------------------------------- drawing
PIVOT = (48, 57)  # frame pixel the whole figure turns about
GRIP = (35.5, 33.0)  # where every weapon's art is held (generate_art.WEAPONS)


def lift_of(height):
    """How far up the body sits for a height: taller legs, higher body."""
    return HEIGHT_ROWS[height] - BASE_ROWS


def place(frame, height, build):
    """Where each part goes in one frame: offsets for the head and body, the
    arm maps placed on their joints, the legs, and the weapon hand."""
    up = lift_of(height)
    bx, by = frame["body"]
    hx, hy = frame["head"]
    out = {"body": (bx, by - up), "head": (hx, hy - up)}
    arms = {}
    for side, joint, push in (("l", JOINT_L, -ARM_OUT[build]), ("r", JOINT_R, ARM_OUT[build])):
        pose, dx, dy = frame["arm_" + side]
        rows, ax, ay, handx, handy = ARMS[pose]
        shift = UP_SHIFT.get(pose, 0) * (1 if side == "r" else -1)
        ox = joint[0] + push + bx + dx + shift - ax
        oy = joint[1] + by - up + dy - ay
        arms[side] = (pose, ox, oy, (ox + handx, oy + handy))
    out["arms"] = arms
    if frame.get("view") in QUARTER_VIEWS:
        pose, ox, oy, hand = arms["l"]
        arms["l"] = (pose, ox + 1, oy, (hand[0] + 1, hand[1]))
    if frame.get("view") == "side":
        # In profile the arms hang from the shoulder at the side of the body.
        for side, joint in (("l", JOINT_L_SIDE), ("r", JOINT_R_SIDE)):
            pose, dx, dy = frame["arm_" + side]
            rows, ax, ay, handx, handy = ARMS[pose]
            ox = joint[0] + bx + dx - ax
            oy = joint[1] + by - up + dy - ay
            arms[side] = (pose, ox, oy, (ox + handx, oy + handy))
    return out


def body_pixels(frame, height, build):
    """The bare body of one frame, as box pixels -> letter, in drawing order."""
    where = place(frame, height, build)
    bx, by = where["body"]
    hx, hy = where["head"]
    rows = HEIGHT_ROWS[height] - frame["crouch"]
    layers = []
    if frame["legs"] == "kneel":
        kneel = {}
        for (x, y), ch in grid(KNEEL, 15, GROUND - 6, {c: c for c in "oPpBbcq"}).items():
            kneel[(x, y)] = ch
        layers.append(kneel)
    elif frame["legs"] == "ride":
        layers.append(_ride_legs(bx, by))
    else:
        for side in ("l", "r"):
            lift, dx = frame["leg_" + side]
            layers.append(leg(side, max(rows, 1), lift, dx, view=frame.get("view", "front")))
    view = frame.get("view", "front")
    torso_map = TORSOS_BACK[build] if view in ("back", "bq") else _turned_details(TORSOS[build]) if view == "fq" else TORSOS[build]
    torso = {}
    for (x, y), ch in grid(torso_map, TORSO_X[build], TORSO_Y, {c: c for c in "oTtufLlGgPp"}).items():
        torso[(x, y)] = ch
    if view == "side":
        torso = side_columns(torso, build)
    torso = {(x + bx, y + by): ch for (x, y), ch in torso.items()}
    arm_layers = []
    for side in ("l", "r"):
        pose, ox, oy, _hand = where["arms"][side]
        arm_layers.append(grid(ARMS[pose][0], ox, oy, {c: c for c in "oTtuSs"}))
    skull = {"back": SKULL_BACK, "side": SKULL_SIDE, "fq": SKULL_FQ, "bq": SKULL_BQ}.get(view, SKULL)
    head = grid(skull, HEAD_X + hx, HEAD_Y + hy, {c: c for c in "oSskhe"})
    if view in QUARTER_VIEWS:
        # The far arm behind the body, the near one over it.
        return layers + [arm_layers[0], torso, arm_layers[1], head]
    if view == "side":
        # The far arm behind the body, the near one over it.
        return layers + [arm_layers[0], torso, arm_layers[1], head]
    return layers + [torso] + arm_layers + [head]


def _ride_legs(bx, by):
    """Sitting astride: both legs short, boots turned out to the sides."""
    out = {}
    for side, x, boot_x in (("l", 17, 15), ("r", 23, 24)):
        y = TORSO_Y + by + 8
        for col, ch in enumerate("oPpo"):
            out[(x + col + bx, y)] = ch
            out[(x + col + bx, y + 1)] = "o" if col in (0, 3) else "p"
        for row, line in enumerate(["occco", "oBBbo", "ooooo"]):
            for col, ch in enumerate(line):
                out[(boot_x + col + bx, y + 2 + row)] = ch
    return out


def to_image(pixel_layers, legend):
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    for layer in pixel_layers:
        for (x, y), ch in layer.items():
            colour = legend.get(ch, ch) if len(ch) == 1 else ch
            fx, fy = x + OX, y + OY
            if 0 <= fx < FRAME and 0 <= fy < FRAME:
                img.putpixel((fx, fy), GA.rgba(colour))
    return img


def turned(img, frame):
    """Quarter-turns about PIVOT, exact to the pixel, then the lying shift."""
    turns = frame["turn"] % 4
    if turns == 0 and frame["ground_shift"] == 0:
        return img
    cx, cy = PIVOT
    half = 40
    box = (cx - half, cy - half, cx + half, cy + half)
    piece = img.crop(box)
    for _ in range(turns):
        piece = piece.transpose(Image.Transpose.ROTATE_270)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(piece, (box[0], box[1] + frame["ground_shift"] * LYING_DROP))
    return out


LYING_DROP = 5


def weapon_image(parts, frame, height, build):
    """A held weapon for one frame: its art turned by a multiple of 45
    degrees about its grip, the grip on the right hand."""
    where = place(frame, height, build)
    hand = where["arms"]["r"][3]
    rig = {"sword": dict(parent=None, pivot=GRIP, parts=parts)}
    pose = {"sword": (hand[0] - GRIP[0], hand[1] - GRIP[1], frame["weapon"])}
    return GA.draw_frame(rig, ["sword"], pose, shadow=False)


def shadow_under(img, frame):
    if frame["turn"] % 4 and frame["ground_shift"] == 0:
        width = 7
    else:
        width = frame["shadow"]
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gy = GROUND + OY
    ImageDraw.Draw(shade).ellipse((22 + OX - width, gy - 1, 22 + OX + width, gy + 2), fill=(0, 0, 0, 90))
    shade.alpha_composite(img)
    return shade


def body_frame(frame, height, build):
    img = to_image(body_pixels(frame, height, build), BODY)
    return shadow_under(turned(img, frame), frame)


def sheet(make_frame):
    out = Image.new("RGBA", (COLUMNS * FRAME, SHEET_ROWS * FRAME), (0, 0, 0, 0))
    for name, frames in ANIMATIONS:
        row, first = LAYOUT[name]
        for col, frame in enumerate(frames):
            at = first + col
            if at >= COLUMNS:
                out.paste(make_frame(frame), ((at - COLUMNS) * FRAME, WRAP[name] * FRAME))
            else:
                out.paste(make_frame(frame), (at * FRAME, row * FRAME))
    return out


# --------------------------------------------------------------- looks
# Head looks are drawn on the box: the skull spans x 14..29, y 12..24, the
# eyes sit at x 19 and 24 on rows 19-20. Maps start at x 11 unless noted.
HX = 11


def head_look(rows, y0, x0=HX):
    return {"head": layer_grid(rows, x0, y0)}


HAIR = {}
HAIR["hair_0"] = head_look([  # Tousled
    ".......oo....oo.......",
    "......oMMo..oMMo..o...",
    ".....oMMMMooMMmMoomo..",
    "....oMMMMMMMMMMmmmmo..",
    "...oMMMMMMMMMMMmmmmmo.",
    "..oMMMMMMMMMMMMmmmmmdo",
    "..oMMMMMmMMMMMmmmmmmdo",
    ".oMMMMmMMMmMMmMmmmmddo",
    ".oMMMmMMMmMMMmMmmmdmdo",
    ".oMMmoMmoMMmoMmdomddo.",
    ".oMmo.mo.oMo.omo.odmo.",
    ".omo..o...o...o...odo.",
    ".omo..............odo.",
    "..oo..............oo..",
], 7)
HAIR["hair_1"] = head_look([  # Cropped
    "......oooooooooo......",
    "....ooMMMMMMMMMmoo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oMMMMMMMMMMMmmmmdo..",
    "..oMMmMMMmMMMmmmmddo..",
    "..omoMmoMmoMmoMmoddo..",
    "..oo.o..o..o..o..oo...",
], 10)
HAIR["hair_2"] = head_look([  # Long
    ".......oooooooo.......",
    ".....ooMMMMMMMMoo.....",
    "....oMMMMMMMMMMmmo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oMMMMMmMMMMMmmmmmdo.",
    ".oMMMMmMMMMmMMMmmmmdo.",
    ".oMMMmoMMmoMMmoMmmdmdo",
    ".oMMmo.omo.omo.ommdmdo",
    ".oMMo..............mdo",
    ".oMmo..............mdo",
    ".oMmo..............mdo",
    ".oMmo..............mdo",
    ".oMmo..............mdo",
    ".omdo..............ddo",
    ".omdo..............ddo",
    ".omdo..............ddo",
    "..odo..............do.",
    "..oo...............oo.",
], 9)
HAIR["hair_6"] = head_look([  # Spiky
    "....o.....o.....o.....",
    "....oo...oMo...oMo....",
    "...oMo..oMMo..oMmo..o.",
    "...oMMooMMMMooMmmo.omo",
    "o..oMMMMMMMMMMmmmmomdo",
    "oMooMMMMMMMMMMMmmmmmo.",
    ".oMMMMMMMMMMMMMmmmmmo.",
    "..oMMMMMMMMMMMMmmmmdo.",
    ".oMMMMmMMMMMmMMmmmmddo",
    ".oMMMmoMMMmoMmmomdmddo",
    "..oMo.oMmo.oMo.omo.do.",
    "..oo...oo...oo..oo.oo.",
], 6)
HAIR["hair_9"] = head_look([  # Wild mane
    ".....oo..oooo..oo.....",
    "....oMMooMMMMooMmo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    ".oMMMMMMMMMMMMMmmmmmo.",
    ".oMMMMMMMMMMMMmmmmmmdo",
    "oMMMMMmMMMMMmMMmmmmmdo",
    "oMMMMmMMMmMMMmmmmmdmdo",
    "oMMMmoMMmoMMmoMmmmdmdo",
    "oMMmo.omo.omo.omdmddo.",
    "oMMmo.............mddo",
    "oMmmo.............mddo",
    "oMmdo.............dddo",
    ".omdo.............ddo.",
    ".omo...............do.",
    "..o.................o.",
], 7)
HAIR["hair_3"] = head_look([  # Ponytail
    "......oooooooo........",
    "....ooMMMMMMMMoo......",
    "...oMMMMMMMMMMmmooo...",
    "..oMMMMMMMMMMMmmmmMo..",
    "..oMMMMMMMMMMMmmmmMMo.",
    "..oMMMMmMMMMMmmmmdomMo",
    "..oMMmoMMmoMMmomddoMmo",
    "..omo.omo.omo.omddoMmo",
    "..oo...o...o...oddomdo",
    "...................mdo",
    "...................mdo",
    "..................omdo",
    "..................odo.",
    "...................o..",
], 9)
HAIR["hair_4"] = head_look([  # Mohawk
    "..........oo..........",
    ".........oMmo.........",
    ".........oMmo.........",
    "........oMMmmo........",
    "........oMMmmo........",
    "........oMMmmo........",
    ".......oMMMmmdo.......",
    ".......oMMMmmdo.......",
    "........oMmmdo........",
    ".........oooo.........",
], 5)
HAIR["hair_5"] = head_look([  # Topknot
    ".........oooo.........",
    "........oMMMmo........",
    "........oMMmmo........",
    ".........oDDo.........",
    "......ooommmmooo......",
    "....ooMMMMMMMMMmoo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oMMMMMMMMMMMmmmmdo..",
    "..oMMmMMMmMMMmmmmddo..",
    "..omoMmoMmoMmoMmoddo..",
    "..oo.o..o..o..o..oo...",
], 6)
HAIR["hair_7"] = head_look([  # Bob
    ".......oooooooo.......",
    ".....ooMMMMMMMMoo.....",
    "....oMMMMMMMMMMmmo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oMMMMMMMMMMMMmmmmo..",
    ".oMMMMMMMMMMMMMmmmmdo.",
    ".oMMmmmmmmmmmmmmmmddo.",
    ".oMMoooooooooooooomdo.",
    ".oMmo............omdo.",
    ".oMmo............omdo.",
    ".oMmo............omdo.",
    ".omdo............oddo.",
    ".omddo..........oddo..",
    "..oooo..........oooo..",
], 9)
HAIR["hair_8"] = head_look([  # Braids
    "......oooooooooo......",
    "....ooMMMMMMMMMmoo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oMMMMMMMMMMMmmmmdo..",
    ".ooMMmMMMmMMMmmmmddoo.",
    ".oMmoMmoMmoMmoMmomdmo.",
    ".oMmo............omdo.",
    ".oMdo............oddo.",
    ".ooo..............ooo.",
    ".oMmo............omdo.",
    ".omdo............oddo.",
    ".ooo..............ooo.",
    ".oMmo............omdo.",
    ".omdo............oddo.",
    "..oo..............oo..",
], 10)
HAIR["hair_10"] = head_look([  # Side sweep
    "......oooooooooo......",
    "....ooMMMMMMMMMMoo....",
    "...oMMMMMMMMMMMMmmo...",
    "..oMMMMMMMMMMMMMmmmo..",
    "..oMMMMMMMMMMMMMmmmdo.",
    "..oMMMMMMMMMMMMmmmmdo.",
    "..omMMMMMMMMMmmmmmddo.",
    "..oooommMMMMmmmmmmddo.",
    "......ooommmmmmmdddo..",
    ".........oooommddo.o..",
    "............ooddo.....",
    "..............oo......",
], 10)
HAIR["hair_11"] = head_look([  # Curls
    "......oo.oooo.oo......",
    ".....oMMoMMMmoMmo.....",
    "....oMMMMMmMMMMmmo....",
    "...oMmMMMMMMmMMmmmo...",
    "..oMMMMmMMMMMMmmmmmo..",
    ".oMMmMMMMmMMMmMmmmdmo.",
    ".oMMMMmMMMMmMMmmdmmdo.",
    ".omMmMMmMMmMMmMmmdmddo",
    ".oMMmoMmoMMoMmomdmddo.",
    ".omMo.omo.oo.omo.dmdo.",
    ".oMmo............omdo.",
    ".omdo............oddo.",
    "..oo..............oo..",
], 7)
HAIR["hair_12"] = head_look([  # Curtains
    ".......oooooooo.......",
    ".....ooMMMMdMMMMoo....",
    "....oMMMMMMdMMMMmmo...",
    "...oMMMMMMMdMMMMmmmo..",
    "..oMMMMMMMMdMMMMmmmmo.",
    "..oMMMMMMModoMMMmmmmo.",
    ".oMMMMMMMo..oMMmmmmdo.",
    ".oMMMMMoo....ooMmmmdo.",
    ".oMMMoo........oommdo.",
    ".oMMo............omdo.",
    ".oMmo............omdo.",
    ".omdo............oddo.",
    "..oo..............oo..",
], 9)
HAIR["hair_13"] = head_look([  # Buzz cut
    "......oooooooooo......",
    "....oodMdMdMdMdmoo....",
    "...odMdMdMdMdMdmdmo...",
    "..odMdMdMdMdMdMdmdmo..",
    "..omdmdmdmdmdmdmdmdo..",
    "..oo..............oo..",
], 11)
HAIR["hair_14"] = head_look([  # Twin tails
    "......oooooooooo......",
    "....ooMMMMMMMMMmoo....",
    "...oMMMMMMMMMMMmmmo...",
    ".yooMMMMMMMMMMMMmmmooy",
    "yyoMMMMMMMMMMMMmmmmoyy",
    "oMoMMmMMMmMMMmmmmddoMo",
    "oMoMoMmoMmoMmoMmoddoMo",
    "oMmoo.o..o..o..o.ooomo",
    "oMmo..............omdo",
    "oMmo..............omdo",
    "oMdo..............oddo",
    "omdo..............oddo",
    ".oo................oo.",
], 10)
HAIR["hair_15"] = head_look([  # Long braid
    "......oooooooooo......",
    "....ooMMMMMMMMMmoo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oMMMMMMMMMMMmmmmdo..",
    ".ooMMmMMMmMMMmmmmddo..",
    ".oMmoMmoMmoMmoMmoddo..",
    ".oMmo.o..o..o..o.oo...",
    ".oMdo.................",
    ".ooo..................",
    ".oMmo.................",
    ".omdo.................",
    ".ooo..................",
    ".oMmo.................",
    ".omdo.................",
    ".oyyo.................",
    ".oMmo.................",
    "..oo..................",
], 10)
HAIR["hair_16"] = head_look([  # Cloud
    ".....oooo....oooo.....",
    "...ooMMMMooooMMmmoo...",
    "..oMMMMMMMMMMMMmmmmo..",
    ".oMMMMMMmMMMMMMmmmmmo.",
    ".oMMMMMMMMMMMmMmmmmmo.",
    "oMMmMMMMMMMMMMMmmmmdmo",
    "oMMMMMMMMMMmMMMmmmmmdo",
    "oMMMMMMmMMMMMMmmmmdmdo",
    "oMMmMMMMMMMMMmmmmmmddo",
    "oMMMMMooooooooommmdmdo",
    ".oMMMo........omddmdo.",
    ".oMMmo........omdmddo.",
    ".omMdo........oddmdo..",
    "..omdo........oddo....",
    "...oo..........oo.....",
], 4)
HAIR["hair_17"] = head_look([  # Undercut
    "......oooooooooooo....",
    "....ooMMMMMMMMMMmmo...",
    "...oMMMMMMMMMMMMmmmo..",
    "..oMMMMMMMMMMMMMmmmdo.",
    "..oMMMMMMMMMMMMmmmddo.",
    "..oddMMMMMMMMmmmmddo..",
    "..o..ooMMMMmmmmdddo...",
    "..o....oooooooooooo...",
], 9)
HAIR["hair_18"] = head_look([  # Messy bun
    ".........o..o.........",
    "........oMooMo........",
    ".......oMMMMmmo.......",
    ".......oMMMmmdo.......",
    "........oDDDDo........",
    "......oooMMMmoo.......",
    "....ooMMMMMMMMMmoo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oMMMMMMMMMMMmmmmdo..",
    ".ooMMmMMMmMMMmmmmddoo.",
    ".oMmo.Mmo.oMo.omoodmo.",
    ".omo...o...o...o..odo.",
    "..oo..............oo..",
], 5)
HAIR["hair_19"] = head_look([  # Slicked back
    "......oooooooooo......",
    "....ooMMMMMMMMMmoo....",
    "...oMMddMMddMMddmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oMMddMMddMMddmmmdo..",
    "..oMMMMMMMMMMMmmmmdo..",
    "..ooooooooooooooooo...",
], 10)
HAIR["hair_20"] = head_look([  # Shaggy
    "......oooooooooo......",
    "....ooMMMMMMMMMmoo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    ".oMMMMMMMMMMMMMmmmmdo.",
    ".oMMMmMMmMMmMMmmmmddo.",
    ".oMMoMmoMmoMmoMmmoddo.",
    ".oMmo.mo.mo.mo.mo.mdo.",
    ".oMmo..o..o..o..o.mdo.",
    ".oMmmo...........omddo",
    ".omdmo...........oddo.",
    "..odo.............do..",
    "...o..............o...",
], 10)


def face(rows, y0, x0=14):
    return {"head": layer_grid(rows, x0, y0)}


def pair(rows, y0, x0):
    """A left-side map and its mirror on the right (ears, horns)."""
    left = layer_grid(rows, x0, y0)
    return {"head": merged(left, mirror(left))}


LOOK = {}
LOOK["eyes"] = {"head": layer_grid(["M"], 19, 20) | layer_grid(["M"], 24, 20)}

# --- beards (tinted with the hair colour)
LOOK["beard_1"] = face([  # Moustache
    "....oooooooo....",
    "...oMMmooMmmo...",
    "....oo....oo....",
], 21)
LOOK["beard_2"] = face([  # Goatee
    "....oooooooo....",
    "...oMMmooMmmo...",
    "....oo.oo.oo....",
    "......oMmo......",
    "......oMdo......",
    ".......oo.......",
], 21)
_SHORT = [
    "o..............o",
    "oMo..........omo",
    "oMMo.oMMmmo.omdo",
    "oMMMoMmoomMomddo",
    ".oMMMMMMMMmmddo.",
]
LOOK["beard_3"] = face(_SHORT + [  # Short beard
    "..ooMMMMMmmdoo..",
    "....oooooooo....",
], 19)
LOOK["beard_4"] = face(_SHORT + [  # Long beard
    ".oMMMMMMMMmmddo.",
    "..oMMMMMMmmddo..",
    "..oMMMmMMmmddo..",
    "...oMMMMmmddo...",
    "....oMMmmddo....",
    ".....oMmmdo.....",
    "......oMdo......",
    ".......oo.......",
], 19)
LOOK["beard_5"] = face(_SHORT + [  # Forked beard
    ".oMMMMMMMMmmddo.",
    "..oMMMMooMmmdo..",
    "..oMMmo..oMmdo..",
    "...oyyo..oyyo...",
    "...oMdo..oMdo...",
    "....oo....oo....",
], 19)
LOOK["beard_6"] = face([  # Chin strap
    "o..............o",
    "oo............oo",
    "oMo..........odo",
    "oMo..........odo",
    ".oMo........odo.",
    "..oMMMMMMMMmdo..",
    "...oooooooooo...",
], 18)
LOOK["beard_7"] = face([  # Mutton chops
    "o..............o",
    "oo............oo",
    "oMo..........omo",
    "oMMo.oooooo.omdo",
    "oMMMoMmoomMomddo",
    ".oMMo.oooo.omdo.",
    "..oo........oo..",
], 18)
LOOK["beard_8"] = face(_SHORT + [  # Braided beard
    "..ooMMMMMmmdoo..",
    "....ooMMmmoo....",
    "......oMmo......",
    "......oooo......",
    "......oMmo......",
    "......oyyo......",
    "......oMdo......",
    ".......oo.......",
], 19)

# --- ears (tinted with the skin)
LOOK["ears_1"] = pair([  # Pointed
    "o....",
    "oMo..",
    ".oMMo",
    ".omMo",
    "..ooo",
], 16, 10)
LOOK["ears_2"] = pair([  # Long
    "o......",
    "oMo....",
    ".oMMo..",
    "..omMMo",
    "...omMo",
    "....ooo",
], 14, 8)
LOOK["ears_3"] = pair([  # Beast (on top, in the hair colour)
    "o....",
    "oMo..",
    "oMpo.",
    "oMppo",
    "oMMMo",
    ".ooo.",
], 7, 15)
LOOK["ears_4"] = pair([  # Fins
    "o.....",
    "oMo...",
    "oMdMo.",
    ".oMdMo",
    "oMdMMo",
    "oMMmo.",
    ".ooo..",
], 15, 9)

# --- horns (bone, in their own colours)
LOOK["horns_1"] = pair([  # Nubs
    ".o.",
    "ovo",
    "oVo",
], 9, 16)
LOOK["horns_2"] = pair([  # Ram
    "..oooo..",
    ".ovvVVo.",
    "ovVoozVo",
    "ovo..oVo",
    "ovVo.ozo",
    ".oVVozo.",
    "..oooo..",
], 13, 9)
LOOK["horns_3"] = pair([  # Devil
    "o....",
    "ovo..",
    "ovo..",
    "oVvo.",
    ".oVvo",
    ".oVVo",
    "..oVo",
    "..ooo",
], 3, 13)
LOOK["horns_4"] = pair([  # Antlers
    "o...o...",
    "ovo.ovo.",
    ".ovoovo.",
    "..ovVo..",
    "o.oVvo..",
    "ovoVVo..",
    ".ovVzo..",
    "..oVzo..",
    "...ooo..",
], 2, 11)
LOOK["horns_5"] = {"head": merged(layer_grid([  # Crystal crown
    "..oo..",
    ".ocCo.",
    ".ocCo.",
    "ocCCKo",
    "ocCCKo",
    "ocCKKo",
    ".oooo.",
], 19, 4), mirror(layer_grid([
    ".o..",
    "oco.",
    "ocCo",
    "oCKo",
    ".oo.",
], 15, 8)), layer_grid([
    ".o..",
    "oco.",
    "ocCo",
    "oCKo",
    ".oo.",
], 15, 8))}
LOOK["horns_6"] = {"head": layer_grid([  # Unicorn
    "...o...",
    "..ovo..",
    "..ovo..",
    "..oVo..",
    ".ovVvo.",
    ".oVvzo.",
    ".ovVzo.",
    "..ooo..",
], 18, 3)}

# --- hats (pale ones take the dye)
LOOK["hat_1"] = head_look([  # Hood
    ".......oooooooo.......",
    ".....ooMMMMMMMMoo.....",
    "....oMMMMMMMMMMmmo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oMMMMMoooooommmmmo..",
    ".oMMMMooDDDDDDoommmdo.",
    ".oMMMoDDDDDDDDDDomddo.",
    ".oMMoD..........Domdo.",
    ".oMMo............omdo.",
    ".oMMo............omdo.",
    ".oMmo............omdo.",
    ".oMmo............omdo.",
    ".oMmmo..........omddo.",
    "oMMmmmo........ommdddo",
    "oMMmmmmoooooooommmdddo",
    ".oooooooooooooooooooo.",
], 8)
LOOK["hat_2"] = head_look([  # Bandana
    "..oooooooooooooooo....",
    "..oMMMMMMMMMMMmmmmoo..",
    "..oMmMMMmMMMmMmmmdomo.",
    "..oooooooooooooooomMdo",
    "..................oMmo",
    "...................oo.",
], 13)
LOOK["hat_3"] = head_look([  # Straw hat
    ".......oooooooo.......",
    "......otttttttTo......",
    ".....otttttttttTo.....",
    ".....otTtTtTtTTTo.....",
    "...oo!!!!!!!!!!!!oo...",
    ".oottttttttttttttTTTo.",
    "otttTtTtTtTtTtTtTTTTqo",
    ".ooqqqqqqqqqqqqqqqqqo.",
    "...oooooooooooooooo...",
], 6)
LOOK["hat_4"] = head_look([  # Wizard hat
    "................ooo...",
    "..............ooMmo...",
    ".............oMMmo....",
    "............oMMMo.....",
    "...........oMMMmo.....",
    "..........oMMMmmo.....",
    ".........oMMMMmmo.....",
    "........oMMMMMmmmo....",
    ".......oMMMMMMmmmo....",
    "......oDDDyyyDDDDDo...",
    "......oDDyoeyDDDDDo...",
    "..ooooMMMyyyMMmmmmoooo",
    "ooMMMMMMMMMMMMMmmmmmmo",
    ".oooooooooooooooooooo.",
], 1)
LOOK["hat_5"] = head_look([  # Flower crown
    ".....o..o.oo.o..o.....",
    "....o%o.&o**o&.o%o....",
    "...o%y%o&o*y*o&o%y%o..",
    "...oG%G7&&***&&7G%Go..",
    "....oGG77GG77GG77GGo..",
    ".....oooooooooooooo...",
], 8)
LOOK["hat_6"] = head_look([  # Circlet
    "..........oo..........",
    ".........oyyo.........",
    ".....oooorrRoooo......",
    "....oyyyyoRoyyyyjo....",
    ".....oooooooooooo.....",
], 10)
LOOK["hat_7"] = head_look([  # Feathered cap
    "....................o.",
    "...................o9o",
    "..................o90o",
    "......oooooooooo.o90o.",
    "....ooMMMMMMMMMmo90o..",
    "...oMMMMMMMMMMMmmo0o..",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oDDDDDDDDDDDDDDDDo..",
    "..oooooooooooooooooo..",
], 5)
LOOK["hat_8"] = head_look([  # Headband
    "..oooooooooooooooo....",
    ".ooMMMMMMMMMMMMmmmo...",
    "oMoDDDDDDDDDDDDDDDo...",
    "oMooooooooooooooooo...",
    ".oMo..................",
    "..oo..................",
], 14)
LOOK["hat_9"] = head_look([  # Woolly hat
    "..........oo..........",
    ".........oMMo.........",
    ".........oMmo.........",
    "......oooooooooo......",
    "....ooMMMMMMMMMmoo....",
    "...oMMMMMMMMMMMmmmo...",
    "..oMMMMMMMMMMMMmmmmo..",
    "..oDMDMDMDMDMDMDMDDo..",
    "..oDDDDDDDDDDDDDDDDo..",
    "..oooooooooooooooooo..",
], 5)
LOOK["hat_10"] = head_look([  # Tricorn
    "........oooooo........",
    "......ooMMMMMMoo......",
    "....ooMMMMMMMMmmoo....",
    ".ooooMMMMMMMMMMmmmoooo",
    "oyMMMMMMMMMMMMMMmmmmyo",
    ".oyyMMMMMMMMMMMmmmyyo.",
    "..ooyyyyyyyyyyyyyyoo..",
    "....oooooooooooooo....",
], 7)

# --- worn on the face
LOOK["acc_1"] = face([  # Spectacles
    "...oooo..oooo...",
    "...o+.oooo+.o...",
    "...o..o..o..o...",
    "...oooo..oooo...",
], 18)
LOOK["acc_2"] = face([  # Eyepatch
    "oo..............",
    "..oo............",
    "....oo..oooo....",
    "......oooeeeo...",
    ".........eeeo...",
    ".........ooo....",
], 15)
LOOK["acc_3"] = face([  # Monocle
    ".........yyyy...",
    ".........y+.y...",
    ".........y..y...",
    ".........yyyy...",
    "............y...",
    "............y...",
], 18)
LOOK["acc_4"] = face([  # Earrings
    "y..............y",
    "r..............r",
], 21, 13)
LOOK["acc_5"] = face([  # Nose ring
    ".......yy.......",
    "......y..y......",
    ".......yy.......",
], 21)
LOOK["acc_6"] = face([  # Face cloth
    ".oooooooooooooo.",
    "oMMMMMMMMMMmmmdo",
    "oMMMMMMdMMMmmmdo",
    ".oMMMMMdMMmmmdo.",
    "..ooMMMdMmmdoo..",
    "....oooooooo....",
], 21)

# --- marks on the skin (no outline; their own colours)
LOOK["mark_1"] = face(["!...", ".!..", ".!..", "..!."], 17, 25)                      # Scar
LOOK["mark_2"] = face(["......bb......", "..............", "..............",
                       "..............", "..............", "...bbb..bbb...", ], 15, 15)  # War paint
LOOK["mark_3"] = face(["~......~", "..~..~..", "........"], 21, 18)                 # Freckles
LOOK["mark_4"] = face(["pp......pp"], 21, 17)                                       # Blush
LOOK["mark_5"] = face([".u.", "u+u", ".u."], 14, 20)                                # Brow gem
LOOK["mark_6"] = face(["eee..", "ee...", "e...."], 21, 16)                          # Tattoo
LOOK["mark_7"] = face(["i....i", "i....i"], 22, 19)                                 # Tusks
LOOK["mark_8"] = face(["i..i"], 23, 20)                                             # Fangs
LOOK["mark_9"] = face(["aaa....aaa", "..........", "aa......aa"], 21, 17)          # Woad
LOOK["mark_10"] = face([".#.", "###", ".#."], 20, 26)                               # Star
LOOK["mark_11"] = face(["yyy....yyy", "..........", "...yyyy..."], 21, 17)         # Gold paint
LOOK["mark_12"] = face([".U.", "UeU", ".U."], 14, 20)                               # Third eye

# --- what each race has of its own (pale = skin colour)
LOOK["race_elf_accent"] = face(["w"], 15, 21)
LOOK["race_dwarf"] = face([".oo.", "oMmo", "omdo", ".oo."], 20, 20)
LOOK["race_orc"] = face(["ddd..ddd"], 18, 18)
LOOK["race_orc_accent"] = face(["i....i", "i....i"], 22, 19)
# A long hooked goblin nose between the eyes.
LOOK["race_goblin"] = face(["..o.", ".oMo", "oMMo", "oMmo", "oMmdo", ".ooo."], 18, 20)
# Slime runs off the jaw and cheeks in drips.
LOOK["race_slime"] = merged(face(["oMo..........oMo", ".o............o."], 23, 14)["head"],
                            face([".M....M.", ".M....M.", ".M......", ".o......"], 24, 17)["head"])
LOOK["race_slime"] = {"head": LOOK["race_slime"]}
LOOK["race_slime_accent"] = face(["++", "+."], 14, 16)
# A skull: dark sockets round the eyes, a hollow nose, cheekbones.
LOOK["race_undead"] = merged(face([".xx....xx.", "xxDx..xDxx", "xxDx..xDxx", ".xx....xx."], 18, 17)["head"],
                             face(["xx", ".x"], 22, 21)["head"], face(["D", "D"], 21, 15)["head"], face(["D", "D"], 21, 28)["head"])
LOOK["race_undead"] = {"head": LOOK["race_undead"]}
LOOK["race_undead_accent"] = face(["vvvvvv", "e.e.e."], 22, 19)
LOOK["race_demonkin_accent"] = face([".f.", "fFf"], 14, 20)
# A fox's face: fur tufts out at the cheeks (in the coat's colour) and a
# pale muzzle with a black nose.
LOOK["race_beastkin"] = merged(face(["oM.", "oMM", ".oM"], 19, 12)["head"], face([".Mo", "MMo", "Mo."], 19, 29)["head"],
                               face([".oMMMMo.", "oMMMMMMo"], 17, 18)["head"])
LOOK["race_beastkin"] = {"head": LOOK["race_beastkin"]}
LOOK["race_beastkin_accent"] = face(["..vvvv..", ".vvvvvv.", ".vveevv.", "..vVVv.."], 21, 18)
# A lizard's snout jutting from the lower face, a crest of spines along
# the top of the head and scales on the cheeks.
LOOK["race_lizardfolk"] = merged(
    face(["..o...o...o.", ".oMo.oMo.oMo", "oMMdoMMdoMMd"], 9, 16)["head"],
    face([".oooooooo.", "oMMMMMMmmo", "oMdMMMMdmo", "omMMMMMmmo", ".oommmmoo."], 21, 17)["head"],
    face(["d.d", ".d."], 17, 15)["head"], face(["d.d", ".d."], 17, 26)["head"])
LOOK["race_lizardfolk"] = {"head": LOOK["race_lizardfolk"]}
LOOK["race_fairy_accent"] = face(["p......p", "pp....pp"], 21, 17)
# Stone: a heavy brow, cracks across the face, chipped cheeks.
LOOK["race_stoneborn"] = merged(face(["xxxx....xxxx"], 18, 16)["head"], face(["x...", "x...", ".x..", ".x.x"], 13, 17)["head"],
                                face(["..x", "..x", ".x.", ".x."], 21, 25)["head"], face(["D.", "DD"], 22, 15)["head"])
LOOK["race_stoneborn"] = {"head": LOOK["race_stoneborn"]}
LOOK["race_stoneborn_accent"] = face(["..77..", ".7887."], 11, 18)
LOOK["race_vampire"] = face(["D....D", ".D..D.", "..DD.."], 13, 19)
LOOK["race_vampire_accent"] = face(["i..i"], 23, 20)
LOOK["race_merfolk"] = pair([
    "o....",
    "oMo..",
    "oMdo.",
    "oMMdo",
    ".oooo",
], 18, 10)
LOOK["race_merfolk_accent"] = face(["u....u"], 17, 19)
LOOK.update(HAIR)


# --- worn on the body: anchored to the torso (x 16..27 at average build)
def body_look(rows, y0, x0, fit=True, behind=False):
    return {"torso": layer_grid(rows, x0, y0), "fit": fit, "behind": behind}


LOOK["neck_1"] = body_look([  # Scarf
    "..oooooooo..",
    ".oMMMMMMmmo.",
    ".oMMMMmmmmdo",
    "..oooooMmdo.",
    "......oMmdo.",
    "......oMddo.",
    ".......ooo..",
], 23, 16, fit=False)
LOOK["neck_2"] = body_look([  # Fur collar
    "...oooooooooo...",
    ".ooHhhhhhhhhHHoo",
    "ohhhhHhhhHhhHHko",
    "oHhhHhhHhhHHkHko",
    ".ooHkoooooooHkoo",
    "...oo......oo...",
], 23, 14, fit=False)
LOOK["neck_3"] = body_look([  # Shawl
    "..oooooooo..",
    ".oMMMMMMmmo.",
    "oMMMMMMMmmdo",
    ".oMMMMMmmdo.",
    "..oMMMmmdo..",
    "...oMmmdo...",
    "....oddo....",
    ".....oo.....",
], 23, 16, fit=False)
LOOK["neck_4"] = body_look([  # Pendant
    "y......y",
    ".y....y.",
    "..y..y..",
    "...oo...",
    "..oyro..",
    "...oo...",
], 24, 18, fit=False)
LOOK["neck_5"] = body_look([  # Bandolier
    "oo..........",
    "oLLo........",
    ".oLLo.......",
    "..oLsLo.....",
    "...oyyo.....",
    "....oLLo....",
    ".....oLLo...",
    "......oLLo..",
    ".......oLLo.",
    "........oo..",
], 24, 16, fit=False)

# Garments over the tunic, in the clothes colour (greys take its tones).
LOOK["outfit_1"] = body_look([  # Robe to the ankles, with a gold sash
    ".oooooooooooo.",
    "oMMMMdddMMMmmo",
    "oMMMMMddMMMmmo",
    "oMMMMMMMMMMmmo",
    "oMMMMMMMMMMmmo",
    "oyyyyyyyyyyYYo",
    "oMMMMMMMMMMmmo",
    "oMMMMMdMMMMmmo",
    "oMMMMMdMMMMmmo",
    ".oMMMMdMMMmmo.",
    ".oMMMMdMMMmmo.",
    ".oMMMMdMMMmmo.",
    ".oMMMMdMMMmmo.",
    ".oMMMMdMMmmmo.",
    ".oddddddddddo.",
    ".oooooooooooo.",
], 24, 15)
LOOK["outfit_2"] = body_look([  # Open vest over the shirt
    ".oooo....oooo.",
    "oMMmo....oMmmo",
    "oMMmo....oMmmo",
    "oMMMmo..oMMmmo",
    "oMMMmo..oMMmmo",
    "oMMMMo..oMMmmo",
    "oMMMMmooMMMmmo",
    "oddddddddddddo",
    ".oooooooooooo.",
], 24, 15)
LOOK["outfit_3"] = body_look([  # Long coat with a high collar and buttons
    "oooo......oooo",
    "oMMMoo..ooMmmo",
    "oMMMMMooMMMmmo",
    "oMMMMMyoMMMmmo",
    "oMMMMMMoMMMmmo",
    "oMMMMMyoMMMmmo",
    "oMMMMMMoMMMmmo",
    "oMMMMMyoMMMmmo",
    "oMMMMMMoMMMmmo",
    ".oMMMMMoMMMmo.",
    ".oMMMMdodMMmo.",
    ".oMMMdd.ddMmo.",
    ".ooooo...oooo.",
], 23, 15)
LOOK["outfit_4"] = body_look([  # Jerkin: crossed straps and studs
    ".oooooooooooo.",
    "oMMMMMMMMMMmmo",
    "oMyMMMMMMMMmyo",
    "oMMMdMMMMdMmmo",
    "oMMMMdMMdMMmmo",
    "oMMMMMddMMMmmo",
    "oMMMMdMMdMMmmo",
    "oddddddddddddo",
    ".oooooooooooo.",
], 24, 15)
LOOK["outfit_5"] = body_look([  # Dress: a fitted bodice and a full skirt
    "..oooooooooooo..",
    ".oMMMMMMMMMMmmo.",
    ".oMMMMMMMMMMmmo.",
    "..oMMMMMMMMmmo..",
    "..oMMMMMMMMmmo..",
    "..oyyyyyyyyYYo..",
    ".oMMMMMMMMMMmmo.",
    ".oMMMMdMMdMMmmo.",
    "oMMMMMdMMdMMmmmo",
    "oMMMMdMMMMdMmmmo",
    "oMMMMdMMMMdMmmmo",
    "oMMMdMMMMMMdmmmo",
    "odddddddddddddo.",
    ".oooooooooooooo.",
], 24, 14)
LOOK["outfit_6"] = body_look([  # Rags: patched and torn at the hem
    ".oooooooooooo.",
    "oMMMMMMdMMMmmo",
    "oMMdMMMMMMMmmo",
    "oMMMMMMMMMdmmo",
    "oMMMMdMMMMMmmo",
    "oMMMMMMMMMMmmo",
    "oMMdMMMMMdMmmo",
    "oMoMMoMMoMMmmo",
    ".o.oo.oo.oooo.",
], 24, 15)

# Capes hang behind: the body is drawn over them, so only the edges and
# the hem show round the figure.
LOOK["cape_1"] = body_look([  # Short cape
    "...oooooooooooo...",
    "..oMMMMMMMMMMmmo..",
    ".oMMMMMMMMMMMmmmo.",
    ".oMMMMMMMMMMMmmmo.",
    "oMMMMMMMMMMMMmmmdo",
    "oMMMMMMMMMMMmmmmdo",
    "oMMMMMMMMMMMmmmddo",
    "oMMMMMMMMMMmmmmddo",
    "oDDDDDDDDDDDDDDDDo",
    ".oooooooooooooooo.",
], 24, 13, behind=True)
LOOK["cape_2"] = body_look([  # Long cloak
    "...oooooooooooo...",
    "..oMMMMMMMMMMmmo..",
    ".oMMMMMMMMMMMmmmo.",
    ".oMMMMMMMMMMMmmmo.",
    "oMMMMMMMMMMMMmmmdo",
    "oMMMMMMMMMMMmmmmdo",
    "oMMMMMMMMMMMmmmddo",
    "oMMMMMMMMMMmmmmddo",
    "oMMdMMMMMMMMmmdmdo",
    "oMMdMMMMMMMmmmdmdo",
    "oMMdMMMMMMMmmmdmdo",
    "oMMdMMMMMMmmmmdmdo",
    "oMMdMMMMMMmmmmdmdo",
    "oMMdMMMMMmmmmmdddo",
    "oMMdMMMMMmmmmmdddo",
    "oDDDDDDDDDDDDDDDDo",
    ".oooooooooooooooo.",
], 24, 13, behind=True)
LOOK["cape_3"] = body_look([  # Tattered cloak
    "...oooooooooooo...",
    "..oMMMMMMMMMMmmo..",
    ".oMMMMMMMMMMMmmmo.",
    ".oMMMMMMMMMMMmmmo.",
    "oMMMMMMMMMMMMmmmdo",
    "oMMMMMMMMMMMmmmmdo",
    "oMMMMMMMMMMMmmmddo",
    "oMMdMMMMMMMmmmmddo",
    "oMMdMMMMMMMmmmdmdo",
    "oMMdMMMMMMmmmmdmdo",
    "oMdoMMMMoMmmmodmdo",
    "odo.oMMo.omdo.oddo",
    ".o...oo...oo...oo.",
], 24, 13, behind=True)
LOOK["cape_4"] = body_look([  # Feather mantle
    "..oooooooooooooo..",
    ".o99999999999990o.",
    "o9990999099909900o",
    "o9909909990990900o",
    ".o90o90o90o90o90o.",
    "..o0o.o0o.o0o.o0o.",
    "...o...o...o...o..",
], 23, 13, fit=False)

# Tails and wings, behind the body.
LOOK["tail_1"] = body_look([  # Devil
    "oo........",
    "oMo.......",
    "ooMo......",
    "..oMo.....",
    "...oMo...o",
    "....oMoooo",
    ".....oMMMo",
    "......oooo",
], 25, 7, fit=False, behind=True)
LOOK["tail_1"]["torso"] = mirror(LOOK["tail_1"]["torso"], 43) if False else LOOK["tail_1"]["torso"]
LOOK["tail_2"] = body_look([  # Brush
    "..oooo....",
    ".oMMMMoo..",
    "oMMMMMMMoo",
    "oMMMMMMmmo",
    "ovMMMMmmmo",
    "ovvMMmmmo.",
    ".ovvooooo.",
    "..oo......",
], 26, 8, fit=False, behind=True)
LOOK["tail_3"] = body_look([  # Lizard
    "........oooo",
    "......ooMMmo",
    "....ooMMmmdo",
    "..ooMMmmddo.",
    ".oMmdddooo..",
    "oMdooo......",
    ".oo.........",
], 28, 6, fit=False, behind=True)
LOOK["wings_1"] = body_look([  # Fairy
    ".oo....................oo.",
    "oMMoo................ooMMo",
    "oMMMMo..............oMMMMo",
    "oMMdMMo............oMMdMMo",
    ".oMMdMMo..........oMMdMMo.",
    "..oMMMMo..........oMMMMo..",
    "...oooo............oooo...",
    "..oMMMo............oMMMo..",
    ".oMMdo..............odMMo.",
    ".oooo................oooo.",
], 16, 9, fit=False, behind=True)
LOOK["wings_2"] = body_look([  # Bat
    "oo......................oo",
    "oMoo..................ooMo",
    "oMMMoo..............ooMMMo",
    "oMdMMMoo..........ooMMMdMo",
    "oMdMdMMMo........oMMMdMdMo",
    "oMdMdMMMo........oMMMdMdMo",
    ".oMoMoMMo........oMMoMoMo.",
    "..o.o.oo..........oo.o.o..",
], 17, 9, fit=False, behind=True)
LOOK["wings_3"] = body_look([  # Awakened: pale feathers tipped with gold
    ".oo........................oo.",
    "oMMoo....................ooMMo",
    "oMMMMoo................ooMMMMo",
    "oMMmMMMoo............ooMMMmMMo",
    ".oMMmMMMMo..........oMMMMmMMo.",
    "..oMMmMmMMo........oMMmMmMMo..",
    "..oMyMmMmMo........oMmMmMyMo..",
    "...oMyMmmo..........ommMyMo...",
    "....oMyMo............oMyMo....",
    ".....oyo..............oyo.....",
    "......o................o......",
], 17, 7, fit=False, behind=True)


# --------------------------------------------------------------- armour
# Plate is drawn pale and tinted with its metal in the game; leather, fur,
# gold and the Heartsworn set keep their own colours.
ARMOUR = {}


def head_piece(rows, y0, x0=13):
    return {"head": layer_grid(rows, x0, y0)}


_CAP = [
    ".....oooooooo.....",
    "...ooMMMdMMMmoo...",
    "..oMMMMMdMMMMmmo..",
    ".oMMMMMMdMMMMmmmo.",
    ".oMMMMMMdMMMMmmmo.",
    "oMMMMMMMdMMMMmmmdo",
    "oDDDDDDDDDDDDDDDDo",
]
ARMOUR["helmet"] = head_piece(_CAP + [
    "oMmo....oMo...omdo",
    "oMmo....oMo...omdo",
    "oMmo.....o....omdo",
    "omdo..........oddo",
    ".oo............oo.",
], 10)
ARMOUR["helmet_plate_1"] = ARMOUR["helmet"]
ARMOUR["helmet_plate_2"] = head_piece([
    ".....oooooooo.....",
    "...ooMMMMMMMmoo...",
    "..oMMMMMMMMMMmmo..",
    ".oMMMMMMMMMMMmmmo.",
    ".oMMMMMMMMMMMmmmo.",
    "oMMMMMMMMMMMMmmmdo",
    "oDDDDDDDDDDDDDDDDo",
    "oMMMMMMMMMMMMmmmdo",
    "oMeeeeeeeeeeeeemdo",
    "oMMMMMMMdMMMMmmmdo",
    "oMMMMMMMdMMeMemmdo",
    "oMMMMMMMdMMMMmmmdo",
    ".oMMMMMMdMMeMemdo.",
    "..oDDDDDDDDDDDDo..",
    "...oooooooooooo...",
], 10)
ARMOUR["helmet_plate_3"] = head_piece([
    "oo.......oo.......oo",
    "oMo.....oyyo.....oMo",
    "oMMo...oyaayo...oMmo",
    ".oMMoooooyyoooooomo.",
    "..oMMMMMMdMMMMmmmo..",
    "...oMMMMMdMMMMmmmo..",
    "..oMMMMMMdMMMMmmmmo.",
    "..oMMMMMMdMMMMmmmmo.",
    ".oMMMMMMMdMMMMmmmmdo",
    ".oyyyyyyyyyyyyyyyyyo",
    ".oMmo....oMo...omdo.",
    ".oMmo....oMo...omdo.",
    ".oMmo.....o....omdo.",
    ".omdo..........oddo.",
    "..oo............oo..",
], 7, 12)
ARMOUR["helmet_leather"] = head_piece([
    ".....oooooooo.....",
    "...oolllslllLoo...",
    "..olllllslllLLLo..",
    ".olllllllsllLLLLo.",
    ".olllllllsllLLLLo.",
    "olllllllllllLLLLNo",
    "oNsNNsNNsNNsNNsNNo",
    "olLo..........oLNo",
    "olLo..........oLNo",
    "oLNo..........oNNo",
    ".oo............oo.",
], 10)
ARMOUR["helmet_crown"] = head_piece([
    "..o....o..o....o..",
    ".oyo..oyooyo..oyo.",
    ".oyyooyyrryyooyyo.",
    "oyyyyyyyyyyyyyyyYo",
    "oyrYyyyYrrYyyyYrYo",
    "ojjjjjjjjjjjjjjjjo",
    ".oooooooooooooooo.",
], 7)
ARMOUR["helmet_heart"] = head_piece([
    ".....oo4oo4oo.....",
    "...oo1114111oo....",
    "..o1111545111o....",
    ".o111115551112o...",
    ".o111111511122o...",
    "o1111111111122o...",
    "o4444444444444o...",
    "o11111111111222o..",
    "o1e66eeeee66e23o..",
    "o11111111111223o..",
    "o1111111111123o...",
    ".o1111111111223o..",
    "..o33333333333o...",
    "...ooooooooooo....",
], 10)
# The heart helm is drawn left-weighted; centre it on the head.
ARMOUR["helmet_heart"] = head_piece([
    "......oo4oo4oo......",
    "....oo1114111oo.....",
    "...o11115451112o....",
    "..o1111155511122o...",
    "..o1111115111122o...",
    ".o111111111111122o..",
    ".o444444444444444o..",
    ".o111111111111222o..",
    ".o1ee66eeee66ee23o..",
    ".o111111111111223o..",
    ".o111111111111223o..",
    "..o1111111111223o...",
    "...o33333333333o....",
    "....ooooooooooo.....",
], 10, 12)
ARMOUR["hood"] = head_piece([
    "......oooooooooo......",
    "....ooMMMMMMMMMmoo....",
    "...oMMMMMMMMMMMMmmo...",
    "..oMMMMMMMMMMMMMmmmo..",
    ".oMMMMMMMMMMMMMMmmmmo.",
    ".oMMMMMooooooooommmmo.",
    "oMMMMooxxxxxxxxoommmdo",
    "oMMMoxxxxxxxxxxxxommdo",
    "oMMoxx..........xxomdo",
    "oMMoxx..........xxomdo",
    "oMMoxx..........xxomdo",
    "oMMox............xomdo",
    "oMMmo............omddo",
    "oMMmmo..........ommddo",
    "oMMmmmo........ommmddo",
    "oMMmmmmoooooooommmmddo",
    ".oooooooooooooooooooo.",
], 7, 11)


def chest_piece(rows, y0=24, x0=16, extra=None):
    piece = {"torso": layer_grid(rows, x0, y0), "fit": True}
    if extra:
        piece["torso"].update(extra)
    return piece


_PLATE_CHEST = [
    ".oooooooooo.",
    "oMMMMdMMMmmo",
    "oMMMMdMMMmmo",
    "oMMMMdMMmmmo",
    "oMMMMdMMmmdo",
    "oDDDDDDDDDDo",
    "oMMMMdMMmmdo",
    "oDDDDDDDDDDo",
    "oooooooooooo",
]
ARMOUR["chest"] = chest_piece(_PLATE_CHEST)
ARMOUR["chest_plate_1"] = ARMOUR["chest"]
_PAULDRONS = layer_grid([
    ".ooo..........ooo.",
    "oMMMo........oMmdo",
    "oMMmo........omddo",
    ".ooo..........ooo.",
], 13, 23)
ARMOUR["chest_plate_2"] = chest_piece([
    ".oooooooooo.",
    "oMMMMdMMMmmo",
    "oMwMMdMMwmmo",
    "oMMMMdMMmmmo",
    "oMwMMdMMwmdo",
    "oDDDDDDDDDDo",
    "oMMMMdMMmmdo",
    "oDMDMDMDMDDo",
    "oooooooooooo",
], extra=_PAULDRONS)
ARMOUR["chest_plate_3"] = chest_piece([
    ".oyyyyyyyyo.",
    "oMMMMyyMMmmo",
    "oMMMyrryMmmo",
    "oMMMMyyMMmmo",
    "oMMMMdMMmmdo",
    "oyyyyyyyyyyo",
    "oMMMMdMMmmdo",
    "oDyDyDyDyDDo",
    "oooooooooooo",
], extra=layer_grid([
    ".ooo..........ooo.",
    "oMMMo........oMmdo",
    "oMMmo........omddo",
    "oyyyo........oyyjo",
    ".ooo..........ooo.",
], 13, 23))
# Mail, the first metal anyone wears: a coif of rings over the head and
# shoulders, open at the face, and a ring shirt belted at the waist. The
# rings alternate light and mid so they read as links, shading darker on
# the far side; the game tints it with its metal like plate.
ARMOUR["helmet_chain"] = head_piece([
    ".....oooooooo.....",
    "...ooMmMmMmMmoo...",
    "..oMmMmMmMmMmmdo..",
    ".oMmMmMmMmMmMmdmo.",
    ".omMmMmMmMmMmdmdo.",
    "oMmMmMmMmMmMmmdmdo",
    "oDdDdDdDdDdDdDdDdo",
    "oMmMo........omdmo",
    "omMmo........odmdo",
    "oMmMo........omdmo",
    "omMmMo......omdmdo",
    ".oMmMmo....omdmdo.",
    "..omMmMooooomdmo..",
    "...oooooooooooo...",
], 10)
ARMOUR["chest_chain"] = chest_piece([
    ".oooooooooo.",
    "oMmMmMmMmmdo",
    "omMmMmMmMdmo",
    "oMmMmMmMmmdo",
    "omMmMmMmMdmo",
    "oNNNNyNNNNNo",
    "oMmMmMmMmmdo",
    "omMmMmMmMdmo",
    "o.o.oo.o.o.o",
], extra=layer_grid([
    ".ooo..........ooo.",
    "oMmMo........omdmo",
    "omMmo........odmdo",
    ".ooo..........ooo.",
], 13, 23))
ARMOUR["chest_leather"] = chest_piece([
    ".oooooooooo.",
    "olllsNslLLLo",
    "ollllNlllLLo",
    "olllsNslLLLo",
    "ollllNlllLLo",
    "oNNNNyNNNNNo",
    "olllsNslLLNo",
    "oNNNNNNNNNNo",
    "oooooooooooo",
])
ARMOUR["chest_fur"] = chest_piece([
    "..............",
    "..............",
    "..............",
    "..olllNlllLo..",
    "..olllNllLLo..",
    "..oNNNyNNNNo..",
    "..olllNlllLo..",
    "..oNNNNNNNNo..",
    "..oooooooooo..",
], x0=14, extra=layer_grid([
    "...oooooooooooo...",
    ".oohhhhhhhhhhHHoo.",
    "ohhhhHhhhHhhHHHHko",
    "ohhHhhhHhhhHHkHHko",
    ".ooHkooooooooHkoo.",
    "...oo........oo...",
], 13, 23))
ARMOUR["chest_heart"] = chest_piece([
    ".o44444444o.",
    "o1111111122o",
    "o1115515122o",
    "o1115555122o",
    "o1111551223o",
    "o4444444444o",
    "o1111411223o",
    "o3333433333o",
    "oooooooooooo",
], extra=layer_grid([
    ".ooo..........ooo.",
    "o111o........o123o",
    "o112o........o233o",
    "o444o........o444o",
    ".ooo..........ooo.",
], 13, 23))
ARMOUR["shoulders"] = {"torso": layer_grid([
    ".oooo........oooo.",
    "oMMMmo......oMMmdo",
    "oMMmmo......oMmmdo",
    "oDDDDo......oDDDDo",
    ".oooo........oooo.",
], 13, 23), "fit": True}
ARMOUR["cape"] = dict(LOOK["cape_2"])
ARMOUR["shield"] = {"hand_l": layer_grid([
    ".oooooooo.",
    "oMMMMMMmmo",
    "oMDDDDDDmo",
    "oMDMMMmDmo",
    "oMDMMmmDmo",
    "oMDMmmmDdo",
    ".oMDDDDdo.",
    "..oMmmdo..",
    "...oddo...",
    "....oo....",
], -5, -4)}

# Leg armour: rows for the trouser part (index from the top, of `rows`)
# and the boot.
LEG_LOOKS = {
    "legs_plate": {"leg": lambda i, n: "oDDo" if i == n // 2 else ("oMmo" if i < n // 2 else "omdo")},
    "legs_chain": {"leg": lambda i, n: "oMmo" if i % 2 == 0 else "omdo"},
    "legs_leather": {"leg": lambda i, n: "oNNo" if i == n - 1 else "olso"},
    "legs_heart": {"leg": lambda i, n: "o5to"[0:0] + ("o44o" if i == n // 2 else ("o12o" if i < n // 2 else "o23o"))},
}
BOOT_LOOKS = {
    "boots_plate": {"boot": ["oDDDo", "oMMmo", "oMmdo", "ooooo"]},
    "boots_leather": {"boot": ["olllo", "oNNNo", "oNNno", "ooooo"]},
    "boots_heart": {"boot": ["o444o", "o112o", "o123o", "ooooo"]},
}


# --------------------------------------------------------------- layers
def fit_build(pixels, build):
    """A torso piece drawn for the average build made to fit a slighter or
    broader one, by taking out or doubling one whole column each side
    (x 18 and x 25), so nothing is resampled."""
    if build == 1:
        return pixels
    out = {}
    for (x, y), c in pixels.items():
        if build == 0:
            if x in (18, 25):
                continue
            out[(x + 1 if x < 18 else (x - 1 if x > 25 else x), y)] = c
        else:
            if x <= 18:
                out[(x - 1, y)] = c
                if x == 18:
                    out[(18, y)] = c
            elif x >= 25:
                out[(x + 1, y)] = c
                if x == 25:
                    out[(25, y)] = c
            else:
                out[(x, y)] = c
    return out


LAYER_LEGEND = dict(ACCENT)
LAYER_LEGEND.update(GREY)

# --------------------------------------------------------------- views
# Every look and piece is drawn for the front; its back and profile come
# from rules by what it is, worked on whole pixels.
SKULL_CELLS = {(HEAD_X + col, HEAD_Y + row): ch for row, line in enumerate(SKULL) for col, ch in enumerate(line) if ch != "."}
SKULL_TOP = HEAD_Y
# Head looks that are part of the face: gone from behind, and turned to
# the face side in profile (except what stands out past the head).
FACE_LOOKS = ("eyes", "mark", "beard", "acc", "race_")


def _fill_holes(pixels):
    """Closes a piece's openings (a helmet's or hood's face) with its own
    middle tone: any empty pixel inside it, row by row and column by column."""
    if not pixels:
        return pixels
    out = dict(pixels)
    fill = GREY["m"]
    xs = [x for x, _y in pixels]
    ys = [y for _x, y in pixels]
    for y in range(min(ys), max(ys) + 1):
        row = sorted(x for (x, yy) in pixels if yy == y)
        if len(row) < 2:
            continue
        for x in range(row[0], row[-1] + 1):
            if (x, y) in out:
                continue
            column = [yy for (xx, yy) in pixels if xx == x]
            if column and min(column) < y < max(column):
                out[(x, y)] = fill
    return out


def _hair_from_behind(pixels, half=None):
    """Hair seen from behind: the back of the skull covered down to as long
    as it hangs at the sides (or over the crown, for short hair), shaded
    from the light crown to the dark nape with a few strands, outlined on
    the skull's own outline. `half` "back" covers only the back of the
    head (for the profile)."""
    sides = [y for (x, y) in pixels if (x <= HEAD_X + 2 or x >= HEAD_X + 13) and SKULL_TOP <= y <= SKULL_TOP + 12]
    bottom = max(sides) if sides else SKULL_TOP + 5
    bottom = max(bottom, SKULL_TOP + 5)
    out = dict(pixels)
    for (x, y), ch in SKULL_CELLS.items():
        if y > bottom or (x, y) in out:
            continue
        if half == "back" and x > HEAD_X + 7:
            continue
        if ch == "o":
            out[(x, y)] = GREY["o"]
        elif y <= SKULL_TOP + 2:
            out[(x, y)] = GREY["M"]
        elif y >= bottom - 1:
            out[(x, y)] = GREY["d"]
        else:
            out[(x, y)] = GREY["d"] if (x * 3 + y) % 7 == 0 else GREY["m"]
    # A hairline: the last row darker where it meets the neck.
    for (x, y), ch in SKULL_CELLS.items():
        if y == bottom and ch != "o" and (half != "back" or x <= HEAD_X + 7):
            out[(x, y)] = GREY["x"]
    return out


def view_head(name, pixels, view):
    """A head look or piece from behind or in profile (box pixels)."""
    if view == "front":
        return pixels
    face = name.startswith(FACE_LOOKS)
    if view == "fq":
        # The face turned a pixel toward the near side; the rest stays.
        if face or name == "eyes":
            return {(fq_shift(x), y): c for (x, y), c in pixels.items() if x >= HEAD_X + 3}
        return pixels
    if view == "bq":
        pixels = view_head(name, pixels, "back")
        if name.startswith("hair"):
            # A sliver of the near cheek and ear shows past the hair.
            return {(x, y): c for (x, y), c in pixels.items() if not (x >= HEAD_X + 13 and SKULL_TOP + 5 <= y <= SKULL_TOP + 9 and c != GREY["o"])}
        return pixels
    if view == "back":
        if name.startswith("hair"):
            return _hair_from_behind(pixels)
        if name.startswith(("helmet", "hood")):
            return _fill_holes(pixels)
        if name.startswith(("eyes", "mark", "beard")):
            return {}
        if face:
            # Only what stands out past the head shows from behind.
            return {p: c for p, c in pixels.items() if p not in SKULL_CELLS or p[1] <= SKULL_TOP + 3}
        return pixels
    # In profile.
    if name.startswith("hair"):
        shifted = {(x - 1, y): c for (x, y), c in pixels.items() if x >= HEAD_X + 2}
        return _hair_from_behind(shifted, "back")
    if name == "eyes":
        return {(x + EYE_SIDE_SHIFT, y): c for (x, y), c in pixels.items() if x >= HEAD_X + 8}
    if name.startswith("ears"):
        # One ear, on the side of the head, its tip toward the back.
        return {(x + 6, y): c for (x, y), c in pixels.items() if x <= HEAD_X + 2}
    if face:
        return {(x + EYE_SIDE_SHIFT, y): c for (x, y), c in pixels.items() if x >= HEAD_X + 3}
    return pixels


def view_torso(name, pixels, view, build, behind):
    """A torso look or piece from behind or in profile."""
    if view == "side":
        return side_columns(pixels, build)
    if view in ("back", "bq") and behind and name.startswith(("cape", "cape_")):
        # A cape seen from behind covers the back, edge to edge.
        out = dict(pixels)
        rows = {}
        for (x, y) in pixels:
            rows.setdefault(y, []).append(x)
        for y, xs in rows.items():
            for x in range(min(xs), max(xs) + 1):
                if (x, y) not in out:
                    out[(x, y)] = GREY["m"] if (x + y) % 5 else GREY["d"]
        return out
    return pixels


def layer_frame(spec, frame, height, build):
    """One frame of a worn layer, on exactly the pixels its body part has
    in the same frame of the body sheet."""
    where = place(frame, height, build)
    bx, by = where["body"]
    hx, hy = where["head"]
    view = frame.get("view", "front")
    name = spec.get("name", "")
    layers = []
    trail = frame.get("trail", 0)
    if "torso" in spec:
        pixels = fit_build(spec["torso"], build) if spec.get("fit") else spec["torso"]
        pixels = view_torso(name, pixels, view, build, spec.get("behind", False))
        if trail and name.startswith("cape"):
            pixels = _trailed(pixels, trail, 34)
        layers.append({(x + bx, y + by): c for (x, y), c in pixels.items()})
    if "head" in spec:
        pixels = view_head(name, spec["head"], view)
        if trail and name.startswith("hair"):
            pixels = _trailed(pixels, trail, 25)
        layers.append({(x + hx, y + hy): c for (x, y), c in pixels.items()})
    if "hand_l" in spec:
        hand = where["arms"]["l"][3]
        ax, ay = int(hand[0]), int(hand[1])
        layers.append({(x + ax, y + ay): c for (x, y), c in spec["hand_l"].items()})
    if ("trouser" in spec or "boot" in spec) and frame["legs"] is None:
        rows = max(HEIGHT_ROWS[height] - frame["crouch"], 1)
        parts = ("trouser",) if "trouser" in spec else ("boot",)
        for side in ("l", "r"):
            lift, dx = frame["leg_" + side]
            pixels = leg(side, rows, lift, dx, trouser=spec.get("trouser"), boot=spec.get("boot"), parts=parts, view=view)
            layers.append({p: LAYER_LEGEND[ch] for p, ch in pixels.items()})
    return turned(to_image(layers, {}), frame)


def _trailed(pixels, trail, below):
    """The part of a layer below row `below` swung `trail` pixels to the
    side, more toward its lowest edge, so a hem or long hair streams."""
    if not pixels:
        return pixels
    bottom = max(y for _x, y in pixels)
    if bottom <= below:
        return pixels
    out = {}
    for (x, y), c in pixels.items():
        if y > below:
            shift = int(round(trail * (y - below) / (bottom - below)))
            out[(x + shift, y)] = c
        else:
            out[(x, y)] = c
    # Rows that moved keep no gaps against the still part above.
    return out


def weapon_frame(parts, frame, height, build):
    return turned(weapon_image(parts, frame, height, build), frame)


def save(img, *path):
    full = os.path.join(ROOT, "sprites", *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full)


AVERAGE_HEIGHT, AVERAGE_BUILD = 2, 1


def write_body():
    for height in range(len(HEIGHT_ROWS)):
        for build in range(len(TORSOS)):
            img = sheet(lambda frame: body_frame(frame, height, build))
            save(img, "people", "body_h%d_b%d.png" % (height, build))
            if (height, build) == (AVERAGE_HEIGHT, AVERAGE_BUILD):
                save(img, "player_sheet.png")


def write_layer(spec, folder, name):
    """A layer at the average height and build, plus build variants for
    pieces fitted to the torso and height variants for leg armour."""
    spec = dict(spec, name=name)
    save(sheet(lambda frame: layer_frame(spec, frame, AVERAGE_HEIGHT, AVERAGE_BUILD)), folder, name + ".png")
    if spec.get("fit"):
        for build in (0, 2):
            save(sheet(lambda frame: layer_frame(spec, frame, AVERAGE_HEIGHT, build)), folder, "%s_b%d.png" % (name, build))
    if "trouser" in spec:
        for height in range(len(HEIGHT_ROWS)):
            if height != AVERAGE_HEIGHT:
                save(sheet(lambda frame: layer_frame(spec, frame, height, AVERAGE_BUILD)), folder, "%s_h%d.png" % (name, height))


def write_frames_table():
    """scripts/player/body_frames.gd: which frames are turned, and how many
    pixels each height and build moves the layers, for the game to line
    every layer up with the body it is worn on."""
    turns = {name: [frame["turn"] % 4 for frame in frames] for name, frames in ANIMATIONS}
    lines = [
        "class_name BodyFrames",
        "extends RefCounted",
        "## Written by tools/generate_people.py: do not edit by hand.",
        "##",
        "## The body has a sheet per height and build (people/body_h<h>_b<b>.png);",
        "## layers are drawn for the average one. A layer worn on the head or",
        "## body moves up by `lift(height)` pixels; one held in a hand also moves",
        "## out by `arm_out(build)`. Frames turned for rolls and falls turn that",
        "## shift with them (`turns`: quarter turns clockwise per frame).",
        "",
        "const AVERAGE_HEIGHT := %d" % AVERAGE_HEIGHT,
        "const AVERAGE_BUILD := %d" % AVERAGE_BUILD,
        "const HEIGHT_ROWS: Array[int] = %s" % json.dumps(HEIGHT_ROWS),
        "const ARM_OUT: Array[int] = %s" % json.dumps(ARM_OUT),
        "const TURNS := %s" % json.dumps(turns),
        "",
        "",
        "## Pixels a layer moves up for a height (taller legs lift everything).",
        "static func lift(height: int) -> int:",
        "\treturn HEIGHT_ROWS[clampi(height, 0, HEIGHT_ROWS.size() - 1)] - HEIGHT_ROWS[AVERAGE_HEIGHT]",
        "",
        "",
        "## Pixels a held thing moves outward for a build.",
        "static func arm_out(build: int) -> int:",
        "\treturn ARM_OUT[clampi(build, 0, ARM_OUT.size() - 1)]",
        "",
        "",
        "## A shift in the frame's own turn: (x, y) turned `turns` quarters clockwise.",
        "static func turned(shift: Vector2i, turns: int) -> Vector2i:",
        "\tvar out := shift",
        "\tfor i in posmod(turns, 4):",
        "\t\tout = Vector2i(-out.y, out.x)",
        "\treturn out",
        "",
    ]
    path = os.path.join(ROOT, "..", "scripts", "player", "body_frames.gd")
    with open(path, "w") as handle:
        handle.write("\n".join(lines))


def _tint_hex(colour, tint):
    r, g, b = (int(colour[i:i + 2], 16) for i in (0, 2, 4))
    return "%02x%02x%02x" % (r * tint[0] // 255, g * tint[1] // 255, b * tint[2] // 255)


def _tinted(pixels, tint):
    return {p: (c if c == OUTLINE else _tint_hex(c, tint)) for p, c in pixels.items()}


# Villagers with a sheet of their own: body colours swapped, hair and a hat
# or helm worn, one idle row.
NPCS = {
    "merchant": {"T": "5f9a6a", "t": "447a50", "u": "2f5a3a", "f": "2f5a3a", "P": "6a5a48", "p": "4e4236", "q": "362e26",
                 "layers": [("hair_20", (200, 196, 184)), ("hat_9", (190, 150, 60)), ("neck_5", None)]},
    "warden": {"T": "8fa0b8", "t": "6a7a94", "u": "4a586e", "f": "4a586e", "P": "3a3a4a", "p": "2a2a38", "q": "1e1e28",
               "layers": [("cape_2", (150, 40, 50)), ("hair_1", (58, 48, 56)), ("helmet", (190, 200, 215))]},
}


def write_npcs():
    for name, spec in NPCS.items():
        legend = dict(BODY)
        legend.update({k: v for k, v in spec.items() if len(k) == 1})
        # Villagers' sheets keep four idle frames (every other breath).
        frames = dict(ANIMATIONS)["idle"][::2]
        out = Image.new("RGBA", (len(frames) * FRAME, FRAME), (0, 0, 0, 0))
        for col, frame in enumerate(frames):
            where = place(frame, AVERAGE_HEIGHT, AVERAGE_BUILD)
            bx, by = where["body"]
            hx, hy = where["head"]
            behind, front = [], []
            for look, tint in spec["layers"]:
                source = LOOK.get(look) or ARMOUR.get(look)
                if "torso" in source:
                    pixels = {(x + bx, y + by): c for (x, y), c in source["torso"].items()}
                else:
                    pixels = {(x + hx, y + hy): c for (x, y), c in source["head"].items()}
                (behind if source.get("behind") else front).append(_tinted(pixels, tint) if tint else pixels)
            img = to_image(behind, {})
            img.alpha_composite(to_image(body_pixels(frame, AVERAGE_HEIGHT, AVERAGE_BUILD), legend))
            img.alpha_composite(to_image(front, {}))
            out.paste(shadow_under(img, frame), (col * FRAME, 0))
        save(out, "npc_%s.png" % name)


def main():
    write_body()
    for name, spec in LOOK.items():
        write_layer(spec, "looks", name)
    for name, spec in ARMOUR.items():
        write_layer(spec, "layers", name)
    for name, look in LEG_LOOKS.items():
        write_layer({"trouser": look["leg"]}, "layers", name)
    for name, look in BOOT_LOOKS.items():
        write_layer({"boot": look["boot"]}, "layers", name)
    write_weapons()
    write_npcs()
    write_frames_table()


# --------------------------------------------------------------- weapon grades
# A weapon looks better as it grows: each grade is drawn from its own art,
# shape by shape (no recolouring in the game):
#   1 honed   a bright edge down the blade or shaft, bindings on the grip
#   2 gilded  the guard in gold and wider, a gem set at its heart
#   3 runed   runes glowing down the weapon, its tip catching the light
TOOLS = ("pickaxe", "hatchet", "rod")
GRADES = 3


def _bounds(polygon):
    xs = [p[0] for p in polygon]
    ys = [p[1] for p in polygon]
    return min(xs), min(ys), max(xs), max(ys)


def graded(parts, grade):
    """A weapon's art at a grade (see GRADES)."""
    out = list(parts)
    if grade <= 0:
        return out
    blades = [poly for m, poly in parts if m in ("blade", "edge", "dark_edge", "obsidian", "crystal", "bone")]
    shafts = [poly for m, poly in parts if m in ("wood", "bark", "belt", "wrap")]
    longest = max(blades or shafts or [poly for _m, poly in parts], key=lambda poly: (_bounds(poly)[3] - _bounds(poly)[1]) + (_bounds(poly)[2] - _bounds(poly)[0]))
    x0, y0, x1, y1 = _bounds(longest)
    tall = (y1 - y0) >= (x1 - x0)
    # 1: a bright edge along the long side of the blade or shaft, and
    # bindings round the grip.
    if tall:
        out.append(("holy" if grade >= 3 else "edge", [(x0, y0 + 1), (x0 + 0.6, y0 + 1), (x0 + 0.6, y1 - 0.5), (x0, y1 - 0.5)]))
    else:
        out.append(("holy" if grade >= 3 else "edge", [(x0 + 1, y0), (x1 - 0.5, y0), (x1 - 0.5, y0 + 0.6), (x0 + 1, y0 + 0.6)]))
    for k in range(2):
        out.append(("gold_m" if grade >= 2 else "wrap", [(34.6, 32.4 + k * 1.2), (36.4, 32.4 + k * 1.2), (36.4, 33.0 + k * 1.2), (34.6, 33.0 + k * 1.2)]))
    if grade >= 2:
        # The guard in gold, a third wider, with a gem at its heart.
        guards = [poly for m, poly in parts if m == "guard"]
        out = [(("gold_m" if m == "guard" else m), poly) for m, poly in out]
        for poly in guards:
            gx0, gy0, gx1, gy1 = _bounds(poly)
            cx, cy = (gx0 + gx1) / 2, (gy0 + gy1) / 2
            out.append(("gold_m", [(cx + (x - cx) * 1.3, cy + (y - cy) * 1.1) for x, y in poly]))
            out.append(("sapphire", [(cx - 0.7, cy - 0.7), (cx + 0.7, cy - 0.7), (cx + 0.7, cy + 0.7), (cx - 0.7, cy + 0.7)]))
        if not guards:
            out.append(("sapphire", [(34.8, 30.4), (36.2, 30.4), (36.2, 31.6), (34.8, 31.6)]))
    if grade >= 3:
        # Runes glowing down the length, and a bright tip.
        steps = 4
        for k in range(steps):
            t = (k + 1) / (steps + 1)
            if tall:
                rx, ry = (x0 + x1) / 2, y0 + (y1 - y0) * t
            else:
                rx, ry = x0 + (x1 - x0) * t, (y0 + y1) / 2
            out.append(("glow_cyan", [(rx - 0.5, ry - 0.5), (rx + 0.5, ry - 0.5), (rx + 0.5, ry + 0.5), (rx - 0.5, ry + 0.5)]))
        tip = (x0 + x1) / 2 if tall else x1
        tip_y = y0 if tall else (y0 + y1) / 2
        out.append(("holy", [(tip - 0.6, tip_y), (tip + 0.6, tip_y), (tip, tip_y + 1.5)]))
    return out


def write_weapons(only=None):
    row_of = {id(frame): row for row, frames in ANIMATIONS for frame in frames}
    for name, parts in GA.WEAPONS.items():
        if only and name not in only:
            continue
        angle = grip_angle(name)

        def carried(frame, angle=angle):
            # Out of the attack rows, the weapon sits in its family's grip.
            if angle is not None and row_of.get(id(frame)) in GRIP_ROWS:
                return dict(frame, weapon=angle)
            return frame
        for grade in range(0 if name in TOOLS else 0, 1 if name in TOOLS else GRADES + 1):
            art = graded(parts, grade)
            suffix = "" if grade == 0 else "_g%d" % grade
            save(sheet(lambda frame, art=art, carried=carried: weapon_frame(art, carried(frame), AVERAGE_HEIGHT, AVERAGE_BUILD)), "weapons", name + suffix + ".png")


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "weapons":
        write_weapons(sys.argv[2:] or None)
    else:
        main()
