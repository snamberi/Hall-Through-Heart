#!/usr/bin/env python3
"""Beasts, drawn pixel by pixel: every four-legged animal of the wilds and
the farm, and the fantasy creatures of each land.

Each is built from the same parts so they all belong to one world: a body
lit from the upper left with a lighter belly, legs in two segments with a
knee (or a hock, bending back) ending in hooves, paws or claws, a neck and
a head with its own snout, ears, eyes and horns, a tail, and the markings
that make each kind itself (spots, stripes, a saddle, a mask, a mane,
socks, the glow of a magic beast). Outlines are a dark tone of the beast's
own coat, not black, so nothing looks cut out.

Frames are made by moving these parts by whole pixels: a diagonal-gait
walk, a crouching wind-up, a lunge, a flinch, a fall onto folded legs, a
rest, a grazing head-down and a stretch. Nothing is stretched, squashed or
turned, so no pixel is ever resampled. Every beast faces right; the game
mirrors it.

Writes assets/sprites/enemies/<name>.png (11 rows of 96-pixel frames, the
rows of EnemyAnimator.ROWS, the pets' rest, scratch and stretch, then the
beast walking away, seen from behind: idle and walk).

Run from the repository root:  python3 tools/generate_beasts.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "enemies")
F = 96
GROUND = 73
ROWS = [("idle", 4), ("walk", 8), ("windup", 6), ("lunge", 6), ("hurt", 3), ("death", 8), ("rest", 4), ("scratch", 4), ("stretch", 4)]


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c, amount):
    return tuple(max(0, min(255, int(v * amount))) for v in c[:3]) + (c[3],)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


class Frame:
    """A 96x96 canvas that knows which pixels are filled (for outlining) and
    shades each shape from a light at the upper left."""

    def __init__(self):
        self.img = Image.new("RGBA", (F, F), (0, 0, 0, 0))
        self.filled = set()

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < F and 0 <= y < F:
            self.img.putpixel((x, y), c)
            self.filled.add((x, y))

    def mask(self, kind, coords, width=1):
        m = Image.new("L", (F, F), 0)
        d = ImageDraw.Draw(m)
        if kind == "ellipse":
            x0, y0, x1, y1 = coords
            if x1 < x0:
                x0, x1 = x1, x0
            if y1 < y0:
                y0, y1 = y1, y0
            d.ellipse((x0, y0, x1, y1), fill=255)
        elif kind == "poly":
            d.polygon(coords, fill=255, outline=255)
        elif kind == "line":
            d.line(coords, fill=255, width=width)
        elif kind == "rect":
            d.rectangle(coords, fill=255)
        return [(x, y) for y in range(F) for x in range(F) if m.getpixel((x, y))]

    def shape(self, kind, coords, ramp, width=1, light=(-0.55, -0.85)):
        """Fills a shape in three tones: lit, middle and shade."""
        pts = self.mask(kind, coords, width)
        if not pts:
            return pts
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        rx, ry = max((max(xs) - min(xs)) / 2, 1), max((max(ys) - min(ys)) / 2, 1)
        for x, y in pts:
            t = (x - cx) / rx * light[0] + (y - cy) / ry * light[1]
            self.put(x, y, ramp[0] if t > 0.4 else ramp[2] if t < -0.35 else ramp[1])
        return pts

    def fill(self, kind, coords, c, width=1):
        for x, y in self.mask(kind, coords, width):
            self.put(x, y, c)

    def outline(self, c):
        add = []
        for y in range(F):
            for x in range(F):
                if (x, y) in self.filled:
                    continue
                if any((x + dx, y + dy) in self.filled for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    add.append((x, y))
        for x, y in add:
            self.img.putpixel((x, y), c)


# ------------------------------------------------------------------ poses
def pose(**kw):
    p = {"bx": 0, "by": 0, "hx": 0, "hy": 0, "legs": [(0, 0, 0)] * 4, "tail": (0, 0), "ear": 0,
         "eye": "open", "lying": 0, "mouth": 0, "shadow": 1.0}
    p.update(kw)
    return p


def walk_frames():
    """A diagonal gait: near front with far hind, then the other pair."""
    out = []
    for i in range(8):
        a = i / 8.0 * math.tau
        step = round(2.6 * math.sin(a))
        lift_a = 1 if math.sin(a + math.pi / 2) > 0.55 else 0
        lift_b = 1 if math.sin(a + math.pi / 2) < -0.55 else 0
        legs = [(step, lift_a, 0), (-step, lift_b, 0), (-step, lift_b, 0), (step, lift_a, 0)]
        bob = -1 if i % 4 in (1, 2) else 0
        out.append(pose(by=bob, hy=-bob if i % 4 == 1 else 0, legs=legs, tail=(0, 1 if i % 4 < 2 else 0)))
    return out


# Leg order everywhere: near front, far front, near hind, far hind.
ANIMS = {
    "idle": [pose(), pose(), pose(by=1, hy=-1), pose(by=1, hy=-1, ear=1, tail=(1, 0))],
    "walk": walk_frames(),
    "windup": [pose(bx=-k, by=min(k, 2), hx=-k // 2, hy=k, legs=[(1, 0, 0), (1, 0, 0), (-1, 0, 0), (-1, 0, 0)], ear=1 if k > 1 else 0, mouth=1 if k > 3 else 0)
               for k in (0, 1, 2, 3, 3, 4)],
    "lunge": [pose(bx=k, by=-1 if 1 <= i <= 3 else 0, hx=k // 2 + 1, hy=-1 if i < 3 else 0,
                   legs=[(3, 1, 0), (2, 1, 0), (-2, 0, 0), (-3, 0, 0)] if 1 <= i <= 3 else [(1, 0, 0), (1, 0, 0), (-1, 0, 0), (-1, 0, 0)], mouth=1 if i < 4 else 0)
              for i, k in enumerate((2, 5, 7, 6, 3, 1))],
    "hurt": [pose(bx=-2, hx=-1, hy=-1, eye="shut", mouth=1), pose(bx=-3, by=1, hx=-2, eye="shut"), pose(bx=-1)],
    "death": [pose(bx=-2, hy=-1, eye="shut", mouth=1), pose(bx=-3, by=1, hy=1, eye="shut"), pose(bx=-3, by=2, hy=3, eye="shut", legs=[(0, 0, 1)] * 4),
              pose(bx=-3, lying=1, hy=4, eye="shut"), pose(bx=-3, lying=1, hy=6, eye="dead", shadow=1.2),
              pose(bx=-3, lying=1, hy=6, eye="dead", shadow=1.2), pose(bx=-3, lying=1, hy=6, eye="dead", shadow=1.2), pose(bx=-3, lying=1, hy=6, eye="dead", shadow=1.2)],
    "rest": [pose(lying=1, hy=1), pose(lying=1, hy=1), pose(lying=1, hy=2, eye="shut"), pose(lying=1, hy=2, eye="shut", tail=(1, 0))],
    "scratch": [pose(hx=2, hy=7, mouth=0), pose(hx=2, hy=8, mouth=1), pose(hx=2, hy=7), pose(hx=2, hy=8, mouth=1, ear=1)],
    "stretch": [pose(), pose(bx=1, by=1, hx=3, hy=3, legs=[(3, 0, 0), (3, 0, 0), (0, 0, 0), (0, 0, 0)]),
                pose(bx=2, by=2, hx=4, hy=4, legs=[(4, 0, 0), (4, 0, 0), (0, 0, 0), (0, 0, 0)], mouth=1), pose(bx=1, by=1, hx=2, hy=2)],
}


# ------------------------------------------------------------------ species
def beast(fur, out=None, belly=None, length=30, height=13, legs=13, leg_w=3, feet="hoof", neck=(4, 8), head=(11, 9),
          snout=(6, 5), ears="pointy", horns=None, horn_col="d8c8a8", tail="short", marks=(), mane=None,
          eye="1a1210", glow=None, feet_col=None, seed=1):
    fur = tuple(C(c) for c in fur)
    return dict(fur=fur, out=C(out) if out else shade(fur[2], 0.45), belly=C(belly) if belly else None, length=length, height=height,
                legs=legs, leg_w=leg_w, feet=feet, neck=neck, head=head, snout=snout, ears=ears, horns=horns,
                horn_col=C(horn_col), tail=tail, marks=marks, mane=C(mane) if mane else None, eye=C(eye),
                glow=C(glow) if glow else None, feet_col=C(feet_col) if feet_col else None, seed=seed)


SPECIES = {
    # --- redrawn from before
    "deer": beast(("c89060", "a06c40", "6e4628"), belly="e8d4b4", length=30, height=12, legs=16, leg_w=2, neck=(4, 10), head=(10, 8),
                  snout=(6, 4), ears="pointy", horns="antlers", tail="fluffy", marks=("spots",)),
    "wild_hare": beast(("b8a088", "907860", "5e4c3c"), belly="e8dcc8", length=16, height=9, legs=5, leg_w=2, feet="paw", neck=(1, 3),
                       head=(8, 7), snout=(3, 3), ears="long", tail="fluffy"),
    "wild_pig": beast(("8a6a58", "6a4e40", "44302a"), belly="9a7a66", length=28, height=14, legs=7, leg_w=3, neck=(0, 2), head=(11, 10),
                      snout=(6, 6), ears="floppy", horns="tusks", tail="curly", mane="3a2820"),
    "mountain_goat": beast(("e8e4dc", "c4beb2", "8e887c"), belly="f4f2ec", length=24, height=12, legs=12, leg_w=3, neck=(3, 7), head=(9, 8),
                           snout=(5, 4), ears="pointy", horns="curved", horn_col="6a6258", tail="short", marks=("beard",)),
    "snow_fox": beast(("f4f6f8", "d4dce4", "9aa8b4"), belly="ffffff", length=22, height=9, legs=8, leg_w=2, feet="paw", neck=(2, 5),
                      head=(9, 7), snout=(6, 3), ears="pointy", tail="bushy", eye="2a2a3a"),
    "desert_lizard": beast(("c8b06a", "9a8448", "64542a"), belly="e0d09a", length=24, height=6, legs=4, leg_w=2, feet="claw", neck=(1, 1),
                           head=(9, 6), snout=(5, 3), ears=None, tail="long", marks=("bands",)),
    "sheep": beast(("f4f0e6", "dcd4c4", "a89e8a"), length=26, height=15, legs=9, leg_w=2, neck=(2, 4), head=(9, 8), snout=(4, 5),
                   ears="floppy", tail="short", marks=("wool", "dark_face", "dark_legs")),
    "lamb": beast(("fbf8f0", "e6dece", "b4aa96"), length=18, height=11, legs=8, leg_w=2, neck=(2, 3), head=(8, 7), snout=(3, 4),
                  ears="floppy", tail="short", marks=("wool", "dark_face", "dark_legs")),
    "cow": beast(("f2eee6", "d6d0c4", "9e978a"), belly="f8f4ee", length=36, height=16, legs=12, leg_w=3, neck=(2, 5), head=(11, 10),
                 snout=(5, 6), ears="side", horns="short", tail="thin", marks=("patches", "pink_nose")),
    "calf": beast(("d8a878", "b48454", "7a5634"), belly="f0d8b8", length=24, height=12, legs=11, leg_w=2, neck=(2, 4), head=(10, 9),
                  snout=(4, 5), ears="side", tail="thin", marks=("blaze", "pink_nose")),
    "bear": beast(("8a6040", "6a4630", "42281a"), belly="9a7050", length=40, height=22, legs=10, leg_w=5, feet="paw", neck=(0, 3),
                  head=(13, 12), snout=(5, 6), ears="round", tail="short", marks=("muzzle",)),
    "grey_wolf": beast(("a8acb4", "80848e", "50545e"), belly="d8dce0", length=30, height=12, legs=12, leg_w=3, feet="paw", neck=(3, 6),
                       head=(10, 8), snout=(7, 4), ears="pointy", tail="bushy", marks=("saddle", "mask_light"), eye="e8c040"),
    "alpha_wolf": beast(("f4f4f2", "d4d6d8", "9ca0a8"), belly="ffffff", length=36, height=15, legs=14, leg_w=3, feet="paw", neck=(3, 7),
                        head=(12, 10), snout=(8, 5), ears="pointy", tail="bushy", marks=("scar", "mane_ruff"), eye="f0d050", seed=7),
    # --- new: the lands' own beasts
    "elk": beast(("9a7048", "765232", "4a321c"), belly="c8a880", length=36, height=15, legs=17, leg_w=3, neck=(5, 11), head=(11, 9),
                 snout=(7, 5), ears="pointy", horns="broad_antlers", tail="fluffy", mane="5a3a20"),
    "badger": beast(("8e8e8e", "6a6a6a", "3e3e3e"), belly="2a2a2a", length=24, height=10, legs=5, leg_w=3, feet="claw", neck=(0, 1),
                    head=(9, 7), snout=(6, 3), ears="round", tail="short", marks=("badger_stripe",)),
    "hedgehog": beast(("8a6a4a", "6a4e34", "3e2c1c"), belly="d8c0a0", length=14, height=8, legs=3, leg_w=2, feet="paw", neck=(0, 0),
                      head=(7, 6), snout=(4, 2), ears="tiny", tail=None, marks=("spines",)),
    "moonstag": beast(("dce4f4", "b0bcd8", "7480a8"), belly="f4f6fc", length=32, height=13, legs=17, leg_w=2, neck=(4, 11), head=(10, 8),
                      snout=(6, 4), ears="pointy", horns="antlers", horn_col="b8f0ff", tail="fluffy", marks=("stars",), glow="9ae8ff", seed=4),
    "snow_leopard": beast(("e8e8e0", "c8c8bc", "8e8e84"), belly="f8f8f2", length=32, height=11, legs=10, leg_w=3, feet="paw", neck=(2, 4),
                          head=(9, 8), snout=(4, 4), ears="round", tail="long_thick", marks=("rosettes",), eye="8ad0e0"),
    "musk_ox": beast(("5a4636", "44342a", "2a201a"), belly="6a5444", length=38, height=20, legs=9, leg_w=4, neck=(0, 2), head=(12, 11),
                     snout=(4, 6), ears=None, horns="ox", horn_col="c8b898", tail="short", marks=("shag",)),
    "ice_bear": beast(("f4f6f8", "d8dee4", "a0aab4"), belly="ffffff", length=42, height=22, legs=11, leg_w=5, feet="paw", neck=(1, 4),
                      head=(12, 11), snout=(6, 5), ears="round", tail="short", eye="1a1a22"),
    "frostmane": beast(("cce0f0", "9ab8d4", "5a7894"), belly="eef6fc", length=32, height=13, legs=13, leg_w=3, feet="paw", neck=(3, 7),
                       head=(11, 9), snout=(8, 4), ears="pointy", tail="bushy", mane="eaffff", marks=("frost",), glow="bff4ff", eye="7ae8ff", seed=5),
    "camel": beast(("d8b884", "b89460", "7e6238"), belly="ecd4a8", length=36, height=14, legs=18, leg_w=3, neck=(8, 14), head=(10, 7),
                   snout=(6, 5), ears="tiny", tail="thin", marks=("hump",)),
    "sand_cat": beast(("dcc49a", "b89e72", "806a48"), belly="f0e4cc", length=20, height=8, legs=7, leg_w=2, feet="paw", neck=(1, 3),
                      head=(9, 8), snout=(3, 3), ears="big_pointy", tail="long", marks=("faint_stripes",), eye="6aa040"),
    "jackal": beast(("c89a60", "a07440", "6a4a24"), belly="ecd8b0", length=26, height=10, legs=11, leg_w=2, feet="paw", neck=(3, 5),
                    head=(9, 7), snout=(7, 3), ears="big_pointy", tail="bushy", marks=("saddle",), eye="e0a030"),
    "sunscale_basilisk": beast(("e0a040", "b87828", "784a14"), belly="f4d088", length=34, height=9, legs=6, leg_w=3, feet="claw", neck=(2, 2),
                               head=(11, 8), snout=(6, 4), ears=None, horns="crest", horn_col="e04a2a", tail="long_thick", marks=("scales", "spikes"),
                               glow="ffe070", eye="ff6020", seed=3),
    "river_otter": beast(("7a5a3e", "5e442c", "3a2818"), belly="b89a78", length=26, height=8, legs=4, leg_w=2, feet="paw", neck=(1, 2),
                         head=(8, 7), snout=(4, 3), ears="tiny", tail="long_thick"),
    "moss_tortoise": beast(("7a8a4a", "5a6a34", "3a4420"), belly="a89870", length=26, height=13, legs=4, leg_w=4, feet="claw", neck=(2, 1),
                           head=(7, 6), snout=(3, 3), ears=None, tail=None, marks=("shell", "moss")),
    "swamp_boar": beast(("5e5a3a", "46422a", "2a281a"), belly="6e6a4a", length=30, height=15, legs=7, leg_w=3, neck=(0, 2), head=(11, 10),
                        snout=(7, 6), ears="floppy", horns="tusks", tail="curly", mane="1e1c12", marks=("mud",)),
    "sporeback_deer": beast(("a48870", "806650", "524032"), belly="d0bca4", length=30, height=12, legs=16, leg_w=2, neck=(4, 10), head=(10, 8),
                            snout=(6, 4), ears="pointy", horns="mushrooms", horn_col="d070b0", tail="fluffy", marks=("spore_spots",), glow="f0a0e0", seed=6),
    "cinder_hound": beast(("4a3a36", "34282a", "1e1618"), belly="5a4440", length=30, height=12, legs=12, leg_w=3, feet="paw", neck=(3, 6),
                          head=(11, 9), snout=(7, 4), ears="pointy", tail="flame", mane="ff8a30", marks=("embers",), glow="ffb040", eye="ffb040", seed=8),
    "ember_salamander": beast(("d8502a", "a8341c", "6a1e10"), belly="f0a040", length=26, height=7, legs=4, leg_w=2, feet="claw", neck=(1, 1),
                              head=(9, 6), snout=(5, 3), ears=None, tail="long", marks=("spots_bright",), glow="ffd060", eye="ffe080", seed=9),
    "thornback_boar": beast(("6a3a3a", "4e2828", "2e1616"), belly="7a4a44", length=32, height=16, legs=8, leg_w=3, neck=(0, 2), head=(12, 11),
                            snout=(7, 6), ears="floppy", horns="tusks", tail="curly", marks=("thorns",), eye="e04040"),
    "crimson_lynx": beast(("c86a5a", "a04a3e", "682a24"), belly="ecc4b4", length=26, height=10, legs=10, leg_w=3, feet="paw", neck=(2, 4),
                          head=(9, 8), snout=(3, 3), ears="tufted", tail="short", marks=("lynx_spots",), eye="f0e070"),
    "void_prowler": beast(("4a3a6a", "34285a", "1e163a"), belly="5a4a80", length=32, height=11, legs=11, leg_w=3, feet="paw", neck=(2, 4),
                          head=(9, 8), snout=(4, 4), ears="pointy", tail="long_thick", marks=("void_marks",), glow="c07aff", eye="e0a0ff", seed=10),
    "void_hare": beast(("6a5a8a", "4e406e", "2e244a"), belly="9a8abc", length=16, height=9, legs=5, leg_w=2, feet="paw", neck=(1, 3),
                       head=(8, 7), snout=(3, 3), ears="long", tail="fluffy", marks=("void_marks",), glow="d8a0ff", eye="f0c0ff", seed=11),
    "salt_antelope": beast(("e8d8c0", "c8b498", "8a7860"), belly="fbf6ee", length=28, height=11, legs=16, leg_w=2, neck=(4, 9), head=(9, 7),
                           snout=(6, 4), ears="pointy", horns="straight", horn_col="4a3e32", tail="short", marks=("flank_stripe",)),
    "mountain_ram": beast(("c8bca8", "a49884", "6e6452"), belly="e0d8c8", length=30, height=15, legs=12, leg_w=3, neck=(2, 5), head=(10, 9),
                          snout=(5, 5), ears="side", horns="ram", horn_col="9a8a70", tail="short", marks=("wool",)),
    "dawn_unicorn": beast(("fbf8f4", "e4dcd4", "aca29a"), belly="ffffff", length=34, height=14, legs=17, leg_w=3, neck=(6, 12), head=(11, 8),
                          snout=(7, 5), ears="pointy", horns="unicorn", horn_col="f8e0a0", tail="flowing", mane="f0b0d8", glow="fff0c0", eye="4a3a8a", seed=12),
}


# ------------------------------------------------------------------ drawing
def draw(spec, p):
    f = Frame()
    rnd = random.Random(spec["seed"])
    fur, out = spec["fur"], spec["out"]
    dark_fur = tuple(shade(c, 0.78) for c in fur)
    L, H, LL, W = spec["length"], spec["height"], spec["legs"], spec["leg_w"]
    lying = p["lying"]
    cx = 46 + p["bx"]
    bottom = GROUND - (LL if not lying else 1) + p["by"] + (0 if not lying else 0)
    if lying:
        bottom = GROUND - 1
    top = bottom - H
    x0, x1 = cx - L // 2, cx + L // 2
    front_hip, hind_hip = x1 - max(3, L // 5), x0 + max(3, L // 5)
    # Shadow on the ground.
    sw = int(L * 0.55 * p["shadow"])
    ImageDraw.Draw(f.img).ellipse((cx - sw, GROUND - 2, cx + sw, GROUND + 2), fill=(0, 0, 0, 70))

    def leg(hip_x, index, far):
        foot_dx, lift, fold = p["legs"][index]
        ramp = dark_fur if far else fur
        hind = index >= 2
        if lying or fold:
            # Folded under the body: a short stub with the foot tucked.
            y0 = bottom - 3
            f.shape("poly", [(hip_x - W // 2, y0), (hip_x + W // 2 + 1, y0), (hip_x + W // 2 + (2 if not hind else -1), GROUND), (hip_x - W // 2, GROUND)], ramp)
            return
        hip_y = bottom - min(5, H // 3)
        foot_x = hip_x + foot_dx + (1 if far else 0)
        foot_y = GROUND - lift
        knee_y = hip_y + (foot_y - hip_y) * 0.55
        knee_x = (hip_x + foot_x) / 2 + (-1.5 if hind else 0.5)
        w0, w1 = W + 1, max(2, W - 1)
        # A thigh, full where it joins the body, narrowing to the knee.
        f.shape("poly", [(hip_x - w0 / 2 - 1, hip_y - 2), (hip_x + w0 / 2 + 1, hip_y - 2), (knee_x + w1 / 2 + 0.5, knee_y), (knee_x - w1 / 2 - 0.5, knee_y)], ramp)
        f.shape("poly", [(knee_x - w1 / 2, knee_y), (knee_x + w1 / 2, knee_y), (foot_x + w1 / 2, foot_y - 1), (foot_x - w1 / 2, foot_y - 1)], ramp)
        sock = spec["feet_col"] or (C("2a2420") if "dark_legs" in spec["marks"] else None)
        if sock:
            f.fill("rect", (int(foot_x - w1 / 2), int(knee_y + 2), int(foot_x + w1 / 2), int(foot_y - 1)), sock)
        if spec["feet"] == "hoof":
            f.fill("rect", (int(foot_x - w1 / 2), foot_y - 1, int(foot_x + w1 / 2), foot_y), C("2e2420"))
        elif spec["feet"] == "paw":
            f.fill("rect", (int(foot_x - w1 / 2), foot_y - 1, int(foot_x + w1 / 2) + 1, foot_y), shade(ramp[1], 0.9))
        else:
            for k in range(3):
                f.put(foot_x - w1 / 2 + k + 1, foot_y, C("e8dcc0"))

    # Far legs first, darker, then the tail.
    leg(front_hip - 2, 1, True)
    leg(hind_hip - 2, 3, True)
    tdx, tdy = p["tail"]
    tail = spec["tail"]
    tx, ty = x0 + 1, top + max(2, H // 4)
    if tail == "fluffy":
        f.shape("ellipse", (tx - 4 + tdx, ty - 2 + tdy, tx + 1 + tdx, ty + 2 + tdy), (C("ffffff"), C("f0ece4"), C("c8c0b0")))
    elif tail == "short":
        f.shape("poly", [(tx + 1, ty), (tx - 3 + tdx, ty + 2 + tdy), (tx + 1, ty + 3)], fur)
    elif tail == "bushy":
        f.shape("poly", [(tx + 2, ty), (tx - 6 + tdx, ty + 4 + tdy), (tx - 9 + tdx, ty + 9 + tdy), (tx - 4 + tdx, ty + 8 + tdy), (tx + 2, ty + 4)], fur)
        f.fill("poly", [(tx - 9 + tdx, ty + 9 + tdy), (tx - 6 + tdx, ty + 9 + tdy), (tx - 7 + tdx, ty + 7 + tdy)], spec["belly"] or fur[0])
    elif tail == "thin":
        f.fill("line", [(tx, ty), (tx - 3 + tdx, ty + 6 + tdy), (tx - 3 + tdx, ty + 11)], fur[2])
        f.shape("ellipse", (tx - 5 + tdx, ty + 10, tx - 1 + tdx, ty + 14), (fur[2], shade(fur[2], 0.8), shade(fur[2], 0.6)))
    elif tail == "curly":
        f.fill("line", [(tx + 1, ty + 1), (tx - 2, ty), (tx - 3, ty + 2), (tx - 1, ty + 3)], fur[1], width=1)
    elif tail in ("long", "long_thick"):
        w = 3 if tail == "long_thick" else 2
        pts = [(tx + 2, ty + 2), (tx - 6 + tdx, ty + 4 + tdy), (tx - 12 + tdx, ty + 2 + tdy), (tx - 15 + tdx, ty - 2 + tdy)]
        for a, b in zip(pts, pts[1:]):
            f.shape("line", [a, b], fur, width=w)
    elif tail == "flame":
        for k, (dx, dy, c) in enumerate([(-3, -1, "ff8a30"), (-6, -3, "ffb040"), (-8, -6, "ffe080")]):
            f.fill("poly", [(tx + 1, ty + 1), (tx + dx + tdx, ty + dy + tdy - 1), (tx + dx + 2 + tdx, ty + dy + tdy + 2)], C(c))
    elif tail == "flowing":
        for k in range(4):
            f.fill("line", [(tx + 1, ty + k), (tx - 6 + tdx, ty + 6 + k + tdy), (tx - 5 + tdx, ty + 13 + tdy)], spec["mane"] or fur[1])

    # The body: a haunch behind, a deep chest in front, the barrel between,
    # lit from the upper left, with a lighter belly.
    if "shell" in spec["marks"] or L < 18:
        f.shape("ellipse", (x0, top, x1, bottom), fur)
    else:
        haunch = (x0, top, x0 + int(L * 0.48), bottom - 1)
        chest = (x1 - int(L * 0.46), top - 1, x1, bottom)
        barrel = (x0 + int(L * 0.18), top + 1, x1 - int(L * 0.18), bottom - 1)
        pts = set(f.mask("ellipse", haunch)) | set(f.mask("ellipse", chest)) | set(f.mask("rect", barrel))
        # Shade the whole as one shape so the joins do not show.
        xs = [q[0] for q in pts]
        ys = [q[1] for q in pts]
        cxm, cym = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        rx, ry = max((max(xs) - min(xs)) / 2, 1), max((max(ys) - min(ys)) / 2, 1)
        for (x, y) in pts:
            t = (x - cxm) / rx * -0.45 + (y - cym) / ry * -0.9
            f.put(x, y, fur[0] if t > 0.38 else fur[2] if t < -0.3 else fur[1])
        # A soft crease where the haunch meets the barrel.
        hx_mid = x0 + int(L * 0.42)
        for y in range(top + 3, bottom - 2):
            if (hx_mid, y) in f.filled and y % 2 == 0:
                f.put(hx_mid, y, shade(fur[1], 0.86))
    if spec["belly"] and "shell" not in spec["marks"]:
        f.fill("ellipse", (x0 + L // 5, bottom - H // 3, x1 - L // 5, bottom), spec["belly"])
        f.fill("ellipse", (x0 + L // 5, bottom - H // 3 - 1, x1 - L // 5, bottom - H // 3 + 1), mix(spec["belly"], fur[1], 0.5))
    marks(f, spec, x0, x1, top, bottom, rnd)

    # Near legs over the body.
    if not lying:
        leg(front_hip, 0, False)
        leg(hind_hip, 2, False)
    else:
        leg(front_hip, 0, False)
        leg(hind_hip, 2, False)

    # Neck and head.
    nx, ny = spec["neck"]
    hw, hh = spec["head"]
    hx = x1 + nx + p["hx"] - (2 if lying else 0)
    hy = top - ny + p["hy"] + hh // 2 + (2 if lying else 0)
    neck_w = max(4, int(hh * 0.65))
    # The neck grows from the shoulders, thick at its root, to the back of the head.
    root_x = x1 - max(4, L // 4)
    f.shape("poly", [(root_x - 1, top + 3), (root_x + neck_w - 1, top - 1), (hx + 2, hy - hh // 2 + 1), (hx + 2, hy + hh // 2 - 1),
                     (x1 - 1, top + H // 2), (root_x + 2, top + H // 2)], fur)
    if spec["mane"]:
        f.fill("line", [(x1 - L // 4 + 1, top), (hx - 1, hy - hh // 2)], spec["mane"], width=2)
    head(f, spec, p, hx, hy, rnd)
    f.outline(out)
    # Magic beasts glow: a few bright pixels that are not outlined.
    if spec["glow"]:
        g = spec["glow"]
        for _ in range(6):
            x, y = rnd.randrange(x0 + 2, x1 - 2), rnd.randrange(top + 1, bottom - 2)
            if (x, y) in f.filled:
                f.img.putpixel((x, y), g)
    return f.img


def marks(f, spec, x0, x1, top, bottom, rnd):
    m = spec["marks"]
    fur = spec["fur"]
    L = x1 - x0
    H = bottom - top
    inside = lambda x, y: (x, y) in f.filled
    if "spots" in m or "stars" in m or "spore_spots" in m or "spots_bright" in m:
        col = {"stars": C("ffffff"), "spore_spots": C("f0a0e0"), "spots_bright": C("ffe070")}.get(next((k for k in m if k.endswith("spots") or k == "stars"), ""), C("f4eadc"))
        for _ in range(7):
            x, y = rnd.randrange(x0 + 3, x1 - 4), rnd.randrange(top + 2, top + H // 2)
            if inside(x, y):
                f.put(x, y, col)
                if rnd.random() < 0.4 and inside(x + 1, y):
                    f.put(x + 1, y, col)
    if "saddle" in m:
        f.fill("ellipse", (x0 + L // 6, top, x1 - L // 4, top + H // 2), shade(fur[2], 0.85))
    if "patches" in m:
        for (px, py, r) in [(x0 + L // 4, top + H // 3, 5), (x1 - L // 3, top + H // 2, 4), (x0 + L // 2, top + 2, 3)]:
            f.fill("ellipse", (px - r, py - r + 1, px + r, py + r - 1), C("4a3a30"))
    if "wool" in m:
        for _ in range(int(L * H / 7)):
            x, y = rnd.randrange(x0, x1), rnd.randrange(top, bottom)
            if inside(x, y):
                f.put(x, y, fur[0] if rnd.random() < 0.5 else fur[2])
    if "stripes" in m or "faint_stripes" in m or "bands" in m:
        col = shade(fur[2], 0.7 if "stripes" in m or "bands" in m else 0.9)
        for k in range(x0 + 4, x1 - 3, 4):
            for y in range(top, top + H * 2 // 3):
                if inside(k + (y - top) // 4, y):
                    f.put(k + (y - top) // 4, y, col)
    if "rosettes" in m or "lynx_spots" in m:
        for _ in range(9):
            x, y = rnd.randrange(x0 + 3, x1 - 3), rnd.randrange(top + 2, bottom - 3)
            if inside(x, y) and inside(x + 1, y + 1):
                f.put(x, y, shade(fur[2], 0.6))
                if "rosettes" in m:
                    f.put(x + 1, y + 1, shade(fur[2], 0.6))
    if "spines" in m:
        for k in range(x0, x1 - 2, 2):
            f.fill("line", [(k, top + 3), (k - 2, top - 2)], C("3a2a1c"))
            f.put(k - 2, top - 2, C("e8dcc0"))
    if "shell" in m:
        shell = (C("8a7a4a"), C("6a5a34"), C("4a3e22"))
        f.shape("ellipse", (x0 - 1, top - 3, x1 + 1, bottom - 2), shell)
        for k in range(x0 + 3, x1 - 2, 6):
            f.fill("line", [(k, top - 1), (k + 2, bottom - 4)], C("3a301a"))
        if "moss" in m:
            for _ in range(14):
                x, y = rnd.randrange(x0, x1), rnd.randrange(top - 3, top + 2)
                if inside(x, y):
                    f.put(x, y, C("7ab04a") if rnd.random() < 0.6 else C("4e8a34"))
    if "hump" in m:
        f.shape("ellipse", (x0 + L // 4, top - 7, x0 + L // 2 + 4, top + 4), fur)
    if "shag" in m:
        for k in range(x0, x1, 2):
            f.fill("line", [(k, bottom - 2), (k + 1, bottom + 4)], shade(fur[2], 0.8))
    if "thorns" in m:
        for k in range(x0 + 2, x1 - 4, 4):
            f.fill("poly", [(k, top + 2), (k + 2, top - 5), (k + 3, top + 2)], C("4a6a2a"))
    if "spikes" in m:
        for k in range(x0 + 2, x1 - 3, 3):
            f.fill("poly", [(k, top + 1), (k + 1, top - 3), (k + 2, top + 1)], C("e04a2a"))
    if "scales" in m:
        for y in range(top + 2, bottom - 2, 3):
            for x in range(x0 + 2 + (y % 2) * 2, x1 - 2, 4):
                if inside(x, y):
                    f.put(x, y, shade(fur[1], 0.8))
    if "embers" in m or "void_marks" in m or "frost" in m:
        col = {"embers": C("ff9030"), "void_marks": C("b06aff"), "frost": C("ffffff")}[next(k for k in ("embers", "void_marks", "frost") if k in m)]
        for _ in range(5):
            x, y = rnd.randrange(x0 + 3, x1 - 3), rnd.randrange(top + 2, bottom - 3)
            if inside(x, y):
                f.fill("line", [(x, y), (x + 2, y + 1)], col)
    if "mud" in m:
        f.fill("rect", (x0, bottom - 3, x1, bottom), C("3a3020"))
    if "badger_stripe" in m:
        f.fill("rect", (x0 + 1, top + 1, x1, top + 2), C("e8e8e8"))
    if "flank_stripe" in m:
        f.fill("rect", (x0 + 3, top + H // 2, x1 - 4, top + H // 2 + 1), C("6a5038"))
    if "scar" in m:
        f.fill("line", [(x1 - L // 3, top + 2), (x1 - L // 3 + 4, top + 6)], C("9a5050"))
    if "mane_ruff" in m:
        for k in range(5):
            f.fill("poly", [(x1 - 9 + k * 2, top + 1), (x1 - 8 + k * 2, top - 3), (x1 - 6 + k * 2, top + 1)], fur[0])
    # Fur texture: short strokes along the back in the dark tone.
    for k in range(x0 + 3, x1 - 3, 3):
        y = top + 2 + (k % 2)
        if inside(k, y) and "shell" not in m:
            f.put(k, y, fur[2] if "wool" not in m else fur[1])


def head(f, spec, p, hx, hy, rnd):
    fur = spec["fur"]
    hw, hh = spec["head"]
    sl, sh = spec["snout"]
    x0, y0 = hx - hw // 2, hy - hh // 2
    # Ears and horns behind the head go first.
    ears = spec["ears"]
    flick = p["ear"]
    if ears in ("pointy", "big_pointy", "tufted"):
        tall = 6 if ears == "pointy" else 8
        f.shape("poly", [(x0 + 1, y0 + 2), (x0 + 2 - flick, y0 - tall), (x0 + 5, y0 + 1)], fur)
        f.fill("poly", [(x0 + 2, y0 + 1), (x0 + 2 - flick, y0 - tall + 3), (x0 + 4, y0 + 1)], C("e0a8a0") if ears != "tufted" else fur[2])
        if ears == "tufted":
            f.put(x0 + 2 - flick, y0 - tall - 1, C("2a1a14"))
            f.put(x0 + 2 - flick, y0 - tall - 2, C("2a1a14"))
    elif ears == "round":
        f.shape("ellipse", (x0, y0 - 3, x0 + 5, y0 + 2), fur)
        f.fill("ellipse", (x0 + 1, y0 - 2, x0 + 3, y0), shade(fur[2], 0.8))
    elif ears == "long":
        f.shape("poly", [(x0 + 1, y0 + 2), (x0 - 1 - flick, y0 - 10), (x0 + 2 - flick, y0 - 11), (x0 + 4, y0 + 1)], fur)
        f.fill("line", [(x0 + 1 - flick, y0 - 8), (x0 + 2, y0)], C("e0a8a0"))
    elif ears in ("floppy", "side"):
        drop = 4 if ears == "floppy" else 1
        f.shape("poly", [(x0 + 1, y0 + 1), (x0 - 4, y0 + drop - flick), (x0 - 3, y0 + drop + 2), (x0 + 2, y0 + 3)], fur)
    elif ears == "tiny":
        f.shape("ellipse", (x0 + 1, y0 - 1, x0 + 3, y0 + 1), fur)
    horns = spec["horns"]
    hc = spec["horn_col"]
    hr = (hc, shade(hc, 0.82), shade(hc, 0.62))
    if horns in ("antlers", "broad_antlers"):
        span = 9 if horns == "antlers" else 12
        base = (x0 + 4, y0)
        f.shape("line", [base, (x0 + 1, y0 - span), (x0 - 3, y0 - span - 3)], hr, width=2 if horns == "broad_antlers" else 1)
        for k in (3, 6, 9)[: 3 if horns == "broad_antlers" else 2]:
            f.fill("line", [(x0 + 3 - k // 3, y0 - k), (x0 + 6 - k // 3, y0 - k - 3)], hc)
        if horns == "broad_antlers":
            f.fill("poly", [(x0 - 3, y0 - span - 3), (x0 - 8, y0 - span - 1), (x0 - 7, y0 - span - 5)], hr[1])
    elif horns == "curved":
        f.shape("line", [(x0 + 4, y0 + 1), (x0 + 2, y0 - 5), (x0 - 3, y0 - 6), (x0 - 5, y0 - 3)], hr, width=2)
    elif horns == "ram":
        f.shape("ellipse", (x0 - 2, y0 - 2, x0 + 6, y0 + 6), hr)
        f.fill("ellipse", (x0 + 1, y0 + 1, x0 + 3, y0 + 3), hr[2])
    elif horns == "short":
        f.shape("poly", [(x0 + 3, y0 + 1), (x0 + 1, y0 - 4), (x0 + 5, y0)], hr)
    elif horns == "straight":
        f.shape("line", [(x0 + 4, y0), (x0, y0 - 11)], hr, width=2)
    elif horns == "ox":
        f.shape("poly", [(x0 + 2, y0 + 1), (x0 - 4, y0 + 3), (x0 - 5, y0 - 1), (x0 + 4, y0 - 2)], hr)
    elif horns == "unicorn":
        f.shape("poly", [(hx + 1, y0 + 1), (hx + 7, y0 - 11), (hx + 4, y0 + 1)], hr)
        for k in range(3):
            f.put(hx + 3 + k, y0 - 2 - k * 3, shade(hc, 0.7))
    elif horns == "crest":
        for k in range(3):
            f.fill("poly", [(x0 + k * 3, y0 + 1), (x0 + k * 3 + 1, y0 - 5 + k), (x0 + k * 3 + 3, y0 + 1)], hc)
    elif horns == "mushrooms":
        for (dx, h) in ((1, 7), (5, 5)):
            f.fill("line", [(x0 + dx, y0), (x0 + dx, y0 - h)], C("e8dcc8"))
            f.shape("ellipse", (x0 + dx - 3, y0 - h - 3, x0 + dx + 3, y0 - h + 1), hr)
            f.put(x0 + dx - 1, y0 - h - 2, C("ffffff"))
    # The head and its snout.
    f.shape("ellipse", (x0, y0, x0 + hw, y0 + hh), fur)
    sx0 = x0 + hw - 3
    snout_col = spec["belly"] or fur[0]
    if "dark_face" in spec["marks"]:
        snout_col = C("3a302a")
        f.shape("ellipse", (x0 + 1, y0 + 1, x0 + hw, y0 + hh), (C("4a3e36"), C("3a302a"), C("2a221e")))
    if "muzzle" in spec["marks"] or "mask_light" in spec["marks"]:
        snout_col = C("c8a880") if "muzzle" in spec["marks"] else C("e8eaee")
    f.shape("ellipse", (sx0, y0 + hh - sh - 1, sx0 + sl + 3, y0 + hh), (snout_col, shade(snout_col, 0.9), shade(snout_col, 0.75)))
    if "blaze" in spec["marks"]:
        f.fill("line", [(x0 + hw // 2 + 1, y0 + 1), (sx0 + sl, y0 + hh - 2)], C("f8f2e8"), width=2)
    if "beard" in spec["marks"]:
        f.fill("poly", [(sx0 + 1, y0 + hh), (sx0 + 3, y0 + hh + 4), (sx0 + 4, y0 + hh)], spec["fur"][1])
    if horns == "tusks":
        f.fill("line", [(sx0 + sl - 1, y0 + hh - 1), (sx0 + sl + 1, y0 + hh - 4)], C("f4ecd8"), width=1)
    # Nose, mouth and eye.
    nose = C("e8a0a0") if "pink_nose" in spec["marks"] or spec["feet"] == "hoof" and horns in (None, "short") and "wool" not in spec["marks"] and "dark_face" not in spec["marks"] and False else C("1e1614")
    if "pink_nose" in spec["marks"]:
        nose = C("e09a9a")
    f.put(sx0 + sl + 2, y0 + hh - sh, nose)
    f.put(sx0 + sl + 2, y0 + hh - sh + 1, nose)
    if p["mouth"]:
        f.fill("line", [(sx0 + 1, y0 + hh - 1), (sx0 + sl + 1, y0 + hh - 1)], C("2a1414"))
        f.put(sx0 + sl, y0 + hh, C("c84a4a"))
    ex, ey = x0 + hw // 2 + 1, y0 + hh // 2 - 1
    if p["eye"] == "open":
        f.put(ex, ey, spec["eye"])
        f.put(ex, ey + 1, spec["eye"])
        if hw >= 11:
            f.put(ex + 1, ey, spec["eye"])
            f.put(ex + 1, ey + 1, spec["eye"])
        f.put(ex, ey, C("ffffff") if spec["eye"][0] < 120 else shade(spec["eye"], 1.3))
    elif p["eye"] == "shut":
        f.fill("line", [(ex - 1, ey + 1), (ex + 1, ey + 1)], C("2a1e1a"))
    else:
        f.put(ex - 1, ey, C("2a1e1a"))
        f.put(ex + 1, ey + 2, C("2a1e1a"))
        f.put(ex, ey + 1, C("2a1e1a"))
        f.put(ex + 1, ey, C("2a1e1a"))
        f.put(ex - 1, ey + 2, C("2a1e1a"))


def draw_back(spec, p):
    """The beast walking away, seen from behind: its rump and tail, the hind
    legs in front and the forelegs (darker) between them, and over the
    back, the back of its head with ears and horns. Moved by the same poses."""
    f = Frame()
    fur, out = spec["fur"], spec["out"]
    dark_fur = tuple(shade(c, 0.72) for c in fur)
    L, H, LL, W = spec["length"], spec["height"], spec["legs"], spec["leg_w"]
    cx = 48
    bottom = GROUND - LL + p["by"]
    top = bottom - H
    half = max(5, int(max(H * 0.62, L * 0.24)))
    sw = half + 3
    ImageDraw.Draw(f.img).ellipse((cx - sw, GROUND - 2, cx + sw, GROUND + 2), fill=(0, 0, 0, 70))

    def leg(x, lift, ramp):
        w = max(2, W)
        foot = GROUND - lift
        f.shape("poly", [(x - w / 2 - 1, bottom - 3), (x + w / 2 + 1, bottom - 3), (x + w / 2, foot - 1), (x - w / 2, foot - 1)], ramp)
        if spec["feet"] == "hoof":
            f.fill("rect", (int(x - w / 2), foot - 1, int(x + w / 2), foot), C("2e2420"))
        else:
            f.fill("rect", (int(x - w / 2), foot - 1, int(x + w / 2), foot), shade(ramp[1], 0.85))

    legs = p["legs"]
    # Forelegs, further away, between the hind ones.
    leg(cx - half // 2 + 1, legs[1][1], dark_fur)
    leg(cx + half // 2 - 1, legs[0][1], dark_fur)
    # The head over the back: no face from here, just its back and ears.
    hw, hh = max(4, spec["head"][0] * 2 // 3), max(4, spec["head"][1] * 3 // 4)
    hy = top - hh + 3 + p["hy"] // 2
    f.shape("ellipse", (cx - hw, hy, cx + hw, hy + hh * 2 - 2), fur)
    ears = spec["ears"]
    for side in (-1, 1):
        ex = cx + side * (hw - 1)
        if ears in ("pointy", "big_pointy", "tufted"):
            tall = 5 if ears != "big_pointy" else 8
            f.shape("poly", [(ex - 2, hy + 2), (ex + side * 2, hy - tall), (ex + 2, hy + 2)], fur)
            if ears == "tufted":
                f.put(ex + side * 2, hy - tall - 1, out)
        elif ears == "long":
            f.shape("poly", [(ex - 1, hy + 2), (ex + side * 2, hy - 11), (ex + side * 3 + 1, hy - 10), (ex + 2, hy + 2)], fur)
        elif ears == "round":
            f.shape("ellipse", (ex - 2, hy - 3, ex + 2, hy + 1), fur)
        elif ears == "floppy":
            f.shape("poly", [(ex, hy + 1), (ex + side * 4, hy + 2), (ex + side * 3, hy + 6), (ex, hy + 4)], dark_fur)
        elif ears == "side":
            f.shape("poly", [(ex, hy + 2), (ex + side * 4, hy), (ex + side * 4, hy + 2)], fur)
    horns = spec["horns"]
    hc = (shade(spec["horn_col"], 1.15), spec["horn_col"], shade(spec["horn_col"], 0.7))
    if horns in ("antlers", "broad_antlers"):
        spread = 9 if horns == "broad_antlers" else 7
        for side in (-1, 1):
            bx = cx + side * 2
            f.fill("line", (bx, hy, bx + side * spread, hy - 9), hc[1], 2)
            f.fill("line", (bx + side * (spread // 2), hy - 4, bx + side * (spread // 2 - 2), hy - 10), hc[0], 1)
            f.fill("line", (bx + side * spread, hy - 9, bx + side * (spread + 2), hy - 13), hc[0], 1)
    elif horns in ("ox", "curved", "ram", "short", "straight"):
        for side in (-1, 1):
            bx = cx + side * (hw - 2)
            if horns == "ram":
                f.shape("ellipse", (bx - 2 + side * 2, hy - 1, bx + 2 + side * 2, hy + 4), hc)
            elif horns == "ox":
                f.fill("line", (bx, hy + 1, bx + side * 5, hy - 2), hc[1], 2)
            else:
                f.fill("line", (bx, hy + 1, bx + side * 2, hy - 6), hc[1], 2)
    elif horns == "unicorn":
        f.fill("line", (cx, hy, cx + 1, hy - 9), hc[0], 1)
    if spec["mane"]:
        f.fill("rect", (cx - 1, hy + hh - 2, cx + 1, top + 3), spec["mane"])
    # The body from behind: a broad rump, a darker line down the spine.
    f.shape("ellipse", (cx - half, top, cx + half, bottom + 2), fur)
    f.fill("line", (cx, top + 1, cx, top + H // 3), shade(fur[1], 0.85))
    # Hind legs, nearest of all.
    leg(cx - half + 2, legs[3][1], fur)
    leg(cx + half - 2, legs[2][1], fur)
    # The tail, on the rump.
    tail = spec["tail"]
    sway = p["tail"][1] - p["tail"][0]
    ty = top + max(2, H // 4)
    if tail in ("short", "curly"):
        f.shape("ellipse", (cx - 2, ty - 1, cx + 2, ty + 3), dark_fur if tail == "short" else fur)
    elif tail in ("fluffy", "bushy"):
        f.shape("ellipse", (cx - 3 + sway, ty - 2, cx + 3 + sway, ty + 5), (C("f6f2ea"), shade(C("f6f2ea"), 0.9), shade(C("f6f2ea"), 0.75)) if tail == "fluffy" else fur)
    elif tail in ("long", "long_thick", "thin", "flowing"):
        w = 3 if tail == "long_thick" else 2 if tail != "thin" else 1
        f.fill("line", (cx, ty, cx + sway * 2, bottom + 6), shade(fur[1], 0.9), w)
    elif tail == "flame":
        f.shape("ellipse", (cx - 2 + sway, ty - 3, cx + 2 + sway, ty + 4), (C("ffe080"), C("ff9a30"), C("d05020")))
    if "spikes" in spec["marks"]:
        # A ridge of spines down the back, seen end on.
        spine = (C("f0e8d8"), C("c8bca8"), C("8a8070"))
        for k, dx in enumerate((-half + 3, -2, 3, half - 4)):
            tall = 4 if k in (1, 2) else 3
            f.shape("poly", [(cx + dx - 1, top + 2), (cx + dx, top - tall), (cx + dx + 2, top + 2)], spine)
    if spec["glow"]:
        f.put(cx - 2, top + 3, spec["glow"])
        f.put(cx + 3, top + 5, spec["glow"])
        f.put(cx, top + H // 2, spec["glow"])
        f.put(cx - half + 3, top + H // 2 + 1, spec["glow"])
    f.outline(out)
    return f.img


BACK_ROWS = [("idle", 4), ("walk", 8)]


def sheet(spec):
    out = Image.new("RGBA", (8 * F, (len(ROWS) + len(BACK_ROWS)) * F), (0, 0, 0, 0))
    for row, (name, count) in enumerate(ROWS):
        frames = ANIMS[name]
        for col in range(count):
            out.paste(draw(spec, frames[col % len(frames)]), (col * F, row * F))
    # Rows 9 and 10: walking away (EnemyAnimator.BACK_ROWS).
    for k, (name, count) in enumerate(BACK_ROWS):
        frames = ANIMS[name]
        for col in range(count):
            out.paste(draw_back(spec, frames[col % len(frames)]), (col * F, (len(ROWS) + k) * F))
    return out


def main(only=None):
    os.makedirs(ROOT, exist_ok=True)
    for name, spec in SPECIES.items():
        if only and name not in only:
            continue
        sheet(spec).save(os.path.join(ROOT, name + ".png"))
    print("beasts drawn:", ", ".join(n for n in SPECIES if not only or n in only))


if __name__ == "__main__":
    import sys
    main(sys.argv[1:] or None)
