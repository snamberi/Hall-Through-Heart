"""Adds walking-away rows to the two-legged and floating monsters' sheets:
row 9 "idle_back" and row 10 "walk_back", the same rigs and poses as the
front rows, seen from behind: no face (eyes, mouths, teeth, glows on the
head are left off) and the near arm tucked behind the body. The game plays
them while a monster heads up the screen (EnemyAnimator).

The sheets' first nine rows are kept exactly as they are.

Run from the repository root:  python3 tools/generate_back_views.py [name ...]
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_art as GA  # noqa: E402
import generate_goblins  # noqa: E402,F401  (its palette and rigs)
import generate_minions  # noqa: E402,F401

# What a face is made of: on the head these are left off from behind.
FACE = {"eye", "void", "mouth", "tooth", "glow_red", "glow_cyan", "glow_orange", "catchlight", "shine", "gob_eye",
        "necro_glow", "arcana_glow", "spark", "gill", "skin_shade", "gob_ear", "blood", "heart_glow", "war_paint"}
ROWS_BEFORE = 9


def away(rig):
    """The rig seen from behind: the face gone from the head."""
    turned = {}
    for name, group in rig.items():
        parts = group["parts"]
        if name == "head":
            parts = [p for p in parts if p[0] not in FACE]
        turned[name] = dict(group, parts=parts)
    return turned


def back_order(order):
    """The near arm (or wing) goes behind the body from this side."""
    order = list(order)
    for near, body in (("front_arm", "back_arm"), ("wing_f", "wing_b")):
        if near in order:
            order.remove(near)
            order.insert(order.index(body) + 1 if body in order else 0, near)
    return order


def rigs():
    found = {}
    for name, (rig, order, animations) in GA.MONSTERS.items():
        if order in (GA.HUSK_ORDER, GA.FLOAT_ORDER):
            found[name] = (rig, order, animations)
    found["husk"] = (GA.HUSK, GA.HUSK_ORDER, GA.HUSK_ANIMATIONS)
    for name, rig in generate_goblins.GOBLINS.items():
        found[name] = (rig, GA.HUSK_ORDER, GA.HUSK_ANIMATIONS)
    for name, entry in generate_minions.MINIONS.items():
        found[name] = entry
    return found


def main(only=()):
    out = os.path.join(GA.ROOT, "sprites", "enemies")
    done = 0
    for name, (rig, order, animations) in rigs().items():
        if only and name not in only:
            continue
        path = os.path.join(out, name + ".png") if name != "husk" else os.path.join(GA.ROOT, "sprites", "husk_sheet.png")
        if not os.path.exists(path):
            continue
        old = Image.open(path).convert("RGBA")
        poses = dict(animations)
        back = GA.draw_sheet(away(rig), back_order(order), [("idle_back", poses["idle"]), ("walk_back", poses["walk"])], rich=True)
        sheet = Image.new("RGBA", (max(old.width, back.width), (ROWS_BEFORE + 2) * GA.FRAME), (0, 0, 0, 0))
        sheet.paste(old.crop((0, 0, old.width, ROWS_BEFORE * GA.FRAME)), (0, 0))
        sheet.paste(back, (0, ROWS_BEFORE * GA.FRAME))
        sheet.save(path)
        done += 1
    print("back views:", done)


# The four-legged hunters drawn on the monster rigs get their rear views from
# the beast drawer (tools/generate_beasts.py), in colours taken from their own
# sheets so they match.
QUADS = {
    "rot_hound": dict(length=28, height=11, legs=11, ears="pointy", tail="thin", feet="paw", marks=("spikes",), glow="e04040"),
    "frost_wolf": dict(length=30, height=12, legs=12, ears="pointy", tail="bushy", feet="paw", marks=("spikes",), glow="8ad8ff"),
    "dire_boar": dict(length=30, height=15, legs=8, ears="side", tail="short", feet="hoof", horns="tusks", marks=("spikes",)),
    "thorn_stalker": dict(length=30, height=12, legs=12, ears="tufted", tail="long", feet="claw", marks=("spikes",), glow="7aff6a"),
    "void_stalker": dict(length=30, height=12, legs=13, ears="big_pointy", tail="long", feet="claw", marks=("spikes",), glow="c070ff"),
    "bog_lurker": dict(length=32, height=13, legs=7, ears="tiny", tail="long_thick", feet="claw"),
}


def palette_of(sheet):
    """The three main tones of a creature's coat, light to dark."""
    frame = sheet.crop((0, 0, GA.FRAME, GA.FRAME)).convert("RGBA")
    counts = {}
    for r, g, b, a in frame.getdata():
        if a < 250:
            continue
        key = (r // 12 * 12, g // 12 * 12, b // 12 * 12)
        counts[key] = counts.get(key, 0) + 1
    tones = [c for c, _n in sorted(counts.items(), key=lambda kv: -kv[1])]
    # Drop the near-black outline; keep the commonest coat colours.
    tones = [c for c in tones if sum(c) > 90][:3] or [(120, 110, 100)]
    while len(tones) < 3:
        tones.append(tuple(int(v * 0.75) for v in tones[-1]))
    tones.sort(key=lambda c: -sum(c))
    return tuple("%02x%02x%02x" % c for c in tones)


def quad_backs(only=()):
    import generate_beasts as BE
    out = os.path.join(GA.ROOT, "sprites", "enemies")
    for name, shape in QUADS.items():
        if only and name not in only:
            continue
        path = os.path.join(out, name + ".png")
        old = Image.open(path).convert("RGBA")
        spec = BE.beast(palette_of(old), **shape)
        sheet = Image.new("RGBA", (old.width, (ROWS_BEFORE + 2) * GA.FRAME), (0, 0, 0, 0))
        sheet.paste(old.crop((0, 0, old.width, ROWS_BEFORE * GA.FRAME)), (0, 0))
        for k, (anim, count) in enumerate(BE.BACK_ROWS):
            frames = BE.ANIMS[anim]
            for col in range(count):
                sheet.paste(BE.draw_back(spec, frames[col % len(frames)]), (col * GA.FRAME, (ROWS_BEFORE + k) * GA.FRAME))
        sheet.save(path)
    print("four-legged back views:", len(QUADS))


if __name__ == "__main__":
    main(set(sys.argv[1:]))
    quad_backs(set(sys.argv[1:]))
