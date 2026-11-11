class_name DayNight
extends CanvasModulate
## The passing of days. Tints the whole world through dawn, day, dusk, and
## night, and gives the player a pool of light after dark.

signal day_changed(day: int)

## Real seconds in one full day.
const DAY_SECONDS := 600.0
## Colour of the world at points through the day (0 = midnight, 0.5 = noon).
const SKY: Array[Array] = [
	[0.0, Color(0.28, 0.32, 0.52)], [0.2, Color(0.3, 0.34, 0.54)], [0.27, Color(0.85, 0.66, 0.62)],
	[0.34, Color(1.0, 0.98, 0.94)], [0.68, Color(1.0, 0.98, 0.94)], [0.76, Color(0.95, 0.62, 0.48)],
	[0.84, Color(0.34, 0.36, 0.58)], [1.0, Color(0.28, 0.32, 0.52)],
]
const PHASES: Array[Array] = [[0.22, "Night"], [0.32, "Dawn"], [0.45, "Morning"], [0.58, "Midday"], [0.7, "Afternoon"], [0.82, "Dusk"], [1.0, "Night"]]

## True through a blood moon night: more monsters, more Elites, more loot.
static var blood_moon := false
## One night in this many (after the third day) may be a blood moon.
const BLOOD_MOON_ODDS := 5
const BLOOD_SKY := Color(0.62, 0.22, 0.24)

## Days start at 1. `time` runs 0 to 1 through the day; a new game starts in the morning.
var day := 1
var time := 0.36
## Indoors the light is steady whatever the hour.
var indoors := false

var _light: PointLight2D
## Brightness left from the last lightning strike, 0 to 1.
var _lightning := 0.0


func setup(player: Player) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.7, 1.0))
	gradient.set_color(1, Color(1.0, 0.9, 0.7, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	_light = PointLight2D.new()
	_light.texture = texture
	_light.texture_scale = 2.4
	_light.position = Vector2(0, -14)
	player.add_child(_light)
	_apply()


func _process(delta: float) -> void:
	var was_night := is_night()
	time += delta / DAY_SECONDS
	if time >= 1.0:
		time -= 1.0
		day += 1
		day_changed.emit(day)
	_lightning = maxf(_lightning - delta * 2.2, 0.0)
	var night := is_night()
	if night and not was_night and not indoors:
		blood_moon = blood_moon_tonight()
		if blood_moon:
			Events.announcement.emit("A BLOOD MOON RISES", "Monsters swarm in greater numbers, and drop richer spoils")
			Audio.play("level_up", -4.0, 0.0)
	elif not night and was_night and blood_moon:
		blood_moon = false
		Events.announcement.emit("THE BLOOD MOON SETS", "")
		Events.codex_event.emit("blood_moons", 1)
	_apply()


## Whether tonight is a blood moon: decided by the day number, so it is the
## same if the game is reloaded.
func blood_moon_tonight() -> bool:
	if day < 3:
		return false
	var night_of := day if time > 0.5 else day - 1
	return posmod(hash(night_of * 7919 + 17), BLOOD_MOON_ODDS) == 0


## A lightning strike lights up the whole land for a moment.
func lightning(strength: float) -> void:
	_lightning = maxf(_lightning, strength)


## How dark it is: 0 in full daylight, 1 in the dead of night.
func darkness() -> float:
	return 0.0 if indoors else clampf(1.0 - (_sky().r - 0.28) / 0.72, 0.0, 1.0)


func is_night() -> bool:
	return darkness() > 0.6


func phase() -> String:
	for entry in PHASES:
		if time < entry[0]:
			return entry[1]
	return "Night"


func _sky() -> Color:
	for index in SKY.size() - 1:
		if time <= SKY[index + 1][0]:
			var span: float = SKY[index + 1][0] - SKY[index][0]
			return (SKY[index][1] as Color).lerp(SKY[index + 1][1], (time - SKY[index][0]) / span)
	return SKY[0][1]


func _apply() -> void:
	var sky := _sky()
	if blood_moon:
		sky = sky.lerp(BLOOD_SKY, darkness() * 0.7)
	color = Color(0.82, 0.8, 0.78) if indoors else sky.lerp(Color(0.95, 0.97, 1.0), _lightning)
	SunShadow.update(time, darkness(), indoors, _lightning)
	if _light:
		_light.energy = 0.55 if indoors else darkness() * 0.9
		_light.enabled = _light.energy > 0.02
