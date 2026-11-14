extends Control
## Chief Engineer induction: a short, skippable story/tutorial briefing.
## Character left, paper dialogue card bottom. First run only; replay from the
## title. Text is data-driven so the beats can be tuned without touching layout.

const BEATS := [
	{
		"card": "INDUCTION", "expr": "neutral",
		"text": "Chief. Good - you're early. I'm Dr. Imani Vale, deputy director. The board just signed your appointment, and the press office is already asking for a quote.",
	},
	{
		"card": "THE AGENCY", "expr": "stern",
		"text": "This agency has three launch windows, one shrinking budget, and a public that stopped watching. Success brings grants and approval. Failure brings a review - and reviewers are cheaper than rockets.",
	},
	{
		"card": "MISSION DESIGN", "expr": "neutral",
		"text": "First, build the mission: hull, launch vehicle, orbit, two instruments. Mass, power and delta-v are not decoration. A fantasy flight plan fails on the pad, not on the planet.",
	},
	{
		"card": "TARGET DRAFT", "expr": "neutral",
		"text": "Then choose a target. Safe worlds are forgiving. Harsh worlds pay more science and more grants, but they will find every weakness in the hardware you can afford.",
	},
	{
		"card": "SURFACE", "expr": "stern",
		"text": "On the surface, data is funding. Move carefully, watch heat and power, and extract before the window closes. HOLD is not cowardice; it is thermal management.",
	},
	{
		"card": "REFIT", "expr": "smile",
		"text": "Back here, spend grants on refits, then claim your field commission. Build for the next planet, not the last one. The agency remembers both.",
	},
	{
		"card": "SEND-OFF", "expr": "smile",
		"text": "That's the job, Chief. Make the agency matter. I'll be on comms.",
	},
]

const PAPER := Color("#e8dfc8")
const INK := Color("#1b1a17")
const ORANGE := Color("#e4572e")
const SIGNAL := Color("#b8332f")
const NIGHT := Color("#101826")
const TEAL := Color("#5f8f8a")
const SHIP_DIR := "res://assets/sprites/crew/"

var beat := 0
var revealed := 0
var first_run := true
var finished := false
var portrait: TextureRect
var body: Label
var nameplate: Label
var card_label: Label
var progress: Label
var next_btn: Button
var skip_btn: Button
var dialogue: Panel
var _textures := {}


func _ready() -> void:
	first_run = not GameState.briefing_seen
	_build()
	var cli: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for raw in cli:
		var arg := str(raw)
		if arg.begins_with("--briefing-beat="):
			beat = clampi(int(arg.substr(16)), 0, BEATS.size() - 1)
	_show_beat(true)


func _build() -> void:
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({
		"planet_center": Vector2(0.86, 0.44),
		"planet_size": 0.58,
		"planet_asset": "rocky",
		"dim": 0.68,
	})
	bg.modulate.a = 0.52

	var left_shade := ColorRect.new()
	left_shade.color = Color(0.02, 0.04, 0.07, 0.42)
	left_shade.position = Vector2(0, 0)
	left_shade.size = Vector2(170, 360)
	left_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_shade)

	var window_line := ColorRect.new()
	window_line.color = Color("#24384a")
	window_line.position = Vector2(170, 0)
	window_line.size = Vector2(1, 360)
	window_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window_line)

	var kicker := UIKit.label("AGENCY INDUCTION  //  CHIEF ENGINEER", 7, Color("#ffc45c"), true)
	kicker.position = Vector2(178, 18)
	kicker.size = Vector2(360, 10)
	add_child(kicker)

	progress = UIKit.label("01 / 07", 7, Color("#8ba0b6"), true, HORIZONTAL_ALIGNMENT_RIGHT)
	progress.position = Vector2(480, 18)
	progress.size = Vector2(142, 10)
	add_child(progress)

	skip_btn = _paper_button("SKIP  [ESC]", Vector2(92, 20), true)
	skip_btn.position = Vector2(530, 32)
	skip_btn.pressed.connect(_skip)
	add_child(skip_btn)

	var glow := ColorRect.new()
	glow.color = Color(0.33, 0.90, 0.82, 0.035)
	glow.position = Vector2(8, 22)
	glow.size = Vector2(160, 238)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	portrait = TextureRect.new()
	portrait.position = Vector2(8, 22)
	portrait.size = Vector2(160, 240)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)

	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.55)
	shadow.position = Vector2(169, 251)
	shadow.size = Vector2(466, 94)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shadow)

	var tab := Panel.new()
	tab.position = Vector2(166, 236)
	tab.size = Vector2(88, 18)
	tab.add_theme_stylebox_override("panel", _paper_style(ORANGE, INK, 1))
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tab)
	card_label = UIKit.label("01  INDUCTION", 6, PAPER, true, HORIZONTAL_ALIGNMENT_CENTER)
	card_label.position = Vector2(3, 3)
	card_label.size = Vector2(82, 12)
	tab.add_child(card_label)

	var tape := ColorRect.new()
	tape.color = Color(0.90, 0.70, 0.36, 0.34)
	tape.position = Vector2(360, 244)
	tape.size = Vector2(74, 7)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tape)

	dialogue = Panel.new()
	dialogue.position = Vector2(166, 248)
	dialogue.size = Vector2(466, 94)
	dialogue.add_theme_stylebox_override("panel", _paper_style(PAPER, INK, 1))
	dialogue.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue.gui_input.connect(_on_dialogue_input)
	add_child(dialogue)

	nameplate = UIKit.label("DR. IMANI VALE  //  DEPUTY DIRECTOR", 7, SIGNAL, true)
	nameplate.position = Vector2(12, 8)
	nameplate.size = Vector2(330, 14)
	dialogue.add_child(nameplate)

	body = UIKit.label("", 8, INK, false)
	body.position = Vector2(12, 27)
	body.size = Vector2(442, 42)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.add_theme_constant_override("line_spacing", 1)
	dialogue.add_child(body)

	var hint := UIKit.label("SPACE / CLICK TO CONTINUE", 5, TEAL, true)
	hint.position = Vector2(12, 74)
	hint.size = Vector2(220, 10)
	dialogue.add_child(hint)

	next_btn = _paper_button("NEXT  >", Vector2(78, 20), true)
	next_btn.position = Vector2(374, 68)
	next_btn.pressed.connect(_advance)
	dialogue.add_child(next_btn)


func _paper_style(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(1)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _paper_button(text: String, size: Vector2, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.size = size
	b.add_theme_font_override("font", UIKit.pixel_font)
	b.add_theme_font_size_override("font_size", 6)
	b.add_theme_color_override("font_color", PAPER if primary else INK)
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_stylebox_override("normal", _paper_style(ORANGE if primary else PAPER, INK, 1))
	b.add_theme_stylebox_override("hover", _paper_style(INK, INK, 1))
	b.add_theme_stylebox_override("pressed", _paper_style(SIGNAL, INK, 1))
	b.add_theme_stylebox_override("focus", _paper_style(ORANGE if primary else PAPER, INK, 2))
	return b


func _show_beat(instant: bool = false) -> void:
	var b: Dictionary = BEATS[beat]
	card_label.text = "%02d  %s" % [beat + 1, str(b.get("card", "BRIEFING"))]
	progress.text = "%02d / %02d" % [beat + 1, BEATS.size()]
	body.text = str(b.get("text", ""))
	revealed = body.text.length() if instant else 0
	body.visible_characters = revealed
	next_btn.text = "BEGIN  >" if beat == BEATS.size() - 1 and first_run else (
		"RETURN  >" if beat == BEATS.size() - 1 else "NEXT  >"
	)
	_set_portrait(str(b.get("expr", "neutral")))
	GameState.sfx("click")


func _set_portrait(expr: String) -> void:
	if not _textures.has(expr):
		var path := SHIP_DIR + "director_%s.png" % expr
		if not ResourceLoader.exists(path):
			path = SHIP_DIR + "director_neutral.png"
		_textures[expr] = load(path) if ResourceLoader.exists(path) else null
	portrait.texture = _textures[expr]


func _process(delta: float) -> void:
	if finished or body == null:
		return
	if revealed < body.text.length():
		revealed = mini(body.text.length(), revealed + int(delta * 48.0) + 1)
		body.visible_characters = revealed


func _on_dialogue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _advance() -> void:
	if finished:
		return
	if revealed < body.text.length():
		revealed = body.text.length()
		body.visible_characters = revealed
		GameState.sfx("click")
		return
	if beat < BEATS.size() - 1:
		beat += 1
		_show_beat()
	else:
		_finish()


func _skip() -> void:
	if finished:
		return
	finished = true
	GameState.mark_briefing_seen()
	GameState.sfx("click")
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _finish() -> void:
	if finished:
		return
	finished = true
	GameState.mark_briefing_seen()
	GameState.sfx("confirm")
	if first_run:
		CrewDirector.begin_run("campaign", 1, "standard")
		get_tree().change_scene_to_file("res://scenes/design.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_advance()
		KEY_ESCAPE, KEY_S:
			_skip()
