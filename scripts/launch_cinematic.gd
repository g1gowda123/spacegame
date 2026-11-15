class_name LaunchCinematic
extends Control
## Cinematic Spacecraft Launch & Interplanetary Transit Sequence for Orbit & Outplay.
##
## Integrates a multi-phase launch into the mission architecture flow:
## - Phase 1: Launch Preparation (Pad, spotlights, gantry, status checklist, countdown)
## - Phase 2: Engine Ignition (Nozzle glow, flame trenches, smoke billows, pad illumination, screen shake)
## - Phase 3: Liftoff (Clamp release, swing arm retraction, vertical acceleration, camera tracking)
## - Phase 4: Atmospheric Ascent & Sky Darkening (Atmospheric scattering falloff, rushing clouds, Max-Q shock collar, altitude scaling)
## - Phase 5: Space Transition & Planet Reveal (Departure planet receding, stage separation, target exoplanet approach, Hohmann vector arc, NASA telemetry)
## - Phase 6: Gameplay Transition (Orbital de-orbit maneuver, seamless fade into sector.tscn preserving all GameState data)
##
## Also supports:
## - Interplanetary orbital departure for subsequent planetary sectors (sector > 1) linking previous & next world
## - Skip Launch option (SPACE / ESC / Skip Button)
## - Reduced-effects mode (--reduced-fx)
## - Native pixel-art sprite overlays with vector geometric fallbacks
## - Accurate spacecraft (Pathfinder, Cryo, Relay, Hopper) and vehicle (Vector L/M/H) visuals

enum Phase {
	PREPARATION,
	IGNITION,
	LIFTOFF,
	ASCENT,
	SPACE,
	TRANSITION,
	DONE
}

# --- Nodes & Layers ---
var _world: Control
var _sky_rect: ColorRect
var _sky_canvas: Control
var _distant_mountains_root: Control
var _midground_terrain_root: Control
var _ground_root: Control
var _foreground_surface: Control
var _ground_illumination: Control
var _pad_mount: Control
var _gantry_tower: Control
var _gantry_sprite: Sprite2D
var _gantry_arm_node: Node2D
var _pad_sprite: Sprite2D
var _gantry_arms: Array[Line2D] = []
var _clouds_root: Control
var _space_root: Control
var _space_backdrop: SpaceBackdrop
var _earth_disc: Control
var _trajectory_overlay: Control
var _target_planet_root: Control
var _target_planet_halo: Control
var _target_planet_rect: TextureRect
var _target_planet_label: Label
var _rocket_root: Node2D
var _rocket_body: Node2D
var _fairing_left: Node2D
var _fairing_right: Node2D
var _ship_sprite: Sprite2D
var _booster_sprite: Sprite2D
var _exhaust_plume: Node2D
var _orbital_plume: Node2D
var _plume_smoke: Node2D
var _plume_frames: Array[Texture2D] = []
var _plume_billows: Array[Sprite2D] = []
var _cloud_textures: Array[Texture2D] = []
var _shock_cone: Polygon2D
var _smoke_particles: CPUParticles2D
var _pad_smoke_left: CPUParticles2D
var _pad_smoke_right: CPUParticles2D
var _spotlights: Node2D
var _hud_layer: CanvasLayer
var _countdown_label: Label
var _phase_label: Label
var _status_vbox: VBoxContainer
var _status_items: Array[Dictionary] = []
var _mission_plaque: PanelContainer
var _skip_button: Button

# --- Planetary Launch Environment ---
var _env: Dictionary = {}
var _env_sky_zenith: Color = Color("#183860")
var _env_sky_horizon: Color = Color("#5c9cd8")
var _current_sky_zenith: Color = Color("#183860")
var _current_sky_horizon: Color = Color("#5c9cd8")
var _env_sun_color: Color = Color(1.0, 0.95, 0.8, 0.9)
var _env_mountain_color: Color = Color("#1e3344")
var _env_mountain_highlight: Color = Color("#4a7090")
var _env_mountain_style: String = "peaks"
var _env_mid_terrain_color: Color = Color("#1a4030")
var _env_ground_base_color: Color = Color("#1c3d28")
var _env_ground_detail_color: Color = Color("#2e5938")
var _env_ground_accent_color: Color = Color("#4e8055")
var _env_atmosphere_haze: Color = Color(0.65, 0.82, 1.0, 0.22)
var _sun_offset_y: float = 0.0
var _engine_light_glow: float = 0.0
var _mountain_polygon: PackedVector2Array = PackedVector2Array()
var _midground_polygon: PackedVector2Array = PackedVector2Array()

# --- Audio Players ---
var _audio_beep: AudioStreamPlayer
var _audio_ignition: AudioStreamPlayer
var _audio_rumble: AudioStreamPlayer
var _audio_staging: AudioStreamPlayer

# --- State ---
var _phase: Phase = Phase.PREPARATION
var _time: float = 0.0
var _phase_time: float = 0.0
var _shake_amount: float = 0.0
var _is_subsequent: bool = false
var _reduced_fx: bool = false
var _no_fairing: bool = false
var _vector_fairing: bool = false
var _skipping: bool = false
var _transitioned: bool = false

# --- Rocket & Vehicle Data ---
var _hull_id: String = "pathfinder"
var _hull_name: String = "PATHFINDER"
var _hull_color: Color = Color("#54e6d1")
var _veh_id: String = "vector_m"
var _veh_name: String = "VECTOR M"
var _objective_title: String = "EXOPLANET SURVEY"

# --- Planetary & Mission Data ---
var _planet_name: String = "TARGET EXOPLANET"
var _planet_biome: String = "temperate"
var _distance_ly: float = 14.2
var _planet_gravity: float = 1.0
var _planet_temp: float = 288.0
var _planet_star: String = "SOLAR SYSTEM"
var _planet_star_type: String = "G2V"
var _planet_escape_kms: float = 11.2
var _current_sector_no: int = 1
var _planet_info: Dictionary = {}

# --- Departure Planet Data (Earth in Sector 1, Previous Planet in Sector > 1) ---
var _departure_name: String = "EARTH (CAPE CANAVERAL)"
var _departure_biome: String = "earth"
var _departure_info: Dictionary = {}

# --- Motion Parameters ---
var _altitude: float = 0.0
var _velocity: float = 0.0
var _acceleration: float = 0.0
var _countdown_val: int = 10
var _last_beep_val: int = -1
var _fairing_split: float = 0.0
var _booster_dropped: bool = false
var _booster_offset_y: float = 0.0
var _target_planet_scale: float = 0.38


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_parse_arguments()
	_load_mission_data()
	_setup_audio()
	_build_scene_layers()
	_build_hud()
	
	if _is_subsequent:
		_start_subsequent_sequence()
	else:
		_start_launch_sequence()


func _parse_arguments() -> void:
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for raw in args:
		var arg := str(raw)
		if arg == "--reduced-fx":
			_reduced_fx = true
		elif arg == "--subsequent":
			_is_subsequent = true
		elif arg == "--full-launch":
			_is_subsequent = false
		elif arg == "--skip-launch":
			call_deferred("_skip_launch")
		elif arg == "--no-fairing":
			_no_fairing = true
		elif arg == "--vector-fairing":
			_vector_fairing = true


func _load_mission_data() -> void:
	_current_sector_no = int(GameState.run.get("sector", 1))
	if _current_sector_no > 1 and not ("--full-launch" in OS.get_cmdline_args() or "--full-launch" in OS.get_cmdline_user_args()):
		_is_subsequent = true

	var h: Dictionary = GameState.hull()
	if not h.is_empty():
		_hull_id = str(h.get("id", "pathfinder"))
		_hull_name = str(h.get("name", "PATHFINDER"))
		_hull_color = Color(str(h.get("color", "#54e6d1")))

	var v: Dictionary = GameState.vehicle()
	if not v.is_empty():
		_veh_id = str(v.get("id", "vector_m"))
		_veh_name = str(v.get("name", "VECTOR M"))

	var o: Dictionary = GameState.objective()
	if not o.is_empty():
		_objective_title = str(o.get("name", "SURVEY MISSION"))

	# Retrieve the actual selected target planet from GameState:
	var sec: Dictionary = GameState.current_sector
	var p: Dictionary = sec.get("planet", {}) if not sec.is_empty() else {}
	if p.is_empty() and not GameState.draft.is_empty():
		p = GameState.draft[0]
	if p.is_empty() and GameState.planets.size() > 0:
		p = GameState.planets[0]

	if not p.is_empty():
		_planet_name = str(p.get("name", "EXOPLANET")).to_upper()
		_planet_biome = str(p.get("biome", "temperate"))
		_distance_ly = float(p.get("distance_ly", 14.2))
		_planet_gravity = float(p.get("gravity_g", 1.0))
		_planet_temp = float(p.get("eq_temp_k", 288.0))
		_planet_star = str(p.get("star", "HOST STAR")).to_upper()
		_planet_star_type = str(p.get("star_type", "G2V"))
		_planet_escape_kms = float(p.get("escape_kms", 11.2))

	_planet_info = get_biome_info(_planet_biome)

	# Departure World setup:
	# The spacecraft launches from the ACTUAL SELECTED PLANET:
	if _current_sector_no <= 1 or not _is_subsequent:
		_departure_name = _planet_name
		_departure_biome = _planet_biome
		_departure_info = _planet_info
	else:
		if GameState.history.size() > 0:
			var prev_p: Dictionary = GameState.history[GameState.history.size() - 1].get("planet", {})
			_departure_name = str(prev_p.get("name", "SECTOR 1 BASE")).to_upper()
			_departure_biome = str(prev_p.get("biome", "barren"))
			_departure_info = get_biome_info(_departure_biome)
		else:
			_departure_name = _planet_name
			_departure_biome = _planet_biome
			_departure_info = _planet_info

	# Initialize planetary launch environment based on target exoplanet
	_env = get_launch_environment(_planet_biome)
	_env_sky_zenith = _env.get("sky_zenith", Color("#163558"))
	_env_sky_horizon = _env.get("sky_horizon", Color("#5896d0"))
	_current_sky_zenith = _env_sky_zenith
	_current_sky_horizon = _env_sky_horizon
	_env_sun_color = _env.get("sun_color", Color(1.0, 0.94, 0.82, 0.95))
	_env_mountain_color = _env.get("mountain_color", Color("#182e40"))
	_env_mountain_highlight = _env.get("mountain_highlight", Color("#3e6888"))
	_env_mountain_style = str(_env.get("mountain_style", "peaks"))
	_env_mid_terrain_color = _env.get("mid_terrain_color", Color("#163d2c"))
	_env_ground_base_color = _env.get("ground_base_color", Color("#183824"))
	_env_ground_detail_color = _env.get("ground_detail_color", Color("#2b5435"))
	_env_ground_accent_color = _env.get("ground_accent_color", Color("#4d8256"))
	_env_atmosphere_haze = _env.get("atmosphere_haze", Color(0.65, 0.82, 1.0, 0.22))

	_mountain_polygon = _build_ridge_polygon(_env_mountain_style, 235.0, 70.0, 33, 640.0)
	_midground_polygon = _build_ridge_polygon(_env_mountain_style, 262.0, 32.0, 25, 640.0)


static func get_biome_info(b_id: String) -> Dictionary:
	match b_id:
		"temperate":
			return {
				"name": "TEMPERATE",
				"color": Color("#4fa8ff"),
				"rim": Color(0.40, 0.75, 1.0, 0.95),
				"terrain": "CONTINENTAL BIOSPHERE • OCEANS & FORESTS",
				"atmosphere": "NITROGEN-OXYGEN 1.0 ATM • MOISTURE",
			}
		"arid":
			return {
				"name": "ARID",
				"color": Color("#e8a848"),
				"rim": Color(0.95, 0.70, 0.30, 0.90),
				"terrain": "DUNES & BASINS • CRACKED SALT FLATS",
				"atmosphere": "THIN CO2 / SILICATE DUST HAZE",
			}
		"cryo":
			return {
				"name": "CRYO",
				"color": Color("#8eedff"),
				"rim": Color(0.55, 0.92, 1.0, 0.95),
				"terrain": "FRACTURED NITROGEN ICE • CRYOGLACIERS",
				"atmosphere": "TENUOUS NITROGEN / METHANE ICE FOG",
			}
		"volcanic":
			return {
				"name": "VOLCANIC",
				"color": Color("#ff5c28"),
				"rim": Color(1.0, 0.40, 0.15, 0.95),
				"terrain": "ACTIVE CALDERAS • BASALT MAGMA CRUST",
				"atmosphere": "DENSE SO2 / VOLCANIC ASH SHROUD",
			}
		"ocean":
			return {
				"name": "OCEAN",
				"color": Color("#2b8aff"),
				"rim": Color(0.20, 0.60, 1.0, 0.95),
				"terrain": "GLOBAL OCEAN • VOLCANIC ARCHIPELAGOS",
				"atmosphere": "HIGH VAPOR PRESSURE • DENSE STORMS",
			}
		"barren":
			return {
				"name": "BARREN",
				"color": Color("#a8b4c0"),
				"rim": Color(0.70, 0.78, 0.88, 0.75),
				"terrain": "CRATERED REGOLITH • IMPACT HIGHLANDS",
				"atmosphere": "NEAR-VACUUM EXOSPHERE",
			}
		"methane":
			return {
				"name": "METHANE LAKES",
				"color": Color("#3ee0a8"),
				"rim": Color(0.25, 0.90, 0.70, 0.90),
				"terrain": "HYDROCARBON SEAS • CRYOGENIC DELTAS",
				"atmosphere": "OPAQUE METHANE-ETHANE GAS HAZE",
			}
		"iron":
			return {
				"name": "IRON DESERT",
				"color": Color("#d85830"),
				"rim": Color(0.90, 0.38, 0.20, 0.85),
				"terrain": "FERROUS OXIDE DUNES • MAGNETIC ANOMALIES",
				"atmosphere": "DRY CO2 • IRON OXIDE DUST SUSPENSION",
			}
		"sulfur":
			return {
				"name": "SULFUR PLAINS",
				"color": Color("#d4e040"),
				"rim": Color(0.85, 0.92, 0.25, 0.90),
				"terrain": "SULFURIC ACID CALDERAS • CORROSIVE VENTS",
				"atmosphere": "TOXIC H2SO4 AEROSOL CANOPY",
			}
		"crystal":
			return {
				"name": "CRYSTAL FIELD",
				"color": Color("#d862e8"),
				"rim": Color(0.88, 0.45, 0.95, 0.90),
				"terrain": "FACETED QUARTZ SPIRES • REFRACTION RIDGES",
				"atmosphere": "SILICA CONDENSATION MIST",
			}
		"obsidian":
			return {
				"name": "OBSIDIAN GLASS",
				"color": Color("#8e52a8"),
				"rim": Color(0.60, 0.35, 0.85, 0.85),
				"terrain": "VITREOUS BASALT GLASS • SHARD PLATEAUS",
				"atmosphere": "HEAVY BASALTIC AEROSOL HAZE",
			}
		"ammonia":
			return {
				"name": "AMMONIA ICE",
				"color": Color("#b888f0"),
				"rim": Color(0.75, 0.55, 0.98, 0.90),
				"terrain": "AMMONIA HYDRATE GLACIERS • SLUSH BASINS",
				"atmosphere": "DENSE NITROGEN-AMMONIA FOG",
			}
		"carbon":
			return {
				"name": "CARBON WORLD",
				"color": Color("#78828e"),
				"rim": Color(0.50, 0.56, 0.65, 0.75),
				"terrain": "GRAPHITE STRATA • HYDROCARBON SOOT PLAINS",
				"atmosphere": "CARBON MONOXIDE / SOOT VEIL",
			}
		_:
			return {
				"name": "EXOPLANET",
				"color": Color("#4fa8ff"),
				"rim": Color(0.40, 0.75, 1.0, 0.85),
				"terrain": "UNEXPLORED EXOPLANETARY TERRAIN",
				"atmosphere": "UNVERIFIED ATMOSPHERIC COLUMN",
			}


static func get_launch_environment(b_id: String) -> Dictionary:
	match b_id:
		"temperate":
			return {
				"sky_zenith": Color("#163558"),
				"sky_horizon": Color("#5896d0"),
				"sun_color": Color(1.0, 0.94, 0.82, 0.95),
				"mountain_color": Color("#182e40"),
				"mountain_highlight": Color("#3e6888"),
				"mountain_style": "peaks",
				"mid_terrain_color": Color("#163d2c"),
				"ground_base_color": Color("#183824"),
				"ground_detail_color": Color("#2b5435"),
				"ground_accent_color": Color("#4d8256"),
				"atmosphere_haze": Color(0.65, 0.82, 1.0, 0.22),
				"terrain_label": "CONTINENTAL HIGHLANDS",
			}
		"arid":
			return {
				"sky_zenith": Color("#582c16"),
				"sky_horizon": Color("#d98842"),
				"sun_color": Color(1.0, 0.90, 0.65, 0.95),
				"mountain_color": Color("#4a2012"),
				"mountain_highlight": Color("#884224"),
				"mountain_style": "mesas",
				"mid_terrain_color": Color("#783a1a"),
				"ground_base_color": Color("#a65822"),
				"ground_detail_color": Color("#c47632"),
				"ground_accent_color": Color("#df9e50"),
				"atmosphere_haze": Color(0.95, 0.70, 0.40, 0.28),
				"terrain_label": "DUNE SEA & SANDSTONE MESAS",
			}
		"cryo":
			return {
				"sky_zenith": Color("#0c1c34"),
				"sky_horizon": Color("#3a749c"),
				"sun_color": Color(0.85, 0.95, 1.0, 0.85),
				"mountain_color": Color("#142a40"),
				"mountain_highlight": Color("#5088b0"),
				"mountain_style": "jagged",
				"mid_terrain_color": Color("#224460"),
				"ground_base_color": Color("#36607c"),
				"ground_detail_color": Color("#5a8ca8"),
				"ground_accent_color": Color("#96cee6"),
				"atmosphere_haze": Color(0.55, 0.85, 1.0, 0.24),
				"terrain_label": "FRACTURED CRYOGLACIERS",
			}
		"volcanic":
			return {
				"sky_zenith": Color("#220806"),
				"sky_horizon": Color("#8a260e"),
				"sun_color": Color(1.0, 0.45, 0.15, 0.95),
				"mountain_color": Color("#180606"),
				"mountain_highlight": Color("#ff4818"),
				"mountain_style": "caldera",
				"mid_terrain_color": Color("#2c0e0c"),
				"ground_base_color": Color("#1e1212"),
				"ground_detail_color": Color("#3a1e1c"),
				"ground_accent_color": Color("#ff4514"),
				"atmosphere_haze": Color(0.95, 0.35, 0.15, 0.25),
				"terrain_label": "BASALT CALDERAS & MAGMA FISSURES",
			}
		"barren":
			return {
				"sky_zenith": Color("#060a10"),
				"sky_horizon": Color("#1a2230"),
				"sun_color": Color(1.0, 1.0, 1.0, 0.95),
				"mountain_color": Color("#161e28"),
				"mountain_highlight": Color("#3a485a"),
				"mountain_style": "peaks",
				"mid_terrain_color": Color("#263040"),
				"ground_base_color": Color("#343e4e"),
				"ground_detail_color": Color("#465264"),
				"ground_accent_color": Color("#66768c"),
				"atmosphere_haze": Color(0.50, 0.60, 0.75, 0.08),
				"terrain_label": "CRATERED REGOLITH HIGHLANDS",
			}
		"ocean":
			return {
				"sky_zenith": Color("#0c2844"),
				"sky_horizon": Color("#3676a2"),
				"sun_color": Color(1.0, 0.95, 0.85, 0.92),
				"mountain_color": Color("#102c44"),
				"mountain_highlight": Color("#2e688e"),
				"mountain_style": "peaks",
				"mid_terrain_color": Color("#184460"),
				"ground_base_color": Color("#143c56"),
				"ground_detail_color": Color("#245c7a"),
				"ground_accent_color": Color("#4c9ec2"),
				"atmosphere_haze": Color(0.40, 0.75, 1.0, 0.25),
				"terrain_label": "SEAMOUNT LAUNCH ATOLL",
			}
		"methane":
			return {
				"sky_zenith": Color("#0a2420"),
				"sky_horizon": Color("#246e5e"),
				"sun_color": Color(0.80, 1.0, 0.85, 0.85),
				"mountain_color": Color("#0c2c28"),
				"mountain_highlight": Color("#2e8070"),
				"mountain_style": "jagged",
				"mid_terrain_color": Color("#14443c"),
				"ground_base_color": Color("#184840"),
				"ground_detail_color": Color("#266c5e"),
				"ground_accent_color": Color("#44b29c"),
				"atmosphere_haze": Color(0.35, 0.88, 0.70, 0.28),
				"terrain_label": "HYDROCARBON DELTA SHORES",
			}
		"crystal":
			return {
				"sky_zenith": Color("#220e34"),
				"sky_horizon": Color("#6c328c"),
				"sun_color": Color(0.95, 0.80, 1.0, 0.95),
				"mountain_color": Color("#26103c"),
				"mountain_highlight": Color("#a244ce"),
				"mountain_style": "spires",
				"mid_terrain_color": Color("#421a64"),
				"ground_base_color": Color("#4e2274"),
				"ground_detail_color": Color("#7236a6"),
				"ground_accent_color": Color("#be6cf0"),
				"atmosphere_haze": Color(0.80, 0.45, 0.95, 0.25),
				"terrain_label": "PRISMATIC QUARTZ SPIRE FIELD",
			}
		"sulfur":
			return {
				"sky_zenith": Color("#24280c"),
				"sky_horizon": Color("#747e1e"),
				"sun_color": Color(1.0, 0.95, 0.4, 0.90),
				"mountain_color": Color("#2a2e0e"),
				"mountain_highlight": Color("#889426"),
				"mountain_style": "peaks",
				"mid_terrain_color": Color("#464e16"),
				"ground_base_color": Color("#5a601a"),
				"ground_detail_color": Color("#7e8626"),
				"ground_accent_color": Color("#d0dc38"),
				"atmosphere_haze": Color(0.85, 0.90, 0.30, 0.28),
				"terrain_label": "SULFURIC BRIMSTONE CRAGS",
			}
		"obsidian":
			return {
				"sky_zenith": Color("#160e22"),
				"sky_horizon": Color("#442c5c"),
				"sun_color": Color(0.9, 0.75, 1.0, 0.90),
				"mountain_color": Color("#1a1024"),
				"mountain_highlight": Color("#66428a"),
				"mountain_style": "spires",
				"mid_terrain_color": Color("#2a1a3c"),
				"ground_base_color": Color("#20162c"),
				"ground_detail_color": Color("#38264e"),
				"ground_accent_color": Color("#784e9c"),
				"atmosphere_haze": Color(0.55, 0.35, 0.75, 0.20),
				"terrain_label": "VITREOUS BASALT GLASS SHEETS",
			}
		"iron":
			return {
				"sky_zenith": Color("#34160e"),
				"sky_horizon": Color("#8e3c22"),
				"sun_color": Color(1.0, 0.7, 0.4, 0.90),
				"mountain_color": Color("#2c100a"),
				"mountain_highlight": Color("#7e321a"),
				"mountain_style": "mesas",
				"mid_terrain_color": Color("#522014"),
				"ground_base_color": Color("#662a1a"),
				"ground_detail_color": Color("#863824"),
				"ground_accent_color": Color("#c05432"),
				"atmosphere_haze": Color(0.85, 0.45, 0.25, 0.25),
				"terrain_label": "FERROUS OXIDE DUNES",
			}
		"ammonia":
			return {
				"sky_zenith": Color("#0c202c"),
				"sky_horizon": Color("#2e627a"),
				"sun_color": Color(0.85, 0.95, 1.0, 0.85),
				"mountain_color": Color("#122834"),
				"mountain_highlight": Color("#447c94"),
				"mountain_style": "jagged",
				"mid_terrain_color": Color("#1c3e4e"),
				"ground_base_color": Color("#2a5264"),
				"ground_detail_color": Color("#44748a"),
				"ground_accent_color": Color("#70acc4"),
				"atmosphere_haze": Color(0.45, 0.80, 0.95, 0.25),
				"terrain_label": "AMMONIA HYDRATE ICE BASIN",
			}
		"carbon":
			return {
				"sky_zenith": Color("#0e1218"),
				"sky_horizon": Color("#283242"),
				"sun_color": Color(0.95, 0.95, 1.0, 0.95),
				"mountain_color": Color("#141a24"),
				"mountain_highlight": Color("#3e4c62"),
				"mountain_style": "spires",
				"mid_terrain_color": Color("#242e3c"),
				"ground_base_color": Color("#303c4c"),
				"ground_detail_color": Color("#46566a"),
				"ground_accent_color": Color("#7c92b0"),
				"atmosphere_haze": Color(0.60, 0.70, 0.85, 0.18),
				"terrain_label": "CARBONACEOUS GRAPHITE TERRACES",
			}
		_:
			return {
				"sky_zenith": Color("#163558"),
				"sky_horizon": Color("#5896d0"),
				"sun_color": Color(1.0, 0.94, 0.82, 0.95),
				"mountain_color": Color("#182e40"),
				"mountain_highlight": Color("#3e6888"),
				"mountain_style": "peaks",
				"mid_terrain_color": Color("#163d2c"),
				"ground_base_color": Color("#183824"),
				"ground_detail_color": Color("#2b5435"),
				"ground_accent_color": Color("#4d8256"),
				"atmosphere_haze": Color(0.65, 0.82, 1.0, 0.22),
				"terrain_label": "EXOPLANETARY SURFACE",
			}


static func _build_ridge_polygon(style: String, base_y: float, max_h: float, num_pts: int = 33, width: float = 640.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dx := width / float(num_pts - 1)
	for i in range(num_pts):
		var x := float(i) * dx
		var nx := x / width
		var h := 0.0
		match style:
			"caldera":
				var cone := exp(-pow((nx - 0.48) * 4.2, 2.0)) * max_h
				var caldera_dip := exp(-pow((nx - 0.48) * 15.0, 2.0)) * (max_h * 0.38)
				h = cone - caldera_dip + sin(nx * 19.0) * 7.0
			"jagged":
				h = abs(sin(nx * 8.5) * cos(nx * 16.0)) * max_h + sin(nx * 28.0) * 8.0
			"mesas":
				var m := sin(nx * 6.8)
				h = maxf(0.0, tanh(m * 2.8)) * max_h + sin(nx * 14.0) * 6.0
			"spires":
				var sp := pow(maxf(0.0, cos(nx * 12.0)), 4.0) * max_h * 1.25
				h = sp + sin(nx * 5.2) * (max_h * 0.35)
			_: # peaks
				h = abs(sin(nx * 3.8) * 0.5 + sin(nx * 10.5) * 0.3 + sin(nx * 21.0) * 0.2) * max_h
		pts.append(Vector2(x, base_y - maxf(4.0, h)))
	pts.append(Vector2(width, 360.0))
	pts.append(Vector2(0.0, 360.0))
	return pts


func _setup_audio() -> void:
	_audio_beep = _create_player("res://assets/audio/launch_beep.wav", -2.0)
	_audio_ignition = _create_player("res://assets/audio/launch_ignition.wav", 0.0)
	_audio_rumble = _create_player("res://assets/audio/launch_rumble.wav", -3.0)
	_audio_staging = _create_player("res://assets/audio/launch_staging.wav", 1.0)


func _create_player(path: String, vol_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = vol_db
	if ResourceLoader.exists(path):
		player.stream = load(path) as AudioStream
	add_child(player)
	return player


func _play_sfx(player: AudioStreamPlayer) -> void:
	if player != null and player.stream != null and is_inside_tree() and player.is_inside_tree():
		player.play()


# --- Scene Construction ----------------------------------------------------

func _build_scene_layers() -> void:
	_world = Control.new()
	_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)

	# 1. Base Sky Background & Planetary Atmosphere
	_sky_rect = ColorRect.new()
	_sky_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_rect.color = _env_sky_zenith
	_world.add_child(_sky_rect)

	_sky_canvas = Control.new()
	_sky_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_canvas.draw.connect(_draw_planetary_sky)
	_world.add_child(_sky_canvas)

	# 2. Distant Mountains & Formations (Slowest parallax)
	_distant_mountains_root = Control.new()
	_distant_mountains_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_distant_mountains_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_distant_mountains_root.draw.connect(_draw_distant_mountains)
	_world.add_child(_distant_mountains_root)

	# 3. Midground Planetary Hills (Medium parallax)
	_midground_terrain_root = Control.new()
	_midground_terrain_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_midground_terrain_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_midground_terrain_root.draw.connect(_draw_midground_terrain)
	_world.add_child(_midground_terrain_root)

	_build_planetary_landmark()

	# 4. Low Atmosphere & Passing Clouds
	_clouds_root = Control.new()
	_clouds_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clouds_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clouds_root.draw.connect(_draw_atmospheric_layers)
	_world.add_child(_clouds_root)
	for i in range(3):
		var cloud_path := "res://assets/sprites/vehicles/cloud_band_%d.png" % i
		if ResourceLoader.exists(cloud_path):
			var ct := load(cloud_path) as Texture2D
			if ct != null:
				_cloud_textures.append(ct)

	# 5. Deep Space Layer (Stars, Destination Planet, Departure Limb, Transfer Arc)
	_space_root = Control.new()
	_space_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_space_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_space_root.modulate.a = 0.0
	_world.add_child(_space_root)

	_space_backdrop = SpaceBackdrop.create({"planet_on": false, "stars_on": true, "dim": 0.15})
	_space_root.add_child(_space_backdrop)

	# Departure Planet Limb (Earth in Sector 1, Previous Planet in Sector > 1)
	_earth_disc = Control.new()
	_earth_disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_earth_disc.draw.connect(_draw_earth_limb)
	_space_root.add_child(_earth_disc)

	# Interplanetary Hohmann Transfer Trajectory Arc
	_trajectory_overlay = Control.new()
	_trajectory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trajectory_overlay.draw.connect(_draw_trajectory_path)
	_space_root.add_child(_trajectory_overlay)

	# Target Destination Exoplanet (Upper Right Space Sector)
	_target_planet_root = Control.new()
	_target_planet_root.position = Vector2(460, 130)
	_target_planet_root.size = Vector2(160, 160)
	_target_planet_root.pivot_offset = Vector2(80, 80)
	_target_planet_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_space_root.add_child(_target_planet_root)

	_target_planet_halo = Control.new()
	_target_planet_halo.position = Vector2(80, 80)
	_target_planet_halo.draw.connect(_draw_target_planet_halo)
	_target_planet_root.add_child(_target_planet_halo)

	_target_planet_rect = TextureRect.new()
	_target_planet_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_planet_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_planet_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_target_planet_rect.position = Vector2(8, 8)
	_target_planet_rect.size = Vector2(144, 144)
	_target_planet_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Load the target planet's authentic high-resolution artwork
	var p_asset_path := "res://assets/sprites/planets/sector/%s.png" % _planet_biome
	if not ResourceLoader.exists(p_asset_path):
		p_asset_path = "res://assets/sprites/planets/%s.png" % _planet_biome
	if not ResourceLoader.exists(p_asset_path):
		p_asset_path = "res://assets/sprites/planets/rocky.png"
	if ResourceLoader.exists(p_asset_path):
		_target_planet_rect.texture = load(p_asset_path) as Texture2D

	var pshader := load("res://shaders/planet_view.gdshader") as Shader
	if pshader != null:
		var pmat := ShaderMaterial.new()
		pmat.shader = pshader
		var rim_col: Color = _planet_info.get("rim", Color(0.40, 0.75, 1.0, 0.95))
		pmat.set_shader_parameter("rim_color", rim_col)
		pmat.set_shader_parameter("atmosphere", 0.75)
		pmat.set_shader_parameter("light_speed", 0.04)
		if _target_planet_rect.texture != null:
			pmat.set_shader_parameter("planet_res", Vector2(_target_planet_rect.texture.get_width(), _target_planet_rect.texture.get_height()))
		_target_planet_rect.material = pmat
	_target_planet_root.add_child(_target_planet_rect)

	# Label above destination planet
	_target_planet_label = UIKit.label("%s  ·  %s" % [_planet_name, _planet_info.get("name", "EXOPLANET")], 7, _planet_info.get("color", UIKit.CYAN), true, HORIZONTAL_ALIGNMENT_CENTER)
	_target_planet_label.position = Vector2(-20, -14)
	_target_planet_label.size = Vector2(200, 14)
	_target_planet_root.add_child(_target_planet_label)

	# 6. Foreground Planetary Surface & Launch Area
	_ground_root = Control.new()
	_ground_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ground_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_ground_root)

	_foreground_surface = Control.new()
	_foreground_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_foreground_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground_surface.draw.connect(_draw_foreground_surface)
	_ground_root.add_child(_foreground_surface)

	_build_planetary_surface_props()

	_pad_mount = Control.new()
	_pad_mount.position = Vector2(320, 275)
	_pad_mount.draw.connect(_draw_launch_pad)
	_ground_root.add_child(_pad_mount)

	var pad_art := "res://assets/sprites/vehicles/launch_pad.png"
	if ResourceLoader.exists(pad_art):
		var pad_tex := load(pad_art) as Texture2D
		if pad_tex != null:
			_pad_sprite = Sprite2D.new()
			_pad_sprite.texture = pad_tex
			_pad_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_pad_sprite.centered = false
			_pad_sprite.scale = Vector2(0.5, 0.5)
			_pad_sprite.position = Vector2(-70, 0)
			_pad_mount.add_child(_pad_sprite)

	_gantry_tower = Control.new()
	_gantry_tower.position = Vector2(380, 160)
	_gantry_tower.draw.connect(_draw_gantry)
	_ground_root.add_child(_gantry_tower)

	var gantry_art := "res://assets/sprites/vehicles/launch_gantry.png"
	if ResourceLoader.exists(gantry_art):
		var gantry_tex := load(gantry_art) as Texture2D
		if gantry_tex != null:
			_gantry_sprite = Sprite2D.new()
			_gantry_sprite.texture = gantry_tex
			_gantry_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_gantry_sprite.centered = false
			_gantry_sprite.scale = Vector2(0.5, 0.5)
			_gantry_sprite.position = Vector2(0, -160)
			_gantry_tower.add_child(_gantry_sprite)

	_gantry_arm_node = Node2D.new()
	_gantry_arm_node.name = "GantryArms"
	_gantry_arm_node.draw.connect(_draw_gantry_arms)
	_gantry_tower.add_child(_gantry_arm_node)

	_ground_illumination = Control.new()
	_ground_illumination.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ground_illumination.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground_illumination.draw.connect(_draw_ground_illumination)
	_ground_root.add_child(_ground_illumination)

	_spotlights = Node2D.new()
	_spotlights.draw.connect(_draw_spotlights)
	_ground_root.add_child(_spotlights)

	# 5. Launch Pad Smoke Emitters (Horizontal Billows)
	_pad_smoke_left = _create_pad_smoke_emitter(-1.0)
	_pad_smoke_left.position = Vector2(290, 310)
	_ground_root.add_child(_pad_smoke_left)

	_pad_smoke_right = _create_pad_smoke_emitter(1.0)
	_pad_smoke_right.position = Vector2(350, 310)
	_ground_root.add_child(_pad_smoke_right)

	# 6. Rocket & Spacecraft Assembly
	_rocket_root = Node2D.new()
	_rocket_root.position = Vector2(320, 240)
	_world.add_child(_rocket_root)

	_build_rocket_assembly()


func _build_planetary_landmark() -> void:
	if _midground_terrain_root == null:
		return
	var landmark_path := ""
	var landmark_pos := Vector2(80, 220)
	var landmark_scale := Vector2(0.55, 0.55)

	match _planet_biome:
		"volcanic", "sulfur", "obsidian":
			landmark_path = "res://assets/tilesets/structures/volcano.png"
			landmark_pos = Vector2(90, 210)
		"arid", "iron":
			landmark_path = "res://assets/tilesets/structures/mesa.png"
			landmark_pos = Vector2(510, 225)
		"cryo", "ammonia", "methane":
			landmark_path = "res://assets/tilesets/structures/glacier_wall.png"
			landmark_pos = Vector2(85, 220)
		"crystal":
			landmark_path = "res://assets/tilesets/structures/crystal_spire.png"
			landmark_pos = Vector2(520, 205)
		"barren":
			landmark_path = "res://assets/tilesets/structures/impact_crater.png"
			landmark_pos = Vector2(100, 230)
		"temperate", "carbon", "ocean":
			landmark_path = "res://assets/tilesets/structures/mountain_range.png"
			landmark_pos = Vector2(500, 220)
		_:
			landmark_path = "res://assets/tilesets/structures/mountain_range.png"
			landmark_pos = Vector2(90, 220)

	if not landmark_path.is_empty() and ResourceLoader.exists(landmark_path):
		var tex := load(landmark_path) as Texture2D
		if tex != null:
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.position = landmark_pos
			sp.scale = landmark_scale
			sp.modulate = _env_mountain_color.lerp(Color.WHITE, 0.55)
			_midground_terrain_root.add_child(sp)


func _build_planetary_surface_props() -> void:
	if _ground_root == null:
		return
	var prop_names: Array[String] = []
	match _planet_biome:
		"volcanic":
			prop_names = ["lava_rock", "accent_volcanic_vent", "sulfur_nodule", "lava_rock"]
		"cryo":
			prop_names = ["ice_chunk", "accent_cryo_ice_teeth", "accent_cryo_crack", "ice_chunk"]
		"arid":
			prop_names = ["dead_bush", "accent_arid_crack", "accent_arid_bones", "dead_bush"]
		"temperate":
			prop_names = ["boulder", "shrub", "accent_temperate_tuft", "boulder"]
		"barren":
			prop_names = ["barren_rock", "accent_barren_bones", "accent_barren_crack", "barren_rock"]
		"ocean":
			prop_names = ["coral_shard", "boulder", "coral_shard"]
		"methane":
			prop_names = ["ice_chunk", "barren_rock", "ice_chunk"]
		"iron":
			prop_names = ["dead_bush", "barren_rock", "obsidian_shard"]
		"sulfur":
			prop_names = ["lava_rock", "sulfur_nodule", "lava_rock"]
		"crystal":
			prop_names = ["ice_chunk", "crystal_nub", "ice_chunk"]
		"obsidian":
			prop_names = ["lava_rock", "obsidian_shard", "lava_rock"]
		"ammonia":
			prop_names = ["ice_chunk", "ice_chunk"]
		"carbon":
			prop_names = ["barren_rock", "barren_rock"]
		_:
			prop_names = ["boulder"]

	var positions := [
		Vector2(50, 275),
		Vector2(115, 278),
		Vector2(185, 274),
		Vector2(450, 276),
		Vector2(520, 279),
		Vector2(590, 274)
	]

	for i in range(mini(prop_names.size(), positions.size())):
		var p_name := prop_names[i]
		var p_path := "res://assets/props/%s.png" % p_name
		if not ResourceLoader.exists(p_path):
			continue
		var tex := load(p_path) as Texture2D
		if tex == null:
			continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = positions[i]
		sp.scale = Vector2(0.85, 0.85)
		_ground_root.add_child(sp)


func _soft_smoke_texture() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var c := Vector2(7.5, 7.5)
	for y in range(16):
		for x in range(16):
			var d := Vector2(x, y).distance_to(c) / 7.5
			var a := clampf(1.0 - d * d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _create_pad_smoke_emitter(direction: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = 32 if not _reduced_fx else 16
	p.lifetime = 1.6
	p.one_shot = false
	p.explosiveness = 0.05
	p.direction = Vector2(direction, -0.2).normalized()
	p.spread = 28.0
	p.gravity = Vector2(direction * 15.0, -12.0)
	p.initial_velocity_min = 45.0
	p.initial_velocity_max = 95.0
	var smoke_tex := _soft_smoke_texture()
	if smoke_tex != null:
		p.texture = smoke_tex
		p.scale_amount_min = 0.35
		p.scale_amount_max = 1.10
	else:
		p.scale_amount_min = 6.0
		p.scale_amount_max = 18.0
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.72, 0.35, 0.85),
		Color(0.85, 0.85, 0.90, 0.65),
		Color(0.40, 0.45, 0.55, 0.25),
		Color(0.20, 0.22, 0.30, 0.0)
	])
	p.color_ramp = grad
	return p


func _build_rocket_assembly() -> void:
	_rocket_body = Node2D.new()
	_rocket_root.add_child(_rocket_body)

	# Booster drawing node
	var booster_node := Node2D.new()
	booster_node.name = "Booster"
	booster_node.draw.connect(_draw_booster)
	_rocket_body.add_child(booster_node)

	var booster_art := "res://assets/sprites/vehicles/%s_booster.png" % _veh_id
	if ResourceLoader.exists(booster_art):
		var art := load(booster_art) as Texture2D
		if art != null:
			_booster_sprite = Sprite2D.new()
			_booster_sprite.texture = art
			_booster_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_booster_sprite.centered = false
			var art_size := art.get_size()
			var native_w := 28.0
			match _veh_id:
				"vector_l": native_w = 20.0
				"vector_h": native_w = 62.0
			var art_scale := 1.0
			if art_size.x > native_w * 1.6:
				art_scale = 0.5
			_booster_sprite.scale = Vector2(art_scale, art_scale)
			_booster_sprite.position = Vector2(-art_size.x * art_scale * 0.5, -30.0)
			booster_node.add_child(_booster_sprite)

	# Exhaust billows
	_plume_smoke = Node2D.new()
	_rocket_body.add_child(_plume_smoke)
	for i in range(3):
		var frame_path := "res://assets/sprites/vehicles/exhaust_plume_%d.png" % i
		if ResourceLoader.exists(frame_path):
			var pf := load(frame_path) as Texture2D
			if pf != null:
				_plume_frames.append(pf)
	if not _plume_frames.is_empty():
		for side in [-1.0, 1.0]:
			var b := Sprite2D.new()
			b.texture = _plume_frames[0]
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b.centered = true
			b.flip_h = side > 0.0
			b.scale = Vector2(0.42, 0.42)
			b.modulate = Color(1, 1, 1, 0.0)
			b.set_meta("side", side)
			_plume_smoke.add_child(b)
			_plume_billows.append(b)
	_plume_smoke.visible = false

	# Exhaust plume node (under rocket)
	_exhaust_plume = Node2D.new()
	_exhaust_plume.draw.connect(_draw_exhaust_plume)
	_rocket_body.add_child(_exhaust_plume)

	# Orbital maneuvering engine plume (used in Phase 5 space cruise)
	_orbital_plume = Node2D.new()
	_orbital_plume.draw.connect(_draw_orbital_thruster)
	_rocket_body.add_child(_orbital_plume)

	# Trailing smoke particles from nozzles
	_smoke_particles = CPUParticles2D.new()
	_smoke_particles.emitting = false
	_smoke_particles.amount = 40 if not _reduced_fx else 18
	_smoke_particles.lifetime = 1.2
	_smoke_particles.direction = Vector2(0, 1)
	_smoke_particles.spread = 16.0
	_smoke_particles.gravity = Vector2(0, 40)
	_smoke_particles.initial_velocity_min = 80.0
	_smoke_particles.initial_velocity_max = 140.0
	var trail_tex := _soft_smoke_texture()
	if trail_tex != null:
		_smoke_particles.texture = trail_tex
		_smoke_particles.scale_amount_min = 0.20
		_smoke_particles.scale_amount_max = 0.55
	else:
		_smoke_particles.scale_amount_min = 4.0
		_smoke_particles.scale_amount_max = 14.0
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.85, 0.40, 0.90),
		Color(0.92, 0.50, 0.20, 0.70),
		Color(0.60, 0.65, 0.75, 0.35),
		Color(0.25, 0.28, 0.35, 0.0)
	])
	_smoke_particles.color_ramp = grad
	_rocket_body.add_child(_smoke_particles)

	# Spacecraft Sprite (Mounted on upper stage)
	var ship_path := "res://assets/sprites/ships/%s.png" % _hull_id
	if not ResourceLoader.exists(ship_path):
		ship_path = "res://assets/sprites/ships/pathfinder.png"
	var ship_tex: Texture2D = load(ship_path) as Texture2D

	_ship_sprite = Sprite2D.new()
	_ship_sprite.texture = ship_tex
	_ship_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ship_sprite.rotation = -PI * 0.5 # Point nose UP
	_ship_sprite.scale = Vector2(0.48, 0.48)
	_ship_sprite.position = Vector2(0, -56)
	_rocket_body.add_child(_ship_sprite)

	# Aerodynamic Fairing Halves (Shroud payload during atmospheric ascent)
	_fairing_left = Node2D.new()
	_rocket_body.add_child(_fairing_left)
	_fairing_right = Node2D.new()
	_rocket_body.add_child(_fairing_right)

	var fairing_left_art := "res://assets/sprites/vehicles/fairing_left.png"
	var fairing_right_art := "res://assets/sprites/vehicles/fairing_right.png"
	var fairing_sprites_loaded := false
	if ResourceLoader.exists(fairing_left_art) and ResourceLoader.exists(fairing_right_art):
		var t_left := load(fairing_left_art) as Texture2D
		var t_right := load(fairing_right_art) as Texture2D
		if t_left != null and t_right != null:
			fairing_sprites_loaded = true
			for pair in [[_fairing_left, t_left, -14.0], [_fairing_right, t_right, 0.0]]:
				var host: Node2D = pair[0]
				var tex: Texture2D = pair[1]
				var spr := Sprite2D.new()
				spr.texture = tex
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				spr.centered = false
				var sc := 0.5 if tex.get_width() > 20 else 1.0
				spr.scale = Vector2(sc, sc)
				spr.position = Vector2(float(pair[2]), -98.0)
				host.add_child(spr)
	if not fairing_sprites_loaded and _vector_fairing:
		var pl := Polygon2D.new()
		pl.color = Color(0.90, 0.92, 0.96)
		pl.polygon = PackedVector2Array([
			Vector2(0, -98), Vector2(-14, -72), Vector2(-14, -30), Vector2(0, -30)
		])
		_fairing_left.add_child(pl)
		var pr := Polygon2D.new()
		pr.color = Color(0.82, 0.84, 0.88)
		pr.polygon = PackedVector2Array([
			Vector2(0, -98), Vector2(14, -72), Vector2(14, -30), Vector2(0, -30)
		])
		_fairing_right.add_child(pr)
	
	if _no_fairing or (not fairing_sprites_loaded and not _vector_fairing):
		_fairing_left.visible = false
		_fairing_right.visible = false

	# Transonic Max-Q Condensation Shock Cone
	_shock_cone = Polygon2D.new()
	_shock_cone.color = Color(0.95, 0.98, 1.0, 0.0)
	_shock_cone.polygon = PackedVector2Array([
		Vector2(0, -96),
		Vector2(-24, -68),
		Vector2(-18, -62),
		Vector2(0, -78),
		Vector2(18, -62),
		Vector2(24, -68)
	])
	_rocket_body.add_child(_shock_cone)


# --- Custom Drawing Callbacks ----------------------------------------------

func _draw_planetary_sky() -> void:
	if _sky_canvas == null:
		return
	var verts := PackedVector2Array([
		Vector2(0, 0),
		Vector2(640, 0),
		Vector2(640, 360),
		Vector2(0, 360)
	])
	var colors := PackedColorArray([
		_current_sky_zenith,
		_current_sky_zenith,
		_current_sky_horizon,
		_current_sky_horizon
	])
	_sky_canvas.draw_polygon(verts, colors)

	# Primary Luminary (Sun / Host Star) in atmospheric sky
	if _space_root != null and _space_root.modulate.a < 0.95:
		var sun_pos := Vector2(170, 92 + _sun_offset_y)
		if sun_pos.y < 350.0:
			var s_a := clampf(1.0 - _space_root.modulate.a, 0.0, 1.0)
			var col := _env_sun_color * Color(1, 1, 1, s_a)
			_sky_canvas.draw_circle(sun_pos, 44.0, col * Color(1, 1, 1, 0.08))
			_sky_canvas.draw_circle(sun_pos, 22.0, col * Color(1, 1, 1, 0.22))
			_sky_canvas.draw_circle(sun_pos, 11.0, col * Color(1, 1, 1, 0.92))
			_sky_canvas.draw_line(sun_pos + Vector2(-40, 30), sun_pos + Vector2(220, 210), col * Color(1, 1, 1, 0.05), 32.0)


func _draw_distant_mountains() -> void:
	if _distant_mountains_root == null or _mountain_polygon.is_empty():
		return
	_distant_mountains_root.draw_polygon(_mountain_polygon, [_env_mountain_color])
	
	# Draw crest ridge highlight
	var ridge_count := _mountain_polygon.size() - 2
	if ridge_count > 1:
		for i in range(ridge_count - 1):
			var p1 := _mountain_polygon[i]
			var p2 := _mountain_polygon[i + 1]
			_distant_mountains_root.draw_line(p1, p2, _env_mountain_highlight, 1.5)
	
	# Atmospheric distance haze across base
	_distant_mountains_root.draw_rect(Rect2(0, 225, 640, 55), _env_atmosphere_haze)


func _draw_midground_terrain() -> void:
	if _midground_terrain_root == null or _midground_polygon.is_empty():
		return
	_midground_terrain_root.draw_polygon(_midground_polygon, [_env_mid_terrain_color])
	
	# Strata lines and rock bands across midground hills
	var ridge_count := _midground_polygon.size() - 2
	if ridge_count > 1:
		for i in range(ridge_count - 1):
			var p1 := _midground_polygon[i]
			var p2 := _midground_polygon[i + 1]
			_midground_terrain_root.draw_line(p1, p2, _env_mid_terrain_color.lightened(0.18), 1.0)
			if i % 3 == 0:
				_midground_terrain_root.draw_line(p1 + Vector2(0, 10), p2 + Vector2(0, 10), _env_ground_detail_color * Color(1, 1, 1, 0.4), 1.0)


func _draw_foreground_surface() -> void:
	if _foreground_surface == null:
		return
	# 1. Base planetary bedrock polygon spanning full width 0..640
	var ground_pts := PackedVector2Array([
		Vector2(0, 268),
		Vector2(70, 266),
		Vector2(140, 270),
		Vector2(210, 267),
		Vector2(248, 275), # Meets launch pad foundation
		Vector2(392, 275),
		Vector2(430, 267),
		Vector2(500, 271),
		Vector2(570, 265),
		Vector2(640, 269),
		Vector2(640, 360),
		Vector2(0, 360)
	])
	_foreground_surface.draw_polygon(ground_pts, [_env_ground_base_color])

	# 2. Geological strata layers across bedrock
	_foreground_surface.draw_line(Vector2(0, 288), Vector2(245, 290), _env_ground_detail_color, 2.0)
	_foreground_surface.draw_line(Vector2(395, 290), Vector2(640, 287), _env_ground_detail_color, 2.0)
	_foreground_surface.draw_line(Vector2(0, 314), Vector2(240, 316), _env_ground_detail_color * Color(1, 1, 1, 0.8), 2.0)
	_foreground_surface.draw_line(Vector2(400, 316), Vector2(640, 313), _env_ground_detail_color * Color(1, 1, 1, 0.8), 2.0)
	_foreground_surface.draw_line(Vector2(0, 342), Vector2(640, 344), _env_ground_detail_color * Color(1, 1, 1, 0.6), 1.5)

	# 3. Boulders, Crags, and Environmental Outcrops
	var rocks := [
		[Vector2(45, 280), Vector2(20, 12)],
		[Vector2(105, 294), Vector2(26, 16)],
		[Vector2(165, 278), Vector2(16, 10)],
		[Vector2(215, 285), Vector2(22, 14)],
		[Vector2(435, 282), Vector2(18, 11)],
		[Vector2(485, 294), Vector2(24, 15)],
		[Vector2(545, 279), Vector2(20, 13)],
		[Vector2(605, 292), Vector2(22, 14)],
	]
	for r in rocks:
		var r_pos: Vector2 = r[0]
		var r_sz: Vector2 = r[1]
		var r_poly := PackedVector2Array([
			r_pos + Vector2(-r_sz.x * 0.5, 0),
			r_pos + Vector2(-r_sz.x * 0.25, -r_sz.y),
			r_pos + Vector2(r_sz.x * 0.35, -r_sz.y * 0.9),
			r_pos + Vector2(r_sz.x * 0.5, 0)
		])
		_foreground_surface.draw_polygon(r_poly, [_env_ground_base_color.darkened(0.25)])
		_foreground_surface.draw_line(r_pos + Vector2(-r_sz.x * 0.25, -r_sz.y), r_pos + Vector2(r_sz.x * 0.35, -r_sz.y * 0.9), _env_ground_accent_color, 1.5)

	# 4. Biome-specific accent details
	match _env_mountain_style:
		"caldera":
			_foreground_surface.draw_polyline(PackedVector2Array([
				Vector2(60, 330), Vector2(95, 335), Vector2(140, 332), Vector2(180, 338)
			]), Color(1.0, 0.42, 0.12, 0.85), 2.0)
			_foreground_surface.draw_polyline(PackedVector2Array([
				Vector2(460, 335), Vector2(510, 331), Vector2(565, 336), Vector2(610, 332)
			]), Color(1.0, 0.42, 0.12, 0.85), 2.0)
		"jagged":
			for ix in [75, 145, 455, 525, 590]:
				var sp := PackedVector2Array([
					Vector2(ix - 5, 275), Vector2(ix, 262), Vector2(ix + 5, 275)
				])
				_foreground_surface.draw_polygon(sp, [_env_ground_accent_color * Color(1, 1, 1, 0.9)])
		"spires":
			for cx in [85, 175, 465, 565]:
				var cp := PackedVector2Array([
					Vector2(cx - 6, 280), Vector2(cx, 258), Vector2(cx + 6, 280)
				])
				_foreground_surface.draw_polygon(cp, [_env_ground_accent_color])
				_foreground_surface.draw_line(Vector2(cx - 6, 280), Vector2(cx, 258), Color(1, 1, 1, 0.8), 1.5)
		"mesas":
			for rx in [30, 90, 150, 440, 500, 560]:
				_foreground_surface.draw_arc(Vector2(rx, 305), 18.0, -PI * 0.7, -PI * 0.3, 8, _env_ground_accent_color, 1.5)

	# 5. Reinforced Launch Platform Bedrock Footing & Flame Trench
	_foreground_surface.draw_rect(Rect2(240, 275, 160, 75), Color("#0e151c"))
	_foreground_surface.draw_rect(Rect2(240, 275, 160, 75), Color("#1e2b36"), false, 2.0)
	_foreground_surface.draw_rect(Rect2(252, 290, 16, 60), Color("#080c10"))
	_foreground_surface.draw_rect(Rect2(372, 290, 16, 60), Color("#080c10"))
	_foreground_surface.draw_rect(Rect2(282, 276, 76, 44), Color("#04070a"))
	_foreground_surface.draw_line(Vector2(282, 276), Vector2(266, 312), Color("#2a3e4c"), 2.0)
	_foreground_surface.draw_line(Vector2(358, 276), Vector2(374, 312), Color("#2a3e4c"), 2.0)
	for hx in range(244, 396, 14):
		_foreground_surface.draw_line(Vector2(hx, 276), Vector2(hx + 6, 282), Color(0.95, 0.75, 0.20, 0.85), 1.5)


func _draw_ground_illumination() -> void:
	if _ground_illumination == null:
		return
	if _phase == Phase.PREPARATION:
		_ground_illumination.draw_circle(Vector2(260, 290), 45.0, Color(0.85, 0.95, 1.0, 0.08))
		_ground_illumination.draw_circle(Vector2(380, 290), 45.0, Color(0.85, 0.95, 1.0, 0.08))
	elif _phase in [Phase.IGNITION, Phase.LIFTOFF]:
		if _engine_light_glow > 0.01:
			var pad_c := Vector2(320, 288)
			var a := _engine_light_glow * 0.65
			_ground_illumination.draw_circle(pad_c, 210.0, Color(1.0, 0.52, 0.12, a * 0.14))
			_ground_illumination.draw_circle(pad_c, 120.0, Color(1.0, 0.68, 0.22, a * 0.32))
			_ground_illumination.draw_circle(pad_c, 52.0, Color(1.0, 0.92, 0.60, a * 0.70))


func _draw_launch_pad() -> void:
	if _pad_sprite != null and is_instance_valid(_pad_sprite):
		return
	var pad_w := 140.0
	var pad_h := 38.0
	_pad_mount.draw_rect(Rect2(-pad_w * 0.5, 0, pad_w, pad_h), Color("#0a121a"))
	_pad_mount.draw_rect(Rect2(-32, 4, 64, pad_h - 4), Color("#04070c"))
	_pad_mount.draw_line(Vector2(-pad_w * 0.5, 0), Vector2(pad_w * 0.5, 0), Color("#2b424d"), 3.0)
	_pad_mount.draw_line(Vector2(-42, 0), Vector2(-42, pad_h), Color("#1b2f38"), 2.0)
	_pad_mount.draw_line(Vector2(42, 0), Vector2(42, pad_h), Color("#1b2f38"), 2.0)
	for i in range(-5, 6):
		var sx := float(i) * 12.0
		_pad_mount.draw_line(Vector2(sx - 4, -1), Vector2(sx + 4, 3), Color(0.95, 0.75, 0.20, 0.75), 1.5)


func _draw_gantry() -> void:
	if _gantry_sprite != null and is_instance_valid(_gantry_sprite):
		return
	var w := 26.0
	var h := 160.0
	_gantry_tower.draw_rect(Rect2(0, -h, w, h), Color("#0d1720"))
	_gantry_tower.draw_rect(Rect2(0, -h, w, h), Color("#263d4a"), false, 1.5)
	for y in range(0, int(h), 20):
		var py := -float(y)
		_gantry_tower.draw_line(Vector2(0, py), Vector2(w, py - 20), Color("#1e313d"), 1.0)
		_gantry_tower.draw_line(Vector2(w, py), Vector2(0, py - 20), Color("#1e313d"), 1.0)


func _draw_gantry_arms() -> void:
	if _gantry_arm_node == null:
		return
	var arm_rot := 0.0
	if _phase >= Phase.LIFTOFF:
		arm_rot = clampf((_time - 7.0) * 1.8, 0.0, 1.0)
	var upper_end := Vector2(-60 + arm_rot * 40.0, -118 - arm_rot * 22.0)
	_gantry_arm_node.draw_line(Vector2(0, -118), upper_end, Color("#3a5666"), 2.0)
	_gantry_arm_node.draw_circle(upper_end, 2.5, Color("#5ce1d0"))
	var lower_end := Vector2(-48 + arm_rot * 32.0, -52 - arm_rot * 16.0)
	_gantry_arm_node.draw_line(Vector2(0, -52), lower_end, Color("#2b4250"), 2.5)


func _draw_spotlights() -> void:
	var left_lamp := Vector2(230, 290)
	var right_lamp := Vector2(410, 290)
	var rocket_target := Vector2(320, 180)
	var beam_alpha := 0.16
	if _phase == Phase.IGNITION:
		beam_alpha = 0.08
	var col_beam := Color(0.85, 0.95, 1.0, beam_alpha)
	_spotlights.draw_polygon(PackedVector2Array([
		left_lamp,
		rocket_target + Vector2(-18, -40),
		rocket_target + Vector2(18, 40)
	]), [col_beam])
	_spotlights.draw_circle(left_lamp, 3.5, Color(0.9, 0.95, 1.0, 0.9))

	_spotlights.draw_polygon(PackedVector2Array([
		right_lamp,
		rocket_target + Vector2(-18, -40),
		rocket_target + Vector2(18, 40)
	]), [col_beam])
	_spotlights.draw_circle(right_lamp, 3.5, Color(0.9, 0.95, 1.0, 0.9))


func _draw_booster() -> void:
	if _rocket_body == null:
		return
	var b_node: Node2D = _rocket_body.get_node_or_null("Booster")
	if b_node == null:
		return
	if _booster_dropped:
		b_node.position.y = _booster_offset_y
		b_node.modulate.a = clampf(1.0 - (_booster_offset_y / 180.0), 0.0, 1.0)
	if _booster_sprite != null and is_instance_valid(_booster_sprite):
		return
	match _veh_id:
		"vector_l": _draw_vector_l_booster(b_node)
		"vector_h": _draw_vector_h_booster(b_node)
		_: _draw_vector_m_booster(b_node)


func _draw_vector_l_booster(node: Node2D) -> void:
	var w := 20.0
	var h := 70.0
	node.draw_rect(Rect2(-w * 0.5, -30, w, 8), Color("#283945"))
	node.draw_rect(Rect2(-w * 0.5, -22, w, h), Color("#e4e9f0"))
	node.draw_rect(Rect2(-w * 0.5, 0, w, 12), Color("#1b252e"))
	node.draw_rect(Rect2(-2, -18, 4, h - 8), Color("#ff7a2f"))
	node.draw_rect(Rect2(-w * 0.5, h - 22, w, 4), Color("#1e2832"))
	node.draw_polygon(PackedVector2Array([Vector2(-6, h - 18), Vector2(6, h - 18), Vector2(8, h - 8), Vector2(-8, h - 8)]), [Color("#35424e")])
	node.draw_polygon(PackedVector2Array([Vector2(-10, h - 24), Vector2(-22, h - 10), Vector2(-10, h - 12)]), [Color("#23303b")])
	node.draw_polygon(PackedVector2Array([Vector2(10, h - 24), Vector2(22, h - 10), Vector2(10, h - 12)]), [Color("#23303b")])


func _draw_vector_m_booster(node: Node2D) -> void:
	var w := 24.0
	var h := 82.0
	node.draw_rect(Rect2(-w * 0.5, -30, w, 8), Color("#253542"))
	node.draw_rect(Rect2(-w * 0.5, -22, w, h), Color("#f0f4fa"))
	node.draw_rect(Rect2(-w * 0.5, 4, w, 14), Color("#18232c"))
	node.draw_rect(Rect2(-3, -18, 6, h - 6), Color("#ff7a2f"))
	node.draw_rect(Rect2(-w * 0.5, h - 22, w, 5), Color("#1a2630"))
	node.draw_polygon(PackedVector2Array([Vector2(-10, h - 17), Vector2(10, h - 17), Vector2(12, h - 6), Vector2(-12, h - 6)]), [Color("#32404c")])
	node.draw_polygon(PackedVector2Array([Vector2(-12, h - 26), Vector2(-26, h - 10), Vector2(-12, h - 14)]), [Color("#23303b")])
	node.draw_polygon(PackedVector2Array([Vector2(12, h - 26), Vector2(26, h - 10), Vector2(12, h - 14)]), [Color("#23303b")])


func _draw_vector_h_booster(node: Node2D) -> void:
	var cw := 26.0
	var bw := 18.0
	var h := 88.0
	node.draw_rect(Rect2(-cw * 0.5, -30, cw, 8), Color("#223340"))
	node.draw_rect(Rect2(-cw * 0.5, -22, cw, h), Color("#f0f4fa"))
	node.draw_rect(Rect2(-3, -22, 6, h), Color("#ff7a2f"))
	node.draw_polygon(PackedVector2Array([Vector2(-cw*0.5 - bw, -12), Vector2(-cw*0.5, -12), Vector2(-cw*0.5 - bw*0.5, -28)]), [Color("#d0d6e0")])
	node.draw_rect(Rect2(-cw * 0.5 - bw, -12, bw, h - 6), Color("#e2e7ef"))
	node.draw_rect(Rect2(-cw * 0.5 - 3, 10, 3, 12), Color("#1b2732"))
	node.draw_polygon(PackedVector2Array([Vector2(cw*0.5, -12), Vector2(cw*0.5 + bw, -12), Vector2(cw*0.5 + bw*0.5, -28)]), [Color("#d0d6e0")])
	node.draw_rect(Rect2(cw * 0.5, -12, bw, h - 6), Color("#e2e7ef"))
	node.draw_rect(Rect2(cw * 0.5, 10, 3, 12), Color("#1b2732"))
	node.draw_polygon(PackedVector2Array([Vector2(-cw*0.5 - 14, h - 18), Vector2(-cw*0.5 - 4, h - 18), Vector2(-cw*0.5 - 3, h - 7), Vector2(-cw*0.5 - 15, h - 7)]), [Color("#384654")])
	node.draw_polygon(PackedVector2Array([Vector2(-6, h - 14), Vector2(6, h - 14), Vector2(7, h - 5), Vector2(-7, h - 5)]), [Color("#384654")])
	node.draw_polygon(PackedVector2Array([Vector2(cw*0.5 + 4, h - 18), Vector2(cw*0.5 + 14, h - 18), Vector2(cw*0.5 + 15, h - 7), Vector2(cw*0.5 + 3, h - 7)]), [Color("#384654")])


func _draw_exhaust_plume() -> void:
	if _phase < Phase.IGNITION or _booster_dropped:
		return
	var base_y := 60.0
	match _veh_id:
		"vector_l": base_y = 62.0
		"vector_m": base_y = 76.0
		"vector_h": base_y = 82.0
	var flick := 0.85 + 0.15 * sin(_time * 47.0) + 0.10 * sin(_time * 89.0)
	var flame_len := (45.0 + 35.0 * flick) * clampf(_velocity * 0.05 + 1.0, 1.0, 2.2)
	var flame_w := 12.0 * flick
	if _veh_id == "vector_h":
		flame_w = 26.0 * flick
	var outer_flame := PackedVector2Array([
		Vector2(-flame_w * 0.5, base_y),
		Vector2(flame_w * 0.5, base_y),
		Vector2(flame_w * 0.35, base_y + flame_len * 0.65),
		Vector2(0, base_y + flame_len),
		Vector2(-flame_w * 0.35, base_y + flame_len * 0.65)
	])
	_exhaust_plume.draw_polygon(outer_flame, [Color(1.0, 0.45, 0.10, 0.85)])
	var core_flame := PackedVector2Array([
		Vector2(-flame_w * 0.25, base_y),
		Vector2(flame_w * 0.25, base_y),
		Vector2(0, base_y + flame_len * 0.5)
	])
	_exhaust_plume.draw_polygon(core_flame, [Color(1.0, 0.95, 0.70, 0.95)])
	for i in range(1, 4):
		var dy := base_y + float(i) * 18.0 * clampf(_velocity * 0.03 + 1.0, 1.0, 1.6)
		if dy < base_y + flame_len * 0.8:
			_exhaust_plume.draw_circle(Vector2(0, dy), 3.0 * flick, Color(0.70, 0.95, 1.0, 0.80))


func _draw_orbital_thruster() -> void:
	if _phase != Phase.SPACE or not _booster_dropped:
		return
	var flick := 0.85 + 0.15 * sin(_time * 33.0)
	var flame_len := 22.0 * flick
	var flame_w := 6.0
	var base_y := 16.0
	var col_ion := Color(0.25, 0.85, 1.0, 0.85)
	var col_core := Color(0.9, 0.98, 1.0, 0.95)
	var plume := PackedVector2Array([
		Vector2(-flame_w * 0.5, base_y),
		Vector2(flame_w * 0.5, base_y),
		Vector2(0, base_y + flame_len)
	])
	_orbital_plume.draw_polygon(plume, [col_ion])
	_orbital_plume.draw_circle(Vector2(0, base_y + 2), 2.2, col_core)


func _draw_atmospheric_layers() -> void:
	if _phase != Phase.LIFTOFF and _phase != Phase.ASCENT:
		return
	var speed := _velocity * 2.8
	var haze_col: Color = _env_atmosphere_haze
	for i in range(7):
		var cy := fmod(float(i * 55) + _time * speed, 380.0) - 20.0
		var cw := 140.0 + sin(float(i) * 3.4) * 60.0
		var cx := 80.0 + float(i % 3) * 190.0
		var a := (0.22 + 0.14 * sin(float(i) + _time)) * clampf(1.0 - (_altitude / 160.0), 0.0, 1.0)
		if a > 0.01:
			var layer_col := haze_col.lightened(0.25)
			layer_col.a = a
			_clouds_root.draw_rect(Rect2(cx, cy, cw, 14), layer_col)
			_clouds_root.draw_rect(Rect2(cx + 12, cy - 4, cw * 0.7, 8), layer_col * Color(1, 1, 1, 0.8))


func _draw_earth_limb() -> void:
	if _phase < Phase.ASCENT:
		return
	var center := Vector2(160, 560)
	var radius := 320.0
	var base_col: Color = _env_ground_base_color
	var mid_col: Color = _env_mid_terrain_color
	var rim_col: Color = _planet_info.get("rim", _env_sky_horizon)

	# Curved planetary horizon of the selected target exoplanet
	_earth_disc.draw_circle(center, radius, base_col.darkened(0.55))
	_earth_disc.draw_arc(center, radius - 16, -PI * 0.68, -PI * 0.32, 36, mid_col, 24.0)
	_earth_disc.draw_arc(center, radius - 32, -PI * 0.62, -PI * 0.38, 28, _env_ground_accent_color * Color(1, 1, 1, 0.45), 14.0)
	# Planetary atmospheric glow rim matching planet's sky horizon
	_earth_disc.draw_arc(center, radius + 2, -PI * 0.75, -PI * 0.25, 48, rim_col, 4.0)
	_earth_disc.draw_arc(center, radius + 7, -PI * 0.72, -PI * 0.28, 36, rim_col * Color(1, 1, 1, 0.30), 8.0)


func _draw_target_planet_halo() -> void:
	var col_halo: Color = _planet_info.get("rim", Color(0.40, 0.75, 1.0, 0.95))
	var rad := 64.0
	_target_planet_halo.draw_circle(Vector2.ZERO, rad + 14.0, col_halo * Color(1, 1, 1, 0.08))
	_target_planet_halo.draw_circle(Vector2.ZERO, rad + 6.0, col_halo * Color(1, 1, 1, 0.18))
	_target_planet_halo.draw_arc(Vector2.ZERO, rad + 2.0, -PI * 0.85, 0.0, 36, col_halo * Color(1, 1, 1, 0.85), 2.5)


func _draw_trajectory_path() -> void:
	if _phase < Phase.SPACE:
		return
	var p_start := _rocket_root.position
	var p_end := _target_planet_root.position + Vector2(72, 72)
	var ctrl := Vector2((p_start.x + p_end.x) * 0.45, minf(p_start.y, p_end.y) - 45.0)
	var col_line := Color(0.35, 0.85, 1.0, 0.40)
	var col_dot := Color(0.9, 0.95, 1.0, 0.85)
	var steps := 24
	var pts: Array[Vector2] = []
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := (1.0 - t) * (1.0 - t) * p_start + 2.0 * (1.0 - t) * t * ctrl + t * t * p_end
		pts.append(p)
	for i in range(pts.size() - 1):
		if i % 2 == 0:
			_trajectory_overlay.draw_line(pts[i], pts[i + 1], col_line, 1.5)
	var pulse_t := fmod(_time * 0.45, 1.0)
	var pulse_pos := (1.0 - pulse_t) * (1.0 - pulse_t) * p_start + 2.0 * (1.0 - pulse_t) * pulse_t * ctrl + pulse_t * pulse_t * p_end
	_trajectory_overlay.draw_circle(pulse_pos, 2.5, col_dot)
	_trajectory_overlay.draw_arc(p_end, 76.0, 0, TAU, 32, Color(0.35, 0.85, 1.0, 0.25), 1.0)


# --- HUD & Telemetry Construction ------------------------------------------

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 50
	add_child(_hud_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(root)

	# Agency Mission Header (Top Left)
	var head_panel := PanelContainer.new()
	head_panel.position = Vector2(16, 14)
	head_panel.add_theme_stylebox_override("panel", UIKit._ops_skin("panel", 6))
	root.add_child(head_panel)

	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	head_panel.add_child(hb)

	var title_lbl := UIKit.label("ORBIT & OUTPLAY  //  EXOPLANET INITIATIVE", 8, UIKit.CYAN, true)
	hb.add_child(title_lbl)

	var dest_lbl := UIKit.label("TARGET: %s  ·  %s" % [_planet_name, _planet_biome.to_upper()], 7, UIKit.CREAM, true)
	hb.add_child(dest_lbl)

	var veh_lbl := UIKit.label("VEHICLE: %s  |  PAYLOAD: %s" % [_veh_name, _hull_name], 7, UIKit.MUTED_C, true)
	hb.add_child(veh_lbl)

	# Readiness Telemetry Checklist (Top Left under Header)
	_status_vbox = VBoxContainer.new()
	_status_vbox.position = Vector2(18, 72)
	_status_vbox.add_theme_constant_override("separation", 3)
	root.add_child(_status_vbox)

	var check_title := UIKit.label("SYSTEMS TELEMETRY", 7, UIKit.MUTED_C, true)
	_status_vbox.add_child(check_title)

	var items: Array[String] = [
		"HULL INTEGRITY : NOMINAL",
		"AVIONICS BUS : SYNCHRONIZED",
		"PROPULSION : CRYOGENIC LOADED",
		"RANGE SAFETY : ARMED"
	]
	for it in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var dot := UIKit.label("●", 6, UIKit.DIM_C, true)
		var l := UIKit.label(it, 7, UIKit.DIM_C, true)
		row.add_child(dot)
		row.add_child(l)
		_status_vbox.add_child(row)
		_status_items.append({"dot": dot, "label": l, "active": false})

	# Digital Countdown Clock (Top Center)
	_countdown_label = UIKit.label("T-03.0s", 16, UIKit.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER)
	_countdown_label.position = Vector2(236, 14)
	_countdown_label.size = Vector2(180, 28)
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_countdown_label)

	_phase_label = UIKit.label("", 7, UIKit.ORANGE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_phase_label.position = Vector2(240, 39)
	_phase_label.size = Vector2(160, 10)
	root.add_child(_phase_label)

	# Skip Button (Bottom Right)
	_skip_button = UIKit.button("SKIP LAUNCH >", Vector2(110, 24), false)
	_skip_button.position = Vector2(514, 322)
	_skip_button.pressed.connect(_skip_launch)
	root.add_child(_skip_button)

	var skip_hint := UIKit.label("[SPACE / ESC]", 6, UIKit.DIM_C, true, HORIZONTAL_ALIGNMENT_RIGHT)
	skip_hint.position = Vector2(418, 328)
	skip_hint.size = Vector2(88, 14)
	root.add_child(skip_hint)

	# Mission Navigation & Science Plaque (Lower Left - Phase 5)
	_build_mission_plaque(root)


func _build_mission_plaque(parent: Control) -> void:
	_mission_plaque = PanelContainer.new()
	_mission_plaque.position = Vector2(18, 192)
	_mission_plaque.size = Vector2(295, 154)
	_mission_plaque.add_theme_stylebox_override("panel", UIKit._ops_skin("panel", 6))
	_mission_plaque.modulate.a = 0.0
	parent.add_child(_mission_plaque)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	_mission_plaque.add_child(vb)

	var badge := UIKit.label("★  INTERPLANETARY INJECTION CONFIRMED  ★", 8, UIKit.LIVE, true, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(badge)

	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vb.add_child(sep)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	vb.add_child(grid)

	var add_row := func(k: String, val: String, col: Color) -> void:
		grid.add_child(UIKit.label(k, 7, UIKit.MUTED_C, true))
		var v_lbl := UIKit.label(val, 7, col, true)
		v_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(v_lbl)

	add_row.call("DESTINATION:", "%s (%.1f LY)" % [_planet_name, _distance_ly], _planet_info.get("color", UIKit.CYAN))
	add_row.call("BIOME CLASSIFICATION:", _planet_info.get("name", "EXOPLANET"), UIKit.CREAM)
	add_row.call("SURFACE TERRAIN:", _planet_info.get("terrain", "CONTINENTS"), UIKit.AMBER)
	add_row.call("ENVIRONMENT:", "GRAV: %.2f g  ·  TEMP: %d K" % [_planet_gravity, int(_planet_temp)], UIKit.CREAM)
	add_row.call("TRAJECTORY STATUS:", "ORBITAL CAPTURE ARC LOCKED", UIKit.LIVE)

	var bot_hint := UIKit.label("COMMENCING ORBITAL DESCENT & SECTOR ENTRY...", 7, UIKit.DIM_C, true, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(bot_hint)


# --- Sequence Timelines ----------------------------------------------------

func _start_launch_sequence() -> void:
	_phase = Phase.PREPARATION
	_time = 0.0
	_phase_time = 0.0
	_countdown_val = 3
	if _ground_root != null:
		_ground_root.visible = true
		_ground_root.modulate.a = 1.0
		_ground_root.position.y = 0.0
	if _midground_terrain_root != null:
		_midground_terrain_root.visible = true
		_midground_terrain_root.modulate.a = 1.0
		_midground_terrain_root.position.y = 0.0
	if _distant_mountains_root != null:
		_distant_mountains_root.visible = true
		_distant_mountains_root.modulate.a = 1.0
		_distant_mountains_root.position.y = 0.0
	if _sky_canvas != null:
		_sky_canvas.visible = true
	if _space_root != null:
		_space_root.modulate.a = 0.0
	_current_sky_zenith = _env_sky_zenith
	_current_sky_horizon = _env_sky_horizon
	if _sky_rect != null:
		_sky_rect.color = _env_sky_zenith
	_sun_offset_y = 0.0
	_engine_light_glow = 0.0
	print("LAUNCH PHASE 1: PREPARATION | Spacecraft: %s | Vehicle: %s | Target: %s" % [_hull_name, _veh_name, _planet_name])


func _start_subsequent_sequence() -> void:
	_phase = Phase.SPACE
	_sky_rect.color = Color(0.003, 0.005, 0.010)
	_space_root.modulate.a = 1.0
	if _ground_root != null:
		_ground_root.visible = false
	if _midground_terrain_root != null:
		_midground_terrain_root.visible = false
	if _distant_mountains_root != null:
		_distant_mountains_root.visible = false
	if _sky_canvas != null:
		_sky_canvas.visible = false
	_countdown_label.visible = false
	if _phase_label != null:
		_phase_label.visible = false
	_status_vbox.visible = false
	_booster_dropped = true
	_fairing_left.visible = false
	_fairing_right.visible = false
	_ship_sprite.position = Vector2(0, 0)
	_ship_sprite.scale = Vector2(0.55, 0.55)
	_rocket_root.position = Vector2(230, 205)
	_rocket_root.rotation = -0.32
	print("LAUNCH SUBSEQUENT ORBITAL DEPARTURE | From: %s | Spacecraft: %s | Target: %s" % [_departure_name, _hull_name, _planet_name])
	
	_play_sfx(_audio_staging)
	_show_space_plaque()


func _process(delta: float) -> void:
	if _transitioned:
		return
	_time += delta
	_phase_time += delta

	if _shake_amount > 0.0 and not _reduced_fx:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_world.position = Vector2(
			rng.randf_range(-_shake_amount, _shake_amount),
			rng.randf_range(-_shake_amount, _shake_amount)
		)
	else:
		_world.position = Vector2.ZERO

	if not _is_subsequent:
		_process_ground_launch(delta)
	else:
		_process_subsequent_flight(delta)


func _process_ground_launch(delta: float) -> void:
	match _phase:
		Phase.PREPARATION: _update_preparation_phase()
		Phase.IGNITION: _update_ignition_phase()
		Phase.LIFTOFF: _update_liftoff_phase(delta)
		Phase.ASCENT: _update_ascent_phase(delta)
		Phase.SPACE: _update_space_phase(delta)


func _update_preparation_phase() -> void:
	var t := _phase_time
	var c := 3
	if t < 0.9: c = 3
	elif t < 1.8: c = 2
	elif t < 2.6: c = 1
	else: c = 0

	if c != _countdown_val:
		_countdown_val = c
		_countdown_label.text = "T-%02d.0s" % _countdown_val
		_countdown_label.add_theme_color_override("font_color", UIKit.CREAM)
		_play_sfx(_audio_beep)
		
		var active_idx: int = 3 - mini(c, 3)
		for i in range(_status_items.size()):
			var item: Dictionary = _status_items[i]
			var dot: Label = item["dot"]
			var lbl: Label = item["label"]
			if i <= active_idx:
				dot.modulate = UIKit.LIVE
				lbl.modulate = UIKit.LIVE
			else:
				dot.modulate = UIKit.DIM_C
				lbl.modulate = UIKit.DIM_C

	if _phase_time >= 3.0:
		_enter_ignition_phase()


func _enter_ignition_phase() -> void:
	_phase = Phase.IGNITION
	_phase_time = 0.0
	print("LAUNCH PHASE 2: ENGINE IGNITION & FLAME TRENCH EXHAUST")
	if _countdown_label != null:
		_countdown_label.text = "IGNITION"
		_countdown_label.add_theme_color_override("font_color", UIKit.ORANGE)
	if _phase_label != null:
		_phase_label.text = "T-00.0s"
	_play_sfx(_audio_ignition)
	_play_sfx(_audio_rumble)

	if not _reduced_fx:
		if _pad_smoke_left != null:
			_pad_smoke_left.emitting = true
		if _pad_smoke_right != null:
			_pad_smoke_right.emitting = true
	if _exhaust_plume != null:
		_exhaust_plume.queue_redraw()


func _update_ignition_phase() -> void:
	var t := clampf(_phase_time / 2.0, 0.0, 1.0)
	_shake_amount = lerpf(0.5, 2.8, t) if not _reduced_fx else 0.4
	_engine_light_glow = lerpf(0.25, 1.0, t)

	if _exhaust_plume != null:
		_exhaust_plume.queue_redraw()
	if _ground_illumination != null:
		_ground_illumination.queue_redraw()

	if _sky_canvas != null:
		_current_sky_zenith = _env_sky_zenith.lerp(_env_sky_zenith.lightened(0.12), sin(t * PI) * 0.45)
		_current_sky_horizon = _env_sky_horizon.lerp(_env_sun_color.lightened(0.2), sin(t * PI) * 0.35)
		_sky_canvas.queue_redraw()

	if _phase_time >= 2.0:
		_enter_liftoff_phase()


func _enter_liftoff_phase() -> void:
	_phase = Phase.LIFTOFF
	_phase_time = 0.0
	print("LAUNCH PHASE 3: LIFTOFF & ATMOSPHERIC ASCENT")
	if _countdown_label != null:
		_countdown_label.text = "LIFTOFF!"
		_countdown_label.add_theme_color_override("font_color", UIKit.LIVE)
	if _phase_label != null:
		_phase_label.text = "ATMOSPHERIC FLIGHT"
	_velocity = 6.0
	_acceleration = 18.0
	if _smoke_particles != null and not _reduced_fx:
		_smoke_particles.emitting = true


func _update_liftoff_phase(delta: float) -> void:
	_velocity += _acceleration * delta
	_altitude += _velocity * delta

	# Parallax layer movements:
	# Rocket ascends relative to camera
	if _rocket_root != null:
		_rocket_root.position.y -= _velocity * delta * 0.40
	# Foreground terrain and launch pad move down fast
	if _ground_root != null:
		_ground_root.position.y += _velocity * delta * 0.65
		_ground_root.modulate.a = 1.0 # 100% visible throughout atmospheric flight
	# Midground hills move down at medium rate
	if _midground_terrain_root != null:
		_midground_terrain_root.position.y += _velocity * delta * 0.38
		_midground_terrain_root.modulate.a = 1.0
	# Distant mountains move down slowly
	if _distant_mountains_root != null:
		_distant_mountains_root.position.y += _velocity * delta * 0.16
		_distant_mountains_root.modulate.a = 1.0
	_sun_offset_y += _velocity * delta * 0.05

	# Ensure space background remains strictly invisible during atmospheric flight
	if _space_root != null:
		_space_root.modulate.a = 0.0

	_engine_light_glow = clampf(1.0 - (_altitude / 100.0), 0.0, 1.0)
	_shake_amount = (2.8 + sin(_time * 28.0) * 0.6) if not _reduced_fx else 0.4

	if _sky_canvas != null:
		_sky_canvas.queue_redraw()
	if _ground_illumination != null:
		_ground_illumination.queue_redraw()
	if _exhaust_plume != null:
		_exhaust_plume.queue_redraw()
	if _clouds_root != null:
		_clouds_root.queue_redraw()
	if _gantry_arm_node != null:
		_gantry_arm_node.queue_redraw()
	elif _gantry_tower != null:
		_gantry_tower.queue_redraw()

	if _phase_time >= 3.8:
		_enter_ascent_phase()


func _enter_ascent_phase() -> void:
	_phase = Phase.ASCENT
	_phase_time = 0.0
	if _countdown_label != null:
		_countdown_label.text = "UPPER ATMOSPHERE"
		_countdown_label.add_theme_color_override("font_color", UIKit.CYAN)
	if _phase_label != null:
		_phase_label.text = "MAX-Q TRANSONIC EXIT"
	print("LAUNCH PHASE 4: UPPER ATMOSPHERE & PLANETARY HORIZON REVEAL")


func _update_ascent_phase(delta: float) -> void:
	_velocity += (_acceleration + 12.0) * delta
	_altitude += _velocity * delta

	var t := clampf(_phase_time / 3.2, 0.0, 1.0)

	# Parallax continuation: ground recedes and fades into atmospheric distance
	if _ground_root != null:
		_ground_root.position.y += _velocity * delta * 0.65
		_ground_root.modulate.a = clampf(1.0 - t * 1.3, 0.0, 1.0)
	if _midground_terrain_root != null:
		_midground_terrain_root.position.y += _velocity * delta * 0.38
		_midground_terrain_root.modulate.a = clampf(1.0 - t * 1.1, 0.0, 1.0)
	if _distant_mountains_root != null:
		_distant_mountains_root.position.y += _velocity * delta * 0.16
		_distant_mountains_root.modulate.a = clampf(1.0 - t * 1.0, 0.0, 1.0)
	_sun_offset_y += _velocity * delta * 0.05

	# Smooth atmospheric sky darkening into cosmic void
	var col_stratosphere := Color(0.015, 0.025, 0.055)
	var col_vacuum := Color(0.003, 0.005, 0.010)
	if t < 0.5:
		_current_sky_zenith = _env_sky_zenith.lerp(col_stratosphere, t * 2.0)
		_current_sky_horizon = _env_sky_horizon.lerp(col_stratosphere.lightened(0.12), t * 2.0)
	else:
		_current_sky_zenith = col_stratosphere.lerp(col_vacuum, (t - 0.5) * 2.0)
		_current_sky_horizon = col_stratosphere.lightened(0.12).lerp(col_vacuum, (t - 0.5) * 2.0)

	if _sky_rect != null:
		_sky_rect.color = _current_sky_zenith
	if _sky_canvas != null:
		_sky_canvas.queue_redraw()

	# Stars emerge only after atmosphere thins significantly
	if _space_root != null:
		_space_root.modulate.a = clampf((t - 0.35) / 0.65, 0.0, 1.0)

	if _shock_cone != null:
		if t >= 0.25 and t <= 0.60:
			var q_peak := sin((t - 0.25) / 0.35 * PI)
			_shock_cone.color.a = q_peak * 0.75
		else:
			_shock_cone.color.a = 0.0

	var sc := lerpf(1.0, 0.55, t)
	if _rocket_body != null:
		_rocket_body.scale = Vector2(sc, sc)
	if _rocket_root != null:
		_rocket_root.position = Vector2(320, lerpf(150, 120, t))

	if _exhaust_plume != null:
		_exhaust_plume.queue_redraw()
	if _clouds_root != null:
		_clouds_root.queue_redraw()
	if _earth_disc != null:
		_earth_disc.queue_redraw()

	if _phase_time >= 3.2:
		_enter_space_phase()


func _enter_space_phase() -> void:
	_phase = Phase.SPACE
	_phase_time = 0.0
	_shake_amount = 0.0
	print("LAUNCH PHASE 5: SPACE TRANSITION, STAGE SEPARATION & TRAJECTORY LOCK")
	if _countdown_label != null:
		_countdown_label.text = "ORBITAL INJECTION"
		_countdown_label.add_theme_color_override("font_color", UIKit.LIVE)
	if _phase_label != null:
		_phase_label.text = "STAGE SEPARATION NOMINAL"
	if _smoke_particles != null:
		_smoke_particles.emitting = false
	if _shock_cone != null:
		_shock_cone.visible = false
	if _ground_root != null:
		_ground_root.visible = false
	if _midground_terrain_root != null:
		_midground_terrain_root.visible = false
	if _distant_mountains_root != null:
		_distant_mountains_root.visible = false
	if _sky_canvas != null:
		_sky_canvas.visible = false
	if _space_root != null:
		_space_root.modulate.a = 1.0
	if _sky_rect != null:
		_sky_rect.color = Color(0.003, 0.005, 0.010)

	_play_sfx(_audio_staging)
	_separate_stages()
	_show_space_plaque()


func _separate_stages() -> void:
	var tw := create_tween()
	if _fairing_left != null:
		tw.tween_property(_fairing_left, "position:x", -65.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_fairing_left, "rotation", -0.85, 1.4)
		tw.parallel().tween_property(_fairing_left, "modulate:a", 0.0, 1.2)

	if _fairing_right != null:
		tw.parallel().tween_property(_fairing_right, "position:x", 65.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_fairing_right, "rotation", 0.85, 1.4)
		tw.parallel().tween_property(_fairing_right, "modulate:a", 0.0, 1.2)

	tw.parallel().tween_property(self, "_booster_offset_y", 180.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _booster_dropped = true)

	if _rocket_root != null:
		tw.parallel().tween_property(_rocket_root, "position", Vector2(230, 205), 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_rocket_root, "rotation", -0.32, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _target_planet_root != null:
		_target_planet_root.scale = Vector2(0.38, 0.38)
		tw.parallel().tween_property(_target_planet_root, "scale", Vector2(0.62, 0.62), 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _show_space_plaque() -> void:
	if _mission_plaque == null:
		_complete_and_transition()
		return
	var tw := create_tween()
	tw.tween_property(_mission_plaque, "modulate:a", 1.0, 0.45)
	tw.tween_interval(3.2 if not _is_subsequent else 2.4)
	tw.tween_callback(_complete_and_transition)


func _update_space_phase(delta: float) -> void:
	if _rocket_root != null:
		_rocket_root.position.x += 12.0 * delta
		_rocket_root.position.y += sin(_time * 1.8) * 0.18
	if _rocket_body != null:
		var b_node: Node2D = _rocket_body.get_node_or_null("Booster")
		if b_node != null and not _booster_dropped:
			b_node.queue_redraw()
	if _orbital_plume != null and _booster_dropped:
		_orbital_plume.queue_redraw()
	if _trajectory_overlay != null:
		_trajectory_overlay.queue_redraw()


func _process_subsequent_flight(delta: float) -> void:
	if _rocket_root != null:
		_rocket_root.position.x += 16.0 * delta
		_rocket_root.position.y += sin(_time * 1.8) * 0.18
	if _orbital_plume != null:
		_orbital_plume.queue_redraw()
	if _trajectory_overlay != null:
		_trajectory_overlay.queue_redraw()


# --- Skip & Scene Transition -----------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			_skip_launch()


func _skip_launch() -> void:
	if _skipping or _transitioned:
		return
	_skipping = true
	GameState.sfx("click")
	_complete_and_transition()


func _complete_and_transition() -> void:
	if _transitioned:
		return
	_transitioned = true
	_phase = Phase.TRANSITION

	if _audio_rumble != null and _audio_rumble.playing:
		var atw := create_tween()
		atw.tween_property(_audio_rumble, "volume_db", -40.0, 0.45)
		atw.tween_callback(_audio_rumble.stop)

	if _mission_plaque != null:
		var tw := create_tween()
		tw.tween_property(_mission_plaque, "modulate:a", 0.0, 0.3)

	if _hud_layer != null:
		var fade_rect := ColorRect.new()
		fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fade_rect.color = Color(0.003, 0.005, 0.010, 0.0)
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		_hud_layer.add_child(fade_rect)

		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 1.0, 0.45)
		tw.tween_interval(0.05)
		tw.tween_callback(func():
			if is_inside_tree() and get_tree() != null:
				print("LAUNCH SEQUENCE COMPLETE -> ENTERING SECTOR: ", _planet_name)
				get_tree().change_scene_to_file("res://scenes/sector.tscn")
		)
	else:
		if is_inside_tree() and get_tree() != null:
			print("LAUNCH SEQUENCE COMPLETE -> ENTERING SECTOR: ", _planet_name)
			get_tree().change_scene_to_file("res://scenes/sector.tscn")
