class_name LaunchCinematic
extends Control
## Cinematic Spacecraft Launch Sequence for Orbit & Outplay.
##
## Integrates a multi-phase launch into the mission architecture flow:
## - Phase 1: Launch Preparation (Pad, spotlights, gantry, status checklist, countdown)
## - Phase 2: Engine Ignition (Nozzle glow, flame trenches, smoke billows, pad illumination, screen shake)
## - Phase 3: Liftoff (Clamp release, swing arm retraction, vertical acceleration, camera tracking)
## - Phase 4: Atmospheric Ascent (Sky transition, rushing cloud layers, Max-Q shock collar, altitude scaling)
## - Phase 5: Space Transition (Curved Earth, booster cutoff, fairing jettison, spacecraft reveal, mission plaque)
## - Phase 6: Gameplay Transition (Fade into sector.tscn preserving all GameState data)
##
## Also supports:
## - Shorter orbital injection transition for subsequent planetary sectors (sector > 1)
## - Skip Launch option (SPACE / ESC / Skip Button)
## - Reduced-effects mode (--reduced-fx)
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
var _rocket_root: Node2D
var _rocket_body: Node2D
var _fairing_left: Node2D
var _fairing_right: Node2D
var _ship_sprite: Sprite2D
var _booster_sprite: Sprite2D
var _exhaust_plume: Node2D
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
var _head_panel: PanelContainer
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

# --- Rocket & Mission Data ---
var _hull_id: String = "pathfinder"
var _hull_name: String = "PATHFINDER"
var _hull_color: Color = Color("#54e6d1")
var _veh_id: String = "vector_m"
var _veh_name: String = "VECTOR M"
var _objective_title: String = "EXOPLANET SURVEY"
var _planet_name: String = "TARGET EXOPLANET"
var _planet_biome: String = "temperate"
var _distance_ly: float = 14.2
var _current_sector_no: int = 1

# --- Motion Parameters ---
var _altitude: float = 0.0
var _velocity: float = 0.0
var _acceleration: float = 0.0
var _countdown_val: int = 10
var _last_beep_val: int = -1
var _fairing_split: float = 0.0
var _booster_dropped: bool = false
var _booster_offset_y: float = 0.0


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
	if player != null and player.stream != null:
		player.play()


# --- Scene Construction ----------------------------------------------------

func _build_scene_layers() -> void:
	_world = Control.new()
	_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)

	# 1. Sky & Atmosphere Background
	_sky_rect = ColorRect.new()
	_sky_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_rect.color = Color(0.04, 0.07, 0.12)
	_world.add_child(_sky_rect)

	# 2. Deep Space Layer (Hidden during ground launch, revealed at Phase 5)
	_space_root = Control.new()
	_space_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_space_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_space_root.modulate.a = 0.0
	_world.add_child(_space_root)

	_space_backdrop = SpaceBackdrop.create({"planet_on": false, "stars_on": true, "dim": 0.20})
	_space_root.add_child(_space_backdrop)

	# Luminous Earth / Departure Planet Limb
	_earth_disc = Control.new()
	_earth_disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_earth_disc.draw.connect(_draw_earth_limb)
	_space_root.add_child(_earth_disc)

	# 3. Clouds & Atmospheric Wisps
	_clouds_root = Control.new()
	_clouds_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clouds_root.draw.connect(_draw_atmospheric_layers)
	_world.add_child(_clouds_root)
	# Native cloud strips replace the flat grey rectangles when VEGA lands them.
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
	# 2x VEGA art (280x76) replaces the 140x38 vector pad; same for the 26x160
	# gantry tower. The animated umbilical arms stay procedural on their own
	# node so they can still retract at liftoff over the sprite.
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


const SMOKE_PUFF_TEX := "res://assets/sprites/vehicles/smoke_puff.png"

func _soft_smoke_texture() -> Texture2D:
	# Square quad particles read as blocks at 640x360; a soft radial puff keeps
	# the billows readable as smoke at every scale.
	if ResourceLoader.exists(SMOKE_PUFF_TEX):
		return load(SMOKE_PUFF_TEX) as Texture2D
	return null

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
	# The soft puff texture is 64 px; keep the on-screen puff small enough that
	# billows stay individual shapes instead of washing the frame.
	p.scale_amount_min = 0.30
	p.scale_amount_max = 0.80
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.72, 0.35, 0.85),
		Color(0.85, 0.85, 0.90, 0.65),
		Color(0.40, 0.45, 0.55, 0.25),
		Color(0.20, 0.22, 0.30, 0.0)
	])
	p.color_ramp = grad
	var puff := _soft_smoke_texture()
	if puff != null:
		p.texture = puff
	return p


func _build_rocket_assembly() -> void:
	_rocket_body = Node2D.new()
	_rocket_root.add_child(_rocket_body)

	# Booster drawing node. If VEGA delivers a 2x vehicle sheet the procedural
	# draw is replaced; otherwise the vector silhouette stays the fallback.
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
			# Native 1x sheets win the artstyle pass; the 2x sheets still work
			# at an exact 0.5 so the pixel grid never lands on half-pixels.
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
			if "--debug-launch" in OS.get_cmdline_args() + OS.get_cmdline_user_args():
				print("LAUNCH booster art ", booster_art, " ", art_size,
					" scale=", art_scale)

	# Exhaust billows from VEGA's three frames. Added before the plume so the
	# flame core draws on top; the textures replace the hard polygon wedges.
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
	_ship_sprite.visible = false
	_rocket_body.add_child(_ship_sprite)

	# Aerodynamic Fairing Halves (Shroud payload during atmospheric ascent)
	# Fairing halves are containers so a native pixel-art pair can replace the
	# flat polygons without changing the jettison tween (rotation stays around
	# the stack axis, position slides out, modulate fades).
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
		# No fairing art yet: show VEGA's hull sprite rather than a flat white
		# polygon. `--vector-fairing` restores the old shroud for comparison.
		_fairing_left.visible = false
		_fairing_right.visible = false
		_ship_sprite.visible = true

	# Transonic Condensation Shock Collar (Max-Q cone)
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
	# Steel flame trench and mobile launch platform
	var pad_w := 140.0
	var pad_h := 38.0
	# Flame trench depression
	_pad_mount.draw_rect(Rect2(-pad_w * 0.5, 0, pad_w, pad_h), Color("#0a121a"))
	_pad_mount.draw_rect(Rect2(-32, 4, 64, pad_h - 4), Color("#04070c"))
	# Launch table beam structure
	_pad_mount.draw_line(Vector2(-pad_w * 0.5, 0), Vector2(pad_w * 0.5, 0), Color("#2b424d"), 3.0)
	_pad_mount.draw_line(Vector2(-42, 0), Vector2(-42, pad_h), Color("#1b2f38"), 2.0)
	_pad_mount.draw_line(Vector2(42, 0), Vector2(42, pad_h), Color("#1b2f38"), 2.0)
	# Hazard safety stripes on launch table deck
	for i in range(-5, 6):
		var sx := float(i) * 12.0
		_pad_mount.draw_line(Vector2(sx - 4, -1), Vector2(sx + 4, 3), Color(0.95, 0.75, 0.20, 0.75), 1.5)


func _draw_gantry() -> void:
	if _gantry_sprite != null and is_instance_valid(_gantry_sprite):
		return
	# Steel lattice service tower
	var w := 26.0
	var h := 160.0
	_gantry_tower.draw_rect(Rect2(0, -h, w, h), Color("#0d1720"))
	_gantry_tower.draw_rect(Rect2(0, -h, w, h), Color("#263d4a"), false, 1.5)
	# Cross trusses
	for y in range(0, int(h), 20):
		var py := -float(y)
		_gantry_tower.draw_line(Vector2(0, py), Vector2(w, py - 20), Color("#1e313d"), 1.0)
		_gantry_tower.draw_line(Vector2(w, py), Vector2(0, py - 20), Color("#1e313d"), 1.0)


func _draw_gantry_arms() -> void:
	# Umbilical service swing arms connecting to the rocket. Kept on their own
	# node so they can animate over VEGA's gantry sprite.
	var arm_rot := 0.0
	if _phase >= Phase.LIFTOFF:
		arm_rot = clampf((_time - 7.0) * 1.8, 0.0, 1.0)
	var upper_end := Vector2(-60 + arm_rot * 40.0, -118 - arm_rot * 22.0)
	_gantry_arm_node.draw_line(Vector2(0, -118), upper_end, Color("#3a5666"), 2.0)
	_gantry_arm_node.draw_circle(upper_end, 2.5, Color("#5ce1d0"))
	var lower_end := Vector2(-60 + arm_rot * 45.0, -42 - arm_rot * 26.0)
	_gantry_arm_node.draw_line(Vector2(0, -42), lower_end, Color("#ff7a2f"), 2.5)
	_gantry_arm_node.draw_circle(lower_end, 2.8, Color("#ffc45c"))


func _draw_spotlights() -> void:
	# Pad floodlights. The beam used to be one hard triangle per light, which
	# read as a grey wedge glued to the vehicle. It is now three nested cones per
	# light (wide+faint, mid, narrow+warm) so the edge falls off instead of
	# cutting, and both cones stop short of the booster body at x 300..340.
	var base_a := 0.055 if _phase < Phase.IGNITION else 0.085
	for side in [-1.0, 1.0]:
		var foot := Vector2(320.0 + side * 140.0, 290)
		var aim := Vector2(320.0, 236)
		for layer in 3:
			var widen := 1.0 - layer * 0.30
			var col := Color(0.85, 0.95, 1.0, base_a * (0.55 + layer * 0.35))
			if layer == 2:
				col = Color(1.0, 0.92, 0.78, base_a * 1.25)
			var near_w := 5.0 * widen
			var far_w := 13.0 * widen
			var dir := (aim - foot).normalized()
			var perp := Vector2(-dir.y, dir.x)
			_spotlights.draw_colored_polygon(PackedVector2Array([
				foot - perp * near_w,
				foot + perp * near_w,
				aim + perp * far_w,
				aim - perp * far_w
			]), col)
		_spotlights.draw_circle(foot, 3.6, Color(0.9, 0.98, 1.0, 0.85))
		_spotlights.draw_circle(foot, 1.6, Color(1.0, 0.96, 0.86, 0.95))


func _draw_booster() -> void:
	if _booster_dropped or _rocket_body == null:
		return
	var b_node: Node2D = _rocket_body.get_node_or_null("Booster")
	if b_node == null:
		return
	if _booster_sprite != null and is_instance_valid(_booster_sprite):
		return

	# Adjust position if staging occurred
	b_node.position.y = _booster_offset_y

	# Draw booster core geometry depending on vehicle selection:
	match _veh_id:
		"vector_l":
			_draw_vector_l_booster(b_node)
		"vector_h":
			_draw_vector_h_booster(b_node)
		_:
			_draw_vector_m_booster(b_node)


func _draw_vector_l_booster(node: Node2D) -> void:
	# Vector L: Sleek light-lift booster core (20px wide, single main nozzle)
	var w := 20.0
	var h := 70.0
	# Interstage / payload adapter
	node.draw_rect(Rect2(-w * 0.5, -30, w, 8), Color("#283945"))
	# Core tank
	node.draw_rect(Rect2(-w * 0.5, -22, w, h), Color("#e4e9f0"))
	# Roll pattern stripes & Agency markings
	node.draw_rect(Rect2(-w * 0.5, 0, w, 12), Color("#1b252e"))
	node.draw_rect(Rect2(-2, -18, 4, h - 8), Color("#ff7a2f"))
	# Base thrust puck & engine nozzle
	node.draw_rect(Rect2(-w * 0.5, h - 22, w, 4), Color("#1e2832"))
	node.draw_polygon(
		PackedVector2Array([Vector2(-6, h - 18), Vector2(6, h - 18), Vector2(8, h - 8), Vector2(-8, h - 8)]),
		[Color("#35424e")]
	)
	# Delta stabilizing fins at base
	node.draw_polygon(PackedVector2Array([Vector2(-10, h - 24), Vector2(-22, h - 10), Vector2(-10, h - 12)]), [Color("#23303b")])
	node.draw_polygon(PackedVector2Array([Vector2(10, h - 24), Vector2(22, h - 10), Vector2(10, h - 12)]), [Color("#23303b")])


func _draw_vector_m_booster(node: Node2D) -> void:
	# Vector M: Balanced medium-lift core (28px wide, dual nozzle cluster, side conduits)
	var w := 28.0
	var h := 82.0
	# Interstage adapter
	node.draw_rect(Rect2(-w * 0.5, -30, w, 8), Color("#202f3a"))
	# Core tank
	node.draw_rect(Rect2(-w * 0.5, -22, w, h), Color("#edf1f7"))
	# Dual roll pattern checkers
	node.draw_rect(Rect2(-w * 0.5, -6, w * 0.5, 14), Color("#17222b"))
	node.draw_rect(Rect2(0, 8, w * 0.5, 14), Color("#17222b"))
	# Side cable raceways & LOX feed line
	node.draw_rect(Rect2(-w * 0.5 - 2, -18, 2, h - 6), Color("#324452"))
	node.draw_rect(Rect2(w * 0.5, -18, 2, h - 6), Color("#324452"))
	# Base thrust structure
	node.draw_rect(Rect2(-w * 0.5, h - 22, w, 6), Color("#222f3b"))
	# Dual engine nozzles
	node.draw_polygon(PackedVector2Array([Vector2(-11, h - 16), Vector2(-3, h - 16), Vector2(-2, h - 6), Vector2(-12, h - 6)]), [Color("#3a4754")])
	node.draw_polygon(PackedVector2Array([Vector2(3, h - 16), Vector2(11, h - 16), Vector2(12, h - 6), Vector2(2, h - 6)]), [Color("#3a4754")])
	# Base aerodynamic fins
	node.draw_polygon(PackedVector2Array([Vector2(-14, h - 26), Vector2(-26, h - 10), Vector2(-14, h - 12)]), [Color("#1f2c38")])
	node.draw_polygon(PackedVector2Array([Vector2(14, h - 26), Vector2(26, h - 10), Vector2(14, h - 12)]), [Color("#1f2c38")])


func _draw_vector_h_booster(node: Node2D) -> void:
	# Vector H: Massive Heavy-Lift triple-core booster (Center core + 2 Strap-on Liquid Boosters)
	var cw := 26.0
	var bw := 18.0
	var h := 88.0
	# Center Core
	node.draw_rect(Rect2(-cw * 0.5, -30, cw, 8), Color("#223340"))
	node.draw_rect(Rect2(-cw * 0.5, -22, cw, h), Color("#f0f4fa"))
	node.draw_rect(Rect2(-3, -22, 6, h), Color("#ff7a2f"))
	# Left Strap-on Booster
	node.draw_polygon(PackedVector2Array([Vector2(-cw*0.5 - bw, -12), Vector2(-cw*0.5, -12), Vector2(-cw*0.5 - bw*0.5, -28)]), [Color("#d0d6e0")])
	node.draw_rect(Rect2(-cw * 0.5 - bw, -12, bw, h - 6), Color("#e2e7ef"))
	node.draw_rect(Rect2(-cw * 0.5 - 3, 10, 3, 12), Color("#1b2732")) # Strut
	# Right Strap-on Booster
	node.draw_polygon(PackedVector2Array([Vector2(cw*0.5, -12), Vector2(cw*0.5 + bw, -12), Vector2(cw*0.5 + bw*0.5, -28)]), [Color("#d0d6e0")])
	node.draw_rect(Rect2(cw * 0.5, -12, bw, h - 6), Color("#e2e7ef"))
	node.draw_rect(Rect2(cw * 0.5, 10, 3, 12), Color("#1b2732")) # Strut
	# 3 Engine Clusters (Left, Center, Right)
	node.draw_polygon(PackedVector2Array([Vector2(-cw*0.5 - 14, h - 18), Vector2(-cw*0.5 - 4, h - 18), Vector2(-cw*0.5 - 3, h - 7), Vector2(-cw*0.5 - 15, h - 7)]), [Color("#384654")])
	node.draw_polygon(PackedVector2Array([Vector2(-6, h - 14), Vector2(6, h - 14), Vector2(7, h - 5), Vector2(-7, h - 5)]), [Color("#384654")])
	node.draw_polygon(PackedVector2Array([Vector2(cw*0.5 + 4, h - 18), Vector2(cw*0.5 + 14, h - 18), Vector2(cw*0.5 + 15, h - 7), Vector2(cw*0.5 + 3, h - 7)]), [Color("#384654")])


func _draw_exhaust_plume() -> void:
	if _phase < Phase.IGNITION or _booster_dropped:
		if _plume_smoke != null:
			_plume_smoke.visible = false
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

	# Soft billows behind the tail. VEGA's frames are 160x96; keep them broad
	# and low-contrast so the white flame core stays the only bright element.
	if _plume_smoke != null:
		_plume_smoke.visible = true
	if not _plume_frames.is_empty():
		var fi := int(_time * 14.0) % _plume_frames.size()
		for k in range(_plume_billows.size()):
			var b: Sprite2D = _plume_billows[k]
			var side := float(b.get_meta("side", 1.0))
			b.texture = _plume_frames[(fi + k) % _plume_frames.size()]
			b.position = Vector2(
				side * (flame_w * 1.55 + 4.0),
				base_y + 26.0 + sin(_time * 9.0 + k * 2.1) * 3.0
			)
			var bs := (0.40 + 0.035 * sin(_time * 11.0 + k)) * clampf(1.0 + _altitude * 0.0008, 1.0, 1.35)
			b.scale = Vector2(bs, bs)
			b.rotation = side * (0.10 + 0.025 * sin(_time * 6.0 + k))
			b.modulate = Color(1.0, 0.97, 0.93, 0.58 + 0.16 * flick)

	# Outer Orange Fire Plume
	var outer_flame := PackedVector2Array([
		Vector2(-flame_w, base_y),
		Vector2(0, base_y + flame_len),
		Vector2(flame_w, base_y)
	])
	_exhaust_plume.draw_colored_polygon(outer_flame, Color(1.0, 0.45, 0.15, 0.78))

	# Inner Brilliant Yellow Flame Core
	var inner_flame := PackedVector2Array([
		Vector2(-flame_w * 0.6, base_y),
		Vector2(0, base_y + flame_len * 0.75),
		Vector2(flame_w * 0.6, base_y)
	])
	_exhaust_plume.draw_colored_polygon(inner_flame, Color(1.0, 0.90, 0.35, 0.92))

	# Core Plasma Spike
	var plasma_core := PackedVector2Array([
		Vector2(-flame_w * 0.28, base_y),
		Vector2(0, base_y + flame_len * 0.45),
		Vector2(flame_w * 0.28, base_y)
	])
	_exhaust_plume.draw_colored_polygon(plasma_core, Color(0.85, 0.98, 1.0, 0.98))

	# Supersonic Shock Diamonds (Mach Diamonds)
	for i in range(1, 4):
		var dy := base_y + float(i) * (flame_len * 0.22)
		if dy < base_y + flame_len * 0.85:
			var diamond := PackedVector2Array([
				Vector2(0, dy - 3.5),
				Vector2(3.5, dy),
				Vector2(0, dy + 3.5),
				Vector2(-3.5, dy)
			])
			_exhaust_plume.draw_colored_polygon(diamond, Color(0.92, 0.96, 1.0, 0.85 * flick))


func _draw_atmospheric_layers() -> void:
	if _phase != Phase.ASCENT:
		return
	# Fast passing horizontal stratus clouds rushing downwards
	var speed := _velocity * 3.2
	for i in range(7):
		var cy := fmod(float(i * 55) + _time * speed, 380.0) - 20.0
		var cw := 140.0 + sin(float(i) * 3.4) * 60.0
		var cx := 80.0 + float(i % 3) * 190.0
		var a := 0.10 + 0.06 * sin(float(i) + _time)
		if not _cloud_textures.is_empty():
			var tex: Texture2D = _cloud_textures[i % _cloud_textures.size()]
			var ch := tex.get_height() * (cw / maxf(1.0, tex.get_width()))
			_clouds_root.draw_texture_rect(tex, Rect2(cx, cy, cw, ch), false,
				Color(1, 1, 1, minf(1.0, a * 2.2)))
		else:
			_clouds_root.draw_rect(Rect2(cx, cy, cw, 14), Color(0.85, 0.92, 1.0, a))
			_clouds_root.draw_rect(Rect2(cx + 12, cy - 4, cw * 0.7, 8), Color(0.90, 0.95, 1.0, a * 0.8))


func _draw_earth_limb() -> void:
	# Curved Earth horizon below in space (Phase 5)
	var center := Vector2(320, 680)
	var radius := 380.0
	# Earth core
	_earth_disc.draw_circle(center, radius, Color(0.08, 0.22, 0.42))
	# Continents/surface hints
	_earth_disc.draw_arc(center, radius - 15, -PI * 0.65, -PI * 0.35, 32, Color(0.14, 0.38, 0.28, 0.8), 22.0)
	# Glowing blue atmospheric limb
	_earth_disc.draw_arc(center, radius + 2, -PI * 0.75, -PI * 0.25, 48, Color(0.40, 0.80, 1.0, 0.85), 3.5)
	_earth_disc.draw_arc(center, radius + 7, -PI * 0.72, -PI * 0.28, 36, Color(0.25, 0.65, 0.95, 0.35), 7.0)


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
	_head_panel = PanelContainer.new()
	_head_panel.position = Vector2(16, 14)
	_head_panel.add_theme_stylebox_override("panel", UIKit._ops_skin("panel", 6))
	root.add_child(_head_panel)

	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	_head_panel.add_child(hb)

	var title_lbl := UIKit.label("ORBIT & OUTPLAY  //  EXOPLANET INITIATIVE", 8, UIKit.CYAN, true)
	hb.add_child(title_lbl)

	var dest_lbl := UIKit.label("TARGET: %s  ·  %s" % [_planet_name, _planet_biome.to_upper()], 7, UIKit.CREAM, true)
	hb.add_child(dest_lbl)

	var veh_lbl := UIKit.label("VEHICLE: %s  |  PAYLOAD: %s" % [_veh_name, _hull_name], 7, UIKit.MUTED_C, true)
	hb.add_child(veh_lbl)

	# Readiness Telemetry Checklist (Top Left under Header) — kept for data,
	# never shown: the launch is a short transition, not a pre-flight sim.
	_status_vbox = VBoxContainer.new()
	_status_vbox.position = Vector2(18, 72)
	_status_vbox.add_theme_constant_override("separation", 3)
	root.add_child(_status_vbox)
	_status_vbox.visible = false

	var check_items := [
		"PAD INTEGRITY: NOMINAL",
		"CRYOGENICS: 100% PRESSURIZED",
		"AVIONICS & GUIDANCE: GO",
		"RANGE SAFETY: GREEN"
	]
	for txt in check_items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var dot := UIKit.label("[O]", 7, UIKit.DIM_C, true)
		var l := UIKit.label(txt, 7, UIKit.DIM_C, true)
		row.add_child(dot)
		row.add_child(l)
		_status_vbox.add_child(row)
		_status_items.append({"dot": dot, "label": l, "active": false})

	# Big Digital Countdown Clock (Top Center)
	_countdown_label = UIKit.label("T-10.0s", 16, UIKit.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER)
	_countdown_label.position = Vector2(236, 14)
	_countdown_label.size = Vector2(180, 28)
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_countdown_label)
	_countdown_label.visible = false
	# Phase word on its own row. Appending it to the clock made the ignition
	# string wider than its slot and it wrote over the agency header.
	_phase_label = UIKit.label("", 7, UIKit.ORANGE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_phase_label.position = Vector2(240, 39)
	_phase_label.size = Vector2(160, 10)
	root.add_child(_phase_label)
	_phase_label.visible = false

	# Skip Launch Button (Bottom Right)
	_skip_button = UIKit.button("SKIP LAUNCH  >", Vector2(100, 22))
	_skip_button.position = Vector2(524, 324)
	_skip_button.pressed.connect(_skip_launch)
	root.add_child(_skip_button)

	var skip_hint := UIKit.label("[SPACE / ESC]", 6, UIKit.DIM_C, true, HORIZONTAL_ALIGNMENT_RIGHT)
	skip_hint.position = Vector2(430, 328)
	skip_hint.size = Vector2(88, 14)
	root.add_child(skip_hint)

	# Mission Success Plaque (Hidden until Phase 5)
	_build_mission_plaque(root)


func _build_mission_plaque(parent: Control) -> void:
	_mission_plaque = PanelContainer.new()
	_mission_plaque.position = Vector2(24, 56)
	_mission_plaque.size = Vector2(330, 192)
	_mission_plaque.add_theme_stylebox_override("panel", UIKit._ops_skin("panel", 6))
	_mission_plaque.modulate.a = 0.0
	parent.add_child(_mission_plaque)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	_mission_plaque.add_child(vb)

	var badge := UIKit.label("★  LAUNCH SUCCESSFUL  ·  TRAJECTORY NOMINAL  ★", 8, UIKit.LIVE, true, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(badge)

	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vb.add_child(sep)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)

	var add_row := func(k: String, val: String, col: Color) -> void:
		grid.add_child(UIKit.label(k, 8, UIKit.MUTED_C, true))
		grid.add_child(UIKit.label(val, 8, col, true))

	add_row.call("LAUNCH VEHICLE:", _veh_name, UIKit.CREAM)
	add_row.call("SPACECRAFT HULL:", _hull_name, _hull_color)
	add_row.call("PRIMARY OBJECTIVE:", _objective_title, UIKit.AMBER)
	add_row.call("DESTINATION:", "%s (%.1f LY)" % [_planet_name, _distance_ly], UIKit.CYAN)
	add_row.call("STATUS:", "TRANSFER ARC INSERTION CONFIRMED", UIKit.LIVE)

	var bot_hint := UIKit.label("COMMENCING SURFACE SURVEY APPROACH...", 7, UIKit.DIM_C, true, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(bot_hint)


# --- Sequence Timelines ----------------------------------------------------

func _start_launch_sequence() -> void:
	_phase = Phase.PREPARATION
	_time = 0.0
	_phase_time = 0.0
	_countdown_val = 10
	print("LAUNCH PHASE 1: PREPARATION | Spacecraft: %s | Vehicle: %s | Target: %s" % [_hull_name, _veh_name, _planet_name])


func _start_subsequent_sequence() -> void:
	# Shorter, high-energy trans-planetary injection sequence for subsequent sectors
	_phase = Phase.SPACE
	_sky_rect.color = Color(0.008, 0.012, 0.024)
	_space_root.modulate.a = 1.0
	_ground_root.visible = false
	_countdown_label.visible = false
	_status_vbox.visible = false
	_booster_dropped = true
	_fairing_left.visible = false
	_fairing_right.visible = false
	_ship_sprite.visible = true
	_ship_sprite.position = Vector2(0, 0)
	_ship_sprite.scale = Vector2(0.55, 0.55)
	_rocket_root.position = Vector2(480, 170)
	print("LAUNCH SUBSEQUENT ORBITAL DEPARTURE | Spacecraft: %s | Target: %s" % [_hull_name, _planet_name])
	
	_play_sfx(_audio_staging)
	_show_space_plaque()


func _process(delta: float) -> void:
	if _transitioned:
		return
	
	_time += delta
	_phase_time += delta

	# Screen Shake application
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
		Phase.PREPARATION:
			_update_preparation_phase()

		Phase.IGNITION:
			_update_ignition_phase()

		Phase.LIFTOFF:
			_update_liftoff_phase(delta)

		Phase.ASCENT:
			_update_ascent_phase(delta)

		Phase.SPACE:
			_update_space_phase(delta)


func _update_preparation_phase() -> void:
	# 0.0s to 4.5s: Countdown from T-10s down to T-2s
	var remaining := maxf(1.0, 10.0 - (_time * 6.0))
	var c_int := int(ceil(remaining))
	_countdown_label.text = "T-%d.0s" % c_int

	# Audio beep on distinct countdown milestones: 10, 5, 3
	if c_int != _last_beep_val and (c_int in [10, 5, 3]):
		_last_beep_val = c_int
		_play_sfx(_audio_beep)

	# Progressively activate telemetry checklist items
	var active_count := int(clampf(_time * 1.0, 0.0, float(_status_items.size())))
	for i in range(_status_items.size()):
		var item: Dictionary = _status_items[i]
		if i < active_count and not item["active"]:
			item["active"] = true
			(item["dot"] as Label).text = "[✓]"
			(item["dot"] as Label).add_theme_color_override("font_color", UIKit.LIVE)
			(item["label"] as Label).add_theme_color_override("font_color", UIKit.CREAM)

	if _time >= 0.25:
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
	_play_sfx(_audio_beep)
	
	if _pad_smoke_left != null:
		_pad_smoke_left.emitting = true
	if _pad_smoke_right != null:
		_pad_smoke_right.emitting = true
	if _exhaust_plume != null:
		_exhaust_plume.queue_redraw()

	var tw := create_tween()
	tw.tween_property(self, "_shake_amount", 1.8 if not _reduced_fx else 0.4, 1.2)


func _update_ignition_phase() -> void:
	# Engines spin up, smoke billows, pad illuminates, rumble begins
	if _phase_time >= 1.2 and _audio_rumble != null and not _audio_rumble.playing:
		_play_sfx(_audio_rumble)

	if _phase_time >= 0.55:
		_enter_liftoff_phase()


func _enter_liftoff_phase() -> void:
	_phase = Phase.LIFTOFF
	_phase_time = 0.0
	print("LAUNCH PHASE 3: LIFTOFF & GANTRY RELEASE")
	if _countdown_label != null:
		_countdown_label.text = "LIFTOFF!"
		# Countdown sits at x236..416; "LIFTOFF!" is wider than "T-10.0s" and used
		# to start inside the mission header panel and clip at the top edge.
		_countdown_label.position = Vector2(300, 16)
		_countdown_label.size = Vector2(210, 28)
		_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_countdown_label.add_theme_color_override("font_color", UIKit.LIVE)
	if _phase_label != null:
		_phase_label.text = ""
	if _smoke_particles != null:
		_smoke_particles.emitting = true
	_acceleration = 46.0
	_velocity = 62.0
	_shake_amount = 3.2 if not _reduced_fx else 0.6


func _update_liftoff_phase(delta: float) -> void:
	_velocity += _acceleration * delta
	_altitude += _velocity * delta

	# Rocket moves up, pad moves down
	if _rocket_root != null:
		_rocket_root.position.y = 240.0 - (_altitude * 0.45)
	if _ground_root != null:
		_ground_root.position.y = _altitude * 0.55

	if _exhaust_plume != null:
		_exhaust_plume.queue_redraw()
	if _gantry_tower != null:
		_gantry_tower.queue_redraw()

	if _altitude >= 150.0:
		_enter_ascent_phase()


func _enter_ascent_phase() -> void:
	_phase = Phase.ASCENT
	_phase_time = 0.0
	print("LAUNCH PHASE 4: ATMOSPHERIC ASCENT & TRANSONIC MAX-Q")
	if _countdown_label != null:
		_countdown_label.visible = false
	if _status_vbox != null:
		_status_vbox.visible = false
	if _ground_root != null:
		_ground_root.visible = false


func _update_ascent_phase(delta: float) -> void:
	_velocity += (_acceleration + 18.0) * delta
	_altitude += _velocity * delta

	# One long, eased atmosphere -> space handoff. The old version switched
	# colour halves in a straight line and only began the space fade at 50 %,
	# so the star plate arrived as a block while the sky was already dark.
	var t := clampf(_phase_time / 2.4, 0.0, 1.0)
	var e := smoothstep(0.0, 1.0, t)
	# Start in the thin outer atmosphere, not a dusk-lit inner sky. The rocket
	# is already well above the weather by the time this phase opens, so the
	# palette begins close to the void and only the airglow changes.
	var col_dusk := Color(0.018, 0.042, 0.085)
	var col_mid := Color(0.014, 0.028, 0.075)
	var col_space := Color(0.008, 0.012, 0.024)
	if _sky_rect != null:
		var sky := col_dusk.lerp(col_mid, smoothstep(0.0, 0.55, e))
		sky = sky.lerp(col_space, smoothstep(0.45, 1.0, e))
		_sky_rect.color = sky
	# Stars come up first and early; the Earth limb waits until the airglow
	# has thinned, so the horizon does not pop on at the phase change.
	if _space_root != null:
		_space_root.modulate.a = smoothstep(0.18, 1.0, t)
	if _earth_disc != null:
		_earth_disc.modulate.a = smoothstep(0.48, 0.98, t)
	if _clouds_root != null:
		_clouds_root.modulate.a = 1.0 - smoothstep(0.30, 0.86, t)

	# Max-Q Condensation Cone (flares at t between 0.35 and 0.65)
	if _shock_cone != null:
		if t >= 0.35 and t <= 0.65:
			var q_peak := sin((t - 0.35) / 0.30 * PI)
			_shock_cone.color.a = q_peak * 0.75
		else:
			_shock_cone.color.a = 0.0

	# Scale rocket down gracefully as it ascends to show immense altitude
	var sc := lerpf(1.0, 0.55, t)
	if _rocket_body != null:
		_rocket_body.scale = Vector2(sc, sc)
	if _rocket_root != null:
		_rocket_root.position = Vector2(320, lerpf(160, 120, t))

	if _exhaust_plume != null:
		_exhaust_plume.queue_redraw()
	if _clouds_root != null:
		_clouds_root.queue_redraw()

	if _phase_time >= 2.4:
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
	if _earth_disc != null:
		_earth_disc.modulate.a = 1.0
	if _clouds_root != null:
		_clouds_root.visible = false

	# Stage Separation: Booster drops away, fairings split, payload is revealed.
	if _ship_sprite != null:
		_ship_sprite.visible = true
	_play_sfx(_audio_staging)
	_separate_stages()
	_show_space_plaque()


func _separate_stages() -> void:
	var tw := create_tween()
	# Fairings pop and tumble outward
	if _fairing_left != null:
		tw.tween_property(_fairing_left, "position:x", -65.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_fairing_left, "rotation", -0.85, 1.4)
		tw.parallel().tween_property(_fairing_left, "modulate:a", 0.0, 1.2)

	if _fairing_right != null:
		tw.parallel().tween_property(_fairing_right, "position:x", 65.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_fairing_right, "rotation", 0.85, 1.4)
		tw.parallel().tween_property(_fairing_right, "modulate:a", 0.0, 1.2)

	# Booster falls away downward
	tw.parallel().tween_property(self, "_booster_offset_y", 180.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _booster_dropped = true)


func _show_space_plaque() -> void:
	if _mission_plaque == null:
		_complete_and_transition()
		return
	var tw := create_tween()
	if _head_panel != null:
		tw.parallel().tween_property(_head_panel, "modulate:a", 0.0, 0.30)
	if _rocket_root != null:
		tw.parallel().tween_property(_rocket_root, "position:x", 480.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mission_plaque, "modulate:a", 1.0, 0.45)
	tw.tween_interval(1.4 if not _is_subsequent else 0.9)
	tw.tween_callback(_complete_and_transition)


func _update_space_phase(delta: float) -> void:
	# Spacecraft gently floats forward in microgravity
	if _rocket_root != null:
		_rocket_root.position.y += sin(_time * 1.5) * 0.15
	if _rocket_body != null:
		var b_node: Node2D = _rocket_body.get_node_or_null("Booster")
		if b_node != null and not _booster_dropped:
			b_node.queue_redraw()


func _process_subsequent_flight(delta: float) -> void:
	if _rocket_root != null:
		_rocket_root.position.x += 18.0 * delta
		_rocket_root.position.y += sin(_time * 2.0) * 0.2


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

	# Stop rumble audio smoothly
	if _audio_rumble != null and _audio_rumble.playing:
		var atw := create_tween()
		atw.tween_property(_audio_rumble, "volume_db", -40.0, 0.45)
		atw.tween_callback(_audio_rumble.stop)

	# Fade to black and change scene to sector.tscn
	if _hud_layer != null:
		var fade_rect := ColorRect.new()
		fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fade_rect.color = Color(0.01, 0.015, 0.025, 0.0)
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		_hud_layer.add_child(fade_rect)

		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 1.0, 0.25)
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
