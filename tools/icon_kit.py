"""A small pixel-art kit for 32x32 item icons.

Shapes are rasterised straight onto the 32x32 grid (no drawing at a larger
size and shrinking, no rotating finished pictures), each pixel decided once.
Every shape is a "part": it is shaded from a five-tone ramp with light from
the upper left (a highlight on edges that face the light, a deep tone on
edges that face away), and where one part meets another below or to the
right a darker seam keeps them apart. A dark outline goes round the whole.

Weapons and tools lie on the diagonal from the lower left (the grip) to the
upper right (the tip). For those, a shape is given in (k, m): k = x - y runs
along the diagonal and m = x + y across it, so a blade is simply the pixels
with k in a range and m near the middle line, a true pixel staircase of
even width.
"""
import colorsys
import math
import random

from PIL import Image, ImageDraw

SIZE = 32
OUTLINE = (26, 20, 32)
MID = 31  # the diagonal x + y = 31 runs from the lower left to the upper right


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def ramp(base, spread=1.0):
    """Five tones from one colour: highlight, light, base, shade, deep. The
    light ones lean warm and the dark ones cool, as pixel artists shade."""
    r, g, b = [c / 255.0 for c in (hex_rgb(base) if isinstance(base, str) else base)]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)

    def shift(dv, ds, dh):
        hh = (h + dh) % 1.0
        return tuple(int(round(c * 255)) for c in colorsys.hsv_to_rgb(hh, min(max(s + ds, 0.0), 1.0), min(max(v + dv, 0.0), 1.0)))

    warm = 0.03 if 0.15 < h < 0.65 else -0.02
    cool = -warm
    return [
        shift(0.28 * spread, -0.22 * spread, warm),
        shift(0.13 * spread, -0.1 * spread, warm * 0.5),
        shift(0.0, 0.0, 0.0),
        shift(-0.18 * spread, 0.08 * spread, cool * 0.6),
        shift(-0.34 * spread, 0.12 * spread, cool),
    ]


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


class Icon:
    def __init__(self):
        self.colour = {}
        self.part = {}
        self.parts = 0
        self.no_outline = set()

    # --- placing shaded parts

    def _mask(self, draw_fn):
        mask = Image.new("L", (SIZE, SIZE), 0)
        draw_fn(ImageDraw.Draw(mask))
        return {(x, y) for y in range(SIZE) for x in range(SIZE) if mask.getpixel((x, y))}

    def shade(self, pixels, tones, flat=False, gradient=1.0, rim=True, under=False):
        """Paints a part. `tones` is a ramp of five. `under` places it behind
        what is already there."""
        pixels = {p for p in pixels if 0 <= p[0] < SIZE and 0 <= p[1] < SIZE}
        if not pixels:
            return set()
        self.parts += 1
        pid = self.parts
        xs = [p[0] for p in pixels]
        ys = [p[1] for p in pixels]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        w, h = max(x1 - x0, 1), max(y1 - y0, 1)
        for (x, y) in pixels:
            if under and (x, y) in self.colour:
                continue
            if flat:
                tone = 2
            else:
                t = gradient * (0.55 * (x - x0) / w + 0.45 * (y - y0) / h) + (1 - gradient) * 0.5
                tone = 1 if t < 0.3 else 2 if t < 0.66 else 3
            if rim:
                if (x - 1, y) not in pixels or (x, y - 1) not in pixels:
                    tone = 0 if tone <= 1 else 1
                elif (x + 1, y) not in pixels or (x, y + 1) not in pixels:
                    tone = 4 if tone >= 2 else 3
            self.colour[(x, y)] = tones[tone]
            self.part[(x, y)] = pid
        return pixels

    def poly(self, points, tones, **kw):
        return self.shade(self._mask(lambda d: d.polygon(points, fill=255, outline=255)), tones, **kw)

    def ellipse(self, box, tones, **kw):
        return self.shade(self._mask(lambda d: d.ellipse(box, fill=255)), tones, **kw)

    def rect(self, box, tones, **kw):
        return self.shade(self._mask(lambda d: d.rectangle(box, fill=255)), tones, **kw)

    def line(self, points, width, tones, **kw):
        return self.shade(self._mask(lambda d: d.line(points, fill=255, width=width)), tones, **kw)

    def ring(self, box, width, tones, **kw):
        return self.shade(self._mask(lambda d: d.ellipse(box, outline=255, width=width)), tones, **kw)

    def km(self, test, tones, **kw):
        """A part given in diagonal coordinates: test(k, d) where k = x - y
        runs along the weapon and d = x + y - MID is the distance across it
        (negative toward the upper left)."""
        return self.shade({(x, y) for y in range(SIZE) for x in range(SIZE) if test(x - y, x + y - MID)}, tones, **kw)

    # --- single pixels and touches

    def put(self, x, y, colour, part=True):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.colour[(x, y)] = colour if isinstance(colour, tuple) else hex_rgb(colour)
            if part and (x, y) not in self.part:
                self.parts += 1
                self.part[(x, y)] = self.parts

    def dots(self, points, colour):
        for x, y in points:
            if (x, y) in self.colour:
                self.colour[(x, y)] = colour if isinstance(colour, tuple) else hex_rgb(colour)

    def scatter(self, pixels, colour, chance, seed):
        r = random.Random(seed)
        for p in sorted(pixels):
            if r.random() < chance and p in self.colour:
                self.colour[p] = colour if isinstance(colour, tuple) else hex_rgb(colour)

    def sparkle(self, x, y, colour=(255, 255, 255)):
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            self.put(x + dx, y + dy, colour if (dx, dy) == (0, 0) else mix(colour, (255, 240, 200), 0.3), part=False)
            self.no_outline.add((x + dx, y + dy))

    # --- finishing

    def image(self, seams=True):
        img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        colours = dict(self.colour)
        if seams:
            for (x, y), pid in self.part.items():
                below = self.part.get((x, y + 1))
                right = self.part.get((x + 1, y))
                if (below is not None and below > pid and (x, y + 1) in colours) or (right is not None and right > pid and (x + 1, y) in colours):
                    colours[(x, y)] = mix(colours[(x, y)], (20, 14, 30), 0.38)
        for (x, y), c in colours.items():
            img.putpixel((x, y), c + (255,))
        filled = set(colours)
        for y in range(SIZE):
            for x in range(SIZE):
                if (x, y) in filled:
                    continue
                if any((x + dx, y + dy) in filled and (x + dx, y + dy) not in self.no_outline for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    img.putpixel((x, y), OUTLINE + (255,))
        return img


# --- diagonal weapon pieces (k along the weapon, d across it)

def across(icon, pixels, tones, centre=lambda k: 0.0):
    """Re-shades a diagonal part across its width: the upper-left edge
    catches the light, the lower-right edge falls into shade."""
    if not pixels:
        return
    width = {}
    for (x, y) in pixels:
        k = x - y
        d = x + y - MID - centre(k)
        width[k] = max(width.get(k, 0.0), abs(d))
    for (x, y) in pixels:
        k = x - y
        d = x + y - MID - centre(k)
        w = max(width[k], 0.5)
        share = d / w
        if (x - 1, y) not in pixels or (x, y - 1) not in pixels:
            tone = 0
        elif (x + 1, y) not in pixels or (x, y + 1) not in pixels:
            tone = 4
        elif share < -0.34:
            tone = 1
        elif share < 0.34:
            tone = 2
        else:
            tone = 3
        icon.colour[(x, y)] = tones[tone]

def blade(icon, tones, k0, k1, half, tip=4, curve=0.0, fuller=None, edge=None, taper=0.0):
    """A straight (or gently curved) blade from k0 to the point at k1."""
    def test(k, d):
        if k < k0 or k > k1:
            return False
        bend = curve * ((k - k0) / max(k1 - k0, 1)) ** 2 * 6.0
        width = half - taper * (k - k0) / max(k1 - k0, 1)
        if k > k1 - tip:
            width = width * (k1 - k) / tip
        return abs(d + bend) <= max(width, 0.0) + 0.01
    pixels = icon.km(test, tones)
    across(icon, pixels, tones, lambda k: -curve * ((k - k0) / max(k1 - k0, 1)) ** 2 * 6.0)
    if fuller is not None:
        for (x, y) in pixels:
            k, d = x - y, x + y - MID
            if fuller[0] <= k <= fuller[1] and abs(d + curve * ((k - k0) / max(k1 - k0, 1)) ** 2 * 6.0) < 0.6:
                icon.colour[(x, y)] = fuller[2]
    if edge is not None:
        for (x, y) in pixels:
            if (x - 1, y) not in pixels or (x, y - 1) not in pixels:
                icon.colour[(x, y)] = edge
    return pixels


def grip(icon, tones, k0, k1, half=1, wrap=None):
    pixels = icon.km(lambda k, d: k0 <= k <= k1 and abs(d) <= half, tones)
    across(icon, pixels, tones)
    if wrap is not None:
        for (x, y) in pixels:
            if (x - y) % 4 in (0, 1) and abs(x + y - MID) <= half:
                icon.colour[(x, y)] = wrap
    return pixels


def guard(icon, tones, k, length, thick=1, curl=0):
    """A crossguard across the weapon at k: `length` each side, curling
    toward the blade at its ends by `curl`."""
    def test(kk, d):
        bend = curl * (abs(d) / max(length, 1)) ** 2
        return abs(kk - k - bend) <= thick and abs(d) <= length
    return icon.km(test, tones, gradient=0.6)


def pommel(icon, tones, k, size=1.6):
    return icon.km(lambda kk, d: (kk - k) ** 2 * 0.5 + d * d * 0.5 <= size * size, tones)


def gem_dot(icon, k, colour, size=1):
    for (x, y) in [(x, y) for y in range(SIZE) for x in range(SIZE) if abs((x - y) - k) <= size and abs(x + y - MID) <= size - 1]:
        icon.put(x, y, colour)
