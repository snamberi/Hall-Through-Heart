#!/usr/bin/env python3
"""Draws the animals (wild game and farm beasts) into assets/sprites/enemies/.

Each is drawn at the size it is shown in the game (its size from
scripts/enemies/enemy_db.gd, a fifth larger than before): the rig's
shapes are scaled before they are rasterised, so an animal is drawn big
pixel by pixel and never stretched afterwards (the game shows wildlife at
scale 1). Legs are shaped (a thigh, a narrower cannon, a knee or hock,
the hoof or paw), and each beast gets a few touches of its own.

Run from the project folder:  python3 tools/generate_animals.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_art as GA  # noqa: E402

E, R = GA.E, GA.R
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
## How much bigger than their old size the animals now appear.
GROWTH = 1.2
## The biggest an animal may be drawn and still fit its 96-pixel frame.
LIMIT = 1.62


def sizes():
    """Each animal's size, read from the game's own table."""
    text = open(os.path.join(ROOT, "scripts", "enemies", "enemy_db.gd")).read()
    out = {}
    for match in re.finditer(r'\t"([a-z_]+)": \{(.*?)\n\t\},', text, re.S):
        found = re.search(r'"size": ([0-9.]+)', match.group(2))
        if found:
            out[match.group(1)] = float(found.group(1))
    return out


def shaped_leg(polygon):
    """A plain upright box leg becomes a shaped one: full at the top,
    narrowing below the knee, with a little bulge at the joint."""
    xs = [p[0] for p in polygon]
    ys = [p[1] for p in polygon]
    if len(polygon) != 4 or len(set(round(x, 2) for x in xs)) != 2 or len(set(round(y, 2) for y in ys)) != 2:
        return polygon
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    w = x1 - x0
    if y1 - y0 < 6 or w > 6:
        return polygon
    knee = y0 + (y1 - y0) * 0.55
    return [(x0 - 0.2, y0), (x1 + 0.2, y0), (x1, knee - 1), (x1 + 0.2, knee), (x1 - w * 0.18, y1), (x0 + w * 0.22, y1),
            (x0 + w * 0.1, knee), (x0, knee - 1)]


EXTRAS = {
    # Dappled flanks and a dark eye-line.
    "deer": {"body": [("eye_white", E(13, 20, 15, 22)), ("eye_white", E(19, 19.5, 21, 21.5)), ("eye_white", E(25, 20, 27, 22)),
                      ("eye_white", E(16, 23, 17.6, 24.6))]},
    "cow": {"head": [("void", R(36, 22.5, 37, 23.5))]},
    "sheep": {"head": [("eye_white", R(33.6, 23.6, 34.4, 24.4))]},
    "bear": {"body": [("bear_muzzle", E(8, 15, 16, 20))]},
    "grey_wolf": {"body": [("wolf_fur", [(27, 19), (31, 16), (33, 22), (30, 25)])]},
    "wild_pig": {"body": [("bristle", [(28, 21), (31, 18), (33, 22)])]},
}


def improved(name, rig, size):
    out = {}
    for group, data in rig.items():
        parts = []
        for material, polygon in data["parts"]:
            if group.startswith("leg"):
                polygon = shaped_leg(polygon)
            parts.append((material, polygon))
        parts += EXTRAS.get(name, {}).get(group, [])
        out[group] = dict(data, parts=parts)
    scale = min(size * GROWTH, LIMIT)

    def pt(p):
        return (22.0 + (p[0] - 22.0) * scale, 41.0 + (p[1] - 41.0) * scale)
    return {group: dict(data, pivot=pt(data["pivot"]), parts=[(m, [pt(p) for p in poly]) for m, poly in data["parts"]])
            for group, data in out.items()}, scale


def main():
    table = sizes()
    out = os.path.join(GA.ROOT, "sprites", "enemies")
    drawn = []
    for name, (rig, order, animations) in GA.WILDLIFE.items():
        size = table.get(name, 1.0)
        big, scale = improved(name, rig, size)
        anims = [(n, [dict(p, shadow=(22, round(p.get("shadow", (22, 9))[1] * scale), 0)) for p in poses]) for n, poses in animations]
        GA.draw_sheet(big, order, anims, rich=True).save(os.path.join(out, name + ".png"))
        drawn.append("%s x%.2f" % (name, scale))
    print("animals drawn: " + ", ".join(drawn))


if __name__ == "__main__":
    main()
