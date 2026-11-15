extends Control
const ORBIT_PLOT := preload("res://scripts/ui_orbit_plot.gd")

var howto_layer: Control
var ranks_layer: Control


class OrbitArc:
	extends Control
	## The planet's orbital track: one thin line sweeping through the gap
	## between the menu section and the title mark, with a tracked body riding
	## it. Same drawing language as the transfer plot, at screen scale.

	func _draw() -> void:
		var c := Vector2(size.x * 0.05, size.y * 0.52)
		var rx := size.x * 0.42
		var ry := size.y * 0.62
		var pts := PackedVector2Array()
		for i in range(97):
			var a := -1.45 + 2.40 * float(i) / 96.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_polyline(pts, Color(0.74, 0.84, 0.82, 0.12), 1.0)
		var m := c + Vector2(cos(0.35) * rx, sin(0.35) * ry)
		draw_circle(m, 1.5, Color(0.62, 0.78, 0.70, 0.34))


class RingMark:
	extends Control
	## Thin plotted orbits around the title lockup, like a mission patch drawn
	## on a light table: two broken arcs, four registration ticks, one tracked
	## body. It turns once every five minutes, so the mark breathes.

	const INK := Color(0.88, 0.92, 0.88)

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 76.0, -0.60, 2.30, 128, Color(INK, 0.24), 1.0, true)
		draw_arc(c, 76.0, 2.72, 5.66, 128, Color(INK, 0.10), 1.0, true)
		draw_arc(c, 84.0, -1.05, -0.15, 48, Color(INK, 0.09), 1.0, true)
		for i in 4:
			var a := -PI * 0.5 + TAU * float(i) / 4.0
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * 70.0, c + dir * 76.0, Color(INK, 0.26), 1.0)
		var m := c + Vector2(cos(-0.60), sin(-0.60)) * 76.0
		draw_circle(m, 1.6, Color(0.52, 0.68, 0.60, 0.9))
		draw_arc(m, 4.0, 0.0, TAU, 20, Color(0.52, 0.68, 0.60, 0.32), 1.0, true)


class SignalBars:
	extends Control
	## A live uplink readout: five bars breathing out of phase.

	var color := Color("#cf7a72")
	var bars := 5
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var gap := 2.0
		var bw := maxf(1.0, (size.x - gap * float(bars - 1)) / float(bars))
		for i in bars:
			var f := 0.5 + 0.5 * sin(_t * (1.3 + 0.21 * float(i)) + float(i) * 1.1)
			var h := maxf(2.0, size.y * (0.25 + 0.75 * f))
			draw_rect(
				Rect2(Vector2(float(i) * (bw + gap), size.y - h), Vector2(bw, h)),
				Color(color, 0.45 + 0.45 * f)
			)


class Ticker:
	extends Control
	## One line of telemetry scrolling right to left. The only thing on the
	## screen that moves in a straight line.

	var speed := 20.0
	var _label: Label
	var _w := 0.0

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label = UIKit.mono("", 6, UIKit.INK_FAINT)
		add_child(_label)

	func set_text(t: String) -> void:
		if _label == null:
			return
		_label.text = t
		_w = _label.get_combined_minimum_size().x
		_label.position = Vector2(0, 0)

	func _process(delta: float) -> void:
		if _w <= 0.0:
			return
		_label.position.x -= speed * delta
		if _label.position.x < -_w:
			_label.position.x = size.x


func _ready() -> void:
	MusicDirector.play("title")
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({
		# The planet is cropped by the left edge and slides behind the mission
		# section, so only its lit right limb is visible: a moon at the edge of
		# frame, which is what gives the screen its depth.
		"planet_center": Vector2(0.235, 0.66),
		"planet_size": 1.00,
		"planet_asset": "rocky",
		# The menu is the shop window: a brighter plate than the consoles, with
		# a visible sky, a lit limb and slow ambient motion.
		"dim": 0.12,
		"bright": 1.0,
		"nebula": 0.012,
		"planet_light": 0.52,
		# The disc edge is nearest-filtered, so a strong rim reads as a dotted
		# outline. Keep it low and let the halo carry the atmosphere.
		"atmosphere": 0.05,
		"sky_top": Color(0.020, 0.055, 0.085),
		"sky_bottom": Color(0.008, 0.030, 0.045),
		"halo": 0.9,
		"motion": true,
		"spin_speed": TAU / 90.0,
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
	# The title is the same terminal as every other screen: a header strip, one
	# narrow mission section on the left, small readout sections on the right,
	# and the agency mark floating in open sky between them. No single
	# enclosing box; the planet is the frame.
	var arc := OrbitArc.new()
	arc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arc)
	_scrim()

	_header()
	_menu_column()
	_title_mark()
	_cells()


func _header() -> void:
	var head := UIKit.label("MISSION TERMINAL", 22, UIKit.NAME, true)
	head.position = Vector2(10, 2)
	add_child(head)
	var sub := UIKit.mono(
		"EXOPLANET SURVEY AGENCY  ·  MISSION ARCHITECTURE DIVISION", 8, UIKit.DIM)
	sub.position = Vector2(10, 28)
	add_child(sub)

	var stamp := TextureRect.new()
	stamp.texture = load("res://assets/ui/skin_ops/stamp_approved.png")
	stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stamp.position = Vector2(532, 6)
	stamp.size = Vector2(90, 26)
	stamp.rotation = -0.06
	stamp.modulate = Color(1, 1, 1, 0.92)
	add_child(stamp)

	UIKit.hairline(self, 10, 42, 620, Color(UIKit.STEEL, 0.5))


func _menu_column() -> void:
	var panel := UIKit.sheet(self, 10, 50, 190, 272, false,
		Color("#0e1b1e"), Color(1, 1, 1, 0.8), 0.94)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel.add_child(v)

	v.add_child(UIKit.vspace(2))
	v.add_child(UIKit.mono("MISSION SELECT", 8, UIKit.MUTED))
	UIKit.hairline(v, 0, 0, 176, UIKit.LINE)
	v.add_child(UIKit.vspace(2))

	var begin := UIKit.button("BEGIN MISSION", Vector2(176, 28), true)
	begin.pressed.connect(_start)
	v.add_child(begin)

	var crew := UIKit.button("MISSION CONTROL", Vector2(176, 23))
	crew.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/crew.tscn"))
	v.add_child(crew)

	var daily := UIKit.button("DAILY RUN", Vector2(176, 23))
	daily.add_theme_font_size_override("font_size", 9)
	daily.pressed.connect(_start_daily)
	v.add_child(daily)

	var how := UIKit.button("HOW TO PLAY", Vector2(176, 23))
	how.add_theme_font_size_override("font_size", 9)
	how.pressed.connect(func(): howto_layer.visible = true)
	v.add_child(how)

	var story := UIKit.button("STORY", Vector2(176, 23))
	story.add_theme_font_size_override("font_size", 9)
	story.pressed.connect(_open_briefing)
	v.add_child(story)

	var ranks := UIKit.button("RANKS", Vector2(176, 23))
	ranks.add_theme_font_size_override("font_size", 9)
	ranks.pressed.connect(func(): ranks_layer.visible = true)
	v.add_child(ranks)

	# Small, unaccented and last: the terminal's own power switch, not a
	# mission action. Q is the shortcut.
	var quit := UIKit.button("QUIT", Vector2(176, 20))
	quit.add_theme_font_size_override("font_size", 8)
	quit.pressed.connect(_quit_game)
	v.add_child(quit)

	v.add_child(UIKit.vspace(2))
	UIKit.hairline(v, 0, 0, 176, Color(UIKit.STEEL, 0.55))
	v.add_child(UIKit.vspace(2))
	v.add_child(UIKit.mono("FLIGHT LOG", 7, UIKit.DIM))
	v.add_child(UIKit.mono(
		"BEST RUN  %s" % _fmt(GameState.best_score), 6, UIKit.INK_SOFT))
	v.add_child(UIKit.mono(
		"CMD %s  ·  DAILY %s" % [GameState.player_name, _daily_note()],
		6, UIKit.INK_FAINT))


func _daily_note() -> String:
	if CrewDirector.daily_key == CrewDirector.today_key() and CrewDirector.daily_best > 0:
		return str(CrewDirector.daily_best)
	return "—"


func _title_mark() -> void:
	_centred(UIKit.label("ORBIT", 30, UIKit.NAME, true), "ORBIT", 30, 421, 78, true)
	_centred(UIKit.label("&", 14, UIKit.ORANGE, false), "&", 14, 421, 106, false)
	_centred(UIKit.label("OUTPLAY", 22, UIKit.NAME, true), "OUTPLAY", 22, 421, 122, true)

	_centred(UIKit.mono("MISSION ARCHITECTURE ROGUELITE", 6, UIKit.ORANGE),
		"MISSION ARCHITECTURE ROGUELITE", 6, 421, 190, false)

	# Two explicit lines rather than one wrapped label: the wrap depends on the
	# font metrics, and this strip has to clear the readout sections below it.
	_centred(UIKit.mono("Design a spacecraft. Draft a real exoplanet.", 6, UIKit.MUTED),
		"Design a spacecraft. Draft a real exoplanet.", 6, 421, 200, false)
	_centred(UIKit.mono("Survive its surface. Save the agency.", 6, UIKit.MUTED),
		"Survive its surface. Save the agency.", 6, 421, 209, false)


func _tw(text: String, font_size: int, pixel: bool = false) -> float:
	## Measure with the same face the label will draw with. Labels clamp their
	## `size` to a minimum that is only refreshed after the node enters the
	## tree, so centring by box width is unreliable; measure instead.
	var f: Font = UIKit.pixel_font if pixel else UIKit.body_font
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _centred(l: Label, text: String, font_size: int, cx: float, y: float,
	pixel: bool = false) -> void:
	l.position = Vector2(cx - _tw(text, font_size, pixel) * 0.5, y)
	add_child(l)


func _cells() -> void:
	# Four small readout sections, the same bay-and-header treatment the design
	# and draft screens use. They sit on a 2x2 grid so the right side of the
	# frame reads as an instrument panel, not as decoration.
	var queue := _cell(300, 228, 158, 42, "SECTOR QUEUE")
	var pool := _queue_planets(3)
	for i in range(pool.size()):
		var p: Dictionary = pool[i]
		var x := 30.0 + float(i) * 32.0
		var thumb := TextureRect.new()
		thumb.texture = load(SpaceBackdrop.asset_for_planet(p)) as Texture2D
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		thumb.position = Vector2(x, 11)
		thumb.size = Vector2(18, 18)
		queue.add_child(thumb)
		var info: Dictionary = GameState.BIOME_INFO.get(str(p.get("biome", "barren")), {})
		var bar := ColorRect.new()
		bar.color = Color(str(info.get("color", "#b8b0a0")))
		bar.position = Vector2(x, 30)
		bar.size = Vector2(18, 2)
		queue.add_child(bar)

	var plot_cell := _cell(468, 228, 162, 42, "TRANSFER PLOT")
	var plot := ORBIT_PLOT.new()
	plot.position = Vector2(0, 8)
	plot.size = Vector2(100, 22)
	plot_cell.add_child(plot)
	var ly := UIKit.mono("18.6 LY", 6, UIKit.INK_SOFT)
	ly.position = Vector2(106, 9)
	plot_cell.add_child(ly)
	var sectors := UIKit.mono("3 SECTORS", 5, UIKit.INK_FAINT)
	sectors.position = Vector2(106, 20)
	plot_cell.add_child(sectors)

	var archive := _cell(300, 274, 158, 46, "ARCHIVE")
	var rows := [
		["WORLDS", str(GameState.planets.size())],
		["HULLS", str(GameState.HULLS.size())],
		["SECTORS", str(GameState.SECTORS_PER_RUN)],
	]
	for i in range(rows.size()):
		var y := 10.0 + float(i) * 8.0
		var key := UIKit.mono(str(rows[i][0]), 6, UIKit.INK_FAINT)
		key.position = Vector2(0, y)
		archive.add_child(key)
		# Right-aligned by measurement: a Label's `size` is clamped to its
		# minimum before it enters the tree, so a fixed box does not hold.
		var vtxt := str(rows[i][1])
		var val := UIKit.mono(vtxt, 6, UIKit.CREAM)
		val.position = Vector2(140.0 - _tw(vtxt, 6), y)
		archive.add_child(val)

	var comms := _cell(468, 274, 162, 46, "COMMS")
	var ticker := Ticker.new()
	ticker.position = Vector2(0, 11)
	ticker.size = Vector2(148, 10)
	comms.add_child(ticker)
	ticker.set_text(
		"TELEMETRY  ·  SOL 001  ·  ORBITAL INSERTION NOMINAL  ·  "
		+ "ARCHIVE SYNC %d WORLDS  ·  GRANTS CLEARED  ·  " % GameState.planets.size())
	var relay := UIKit.mono("UPLINK 98%  ·  RELAY 3/3", 6, UIKit.INK_FAINT)
	relay.position = Vector2(0, 27)
	comms.add_child(relay)


func _cell(x: float, y: float, w: float, h: float, title: String) -> Control:
	var panel := UIKit.sheet(self, x, y, w, h, false,
		Color("#0d1a1d"), Color(1, 1, 1, 0.8), 0.93)
	var body := UIKit.fill(panel)
	body.add_child(UIKit.mono(title, 6, UIKit.MUTED))
	UIKit.hairline(body, 0, 9, w - 16, Color(UIKit.STEEL, 0.5))
	return body


func _queue_planets(count: int) -> Array:
	## A stable sample of the archive, so the queue never flickers between
	## frames but still changes between builds as the data changes.
	var out: Array = []
	if GameState.planets.is_empty():
		return out
	var step: int = maxi(1, int(GameState.planets.size() / count))
	for i in range(count):
		out.append(GameState.planets[(i * step + 7) % GameState.planets.size()])
	return out


func _footer() -> void:
	UIKit.hairline(self, 10, 326, 620, Color(UIKit.STEEL, 0.5))
	var bars := SignalBars.new()
	bars.position = Vector2(10, 331)
	bars.size = Vector2(18, 9)
	add_child(bars)
	var sig := UIKit.mono("SIGNAL LOCKED", 6, UIKit.SIGNAL)
	sig.position = Vector2(32, 331)
	add_child(sig)

	# Body face here: the pixel font is uppercase-only, so it would render the
	# archive table name as PSCOMPPARS. The source name is PSCompPars.
	_centred(UIKit.mono("PLANETARY DATA  //  NASA EXOPLANET ARCHIVE  ·  PSCompPars",
		6, UIKit.INK_FAINT),
		"PLANETARY DATA  //  NASA EXOPLANET ARCHIVE  ·  PSCompPars", 6, 320, 331, false)

	var proto_text := "PROTOTYPE 1.0  ·  WEB BUILD"
	var proto := UIKit.mono(proto_text, 6, UIKit.INK_FAINT)
	proto.position = Vector2(630.0 - _tw(proto_text, 6), 331)
	add_child(proto)


func _scrim() -> void:
	## A soft left-edge vignette. The planet's lower limb runs under the footer
	## and the header, so those small type rows need their own ground without a
	## box being drawn around them.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(0.015, 0.030, 0.040, 0.52),
		Color(0.015, 0.030, 0.040, 0.26),
		Color(0.015, 0.030, 0.040, 0.0),
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.0, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 8
	var r := TextureRect.new()
	r.texture = t
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = Vector2.ZERO
	r.size = Vector2(240, 360)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)


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
	close.position = Vector2(462, 290)
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
	close.position = Vector2(350, 232)
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
