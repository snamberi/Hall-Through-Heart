"""What villagers carry for their work, drawn at the size they are held
(not item icons shrunk to half, which drops every other pixel): a hatchet,
a pickaxe, a fishing rod with its float, a spear with a red tassel, a hunting
bow, a sheaf of wheat, a basket of herbs and a basket of bread.

Each is a 20x32 cell of assets/sprites/held_tools.png, held at GRIP (the
pixel the hand closes on); scripts/world/person_figure.gd keeps that pixel
on the figure's hand, frame by frame.

Run from the repository root:  python3 tools/generate_held.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from generate_flora import C, Canvas, ramp  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
W, H = 20, 32
# Where the hand closes in every cell.
GRIP = (10, 22)

WOOD = ramp("b08a5c", "7e5a38", "4e3622")
IRON = ramp("e2e6ec", "a0a8b4", "5e6674")
LEATHER = ramp("8a5a3a", "623e26", "40281a")
WHEAT = ramp("f4d878", "d0a848", "94702a")
STALK = ramp("d8c070", "b09848", "7a6630")
WICKER = ramp("d0a462", "a07440", "6a4826")
LEAF = ramp("8acc68", "58944a", "34602e")
BREAD = ramp("eab070", "c08040", "84522a")
RED = ramp("e05a50", "b03c3c", "702424")
TWINE = C("ece0c0")


def hatchet():
    c = Canvas(W, H)
    c.shade("rect", (9, 9, 10, 27), WOOD)
    c.fill("rect", (10, 10, 10, 27), WOOD[2])
    c.shade("poly", [(11, 7), (15, 5), (17, 5), (17, 13), (15, 13), (11, 11)], IRON)
    c.fill("rect", (17, 6, 17, 12), IRON[0])
    c.fill("rect", (8, 8, 11, 11), IRON[2])
    c.put(9, 9, IRON[1])
    c.fill("rect", (9, 21, 10, 23), LEATHER[1])
    c.outline()
    return c.img


def pickaxe():
    c = Canvas(W, H)
    c.shade("rect", (9, 8, 10, 28), WOOD)
    c.fill("rect", (10, 9, 10, 28), WOOD[2])
    c.shade("poly", [(2, 10), (5, 7), (9, 5), (11, 5), (15, 7), (18, 10), (17, 10), (14, 8), (11, 7), (9, 7), (6, 8), (3, 10)], IRON)
    c.put(2, 10, IRON[2]); c.put(18, 10, IRON[2]); c.put(9, 5, IRON[0]); c.put(10, 5, IRON[0])
    c.fill("rect", (8, 6, 11, 8), IRON[2])
    c.fill("rect", (9, 21, 10, 23), LEATHER[1])
    c.outline()
    return c.img


def fishing_rod():
    c = Canvas(W, H)
    c.fill("line", (10, 26, 16, 3), WOOD[1])
    c.fill("line", (11, 26, 17, 3), WOOD[0])
    c.fill("line", (10, 27, 10, 24), WOOD[2])
    c.fill("rect", (8, 20, 9, 21), IRON[1]); c.put(8, 20, IRON[0])
    c.fill("rect", (9, 21, 11, 23), LEATHER[1])
    c.outline()
    # The line and its float hang from the tip, unoutlined (it is thin).
    c.fill("line", (17, 3, 18, 14), TWINE)
    c.put(18, 15, RED[0]); c.put(18, 16, C("f4f4f0")); c.put(18, 17, RED[1])
    return c.img


def spear():
    c = Canvas(W, H)
    c.fill("rect", (9, 6, 9, 31), WOOD[0])
    c.fill("rect", (10, 6, 10, 31), WOOD[2])
    c.shade("poly", [(9, 0), (11, 3), (11, 6), (8, 6), (8, 3)], IRON)
    c.put(9, 1, IRON[0]); c.put(9, 2, IRON[0])
    c.shade("poly", [(8, 7), (11, 7), (12, 11), (10, 9), (9, 11), (7, 11)], RED)
    c.fill("rect", (8, 6, 11, 6), IRON[2])
    c.fill("rect", (9, 21, 10, 23), LEATHER[1])
    c.outline()
    return c.img


def bow():
    c = Canvas(W, H)
    # A recurve: the limbs bow back, the tips flick forward.
    limb = [(12, 3), (10, 5), (8, 9), (7, 14), (7, 19), (8, 24), (10, 28), (12, 30)]
    for (x0, y0), (x1, y1) in zip(limb, limb[1:]):
        c.fill("line", (x0, y0, x1, y1), WOOD[1], 2)
    c.fill("line", (8, 9, 7, 14), WOOD[0]); c.fill("line", (7, 19, 8, 24), WOOD[2])
    c.put(13, 3, WOOD[2]); c.put(13, 30, WOOD[2])
    c.fill("rect", (7, 15, 9, 18), LEATHER[1]); c.put(7, 15, LEATHER[0])
    c.outline()
    c.fill("line", (12, 4, 12, 29), TWINE)
    return c.img


def wheat():
    c = Canvas(W, H)
    for k, (top_x, lean) in enumerate(((5, -2), (7, -1), (9, 0), (11, 0), (13, 1), (15, 2))):
        c.fill("line", (9 + k // 2, 27, top_x + 1, 12), STALK[k % 3])
    for k, (x, y) in enumerate(((4, 7), (6, 5), (8, 4), (10, 4), (12, 5), (14, 7))):
        c.shade("ellipse", (x, y, x + 2, y + 6), WHEAT, dither=False)
        c.put(x + 1, y + 1, WHEAT[0])
    c.fill("rect", (8, 20, 12, 21), TWINE); c.put(13, 21, C("c8b890"))
    c.outline()
    return c.img


def basket(goods):
    c = Canvas(W, H)
    # The handle arcs up to the hand; the basket hangs below it.
    c.fill("line", (5, 26, 6, 22), WICKER[1], 2)
    c.fill("line", (6, 22, 10, 20), WICKER[1], 2)
    c.fill("line", (10, 20, 14, 22), WICKER[1], 2)
    c.fill("line", (14, 22, 15, 26), WICKER[1], 2)
    if goods == "herbs":
        for x, y in ((6, 23), (9, 22), (12, 23), (14, 24)):
            c.shade("ellipse", (x - 2, y - 1, x + 2, y + 4), LEAF, dither=False)
        c.put(8, 22, C("f0e070")); c.put(13, 23, C("e888c0"))
    else:
        c.shade("ellipse", (4, 22, 11, 28), BREAD, dither=False)
        c.shade("ellipse", (9, 21, 16, 27), BREAD, dither=False)
        c.put(7, 24, BREAD[0]); c.put(12, 23, BREAD[0]); c.put(10, 23, BREAD[2]); c.put(13, 24, BREAD[2])
    c.shade("poly", [(3, 26), (17, 26), (16, 31), (4, 31)], WICKER)
    for x in range(4, 17, 2):
        c.put(x, 28, WICKER[2]); c.put(x + 1, 29, WICKER[2])
    c.fill("rect", (3, 26, 17, 26), WICKER[0])
    c.outline()
    return c.img


# Order of the cells; the game looks a tool up by the item a job carries.
TOOLS = [
    ("worn_hatchet", hatchet), ("worn_pickaxe", pickaxe), ("fishing_rod", fishing_rod), ("spear", spear),
    ("bow", bow), ("wheat", wheat), ("healing_herb", lambda: basket("herbs")), ("bread", lambda: basket("bread")),
]


def main():
    sheet = Image.new("RGBA", (W * len(TOOLS), H), (0, 0, 0, 0))
    for index, (_name, draw) in enumerate(TOOLS):
        sheet.alpha_composite(draw(), (index * W, 0))
    sheet.save(os.path.join(ROOT, "held_tools.png"))
    print("held tools: " + ", ".join(name for name, _draw in TOOLS))


if __name__ == "__main__":
    main()
