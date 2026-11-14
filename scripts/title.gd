extends Control

var howto_layer: Control
var ranks_layer: Control


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
	_build_ranks()
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

	var ranks := UIKit.button("RANKS", Vector2(80, 26))
	ranks.position = Vector2(450, 264)
	ranks.pressed.connect(func(): ranks_layer.visible = true)
	add_child(ranks)

	var daily_note := "BEST RUN  %s   ·   CMD %s" % [_fmt(GameState.best_score), GameState.player_name]
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

	# Body face here: the pixel font is uppercase-only, so it would render the
	# archive table name as PSCOMPPARS. The source name is PSCompPars.
	var credit := UIKit.label(
		"PLANETARY DATA  //  NASA EXOPLANET ARCHIVE  ·  PSCompPars",
		7, UIKit.DIM, false
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
		["03  SURVIVE", "Click a tile to preview the path. ENTER commits the move. Collect the required data nodes, then return to the lander and press EXTRACT before sols or delta-v run out."],
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


func _build_ranks() -> void:
	ranks_layer = Control.new()
	ranks_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ranks_layer.visible = false
	add_child(ranks_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.80)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ranks_layer.add_child(shade)

	var sheet := Panel.new()
	sheet.position = Vector2(92, 44)
	sheet.size = Vector2(456, 272)
	var paper := StyleBoxFlat.new()
	paper.bg_color = UIKit.PAPER
	paper.border_color = UIKit.INK
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(0)
	sheet.add_theme_stylebox_override("panel", paper)
	ranks_layer.add_child(sheet)

	var kicker := UIKit.label("AGENCY HONOURS BOARD  //  LOCAL RECORDS", 7, UIKit.ORANGE, true)
	kicker.position = Vector2(18, 16)
	kicker.size = Vector2(420, 10)
	sheet.add_child(kicker)
	var title := UIKit.label("WHO SAVED THE AGENCY?", 12, UIKit.INK, true)
	title.position = Vector2(18, 32)
	title.size = Vector2(420, 14)
	sheet.add_child(title)
	var note := UIKit.label("BEST RUN PER CALLSIGN  ·  STORED ON THIS TERMINAL", 5, Color("#4a4438"), true)
	note.position = Vector2(18, 48)
	note.size = Vector2(420, 8)
	sheet.add_child(note)

	var rows := GameState.leaderboard_top(5)
	if rows.is_empty():
		var empty := UIKit.label("NO FLIGHTS FILED YET. BE THE FIRST.", 8, Color("#4a4438"), true)
		empty.position = Vector2(18, 92)
		empty.size = Vector2(420, 14)
		sheet.add_child(empty)
	else:
		for i in range(rows.size()):
			var row: Dictionary = rows[i]
			var y := 76 + i * 28
			var rank := UIKit.label("%02d" % (i + 1), 9, UIKit.ORANGE, true)
			rank.position = Vector2(18, y)
			rank.size = Vector2(28, 12)
			sheet.add_child(rank)
			var who := UIKit.label(str(row.get("name", "CHIEF")), 9, UIKit.INK, true)
			who.position = Vector2(50, y)
			who.size = Vector2(120, 12)
			sheet.add_child(who)
			var score := UIKit.label("%d" % int(row.get("score", 0)), 9, UIKit.INK, true, HORIZONTAL_ALIGNMENT_RIGHT)
			score.position = Vector2(170, y)
			score.size = Vector2(64, 12)
			sheet.add_child(score)
			var grade := UIKit.label(str(row.get("grade", "C")), 9, UIKit.SIGNAL, true)
			grade.position = Vector2(242, y)
			grade.size = Vector2(20, 12)
			sheet.add_child(grade)
			var meta := UIKit.label("%s  ·  %s" % [str(row.get("date", "")), str(row.get("difficulty", "standard")).to_upper()], 5, Color("#4a4438"), true)
			meta.position = Vector2(270, y + 2)
			meta.size = Vector2(168, 8)
			sheet.add_child(meta)
			var rule := ColorRect.new()
			rule.color = Color(0.11, 0.10, 0.09, 0.18)
			rule.position = Vector2(18, y + 22)
			rule.size = Vector2(420, 1)
			sheet.add_child(rule)

	var close := UIKit.button("CLOSE", Vector2(88, 22))
	close.position = Vector2(350, 236)
	close.pressed.connect(func(): ranks_layer.visible = false)
	sheet.add_child(close)


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
		elif event.keycode == KEY_ESCAPE:
			howto_layer.visible = false
			ranks_layer.visible = false
