#!/usr/bin/env python3
"""Draws the interface art for every style the player can choose in
Settings (scripts/ui/ui_theme.gd STYLES) into assets/ui/themes/<style>/.
The base set in assets/ui/ is the walnut style, kept as the fallback.

Run from the repository root:  python3 tools/generate_ui_styles.py
"""
import os
import subprocess
import sys

STYLES = ["parchment", "forge", "dwarven", "ashen", "walnut", "navy"]
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "assets", "ui", "themes")

for style in STYLES:
    out = os.path.join(ROOT, style)
    os.makedirs(out, exist_ok=True)
    env = dict(os.environ, UI_THEME=style, UI_OUT=out)
    subprocess.run([sys.executable, os.path.join(HERE, "generate_ui.py")], env=env, check=True)
    print("style:", style)
