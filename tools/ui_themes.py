"""Interface skins for tools/generate_ui.py: ten ways the game's windows can
look, one picked with UI_THEME=<name> (default "walnut", the one in use).

Each theme sets the metals (the window's frame, its trim and studs, the
quiet rim of ordinary cards and buttons), the window's surface (wood grain,
woven cloth, dressed stone, tooled leather, parchment or frosted glass),
the page inside it, the cards, slots, buttons and tooltip, and the colours
of the text set on them (scripts/ui/ui_theme.gd).
"""


def metal(out, dark, mid, light, hi):
    return {"out": out, "dark": dark, "mid": mid, "light": light, "hi": hi}


GOLD = metal("1a1206", "7a5418", "c8902e", "f2c14e", "fff0b0")
BRONZE = metal("120c08", "4a3218", "8a6234", "c89a52", "f0d088")
SILVER = metal("0c0e12", "4a5260", "8a94a4", "c4ccd8", "f0f4fa")
IRON = metal("0a0a0c", "2a2a30", "45454e", "65656e", "8a8a94")
COPPER = metal("140a06", "5a2e18", "9a5430", "d08050", "f8c098")
BONE = metal("14100c", "6a6050", "a89a80", "d8ccb0", "f8f0e0")
BLOOD = metal("140406", "4a0e14", "7a1a24", "b02a34", "e06a70")
VIOLET = metal("0e0818", "3a2458", "6a48a0", "a080d8", "e0d0ff")
JADE = metal("06100c", "1e4a36", "3a7a5a", "6ab08a", "b8f0d0")
ICE = metal("0a1018", "3a5a78", "6a90b0", "a8d0ec", "f0faff")

THEMES = {
    "walnut": {
        "title": "Walnut & Gold", "text": "A book's board of dark walnut bound in bronze, gold studs and a gold rule; smoke-dark vellum pages.",
        "frame": BRONZE, "trim": GOLD, "gem": "c83a3a", "rim": metal("0c0805", "2e1f14", "4a3424", "664a32", "8a6a48"),
        "surface": ("wood", {"dark": "2a1a10", "mid": "3a2616", "light": "4a321e", "grain": "22150c", "knot": "1a1008"}),
        "page": ("1e1610", "231a13", "1a130d", "6a5028", "4a3620"),
        "card": "261a11", "card_hover": "33241a", "card_selected": "3a2c16", "card_dim": "17110c", "slot": "140e0a",
        "button": ("3a2818", "553a24", "24180e"), "button_hover": "4a331e", "button_pressed": "5a4320", "button_disabled": "1e1712",
        "tooltip": "1c140e", "ink": ("e6dfcf", "9a8c74", "e8c878", "f2c14e", "5a4630"),
    },
    "parchment": {
        "title": "Parchment Book", "text": "Light parchment pages in a leather-bound book with brass corners; dark ink text.",
        "frame": metal("140c06", "4a2c18", "6e4228", "945c38", "c08458"), "trim": BRONZE, "gem": "a83030",
        "rim": metal("2a1a0e", "8a6a48", "a8865c", "c8a878", "e8d0a0"),
        "surface": ("leather", {"dark": "b8966a", "mid": "c6a478", "light": "d2b286", "grain": "a8865a", "knot": "9a7a50"}),
        "page": ("e8d8b0", "f0e2c0", "dcc8a0", "a88a5a", "8a6a40"),
        "card": "e2d0a4", "card_hover": "ecdcb4", "card_selected": "f2d890", "card_dim": "cdbb92", "slot": "d4c096",
        "button": ("c8a878", "e0c494", "9a7a50"), "button_hover": "d8b888", "button_pressed": "b08a58", "button_disabled": "a8987a",
        "tooltip": "efe0bc", "ink": ("3a2818", "6a5638", "5a2a10", "8a4a10", "a88a5a"),
    },
    "navy": {
        "title": "Midnight Navy", "text": "Deep navy cloth in heavy riveted bronze with red-gem corner bosses (the old look).",
        "frame": BRONZE, "trim": BRONZE, "gem": "c83a3a", "rim": metal("080a10", "222838", "39415a", "4e5876", "6a7494"),
        "surface": ("cloth", {"dark": "111624", "mid": "131929", "light": "161d30", "grain": "10141f", "knot": "0e121c"}),
        "page": ("0c101a", "0e131f", "0b0e17", "3a3020", "1c1a1e"),
        "card": "151b2b", "card_hover": "1c2338", "card_selected": "2a2414", "card_dim": "0e1119", "slot": "0b0e16",
        "button": ("242a3c", "343c52", "171b27"), "button_hover": "323a52", "button_pressed": "4a3a20", "button_disabled": "181b24",
        "tooltip": "0e1220", "ink": ("e6dfcf", "8f8a80", "e8c878", "f2c14e", "39415a"),
    },
    "forge": {
        "title": "Forged Iron", "text": "Blackened iron plate, hammered rivets and glowing ember seams; a forge-hot orange for what's chosen.",
        "frame": IRON, "trim": metal("1a0a04", "7a3010", "d06020", "ff9a40", "ffe0a0"), "gem": "ff7a20",
        "rim": IRON,
        "surface": ("stone", {"dark": "1a1a1e", "mid": "222226", "light": "2c2c32", "grain": "141418", "knot": "ff7a2a"}),
        "page": ("141416", "18181b", "111113", "4a2a14", "2a2a2e"),
        "card": "1e1e22", "card_hover": "28282e", "card_selected": "3a2210", "card_dim": "141416", "slot": "111113",
        "button": ("2e2e34", "44444c", "1a1a1e"), "button_hover": "3a3a42", "button_pressed": "5a3014", "button_disabled": "1a1a1c",
        "tooltip": "18181b", "ink": ("e8e4dc", "8e8a84", "ffb060", "ff9a40", "45454e"),
    },
    "elven": {
        "title": "Elven Grove", "text": "Deep green leaf-dyed cloth framed in pale silver vines with jade studs; moonlit pages.",
        "frame": SILVER, "trim": JADE, "gem": "6ae0a0", "rim": metal("06100c", "1a3a2c", "2e5a46", "467a62", "6aa088"),
        "surface": ("cloth", {"dark": "10241c", "mid": "142c22", "light": "183428", "grain": "0e2018", "knot": "0c1c14"}),
        "page": ("0e1c16", "12221a", "0c1812", "3a6a52", "1e3a2e"),
        "card": "13261e", "card_hover": "1a3226", "card_selected": "1e3a2a", "card_dim": "0c1812", "slot": "0b1610",
        "button": ("1e3a2c", "2e5442", "122418"), "button_hover": "264a38", "button_pressed": "2e5a3a", "button_disabled": "13201a",
        "tooltip": "0e1c16", "ink": ("e4efe6", "8aa898", "c8f0d8", "8ae0b0", "2e5a46"),
    },
    "dwarven": {
        "title": "Dwarven Hall", "text": "Dressed grey stone blocks bound in copper bands and brass rivets; runes on the corners.",
        "frame": COPPER, "trim": metal("140c04", "6a4818", "a87a30", "e0b050", "fff0b0"), "gem": "4ab0e8",
        "rim": metal("0c0c0e", "34343a", "50505a", "6c6c78", "90909c"),
        "surface": ("stone", {"dark": "3a3a40", "mid": "46464c", "light": "52525a", "grain": "2e2e34", "knot": "26262c"}),
        "page": ("26262a", "2c2c30", "222226", "6a4a28", "3a3a40"),
        "card": "2e2e34", "card_hover": "38383e", "card_selected": "4a3a24", "card_dim": "222226", "slot": "1e1e22",
        "button": ("4a4a52", "62626c", "2e2e34"), "button_hover": "56565e", "button_pressed": "6a4a28", "button_disabled": "2a2a2e",
        "tooltip": "2a2a2e", "ink": ("eceae4", "9c9a94", "f0c070", "e0b050", "50505a"),
    },
    "bloodmoon": {
        "title": "Blood Moon", "text": "Crimson tooled leather, black iron and bone; the Heart's red for what's chosen.",
        "frame": metal("0a0606", "2a1a1a", "3e2828", "5a3a3a", "7a5050"), "trim": BONE, "gem": "ff3a4a",
        "rim": metal("100406", "3a1218", "5a1e26", "7a2a34", "9a3a44"),
        "surface": ("leather", {"dark": "3a0e14", "mid": "4a141a", "light": "5a1a22", "grain": "2e0a10", "knot": "24080c"}),
        "page": ("1c0a0c", "220e10", "180809", "6a2a2a", "3a1418"),
        "card": "2a1014", "card_hover": "36161a", "card_selected": "4a1a1e", "card_dim": "1a0a0c", "slot": "160809",
        "button": ("4a1a20", "6a2a30", "2a0c10"), "button_hover": "5a2028", "button_pressed": "7a2a30", "button_disabled": "2a1416",
        "tooltip": "1e0c0e", "ink": ("f0e4e0", "a08888", "ff8a90", "ff5a64", "5a1e26"),
    },
    "arcane": {
        "title": "Arcane Starlight", "text": "Deep violet velvet sewn with stars, pale gold filigree and amethyst corners.",
        "frame": VIOLET, "trim": GOLD, "gem": "c080ff", "rim": metal("0a0614", "2a1a44", "3e2a62", "564082", "7a62a8"),
        "surface": ("cloth", {"dark": "1e1230", "mid": "24163a", "light": "2a1a44", "grain": "1a0e2a", "knot": "fff0b0"}),
        "page": ("140c22", "180e28", "10081c", "5a4a88", "2a1a44"),
        "card": "1e1232", "card_hover": "28183e", "card_selected": "3a2a18", "card_dim": "140c22", "slot": "120a1e",
        "button": ("34224e", "4a346a", "1e1230"), "button_hover": "3e2a5c", "button_pressed": "4a3a20", "button_disabled": "1c1428",
        "tooltip": "160e26", "ink": ("ece6f8", "9a90b0", "e8c878", "f2c14e", "3e2a62"),
    },
    "frost": {
        "title": "Frost Glass", "text": "Frosted blue glass in white silver, ice-crystal corners; cold and clean.",
        "frame": SILVER, "trim": ICE, "gem": "a8f0ff", "rim": metal("0a1018", "2a4058", "3e5a78", "5a7a98", "8aa8c4"),
        "surface": ("glass", {"dark": "1a2a3a", "mid": "1e3044", "light": "24384e", "grain": "16243a", "knot": "4a6a8a"}),
        "page": ("121e2a", "162432", "0f1824", "4a6a88", "24384e"),
        "card": "1a2a3a", "card_hover": "223648", "card_selected": "2a4458", "card_dim": "121e2a", "slot": "101a26",
        "button": ("2a4058", "3e5a78", "1a2a3a"), "button_hover": "345070", "button_pressed": "3e6a88", "button_disabled": "1a2430",
        "tooltip": "142230", "ink": ("eef6fc", "8aa0b4", "c8ecff", "a8e0ff", "3e5a78"),
    },
    "ashen": {
        "title": "Ashen Bone", "text": "Charcoal and soot, bone-white trim and no gems; quiet and stark, the text does the work.",
        "frame": BONE, "trim": BONE, "gem": "e8e0d0", "rim": metal("0a0a0a", "2a2826", "3e3a36", "56504a", "7a726a"),
        "surface": ("cloth", {"dark": "161514", "mid": "1a1918", "light": "1e1d1c", "grain": "131211", "knot": "121110"}),
        "page": ("121110", "151413", "0f0e0d", "5a544c", "2a2826"),
        "card": "1a1918", "card_hover": "24221f", "card_selected": "302c24", "card_dim": "121110", "slot": "0f0e0d",
        "button": ("2a2826", "3e3a36", "181716"), "button_hover": "34312d", "button_pressed": "48423a", "button_disabled": "1a1918",
        "tooltip": "141312", "ink": ("ece8e0", "8e8880", "f0e8d8", "e8dcc0", "3e3a36"),
    },
}
