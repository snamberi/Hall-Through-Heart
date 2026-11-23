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
    for name, (rig, order, animations) in GA.MONSTERS.items():
        if not only or name in only:
            GA.draw_sheet(rig, order, animations, rich=True).save(os.path.join(out, name + ".png"))
    if not only or "husk" in only:
        GA.draw_sheet(GA.HUSK, GA.HUSK_ORDER, GA.HUSK_ANIMATIONS, rich=True).save(os.path.join(GA.ROOT, "sprites", "husk_sheet.png"))
    table = AN.sizes()
    for name, (rig, order, animations) in GA.WILDLIFE.items():
        if only and name not in only:
            continue
        size = table.get(name, 1.0)
        big, scale = AN.improved(name, rig, size)
        anims = [(n, [dict(p, shadow=(22, round(p.get("shadow", (22, 9))[1] * scale), 0)) for p in poses]) for n, poses in animations]
        GA.draw_sheet(big, order, anims, rich=True).save(os.path.join(out, name + ".png"))


if __name__ == "__main__":
    main(set(sys.argv[1:]))
