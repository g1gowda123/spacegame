class_name UITip
extends CanvasLayer
## Balatro-style hover dossier: one paper slip with a coloured edge that appears
## beside the control under the cursor. The card is input-transparent, so it can
## never steal the click that opened it.

static var _inst: UITip

var _panel: PanelContainer
var _title: Label
var _body: Label
var _host: Control
var _tween: Tween


static func bind(host: Control, title: String, body: String,
	accent: Color = UIKit.CYAN) -> void:
	if host == null:
		return
	if "--no-tips" in OS.get_cmdline_args() or "--no-tips" in OS.get_cmdline_user_args():
		return
	host.mouse_entered.connect(func(): _open(host, title, body, accent))
	host.mouse_exited.connect(func(): _close(host))


static func _ensure() -> UITip:
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		return _inst
	_inst = UITip.new()
	_inst.layer = 60
	var scene := (Engine.get_main_loop() as SceneTree).current_scene
	if scene != null:
		scene.add_child(_inst)
	return _inst


static func _open(host: Control, title: String, body: String, accent: Color) -> void:
	var tip := _ensure()
	tip._host = host
	tip._title.text = title
	tip._title.add_theme_color_override("font_color", UIKit.INK)
	tip._body.text = body
	tip._panel.add_theme_stylebox_override("panel", tip._style(accent))
	tip._place(host)
	tip.visible = true
	if tip._tween != null and tip._tween.is_valid():
		tip._tween.kill()
	tip._panel.modulate.a = 0.0
	tip._tween = tip.create_tween()
	tip._tween.tween_property(tip._panel, "modulate:a", 1.0, 0.08)


static func _close(host: Control) -> void:
	if _inst == null or not is_instance_valid(_inst):
		return
	# Entering the next row fires this before the next open; only the current
	# host may dismiss the card.
	if _inst._host != host:
		return
	_inst.visible = false


static func hide_tip() -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst.visible = false


func _init() -> void:
	layer = 60
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 3)
	_panel.add_child(v)

	_title = UIKit.head("", 8, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title)

	_body = UIKit.mono("", 7, UIKit.INK_SOFT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(178, 0)
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_body)
	visible = false


func _style(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UIKit.PAPER
	var edge := accent
	if edge.get_luminance() > 0.55:
		edge = edge.darkened(0.32)
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.shadow_color = Color(0.04, 0.03, 0.02, 0.55)
	s.shadow_size = 2
	s.shadow_offset = Vector2(2, 2)
	return s


func _place(host: Control) -> void:
	var width := 196.0
	_panel.size = Vector2(width, 0)
	var height := maxf(24.0, _panel.get_combined_minimum_size().y)
	_panel.size = Vector2(width, height)
	var r := host.get_global_rect()
	var x := r.end.x + 8.0
	if x + width > 632.0:
		x = r.position.x - width - 8.0
	x = clampf(x, 8.0, 632.0 - width)
	var y := r.position.y
	# Top-bar dossiers drop below the bar instead of covering the stat the
	# cursor is asking about.
	if y < 50.0 and r.size.y <= 50.0:
		y = r.end.y + 4.0
	if y + height > 352.0:
		y = 352.0 - height
	y = clampf(y, 8.0, 352.0 - height)
	_panel.position = Vector2(x, y)
