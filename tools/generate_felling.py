"""Felling art for every tree that gives wood: how each one comes down, and
what it leaves. One row per tree (in Flora.WOODEN order), six cells of
192 x 128, the tree's foot at FOOT_AT in each:

    0..2  toppling: leaning 20, 45 and 70 degrees, falling to the right
    3     lying on the ground (turned exactly a quarter)
    4     its trunk as a log, lying beside the stump, the cut end showing
    5     its stump: its own roots and bark, the cut face on top with rings

The leaning frames are turned the way pixel artists turn sprites: the
picture is first enlarged 4x with EPX (which rounds diagonal steps
instead of copying blocks), then each pixel of the frame takes the colour
under its centre, so lines stay one pixel thick. Nothing is rotated in
the game.

Also writes scripts/world/fell_data.gd: each tree's trunk at the height
an axe bites (left and right of its foot), for the chop notch.

Run: python3 tools/generate_felling.py (after the flora sheets).
"""
import math
import os

import numpy as np
from PIL import Image

import generate_flora
import generate_trees
import generate_trees_small
import generate_plants

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(HERE, "..", "assets", "sprites")
SCRIPTS = os.path.join(HERE, "..", "scripts", "world")

CELL = (192, 176)
FOOT_AT = (40, 122)
FRAMES = 6
# Flora.WOODEN, in order.
WOODEN = [0, 1, 2, 3, 4, 5, 6, 9, 12, 20, 21, 22, 23, 24, 25, 26, 27,
          28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 41]
FIRST_GRAND = 28
WOOD = [(202, 164, 116, 255), (176, 138, 92, 255), (142, 106, 68, 255), (96, 70, 44, 255)]
OUTLINE = (20, 16, 20, 255)


def _tree(look):
    """(picture, foot x, foot y) of a tree on its sheet."""
    if look >= FIRST_GRAND:
        return generate_trees.TREES[look - FIRST_GRAND].convert("RGBA"), 48, generate_trees.FOOT
    return TALL[look].convert("RGBA"), 32, generate_trees_small.FOOT


def _rgba(img):
    return np.array(img, dtype=np.uint8)


def _epx(a):
    """EPX / Scale2x on an RGBA array: twice the size, diagonals rounded."""
    h, w, _ = a.shape
    v = a.view(np.uint32).reshape(h, w)
    p = np.pad(v, 1, mode="edge")
    P = p[1:-1, 1:-1]
    A, B, C, D = p[:-2, 1:-1], p[1:-1, 2:], p[1:-1, :-2], p[2:, 1:-1]
    o1 = np.where((C == A) & (C != D) & (A != B), A, P)
    o2 = np.where((A == B) & (A != C) & (B != D), B, P)
    o3 = np.where((D == C) & (D != B) & (C != A), C, P)
    o4 = np.where((B == D) & (B != A) & (D != C), D, P)
    out = np.empty((h * 2, w * 2), dtype=np.uint32)
    out[0::2, 0::2], out[0::2, 1::2], out[1::2, 0::2], out[1::2, 1::2] = o1, o2, o3, o4
    return out.view(np.uint8).reshape(h * 2, w * 2, 4)


def _solid_only(img):
    """The picture without its ground shadow (half-clear pixels)."""
    a = _rgba(img).copy()
    a[a[..., 3] < 128] = 0
    return a


def _turned(img, foot, degrees):
    """The tree turned clockwise about its foot by `degrees`, as a cell."""
    big = _epx(_epx(_solid_only(img)))
    s = 4
    t = math.radians(degrees)
    ys, xs = np.mgrid[0:CELL[1], 0:CELL[0]]
    dx = xs + 0.5 - FOOT_AT[0]
    dy = ys + 0.5 - FOOT_AT[1]
    # Back from the frame to the picture: turn the other way.
    sx = foot[0] + dx * math.cos(t) + dy * math.sin(t)
    sy = foot[1] - dx * math.sin(t) + dy * math.cos(t)
    bx = np.floor(sx * s).astype(int)
    by = np.floor(sy * s).astype(int)
    inside = (bx >= 0) & (by >= 0) & (bx < big.shape[1]) & (by < big.shape[0])
    out = np.zeros((CELL[1], CELL[0], 4), dtype=np.uint8)
    out[inside] = big[by[inside], bx[inside]]
    return Image.fromarray(out, "RGBA")


def _lying(img, foot):
    """The tree turned exactly a quarter (top to the right), on the ground."""
    a = _solid_only(img)
    q = np.rot90(a, k=-1)  # clockwise
    h, w = a.shape[:2]
    # After the turn the foot (fx, fy) sits at (h - 1 - fy, fx).
    fx, fy = foot
    out = Image.new("RGBA", CELL, (0, 0, 0, 0))
    layer = Image.fromarray(np.ascontiguousarray(q), "RGBA")
    # It lands with its trunk on the ground line, its base by the stump; its
    # crown spreads both ways from it (the near half toward us).
    y = FOOT_AT[1] - 3 - fx
    x = FOOT_AT[0] - (h - 1 - fy) + 4
    out.alpha_composite(_ground_shadow(layer), (x, y + 2))
    out.alpha_composite(layer, (x, y))
    return out


def _ground_shadow(layer):
    a = _rgba(layer)
    shade = np.zeros_like(a)
    shade[a[..., 3] >= 128] = (0, 0, 0, 60)
    return Image.fromarray(shade, "RGBA")


def _trunk_run(a, y, cx):
    """The run of solid pixels in row y that holds x = cx: (left, right)."""
    if a[y, cx, 3] < 128:
        return None
    l = r = cx
    while l > 0 and a[y, l - 1, 3] >= 128:
        l -= 1
    while r < a.shape[1] - 1 and a[y, r + 1, 3] >= 128:
        r += 1
    return l, r


def _bark(img, foot):
    """The trunk just above the roots: rows of (left, right, pixels), and
    the set of its colours."""
    a = _rgba(img)
    fx, fy = foot
    rows = []
    colours = set()
    for y in range(fy - 22, fy - 5):
        run = _trunk_run(a, y, fx)
        if run is None or run[1] - run[0] > 24:
            continue
        rows.append((y, run[0], run[1]))
        for x in range(run[0], run[1] + 1):
            colours.add(tuple(int(v) for v in a[y, x]))
    return a, rows, colours


def _log(img, foot):
    """The trunk as a log lying to the right of the stump: the bark above
    the roots repeated to the tree's length, thinning toward the top end,
    a stub of a bough, and the pale cut face at the near end."""
    a, rows, _ = _bark(img, foot)
    out = Image.new("RGBA", CELL, (0, 0, 0, 0))
    if not rows:
        return out, 6
    base = [r for r in rows if r[0] >= foot[1] - 10] or rows
    widths = sorted(r[2] - r[1] + 1 for r in base)
    width = widths[len(widths) // 2]
    length = int((foot[1] - min(r[0] for r in rows)) * 1.0 + img.size[1] * 0.35)
    length = min(length, CELL[0] - FOOT_AT[0] - 14)
    segment = [r for r in rows if r[2] - r[1] + 1 <= width] or base
    o = np.zeros((CELL[1], CELL[0], 4), dtype=np.uint8)
    x0 = FOOT_AT[0] + width // 2 + 4
    top = FOOT_AT[1] - width
    for k in range(length):
        y, l, r = segment[k % len(segment)]
        column = a[y, l:r + 1]
        # Thinning toward the far end.
        trim = int(max(0, (k - length * 0.6) / (length * 0.4)) * width * 0.35)
        col = column[trim:len(column) - trim] if len(column) - 2 * trim > 2 else column[:3]
        for d, px in enumerate(col[:width - 2 * trim]):
            # Turned a quarter: the trunk's left (lit) side becomes the top.
            if 0 <= top + trim + d < CELL[1] and 0 <= x0 + k < CELL[0]:
                o[top + trim + d, x0 + k] = px
    # A stub of a bough on the top side.
    stub = x0 + length // 2
    for d in range(3):
        o[top - 1 - d, stub] = a[segment[0][0], segment[0][1] + 1]
        o[top - 1 - d, stub + 1] = a[segment[0][0], segment[0][2] - 1]
    # The cut face at the near end: an upright oval of rings.
    for d in range(width):
        u = (d - (width - 1) / 2) / max(width / 2, 1)
        ring = WOOD[0] if abs(u) < 0.35 else WOOD[1] if abs(u) < 0.75 else WOOD[3]
        o[top + d, x0 - 1] = ring
        o[top + d, x0] = WOOD[2] if abs(u) < 0.75 else WOOD[3]
    layer = Image.fromarray(o, "RGBA").copy()
    _outline(layer)
    out.alpha_composite(_ground_shadow(layer), (0, 2))
    out.alpha_composite(layer)
    return out, width


def _outline(img):
    px = img.load()
    w, h = img.size
    add = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] >= 128:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] >= 128
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                add.append((x, y))
    for x, y in add:
        px[x, y] = OUTLINE


def _stump(img, foot):
    """Its own stump: the roots and the lowest bark of the trunk (nothing
    green), cut flat with the rings showing on top."""
    a, rows, bark = _bark(img, foot)
    fx, fy = foot
    cut = fy - 9
    keep = np.zeros(a.shape[:2], dtype=bool)
    # Everything bark-coloured joined to the trunk, below the cut.
    seeds = [(fy - 6, x) for x in range(a.shape[1]) if _trunk_run(a, fy - 6, fx) and
             _trunk_run(a, fy - 6, fx)[0] <= x <= _trunk_run(a, fy - 6, fx)[1]]
    stack = list(seeds)
    while stack:
        y, x = stack.pop()
        if y < cut or y >= a.shape[0] or x < 0 or x >= a.shape[1] or keep[y, x]:
            continue
        p = tuple(int(v) for v in a[y, x])
        if p[3] < 128 or (p not in bark and p != OUTLINE and sum(p[:3]) > 120):
            continue
        keep[y, x] = True
        stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    o = np.zeros_like(a)
    o[keep] = a[keep]
    # The ground shadow under it, kept as drawn.
    shadow = (a[..., 3] > 0) & (a[..., 3] < 128)
    o[shadow & (np.arange(a.shape[0])[:, None] >= fy - 4)] = a[shadow & (np.arange(a.shape[0])[:, None] >= fy - 4)]
    run = _trunk_run(a, cut + 1, fx) or (fx - 3, fx + 3)
    l, r = run
    half = (r - l) / 2
    mid = (l + r) / 2
    # The cut face: an oval of pale wood, rings round the heart, a bark rim.
    for y in range(cut - 2, cut + 2):
        v = (y - (cut - 0.5)) / 2.0
        for x in range(l - 1, r + 2):
            u = (x - mid) / max(half + 0.5, 1)
            if u * u + v * v > 1.0:
                continue
            edge = u * u + v * v > 0.62
            ring = (round(math.hypot(u * 3, v * 3)) % 2 == 0)
            o[y, x] = WOOD[3] if edge else (WOOD[0] if ring else WOOD[1])
    o[cut - 1, int(mid)] = WOOD[2]
    layer = Image.fromarray(o, "RGBA").copy()
    _outline(layer)
    out = Image.new("RGBA", CELL, (0, 0, 0, 0))
    out.alpha_composite(layer, (FOOT_AT[0] - fx, FOOT_AT[1] - fy))
    return out, (l - fx, r - fx)


def main():
    rows = []
    trunks = {}
    for look in WOODEN:
        img, fx, fy = _tree(look)
        foot = (fx, fy)
        cells = [_turned(img, foot, d) for d in (20, 45, 70)]
        cells.append(_lying(img, foot))
        log, _ = _log(img, foot)
        cells.append(log)
        stump, _ = _stump(img, foot)
        cells.append(stump)
        rows.append(cells)
        # Where the axe bites, above the flare of the roots.
        bite = (fx - 3, fx + 3)
        for row in range(fy - 11, fy - 5):
            run = _trunk_run(_rgba(img), row, fx)
            if run and run[1] - run[0] <= 16:
                bite = run
                break
        trunks[look] = (bite[0] - fx, bite[1] - fx)
    sheet = Image.new("RGBA", (CELL[0] * FRAMES, CELL[1] * len(rows)), (0, 0, 0, 0))
    for i, cells in enumerate(rows):
        for k, cell in enumerate(cells):
            sheet.alpha_composite(cell, (k * CELL[0], i * CELL[1]))
    sheet.save(os.path.join(SPRITES, "flora_fell.png"))
    lines = ["extends RefCounted",
             "## Generated by tools/generate_felling.py: each wooden tree's trunk where",
             "## an axe bites, as [left, right] pixels from its foot (as drawn, unflipped).",
             "",
             "const TRUNKS := {"]
    for look, (l, r) in trunks.items():
        lines.append("\t%d: [%d, %d]," % (look, l, r))
    lines.append("}")
    with open(os.path.join(SCRIPTS, "fell_data.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")


# The tall pictures as the flora sheet has them (redrawn bushes and trees).
TALL = list(generate_flora.TALL)
generate_plants.redraw(list(generate_flora.SMALL), TALL)
generate_trees_small.redraw(TALL)

if __name__ == "__main__":
    main()
