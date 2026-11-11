class_name RecruitMenu
extends GameMenu
## Asking a villager to come and live at your home.

var offer: Dictionary = {}

var _title: Label
var _text: Label
var _terms: Label
var _message: Label
var _button: Button


func _build() -> void:
	_title = UITheme.heading("", 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	var panel := UITheme.inset_panel()
	panel.custom_minimum_size = Vector2(620, 0)
	content.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_text = UITheme.label("", 16)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size = Vector2(580, 60)
	box.add_child(_text)
	_terms = UITheme.label("", 15, UITheme.DIM)
	_terms.autowrap_mode = TextServer.AUTOWRAP_WORD
	_terms.custom_minimum_size = Vector2(580, 40)
	box.add_child(_terms)
	_button = UITheme.button("Invite them home", func() -> void:
		_message.text = _settlers().recruit(offer)
		refresh()
	, 260.0)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_button)
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	_message.custom_minimum_size = Vector2(600, 40)
	content.add_child(_message)


func _settlers() -> Settlers:
	return player.get_parent().get_node("Settlers")


func refresh() -> void:
	if offer.is_empty():
		return
	var settlers := _settlers()
	var role: Dictionary = Settlers.ROLES[offer["role"]]
	_title.text = "%s the %s" % [offer["name"], role["title"]]
	if settlers.has_settler(offer["id"]):
		_text.text = "\"I'll see you at home.\""
		_terms.text = ""
		_button.disabled = true
		return
	_text.text = "\"This village is no place for a %s. If you have a roof and a spare bed, I'd come and work for you.\"\n\n%s" % [role["title"].to_lower(), role["text"]]
	_terms.text = "Cost to move: %d gold.   Beds needed: one for you and one for each settler (you have %d).   Settlers so far: %d." % [settlers.cost(), settlers.beds(), settlers.settlers.size()]
	var problem := settlers.recruit_problem(offer["id"])
	_button.disabled = problem != ""
	if problem != "" and _message.text == "":
		_message.text = problem
