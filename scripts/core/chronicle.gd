class_name Chronicle
extends Node
## The log of what was said and what happened: villagers' words, merchants'
## remarks, announcements, quests done, levels gained, bosses felled, and
## deaths, each with the day and hour. Kept in the save (the newest few
## hundred); read in the Log screen.

const KEEP := 300
## Kinds of entry, for the Log's filters.
const KINDS := {"speech": "Speech", "event": "Events", "fight": "Battles", "quest": "Quests"}

## [day, hour text, kind, who, text]
var entries: Array = []


func _ready() -> void:
	add_to_group("chronicle")
	SaveGame.register("chronicle", self)
	Events.announcement.connect(func(title: String, detail: String) -> void:
		var words := detail if title == "" else ("%s: %s" % [title.capitalize(), detail] if detail != "" else title.capitalize())
		if detail.begins_with("\"") and title == "":
			note("speech", "", detail.trim_prefix("\"").trim_suffix("\""))
		else:
			note("event", "", words))
	Events.quest_completed.connect(func(title: String, rewards: String) -> void: note("quest", "", "Quest done: %s. %s" % [title, rewards]))
	Events.level_up.connect(func(level: int) -> void: note("event", "", "Reached level %d." % level))
	Events.boss_defeated.connect(func(boss_id: String) -> void:
		note("fight", "", "Felled %s." % str(BossDB.BOSSES.get(boss_id, {}).get("name", "a great beast"))))
	Events.player_died.connect(func(_xp: int) -> void:
		var player := get_tree().get_first_node_in_group("player") as Player
		var recap := player.death_recap() if player else ""
		note("fight", "", "You fell. " + recap.replace("\n", " ")))


## Adds a line to the log of whoever is listening.
static func say(tree: SceneTree, kind: String, who: String, text: String) -> void:
	var chronicle := tree.get_first_node_in_group("chronicle") as Chronicle
	if chronicle:
		chronicle.note(kind, who, text)


func note(kind: String, who: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	# The same line twice in a row (a remark repeated) is kept once.
	if not entries.is_empty() and entries.back()[4] == text and entries.back()[3] == who:
		return
	var day_night: DayNight = get_parent().get_node_or_null("DayNight") if get_parent() else null
	var day := day_night.day if day_night else 1
	var hour := day_night.clock() if day_night and day_night.has_method("clock") else (day_night.phase() if day_night else "")
	entries.append([day, hour, kind, who, text])
	if entries.size() > KEEP:
		entries = entries.slice(entries.size() - KEEP)


func save_data() -> Dictionary:
	return {"entries": entries}


func load_data(data: Dictionary) -> void:
	var saved: Variant = data.get("entries", [])
	entries = []
	if saved is Array:
		for entry: Variant in saved:
			if entry is Array and (entry as Array).size() == 5:
				entries.append(entry)
