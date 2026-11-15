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
var _ground_root: Control
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

	var sec: Dictionary = GameState.current_sector
	if not sec.is_empty():
		var p: Dictionary = sec.get("planet", {})
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
	if _current_sector_no <= 1:
		_departure_name = "EARTH (CAPE CANAVERAL)"
		_departure_biome = "earth"
		_departure_info = {
			"name": "EARTH",
			"color": Color("#4fa8ff"),
			"rim": Color(0.35, 0.75, 1.0, 0.95),
			"terrain": "CONTINENTAL BIOSPHERE • OCEANS",
			"atmosphere": "1.00 ATM N2/O2 • WATER CLOUD DECKS",
		}
	else:
		if GameState.history.size() > 0:
			var prev_p: Dictionary = GameState.history[GameState.history.size() - 1].get("planet", {})
			_departure_name = str(prev_p.get("name", "SECTOR 1 BASE")).to_upper()
			_departure_biome = str(prev_p.get("biome", "barren"))
			_departure_info = get_biome_info(_departure_biome)
		else:
			_departure_name = "ORBITAL STAGING OUTPOST"
			_departure_biome = "barren"
			_departure_info = get_biome_info("barren")


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

	# 1. Sky & Atmosphere Background (Day/Twilight on ground -> Dark vacuum in space)
	_sky_rect = ColorRect.new()
	_sky_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_rect.color = Color(0.04, 0.07, 0.12)
	_world.add_child(_sky_rect)

	# 2. Deep Space Layer (Stars, Destination Planet, Departure Limb, Transfer Arc)
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

	# 3. Clouds & Atmospheric Wisps (Lower atmosphere during ascent)
	_clouds_root = Control.new()
	_clouds_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clouds_root.draw.connect(_draw_atmospheric_layers)
	_world.add_child(_clouds_root)
	for i in range(3):
		var cloud_path := "res://assets/sprites/vehicles/cloud_band_%d.png" % i
		if ResourceLoader.exists(cloud_path):
			_cloud_textures.append(load(cloud_path) as Texture2D)

	# 4. Ground & Launch Pad
	_ground_root = Control.new()
	_ground_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.add_child(_ground_root)

	_pad_mount = Control.new()
	_pad_mount.position = Vector2(320, 275)
	_pad_mount.draw.connect(_draw_launch_pad)
	_ground_root.add_child(_pad_mount)

	var pad_art := "res://assets/sprites/vehicles/launch_pad.png"
	if ResourceLoader.exists(pad_art):
		_pad_sprite = Sprite2D.new()
		_pad_sprite.texture = load(pad_art) as Texture2D
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
		_gantry_sprite = Sprite2D.new()
		_gantry_sprite.texture = load(gantry_art) as Texture2D
		_gantry_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_gantry_sprite.centered = false
		_gantry_sprite.scale = Vector2(0.5, 0.5)
		_gantry_sprite.position = Vector2(0, -160)
		_gantry_tower.add_child(_gantry_sprite)

	_gantry_arm_node = Node2D.new()
	_gantry_arm_node.name = "GantryArms"
	_gantry_arm_node.draw.connect(_draw_gantry_arms)
	_gantry_tower.add_child(_gantry_arm_node)

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
			_plume_frames.append(load(frame_path) as Texture2D)
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
	if ResourceLoader.exists(fairing_left_art) and ResourceLoader.exists(fairing_right_art):
		for pair in [[_fairing_left, fairing_left_art, -14.0], [_fairing_right, fairing_right_art, 0.0]]:
			var host: Node2D = pair[0]
			var tex := load(str(pair[1])) as Texture2D
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.centered = false
			var sc := 0.5 if tex.get_width() > 20 else 1.0
			spr.scale = Vector2(sc, sc)
			spr.position = Vector2(float(pair[2]), -98.0)
			host.add_child(spr)
	elif _vector_fairing:
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
	
	if _no_fairing or (not ResourceLoader.exists(fairing_left_art) and not _vector_fairing):
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
	if _phase != Phase.ASCENT:
		return
	var speed := _velocity * 3.2
	for i in range(7):
		var cy := fmod(float(i * 55) + _time * speed, 380.0) - 20.0
		var cw := 140.0 + sin(float(i) * 3.4) * 60.0
		var cx := 80.0 + float(i % 3) * 190.0
		var a := (0.18 + 0.12 * sin(float(i) + _time)) * clampf(1.0 - (_altitude / 70.0), 0.0, 1.0)
		if a > 0.01:
			_clouds_root.draw_rect(Rect2(cx, cy, cw, 14), Color(0.85, 0.92, 1.0, a))
			_clouds_root.draw_rect(Rect2(cx + 12, cy - 4, cw * 0.7, 8), Color(0.90, 0.95, 1.0, a * 0.8))


func _draw_earth_limb() -> void:
	if _phase < Phase.ASCENT:
		return
	var center := Vector2(160, 560)
	var radius := 320.0
	if _departure_biome == "earth":
		_earth_disc.draw_circle(center, radius, Color(0.04, 0.12, 0.28))
		_earth_disc.draw_arc(center, radius - 15, -PI * 0.68, -PI * 0.32, 36, Color(0.12, 0.28, 0.18, 0.85), 24.0)
		_earth_disc.draw_arc(center, radius - 28, -PI * 0.62, -PI * 0.38, 28, Color(0.92, 0.95, 1.0, 0.35), 14.0)
		_earth_disc.draw_arc(center, radius + 2, -PI * 0.75, -PI * 0.25, 48, Color(0.35, 0.75, 1.0, 0.90), 3.5)
		_earth_disc.draw_arc(center, radius + 6, -PI * 0.72, -PI * 0.28, 36, Color(0.20, 0.50, 0.95, 0.30), 6.0)
	else:
		var base_col: Color = _departure_info.get("color", Color("#a8b4c0"))
		var rim_col: Color = _departure_info.get("rim", Color(0.7, 0.8, 0.9, 0.8))
		_earth_disc.draw_circle(center, radius, base_col.darkened(0.65))
		_earth_disc.draw_arc(center, radius - 14, -PI * 0.68, -PI * 0.32, 32, base_col.darkened(0.25), 22.0)
		_earth_disc.draw_arc(center, radius + 2, -PI * 0.75, -PI * 0.25, 48, rim_col, 3.5)
		_earth_disc.draw_arc(center, radius + 6, -PI * 0.72, -PI * 0.28, 36, rim_col * Color(1, 1, 1, 0.35), 6.0)


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
	_countdown_label = UIKit.label("T-10.0s", 16, UIKit.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER)
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
	_countdown_val = 10
	print("LAUNCH PHASE 1: PREPARATION | Spacecraft: %s | Vehicle: %s | Target: %s" % [_hull_name, _veh_name, _planet_name])


func _start_subsequent_sequence() -> void:
	_phase = Phase.SPACE
	_sky_rect.color = Color(0.003, 0.005, 0.010)
	_space_root.modulate.a = 1.0
	_ground_root.visible = false
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
	var c := 10
	if t < 0.8: c = 10
	elif t < 1.6: c = 5
	elif t < 2.3: c = 3
	elif t < 2.8: c = 2
	else: c = 1

	if c != _countdown_val:
		_countdown_val = c
		_countdown_label.text = "T-%02d.0s" % _countdown_val
		_countdown_label.add_theme_color_override("font_color", UIKit.CREAM)
		_play_sfx(_audio_beep)
		
		var active_idx: int = 4 - mini(c, 4)
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

	if _phase_time >= 3.2:
		_enter_ignition_phase()


func _enter_ignition_phase() -> void:
	_phase = Phase.IGNITION
	_phase_time = 0.0
	print("LAUNCH PHASE 2: ENGINE IGNITION & FLAME TRENCH EXHAUST")
	if _countdown_label != null:
		_countdown_label.text = "T-1.0s"
		_countdown_label.add_theme_color_override("font_color", UIKit.ORANGE)
	if _phase_label != null:
		_phase_label.text = "IGNITION"
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
	_shake_amount = lerpf(0.5, 3.2, t) if not _reduced_fx else 0.4
	
	if _exhaust_plume != null:
		_exhaust_plume.queue_redraw()

	if _sky_rect != null:
		var col_dusk := Color(0.04, 0.07, 0.12)
		var col_flash := Color(0.14, 0.09, 0.08)
		_sky_rect.color = col_dusk.lerp(col_flash, sin(t * PI) * 0.45)

	if _phase_time >= 2.2:
		_enter_liftoff_phase()


func _enter_liftoff_phase() -> void:
	_phase = Phase.LIFTOFF
	_phase_time = 0.0
	print("LAUNCH PHASE 3: LIFTOFF & GANTRY RELEASE")
	if _countdown_label != null:
		_countdown_label.text = "LIFTOFF!"
		_countdown_label.add_theme_color_override("font_color", UIKit.LIVE)
	if _phase_label != null:
		_phase_label.text = ""
	_velocity = 8.0
	_acceleration = 24.0
	if _smoke_particles != null and not _reduced_fx:
		_smoke_particles.emitting = true


func _update_liftoff_phase(delta: float) -> void:
	_velocity += _acceleration * delta
	_altitude += _velocity * delta

	if _rocket_root != null:
		_rocket_root.position.y -= _velocity * delta * 0.65
	if _ground_root != null:
		_ground_root.position.y += _velocity * delta * 0.45

	_shake_amount = (3.5 + sin(_time * 30.0) * 0.8) if not _reduced_fx else 0.5

	if _exhaust_plume != null:
		_exhaust_plume.queue_redraw()
	if _gantry_arm_node != null:
		_gantry_arm_node.queue_redraw()
	elif _gantry_tower != null:
		_gantry_tower.queue_redraw()

	if _phase_time >= 2.4:
		_enter_ascent_phase()


func _enter_ascent_phase() -> void:
	_phase = Phase.ASCENT
	_phase_time = 0.0
	if _countdown_label != null:
		_countdown_label.text = "MAX-Q ASCENT"
		_countdown_label.add_theme_color_override("font_color", UIKit.CYAN)
	print("LAUNCH PHASE 4: ATMOSPHERIC ASCENT & TRANSONIC MAX-Q")


func _update_ascent_phase(delta: float) -> void:
	_velocity += (_acceleration + 18.0) * delta
	_altitude += _velocity * delta

	var t := clampf(_phase_time / 3.4, 0.0, 1.0)
	var col_dusk := Color(0.04, 0.07, 0.12)
	var col_stratosphere := Color(0.02, 0.03, 0.07)
	var col_vacuum := Color(0.003, 0.005, 0.010)
	
	if _sky_rect != null:
		if t < 0.5:
			_sky_rect.color = col_dusk.lerp(col_stratosphere, t * 2.0)
		else:
			_sky_rect.color = col_stratosphere.lerp(col_vacuum, (t - 0.5) * 2.0)
	
	if _space_root != null:
		_space_root.modulate.a = clampf((t - 0.25) / 0.70, 0.0, 1.0)

	if _shock_cone != null:
		if t >= 0.35 and t <= 0.65:
			var q_peak := sin((t - 0.35) / 0.30 * PI)
			_shock_cone.color.a = q_peak * 0.75
		else:
			_shock_cone.color.a = 0.0

	var sc := lerpf(1.0, 0.55, t)
	if _rocket_body != null:
		_rocket_body.scale = Vector2(sc, sc)
	if _rocket_root != null:
		_rocket_root.position = Vector2(320, lerpf(160, 120, t))

	if _exhaust_plume != null:
		_exhaust_plume.queue_redraw()
	if _clouds_root != null:
		_clouds_root.queue_redraw()
	if _earth_disc != null:
		_earth_disc.queue_redraw()

	if _phase_time >= 3.6:
		_enter_space_phase()


func _enter_space_phase() -> void:
	_phase = Phase.SPACE
	_phase_time = 0.0
	_shake_amount = 0.0
	print("LAUNCH PHASE 5: SPACE TRANSITION, STAGE SEPARATION & TRAJECTORY LOCK")
	if _smoke_particles != null:
		_smoke_particles.emitting = false
	if _shock_cone != null:
		_shock_cone.visible = false
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
