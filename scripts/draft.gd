extends Control

var cards: Array = []
var selected_id := ""
var confirm_btn: Button
var detail_label: Label
var objective_label: Label
var selected_planet: Dictionary = {}
var review_layer: CanvasLayer


func _ready() -> void:
	if GameState.draft.is_empty():
		GameState.roll_draft()
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({"planet_on": false, "dim": 0.38})
	_build()
	_select_first()
	_refresh()
	if "--review" in OS.get_cmdline_args() or "--review" in OS.get_cmdline_user_args():
		_show_mission_review()


func _build() -> void:
	var header := UIKit.label("DESTINATION DRAFT  //  %02d" % int(GameState.run.get("sector", 1)), 13, UIKit.CYAN, true)
	header.position = Vector2(10, 7)
	add_child(header)
	var step := UIKit.label("SECTOR %d OF %d  ·  CHOOSE A REAL EXOPLANET" % [
		int(GameState.run.get("sector", 1)), GameState.SECTORS_PER_RUN
	], 7, UIKit.DIM, true)
	step.position = Vector2(10, 24)
	add_child(step)

	# Body face: the pixel font is uppercase-only and would print PSCOMPPARS.
	var src := UIKit.label("NASA EXOPLANET ARCHIVE  ·  PSCompPars", 7, UIKit.DIM, false)
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
	# One-second read for the first real decision: how hostile is this world
	# relative to the other two cards? The number is derived only from the
	# archive fields already shown on the card.
	var threat := int(g["heat"]) * 0.5 + int(g["radiation"]) * 0.35 + int(g["comms_loss"]) * 1.5
	var tag := "SAFE ROUTE"
	var tag_color := UIKit.GREEN
	if threat >= 68.0:
		tag = "HARSH WORLD"
		tag_color = UIKit.RED
	elif threat >= 36.0:
		tag = "BALANCED"
		tag_color = UIKit.AMBER
	var risk := UIKit.label("%s  ·  THREAT %d" % [tag, int(round(threat))], 6, tag_color, true,
		HORIZONTAL_ALIGNMENT_CENTER)
	risk.position = Vector2(4, 117)
	risk.size = Vector2(188, 10)
	c.add_child(risk)

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
	var relay := GameState.sector_mode() == "relay"
	objective_label.text = "OBJECTIVE  ·  %s  ·  %s" % [
		str(o.get("name", "")),
		"PLANT 3 RELAY BEACONS" if relay else "%d OF 4 DATA NODES REQUIRED" % int(o.get("quota", 3))
	]
	confirm_btn.disabled = selected_planet.is_empty()
	if selected_planet.is_empty():
		return
	var p := selected_planet
	var g: Dictionary = p["game"]
	detail_label.text = "Teq %d K  ·  heat %d   ·   %.2fg  ·  dv %d   ·   %.1f ly  ·  comms -%d%%   ·   science %d" % [
		int(p["eq_temp_k"]), int(g["heat"]), float(p["gravity_g"]),
		int(g["delta_v"]), float(p["distance_ly"]), int(g["comms_loss"]),
		int(g["science"])
	]


func _confirm() -> void:
	if selected_planet.is_empty() or review_layer != null:
		return
	_show_mission_review()


## Mission architecture review: the four segment model from the NASA design
## guide, a Mission-Viz-style transfer arc, and the ConOps timeline. This is
## the last decision point before the surface, so the player can see that the
## design choices from the previous screen became a complete mission.
func _show_mission_review() -> void:
	var p := selected_planet
	var g: Dictionary = p["game"]
	var ship := GameState.ship()
	var veh := GameState.vehicle()
	var obj := GameState.objective()
	var orbit := GameState.orbit_stats(p)
	var cm := GameState.cml()
	var relay := GameState.sector_mode() == "relay"
	review_layer = CanvasLayer.new()
	review_layer.layer = 35
	add_child(review_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The modal must swallow input: clicks and arrow keys used to fall through to
	# the draft cards underneath and silently re-roll the chosen target.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	review_layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)

	var panel := UIKit.panel(Color("#0b1320"), UIKit.CYAN)
	panel.position = Vector2(20, 24)
	panel.size = Vector2(600, 300)
	root.add_child(panel)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(c)

	var kicker := UIKit.label("MISSION ARCHITECTURE REVIEW  //  PRE-COMMIT", 7, UIKit.AMBER, true)
	kicker.position = Vector2(12, 8)
	kicker.size = Vector2(560, 12)
	c.add_child(kicker)
	var title := UIKit.label("%s  ·  %s" % [str(p["name"]).to_upper(), GameState.biome_name(str(p["biome"])).to_upper()], 12, UIKit.CYAN, true)
	title.position = Vector2(12, 22)
	title.size = Vector2(560, 16)
	c.add_child(title)

	# ---- transfer arc (Mission Viz / VR resource: trajectory + timeline)
	var traj := Control.new()
	traj.position = Vector2(12, 44)
	traj.size = Vector2(270, 112)
	traj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(traj)
	var frame := UIKit.panel(Color("#060b13"), Color("#1d344a"))
	frame.position = Vector2.ZERO
	frame.size = traj.size
	traj.add_child(frame)
	var earth := TextureRect.new()
	earth.texture = load("res://assets/sprites/planets/temperate.png")
	earth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	earth.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	earth.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	earth.position = Vector2(8, 52)
	earth.size = Vector2(46, 46)
	earth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	traj.add_child(earth)
	var target_path := SpaceBackdrop.asset_for_planet(p)
	var target := TextureRect.new()
	if ResourceLoader.exists(target_path):
		target.texture = load(target_path)
	target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	target.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	target.position = Vector2(216, 8)
	target.size = Vector2(46, 46)
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	traj.add_child(target)
	var arc := Line2D.new()
	arc.width = 1.3
	arc.default_color = Color(0.33, 0.90, 0.84, 0.72)
	var pts := PackedVector2Array()
	for i in range(25):
		var t := float(i) / 24.0
		var a := Vector2(52, 78)
		var b := Vector2(118, 4)
		var d := Vector2(238, 34)
		pts.append(a.lerp(b, t).lerp(b.lerp(d, t), t))
	arc.points = pts
	traj.add_child(arc)
	var moving := Polygon2D.new()
	moving.polygon = PackedVector2Array([Vector2(0, -3), Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0)])
	moving.position = pts[15]
	moving.color = Color(1.0, 0.78, 0.30, 0.95)
	traj.add_child(moving)
	var e1 := UIKit.label("EARTH", 5, UIKit.DIM, true)
	e1.position = Vector2(8, 99)
	e1.size = Vector2(46, 8)
	traj.add_child(e1)
	var e2 := UIKit.label(str(p["name"]).to_upper(), 5, UIKit.AMBER, true, HORIZONTAL_ALIGNMENT_RIGHT)
	e2.position = Vector2(160, 55)
	e2.size = Vector2(102, 8)
	traj.add_child(e2)
	var t1 := UIKit.label("TRANSFER ARC  ·  %.1f LY  ·  %.1f YR @0.85c" % [
		float(p["distance_ly"]), maxf(0.4, float(p["distance_ly"]) / 0.85)
	], 5, UIKit.CYAN, true)
	t1.position = Vector2(56, 88)
	t1.size = Vector2(206, 10)
	traj.add_child(t1)

	var timeline := UIKit.label(
		"CONOPS  LAUNCH > CRUISE > ORBIT INSERTION > SURFACE > DOWNLINK > END
"
		+ "SURFACE WINDOW  %d SOLS   ·   DOWNLINK LOSS  -%d%%   ·   %s" % [
			int(g["sols"]), int(g["comms_loss"]),
			"3 RELAY BEACONS" if relay else "%d DATA NODES" % int(obj.get("quota", 3))
		], 6, UIKit.MUTED, false)
	timeline.position = Vector2(12, 162)
	timeline.size = Vector2(270, 42)
	timeline.add_theme_constant_override("line_spacing", 1)
	c.add_child(timeline)

	# ---- four mission segments (Design and Develop Science Missions)
	var seg_x := 298.0
	var segs := [
		["LAUNCH", "%s · %dKG CAP" % [str(veh.get("name", "—")).to_upper(), int(veh.get("capacity", 0))], UIKit.CYAN],
		["SPACE", "%s · %d INSTR · %dW" % [str(GameState.hull().get("name", "—")).to_upper(), GameState.run.get("instruments", []).size(), int(ship.get("power_gen", 0))], UIKit.GREEN],
		["GROUND", "-%d%% DOWNLINK · %d PASSES/DAY" % [int(g["comms_loss"]), int(orbit["passes"])], UIKit.AMBER],
		["USER", "%s%s" % [str(obj.get("name", "—")).to_upper(), " · FIT +10%" if bool(ship.get("science_fit", false)) else ""], UIKit.PURPLE],
	]
	for i in range(segs.size()):
		var y := 44.0 + i * 27.0
		var lab := UIKit.label(str(segs[i][0]), 6, UIKit.DIM, true)
		lab.position = Vector2(seg_x, y)
		lab.size = Vector2(38, 10)
		c.add_child(lab)
		var val := UIKit.label(str(segs[i][1]), 7, segs[i][2], true)
		val.position = Vector2(seg_x + 42, y - 1)
		val.size = Vector2(248, 12)
		c.add_child(val)
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(seg_x, y + 14), Vector2(seg_x + 286, y + 14)])
		line.width = 1.0
		line.default_color = Color(0.16, 0.25, 0.35, 0.9)
		c.add_child(line)

	var cml := UIKit.label("CML %d %s  ·  %s" % [
		int(cm["level"]), str(cm["label"]),
		"SCIENCE TRACEABILITY CLOSED" if bool(ship.get("science_fit", false)) else "SCIENCE FIT MISSING"
	], 7, UIKit.GREEN if bool(ship.get("science_fit", false)) else UIKit.AMBER, true)
	cml.position = Vector2(seg_x, 158)
	cml.size = Vector2(288, 12)
	c.add_child(cml)
	var note := UIKit.label(
		"NASA 4-segment model · orbit %s %dkm · %dmin · %d%% eclipse · c-fraction abstracted" % [
			str(orbit["label"]), int(orbit["alt_km"]), int(orbit["period_min"]), int(orbit["eclipse"])
		], 5, UIKit.DIM, false)
	note.position = Vector2(seg_x, 174)
	note.size = Vector2(288, 44)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(note)

	var back := UIKit.button("< BACK TO DRAFT", Vector2(112, 24))
	back.position = Vector2(298, 260)
	back.pressed.connect(func():
		if review_layer != null:
			review_layer.queue_free()
			review_layer = null
	)
	c.add_child(back)
	var commit := UIKit.button("COMMIT MISSION >", Vector2(160, 24), true)
	commit.position = Vector2(426, 260)
	commit.pressed.connect(_commit_route)
	c.add_child(commit)


func _commit_route() -> void:
	print("DBG commit_route planet=%s" % str(selected_planet.get("name", "<empty>")))
	if selected_planet.is_empty():
		return
	GameState.begin_sector(selected_planet)
	GameState.sfx("confirm")
	get_tree().change_scene_to_file("res://scenes/sector.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# While the review is open it owns the keyboard: ENTER commits, ESC backs
		# out of the modal. Without this the underlying draft kept reacting to
		# arrows and the modal's commit could be missed.
		if review_layer != null:
			if event.keycode == KEY_ENTER:
				_commit_route()
			elif event.keycode == KEY_ESCAPE:
				_close_review()
			return
		if event.keycode == KEY_ESCAPE:
			GameState.undo_design()
			get_tree().change_scene_to_file("res://scenes/design.tscn")
		elif event.keycode == KEY_ENTER:
			_confirm()


func _input(event: InputEvent) -> void:
	print("DBG input key=%d review=%s" % [event.keycode if event is InputEventKey else -1, str(review_layer != null)])
	# While the review is open it owns the keyboard. Handled in _input rather
	# than _unhandled_input so a focused button cannot swallow the key first.
	if review_layer == null or not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_commit_route()
	elif event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close_review()


func _close_review() -> void:
	if review_layer != null:
		review_layer.queue_free()
		review_layer = null
