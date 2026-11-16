class_name MenuIcons
extends RefCounted
## Pictures for the menu screens (tools/generate_ability_icons.py): a
## backpack for the inventory, a folded map for the map, and so on.

const SHEET: Texture2D = preload("res://assets/icons/menus.png")
const IDS: Array[String] = ["inventory", "abilities", "class", "magic", "build", "professions", "journal", "map",
	"attributes", "talents", "mastery", "evolution", "codex", "pets", "wardrobe", "pause", "relics"]
static var _icons: Dictionary = {}


## Screens drawn with an item icon instead (screen id -> item icon index).
const FROM_ITEMS := {"runes": 156}


static func icon(screen_id: String) -> Texture2D:
	if FROM_ITEMS.has(screen_id):
		return ItemDB.icon(FROM_ITEMS[screen_id])
	if not _icons.has(screen_id):
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(maxi(IDS.find(screen_id), 0) * 24, 0, 24, 24)
		_icons[screen_id] = atlas
	return _icons[screen_id]
