"""The older trees of the tall sheet (64 x 96), redrawn in the grand trees'
style (tools/generate_trees.py): tapering bark with fissures and knots,
roots over the ground, boughs between layered leaf clusters covered in
small lit leaf scales. Every tree in the game is then drawn the same way.

The broadleaf crowns are painted in the seasons' summer greens (only
green pixels turn with the year); the autumn oak, red maple and cherry
keep their own colours, in five tones whose brightness steps match
scripts/effects/seasons.gd (CUTS below, printed by `python3 -m`).

Used by generate_flora.write_flora_sheets().
"""
import math
import random

from generate_flora import Canvas, C
from generate_trees import (SUMMER, OAK_BARK, DARK_BARK, PINE, CRIMSON, THORN, SNOW,
                            trunk, roots, bough, crown, shadow, fruit, finish, hash2, mix)

W, H = 64, 96
FOOT = 90
X = 32

ORANGE = [(74, 36, 18, 255), (138, 68, 32, 255), (192, 106, 42, 255), (232, 152, 58, 255), (248, 200, 104, 255)]
RED = [(60, 14, 20, 255), (122, 26, 36, 255), (176, 42, 52, 255), (220, 74, 76, 255), (255, 154, 136, 255)]
BLOSSOM = [C("6e3a4e"), C("a45c78"), C("d088a4"), C("eab4c8"), C("fbe2ec")]
CHERRY_BARK = [C("1e1416"), C("33242a"), C("4a343a"), C("604650"), C("7a5c66")]
WILLOW_GREEN = SUMMER


def _luma(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0


def cuts(tones):
    """Brightness boundaries between five tones, for the season shader."""
    l = [_luma(t) for t in tones]
    return tuple(round((l[k] + l[k + 1]) / 2, 3) for k in range(4))


def _broadleaf(seed, clusters, trunk_top, trunk_w, tones=SUMMER, bark=OAK_BARK, boughs=(), lean=0.0, extra=None):
    c = Canvas(W, H)
    shadow(c, X, FOOT, 18, 3)
    roots(c, X, FOOT, trunk_w, bark, seed, count=4, reach=8)
    trunk(c, X, trunk_top, FOOT, trunk_w, max(3, trunk_w - 3), bark, seed, lean=lean)
    for b in boughs:
        bough(c, *b, bark)
    crown(c, clusters, tones, seed)
    if extra:
        extra(c)
    return finish(c)


def oak():
    return _broadleaf(101, [(20, 42, 10, 8, 1), (44, 40, 10, 8, 1), (32, 30, 14, 10, 1),
                            (17, 32, 8, 7, 0), (47, 31, 8, 7, 0), (26, 21, 10, 8, 0), (39, 22, 9, 8, 0),
                            (32, 40, 10, 7, 0), (23, 46, 7, 5, 0), (41, 46, 7, 5, 0)],
                      52, 9, boughs=[(31, 60, 20, 46, 3, 2), (33, 58, 44, 44, 3, 2)])


def oak_2():
    # Leaning a little, its crown heavier on one side.
    return _broadleaf(102, [(16, 44, 9, 7, 1), (40, 38, 12, 9, 1), (30, 30, 13, 10, 1),
                            (14, 36, 7, 6, 0), (46, 30, 9, 8, 0), (24, 22, 10, 8, 0), (38, 20, 9, 7, 0),
                            (30, 41, 10, 7, 0), (46, 42, 7, 5, 0)],
                      52, 9, lean=-0.04, boughs=[(32, 60, 18, 46, 3, 2), (32, 58, 46, 40, 3, 2)])


def broad_oak():
    return _broadleaf(103, [(14, 46, 10, 8, 1), (50, 46, 10, 8, 1), (32, 38, 17, 11, 1),
                            (10, 38, 8, 7, 0), (54, 38, 8, 7, 0), (22, 30, 11, 8, 0), (42, 30, 11, 8, 0),
                            (32, 24, 11, 8, 0), (32, 46, 12, 7, 0), (20, 50, 7, 5, 0), (44, 50, 7, 5, 0)],
                      56, 11, boughs=[(30, 64, 12, 50, 4, 2), (34, 62, 52, 50, 4, 2), (32, 60, 32, 40, 3, 2)])


def tall_oak():
    return _broadleaf(104, [(24, 34, 8, 7, 1), (40, 32, 8, 7, 1), (32, 24, 11, 9, 1),
                            (22, 24, 7, 6, 0), (42, 22, 7, 6, 0), (32, 14, 9, 7, 0), (32, 34, 8, 6, 0),
                            (26, 40, 6, 5, 0), (38, 40, 6, 5, 0)],
                      42, 8, boughs=[(31, 50, 24, 38, 2, 1), (33, 48, 40, 36, 2, 1)])


def autumn_oak():
    return _broadleaf(105, [(20, 42, 10, 8, 1), (44, 40, 10, 8, 1), (32, 30, 14, 10, 1),
                            (17, 32, 8, 7, 0), (47, 31, 8, 7, 0), (26, 21, 10, 8, 0), (39, 22, 9, 8, 0),
                            (32, 40, 10, 7, 0), (23, 46, 7, 5, 0), (41, 46, 7, 5, 0)],
                      52, 9, tones=ORANGE, boughs=[(31, 60, 20, 46, 3, 2), (33, 58, 44, 44, 3, 2)],
                      extra=lambda c: _fallen_leaves(c, ORANGE, 105))


def red_maple():
    return _broadleaf(106, [(24, 40, 9, 7, 1), (40, 38, 9, 7, 1), (32, 28, 12, 9, 1),
                            (20, 30, 7, 6, 0), (44, 29, 7, 6, 0), (28, 19, 8, 7, 0), (37, 18, 8, 7, 0),
                            (32, 38, 9, 6, 0)],
                      48, 7, tones=RED, bark=DARK_BARK, boughs=[(31, 56, 22, 42, 2, 1), (33, 54, 42, 40, 2, 1)],
                      extra=lambda c: _fallen_leaves(c, RED, 106))


def cherry():
    def petals(c):
        _fallen_leaves(c, BLOSSOM, 107)
    return _broadleaf(107, [(18, 44, 9, 7, 1), (46, 42, 9, 7, 1), (32, 34, 13, 9, 1),
                            (16, 35, 7, 6, 0), (48, 34, 7, 6, 0), (26, 26, 9, 7, 0), (39, 25, 9, 7, 0),
                            (32, 43, 9, 6, 0)],
                      54, 8, tones=BLOSSOM, bark=CHERRY_BARK, lean=0.03,
                      boughs=[(31, 62, 18, 46, 3, 1), (33, 60, 46, 44, 3, 1), (32, 58, 30, 36, 2, 1)], extra=petals)


def _fallen_leaves(c, tones, seed):
    """A scatter of fallen leaves or petals round the foot."""
    r = random.Random(seed)
    for _ in range(9):
        x = X + r.randint(-16, 16)
        y = FOOT + r.randint(-2, 3)
        if abs(x - X) < 5:
            continue
        c.put(x, y, tones[r.choice((2, 3, 4))])


def pine(height=1.0, width=1.0, snowy=False, seed=7, tiers=6):
    """A fir in drooping tiers of boughs, lit along their tops, with needle
    strokes and tips; snow along the upper face of each tier."""
    c = Canvas(W, H)
    shadow(c, X, FOOT, int(14 * width) + 2, 3)
    roots(c, X, FOOT, 6, OAK_BARK, seed, count=3, reach=5)
    top = int(FOOT - 78 * height)
    trunk(c, X, top + 8, FOOT, 6, 2, OAK_BARK, seed)
    step = (FOOT - 12 - top) / tiers
    for k in range(tiers):
        y = int(top + 8 + k * step)
        half = (4 + k * (17 / max(tiers - 1, 1))) * width
        for x in range(int(X - half), int(X + half) + 1):
            u = (x - X) / max(half, 1)
            droop = int(abs(u) ** 1.6 * 4)
            top_y = y - 4 + droop - int((1 - abs(u)) * 2)
            hem = y + 5 + droop // 2 + int(hash2(x // 2, k, seed) * 3) - (1 if x % 3 == 0 else 0)
            for yy in range(top_y, hem):
                t = (yy - top_y) / max(hem - top_y, 1)
                tone = 3 if t < 0.25 and u < 0.3 else 2 if t < 0.55 else 1 if t < 0.85 else 0
                if u > 0.5 and tone > 1:
                    tone -= 1
                if 0.2 < t < 0.85 and (x + yy * 2) % 5 == 0:
                    tone = max(tone - 1, 0)
                c.put(x, yy, PINE[tone])
            if snowy and abs(u) < 0.9:
                c.put(x, top_y, SNOW[4] if u < 0.2 else SNOW[2])
                if hash2(x, k, seed + 2) < 0.45:
                    c.put(x, top_y + 1, SNOW[1])
        for x in range(int(X - half), int(X + half) + 1, 3):
            c.put(x, y + 1, PINE[4] if x < X else PINE[3])
    for k in range(5):
        c.put(X, top + k, PINE[2])
        c.put(X - 1, top + 2 + k, PINE[3])
    if snowy:
        c.put(X, top, SNOW[4])
    return finish(c)


def dead_tree():
    """A bare, forked dead tree: grey bark, split branches, a broken top."""
    bark = [C("2a2624"), C("443e3a"), C("625a54"), C("807870"), C("9c948a")]
    c = Canvas(W, H)
    shadow(c, X, FOOT, 14, 3)
    roots(c, X, FOOT, 8, bark, 108, count=4, reach=8)
    trunk(c, X, 34, FOOT, 8, 4, bark, 108, lean=0.02)
    for b in [(31, 60, 16, 44, 3, 1), (16, 44, 10, 34, 2, 1), (16, 44, 20, 30, 1, 1),
              (33, 54, 48, 38, 3, 1), (48, 38, 54, 28, 2, 1), (48, 38, 44, 26, 1, 1),
              (32, 40, 28, 22, 2, 1), (28, 22, 24, 14, 1, 1), (28, 22, 33, 16, 1, 1)]:
        bough(c, *b, bark)
    # A woodpecker's hole and a shelf fungus.
    c.put(X - 1, 66, bark[0])
    c.put(X, 66, bark[0])
    for k in range(4):
        c.put(X + 3 + k, 72, C("b89a6a") if k < 3 else C("8a7048"))
    return finish(c)


def willow():
    c = Canvas(W, H)
    shadow(c, X, FOOT, 20, 3)
    roots(c, X, FOOT, 9, OAK_BARK, 109, count=4, reach=8)
    trunk(c, X, 44, FOOT, 9, 6, OAK_BARK, 109, lean=-0.03)
    crown(c, [(32, 30, 18, 10, 1), (22, 34, 10, 7, 0), (42, 33, 10, 7, 0), (32, 22, 12, 7, 0)], WILLOW_GREEN, 109)
    r = random.Random(109)
    for x in range(14, 51, 2):
        top = 34 + int(abs(x - X) * 0.2)
        length = r.randint(18, 34)
        for y in range(top, min(top + length, FOOT - 3)):
            t = (y - top) / length
            if hash2(x, y, 9) < 0.12:
                continue
            c.put(x, y, WILLOW_GREEN[3 if (x // 2) % 3 == 0 and t < 0.6 else 2 if t < 0.7 else 1])
        c.put(x, min(top + length, FOOT - 3), WILLOW_GREEN[4])
    return finish(c)


def crimson():
    c = Canvas(W, H)
    shadow(c, X, FOOT, 18, 3)
    roots(c, X, FOOT, 8, DARK_BARK, 110, count=4, reach=8)
    trunk(c, X, 48, FOOT, 8, 5, DARK_BARK, 110)
    bough(c, 31, 56, 20, 44, 3, 1, DARK_BARK)
    bough(c, 33, 54, 44, 42, 3, 1, DARK_BARK)
    crown(c, [(20, 40, 9, 7, 1), (44, 38, 9, 7, 1), (32, 28, 13, 9, 0), (23, 31, 8, 6, 0), (41, 30, 8, 6, 0),
              (32, 40, 9, 6, 0)], CRIMSON, 110)
    r = random.Random(110)
    for _ in range(9):
        x = r.randint(14, 50)
        top = 42 + r.randint(0, 5)
        for k in range(r.randint(5, 12)):
            c.put(x + (k // 4) % 2, top + k, CRIMSON[2] if k % 4 else CRIMSON[3])
    return finish(c)


def thorn():
    c = Canvas(W, H)
    shadow(c, X, FOOT, 15, 3)
    roots(c, X, FOOT, 7, DARK_BARK, 111, count=4, reach=8)
    for k, lean in enumerate((-0.07, 0.05, -0.02)):
        trunk(c, X - 2 + k * 2, 44, FOOT, 4, 2, DARK_BARK, 111 + k, lean=lean)
    bough(c, 30, 52, 16, 38, 2, 1, DARK_BARK)
    bough(c, 34, 50, 48, 36, 2, 1, DARK_BARK)
    r = random.Random(111)
    for _ in range(18):
        x, y = r.randint(16, 48), r.randint(30, FOOT - 6)
        if (x, y) in c.filled:
            c.put(x + r.choice((-1, 1)), y - 1, C("c8c0a8"))
    crown(c, [(18, 36, 7, 5, 1), (46, 34, 7, 5, 1), (31, 26, 9, 6, 0), (24, 31, 6, 4, 0), (39, 29, 6, 4, 0)], THORN, 111)
    fruit(c, [(20, 34), (44, 32), (30, 22), (35, 29)], C("8a1c2a"), C("d04858"))
    return finish(c)


def redraw(tall):
    """Puts the redrawn trees in the tall sheet's list (indices as Flora.Tall)."""
    tall[0] = oak()
    tall[1] = oak_2()
    tall[2] = dead_tree()
    tall[3] = pine(1.0, 1.0, False, 7)
    tall[4] = pine(1.0, 1.0, True, 8)
    tall[5] = thorn()
    tall[6] = crimson()
    tall[12] = willow()
    tall[20] = broad_oak()
    tall[21] = tall_oak()
    tall[22] = pine(1.08, 0.72, False, 9, tiers=7)
    tall[23] = pine(1.08, 0.72, True, 10, tiers=7)
    tall[24] = pine(0.78, 1.22, False, 11, tiers=5)
    tall[25] = autumn_oak()
    tall[26] = cherry()
    tall[27] = red_maple()


if __name__ == "__main__":
    for name, tones in (("summer", SUMMER), ("orange", ORANGE), ("red", RED), ("blossom", BLOSSOM)):
        print(name, cuts(tones))
