extends Control
## Mission Control: crew size, difficulty tier, daily challenge and campaign
## code entry. Sits between the title and mission design.

const TEAM_COLORS := ["#54e6d1", "#ffc45c", "#7fe08a", "#b692ff"]

var mode := "campaign"
var players := 2
var difficulty := "standard"
var code_seed := 0
var code_loadout: Dictionary = {}

var mode_cards: Dictionary = {}
var size_cards: Dictionary = {}
var diff_cards: Dictionary = {}
var roster_root: Control
var code_edit: LineEdit
var code_apply_btn: Button
var code_status: Label
var budget_label: Label
var start_btn: Button
var mode_note: Label


func _ready() -> void:
	# Development hooks for screenshots and QA.
	for raw in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var arg := str(raw)
		if arg.begins_with("--players="):
			players = clampi(int(arg.substr(10)), 1, 4)
		elif arg.begins_with("--difficulty="):
			difficulty = arg.substr(13)
		elif arg.begins_with("--mode="):
			mode = arg.substr(7)
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({"planet_on": false, "dim": 0.48})
	_build()
	_refresh()


func _build() -> void:
	var header := UIKit.label("MISSION CONTROL  //  00", 13, UIKit.CYAN, true)
	header.position = Vector2(10, 7)
	add_child(header)
	var step := UIKit.label("CREW MANIFEST  ·  DIFFICULTY  ·  CAMPAIGN SEED", 7, UIKit.DIM, true)
	step.position = Vector2(10, 23)
	add_child(step)

	budget_label = UIKit.label("", 9, UIKit.AMBER, true, HORIZONTAL_ALIGNMENT_RIGHT)
	budget_label.position = Vector2(420, 8)
	budget_label.size = Vector2(210, 12)
	add_child(budget_label)

	_build_left()
	_build_right()
	_build_footer()


func _build_left() -> void:
	var p := _panel(10, 40, 190, 276)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)

	c.add_child(_label_at("MISSION TYPE", Vector2(8, 0), 7, UIKit.CYAN))
	var campaign := UIKit.option_card(c, Rect2(8, 23, 84, 22), "CAMPAIGN", "", UIKit.CYAN, 7, 6)
	campaign["button"].pressed.connect(_set_mode.bind("campaign"))
	mode_cards["campaign"] = campaign
	var daily := UIKit.option_card(c, Rect2(98, 23, 84, 22), "DAILY", "", UIKit.AMBER, 7, 6)
	daily["button"].pressed.connect(_set_mode.bind("daily"))
	mode_cards["daily"] = daily

	c.add_child(_label_at("CREW SIZE", Vector2(8, 47), 7, UIKit.CYAN))
	for i in range(4):
		var n := i + 1
		var card := UIKit.option_card(
			c, Rect2(8 + i * 44, 69, 40, 22), str(n), "", UIKit.CYAN, 10, 6
		)
		card["button"].pressed.connect(_set_players.bind(n))
		size_cards[n] = card
	mode_note = UIKit.label("2-4 players share one console. 1 is solo.", 6, UIKit.DIM, false)
	mode_note.position = Vector2(8, 93)
	mode_note.size = Vector2(174, 10)
	c.add_child(mode_note)

	c.add_child(_label_at("DIFFICULTY", Vector2(8, 106), 7, UIKit.CYAN))
	for i in range(3):
		var id: String = ["cadet", "standard", "director"][i]
		var d: Dictionary = CrewDirector.DIFFICULTIES[id]
		var card := UIKit.option_card(
			c, Rect2(8, 128 + i * 38, 174, 34),
			str(d["name"]), str(d["short"]), Color(str(d["color"])), 8, 6
		)
		card["button"].pressed.connect(_set_difficulty.bind(id))
		diff_cards[id] = card

	c.add_child(_label_at(
		"BUFFS ON  ·  GOALS +180",
		Vector2(8, 240), 6, UIKit.DIM
	))


func _build_right() -> void:
	var p := _panel(208, 40, 422, 276)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)

	c.add_child(_label_at("CREW MANIFEST  ·  FOUR ROLES, FOUR METRICS  ·  NEGOTIATE", Vector2(10, 0), 8, UIKit.AMBER))
	roster_root = Control.new()
	roster_root.position = Vector2(10, 26)
	roster_root.size = Vector2(402, 168)
	roster_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(roster_root)

	c.add_child(_label_at("CAMPAIGN CODE  ·  SEED OR FULL DESIGN", Vector2(10, 196), 6, UIKit.CYAN))
	code_edit = LineEdit.new()
	code_edit.position = Vector2(10, 218)
	code_edit.size = Vector2(240, 20)
	code_edit.placeholder_text = "OO-0F7A5-S1-PAVMOLOA-SPTH"
	code_edit.max_length = 32
	code_edit.add_theme_font_size_override("font_size", 8)
	code_edit.add_theme_color_override("font_color", UIKit.TEXT)
	code_edit.add_theme_color_override("font_placeholder_color", UIKit.DIM)
	code_edit.add_theme_stylebox_override("normal", UIKit.style_panel(Color("#0a1220"), UIKit.LINE, 2))
	code_edit.add_theme_stylebox_override("focus", UIKit.style_panel(Color("#0c1726"), UIKit.CYAN, 2))
	code_edit.text_submitted.connect(func(_t: String): _apply_code())
	c.add_child(code_edit)
	var apply := UIKit.button("APPLY", Vector2(58, 20))
	apply.position = Vector2(256, 218)
	apply.pressed.connect(_apply_code)
	code_apply_btn = apply
	c.add_child(apply)
	code_status = UIKit.label("PASTE A CODE TO FLY SOMEONE ELSE'S WORLDS.", 6, UIKit.DIM, false)
	code_status.position = Vector2(10, 242)
	code_status.size = Vector2(380, 10)
	c.add_child(code_status)



func _build_footer() -> void:
	var back := UIKit.button("< BACK", Vector2(72, 24))
	back.position = Vector2(10, 324)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	add_child(back)

	var note := UIKit.label(
		"THE BRIEF: design, launch, manage and simulate a complete mission. Every modifier above is explained in-game.",
		6, UIKit.DIM, false
	)
	note.position = Vector2(92, 330)
	note.size = Vector2(300, 12)
	add_child(note)

	start_btn = UIKit.button("BEGIN MISSION >", Vector2(206, 26), true)
	start_btn.position = Vector2(404, 322)
	start_btn.pressed.connect(_start)
	add_child(start_btn)


func _panel(x: float, y: float, w: float, h: float,
		bg: Color = Color("#0c1421"), border: Color = UIKit.LINE,
		parent: Node = null) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UIKit.style_panel(bg, border, 3)
	st.content_margin_left = 0
	st.content_margin_right = 0
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", st)
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.custom_minimum_size = Vector2(w, h)
	if parent == null:
		parent = self
	parent.add_child(p)
	return p


func _label_at(text: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := UIKit.label(text, size, color, size <= 7)
	l.position = pos
	l.size = Vector2(400, 12)
	return l


func _set_mode(id: String) -> void:
	mode = id
	if mode == "daily":
		players = 1
		difficulty = "standard"
		code_seed = 0
		code_loadout = {}
		code_status.text = "DAILY RUN USES TODAY'S FIXED SEED."
	GameState.sfx("click")
	_refresh()


func _set_players(n: int) -> void:
	if mode == "daily":
		return
	players = clampi(n, 1, 4)
	GameState.sfx("click")
	_refresh()


func _set_difficulty(id: String) -> void:
	if mode == "daily":
		return
	difficulty = id
	GameState.sfx("click")
	_refresh()


func _apply_code() -> void:
	var parsed := CrewDirector.parse_code(code_edit.text)
	if parsed.is_empty():
		code_status.text = "INVALID CODE  ·  EXPECTED OO-XXXXX-S1"
		code_status.add_theme_color_override("font_color", UIKit.RED)
		GameState.sfx("alarm")
		return
	code_seed = int(parsed["seed"])
	mode = "campaign"
	players = int(parsed["players"])
	difficulty = str(parsed["difficulty"])
	code_loadout = parsed.get("loadout", {})
	var design_note := "  ·  DESIGN IMPORTED" if not code_loadout.is_empty() else ""
	code_status.text = "CODE LOCKED  ·  SEED %05X  ·  %s  ·  %d PLAYER%s%s" % [
		code_seed, str(CrewDirector.DIFFICULTIES[difficulty]["name"]), players,
		"" if players == 1 else "S", design_note
	]
	code_status.add_theme_color_override("font_color", UIKit.GREEN)
	GameState.sfx("confirm")
	_refresh()


func _refresh() -> void:
	for id in mode_cards:
		UIKit.select_card(mode_cards[id], mode == id)
	for n in size_cards:
		UIKit.select_card(size_cards[n], players == int(n))
		size_cards[n]["button"].disabled = mode == "daily"
		size_cards[n]["root"].modulate = Color(1, 1, 1, 0.35) if mode == "daily" else Color.WHITE
	for id in diff_cards:
		UIKit.select_card(diff_cards[id], difficulty == id)
		diff_cards[id]["button"].disabled = mode == "daily"
		diff_cards[id]["root"].modulate = Color(1, 1, 1, 0.35) if mode == "daily" else Color.WHITE

	var d: Dictionary = CrewDirector.DIFFICULTIES[difficulty]
	var budget := GameState.START_BUDGET + float(d["budget"])
	var approval := clampi(GameState.START_APPROVAL + int(d["approval"]), 1, 100)
	budget_label.text = "START  $%dM  ·  APPROVAL %d" % [int(budget), approval]
	mode_note.text = "2-4 players share one console. 1 is solo." if mode == "campaign" else "Daily: one fixed seed for everyone today."
	start_btn.text = "START DAILY RUN >" if mode == "daily" else "BEGIN CAMPAIGN >"
	if code_edit != null:
		code_edit.editable = mode != "daily"
		code_edit.modulate.a = 0.4 if mode == "daily" else 1.0
	if code_apply_btn != null:
		code_apply_btn.disabled = mode == "daily"

	_build_roster()


func _build_roster() -> void:
	if roster_root == null:
		return
	for child in roster_root.get_children():
		child.queue_free()
	if players <= 1:
		_add_row(0, {
			"name": "SOLO FLIGHT",
			"line": "You own every decision. No role buffs, no role goals.\nDifficulty still changes budget, approval, hazards and score.",
		}, 1)
		return
	var sets: Array = CrewDirector.ROLE_SETS.get(players, [])
	var cols := 1 if players <= 2 else 2
	for i in range(sets.size()):
		var role_ids: Array = sets[i]
		var buffs: Array = []
		var goals: Array = []
		var shorts: Array = []
		for rid in role_ids:
			var role: Dictionary = CrewDirector.ROLES[rid]
			buffs.append(str(role["buff"]))
			goals.append("%s: %s" % [str(role["short"]), str(role["goal_short"])])
			shorts.append(str(role["short"]))
		_add_row(i, {
			"name": "PLAYER %d" % (i + 1),
			"roles": role_ids,
			"line": "  ".join(buffs) + "\nGOAL  " + "  ·  ".join(goals),
			"shorts": " + ".join(shorts),
		}, cols)


func _add_row(idx: int, row: Dictionary, cols: int = 1) -> void:
	var cell_w := 402.0 if cols == 1 else 197.0
	var col := idx % cols
	var line_no := int(idx / cols)
	var x := float(col) * (cell_w + 8.0)
	var y := float(line_no) * 84.0
	var p := _panel(x, y, cell_w, 80, Color("#0a1220"), Color("#22354d"), roster_root)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)

	var color := Color(TEAM_COLORS[idx % TEAM_COLORS.size()])
	var nm := UIKit.label(str(row["name"]), 7, color, true)
	nm.position = Vector2(8, 2)
	nm.size = Vector2(150, 20)
	c.add_child(nm)
	if row.has("shorts"):
		var sh := UIKit.label(str(row["shorts"]), 6, color, true, HORIZONTAL_ALIGNMENT_RIGHT)
		sh.position = Vector2(120, 3)
		sh.size = Vector2(cell_w - 128, 18)
		c.add_child(sh)
	var line := UIKit.label(str(row["line"]), 6, UIKit.MUTED, false)
	line.position = Vector2(8, 24)
	line.size = Vector2(cell_w - 16, 50)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	line.add_theme_constant_override("line_spacing", -2)
	c.add_child(line)


func _start() -> void:
	CrewDirector.begin_run(mode, players, difficulty, code_seed, code_loadout)
	GameState.sfx("confirm")
	get_tree().change_scene_to_file("res://scenes/design.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		elif event.keycode == KEY_ENTER:
			_start()
