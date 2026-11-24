class_name CompassStrip
extends Control
## A strip along the top of the screen with the compass points on it and a
## mark for each place worth heading to: your waypoint (gold), your home
## (green), the Sanctuary (pale), and for a tracked quest whose objective
## is a kind of place (a cave, a world boss, a graveyard...) the nearest one
## of that kind you have seen (blue). The nearest of them shows its
## distance. North is the middle; the strip spans every direction.

const WIDTH := 420.0
const HEIGHT := 28.0
## Quest stats that mean "go to a place of this kind".
const QUEST_SITES := {
	"caves": "cave", "bosses": "boss", "portals": "portal", "graveyards_cleansed": "graveyard", "minibosses": "lair",
	"waystones": "waystone", "villages": "village", "talk_merchant": "village", "purchases": "village", "sales": "village",
	"dungeons": "dungeon", "shrines": "shrine", "ruins": "ruin", "camps": "camp",
}
const SEARCH_CHUNKS := 8
const REFRESH := 1.0

var _player: Player
var _marks: Array = []
var _refresh_left := 0.0


func setup(player: Player) -> void:
	_player = player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -WIDTH / 2.0
	offset_right = WIDTH / 2.0
	offset_top = 6.0
	offset_bottom = 6.0 + HEIGHT + 18.0


func _process(delta: float) -> void:
	if _player == null:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH
		_marks = _find_marks()
	visible = not _player.indoors and not _marks.is_empty()
	queue_redraw()


## [world position, colour, name] for each place to mark.
func _find_marks() -> Array:
	var marks: Array = []
	var main := _player.get_parent()
	var world: World = main.get_node_or_null("World")
	if world == null:
		return marks
	if MapMenu.waypoint != null:
		marks.append([MapMenu.waypoint, UITheme.GOLD, "Waypoint"])
	var buildings: Buildings = main.get_node_or_null("Buildings")
	if buildings and not buildings.home.is_empty():
		marks.append([Vector2(buildings.home["position"][0], buildings.home["position"][1]), UITheme.GOOD, "Home"])
	marks.append([world.cell_to_world(Vector2i.ZERO), Color(0.95, 0.9, 0.75), "Sanctuary"])
	var quest := _quest_place(world)
	if not quest.is_empty():
		marks.append(quest)
	return marks


## The nearest seen place a tracked quest is asking for, as a mark, or [].
func _quest_place(world: World) -> Array:
	var book: Node = _player.get_parent().get_node_or_null("QuestBook")
	if book == null or not "tracked" in book:
		return []
	for id: String in book.tracked:
		var quest: Dictionary = QuestBookDB.find(id)
		for objective: Dictionary in quest.get("objectives", []):
			var kind: String = QUEST_SITES.get(objective.get("stat", ""), "")
			if kind == "" or book.progress(objective) >= book.goal(objective):
				continue
			var spot := _nearest_site(world, kind)
			if spot != Vector2.INF:
				return [spot, UITheme.INFO, "%s: %s" % [quest.get("title", "Quest"), objective.get("label", kind)]]
	return []


func _nearest_site(world: World, kind: String) -> Vector2:
	var main := _player.get_parent()
	var structures: Structures = main.get_node_or_null("Structures")
	var exploration: Exploration = main.get_node_or_null("Exploration")
	if structures == null or exploration == null:
		return Vector2.INF
	var here := world.world_to_cell(_player.global_position)
	var chunk := Vector2i((Vector2(here) / World.CHUNK_SIZE).floor())
	var best := Vector2.INF
	var best_distance := INF
	if kind == "village":
		var region := Vector2i((Vector2(here) / WorldGenerator.VILLAGE_REGION).floor())
		for ry in range(region.y - 2, region.y + 3):
			for rx in range(region.x - 2, region.x + 3):
				var center: Variant = world.generator.village_center(Vector2i(rx, ry))
				if center != null and exploration.is_tile_seen(center):
					var at := world.cell_to_world(center)
					if at.distance_to(_player.global_position) < best_distance:
						best_distance = at.distance_to(_player.global_position)
						best = at
		return best
	for cy in range(chunk.y - SEARCH_CHUNKS, chunk.y + SEARCH_CHUNKS + 1):
		for cx in range(chunk.x - SEARCH_CHUNKS, chunk.x + SEARCH_CHUNKS + 1):
			var site := structures.site_for(Vector2i(cx, cy))
			if site.is_empty() or site["kind"] != kind or not exploration.is_tile_seen(site["cell"]):
				continue
			var at := world.cell_to_world(site["cell"])
			var distance := at.distance_to(_player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = at
	return best


func _draw() -> void:
	if _marks.is_empty():
		return
	var strip := Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT))
	draw_rect(strip, Color(0.071, 0.054, 0.040, 0.72))
	draw_rect(strip, Color("8a683a"), false, 1.0)
	var font := UITheme.body_bold()
	# The compass points and ticks: N in the middle, S at both ends.
	for index in 8:
		var angle := index * 45.0
		var x := _x_for(angle)
		var main := index % 2 == 0
		draw_line(Vector2(x, HEIGHT - (8.0 if main else 5.0)), Vector2(x, HEIGHT - 1.0), Color(0.75, 0.7, 0.6, 0.8), 1.0)
		if main:
			var letter: String = ["N", "E", "S", "W"][index / 2]
			draw_string(font, Vector2(x - 5.0, 13.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.BAD if letter == "N" else Color(0.85, 0.82, 0.75))
	if _x_for(180.0) > WIDTH - 4.0:
		draw_string(font, Vector2(1.0, 13.0), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.82, 0.75))
	# The marks, and the distance to the nearest.
	var nearest: Array = []
	var nearest_distance := INF
	for mark: Array in _marks:
		var offset: Vector2 = (mark[0] as Vector2) - _player.global_position
		var distance := offset.length()
		if distance < 40.0:
			continue
		# Bearing from north, clockwise, in degrees.
		var bearing := fposmod(rad_to_deg(atan2(offset.x, -offset.y)), 360.0)
		var x := _x_for(bearing)
		var color: Color = mark[1]
		draw_colored_polygon(PackedVector2Array([Vector2(x, HEIGHT - 4.0), Vector2(x - 5.0, HEIGHT - 12.0), Vector2(x, HEIGHT - 20.0), Vector2(x + 5.0, HEIGHT - 12.0)]), Color(0, 0, 0, 0.8))
		draw_colored_polygon(PackedVector2Array([Vector2(x, HEIGHT - 6.0), Vector2(x - 3.5, HEIGHT - 12.0), Vector2(x, HEIGHT - 18.0), Vector2(x + 3.5, HEIGHT - 12.0)]), color)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = [x, color, mark[2], distance]
	if not nearest.is_empty():
		var words := "%s  ·  %d tiles" % [nearest[2], roundi(float(nearest[3]) / TerrainTiles.TILE_SIZE)]
		var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var x := clampf(float(nearest[0]) - width / 2.0, 0.0, WIDTH - width)
		draw_string_outline(font, Vector2(x, HEIGHT + 15.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.02, 0.02, 0.04, 0.9))
		draw_string(font, Vector2(x, HEIGHT + 15.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, nearest[1])


## Where a bearing (degrees from north, clockwise) falls on the strip.
func _x_for(bearing: float) -> float:
	var centred := fposmod(bearing + 180.0, 360.0) - 180.0
	return WIDTH / 2.0 + centred / 180.0 * (WIDTH / 2.0)
