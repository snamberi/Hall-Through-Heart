"""Cliff faces, drawn a pixel at a time (visual overhaul, phase 2).

scripts/world/cliff_faces.gd lays these strips down column by column under
the wavy lip of each face. Each look is one strip four tiles wide that
repeats, so faces run on along a ridge without a seam:

  rock, peak       bedded stone: strata of different thickness, each bed
                   split into blocks by joints, lit along its top and left
                   edge, shaded along its foot, with cracks and grain;
  earth, frozen,   an earthen bank: soil in wavy layers, paler under the
  sandstone, ash   lip and darker toward the foot, with stones set in it,
                   pebbles, and thin roots threading down.

Each strip is 176 x 56: the face proper starts 8 px down (the lip can
rise above it) and the light comes from the top-left.

Run: python3 tools/generate_cliffs.py -> assets/tiles/cliffs.png
"""
import math
import os
import random

from PIL import Image

W, H = 176, 56
TOP = 8
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "tiles")


def C(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def hash2(x, y, seed=0):
    h = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


# The same colours as the faces' code (cliff_faces.gd STONES and SOIL).
STONES = {
    "earth": [C("8e8270"), C("b6aa92"), C("645a4c"), C("2e2219")],
    "frozen": [C("8a8e9c"), C("b8bece"), C("62667a"), C("2a2a36")],
    "sandstone": [C("b8955e"), C("d8b880"), C("8a6a40"), C("4a3420")],
    "ash": [C("5a5458"), C("7a7278"), C("3e3a3e"), C("1a1618")],
    "rock": [C("7a7682"), C("a8a4b2"), C("55525e"), C("24222a")],
    "peak": [C("9aa4b8"), C("d0d8e8"), C("6a7488"), C("2e3442")],
}
SOIL = {
    "earth": [C("7a5a3c"), C("5e432c"), C("47321f"), C("2a1c12")],
    "frozen": [C("6a6474"), C("524c5c"), C("3e3a48"), C("24202c")],
    "sandstone": [C("c8a070"), C("a8804e"), C("86623a"), C("4a3420")],
    "ash": [C("5a5054"), C("463e42"), C("342e32"), C("1c181a")],
}
ORDER = ["rock", "peak", "earth", "frozen", "sandstone", "ash"]


def wave(x, k, phase, amp):
    """A wavy line that repeats every strip (k whole waves across it)."""
    return amp * math.sin(x / W * math.tau * k + phase)


def rock_strip(look, seed):
    """Bedded stone."""
    top, lit, low, seam = STONES[look]
    r = random.Random(seed)
    img = Image.new("RGBA", (W, H), seam)
    px = img.load()
    # Bed boundaries: wavy lines across the strip.
    beds = []
    y = 1.0
    while y < H + 8:
        thick = r.randrange(5, 14)
        beds.append((y, r.randrange(1, 4), r.uniform(0, math.tau), r.uniform(0.8, 2.2), r.random()))
        y += thick
    beds.append((H + 20, 1, 0.0, 0.0, 0.5))

    def bed_at(x, yy):
        for i in range(len(beds) - 1):
            y0 = beds[i][0] + wave(x, beds[i][1], beds[i][2], beds[i][3])
            y1 = beds[i + 1][0] + wave(x, beds[i + 1][1], beds[i + 1][2], beds[i + 1][3])
            if y0 <= yy < y1:
                return i, yy - y0, y1 - yy
        return len(beds) - 1, 0, 99

    # Joints: for each bed, where its blocks part (x positions, wrapping).
    # Joints: few, far apart and leaning, so the beds break into long
    # irregular blocks rather than bricks. Each block has its own tone.
    joints, leans = [], []
    for i in range(len(beds)):
        xs, x = [], r.randrange(0, 20)
        while x < W - 6:
            xs.append(x)
            x += r.randrange(14, 38)
        joints.append(xs)
        leans.append(r.choice((-0.5, -0.34, 0, 0.34, 0.5)))

    def joint_info(i, x, from_top):
        """(on a joint, just right of one, just left of one, block index)."""
        shift = int(round(from_top * leans[i]))
        xs = [(j + shift) % W for j in joints[i]]
        block = sum(1 for j in xs if j <= x)
        return x in xs, (x - 1) % W in xs, (x + 1) % W in xs, block
    for yy in range(H):
        for x in range(W):
            i, from_top, to_bottom = bed_at(x, yy)
            on_joint, right_of, left_of, block = joint_info(i, x, from_top)
            tone = beds[i][4] * 0.6 + hash2(i, block % max(1, len(joints[i])), seed + 3) * 0.4
            # Beds that stand out are lighter, those set back darker.
            body = mix(low, top, 0.35 + tone * 0.65)
            # Toward the foot the face lies in its own shadow.
            depth = max(0.0, (yy - TOP) / (H - TOP))
            body = shade(body, 1.0 - 0.16 * depth)
            if from_top < 1:
                c = seam
            elif from_top < 2:
                c = mix(body, lit, 0.7)
            elif to_bottom < 2:
                c = mix(body, low, 0.75)
            else:
                c = body
            # Joints split the bed into blocks: a dark seam, the block to its
            # right lit along its edge, the block to its left shaded.
            if on_joint and from_top >= 1:
                c = seam
            elif right_of and from_top >= 2 and to_bottom >= 2:
                c = mix(c, lit, 0.45)
            elif left_of and from_top >= 1:
                c = mix(c, low, 0.6)
            # Grain.
            g = hash2(x, yy, seed)
            if c not in (seam,) and g < 0.08:
                c = shade(c, 0.9)
            elif c not in (seam,) and g > 0.95:
                c = shade(c, 1.08)
            px[x, yy] = c
    # Cracks running down a block or two.
    for _ in range(14):
        x, yy = r.randrange(W), r.randrange(TOP, H - 6)
        for k in range(r.randrange(3, 8)):
            px[x % W, yy] = seam
            if px[(x + 1) % W, yy] != seam:
                px[(x + 1) % W, yy] = mix(px[(x + 1) % W, yy], lit, 0.3)
            yy += 1
            x += r.choice((-1, 0, 0, 1))
            if yy >= H:
                break
    return img


def earth_strip(look, seed):
    """An earthen bank."""
    s0, s1, s2, seam = SOIL[look]
    stones = STONES[look]
    r = random.Random(seed)
    img = Image.new("RGBA", (W, H), s1)
    px = img.load()
    layers = [(r.uniform(0, math.tau), r.randrange(1, 3)) for _ in range(6)]
    for yy in range(H):
        for x in range(W):
            depth = max(0.0, min(1.0, (yy - TOP) / (H - TOP - 6)))
            c = mix(s0, s1, min(1.0, depth * 1.7)) if depth < 0.6 else mix(s1, s2, (depth - 0.6) / 0.4)
            # Wavy layers: each a little darker, with a pale line on top.
            band_y = yy + wave(x, 2, layers[0][0], 1.6) + wave(x, 3, layers[1][0], 0.8)
            band = int(band_y // 7)
            within = band_y - band * 7
            if band % 2:
                c = shade(c, 0.92)
            if within < 1:
                c = shade(c, 1.1)
            g = hash2(x, yy, seed)
            if g < 0.1:
                c = shade(c, 0.86)
            elif g > 0.94:
                c = shade(c, 1.12)
            px[x, yy] = c
    # Stones set in the soil.
    for _ in range(20):
        cx, cy = r.randrange(W), r.randrange(TOP + 4, H - 4)
        w, h = r.randrange(3, 8), r.randrange(2, 5)
        tint = mix(stones[0], stones[1], r.random() * 0.3)
        for dy in range(h + 1):
            for dx in range(w + 1):
                u, v = (dx - w / 2) / (w / 2 + 0.5), (dy - h / 2) / (h / 2 + 0.5)
                if u * u + v * v <= 1.0 and cy + dy + 1 < H:
                    xx = (cx + dx + 1) % W
                    px[xx, cy + dy + 1] = shade(px[xx, cy + dy + 1], 0.72)
        for dy in range(h):
            for dx in range(w):
                u, v = (dx + 0.5 - w / 2) / (w / 2), (dy + 0.5 - h / 2) / (h / 2)
                if u * u + v * v > 1.0:
                    continue
                lit = -u - v
                c = stones[1] if lit > 0.8 else tint if lit > -0.6 else stones[2]
                px[(cx + dx) % W, cy + dy] = c
    # Pebbles.
    for _ in range(40):
        x, yy = r.randrange(W), r.randrange(TOP + 2, H - 2)
        px[x, yy] = stones[2]
        px[x, yy - 1] = stones[1] if r.random() < 0.6 else stones[0]
    # Roots threading down from under the lip.
    root_dark, root_lit = shade(seam, 1.3), mix(s0, (200, 170, 120, 255), 0.3)
    for _ in range(9):
        x, yy = r.randrange(W), TOP + r.randrange(0, 4)
        for k in range(r.randrange(8, 22)):
            px[x % W, yy] = root_dark
            if k % 3 == 0:
                px[(x - 1) % W, yy] = root_lit
            yy += 1
            if r.random() < 0.35:
                x += r.choice((-1, 1))
            if yy >= H - 2:
                break
    return img


def main():
    sheet = Image.new("RGBA", (W, H * len(ORDER)))
    for i, look in enumerate(ORDER):
        strip = rock_strip(look, 11 + i) if look in ("rock", "peak") else earth_strip(look, 31 + i)
        sheet.paste(strip, (0, i * H))
    sheet.save(os.path.join(ROOT, "cliffs.png"))


if __name__ == "__main__":
    main()
