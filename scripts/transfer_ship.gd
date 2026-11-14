class_name TransferShip
extends Control
## Animated transfer-arc ship for the mission review panel.
##
## The review already drew a static diamond on the Earth→target arc. This node
## replaces it with a ship that actually travels the curve: comet trail, engine
## flare, launch ring at Earth, arrival ring at the target, then a loop after a
## short hold. Everything is drawn in the panel's 270x112 local space, so it
## scales with the review panel and needs no textures.

signal progress_changed(u: float)

var points: PackedVector2Array = PackedVector2Array()
var accent := Color("#ffc45c")
var ship_texture: Texture2D
var travel_seconds := 4.6
var hold_seconds := 0.9

var _curve: Curve2D
var _length := 0.0
var _time := 0.0
var _trail_dots: Array[Vector3] = []
var _last_pct := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()
	set_process(true)


func _build() -> void:
	_curve = Curve2D.new()
	for p in points:
		_curve.add_point(p)
	_length = maxf(_curve.get_baked_length(), 1.0)
	# Deterministic dust specks behind the ship so the trail has texture even
	# when the panel is repainted every frame.
	_trail_dots.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4217
	for i in range(10):
		_trail_dots.append(Vector3(rng.randf_range(0.10, 0.26), rng.randf_range(-4.0, 4.0), rng.randf()))


func set_points(pts: PackedVector2Array) -> void:
	points = pts
	_build()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var cycle := travel_seconds + hold_seconds
	var t := fmod(_time, cycle)
	# Fade in off Earth, fade out at the end of the hold, so the loop restart is
	# a launch rather than a teleport.
	var fade := 1.0
	var raw := clampf(t / travel_seconds, 0.0, 1.0)
	if raw < 0.06:
		fade = raw / 0.06
	elif t > travel_seconds + hold_seconds * 0.72:
		fade = clampf(1.0 - (t - travel_seconds - hold_seconds * 0.72) / (hold_seconds * 0.28), 0.0, 1.0)
	modulate.a = fade
	var pct := 100 if raw >= 1.0 else int(raw * 100.0)
	if pct != _last_pct:
		_last_pct = pct
		progress_changed.emit(1.0 if pct >= 100 else raw)
	queue_redraw()


func _at(u: float) -> Vector2:
	return _curve.sample_baked(clampf(u, 0.0, 1.0) * _length)


func _draw() -> void:
	if points.size() < 2 or _curve == null:
		return
	var cycle := travel_seconds + hold_seconds
	var t := fmod(_time, cycle)
	var raw_u := clampf(t / travel_seconds, 0.0, 1.0)
	# Smoothstep travel: accelerates off Earth, eases into orbit. A constant
	# speed reads like a progress bar, not a ship.
	var u := raw_u * raw_u * (3.0 - 2.0 * raw_u)

	# Trail: the last 22 % of the path, fading toward the tail.
	var trail_span := 0.22
	var segs := 18
	for i in range(segs):
		var u0 := u - trail_span * float(i + 1) / segs
		var u1 := u - trail_span * float(i) / segs
		if u0 < 0.0:
			break
		var k := 1.0 - float(i) / float(segs)
		if i == 0:
			draw_line(_at(u0), _at(u1), Color(accent.r, accent.g, accent.b, 0.0), 1.0, true)
			continue
		draw_line(_at(u0), _at(u1), Color(accent.r, accent.g, accent.b, 0.48 * k), 1.0, true)

	# Space dust around the trail.
	var tangent := (_at(minf(u + 0.02, 1.0)) - _at(maxf(u - 0.02, 0.0))).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	for d in _trail_dots:
		if u < float(d.x):
			continue
		var uu := u - float(d.x)
		var p := _at(uu) + normal * float(d.y) + tangent * (float(d.z) - 0.5) * 4.0
		var a := 0.12 + 0.22 * float(d.z)
		draw_rect(Rect2(p, Vector2(1, 1)), Color(0.75, 0.92, 1.0, a), true)

	# Ship: the authored hull silhouette when available, otherwise a delta.
	var p := _at(u)
	var s := 3.9
	var engine := p - tangent * s * 1.9
	if ship_texture != null:
		var target_w := 32.0
		var k := target_w / maxf(float(ship_texture.get_width()), 1.0)
		var th := float(ship_texture.get_height()) * k
		draw_set_transform(p, tangent.angle(), Vector2(k, k))
		draw_texture_rect(ship_texture, Rect2(
			-ship_texture.get_width() * 0.5, -ship_texture.get_height() * 0.5,
			ship_texture.get_width(), ship_texture.get_height()
		), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		engine = p - tangent * (target_w * 0.42)
	else:
		var tri := PackedVector2Array([
			p + tangent * s * 1.7,
			p - tangent * s - normal * s * 0.75,
			p - tangent * s + normal * s * 0.75,
		])
		draw_colored_polygon(tri, accent)
		draw_polyline(tri + PackedVector2Array([tri[0]]),
			accent.lightened(0.42), 0.9, true)
	var flick := 0.7 + 0.30 * sin(_time * 21.0) + 0.12 * sin(_time * 47.0)
	draw_circle(engine, 1.6 + 0.9 * flick, Color(0.48, 0.95, 1.0, 0.55))
	draw_circle(engine, 0.8, Color(1.0, 1.0, 1.0, 0.85))

	# Launch ring at Earth during the first 12 % of the journey.
	if raw_u < 0.12:
		var k := raw_u / 0.12
		draw_arc(_at(0.0), 3.0 + 12.0 * k, 0.0, TAU, 18,
			Color(accent.r, accent.g, accent.b, 0.5 * (1.0 - k)), 1.0, true)

	# Arrival: expanding ring + a short burst while the ship holds in orbit.
	if t > travel_seconds:
		var k := clampf((t - travel_seconds) / hold_seconds, 0.0, 1.0)
		var ring_col := Color(0.62, 0.95, 0.92, 0.65 * (1.0 - k))
		draw_arc(_at(1.0), 4.0 + 14.0 * k, 0.0, TAU, 20, ring_col, 1.0, true)
		draw_circle(_at(1.0), 1.6, Color(0.85, 1.0, 0.98, 0.9))
