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
var fx_root: Control
var _impact_flash: ColorRect

var name_label: Label
var biome_label: Label
var int_label: Label
var dv_label: Label
var sol_label: Label
var data_label: Label
var data_caption: Label
var heat_bar: ProgressBar
var heat_val: Label
var data_bar: ProgressBar
var power_pips: Array = []
var threat_label: Label
var route_label: Label
var quota_label: Label
var dpad: Control
var hold_btn: Button
var extract_btn: Button
var move_btn: Button

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
	sec = GameState.current_sector
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--debug-transitions" in args:
		debug_transitions = true
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
	zoom = 0.82
	_build_tileset()
	_build_view()
	move_layer = Node2D.new()
	move_layer.z_index = 24
	add_child(move_layer)
	fx_layer = Node2D.new()
	fx_layer.z_index = 21
	add_child(fx_layer)
	var fx_canvas := CanvasLayer.new()
	fx_canvas.layer = 26
	add_child(fx_canvas)
	fx_root = Control.new()
	fx_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_canvas.add_child(fx_root)
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
	_spawn_hazard()
	_update_chunks()
	_render_window()
	_refresh_all()
	_draw_move_preview()


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
	top.size = Vector2(620, 38)
	root.add_child(top)
	var tc := Control.new()
	tc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tc)

	name_label = UIKit.label("—", 9, UIKit.TEXT, true)
	name_label.position = Vector2(8, 3)
	name_label.size = Vector2(140, 14)
	tc.add_child(name_label)
	biome_label = UIKit.label("—", 7, UIKit.MUTED, true)
	biome_label.position = Vector2(8, 18)
	biome_label.size = Vector2(140, 12)
	tc.add_child(biome_label)

	int_label = _top_stat(tc, 150, "INTEGRITY", UIKit.RED)
	dv_label = _top_stat(tc, 206, "DELTA-V", UIKit.CYAN)
	sol_label = _top_stat(tc, 262, "SOLS", UIKit.AMBER)
	data_caption = UIKit.label("DATA", 6, UIKit.DIM, true)
	data_caption.position = Vector2(318, 4)
	data_caption.size = Vector2(64, 10)
	tc.add_child(data_caption)
	data_label = UIKit.label("—", 10, UIKit.GREEN, true)
	data_label.position = Vector2(318, 14)
	data_label.size = Vector2(64, 14)
	tc.add_child(data_label)

	var heat_l := UIKit.label("THERMAL", 6, UIKit.DIM, true)
	heat_l.position = Vector2(388, 4)
	heat_l.size = Vector2(96, 10)
	tc.add_child(heat_l)
	heat_bar = UIKit.bar(84, 6, UIKit.AMBER)
	heat_bar.position = Vector2(388, 19)
	tc.add_child(heat_bar)
	heat_val = UIKit.label("0", 9, UIKit.AMBER, true, HORIZONTAL_ALIGNMENT_RIGHT)
	heat_val.position = Vector2(446, 2)
	heat_val.size = Vector2(36, 12)
	tc.add_child(heat_val)

	var pwr_l := UIKit.label("POWER", 6, UIKit.DIM, true)
	pwr_l.position = Vector2(492, 4)
	pwr_l.size = Vector2(78, 10)
	tc.add_child(pwr_l)
	for i in range(12):
		var pip := ColorRect.new()
		pip.color = UIKit.CYAN
		pip.position = Vector2(492 + i * 9, 19)
		pip.size = Vector2(7, 7)
		tc.add_child(pip)
		power_pips.append(pip)

	quota_label = UIKit.label("0/3", 7, UIKit.CYAN, true, HORIZONTAL_ALIGNMENT_RIGHT)
	quota_label.position = Vector2(562, 4)
	quota_label.size = Vector2(50, 12)
	tc.add_child(quota_label)

	# ----- bottom-left status
	var bottom := UIKit.panel(Color(0.035, 0.055, 0.085, 0.92), Color("#2b4058"))
	bottom.position = Vector2(10, 314)
	bottom.size = Vector2(430, 36)
	root.add_child(bottom)
	var bc := Control.new()
	bc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bc)

	threat_label = UIKit.label("—", 7, UIKit.AMBER, true)
	threat_label.position = Vector2(8, 3)
	threat_label.size = Vector2(414, 14)
	bc.add_child(threat_label)
	route_label = UIKit.label("—", 7, UIKit.MUTED, false)
	route_label.position = Vector2(8, 18)
	route_label.size = Vector2(414, 14)
	bc.add_child(route_label)

	toast_label = UIKit.label("", 9, UIKit.CYAN, true, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.position = Vector2(120, 288)
	toast_label.size = Vector2(320, 18)
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

	move_btn = UIKit.button("MOVE  (ENTER)", Vector2(100, 22), true)
	move_btn.position = Vector2(444, 268)
	move_btn.pressed.connect(_execute_path)
	root.add_child(move_btn)
	hold_btn = UIKit.button("HOLD  (SPACE)", Vector2(100, 22))
	hold_btn.position = Vector2(444, 294)
	hold_btn.pressed.connect(_hold)
	root.add_child(hold_btn)
	extract_btn = UIKit.button("EXTRACT  (E)", Vector2(100, 22))
	extract_btn.position = Vector2(444, 320)
	extract_btn.pressed.connect(_extract)
	root.add_child(extract_btn)


func _top_stat(parent: Control, x: float, name: String, color: Color, w: float = 52.0) -> Label:
	var l := UIKit.label(name, 6, UIKit.DIM, true)
	l.position = Vector2(x, 4)
	l.size = Vector2(w, 10)
	parent.add_child(l)
	var v := UIKit.label("—", 10, color, true)
	v.position = Vector2(x, 14)
	v.size = Vector2(w, 14)
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
	quota_label.text = "QUOTA %d" % int(sec["quota"])

	UIKit.set_bar(heat_bar, float(sec["thermal"]), 100.0)
	heat_val.text = "%d" % int(sec["thermal"])
	var hc := UIKit.GREEN
	if float(sec["thermal"]) >= 75:
		hc = UIKit.RED
	elif float(sec["thermal"]) >= 45:
		hc = UIKit.AMBER
	heat_bar.add_theme_stylebox_override("fill", _fill_style(hc))
	heat_val.add_theme_color_override("font_color", hc)

	for i in range(power_pips.size()):
		var pip: ColorRect = power_pips[i]
		var on := i < int(sec["power"])
		var beyond := i >= int(sec["power_max"])
		pip.visible = not beyond
		pip.color = UIKit.CYAN if on else Color("#22344a")

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
	var base := "TURN %d · RANGE %d" % [turn, move_range]
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
	view_origin = player_cell - Vector2i(VIEW_W / 2, VIEW_H / 2)
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
	if turn >= 3:
		b += 1
	if turn >= 6:
		b += 1
	if int(sec.get("sector", 1)) >= 2 and turn >= 4:
		b += 1
	b += int(sec.get("hazard_mod", 0))
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
	cell.x = clampi(cell.x, player_cell.x - VIEW_W / 2 + 3, player_cell.x + VIEW_W / 2 - 3)
	cell.y = clampi(cell.y, player_cell.y - VIEW_H / 2 + 3, player_cell.y + VIEW_H / 2 - 3)
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
				var moved: Array[Vector2i] = []
				for c in h["cells"]:
					moved.append(c + d)
				h["cells"] = moved
				h["origin"] = Vector2i(h["origin"]) + d
		h["age"] = age + 1
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
		return
	_select_cell(target)
	if path_valid and not path_cells.is_empty():
		_execute_path()



# ---------------------------------------------------------------------------
# Turn-based movement (Into the Breach style): choose a destination, preview
# the whole path and its cost, commit one move, then resolve the hazard.
# ---------------------------------------------------------------------------

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
	path_cells = _find_path(player_cell, cell, mini(move_range, maxi(0, resource_cap)))
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


func _collect_node_at(cell: Vector2i) -> void:
	for i in range(objectives.size()):
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
			_pickup_flash()
			return


func _check_overheat() -> void:
	if int(sec["thermal"]) >= 100:
		sec["thermal"] = 62
		sec["integrity"] = maxi(0, int(sec["integrity"]) - 1)
		GameState.sfx("hazard")
		message_text = "THERMAL OVERLOAD  -1 INTEGRITY"
		message_color = UIKit.RED
		_show_toast(message_text, message_color)


func _execute_path() -> void:
	if done or moved:
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
			message_text = "ALL DATA ABOARD  ·  RETURN TO LANDER"
			message_color = UIKit.GREEN
			_show_toast(message_text, message_color)
		# Render each cell and pan one step, so committing a 2-3 tile route
		# follows the preview instead of collapsing the whole path into a cut.
		_update_chunks()
		_render_window()
		_refresh_status()
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
	out.append(move_layer)
	return out


func _end_turn() -> void:
	if done:
		return
	# The telegraphed hazard resolves at the end of the turn, not when you
	# step into it. The path preview marks the tiles so the player can dodge.
	if _in_hazard(player_cell):
		_resolve_hazard()
		_check_overheat()
	if int(sec["integrity"]) <= 0:
		_end(false, "HULL BREACH")
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
		_end(false, "MISSION WINDOW CLOSED")
		return
	if int(sec["delta_v"]) <= 0:
		_end(false, "DELTA-V EXHAUSTED")
		return
	_advance_hazards()
	_advance_scars()
	_spawn_hazard()
	_update_chunks()
	_render_window()
	_refresh_status()
	_draw_move_preview()


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

	var reach := _reachable_cells(move_range)
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
		fx_layer.modulate.a = 0.88 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
	# Idle hover: a sub-pixel bob sells the lander as floating without touching
	# the shadow. Sprite2D.offset is independent of the move tween on position.
	if player_sprite != null:
		var bob := 0.0
		if not done and not moved:
			bob = sin(Time.get_ticks_msec() * 0.0045) * 6.0
		player_sprite.offset.y = move_toward(player_sprite.offset.y, bob, 30.0 * delta)


func _render_window() -> void:
	# The parent renderer only knows about one 3x3 hazard. Suppress that path
	# and draw the full hazard set (shapes, sweeps, scars) in _draw_hazards().
	hazard_kind = ""
	super._render_window()
	_draw_hazards()


func _hazard_quad(cell: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([
		_project(Vector2(cell.x * TILE, cell.y * TILE)),
		_project(Vector2((cell.x + 1) * TILE, cell.y * TILE)),
		_project(Vector2((cell.x + 1) * TILE, (cell.y + 1) * TILE)),
		_project(Vector2(cell.x * TILE, (cell.y + 1) * TILE)),
	])


func _draw_hazards() -> void:
	if fx_layer == null:
		return
	for child in fx_layer.get_children():
		child.free()
	# Scarred ground: where a hazard actually landed.
	for s in scars:
		var sc: Vector2i = s["cell"]
		if not _in_view(sc.x, sc.y):
			continue
		var life := float(s["life"]) / 4.0
		var col: Color = s["color"]
		var q := _hazard_quad(sc)
		var fill := Polygon2D.new()
		fill.polygon = q
		fill.color = Color(0.05, 0.03, 0.03, 0.25 + 0.25 * life)
		fx_layer.add_child(fill)
		var edge := Line2D.new()
		edge.points = q
		edge.closed = true
		edge.width = 1.0
		edge.default_color = Color(col.r, col.g, col.b, 0.18 + 0.25 * life)
		fx_layer.add_child(edge)
	# Every active hazard footprint.
	for h in hazards:
		var info: Dictionary = h["info"]
		var col: Color = info["color"]
		var cells: Array[Vector2i] = h["cells"]
		var armed := int(h.get("age", 1)) >= 1
		for c in cells:
			if not _in_view(c.x, c.y):
				continue
			var quad := _hazard_quad(c)
			var fill := Polygon2D.new()
			fill.polygon = quad
			fill.color = Color(col.r, col.g, col.b, 0.28 if armed else 0.10)
			fx_layer.add_child(fill)
			var line := Line2D.new()
			line.points = quad
			line.closed = true
			line.width = 1.8 if armed else 0.8
			line.default_color = Color(col.r, col.g, col.b, 0.95 if armed else 0.38)
			fx_layer.add_child(line)
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


func _resolve_hazard() -> void:
	if hazards.is_empty():
		return
	var hits: Array[Dictionary] = []
	for h in hazards:
		if int(h.get("age", 1)) >= 1 and h["cells"].has(player_cell):
			hits.append(h)
	if hits.is_empty():
		return
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
	sec["integrity"] = maxi(0, int(sec["integrity"]) - total_i)
	sec["thermal"] = clampi(int(sec["thermal"]) + total_t, 0, 100)
	sec["delta_v"] = maxi(0, int(sec["delta_v"]) - total_dv)
	sec["power"] = clampi(int(sec["power"]) - total_p, 0, int(sec["power_max"]))
	if total_i != 0 or total_t != 0 or total_dv != 0 or total_p != 0:
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
		message_text = "%s HIT  %s" % [str(hits[0]["info"]["name"]), " · ".join(bits)]
		if hits.size() > 1:
			message_text = "%d HAZARDS HIT  %s" % [hits.size(), " · ".join(bits)]
		message_color = hits[0]["info"]["color"]
		_show_toast(message_text, message_color)
		_impact(player_cell, hits[0]["info"]["color"], total_i, total_t)
		GameState.sfx("hazard")
	elif blocked > 0:
		message_text = "SHIELD ABSORBED  %s" % str(hits[0]["info"]["name"])
		message_color = UIKit.CYAN
		_show_toast(message_text, message_color)
		GameState.sfx("click")
		_impact(player_cell, UIKit.CYAN, 0, 0)


func _add_scar(cell: Vector2i, color: Color) -> void:
	for s in scars:
		if s["cell"] == cell:
			s["life"] = 4
			s["color"] = color
			return
	scars.append({"cell": cell, "color": color, "life": 4})


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
	if _impact_flash != null:
		_impact_flash.color = Color(color.r, color.g, color.b, 0.0)
		var flash := create_tween()
		flash.tween_property(_impact_flash, "color:a", 0.34, 0.05)
		flash.tween_property(_impact_flash, "color:a", 0.0, 0.30)
	var base := position
	var shake := create_tween()
	for i in range(4):
		shake.tween_property(self, "position", base + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), 0.035)
	shake.tween_property(self, "position", base, 0.06)


func _pickup_flash() -> void:
	if _impact_flash == null:
		return
	_impact_flash.color = Color(1, 1, 1, 0)
	var flash := create_tween()
	flash.tween_property(_impact_flash, "color:a", 0.18, 0.02)
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
	toast_label.modulate.a = 1.0
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
	var world := p + VIEW_PX * 0.5 + Vector2(view_origin.x, view_origin.y) * TILE
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
