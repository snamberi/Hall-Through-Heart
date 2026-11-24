"""Redraws only the monster and wild animal sheets (not people, tiles or
icons): python3 tools/redraw_monsters.py [name ...]

Uses the rigs and poses in generate_art.py and the sizes in
generate_animals.py, exactly as the full rebuild does.
"""
import os
import sys

import generate_art as GA
import generate_animals as AN


def main(only):
    out = os.path.join(GA.ROOT, "sprites", "enemies")
    # The monsters (and the husk), drawn at their own sizes.
    AN.monsters()
    table = AN.sizes()
    import generate_beasts
    import generate_birds
    for name, (rig, order, animations) in GA.WILDLIFE.items():
        if only and name not in only:
            continue
        # Hand-drawn elsewhere: the four-legged beasts and the birds.
        if name in generate_beasts.SPECIES or name in generate_birds.SPECIES:
            continue
        size = table.get(name, 1.0)
        big, scale = AN.improved(name, rig, size)
        anims = [(n, [dict(p, shadow=(22, round(p.get("shadow", (22, 9))[1] * scale), 0)) for p in poses]) for n, poses in animations]
        GA.draw_sheet(big, order, anims, rich=True).save(os.path.join(out, name + ".png"))


if __name__ == "__main__":
    main(set(sys.argv[1:]))
