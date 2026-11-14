extends Node
## Mission-control meta layer: crew roles, difficulty, daily challenge and
## campaign share codes. Autoloaded as "CrewDirector".
##
## The design goal is co-op tension: every role owns a different success
## metric and the metrics pull against each other. A science lead wants one
## more node; the flight dynamics officer wants delta-v in the tank; the
## field commander wants the hull home intact; the director wants approval.
## One run, four definitions of a good mission.

signal meta_changed

const GOAL_BONUS := 180

const ROLES := {
	"director": {
		"name": "FLIGHT DIRECTOR", "short": "CDR", "color": "#54e6d1",
		"brief": "Own the architecture: hull, launch vehicle, orbit and budget.",
		"buff": "+$30M starting budget.",
		"goal": "Finish with approval 60 or higher.",
		"goal_short": "APPROVAL 60+",
	},
	"science": {
		"name": "SCIENCE LEAD", "short": "SCI", "color": "#b692ff",
		"brief": "Own the payload and the science trace: objective + instruments.",
		"buff": "+10% science value all run.",
		"goal": "Deliver 9 data nodes across the campaign.",
		"goal_short": "9 NODES",
	},
	"dynamics": {
		"name": "FLIGHT DYNAMICS", "short": "NAV", "color": "#7cc8ff",
		"brief": "Own the destination choice and the fuel plan.",
		"buff": "+3 delta-v in every sector.",
		"goal": "Finish the campaign with 12+ delta-v left.",
		"goal_short": "12 DELTA-V",
	},
	"ops": {
		"name": "FIELD COMMANDER", "short": "OPS", "color": "#7fe08a",
		"brief": "Own the surface route, extraction call and hull.",
		"buff": "+1 hull integrity in every sector.",
		"goal": "Complete all three sectors without a failure.",
		"goal_short": "3 CLEAN SECTORS",
	},
}


## Compact loadout alphabet for shareable mission-design codes.
const HULL_CODES := {"pathfinder": "PA", "cryo": "CR", "relay": "DR", "hopper": "HP"}
const VEHICLE_CODES := {"vector_l": "VL", "vector_m": "VM", "vector_h": "VH"}
const ORBIT_CODES := {"low": "OL", "polar": "OP", "high": "OH"}
const OBJECTIVE_CODES := {"atmosphere": "OA", "surface": "OS", "astro": "OB", "geology": "OG"}
const INSTRUMENT_CODES := {
	"camera": "CA", "spectrometer": "SP", "radar": "RA",
	"thermal": "TH", "magnetometer": "MG", "drill": "DR",
}

## Role sets for each crew size, tuned so two players still cover all four
## responsibilities. 1 player is solo: no role buffs, no role goals.
const ROLE_SETS := {
	2: [["director", "dynamics"], ["science", "ops"]],
	3: [["director"], ["science", "dynamics"], ["ops"]],
	4: [["director"], ["science"], ["dynamics"], ["ops"]],
}

const DIFFICULTIES := {
	"cadet": {
		"name": "CADET", "color": "#7fe08a",
		"desc": "Learn the trade. Extra budget and approval; fewer fronts.",
		"mods": "+$100M  ·  +10 approval  ·  -1 hazard front  ·  heat -1  ·  score x0.90",
		"short": "+$100M  ·  +10 appr  ·  -1 hazard  ·  heat -1  ·  x0.90",
		"budget": 100.0, "approval": 10, "hazard": -1, "heat": -1, "score": 0.90,
	},
	"standard": {
		"name": "STANDARD", "color": "#54e6d1",
		"desc": "The baseline brief. Every rule as documented.",
		"mods": "No budget, approval or hazard modifiers  ·  score x1.00",
		"short": "Baseline brief  ·  no modifiers  ·  x1.00",
		"budget": 0.0, "approval": 0, "hazard": 0, "heat": 0, "score": 1.0,
	},
	"director": {
		"name": "DIRECTOR", "color": "#ff6d5e",
		"desc": "Tight budget, hostile fronts. For players who know the loop.",
		"mods": "-$75M  ·  -10 approval  ·  +1 hazard front  ·  heat +1  ·  score x1.25",
		"short": "-$75M  ·  -10 appr  ·  +1 hazard  ·  heat +1  ·  x1.25",
		"budget": -75.0, "approval": -10, "hazard": 1, "heat": 1, "score": 1.25,
	},
}

const DAILY_SAVE := "user://orbit_daily.cfg"

var daily_key := ""
var daily_best := 0

var _layer: CanvasLayer
var _banner: PanelContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _last_scene := ""


func _ready() -> void:
	_load_daily()
	_build_overlay()


# ------------------------------------------------------------------ run setup

func begin_run(mode: String, players: int, difficulty_id: String, seed_override: int = 0,
		loadout: Dictionary = {}, seed_label: String = "") -> void:
	GameState.new_run()
	var run := GameState.run
	players = clampi(players, 1, 4)
	var diff_id := difficulty_id if DIFFICULTIES.has(difficulty_id) else "standard"
	var diff: Dictionary = DIFFICULTIES[diff_id]

	run["mode"] = mode
	run["players"] = players
	run["difficulty"] = diff_id
	run["score_mult"] = float(diff["score"])
	run["hazard_mod"] = int(diff["hazard"])
	run["heat_mod"] = int(diff["heat"])
	run["budget"] = GameState.START_BUDGET + float(diff["budget"])
	run["approval"] = clampi(GameState.START_APPROVAL + int(diff["approval"]), 1, 100)
	run["daily"] = mode == "daily"
	run["daily_key"] = ""
	run["seed_label"] = seed_label.strip_edges()

	if mode == "daily":
		run["daily_key"] = today_key()
		players = 1
		run["players"] = 1
		run["seed"] = daily_seed(today_key())
	elif seed_override > 0:
		run["seed"] = seed_override

	# Assign roles. A one-player crew is a solo flight: no buffs, no goals.
	var crew: Array = []
	run["crew_dv"] = 0
	run["crew_integrity"] = 0
	run["crew_science_mult"] = 1.0
	if players > 1:
		var sets: Array = ROLE_SETS.get(players, [])
		for i in range(mini(players, sets.size())):
			var role_ids: Array = sets[i]
			var row := {"name": "PLAYER %d" % (i + 1), "roles": role_ids}
			crew.append(row)
			for rid in role_ids:
				match str(rid):
					"director":
						run["budget"] = float(run["budget"]) + 30.0
					"science":
						run["crew_science_mult"] = float(run["crew_science_mult"]) * 1.10
					"dynamics":
						run["crew_dv"] = int(run["crew_dv"]) + 3
					"ops":
						run["crew_integrity"] = int(run["crew_integrity"]) + 1
	run["crew_players"] = crew

	# Optional imported design: a shared code can reproduce the exact stack.
	if not loadout.is_empty():
		for key in ["hull", "vehicle", "orbit", "objective"]:
			if loadout.has(key):
				run[key] = str(loadout[key])
		var insts: Array = loadout.get("instruments", [])
		if insts.size() >= 1:
			run["instruments"] = insts.slice(0, 2)
	run["share_code"] = code_for_run()

	# Re-roll the draft from the final seed so a shared code reproduces the
	# same three worlds on every machine.
	GameState.roll_draft()
	run["share_code"] = code_for_run()
	meta_changed.emit()
	GameState.changed.emit()


func today_key() -> String:
	# UTC so the daily seed is the same for every player worldwide.
	return Time.get_date_string_from_system(true)


func daily_seed(key: String) -> int:
	return 1000 + absi(int(hash("orbit-daily-" + key))) % 90000


# -------------------------------------------------------------------- roles

func crew_players() -> Array:
	if GameState == null or GameState.run == null:
		return []
	return GameState.run.get("crew_players", [])


func has_crew() -> bool:
	return crew_players().size() >= 2


func roles_text(role_ids: Array) -> String:
	var names: Array = []
	for rid in role_ids:
		names.append(str(ROLES.get(str(rid), {}).get("name", str(rid))))
	return " + ".join(names)


func role_owner(role_id: String) -> int:
	for i in range(crew_players().size()):
		var row: Dictionary = crew_players()[i]
		if role_id in row.get("roles", []):
			return i
	return -1


func goal_rows() -> Array:
	if GameState == null or GameState.run == null:
		return []
	var delivered := 0
	var successes := 0
	var dv_left := 0
	for h in GameState.history:
		delivered += int(h.get("delivered", 0))
		if bool(h.get("success", false)):
			successes += 1
		dv_left = int(h.get("delta_v_left", 0))
	if GameState.history.is_empty():
		dv_left = 0
	var approval := int(GameState.run.get("approval", 0))
	var rows: Array = []
	for p in crew_players():
		var roles: Array = p.get("roles", [])
		for rid in roles:
			var role: Dictionary = ROLES.get(str(rid), {})
			var ok := false
			match str(rid):
				"director":
					ok = approval >= 60
				"science":
					ok = delivered >= 9
				"dynamics":
					ok = dv_left >= 12
				"ops":
					ok = successes >= GameState.SECTORS_PER_RUN
			rows.append({
				"player": str(p.get("name", "PLAYER")),
				"role": str(role.get("name", rid)),
				"role_id": str(rid),
				"goal": str(role.get("goal_short", role.get("goal", ""))),
				"ok": ok, "bonus": GOAL_BONUS,
			})
	return rows


func goal_bonus() -> int:
	var total := 0
	for row in goal_rows():
		if bool(row["ok"]):
			total += int(row["bonus"])
	return total


func achieved_goals() -> int:
	var n := 0
	for row in goal_rows():
		if bool(row["ok"]):
			n += 1
	return n


func total_goals() -> int:
	return goal_rows().size()


# --------------------------------------------------------------- share codes

## Accepts any seed a player can type. Numeric strings keep their value,
## 0x-prefixed strings are hex, and everything else becomes a stable 31-bit
## hash. This removes the old requirement that every seed be a five-digit
## number wrapped in an OO- campaign code.
func seed_for_text(text: String) -> int:
	var t := text.strip_edges()
	if t == "":
		return 0
	var low := t.to_lower()
	if low.begins_with("seed="):
		t = t.substr(5).strip_edges()
	elif low.begins_with("seed:"):
		t = t.substr(5).strip_edges()
	low = t.to_lower()
	if low.begins_with("0x"):
		var hx := t.substr(2).hex_to_int()
		if hx != 0:
			return (hx & 0x7fffffff)
	if t.is_valid_int():
		var n := int(t)
		var masked := n & 0x7fffffff
		if masked != 0:
			return masked
		return 1
	var h := hash("orbit-seed:" + low) & 0x7fffffff
	return h if h != 0 else 1


func code_for_run() -> String:
	if GameState == null or GameState.run == null:
		return "OO-00000-S1"
	var seed_value := int(GameState.run.get("seed", 0))
	var diff := str(GameState.run.get("difficulty", "standard"))
	var letter := "S"
	if diff == "cadet":
		letter = "C"
	elif diff == "director":
		letter = "D"
	var players := int(GameState.run.get("players", 1))
	var base := "OO-%05X-%s%d" % [seed_value, letter, players]
	var load := loadout_blob()
	if load == "":
		return base
	return base + "-" + load


func loadout_blob() -> String:
	if GameState == null or GameState.run == null:
		return ""
	var run := GameState.run
	var hull_id := str(run.get("hull", ""))
	var veh_id := str(run.get("vehicle", ""))
	var orbit_id := str(run.get("orbit", ""))
	var obj_id := str(run.get("objective", ""))
	if hull_id == "" or veh_id == "" or orbit_id == "" or obj_id == "":
		return ""
	var insts: Array = run.get("instruments", [])
	if insts.size() < 2:
		return ""
	var a := str(INSTRUMENT_CODES.get(str(insts[0]), ""))
	var b := str(INSTRUMENT_CODES.get(str(insts[1]), ""))
	if a == "" or b == "":
		return ""
	return "%s%s%s%s-%s%s" % [
		str(HULL_CODES.get(hull_id, "")), str(VEHICLE_CODES.get(veh_id, "")),
		str(ORBIT_CODES.get(orbit_id, "")), str(OBJECTIVE_CODES.get(obj_id, "")),
		a, b,
	]


## Codes carry seed + difficulty + crew size, and optionally the exact design:
##   OO-043AF-D3                      same worlds, your design
##   OO-043AF-D3-PAVMOLOA-SPTH        same worlds, same stack
func parse_code(text: String) -> Dictionary:
	var raw := text.strip_edges()
	if raw == "":
		return {}
	var t := raw.to_upper().replace(" ", "")
	if t.begins_with("OO-"):
		var parts := t.split("-")
		if parts.size() >= 3:
			var seed_value := int(str(parts[1]).hex_to_int())
			if seed_value > 0:
				var tag := str(parts[2])
				var diff := "standard"
				match tag.substr(0, 1):
					"C":
						diff = "cadet"
					"D":
						diff = "director"
				var players := 1
				if tag.length() > 1:
					players = clampi(int(tag.substr(1, 1)), 1, 4)
				var out := {
					"seed": seed_value, "seed_label": raw,
					"difficulty": diff, "players": players,
				}
				if parts.size() >= 5:
					var loadout := _parse_loadout(str(parts[3]), str(parts[4]))
					if not loadout.is_empty():
						out["loadout"] = loadout
				return out
	# Not a legacy OO- code: treat the whole string as a seed. This also means
	# a malformed OO- string still runs as a text seed instead of being a dead
	# end; the player can see the resolved hex in the status line.
	var seed_value := seed_for_text(raw)
	if seed_value <= 0:
		return {}
	return {
		"seed": seed_value, "seed_label": raw,
		"difficulty": "standard", "players": 1,
	}


func _parse_loadout(blob: String, inst_blob: String) -> Dictionary:
	if blob.length() < 8 or inst_blob.length() < 4:
		return {}
	var out := {
		"hull": _reverse(HULL_CODES, blob.substr(0, 2)),
		"vehicle": _reverse(VEHICLE_CODES, blob.substr(2, 2)),
		"orbit": _reverse(ORBIT_CODES, blob.substr(4, 2)),
		"objective": _reverse(OBJECTIVE_CODES, blob.substr(6, 2)),
	}
	if str(out["hull"]) == "" or str(out["vehicle"]) == "" \
			or str(out["orbit"]) == "" or str(out["objective"]) == "":
		return {}
	var insts: Array = []
	for i in range(0, 4, 2):
		var id := _reverse(INSTRUMENT_CODES, inst_blob.substr(i, 2))
		if id == "":
			return {}
		insts.append(id)
	out["instruments"] = insts
	return out


func _reverse(table: Dictionary, code: String) -> String:
	for key in table:
		if str(table[key]) == code:
			return str(key)
	return ""


# --------------------------------------------------------------- daily best

func _load_daily() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(DAILY_SAVE) == OK:
		daily_key = str(cfg.get_value("daily", "key", ""))
		daily_best = int(cfg.get_value("daily", "best", 0))


func note_report_score(total: int) -> void:
	if GameState == null or GameState.run == null:
		return
	if not bool(GameState.run.get("daily", false)):
		return
	var key := str(GameState.run.get("daily_key", today_key()))
	if key == daily_key and total <= daily_best:
		return
	daily_key = key
	daily_best = total
	var cfg := ConfigFile.new()
	cfg.set_value("daily", "key", daily_key)
	cfg.set_value("daily", "best", daily_best)
	cfg.save(DAILY_SAVE)
	meta_changed.emit()


# ---------------------------------------------------------- handoff overlay

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_banner = UIKit.panel(Color(0.03, 0.06, 0.09, 0.96), UIKit.CYAN_DARK, 2)
	_banner.position = Vector2(80, 6)
	_banner.size = Vector2(480, 50)
	_banner.custom_minimum_size = Vector2(480, 50)
	_banner.visible = false
	_banner.modulate.a = 0.0
	_layer.add_child(_banner)

	var inner := Control.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(inner)
	_banner_title = UIKit.label("", 9, UIKit.CYAN, true)
	_banner_title.position = Vector2(10, 6)
	_banner_title.size = Vector2(456, 14)
	inner.add_child(_banner_title)
	_banner_sub = UIKit.label("", 7, UIKit.MUTED, false)
	_banner_sub.position = Vector2(10, 22)
	_banner_sub.size = Vector2(456, 22)
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_banner_sub)


func _process(_delta: float) -> void:
	if not is_instance_valid(get_tree().current_scene):
		return
	var path := str(get_tree().current_scene.scene_file_path)
	if path == _last_scene:
		return
	_last_scene = path
	if not has_crew():
		return
	var phase := _phase_from_path(path)
	if phase == "":
		return
	_show_handoff(phase)


func _phase_from_path(path: String) -> String:
	if path.ends_with("design.tscn"):
		return "design"
	if path.ends_with("draft.tscn"):
		return "draft"
	if path.ends_with("sector.tscn"):
		return "sector"
	if path.ends_with("debrief.tscn"):
		return "debrief"
	if path.ends_with("report.tscn"):
		return "report"
	return ""


func _show_handoff(phase: String) -> void:
	var role_id := "director"
	match phase:
		"draft":
			role_id = "dynamics"
		"sector":
			role_id = "ops"
		"design", "debrief":
			role_id = "director"
		"report":
			_show_text(
				"ALL HANDS  -  FILE THE REPORT",
				"The campaign is over. Compare each player's role goal, then run it back with a new seed."
			)
			return
	var owner := role_owner(role_id)
	if owner < 0:
		return
	var player: Dictionary = crew_players()[owner]
	var role: Dictionary = ROLES.get(role_id, {})
	var title := "PASS THE CONSOLE  ->  %s  -  %s" % [
		str(player.get("name", "PLAYER")), str(role.get("name", role_id))
	]
	var sub := "%s  GOAL: %s" % [str(role.get("brief", "")), str(role.get("goal", ""))]
	# Some phases are shared: name the co-owner so a four-player table knows
	# which half of the screen belongs to whom.
	if phase == "design":
		var sci := role_owner("science")
		if sci >= 0 and sci != owner:
			sub += "   PAYLOAD CALL: %s." % str(crew_players()[sci].get("name", "PLAYER"))
	elif phase == "sector":
		var sci2 := role_owner("science")
		if sci2 >= 0 and sci2 != owner:
			sub += "   DATA CALL: %s." % str(crew_players()[sci2].get("name", "PLAYER"))
	_show_text(title, sub, Color(str(role.get("color", "#54e6d1"))))


func _show_text(title: String, sub: String, color: Color = UIKit.CYAN) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.22)
	_banner_tween.tween_interval(4.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(func(): _banner.visible = false)


func show_toast(title: String, sub: String) -> void:
	_show_text(title, sub)
