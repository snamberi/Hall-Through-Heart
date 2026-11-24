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


if __name__ == "__main__":
    main(set(sys.argv[1:]))
