"""Wind sway as drawn frames (no shader shear): each tree gets four frames
stacked down its column of the sheet,

    0  at rest
    1  leaning with the wind (to the right as drawn)
    2  back at rest, its leaves fluttered
    3  leaning the other way

and the game picks a frame per tree from the wind (scripts/effects/wind.gd).

A frame moves the crown as one piece by whole pixels, with the top of a
big crown going a pixel further, so the trunk bends at the crown's
underside instead of every row sliding on its own. The bottom of the tree,
its roots and its ground shadow never move. The leaves flutter: a few
bumps of the crown's edge rise or fall back by a pixel (the outline goes
with them), and a few of the lightest leaf scales trade places with the
next tone, a different few in each frame.
"""
import random

from PIL import Image

FRAMES = 4


def _solid(px, w, h):
    return {(x, y) for y in range(h) for x in range(w) if px[x, y][3] >= 128}


def _crown_rows(solid, w, h):
    """(top, bottom): the rows of the crown, from its top down to where the
    picture narrows to the trunk."""
    rows = {}
    for x, y in solid:
        rows.setdefault(y, []).append(x)
    if not rows:
        return 0, 0
    top, base = min(rows), max(rows)
    width = {y: max(xs) - min(xs) + 1 for y, xs in rows.items()}
    near = sorted(width.get(y, 0) for y in range(base - 14, base - 4) if y in width)
    trunk_w = near[len(near) // 2] if near else 4
    bottom = top
    narrow = 0
    for y in range(top, base + 1):
        if width.get(y, 0) <= trunk_w + 3:
            narrow += 1
            if narrow >= 3:
                bottom = y - 2
                break
        else:
            narrow = 0
            bottom = y
    return top, max(bottom, top + 1)


def _shifted(src, w, h, shifts):
    """A copy with row y moved shifts[y] pixels sideways (0 rows stay)."""
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s, o = src.load(), out.load()
    for y in range(h):
        d = shifts.get(y, 0)
        for x in range(w):
            p = s[x, y]
            if p[3] == 0:
                continue
            nx = x + d
            if 0 <= nx < w:
                o[nx, y] = p
    # Where a moved row left a hole above a row that stayed (or the other
    # way round), fill it from the pixel beside it, so the bend never tears.
    for y in range(h):
        d = shifts.get(y, 0)
        if d == 0:
            continue
        for x in range(w):
            if o[x, y][3] == 0 and s[x, y][3] >= 128 and shifts.get(y + 1, 0) != d:
                nx = x - (1 if d > 0 else -1)
                if 0 <= nx < w and o[nx, y][3] >= 128:
                    o[x, y] = o[nx, y]
    return out


def _flutter(img, w, h, top, bottom, seed, outline_like):
    """Leaf flutter on the crown: edge bumps out or in a pixel, light leaf
    scales trading places with the next tone."""
    r = random.Random(seed)
    px = img.load()
    solid = _solid(px, w, h)
    # The crown's own tones, lightest first, for the scale shimmer.
    tones = {}
    for x, y in solid:
        if top <= y <= bottom:
            c = px[x, y]
            tones[c] = tones.get(c, 0) + 1
    common = sorted((c for c, n in tones.items() if n > 6 and not outline_like(c)),
                    key=lambda c: -(c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114))
    swap = {}
    if len(common) >= 2:
        swap = {common[0]: common[1], common[1]: common[0]}
    for x, y in list(solid):
        if not (top <= y <= bottom):
            continue
        c = px[x, y]
        if c in swap and r.random() < 0.1:
            # Only inside the crown, where the swap reads as a leaf turning.
            if all((x + dx, y + dy) in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = swap[c]
    edges = [(x, y) for x, y in solid if top <= y <= bottom - 2 and outline_like(px[x, y])
             and any((x + dx, y + dy) not in solid for dx, dy in ((1, 0), (-1, 0), (0, -1)))]
    for x, y in edges:
        roll = r.random()
        if roll < 0.05:
            # A leaf lifts: the outline steps out a pixel, the leaf behind it fills in.
            for dx, dy in ((0, -1), (-1, 0), (1, 0)):
                ox, oy = x + dx, y + dy
                if 0 <= ox < w and 0 <= oy < h and px[ox, oy][3] == 0:
                    inner = px[x - dx, y - dy] if 0 <= x - dx < w and 0 <= y - dy < h else px[x, y]
                    if inner[3] >= 128 and not outline_like(inner):
                        px[ox, oy] = px[x, y]
                        px[x, y] = inner
                    break
        elif roll < 0.09:
            # A leaf drops back: the outline steps in.
            for dx, dy in ((0, 1), (1, 0), (-1, 0)):
                ix, iy = x + dx, y + dy
                if 0 <= ix < w and 0 <= iy < h and px[ix, iy][3] >= 128 and not outline_like(px[ix, iy]):
                    if sum((x + ex, y + ey) in solid for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1))) >= 2:
                        px[ix, iy] = px[x, y]
                        px[x, y] = (0, 0, 0, 0)
                    break
    return img


def _dark(c):
    return c[3] >= 128 and c[0] + c[1] + c[2] < 150


def frames(img, kind="tree", reach=1, seed=0):
    """The four sway frames of a picture. kind: "tree" (crown sways, trunk
    bends below it), "bush" (its top half sways a pixel), "still" (no
    sway: crystals, cacti, bones, logs). reach: how far the crown leans."""
    img = img.convert("RGBA")
    w, h = img.size
    if kind == "still":
        return [img.copy() for _ in range(FRAMES)]
    px = img.load()
    solid = _solid(px, w, h)
    if not solid:
        return [img.copy() for _ in range(FRAMES)]
    rows = sorted({y for _, y in solid})
    first, last = rows[0], rows[-1]
    if kind == "bush":
        top, bottom = first, first + (last - first) // 2
    else:
        top, bottom = _crown_rows(solid, w, h)
    cap = top + (bottom - top) * 2 // 5
    out = [img.copy()]
    for k, lean in ((1, 1), (2, 0), (3, -1)):
        shifts = {}
        if lean:
            for y in range(top - 2, bottom + 1):
                shifts[y] = lean * (reach if y <= cap or reach == 1 else max(1, reach - 1))
        frame = _shifted(img, w, h, shifts)
        out.append(_flutter(frame, w, h, top, bottom, seed * 7 + k, _dark))
    return out


def stacked(pictures, w, h, kinds):
    """A sheet with one column per picture and its FRAMES frames down it."""
    sheet = Image.new("RGBA", (w * len(pictures), h * FRAMES), (0, 0, 0, 0))
    for i, picture in enumerate(pictures):
        kind, reach = kinds(i)
        for k, frame in enumerate(frames(picture, kind, reach, seed=i + 1)):
            sheet.alpha_composite(frame, (i * w, k * h))
    return sheet
