#!/usr/bin/env python3
"""The common monsters, drawn pixel by pixel from a skeleton.

Every frame is drawn afresh, not moved or turned from another: the joints
of the pose are placed, and each body part (round masses for chest, loins
and haunches, tapering limbs, a skull and muzzle, a tail) is filled whole
pixel by whole pixel and lit as a solid from the upper left, in five tones
of its own colour. Fur breaks its edge into tufts where fur hangs (throat,
belly, tail), so a wolf does not read as a box on sticks. Parts that cross
the body (the near legs) are parted from it by a line of their deepest
tone; the whole beast is outlined in a dark tone of its own coat.

Drawn here:
- frost_wolf: a pale ice-blue wolf, ice shards along its spine;
- rot_hound: a mangy, starved hound, its ribs showing through the hide;
- sand_scorpion: a plated scorpion, its tail arched over its back;
- bog_slime: a murky bog slime that squashes, stretches and hops;
- husk: a hunched, hollow thing on two legs, bone spurs up its back,
  long arms ending in claws, its jaw hanging; it swipes with a smear of
  pale light and falls forward onto its face.

Each sheet has the nine rows of EnemyAnimator.ROWS plus the pets' rest,
scratch and stretch, 96-pixel frames, facing right (the game mirrors it).
They are drawn at the size they are shown, so the game never scales them.

Run from the repository root:  python3 tools/generate_predators.py [name ...]
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "sprites", "enemies")
F = 96
GROUND = 72
ROWS = [("idle", 4), ("walk", 8), ("windup", 6), ("lunge", 6), ("hurt", 3), ("death", 8), ("rest", 4), ("scratch", 4), ("stretch", 4)]
LIGHT = np.array([-0.5, -0.72, 0.48])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
YY, XX = np.mgrid[0:F, 0:F].astype(float) + 0.5


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def ramp(*hexes):
    return [C(h) for h in hexes]


# ------------------------------------------------------------------ shapes
# Each shape gives (inside mask, normal x, normal y, normal z) on the grid.
def ellipse(cx, cy, rx, ry, tufts=None):
    dx = (XX - cx) / rx
    dy = (YY - cy) / ry
    d = np.sqrt(dx * dx + dy * dy)
    edge = np.ones_like(d)
    if tufts:
        edge = edge + _tufts(np.arctan2(dy, dx), tufts)
    inside = d <= edge
    nz = np.sqrt(np.clip(1.0 - (d / edge) ** 2, 0.0, 1.0))
    return inside, dx / np.maximum(edge, 1e-6), dy / np.maximum(edge, 1e-6), nz


def capsule(ax, ay, bx, by, ra, rb, tufts=None):
    vx, vy = bx - ax, by - ay
    length2 = max(vx * vx + vy * vy, 1e-6)
    t = np.clip(((XX - ax) * vx + (YY - ay) * vy) / length2, 0.0, 1.0)
    px, py = ax + vx * t, ay + vy * t
    ox, oy = XX - px, YY - py
    r = ra + (rb - ra) * t
    d = np.sqrt(ox * ox + oy * oy)
    edge = r.copy()
    if tufts:
        edge = r * (1.0 + _tufts(np.arctan2(oy, ox), tufts))
    inside = d <= edge
    nz = np.sqrt(np.clip(1.0 - (d / edge) ** 2, 0.0, 1.0))
    return inside, ox / edge, oy / edge, nz


def polygon(points, nx=0.0, ny=0.0):
    """A flat polygon (an ear, a shard, a claw) facing (nx, ny)."""
    inside = np.zeros((F, F), bool)
    n = len(points)
    for k in range(n):
        x0, y0 = points[k]
        x1, y1 = points[(k + 1) % n]
        crosses = (y0 <= YY) != (y1 <= YY)
        with np.errstate(divide="ignore", invalid="ignore"):
            xcut = x0 + (YY - y0) / (y1 - y0) * (x1 - x0)
        inside ^= crosses & (XX < xcut)
    z = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
    return inside, np.full((F, F), nx), np.full((F, F), ny), np.full((F, F), z)


def _tufts(angle, spec):
    """Pointed tufts of fur along part of an edge: spec = (from, to, count,
    depth), angles in radians (0 is right, pi/2 is down)."""
    lo, hi, count, depth = spec
    a = np.mod(angle - lo, math.tau)
    span = np.mod(hi - lo, math.tau)
    on = a <= span
    saw = np.abs(np.mod(a / span * count, 1.0) - 0.5) * 2.0
    return np.where(on, depth * (1.0 - saw) * np.sin(np.clip(a / span, 0, 1) * math.pi) ** 0.5, 0.0)


def union(*shapes):
    """Shapes as one mass: where they overlap, the one whose surface stands
    furthest out (its normal z) wins, so the masses melt into each other."""
    inside = np.zeros((F, F), bool)
    nx = np.zeros((F, F))
    ny = np.zeros((F, F))
    nz = np.full((F, F), -1.0)
    for s_in, s_nx, s_ny, s_nz in shapes:
        take = s_in & (s_nz > nz)
        nx = np.where(take, s_nx, nx)
        ny = np.where(take, s_ny, ny)
        nz = np.where(take, s_nz, nz)
        inside |= s_in
    return inside, nx, ny, np.clip(nz, 0, 1)


# ------------------------------------------------------------------ canvas
class Canvas:
    def __init__(self):
        self.rgba = np.zeros((F, F, 4), np.uint8)
        self.layer = np.full((F, F), -1, int)
        self.count = 0
        self.body = np.zeros((F, F), bool)

    def paint(self, shape, tones, seam=None, bands=(0.86, 0.55, 0.14, -0.3), only=None, under=False):
        """Fills a shape lit from the upper left in its five tones. `seam`
        is a tone drawn along the shape's edge where it lies over pixels
        already drawn (to part a near leg from the body); `only` limits the
        seam to a mask. `under` draws only where nothing is yet."""
        inside, nx, ny, nz = shape
        if under:
            inside = inside & (self.layer < 0)
        lit = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
        tone = np.select([lit > bands[0], lit > bands[1], lit > bands[2], lit > bands[3]], [0, 1, 2, 3], 4)
        before = self.layer >= 0
        self.count += 1
        for k in range(5):
            m = inside & (tone == k)
            self.rgba[m] = tones[k]
        if seam is not None:
            edge = inside & ~_shrink(inside) & before
            if only is not None:
                edge &= only
            self.rgba[edge] = seam
        self.layer[inside] = self.count
        return inside

    def put(self, x, y, colour):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < F and 0 <= y < F:
            self.rgba[y, x] = colour
            if self.layer[y, x] < 0:
                self.count += 1
                self.layer[y, x] = self.count

    def recolour(self, mask, frm, to):
        """Swaps one set of tones for another inside a mask (markings)."""
        for a, b in zip(frm, to):
            hit = mask & np.all(self.rgba == np.array(a, np.uint8), axis=2)
            self.rgba[hit] = b

    def outline(self, colour):
        filled = self.layer >= 0
        ring = _grow(filled) & ~filled
        self.rgba[ring] = colour
        self.layer[ring] = 0

    def shadow(self, cx, half, alpha=70):
        for y in range(GROUND - 2, GROUND + 3):
            w = half * math.sqrt(max(0.0, 1 - ((y - GROUND) / 2.6) ** 2))
            for x in range(int(cx - w), int(cx + w) + 1):
                if 0 <= x < F and self.rgba[y, x, 3] == 0:
                    self.rgba[y, x] = (0, 0, 0, alpha)

    def shadow_at(self, cx, cy, half, ry, alpha=70):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            w = half * math.sqrt(max(0.0, 1 - ((y + 0.5 - cy) / ry) ** 2))
            for x in range(int(cx - w), int(cx + w) + 1):
                if 0 <= x < F and 0 <= y < F and self.rgba[y, x, 3] == 0:
                    self.rgba[y, x] = (0, 0, 0, alpha)

    def image(self):
        return Image.fromarray(self.rgba, "RGBA")


def _shrink(m):
    out = m.copy()
    out[1:, :] &= m[:-1, :]
    out[:-1, :] &= m[1:, :]
    out[:, 1:] &= m[:, :-1]
    out[:, :-1] &= m[:, 1:]
    return out


def _grow(m):
    out = m.copy()
    out[1:, :] |= m[:-1, :]
    out[:-1, :] |= m[1:, :]
    out[:, 1:] |= m[:, :-1]
    out[:, :-1] |= m[:, 1:]
    return out


def darker(tones, k=0.8):
    return [tuple(int(v * k) for v in t[:3]) + (255,) for t in tones]


# ================================================================== canines
def canine_pose(**kw):
    p = dict(bx=0.0, by=0.0, pitch=0.0, hx=0.0, hy=0.0, nod=0.0, jaw=0.0, ears=0.0, eye="open",
             tail=0.0, tail_lift=0.0, hackles=0.0,
             legs=[(0, 0), (0, 0), (0, 0), (0, 0)], bend=[0, 0, 0, 0], lying=0.0, side=0.0, shadow=1.0, breathe=0.0)
    p.update(kw)
    return p


def _trot():
    out = []
    for i in range(8):
        a = i / 8 * math.tau
        s = math.sin(a)
        c = math.cos(a)
        # Diagonal pairs: near front with far hind.
        A = (3.2 * s, max(0.0, c) * 2.6)
        B = (-3.2 * s, max(0.0, -c) * 2.6)
        bob = -1 if i % 4 in (1, 2) else 0
        out.append(canine_pose(by=bob, hy=0.5 * (i % 4 == 2), legs=[A, B, B, A], tail=0.25 * math.sin(a * 2), ears=0.0))
    return out


CANINE_ANIMS = {
    "idle": [canine_pose(), canine_pose(breathe=1), canine_pose(breathe=1, tail=0.15), canine_pose(tail=0.1, ears=0.4)],
    "walk": _trot(),
    "windup": [canine_pose(bx=-k * 0.8, by=k * 0.7, pitch=k * 0.6, hx=-k * 0.3, hy=k * 0.9, nod=k * 0.05, jaw=min(1.0, k / 4) * 0.55,
                           ears=min(1.0, k / 3), hackles=min(1.0, k / 3), tail=-0.15 * k / 5, tail_lift=-0.1,
                           legs=[(1, 0), (1, 0), (-1, 0), (-1, 0)], bend=[k * 0.6] * 4)
               for k in (0, 1, 2, 3.5, 4.5, 5)],
    "lunge": [canine_pose(bx=x, by=y, pitch=pt, hx=hx, hy=hy, jaw=j, ears=1, hackles=1, tail=0.3, tail_lift=0.3 if y < 0 else 0,
                          legs=lg, bend=bd)
              for x, y, pt, hx, hy, j, lg, bd in (
                  (2, -1, -1, 1, 0, 0.8, [(3, 1), (2, 1), (-3, 0), (-4, 0)], [0, 0, 1, 1]),
                  (6, -4, -2, 2, -1, 1.0, [(7, 4), (6, 3), (-7, 2), (-8, 3)], [0, 0, 0, 0]),
                  (9, -3, -1, 3, 0, 1.0, [(7, 3), (6, 2), (-6, 3), (-7, 3)], [0, 0, 0, 0]),
                  (9, 0, 1, 3, 2, 0.4, [(4, 0), (3, 0), (-3, 1), (-4, 0)], [2, 2, 0, 0]),
                  (5, 0, 0.5, 1, 1, 0.2, [(2, 0), (1, 0), (-1, 0), (-2, 0)], [1, 1, 0, 0]),
                  (2, 0, 0, 0, 0, 0.0, [(1, 0), (0, 0), (0, 0), (-1, 0)], [0, 0, 0, 0]))],
    "hurt": [canine_pose(bx=-3, by=0, pitch=-1, hx=-1, hy=-2, jaw=0.6, eye="shut", ears=1, tail=-0.4),
             canine_pose(bx=-4, by=1, pitch=0, hx=-2, hy=0, jaw=0.2, eye="shut", ears=1, tail=-0.3, bend=[1, 1, 1, 1]),
             canine_pose(bx=-1, ears=0.5)],
    "death": [canine_pose(bx=-3, hx=-1, hy=-2, jaw=0.7, eye="shut", ears=1),
              canine_pose(bx=-4, by=2, pitch=2, hy=2, jaw=0.4, eye="shut", ears=1, bend=[2, 2, 1, 1]),
              canine_pose(bx=-4, by=4, pitch=3, hy=4, eye="shut", ears=1, bend=[4, 4, 3, 3], tail=-0.3),
              canine_pose(bx=-4, lying=0.5, side=0.5, hy=5, eye="shut", ears=1, tail=-0.4),
              canine_pose(bx=-4, lying=1.0, side=1.0, hy=6, eye="dead", ears=1, tail=-0.6, shadow=1.2),
              canine_pose(bx=-4, lying=1.0, side=1.0, hy=6, eye="dead", ears=1, tail=-0.6, shadow=1.2),
              canine_pose(bx=-4, lying=1.0, side=1.0, hy=6, eye="dead", ears=1, tail=-0.6, shadow=1.2),
              canine_pose(bx=-4, lying=1.0, side=1.0, hy=6, eye="dead", ears=1, tail=-0.6, shadow=1.2)],
    "rest": [canine_pose(lying=1.0, hy=5, nod=0.1, tail=-0.5), canine_pose(lying=1.0, hy=5, nod=0.1, tail=-0.5, breathe=1),
             canine_pose(lying=1.0, hy=6, nod=0.15, eye="shut", tail=-0.5, breathe=1), canine_pose(lying=1.0, hy=6, nod=0.15, eye="shut", tail=-0.45)],
    "scratch": [canine_pose(hx=2, hy=8, nod=0.45, tail=0.2), canine_pose(hx=2, hy=9, nod=0.5, tail=0.3, jaw=0.2),
                canine_pose(hx=2, hy=8, nod=0.45, tail=0.15), canine_pose(hx=2, hy=9, nod=0.5, tail=0.3, ears=0.4)],
    "stretch": [canine_pose(), canine_pose(pitch=3, hx=2, hy=4, legs=[(3, 0), (3, 0), (0, 0), (0, 0)], tail=0.3, tail_lift=0.3),
                canine_pose(pitch=5, hx=3, hy=6, jaw=0.5, legs=[(5, 0), (5, 0), (0, 0), (0, 0)], tail=0.4, tail_lift=0.4, eye="shut"),
                canine_pose(pitch=2, hx=1, hy=2, legs=[(2, 0), (2, 0), (0, 0), (0, 0)], tail=0.2)],
}


def canine(spec, p):
    s = spec["scale"]
    cv = Canvas()
    fur, far_fur = spec["fur"], darker(spec["fur"], 0.72)
    out = spec["out"]
    lying = p["lying"]
    rx = 44 + p["bx"]
    leg_h = spec["leg"] * s
    # The back: shoulders and hips, front dipped by pitch; lying lowers all.
    lift = leg_h * (1 - lying * 0.72)
    sh = (rx + 9 * s, GROUND - lift - 6 * s + p["by"] + p["pitch"] + p["breathe"] * 0.0)
    hp = (rx - 11 * s, GROUND - lift - 6 * s + p["by"] - p["pitch"] * 0.3)
    cv.shadow(rx, 22 * s * p["shadow"])

    def leg(i, far):
        dx, up = p["legs"][i]
        bend = p["bend"][i]
        front = i < 2
        tones = far_fur if far else fur
        top = sh if front else hp
        ox = -1.5 if far else 0.0
        if lying >= 0.5:
            # Folded: front legs stretched out ahead along the ground, hind
            # legs tucked under the haunch.
            if front:
                a = (top[0] + ox, GROUND - 4)
                b = (top[0] + 7 * s + ox + (2 if far else 0), GROUND - 2)
                cv.paint(union(capsule(a[0], a[1], b[0], b[1], 2.6 * s, 2.0 * s), ellipse(b[0] + 1.5, GROUND - 1.8, 2.6 * s, 1.6)),
                         tones, seam=None if far else tones[4], only=None if far else cv.body)
            else:
                cv.paint(union(ellipse(top[0] + 1 + ox, GROUND - 5, 6 * s, 4.5 * s), ellipse(top[0] + 6 * s + ox, GROUND - 1.8, 3.0 * s, 1.6)),
                         tones, seam=None if far else tones[4], only=None if far else cv.body)
            return
        foot = (top[0] + dx + ox + (1 if front else 0), GROUND - 1 - up)
        if front:
            elbow = (top[0] - 1.0 * s + ox + dx * 0.25, top[1] + 7 * s + bend * 0.6)
            wrist = (foot[0] - 0.5 - up * 0.5, foot[1] - 3.5 * s + (0 if up < 1 else 1))
            if up >= 1:
                wrist = (foot[0] - 1.5, foot[1] - 2.5)
            shape = union(capsule(top[0] + ox, top[1] - 2, elbow[0], elbow[1], 4.2 * s, 2.6 * s),
                          capsule(elbow[0], elbow[1], wrist[0], wrist[1], 2.3 * s, 1.8 * s),
                          capsule(wrist[0], wrist[1], foot[0] + 0.5, foot[1] - 0.6, 1.8 * s, 1.7 * s),
                          ellipse(foot[0] + 1.2, foot[1] - 0.6, 2.4 * s, 1.4))
            low = top[1] + 6 * s
        else:
            stifle = (top[0] + 3.0 * s + ox + dx * 0.3, top[1] + 7.5 * s + bend * 0.5)
            hock = (top[0] - 3.0 * s + ox + dx * 0.6, GROUND - 5.5 * s - up + bend * 0.3)
            shape = union(capsule(top[0] + ox, top[1] - 1, stifle[0], stifle[1], 6.0 * s, 3.2 * s),
                          capsule(stifle[0], stifle[1], hock[0], hock[1], 2.8 * s, 1.8 * s),
                          capsule(hock[0], hock[1], foot[0] - 0.5, foot[1] - 0.6, 1.8 * s, 1.7 * s),
                          ellipse(foot[0] + 0.6, foot[1] - 0.6, 2.4 * s, 1.4))
            low = top[1] + 4 * s
        cv.paint(shape, tones, seam=None if far else tones[4], only=None if far else (cv.body & (YY > low)))

    # Far legs, then the tail behind the body.
    leg(1, True)
    leg(3, True)
    _canine_tail(cv, spec, p, hp, s)
    # The body: deep chest, tucked loin, round haunch, all one mass.
    chest_y = sh[1] + 3 * s
    body = union(
        ellipse(sh[0] - 1 * s, chest_y + p["breathe"] * 0.5, 9.5 * s, 8.0 * s + p["breathe"] * 0.5, tufts=spec.get("chest_tufts")),
        ellipse((sh[0] + hp[0]) / 2 - 1, (sh[1] + hp[1]) / 2 + 1 * s - spec.get("tuck", 0), 9 * s, 5.2 * s - spec.get("tuck", 0),
                tufts=spec.get("belly_tufts")),
        ellipse(hp[0] + 1 * s, hp[1] + 2 * s, 7.0 * s, 6.8 * s),
    )
    cv.paint(body, fur)
    body_mask = body[0]
    cv.body = body_mask.copy()
    cv.body_layer = cv.count
    spec["marks"](cv, spec, p, sh, hp, s, body_mask, "body")
    # Near legs over the body.
    leg(0, False)
    leg(2, False)
    # Neck and head.
    _canine_head(cv, spec, p, sh, s)
    spec["marks"](cv, spec, p, sh, hp, s, body_mask, "after")
    cv.outline(out)
    return cv.image()


def _canine_tail(cv, spec, p, hp, s):
    base = (hp[0] - 5 * s, hp[1] - 1 * s)
    swing = p["tail"]
    lift = p["tail_lift"]
    pts = [base]
    a = math.pi * 0.92 - swing * 0.5 - lift
    seg = spec["tail_len"] * s / 4
    for k in range(4):
        a -= 0.1 + 0.05 * k - swing * 0.3
        x, y = pts[-1]
        pts.append((x + math.cos(a) * seg, y + math.sin(a) * seg))
    shapes = []
    radii = spec["tail_r"]
    for k in range(4):
        (ax, ay), (bx, by) = pts[k], pts[k + 1]
        shapes.append(capsule(ax, ay, bx, by, radii[k] * s, radii[k + 1] * s, tufts=spec.get("tail_tufts")))
    cv.paint(union(*shapes), spec.get("tail_fur", spec["fur"]))
    if spec.get("tail_tip"):
        x, y = pts[-1]
        cv.paint(ellipse(x, y, 1.6 * s, 1.6 * s), spec["tail_tip"], under=False)


def _canine_head(cv, spec, p, sh, s):
    fur = spec["fur"]
    lying = p["lying"]
    hx = sh[0] + 9 * s + p["hx"]
    hy = sh[1] - 6 * s + p["hy"] + lying * 2
    nod = p["nod"]
    # The neck, thick, a ruff of fur at its throat.
    cv.paint(capsule(sh[0] + 1 * s, sh[1] + 2 * s, hx - 2 * s, hy + 1 * s, 6.2 * s, 4.6 * s, tufts=spec.get("ruff")), fur)
    # Ears behind the skull: the far one first, laid back by p["ears"].
    back = p["ears"] * 2.5
    for far in (True, False):
        ox = -2.2 * s if far else 0
        tones = darker(fur, 0.8) if far else fur
        base_x = hx - 1.0 * s + ox
        tip = (base_x - 1.0 * s - back * 1.2, hy - 9.5 * s + back * 1.3)
        cv.paint(polygon([(base_x - 2.2 * s, hy - 2.5 * s), (tip[0], tip[1]), (base_x + 2.4 * s, hy - 3.0 * s)], -0.3, -0.4), tones)
        if not far:
            cv.paint(polygon([(base_x - 0.8 * s, hy - 3.5 * s), (tip[0] + 0.3, tip[1] + 2.5), (base_x + 1.0 * s, hy - 3.5 * s)], 0.2, 0.2),
                     [spec["ear_in"]] * 5)
    # Skull, then the muzzle running forward and a little down.
    cv.paint(ellipse(hx, hy, 5.4 * s, 4.8 * s, tufts=spec.get("cheek_tufts")), fur)
    angle = 0.22 + nod
    mlen = spec["muzzle"] * s
    tipx, tipy = hx + 3 * s + math.cos(angle) * mlen, hy + 0.5 * s + math.sin(angle) * mlen
    jaw = p["jaw"]
    # The lower jaw drops open as a separate piece behind the upper muzzle.
    if jaw > 0.05:
        ja = angle + 0.45 * jaw
        jx, jy = hx + 2 * s + math.cos(ja) * mlen * 0.9, hy + 2 * s + math.sin(ja) * mlen * 0.9
        cv.paint(capsule(hx + 1 * s, hy + 2.2 * s, jx, jy, 2.4 * s, 1.4 * s), darker(fur, 0.86))
        # The mouth's dark inside and teeth.
        mouth = capsule(hx + 3 * s, hy + 1.8 * s, (tipx + jx) / 2, (tipy + jy) / 2 - 0.4, 1.0 * s * jaw + 0.6, 0.6 * jaw + 0.4)
        cv.paint(mouth, [spec["mouth"]] * 5)
        for k in range(3):
            t = 0.35 + k * 0.25
            cv.put(hx + 3 * s + (tipx - hx - 3 * s) * t, hy + 1.6 * s + (tipy - hy - 1.6 * s) * t + 0.8, spec["teeth"])
            cv.put(hx + 3 * s + (jx - hx - 3 * s) * t, hy + 2.2 * s + (jy - hy - 2.2 * s) * t - 0.6, spec["teeth"])
    cv.paint(capsule(hx + 2 * s, hy + 0.2 * s, tipx, tipy, 3.0 * s, 1.9 * s), fur)
    if spec.get("muzzle_light"):
        cv.recolour(capsule(hx + 2 * s, hy + 2.0 * s, tipx, tipy + 1.0 * s, 1.6 * s, 1.0 * s)[0], fur[1:4], spec["muzzle_light"])
    # Nose, eye, brow.
    cv.put(tipx + 1.2 * s - 0.5, tipy - 0.8 * s, spec["nose"])
    cv.put(tipx + 1.2 * s - 0.5, tipy - 0.8 * s + 1, spec["nose"])
    cv.put(tipx + 0.2 * s - 0.5, tipy - 0.8 * s, spec["nose"])
    ex, ey = hx + 2.2 * s, hy - 1.4 * s
    eye = p["eye"]
    if eye == "open":
        cv.put(ex, ey, spec["eye"])
        cv.put(ex + 1, ey, spec["eye_hot"])
        cv.put(ex - 1, ey + 1, darker([spec["eye"]], 0.6)[0])
        cv.put(ex - 1, ey - 1, fur[4])
        cv.put(ex, ey - 1, fur[4])
        if spec.get("eye_glow"):
            cv.put(ex + 2, ey, spec["eye_glow"])
    elif eye == "shut":
        cv.put(ex - 1, ey, fur[4])
        cv.put(ex, ey, fur[4])
        cv.put(ex + 1, ey + 1, fur[4])
    else:
        for d in (-1, 0, 1):
            cv.put(ex + d, ey + d, fur[4])
            cv.put(ex + d, ey - d, fur[4])


# ---- markings
def frost_marks(cv, spec, p, sh, hp, s, body, when):
    if when == "body":
        # A darker blue saddle along the back, the belly and chest paler.
        back = body & (YY < (sh[1] + hp[1]) / 2 + 0.5 + (XX - hp[0]) * 0.0)
        cv.recolour(back & (YY < sh[1] + 1), spec["fur"], darker(spec["fur"], 0.9))
        belly = body & (YY > (sh[1] + hp[1]) / 2 + 6 * s)
        cv.recolour(belly, spec["fur"][1:], spec["fur"][:4])
        return
    # Ice shards up the spine, taller with the hackles raised.
    rise = 1.0 + p["hackles"] * 0.6
    n = 5
    for k in range(n):
        t = k / (n - 1)
        x = hp[0] + 2 + (sh[0] - hp[0] + 1) * t
        y = hp[1] - 4 * s + (sh[1] - hp[1]) * t - 1.5
        h = (3.5 + 3.0 * math.sin(t * math.pi)) * s * rise * (1 - p["lying"] * 0.3)
        lean = -1.5
        ice = spec["ice"]
        # Two facets: the lit left face, the shaded right one, a bright edge.
        cv.paint(polygon([(x - 2.0 * s, y + 2), (x + lean, y - h), (x + 0.2, y + 2)]), [ice[1]] * 5)
        cv.paint(polygon([(x + 0.2, y + 2), (x + lean, y - h), (x + 1.9 * s, y + 2)]), [ice[3]] * 5)
        for j in range(int(h * 0.7)):
            t = j / max(h, 1)
            cv.put(x + lean * t + 0.1 - 0.5 * (1 - t), y + 1 - j, ice[0] if j > 1 else ice[2])


def rot_marks(cv, spec, p, sh, hp, s, body, when):
    if when == "after":
        # Mange: bare, sore patches of grey-pink hide.
        for (ox, oy, r) in ((-12, 1, 3.0), (5, 6, 2.4), (-15, -3, 2.0), (8, 0, 1.8)):
            x = (sh[0] + hp[0]) / 2 + ox * s
            y = (sh[1] + hp[1]) / 2 + oy * s
            patch = ellipse(x, y, r * s + 0.6, r * s * 0.8)[0] & body
            cv.recolour(patch, spec["fur"], spec["hide"])
        # Ribs showing through the hide: a sunken flank, each rib a bar of
        # bone curving down and back, a dark gap behind it.
        if p["lying"] < 0.5:
            flank = ellipse(sh[0] - 10 * s, sh[1] + 4 * s, 6.5 * s, 4.2 * s)[0] & body & (cv.layer == cv.body_layer)
            cv.recolour(flank, spec["fur"], spec["hide"])
            for k in range(4):
                x0 = sh[0] - 6 * s - k * 3 * s
                for j in range(int(7 * s)):
                    y = int(sh[1] + 1 * s + j)
                    x = int(x0 - (j / (7 * s)) ** 2 * 2.5)
                    if 0 <= y < F and 0 <= x < F - 1 and flank[y, x]:
                        cv.put(x, y, spec["bone"][0] if j < 2 else spec["bone"][1] if j < 5 else spec["bone"][2])
                        if flank[y, x - 1]:
                            cv.put(x - 1, y, spec["hide"][4])
        # Drool from the jaw when it snarls.
        if p["jaw"] > 0.3 and p["lying"] < 0.5:
            hx = sh[0] + 9 * s + p["hx"]
            hy = sh[1] - 6 * s + p["hy"]
            for k in range(3):
                cv.put(hx + 5 * s, hy + 4 * s + k, spec["drool"])
        return
    if when != "body":
        return
    # Bony knobs along the spine, sharper with the hackles up.
    for k in range(5):
        t = k / 4
        x = hp[0] + 1 + (sh[0] - hp[0] + 2) * t
        y = hp[1] - 4.5 * s + (sh[1] - hp[1]) * t - 0.5
        h = (2.0 + 1.8 * math.sin(t * math.pi) + p["hackles"] * 1.5) * s * (1 - p["lying"] * 0.4)
        cv.paint(polygon([(x - 1.3 * s, y + 1.5), (x - 0.6, y - h), (x, y + 1.5)]), [spec["bone"][1]] * 5)
        cv.paint(polygon([(x, y + 1.5), (x - 0.6, y - h), (x + 1.3 * s, y + 1.5)]), [spec["bone"][3]] * 5)


def wolf_spec(**kw):
    spec = dict(scale=1.0, leg=16, muzzle=6.0, tail_len=17, tail_r=(2.6, 3.4, 3.4, 2.6, 1.2),
                chest_tufts=(1.2, 2.2, 5, 0.18), belly_tufts=(1.0, 2.3, 4, 0.14), ruff=(0.9, 2.6, 5, 0.22),
                tail_tufts=(0.0, math.tau - 0.01, 7, 0.22), cheek_tufts=(1.6, 2.8, 2, 0.2),
                mouth=C("3a1218"), teeth=C("f4f0e4"), nose=C("1c1820"))
    spec.update(kw)
    return spec


CANINES = {
    "frost_wolf": wolf_spec(
        fur=ramp("eaf4fb", "bcd2e6", "8ca6c4", "647e9e", "465a7a"), out=C("1e2640"),
        ear_in=C("b0a0b8"), eye=C("7ae8ff"), eye_hot=C("e8ffff"), eye_glow=None,
        ice=ramp("e4ffff", "8eeaff", "40c0ec", "2286c4", "1a5a94"), muzzle_light=ramp("f4faff", "e2eef8", "cfe0ee"),
        tail_tip=ramp("f4faff", "e2eef8", "cfe0ee", "a8c0d6", "7c96b2"), marks=frost_marks),
    "rot_hound": wolf_spec(
        scale=1.0, leg=15, muzzle=6.5, tuck=1.6, tail_len=14, tail_r=(1.8, 1.6, 1.3, 1.0, 0.7), tail_tufts=(0.0, math.tau - 0.01, 4, 0.3),
        ruff=(0.9, 2.6, 4, 0.3), chest_tufts=(1.2, 2.2, 4, 0.22), belly_tufts=(1.0, 2.3, 3, 0.2),
        fur=ramp("9a6a58", "7a4c3e", "5c3430", "422220", "2c1414"), out=C("160a0a"),
        hide=ramp("d0a8a0", "b08680", "8c6264", "6a4448", "40262c"), bone=ramp("f0e6cc", "d8caa8", "b0a07c", "8a7a5a", "5e523c"),
        ear_in=C("6a2a2a"), eye=C("ff3a2a"), eye_hot=C("ffd0a0"), eye_glow=C("aa2020"), drool=C("c8e0a0"),
        mouth=C("2a0808"), teeth=C("e8dcc0"), marks=rot_marks),
}


# ================================================================== slime
def slime_pose(**kw):
    p = dict(w=1.0, h=1.0, bx=0.0, up=0.0, eye="open", mouth=0.0, melt=0.0, wobble=0.0, shadow=1.0, lean=0.0)
    p.update(kw)
    return p


SLIME_ANIMS = {
    "idle": [slime_pose(), slime_pose(w=1.04, h=0.96), slime_pose(w=1.06, h=0.93), slime_pose(w=1.03, h=0.97)],
    "walk": [slime_pose(w=1.12, h=0.86), slime_pose(w=0.92, h=1.12, up=1, lean=0.6), slime_pose(w=0.86, h=1.2, up=5, bx=1, lean=0.8, shadow=0.8),
             slime_pose(w=0.92, h=1.1, up=7, bx=2, shadow=0.7), slime_pose(w=0.98, h=1.02, up=5, bx=3, shadow=0.8),
             slime_pose(w=1.02, h=0.98, up=1, bx=4), slime_pose(w=1.2, h=0.8, bx=4), slime_pose(w=1.06, h=0.94, bx=2)],
    "windup": [slime_pose(w=1.06, h=0.94), slime_pose(w=1.14, h=0.86, bx=-1), slime_pose(w=1.22, h=0.78, bx=-2, mouth=0.4),
               slime_pose(w=1.3, h=0.7, bx=-2, mouth=0.7), slime_pose(w=1.34, h=0.66, bx=-3, mouth=1.0), slime_pose(w=1.36, h=0.64, bx=-3, mouth=1.0)],
    "lunge": [slime_pose(w=0.8, h=1.25, up=3, bx=2, lean=1.2, mouth=1.0, shadow=0.8), slime_pose(w=1.2, h=0.9, up=9, bx=8, lean=1.4, mouth=1.0, shadow=0.6),
              slime_pose(w=1.25, h=0.85, up=6, bx=12, lean=0.8, mouth=1.0, shadow=0.7), slime_pose(w=1.35, h=0.72, bx=13, mouth=0.6),
              slime_pose(w=1.12, h=0.9, bx=10), slime_pose(w=1.0, h=1.0, bx=4)],
    "hurt": [slime_pose(w=1.25, h=0.78, bx=-2, eye="shut", mouth=0.5), slime_pose(w=0.88, h=1.12, bx=-3, eye="shut"), slime_pose(w=1.04, h=0.96, bx=-1)],
    "death": [slime_pose(w=1.2, h=0.82, eye="shut", mouth=0.6), slime_pose(w=1.3, h=0.7, eye="shut", melt=0.15), slime_pose(w=1.42, h=0.58, eye="dead", melt=0.3),
              slime_pose(w=1.56, h=0.46, eye="dead", melt=0.5), slime_pose(w=1.7, h=0.34, eye="dead", melt=0.7, shadow=1.2),
              slime_pose(w=1.82, h=0.24, eye="none", melt=0.85, shadow=1.3), slime_pose(w=1.9, h=0.17, eye="none", melt=1.0, shadow=1.3),
              slime_pose(w=1.9, h=0.17, eye="none", melt=1.0, shadow=1.3)],
    "rest": [slime_pose(w=1.12, h=0.86, eye="shut"), slime_pose(w=1.14, h=0.84, eye="shut"), slime_pose(w=1.12, h=0.86, eye="shut"),
             slime_pose(w=1.1, h=0.88, eye="shut")],
    "scratch": [slime_pose(wobble=1.0), slime_pose(wobble=-1.0, w=1.04, h=0.96), slime_pose(wobble=1.0), slime_pose(wobble=-1.0, w=1.04, h=0.96)],
    "stretch": [slime_pose(), slime_pose(w=0.9, h=1.14), slime_pose(w=0.82, h=1.26, mouth=0.6, eye="shut"), slime_pose(w=0.94, h=1.08)],
}


def slime(spec, p):
    cv = Canvas()
    gel = spec["gel"]
    w = spec["w"] * p["w"]
    h = spec["h"] * p["h"]
    cx = 48 + p["bx"]
    base = GROUND - p["up"]
    cv.shadow(cx, w * 0.9 * p["shadow"] * (1 - p["up"] / 20), 80)
    # A dome, flat at its foot; it slides into a puddle as it melts.
    top = base - h
    cy = base - h * 0.55
    lean = p["lean"] * 2.0
    body = union(
        ellipse(cx + lean * 0.4, cy, w, h * 0.62),
        ellipse(cx, base - h * 0.26, w * 1.02, h * 0.3 + 1.5),
        ellipse(cx + lean, top + h * 0.32, w * 0.72, h * 0.34),
    )
    inside = body[0] & (YY <= base)
    if p["melt"] > 0:
        # Drips running down onto the ground around it.
        for k in range(5):
            x = cx - w + (k + 0.5) * w * 2 / 5
            inside |= capsule(x, base - 2, x + (k - 2) * p["melt"] * 3, base, 1.6, 1.0 + p["melt"] * 1.6)[0]
    body = (inside,) + body[1:]
    cv.paint(body, gel, bands=(0.82, 0.55, 0.2, -0.18))
    # Bits of the bog suspended inside: a twig, a leaf, bubbles, a bone.
    rnd = random.Random(spec["seed"])
    for kind, fx, fy in spec["bits"]:
        x = cx + fx * w
        y = base - h * 0.5 + fy * h * 0.5
        if not inside[int(min(max(y, 0), F - 1)), int(min(max(x, 0), F - 1))]:
            continue
        if kind == "twig":
            cv.paint(capsule(x - 3, y + 1, x + 3, y - 1, 0.8, 0.6), [spec["twig"]] * 5)
            cv.put(x + 1, y - 2, spec["twig"])
        elif kind == "leaf":
            cv.paint(ellipse(x, y, 2.2, 1.3), spec["leaf"])
        elif kind == "bubble":
            cv.put(x, y, gel[0])
            cv.put(x + 1, y + 1, gel[3])
        elif kind == "bone":
            cv.paint(capsule(x - 2.5, y, x + 2.5, y, 0.7, 0.7), [spec["bone"]] * 5)
            cv.put(x - 3, y - 1, spec["bone"])
            cv.put(x + 3, y + 1, spec["bone"])
    # The darker core and a light inner rim (it is see-through gel).
    core = ellipse(cx, base - h * 0.42, w * 0.55, h * 0.3)[0] & inside
    cv.recolour(core, gel[1:3], gel[2:4])
    # A wet shine: a curved highlight and a spark, upper left.
    if h > 6:
        for k in range(4):
            a = math.pi * (1.1 + k * 0.1)
            cv.put(cx + math.cos(a) * w * 0.62 + lean * 0.4, cy + math.sin(a) * h * 0.5, spec["shine"])
        cv.put(cx - w * 0.35 + lean * 0.5, top + h * 0.22, spec["shine"])
    # The face, with the wobble swinging it.
    if p["eye"] != "none" and h > 5:
        fx = cx + w * 0.28 + p["wobble"] + lean * 0.7
        fy = base - h * 0.55
        for side in (-1, 1):
            ex = fx + side * w * 0.22
            if p["eye"] == "open":
                for dy in (-2, -1, 0):
                    cv.put(ex, fy + dy, spec["eye"])
                    cv.put(ex + 1, fy + dy, spec["eye"])
                cv.put(ex + 1, fy - 2, spec["eye_shine"])
            elif p["eye"] == "shut":
                cv.put(ex - 1, fy, spec["eye"])
                cv.put(ex, fy, spec["eye"])
                cv.put(ex + 1, fy, spec["eye"])
            else:
                cv.put(ex - 1, fy - 1, spec["eye"])
                cv.put(ex + 1, fy + 1, spec["eye"])
                cv.put(ex, fy, spec["eye"])
                cv.put(ex + 1, fy - 1, spec["eye"])
                cv.put(ex - 1, fy + 1, spec["eye"])
        m = p["mouth"]
        if m > 0.1:
            mw = 1.5 + m * 2
            mh = 0.6 + m * 2
            cv.paint(ellipse(fx, fy + 4, mw, mh), [spec["mouth"]] * 5)
            cv.put(fx - mw + 1, fy + 3, spec["teeth"])
            cv.put(fx + mw - 1, fy + 3, spec["teeth"])
        else:
            cv.put(fx - 1, fy + 3, spec["eye"])
            cv.put(fx, fy + 4, spec["eye"])
            cv.put(fx + 1, fy + 3, spec["eye"])
    cv.outline(spec["out"])
    return cv.image()


SLIMES = {
    "bog_slime": dict(w=13.0, h=17.0, seed=3, gel=ramp("bcd884", "8ab052", "628a38", "456628", "2e4419"), out=C("1a2810"),
                      shine=C("f4ffd8"), eye=C("142010"), eye_shine=C("e8ffd0"), mouth=C("1c2a10"), teeth=C("e8f0c8"),
                      twig=C("4a5a22"), leaf=ramp("8a8a3a", "707030", "585a26", "44461c", "343614"), bone=C("b8c890"),
                      bits=[("twig", -0.5, 0.55), ("leaf", -0.15, 0.75), ("bubble", -0.35, -0.35), ("bubble", 0.1, 0.1),
                            ("bubble", -0.62, 0.05), ("bone", -0.62, 0.8)]),
}


# ================================================================== scorpion
def scorp_pose(**kw):
    p = dict(bx=0.0, by=0.0, curl=0.0, strike=0.0, claw=0.0, pinch=0.0, step=0.0, eye="open", flip=0.0, droop=0.0, shadow=1.0, sway=0.0)
    p.update(kw)
    return p


SCORP_ANIMS = {
    "idle": [scorp_pose(), scorp_pose(sway=0.5, by=0.0), scorp_pose(sway=1.0, pinch=0.4), scorp_pose(sway=0.5)],
    "walk": [scorp_pose(step=i / 8, by=-1 if i % 2 else 0, sway=math.sin(i / 8 * math.tau) * 0.5) for i in range(8)],
    "windup": [scorp_pose(curl=k / 5, claw=k / 5, bx=-k * 0.4, pinch=0.0) for k in range(6)],
    "lunge": [scorp_pose(strike=0.5, claw=1.0, bx=1), scorp_pose(strike=1.0, claw=0.8, bx=3, pinch=1.0), scorp_pose(strike=1.0, claw=0.6, bx=3, pinch=1.0),
              scorp_pose(strike=0.6, claw=0.4, bx=2), scorp_pose(strike=0.2, claw=0.2, bx=1), scorp_pose()],
    "hurt": [scorp_pose(bx=-3, curl=-0.3, eye="shut", claw=0.5), scorp_pose(bx=-4, by=1, curl=-0.2, eye="shut"), scorp_pose(bx=-1)],
    "death": [scorp_pose(bx=-2, eye="shut", curl=-0.2), scorp_pose(bx=-3, by=1, droop=0.25, eye="shut"), scorp_pose(bx=-3, by=2, droop=0.5, eye="shut", shadow=1.1),
              scorp_pose(bx=-3, by=3, droop=0.75, eye="dead", shadow=1.1), scorp_pose(bx=-3, by=3, droop=1.0, eye="dead", shadow=1.2),
              scorp_pose(bx=-3, by=3, droop=1.0, eye="dead", shadow=1.2), scorp_pose(bx=-3, by=3, droop=1.0, eye="dead", shadow=1.2),
              scorp_pose(bx=-3, by=3, droop=1.0, eye="dead", shadow=1.2)],
    "rest": [scorp_pose(by=2, droop=0.3, sway=0.0), scorp_pose(by=2, droop=0.3, sway=0.3), scorp_pose(by=2, droop=0.3, sway=0.6, eye="shut"),
             scorp_pose(by=2, droop=0.3, sway=0.3, eye="shut")],
    "scratch": [scorp_pose(pinch=1.0, claw=0.3), scorp_pose(pinch=0.0, claw=0.4), scorp_pose(pinch=1.0, claw=0.3), scorp_pose(pinch=0.0, claw=0.2)],
    "stretch": [scorp_pose(), scorp_pose(curl=-0.3, claw=0.5), scorp_pose(curl=-0.5, claw=0.8, pinch=1.0), scorp_pose(curl=-0.2, claw=0.3)],
}


def scorpion(spec, p):
    """Seen from above at three-quarters, the way the world is: the far
    legs fan out above the body, the near ones below, the claws spread
    forward and the tail arches up over the back. Joints are placed in 3D
    (x along the body, d toward the viewer, z up) and projected."""
    cv = Canvas()
    shell, far_shell = spec["shell"], darker(spec["shell"], 0.72)
    droop = p["droop"]
    cx = 44 + p["bx"]
    g0 = GROUND - 8 + p["by"]
    lift_body = 3.0 - droop * 1.5

    def at(x, d, z):
        return (x, g0 + d * 0.72 - z * 0.9)

    cv.shadow_at(cx + 1, g0 + 1, 18 * p["shadow"], 6.5)

    def legs(side):
        tones = far_shell if side < 0 else shell
        for k in range(4):
            x = cx + 4.5 - k * 3.4
            reach = (9.0, 4.0, -3.0, -8.0)[k]
            phase = (p["step"] + k * 0.27 + (0.5 if side < 0 else 0)) * math.tau
            swing = math.sin(phase) * 1.8 if p["step"] else 0.0
            up = max(0.0, math.cos(phase)) * 1.6 if p["step"] else 0.0
            curl = droop
            hip = at(x, side * 2.5, lift_body)
            knee = at(x + reach * 0.55 + swing * 0.5, side * (7.0 - curl * 2.5), 5.5 + up)
            foot = at(x + reach * (1 - curl * 0.6) + swing, side * (12.0 - curl * 7), up + curl * 5)
            cv.paint(union(capsule(hip[0], hip[1], knee[0], knee[1], 1.3, 1.1),
                           capsule(knee[0], knee[1], foot[0], foot[1], 1.0, 0.5)), tones,
                     seam=tones[4] if side > 0 else None, only=cv.body if side > 0 else None)

    def claw(side):
        tones = darker(spec["claw"], 0.74) if side < 0 else spec["claw"]
        raise_ = p["claw"]
        sh = at(cx + 9.0, side * 2.0, lift_body)
        el = at(cx + 13.0, side * 6.5, lift_body + raise_ * 2.5)
        hand = at(cx + 18.5 + raise_, side * 6.0, lift_body + 0.5 + raise_ * 4.0)
        cv.paint(union(capsule(sh[0], sh[1], el[0], el[1], 1.7, 1.5), capsule(el[0], el[1], hand[0], hand[1], 1.5, 2.2)), tones)
        cv.paint(ellipse(hand[0] + 1.0, hand[1], 4.2, 3.0), tones, seam=None if side < 0 else tones[4])
        gap = 0.3 + (1.0 - p["pinch"]) * 1.1
        fx, fy = hand[0] + 4.0, hand[1]
        cv.paint(polygon([(fx - 1.5, fy - 2.4), (fx + 2.6, fy - 2.8 - gap), (fx + 5.4, fy - 1.4 - gap), (fx + 4.4, fy - 0.6 - gap),
                          (fx + 1.6, fy - 1.0 - gap * 0.6), (fx - 1.0, fy - 0.4)]), [tones[1]] * 4 + [tones[2]])
        cv.paint(polygon([(fx - 1.0, fy + 0.4), (fx + 2.2, fy + 0.6 + gap * 0.5), (fx + 4.0, fy + 0.2 + gap * 0.6), (fx + 3.2, fy + 1.6 + gap * 0.6),
                          (fx - 1.0, fy + 2.2)]), [tones[2]] * 5)

    def tail():
        # Rings in the x-z plane: up from the back end, over, the sting
        # forward. curl draws it back, strike throws it over the head;
        # dying, it sags out flat behind.
        x, z = cx - 11.0, lift_body + 1.0
        x += p["strike"] * 3
        ang = math.radians(118 + p["curl"] * 22 - p["strike"] * 28 + p["sway"] * 3)
        turn = math.radians(-26 + p["curl"] * 3 + p["strike"] * 8)
        lens_k = 1.0 + p["strike"] * 0.12
        ang = ang * (1 - droop) + math.pi * droop
        turn = turn * (1 - droop) + math.radians(-3) * droop
        pts = [(x, z)]
        lens = [v * lens_k for v in (5.0, 4.8, 4.6, 4.4, 4.2)]
        for k in range(5):
            ang += turn * (0.4 if k == 0 else 1.0)
            x, z = pts[-1]
            pts.append((x + math.cos(ang) * lens[k], z + math.sin(ang) * lens[k]))
        scr = [at(px, 0, pz) for px, pz in pts]
        for k in range(5):
            (ax, ay), (bx, by) = scr[k], scr[k + 1]
            r = 3.2 - k * 0.28
            cv.paint(capsule(ax, ay, bx, by, r, r - 0.3), shell, seam=shell[4] if k else None)
        ang += turn
        bx, bz = pts[-1][0] + math.cos(ang) * 2.8, pts[-1][1] + math.sin(ang) * 2.8
        b = at(bx, 0, bz)
        cv.paint(ellipse(b[0], b[1], 3.5, 3.0), spec["bulb"], seam=shell[4])
        a2 = ang + turn * 2
        s0 = at(bx + math.cos(a2) * 2.8, 0, bz + math.sin(a2) * 2.8)
        s1 = at(bx + math.cos(a2) * 4.6 + math.cos(a2 + turn * 4) * 1.5, 0, bz + math.sin(a2) * 4.6 + math.sin(a2 + turn * 4) * 1.5)
        cv.paint(union(capsule(b[0], b[1], s0[0], s0[1], 1.4, 1.0), capsule(s0[0], s0[1], s1[0], s1[1], 1.0, 0.4)), spec["sting"])

    legs(-1)
    claw(-1)
    # The body from above: a long oval back in plates and the head shield.
    bc = at(cx - 3.0, 0, lift_body)
    hc = at(cx + 6.5, 0, lift_body)
    body = union(ellipse(bc[0], bc[1], 9.8, 4.0), ellipse(hc[0], hc[1], 5.0, 3.5))
    cv.paint(body, shell)
    cv.body = body[0].copy()
    # The plates' joins run across the back, each with a lit edge before it.
    for k in range(5):
        x = int(bc[0] - 8 + k * 3.4)
        col = [y for y in range(F) if body[0][y, x]]
        for y in col[1:-1]:
            cv.rgba[y, x] = shell[3]
            if body[0][y, x - 1]:
                cv.rgba[y, x - 1] = shell[1] if y < bc[1] else shell[2]
    # Where the head shield meets the back, and the eyes on its crown.
    hx = int(hc[0] - 4)
    col = [y for y in range(F) if body[0][y, hx]]
    for y in col[1:-1]:
        cv.rgba[y, hx] = shell[4]
    ex, ey = hc[0] + 1, hc[1] - 2
    if p["eye"] == "open":
        cv.put(ex, ey, spec["eye"])
        cv.put(ex + 1, ey, spec["eye"])
        cv.put(ex, ey + 2, spec["eye"])
        cv.put(ex + 1, ey + 2, spec["eye"])
        cv.put(ex + 1, ey - 1 + 0, spec["eye_shine"])
    elif p["eye"] == "shut":
        cv.put(ex, ey, shell[4])
        cv.put(ex, ey + 2, shell[4])
    else:
        for d in (-1, 0, 1):
            cv.put(ex + d, ey + 1 + d, shell[4])
            cv.put(ex + d, ey + 1 - d, shell[4])
    tail()
    legs(1)
    claw(1)
    cv.outline(spec["out"])
    return cv.image()


SCORPIONS = {
    "sand_scorpion": dict(shell=ramp("f4dca0", "dcb872", "b48a4c", "86603a", "5a3e26"), out=C("2e1e12"),
                          bulb=ramp("e8b070", "c88848", "a06430", "784622", "523018"), sting=ramp("3a2418", "2a1810", "1e100a", "140a06", "0a0402"),
                          claw=ramp("f8d8a0", "e0aa6a", "b87c44", "8a5630", "5e381e"),
                          eye=C("1a0e08"), eye_shine=C("f0e0b0")),
}


# ================================================================== husk
def _ik(a, target, l1, l2, bend):
    """The middle joint of a two-part limb from a to target: bend +1 bows
    it to the right of the a->target line (screen), -1 to the left."""
    dx, dy = target[0] - a[0], target[1] - a[1]
    d = max(min(math.hypot(dx, dy), l1 + l2 - 0.01), abs(l1 - l2) + 0.01)
    k = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - k * k, 0.0))
    ux, uy = dx / max(math.hypot(dx, dy), 1e-6), dy / max(math.hypot(dx, dy), 1e-6)
    return (a[0] + ux * k - uy * h * bend, a[1] + uy * k + ux * h * bend)


def husk_pose(**kw):
    p = dict(bx=0.0, by=0.0, lean=0.0, hx=0.0, hy=0.0, jaw=0.3, eye="open",
             near_hand=(4.0, 13.0), far_hand=(2.0, 12.0), near_foot=(2.0, 0.0), far_foot=(-2.0, 0.0),
             kneel=0.0, lying=0.0, smear=0, shadow=1.0)
    p.update(kw)
    return p


def _shamble():
    out = []
    for i in range(8):
        a = i / 8 * math.tau
        s, c = math.sin(a), math.cos(a)
        out.append(husk_pose(by=-1 if i % 4 in (1, 2) else 0, lean=0.5 * s,
                             near_foot=(3.5 * s, max(0.0, c) * 2.5), far_foot=(-3.5 * s, max(0.0, -c) * 2.5),
                             near_hand=(4 - 3 * s, 13 - abs(s)), far_hand=(2 + 3 * s, 12 - abs(s)), jaw=0.3 + 0.1 * c, hy=0.5 * (i % 4 == 2)))
    return out


HUSK_ANIMS = {
    "idle": [husk_pose(), husk_pose(by=0.5, jaw=0.4), husk_pose(by=1, jaw=0.45, near_hand=(4, 14)), husk_pose(by=0.5, jaw=0.35)],
    "walk": _shamble(),
    "windup": [husk_pose(lean=-k * 0.5, bx=-k * 0.4, jaw=0.3 + k * 0.12, near_hand=(4 - k * 2.2, 13 - k * 5.2), far_hand=(3 + k * 0.6, 12 - k * 1.5),
                         near_foot=(2 + k * 0.4, 0), far_foot=(-2 - k * 0.6, 0), hy=-k * 0.4)
               for k in (0, 1, 2, 3, 3.6, 4)],
    "lunge": [husk_pose(lean=1, bx=1, jaw=0.9, near_hand=(10, -4), far_hand=(4, 10), near_foot=(4, 0), far_foot=(-3, 0), smear=1),
              husk_pose(lean=3, bx=3, jaw=1.0, near_hand=(14, 6), far_hand=(5, 9), near_foot=(5, 0), far_foot=(-4, 0), smear=2),
              husk_pose(lean=3.5, bx=3, jaw=0.8, near_hand=(10, 15), far_hand=(6, 10), near_foot=(5, 0), far_foot=(-4, 0), smear=3),
              husk_pose(lean=2.5, bx=2, jaw=0.6, near_hand=(7, 16), far_hand=(4, 12), near_foot=(4, 0), far_foot=(-3, 0)),
              husk_pose(lean=1.2, bx=1, jaw=0.4, near_hand=(5, 14), far_hand=(3, 12), near_foot=(3, 0), far_foot=(-2, 0)),
              husk_pose(jaw=0.3)],
    "hurt": [husk_pose(lean=-2.5, bx=-3, hx=-1, hy=-1, jaw=0.9, eye="shut", near_hand=(0, 10), far_hand=(-1, 10)),
             husk_pose(lean=-1.5, bx=-3, by=1, jaw=0.6, eye="shut", near_hand=(1, 12), far_hand=(0, 11)),
             husk_pose(bx=-1, jaw=0.4)],
    "death": [husk_pose(lean=-2.5, bx=-2, jaw=1.0, eye="shut", near_hand=(0, 9), far_hand=(-1, 9)),
              husk_pose(lean=-1, bx=-2, by=1, jaw=0.8, eye="shut", near_hand=(2, 13), far_hand=(1, 13)),
              husk_pose(bx=-2, kneel=0.5, jaw=0.7, eye="shut", near_hand=(5, 13), far_hand=(4, 13)),
              husk_pose(bx=-2, kneel=1.0, lean=2, jaw=0.7, eye="shut", near_hand=(6, 11), far_hand=(5, 11)),
              husk_pose(bx=-2, kneel=1.0, lying=0.5, jaw=0.6, eye="dead", shadow=1.1),
              husk_pose(bx=-2, lying=1.0, jaw=0.5, eye="dead", shadow=1.3),
              husk_pose(bx=-2, lying=1.0, jaw=0.5, eye="dead", shadow=1.3),
              husk_pose(bx=-2, lying=1.0, jaw=0.5, eye="dead", shadow=1.3)],
    "rest": [husk_pose(kneel=1.0, jaw=0.3, near_hand=(6, 12), far_hand=(5, 12)), husk_pose(kneel=1.0, by=0.5, jaw=0.35, near_hand=(6, 12), far_hand=(5, 12)),
             husk_pose(kneel=1.0, by=0.5, jaw=0.4, eye="shut", near_hand=(6, 12), far_hand=(5, 12)), husk_pose(kneel=1.0, jaw=0.35, eye="shut", near_hand=(6, 12), far_hand=(5, 12))],
    "scratch": [husk_pose(hx=1, hy=1, jaw=0.6), husk_pose(hx=-1, hy=0, jaw=0.2), husk_pose(hx=1, hy=1, jaw=0.7), husk_pose(hx=0, hy=0, jaw=0.3)],
    "stretch": [husk_pose(), husk_pose(lean=-2, jaw=0.7, near_hand=(3, -6), far_hand=(1, -5)), husk_pose(lean=-3, jaw=1.0, eye="shut", near_hand=(2, -10), far_hand=(0, -9)),
                husk_pose(lean=-1, jaw=0.5, near_hand=(4, 4), far_hand=(2, 5))],
}


def husk(spec, p):
    cv = Canvas()
    skin, far_skin = spec["skin"], darker(spec["skin"], 0.74)
    bone = spec["bone"]
    lying, kneel = p["lying"], p["kneel"]
    rx = 44 + p["bx"]
    cv.shadow(rx + 2 + lying * 6, (11 + lying * 9) * p["shadow"])
    # Hips and shoulders: stooped forward, lower when kneeling, on the
    # ground when lying.
    hip_y = GROUND - 14 + p["by"] + kneel * 6
    hip = (rx, hip_y)
    sh = (rx + 6 + p["lean"], hip_y - 13 + abs(p["lean"]) * 0.15)
    if lying > 0:
        hip = (hip[0] * (1 - lying) + (rx - 4) * lying, hip[1] * (1 - lying) + (GROUND - 5) * lying)
        sh = (sh[0] * (1 - lying) + (rx + 10) * lying, sh[1] * (1 - lying) + (GROUND - 6) * lying)
    head = (sh[0] + 7 + p["hx"] + lying * 2, sh[1] - 1 + p["hy"] + lying * 1.5)

    def leg(far):
        tones = far_skin if far else skin
        ox = -2 if far else 0
        h = (hip[0] + ox, hip[1])
        if lying >= 0.5:
            knee = (h[0] - 7, GROUND - 4 + (1 if far else 0))
            foot = (h[0] - 13, GROUND - 3 + (1 if far else 0))
        elif kneel > 0:
            fx, up = p["far_foot" if far else "near_foot"]
            knee = (h[0] + 5 - kneel * 1, min(GROUND - 2, h[1] + 7))
            foot = (h[0] - 4 - kneel * 3, GROUND - 1.5)
        else:
            fx, up = p["far_foot" if far else "near_foot"]
            foot = (h[0] + fx + 1, GROUND - 1.5 - up)
            knee = _ik(h, foot, 7.5, 7.5, -1)
        cv.paint(union(capsule(h[0], h[1], knee[0], knee[1], 3.0, 2.0), capsule(knee[0], knee[1], foot[0], foot[1], 2.0, 1.4)), tones,
                 seam=None if far else tones[4], only=None if far else cv.body)
        # A long bony foot with two claw toes.
        if lying < 0.5:
            cv.paint(capsule(foot[0] - 1, foot[1], foot[0] + 3.5, foot[1] + 0.5, 1.3, 1.0), tones)
            cv.put(foot[0] + 4.5, foot[1] + 0.5, bone[2])
            cv.put(foot[0] + 4.5, foot[1] - 0.5, bone[1])

    def arm(far):
        tones = far_skin if far else skin
        o = (-2.5, -1) if far else (0, 0)
        s = (sh[0] + o[0], sh[1] + 2 + o[1])
        if lying >= 0.5:
            hand = (s[0] + 12, GROUND - 2 - (1 if far else 0))
            elbow = (s[0] + 6, GROUND - 3)
        else:
            hx, hy = p["far_hand" if far else "near_hand"]
            hand = (s[0] + hx, s[1] + hy)
            elbow = _ik(s, hand, 8.5, 8.5, 1 if hx >= 0 else -1)
        cv.paint(union(capsule(s[0], s[1], elbow[0], elbow[1], 2.4, 1.6), capsule(elbow[0], elbow[1], hand[0], hand[1], 1.6, 1.3)), tones,
                 seam=None if far else tones[4], only=None if far else cv.body)
        # The knob of the elbow, and three long claws raking from the hand.
        cv.put(elbow[0] - 0.5, elbow[1] - 1.5, tones[1] if not far else tones[2])
        ang = math.atan2(hand[1] - elbow[1], hand[0] - elbow[0])
        cv.paint(ellipse(hand[0], hand[1], 1.6, 1.4), tones)
        claws = bone if not far else darker(bone, 0.8)
        for k in (-1, 0, 1):
            a = ang + k * 0.55
            for j in range(1, 5):
                cv.put(hand[0] + math.cos(a) * (1.2 + j), hand[1] + math.sin(a) * (1.2 + j), claws[1] if j < 3 else claws[3])
        return hand, ang

    leg(True)
    arm(True)
    # The body: a sunken belly, a hunched back and a narrow chest, one mass.
    mid = ((hip[0] + sh[0]) / 2, (hip[1] + sh[1]) / 2)
    flat = lying
    body = union(
        ellipse(hip[0] + 0.5, hip[1] - 1, 5.0 + flat * 1.5, 4.5 - flat * 1.0),
        ellipse(mid[0] - 2.5 + flat * 1, mid[1] - 2 + flat * 2.5, 6.5 + flat * 2, 6.5 - flat * 2.5),
        ellipse(sh[0] - 0.5, sh[1] + 2.5, 5.5 + flat * 1.5, 5.0 - flat * 1.2),
    )
    cv.paint(body, skin)
    cv.body = body[0].copy()
    # Ribs pressed through the side, a pale scar, a patch of moss.
    for k in range(3):
        x = int(mid[0] + 1 - k * 2.4)
        for j in range(4):
            y = int(mid[1] + j - (1 if lying < 0.5 else 0))
            if 0 <= y < F and cv.body[y, x] and cv.body[y, x - 1]:
                cv.rgba[y, x] = skin[1] if j < 2 else skin[2]
                cv.rgba[y, x - 1] = skin[4]
    # Lichen grown on the shoulder.
    for dx, dy, k in ((-2, -3, 1), (-1, -3, 2), (-3, -2, 2), (0, -4, 0), (-2, -2, 3)):
        x, y = int(sh[0] + dx), int(sh[1] + dy + 2)
        if 0 <= y < F and 0 <= x < F and cv.body[y, x]:
            cv.rgba[y, x] = spec["moss"][k]
    # Bone spurs breaking out along the hunched spine.
    spine_top = [(hip[0] - 3 + (sh[0] - hip[0]) * t, mid[1] - 8.5 + flat * 5 + (sh[1] - hip[1]) * (t - 0.5) * 0.6) for t in (0.15, 0.4, 0.65, 0.88)]
    for k, (x, y) in enumerate(spine_top):
        h = (2.5 + (1.5 if k in (1, 2) else 0)) * (1 - flat * 0.5)
        lean = -1.2 - flat
        cv.paint(polygon([(x - 1.4, y + 1.5), (x + lean, y - h), (x + 0.2, y + 1.5)]), [bone[1]] * 5)
        cv.paint(polygon([(x + 0.2, y + 1.5), (x + lean, y - h), (x + 1.6, y + 1.5)]), [bone[3]] * 5)
    leg(False)
    # The head: a hollow skull hung forward, the jaw dropped open.
    cv.paint(capsule(sh[0] + 1, sh[1] + 1, head[0] - 2, head[1] + 1, 2.6, 2.2), skin)
    jaw = p["jaw"]
    cv.paint(ellipse(head[0], head[1], 5.0, 5.2), skin)
    # Brow ridge shading and the deep socket with its cold light.
    ex, ey = head[0] + 1.5, head[1] - 1
    cv.paint(ellipse(ex, ey, 1.9, 1.7), [spec["socket"]] * 5)
    if p["eye"] == "open":
        cv.put(ex + 0.5, ey, spec["eye"])
        cv.put(ex + 1.5, ey, spec["eye_dim"])
    elif p["eye"] == "dead":
        cv.put(ex - 0.5, ey - 0.5, skin[4])
        cv.put(ex + 1, ey + 1, skin[4])
    # The jaw hangs from the back of the skull: a dark maw, broken teeth.
    jy = head[1] + 2.5 + jaw * 3.5
    cv.paint(capsule(head[0] - 1, head[1] + 2.5, head[0] + 4, jy, 1.0 + jaw * 1.4, 0.8 + jaw), [spec["maw"]] * 5)
    cv.paint(capsule(head[0] - 2, head[1] + 3.5, head[0] + 3.5, jy + 1.5, 1.6, 1.3), darker(skin, 0.85))
    for k in range(3):
        t = 0.25 + k * 0.3
        cv.put(head[0] + 4.5 * t, head[1] + 2.2 + (jy - head[1] - 2.2) * 0.0, bone[0])
        if k != 1:
            cv.put(head[0] - 0.5 + 4.5 * t, jy + 0.2, bone[1])
    if jaw > 0.5 and lying < 0.5:
        for k in range(2 + int(jaw * 2)):
            cv.put(head[0] + 2, jy + 2 + k, spec["drool"])
    hand, ang = arm(False)
    # The swipe's smear: a curved band of pale light behind the claws.
    if p["smear"]:
        cx_, cy_ = sh[0] + 1, sh[1] + 3
        r = 15.5
        a0 = {1: (-1.9, -0.9), 2: (-1.2, 0.3), 3: (-0.4, 1.1)}[p["smear"]]
        steps = 22
        for k in range(steps + 1):
            a = a0[0] + (a0[1] - a0[0]) * k / steps
            for w in range(3):
                rr = r - w
                x, y = cx_ + math.cos(a) * rr, cy_ + math.sin(a) * rr
                xi, yi = int(x), int(y)
                if 0 <= xi < F and 0 <= yi < F and cv.layer[yi, xi] < 0:
                    cv.put(x, y, spec["smear"][min(w + (0 if k > steps * 0.4 else 1), 2)])
    cv.outline(spec["out"])
    return cv.image()


HUSKS = {
    "husk": dict(skin=ramp("a4acb8", "7e8696", "5e6474", "42464f", "2c2e36"), out=C("141218"),
                 bone=ramp("f4ecd4", "dcd0b0", "b4a888", "8a7e62", "5e5440"), moss=ramp("9ac860", "74a040", "547a2e", "3a5a20", "263c14"),
                 socket=C("0e0c12"), eye=C("9affd0"), eye_dim=C("3a9a78"), maw=C("2a0a0e"), drool=C("b8303a"),
                 smear=[C("f4f0e8"), C("c8c4c0"), C("8e8a90")]),
}


# ================================================================== sheets
def sheet(draw, spec, anims):
    img = Image.new("RGBA", (8 * F, len(ROWS) * F), (0, 0, 0, 0))
    for row, (name, count) in enumerate(ROWS):
        frames = anims[name]
        for col in range(count):
            img.paste(draw(spec, frames[col % len(frames)]), (col * F, row * F))
    return img


def ALL():
    out = {}
    for name, spec in CANINES.items():
        out[name] = (canine, spec, CANINE_ANIMS)
    for name, spec in SLIMES.items():
        out[name] = (slime, spec, SLIME_ANIMS)
    for name, spec in SCORPIONS.items():
        out[name] = (scorpion, spec, SCORP_ANIMS)
    for name, spec in HUSKS.items():
        out[name] = (husk, spec, HUSK_ANIMS)
    return out


NAMES = ["frost_wolf", "rot_hound", "sand_scorpion", "bog_slime", "husk"]


def path_of(name):
    if name == "husk":
        return os.path.join(ROOT, "assets", "sprites", "husk_sheet.png")
    return os.path.join(OUT, name + ".png")


def main(only=None):
    for name, (draw, spec, anims) in ALL().items():
        if only and name not in only:
            continue
        sheet(draw, spec, anims).save(path_of(name))
    print("predators drawn:", ", ".join(n for n in NAMES if not only or n in only))


if __name__ == "__main__":
    main(sys.argv[1:] or None)
