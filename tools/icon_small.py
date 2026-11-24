"""The 16x16 versions of the 32x32 item pictures, for where an item is
shown at the world's own pixel size (lying on the ground, held by a
villager, a small slot), so its pixels are never half the size of the
world's.

Each 2x2 block of the picture becomes one pixel: the colour most of its
lit pixels share (outline pixels only where nothing else is there), so
faces keep their colour rather than a muddy average; then the new edge
takes the darkest tone that block had (its outline), or a deep shade of
its own colour, so every small picture is outlined like the big one.
"""
from collections import Counter

import numpy as np
from PIL import Image


def _lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def reduce(icon):
    a = np.array(icon.convert("RGBA")).astype(int)
    n = a.shape[0] // 2
    out = np.zeros((n, n, 4), int)
    solid = a[:, :, 3] > 0
    lums = [_lum(a[y, x]) for y in range(a.shape[0]) for x in range(a.shape[1]) if solid[y, x]]
    if not lums:
        return Image.fromarray(out.astype(np.uint8), "RGBA")
    # "Outline dark": among the darkest eighth of the picture's pixels.
    dark = float(np.percentile(lums, 12)) + 1.0
    darkest = {}
    for by in range(n):
        for bx in range(n):
            px = [tuple(a[by * 2 + j, bx * 2 + i]) for j in (0, 1) for i in (0, 1) if solid[by * 2 + j, bx * 2 + i]]
            if not px:
                continue
            light = [p for p in px if _lum(p) > dark]
            if len(px) == 1 and not light:
                continue
            pool = light or px
            counts = Counter(pool).most_common()
            best = counts[0][0]
            if len(counts) > 1 and counts[0][1] == counts[1][1]:
                mean = np.mean(pool, axis=0)
                tied = [p for p, k in counts if k == counts[0][1]]
                best = min(tied, key=lambda p: sum((p[k] - mean[k]) ** 2 for k in range(3)))
            out[by, bx] = best
            darkest[(bx, by)] = min(px, key=_lum)
    # A lone pixel with nothing round it (a sparkle) is dropped.
    filled = out[:, :, 3] > 0
    for by in range(n):
        for bx in range(n):
            if filled[by, bx] and not filled[max(by - 1, 0):by + 2, max(bx - 1, 0):bx + 2].sum() > 1:
                out[by, bx] = 0
    filled = out[:, :, 3] > 0
    for (bx, by), deep in darkest.items():
        if not filled[by, bx]:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            x, y = bx + dx, by + dy
            if not (0 <= x < n and 0 <= y < n) or not filled[y, x]:
                out[by, bx] = deep if _lum(deep) <= dark else tuple(int(v * 0.45) for v in deep[:3]) + (255,)
                break
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def sheet(big, cell=32):
    """The whole 32-pixel sheet at 16, cell by cell, in the same places."""
    cols, rows = big.width // cell, big.height // cell
    small = Image.new("RGBA", (cols * cell // 2, rows * cell // 2), (0, 0, 0, 0))
    for r in range(rows):
        for c in range(cols):
            small.paste(reduce(big.crop((c * cell, r * cell, c * cell + cell, r * cell + cell))), (c * cell // 2, r * cell // 2))
    return small
