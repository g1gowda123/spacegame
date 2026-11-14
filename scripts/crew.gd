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
var approval_label: Label
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
	var header := UIKit.head("MISSION CONTROL", 12, UIKit.TEXT)
	header.position = Vector2(10, 6)
	add_child(header)
	var step := UIKit.mono("CREW MANIFEST  ·  DIFFICULTY  ·  CAMPAIGN SEED", 7, UIKit.DIM)
	step.position = Vector2(10, 22)
	add_child(step)

	budget_label = UIKit.head("", 10, UIKit.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	budget_label.position = Vector2(480, 5)
	budget_label.size = Vector2(140, 15)
	add_child(budget_label)
	approval_label = UIKit.mono("", 7, UIKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	approval_label.position = Vector2(480, 20)
	approval_label.size = Vector2(140, 12)
	add_child(approval_label)
	UIKit.hairline(self, 10, 36, 620)

	_build_left()
	_build_right()
	_build_footer()


func _build_left() -> void:
	var p := _panel(10, 39, 190, 282)
	var c := UIKit.fill(p)

	c.add_child(_label_at("MISSION TYPE", Vector2(10, 0), 8, UIKit.MUTED))
	var campaign := UIKit.option_card(c, Rect2(10, 20, 82, 22), "CAMPAIGN", "", UIKit.CYAN, 9, 7, "", false)
	campaign["button"].pressed.connect(_set_mode.bind("campaign"))
	mode_cards["campaign"] = campaign
	var daily := UIKit.option_card(c, Rect2(98, 20, 82, 22), "DAILY", "", UIKit.CYAN, 9, 7, "", false)
	daily["button"].pressed.connect(_set_mode.bind("daily"))
	mode_cards["daily"] = daily

	c.add_child(_label_at("CREW SIZE", Vector2(10, 50), 8, UIKit.MUTED))
	for i in range(4):
		var n := i + 1
		var card := UIKit.option_card(
			c, Rect2(10 + i * 44, 70, 40, 22), str(n), "", UIKit.CYAN, 10, 7
		)
		card["button"].pressed.connect(_set_players.bind(n))
		size_cards[n] = card
	mode_note = UIKit.mono("2-4 players share one console. 1 is solo.", 7, UIKit.DIM)
	mode_note.position = Vector2(10, 96)
	mode_note.size = Vector2(174, 12)
	c.add_child(mode_note)

	c.add_child(_label_at("DIFFICULTY", Vector2(10, 114), 8, UIKit.MUTED))
	for i in range(3):
		var id: String = ["cadet", "standard", "director"][i]
		var d: Dictionary = CrewDirector.DIFFICULTIES[id]
		var card := UIKit.option_card(
			c, Rect2(10, 132 + i * 42, 170, 40),
			str(d["name"]), str(d["short"]), Color(str(d["color"])), 9, 7
		)
		card["button"].pressed.connect(_set_difficulty.bind(id))
		diff_cards[id] = card

	var buffs := UIKit.mono("BUFFS ON  ·  GOALS +180", 6, UIKit.DIM)
	buffs.position = Vector2(10, 262)
	c.add_child(buffs)


func _build_right() -> void:
	var p := _panel(208, 39, 422, 282)
	var c := UIKit.fill(p)

	c.add_child(_label_at("CREW MANIFEST", Vector2(12, 0), 8, UIKit.MUTED))
	UIKit.hairline(c, 12, 198, 398)

	roster_root = Control.new()
	roster_root.position = Vector2(12, 24)
	roster_root.size = Vector2(398, 150)
	roster_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(roster_root)

	c.add_child(_label_at("CAMPAIGN CODE", Vector2(12, 208), 8, UIKit.MUTED))
	var code_hint := UIKit.mono("SEED OR FULL DESIGN", 7, UIKit.DIM)
	code_hint.position = Vector2(120, 209)
	c.add_child(code_hint)
	code_edit = LineEdit.new()
	code_edit.position = Vector2(12, 226)
	code_edit.size = Vector2(286, 20)
	code_edit.placeholder_text = "OO-0F7A5-S1-PAVMOLOA-SPTH"
	code_edit.max_length = 32
	code_edit.add_theme_font_override("font", UIKit.body_font)
	code_edit.add_theme_font_size_override("font_size", 8)
	code_edit.add_theme_color_override("font_color", UIKit.TEXT)
	code_edit.add_theme_color_override("font_placeholder_color", UIKit.DIM)
	code_edit.add_theme_stylebox_override("normal", UIKit.style_panel(Color("#0a1220"), UIKit.LINE, 2))
	code_edit.add_theme_stylebox_override("focus", UIKit.style_panel(Color("#0c1726"), UIKit.CYAN, 2))
	code_edit.text_submitted.connect(func(_t: String): _apply_code())
	c.add_child(code_edit)
	var apply := UIKit.button("APPLY", Vector2(56, 20))
	apply.position = Vector2(304, 226)
	apply.pressed.connect(_apply_code)
	code_apply_btn = apply
	c.add_child(apply)
	code_status = UIKit.mono("PASTE A CODE TO FLY SOMEONE ELSE'S WORLDS.", 6, UIKit.DIM)
	code_status.position = Vector2(12, 250)
	code_status.size = Vector2(398, 12)
	c.add_child(code_status)


func _build_footer() -> void:
	UIKit.hairline(self, 10, 325, 620)
	var back := UIKit.button("< BACK", Vector2(72, 24))
	back.position = Vector2(10, 330)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	add_child(back)

	var note := UIKit.mono(
		"Hot-seat co-op: every role owns a different metric, and the goals conflict.",
		7, UIKit.DIM
	)
	note.position = Vector2(92, 336)
	add_child(note)

	start_btn = UIKit.button("BEGIN CAMPAIGN >", Vector2(196, 26), true)
	start_btn.position = Vector2(414, 329)
	start_btn.pressed.connect(_start)
	add_child(start_btn)


func _panel(x: float, y: float, w: float, h: float,
		bg: Color = Color("#0b1522"), border: Color = UIKit.SHEET_LINE,
		parent: Node = null) -> PanelContainer:
	return UIKit.sheet(parent if parent != null else self, x, y, w, h)


func _label_at(text: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := UIKit.mono(text, size, color)
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
	budget_label.text = "START $%dM" % int(budget)
	approval_label.text = "APPROVAL %d" % approval
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
	var cell_w := 398.0 if cols == 1 else 195.0
	var col := idx % cols
	var line_no := int(idx / cols)
	var x := float(col) * (cell_w + 8.0)
	var y := float(line_no) * 66.0
	var color := Color(TEAM_COLORS[idx % TEAM_COLORS.size()])
	var bg := Panel.new()
	bg.position = Vector2(x, y)
	bg.size = Vector2(cell_w, 60)
	bg.add_theme_stylebox_override("panel", UIKit.row_style(false, false, color))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roster_root.add_child(bg)
	# Left role-colour marker, the same grammar as selected rows elsewhere.
	var marker := ColorRect.new()
	marker.color = color
	marker.position = Vector2(0, 0)
	marker.size = Vector2(2, 60)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(marker)

	var nm := UIKit.head(str(row["name"]), 8, color)
	nm.position = Vector2(10, 4)
	nm.size = Vector2(120, 12)
	bg.add_child(nm)
	if row.has("shorts"):
		var sh := UIKit.mono(str(row["shorts"]), 7, color, HORIZONTAL_ALIGNMENT_RIGHT)
		sh.position = Vector2(130, 5)
		sh.size = Vector2(cell_w - 140, 12)
		bg.add_child(sh)
	var line := UIKit.mono(str(row["line"]), 7, UIKit.MUTED)
	line.position = Vector2(10, 20)
	line.size = Vector2(cell_w - 20, 38)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	line.add_theme_constant_override("line_spacing", 0)
	bg.add_child(line)


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
