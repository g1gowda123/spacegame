extends Control

var cards: Array = []
var selected_id := ""
var confirm_btn: Button
var detail_label: Label
var objective_label: Label
var selected_planet: Dictionary = {}


func _ready() -> void:
	if GameState.draft.is_empty():
		GameState.roll_draft()
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({"planet_on": false, "dim": 0.38})
	_build()
	_select_first()
	_refresh()


func _build() -> void:
	var header := UIKit.label("DESTINATION DRAFT  //  %02d" % int(GameState.run.get("sector", 1)), 13, UIKit.CYAN, true)
	header.position = Vector2(10, 7)
	add_child(header)
	var step := UIKit.label("SECTOR 1 OF 3  ·  CHOOSE A REAL EXOPLANET", 7, UIKit.DIM, true)
	step.position = Vector2(10, 24)
	add_child(step)

	var src := UIKit.label("NASA EXOPLANET ARCHIVE  ·  PSCompPars", 7, UIKit.DIM, true)
	src.position = Vector2(10, 33)
	add_child(src)

	var budget := UIKit.label("GRANTS  $%dM" % int(GameState.run.get("budget", 0)), 10, UIKit.AMBER, true)
	budget.position = Vector2(500, 8)
	budget.size = Vector2(130, 14)
	budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(budget)

	var appr := UIKit.label("APPROVAL  %d" % int(GameState.run.get("approval", 0)), 7, UIKit.MUTED, true)
	appr.position = Vector2(392, 25)
	appr.size = Vector2(238, 12)
	appr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(appr)



	for i in range(mini(3, GameState.draft.size())):
		_make_card(GameState.draft[i], i)
	_build_footer()


func _make_card(p: Dictionary, idx: int) -> void:
	var x := 10.0 + float(idx) * 208.0
	var root := Control.new()
	root.position = Vector2(x, 44)
	root.size = Vector2(196, 236)
	add_child(root)

	var panel := UIKit.panel(Color("#0d1624"), UIKit.LINE)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)

	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(c)

	# Planet portrait.
	var holder := Control.new()
	holder.position = Vector2(52, 2)
	holder.size = Vector2(92, 72)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(holder)
	var portrait := SpaceBackdrop.new()
	holder.add_child(portrait)
	portrait.configure({
		"stars_on": false,
		"planet_center": Vector2(0.5, 0.5),
		"planet_size": 0.94,
		"planet_asset": SpaceBackdrop.asset_for_planet(p),
	})

	var name := UIKit.label(str(p["name"]), 9, UIKit.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	name.position = Vector2(4, 72)
	name.size = Vector2(188, 13)
	c.add_child(name)

	var star_type := str(p.get("star_type", "")).strip_edges()
	if star_type == "" or star_type == "—":
		star_type = "UNKNOWN TYPE"
	var meta := UIKit.label(
		"%s  ·  %.1f ly" % [star_type, float(p["distance_ly"])],
		6, UIKit.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER
	)
	meta.position = Vector2(4, 87)
	meta.size = Vector2(188, 10)
	c.add_child(meta)

	var chip1 := UIKit.chip(GameState.biome_name(str(p["biome"])), GameState.biome_color(str(p["biome"])))
	chip1.position = Vector2(9, 101)
	chip1.size = Vector2(84, 14)
	c.add_child(chip1)
	var chip2 := UIKit.chip("%d K" % int(p["eq_temp_k"]), UIKit.AMBER)
	chip2.position = Vector2(98, 101)
	chip2.size = Vector2(52, 14)
	c.add_child(chip2)
	if bool(p.get("mass_est", false)):
		var chip3 := UIKit.chip("EST", UIKit.DIM)
		chip3.position = Vector2(154, 101)
		chip3.size = Vector2(34, 14)
		c.add_child(chip3)

	var g: Dictionary = p["game"]
	_stat(c, 132, "THERMAL LOAD", "%d" % int(g["heat"]), float(g["heat"]) / 100.0,
		UIKit.RED if int(g["heat"]) > 60 else UIKit.AMBER)
	_stat(c, 147, "RADIATION", "%d" % int(g["radiation"]), float(g["radiation"]) / 100.0,
		UIKit.AMBER if int(g["radiation"]) > 40 else UIKit.GREEN)
	_stat(c, 162, "GRAVITY", "%.2fg" % float(p["gravity_g"]), float(p["gravity_g"]) / 3.0,
		UIKit.BLUE)
	_stat(c, 177, "COMMS LOSS", "-%d%%" % int(g["comms_loss"]), 1.0 - float(g["comms_loss"]) / 30.0,
		UIKit.GREEN if int(g["comms_loss"]) <= 10 else UIKit.AMBER)
	_stat(c, 192, "SCIENCE", "%d" % int(g["science"]), float(g["science"]) / 120.0,
		UIKit.CYAN)

	var pick := UIKit.button("SELECT TARGET", Vector2(176, 20), false)
	pick.position = Vector2(10, 210)
	pick.pressed.connect(_select.bind(str(p["id"])))
	c.add_child(pick)

	var overlay := Button.new()
	overlay.flat = true
	overlay.focus_mode = Control.FOCUS_NONE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		overlay.add_theme_stylebox_override(s, empty)
	root.add_child(overlay)
	overlay.mouse_entered.connect(func(): _hover(root, panel, true))
	overlay.mouse_exited.connect(func(): _hover(root, panel, false))

	var card := {
		"id": str(p["id"]), "planet": p, "root": root, "panel": panel,
		"title": name, "accent": GameState.biome_color(str(p["biome"])),
		"selected": false,
	}
	cards.append(card)


func _hover(root: Control, panel: PanelContainer, on: bool) -> void:
	var selected := false
	for c in cards:
		if c["root"] == root:
			selected = bool(c["selected"])
	if selected:
		return
	panel.add_theme_stylebox_override("panel", UIKit.style_panel(
		UIKit.PANEL_3 if on else Color("#0d1624"),
		Color("#3b5370") if on else UIKit.LINE, 3
	))


func _stat(c: Control, y: float, name: String, value: String, frac: float, color: Color) -> void:
	var l := UIKit.label(name, 6, UIKit.DIM, true)
	l.position = Vector2(10, y)
	l.size = Vector2(74, 12)
	c.add_child(l)
	var bar := UIKit.bar(52, 5, color)
	bar.position = Vector2(86, y + 3)
	c.add_child(bar)
	UIKit.set_bar(bar, clampf(frac, 0.0, 1.0) * 100.0, 100.0)
	var v := UIKit.label(value, 7, UIKit.TEXT, false, HORIZONTAL_ALIGNMENT_RIGHT)
	v.position = Vector2(142, y)
	v.size = Vector2(44, 12)
	c.add_child(v)


func _build_footer() -> void:
	var p := UIKit.panel(Color("#0b1320"), Color("#24344a"))
	p.position = Vector2(10, 282)
	p.size = Vector2(620, 72)
	add_child(p)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(c)

	objective_label = UIKit.label("OBJECTIVE  ·  ...", 7, UIKit.CYAN, true)
	objective_label.position = Vector2(7, 3)
	c.add_child(objective_label)
	detail_label = UIKit.label("Select a destination to see how its real data becomes mission constraints.", 7, UIKit.MUTED, false)
	detail_label.position = Vector2(7, 14)
	detail_label.size = Vector2(460, 12)
	c.add_child(detail_label)

	confirm_btn = UIKit.button("SET COURSE >", Vector2(130, 22), true)
	confirm_btn.position = Vector2(482, 6)
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_confirm)
	c.add_child(confirm_btn)

	var back := UIKit.button("< REFIT", Vector2(64, 22))
	back.position = Vector2(10, 40)
	back.pressed.connect(func():
		GameState.undo_design()
		get_tree().change_scene_to_file("res://scenes/design.tscn")
	)
	c.add_child(back)

	var note := UIKit.label(
		"TEQ = starlight-only temperature · gravity drives dv · distance drives comms loss · source: NASA Exoplanet Archive",
		6, UIKit.DIM, false
	)
	note.position = Vector2(84, 43)
	note.size = Vector2(536, 22)
	c.add_child(note)


func _select_first() -> void:
	if not GameState.draft.is_empty():
		_select(str(GameState.draft[0]["id"]), false)


func _select(id: String, play_sound: bool = true) -> void:
	selected_id = id
	for c in cards:
		var on: bool = str(c["id"]) == id
		c["selected"] = on
		var accent: Color = c["accent"]
		var panel: PanelContainer = c["panel"]
		var title: Label = c["title"]
		if on:
			panel.add_theme_stylebox_override("panel", UIKit.style_panel(
				Color(accent.r * 0.11, accent.g * 0.11, accent.b * 0.11, 0.99),
				accent, 3, 2
			))
			title.add_theme_color_override("font_color", accent)
			selected_planet = c["planet"]
		else:
			panel.add_theme_stylebox_override("panel", UIKit.style_panel(
				Color("#0d1624"), UIKit.LINE, 3
			))
			title.add_theme_color_override("font_color", UIKit.TEXT)
	if play_sound:
		GameState.sfx("click")
	_refresh()


func _refresh() -> void:
	var o := GameState.objective()
	objective_label.text = "OBJECTIVE  ·  %s  ·  %d OF 4 DATA NODES REQUIRED" % [
		str(o.get("name", "")), int(o.get("quota", 3))
	]
	confirm_btn.disabled = selected_planet.is_empty()
	if selected_planet.is_empty():
		return
	var p := selected_planet
	var g: Dictionary = p["game"]
	detail_label.text = "Teq %d K > heat %d   ·   %.2fg > dv %d   ·   %.1f ly > comms -%d%%   ·   science %d" % [
		int(p["eq_temp_k"]), int(g["heat"]), float(p["gravity_g"]),
		int(g["delta_v"]), float(p["distance_ly"]), int(g["comms_loss"]),
		int(g["science"])
	]


func _confirm() -> void:
	if selected_planet.is_empty():
		return
	GameState.begin_sector(selected_planet)
	GameState.sfx("confirm")
	get_tree().change_scene_to_file("res://scenes/sector.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			GameState.undo_design()
			get_tree().change_scene_to_file("res://scenes/design.tscn")
		elif event.keycode == KEY_ENTER:
			_confirm()
