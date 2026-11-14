extends "res://scripts/map_generator.gd"
## Surface operations for one exoplanet sector.

const OBJECTIVE_NODES := 4
# The board is drawn isometrically; a screen-direction step is a diagonal in
# grid space. Use 8-way moves so "range 3" means three visible steps, not one.
const MOVE_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

# Boundary sides of a cell as [neighbour offset, first corner, second corner]
# with corners numbered 0=NW, 1=NE, 2=SE, 3=SW. Clockwise order keeps the
# union contour continuous when the strokes are drawn independently.
const REACH_SIDES := [
	[Vector2i(-1, 0), 0, 3],  # west  NW -> SW
	[Vector2i(1, 0), 1, 2],   # east  NE -> SE
	[Vector2i(0, -1), 0, 1],  # north NW -> NE
	[Vector2i(0, 1), 3, 2],   # south SW -> SE
]

const HAZARDS := {
	"flare": {
		"name": "STELLAR FLARE", "color": Color("#ff6d5e"), "block": true,
		"integrity": 1, "thermal": 8, "dv": 0, "power": 0,
	},
	"thermal": {
		"name": "THERMAL SURGE", "color": Color("#ff9c4a"), "block": true,
		"integrity": 0, "thermal": 24, "dv": 0, "power": 0,
	},
	"dust": {
		"name": "DUST STORM", "color": Color("#d8b070"), "block": true,
		"integrity": 1, "thermal": 0, "dv": 1, "power": 0,
	},
	"quake": {
		"name": "SEISMIC SHOCK", "color": Color("#ffc45c"), "block": false,
		"integrity": 1, "thermal": 0, "dv": 0, "power": 0,
	},
	"radiation": {
		"name": "RADIATION BELT", "color": Color("#7fe08a"), "block": true,
		"integrity": 1, "thermal": 5, "dv": 0, "power": 0,
	},
	"eclipse": {
		# Signed deltas: thermal < 0 cools, power < 0 restores. `_resolve_hazard`
		# subtracts these values, so a positive `power` would drain the pips.
		"name": "ECLIPSE SHADOW", "color": Color("#7cc8ff"), "block": false,
		"integrity": 0, "thermal": -16, "dv": 0, "power": -2,
	},
	"cryo": {
		"name": "CRYO QUAKE", "color": Color("#9fd9ff"), "block": false,
		"integrity": 1, "thermal": 0, "dv": 1, "power": 0,
	},
	"wind": {
		"name": "SOLAR WIND FRONT", "color": Color("#ff7a59"), "block": true,
		"integrity": 0, "thermal": 15, "dv": 1, "power": 0,
	},
	"meteor": {
		"name": "METEOR SHOWER", "color": Color("#ffb35c"), "block": false,
		"integrity": 2, "thermal": 4, "dv": 0, "power": 0,
	},
}

var sec: Dictionary = {}
var done := false
var sector_planet: TextureRect
var hazard_info: Dictionary = {}
var hazards: Array[Dictionary] = []
var scars: Array[Dictionary] = []
var message_color := Color("#54e6d1")
var toast_label: Label
var _toast_tween: Tween
var fx_layer: Node2D
var vfx_layer: Node2D
var pad_beacon: VFX.RingNode
var _ending_turn := false
var _last_strike_near := false
var _world_timer := 2.4
var _star_timer := 5.0
var fx_root: Control
var _state_overlay: ColorRect
var _state_mat: ShaderMaterial
var _impact_flash: ColorRect

var name_label: Label
var biome_label: Label
var int_label: Label
var dv_label: Label
var sol_label: Label
var data_label: Label
var data_caption: Label
var heat_bar: UIGauge
var heat_val: Label
var data_bar: ProgressBar
var power_pips: Array = []
var threat_label: Label
var route_label: Label
var dpad: Control
var hold_btn: Button
var extract_btn: Button
var move_btn: Button
var lz_flag: Polygon2D

var turn := 1
var start_cell := Vector2i.ZERO
var moved := false
var move_range := 3
var cursor_cell := Vector2i.ZERO
var path_cells: Array[Vector2i] = []
var path_valid := false
var path_cost := 0
var path_heat := 0
var path_nodes := 0
var move_layer: Node2D

var result_layer: Control


func _ready() -> void:
	MusicDirector.play("sector")
	sec = GameState.current_sector
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--debug-transitions" in args:
		debug_transitions = true
	if "--fog" in args:
		fog_enabled = true
	if "--no-fog" in args:
		fog_enabled = false
	# Tactical sector view: keep the rectangular focus but let the shader fade
	# the slab edge into space. The old circle mask hid too much of the board.
	if "--circle" not in args:
		circle_view = false
	var force_relay := "--relay" in args
	if sec.is_empty():
		# Recover gracefully if someone opens the scene directly.
		GameState.new_run()
		GameState.quick_loadout()
		GameState.commit_design()
		if force_relay:
			GameState.run["sector"] = 2
		var p: Dictionary = GameState.draft[0]
		GameState.begin_sector(p)
		sec = GameState.current_sector
	RenderingServer.set_default_clear_color(Color("#070a11"))
	zoom = 1.35
	_build_tileset()
	_build_view()
	move_layer = Node2D.new()
	move_layer.z_index = 24
	add_child(move_layer)
	fx_layer = Node2D.new()
	fx_layer.z_index = 21
	add_child(fx_layer)
	# Impact/pickup effects sit above actors (25) but below the HUD canvas (26+).
	vfx_layer = Node2D.new()
	vfx_layer.z_index = 27
	add_child(vfx_layer)
	var fx_canvas := CanvasLayer.new()
	fx_canvas.layer = 26
	add_child(fx_canvas)
	fx_root = Control.new()
	fx_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_canvas.add_child(fx_root)
	# Persistent state overlay (low hull / heat) sits below the one-shot hit
	# flash so a hit still whites out the screen.
	_state_overlay = ColorRect.new()
	_state_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_state_overlay.color = Color(1, 1, 1, 0)
	_state_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_mat = ShaderMaterial.new()
	_state_mat.shader = load("res://shaders/screen_state.gdshader") as Shader
	_state_overlay.material = _state_mat
	fx_root.add_child(_state_overlay)
	_impact_flash = ColorRect.new()
	_impact_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_impact_flash.color = Color(1, 0.2, 0.15, 0)
	_impact_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_root.add_child(_impact_flash)
	_build_hud()
	_start_sector()
	GameState.sfx("confirm")
	for raw in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var arg := str(raw)
		if arg.begins_with("--moves="):
			_run_dev_moves(arg.substr(8).to_upper())
		elif arg.begins_with("--turns="):
			for _i in range(int(arg.substr(8))):
				if not done:
					_end_turn()
		elif arg == "--hurt":
			if not hazards.is_empty():
				player_cell = hazards[0]["cells"][0]
				_end_turn()
		elif arg.begins_with("--select="):
			var sp := arg.substr(9).split(",")
			if sp.size() == 2:
				_select_cell(player_cell + Vector2i(int(sp[0]), int(sp[1])))
		elif arg.begins_with("--pathmove="):
			var parts := arg.substr(11).split(",")
			if parts.size() == 2:
				_select_cell(player_cell + Vector2i(int(parts[0]), int(parts[1])))
				_execute_path()
		elif arg == "--result=success":
			sec["data"] = 4
			_end(true, "SURVEY COMPLETE")
		elif arg == "--result=fail":
			sec["integrity"] = 0
			_end(false, "HULL BREACH")
		elif arg == "--collect":
			# QA hook for the pickup flash/sound without hunting for a node.
			if not objectives.is_empty():
				_collect_node_at(objectives[0])
		elif arg.begins_with("--fx="):
			# Visual QA hook: play one effect sequence on a loop so a movie
			# capture can show it. `--fx=all` plays impact, shield, pickup and
			# the extraction beacon in order.
			_run_fx_demo(arg.substr(5).to_lower())



func _configure_map() -> void:
	var p: Dictionary = sec["planet"]
	var h: int = absi(int(hash(str(p["id"])))) % 90000 + 1000
	seed_value = h + int(sec["sector"]) * 7919
	planet_name = str(p["name"])
	# Resolve the terrain index by name, not by a shared ordinal: the playable
	# planet list omits ocean, so an ordinal lookup would silently shift every
	# biome after volcanic and render barren worlds as water.
	biome_index = 0
	for i in range(BIOMES.size()):
		if str(BIOMES[i]["id"]) == str(p["biome"]):
			biome_index = i
			break
	_generate()
	# _generate() resets the demo counters; the sector holds the real ones.
	planet_name = str(p["name"])


func _paint_space_planet() -> void:
	if space_layer == null:
		return
	if sector_planet == null:
		sector_planet = TextureRect.new()
		sector_planet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sector_planet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sector_planet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sector_planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		space_layer.add_child(sector_planet)
	var p: Dictionary = sec.get("planet", {})
	var path := SpaceBackdrop.asset_for_planet(p)
	var biome := str(p.get("biome", "barren"))
	var hd_path := "res://assets/sprites/planets/sector/%s.png" % biome
	if ResourceLoader.exists(hd_path):
		path = hd_path
	if not ResourceLoader.exists(path):
		sector_planet.visible = false
		return
	sector_planet.texture = load(path) as Texture2D
	sector_planet.position = Vector2(520, -32)
	sector_planet.size = Vector2(270, 270)
	sector_planet.modulate = Color(1, 1, 1, 0.14)
	sector_planet.visible = true


func _start_sector() -> void:
	objective_mode = str(sec.get("mode", "survey"))
	_configure_map()
	_paint_space_planet()
	start_cell = player_cell
	turn = 1
	moved = false
	move_range = int(sec.get("move_range", 3))
	cursor_cell = player_cell
	path_cells.clear()
	path_valid = false
	path_cost = 0
	path_heat = 0
	path_nodes = 0
	hazards.clear()
	scars.clear()
	revealed.clear()
	_reveal_around(player_cell, 5)
	_spawn_hazard()
	_update_chunks()
	_render_window()
	_refresh_all()
	_draw_move_preview()
	_spawn_pad_beacon()
	_play_landing()
	if bool(sec.get("shakedown", false)):
		_show_toast("SHAKEDOWN // +2 HULL · RANGE %d" % move_range, UIKit.CYAN)


func _play_landing() -> void:
	if vfx_layer == null:
		return
	await get_tree().create_timer(0.06).timeout
	if done:
		return
	var at := _cell_center(player_cell)
	VFX.beam(vfx_layer, at, Color(0.45, 0.95, 0.88, 0.55), 26.0, 0.34, 9)
	VFX.dust(vfx_layer, at, Color(0.58, 0.64, 0.56, 0.55), 10, 30.0)
	VFX.ring(vfx_layer, at, UIKit.CYAN, 22.0, 0.38, 1.6, 8)


func _spawn_pad_beacon() -> void:
	if vfx_layer == null:
		return
	if pad_beacon != null and is_instance_valid(pad_beacon):
		pad_beacon.queue_free()
	if lz_flag != null and is_instance_valid(lz_flag):
		lz_flag.queue_free()
	var mast := Line2D.new()
	mast.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -28)])
	mast.width = 2.0
	mast.default_color = Color(0.33, 0.90, 0.82, 0.62)
	mast.position = _cell_center(start_cell)
	vfx_layer.add_child(mast)
	var beam := Line2D.new()
	beam.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -58)])
	beam.width = 3.0
	beam.default_color = Color(1.0, 0.69, 0.0, 0.38)
	beam.position = _cell_center(start_cell)
	vfx_layer.add_child(beam)
	lz_flag = Polygon2D.new()
	lz_flag.polygon = PackedVector2Array([Vector2(0, 0), Vector2(18, -7), Vector2(0, -14)])
	lz_flag.color = Color(1.0, 0.69, 0.0, 0.95)
	lz_flag.position = _cell_center(start_cell) + Vector2(0, -44)
	vfx_layer.add_child(lz_flag)
	var ring := VFX.RingNode.new()
	ring.position = _cell_center(start_cell)
	ring.z_index = 2
	ring.z_as_relative = true
	ring.radius = 17.0
	ring.width = 1.6
	ring.ring_color = Color(0.33, 0.90, 0.82, 0.55)
	ring.set_meta("pad_beacon", true)
	vfx_layer.add_child(ring)
	pad_beacon = ring
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "radius", 25.0, 1.1).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(ring, "ring_color:a", 0.10, 1.1)
	tw.tween_property(ring, "radius", 17.0, 1.1).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(ring, "ring_color:a", 0.55, 1.1)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# ----- top mission bar
	var top := UIKit.panel(Color(0.035, 0.055, 0.085, 0.94), Color("#2b4058"))
	top.position = Vector2(10, 6)
	top.size = Vector2(620, 40)
	root.add_child(top)
	var tc := Control.new()
	tc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tc)

	name_label = UIKit.head("—", 9, UIKit.TEXT)
	name_label.position = Vector2(10, 3)
	name_label.size = Vector2(150, 14)
	tc.add_child(name_label)
	biome_label = UIKit.mono("—", 7, UIKit.MUTED)
	biome_label.position = Vector2(10, 19)
	biome_label.size = Vector2(150, 12)
	tc.add_child(biome_label)

	for sx in [166.0, 222.0, 274.0, 322.0, 398.0, 506.0]:
		var sep := ColorRect.new()
		sep.color = Color(0.16, 0.25, 0.35, 0.55)
		sep.position = Vector2(sx, 8)
		sep.size = Vector2(1, 24)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tc.add_child(sep)

	int_label = _top_stat(tc, 172, "INTEGRITY", UIKit.RED, 48)
	dv_label = _top_stat(tc, 228, "DELTA-V", UIKit.CYAN, 44)
	sol_label = _top_stat(tc, 280, "SOLS", UIKit.AMBER, 40)
	data_caption = UIKit.mono("DATA", 6, UIKit.DIM)
	data_caption.position = Vector2(328, 4)
	data_caption.size = Vector2(60, 11)
	tc.add_child(data_caption)
	data_label = UIKit.head("—", 10, UIKit.GREEN)
	data_label.position = Vector2(328, 15)
	data_label.size = Vector2(60, 14)
	tc.add_child(data_label)

	var heat_l := UIKit.mono("THERMAL", 6, UIKit.DIM)
	heat_l.position = Vector2(404, 4)
	heat_l.size = Vector2(60, 11)
	tc.add_child(heat_l)
	heat_val = UIKit.mono("0", 8, UIKit.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	heat_val.position = Vector2(464, 3)
	heat_val.size = Vector2(32, 11)
	tc.add_child(heat_val)
	heat_bar = UIKit.bar(64, 5, UIKit.AMBER)
	heat_bar.position = Vector2(404, 21)
	tc.add_child(heat_bar)

	var pwr_l := UIKit.mono("POWER", 6, UIKit.DIM)
	pwr_l.position = Vector2(512, 4)
	pwr_l.size = Vector2(64, 11)
	tc.add_child(pwr_l)
	for i in range(12):
		var pip := ColorRect.new()
		pip.color = UIKit.CYAN
		pip.position = Vector2(512 + i * 6, 21)
		pip.size = Vector2(5, 5)
		tc.add_child(pip)
		power_pips.append(pip)

	# Hover dossiers: the HUD keeps numbers only; the rules live behind the
	# cursor, Balatro-style, when a judge wants the exact mechanic.
	_hover_cell(tc, Rect2(168, 2, 52, 36), "INTEGRITY",
		"Hull hits left. At 0 the sector fails.\nBlockable hazards spend shield power; unblockable ones always land.",
		UIKit.RED)
	_hover_cell(tc, Rect2(224, 2, 50, 36), "DELTA-V",
		"Fuel left. Each path tile costs 1 ΔV.\nAt 0 the sector fails; return to the lander to extract.",
		UIKit.CYAN)
	_hover_cell(tc, Rect2(276, 2, 44, 36), "SOLS",
		"Mission window. One sol per move or HOLD.\nAt 0 the sector fails.",
		UIKit.AMBER)
	_hover_cell(tc, Rect2(324, 2, 70, 36), "DATA",
		"Nodes delivered / quota.\nMeet the quota, return to the lander, then EXTRACT.",
		UIKit.GREEN)
	_hover_cell(tc, Rect2(400, 2, 100, 36), "THERMAL LOAD",
		"Heat rises every move. At 100: overload, -1 hull.\nHOLD vents 8 + thermal resistance and burns one sol.",
		UIKit.AMBER)
	_hover_cell(tc, Rect2(508, 2, 114, 36), "POWER",
		"Shield energy for blockable hazards.\nRecharges at end of turn; HOLD adds reactor vent power.",
		UIKit.CYAN)

	# ----- bottom-left status
	var bottom := UIKit.panel(Color(0.035, 0.055, 0.085, 0.92), Color("#2b4058"))
	bottom.position = Vector2(10, 314)
	bottom.size = Vector2(414, 36)
	root.add_child(bottom)
	var bc := Control.new()
	bc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bc)

	threat_label = UIKit.head("—", 8, UIKit.AMBER)
	threat_label.position = Vector2(8, 3)
	threat_label.size = Vector2(398, 12)
	bc.add_child(threat_label)
	route_label = UIKit.mono("—", 7, UIKit.MUTED)
	route_label.position = Vector2(8, 18)
	route_label.size = Vector2(398, 12)
	bc.add_child(route_label)

	toast_label = UIKit.head("", 9, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.position = Vector2(110, 288)
	toast_label.size = Vector2(300, 18)
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_label.add_theme_constant_override("outline_size", 3)
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	# ----- input cluster
	dpad = Control.new()
	dpad.position = Vector2(554, 252)
	dpad.size = Vector2(76, 76)
	dpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dpad)
	_add_dpad(Vector2(25, 0), "W", Vector2i(0, -1))
	_add_dpad(Vector2(0, 25), "A", Vector2i(-1, 0))
	_add_dpad(Vector2(50, 25), "D", Vector2i(1, 0))
	_add_dpad(Vector2(25, 50), "S", Vector2i(0, 1))

	move_btn = UIKit.button("MOVE  (ENTER)", Vector2(112, 22), true)
	move_btn.position = Vector2(436, 268)
	move_btn.add_theme_font_size_override("font_size", 8)
	move_btn.pressed.connect(_execute_path)
	root.add_child(move_btn)
	hold_btn = UIKit.button("HOLD  (SPACE)", Vector2(112, 22))
	hold_btn.position = Vector2(436, 294)
	hold_btn.add_theme_font_size_override("font_size", 8)
	hold_btn.pressed.connect(_hold)
	root.add_child(hold_btn)
	extract_btn = UIKit.button("EXTRACT  (E)", Vector2(112, 22))
	extract_btn.position = Vector2(436, 320)
	extract_btn.add_theme_font_size_override("font_size", 8)
	extract_btn.pressed.connect(_extract)
	root.add_child(extract_btn)


func _hover_cell(parent: Control, rect: Rect2, title: String, body: String,
	accent: Color = UIKit.CYAN) -> void:
	var zone := Control.new()
	zone.position = rect.position
	zone.size = rect.size
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(zone)
	UIKit.hover_info(zone, title, body, accent)



func _top_stat(parent: Control, x: float, name: String, color: Color, w: float = 52.0) -> Label:
	var l := UIKit.mono(name, 6, UIKit.DIM)
	l.position = Vector2(x, 4)
	l.size = Vector2(w, 11)
	parent.add_child(l)
	var v := UIKit.head("—", 10, color)
	v.position = Vector2(x, 14)
	v.size = Vector2(w, 15)
	parent.add_child(v)
	return v


func _add_dpad(pos: Vector2, text: String, dir: Vector2i) -> void:
	var b := UIKit.button(text, Vector2(25, 25))
	b.position = pos
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(_on_dpad.bind(dir))
	dpad.add_child(b)


func _run_dev_moves(seq: String) -> void:
	for ch in seq:
		if done:
			break
		match ch:
			"D":
				_try_move(_screen_to_grid(Vector2i(1, 0)))
			"A":
				_try_move(_screen_to_grid(Vector2i(-1, 0)))
			"W":
				_try_move(_screen_to_grid(Vector2i(0, -1)))
			"S":
				_try_move(_screen_to_grid(Vector2i(0, 1)))
			"H":
				_hold()
			"E":
				_extract()


func _is_relay() -> bool:
	return str(sec.get("mode", "survey")) == "relay"


func _objective_cap() -> int:
	return int(sec.get("quota", 3)) if _is_relay() else OBJECTIVE_NODES


func _refresh_all() -> void:
	_refresh_status()


func _refresh_status() -> void:
	if int_label == null or sec.is_empty():
		return
	var p: Dictionary = sec["planet"]
	name_label.text = str(p["name"])
	var sector_no := int(sec["sector"])
	biome_label.text = "%s · %s · %d/3 · T%d" % [
		GameState.biome_name(str(p["biome"])).to_upper(),
		"RELAY" if _is_relay() else "SURVEY", sector_no, turn
	]
	biome_label.add_theme_color_override("font_color", GameState.biome_color(str(p["biome"])))

	int_label.text = "%d/%d" % [int(sec["integrity"]), int(sec["integrity_max"])]
	int_label.add_theme_color_override("font_color",
		UIKit.RED if int(sec["integrity"]) <= 1 else UIKit.TEXT)
	dv_label.text = str(int(sec["delta_v"]))
	dv_label.add_theme_color_override("font_color",
		UIKit.RED if int(sec["delta_v"]) <= 5 else UIKit.CYAN)
	sol_label.text = str(int(sec["sols"]))
	sol_label.add_theme_color_override("font_color",
		UIKit.RED if int(sec["sols"]) <= 5 else UIKit.AMBER)
	data_caption.text = "RELAYS" if _is_relay() else "DATA"
	data_label.text = "%d/%d" % [int(sec["data"]), int(sec["quota"])]

	UIKit.set_bar(heat_bar, float(sec["thermal"]), 100.0)
	heat_val.text = "%d" % int(sec["thermal"])
	var hc := UIKit.GREEN
	if float(sec["thermal"]) >= 75:
		hc = UIKit.RED
	elif float(sec["thermal"]) >= 45:
		hc = UIKit.AMBER
	UIKit.set_bar_color(heat_bar, hc)
	heat_val.add_theme_color_override("font_color", hc)

	if _state_mat != null:
		var hull_now := int(sec["integrity"])
		var low := 0.0
		if hull_now <= 1:
			low = 1.0
		elif hull_now == 2:
			low = 0.45
		_state_mat.set_shader_parameter("screen_size", get_viewport_rect().size)
		_state_mat.set_shader_parameter("low_hull", low)
		_state_mat.set_shader_parameter("heat", clampf((float(sec["thermal"]) - 68.0) / 32.0, 0.0, 1.0))
		_state_mat.set_shader_parameter("alert", 1.0 if done else 0.0)

	for i in range(power_pips.size()):
		var pip: ColorRect = power_pips[i]
		var on := i < int(sec["power"])
		var beyond := i >= int(sec["power_max"])
		pip.visible = not beyond
		pip.color = UIKit.CYAN if on else Color("#22344a")

	# The bed drops ~6 dB while a telegraph is on screen so the alarm/thud cues
	# sit above it; it comes back up as soon as the sector is clear or closed.
	MusicDirector.set_duck(not done and not hazards.is_empty())

	if done:
		threat_label.text = "SECTOR CLOSED  ·  DEBRIEF READY"
		threat_label.add_theme_color_override("font_color", UIKit.CYAN if game_over else UIKit.MUTED)
	elif not hazards.is_empty():
		var first: Dictionary = hazards[0]["info"]
		var shield := int(sec["shield_cost"])
		var sweep := false
		var forming := false
		for h in hazards:
			if int(h["speed"]) > 0:
				sweep = true
			if int(h.get("age", 1)) < 1:
				forming = true
		var names: Array[String] = []
		for h in hazards:
			names.append(str(h["info"]["name"]).split(" ")[0])
		var tag := names[0] if names.size() == 1 else "%s +%d" % [names[0], names.size() - 1]
		var tail := "SWEEP" if sweep else ("SHIELD %d PWR OR -%d INT" % [shield, int(first["integrity"])] if bool(first["block"]) else "UNBLOCKABLE")
		if forming:
			tail = ("SWEEP · " if sweep else "") + "ARMS NEXT TURN"
		threat_label.text = "%s: %s  ·  %s" % ["FORMING" if forming else "INCOMING", tag, tail]
		threat_label.add_theme_color_override("font_color", first["color"])
	else:
		threat_label.text = "—"

	if done:
		route_label.text = "Continue to the debrief for grants, approval, and refit."
		route_label.add_theme_color_override("font_color", UIKit.MUTED)
		if move_btn != null:
			move_btn.disabled = true
		return
	var quota := int(sec["quota"])
	var base := "TURN %d · RANGE %d" % [turn, _current_range()]
	var threat := float(sec.get("threat", 1.0))
	if threat > 1.01:
		base += " · THREAT %.1fx" % threat
	if cursor_cell != player_cell:
		if path_valid:
			route_label.text = "%s · PATH %d · %d dv · HEAT +%d%s%s" % [
				base, path_cost, path_cost, path_heat,
				" · NODE" if path_nodes > 0 else "",
				" · HAZARD" if _path_has_hazard() else ""
			]
			route_label.add_theme_color_override("font_color", UIKit.AMBER if _path_has_hazard() else UIKit.CYAN)
		else:
			route_label.text = "%s · NO PATH / OUT OF RANGE" % base
			route_label.add_theme_color_override("font_color", UIKit.RED)
	elif int(sec["data"]) >= quota:
		if player_cell == start_cell:
			route_label.text = "%s · %s — E EXTRACT" % [base, "RELAYS READY" if _is_relay() else "QUOTA MET"]
		else:
			route_label.text = "%s · QUOTA MET — RETURN TO LANDER" % base
		route_label.add_theme_color_override("font_color", UIKit.GREEN)
	else:
		var need := quota - int(sec["data"])
		var noun := "relay" if need == 1 else "relays"
		if not _is_relay():
			noun = "node" if need == 1 else "nodes"
		route_label.text = "%s · need %d more %s · CLICK A TILE" % [base, need, noun]
		route_label.add_theme_color_override("font_color", Color("#a9bccf"))
	if move_btn != null:
		move_btn.disabled = done or moved or not path_valid or path_cost <= 0


func _fill_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(1)
	return s


func _spawn_hazard() -> void:
	if done:
		return
	# Spawn against the window the player will actually see after this move.
	view_origin = player_cell - Vector2i(view_w / 2, view_h / 2)
	var budget := _hazard_budget()
	var guard := 0
	while hazards.size() < budget and guard < 20:
		guard += 1
		var h := _roll_hazard()
		if h.is_empty():
			continue
		if _hazard_overlaps(h):
			continue
		hazards.append(h)
	_sync_primary()


func _hazard_budget() -> int:
	var b := 1
	if int(sec.get("sector", 1)) == 1:
		# Shakedown board: one front, then a second at turn 5. Never three.
		if turn >= 5:
			b = 2
		b += int(sec.get("hazard_mod", 0))
		return clampi(b, 1, 2)
	if turn >= 3:
		b += 1
	if turn >= 6:
		b += 1
	if int(sec.get("sector", 1)) >= 2 and turn >= 4:
		b += 1
	b += int(sec.get("hazard_mod", 0))
	# Quadratic tier bonus: sector 3 gets one extra front, sectors 1–2 do not.
	b += int(floor(pow(float(int(sec.get("sector", 1)) - 1), 2.0) * 0.25))
	return clampi(b, 1, 4)


func _roll_hazard() -> Dictionary:
	var pool := _hazard_pool()
	var kind: String = pool[rng.randi_range(0, pool.size() - 1)]
	var info: Dictionary = HAZARDS[kind]
	var sector_no := int(sec.get("sector", 1))
	var shape := "block"
	var dir := Vector2i.ZERO
	var sweep := false
	var forced_sweep := turn == 3 and hazards.is_empty()
	if forced_sweep:
		shape = "line"
	elif turn >= 3:
		var r := rng.randf()
		if r < 0.30:
			shape = "line"
		elif r < 0.55:
			shape = "cross"
		elif r < 0.68:
			shape = "diamond"
	if shape == "line":
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		dir = dirs[rng.randi_range(0, dirs.size() - 1)]
		sweep = forced_sweep or rng.randf() < 0.45 + 0.12 * float(sector_no) + 0.03 * float(turn)
	for attempt in range(10):
		var anchor := _hazard_anchor()
		# The visual anchor is the *centre* of the footprint, so a sweep arrow
		# can start at the middle of its line. `cells[0]` is physically one end
		# of the front, which put the arrow two cells off the line.
		var origin_cell := anchor
		var cells: Array[Vector2i] = []
		match shape:
			"line":
				var perp := Vector2i(-dir.y, dir.x)
				var start_cell := anchor
				if sweep:
					start_cell = player_cell - dir * 3
				origin_cell = start_cell
				for i in range(-2, 3):
					cells.append(start_cell + perp * i)
			"cross":
				cells = [anchor, anchor + Vector2i(1, 0), anchor + Vector2i(-1, 0),
					anchor + Vector2i(0, 1), anchor + Vector2i(0, -1)]
			"diamond":
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						if absi(dx) + absi(dy) <= 2:
							cells.append(anchor + Vector2i(dx, dy))
			_:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						cells.append(anchor + Vector2i(dx, dy))
		if not _hazard_cells_valid(cells):
			continue
		if cells.has(player_cell):
			continue
		var life := 4 if sweep else 1
		return {
			"kind": kind, "info": info, "cells": cells,
			"origin": origin_cell, "shape": shape, "dir": dir,
			"speed": 1 if sweep else 0, "life": life,
			# A front forms for one turn (faint, not yet dangerous) before it
			# arms. That extra read is the planning window, not extra damage.
			"age": 0,
		}
	return {}


func _hazard_anchor() -> Vector2i:
	var base := player_cell
	var open_nodes: Array[Vector2i] = []
	for i in range(objectives.size()):
		if not collected[i]:
			open_nodes.append(objectives[i])
	if not open_nodes.is_empty() and rng.randf() < 0.55:
		base = open_nodes[rng.randi_range(0, open_nodes.size() - 1)]
	var cell := base + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
	cell.x = clampi(cell.x, player_cell.x - view_w / 2 + 3, player_cell.x + view_w / 2 - 3)
	cell.y = clampi(cell.y, player_cell.y - view_h / 2 + 3, player_cell.y + view_h / 2 - 3)
	return cell


func _hazard_cells_valid(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var walkable := 0
	for c in cells:
		if not _in_view(c.x, c.y):
			return false
		if _is_walkable_world(c):
			walkable += 1
	# A footprint that lands entirely on mountains, structures, water or lava
	# can never touch the player, yet it still consumes a hazard budget slot.
	# Require at least one reachable tile so every front is a real threat.
	return walkable > 0


func _hazard_overlaps(h: Dictionary) -> bool:
	for other in hazards:
		for c in h["cells"]:
			if other["cells"].has(c):
				return true
	return false


func _advance_hazards() -> void:
	var kept: Array[Dictionary] = []
	for h in hazards:
		var age := int(h.get("age", 1))
		if age >= 1:
			h["life"] = int(h["life"]) - 1
			if int(h["speed"]) > 0:
				var d: Vector2i = h["dir"]
				var old_origin: Vector2i = h["origin"]
				var moved: Array[Vector2i] = []
				for c in h["cells"]:
					moved.append(c + d)
				h["cells"] = moved
				h["origin"] = Vector2i(h["origin"]) + d
				if vfx_layer != null:
					# Trail behind the advancing front so a sweep reads as a
					# moving threat, not a rectangle that teleported.
					var col: Color = h["info"]["color"]
					VFX.dust(vfx_layer, _cell_center(old_origin),
						Color(col.r, col.g, col.b, 0.45), 5, 16.0)
		h["age"] = age + 1
		if age == 0 and vfx_layer != null and not h["cells"].is_empty():
			# FORMING -> ARMED: a single ring at the front's centre is the cue
			# that the telegraph is now live.
			var arm_col: Color = h["info"]["color"]
			VFX.ring(vfx_layer, _cell_center(h["origin"]), arm_col, 24.0, 0.4, 1.8)
		if int(h["life"]) > 0 and not h["cells"].is_empty():
			var visible := false
			for c in h["cells"]:
				if _in_view(c.x, c.y):
					visible = true
					break
			if visible:
				kept.append(h)
	hazards = kept
	_sync_primary()


func _sync_primary() -> void:
	if hazards.is_empty():
		hazard_info = {}
		hazard_kind = ""
		hazard_cell = Vector2i(-999, -999)
		return
	var h: Dictionary = hazards[0]
	hazard_info = h["info"]
	hazard_kind = str(hazard_info["name"])
	hazard_color = hazard_info["color"]
	hazard_cell = h["origin"]


func _hazard_pool() -> Array:
	var p: Dictionary = sec["planet"]
	var g: Dictionary = p["game"]
	var pool: Array = []
	if int(g["heat"]) >= 55:
		pool.append_array(["thermal", "wind", "quake", "flare"])
	if int(g["radiation"]) >= 35:
		pool.append_array(["radiation", "flare", "wind"])
	match str(p["biome"]):
		"cryo", "ammonia":
			pool.append_array(["cryo", "cryo", "eclipse", "wind"])
		"arid", "barren", "iron":
			pool.append_array(["dust", "meteor", "quake"])
		"volcanic", "sulfur", "obsidian":
			pool.append_array(["thermal", "meteor", "quake", "flare"])
		"temperate", "methane":
			pool.append_array(["flare", "dust", "eclipse"])
		"crystal":
			pool.append_array(["quake", "eclipse", "radiation"])
		_:
			pool.append_array(["dust", "flare"])
	if pool.is_empty():
		pool.append_array(["dust", "flare", "quake"])
	return pool


func _try_move(dir: Vector2i) -> void:
	# Development hook (`--moves=`). Route it through the shipped turn model so
	# QA captures match real play: the old copy resolved the hazard on entry,
	# ignored move range and never advanced the turn.
	if done:
		return
	var target := player_cell + dir
	if not _is_walkable_world(target):
		GameState.sfx("deny")
		return
	_select_cell(target)
	if path_valid and not path_cells.is_empty():
		_execute_path()



# ---------------------------------------------------------------------------
# Turn-based movement (Into the Breach style): choose a destination, preview
# the whole path and its cost, commit one move, then resolve the hazard.
# ---------------------------------------------------------------------------

func _current_range() -> int:
	# M6 return weight: once the quota is aboard every extra sample is mass.
	# The first cargo box costs one range; additional boxes cost one each.
	var cargo := maxi(0, int(sec.get("data", 0)) - int(sec.get("quota", 3)) + 1)
	if int(sec.get("data", 0)) < int(sec.get("quota", 3)):
		cargo = 0
	return maxi(1, move_range - cargo)


func _select_cell(cell: Vector2i) -> void:
	if done:
		return
	if not _in_view(cell.x, cell.y):
		return
	cursor_cell = cell
	# Every path tile spends 1 delta-v and 1 sol, so the reachable radius is the
	# smallest of the ship's range and the resources actually left. Without
	# this cap the preview would accept a 3-tile path with 1 dv left and
	# `_execute_path` would strand the lander and fail the sector.
	var resource_cap := mini(int(sec["delta_v"]), int(sec["sols"]))
	path_cells = _find_path(player_cell, cell, mini(_current_range(), maxi(0, resource_cap)))
	path_valid = cell == player_cell or not path_cells.is_empty()
	path_cost = path_cells.size()
	path_heat = path_cost * int(sec.get("heat_gain", 1))
	path_nodes = 0
	for i in range(objectives.size()):
		if not collected[i] and objectives[i] in path_cells:
			path_nodes += 1
	_draw_move_preview()
	_refresh_status()


func _move_cursor(step: Vector2i) -> void:
	var next := cursor_cell + step
	if not _in_view(next.x, next.y):
		return
	_select_cell(next)


func _on_dpad(dir: Vector2i) -> void:
	_move_cursor(_screen_to_grid(dir))


func _find_path(start: Vector2i, goal: Vector2i, max_steps: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if start == goal:
		return out
	var dist := {start: 0}
	var came := {}
	var q: Array[Vector2i] = [start]
	var head := 0
	var found := false
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		if int(dist[cur]) >= max_steps:
			continue
		for d in MOVE_DIRS:
			var n: Vector2i = cur + d
			if dist.has(n) or not _is_walkable_world(n):
				continue
			dist[n] = int(dist[cur]) + 1
			came[n] = cur
			q.append(n)
			if n == goal:
				found = true
				break
		if found:
			break
	if not found:
		return out
	var step = goal
	while step != start:
		out.push_front(step)
		step = came[step]
	return out


func _reachable_cells(max_steps: int) -> Dictionary:
	var dist := {player_cell: 0}
	var q: Array[Vector2i] = [player_cell]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		if int(dist[cur]) >= max_steps:
			continue
		for d in MOVE_DIRS:
			var n: Vector2i = cur + d
			if dist.has(n) or not _is_walkable_world(n):
				continue
			dist[n] = int(dist[cur]) + 1
			q.append(n)
	return dist


func _in_hazard(cell: Vector2i) -> bool:
	for h in hazards:
		if h["cells"].has(cell):
			return true
	return false


func _path_has_hazard() -> bool:
	for c in path_cells:
		if _in_hazard(c):
			return true
	return false


func _pulse(node: Control, color: Color) -> void:
	## Quick scale/colour pop on a HUD value. Used for damage, heat and data so
	## the number that changed is the number the eye lands on.
	if node == null:
		return
	if node.has_meta("pulse_tw"):
		var old: Tween = node.get_meta("pulse_tw")
		if old != null and old.is_valid():
			old.kill()
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(1.18, 1.18)
	node.modulate = Color.WHITE.lerp(color, 0.65)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate", Color.WHITE, 0.32)
	node.set_meta("pulse_tw", tw)


func _run_fx_demo(kind: String) -> void:
	await get_tree().create_timer(0.9).timeout
	if done:
		return
	match kind:
		"impact":
			_impact(player_cell, Color("#ff9c4a"), 2, 24)
		"shield":
			_impact(player_cell, UIKit.CYAN, 0, 0)
		"pickup":
			_pickup_flash(player_cell, UIKit.CYAN)
		"extract":
			VFX.beam(vfx_layer, _cell_center(player_cell), Color(0.55, 1.0, 0.92, 0.9), 62.0, 0.85, 9)
			VFX.ring(vfx_layer, _cell_center(player_cell), UIKit.CYAN, 40.0, 0.55, 2.4, 8)
			VFX.sparks(vfx_layer, _cell_center(player_cell), UIKit.CYAN, 14, 55.0, -40.0, 10)
		"disaster":
			# Deterministic hazard strike on the player for reviewing the
			# disaster beat (banner + edge flash + pause + aftermath).
			var h := {
				"kind": "thermal", "info": HAZARDS["thermal"],
				"cells": [player_cell, player_cell + Vector2i(1, 0),
					player_cell + Vector2i(0, 1), player_cell + Vector2i(1, 1)],
				"origin": player_cell, "shape": "block", "dir": Vector2i.ZERO,
				"speed": 0, "life": 2, "age": 1,
			}
			hazards.append(h)
			_resolve_hazard()
		_:
			_impact(player_cell, Color("#ff9c4a"), 2, 24)
			await get_tree().create_timer(0.75).timeout
			if done:
				return
			_impact(player_cell, UIKit.CYAN, 0, 0)
			await get_tree().create_timer(0.65).timeout
			if done:
				return
			_pickup_flash(player_cell, UIKit.CYAN)
			await get_tree().create_timer(0.75).timeout
			if done:
				return
			VFX.beam(vfx_layer, _cell_center(player_cell), Color(0.55, 1.0, 0.92, 0.9), 62.0, 0.85, 9)
			VFX.ring(vfx_layer, _cell_center(player_cell), UIKit.CYAN, 40.0, 0.55, 2.4, 8)


func _collect_node_at(cell: Vector2i) -> void:	for i in range(objectives.size()):
		if objectives[i] == cell and not collected[i]:
			collected[i] = true
			var gain := 1
			var rock := str(sec["planet"]["biome"]) in ["arid", "barren", "volcanic", "iron", "crystal", "sulfur"]
			if rock and int(sec["bonus_data"]) > 0:
				gain += int(sec["bonus_data"])
			# Report what was actually credited, not the raw roll: at the cap the
			# counter can rise by less than `gain`, and the toast used to lie.
			var before := int(sec["data"])
			sec["data"] = mini(_objective_cap(), before + gain)
			var credited := int(sec["data"]) - before
			data_collected = int(sec["data"])
			GameState.sfx("confirm")
			message_text = ("RELAY BEACON PLANTED  +%d" if _is_relay() else "DATA NODE SECURED  +%d") % credited
			message_color = UIKit.AMBER if _is_relay() else UIKit.CYAN
			_show_toast(message_text, message_color)
			_pickup_flash(cell, message_color)
			_pulse(data_label, message_color)
			return


func _check_overheat() -> void:
	if int(sec["thermal"]) >= 100:
		sec["thermal"] = 62
		sec["integrity"] = maxi(0, int(sec["integrity"]) - 1)
		GameState.sfx("hazard")
		message_text = "THERMAL OVERLOAD  -1 INTEGRITY"
		message_color = UIKit.RED
		_show_toast(message_text, message_color)
		if vfx_layer != null:
			var at := _cell_center(player_cell)
			VFX.embers(vfx_layer, at, Color(1.0, 0.55, 0.22, 0.9), 10)
			VFX.shockwave(vfx_layer, at, UIKit.RED, 26.0)
			VFX.dust(vfx_layer, at, Color(0.75, 0.45, 0.30, 0.5), 6, 18.0)
		_impact(player_cell, UIKit.RED, 1, 0)


func _execute_path() -> void:
	if done or moved or _ending_turn:
		return
	if path_cells.is_empty() or not path_valid:
		message_text = "SELECT A DESTINATION"
		message_color = UIKit.MUTED
		_show_toast(message_text, message_color)
		return
	moved = true
	GameState.sfx("move")
	var steps: Array[Vector2i] = path_cells.duplicate()
	var remaining: Array[Vector2i] = steps.duplicate()
	for c in steps:
		if done:
			break
		if int(sec["sols"]) <= 0:
			_end(false, "MISSION WINDOW CLOSED")
			return
		if int(sec["delta_v"]) <= 0:
			_end(false, "DELTA-V EXHAUSTED")
			return
		var step_from := player_cell
		player_cell = c
		if fog_enabled:
			_reveal_around(c, 2)
		sec["delta_v"] = int(sec["delta_v"]) - 1
		sec["sols"] = int(sec["sols"]) - 1
		sec["thermal"] = int(sec["thermal"]) + int(sec["heat_gain"])
		_collect_node_at(c)
		_check_overheat()
		if int(sec["integrity"]) <= 0:
			_end(false, "HULL BREACH")
			return
		if int(sec["data"]) >= _objective_cap():
			# All samples are aboard, but the mission is not over: the lander
			# has to get back to the landing zone before it can extract.
			message_text = "ALL DATA ABOARD  ·  CARGO HEAVY  ·  RANGE %d" % _current_range()
			message_color = UIKit.GREEN
			_show_toast(message_text, message_color)
		# Render each cell and pan one step, so committing a 2-3 tile route
		# follows the preview instead of collapsing the whole path into a cut.
		# `_animate_player()` re-anchors the sprite at the previous cell and
		# tweens it in, which also fires the dust puff for this step.
		_update_chunks()
		_render_window()
		_refresh_status()
		_animate_player(step_from)
		if player_sprite != null:
			# Bank into the turn, then settle. This reads as a vehicle changing
			# heading instead of a token being teleported one cell.
			var bank := clampf(float(c.x - step_from.x) * 0.075, -0.12, 0.12)
			player_sprite.rotation = -bank
			var bank_tw := create_tween()
			bank_tw.tween_property(player_sprite, "rotation", 0.0, 0.34) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_pan_camera(step_from)
		await camera_tween.finished
		remaining.pop_front()
		path_cells = remaining.duplicate()
		path_valid = not path_cells.is_empty()
		path_cost = path_cells.size()
		_draw_move_preview()
	if not done:
		_end_turn()


func _camera_world_layers() -> Array:
	var out: Array = super._camera_world_layers()
	out.append(fx_layer)
	out.append(vfx_layer)
	out.append(move_layer)
	return out


func _end_turn() -> void:
	if done or _ending_turn:
		return
	_ending_turn = true
	# Every live front resolves at end of turn, hit or miss. A front that lands
	# on empty ground still gets a visible strike: the world reacts even when
	# the player dodged it.
	var struck := _resolve_hazard()
	if struck:
		_check_overheat()
		if int(sec["integrity"]) <= 0:
			_ending_turn = false
			_end(false, "HULL BREACH")
			return
	# Beat before the board advances: the strike, banner and shake need a
	# moment to read. Without this the new telegraph appears in the same frame
	# as the damage and the player never registers what happened.
	if struck and _last_strike_near and not done:
		await get_tree().create_timer(0.62).timeout
		if done:
			_ending_turn = false
			return
	sec["power"] = mini(int(sec["power_max"]),
		int(sec["power"]) + int(sec["power_regen"]))
	turn += 1
	moved = false
	cursor_cell = player_cell
	path_cells.clear()
	path_valid = false
	path_cost = 0
	path_heat = 0
	path_nodes = 0
	if int(sec["sols"]) <= 0:
		_ending_turn = false
		_end(false, "MISSION WINDOW CLOSED")
		return
	if int(sec["delta_v"]) <= 0:
		_ending_turn = false
		_end(false, "DELTA-V EXHAUSTED")
		return
	_advance_hazards()
	_advance_scars()
	_spawn_hazard()
	_update_chunks()
	_render_window()
	_refresh_status()
	_draw_move_preview()
	_ending_turn = false


func _alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


func _cell_center(cell: Vector2i) -> Vector2:
	return _project(Vector2((cell.x + 0.5) * TILE, (cell.y + 0.5) * TILE))


func _reach_cell_quad(cell: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([
		_cell_corner(cell, 0), _cell_corner(cell, 1),
		_cell_corner(cell, 2), _cell_corner(cell, 3),
	])


func _cell_corner(cell: Vector2i, corner: int) -> Vector2:
	# 0 = NW, 1 = NE, 2 = SE, 3 = SW in cell space, then projected.
	var x := cell.x + (1 if corner == 1 or corner == 2 else 0)
	var y := cell.y + (1 if corner == 2 or corner == 3 else 0)
	return _project(Vector2(x * TILE, y * TILE))


func _draw_move_preview() -> void:
	if move_layer == null:
		return
	for child in move_layer.get_children():
		child.free()
	if done:
		return

	var reach := _reachable_cells(_current_range())
	var drawn := {}
	for key in reach.keys():
		var cell: Vector2i = key
		if not _in_view(cell.x, cell.y):
			continue
		drawn[cell] = true
		var danger := _in_hazard(cell)
		var base := Color("#ff5d6c") if danger else UIKit.CYAN
		var corners := _reach_cell_quad(cell)
		var fill := Polygon2D.new()
		fill.polygon = corners
		fill.color = _alpha(base, 0.16 if danger else 0.055)
		move_layer.add_child(fill)
		if danger:
			# Hazards inside reach keep a per-cell red wireframe: the threat is
			# the actionable information, so it may break the calm union edge.
			var edge := Line2D.new()
			edge.points = corners
			edge.closed = true
			edge.width = 1.0
			edge.default_color = _alpha(base, 0.55)
			move_layer.add_child(edge)

	# Reachability reads as one crisp boundary, not a lattice of cell borders.
	# Each side is stroked only when the neighbour is outside the reachable
	# (and visible) set, so shared borders never double-draw.
	for cell in drawn.keys():
		var c: Vector2i = cell
		var base := Color("#ff5d6c") if _in_hazard(c) else UIKit.CYAN
		for side in REACH_SIDES:
			var offset: Vector2i = side[0]
			if drawn.has(c + offset):
				continue
			var a := _cell_corner(c, int(side[1]))
			var b := _cell_corner(c, int(side[2]))
			var stroke := Line2D.new()
			stroke.points = PackedVector2Array([a, b])
			stroke.width = 1.5
			stroke.antialiased = false
			stroke.default_color = _alpha(base, 0.88)
			move_layer.add_child(stroke)

	if path_valid and not path_cells.is_empty():
		var pts := PackedVector2Array()
		pts.append(_cell_center(player_cell))
		for c in path_cells:
			pts.append(_cell_center(c))
		var line := Line2D.new()
		line.points = pts
		line.width = 2.0
		line.default_color = _alpha(
			Color("#ff5d6c") if _path_has_hazard() else UIKit.CYAN, 0.82
		)
		move_layer.add_child(line)
		for c in path_cells:
			var dot := Polygon2D.new()
			dot.polygon = _diamond_points(2.0 * map_scale)
			dot.position = _cell_center(c)
			dot.color = _alpha(UIKit.TEXT, 0.95)
			move_layer.add_child(dot)

	var target := cursor_cell
	var tcolor := Color("#ff5d6c") if _in_hazard(target) else UIKit.CYAN
	if not path_valid and target != player_cell:
		tcolor = UIKit.RED
	var target_mark := Polygon2D.new()
	target_mark.polygon = _diamond_points(13.0 * map_scale)
	target_mark.position = _cell_center(target)
	target_mark.color = _alpha(tcolor, 0.16)
	move_layer.add_child(target_mark)
	var target_edge := Line2D.new()
	target_edge.points = _diamond_points(13.0 * map_scale)
	target_edge.closed = true
	target_edge.width = 1.6
	target_edge.default_color = _alpha(tcolor, 0.95)
	target_edge.position = _cell_center(target)
	move_layer.add_child(target_edge)


func _process(delta: float) -> void:
	if fx_layer != null and not done:
		# The hazard shader owns the pulse now; keep only a faint breath here so
		# the footprint never doubles up two conflicting rhythms.
		fx_layer.modulate.a = 0.96 + 0.04 * sin(Time.get_ticks_msec() * 0.004)
	# Idle hover: a sub-pixel bob sells the lander as floating without touching
	# the shadow. Sprite2D.offset is independent of the move tween on position.
	if player_sprite != null:
		var bob := 0.0
		if not done and not moved:
			bob = sin(Time.get_ticks_msec() * 0.0045) * 6.0
		player_sprite.offset.y = move_toward(player_sprite.offset.y, bob, 30.0 * delta)
	# The sector planet is a distant body, not a sticker: drift it a few pixels
	# so the backdrop reads as depth behind the board.
	if sector_planet != null:
		sector_planet.position.y = -32.0 + sin(Time.get_ticks_msec() * 0.00011) * 5.0
	# Live minimap: the radar sweep needs a redraw even when nothing changed.
	if minimap != null and not done:
		minimap.queue_redraw()
	# World aliveness: biome events on the board and meteors in the sky.
	if not done:
		_world_timer -= delta
		if _world_timer <= 0.0:
			_world_timer = rng.randf_range(2.2, 4.4)
			_world_event()
		_star_timer -= delta
		if _star_timer <= 0.0:
			_star_timer = rng.randf_range(6.0, 12.0)
			_shooting_star()


func _visible_structures() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for coord in chunks:
		var data: Dictionary = chunks[coord]
		for s in data.get("structures", []):
			if _in_view(int(s["gx"]), int(s["gy"]), int(s["w"]), int(s["h"])):
				out.append(s)
	return out


func _world_event() -> void:
	if vfx_layer == null or done:
		return
	# Prefer an authored structure with a readable signature (erupting volcano,
	# venting geyser, prism glint) over generic dust; that is what makes the
	# board feel inhabited rather than decorated.
	var special := ["volcano", "geyser", "crystal_outcrop", "iceberg", "coral_spire"]
	var pool: Array[Dictionary] = []
	for s in _visible_structures():
		if str(s["key"]) in special:
			pool.append(s)
	if not pool.is_empty() and rng.randf() < 0.72:
		var s: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var c := Vector2i(
			int(s["gx"]) + maxi(1, int(s["w"])) / 2,
			int(s["gy"]) + maxi(1, int(s["h"])) / 2
		)
		var at := _cell_center(c) - Vector2(0.0, float(s["h"]) * TILE * map_scale * 0.30)
		match str(s["key"]):
			"volcano":
				VFX.dust(vfx_layer, at, Color(0.30, 0.26, 0.24, 0.50), 5, 12.0)
				VFX.embers(vfx_layer, at, Color(1.0, 0.55, 0.22, 0.85), 5)
			"geyser":
				VFX.beam(vfx_layer, at, Color(0.78, 0.94, 1.0, 0.40), 24.0, 0.55, 6)
				VFX.dust(vfx_layer, at, Color(0.85, 0.92, 0.95, 0.38), 4, 16.0)
			"crystal_outcrop":
				VFX.sparks(vfx_layer, at, Color(0.82, 0.70, 1.0, 0.85), 5, 24.0, -16.0)
			"iceberg", "coral_spire":
				VFX.sparks(vfx_layer, at, Color(0.75, 0.95, 1.0, 0.65), 4, 18.0, -10.0)
			_:
				VFX.dust(vfx_layer, at, Color(0.55, 0.50, 0.45, 0.30), 3, 10.0)
		return
	# Generic biome life on a random visible tile.
	var cell := Vector2i(
		view_origin.x + rng.randi_range(1, view_w - 2),
		view_origin.y + rng.randi_range(1, view_h - 2)
	)
	if not _in_view(cell.x, cell.y):
		return
	var at := _cell_center(cell)
	var terrain := _render_terrain_world(cell.x, cell.y)
	if "lava" in terrain:
		VFX.embers(vfx_layer, at, Color(1.0, 0.55, 0.20, 0.85), 4)
	elif "water" in terrain:
		VFX.ring(vfx_layer, at, Color(0.55, 0.90, 0.95, 0.45), 11.0, 0.75, 1.0, 4)
	elif "ice" in terrain or "snow" in terrain:
		VFX.sparks(vfx_layer, at, Color(0.80, 0.95, 1.0, 0.75), 3, 10.0, -6.0, 5)
	else:
		match str(sec["planet"]["biome"]):
			"volcanic", "sulfur", "obsidian":
				VFX.embers(vfx_layer, at, Color(1.0, 0.58, 0.22, 0.80), 3)
			"cryo", "ammonia":
				VFX.dust(vfx_layer, at, Color(0.82, 0.92, 1.0, 0.28), 3, 10.0)
			"ocean", "methane":
				VFX.dust(vfx_layer, at, Color(0.55, 0.88, 0.90, 0.25), 2, 8.0)
			"crystal":
				VFX.sparks(vfx_layer, at, Color(0.80, 0.68, 1.0, 0.80), 3, 14.0, -8.0)
			"arid", "barren", "iron", "carbon":
				# Dust devil: three offset puffs that read as a moving column.
				VFX.dust(vfx_layer, at, Color(0.72, 0.64, 0.52, 0.35), 3, 12.0)
				VFX.dust(vfx_layer, at + Vector2(9, -4), Color(0.70, 0.62, 0.50, 0.26), 2, 10.0)
				VFX.dust(vfx_layer, at + Vector2(18, -8), Color(0.68, 0.60, 0.48, 0.18), 2, 8.0)
			_:
				VFX.sparks(vfx_layer, at, Color(0.72, 0.96, 0.74, 0.55), 3, 10.0, -8.0)


func _shooting_star() -> void:
	if fx_root == null or done:
		return
	var start := Vector2(
		rng.randf_range(0.08, 0.72) * 640.0,
		rng.randf_range(0.05, 0.28) * 360.0
	)
	var dir := Vector2(1.0, 0.42).normalized()
	var length := rng.randf_range(12.0, 24.0)
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2.ZERO, -dir * length])
	line.width = 1.0
	line.default_color = Color(0.85, 0.95, 1.0, 0.0)
	line.position = start
	line.z_index = 44
	fx_root.add_child(line)
	var travel := rng.randf_range(80.0, 140.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(line, "position", start + dir * travel, 0.60) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(line, "modulate:a", 1.0, 0.16)
	tw.chain().tween_property(line, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(line.queue_free)


func _draw_minimap() -> void:
	super._draw_minimap()
	if minimap == null or done:
		return
	var sz := minimap.size
	var c := sz * 0.5
	var r := minf(sz.x, sz.y) * 0.44
	var ang := fmod(Time.get_ticks_msec() * 0.0011, TAU)
	var col := Color(0.33, 0.90, 0.82, 0.16)
	# A fading wedge trail behind the sweep line sells the rotation cheaply.
	for i in range(4):
		var a := ang - float(i) * 0.10
		minimap.draw_line(c, c + Vector2(cos(a), sin(a)) * r,
			Color(col.r, col.g, col.b, col.a * (1.0 - float(i) / 4.0)), 1.0, true)




func _render_window() -> void:
	# The parent renderer only knows about one 3x3 hazard. Suppress that path
	# and draw the full hazard set (shapes, sweeps, scars) in _draw_hazards().
	hazard_kind = ""
	super._render_window()
	_draw_hazards()
	_draw_fog()


func _hazard_quad(cell: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([
		_project(Vector2(cell.x * TILE, cell.y * TILE)),
		_project(Vector2((cell.x + 1) * TILE, cell.y * TILE)),
		_project(Vector2((cell.x + 1) * TILE, (cell.y + 1) * TILE)),
		_project(Vector2(cell.x * TILE, (cell.y + 1) * TILE)),
	])


const HAZARD_KIND := {
	"flare": 1, "thermal": 2, "dust": 3, "quake": 4, "radiation": 5,
	"eclipse": 6, "cryo": 7, "wind": 8, "meteor": 9,
}

var _hazard_shader: Shader


func _hazard_material(kind: int, mode: int, color: Color, seed_value: float,
		intensity: float) -> ShaderMaterial:
	if _hazard_shader == null:
		_hazard_shader = load("res://shaders/hazard_field.gdshader") as Shader
	var m := ShaderMaterial.new()
	m.shader = _hazard_shader
	m.set_shader_parameter("hazard_color", color)
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("seed", seed_value)
	m.set_shader_parameter("intensity", intensity)
	return m


func _hazard_uvs(cell: Vector2i) -> PackedVector2Array:
	# World tile coordinates, so the pattern is continuous across cells.
	var x := float(cell.x)
	var y := float(cell.y)
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + 1.0, y),
		Vector2(x + 1.0, y + 1.0), Vector2(x, y + 1.0),
	])


func _draw_hazards() -> void:
	if fx_layer == null:
		return
	for child in fx_layer.get_children():
		child.free()
	# Scarred ground: where a hazard actually landed. The shader draws the burn
	# and ember rim; intensity tracks the four-turn scar lifetime.
	for s in scars:
		var sc: Vector2i = s["cell"]
		if not _in_view(sc.x, sc.y):
			continue
		var life := float(s["life"]) / 4.0
		var col: Color = s["color"]
		var fill := Polygon2D.new()
		fill.polygon = _hazard_quad(sc)
		fill.uv = _hazard_uvs(sc)
		fill.material = _hazard_material(0, 2, col, float(sc.x * 17 + sc.y), 0.35 + 0.65 * life)
		fx_layer.add_child(fill)
	# Every active hazard footprint.
	for h in hazards:
		var info: Dictionary = h["info"]
		var col: Color = info["color"]
		var cells: Array[Vector2i] = h["cells"]
		var armed := int(h.get("age", 1)) >= 1
		var kind := int(HAZARD_KIND.get(str(h.get("kind", "")), 0))
		var mat := _hazard_material(
			kind, 0 if armed else 1, col,
			float(int(hash(str(h.get("kind", "")))) % 997) * 0.37, 1.0
		)
		for c in cells:
			if not _in_view(c.x, c.y):
				continue
			var fill := Polygon2D.new()
			fill.polygon = _hazard_quad(c)
			fill.uv = _hazard_uvs(c)
			fill.material = mat
			fx_layer.add_child(fill)
		if int(h["speed"]) > 0:
			var origin: Vector2i = h["origin"]
			var d: Vector2i = h["dir"]
			var from := _cell_center(origin)
			var to := _cell_center(origin + d * 2)
			var arrow := Line2D.new()
			arrow.points = PackedVector2Array([from, to])
			arrow.width = 2.2
			arrow.default_color = Color(col.r, col.g, col.b, 0.92 if armed else 0.30)
			fx_layer.add_child(arrow)
			var tip := Polygon2D.new()
			tip.polygon = _diamond_points(4.5 * map_scale)
			tip.position = to
			tip.color = Color(col.r, col.g, col.b, 0.95 if armed else 0.35)
			fx_layer.add_child(tip)
			# Marching pulse along the sweep vector: the arrow reads as motion
			# even before the front actually advances.
			var march := arrow.create_tween().set_loops()
			march.tween_property(arrow, "modulate:a", 0.35, 0.35) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			march.tween_property(arrow, "modulate:a", 1.0, 0.35) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _hold() -> void:
	if done or moved:
		return
	if int(sec["sols"]) <= 0:
		_end(false, "MISSION WINDOW CLOSED")
		return
	sec["sols"] = int(sec["sols"]) - 1
	var vent := 8 + int(sec["thermal_res"]) + int(sec.get("vent_power_extra", 0)) * 4
	sec["thermal"] = maxi(0, int(sec["thermal"]) - vent)
	var extra := int(sec.get("vent_power_extra", 0))
	sec["power"] = mini(int(sec["power_max"]),
		int(sec["power"]) + extra)
	GameState.sfx("click")
	message_text = "HOLD  ·  VENTED HEAT"
	message_color = UIKit.BLUE
	_show_toast(message_text, message_color)
	_end_turn()


func _hazard_distance(h: Dictionary) -> int:
	var best := 99
	for c in h["cells"]:
		var d := maxi(absi(c.x - player_cell.x), absi(c.y - player_cell.y))
		if d < best:
			best = d
	return best


func _strike_visuals(h: Dictionary, dist: int, hit: bool) -> void:
	## A front landing on the world. `_impact()` owns the player-hit FX, so this
	## covers the footprint itself and the dodged/remote case, which used to be
	## completely silent.
	if vfx_layer == null:
		return
	var info: Dictionary = h["info"]
	var color: Color = info["color"]
	var cells: Array = h["cells"]
	var at := _cell_center(Vector2i(h["origin"]))
	var major := not hit and dist <= 6
	if major:
		VFX.flare_burst(vfx_layer, at, color, 0.85, 9)
		VFX.shockwave(vfx_layer, at, color, 30.0, 8)
		VFX.sparks(vfx_layer, at, Color(color.r, color.g, color.b, 1.0), 10, 55.0, 90.0, 9)
		VFX.sheet_burst(vfx_layer, at, "debris", color, 0.8, 9)
		VFX.beam(vfx_layer, at, Color(color.r, color.g, color.b, 0.5), 30.0, 0.42, 10)
		VFX.embers(vfx_layer, at, color, 6)
	elif not hit:
		# Remote strike: still visible on the board, but no full-screen event.
		VFX.sparks(vfx_layer, at, Color(color.r, color.g, color.b, 0.85), 5, 34.0, 70.0, 8)
		VFX.dust(vfx_layer, at, Color(color.r, color.g, color.b, 0.35), 4, 16.0)
	# Dust and ash across every affected tile (capped so a 13-cell diamond
	# does not become a particle storm).
	var step := maxi(1, int(cells.size() / 7))
	for i in range(0, cells.size(), step):
		var c: Vector2i = cells[i]
		if not _in_view(c.x, c.y):
			continue
		VFX.dust(vfx_layer, _cell_center(c),
			Color(color.r * 0.8, color.g * 0.72, color.b * 0.66, 0.42), 3, 12.0)
	# Scarred ground for the tiles near the player, so a near miss leaves a
	# readable burn field instead of vanishing without a trace.
	for c in cells:
		var d := maxi(absi(c.x - player_cell.x), absi(c.y - player_cell.y))
		if d <= 6 and scars.size() < 26:
			_add_scar(c, color, 3)


func _disaster_banner(h: Dictionary, subtitle: String, hit: bool) -> void:
	if fx_root == null:
		return
	var info: Dictionary = h["info"]
	var color: Color = info["color"]
	var name := str(info["name"]).to_upper()
	var title := ("!! %s STRIKE" % name) if hit else ("!! %s SURGE" % name)
	var p := UIKit.panel(Color(0.055, 0.040, 0.055, 0.94), color)
	p.size = Vector2(360, 40)
	p.position = Vector2(140, 46)
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(0.82, 0.30)
	p.modulate.a = 0.0
	fx_root.add_child(p)
	var bar := ColorRect.new()
	bar.color = Color(color.r, color.g, color.b, 0.9)
	bar.position = Vector2(1, 1)
	bar.size = Vector2(2, 38)
	p.add_child(bar)
	var title_label := UIKit.label(title, 11, color, true, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.position = Vector2(10, 3)
	title_label.size = Vector2(340, 15)
	p.add_child(title_label)
	var sub_label := UIKit.label(subtitle, 7, UIKit.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	sub_label.position = Vector2(10, 20)
	sub_label.size = Vector2(340, 12)
	p.add_child(sub_label)
	var sweep := ColorRect.new()
	sweep.color = Color(color.r, color.g, color.b, 0.35)
	sweep.position = Vector2(1, 37)
	sweep.size = Vector2(0, 2)
	p.add_child(sweep)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.10)
	tw.tween_property(sweep, "size:x", 358.0, 0.34).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.78)
	tw.chain().tween_property(p, "modulate:a", 0.0, 0.24)
	tw.chain().tween_callback(p.queue_free)


func _disaster_edge(color: Color) -> void:
	if _state_mat == null:
		return
	_state_mat.set_shader_parameter("flash_color", color)
	var tw := create_tween()
	tw.tween_method(
		func(v: float): _state_mat.set_shader_parameter("flash", v),
		1.0, 0.0, 0.55
	).set_ease(Tween.EASE_OUT)


func _shake(amp: float) -> void:
	var base := position
	var tw := create_tween()
	for i in range(5):
		tw.tween_property(self, "position",
			base + Vector2(rng.randf_range(-amp, amp), rng.randf_range(-amp, amp)), 0.035)
	tw.tween_property(self, "position", base, 0.07)


func _resolve_hazard() -> bool:
	var strikes: Array[Dictionary] = []
	for h in hazards:
		if int(h.get("age", 1)) >= 1:
			strikes.append(h)
	if strikes.is_empty():
		return false
	var hits: Array[Dictionary] = []
	for h in strikes:
		if h["cells"].has(player_cell):
			hits.append(h)
	var shield_cost := int(sec["shield_cost"])
	var shield_used := false
	var total_i := 0
	var total_t := 0
	var total_dv := 0
	var total_p := 0
	var blocked := 0
	for h in hits:
		var info: Dictionary = h["info"]
		if bool(info["block"]) and not shield_used and int(sec["power"]) >= shield_cost:
			shield_used = true
			blocked += 1
			sec["power"] = int(sec["power"]) - shield_cost
			continue
		total_i += int(info["integrity"])
		total_t += int(info["thermal"])
		total_dv += int(info["dv"])
		total_p += int(info["power"])
		_add_scar(player_cell, info["color"])
	if int(sec.get("sector", 1)) == 1 and total_i > 1:
		# First board: a single hit can never take more than one hull box.
		total_i = 1
	sec["integrity"] = maxi(0, int(sec["integrity"]) - total_i)
	sec["thermal"] = clampi(int(sec["thermal"]) + total_t, 0, 100)
	sec["delta_v"] = maxi(0, int(sec["delta_v"]) - total_dv)
	sec["power"] = clampi(int(sec["power"]) - total_p, 0, int(sec["power_max"]))
	var bits: Array[String] = []
	if total_i > 0:
		bits.append("-%d INT" % total_i)
	if total_t > 0:
		bits.append("+%d HEAT" % total_t)
	elif total_t < 0:
		bits.append("%d HEAT" % total_t)
	if total_dv > 0:
		bits.append("-%d DV" % total_dv)
	if total_p > 0:
		bits.append("-%d PWR" % total_p)
	elif total_p < 0:
		bits.append("+%d PWR" % -total_p)

	# Every front gets world feedback, including the ones the player dodged.
	var closest := 99
	var primary: Dictionary = strikes[0]
	if not hits.is_empty():
		primary = hits[0]
	for h in strikes:
		var d := _hazard_distance(h)
		if d < closest:
			closest = d
			if hits.is_empty():
				primary = h
		_strike_visuals(h, d, hits.has(h))
	_last_strike_near = not hits.is_empty() or closest <= 5

	if not hits.is_empty():
		if total_i != 0 or total_t != 0 or total_dv != 0 or total_p != 0:
			message_text = "%s HIT  %s" % [str(primary["info"]["name"]), " · ".join(bits)]
			if hits.size() > 1:
				message_text = "%d HAZARDS HIT  %s" % [hits.size(), " · ".join(bits)]
			message_color = primary["info"]["color"]
			_show_toast(message_text, message_color)
			_impact(player_cell, primary["info"]["color"], total_i, total_t)
			GameState.sfx("hazard")
			_disaster_banner(primary, " · ".join(bits), true)
			_disaster_edge(primary["info"]["color"])
		elif blocked > 0:
			message_text = "SHIELD ABSORBED  %s" % str(primary["info"]["name"])
			message_color = UIKit.CYAN
			_show_toast(message_text, message_color)
			GameState.sfx("click")
			_impact(player_cell, UIKit.CYAN, 0, 0)
			_disaster_banner(primary, "SHIELD ABSORBED · NO DAMAGE", false)
	elif closest <= 5:
		# Near miss: the player sees and feels the disaster land next to them.
		message_text = "%s SURGE  ·  NO CONTACT" % str(primary["info"]["name"]).to_upper()
		message_color = primary["info"]["color"]
		_show_toast(message_text, message_color)
		_disaster_banner(primary, "NO CONTACT · GROUND SCARRED", false)
		_disaster_edge(primary["info"]["color"])
		_shake(2.2)
		if closest <= 3:
			GameState.sfx("hazard")
	return true


func _add_scar(cell: Vector2i, color: Color, life := 4) -> void:
	for s in scars:
		if s["cell"] == cell:
			s["life"] = maxi(int(s["life"]), life)
			s["color"] = color
			return
	scars.append({"cell": cell, "color": color, "life": life})


func _advance_scars() -> void:
	var kept: Array[Dictionary] = []
	for s in scars:
		s["life"] = int(s["life"]) - 1
		if int(s["life"]) > 0:
			kept.append(s)
	scars = kept


func _impact(cell: Vector2i, color: Color, dmg_i: int, dmg_t: int) -> void:
	var text := ""
	if dmg_i > 0:
		text += "-%d INT" % dmg_i
	if dmg_t > 0:
		text += ("  " if text != "" else "") + "+%d HEAT" % dmg_t
	if text != "":
		_float_text(text, cell, color)
	if dmg_i > 0 and int_label != null:
		_pulse(int_label, color)
	if dmg_t > 0 and heat_val != null:
		_pulse(heat_val, color)
	var at := _cell_center(cell)
	if vfx_layer != null:
		if dmg_i > 0 or dmg_t > 0:
			VFX.flare_burst(vfx_layer, at, color, 0.9)
			VFX.shockwave(vfx_layer, at, color, 34.0)
			VFX.sparks(vfx_layer, at, Color(color.r, color.g, color.b, 1.0), 12, 70.0, 110.0)
			VFX.dust(vfx_layer, at, Color(0.55, 0.50, 0.44, 0.55), 7, 26.0)
			VFX.sheet_burst(vfx_layer, at, "debris", Color(0.82, 0.74, 0.62, 0.9), 0.9, 8)
			if dmg_t > 0:
				VFX.embers(vfx_layer, at, Color(color.r, color.g, color.b, 0.9), 8)
		else:
			VFX.shield(vfx_layer, at, color)
			VFX.ring(vfx_layer, at, Color(color.r, color.g, color.b, 0.9), 30.0, 0.34, 2.0)
	if _impact_flash != null:
		_impact_flash.color = Color(color.r, color.g, color.b, 0.0)
		var flash := create_tween()
		flash.tween_property(_impact_flash, "color:a", 0.14, 0.04)
		flash.tween_property(_impact_flash, "color:a", 0.0, 0.20)
	var base := position
	var shake := create_tween()
	for i in range(4):
		shake.tween_property(self, "position", base + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), 0.035)
	shake.tween_property(self, "position", base, 0.06)


func _pickup_flash(cell := Vector2i.ZERO, color := Color(1, 1, 1)) -> void:
	if vfx_layer != null:
		VFX.pickup(vfx_layer, _cell_center(cell), color)
	if _impact_flash == null:
		return
	_impact_flash.color = Color(1, 1, 1, 0)
	var flash := create_tween()
	flash.tween_property(_impact_flash, "color:a", 0.10, 0.02)
	flash.tween_property(_impact_flash, "color:a", 0.0, 0.12)


func _float_text(text: String, cell: Vector2i, color: Color) -> void:
	if fx_root == null:
		return
	var l := UIKit.label(text, 9, color, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = Vector2(180, 16)
	l.position = _cell_center(cell) - Vector2(90, 12)
	fx_root.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 22, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(l.queue_free)


func _risk_bonus_nearby() -> int:
	# Extracting while a live front is inside two tiles is the greedy play.
	# The bonus is capped across the run in GameState.
	for h in hazards:
		for c in h["cells"]:
			if maxi(absi(c.x - player_cell.x), absi(c.y - player_cell.y)) <= 2:
				return 1
	return 0


func _extract() -> void:
	if done:
		return
	if player_cell != start_cell:
		message_text = "RETURN TO THE LANDING ZONE TO EXTRACT"
		message_color = UIKit.AMBER
		_show_toast(message_text, message_color)
		return
	if int(sec["data"]) < int(sec["quota"]):
		var need := int(sec["quota"]) - int(sec["data"])
		message_text = "NEED %d MORE %s BEFORE EXTRACTION" % [
			need, "RELAY" if _is_relay() else "DATA"
		]
		message_color = UIKit.AMBER
		_show_toast(message_text, message_color)
		return
	sec["risk_bonus"] = _risk_bonus_nearby()
	GameState.sfx("confirm")
	if vfx_layer != null:
		var at := _cell_center(start_cell)
		VFX.beam(vfx_layer, at, Color(0.55, 1.0, 0.92, 0.9), 62.0, 0.85, 9)
		VFX.ring(vfx_layer, at, Color(0.55, 1.0, 0.92, 0.95), 40.0, 0.55, 2.4, 8)
		VFX.sparks(vfx_layer, at, UIKit.CYAN, 14, 55.0, -40.0, 10)
		await get_tree().create_timer(0.45).timeout
		if done:
			return
	_end(true, "EXTRACTION")


func _end(extracted: bool, reason: String) -> void:
	if done:
		return
	done = true
	game_over = true
	if not sec.has("risk_bonus"):
		sec["risk_bonus"] = _risk_bonus_nearby()
	hazard_info = {}
	if hold_btn != null:
		hold_btn.disabled = true
	if extract_btn != null:
		extract_btn.disabled = true
	if move_btn != null:
		move_btn.disabled = true
	var success := extracted and int(sec["data"]) >= int(sec["quota"])
	GameState.finish_sector(extracted, int(sec["data"]), sec)
	_refresh_status()
	_show_result(success, reason)


func _show_result(success: bool, reason: String) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	result_layer = Control.new()
	result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(result_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(shade)

	var has_risk := int(GameState.last_result.get("risk_bonus", 0)) > 0
	var p := UIKit.panel(Color("#0d1522"), UIKit.CYAN_DARK if success else Color("#5a2630"))
	p.position = Vector2(150, 70)
	p.size = Vector2(340, 226 if has_risk else 212)
	result_layer.add_child(p)
	# Arrival beat: the review is stamped onto the board rather than popped.
	# Shade fades, panel settles from 94 %, title lands a touch later.
	shade.color = Color(0.01, 0.02, 0.04, 0.0)
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(0.94, 0.94)
	p.modulate.a = 0.0
	var in_tw := create_tween()
	in_tw.set_parallel(true)
	in_tw.tween_property(shade, "color:a", 0.78, 0.16)
	in_tw.tween_property(p, "modulate:a", 1.0, 0.20)
	in_tw.tween_property(p, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(c)

	var title := UIKit.label(
		"SECTOR COMPLETE" if success else "SECTOR FAILED", 20,
		UIKit.CYAN if success else UIKit.RED, true, HORIZONTAL_ALIGNMENT_CENTER
	)
	title.position = Vector2(0, 14)
	title.size = Vector2(340, 26)
	c.add_child(title)
	var sub := UIKit.label(reason, 8, UIKit.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 42)
	sub.size = Vector2(340, 14)
	c.add_child(sub)
	c.add_child(_result_line(64, "BEACONS PLACED" if _is_relay() else "DATA RECOVERED", "%d / %d  (quota %d)" % [
		int(sec["data"]), _objective_cap(), int(sec["quota"])
	], UIKit.AMBER if _is_relay() else UIKit.GREEN))
	c.add_child(_result_line(82, "INTEGRITY LEFT", "%d / %d" % [
		int(sec["integrity"]), int(sec["integrity_max"])
	], UIKit.TEXT))
	c.add_child(_result_line(100, "DELTA-V LEFT", "%d / %d" % [
		int(sec["delta_v"]), int(sec["delta_v_max"])
	], UIKit.CYAN))
	c.add_child(_result_line(118, "GRANTS AWARDED", "$%dM" % int(GameState.last_result.get("grant", 0)), UIKit.AMBER))
	c.add_child(_result_line(136, "AGENCY APPROVAL", "%+d" % int(GameState.last_result.get("approval_delta", 0)), UIKit.GREEN if success else UIKit.RED))
	if has_risk:
		c.add_child(_result_line(154, "RISK BONUS", "+1 CLASSIFIED", UIKit.PURPLE))

	var btn := UIKit.button(
		"CONTINUE TO DEBRIEF >", Vector2(200, 26), true
	)
	btn.position = Vector2(70, 182 if has_risk else 170)
	btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/debrief.tscn")
	)
	c.add_child(btn)


func _show_toast(text: String, color: Color) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 0.15
	var tin := create_tween()
	tin.tween_property(toast_label, "modulate:a", 1.0, 0.10)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.45)


func _result_line(y: float, label: String, value: String, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.position = Vector2(24, y)
	h.size = Vector2(292, 16)
	var l := UIKit.label(label, 7, UIKit.MUTED, true)
	l.custom_minimum_size = Vector2(180, 14)
	h.add_child(l)
	var v := UIKit.label(value, 8, color, false, HORIZONTAL_ALIGNMENT_RIGHT)
	v.custom_minimum_size = Vector2(100, 14)
	h.add_child(v)
	return h


func _cell_at_screen(pos: Vector2) -> Vector2i:
	var vp := get_viewport_rect().size
	var q := pos - vp * 0.5
	var p := Vector2.ZERO
	match view_mode:
		0:
			p = Vector2(q.x / map_scale, q.y / (map_scale * tilt))
		1:
			var u := q.x / map_scale
			var v := q.y / (map_scale * tilt)
			p = Vector2((u + v) * 0.70710678, (v - u) * 0.70710678)
		_:
			p = q / map_scale
	var world := p + _view_px() * 0.5 + Vector2(view_origin.x, view_origin.y) * TILE
	return Vector2i(
		int(floor(world.x / float(TILE))),
		int(floor(world.y / float(TILE)))
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var cell := _cell_at_screen(motion.position)
		if cell != cursor_cell:
			_select_cell(cell)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var cell := _cell_at_screen(mb.position)
			if cell == cursor_cell:
				_execute_path()
			else:
				_select_cell(cell)
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_UP, KEY_W:
			_move_cursor(_screen_to_grid(Vector2i(0, -1)))
		KEY_DOWN, KEY_S:
			_move_cursor(_screen_to_grid(Vector2i(0, 1)))
		KEY_LEFT, KEY_A:
			_move_cursor(_screen_to_grid(Vector2i(-1, 0)))
		KEY_RIGHT, KEY_D:
			_move_cursor(_screen_to_grid(Vector2i(1, 0)))
		KEY_ENTER, KEY_KP_ENTER:
			_execute_path()
		KEY_SPACE:
			_hold()
		KEY_E:
			_extract()
		KEY_V:
			view_mode = (view_mode + 1) % 3
			_update_view()
			_select_cell(cursor_cell)
		KEY_G:
			show_grid = not show_grid
			_update_view()
			_select_cell(cursor_cell)
		KEY_F9:
			debug_transitions = not debug_transitions
			_render_window()
