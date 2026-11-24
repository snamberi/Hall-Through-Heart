"""The goblins, drawn with the monster rig of generate_art.py:

  goblin        a camp goblin in patched hide and a rope belt, a short spear,
                big ears, curious yellow eyes (leaves you be unless struck)
  goblin_raider a wild goblin: red war paint, a spiked leather cap, a
                notched cleaver and a necklace of teeth (attacks on sight)
  goblin_chief  the leader of a camp: bigger, a bone crown and a cloak of
                pelts, a heavy club bound with iron

Run from the repository root:  python3 tools/generate_goblins.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate_art as GA  # noqa: E402
from generate_art import E, R  # noqa: E402

GA.PALETTE.update({
    "gob": ["9cc464", "76a048", "507434"],
    "gob_d": ["76a048", "587c36", "3e5a26"],
    "gob_ear": ["e0a08c", "c07c6a", "8e5648"],
    "gob_eye": ["fff0a0", "ffe060", "e0b030"],
    "gob_hide": ["b89468", "8e7048", "624c30"],
    "gob_patch": ["8a6a8e", "6a4e6e", "4a364e"],
    "rope": ["d8c08a", "b09a64", "806c44"],
    "war_paint": ["e04a3a", "b0302a", "7a1e1a"],
    "pelt": ["9a8a78", "766654", "54483a"],
    "iron": ["c4ccd6", "8a94a2", "5a6270"],
})
GA.TEXTURES["flesh"] += ["gob", "gob_d"]
GA.TEXTURES["fur"] += ["gob_hide", "pelt"]
GA.TEXTURE_OF.update({"gob": "flesh", "gob_d": "flesh", "gob_hide": "fur", "pelt": "fur"})


def _head(extra=()):
    return [
        # Long ears sweeping back, pink inside.
        ("gob", [(16, 13), (7, 8), (9, 12), (16, 17)]), ("gob_ear", [(15, 13.6), (9.6, 10), (10.6, 12), (15, 15.6)]),
        ("gob", [(29, 13), (38, 8), (36, 12), (29, 17)]), ("gob_ear", [(30, 13.6), (35.4, 10), (34.4, 12), (30, 15.6)]),
        ("gob", E(15.5, 8, 30, 22)), ("gob_d", E(16, 16, 29.5, 22.6)),
        # A long hooked nose, deep-set eyes, a toothy grin.
        ("gob_d", [(22, 14), (24.6, 14), (26.4, 19.4), (23.4, 18.6)]),
        ("void", E(18, 12.2, 21.6, 15.6)), ("void", E(24.6, 12.2, 28.2, 15.6)),
        ("gob_eye", R(19, 13, 20.6, 14.6)), ("gob_eye", R(25.6, 13, 27.2, 14.6)),
        ("mouth", [(19.4, 19.2), (27, 19.2), (26, 21), (20.4, 21)]),
        ("tooth", R(20.6, 19.2, 21.4, 20.2)), ("tooth", R(24.6, 19.2, 25.4, 20.2)),
    ] + list(extra)


def _legs(cloth):
    return dict(
        leg_l=[("gob", R(18, 32, 20, 39)), (cloth, R(17.4, 31.6, 20.6, 35)), ("gob_d", [(16.4, 38.6), (20.6, 38.6), (20.6, 41), (15.6, 41)])],
        leg_r=[("gob", R(24, 32, 26, 39)), (cloth, R(23.4, 31.6, 26.6, 35)), ("gob_d", [(23.4, 38.6), (27.6, 38.6), (28.4, 41), (23.4, 41)])],
    )


GOBLIN = GA._biped(
    back_arm=[("gob", R(13, 22, 15.4, 31)), ("gob_d", E(12.4, 30, 15.8, 33))],
    torso=[("gob_hide", [(16, 21), (28, 21), (29, 33), (15, 33)]), ("gob_patch", R(17.4, 24, 21, 27.6)),
           ("rope", R(15.4, 29.4, 28.6, 30.6)), ("rope", [(21, 30.6), (22.4, 30.6), (22, 34), (21, 34)]),
           ("gob_hide", [(15, 32), (29, 32), (28, 35.6), (25, 34), (22, 36), (19, 34), (16, 35.6)]), ("gob_d", R(19.6, 20.4, 24.6, 22))],
    head=_head(),
    front_arm=[("gob", R(29, 22, 31.4, 30.6)), ("gob_d", E(28.8, 29.4, 32.2, 32.6)),
               ("wood", R(32, 10, 33.2, 38)), ("iron", [(31.4, 10.4), (32.6, 4.6), (33.8, 10.4)]), ("rope", R(31.6, 10.4, 33.6, 11.6))],
    pivots={"head": (23, 20)}, **_legs("gob_hide"),
)

GOBLIN_RAIDER = GA._biped(
    back_arm=[("gob", R(13, 22, 15.4, 31)), ("war_paint", R(13, 24, 15.4, 25)), ("gob_d", E(12.4, 30, 15.8, 33))],
    torso=[("gob_hide", [(16, 21), (28, 21), (29, 33), (15, 33)]), ("war_paint", [(17, 23), (27, 23), (26, 24.4), (18, 24.4)]),
           ("tooth", R(18, 21.2, 18.8, 22.6)), ("tooth", R(20.4, 21.6, 21.2, 23)), ("tooth", R(23, 21.6, 23.8, 23)), ("tooth", R(25.6, 21.2, 26.4, 22.6)),
           ("belt", R(15.4, 29.4, 28.6, 30.8)), ("iron", R(21.2, 29.2, 22.8, 31)),
           ("gob_hide", [(15, 32), (29, 32), (28, 36), (25, 34), (22, 36.6), (19, 34), (16, 36)])],
    head=_head([
        ("war_paint", R(17.6, 15.8, 28.4, 16.8)), ("war_paint", [(22.6, 9), (23.6, 9), (23.4, 12), (22.8, 12)]),
        ("gob_hide", [(16, 11), (18, 6.4), (23, 4.6), (28, 6.4), (30, 11)]), ("iron", [(19, 6.4), (19.8, 3), (20.6, 6)]),
        ("iron", [(22.4, 5), (23, 1.4), (23.6, 5)]), ("iron", [(25.4, 6), (26.2, 3), (27, 6.4)]),
    ]),
    front_arm=[("gob", R(29, 22, 31.4, 30.6)), ("war_paint", R(29, 24, 31.4, 25)), ("gob_d", E(28.8, 29.4, 32.2, 32.6)),
               ("wood", R(31.4, 28, 33, 34)), ("iron", [(30.4, 16), (37, 15), (38, 21), (36, 22.4), (36.4, 25), (32.4, 28.6), (31, 28)]),
               ("void", R(34, 17.6, 34.8, 18.4)), ("shine", [(31.6, 17), (36, 16.2), (36.4, 17)])],
    pivots={"head": (23, 20)}, **_legs("gob_hide"),
)

GOBLIN_CHIEF = GA._biped(
    back_arm=[("pelt", [(10, 19), (16, 19), (16, 36), (11, 38), (9, 30)]), ("gob", R(12.6, 22, 15.6, 32)), ("gob_d", E(12, 31, 16, 34.6))],
    torso=[("pelt", [(12.4, 19), (31.6, 19), (33, 36), (28, 34), (22, 37.4), (16, 34), (11, 36)]),
           ("gob_hide", [(16.4, 21), (27.6, 21), (28.4, 33), (15.6, 33)]), ("bone", E(19.6, 22, 24.4, 26)), ("void", R(21, 23.4, 21.8, 24.2)), ("void", R(22.4, 23.4, 23.2, 24.2)),
           ("belt", R(15.4, 29.2, 28.6, 31)), ("gob_eye", R(21.2, 29.2, 22.8, 31))],
    head=_head([
        ("bone", [(16, 9.4), (17.6, 3.6), (19, 8)]), ("bone", [(19.6, 7.6), (21, 1.6), (22.4, 7.2)]), ("bone", [(23.4, 7.2), (25, 1.6), (26.4, 7.6)]),
        ("bone", [(27, 8), (28.6, 3.6), (30, 9.4)]), ("bone", R(16, 8.4, 30, 10)), ("war_paint", E(21.8, 9, 24.2, 10.6)),
    ]),
    front_arm=[("gob", R(28.6, 22, 31.8, 31)), ("gob_d", E(28.4, 30, 32.4, 33.6)),
               ("wood", [(31, 34), (33, 34), (36.6, 12), (40.4, 8.6), (41.6, 13), (38.6, 16)]),
               ("iron", [(35.2, 17.6), (39.4, 15.4), (39.8, 16.8), (35.6, 19)]), ("iron", [(36.2, 12.4), (40, 9.6), (40.6, 11)]),
               ("iron", [(41, 9), (43, 8), (42, 10.4)])],
    pivots={"head": (23, 20)}, **_legs("pelt"),
)

GOBLINS = {"goblin": GOBLIN, "goblin_raider": GOBLIN_RAIDER, "goblin_chief": GOBLIN_CHIEF}


def main(only=()):
    out = os.path.join(GA.ROOT, "sprites", "enemies")
    for name, rig in GOBLINS.items():
        if not only or name in only:
            GA.draw_sheet(rig, GA.HUSK_ORDER, GA.HUSK_ANIMATIONS, rich=True).save(os.path.join(out, name + ".png"))
    print("goblins:", ", ".join(GOBLINS))


if __name__ == "__main__":
    main(set(sys.argv[1:]))
