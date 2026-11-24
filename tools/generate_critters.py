#!/usr/bin/env python3
"""The small wildlife (and the pets they become), drawn at 32x32, a whole
pixel at a time: a rabbit, a songbird, a butterfly and a frog.

Eight frames each, in this order:
  0 at rest   1 a small idle movement   2-3 moving (a hop, a wingbeat, a leap)
  4-5 a fidget (a scratch, a preen, a rub)   6 a yawn   7 asleep

Writes assets/sprites/critters.png (one row: 4 kinds x 8 frames).
Run from the repository root:  python3 tools/generate_critters.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_flora import Canvas, C, ramp, OUTLINE  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
S = 32
GROUND = 29
KINDS = ["rabbit", "bird", "butterfly", "frog"]
FRAMES = 8


def shadow(c, x, w):
    c.shadow(x, GROUND, w, 2, 70)


# ----------------------------------------------------------------- rabbit
FUR = ramp("d8c8ac", "ae977c", "735f4c")
FUR_DARK = ramp("9a8468", "7a6650", "54463a")
BELLY = ramp("f6f1e6", "e0d6c4", "bcae98")
PINK = C("e8a0a4")


def rabbit(frame):
    c = Canvas(S, S)
    if frame in (2, 3):
        # A hop: stretched out, ears laid back; 3 gathers to land.
        up = 5 if frame == 2 else 2
        shadow(c, 15, 9)
        c.shade("ellipse", (3, 15 - up, 21, 24 - up), FUR)
        c.shade("ellipse", (8, 19 - up, 19, 25 - up), BELLY)
        c.shade("ellipse", (17, 11 - up, 27, 19 - up), FUR)
        c.shade("ellipse", (23, 14 - up, 28, 18 - up), BELLY)
        c.shade("poly", [(18, 12 - up), (11, 6 - up), (13, 5 - up), (21, 11 - up)], FUR_DARK, dither=False)
        c.shade("poly", [(20, 12 - up), (14, 4 - up), (16, 3 - up), (23, 11 - up)], FUR, dither=False)
        c.fill("line", (15, 5 - up, 20, 10 - up), PINK)
        c.fill("ellipse", (1, 15 - up, 6, 20 - up), C("faf8f2"))
        if frame == 2:
            c.shade("poly", [(6, 21 - up), (0, 28 - up), (3, 29 - up), (10, 23 - up)], FUR_DARK, dither=False)
            c.shade("poly", [(19, 20 - up), (26, 25 - up), (27, 23 - up), (21, 19 - up)], FUR, dither=False)
        else:
            c.shade("poly", [(7, 21 - up), (8, 28 - up), (13, 28 - up), (11, 22 - up)], FUR_DARK, dither=False)
            c.shade("poly", [(18, 21 - up), (19, 28 - up), (22, 28 - up), (21, 20 - up)], FUR, dither=False)
        c.put(23, 14 - up, OUTLINE)
        c.put(23, 13 - up, C("ffffff"))
        c.put(28, 16 - up, PINK)
        c.outline()
        return c.img
    if frame == 7:
        # Asleep: a round loaf, ears flat along the back, eyes shut.
        shadow(c, 16, 11)
        c.shade("ellipse", (4, 17, 27, 29), FUR)
        c.shade("ellipse", (17, 18, 27, 27), FUR)
        c.shade("poly", [(19, 19), (8, 16), (9, 18), (19, 21)], FUR_DARK, dither=False)
        c.shade("poly", [(20, 18), (10, 14), (11, 16), (21, 20)], FUR, dither=False)
        c.fill("ellipse", (2, 20, 7, 24), C("faf8f2"))
        c.fill("line", (22, 22, 24, 22), OUTLINE)
        c.put(27, 24, PINK)
        c.fill("rect", (20, 28, 25, 28), BELLY[2])
        c.outline()
        c.put(28, 13, C("c8d0ff"))
        c.put(29, 11, C("c8d0ff"))
        return c.img
    # Sitting up (0, 1, the fidgets 4-5 and the yawn 6).
    shadow(c, 15, 10)
    c.shade("ellipse", (4, 15, 20, 29), FUR)
    c.shade("ellipse", (13, 16, 22, 29), FUR)
    c.shade("ellipse", (15, 20, 22, 29), BELLY)
    # Fur texture: a few darker strokes along the haunch.
    for (x, y) in ((8, 18), (10, 20), (7, 22), (12, 17)):
        c.put(x, y, FUR[2])
        c.put(x + 1, y + 1, FUR[2])
    c.fill("ellipse", (1, 18, 6, 23), C("faf8f2"))
    c.put(2, 19, C("ffffff"))
    look_up = 2 if frame == 6 else 0
    hx, hy = 16, 10 - look_up
    c.shade("ellipse", (hx, hy, hx + 10, hy + 10), FUR)
    c.shade("ellipse", (hx + 6, hy + 4, hx + 11, hy + 9), BELLY)
    # Ears: the far one darker, the near one with a pink lining; frame 1
    # turns one to listen.
    lean = 2 if frame == 1 else 0
    c.shade("poly", [(hx + 2, hy + 2), (hx - 1 - lean, hy - 8), (hx + 1 - lean, hy - 9), (hx + 4, hy + 1)], FUR_DARK, dither=False)
    c.shade("poly", [(hx + 4, hy + 2), (hx + 3, hy - 9), (hx + 6, hy - 9), (hx + 7, hy + 1)], FUR, dither=False)
    c.fill("line", (hx + 5, hy - 7, hx + 5, hy), PINK)
    eye = (hx + 7, hy + 4)
    if frame == 6:
        # A yawn: eyes squeezed shut, mouth wide and pink.
        c.fill("line", (eye[0] - 1, eye[1], eye[0] + 1, eye[1]), OUTLINE)
        c.fill("ellipse", (hx + 8, hy + 6, hx + 11, hy + 10), C("b0404a"))
        c.put(hx + 9, hy + 7, PINK)
    else:
        c.fill("rect", (eye[0], eye[1], eye[0] + 1, eye[1] + 1), C("2a1a14"))
        c.put(eye[0], eye[1], C("ffffff"))
        c.put(hx + 11, hy + 6, PINK)
        # Whiskers.
        c.put(hx + 12, hy + 7, C("f0ece0"))
        c.put(hx + 13, hy + 8, C("f0ece0"))
    # Paws; in the scratch a hind foot comes up to the ear.
    c.fill("rect", (17, 28, 21, 28), BELLY[1])
    if frame in (4, 5):
        reach = 0 if frame == 4 else 2
        c.shade("poly", [(10, 24), (13 + reach, 13 - reach), (16 + reach, 13 - reach), (14, 25)], FUR_DARK, dither=False)
        c.fill("rect", (14 + reach, 12 - reach, 16 + reach, 13 - reach), BELLY[1])
    else:
        c.shade("rect", (6, 27, 15, 28), FUR_DARK, dither=False)
        c.fill("rect", (15, 28, 16, 28), BELLY[1])
    c.outline()
    return c.img


# ----------------------------------------------------------------- bird
BODY = ramp("8e7c6a", "655648", "3e3430")
CAP = ramp("5a4a40", "40342e", "2a2220")
BREAST = ramp("f0a070", "cc7048", "8e4628")
WING = ramp("7a6a5a", "524438", "2e2622")
BEAK = C("f2b432")
LEG = C("c0802c")


def wing_feathers(c, x0, y0, x1, y1):
    for k, y in enumerate(range(y0, y1)):
        c.put(x0 + k % 3, y, WING[0])
    c.fill("line", (x0, y1, x1, y1), WING[2])


def bird(frame):
    c = Canvas(S, S)
    if frame in (2, 3):
        # In flight: wings up, then down, primaries spread.
        c.shade("ellipse", (8, 13, 22, 21), BODY)
        c.shade("ellipse", (13, 16, 21, 21), BREAST)
        c.shade("ellipse", (19, 10, 27, 17), BODY)
        c.shade("ellipse", (19, 9, 26, 13), CAP)
        c.shade("poly", [(9, 15), (2, 13), (2, 16), (4, 18), (9, 18)], WING, dither=False)
        if frame == 2:
            c.shade("poly", [(10, 15), (6, 2), (11, 3), (14, 4), (18, 14)], WING)
            for k in range(4):
                c.fill("line", (7 + k * 2, 3 + k, 10 + k * 2, 11), WING[2])
        else:
            c.shade("poly", [(10, 17), (5, 29), (10, 28), (14, 27), (18, 18)], WING)
            for k in range(4):
                c.fill("line", (7 + k * 2, 27 - k, 11 + k * 2, 20), WING[2])
        c.fill("rect", (27, 13, 28, 13), BEAK)
        c.put(28, 14, C("b07818"))
        c.put(24, 12, OUTLINE)
        c.put(24, 11, C("ffffff"))
        c.outline()
        return c.img
    shadow(c, 14, 7)
    # Perched: body, a russet breast, a striped wing folded over, a tail.
    fluff = 1 if frame == 7 else 0
    c.shade("ellipse", (7 - fluff, 13 - fluff, 22 + fluff, 25), BODY)
    c.shade("ellipse", (13, 16, 22 + fluff, 25), BREAST)
    c.shade("poly", [(8, 17), (1, 19), (2, 22), (9, 21)], WING, dither=False)
    c.fill("line", (2, 21, 8, 20), WING[2])
    c.shade("poly", [(8, 15), (18, 15), (16, 22), (6, 21)], WING)
    wing_feathers(c, 8, 16, 16, 21)
    # Head: lowered to peck (1), turned into the wing to preen (4-5), up
    # with the beak open (6), tucked in sleep (7).
    if frame == 7:
        c.shade("ellipse", (15, 11, 23, 18), BODY)
        c.shade("ellipse", (15, 11, 22, 14), CAP)
        c.fill("line", (19, 15, 21, 15), OUTLINE)
    else:
        if frame == 1:
            hx, hy = 18, 13
        elif frame in (4, 5):
            hx, hy = 12 + (frame - 4), 11
        elif frame == 6:
            hx, hy = 17, 6
        else:
            hx, hy = 17, 8
        c.shade("ellipse", (hx, hy, hx + 8, hy + 8), BODY)
        c.shade("ellipse", (hx, hy, hx + 7, hy + 4), CAP)
        c.fill("line", (hx + 2, hy + 5, hx + 6, hy + 5), C("e8dccc"))
        if frame in (4, 5):
            # Beak in the feathers of the wing.
            c.fill("rect", (hx - 1, hy + 6, hx, hy + 6), BEAK)
            c.put(hx + 3, hy + 3, OUTLINE)
        else:
            open_ = frame == 6
            c.fill("rect", (hx + 8, hy + 3, hx + 10, hy + 3), BEAK)
            c.put(hx + 8, hy + 4 + (1 if open_ else 0), C("b07818"))
            if open_:
                c.put(hx + 9, hy + 5, BEAK)
                c.put(hx + 8, hy + 4, C("c04040"))
            c.put(hx + 6, hy + 3, OUTLINE)
            c.put(hx + 6, hy + 2, C("ffffff"))
    c.fill("rect", (12, 25, 12, 28), LEG)
    c.fill("rect", (16, 25, 16, 28), LEG)
    c.fill("rect", (11, 28, 13, 28), LEG)
    c.fill("rect", (15, 28, 17, 28), LEG)
    c.outline()
    if frame == 7:
        c.img.putpixel((25, 9), (200, 208, 255, 255))
        c.img.putpixel((27, 7), (200, 208, 255, 255))
    return c.img


# ----------------------------------------------------------------- butterfly
FORE = (C("f6d690"), C("e2a452"), C("9e6228"))
HIND = (C("ecbe7e"), C("ca8c46"), C("7c4e22"))
RIM = C("3a2416")


def butterfly(frame):
    """Seen from above: open, half, shut, half; the fidgets slow beats; asleep
    wings shut."""
    c = Canvas(S, S)
    open_ = [5, 4, 1, 4, 5, 3, 5, 1][frame]
    cx = 16
    for side in (-1, 1):
        x0 = cx - 1 if side < 0 else cx
        if open_ >= 2:
            w = open_ + 5
            c.shade("poly", [(x0 + side, 12), (x0 + side * w, 6), (x0 + side * (w + 2), 9), (x0 + side * (w + 1), 13), (x0 + side * 2, 16)], FORE, dither=False)
            c.shade("poly", [(x0 + side, 16), (x0 + side * (w - 1), 17), (x0 + side * (w - 2), 22), (x0 + side * 3, 23), (x0 + side, 20)], HIND, dither=False)
            # Rims, veins and eye-spots.
            c.fill("line", (x0 + side * w, 6, x0 + side * (w + 2), 9), RIM)
            c.fill("line", (x0 + side * (w - 2), 22, x0 + side * 3, 23), RIM)
            c.fill("line", (x0 + side * 2, 13, x0 + side * (w - 1), 9), FORE[2])
            c.fill("line", (x0 + side * 2, 17, x0 + side * (w - 3), 20), HIND[2])
            xa, xb = sorted((x0 + side * (w - 4), x0 + side * (w - 2)))
            c.fill("ellipse", (xa, 9, xb, 11), C("fff2d8"))
            c.put(x0 + side * (w - 3), 10, RIM)
            c.put(x0 + side * (w - 4), 19, C("fff2d8"))
        else:
            c.fill("rect", (x0 + side, 7, x0 + side, 18), FORE[1])
            c.fill("rect", (x0 + side * 2, 8, x0 + side * 2, 16), FORE[2])
            c.put(x0 + side, 7, RIM)
    c.fill("rect", (cx - 1, 10, cx, 21), C("2a1c14"))
    c.fill("rect", (cx - 1, 10, cx, 11), C("5a4434"))
    # Antennae, cleaned (curled) in the fidgets.
    curl = frame in (4, 5)
    for side in (-1, 1):
        x0 = cx - 1 if side < 0 else cx
        c.put(x0 + side, 9, RIM)
        c.put(x0 + side * 2, 8 if not curl else 9, RIM)
        c.put(x0 + side * 3, 7 if not curl else 9, RIM)
        c.put(x0 + side * 3, 6 if not curl else 10, C("5a4434"))
    if frame == 7:
        c.put(22, 5, C("c8d0ff"))
    return c.img


# ----------------------------------------------------------------- frog
SKIN = ramp("a4dc78", "62a64c", "38702c")
FBELLY = ramp("eef4c8", "cedca6", "9eb474")
SPOT = C("2e5a24")
EYE = C("f4e060")


def frog(frame):
    c = Canvas(S, S)
    if frame in (2, 3):
        up = 7 if frame == 2 else 3
        b = 16 - up
        shadow(c, 16, 8)
        c.shade("ellipse", (9, b, 25, b + 9), SKIN)
        c.shade("ellipse", (13, b + 4, 23, b + 10), FBELLY)
        c.shade("ellipse", (19, b - 3, 25, b + 3), SKIN, dither=False)
        c.fill("ellipse", (20, b - 2, 23, b + 1), EYE)
        c.put(22, b - 1, OUTLINE)
        for (x, y) in ((12, b + 2), (16, b + 1), (14, b + 4)):
            c.put(x, y, SPOT)
        if frame == 2:
            c.shade("poly", [(10, b + 5), (3, b + 11), (4, b + 13), (12, b + 8)], SKIN, dither=False)
            c.shade("poly", [(3, b + 12), (0, b + 15), (2, b + 16), (5, b + 13)], SKIN, dither=False)
            c.fill("rect", (23, b + 6, 27, b + 7), SKIN[1])
            c.put(28, b + 8, SKIN[2])
        else:
            c.shade("poly", [(10, b + 6), (6, b + 12), (10, b + 13), (14, b + 8)], SKIN, dither=False)
            c.fill("rect", (5, b + 13, 10, b + 13), SKIN[2])
            c.fill("rect", (21, b + 8, 22, b + 12), SKIN[1])
            c.fill("rect", (21, b + 13, 25, b + 13), SKIN[2])
        c.outline()
        return c.img
    shadow(c, 16, 11)
    flat = 2 if frame == 7 else 0
    c.shade("ellipse", (6, 15 + flat, 26, 27), SKIN)
    c.shade("ellipse", (10, 19 + flat, 22, 27), FBELLY)
    if frame == 1:
        # The throat swells.
        c.shade("ellipse", (11, 21, 21, 29), FBELLY)
        c.put(14, 23, C("ffffff"))
    for (x, y) in ((9, 18 + flat), (12, 16 + flat), (21, 17 + flat), (23, 20 + flat), (17, 16 + flat)):
        c.put(x, y, SPOT)
        c.put(x + 1, y, SPOT)
    # Folded hind legs and splayed feet.
    for side in (-1, 1):
        kx = 6 if side < 0 else 25
        c.shade("ellipse", (kx - 4, 19, kx + 4, 27), SKIN)
        c.fill("rect", (min(kx, kx + side * 5), 27, max(kx, kx + side * 5), 28), SKIN[1])
        c.put(kx + side * 6, 28, SKIN[2])
        c.put(kx + side * 5, 29, SKIN[2])
        fx = 12 if side < 0 else 19
        lift = 4 if frame in (4, 5) and side > 0 else 0
        c.fill("rect", (fx, 25 - lift, fx, 28 - lift), SKIN[1])
        c.put(fx + side, 28 - lift, SKIN[2])
    # Eyes on top of the head: shut asleep, one rubbed in the fidget.
    for side, ex in ((-1, 8), (1, 18)):
        c.shade("ellipse", (ex, 11 + flat, ex + 6, 17 + flat), SKIN, dither=False)
        if frame == 7 or (frame in (4, 5) and side > 0):
            c.fill("line", (ex + 1, 14 + flat, ex + 5, 14 + flat), SKIN[2])
        else:
            c.fill("ellipse", (ex + 1, 12 + flat, ex + 5, 16 + flat), EYE)
            c.fill("rect", (ex + 2, 14 + flat, ex + 4, 14 + flat), OUTLINE)
            c.put(ex + 2, 13 + flat, C("ffffff"))
    # The mouth: a long line, wide open in the yawn.
    if frame == 6:
        c.fill("ellipse", (11, 19, 21, 24), C("a03848"))
        c.fill("ellipse", (13, 21, 19, 23), C("e07a88"))
    else:
        c.fill("line", (10, 20 + flat, 22, 20 + flat), SPOT)
    c.outline()
    if frame == 7:
        c.img.putpixel((27, 9), (200, 208, 255, 255))
        c.img.putpixel((29, 7), (200, 208, 255, 255))
    return c.img


DRAW = {"rabbit": rabbit, "bird": bird, "butterfly": butterfly, "frog": frog}


def main():
    sheet = Image.new("RGBA", (S * FRAMES * len(KINDS), S), (0, 0, 0, 0))
    for k, kind in enumerate(KINDS):
        for f in range(FRAMES):
            sheet.paste(DRAW[kind](f), ((k * FRAMES + f) * S, 0))
    sheet.save(os.path.join(ROOT, "critters.png"))
    print("critters:", len(KINDS) * FRAMES, "frames at", S)


if __name__ == "__main__":
    main()
