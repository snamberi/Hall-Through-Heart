#!/usr/bin/env python3
"""Draws the mounts into assets/sprites/mounts/: a horse in its tack, the
pony, the sand strider, the nightmare and the frost elk.

Each is built at its own size: the rig's shapes are scaled about the
hooves before they are rasterised, so a big horse is drawn big pixel by
pixel (never a small one stretched). Each has its own coat and mane rather
than a tint, a saddle on a blanket with girth, stirrup, bridle and reins,
slim legs with fetlocks and hooves, and besides the usual rows a gallop.

Run from the project folder:  python3 tools/generate_mounts.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_art as GA  # noqa: E402

E, R = GA.E, GA.R

GA.PALETTE.update({
    "bay": ["9a6440", "74482c", "4e2e1c"],
    "bay_mane": ["3a2a22", "2a1e18", "1a120e"],
    "cream": ["e4c89a", "c0a070", "8e7448"],
    "cream_mane": ["f4eee0", "d0c8b8", "a0988a"],
    "dune": ["e0b468", "b88a44", "86602c"],
    "dune_stripe": ["8a5a2c", "6a421e", "4a2c12"],
    "dune_mane": ["f0d8a0", "c8ac70", "947c48"],
    "night": ["443a52", "2e2638", "1c1624"],
    "night_mane": ["d8a0ff", "9a58e8", "6030b0"],
    "saddle": ["7a4a2c", "5a3420", "3a2014"],
    "blanket_red": ["b8404a", "8a2c37", "5c1c28"],
    "blanket_blue": ["4a6ab0", "33508a", "223660"],
    "blanket_sand": ["40a0a0", "2a7a7a", "1c5454"],
    "blanket_black": ["5a2a3a", "3e1c28", "28121a"],
})
for material in ("bay", "cream", "dune", "night"):
    GA.TEXTURES["fur"].append(material)
GA.TEXTURE_OF.update({m: "fur" for m in ("bay", "cream", "dune", "night")})


def horse(coat, mane, blanket, stripes=None, eyes="void", flames=False, horn=None):
    def leg(x):
        parts = [(coat, [(x, 28), (x + 3.2, 28), (x + 3, 33.5), (x + 2.7, 38), (x + 0.5, 38), (x + 0.2, 33.5)]),
                 (mane if flames else "hair", R(x + 0.2, 36.4, x + 2.9, 38.2)),
                 ("boot", [(x - 0.1, 38), (x + 3.2, 38), (x + 3.5, 40.4), (x - 0.4, 40.4)])]
        return parts
    body = [(coat, E(6, 17, 35, 30)), (coat, E(24, 16, 37, 29)), (coat, E(3.5, 16.5, 17, 29))]
    if stripes:
        for k in range(4):
            body.append((stripes, [(9 + k * 4, 17.5), (10.5 + k * 4, 17.5), (9.8 + k * 4, 23), (8.6 + k * 4, 23)]))
    body += [
        (blanket, [(12.5, 17.5), (27.5, 17.5), (27, 25.5), (13, 25.5)]),
        ("saddle", [(14, 18), (15.4, 14.2), (17.6, 16.4), (23, 16.4), (25.2, 13.4), (26.6, 18), (25.6, 22.4), (15, 22.4)]),
        ("guard", R(16, 18.2, 25, 19)),
        ("saddle", R(19.6, 22, 21, 29.4)),
        ("guard", [(18.4, 29), (22.2, 29), (21.8, 31.8), (18.8, 31.8)]), ("void", R(19.4, 29.8, 21.2, 31)),
    ]
    head = [
        (coat, [(29, 22), (31.5, 12), (35.5, 7), (40, 6.6), (44.2, 11.5), (45.4, 15.6), (43.4, 18), (39, 16.4), (36, 23)]),
        (mane, [(29.6, 21.4), (31.4, 10.5), (34.4, 6), (37.4, 6.4), (34.6, 11.4), (32.8, 21.4)]),
        (coat, [(36.6, 7), (37.8, 2.4), (39.4, 6.8)]),
        (eyes, R(39, 9.8, 40.4, 11.2)),
        ("void", R(43.6, 14.4, 44.6, 15.4)),
        ("saddle", [(37, 10.4), (44.8, 14), (44.4, 15.2), (36.6, 11.6)]),
        ("saddle", [(42.4, 15), (27, 17.2), (27, 18.2), (42.2, 16)]),
    ]
    if flames:
        head += [(mane, [(33, 6), (35, 1), (36, 6.5)]), (mane, [(30.5, 12), (28.5, 8), (32, 11)])]
    if horn:
        head.append((horn, [(37.6, 6), (39.6, -1), (39.6, 6.4)]))
    tail = [(mane, [(5.6, 19), (1.6, 21.6), (0, 29), (1.2, 35.6), (3.6, 32.6), (4.8, 26.4), (7, 22)])]
    if flames:
        tail.append((mane, [(1.2, 34), (-1, 38), (2.6, 36)]))
    return GA._quad(body=body, head=head, tail=tail, leg=leg, head_pivot=(33, 20))


def scaled(rig, s, about=(22.0, 41.0)):
    """The rig with every shape and pivot scaled about the hooves, so it is
    rasterised at that size."""
    def pt(p):
        return (about[0] + (p[0] - about[0]) * s, about[1] + (p[1] - about[1]) * s)
    out = {}
    for name, group in rig.items():
        parts = [(material, [pt(p) for p in polygon]) for material, polygon in group["parts"]]
        out[name] = dict(group, pivot=pt(group["pivot"]), parts=parts)
    return out


# A gallop: the forelegs reaching together, the hind pushing off, the body
# rocking, the head low and the tail streaming.
GALLOP = GA.cycle(6, lambda s: {
    "root": (0, -round(2 * max(s, 0)), 0), "body": (0, 0, -5 * s), "head": (0, 0, -6 + 8 * s), "tail": (0, 0, -18 + 12 * s),
    "leg_fl": (0, 0, -40 * s - 10), "leg_fr": (0, 0, -32 * s - 6), "leg_bl": (0, 0, 38 * s + 6), "leg_br": (0, 0, 30 * s + 2)})
# Idle: breathing, a slow nod, the tail swishing.
IDLE = [{"body": (0, b, 0), "head": (0, 0, nod), "tail": (0, 0, swish)} for b, nod, swish in ((0, 0, 0), (1, 3, 10), (1, 4, 18), (0, 1, 6))]
ANIMATIONS = [("idle", IDLE)] + [row for row in GA.QUAD_ANIMATIONS if row[0] != "idle"] + [("gallop", GALLOP)]

MOUNTS = {
    "pony": (scaled(horse("cream", "cream_mane", "blanket_blue"), 1.1), 1.1),
    "horse": (scaled(horse("bay", "bay_mane", "blanket_red"), 1.3), 1.3),
    "sand_strider": (scaled(horse("dune", "dune_mane", "blanket_sand", stripes="dune_stripe"), 1.3), 1.3),
    "nightmare": (scaled(horse("night", "night_mane", "blanket_black", eyes="glow_red", flames=True), 1.38), 1.38),
    "frost_elk": (scaled(GA.FROST_ELK, 1.3), 1.3),
}


# A tall riding boot standing in the stirrup, for the front layer.
BOOT = [("boot", [(19.2, 21.6), (21.6, 21.6), (21.8, 28.4), (23, 29.2), (23, 30.2), (18.8, 30.2), (19, 28.4)])]


def front(rig, size):
    """The mount's near side, drawn over the rider so they sit in the
    saddle: the barrel, blanket, saddle and stirrup with a boot in it."""
    def pt(p):
        return (22.0 + (p[0] - 22.0) * size, 41.0 + (p[1] - 41.0) * size)
    out = {name: dict(group, parts=[]) for name, group in rig.items()}
    out["body"] = dict(rig["body"], parts=rig["body"]["parts"] + [(m, [pt(p) for p in poly]) for m, poly in BOOT])
    return out


def main():
    out = os.path.join(GA.ROOT, "sprites", "mounts")
    os.makedirs(out, exist_ok=True)
    for name, (rig, size) in MOUNTS.items():
        anims = [(n, [dict(p, shadow=(22, round(13 * size), 0)) for p in poses]) for n, poses in ANIMATIONS]
        GA.draw_sheet(rig, GA.QUAD_ORDER, anims, rich=True).save(os.path.join(out, name + ".png"))
        GA.draw_sheet(front(rig, size), GA.QUAD_ORDER, anims, shadow=False, rich=True).save(os.path.join(out, name + "_front.png"))
    print("mounts drawn: " + ", ".join(MOUNTS))


if __name__ == "__main__":
    main()
