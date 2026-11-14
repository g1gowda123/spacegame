class_name SpaceBackdrop
extends Control
## Raster space backdrop. Every illustration is a ComfyUI-generated PNG; this
## node only positions and scales those textures. No shader/vector artwork.

const BG_PATH := "res://assets/backgrounds/space.png"
const PLANET_DIR := "res://assets/sprites/planets/"
const FALLBACK_PLANET := "res://assets/sprites/planets/rocky.png"

var star_rect: TextureRect
var planet_rect: TextureRect
var _planet_center := Vector2(0.82, 0.34)
var _planet_size := 0.62
var _planet_on := true
var _planet_asset := ""
var _stars_on := true
var _bg_on := true
var _dim := 0.35
var _bg_rect: ColorRect
var _shade: ColorRect


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
	add_child(star_rect)

	planet_rect = TextureRect.new()
	planet_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	planet_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	planet_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	planet_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	planet_rect.visible = _planet_on
	add_child(planet_rect)

	_shade = ColorRect.new()
	_shade.color = Color(0.03, 0.05, 0.08, _dim)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.visible = _bg_on
	add_child(_shade)
	_layout()


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
	planet_rect.position = Vector2(
		vp.x * _planet_center.x - rect_d * 0.5,
		vp.y * _planet_center.y - rect_d * 0.5
	)
	planet_rect.visible = _planet_on


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
