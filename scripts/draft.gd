extends Control

var cards: Array = []
var selected_id := ""
var confirm_btn: Button
var detail_label: Label
var objective_label: Label
var selected_planet: Dictionary = {}
var review_layer: CanvasLayer
var _committing := false


func _ready() -> void:
	MusicDirector.play("draft")
	if GameState.draft.is_empty():
		GameState.roll_draft()
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({"planet_on": false, "dim": 0.38})
	_build()
	_select_first()
	_refresh()
	if "--capture" in OS.get_cmdline_args() or "--capture" in OS.get_cmdline_user_args():
		# Capture starts with the pointer at screen centre, which can sit on a
		# planet card. Dismiss the dossier so the evidence frame shows the board.
		call_deferred("_hide_tips_for_capture")
	if "--review" in OS.get_cmdline_args() or "--review" in OS.get_cmdline_user_args():
		_show_mission_review()
	if "--commit" in OS.get_cmdline_args() or "--commit" in OS.get_cmdline_user_args():
		_commit_route.call_deferred()


func _hide_tips_for_capture() -> void:
	Input.warp_mouse(Vector2(2, 2))
	UITip.hide_tip()


func _build() -> void:
	var header := UIKit.head("DESTINATION DRAFT", 12, UIKit.NIGHT_TEXT)
	header.position = Vector2(10, 6)
	add_child(header)
	var step := UIKit.mono("SECTOR %d OF %d   ·   NASA EXOPLANET ARCHIVE   ·   PSCompPars" % [
		int(GameState.run.get("sector", 1)), GameState.SECTORS_PER_RUN
	], 7, UIKit.NIGHT_MUTED)
	step.position = Vector2(10, 22)
	add_child(step)

	var budget := UIKit.head("GRANTS $%dM" % int(GameState.run.get("budget", 0)), 10, UIKit.AMBER,
		HORIZONTAL_ALIGNMENT_RIGHT)
	budget.position = Vector2(490, 5)
	budget.size = Vector2(140, 15)
	add_child(budget)

	var appr := UIKit.mono("APPROVAL %d" % int(GameState.run.get("approval", 0)), 7, UIKit.NIGHT_MUTED,
		HORIZONTAL_ALIGNMENT_RIGHT)
	appr.position = Vector2(490, 20)
	appr.size = Vector2(140, 12)
	add_child(appr)
	UIKit.hairline(self, 10, 36, 620, UIKit.NIGHT_LINE)

	for i in range(mini(3, GameState.draft.size())):
		_make_card(GameState.draft[i], i)
	_build_footer()


func _make_card(p: Dictionary, idx: int) -> void:
	var x := 10.0 + float(idx) * 208.0
	var root := Control.new()
	root.position = Vector2(x, 40)
	root.size = Vector2(196, 238)
	add_child(root)

	var panel := UIKit.sheet(root, 0, 0, 196, 238)
	panel.add_theme_stylebox_override("panel", UIKit.style_panel(Color(0, 0, 0, 0), UIKit.INK, 0, 1))

	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(c)

	# Planet portrait.
	var holder := Control.new()
	holder.position = Vector2(52, 4)
	holder.size = Vector2(92, 66)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(holder)
	var portrait := SpaceBackdrop.new()
	holder.add_child(portrait)
	portrait.configure({
		"stars_on": false,
		"bg_on": false,
		"planet_center": Vector2(0.5, 0.5),
		"planet_size": 0.98,
		"planet_asset": SpaceBackdrop.asset_for_planet(p),
	})

	var name := UIKit.label(str(p["name"]), 9, UIKit.INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	name.position = Vector2(4, 72)
	name.size = Vector2(180, 13)
	c.add_child(name)

	var star_type := str(p.get("star_type", "")).strip_edges()
	if star_type == "" or star_type == "—":
		star_type = "UNKNOWN TYPE"
	var type_line := UIKit.mono(
		"%s   ·   %d K" % [
			GameState.biome_name(str(p["biome"])).to_upper(), int(p["eq_temp_k"])
		],
		8, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER
	)
	type_line.position = Vector2(4, 92)
	type_line.size = Vector2(180, 11)
	c.add_child(type_line)


	var g: Dictionary = p["game"]
	# One-second read for the first real decision: how hostile is this world
	# relative to the other two cards? The number is derived only from the
	# archive fields already shown on the card.
	var threat := int(g["heat"]) * 0.5 + int(g["radiation"]) * 0.35 + int(g["comms_loss"]) * 1.5
	var tag := "SAFE ROUTE"
	var tag_color := UIKit.GREEN
	if threat >= 68.0:
		tag = "HARSH WORLD"
		tag_color = UIKit.SIGNAL.lightened(0.18)
	elif threat >= 36.0:
		tag = "BALANCED"
		tag_color = UIKit.CAUTION
	var risk := UIKit.label("%s  ·  THREAT %d" % [tag, int(round(threat))], 6, tag_color, true,
		HORIZONTAL_ALIGNMENT_CENTER)
	risk.position = Vector2(4, 110)
	risk.size = Vector2(180, 12)
	c.add_child(risk)

	_stat(c, 124, "THERMAL LOAD", "%d" % int(g["heat"]), float(g["heat"]) / 100.0,
		UIKit.RED if int(g["heat"]) > 60 else UIKit.AMBER)
	_stat(c, 140, "RADIATION", "%d" % int(g["radiation"]), float(g["radiation"]) / 100.0,
		UIKit.ORANGE_DARK if int(g["radiation"]) > 40 else UIKit.INK)
	_stat(c, 156, "GRAVITY", "%.2fg" % float(p["gravity_g"]), float(p["gravity_g"]) / 3.0,
		UIKit.INK)
	_stat(c, 172, "COMMS LOSS", "-%d%%" % int(g["comms_loss"]), 1.0 - float(g["comms_loss"]) / 30.0,
		UIKit.INK if int(g["comms_loss"]) <= 10 else UIKit.ORANGE_DARK)
	_stat(c, 188, "SCIENCE", "%d" % int(g["science"]), float(g["science"]) / 120.0,
		UIKit.ORANGE_DARK)

	var mark := UIKit.mono("SELECT", 7, UIKit.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER)
	mark.position = Vector2(10, 210)
	mark.size = Vector2(172, 12)
	c.add_child(mark)

	var overlay := Button.new()
	overlay.flat = true
	overlay.focus_mode = Control.FOCUS_NONE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		overlay.add_theme_stylebox_override(s, empty)
	root.add_child(overlay)
	# The full-card hit target sits above the inner SELECT button. Without a
	# pressed handler it swallowed every click except the bottom sliver of the
	# button; make the whole card select the target instead.
	overlay.pressed.connect(_select.bind(str(p["id"])))
	overlay.mouse_entered.connect(func(): _hover(root, panel, true))
	overlay.mouse_exited.connect(func(): _hover(root, panel, false))
	var read := "A forgiving survey. Good for a fresh hull."
	if tag == "BALANCED":
		read = "Real trade-offs. A generalist build travels best."
	elif tag == "HARSH WORLD":
		read = "High thermal and comms pressure. Specialise or expect losses."
	UIKit.hover_info(overlay, str(p["name"]),
		"STAR  %s\nDISTANCE  %.1f ly\nGRAVITY  %.2fg\nSURFACE  %d SOLS · ΔV %d · %d NODES\nTHREAT  %d — %s\n\n%s" % [
			star_type, float(p["distance_ly"]), float(p["gravity_g"]),
			int(g["sols"]), int(g["delta_v"]), int(GameState.objective().get("quota", 3)),
			int(round(threat)), tag, read
		], GameState.biome_color(str(p["biome"])).lightened(0.2))

	var card := {
		"id": str(p["id"]), "planet": p, "root": root, "panel": panel,
		"title": name, "mark": mark, "accent": GameState.biome_color(str(p["biome"])),
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
		Color(0, 0, 0, 0), UIKit.ORANGE if on else UIKit.INK, 0, 2 if on else 1
	))


func _stat(c: Control, y: float, name: String, value: String, frac: float, color: Color) -> void:
	var l := UIKit.mono(name, 7, UIKit.INK_SOFT)
	l.position = Vector2(10, y)
	l.size = Vector2(74, 11)
	c.add_child(l)
	var bar := UIKit.bar(46, 4, UIKit.TEAL)
	bar.position = Vector2(88, y + 3)
	c.add_child(bar)
	UIKit.set_bar(bar, clampf(frac, 0.0, 1.0) * 100.0, 100.0)
	var v := UIKit.mono(value, 8, color, HORIZONTAL_ALIGNMENT_RIGHT)
	v.position = Vector2(136, y)
	v.size = Vector2(44, 11)
	c.add_child(v)


func _build_footer() -> void:
	var p := UIKit.sheet(self, 10, 282, 620, 72)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(c)

	objective_label = UIKit.mono("OBJECTIVE  ·  ...", 7, UIKit.SIGNAL)
	objective_label.position = Vector2(10, 5)
	c.add_child(objective_label)
	detail_label = UIKit.mono("Select a destination to see its mission constraints.", 8, UIKit.INK_SOFT)
	detail_label.position = Vector2(10, 18)
	detail_label.size = Vector2(470, 14)
	c.add_child(detail_label)

	confirm_btn = UIKit.button("SET COURSE >", Vector2(130, 22), true)
	confirm_btn.position = Vector2(470, 6)
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_confirm)
	c.add_child(confirm_btn)

	var back := UIKit.button("< REFIT", Vector2(72, 22))
	back.position = Vector2(10, 42)
	back.pressed.connect(func():
		GameState.undo_design()
		get_tree().change_scene_to_file("res://scenes/design.tscn")
	)
	c.add_child(back)



func _select_first() -> void:
	if not GameState.draft.is_empty():
		_select(str(GameState.draft[0]["id"]), false)


func _select(id: String, play_sound: bool = true) -> void:
	selected_id = id
	for c in cards:
		var on: bool = str(c["id"]) == id
		c["selected"] = on
		var panel: PanelContainer = c["panel"]
		var title: Label = c["title"]
		var mark: Label = c["mark"]
		if on:
			panel.add_theme_stylebox_override("panel", UIKit.style_panel(
				Color(0, 0, 0, 0), UIKit.ORANGE, 0, 2
			))
			title.add_theme_color_override("font_color", UIKit.ORANGE_DARK)
			mark.text = "●  TARGET MARKED"
			mark.add_theme_color_override("font_color", UIKit.ORANGE_DARK)
			selected_planet = c["planet"]
		else:
			panel.add_theme_stylebox_override("panel", UIKit.style_panel(
				Color(0, 0, 0, 0), UIKit.INK, 0, 1
			))
			title.add_theme_color_override("font_color", UIKit.INK)
			mark.text = "SELECT"
			mark.add_theme_color_override("font_color", UIKit.INK_FAINT)
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
	detail_label.text = "SURFACE WINDOW %d SOLS   ·   DELTA-V %d" % [
		int(g["sols"]), int(g["delta_v"])
	]
	detail_label.add_theme_color_override("font_color", UIKit.INK)


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
	shade.color = Color(0.01, 0.02, 0.04, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)

	var panel := UIKit.sheet(root, 20, 24, 600, 300)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(c)

	var kicker := UIKit.label("MISSION ARCHITECTURE REVIEW  //  PRE-COMMIT", 7, UIKit.ORANGE, true)
	kicker.position = Vector2(12, 8)
	kicker.size = Vector2(560, 12)
	c.add_child(kicker)
	var title := UIKit.label("%s  ·  %s" % [str(p["name"]).to_upper(), GameState.biome_name(str(p["biome"])).to_upper()], 12, UIKit.ORANGE_DARK, true)
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
	arc.modulate.a = 0.0
	traj.add_child(arc)
	# Live transfer: the ship actually flies the arc instead of a frozen
	# diamond at the midpoint. One-way loop with launch/arrival beats.
	var flyer := TransferShip.new()
	flyer.points = pts
	flyer.accent = Color(1.0, 0.78, 0.30)
	var hull_path := "res://assets/sprites/ships/%s.png" % str(GameState.hull().get("id", "pathfinder"))
	if ResourceLoader.exists(hull_path):
		flyer.ship_texture = load(hull_path) as Texture2D
	flyer.size = traj.size
	flyer.position = Vector2.ZERO
	traj.add_child(flyer)
	var arc_tw := flyer.create_tween()
	arc_tw.tween_property(arc, "modulate:a", 1.0, 0.45)
	var e1 := UIKit.label("EARTH", 5, UIKit.NIGHT_MUTED, true)
	e1.position = Vector2(8, 96)
	e1.size = Vector2(46, 10)
	traj.add_child(e1)
	var e2 := UIKit.label(str(p["name"]).to_upper(), 5, UIKit.AMBER, true, HORIZONTAL_ALIGNMENT_RIGHT)
	e2.position = Vector2(160, 55)
	e2.size = Vector2(102, 10)
	traj.add_child(e2)
	var t1 := UIKit.label("TRANSFER ARC  ·  %.1f LY  ·  %.1f YR @0.85c" % [
		float(p["distance_ly"]), maxf(0.4, float(p["distance_ly"]) / 0.85)
	], 5, UIKit.CYAN, true)
	t1.position = Vector2(56, 88)
	t1.size = Vector2(206, 12)
	traj.add_child(t1)
	var transit := UIKit.label("IN TRANSIT  0%", 5, UIKit.AMBER, true, HORIZONTAL_ALIGNMENT_RIGHT)
	transit.position = Vector2(160, 96)
	transit.size = Vector2(102, 10)
	traj.add_child(transit)
	flyer.progress_changed.connect(func(u: float):
		transit.text = "ORBIT INSERTION" if u >= 1.0 else "IN TRANSIT  %d%%" % int(u * 100.0)
	)

	var timeline := UIKit.label(
		"CONOPS  LAUNCH > CRUISE > ORBIT INSERTION > SURFACE > DOWNLINK > END
"
		+ "SURFACE WINDOW  %d SOLS   ·   DOWNLINK LOSS  -%d%%   ·   %s" % [
			int(g["sols"]), int(g["comms_loss"]),
			"3 RELAY BEACONS" if relay else "%d DATA NODES" % int(obj.get("quota", 3))
		], 7, UIKit.INK)
	timeline.position = Vector2(12, 162)
	timeline.size = Vector2(270, 42)
	timeline.add_theme_constant_override("line_spacing", 1)
	c.add_child(timeline)

	# ---- four mission segments (Design and Develop Science Missions)
	var seg_x := 298.0
	var segs := [
		["LAUNCH", "%s · %dKG CAP" % [str(veh.get("name", "—")).to_upper(), int(veh.get("capacity", 0))], UIKit.TEXT],
		["SPACE", "%s · %d INSTR · %dW" % [str(GameState.hull().get("name", "—")).to_upper(), GameState.run.get("instruments", []).size(), int(ship.get("power_gen", 0))], UIKit.TEXT],
		["GROUND", "-%d%% DOWNLINK · %d PASSES/DAY" % [int(g["comms_loss"]), int(orbit["passes"])], UIKit.TEXT],
		["USER", "%s%s" % [str(obj.get("name", "—")).to_upper(), " · FIT +10%" if bool(ship.get("science_fit", false)) else ""], UIKit.TEXT],
	]
	for i in range(segs.size()):
		var y := 44.0 + i * 27.0
		var lab := UIKit.label(str(segs[i][0]), 6, UIKit.INK, true)
		lab.position = Vector2(seg_x, y)
		lab.size = Vector2(38, 12)
		c.add_child(lab)
		var val := UIKit.label(str(segs[i][1]), 7, UIKit.INK, true)
		val.position = Vector2(seg_x + 42, y - 1)
		val.size = Vector2(248, 12)
		c.add_child(val)
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(seg_x, y + 14), Vector2(seg_x + 286, y + 14)])
		line.width = 1.0
		line.default_color = UIKit.SHEET_LINE
		c.add_child(line)

	var cml := UIKit.label("CML %d %s  ·  %s" % [
		int(cm["level"]), str(cm["label"]),
		"SCIENCE TRACEABILITY CLOSED" if bool(ship.get("science_fit", false)) else "SCIENCE FIT MISSING"
	], 7, UIKit.TEAL if bool(ship.get("science_fit", false)) else UIKit.ORANGE_DARK, true)
	cml.position = Vector2(seg_x, 158)
	cml.size = Vector2(288, 12)
	c.add_child(cml)

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
	if selected_planet.is_empty() or _committing:
		return
	_committing = true
	var planet := selected_planet
	GameState.begin_sector(planet)
	GameState.sfx("confirm")
	# The review's mini-viz becomes a full-screen transfer before the sector
	# loads: the ship leaves Earth, crosses, and the cut lands on the surface.
	_play_commit_transit(planet)
	await get_tree().create_timer(1.85).timeout
	get_tree().change_scene_to_file("res://scenes/sector.tscn")


func _play_commit_transit(p: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.008, 0.012, 0.026, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var stars := SpaceBackdrop.new()
	stars.configure({"planet_on": false, "dim": 0.30})
	root.add_child(stars)
	var earth := TextureRect.new()
	earth.texture = load("res://assets/sprites/planets/temperate.png")
	earth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	earth.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	earth.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	earth.position = Vector2(54, 196)
	earth.size = Vector2(84, 84)
	root.add_child(earth)
	var target := TextureRect.new()
	var tp := SpaceBackdrop.asset_for_planet(p)
	if ResourceLoader.exists(tp):
		target.texture = load(tp)
	target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	target.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	target.position = Vector2(486, 58)
	target.size = Vector2(100, 100)
	root.add_child(target)
	var pts := PackedVector2Array()
	for i in range(30):
		var t := float(i) / 29.0
		var a := Vector2(132, 240)
		var b := Vector2(286, 62)
		var d := Vector2(506, 138)
		pts.append(a.lerp(b, t).lerp(b.lerp(d, t), t))
	var arc := Line2D.new()
	arc.points = pts
	arc.width = 1.4
	arc.default_color = Color(0.33, 0.90, 0.84, 0.55)
	root.add_child(arc)
	var flyer := TransferShip.new()
	flyer.points = pts
	flyer.size = Vector2(640, 360)
	flyer.travel_seconds = 1.35
	flyer.hold_seconds = 0.30
	flyer.accent = Color(1.0, 0.78, 0.30)
	var hp := "res://assets/sprites/ships/%s.png" % str(GameState.hull().get("id", "pathfinder"))
	if ResourceLoader.exists(hp):
		flyer.ship_texture = load(hp) as Texture2D
	root.add_child(flyer)
	var lab := UIKit.label("TRANSIT  ·  %s" % str(p["name"]).to_upper(),
		9, UIKit.CYAN, true, HORIZONTAL_ALIGNMENT_CENTER)
	lab.position = Vector2(0, 24)
	lab.size = Vector2(640, 16)
	root.add_child(lab)
	var sub := UIKit.label("%.1f LY  ·  %.1f YR @0.85c" % [
		float(p["distance_ly"]), maxf(0.4, float(p["distance_ly"]) / 0.85)
	], 7, UIKit.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 42)
	sub.size = Vector2(640, 12)
	root.add_child(sub)
	var earth_lab := UIKit.label("EARTH", 6, UIKit.DIM, true)
	earth_lab.position = Vector2(54, 284)
	earth_lab.size = Vector2(84, 10)
	root.add_child(earth_lab)
	var dest_lab := UIKit.label(str(p["name"]).to_upper(), 6, UIKit.AMBER, true,
		HORIZONTAL_ALIGNMENT_RIGHT)
	dest_lab.position = Vector2(486, 162)
	dest_lab.size = Vector2(100, 10)
	root.add_child(dest_lab)
	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.25)


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
