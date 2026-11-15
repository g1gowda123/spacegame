extends Node
## Screenshot helper for development and verification.
## Run with `-- --capture` to save the current frame, or press F10.

var _requested := false
var _elapsed := 0.0
var _path := "user://capture.png"
var _once := false
var _delay := 1.8


func _ready() -> void:
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for raw in args:
		var arg := str(raw)
		if arg == "--capture":
			_requested = true
		elif arg.begins_with("--capture-name="):
			_path = "user://%s.png" % arg.substr(15)
		elif arg.begins_with("--capture-delay="):
			_delay = maxf(0.1, float(arg.substr(16)))


func _process(delta: float) -> void:
	if not _requested or _once:
		return
	_elapsed += delta
	if _elapsed >= _delay:
		_once = true
		_requested = false
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			var err := img.save_png(_path)
			print("CAPTURE ", ProjectSettings.globalize_path(_path), " err=", err)
		else:
			push_error("capture failed: no image")
		var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
		if "--capture" in args:
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			_capture_now()


func _capture_now() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(_path)
		print("CAPTURE ", ProjectSettings.globalize_path(_path))
