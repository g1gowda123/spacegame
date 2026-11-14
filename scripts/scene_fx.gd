extends CanvasLayer
## Global scene-arrival transition.
##
## Every screen still calls `change_scene_to_file()` directly, so this autoload
## does not need to own navigation: it watches `tree.current_scene` and plays a
## short fade on the frame a new scene appears. That converts every hard cut in
## the game (title → design → draft → sector → debrief → report, and the
## briefing/crew/buff detours) into an arrival beat without touching a single
## call site.
##
## Headless-safe: a ColorRect with no visual cost, no timers, no audio.

const FADE_IN := 0.24
const HOLD := 0.03

var _fade: ColorRect
var _tween: Tween
var _last_scene: Node
var _first := true


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.015, 0.020, 0.032, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_fade.visible = false


func _process(_delta: float) -> void:
	var current := get_tree().current_scene
	if current == _last_scene:
		return
	_last_scene = current
	_play_fade()


func _play_fade() -> void:
	if _fade == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_fade.visible = true
	_fade.color = Color(0.015, 0.020, 0.032, 1.0)
	_tween = create_tween()
	# A 1-frame hold makes the cut read as an intentional beat rather than a
	# frame of missing content if the scene takes a frame to draw.
	_tween.tween_interval(HOLD if not _first else 0.06)
	_tween.tween_property(_fade, "color:a", 0.0, FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _fade.visible = false)
	_first = false
