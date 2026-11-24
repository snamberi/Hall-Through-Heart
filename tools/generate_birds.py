#!/usr/bin/env python3
"""Birds, drawn pixel by pixel on two legs: the chicken, the chick and the
pheasant (they used to share the four-legged rig).

Each is built of its own parts: an egg-shaped body lit from the upper
left with a paler breast, a folded wing with feather rows, a tail, a head
with its beak and eye (the hen's comb and wattle, the pheasant's red eye
patch and white collar), and two thin scaled legs with three toes forward
and one back. Outlines are a dark tone of the bird's own feathers.

Frames move the parts by whole pixels, nothing is stretched or turned:
pecking at rest, a head-bobbing walk with legs stepping in turn, a crouch
with wings lifting, a flapping leap, a flinch with a loose feather, a fall
onto its side, sitting puffed up, scratching the ground and a wing
stretch, then walking away seen from behind. Every bird faces right; the
game mirrors it.

Writes assets/sprites/enemies/<name>.png with the rows of
tools/generate_beasts.py (EnemyAnimator.ROWS, the pets' rows, the back).

Run from the repository root:  python3 tools/generate_birds.py
"""
import math
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "enemies")
F = 96
GROUND = 73
ROWS = [("idle", 4), ("walk", 8), ("windup", 6), ("lunge", 6), ("hurt", 3), ("death", 8), ("rest", 4), ("scratch", 4), ("stretch", 4)]
BACK_ROWS = [("idle", 4), ("walk", 8)]


def C(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (F, F), (0, 0, 0, 0))
        self.px = self.img.load()
        self.filled = set()

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < F and 0 <= y < F:
            self.px[x, y] = c
            self.filled.add((x, y))

    def blob(self, cx, cy, rx, ry, tones, light=(-0.6, -0.8)):
        """An oval shaded from the upper left: tones are light to dark."""
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if u * u + v * v > 1.0:
                    continue
                lit = u * light[0] + v * light[1]
                self.put(x, y, tones[0] if lit > 0.45 else tones[1] if lit > -0.2 else tones[2] if lit > -0.65 else tones[3])

    def poly(self, points, colour):
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            for x in range(int(min(xs)), int(max(xs)) + 1):
                if _inside(x + 0.5, y + 0.5, points):
                    self.put(x, y, colour)

    def outline(self, colour):
        add = []
        for x, y in self.filled:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p not in self.filled and 0 <= p[0] < F and 0 <= p[1] < F:
                    add.append(p)
        for x, y in add:
            self.px[x, y] = colour

    def shadow(self, cx, rx):
        for y in range(GROUND - 1, GROUND + 2):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                u, v = (x - cx) / rx, (y - GROUND) / 1.6
                if u * u + v * v <= 1.0 and self.px[x, y][3] == 0:
                    self.px[x, y] = (0, 0, 0, 70)


def _inside(x, y, pts):
    n, inside = len(pts), False
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            inside = not inside
        j = i
    return inside


# --- the birds -------------------------------------------------------------------

def hen():
    return dict(
        feathers=[C("fcfaf2"), C("ece6d8"), C("cfc6b4"), C("a49a88")], outline=C("5e5448"),
        breast=None, wing=[C("e4ddcc"), C("c2b8a4"), C("968c7a")],
        tail=[C("f4f0e6"), C("d0c8b6"), C("a49a88")],
        head=[C("fcfaf2"), C("ece6d8"), C("cfc6b4"), C("a49a88")],
        comb=[C("e8414a"), C("a8202c")], wattle=True, patch=None, collar=None,
        beak=[C("f4c044"), C("c08a20")], legs=[C("f0b030"), C("b07818")], eye=C("1a1414"),
        body=(9, 7), body_at=(43, 61), head_at=(52, 51), head_r=4, tail_len=8, leg_len=6, tail_kind="hen",
    )


def chick():
    yellow = [C("fff07a"), C("f6d84a"), C("dcb22e"), C("b08a1c")]
    return dict(
        feathers=yellow, outline=C("7a5a14"), breast=None, wing=[C("f6d84a"), C("dcb22e"), C("b08a1c")],
        tail=[C("f6d84a"), C("dcb22e"), C("b08a1c")], head=yellow,
        comb=None, wattle=False, patch=None, collar=None,
        beak=[C("f4a040"), C("c07020")], legs=[C("f09a30"), C("b06a18")], eye=C("1a1414"),
        body=(5, 5), body_at=(44, 66), head_at=(49, 60), head_r=3, tail_len=2, leg_len=2, tail_kind="stub",
    )


def pheasant():
    copper = [C("e0904a"), C("b86a30"), C("8a4a22"), C("5e3018")]
    return dict(
        feathers=copper, outline=C("3a1e10"), breast=[C("c8743a")], wing=[C("c8a070"), C("9a7448"), C("6a4e2e")],
        tail=[C("c89a62"), C("8a6036"), C("4a2e18")],
        head=[C("4aa070"), C("2e7a56"), C("1e5a40"), C("143e2e")],
        comb=None, wattle=False, patch=C("d8303a"), collar=C("f2eee4"),
        beak=[C("e8d8a0"), C("a89a68")], legs=[C("9a8a70"), C("6a5e4a")], eye=C("f4e070"),
        body=(10, 6), body_at=(44, 62), head_at=(56, 49), head_r=3, tail_len=18, leg_len=6, tail_kind="long",
    )


SPECIES = {"chicken": hen(), "chick": chick(), "pheasant": pheasant()}


# --- poses ---------------------------------------------------------------------------

def pose(**kw):
    p = dict(dx=0, dy=0, head=(0, 0), legs=((0, 0), (0, 0)), wing=0, tail=0, sit=False, lying=False, eye_shut=False, feather=None, peck=False)
    p.update(kw)
    return p


ANIMS = {
    "idle": [pose(), pose(head=(1, 2), peck=True), pose(head=(1, 3), peck=True), pose(head=(0, 1))],
    # A step at a time, the head jerking forward then holding still.
    "walk": [pose(dy=d, head=(h, 0), legs=legs) for d, h, legs in [
        (0, -1, ((2, 0), (-2, 0))), (-1, 0, ((1, -1), (-1, 0))), (0, 1, ((0, -2), (0, 0))), (0, 2, ((-1, -1), (1, 0))),
        (0, -1, ((-2, 0), (2, 0))), (-1, 0, ((-1, 0), (1, -1))), (0, 1, ((0, 0), (0, -2))), (0, 2, ((1, 0), (-1, -1)))]],
    "windup": [pose(dy=round(k * 0.4), head=(-round(k * 0.5), 0), wing=1 if k > 2 else 0, tail=1 if k > 1 else 0) for k in range(6)],
    "lunge": [pose(dx=dx, dy=dy, head=(2, 1), wing=w, legs=((-2, -2), (-3, -1)), tail=1) for dx, dy, w in
              ((2, -2, 2), (4, -4, 3), (6, -5, 2), (7, -4, 3), (7, -2, 2), (6, 0, 1))],
    "hurt": [pose(dy=-1, head=(-2, -1), wing=1, feather=(30, 48)), pose(dy=-2, head=(-2, -1), wing=2, feather=(28, 44)), pose(head=(-1, 0), feather=(27, 52))],
    "death": [pose(), pose(head=(-2, -1), wing=1), pose(dy=2, head=(-2, 1), wing=2), pose(dy=4, sit=True, head=(-1, 3)),
              pose(lying=True, eye_shut=True, feather=(36, 50)), pose(lying=True, eye_shut=True, feather=(38, 56)),
              pose(lying=True, eye_shut=True, feather=(40, 62)), pose(lying=True, eye_shut=True)],
    "rest": [pose(sit=True), pose(sit=True, dy=-1), pose(sit=True, eye_shut=True), pose(sit=True, dy=-1, eye_shut=True)],
    "scratch": [pose(head=(1, 2), legs=((0, 0), (-3, -1))), pose(head=(1, 2), legs=((0, 0), (-5, -2))),
                pose(head=(1, 3), peck=True, legs=((0, 0), (-3, 0))), pose(head=(1, 3), peck=True)],
    "stretch": [pose(wing=1), pose(wing=3, legs=((0, 0), (-3, -1))), pose(wing=3, legs=((0, 0), (-4, -1)), tail=1), pose(wing=1)],
}


def draw(spec, p):
    c = Canvas()
    bx, by = spec["body_at"]
    bx += p["dx"]
    by += p["dy"]
    rx, ry = spec["body"]
    if p["lying"]:
        return _lying(spec, c, bx, rx, ry, p)
    sit = 3 if p["sit"] else 0
    by += sit
    # Legs first, behind the body: thin shanks with scales, toes splayed.
    if not p["sit"]:
        for k, (lx, ly) in enumerate(p["legs"]):
            x = bx - 2 + k * 3 + lx
            top = by + ry - 1
            foot = GROUND + ly
            for y in range(top, foot):
                c.put(x, y, spec["legs"][0] if (y + k) % 3 else spec["legs"][1])
            # Three toes forward, one back.
            for t in range(1, 3 if spec["leg_len"] < 4 else 4):
                c.put(x + t, foot, spec["legs"][0])
            c.put(x - 1, foot, spec["legs"][1])
            c.put(x, foot, spec["legs"][1])
    _tail(spec, c, bx, by, rx, ry, p)
    c.blob(bx, by, rx, ry, spec["feathers"])
    if spec["breast"]:
        for y in range(by - 1, by + ry):
            for x in range(bx + rx - 4, bx + rx + 1):
                u, v = (x + 0.5 - bx) / rx, (y + 0.5 - by) / ry
                if u * u + v * v <= 0.92 and (x + y) % 3:
                    c.put(x, y, spec["breast"][0])
        # The pheasant's dark scalloped spots.
        for k in range(7):
            x, y = bx - rx + 3 + k * 2, by - 1 + (k % 3)
            c.put(x, y, spec["feathers"][3])
    _wing(spec, c, bx, by, rx, ry, p)
    _head(spec, c, bx, by, rx, ry, p)
    if p["feather"]:
        fx, fy = p["feather"]
        c.put(fx, fy, spec["feathers"][1])
        c.put(fx + 1, fy + 1, spec["feathers"][2])
    c.outline(spec["outline"])
    c.shadow(bx, rx + 2)
    return c.img


def _tail(spec, c, bx, by, rx, ry, p):
    t = spec["tail"]
    lift = p["tail"]
    x0, y0 = bx - rx + 1, by - 1
    if spec["tail_kind"] == "hen":
        # An upright fan of tail feathers at the rump.
        for k in range(4):
            x = x0 - k
            for y in range(y0 - spec["tail_len"] + k - lift, y0 + 2):
                c.put(x, y, t[0] if k == 0 else t[1] if k < 3 else t[2])
        c.put(x0 - 4, y0 - 2 - lift, t[2])
    elif spec["tail_kind"] == "long":
        # A long barred tail streaming back and a little up.
        for k in range(spec["tail_len"]):
            x = x0 - k
            y = y0 - k // 4 - lift
            for d in range(2):
                c.put(x, y + d, t[2] if k % 4 == 0 else t[0] if d == 0 else t[1])
    else:
        c.put(x0, y0, t[1])
        c.put(x0 - 1, y0 - 1, t[2])


def _wing(spec, c, bx, by, rx, ry, p):
    w = spec["wing"]
    state = p["wing"]
    if state == 0:
        # Folded on the side: rows of feathers, tips toward the tail.
        cy = by + 1
        wrx, wry = max(rx - 3, 2), max(ry - 3, 1.5)
        rows = {}
        for y in range(int(cy - wry - 1), int(cy + wry + 2)):
            for x in range(int(bx - 1 - wrx - 1), int(bx - 1 + wrx + 2)):
                u, v = (x + 0.5 - (bx - 1)) / wrx, (y + 0.5 - cy) / wry
                if u * u + v * v <= 1.0:
                    rows.setdefault(y, []).append(x)
        ys = sorted(rows)
        for i, y in enumerate(ys):
            for x in rows[y]:
                # Lit along its top, a feather edge along its lower rim.
                c.put(x, y, w[0] if i == 0 else w[2] if i == len(ys) - 1 else w[1])
        # The long flight feathers' tips toward the tail.
        if ys:
            left = min(rows[ys[-1]])
            for k in range(3):
                c.put(left - 1 - k, ys[-1] - k // 2, w[2])
        return
    # Lifted: the wing raised above the back, spread wider each step.
    span = {1: 4, 2: 7, 3: 9}[state]
    for k in range(span):
        x = bx + 2 - k
        top = by - ry - k // 2 - (2 if state > 1 else 0)
        for y in range(top, by - 1):
            c.put(x, y, w[0] if y == top else w[1] if (y - top) < 3 else w[2])
        if k % 2 == 0:
            c.put(x, top - 1, w[2])


def _head(spec, c, bx, by, rx, ry, p):
    hx0, hy0 = spec["head_at"]
    hx = hx0 + p["dx"] + p["head"][0]
    hy = hy0 + p["dy"] + p["head"][1] + (3 if p["sit"] else 0)
    r = spec["head_r"]
    tones = spec["head"]
    # The neck joining head to breast.
    for k in range(4):
        x = hx - 2 + (bx + rx - 2 - (hx - 2)) * k // 3
        y = hy + 2 + (by - 2 - (hy + 2)) * k // 3
        c.blob(x, y, 2.2, 2.2, spec["feathers"] if spec["collar"] is None or k > 1 else tones)
    if spec["collar"]:
        x = hx - 1 + (bx + rx - hx) // 3
        y = hy + r
        for d in range(-1, 2):
            c.put(x + d, y + 1, spec["collar"])
    c.blob(hx, hy, r, r, tones)
    if spec["comb"]:
        for k, dx in enumerate((-2, -1, 0, 1)):
            for d in range(2 if k % 2 == 0 else 1):
                c.put(hx + dx, hy - r - d, spec["comb"][0] if d == 0 else spec["comb"][1])
    if spec["patch"]:
        c.put(hx + 1, hy - 1, spec["patch"])
        c.put(hx + 2, hy - 1, spec["patch"])
        c.put(hx + 1, hy, spec["patch"])
    # Beak, pointing down when it pecks.
    bkx, bky = hx + r, hy + (1 if p["peck"] else 0)
    c.put(bkx, bky, spec["beak"][0])
    c.put(bkx + 1, bky, spec["beak"][0])
    c.put(bkx + 2 if not p["peck"] else bkx + 1, bky + (0 if not p["peck"] else 1), spec["beak"][1])
    c.put(bkx, bky + 1, spec["beak"][1])
    if spec["wattle"]:
        c.put(bkx - 1, bky + 2, spec["comb"][0])
        c.put(bkx - 1, bky + 3, spec["comb"][1])
    # The eye (shut, a line).
    ex, ey = hx + 1, hy - 1
    if p["eye_shut"]:
        c.put(ex, ey + 1, spec["outline"])
    else:
        c.put(ex, ey, spec["eye"])
        if spec["eye"][0] > 200:
            c.put(ex, ey + 1, C("1a1414"))


def _lying(spec, c, bx, rx, ry, p):
    """On its side: the body flat on the ground, the legs stiff in the air,
    the head lolled forward."""
    by = GROUND - ry + 1
    t = spec["tail"]
    for k in range(min(spec["tail_len"], 10)):
        c.put(bx - rx - k, by + 1 + k // 5, t[1] if k % 3 else t[2])
    for k, lx in enumerate((-2, 1)):
        x = bx + lx
        for y in range(by - ry - 4 + k, by - ry + 1):
            c.put(x + (by - ry - y) // 2, y, spec["legs"][0])
        c.put(x + 3, by - ry - 4 + k, spec["legs"][1])
    c.blob(bx, by, rx, ry - 1, spec["feathers"])
    hx, hy = bx + rx + 2, by + 2
    c.blob(hx, hy, spec["head_r"], spec["head_r"] - 1, spec["head"])
    if spec["comb"]:
        c.put(hx, hy - spec["head_r"], spec["comb"][0])
        c.put(hx + 1, hy - spec["head_r"], spec["comb"][1])
    c.put(hx + spec["head_r"], hy + 1, spec["beak"][0])
    c.put(hx + spec["head_r"] + 1, hy + 1, spec["beak"][1])
    c.put(hx + 1, hy - 1, spec["outline"])
    c.put(hx + 2, hy, spec["outline"])
    if p["feather"]:
        fx, fy = p["feather"]
        c.put(fx, fy, spec["feathers"][1])
        c.put(fx + 1, fy + 1, spec["feathers"][2])
    c.outline(spec["outline"])
    c.shadow(bx, rx + 3)
    return c.img


def draw_back(spec, p):
    """Walking away: the round rump and tail toward us, legs stepping
    below, the top of the head over the back."""
    c = Canvas()
    bx, by = 44, spec["body_at"][1] + p["dy"]
    rx, ry = spec["body"]
    half = max(3, rx - 3)
    if not p["sit"]:
        for k, (lx, ly) in enumerate(p["legs"]):
            x = bx - 2 + k * 4
            for y in range(by + ry - 1, GROUND + min(ly, 0)):
                c.put(x, y, spec["legs"][0])
    c.blob(bx, by, half, ry, spec["feathers"])
    c.blob(bx, by - ry - 1 + p["head"][1] // 2, spec["head_r"], spec["head_r"], spec["head"])
    if spec["comb"]:
        for dx in (-1, 0, 1):
            c.put(bx + dx, by - ry - 1 - spec["head_r"], spec["comb"][0])
    t = spec["tail"]
    for k in range(3 if spec["tail_kind"] != "long" else 2):
        for y in range(by - ry - (spec["tail_len"] // 2 if spec["tail_kind"] == "hen" else 1), by + 2):
            c.put(bx - 1 + k, y, t[k % 3])
    if spec["tail_kind"] == "long":
        for y in range(by, by + 10):
            c.put(bx, y, t[2] if y % 4 == 0 else t[0])
            c.put(bx + 1, y, t[1])
    c.outline(spec["outline"])
    c.shadow(bx, half + 2)
    return c.img


def sheet(spec):
    out = Image.new("RGBA", (8 * F, (len(ROWS) + len(BACK_ROWS)) * F), (0, 0, 0, 0))
    for row, (name, count) in enumerate(ROWS):
        frames = ANIMS[name]
        for col in range(count):
            out.paste(draw(spec, frames[col % len(frames)]), (col * F, row * F))
    for k, (name, count) in enumerate(BACK_ROWS):
        frames = ANIMS[name]
        for col in range(count):
            out.paste(draw_back(spec, frames[col % len(frames)]), (col * F, (len(ROWS) + k) * F))
    return out


def main():
    for name, spec in SPECIES.items():
        sheet(spec).save(os.path.join(ROOT, name + ".png"))
    print("birds drawn:", ", ".join(SPECIES))


if __name__ == "__main__":
    main()
