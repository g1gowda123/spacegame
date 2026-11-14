extends CanvasLayer
## Restrained print/film pass over the whole frame: static grain, warm edge
## vignette, a touch of highlight halation. One screen read, 640×360 first.
## Off by default; F8 cycles 0 → 0.35 → 0.7 → 1.0 so a browser run can A/B it.
## CLI: --post / --post=0.6 / --no-post.  The shader is shaders/ui_post.gdshader.

const SHADER := preload("res://shaders/ui_post.gdshader")
const STEPS: Array[float] = [0.0, 0.35, 0.7, 1.0]

var _rect: ColorRect
var _mat: ShaderMaterial
var _strength := 0.0


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for raw in args:
		var arg := str(raw)
		if arg == "--no-post":
			_strength = 0.0
		elif arg == "--post":
			_strength = 1.0
		elif arg.begins_with("--post="):
			_strength = clampf(float(arg.substr(7)), 0.0, 1.0)
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	_apply()


func _apply() -> void:
	visible = _strength > 0.001
	if _mat:
		_mat.set_shader_parameter("strength", _strength)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_F8:
			var next := 0
			for i in STEPS.size():
				if is_equal_approx(_strength, STEPS[i]):
					next = (i + 1) % STEPS.size()
					break
			_strength = STEPS[next]
			_apply()
			print("POST strength %.2f" % _strength)
			get_viewport().set_input_as_handled()
