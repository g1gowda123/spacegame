extends Control

var howto_layer: Control


func _ready() -> void:
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({
		"planet_center": Vector2(1.05, 0.40),
		"planet_size": 0.92,
		"planet_asset": "rocky",
		"dim": 0.58,
	})
	_build_ui()
	_build_howto()
	if "--howto" in OS.get_cmdline_args() or "--howto" in OS.get_cmdline_user_args():
		howto_layer.visible = true
	GameState.sfx("confirm")
	if not GameState.briefing_seen and not _dev_screen():
		call_deferred("_open_briefing")


func _build_ui() -> void:
	var kicker := UIKit.label("NASA SPACE APPS CHALLENGE 2026", 9, UIKit.CYAN, true)
	kicker.position = Vector2(42, 24)
	add_child(kicker)
	var sub := UIKit.label("OFFICIAL CHALLENGE  //  SPACE MISSION DESIGN GAME", 7, UIKit.DIM, true)
	sub.position = Vector2(42, 38)
	add_child(sub)

	var logo := UIKit.label("ORBIT", 46, UIKit.TEXT, true)
	logo.position = Vector2(38, 72)
	add_child(logo)
	var amp := UIKit.label("&", 34, UIKit.AMBER, false)
	amp.position = Vector2(40, 116)
	amp.size = Vector2(22, 34)
	add_child(amp)
	var outplay := UIKit.label("OUTPLAY", 30, UIKit.AMBER, true)
	outplay.position = Vector2(64, 118)
	add_child(outplay)

	var tag := UIKit.label("MISSION ARCHITECTURE ROGUELITE", 9, UIKit.CYAN, true)
	tag.position = Vector2(44, 160)
	add_child(tag)

	var blurb := UIKit.label(
		"Design a spacecraft. Draft a real exoplanet.\n"
		+ "Survive its surface. Three missions to save\nyour agency from being defunded.",
		9, UIKit.MUTED, false
	)
	blurb.position = Vector2(44, 180)
	add_child(blurb)

	var begin := UIKit.button("BEGIN MISSION", Vector2(160, 30), true)
	begin.position = Vector2(44, 228)
	begin.pressed.connect(_start)
	add_child(begin)

	var crew := UIKit.button("MISSION CONTROL", Vector2(148, 30))
	crew.position = Vector2(212, 228)
	crew.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/crew.tscn"))
	add_child(crew)

	var daily := UIKit.button("DAILY RUN", Vector2(148, 26))
	daily.position = Vector2(44, 264)
	daily.pressed.connect(_start_daily)
	add_child(daily)

	var how := UIKit.button("HOW TO PLAY", Vector2(130, 26))
	how.position = Vector2(200, 264)
	how.pressed.connect(func(): howto_layer.visible = true)
	add_child(how)

	var story := UIKit.button("STORY", Vector2(104, 26))
	story.position = Vector2(338, 264)
	story.pressed.connect(_open_briefing)
	add_child(story)

	var daily_note := "BEST RUN  %s" % _fmt(GameState.best_score)
	var today := CrewDirector.today_key()
	if CrewDirector.daily_key == today and CrewDirector.daily_best > 0:
		daily_note += "   ·   DAILY %s  %d" % [today, CrewDirector.daily_best]
	else:
		daily_note += "   ·   DAILY %s  %s" % [today, _fmt(0)]
	var best := UIKit.label(daily_note, 8, UIKit.DIM, true)
	best.position = Vector2(46, 296)
	add_child(best)

	var line := ColorRect.new()
	line.color = Color(0.33, 0.90, 0.82, 0.35)
	line.position = Vector2(44, 314)
	line.size = Vector2(316, 1)
	add_child(line)

	var credit := UIKit.label(
		"PLANETARY DATA  //  NASA EXOPLANET ARCHIVE  ·  PSCompPars",
		7, UIKit.DIM, true
	)
	credit.position = Vector2(44, 322)
	add_child(credit)

	var proto := UIKit.label("PROTOTYPE 1.0  ·  WEB BUILD", 7, UIKit.DIM, true)
	proto.position = Vector2(468, 338)
	add_child(proto)

	var sig := UIKit.label("> SIGNAL LOCKED", 7, UIKit.GREEN, true)
	sig.position = Vector2(44, 338)
	add_child(sig)
	var tw := create_tween().set_loops()
	tw.tween_property(sig, "modulate:a", 0.25, 1.4)
	tw.tween_property(sig, "modulate:a", 1.0, 1.4)


func _build_howto() -> void:
	howto_layer = Control.new()
	howto_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	howto_layer.visible = false
	add_child(howto_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	howto_layer.add_child(shade)

	var p := UIKit.panel(Color("#0d1522"), UIKit.CYAN_DARK)
	p.position = Vector2(70, 34)
	p.size = Vector2(500, 292)
	howto_layer.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	v.add_child(UIKit.label("HOW TO PLAY", 20, UIKit.CYAN, true))
	v.add_child(UIKit.label("ONE RUN = 3 EXOPLANETS. PICK 1-4 CREW AND A DIFFICULTY IN MISSION CONTROL.", 7, UIKit.AMBER, true))
	v.add_child(UIKit.rule())

	var rows := [
		["01  DESIGN", "Choose 1-4 players and a difficulty tier in MISSION CONTROL, then pick a hull, launch vehicle, mission objective and 2 instruments. Mass, power, budget and delta-v are real trade-offs."],
		["02  DRAFT", "Choose 1 of 3 real exoplanets from the NASA Exoplanet Archive. Its temperature, gravity, radiation and distance generate the mission."],
		["03  SURVIVE", "Click a tile to preview the path. One move per turn; ENTER commits. Collect 3 of 4 data nodes before sols or delta-v run out."],
		["04  MANAGE", "Every path tile costs 1 dv + 1 sol and adds heat. Hazards resolve at end of turn. HOLD vents heat, recharges power, and burns a sol."],
		["05  BUILD", "Spend grants between sectors on modules and firmware. Stack bonuses. No single build survives every planet."],
	]
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var key := UIKit.label(r[0], 8, UIKit.CYAN, true)
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


func _dev_screen() -> bool:
	for raw in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var arg := str(raw)
		if arg.begins_with("--screen=") or arg == "--capture" \
				or arg.begins_with("--capture-name=") or arg == "--howto":
			return true
	return false


func _open_briefing() -> void:
	get_tree().change_scene_to_file("res://scenes/briefing.tscn")


func _start() -> void:
	CrewDirector.begin_run("campaign", 1, "standard")
	get_tree().change_scene_to_file("res://scenes/design.tscn")


func _start_daily() -> void:
	CrewDirector.begin_run("daily", 1, "standard")
	get_tree().change_scene_to_file("res://scenes/design.tscn")


func _fmt(n: int) -> String:
	if n <= 0:
		return "—"
	return str(n)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if howto_layer.visible:
				howto_layer.visible = false
			else:
				_start()
		elif event.keycode == KEY_H:
			howto_layer.visible = not howto_layer.visible
		elif event.keycode == KEY_C:
			get_tree().change_scene_to_file("res://scenes/crew.tscn")
		elif event.keycode == KEY_ESCAPE:
			howto_layer.visible = false
