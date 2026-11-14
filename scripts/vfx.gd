class_name VFX
extends RefCounted
## Procedural in-world effects for the surface sector.
##
## Everything here draws itself or uses CPUParticles2D, so no texture set is
## required to ship. If `tools/make_vfx_art.py` has been run, the authored
## particle PNGs in `assets/vfx/` are preferred (spark, smoke, ember, snow,
## spore). Node artists can regenerate those without touching this file.

const FX_DIR := "res://assets/vfx/"

static var _tex_cache := {}


# --- textures -------------------------------------------------------------

static func _asset(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := FX_DIR + name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[name] = tex
	return tex


static func _radial(size: int, core: Color, edge: Color) -> Texture2D:
	# Soft round falloff. Cached per size/colour pair; particles are small so
	# a handful of these cover every effect.
	var key := "radial_%d_%s_%s" % [size, core.to_html(false), edge.to_html(false)]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length() / c
			var k := clampf(1.0 - d, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var col := edge.lerp(core, k)
			col.a *= k
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


static func dot_texture() -> Texture2D:
	var t := _asset("particle_dot")
	return t if t != null else _radial(8, Color(1, 1, 1, 1), Color(1, 1, 1, 0))


static func spark_texture() -> Texture2D:
	var t := _asset("particle_spark")
	return t if t != null else _radial(12, Color(1, 1, 1, 1), Color(1, 1, 1, 0))


static func smoke_texture() -> Texture2D:
	var t := _asset("particle_smoke")
	return t if t != null else _radial(16, Color(0.72, 0.72, 0.70, 0.9), Color(0.55, 0.55, 0.55, 0))


# --- ring / shockwave -----------------------------------------------------

class RingNode extends Node2D:
	## An expanding stroked circle. Tween `radius` and `ring_color:a`; the
	## setter forces a redraw so no per-frame script is needed.
	var radius := 0.0:
		set(v):
			radius = v
			queue_redraw()
	var ring_color := Color.WHITE:
		set(v):
			ring_color = v
			queue_redraw()
	var width := 2.0:
		set(v):
			width = v
			queue_redraw()
	var segments := 40
	var filled := false
	var fill_color := Color(1, 1, 1, 0.08)

	func _draw() -> void:
		if radius <= 0.0:
			return
		if filled and fill_color.a > 0.0:
			var pts := PackedVector2Array()
			for i in range(segments):
				var ang := TAU * float(i) / float(segments)
				pts.append(Vector2(cos(ang), sin(ang)) * radius)
			draw_colored_polygon(pts, fill_color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, segments, ring_color, width, true)


static func ring(parent: Node, at: Vector2, color: Color,
		end_radius := 34.0, life := 0.36, width := 2.0, z := 6) -> RingNode:
	if parent == null:
		return null
	var r := RingNode.new()
	r.position = at
	r.z_index = z
	r.z_as_relative = true
	r.radius = 2.0
	r.width = width
	r.ring_color = color
	parent.add_child(r)
	var tw := r.create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "radius", end_radius, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(r, "width", 0.4, life)
	tw.tween_property(r, "ring_color:a", 0.0, life)
	tw.chain().tween_callback(r.queue_free)
	return r


static func shockwave(parent: Node, at: Vector2, color: Color, radius := 30.0,
		z := 6) -> void:
	if parent == null:
		return
	var inner := color
	inner.a = 0.85
	ring(parent, at, inner, radius * 0.62, 0.24, 3.0, z)
	ring(parent, at, Color(color.r, color.g, color.b, 0.55), radius, 0.42, 1.6, z)
	var flash := RingNode.new()
	flash.position = at
	flash.z_index = z + 1
	flash.filled = true
	flash.fill_color = Color(color.r, color.g, color.b, 0.30)
	flash.ring_color = Color(color.r, color.g, color.b, 0.0)
	flash.width = 0.0
	flash.radius = 6.0
	parent.add_child(flash)
	var tw := flash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "radius", radius * 0.55, 0.14)
	tw.tween_property(flash, "fill_color:a", 0.0, 0.18)
	tw.chain().tween_callback(flash.queue_free)


# --- particles ------------------------------------------------------------

static func _emitter(parent: Node, at: Vector2, color: Color, z: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.z_index = z
	p.z_as_relative = true
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.emitting = false
	parent.add_child(p)
	return p


static func sparks(parent: Node, at: Vector2, color: Color, count := 10,
		speed := 60.0, gravity := 90.0, z := 7) -> void:
	if parent == null:
		return
	var p := _emitter(parent, at, color, z)
	p.texture = spark_texture()
	p.amount = count
	p.lifetime = 0.42
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, gravity)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.8
	p.color = color
	p.color_ramp = _fade_ramp(color)
	p.emitting = true
	_free_later(parent, p, 1.2)


static func dust(parent: Node, at: Vector2, color: Color, count := 8,
		speed := 24.0, z := 5) -> void:
	if parent == null:
		return
	var p := _emitter(parent, at, color, z)
	p.texture = smoke_texture()
	p.amount = count
	p.lifetime = 0.75
	p.one_shot = true
	p.explosiveness = 0.8
	p.direction = Vector2(0, -1)
	p.spread = 120.0
	p.gravity = Vector2(0, -6)
	p.damping_min = 14.0
	p.damping_max = 22.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.1
	p.color = color
	p.color_ramp = _fade_ramp(color)
	p.emitting = true
	_free_later(parent, p, 1.4)


static func embers(parent: Node, at: Vector2, color: Color, count := 6, z := 5) -> void:
	if parent == null:
		return
	var p := _emitter(parent, at, color, z)
	p.texture = _asset("particle_ember")
	if p.texture == null:
		p.texture = dot_texture()
	p.amount = count
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.6
	p.direction = Vector2(0, -1)
	p.spread = 55.0
	p.gravity = Vector2(0, -26)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color = color
	p.color_ramp = _fade_ramp(color)
	p.emitting = true
	_free_later(parent, p, 1.4)


static func _fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, color.a))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	return g


static func _free_later(parent: Node, node: Node, seconds: float) -> void:
	if parent == null or not parent.is_inside_tree():
		node.queue_free()
		return
	var timer := parent.get_tree().create_timer(seconds)
	timer.timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)


# --- shield ---------------------------------------------------------------

class ShieldNode extends Node2D:
	var radius := 18.0:
		set(v):
			radius = v
			queue_redraw()
	var shield_color := Color(0.33, 0.9, 0.82, 0.9):
		set(v):
			shield_color = v
			queue_redraw()
	var filled := true

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in range(6):
			var ang := TAU * float(i) / 6.0 + PI / 6.0
			pts.append(Vector2(cos(ang), sin(ang)) * radius)
		if filled:
			var fill := shield_color
			fill.a *= 0.22
			draw_colored_polygon(pts, fill)
		draw_polyline(pts + PackedVector2Array([pts[0]]), shield_color, 2.0, true)


static func shield(parent: Node, at: Vector2, color: Color, z := 8) -> void:
	if parent == null:
		return
	var s := ShieldNode.new()
	s.position = at
	s.z_index = z
	s.z_as_relative = true
	s.radius = 10.0
	s.shield_color = Color(color.r, color.g, color.b, 0.95)
	parent.add_child(s)
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "radius", 22.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(s, "shield_color:a", 0.0, 0.38).set_delay(0.08)
	tw.chain().tween_callback(s.queue_free)


# --- pickup / beam --------------------------------------------------------

static func pickup(parent: Node, at: Vector2, color: Color, z := 7) -> void:
	if parent == null:
		return
	ring(parent, at, Color(color.r, color.g, color.b, 0.95), 26.0, 0.42, 2.0, z)
	shockwave(parent, at, Color(1, 1, 1, 0.8), 16.0, z + 1)
	sparks(parent, at, color, 9, 42.0, -30.0, z + 2)
	# Three rising motes that read as data being lifted out of the node.
	for i in range(3):
		var mote := RingNode.new()
		mote.position = at
		mote.z_index = z + 2
		mote.radius = 1.6
		mote.width = 0.0
		mote.filled = true
		mote.fill_color = Color(color.r, color.g, color.b, 0.9)
		parent.add_child(mote)
		var tw := mote.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mote, "position:y", at.y - 26.0 - float(i) * 5.0, 0.55 + float(i) * 0.06)
		tw.tween_property(mote, "fill_color:a", 0.0, 0.5).set_delay(0.12)
		tw.chain().tween_callback(mote.queue_free)


class BeamNode extends Node2D:
	var beam_color := Color(0.33, 0.9, 0.82, 0.8):
		set(v):
			beam_color = v
			queue_redraw()
	var height := 20.0:
		set(v):
			height = v
			queue_redraw()
	var width := 3.0

	func _draw() -> void:
		var w := width
		var pts := PackedVector2Array([
			Vector2(-w * 0.5, 0.0), Vector2(w * 0.5, 0.0),
			Vector2(w * 0.22, -height), Vector2(-w * 0.22, -height),
		])
		draw_colored_polygon(pts, beam_color)
		# Hot core.
		var core := beam_color
		core.a *= 0.9
		core = core.lightened(0.35)
		draw_line(Vector2(0, 0), Vector2(0, -height), core, maxf(1.0, w * 0.22), true)


static func beam(parent: Node, at: Vector2, color: Color, height := 34.0,
		life := 0.7, z := 9) -> void:
	if parent == null:
		return
	var b := BeamNode.new()
	b.position = at
	b.z_index = z
	b.z_as_relative = true
	b.beam_color = color
	b.width = 4.0
	b.height = 2.0
	parent.add_child(b)
	# Additive light so the beam glows over dark terrain.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	b.material = mat
	var tw := b.create_tween()
	tw.set_parallel(true)
	tw.tween_property(b, "height", height, life * 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(b, "beam_color:a", 0.0, life * 0.55).set_delay(life * 0.45)
	tw.chain().tween_callback(b.queue_free)


# --- ground scar ----------------------------------------------------------

static func scorch(parent: Node, at: Vector2, color: Color, z := 1) -> void:
	if parent == null:
		return
	var s := RingNode.new()
	s.position = at
	s.z_index = z
	s.z_as_relative = true
	s.radius = 14.0
	s.width = 0.0
	s.filled = true
	s.fill_color = Color(0.03, 0.02, 0.02, 0.55)
	s.ring_color = Color(color.r * 0.6, color.g * 0.4, color.b * 0.3, 0.5)
	parent.add_child(s)
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "radius", 20.0, 0.5)
	tw.tween_property(s, "fill_color:a", 0.28, 0.5)
	tw.tween_property(s, "ring_color:a", 0.0, 0.5)
