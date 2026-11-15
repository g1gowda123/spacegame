class_name ShipDiagram
extends Control
const SHIP_BUILD := preload("res://scripts/ship_build.gd")
## Generated spacecraft portrait with a live build layer.
##
## The hull PNG stays the authored pixel-art base. Modules and instruments are
## drawn as integer-aligned pixel blocks on top of it from the same slot map,
## so the ship visibly grows as the player installs refits between planets.

const SHIP_DIR := "res://assets/sprites/ships/"
const MODULE_TEX_DIR := "res://assets/sprites/modules/ship/"

var hull_id := "pathfinder"
var accent := Color("#54e6d1")
var instruments: Array = []
var owned: Array = []
var _tex: Texture2D
var _bbox := Rect2(0, 0, 190, 70)
var _modules: Array = []
var _refits := 0
var _time := 0.0
var _flash := 0.0
var _has_live := false
# Install feedback: when a refit is bought, the new module's slot pulses for
# ~2 s so the player can see *where* the upgrade went, not just that a number
# changed. `_install_slots` holds the world-space rects of the added modules.
var _install_slots: Array[Rect2] = []
var _install_left := 0.0
var _install_name := ""
var _font: Font = null
var _module_tex: Dictionary = {}
const INSTALL_PULSE := 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	set_process(true)
	_load_texture()


func set_ship(hull: String, insts: Array) -> void:
	set_build(hull, insts, GameState.owned)


func set_build(hull: String, insts: Array, refits: Array) -> void:
	var previous_owned := owned.duplicate()
	hull_id = hull
	instruments = insts.duplicate()
	owned = refits.duplicate()
	match hull:
		"cryo":
			accent = Color("#7cc8ff")
		"relay":
			accent = Color("#ffc45c")
		"hopper":
			accent = Color("#b692ff")
		_:
			accent = Color("#54e6d1")
	_refits = SHIP_BUILD.refit_count(owned)
	_modules = SHIP_BUILD.modules(instruments, owned)
	_has_live = false
	for m in _modules:
		if str(m["id"]) in ["antenna", "ion", "buffer", "radar", "camera"]:
			_has_live = true
	_load_texture()
	# A purchase is a visible event: find modules that were not owned before,
	# remember their slots, and pulse them. No caller change needed — both the
	# design and debrief screens already call set_build after a refit.
	var added: Array = []
	for m in _modules:
		var mid := str(m["id"])
		if mid in owned and not (mid in previous_owned):
			added.append(m)
	if not added.is_empty() and _tex != null:
		var ts := _tex.get_size()
		_install_slots.clear()
		for m in added:
			_install_slots.append(_slot_rect(str(m["slot"]), ts))
		var first_id := str(added[0]["id"])
		var info: Dictionary = SHIP_BUILD.MODULE_INFO.get(first_id, {})
		_install_name = "+" + str(info.get("short", "MOD"))
		_install_left = INSTALL_PULSE
	queue_redraw()


func module_count() -> int:
	return _modules.size()


func refit_count() -> int:
	return _refits


func tier() -> Dictionary:
	return SHIP_BUILD.tier(_refits)


func module_line() -> String:
	return SHIP_BUILD.line(instruments, owned)


func flash_build() -> void:
	_flash = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.8)
	if _install_left > 0.0:
		_install_left = maxf(0.0, _install_left - delta)
		if _install_left == 0.0:
			_install_slots.clear()
	# The portrait is always alive: nav strobe + engine glow run even on a
	# STOCK hull, not only once a live module is fitted.
	queue_redraw()


func _load_texture() -> void:
	var path := SHIP_DIR + hull_id + "_2x.png"
	if not ResourceLoader.exists(path):
		path = SHIP_DIR + hull_id + ".png"
	if not ResourceLoader.exists(path):
		path = SHIP_DIR + "pathfinder.png"
	if ResourceLoader.exists(path):
		_tex = load(path) as Texture2D
	if _tex == null:
		return
	var img := _tex.get_image()
	if img != null:
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			_bbox = Rect2(used)


func _draw() -> void:
	if _tex == null:
		return
	var ts := _tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	# Uniform scale only: the old per-axis fit squashed a 190x70 hull into a
	# 190x60 control (y = 0.857), so every 1 px horizontal panel line dropped a
	# row intermittently and read as stray scanlines across the sprite.
	var sf := minf(size.x / ts.x, size.y / ts.y)
	var draw_size := ts * sf
	var origin := (size - draw_size) * 0.5
	draw_set_transform(origin, 0.0, Vector2(sf, sf))
	draw_texture(_tex, Vector2.ZERO)
	_draw_live_lights()
	for m in _modules:
		_draw_module(m, _slot_rect(str(m["slot"]), ts))
	_draw_install_pulse()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_install_pulse() -> void:
	# Drawn in texture space (inside the scaled transform), so the pulse sits on
	# the module slot at any control size. Reads as "this part just arrived":
	# white outline on the slot, an expanding accent ring, and a rising "+".
	if _install_left <= 0.0 or _install_slots.is_empty():
		return
	var t := clampf(1.0 - _install_left / INSTALL_PULSE, 0.0, 1.0)
	var blink := 0.55 + 0.45 * sin(_time * 18.0)
	for r in _install_slots:
		# Dark under-stroke first so the accent ring reads on paper and on space.
		draw_rect(r.grow(1.6), Color(0.03, 0.05, 0.07, 0.55), false, 2.0)
		draw_rect(r.grow(1.0), Color(1, 1, 1, 0.90 * blink), false, 1.0)
		draw_rect(r.grow(3.0 + t * 6.0),
			Color(accent.r, accent.g, accent.b, 0.80 * (1.0 - t)), false, 1.0)
		var cx := r.get_center().x
		var y := r.position.y - 2.0 - t * 7.0
		var a := (1.0 - t) * 0.95
		draw_line(Vector2(cx - 2.0, y), Vector2(cx + 2.0, y), Color(1, 1, 1, a), 1.0)
		draw_line(Vector2(cx, y - 2.0), Vector2(cx, y + 2.0), Color(1, 1, 1, a), 1.0)
	# Name chip so the player reads what arrived, not just that something did.
	if _font == null:
		if ResourceLoader.exists("res://assets/ui/Silkscreen-Bold.ttf"):
			_font = load("res://assets/ui/Silkscreen-Bold.ttf") as Font
	if _font != null and _install_name != "":
		var fs := 8
		var tw := _font.get_string_size(_install_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var chip := Rect2(
			clampf(_bbox.position.x + _bbox.size.x * 0.5 - tw * 0.5 - 4.0, 1.0,
				size.x - tw - 9.0),
			maxf(1.0, _bbox.position.y + 1.0 - t * 3.0),
			tw + 8.0, 10.0)
		var fade := clampf((1.0 - t) * 2.4, 0.0, 1.0)
		draw_rect(chip, Color(0.04, 0.07, 0.10, 0.92 * fade))
		draw_rect(chip, Color(accent.r, accent.g, accent.b, 0.95 * fade), false, 1.0)
		draw_string(_font, chip.position + Vector2(4.0, 9.0), _install_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, fade))


func _draw_live_lights() -> void:
	# Engine exhaust: a warm/cool glow behind the bbox that flickers at two
	# frequencies so it never reads as a sine wave.
	var cy := _bbox.position.y + _bbox.size.y * 0.5
	var flick := 0.55 + 0.30 * sin(_time * 7.3) + 0.15 * sin(_time * 23.0)
	var ec := Color(accent.r, accent.g, accent.b, 0.16 + 0.20 * flick)
	var rear := Vector2(_bbox.position.x - 2.0, cy + 1.0)
	draw_circle(rear, 3.4 + flick * 1.8, ec)
	draw_circle(rear, 1.3, Color(1.0, 1.0, 1.0, 0.20 + 0.30 * flick))
	# Navigation strobe: two short red/green blinks per 1.6 s cycle. This is the
	# cheapest way to make a static portrait read as a live vehicle.
	var phase := fmod(_time, 1.6)
	if phase < 0.10 or (phase > 0.22 and phase < 0.32):
		draw_circle(Vector2(bbox_end_x() - 2.0, _bbox.position.y + 4.0), 1.4,
			Color(1.0, 0.34, 0.28, 0.95))
		draw_circle(Vector2(_bbox.position.x + 2.0, _bbox.position.y + 3.0), 1.1,
			Color(0.42, 1.0, 0.68, 0.90))


func _module_texture(id: String) -> Texture2D:
	if _module_tex.has(id):
		return _module_tex[id]
	var path := MODULE_TEX_DIR + id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_module_tex[id] = tex
	return tex


func _slot_rect(slot: String, ts: Vector2) -> Rect2:
	var bx := _bbox.position.x
	var by := _bbox.position.y
	var bw := _bbox.size.x
	var bh := _bbox.size.y
	var cx := bx + bw * 0.5
	var cy := by + bh * 0.5
	var r := Rect2(Vector2.ZERO, Vector2(10, 8))
	match slot:
		"nose":
			r = Rect2(bbox_end_x() - 6.0, cy - 4.0, 9.0, 8.0)
		"nose_low":
			r = Rect2(bbox_end_x() - 15.0, bbox_end_y() - 7.0, 10.0, 6.0)
		"top_front":
			r = Rect2(bx + bw * 0.66, by + 1.0, 10.0, 7.0)
		"top_mid":
			r = Rect2(bx + bw * 0.44, by + 1.0, 12.0, 8.0)
		"top_rear":
			r = Rect2(bx + bw * 0.18, by + 1.0, 14.0, 8.0)
		"top_aux":
			r = Rect2(bx + bw * 0.56, by + 1.0, 10.0, 6.0)
		"rear":
			r = Rect2(bx - 6.0, cy - 5.0, 10.0, 10.0)
		"rear_low":
			r = Rect2(bx + 1.0, bbox_end_y() - 7.0, 11.0, 7.0)
		"rear_aux":
			r = Rect2(bx - 3.0, bbox_end_y() - 11.0, 9.0, 7.0)
		"bottom":
			r = Rect2(bx + bw * 0.36, bbox_end_y() - 2.0, 6.0, 6.0)
		"bottom_front":
			r = Rect2(bx + bw * 0.62, bbox_end_y() - 5.0, 8.0, 6.0)
		"boom":
			r = Rect2(bx - 13.0, cy + 1.0, 15.0, 2.0)
		"wing_l":
			r = Rect2(bx - 18.0, cy - 4.0, 18.0, 8.0)
		"wing_r":
			r = Rect2(bbox_end_x() - 1.0, cy - 4.0, 18.0, 8.0)
	r.position.x = clampf(r.position.x, 1.0, ts.x - r.size.x - 1.0)
	r.position.y = clampf(r.position.y, 1.0, ts.y - r.size.y - 1.0)
	return r


func bbox_end_x() -> float:
	return _bbox.position.x + _bbox.size.x


func bbox_end_y() -> float:
	return _bbox.position.y + _bbox.size.y


func _draw_module(m: Dictionary, r: Rect2) -> void:
	var id := str(m["id"])
	var tex := _module_texture(id)
	if tex != null:
		# High-resolution module portraits replace the old 10×8 vector blocks;
		# the source art is authored at 64×48 and downsampled with nearest.
		draw_texture_rect(tex, Rect2(r.position - Vector2(4, 4),
			r.size + Vector2(8, 8)), false)
		if _flash > 0.0:
			draw_rect(r.grow(3.0), Color(1, 1, 1, 0.35 * _flash), false, 1.0)
		return
	var c: Color = m["color"]
	var dark := c.darkened(0.55)
	var light := c.lightened(0.28)
	if _flash > 0.0:
		draw_rect(r.grow(2.0), Color(1, 1, 1, 0.35 * _flash), false, 1.0)
	match id:
		"camera":
			_rect(r, dark, light)
			draw_circle(r.get_center(), 2.5, Color("#0a1620"))
			draw_circle(r.get_center() + Vector2(-0.5, -0.5), 1.0, Color("#54e6d1"))
		"spectrometer":
			var p := PackedVector2Array([
				Vector2(r.position.x, r.end.y),
				Vector2(r.get_center().x, r.position.y),
				Vector2(r.end.x, r.end.y),
			])
			draw_colored_polygon(p, dark)
			draw_polyline(p + PackedVector2Array([p[0]]), light, 1.0)
			draw_line(r.get_center() + Vector2(0, 1), r.get_center() + Vector2(4, -2), light, 1.0)
		"radar":
			_rect(r, dark, light)
			draw_arc(r.get_center(), 3.2, PI * 1.1, PI * 1.9, 8, light, 1.0)
			draw_line(r.get_center(), r.get_center() + Vector2(2, 3), c, 1.0)
		"thermal":
			_rect(r, dark, light)
			draw_line(r.position + Vector2(1, 2), r.position + Vector2(7, 2), Color("#ff9c4a"), 2.0)
			draw_circle(r.position + Vector2(8, 4), 1.2, Color("#ffc45c"))
		"magnetometer":
			draw_line(r.position, r.position + Vector2(r.size.x, 0), light, 1.0)
			draw_circle(r.position + Vector2(r.size.x, 0), 1.8, c)
			draw_line(r.position + Vector2(3, 0), r.position + Vector2(3, 3), light, 1.0)
		"drill":
			var d := PackedVector2Array([
				Vector2(r.position.x, r.position.y),
				Vector2(r.end.x, r.position.y),
				Vector2(r.get_center().x, r.end.y),
			])
			draw_colored_polygon(d, Color("#9aa2b2"))
			draw_polyline(d + PackedVector2Array([d[0]]), light, 1.0)
			draw_line(r.get_center() + Vector2(0, 1), r.get_center() + Vector2(0, 4), dark, 1.0)
		"rtg":
			_rect(r, dark, light)
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y - 4)), c, false, 1.0)
			for i in range(3):
				draw_line(r.position + Vector2(3, 3 + i * 2), r.position + Vector2(r.size.x - 3, 3 + i * 2), light, 1.0)
		"radiator":
			for i in range(3):
				var x := r.position.x + 1.0 + i * 4.0
				draw_rect(Rect2(x, r.position.y, 3.0, r.size.y), c, true)
				draw_rect(Rect2(x, r.position.y, 3.0, r.size.y), light, false, 1.0)
		"wheel":
			for i in range(3):
				var px := r.position.x + 1.0 + i * 2.5
				draw_circle(Vector2(px, r.end.y), 2.2, Color("#101820"))
				draw_circle(Vector2(px, r.end.y), 0.9, light)
		"armor":
			var a := PackedVector2Array([
				r.position + Vector2(0, 2),
				r.position + Vector2(r.size.x, 1),
				r.position + Vector2(r.size.x, 6),
				r.position + Vector2(0, 7),
			])
			draw_colored_polygon(a, light)
			draw_polyline(a + PackedVector2Array([a[0]]), dark, 1.0)
		"buffer":
			_rect(r, dark, light)
			draw_rect(Rect2(r.position + Vector2(2, 1), Vector2(r.size.x - 4, 2)), c, true)
			if int(_time * 2.0) % 2 == 0:
				draw_circle(r.position + Vector2(r.size.x - 2, r.size.y - 2), 1.0, Color("#7fe08a"))
		"antenna":
			var center := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.35)
			draw_line(center, r.position + Vector2(r.size.x * 0.5, r.size.y), light, 1.0)
			draw_circle(center, 3.8, dark)
			draw_arc(center, 3.8, 0.0, TAU, 12, light, 1.0)
			draw_circle(center + Vector2(-1, -1), 1.0, c)
		"science_pack":
			_rect(r, dark, light)
			draw_circle(r.get_center(), 2.2, Color("#b692ff"))
			draw_circle(r.get_center() + Vector2(-0.5, -0.5), 0.8, Color("#e8eff7"))
		"salvage":
			_rect(r, dark, light)
			draw_line(r.position + Vector2(1, 6), r.position + Vector2(4, 2), c, 1.0)
			draw_line(r.end + Vector2(-1, -1), r.end + Vector2(-4, -5), c, 1.0)
			draw_circle(r.get_center(), 1.2, c)
		"repair":
			_rect(r, dark, light)
			draw_line(r.get_center() + Vector2(-3, 0), r.get_center() + Vector2(3, 0), Color("#7fe08a"), 1.0)
			draw_line(r.get_center() + Vector2(0, -3), r.get_center() + Vector2(0, 3), Color("#7fe08a"), 1.0)
		"coolant":
			var p := PackedVector2Array([
				r.position + Vector2(1, 1), r.position + Vector2(4, 1),
				r.position + Vector2(4, 5), r.end + Vector2(-1, -1),
			])
			draw_polyline(p, light, 1.0)
			draw_circle(r.position + Vector2(2, 5), 1.5, c)
		"ion":
			var n := PackedVector2Array([
				r.position + Vector2(0, 1),
				r.position + Vector2(4, 3),
				r.position + Vector2(0, 5),
			])
			draw_colored_polygon(n, dark)
			draw_polyline(n + PackedVector2Array([n[0]]), light, 1.0)
			var flicker := 0.55 + 0.45 * sin(_time * 12.0)
			draw_line(r.position + Vector2(0, 3), r.position + Vector2(-5, 3), Color(0.33, 0.9, 0.82, flicker), 1.0)
		_:
			_rect(r, dark, light)


func _rect(r: Rect2, fill: Color, outline: Color) -> void:
	draw_rect(r, fill, true)
	draw_rect(r, outline, false, 1.0)
