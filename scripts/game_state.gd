extends Node
## Orbit & Outplay - run state, mission architecture, and all rules.
## Autoloaded as "GameState". Scenes read/write this singleton.

signal changed

const START_BUDGET := 500.0
const START_APPROVAL := 62
const SECTORS_PER_RUN := 3
const OBJECTIVE_NODES := 4

const HULLS := [
	{
		"id": "pathfinder", "name": "PATHFINDER", "class": "General survey bus",
		"mass": 380.0, "cost": 170.0, "power_gen": 120.0, "delta_v": 30,
		"integrity": 4, "data_cap": 8, "thermal_res": 4, "move_range": 3,
		"science_mult": 1.0, "grant_mult": 1.0, "comms_bonus": 0,
		"perk": "+1 power capacity. No weaknesses.",
		"color": "#54e6d1",
	},
	{
		"id": "cryo", "name": "CRYO SURVEYOR", "class": "Cold-world specialist",
		"mass": 330.0, "cost": 150.0, "power_gen": 100.0, "delta_v": 34,
		"integrity": 3, "data_cap": 7, "thermal_res": 12, "move_range": 3,
		"science_mult": 1.0, "grant_mult": 1.0, "comms_bonus": 0,
		"perk": "Heat gain x0.6. +4 delta-v, thinner hull.",
		"color": "#7cc8ff",
	},
	{
		"id": "relay", "name": "DEEP RELAY", "class": "Data hauler",
		"mass": 560.0, "cost": 210.0, "power_gen": 170.0, "delta_v": 26,
		"integrity": 4, "data_cap": 14, "thermal_res": 5, "move_range": 3,
		"science_mult": 1.05, "grant_mult": 1.25, "comms_bonus": 12,
		"perk": "+25% grants. Deep buffer, -12% comms loss.",
		"color": "#ffc45c",
	},
	{
		"id": "hopper", "name": "HOPPER", "class": "Light lander",
		"mass": 240.0, "cost": 130.0, "power_gen": 80.0, "delta_v": 38,
		"integrity": 2, "data_cap": 6, "thermal_res": 2, "move_range": 4,
		"science_mult": 1.0, "grant_mult": 1.0, "comms_bonus": 0,
		"perk": "+8 delta-v. Two hits and it is over.",
		"color": "#b692ff",
	},
]

const ORBITS := [
	{"id": "low", "name": "LOW", "desc": "Balanced global survey.",
	 "heat_mult": 1.0, "science": 0.0, "alt_km": 400.0, "eclipse": 34, "passes": 5},
	{"id": "polar", "name": "POLAR", "desc": "+15% science, +10% heat per tile.",
	 "heat_mult": 1.1, "science": 0.15, "alt_km": 600.0, "eclipse": 36, "passes": 6},
	{"id": "high", "name": "HIGH", "desc": "-15% heat per tile, -10% science.",
	 "heat_mult": 0.85, "science": -0.10, "alt_km": 1200.0, "eclipse": 41, "passes": 4},
]

# Instrument families that directly address each objective. This is the
# "science traceability" rule from the NASA telescope-design game: a payload
# only earns the full science return when at least one instrument matches the
# question the mission was built to answer.
const OBJECTIVE_INSTRUMENTS := {
	"atmosphere": ["spectrometer", "camera"],
	"surface": ["camera", "radar"],
	"astro": ["camera", "spectrometer"],
	"geology": ["drill", "radar", "magnetometer"],
}

const VEHICLES := [
	{"id": "vector_l", "name": "VECTOR L", "cost": 55.0, "capacity": 450.0,
	 "note": "Light-lift. Cheap, tight mass margin."},
	{"id": "vector_m", "name": "VECTOR M", "cost": 100.0, "capacity": 850.0,
	 "note": "Medium-lift. The safe middle."},
	{"id": "vector_h", "name": "VECTOR H", "cost": 190.0, "capacity": 1400.0,
	 "note": "Heavy-lift. Expensive, room for anything."},
]

const INSTRUMENTS := [
	{
		"id": "camera", "name": "MULTISPECTRAL CAMERA", "mass": 35.0,
		"cost": 45.0, "power": 12.0, "science": 0.10, "data_cap": 1,
		"perk": "+10% science. Cheap, light, reliable.",
	},
	{
		"id": "spectrometer", "name": "SPECTROMETER", "mass": 45.0,
		"cost": 60.0, "power": 18.0, "science": 0.20, "data_cap": 0,
		"perk": "+20% science. The atmosphere workhorse.",
	},
	{
		"id": "radar", "name": "RADAR SOUNDER", "mass": 30.0,
		"cost": 50.0, "power": 14.0, "science": 0.0, "data_cap": 0,
		"perk": "Hazard shielding costs 0 power.",
	},
	{
		"id": "thermal", "name": "THERMAL IMAGER", "mass": 28.0,
		"cost": 40.0, "power": 10.0, "science": 0.0, "data_cap": 0,
		"perk": "Heat gain x0.7. Heat is the silent killer.",
	},
	{
		"id": "magnetometer", "name": "MAGNETOMETER", "mass": 22.0,
		"cost": 35.0, "power": 8.0, "science": 0.0, "data_cap": 0,
		"perk": "+1 power regeneration per turn.",
	},
	{
		"id": "drill", "name": "SUBSURFACE DRILL", "mass": 55.0,
		"cost": 55.0, "power": 16.0, "science": 0.0, "data_cap": 0,
		"perk": "BONUS DATA on rock worlds (arid, barren, volcanic).",
	},
]

const OBJECTIVES := [
	{
		"id": "atmosphere", "name": "CHARACTERIZE ATMOSPHERE",
		"quota": 3, "power_cap": 1, "dv": 0, "integrity": 0,
		"perk": "+1 power. 3 nodes to succeed.",
	},
	{
		"id": "surface", "name": "MAP THE SURFACE",
		"quota": 4, "power_cap": 0, "dv": 3, "integrity": 0,
		"perk": "+3 delta-v. Needs all 4.",
	},
	{
		"id": "astro", "name": "SEARCH FOR BIOSIGNATURES",
		"quota": 3, "power_cap": 0, "dv": 0, "integrity": 1,
		"perk": "+1 integrity. 2x temperate science.",
	},
	{
		"id": "geology", "name": "SURVEY PLANETARY GEOLOGY",
		"quota": 3, "power_cap": 0, "dv": 0, "integrity": 0,
		"perk": "+25% grants on rocky worlds.",
	},
]

const UPGRADES := [
	{"id": "rtg", "name": "RTG AUXILIARY", "cost": 70.0, "kind": "MODULE",
	 "desc": "+1 power regeneration.", "power_regen": 1},
	{"id": "radiator", "name": "DEPLOYABLE RADIATOR", "cost": 65.0, "kind": "MODULE",
	 "desc": "Heat gain -3 per move.", "thermal_res": 6},
	{"id": "wheel", "name": "REACTION WHEEL", "cost": 55.0, "kind": "MODULE",
	 "desc": "+4 delta-v in every sector.", "dv": 4},
	{"id": "armor", "name": "ABLATIVE ARMOR", "cost": 60.0, "kind": "MODULE",
	 "desc": "+2 maximum integrity.", "integrity": 2},
	{"id": "buffer", "name": "DEEP DATA BUFFER", "cost": 50.0, "kind": "MODULE",
	 "desc": "+4 data buffer. Less loss on long links.", "data_cap": 4},
	{"id": "antenna", "name": "HIGH-GAIN ANTENNA", "cost": 80.0, "kind": "MODULE",
	 "desc": "Comms loss -10%.", "comms_bonus": 10},
	{"id": "science_pack", "name": "SCIENCE PACKAGE", "cost": 75.0, "kind": "FIRMWARE",
	 "desc": "+15% science value.", "science": 0.15},
	{"id": "salvage", "name": "SALVAGE PROTOCOL", "cost": 70.0, "kind": "FIRMWARE",
	 "desc": "+30% grant from every sector.", "grant": 0.30},
	{"id": "repair", "name": "FIELD REPAIR KIT", "cost": 40.0, "kind": "MODULE",
	 "desc": "Restore 2 integrity now.", "repair": 2, "repeatable": true},
	{"id": "coolant", "name": "CRYO COOLANT LOOP", "cost": 55.0, "kind": "FIRMWARE",
	 "desc": "Venting heat also restores 1 extra power.", "vent_power": 1},
	{"id": "ion", "name": "ION THRUSTER", "cost": 60.0, "kind": "MODULE",
	 "desc": "+1 tile movement range each turn.", "move_range": 1},
]

const BIOME_INFO := {
	"temperate": {"name": "Temperate", "color": "#7fe08a"},
	"arid": {"name": "Arid", "color": "#ffb06a"},
	"cryo": {"name": "Cryo", "color": "#8fd4ff"},
	"volcanic": {"name": "Volcanic", "color": "#ff6d5e"},
	"barren": {"name": "Barren", "color": "#b8b0a0"},
	"methane": {"name": "Methane Lakes", "color": "#63d6c4"},
	"iron": {"name": "Iron Desert", "color": "#d97a50"},
	"sulfur": {"name": "Sulfur Plains", "color": "#f0dc5a"},
	"crystal": {"name": "Crystal Field", "color": "#b08cff"},
	"obsidian": {"name": "Obsidian Glass", "color": "#9b7bd6"},
	"ammonia": {"name": "Ammonia Ice", "color": "#72c8e8"},
	"carbon": {"name": "Carbon World", "color": "#9aa2b2"},
}

# Must match the BIOMES order in scripts/map_generator.gd (ocean is terrain-only;
# it is excluded from the playable planet pool because it is fully impassable).
const BIOME_ORDER := [
	"temperate", "arid", "cryo", "volcanic", "ocean", "barren",
	"methane", "iron", "sulfur", "crystal", "obsidian",
	"ammonia", "carbon",
]

var planets: Array = []
var data_meta: Dictionary = {}

var run: Dictionary = {}
var draft: Array = []
var current_sector: Dictionary = {}
var last_result: Dictionary = {}
var history: Array = []
var owned: Array = []
var shop_offers: Array = []
var best_score: int = 0

var rng := RandomNumberGenerator.new()

var pixel_font: Font
var body_font: Font
var audio_click: AudioStream
var audio_confirm: AudioStream
var audio_alarm: AudioStream
var audio_player: AudioStreamPlayer


func _ready() -> void:
	rng.randomize()
	_load_fonts()
	_load_planets()
	_load_audio()
	_load_best()
	UIKit.pixel_font = pixel_font
	UIKit.body_font = body_font


func _load_fonts() -> void:
	var pf := load("res://assets/ui/Silkscreen-Regular.ttf") as Font
	var pfb := load("res://assets/ui/Silkscreen-Bold.ttf") as Font
	var bf := load("res://assets/ui/IBMPlexMono-Regular.ttf") as Font
	pixel_font = pf if pf != null else ThemeDB.fallback_font
	# Bold pixel is used as a separate face when available.
	if pfb != null:
		pixel_font = pfb
	body_font = bf if bf != null else ThemeDB.fallback_font


func _load_planets() -> void:
	var txt := FileAccess.get_file_as_string("res://data/exoplanets.json")
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		planets = parsed.get("planets", [])
		data_meta = parsed.get("meta", {})
	else:
		push_error("Could not parse data/exoplanets.json")


func _load_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	audio_click = _load_ogg("res://assets/audio/click.wav")
	audio_confirm = _load_ogg("res://assets/audio/confirm.wav")
	audio_alarm = _load_ogg("res://assets/audio/alarm.wav")
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	add_child(audio_player)


func _load_ogg(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _exit_tree() -> void:
	if audio_player != null:
		audio_player.stop()
		audio_player.stream = null
	audio_click = null
	audio_confirm = null
	audio_alarm = null


func sfx(which: String) -> void:
	var stream: AudioStream = null
	match which:
		"click": stream = audio_click
		"confirm": stream = audio_confirm
		"alarm": stream = audio_alarm
	if stream != null and audio_player != null:
		audio_player.stream = stream
		audio_player.play()


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://orbit_save.cfg") == OK:
		best_score = int(cfg.get_value("score", "best", 0))


func _save_best(score: int) -> void:
	if score <= best_score:
		return
	best_score = score
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best_score)
	cfg.save("user://orbit_save.cfg")


# ---------------------------------------------------------------- run setup

func new_run() -> void:
	run = {
		"budget": START_BUDGET,
		"approval": START_APPROVAL,
		"hull": "",
		"vehicle": "",
		"orbit": "low",
		"instruments": [],
		"objective": "",
		"sector": 1,
		"seed": rng.randi_range(1000, 99999),
	}
	draft = []
	current_sector = {}
	last_result = {}
	history = []
	owned = []
	shop_offers = []
	roll_draft()
	changed.emit()


func hull() -> Dictionary:
	for h in HULLS:
		if str(h["id"]) == str(run.get("hull", "")):
			return h
	return {}


func vehicle() -> Dictionary:
	for v in VEHICLES:
		if str(v["id"]) == str(run.get("vehicle", "")):
			return v
	return {}


func objective() -> Dictionary:
	for o in OBJECTIVES:
		if str(o["id"]) == str(run.get("objective", "")):
			return o
	return {}


func science_fit() -> bool:
	var oid := str(run.get("objective", ""))
	var fits: Array = OBJECTIVE_INSTRUMENTS.get(oid, [])
	for iid in run.get("instruments", []):
		if str(iid) in fits:
			return true
	return false


func cml() -> Dictionary:
	var s := ship()
	if hull().is_empty():
		return {"level": 1, "label": "CONCEPT", "desc": "Idea only; select a bus."}
	if not bool(s.get("valid", false)):
		return {"level": 2, "label": "FEASIBILITY", "desc": "Resolve mass, power and budget."}
	var cap := maxf(1.0, float(s.get("capacity", 1.0)))
	var mass_margin := 1.0 - float(s.get("mass", 0.0)) / cap
	var gen := maxf(1.0, float(s.get("power_gen", 1.0)))
	var power_margin := (gen - float(s.get("power_draw", 0.0))) / gen
	if mass_margin >= 0.10 and power_margin >= 0.15 and science_fit():
		return {"level": 4, "label": "POINT DESIGN", "desc": "Margins and science traceability closed."}
	return {"level": 3, "label": "TRADE STUDY", "desc": "Valid, but margins or science fit are tight."}


func orbit_stats(p: Dictionary) -> Dictionary:
	var orb := orbit()
	var radius_earth := maxf(0.2, float(p.get("radius_earth", 1.0)))
	var mass_earth := maxf(0.05, float(p.get("mass_earth", 1.0)))
	var r_km := radius_earth * 6371.0 + float(orb.get("alt_km", 400.0))
	var mu := 398600.0 * mass_earth
	var period_min := (2.0 * PI * sqrt(pow(r_km, 3.0) / mu)) / 60.0
	return {
		"alt_km": int(orb.get("alt_km", 400.0)),
		"period_min": int(round(period_min)),
		"eclipse": int(orb.get("eclipse", 34)),
		"passes": int(orb.get("passes", 5)),
		"label": str(orb.get("name", "LOW")),
	}


func orbit_summary(p: Dictionary) -> String:
	var st := orbit_stats(p)
	return "ORBIT %s · %d km · %d min · %d%% eclipse · %d passes/day" % [
		str(st["label"]), int(st["alt_km"]), int(st["period_min"]),
		int(st["eclipse"]), int(st["passes"]),
	]


func instrument_list() -> Array:
	var out: Array = []
	for iid in run.get("instruments", []):
		for inst in INSTRUMENTS:
			if str(inst["id"]) == str(iid):
				out.append(inst)
	return out


func has_instrument(id: String) -> bool:
	return id in run.get("instruments", [])


func toggle_instrument(id: String) -> void:
	var list: Array = run.get("instruments", [])
	if id in list:
		list.erase(id)
	elif list.size() < 2:
		list.append(id)
	run["instruments"] = list
	sfx("click")
	changed.emit()


func orbit() -> Dictionary:
	for o in ORBITS:
		if str(o["id"]) == str(run.get("orbit", "low")):
			return o
	return ORBITS[0]


func select_orbit(id: String) -> void:
	run["orbit"] = id
	sfx("click")
	changed.emit()


func select_hull(id: String) -> void:
	run["hull"] = id
	sfx("click")
	changed.emit()


func select_vehicle(id: String) -> void:
	run["vehicle"] = id
	sfx("click")
	changed.emit()


func select_objective(id: String) -> void:
	run["objective"] = id
	sfx("click")
	changed.emit()


func ship() -> Dictionary:
	var h := hull()
	if h.is_empty():
		return {
			"mass": 0.0, "capacity": 0.0, "cost": 0.0, "power_gen": 0.0,
			"power_draw": 0.0, "delta_v": 0, "integrity": 0, "data_cap": 0,
			"thermal_res": 0, "science_mult": 1.0, "grant_mult": 1.0,
			"comms_bonus": 0, "heat_mult": 1.0, "valid": false,
			"warnings": ["Select a hull, launch vehicle, objective and 2 instruments."],
		}
	var v := vehicle()
	var o := objective()
	var warnings: Array = []
	var mass := float(h["mass"])
	var cost := float(h["cost"]) + float(v.get("cost", 0.0))
	var power_draw := 0.0
	var science := float(h["science_mult"])
	var data_cap := int(h["data_cap"])
	var comms := int(h["comms_bonus"])
	var heat_mult := 1.0
	var orb := orbit()
	var power_regen_bonus := 0
	var shield_cost := 1
	var bonus_data := 0

	for inst in instrument_list():
		mass += float(inst["mass"])
		cost += float(inst["cost"])
		power_draw += float(inst["power"])
		science += float(inst.get("science", 0.0))
		data_cap += int(inst.get("data_cap", 0))
		match str(inst["id"]):
			"thermal":
				heat_mult *= 0.7
			"magnetometer":
				power_regen_bonus += 1
			"radar":
				shield_cost = 0
			"drill":
				bonus_data = 1

	science += float(orb.get("science", 0.0))
	if science_fit():
		science += 0.10
	heat_mult *= float(orb.get("heat_mult", 1.0))

	var thermal_res := int(h["thermal_res"])
	var grant_mult := float(h["grant_mult"])
	var power_regen := 1 + power_regen_bonus
	if float(h["power_gen"]) >= 150.0:
		power_regen += 1
	if power_draw >= 36.0:
		power_regen -= 1
	power_regen = max(0, power_regen)

	# Objective + upgrades.
	var dv := int(h["delta_v"])
	var integrity := int(h["integrity"])
	if not o.is_empty():
		data_cap += 0
		dv += int(o.get("dv", 0))
		integrity += int(o.get("integrity", 0))
		if str(o["id"]) == "atmosphere":
			pass
	# upgrades
	for uid in owned:
		var up := _upgrade_by_id(str(uid))
		if up.is_empty():
			continue
		match str(up["id"]):
			"rtg":
				power_regen += 1
			"radiator":
				thermal_res += int(up.get("thermal_res", 0))
			"wheel":
				dv += int(up.get("dv", 0))
			"armor":
				integrity += int(up.get("integrity", 0))
			"buffer":
				data_cap += int(up.get("data_cap", 0))
			"antenna":
				comms += int(up.get("comms_bonus", 0))
			"science_pack":
				science += float(up.get("science", 0.0))
			"salvage":
				grant_mult += float(up.get("grant", 0.0))

	if v.is_empty():
		warnings.append("Choose a launch vehicle.")
	elif mass > float(v["capacity"]):
		warnings.append("Over mass limit: %.0f / %.0f kg" % [mass, float(v["capacity"])])
	if o.is_empty():
		warnings.append("Choose a mission objective.")
	elif instrument_list().size() < 2:
		warnings.append("Install exactly 2 instruments (%d/2)." % instrument_list().size())
	if cost > float(run.get("budget", START_BUDGET)):
		warnings.append("Over budget: $%.0fM / $%.0fM" % [cost, float(run.get("budget", START_BUDGET))])
	if h.get("id", "") == "relay" and v.get("id", "") == "vector_l":
		warnings.append("DEEP RELAY does not fit on VECTOR L.")

	var valid := warnings.is_empty() and not v.is_empty() and not o.is_empty() and instrument_list().size() == 2

	return {
		"mass": mass, "capacity": float(v.get("capacity", 0.0)),
		"cost": cost, "power_gen": float(h["power_gen"]),
		"power_draw": power_draw, "delta_v": dv, "integrity": integrity,
		"data_cap": data_cap, "thermal_res": thermal_res,
		"science_mult": science, "grant_mult": grant_mult,
		"comms_bonus": comms, "heat_mult": heat_mult,
		"power_regen_bonus": power_regen_bonus, "shield_cost": shield_cost,
		"bonus_data": bonus_data, "power_regen": power_regen,
		"orbit": str(orb.get("id", "low")),
		"science_fit": science_fit(),
		"valid": valid, "warnings": warnings,
	}


func quick_loadout() -> void:
	run["hull"] = "pathfinder"
	run["vehicle"] = "vector_m"
	run["orbit"] = "low"
	run["objective"] = "atmosphere"
	run["instruments"] = ["spectrometer", "thermal"]
	changed.emit()


func can_launch() -> bool:
	return bool(ship().get("valid", false))


func commit_design() -> bool:
	var s := ship()
	if not bool(s.get("valid", false)):
		return false
	if not bool(run.get("launched", false)):
		run["budget"] = float(run["budget"]) - float(s["cost"])
		run["design_cost"] = float(s["cost"])
		run["launched"] = true
	changed.emit()
	return true


func undo_design() -> void:
	if bool(run.get("launched", false)):
		run["budget"] = float(run["budget"]) + float(run.get("design_cost", 0.0))
		run["launched"] = false
	changed.emit()


# ------------------------------------------------------------- destinations

func roll_draft() -> void:
	if planets.is_empty():
		return
	var visited := {}
	for h in history:
		visited[str(h["planet"]["id"])] = true
	var pool: Array = []
	for p in planets:
		if not visited.has(str(p["id"])):
			pool.append(p)

	# Bias the draft toward one mild, one moderate and one harsh destination so
	# every choice is a real risk/reward decision.
	var mild: Array = []
	var mid: Array = []
	var harsh: Array = []
	for p in pool:
		var heat := int(p["game"]["heat"])
		if heat <= 26:
			mild.append(p)
		elif heat <= 62:
			mid.append(p)
		else:
			harsh.append(p)

	var picked: Array = []
	var used_biome := {}
	for bucket in [mild, mid, harsh]:
		if bucket.is_empty():
			continue
		var choices: Array = []
		for p in bucket:
			if not used_biome.has(str(p["biome"])):
				choices.append(p)
		var src: Array = choices if not choices.is_empty() else bucket
		var p: Dictionary = src[rng.randi_range(0, src.size() - 1)]
		if not picked.has(p):
			picked.append(p)
			used_biome[str(p["biome"])] = true

	# Fill to 3 if the buckets were thin.
	var guard := 0
	while picked.size() < 3 and guard < 200:
		guard += 1
		var p: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		if not picked.has(p):
			picked.append(p)
	picked.shuffle()
	draft = picked
	changed.emit()


# ---------------------------------------------------------------- sector

func begin_sector(planet: Dictionary) -> void:
	var s := ship()
	var o := objective()
	var heat := int(planet["game"]["heat"])
	var rad := int(planet["game"]["radiation"])
	var base_dv := int(planet["game"]["delta_v"])
	var dv := int(round(base_dv * (float(s["delta_v"]) / 30.0)))
	var sols := int(planet["game"]["sols"]) - (int(run.get("sector", 1)) - 1) * 2
	sols = max(18, sols)

	var heat_mult := float(s["heat_mult"])
	if str(hull().get("id", "")) == "cryo":
		heat_mult *= 0.6
	var heat_gain := int(round(float(heat) * 0.11)) - int(s["thermal_res"])
	heat_gain = int(round(float(heat_gain) * heat_mult))
	heat_gain = clampi(heat_gain, 1, 18)

	var power_max := 4 + int(float(s["power_gen"]) / 40.0)
	if str(o.get("id", "")) == "atmosphere":
		power_max += 1
	power_max += int(run.get("sector", 1)) - 1

	var comms_loss := clampi(int(planet["game"]["comms_loss"]) - int(s["comms_bonus"]), 0, 40)

	current_sector = {
		"planet": planet,
		"sector": int(run.get("sector", 1)),
		"quota": int(o.get("quota", 3)),
		"integrity": int(s["integrity"]),
		"integrity_max": int(s["integrity"]),
		"delta_v": dv,
		"delta_v_max": dv,
		"sols": sols,
		"sols_max": sols,
		"thermal": clampi(int(round(float(heat) * 0.32)), 0, 55),
		"heat_gain": heat_gain,
		"power": power_max,
		"power_max": power_max,
		"power_regen": int(s["power_regen"]),
		"move_range": int(hull().get("move_range", 3)) + _upgrade_int("move_range"),
		"shield_cost": int(s["shield_cost"]),
		"vent_power_extra": _upgrade_int("vent_power"),
		"comms_loss": comms_loss,
		"science_mult": float(s["science_mult"]),
		"grant_mult": float(s["grant_mult"]),
		"bonus_data": int(s["bonus_data"]),
		"data": 0,
		"thermal_res": int(s["thermal_res"]),
		"status": "active",
	}
	# Repair-kit upgrades that heal between sectors.
	var repair := int(run.get("pending_repair", 0))
	if repair > 0 and int(current_sector["integrity"]) < int(current_sector["integrity_max"]):
		current_sector["integrity"] = mini(
			int(current_sector["integrity_max"]),
			int(current_sector["integrity"]) + repair
		)
		run["pending_repair"] = 0
	sfx("confirm")
	changed.emit()


func _upgrade_int(field: String) -> int:
	var total := 0
	for uid in owned:
		var up := _upgrade_by_id(str(uid))
		if up.has(field):
			total += int(up[field])
	return total


func _upgrade_by_id(id: String) -> Dictionary:
	for up in UPGRADES:
		if str(up["id"]) == id:
			return up
	return {}


func owned_modules() -> Array:
	var out: Array = []
	for uid in owned:
		var up := _upgrade_by_id(str(uid))
		if not up.is_empty():
			out.append(up)
	return out


func finish_sector(extracted: bool, data: int, sec: Dictionary) -> void:
	var planet: Dictionary = sec["planet"]
	var quota := int(sec["quota"])
	var success := extracted and data >= quota
	var delivered := int(round(float(data) * (1.0 - float(sec["comms_loss"]) / 100.0)))
	delivered = clampi(delivered, 0, 4)
	var objective := objective()
	var science := float(planet["game"]["science"]) * float(sec["science_mult"]) * float(delivered)
	if str(objective.get("id", "")) == "astro" and str(planet["biome"]) == "temperate":
		science *= 2.0
	var grant := 0.0
	if success:
		grant = (55.0 + float(delivered) * 28.0) * float(sec["grant_mult"])
		if str(objective.get("id", "")) == "geology" and str(planet["biome"]) in [
			"arid", "barren", "volcanic", "iron", "crystal", "sulfur"
		]:
			grant *= 1.25
		if data >= OBJECTIVE_NODES:
			grant += 35.0
		grant = round(grant)
		run["budget"] = float(run["budget"]) + grant
	var approval_delta := 0
	if success:
		approval_delta = 8 + data * 2
	else:
		approval_delta = -24
	run["approval"] = clampi(int(run["approval"]) + approval_delta, 0, 100)

	# Data buffer overflow: the deep buffer lets you keep bonus nodes.
	if data > OBJECTIVE_NODES:
		data = OBJECTIVE_NODES
	var result := {
		"planet": planet,
		"sector": int(sec["sector"]),
		"success": success,
		"extracted": extracted,
		"data": data,
		"delivered": delivered,
		"quota": quota,
		"science": science,
		"grant": grant,
		"approval_delta": approval_delta,
		"comms_loss": int(sec["comms_loss"]),
		"integrity_left": int(sec["integrity"]),
		"delta_v_left": int(sec["delta_v"]),
		"sols_left": int(sec["sols"]),
		"thermal": int(sec["thermal"]),
		"objective": objective.get("name", ""),
	}
	last_result = result
	history.append(result)
	run["sector"] = int(run["sector"]) + 1
	last_result["run_over"] = int(run["approval"]) <= 0
	sfx("confirm" if success else "alarm")
	changed.emit()


func make_shop() -> void:
	var pool: Array = []
	for up in UPGRADES:
		if up["id"] in owned and not bool(up.get("repeatable", false)):
			continue
		pool.append(up)
	pool.shuffle()
	shop_offers = pool.slice(0, 3)
	changed.emit()


func buy_offer(index: int) -> bool:
	if index < 0 or index >= shop_offers.size():
		return false
	var up: Dictionary = shop_offers[index]
	var cost := float(up["cost"])
	if float(run["budget"]) < cost:
		sfx("alarm")
		return false
	run["budget"] = float(run["budget"]) - cost
	owned.append(str(up["id"]))
	if up.has("repair"):
		run["pending_repair"] = int(up["repair"])
	shop_offers.remove_at(index)
	sfx("confirm")
	changed.emit()
	return true


# ------------------------------------------------------------------ score

func calculate_score() -> Dictionary:
	var science := 0.0
	var efficiency := 0.0
	var successes := 0
	var delivered := 0
	for h in history:
		science += float(h["science"])
		delivered += int(h["delivered"])
		if bool(h["success"]):
			successes += 1
			efficiency += float(h["delta_v_left"]) * 8.0
			efficiency += float(h["integrity_left"]) * 55.0
	var approval_score := float(run.get("approval", 0)) * 12.0
	var budget_score := float(run.get("budget", 0)) * 1.5
	var completion := float(successes) * 220.0
	var total := int(round(science + efficiency + approval_score + budget_score + completion))
	if successes == SECTORS_PER_RUN:
		total += 400
	var grade := "C"
	if total >= 5200:
		grade = "S"
	elif total >= 4000:
		grade = "A"
	elif total >= 2800:
		grade = "B"
	_save_best(total)
	return {
		"total": total,
		"science": int(round(science)),
		"efficiency": int(round(efficiency)),
		"approval": int(round(approval_score)),
		"budget": int(round(budget_score)),
		"completion": int(round(completion)),
		"successes": successes,
		"delivered": delivered,
		"grade": grade,
	}


# ------------------------------------------------------------ ui helpers

func biome_color(biome: String) -> Color:
	return Color(str(BIOME_INFO.get(biome, {}).get("color", "#ffffff")))


func biome_name(biome: String) -> String:
	return str(BIOME_INFO.get(biome, {}).get("name", biome.capitalize()))


func planet_biome_index(biome: String) -> int:
	var idx := BIOME_ORDER.find(biome)
	return idx if idx >= 0 else 0


func planet_headline(p: Dictionary) -> String:
	var g: Dictionary = p.get("game", {})
	if int(g.get("heat", 0)) >= 60:
		return "Extreme thermal environment"
	if int(g.get("radiation", 0)) >= 45:
		return "High stellar radiation"
	if int(p.get("eq_temp_k", 0)) <= 190:
		return "Cryogenic surface"
	if str(p.get("biome", "")) == "temperate":
		return "Potentially habitable zone"
	return "Stable survey target"
