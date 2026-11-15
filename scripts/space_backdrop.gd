class_name SpaceBackdrop
extends Control
## Raster space backdrop. Every illustration is a ComfyUI-generated PNG; this
## node only positions and scales those textures. No shader/vector artwork.

const BG_PATH := "res://assets/backgrounds/space.png"
const PLANET_DIR := "res://assets/sprites/planets/"
const FALLBACK_PLANET := "res://assets/sprites/planets/rocky.png"

var star_rect: TextureRect
var planet_rect: TextureRect
var _star_mat: ShaderMaterial
var _planet_mat: ShaderMaterial
var _planet_center := Vector2(0.82, 0.34)
var _planet_size := 0.62
var _planet_on := true
var _planet_asset := ""
var _stars_on := true
var _bg_on := true
var _dim := 0.35
var _bg_rect: ColorRect
var _shade: ColorRect
var _sky: TextureRect
var _halo: TextureRect
var _halo_on := 0.0

## Slow ambient motion for the title menu. Everything here is optional and off
## by default: the working consoles stay still, the menu breathes.
const CRAFT_PATH := "res://assets/sprites/ships/pathfinder.png"

var _motion := false
var _t := 0.0
var _craft: TextureRect
var _craft_t := 0.0
var _comet: Node2D
var _comet_age := 0.0
var _comet_life := 1.8
var _comet_timer := 1.4
var _planet_base := Vector2.ZERO
var _spin := 0.0
var _spin_speed := 0.0


class Streak:
	extends Node2D
	## A short tapered meteor trail. Drawn, not textured, so it stays crisp at
	## 640x360 and costs nothing to ship.
	var tail := 30.0

	func _draw() -> void:
		var seg := 7
		for i in seg:
			var f := float(i) / float(seg)
			var a := 0.65 * (1.0 - f)
			draw_line(
				Vector2(-tail * f, 0.0),
				Vector2(-tail * (f + 1.0 / float(seg)), 0.0),
				Color(1.0, 0.94, 0.82, a), 1.0
			)
		draw_circle(Vector2.ZERO, 1.2, Color(1.0, 0.98, 0.92, 0.9))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_layout)


func _build() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.color = Color("#070a11")
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rect.visible = _bg_on
	add_child(_bg_rect)

	star_rect = TextureRect.new()
	star_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star_rect.stretch_mode = TextureRect.STRETCH_SCALE
	star_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	star_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_rect.visible = _stars_on
	if ResourceLoader.exists(BG_PATH):
		star_rect.texture = load(BG_PATH) as Texture2D
	# Drift + twinkle: the plate is a raster, the shader makes it alive.
	var shader := load("res://shaders/star_drift.gdshader") as Shader
	if shader != null:
		_star_mat = ShaderMaterial.new()
		_star_mat.shader = shader
		star_rect.material = _star_mat
	add_child(star_rect)

	# Optional sky wash, added on top of the raster. Additive, so every star and
	# nebula in the plate survives and only the shadows lift towards deep blue.
	# The consoles leave it off and keep the flat void.
	_sky = TextureRect.new()
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.visible = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sky.material = add
	add_child(_sky)

	# Atmosphere bloom behind the disc: one radial gradient, no extra pass.
	_halo = TextureRect.new()
	_halo.texture = _halo_texture()
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.modulate = Color(1, 1, 1, 0)
	add_child(_halo)

	planet_rect = TextureRect.new()
	planet_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	planet_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	planet_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	planet_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	planet_rect.visible = _planet_on
	var pshader := load("res://shaders/planet_view.gdshader") as Shader
	if pshader != null:
		_planet_mat = ShaderMaterial.new()
		_planet_mat.shader = pshader
		planet_rect.material = _planet_mat
	add_child(planet_rect)

	_shade = ColorRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.visible = _bg_on
	add_child(_shade)

	# Ambient life, drawn above the shade so the ship and meteors stay legible
	# against a dimmed plate. Hidden until a screen asks for motion.
	_craft = TextureRect.new()
	_craft.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_craft.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_craft.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_craft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_craft.modulate = Color(0.93, 0.95, 0.94, 0.0)
	if ResourceLoader.exists(CRAFT_PATH):
		_craft.texture = load(CRAFT_PATH) as Texture2D
	_craft.visible = false
	add_child(_craft)

	_comet = Streak.new()
	_comet.visible = false
	add_child(_comet)

	_layout()
	set_process(_motion)


func _halo_texture() -> GradientTexture2D:
	## A ring of air just outside the disc. The gradient's bright stop sits at
	## the disc radius for the size _layout() gives the halo (1.62x the disc),
	## so the glow hugs the limb and falls off into space.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 0.79, 0.92, 1.0])
	g.colors = PackedColorArray([
		Color(0.30, 0.52, 0.68, 0.0),
		Color(0.34, 0.58, 0.72, 0.04),
		Color(0.48, 0.74, 0.86, 0.22),
		Color(0.40, 0.64, 0.78, 0.07),
		Color(0.40, 0.64, 0.78, 0.0),
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _set_sky(top: Color, bottom: Color) -> void:
	## Vertical air wash, slightly diagonal so the top-left corner is deepest.
	if _sky == null:
		return
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.22, 1.0)
	t.width = 32
	t.height = 64
	_sky.texture = t
	_sky.visible = true


func configure(opts: Dictionary) -> void:
	if opts.has("planet_center"):
		_planet_center = opts["planet_center"]
	if opts.has("planet_size"):
		_planet_size = float(opts["planet_size"])
	if opts.has("planet_on"):
		_planet_on = bool(opts["planet_on"])
	if opts.has("stars_on"):
		_stars_on = bool(opts["stars_on"])
		if star_rect != null:
			star_rect.visible = _stars_on
	if opts.has("bg_on"):
		_bg_on = bool(opts["bg_on"])
		if _bg_rect != null:
			_bg_rect.visible = _bg_on
		if _shade != null:
			_shade.visible = _bg_on
	if opts.has("planet_asset"):
		_planet_asset = str(opts["planet_asset"])
		_load_planet(_planet_asset)
	if opts.has("dim"):
		_dim = clampf(float(opts["dim"]), 0.0, 1.0)
		if _shade != null:
			_shade.color = Color(0.03, 0.05, 0.08, _dim)
	if opts.has("sky_top") or opts.has("sky_bottom"):
		_set_sky(
			opts.get("sky_top", Color(0.02, 0.05, 0.08)),
			opts.get("sky_bottom", Color(0.01, 0.03, 0.05))
		)
	if opts.has("halo"):
		_halo_on = clampf(float(opts["halo"]), 0.0, 1.0)
		if _halo != null:
			_halo.modulate.a = _halo_on
	if opts.has("light_angle") and _planet_mat != null:
		# Radians. The default (-0.75) lights the disc from the right; the
		# title menu puts the planet on the left, so its key light must come
		# from off-frame left and leave the menu side in shadow.
		_planet_mat.set_shader_parameter("light_angle", float(opts["light_angle"]))
	if opts.has("nebula") and _star_mat != null:
		_star_mat.set_shader_parameter("nebula", float(opts["nebula"]))
	if opts.has("bright") and _star_mat != null:
		_star_mat.set_shader_parameter("bright", float(opts["bright"]))
	if opts.has("planet_light") and _planet_mat != null:
		_planet_mat.set_shader_parameter("base_light",
			clampf(float(opts["planet_light"]), 0.0, 1.0))
	if opts.has("atmosphere") and _planet_mat != null:
		_planet_mat.set_shader_parameter("atmosphere",
			clampf(float(opts["atmosphere"]), 0.0, 2.0))
	if opts.has("spin_speed"):
		# Radians per second. One turn per ~90 s at TAU/90 reads as a planet
		# turning: slow, but you can see the surface move if you watch it.
		_spin_speed = float(opts["spin_speed"])
	if opts.has("motion"):
		_motion = bool(opts["motion"])
		set_process(_motion)
		if not _motion:
			if _craft != null:
				_craft.visible = false
			if _comet != null:
				_comet.visible = false
		elif _craft != null:
			# The craft fades in through modulate alpha on the first pass, so it
			# only needs to be made visible here.
			_craft.visible = true
	if planet_rect != null:
		planet_rect.visible = _planet_on
	_layout()


func _load_planet(asset: String) -> void:
	if planet_rect == null:
		return
	var path := asset
	if not path.begins_with("res://"):
		path = PLANET_DIR + asset + ".png"
	if not ResourceLoader.exists(path):
		path = FALLBACK_PLANET
	if ResourceLoader.exists(path):
		planet_rect.texture = load(path) as Texture2D
		if _planet_mat != null and planet_rect.texture != null:
			_planet_mat.set_shader_parameter("planet_res",
				Vector2(planet_rect.texture.get_width(), planet_rect.texture.get_height()))


func set_planet_colors(_a: Color, _b: Color, _c: Color) -> void:
	# Kept for call-site compatibility. The generated planet already carries
	# its own biome palette, so runtime tinting is intentionally disabled.
	pass


func set_planet_rect(center: Vector2, size_frac: float) -> void:
	_planet_center = center
	_planet_size = size_frac
	_layout()


func _layout() -> void:
	if star_rect == null:
		return
	var vp := size
	if vp.x <= 0.0:
		vp = get_viewport_rect().size
	star_rect.position = Vector2.ZERO
	star_rect.size = vp
	star_rect.visible = _stars_on
	if _star_mat != null:
		_star_mat.set_shader_parameter("resolution", vp)
	if _sky != null:
		_sky.position = Vector2.ZERO
		_sky.size = vp
	if _shade != null:
		_shade.position = Vector2.ZERO
		_shade.size = vp
		_shade.color = Color(0.03, 0.05, 0.08, _dim)
	if planet_rect == null:
		return
	var d: float = minf(vp.x, vp.y) * _planet_size
	# The source planet PNGs include a small transparent margin. Give the
	# texture box a little extra room so the disc is never clipped.
	var rect_d := d * 1.10
	planet_rect.size = Vector2(rect_d, rect_d)
	# Spin about the disc centre, not the texture's top-left corner.
	planet_rect.pivot_offset = Vector2(rect_d, rect_d) * 0.5
	planet_rect.position = Vector2(
		vp.x * _planet_center.x - rect_d * 0.5,
		vp.y * _planet_center.y - rect_d * 0.5
	)
	_planet_base = planet_rect.position
	planet_rect.visible = _planet_on
	if _halo != null:
		var hd := d * 1.62
		_halo.size = Vector2(hd, hd)
		_halo.position = Vector2(
			vp.x * _planet_center.x - hd * 0.5,
			vp.y * _planet_center.y - hd * 0.5
		)


func _process(delta: float) -> void:
	if not _motion:
		return
	_t += delta
	var vp := size
	if vp.x <= 0.0:
		return

	# A survey probe climbing the open sky on the right: 30 s a pass, so it
	# reads as something crossing the frame rather than a loop you can catch.
	if _craft != null:
		_craft_t = fmod(_craft_t + delta / 30.0, 1.0)
		var cs: float = maxf(vp.y * 0.095, 24.0)
		_craft.size = Vector2(cs * 1.9, cs)
		_craft.position = Vector2(
			vp.x * (0.94 - 0.34 * _craft_t) + sin(_craft_t * TAU * 1.3) * 8.0,
			lerpf(vp.y * 1.06, vp.y * -0.12, _craft_t)
		)
		_craft.rotation = -0.40 + 0.09 * sin(_craft_t * TAU)
		_craft.modulate.a = clampf(minf(_craft_t, 1.0 - _craft_t) / 0.08, 0.0, 1.0) * 0.92

	# The planet drifts a couple of pixels and turns on its axis: enough to feel
	# alive, not enough to pull the eye off the menu.
	if planet_rect != null and _planet_on:
		if _spin_speed != 0.0:
			_spin = fmod(_spin + delta * _spin_speed, TAU)
			planet_rect.rotation = _spin
			if _planet_mat != null:
				_planet_mat.set_shader_parameter("spin", _spin)
		planet_rect.position = _planet_base + Vector2(0.0, sin(_t * 0.27) * 2.0)

	# One meteor every 7-12 s, crossing the open sky on the right. The first
	# one arrives after ~1.4 s so the frame is alive on the very first look.
	if _comet != null:
		if _comet.visible:
			_comet_age += delta
			_comet.position += Vector2(-168.0, 98.0) * delta
			_comet.modulate.a = sin(clampf(_comet_age / _comet_life, 0.0, 1.0) * PI)
			if _comet_age >= _comet_life:
				_comet.visible = false
				_comet_age = 0.0
				_comet_timer = 7.0 + fmod(_t * 5.7, 5.0)
		else:
			_comet_timer -= delta
			if _comet_timer <= 0.0:
				_comet.visible = true
				_comet_age = 0.0
				_comet.position = Vector2(
					vp.x * (0.70 + fmod(_t * 0.37, 0.24)), vp.y * 0.08)
				_comet.rotation = 0.52


static func planet_path(name: String) -> String:
	var path := PLANET_DIR + name + ".png"
	if ResourceLoader.exists(path):
		return path
	return FALLBACK_PLANET


static func asset_for_planet(p: Dictionary) -> String:
	return planet_path(str(p.get("biome", "barren")))


static func colors_for_planet(p: Dictionary) -> Array:
	# Legacy helper retained for any non-visual callers. The actual portrait is
	# selected by biome in asset_for_planet().
	var teq := float(p.get("eq_temp_k", 280.0))
	if teq >= 700.0:
		return [Color("#ff6d4a"), Color("#4a1408"), Color("#ffd08a")]
	if teq >= 500.0:
		return [Color("#e08a4a"), Color("#552c14"), Color("#ffd8a8")]
	if teq >= 330.0:
		return [Color("#c9925c"), Color("#4b3520"), Color("#f2d8b0")]
	if teq >= 235.0:
		return [Color("#4fa8a0"), Color("#123a4a"), Color("#c8f4e8")]
	return [Color("#7c9fd6"), Color("#17264a"), Color("#dcecff")]


static func create(opts: Dictionary = {}) -> SpaceBackdrop:
	var b := SpaceBackdrop.new()
	b.configure(opts)
	return b
