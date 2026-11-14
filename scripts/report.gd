extends Control
const SHIP_BUILD := preload("res://scripts/ship_build.gd")
## Final agency ledger and run summary.

var score: Dictionary = {}
var share_code := ""
var share_line: Label


func _ready() -> void:
	MusicDirector.play("report")
	score = GameState.calculate_score()
	share_code = str(score.get("share_code", CrewDirector.code_for_run()))
	CrewDirector.note_report_score(int(score.get("total", 0)))
	_build()


func _build() -> void:
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({
		"planet_center": Vector2(0.88, 0.70),
		"planet_size": 0.60,
		"planet_asset": "ringed",
		"dim": 0.22,
	})
	bg.modulate.a = 0.20

	var title := UIKit.head("FINAL MISSION REPORT", 12, UIKit.TEXT)
	title.position = Vector2(10, 6)
	title.size = Vector2(300, 18)
	add_child(title)
	var mode_label := "CAMPAIGN"
	if bool(GameState.run.get("daily", false)):
		mode_label = "DAILY " + str(GameState.run.get("daily_key", ""))
	var diff_name := str(CrewDirector.DIFFICULTIES.get(str(GameState.run.get("difficulty", "standard")), {}).get("name", "STANDARD"))
	var sub := UIKit.mono(
		"ORBIT + OUTPLAY  ·  NASA SPACE APPS 2026  ·  %s  ·  %s  ·  %d PLAYER%s" % [
			mode_label, diff_name, int(GameState.run.get("players", 1)),
			"" if int(GameState.run.get("players", 1)) == 1 else "S",
		], 7, UIKit.DIM)
	sub.position = Vector2(10, 22)
	add_child(sub)
	sub.size = Vector2(600, 16)

	_build_grade()
	_build_ledger()
	_build_footer()


func _build_grade() -> void:
	var p := UIKit.sheet(self, 10, 42, 266, 249)
	var c := UIKit.fill(p)

	var g := str(score.get("grade", "C"))
	var gc := UIKit.CYAN
	if g == "S":
		gc = UIKit.CYAN
	elif g == "A":
		gc = UIKit.GREEN
	elif g == "B":
		gc = UIKit.AMBER
	else:
		gc = UIKit.RED
	var grade := UIKit.label(g, 58, gc, true, HORIZONTAL_ALIGNMENT_CENTER)
	grade.position = Vector2(0, 0)
	grade.size = Vector2(266, 70)
	c.add_child(grade)
	var gl := UIKit.label("AGENCY GRADE", 7, UIKit.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	gl.position = Vector2(0, 66)
	gl.size = Vector2(266, 12)
	c.add_child(gl)

	var total := UIKit.label("%d" % int(score.get("total", 0)), 26, UIKit.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	total.position = Vector2(0, 84)
	total.size = Vector2(266, 32)
	c.add_child(total)
	var tl := UIKit.label("TOTAL SCORE", 7, UIKit.DIM, true, HORIZONTAL_ALIGNMENT_CENTER)
	tl.position = Vector2(0, 114)
	tl.size = Vector2(266, 12)
	c.add_child(tl)

	UIKit.hairline(c, 14, 128, 238, UIKit.LINE)
	var rows := [
		["SCIENCE", "+%d" % int(score.get("science", 0)), UIKit.TEXT],
		["EFFICIENCY", "+%d" % int(score.get("efficiency", 0)), UIKit.TEXT],
		["APPROVAL", "+%d" % int(score.get("approval", 0)), UIKit.TEXT],
		["FUNDS", "+%d" % int(score.get("budget", 0)), UIKit.TEXT],
		["COMPLETION/SWEEP", "+%d" % (int(score.get("completion", 0)) + (400 if int(score.get("successes", 0)) >= GameState.SECTORS_PER_RUN else 0)), UIKit.TEXT],
	]
	if int(score.get("risk", 0)) > 0:
		rows.append(["RISK BONUS", "+%d" % int(score.get("risk", 0)), UIKit.AMBER])
	if int(score.get("crew_bonus", 0)) > 0 or int(GameState.run.get("players", 1)) > 1:
		rows.append([
			"CREW GOALS %d/%d" % [CrewDirector.achieved_goals(), CrewDirector.total_goals()],
			"+%d" % int(score.get("crew_bonus", 0)), UIKit.GREEN,
		])
	rows.append(["DIFFICULTY x%.2f" % float(score.get("score_mult", 1.0)),
		"%+d" % int(score.get("difficulty_delta", 0)), UIKit.MUTED])
	var y := 132.0
	for row in rows:
		var l := UIKit.label(str(row[0]), 7, UIKit.MUTED, true)
		l.position = Vector2(14, y)
		l.size = Vector2(150, 12)
		c.add_child(l)
		var v := UIKit.label(str(row[1]), 8, row[2], true, HORIZONTAL_ALIGNMENT_RIGHT)
		v.position = Vector2(154, y)
		v.size = Vector2(98, 12)
		c.add_child(v)
		y += 12.0

	var next_grade := str(score.get("next_grade", "MAX"))
	var next_gap := int(score.get("next_gap", 0))
	var next_text := "S GRADE  ·  MAXIMUM"
	if next_grade != "MAX":
		next_text = "NEXT  +%d TO GRADE %s" % [next_gap, next_grade]
	var next := UIKit.label(next_text, 6, UIKit.CYAN if next_grade == "MAX" else UIKit.DIM, true)
	next.position = Vector2(14, 232)
	next.size = Vector2(238, 12)
	c.add_child(next)


func _build_ledger() -> void:
	var p := UIKit.sheet(self, 286, 42, 344, 249)
	var c := UIKit.fill(p)

	var h := UIKit.head("SECTOR LEDGER", 9, UIKit.AMBER)
	h.position = Vector2(12, 7)
	h.size = Vector2(220, 12)
	c.add_child(h)
	var best := UIKit.mono("BEST %d" % int(GameState.best_score), 7, UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	best.position = Vector2(210, 8)
	best.size = Vector2(122, 12)
	c.add_child(best)

	var y := 28.0
	for i in range(GameState.SECTORS_PER_RUN):
		if i < GameState.history.size():
			var hrow: Dictionary = GameState.history[i]
			var ok := bool(hrow.get("success", false))
			var planet: Dictionary = hrow.get("planet", {})
			var num := UIKit.label("%02d" % (i + 1), 8, UIKit.DIM, true)
			num.position = Vector2(12, y + 1)
			num.size = Vector2(22, 12)
			c.add_child(num)
			var nm := UIKit.label(str(planet.get("name", "—")), 8,
				UIKit.TEXT if ok else UIKit.RED, false)
			nm.position = Vector2(36, y + 1)
			nm.size = Vector2(150, 12)
			c.add_child(nm)
			var dat := UIKit.label("%d/%d" % [int(hrow.get("delivered", 0)), int(hrow.get("quota", 3))],
				8, UIKit.GREEN if ok else UIKit.RED, true, HORIZONTAL_ALIGNMENT_RIGHT)
			dat.position = Vector2(190, y + 1)
			dat.size = Vector2(46, 12)
			c.add_child(dat)
			var gr := UIKit.label("+$%dM" % int(hrow.get("grant", 0)), 8, UIKit.AMBER, true,
				HORIZONTAL_ALIGNMENT_RIGHT)
			gr.position = Vector2(240, y + 1)
			gr.size = Vector2(92, 12)
			c.add_child(gr)
		else:
			var dash := UIKit.label("%02d  —  NOT FLOWN" % (i + 1), 8, UIKit.DIM, true)
			dash.position = Vector2(12, y + 1)
			dash.size = Vector2(320, 12)
			c.add_child(dash)
		y += 20.0

	UIKit.hairline(c, 12, 92, 320, UIKit.LINE)
	var successes := int(score.get("successes", 0))
	var story := "Three clean surveys. The agency's\ncadence is now the envy of the field."
	if successes == 2:
		story = "Two clean surveys. A credible program\nwith room to grow."
	elif successes == 1:
		story = "One survey delivered. The agency\nsurvives, bruised but funded."
	elif successes == 0:
		story = "No data recovered. The review board\nis drafting a shutdown memo."
	if int(GameState.run.get("approval", 0)) <= 0:
		story = "Approval collapsed. The agency has\nbeen defunded."
	var narrative := UIKit.mono(story, 8, UIKit.TEXT)
	narrative.position = Vector2(12, 98)
	narrative.size = Vector2(320, 30)
	narrative.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(narrative)

	var cm := GameState.cml()
	var risk_note := ""
	if int(score.get("risk_points", 0)) > 0:
		risk_note = " · RISK %d" % int(score.get("risk_points", 0))
	var tier := SHIP_BUILD.tier(SHIP_BUILD.refit_count(GameState.owned))
	var stats := UIKit.label(
		"SHIP  %s · %s · %d MOD · %d COMM\nTARGETS FLOWN  %d / %d\nDATA DELIVERED  %d NODES\nGRANTS REMAINING  $%dM\nAPPROVAL  %d / 100\nCONCEPT  CML %d · %s%s" % [
			str(GameState.hull().get("name", "—")).to_upper(), str(tier["name"]),
			SHIP_BUILD.refit_count(GameState.owned) + int(GameState.run.get("instruments", []).size()),
			GameState.run.get("buffs", []).size(),
			GameState.history.size(), GameState.SECTORS_PER_RUN,
			int(score.get("delivered", 0)),
			int(GameState.run.get("budget", 0)),
			int(GameState.run.get("approval", 0)),
			int(cm["level"]), str(cm["label"]), risk_note,
		], 7, UIKit.MUTED, false)
	stats.position = Vector2(12, 146)
	stats.size = Vector2(300, 64)
	stats.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	stats.add_theme_constant_override("line_spacing", 0)
	c.add_child(stats)

	var last_planet: Dictionary = {}
	if not GameState.history.is_empty():
		last_planet = GameState.history[GameState.history.size() - 1].get("planet", {})
	var orbit_line := "ORBIT  LOW · 400 KM · 109 MIN · 34% ECLIPSE"
	if not last_planet.is_empty():
		var st := GameState.orbit_stats(last_planet)
		orbit_line = "ORBIT  %s · %d KM · %d MIN · %d%% ECLIPSE · %d PASSES/DAY" % [
			str(st["label"]), int(st["alt_km"]), int(st["period_min"]), int(st["eclipse"]),
			int(st["passes"])
		]
	var notes := UIKit.label(
		"SEGMENTS  LAUNCH · SPACE · GROUND · USER\n%s\nANALOG  %s" % [orbit_line, GameState.objective_analog().to_upper()],
		7, UIKit.DIM)
	notes.position = Vector2(12, 212)
	notes.size = Vector2(320, 44)
	notes.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	notes.add_theme_constant_override("line_spacing", 0)
	c.add_child(notes)



func _hr(x: float, y: float, w: float) -> HSeparator:
	var sep := UIKit.rule()
	sep.position = Vector2(x, y)
	sep.size = Vector2(w, 1)
	sep.custom_minimum_size = Vector2(w, 1)
	return sep


func _build_footer() -> void:
	var p := UIKit.panel(Color("#0b1522"), UIKit.SHEET_LINE)
	p.position = Vector2(10, 299)
	p.size = Vector2(620, 52)
	add_child(p)
	var c := UIKit.fill(p)

	var l := UIKit.head(
		"THE CAMPAIGN IS OVER  ·  YOUR AGENCY'S RECORD IS FILED",
		8, UIKit.CYAN)
	l.position = Vector2(12, 8)
	l.size = Vector2(360, 12)
	c.add_child(l)
	var s := UIKit.mono(
		"CAMPAIGN CODE  %s  ·  SAME WORLDS + STACK  ·  PRESS C TO COPY" % share_code,
		7, UIKit.MUTED)
	s.position = Vector2(12, 23)
	s.size = Vector2(420, 14)
	s.name = "ShareLine"
	share_line = s
	c.add_child(s)

	var again := UIKit.button("NEW CAMPAIGN >", Vector2(150, 28), true)
	again.position = Vector2(456, 11)
	again.pressed.connect(func():
		GameState.new_run()
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	)
	c.add_child(again)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			DisplayServer.clipboard_set(share_code)
			if share_line != null:
				share_line.text = "COPIED  %s  ·  PASTE IT IN MISSION CONTROL" % share_code
				share_line.add_theme_color_override("font_color", UIKit.GREEN)
			GameState.sfx("confirm")
