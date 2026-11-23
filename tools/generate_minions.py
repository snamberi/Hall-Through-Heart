"""The player's summoned allies, each drawn for itself (they used to be
tinted copies of monsters): a Necromancer's Risen Dead and Bound Archers,
and a Spellcaster's Familiar.

Drawn with the monster rigs and poses of generate_art.py, in their own
palette: grave linen and corpse flesh lit from inside by necromantic violet,
and an arcane indigo for the familiar.

Run from the repository root:  python3 tools/generate_minions.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import generate_art as GA  # noqa: E402
from generate_art import E, R  # noqa: E402

GA.PALETTE.update({
    "shroud": ["d6cfbe", "a8a090", "726b5e"],
    "shroud_dark": ["4c465c", "353142", "24212e"],
    "necro": ["c290ff", "9a5ce8", "6a34b8"],
    "necro_glow": ["f0dcff", "f0dcff", "f0dcff"],
    "grave_dirt": ["6e5844", "503f30", "362a20"],
    "arcana": ["6a74d8", "4a50a8", "2e336c"],
    "arcana_belly": ["b4bef8", "8c98e4", "6670c0"],
    "arcana_glow": ["b8f6ff", "b8f6ff", "b8f6ff"],
    "star": ["fff4b8", "fff4b8", "fff4b8"],
    "rune": ["d8b8ff", "a884f0", "7656c4"],
})
GA.TEXTURES["flesh"] += ["shroud"]
GA.TEXTURES["spectral"] += ["arcana"]
GA.TEXTURE_OF.update({"shroud": "flesh", "arcana": "spectral"})

# A Risen Dead: hunched in a torn burial shroud, grave dirt to the shins,
# the chest open on its ribs with a seam of violet soul-light, the jaw
# hanging, one arm reaching for whatever it is set on.
RISEN_DEAD = GA._biped(
    back_arm=[("corpse", [(12, 21), (15, 21), (15.5, 30), (14, 35), (11.5, 33)]), ("corpse_d", [(11.5, 33), (14, 35), (12, 37.5), (10.5, 35)]),
              ("bone", [(11.6, 36.5), (10.8, 39.4), (12.4, 38)]), ("shroud", [(11.5, 20.5), (15.6, 20.5), (15.2, 26), (11.8, 26)]),
              ("shroud_dark", [(11.6, 24.6), (15.3, 24.6), (15.2, 26), (11.8, 26)])],
    leg_l=[("shroud", [(16, 32), (21, 32), (20.6, 38), (16.4, 38)]), ("corpse_d", R(16.6, 37.6, 20.4, 40)),
           ("grave_dirt", [(15.4, 38.6), (21.2, 39), (21.2, 41.6), (15.4, 41.6)])],
    leg_r=[("shroud", [(23, 32), (28, 32), (27.6, 38), (23.4, 38)]), ("corpse", R(23.6, 37.6, 27.4, 40)),
           ("grave_dirt", [(23, 38.8), (28.6, 38.6), (28.6, 41.6), (23, 41.6)])],
    torso=[("shroud", [(15, 19), (29, 19), (31, 33), (28.5, 36.5), (25.5, 33.5), (22.5, 37.5), (19.5, 33.5), (16.5, 36.5), (13, 33)]),
           ("corpse", [(18, 20), (26.5, 20), (26, 28.5), (18.5, 28.5)]),
           ("void", R(19, 21.8, 25.6, 22.6)), ("void", R(19, 24.2, 25.6, 25)), ("void", R(19.2, 26.6, 25.4, 27.4)),
           ("necro", R(21.4, 20.6, 22.8, 29.5)), ("necro_glow", R(21.7, 22.6, 22.5, 26.4)),
           ("shroud_dark", [(15.2, 19), (16.6, 19), (16.4, 33.5), (14.8, 31.5)]), ("shroud_dark", [(27.8, 19), (29, 19), (30, 31), (28.2, 33.5)]),
           ("shroud_dark", [(19, 29.4), (20, 29.4), (20.4, 35.6), (19.4, 35.6)]), ("grave_dirt", E(14.4, 30.6, 17.4, 33.6))],
    head=[("corpse", E(16, 6, 30, 20)), ("corpse_d", E(16.5, 13.5, 29.5, 21)),
          ("void", E(18, 9.6, 22, 14.4)), ("void", E(23.6, 9.6, 27.6, 14.4)),
          ("necro_glow", R(19.4, 11.2, 20.8, 12.6)), ("necro_glow", R(25, 11.2, 26.4, 12.6)),
          ("void", [(19.5, 16.6), (26.5, 16.6), (25.6, 23), (20.4, 23)]),
          ("tooth", [(20.4, 16.6), (21.6, 16.6), (21, 18.4)]), ("tooth", [(24.4, 16.6), (25.6, 16.6), (25, 18.4)]),
          ("tooth", [(22.4, 21.6), (23.4, 21.6), (22.9, 20.2)]),
          ("rag", [(16.5, 7.5), (19.5, 5), (18.5, 10), (16.5, 12)]), ("rag", [(27, 5.6), (30.5, 8.5), (29.6, 12.5), (27.6, 9)]),
          ("grave_dirt", E(23.5, 5.6, 27.5, 8.6))],
    front_arm=[("corpse", [(28, 21), (31.5, 21), (38.5, 23.6), (38, 27), (30, 27.5)]), ("corpse_d", [(31, 25.6), (38, 25.4), (38, 27), (30, 27.5)]),
               ("corpse", [(37, 22.6), (40.6, 22), (41, 24.2), (37.6, 25.4)]),
               ("bone", [(40, 21.8), (42.6, 20.8), (42, 22.6)]), ("bone", [(40.4, 23.6), (43, 24), (41.8, 25)]),
               ("shroud", [(27.6, 20.4), (31.8, 20.4), (32.4, 25.2), (28.2, 25.2)])],
    pivots={"head": (23, 19), "front_arm": (30, 23)},
)

# A Bound Archer: bones held together by violet bindings that glow where
# they knot, a ragged hood over the skull, eyes lit from within, and a bow
# of bone with a string of soul-light.
BOUND_ARCHER = GA._biped(
    back_arm=[("bone", R(12.6, 20, 14.2, 31)), ("necro", [(12, 22.6), (14.8, 21.8), (14.8, 23), (12, 23.8)]),
              ("necro", [(12, 27), (14.8, 26.2), (14.8, 27.4), (12, 28.2)]), ("bone", E(11.8, 30.2, 14.8, 33.2))],
    leg_l=[("bone", R(18, 32, 19.6, 40)), ("bone", R(16.8, 39.6, 20.6, 41.4)), ("necro", [(17.6, 35), (20, 34.2), (20, 35.4), (17.6, 36.2)]),
           ("shroud_dark", [(16, 31.6), (21, 31.6), (20.4, 34), (16.6, 34.6)])],
    leg_r=[("bone", R(24.4, 32, 26, 40)), ("bone", R(23.4, 39.6, 27.4, 41.4)), ("shroud_dark", [(23, 31.6), (28, 31.6), (27.4, 34.6), (23.6, 34)])],
    torso=[("bone", R(20.8, 19, 23.4, 33)),
           ("bone", [(16.8, 20.6), (27.4, 20.6), (26.6, 22.6), (17.6, 22.6)]), ("bone", [(17.2, 23.8), (27, 23.8), (26.2, 25.8), (18, 25.8)]),
           ("bone", [(17.8, 27), (26.4, 27), (25.4, 28.8), (18.8, 28.8)]), ("bone", E(17, 29.6, 27.4, 34)),
           ("shroud_dark", [(13.6, 17), (30.4, 17), (29.6, 22.4), (26.4, 19.8), (17.6, 19.8), (14.4, 22.4)]),
           ("necro", [(16.6, 25.4), (27.6, 22.4), (27.6, 23.8), (16.6, 26.8)]), ("necro_glow", R(21.4, 23.4, 22.8, 24.8)),
           ("shroud_dark", [(16, 31.4), (28, 31.4), (27, 36), (24.6, 33.6), (22, 37), (19.4, 33.6), (17, 36)])],
    head=[("shroud_dark", [(13.6, 9), (18, 2.6), (26, 1.8), (31.4, 7), (31.4, 19.6), (28, 15), (16, 15), (13.6, 19.6)]),
          ("bone", E(17, 6.6, 28.4, 19)), ("bone", R(19, 16, 26.4, 20)),
          ("void", E(18.4, 9.8, 22.2, 14.2)), ("void", E(23.4, 9.8, 27.2, 14.2)),
          ("necro_glow", R(19.6, 11.2, 21, 12.6)), ("necro_glow", R(24.6, 11.2, 26, 12.6)),
          ("void", R(20, 17.8, 20.7, 20)), ("void", R(22.1, 17.8, 22.8, 20)), ("void", R(24.2, 17.8, 24.9, 20)),
          ("shroud_dark", [(13.6, 9), (18, 2.6), (26, 1.8), (31.4, 7), (30.4, 9.4), (25.4, 5.2), (19, 6), (15.8, 10.4)]),
          ("necro", [(14.2, 15.6), (17.6, 15.2), (17.2, 16.4), (14.2, 16.8)])],
    front_arm=[("bone", R(29.6, 21, 31.2, 31)), ("necro", [(29, 25.8), (31.8, 25), (31.8, 26.2), (29, 27)]),
               ("bone", [(33, 12.6), (35.2, 14.6), (36.6, 24), (35.2, 33.4), (33, 35.4), (34.2, 32.4), (35.4, 24), (34, 15.6)]),
               ("bone", E(34.6, 22.4, 37.4, 25.6)), ("necro_glow", R(32.6, 13.8, 33.2, 34.6)),
               ("necro", E(32, 12, 34, 14)), ("necro", E(32, 34.2, 34, 36.2))],
)

# A Familiar: a small owl-like spirit of the arcane, deep indigo flecked
# with stars, lantern eyes, ear tufts, and a tail of starlight; runes drift
# about it.
FAMILIAR = GA._floater(
    body=[("arcana", E(12, 13, 32, 32)), ("arcana_belly", E(16, 20, 28, 31.4)),
          ("arcana", [(17, 23), (19, 24.6), (21, 23)]), ("arcana", [(23, 23), (25, 24.6), (27, 23)]),
          ("arcana", [(19, 26.6), (21, 28.2), (23, 26.6)]), ("arcana", [(23.6, 26.6), (25.6, 28.2), (27.4, 26.6)]),
          ("star", R(14, 18, 14.8, 18.8)), ("star", R(29.4, 21, 30.2, 21.8)), ("star", R(15.6, 27.2, 16.4, 28)),
          ("rune", [(5, 18), (7, 17), (7.6, 19.4), (5.6, 20)]), ("rune", [(37, 25), (39.4, 24.4), (39, 26.8), (36.8, 27)]),
          ("rune", [(9, 33), (11, 32), (11.4, 34.4), (9.4, 35)]), ("arcana_glow", R(5.8, 18.2, 6.6, 19)), ("arcana_glow", R(37.6, 25.2, 38.4, 26))],
    head=[("arcana", [(13, 15), (14.6, 6.6), (18.4, 13)]), ("arcana", [(26, 13), (29.4, 6.6), (31, 15)]),
          ("rune", [(14.2, 9), (15, 7.4), (16, 10.4)]), ("rune", [(28.2, 10.4), (29, 7.4), (29.8, 9)]),
          ("void", E(14.6, 14.6, 21.4, 21.4)), ("void", E(22.6, 14.6, 29.4, 21.4)),
          ("arcana_glow", E(15.4, 15.4, 20.6, 20.6)), ("arcana_glow", E(23.4, 15.4, 28.6, 20.6)),
          ("void", R(17.4, 17, 19, 19.4)), ("void", R(25.4, 17, 27, 19.4)), ("shine", R(16.4, 16, 17.2, 16.8)), ("shine", R(24.4, 16, 25.2, 16.8)),
          ("star", [(21, 20.6), (23, 20.6), (22, 23.4)])],
    tail=[("arcana", [(17, 29), (27, 29), (25, 35), (22, 41), (19, 35)]), ("arcana_belly", [(20, 31), (24, 31), (22, 38)]),
          ("star", R(21.6, 39, 22.4, 39.8)), ("star", R(18.6, 36.6, 19.4, 37.4)), ("star", R(25, 37.4, 25.8, 38.2)), ("star", R(22.2, 43, 23, 43.8))],
    wing_b=[("arcana", [(14, 19), (7, 16), (3, 21), (6, 23), (4, 27), (9, 26), (13, 25)]), ("rune", [(7, 16), (3, 21), (4.4, 21.4), (7.6, 17.4)])],
    wing_f=[("arcana", [(30, 19), (37, 16), (41, 21), (38, 23), (40, 27), (35, 26), (31, 25)]), ("rune", [(37, 16), (41, 21), (39.6, 21.4), (36.4, 17.4)])],
)

MINIONS = {
    "risen_dead": (RISEN_DEAD, GA.HUSK_ORDER, GA.HUSK_ANIMATIONS),
    "bound_archer": (BOUND_ARCHER, GA.HUSK_ORDER, GA.HUSK_ANIMATIONS),
    "familiar": (FAMILIAR, GA.FLOAT_ORDER, GA.FLOAT_ANIMATIONS),
}


def main(only=()):
    out = os.path.join(GA.ROOT, "sprites", "enemies")
    for name, (rig, order, animations) in MINIONS.items():
        if not only or name in only:
            GA.draw_sheet(rig, order, animations, rich=True).save(os.path.join(out, name + ".png"))


if __name__ == "__main__":
    main(set(sys.argv[1:]))
