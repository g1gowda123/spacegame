extends Control
const ORBIT_PLOT := preload("res://scripts/ui_orbit_plot.gd")

var howto_layer: Control
var ranks_layer: Control


func _ready() -> void:
	MusicDirector.play("title")
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({
		"planet_center": Vector2(1.05, 0.40),
		"planet_size": 0.92,
		"planet_asset": "rocky",
		"dim": 0.58,
		# Home-screen life: drifting cloud bands + a barely-there sway.
		"planet_clouds": 1.0,
		"planet_turn": 1.0,
		"planet_sway": 1.0,
	})
	_build_ui()
	_build_howto()
	_build_ranks()
	if "--howto" in OS.get_cmdline_args() or "--howto" in OS.get_cmdline_user_args():
		howto_layer.visible = true
	if "--ranks" in OS.get_cmdline_args() or "--ranks" in OS.get_cmdline_user_args():
		ranks_layer.visible = true
	GameState.sfx("confirm")
	if not GameState.briefing_seen and not _dev_screen():
		call_deferred("_open_briefing")


func _build_ui() -> void:
	# Full-bleed title: the starfield stays open and a soft scrim carries the
	# type. No poster edge, so the screen reads as one continuous view.
	var scrim := TextureRect.new()
	scrim.texture = _left_scrim()
	scrim.position = Vector2.ZERO
	scrim.size = Vector2(472, 360)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var plot := ORBIT_PLOT.new()
	plot.position = Vector2(300, 68)
	plot.size = Vector2(150, 78)
	add_child(plot)
	var stamp := TextureRect.new()
	stamp.texture = load("res://assets/ui/skin_ops/stamp_approved.png")
	stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stamp.position = Vector2(366, 26)
	stamp.size = Vector2(92, 30)
	stamp.rotation = -0.06
	stamp.modulate = Color(1, 1, 1, 0.92)
	add_child(stamp)

	var logo := UIKit.label("ORBIT", 46, UIKit.TEXT, true)
	logo.position = Vector2(38, 44)
	add_child(logo)
	var amp := UIKit.label("&", 34, UIKit.ORANGE, false)
	amp.position = Vector2(40, 88)
	amp.size = Vector2(22, 34)
	add_child(amp)
	var outplay := UIKit.label("OUTPLAY", 30, UIKit.TEXT, true)
	outplay.position = Vector2(64, 90)
	add_child(outplay)

	var tagline := UIKit.mono("DESIGN A SHIP.  DRAFT A WORLD.  SURVIVE IT.", 8, UIKit.MUTED)
	tagline.position = Vector2(44, 138)
	add_child(tagline)

	var begin := UIKit.button("BEGIN MISSION", Vector2(208, 34), true)
	begin.position = Vector2(44, 170)
	begin.add_theme_font_size_override("font_size", 11)
	begin.pressed.connect(_start)
	add_child(begin)

	var crew := UIKit.button("MISSION CONTROL", Vector2(156, 34))
	crew.position = Vector2(264, 170)
	crew.add_theme_font_size_override("font_size", 10)
	crew.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/crew.tscn"))
	add_child(crew)

	var daily := UIKit.button("DAILY RUN", Vector2(96, 26))
	daily.position = Vector2(44, 222)
	daily.add_theme_font_size_override("font_size", 9)
	daily.pressed.connect(_start_daily)
	add_child(daily)

	var how := UIKit.button("HOW TO PLAY", Vector2(112, 26))
	how.position = Vector2(148, 222)
	how.add_theme_font_size_override("font_size", 9)
	how.pressed.connect(func(): howto_layer.visible = true)
	add_child(how)

	var story := UIKit.button("STORY", Vector2(72, 26))
	story.position = Vector2(268, 222)
	story.add_theme_font_size_override("font_size", 9)
	story.pressed.connect(_open_briefing)
	add_child(story)

	var ranks := UIKit.button("RANKS", Vector2(72, 26))
	ranks.position = Vector2(348, 222)
	ranks.add_theme_font_size_override("font_size", 9)
	ranks.pressed.connect(func(): ranks_layer.visible = true)
	add_child(ranks)

	var quit := UIKit.button("QUIT", Vector2(56, 26))
	quit.position = Vector2(428, 222)
	quit.add_theme_font_size_override("font_size", 9)
	quit.pressed.connect(_quit_game)
	add_child(quit)

	var daily_note := "BEST RUN  %s   ·   CMD %s" % [_fmt(GameState.best_score), GameState.player_name]
	var best := UIKit.mono(daily_note, 7, UIKit.INK_SOFT)
	best.position = Vector2(44, 318)
	add_child(best)



func _left_scrim() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.82, 1.0])
	g.colors = PackedColorArray([
		Color(0.039, 0.067, 0.082, 0.94),
		Color(0.039, 0.067, 0.082, 0.88),
		Color(0.039, 0.067, 0.082, 0.48),
		Color(0.039, 0.067, 0.082, 0.0),
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 2
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	return t


func _build_howto() -> void:
	howto_layer = Control.new()
	howto_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	howto_layer.visible = false
	add_child(howto_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	howto_layer.add_child(shade)

	var p := UIKit.panel(UIKit.PAPER, UIKit.INK)
	p.position = Vector2(70, 34)
	p.size = Vector2(500, 292)
	howto_layer.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	v.add_child(UIKit.label("HOW TO PLAY", 20, UIKit.ORANGE, true))
	v.add_child(UIKit.label("ONE RUN = 3 EXOPLANETS. PICK 1-4 CREW AND A DIFFICULTY IN MISSION CONTROL.", 7, UIKit.SIGNAL, true))
	v.add_child(UIKit.rule())

	var rows := [
		["01  DESIGN", "Choose 1-4 players and a difficulty tier in MISSION CONTROL, then pick a hull, launch vehicle, mission objective and 2 instruments. Mass, power, budget and delta-v are real trade-offs."],
		["02  DRAFT", "Choose 1 of 3 real exoplanets from the NASA Exoplanet Archive. Its temperature, gravity, radiation and distance generate the mission."],
		["03  SURVIVE", "Click a tile to preview the path. ENTER commits the move. Collect the required data nodes, then return to the lander and press EXTRACT before sols or delta-v run out."],
		["04  MANAGE", "Every path tile costs 1 dv + 1 sol and adds heat. Hazards resolve at end of turn. HOLD vents heat, recharges power, and burns a sol."],
		["05  BUILD", "Spend grants between sectors on modules and firmware. Stack bonuses. No single build survives every planet."],
	]
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var key := UIKit.label(r[0], 8, UIKit.ORANGE, true)
		key.custom_minimum_size = Vector2(86, 0)
		h.add_child(key)
		var body := UIKit.label(r[1], 8, UIKit.MUTED, false)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(382, 0)
		h.add_child(body)
		v.add_child(h)

	var close := UIKit.button("GOT IT", Vector2(100, 26), true)
	close.position = Vector2(462, 296)
	close.pressed.connect(func(): howto_layer.visible = false)
	howto_layer.add_child(close)


func _build_ranks() -> void:
	ranks_layer = Control.new()
	ranks_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ranks_layer.visible = false
	add_child(ranks_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.80)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ranks_layer.add_child(shade)

	var sheet := UIKit.sheet(ranks_layer, 92, 44, 456, 272)
	var content := UIKit.fill(sheet)

	var kicker := UIKit.label("AGENCY HONOURS BOARD  //  LOCAL RECORDS", 7, UIKit.ORANGE, true)
	kicker.position = Vector2(18, 16)
	kicker.size = Vector2(420, 10)
	content.add_child(kicker)
	var title := UIKit.label("WHO SAVED THE AGENCY?", 12, UIKit.INK, true)
	title.position = Vector2(18, 32)
	title.size = Vector2(420, 14)
	content.add_child(title)
	var note := UIKit.label("BEST RUN PER CALLSIGN  ·  STORED ON THIS TERMINAL", 5, UIKit.MUTED, true)
	note.position = Vector2(18, 48)
	note.size = Vector2(420, 10)
	content.add_child(note)

	var rows := GameState.leaderboard_top(5)
	if rows.is_empty():
		var empty := UIKit.label("NO FLIGHTS FILED YET. BE THE FIRST.", 8, UIKit.MUTED, true)
		empty.position = Vector2(18, 92)
		empty.size = Vector2(420, 14)
		content.add_child(empty)
	else:
		for i in range(rows.size()):
			var row: Dictionary = rows[i]
			var y := 76 + i * 28
			var rank := UIKit.label("%02d" % (i + 1), 9, UIKit.ORANGE, true)
			rank.position = Vector2(18, y)
			rank.size = Vector2(28, 12)
			content.add_child(rank)
			var who := UIKit.label(str(row.get("name", "CHIEF")), 9, UIKit.INK, true)
			who.position = Vector2(50, y)
			who.size = Vector2(120, 12)
			content.add_child(who)
			var score := UIKit.label("%d" % int(row.get("score", 0)), 9, UIKit.INK, true, HORIZONTAL_ALIGNMENT_RIGHT)
			score.position = Vector2(170, y)
			score.size = Vector2(64, 12)
			content.add_child(score)
			var grade := UIKit.label(str(row.get("grade", "C")), 9, UIKit.SIGNAL, true)
			grade.position = Vector2(242, y)
			grade.size = Vector2(20, 12)
			content.add_child(grade)
			var meta := UIKit.label("%s  ·  %s" % [str(row.get("date", "")), str(row.get("difficulty", "standard")).to_upper()], 5, UIKit.MUTED, true)
			meta.position = Vector2(270, y + 2)
			meta.size = Vector2(168, 10)
			content.add_child(meta)
			var rule := ColorRect.new()
			rule.color = UIKit.STEEL
			rule.position = Vector2(18, y + 22)
			rule.size = Vector2(420, 1)
			content.add_child(rule)

	var close := UIKit.button("CLOSE", Vector2(88, 22))
	close.position = Vector2(350, 244)
	close.pressed.connect(func(): ranks_layer.visible = false)
	content.add_child(close)


func _dev_screen() -> bool:
	for raw in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var arg := str(raw)
		if arg.begins_with("--screen=") or arg == "--capture" \
				or arg.begins_with("--capture-name=") or arg == "--howto":
			return true
	return false


func _open_briefing() -> void:
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/briefing.tscn")


func _start() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	CrewDirector.begin_run("campaign", 1, "standard")
	get_tree().change_scene_to_file("res://scenes/design.tscn")


func _start_daily() -> void:
	CrewDirector.begin_run("daily", 1, "standard")
	get_tree().change_scene_to_file("res://scenes/design.tscn")


func _fmt(n: int) -> String:
	if n <= 0:
		return "—"
	return str(n)


func _quit_game() -> void:
	if GameState:
		GameState.sfx("confirm")
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if howto_layer.visible:
				howto_layer.visible = false
			elif ranks_layer.visible:
				ranks_layer.visible = false
			else:
				_start()
		elif event.keycode == KEY_H:
			ranks_layer.visible = false
			howto_layer.visible = not howto_layer.visible
		elif event.keycode == KEY_R:
			howto_layer.visible = false
			ranks_layer.visible = not ranks_layer.visible
		elif event.keycode == KEY_C:
			get_tree().change_scene_to_file("res://scenes/crew.tscn")
		elif event.keycode == KEY_Q and not howto_layer.visible and not ranks_layer.visible:
			_quit_game()
		elif event.keycode == KEY_ESCAPE:
			howto_layer.visible = false
			ranks_layer.visible = false
