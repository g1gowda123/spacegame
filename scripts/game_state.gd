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
	{"id": "rtg", "name": "RTG AUXILIARY", "cost": 90.0, "kind": "MODULE",
	 "icon": "reactor", "desc": "+1 power regeneration.",
	 "plain": "A small nuclear battery: +1 power every turn.",
	 "power_regen": 1},
	{"id": "radiator", "name": "DEPLOYABLE RADIATOR", "cost": 85.0, "kind": "MODULE",
	 "icon": "aerogel", "desc": "Heat gain -3 per move.",
	 "plain": "Radiator panels: every move adds 3 less heat.",
	 "thermal_res": 3},
	{"id": "wheel", "name": "REACTION WHEEL", "cost": 75.0, "kind": "MODULE",
	 "icon": "sling", "desc": "+4 delta-v in every sector.",
	 "plain": "Saves fuel: start each sector with 4 extra delta-v.",
	 "dv": 4},
	{"id": "armor", "name": "ABLATIVE ARMOR", "cost": 80.0, "kind": "MODULE",
	 "icon": "harden", "desc": "+2 maximum integrity.",
	 "plain": "Extra hull plating: survive 2 more hits.",
	 "integrity": 2},
	{"id": "buffer", "name": "DEEP DATA BUFFER", "cost": 70.0, "kind": "MODULE",
	 "icon": "cache", "desc": "+4 data buffer. Comms loss -4%.",
	 "plain": "A bigger recorder: 4% less data lost on downlink.",
	 "data_cap": 4, "comms_bonus": 4},
	{"id": "antenna", "name": "HIGH-GAIN ANTENNA", "cost": 100.0, "kind": "MODULE",
	 "icon": "deepnet", "desc": "Comms loss -10%.",
	 "plain": "A larger dish: 10% less data lost on downlink.",
	 "comms_bonus": 10},
	{"id": "science_pack", "name": "SCIENCE PACKAGE", "cost": 95.0, "kind": "FIRMWARE",
	 "icon": "science", "desc": "+15% science value.",
	 "plain": "Better labs: each data node is worth 15% more science.",
	 "science": 0.15},
	{"id": "salvage", "name": "SALVAGE PROTOCOL", "cost": 90.0, "kind": "FIRMWARE",
	 "icon": "favor", "desc": "+30% grant from every sector.",
	 "plain": "Better contracts: each sector pays 30% more grant.",
	 "grant": 0.30},
	{"id": "repair", "name": "FIELD REPAIR KIT", "cost": 60.0, "kind": "MODULE",
	 "icon": "repair", "desc": "Restore 2 integrity next sector.",
	 "plain": "Spare parts: restore 2 hull integrity next sector.",
	 "repair": 2, "repeatable": true},
	{"id": "coolant", "name": "CRYO COOLANT LOOP", "cost": 75.0, "kind": "FIRMWARE",
	 "icon": "shield", "desc": "Venting heat also restores 1 extra power.",
	 "plain": "Venting heat also recovers 1 extra power.",
	 "vent_power": 1},
	{"id": "ion", "name": "ION THRUSTER", "cost": 80.0, "kind": "MODULE",
	 "icon": "ranger", "desc": "+1 tile movement range each turn.",
	 "plain": "A steady low-thrust engine: move 1 extra tile each turn.",
	 "move_range": 1},
]


# Free, permanent field commissions chosen between planets. Unlike the paid
# refit shop these never touch the grant balance; they are the Soul Knight
# style "pick one of three" progression beat.
const BUFFS := [
	{
		"id": "reactor", "name": "REACTOR OVERDRIVE", "rarity": "rare", "weight": 2,
		"icon": "reactor", "power_regen": 1,
		"desc": "Reactor output +1 power every turn.",
	},
	{
		"id": "harden", "name": "HARDENED BUS", "rarity": "common", "weight": 3,
		"icon": "harden", "integrity": 2,
		"desc": "+2 maximum hull integrity.",
	},
	{
		"id": "aerogel", "name": "AEROGEL SKIN", "rarity": "common", "weight": 3,
		"icon": "aerogel", "thermal_res": 3,
		"desc": "Heat gain -3 on every move.",
	},
	{
		"id": "sling", "name": "GRAVITY SLING", "rarity": "rare", "weight": 2,
		"icon": "sling", "dv": 4,
		"desc": "+4 delta-v at the start of every sector.",
	},
	{
		"id": "deepnet", "name": "DEEP-SPACE NET", "rarity": "rare", "weight": 2,
		"icon": "deepnet", "comms_bonus": 8,
		"desc": "Comms loss -8% on every downlink.",
	},
	{
		"id": "science", "name": "TARGETED SCIENCE", "rarity": "rare", "weight": 2,
		"icon": "science", "science": 0.12,
		"desc": "+12% science from every delivered node.",
	},
	{
		"id": "favor", "name": "AGENCY FAVOR", "rarity": "common", "weight": 3,
		"icon": "favor", "grant": 0.15,
		"desc": "+15% grant from every sector.",
	},
	{
		"id": "ranger", "name": "RANGER PACK", "rarity": "rare", "weight": 2,
		"icon": "ranger", "move_range": 1,
		"desc": "+1 tile movement range.",
	},
	{
		"id": "shield", "name": "REDUNDANT SYSTEMS", "rarity": "epic", "weight": 1,
		"icon": "shield", "shield_cost": 0,
		"desc": "Hazard shielding costs 0 power.",
	},
	{
		"id": "cache", "name": "DATA CACHE", "rarity": "common", "weight": 3,
		"icon": "cache", "start_data": 1,
		"desc": "Start every sector with +1 data.",
	},
	{
		"id": "legacy", "name": "MISSION LEGACY", "rarity": "epic", "weight": 1,
		"icon": "legacy", "score": 300,
		"desc": "+300 points in the final report.",
	},
	{
		"id": "repair", "name": "EMERGENCY REPAIR", "rarity": "common", "weight": 3,
		"icon": "repair", "sector_integrity": 1,
		"desc": "+1 hull integrity at every sector start.",
	},
]

const BUFF_MILESTONES := [1, 2]

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
var event_card: Dictionary = {}
var best_score: int = 0
var briefing_seen: bool = false
var player_name: String = "CHIEF"
var player_named: bool = false
var leaderboard: Array = []

var rng := RandomNumberGenerator.new()

var pixel_font: Font
var body_font: Font
var audio_click: AudioStream
var audio_confirm: AudioStream
var audio_alarm: AudioStream
var audio_move: AudioStream
var audio_hazard: AudioStream
var audio_deny: AudioStream
# A small round-robin pool: a single player cuts the previous cue when two land
# in the same frame (multi-node pickup, hazard + overheat).
const AUDIO_VOICES := 4
var audio_players: Array[AudioStreamPlayer] = []
var audio_voice := 0


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
	audio_move = _load_ogg("res://assets/audio/move.wav")
	audio_hazard = _load_ogg("res://assets/audio/hazard.wav")
	audio_deny = _load_ogg("res://assets/audio/deny.wav")
	for _i in range(AUDIO_VOICES):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		audio_players.append(player)


func _load_ogg(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _exit_tree() -> void:
	for player in audio_players:
		player.stop()
		player.stream = null
	audio_players.clear()
	audio_click = null
	audio_confirm = null
	audio_alarm = null
	audio_move = null
	audio_hazard = null
	audio_deny = null


func sfx(which: String) -> void:
	var stream: AudioStream = null
	var volume_db := 0.0
	match which:
		"click": stream = audio_click
		"confirm": stream = audio_confirm
		"alarm": stream = audio_alarm
		"move":
			stream = audio_move
			volume_db = -4.0
		"hazard": stream = audio_hazard
		"deny":
			stream = audio_deny
			volume_db = -5.0
	if stream != null and not audio_players.is_empty():
		var player := audio_players[audio_voice % audio_players.size()]
		audio_voice += 1
		player.volume_db = volume_db
		player.stream = stream
		player.play()


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://orbit_save.cfg") == OK:
		best_score = int(cfg.get_value("score", "best", 0))
		briefing_seen = bool(cfg.get_value("briefing", "seen", false))
		player_name = str(cfg.get_value("pilot", "name", "CHIEF"))
		player_named = bool(cfg.get_value("pilot", "named", false))
		var raw_lb := str(cfg.get_value("leaderboard", "entries", ""))
		if raw_lb != "":
			var parsed = JSON.parse_string(raw_lb)
			if parsed is Array:
				leaderboard = parsed


func _save_best(score: int) -> void:
	if score <= best_score:
		return
	best_score = score
	var cfg := ConfigFile.new()
	cfg.load("user://orbit_save.cfg")
	cfg.set_value("score", "best", best_score)
	cfg.set_value("briefing", "seen", briefing_seen)
	cfg.set_value("pilot", "name", player_name)
	cfg.set_value("pilot", "named", player_named)
	cfg.save("user://orbit_save.cfg")


func mark_briefing_seen() -> void:
	briefing_seen = true
	var cfg := ConfigFile.new()
	cfg.load("user://orbit_save.cfg")
	cfg.set_value("briefing", "seen", true)
	cfg.set_value("score", "best", best_score)
	cfg.set_value("pilot", "name", player_name)
	cfg.set_value("pilot", "named", player_named)
	cfg.save("user://orbit_save.cfg")


func has_player_name() -> bool:
	return player_named


func set_player_name(raw: String) -> void:
	var clean := raw.strip_edges().to_upper()
	clean = clean.substr(0, 12)
	player_name = clean if clean != "" else "CHIEF"
	player_named = true
	var cfg := ConfigFile.new()
	cfg.load("user://orbit_save.cfg")
	cfg.set_value("pilot", "name", player_name)
	cfg.set_value("pilot", "named", true)
	cfg.set_value("score", "best", best_score)
	cfg.set_value("briefing", "seen", briefing_seen)
	cfg.save("user://orbit_save.cfg")


func leaderboard_top(count: int = 5) -> Array:
	var rows := leaderboard.duplicate()
	rows.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	return rows.slice(0, maxi(0, count))


func record_run(total: int, grade: String) -> void:
	if bool(run.get("score_recorded", false)):
		return
	run["score_recorded"] = true
	_save_best(total)
	var entry := {
		"name": player_name if player_name != "" else "CHIEF",
		"score": total,
		"grade": grade,
		"date": Time.get_date_string_from_system(),
		"mode": str(run.get("mode", "campaign")),
		"difficulty": str(run.get("difficulty", "standard")),
		"successes": int(run.get("sector", 1)) - 1,
	}
	leaderboard.append(entry)
	# Keep the best row per callsign, then the global top eight.
	var best_by_name := {}
	for row in leaderboard:
		var key := str(row.get("name", "CHIEF"))
		if not best_by_name.has(key) or int(row.get("score", 0)) > int(best_by_name[key].get("score", 0)):
			best_by_name[key] = row
	var rows: Array = best_by_name.values()
	rows.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	leaderboard = rows.slice(0, 8)
	var cfg := ConfigFile.new()
	cfg.load("user://orbit_save.cfg")
	cfg.set_value("leaderboard", "entries", JSON.stringify(leaderboard))
	cfg.set_value("pilot", "name", player_name)
	cfg.set_value("pilot", "named", player_named)
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
		"seed_label": "",
		"score_recorded": false,
		"event_card": {},
		"event_resolved": true,
		"events_seen": [],
		"next_heat": 0,
		"next_dv": 0,
		"next_power": 0,
		"next_sol": 0,
		"next_integrity": 0,
		"next_data": 0,
		"bonus_science": 0,
		"risk_points": 0,
		"buffs": [],
		"pending_buff": false,
		"buff_choices": [],
		# Mission-control meta (set by CrewDirector.begin_run).
		"mode": "campaign",
		"players": 1,
		"crew_players": [],
		"difficulty": "standard",
		"score_mult": 1.0,
		"hazard_mod": 0,
		"heat_mod": 0,
		"crew_dv": 0,
		"crew_integrity": 0,
		"crew_science_mult": 1.0,
		"daily": false,
		"daily_key": "",
		"share_code": "",
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


const OBJECTIVE_ANALOG := {
	"atmosphere": "JWST / Hubble transmission spectroscopy",
	"surface": "Lunar Reconnaissance Orbiter mapping",
	"astro": "JWST biosignature survey",
	"geology": "Mars Reconnaissance Orbiter / Perseverance",
}


func objective_analog() -> String:
	return str(OBJECTIVE_ANALOG.get(str(run.get("objective", "")), "NASA Discovery-class survey"))


## Between-sector incidents. One card is drawn per gap; both options are
## deliberately real trade-offs, not a good/bad button.
const EVENTS := [
	{
		"id": "solar_storm", "title": "SOLAR STORM WARNING",
		"body": "A coronal front is tracking toward the next target.",
		"options": [
			{"label": "RIDE IT OUT", "desc": "Next sector starts with +8 heat.", "effect": {"next_heat": 8}},
			{"label": "POWER DOWN", "desc": "-1 approval, +1 power next sector.", "effect": {"approval": -1, "next_power": 1}},
		],
	},
	{
		"id": "private_donor", "title": "PRIVATE DONOR",
		"body": "A launch provider offers a no-strings grant. The board notices.",
		"options": [
			{"label": "TAKE THE GRANT", "desc": "+$50M, -2 approval.", "effect": {"budget": 50, "approval": -2}},
			{"label": "DECLINE", "desc": "+1 approval.", "effect": {"approval": 1}},
		],
	},
	{
		"id": "salvage_cache", "title": "SALVAGE CACHE",
		"body": "A spent upper stage is drifting near the transfer orbit.",
		"options": [
			{"label": "STRIP IT", "desc": "+$30M, +1 delta-v next sector.", "effect": {"budget": 30, "next_dv": 1}},
			{"label": "LEAVE IT", "desc": "+1 integrity next sector.", "effect": {"next_integrity": 1}},
		],
	},
	{
		"id": "cryo_leak", "title": "CRYO LOOP LEAK",
		"body": "The thermal loop is losing working fluid between missions.",
		"options": [
			{"label": "PATCH IT", "desc": "$25M, +1 integrity next sector.", "effect": {"budget": -25, "next_integrity": 1}},
			{"label": "TOP IT OFF", "desc": "+1 heat, +1 power next sector.", "effect": {"next_heat": 1, "next_power": 1}},
		],
	},
	{
		"id": "stellar_data", "title": "STELLAR ARCHIVE",
		"body": "A colleague offers a calibrated light-curve archive.",
		"options": [
			{"label": "BUY ACCESS", "desc": "$30M for +160 science.", "effect": {"budget": -30, "bonus_science": 160}},
			{"label": "SHARE LATER", "desc": "+1 approval.", "effect": {"approval": 1}},
		],
	},
	{
		"id": "crew_fatigue", "title": "CREW FATIGUE",
		"body": "Two flight controllers have been awake for 31 hours.",
		"options": [
			{"label": "REST ROTATION", "desc": "-1 sol next sector, +1 integrity.", "effect": {"next_sol": -1, "next_integrity": 1}},
			{"label": "PUSH THROUGH", "desc": "+1 delta-v, -1 integrity next sector.", "effect": {"next_dv": 1, "next_integrity": -1}},
		],
	},
	{
		"id": "rival_agency", "title": "RIVAL AGENCY",
		"body": "A competitor wants your raw survey data before publication.",
		"options": [
			{"label": "PUBLISH FIRST", "desc": "+2 approval, -$20M.", "effect": {"approval": 2, "budget": -20}},
			{"label": "SELL THE COPY", "desc": "+$35M, -1 approval.", "effect": {"budget": 35, "approval": -1}},
		],
	},
	{
		"id": "anomalous_signal", "title": "ANOMALOUS SIGNAL",
		"body": "The receiver hears a narrowband pulse during the cruise phase.",
		"options": [
			{"label": "INVESTIGATE", "desc": "-1 integrity, +180 science.", "effect": {"next_integrity": -1, "bonus_science": 180}},
			{"label": "LOG AND MOVE", "desc": "+1 power next sector.", "effect": {"next_power": 1}},
		],
	},
]


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
				comms += int(up.get("comms_bonus", 0))
			"antenna":
				comms += int(up.get("comms_bonus", 0))
			"science_pack":
				science += float(up.get("science", 0.0))
			"salvage":
				grant_mult += float(up.get("grant", 0.0))

	# Free field commissions are applied after paid refits.
	power_regen += _buff_int("power_regen")
	dv += _buff_int("dv")
	integrity += _buff_int("integrity")
	thermal_res += _buff_int("thermal_res")
	comms += _buff_int("comms_bonus")
	science += _buff_float("science")
	grant_mult += float(_buff_float("grant"))
	data_cap += _buff_int("data_cap")
	if _buff_has("shield"):
		shield_cost = 0
	if v.is_empty():
		warnings.append("Choose a launch vehicle.")
	elif mass > float(v["capacity"]):
		warnings.append("Over mass limit: %.0f / %.0f kg" % [mass, float(v["capacity"])])
	if o.is_empty():
		warnings.append("Choose a mission objective.")
	elif instrument_list().size() < 2:
		warnings.append("Install exactly 2 instruments (%d/2)." % instrument_list().size())
	# After launch the design cost is sunk. Compare against the budget that was
	# available when the mission was committed, not the remaining grant balance.
	var budget_check := float(run.get("budget", START_BUDGET))
	if bool(run.get("launched", false)):
		budget_check += float(run.get("design_cost", 0.0))
	if cost > budget_check:
		warnings.append("Over budget: $%.0fM / $%.0fM" % [cost, budget_check])
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
		"move_range": int(h["move_range"]) + _upgrade_int("move_range") + _buff_int("move_range"),
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
	# Draft from the run seed, not the global RNG: a shared campaign code must
	# reproduce the same three worlds on every machine, and a daily seed must
	# be identical for every player.
	var drng := RandomNumberGenerator.new()
	drng.seed = int(run.get("seed", 1)) + history.size() * 7919
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
		var p: Dictionary = src[drng.randi_range(0, src.size() - 1)]
		if not picked.has(p):
			picked.append(p)
			used_biome[str(p["biome"])] = true

	# Fill to 3 if the buckets were thin.
	var guard := 0
	while picked.size() < 3 and guard < 200:
		guard += 1
		var p: Dictionary = pool[drng.randi_range(0, pool.size() - 1)]
		if not picked.has(p):
			picked.append(p)
	# Deterministic Fisher-Yates so card order is part of the seed too.
	for i in range(picked.size() - 1, 0, -1):
		var j := drng.randi_range(0, i)
		var tmp = picked[i]
		picked[i] = picked[j]
		picked[j] = tmp
	draft = picked
	changed.emit()


# ---------------------------------------------------------------- sector

func sector_mode() -> String:
	return "relay" if int(run.get("sector", 1)) % 2 == 0 else "survey"


func roll_event() -> void:
	event_card = {}
	run["event_resolved"] = false
	var sector_no := int(run.get("sector", 1))
	if sector_no > SECTORS_PER_RUN:
		run["event_resolved"] = true
		return
	var seen: Array = run.get("events_seen", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(run.get("seed", 1)) + sector_no * 977
	var pick: Dictionary = {}
	for attempt in range(EVENTS.size()):
		var cand: Dictionary = EVENTS[(rng.randi_range(0, EVENTS.size() - 1) + attempt) % EVENTS.size()]
		if not seen.has(str(cand["id"])):
			pick = cand
			break
	if pick.is_empty():
		pick = EVENTS[rng.randi_range(0, EVENTS.size() - 1)]
	event_card = pick
	run["event_card"] = pick
	changed.emit()


func choose_event(choice_index: int) -> bool:
	var card: Dictionary = event_card
	if card.is_empty():
		card = run.get("event_card", {})
	if card.is_empty():
		return false
	var options: Array = card.get("options", [])
	if choice_index < 0 or choice_index >= options.size():
		return false
	var effect: Dictionary = options[choice_index].get("effect", {})
	if effect.has("budget"):
		run["budget"] = maxf(0.0, float(run["budget"]) + float(effect["budget"]))
	if effect.has("approval"):
		run["approval"] = clampi(int(run["approval"]) + int(effect["approval"]), 0, 100)
	run["next_heat"] = int(run.get("next_heat", 0)) + int(effect.get("next_heat", 0))
	run["next_dv"] = int(run.get("next_dv", 0)) + int(effect.get("next_dv", 0))
	run["next_power"] = int(run.get("next_power", 0)) + int(effect.get("next_power", 0))
	run["next_sol"] = int(run.get("next_sol", 0)) + int(effect.get("next_sol", 0))
	run["next_integrity"] = int(run.get("next_integrity", 0)) + int(effect.get("next_integrity", 0))
	run["next_data"] = int(run.get("next_data", 0)) + int(effect.get("next_data", 0))
	run["bonus_science"] = int(run.get("bonus_science", 0)) + int(effect.get("bonus_science", 0))
	if effect.has("repair"):
		run["next_integrity"] = int(run.get("next_integrity", 0)) + int(effect["repair"])
	var seen: Array = run.get("events_seen", [])
	seen.append(str(card.get("id", "")))
	run["events_seen"] = seen
	run["event_resolved"] = true
	run["event_card"] = {}
	event_card = {}
	sfx("confirm")
	changed.emit()
	return true


func begin_sector(planet: Dictionary) -> void:
	var s := ship()
	var o := objective()
	var heat := int(planet["game"]["heat"]) + int(run.get("next_heat", 0))
	var rad := int(planet["game"]["radiation"])
	var base_dv := int(planet["game"]["delta_v"])
	var dv := int(round(base_dv * (float(s["delta_v"]) / 30.0))) + int(run.get("next_dv", 0)) + int(run.get("crew_dv", 0))
	var sector_no := int(run.get("sector", 1))
	# Gentle quadratic run curve: 1.00 / 1.18 / 1.72. Not literal n² (1/4/9
	# would erase the refit power curve); the square is normalised to the
	# three-sector campaign. Balatro/Soul Knight both ramp in discrete steps,
	# so the extra hazard budget at sector 3 is the visible rule change.
	var threat := 1.0 + 0.18 * pow(float(sector_no - 1), 2.0)
	var sols := int(planet["game"]["sols"]) - (sector_no - 1) * 2
	sols = max(18, sols + int(run.get("next_sol", 0)))
	var integrity := maxi(1, int(s["integrity"]) + int(run.get("next_integrity", 0)) + int(run.get("crew_integrity", 0)) + _buff_int("sector_integrity"))
	# Sector 1 is a shakedown: a little more hull, a little more time, one extra
	# range so the first signal is reachable without a perfect route.
	var shakedown := sector_no == 1
	if shakedown:
		integrity += 2
		sols += 4

	var heat_mult := float(s["heat_mult"])
	if str(hull().get("id", "")) == "cryo":
		heat_mult *= 0.6
	var heat_gain := int(round(float(heat) * 0.11)) - int(s["thermal_res"])
	heat_gain = int(round(float(heat_gain) * heat_mult))
	heat_gain += int(run.get("heat_mod", 0))
	heat_gain = int(round(float(heat_gain) * threat))
	heat_gain = clampi(heat_gain, 1, 18)

	var power_max := 4 + int(float(s["power_gen"]) / 40.0)
	if str(o.get("id", "")) == "atmosphere":
		power_max += 1
	power_max += int(run.get("sector", 1)) - 1
	power_max += int(run.get("next_power", 0))

	var comms_loss := clampi(int(planet["game"]["comms_loss"]) - int(s["comms_bonus"]), 0, 40)
	var mode := sector_mode()
	var quota := 3 if mode == "relay" else int(o.get("quota", 3))
	var starting_integrity := integrity

	current_sector = {
		"planet": planet,
		"sector": int(run.get("sector", 1)),
		"mode": mode,
		"quota": quota,
		"integrity": starting_integrity,
		"integrity_max": starting_integrity,
		"delta_v": dv,
		"delta_v_max": dv,
		"sols": sols,
		"sols_max": sols,
		"thermal": clampi(int(round(float(heat) * 0.32)), 0, 55),
		"heat_gain": heat_gain,
		"power": power_max,
		"power_max": power_max,
		"power_regen": int(s["power_regen"]),
		"move_range": int(s.get("move_range", hull().get("move_range", 3))) + (1 if shakedown else 0),
		"shakedown": shakedown,
		"shield_cost": int(s["shield_cost"]),
		"vent_power_extra": _upgrade_int("vent_power"),
		"comms_loss": comms_loss,
		"science_mult": float(s["science_mult"]) * float(run.get("crew_science_mult", 1.0)),
		"grant_mult": float(s["grant_mult"]),
		"bonus_data": int(s["bonus_data"]) + int(run.get("next_data", 0)),
		"data": _buff_int("start_data"),
		"thermal_res": int(s["thermal_res"]),
		"hazard_mod": int(run.get("hazard_mod", 0)),
		"threat": threat,
		"status": "active",
	}
	# Repair kits bought in the debrief add integrity to the *next* sector. The
	# old `pending_repair` heal compared against `integrity_max` after integrity
	# had already been set to that max, so it could never fire.
	for key in ["next_heat", "next_dv", "next_power", "next_sol", "next_integrity", "next_data"]:
		run[key] = 0
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


func _buff_by_id(id: String) -> Dictionary:
	for b in BUFFS:
		if str(b["id"]) == id:
			return b
	return {}


func _buff_has(id: String) -> bool:
	return id in run.get("buffs", [])


func _buff_int(field: String) -> int:
	var total := 0
	for id in run.get("buffs", []):
		var b := _buff_by_id(str(id))
		if b.has(field):
			total += int(b[field])
	return total


func _buff_float(field: String) -> float:
	var total := 0.0
	for id in run.get("buffs", []):
		var b := _buff_by_id(str(id))
		if b.has(field):
			total += float(b[field])
	return total


func has_pending_buff() -> bool:
	return bool(run.get("pending_buff", false)) and not (run.get("buff_choices", []) as Array).is_empty()


func pending_buff_cards() -> Array:
	var out: Array = []
	for id in run.get("buff_choices", []):
		var b := _buff_by_id(str(id))
		if not b.is_empty():
			out.append(b)
	return out


func buff_milestone_number() -> int:
	var finished := int(run.get("sector", 1)) - 1
	var idx := BUFF_MILESTONES.find(finished)
	return idx + 1 if idx >= 0 else 0


func roll_buff_choices() -> void:
	if BUFFS.is_empty():
		return
	var pool: Array = []
	for b in BUFFS:
		if not _buff_has(str(b["id"])):
			pool.append(b)
	var drng := RandomNumberGenerator.new()
	drng.seed = int(run.get("seed", 1)) + int(run.get("sector", 1)) * 7919 + run.get("buffs", []).size() * 104729
	var picked: Array = []
	while picked.size() < 3 and not pool.is_empty():
		var total := 0
		for b in pool:
			total += int(b.get("weight", 1))
		var roll := drng.randi_range(1, total)
		var acc := 0
		for i in range(pool.size()):
			acc += int(pool[i].get("weight", 1))
			if roll <= acc:
				picked.append(str(pool[i]["id"]))
				pool.remove_at(i)
				break
	run["buff_choices"] = picked
	run["pending_buff"] = true
	changed.emit()


func choose_buff(index: int) -> bool:
	var choices: Array = run.get("buff_choices", [])
	if index < 0 or index >= choices.size():
		return false
	var id := str(choices[index])
	if _buff_has(id):
		return false
	var owned_buffs: Array = run.get("buffs", [])
	owned_buffs.append(id)
	run["buffs"] = owned_buffs
	run["pending_buff"] = false
	run["buff_choices"] = []
	sfx("confirm")
	changed.emit()
	return true


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
	var mode := str(sec.get("mode", "survey"))
	var cap := 4 if mode == "survey" else quota
	var success := extracted and data >= quota
	var delivered := int(round(float(data) * (1.0 - float(sec["comms_loss"]) / 100.0)))
	delivered = clampi(delivered, 0, cap)
	var objective := objective()
	var science := float(planet["game"]["science"]) * float(sec["science_mult"]) * float(delivered)
	if str(objective.get("id", "")) == "astro" and str(planet["biome"]) == "temperate":
		science *= 2.0
	var grant := 0.0
	if success:
		grant = (30.0 + float(delivered) * 15.0) * float(sec["grant_mult"])
		if str(objective.get("id", "")) == "geology" and str(planet["biome"]) in [
			"arid", "barren", "volcanic", "iron", "crystal", "sulfur"
		]:
			grant *= 1.25
		if data >= cap:
			grant += 20.0
		grant = round(grant)
		run["budget"] = float(run["budget"]) + grant
	var approval_delta := 0
	if success:
		approval_delta = 8 + data * 2
	else:
		approval_delta = -24
	run["approval"] = clampi(int(run["approval"]) + approval_delta, 0, 100)

	# Data buffer overflow: the deep buffer lets you keep bonus nodes.
	if data > cap:
		data = cap

	# Risk pays once per sector, but only twice per run. The player earns it
	# by extracting while a live front is still close to the lander.
	var risk_award := 0
	if success and int(sec.get("risk_bonus", 0)) > 0:
		risk_award = mini(1, 2 - int(run.get("risk_points", 0)))
		run["risk_points"] = int(run.get("risk_points", 0)) + risk_award
	var result := {
		"planet": planet,
		"sector": int(sec["sector"]),
		"success": success,
		"extracted": extracted,
		"mode": mode,
		"data": data,
		"delivered": delivered,
		"quota": quota,
		"risk_bonus": risk_award,
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
	var finished_sector := int(sec["sector"])
	run["sector"] = finished_sector + 1
	# Each debrief gets a fresh set of three cards. Offers persist within the
	# one debrief, but must not leak into the next sector in a shorter form.
	shop_offers.clear()
	last_result["run_over"] = int(run["approval"]) <= 0
	if int(run["sector"]) <= SECTORS_PER_RUN and int(run["approval"]) > 0:
		roll_event()
		if finished_sector in BUFF_MILESTONES:
			roll_buff_choices()
		else:
			run["pending_buff"] = false
			run["buff_choices"] = []
	else:
		run["event_card"] = {}
		run["event_resolved"] = true
		run["pending_buff"] = false
		run["buff_choices"] = []
	sfx("confirm" if success else "alarm")
	changed.emit()


func make_shop() -> void:
	var pool: Array = []
	for up in UPGRADES:
		if up["id"] in owned and not bool(up.get("repeatable", false)):
			continue
		pool.append(up)
	pool.shuffle()
	if pool.is_empty():
		shop_offers = []
		changed.emit()
		return
	# Keep one affordable option in every shop. Without this, a bad roll can
	# show three cards the player cannot buy after a low-payout sector, which
	# reads as a broken store rather than a hard choice.
	var budget := float(run.get("budget", 0))
	var affordable: Array = []
	for up in pool:
		if float(up["cost"]) <= budget:
			affordable.append(up)
	var anchor: Dictionary = affordable[0] if not affordable.is_empty() else pool[0]
	shop_offers = [anchor]
	for up in pool:
		if shop_offers.size() >= 3:
			break
		if str(up["id"]) == str(anchor["id"]):
			continue
		shop_offers.append(up)
	shop_offers.shuffle()
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
		run["next_integrity"] = int(run.get("next_integrity", 0)) + int(up["repair"])
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
	var risk := float(run.get("risk_points", 0)) * 120.0
	var bonus_science := float(run.get("bonus_science", 0))
	var buff_score := 0
	for id in run.get("buffs", []):
		buff_score += int(_buff_by_id(str(id)).get("score", 0))
	var subtotal := int(round(science + efficiency + approval_score + budget_score + completion + risk + bonus_science)) + buff_score
	if successes == SECTORS_PER_RUN:
		subtotal += 400
	# Difficulty scales the engineering result; crew goals are added after so
	# four-player co-op is rewarded for coordination, not punished by tier.
	var mult := float(run.get("score_mult", 1.0))
	var adjusted := int(round(float(subtotal) * mult))
	var difficulty_delta := adjusted - subtotal
	var crew_bonus := CrewDirector.goal_bonus()
	var total := adjusted + crew_bonus
	var grade := "C"
	var next_grade := "B"
	var next_gap := maxi(0, 2800 - total)
	if total >= 5200:
		grade = "S"
		next_grade = "MAX"
		next_gap = 0
	elif total >= 4000:
		grade = "A"
		next_grade = "S"
		next_gap = 5200 - total
	elif total >= 2800:
		grade = "B"
		next_grade = "A"
		next_gap = 4000 - total
	record_run(total, grade)
	return {
		"total": total,
		"science": int(round(science + bonus_science)),
		"efficiency": int(round(efficiency)),
		"approval": int(round(approval_score)),
		"budget": int(round(budget_score)),
		"completion": int(round(completion)),
		"risk": int(round(risk)),
		"risk_points": int(run.get("risk_points", 0)),
		"buff_score": buff_score,
		"buffs": run.get("buffs", []).duplicate(),
		"successes": successes,
		"delivered": delivered,
		"grade": grade,
		"next_grade": next_grade,
		"next_gap": next_gap,
		"subtotal": subtotal,
		"difficulty": str(run.get("difficulty", "standard")),
		"score_mult": mult,
		"difficulty_delta": difficulty_delta,
		"crew_bonus": crew_bonus,
		"crew_goals": CrewDirector.goal_rows(),
		"share_code": CrewDirector.code_for_run(),
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
