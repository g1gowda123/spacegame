class_name PauseMenu
extends CanvasLayer
## Mission hold. A shared overlay so the pause key/button can stop the
## simulation without stopping its own controls.

signal quit_requested

var is_open := false
var _root: Control
var _panel: Control


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color(0.012, 0.022, 0.028, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var p := UIKit.sheet(_root, 184, 68, 272, 224)
	_panel = p
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)

	var kicker := UIKit.mono("MISSION HOLD  //  SIMULATION PAUSED", 7, UIKit.SAGE)
	kicker.position = Vector2(16, 10)
	kicker.size = Vector2(240, 12)
	c.add_child(kicker)
	var title := UIKit.head("PAUSED", 18, UIKit.NAME)
	title.position = Vector2(16, 25)
	title.size = Vector2(240, 22)
	c.add_child(title)
	var rule := ColorRect.new()
	rule.color = UIKit.STEEL
	rule.position = Vector2(16, 52)
	rule.size = Vector2(240, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(rule)

	var sector := 1
	if not GameState.run.is_empty():
		sector = int(GameState.run.get("sector", 1))
	var status := UIKit.mono("SECTOR %d  ·  RUN IN PROGRESS" % sector, 7, UIKit.INK_SOFT)
	status.position = Vector2(16, 62)
	status.size = Vector2(240, 12)
	c.add_child(status)

	var resume := UIKit.button("RESUME", Vector2(240, 32), true)
	resume.position = Vector2(16, 92)
	resume.add_theme_font_size_override("font_size", 11)
	resume.pressed.connect(close)
	c.add_child(resume)

	var quit := UIKit.button("QUIT TO TITLE", Vector2(240, 24))
	quit.position = Vector2(16, 132)
	quit.add_theme_font_size_override("font_size", 9)
	quit.pressed.connect(func():
		close()
		quit_requested.emit()
	)
	c.add_child(quit)

	var hint := UIKit.mono("ESC / P TO RESUME", 6, UIKit.INK_FAINT,
		HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(16, 176)
	hint.size = Vector2(240, 12)
	c.add_child(hint)


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	_panel.modulate.a = 1.0
	GameState.sfx("click")


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode in [KEY_ESCAPE, KEY_P]:
		close()
		get_viewport().set_input_as_handled()
