"""Pictures for the phone's touch buttons, 32x32 each, drawn pixel by pixel
with the item icons' kit (tools/icon_kit.py): dash, parry, swap set, run,
walk, ride, drink, chat, and the Use button's faces, which change with what
is near (talk, open, enter, read, touch a stone, pick up, sleep, use).

Writes assets/icons/touch.png (one row); scripts/ui/touch_controls.gd keeps
the order in TOUCH_ICONS.

Run from the repository root:  python3 tools/generate_touch_icons.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from icon_kit import Icon, ramp  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
BRONZE, GOLD, STEEL, IRON = "c8904a", "e8bc4a", "c4ccd8", "8e96a4"
LEATHER, WOOD, PAPER, CLOTH = "8e5e3a", "9a6a40", "e8dcb8", "4a6ab0"
RED, GREEN, ICE = "c84a4a", "5ab06a", "9ad8f0"


def erase(icon, test):
    """Takes away the pixels where test(x, y) holds (a gap cut in a shape)."""
    for (x, y) in list(icon.colour):
        if test(x, y):
            del icon.colour[(x, y)]
            icon.part.pop((x, y), None)


def dash():
    icon = Icon()
    # A boot kicking forward, three wind lines behind it.
    icon.poly([(12, 6), (20, 6), (20, 18), (28, 20), (28, 26), (12, 26)], ramp(LEATHER))
    icon.rect((12, 24, 28, 27), ramp("5a3a26"))
    for y, x0 in ((10, 2), (16, 4), (22, 2)):
        icon.line([(x0, y), (x0 + 7, y)], 1, ramp(ICE))
    return icon


def parry():
    icon = Icon()
    # Two blades crossing, a spark where they meet.
    icon.line([(5, 27), (26, 6)], 2, ramp(STEEL))
    icon.line([(5, 6), (26, 27)], 2, ramp(STEEL))
    icon.rect((3, 25, 8, 29), ramp(BRONZE))
    icon.rect((23, 25, 28, 29), ramp(BRONZE))
    icon.sparkle(16, 16, (255, 240, 190))
    return icon


def swap():
    icon = Icon()
    # Two arrows chasing each other round.
    icon.ring((5, 5, 27, 27), 2, ramp(GOLD))
    icon.poly([(22, 2), (29, 8), (21, 11)], ramp(GOLD))
    icon.poly([(10, 30), (3, 24), (11, 21)], ramp(GOLD))
    return icon


def run():
    icon = Icon()
    # Two chevrons, fast.
    for x in (5, 15):
        icon.poly([(x, 6), (x + 6, 6), (x + 13, 16), (x + 6, 26), (x, 26), (x + 7, 16)], ramp(GOLD))
    return icon


def walk():
    icon = Icon()
    # Two footprints.
    icon.ellipse((6, 14, 13, 27), ramp(PAPER))
    icon.ellipse((7, 8, 12, 12), ramp(PAPER))
    icon.ellipse((18, 6, 25, 19), ramp(PAPER))
    icon.ellipse((19, 21, 24, 25), ramp(PAPER))
    return icon


def ride():
    icon = Icon()
    # A horseshoe with its nails.
    icon.ring((5, 4, 27, 30), 4, ramp(IRON))
    erase(icon, lambda x, y: y > 24 and 11 < x < 21)
    for (x, y) in ((8, 12), (8, 18), (23, 12), (23, 18)):
        icon.put(x, y, (40, 40, 48))
    return icon


def drink():
    icon = Icon()
    # A round potion flask, red.
    icon.ellipse((7, 11, 25, 29), ramp(RED))
    icon.rect((13, 4, 19, 12), ramp("d8e0ea"))
    icon.rect((12, 2, 20, 5), ramp(WOOD))
    icon.put(11, 17, (255, 220, 220))
    return icon


def chat():
    icon = Icon()
    # A speech bubble with lines of words.
    icon.ellipse((3, 4, 29, 24), ramp(PAPER))
    icon.poly([(8, 20), (14, 22), (6, 29)], ramp(PAPER))
    for y in (10, 14, 18):
        icon.line([(9, y), (23, y)], 1, ramp("6a6676"))
    return icon


def use():
    icon = Icon()
    # An open hand.
    icon.rect((9, 14, 24, 28), ramp("e8c4a0"))
    for x in (9, 13, 17, 21):
        icon.rect((x, 5, x + 2, 15), ramp("e8c4a0"))
    icon.poly([(24, 18), (29, 12), (30, 15), (25, 22)], ramp("e8c4a0"))
    return icon


def talk():
    icon = Icon()
    # A speech bubble with three dots: someone to talk to.
    icon.ellipse((3, 5, 29, 25), ramp(GOLD))
    icon.poly([(20, 21), (26, 22), (27, 29)], ramp(GOLD))
    for x in (10, 16, 22):
        icon.rect((x - 1, 14, x + 1, 16), ramp("4a3a20"))
    return icon


def open_chest():
    icon = Icon()
    # A chest with its lid thrown back and gold inside.
    icon.rect((4, 16, 28, 28), ramp(WOOD))
    icon.poly([(4, 16), (8, 4), (28, 4), (28, 16)], ramp("7a5232"))
    icon.rect((5, 14, 27, 17), ramp(GOLD))
    icon.rect((4, 20, 28, 21), ramp(IRON))
    icon.rect((14, 19, 18, 23), ramp(GOLD))
    return icon


def enter():
    icon = Icon()
    # An arched door, ajar.
    icon.poly([(7, 29), (7, 10), (16, 3), (25, 10), (25, 29)], ramp("5a5664"))
    icon.poly([(10, 29), (10, 11), (16, 6), (22, 11), (22, 29)], ramp(WOOD))
    icon.poly([(10, 29), (10, 11), (14, 8), (14, 29)], ramp("2a2030"))
    icon.put(19, 19, (232, 188, 74))
    return icon


def read():
    icon = Icon()
    # An open scroll.
    icon.rect((7, 6, 25, 26), ramp(PAPER))
    icon.rect((5, 4, 27, 7), ramp(WOOD))
    icon.rect((5, 25, 27, 28), ramp(WOOD))
    for y in (11, 15, 19):
        icon.line([(10, y), (22, y)], 1, ramp("6a5a46"))
    return icon


def stone():
    icon = Icon()
    # A standing stone with a glowing rune.
    icon.poly([(8, 29), (9, 10), (13, 3), (20, 3), (24, 10), (25, 29)], ramp("8a8694"))
    icon.line([(16, 9), (16, 22)], 1, ramp("4ad8f0"))
    icon.line([(12, 13), (20, 13)], 1, ramp("4ad8f0"))
    icon.line([(13, 19), (19, 16)], 1, ramp("4ad8f0"))
    return icon


def pick_up():
    icon = Icon()
    # A hand reaching down to a coin.
    icon.ellipse((10, 20, 22, 30), ramp(GOLD))
    icon.rect((11, 2, 22, 12), ramp("e8c4a0"))
    for x in (11, 15, 19):
        icon.rect((x, 10, x + 2, 17), ramp("e8c4a0"))
    return icon


def sleep():
    icon = Icon()
    # A crescent moon and a Z.
    icon.ellipse((4, 6, 22, 26), ramp(GOLD))
    erase(icon, lambda x, y: ((x - 18) / 8.0) ** 2 + ((y - 12) / 9.5) ** 2 < 1.0)
    icon.line([(19, 20), (28, 20), (19, 29), (28, 29)], 1, ramp(PAPER))
    return icon


# Order of the cells; touch_controls.gd looks them up by name.
ICONS = [("dash", dash), ("parry", parry), ("swap", swap), ("run", run), ("walk", walk), ("ride", ride),
         ("drink", drink), ("chat", chat), ("use", use), ("talk", talk), ("open", open_chest), ("enter", enter),
         ("read", read), ("stone", stone), ("pick_up", pick_up), ("sleep", sleep)]


def main():
    sheet = Image.new("RGBA", (32 * len(ICONS), 32), (0, 0, 0, 0))
    for index, (_name, draw) in enumerate(ICONS):
        sheet.alpha_composite(draw().image(), (index * 32, 0))
    out = os.path.join(ROOT, "assets", "icons", "touch.png")
    sheet.save(out)
    print("touch icons: " + ", ".join(name for name, _draw in ICONS))


if __name__ == "__main__":
    main()
