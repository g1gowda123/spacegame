extends Control
## Chief Engineer induction: a short, skippable story/tutorial briefing.
## Character left, paper dialogue card bottom. First run only; replay from the
## title. Text is data-driven so the beats can be tuned without touching layout.

const BEATS := [
	{
		"card": "INDUCTION", "expr": "smile",
		"text": "Chief. Good - you're early. I'm Dr. Imani Vale, the director's executive secretary. I keep the launch windows, the budget, and the director's calendar. The board just signed your appointment, and the press office is already asking for a quote.",
	},
	{
		"card": "THE AGENCY", "expr": "stern",
		"text": "The director will deny this, but the agency has three launch windows, one shrinking budget, and a public that stopped watching. Success brings grants and approval. Failure brings a review - and reviewers are cheaper than rockets.",
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
		"text": "On the surface, data is funding. Your radar only paints a short radius, so move to reveal the board; signals outside it are dark. Watch heat and power, and extract before the window closes. HOLD is not cowardice; it is thermal management.",
	},
	{
		"card": "REFIT", "expr": "smile",
		"text": "Back here, spend grants on refits, then claim your field commission. Build for the next planet, not the last one. The agency remembers both.",
	},
	{
		"card": "SEND-OFF", "expr": "smile",
		"text": "That's the job, Chief. Make the agency matter. I'll keep the comms line open.",
	},
]

const PAPER := Color("#0e1624")
const INK := Color("#e8eff7")
const ORANGE := Color("#54e6d1")
const SIGNAL := Color("#ff5d6c")
const NIGHT := Color("#070a11")
const TEAL := Color("#54e6d1")
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
var name_layer: Control
var name_edit: LineEdit
var _textures := {}


func _ready() -> void:
	first_run = not GameState.briefing_seen
	_build()
	var cli: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for raw in cli:
		var arg := str(raw)
		if arg.begins_with("--briefing-beat="):
			beat = clampi(int(arg.substr(16)), 0, BEATS.size() - 1)
		if arg.begins_with("--pilot-name="):
			GameState.set_player_name(arg.substr(13))
			if name_layer != null:
				name_layer.visible = false
	_show_beat(true)
	for raw in cli:
		var arg := str(raw)
		if arg == "--briefing-finish":
			call_deferred("_finish")
		elif arg == "--briefing-skip":
			call_deferred("_skip")


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

	var station := TextureRect.new()
	station.texture = load("res://assets/backgrounds/briefing_station.png")
	station.position = Vector2.ZERO
	station.size = Vector2(640, 360)
	station.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	station.stretch_mode = TextureRect.STRETCH_SCALE
	station.mouse_filter = Control.MOUSE_FILTER_IGNORE
	station.modulate.a = 0.8
	add_child(station)

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

	var portrait_card := Panel.new()
	portrait_card.position = Vector2(3, 12)
	portrait_card.size = Vector2(170, 250)
	portrait_card.add_theme_stylebox_override("panel", _paper_style(Color("#e8dfc8"), INK, 1))
	portrait_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_card)

	var card_code := UIKit.label("PERSONNEL FILE // VALE", 5, Color("#4a4438"), true)
	card_code.position = Vector2(8, 238)
	card_code.size = Vector2(154, 9)
	card_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(card_code)

	var photo_back := Panel.new()
	photo_back.position = Vector2(10, 20)
	photo_back.size = Vector2(152, 152)
	photo_back.add_theme_stylebox_override("panel", _paper_style(Color("#d8c9ab"), Color("#1b1a17"), 1))
	photo_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(photo_back)

	portrait = TextureRect.new()
	portrait.position = Vector2(13, 23)
	portrait.size = Vector2(146, 146)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.modulate = Color(1.06, 1.04, 1.0)
	add_child(portrait)

	var id_name := UIKit.label("DR. IMANI VALE", 6, Color("#1b1a17"), true)
	id_name.position = Vector2(12, 180)
	id_name.size = Vector2(146, 9)
	id_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(id_name)

	var id_role := UIKit.label("EXECUTIVE SECRETARY", 5, Color("#4a4438"), true)
	id_role.position = Vector2(12, 191)
	id_role.size = Vector2(146, 8)
	id_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(id_role)

	var id_clear := UIKit.label("CLEARANCE  A-2  ·  MISSION CONTROL", 4, Color("#6b5f4c"), true)
	id_clear.position = Vector2(12, 202)
	id_clear.size = Vector2(146, 8)
	id_clear.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(id_clear)

	var photo_tape := TextureRect.new()
	photo_tape.texture = load("res://assets/ui/skin/tape_masking.png")
	photo_tape.position = Vector2(35, 5)
	photo_tape.size = Vector2(104, 14)
	photo_tape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo_tape.stretch_mode = TextureRect.STRETCH_SCALE
	photo_tape.modulate = Color(1, 1, 1, 0.75)
	photo_tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(photo_tape)

	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.55)
	shadow.position = Vector2(169, 251)
	shadow.size = Vector2(466, 94)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shadow)

	var tab := Panel.new()
	tab.position = Vector2(166, 228)
	tab.size = Vector2(104, 20)
	tab.add_theme_stylebox_override("panel", _paper_style(ORANGE, INK, 1))
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.z_index = 5
	add_child(tab)
	card_label = UIKit.label("01  INDUCTION", 6, NIGHT, true, HORIZONTAL_ALIGNMENT_CENTER)
	card_label.position = Vector2(3, 4)
	card_label.size = Vector2(98, 12)
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

	var paper_tex := TextureRect.new()
	paper_tex.texture = load("res://assets/ui/skin/paper_texture.png")
	paper_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper_tex.stretch_mode = TextureRect.STRETCH_TILE
	paper_tex.modulate = Color(1, 1, 1, 0.18)
	paper_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue.add_child(paper_tex)

	var barcode := TextureRect.new()
	barcode.texture = load("res://assets/ui/skin/barcode_strip.png")
	barcode.position = Vector2(392, 80)
	barcode.size = Vector2(64, 9)
	barcode.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	barcode.stretch_mode = TextureRect.STRETCH_SCALE
	barcode.modulate = Color(0.15, 0.14, 0.12, 0.55)
	barcode.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue.add_child(barcode)

	nameplate = UIKit.label("DR. IMANI VALE  //  EXECUTIVE SECRETARY", 7, SIGNAL, true)
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

	var hint := UIKit.mono("SPACE / CLICK TO CONTINUE", 7, TEAL)
	hint.position = Vector2(12, 72)
	hint.size = Vector2(220, 14)
	dialogue.add_child(hint)

	next_btn = _paper_button("NEXT  >", Vector2(78, 20), true)
	next_btn.position = Vector2(374, 68)
	next_btn.pressed.connect(_advance)
	dialogue.add_child(next_btn)

	if first_run and not GameState.has_player_name():
		_build_name_prompt()


func _build_name_prompt() -> void:
	name_layer = Control.new()
	name_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	name_layer.z_index = 30
	add_child(name_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	name_layer.add_child(shade)

	var sheet_shadow := ColorRect.new()
	sheet_shadow.color = Color(0.04, 0.04, 0.03, 0.55)
	sheet_shadow.position = Vector2(116, 88)
	sheet_shadow.size = Vector2(420, 192)
	sheet_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_layer.add_child(sheet_shadow)

	var sheet := Panel.new()
	sheet.position = Vector2(110, 82)
	sheet.size = Vector2(420, 192)
	sheet.add_theme_stylebox_override("panel", _paper_style(PAPER, INK, 1))
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	name_layer.add_child(sheet)

	var tape := TextureRect.new()
	tape.texture = load("res://assets/ui/skin/tape_masking.png")
	tape.position = Vector2(168, 72)
	tape.size = Vector2(120, 16)
	tape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tape.stretch_mode = TextureRect.STRETCH_SCALE
	tape.modulate = Color(1, 1, 1, 0.8)
	name_layer.add_child(tape)

	var kicker := UIKit.label("AGENCY PERSONNEL  //  CALLSIGN", 7, ORANGE, true)
	kicker.position = Vector2(18, 18)
	kicker.size = Vector2(384, 10)
	sheet.add_child(kicker)

	var title := UIKit.label("Before I file your appointment.", 10, INK, true)
	title.position = Vector2(18, 34)
	title.size = Vector2(384, 14)
	sheet.add_child(title)

	var copy := UIKit.label(
		"What should the agency call you, Chief?",
		7, UIKit.MUTED, false
	)
	copy.position = Vector2(18, 54)
	copy.size = Vector2(380, 12)
	sheet.add_child(copy)

	name_edit = LineEdit.new()
	name_edit.position = Vector2(18, 74)
	name_edit.size = Vector2(250, 26)
	name_edit.max_length = 12
	name_edit.placeholder_text = "CHIEF"
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_font_override("font", UIKit.pixel_font)
	name_edit.add_theme_font_size_override("font_size", 9)
	name_edit.add_theme_color_override("font_color", Color("#1b1a17"))
	name_edit.add_theme_color_override("font_placeholder_color", Color(0.35, 0.32, 0.27, 0.6))
	name_edit.add_theme_color_override("caret_color", ORANGE)
	name_edit.add_theme_stylebox_override("normal", _paper_style(Color("#f2ead6"), INK, 1))
	name_edit.add_theme_stylebox_override("focus", _paper_style(Color("#fff8e6"), ORANGE, 2))
	name_edit.text_submitted.connect(func(_t): _submit_name())
	sheet.add_child(name_edit)

	var submit := _paper_button("FILE APPOINTMENT  >", Vector2(164, 24), true)
	submit.position = Vector2(18, 110)
	submit.pressed.connect(_submit_name)
	sheet.add_child(submit)

	var hint := UIKit.mono("THIS NAME GOES ON THE MISSION RECORD AND THE HONOURS BOARD.",
		6, Color("#4a4438"))
	hint.position = Vector2(18, 146)
	hint.size = Vector2(384, 9)
	sheet.add_child(hint)
	var key_hint := UIKit.mono("ENTER TO FILE  ·  ESC TO USE 'CHIEF'", 6, Color("#6b5f4c"))
	key_hint.position = Vector2(18, 160)
	key_hint.size = Vector2(384, 9)
	sheet.add_child(key_hint)

	name_edit.call_deferred("grab_focus")


func _submit_name() -> void:
	if name_layer == null or not name_layer.visible:
		return
	GameState.set_player_name(name_edit.text if name_edit != null else "")
	name_layer.visible = false
	GameState.sfx("confirm")


func _dismiss_name() -> void:
	if name_layer == null or not name_layer.visible:
		return
	GameState.set_player_name("CHIEF")
	name_layer.visible = false
	GameState.sfx("click")


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
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			# The delivered seed-4101 bust occupies a 134x134 square inside the
			# 160x240 canvas; crop to the visible alpha box so it reads as an ID
			# photo. If VEGA lands a full-height bust, keep the whole frame.
			var img := tex.get_image()
			if img != null:
				var used := img.get_used_rect()
				if used.size.x > 0 and used.size.y > 0 \
						and used.size.x <= 180 and used.size.y <= 180:
					atlas.region = used
			_textures[expr] = atlas
		else:
			_textures[expr] = null
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
	if finished or (name_layer != null and name_layer.visible):
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
	if name_layer != null and name_layer.visible:
		GameState.set_player_name("CHIEF")
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
	if name_layer != null and name_layer.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				_submit_name()
			elif event.keycode == KEY_ESCAPE:
				_dismiss_name()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_advance()
		KEY_ESCAPE, KEY_S:
			_skip()
