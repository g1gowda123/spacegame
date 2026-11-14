class_name UIGauge
extends Control
## Quiet segmented readout used in place of a glossy ProgressBar.
## Draws a 2 px track, quarter ticks and a 4 px fill; no theme resource needed.

var value := 0.0
var max_value := 100.0
var fill_color := Color("#54e6d1")
var track_color := Color("#15263a")
var tick_color := Color("#24384f")
var segments := 4


func _init(w: float = 80.0, h: float = 6.0, color: Color = Color("#54e6d1")) -> void:
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_color = color


func set_value(v: float, m: float) -> void:
	max_value = maxf(1.0, m)
	value = clampf(v, 0.0, max_value)
	queue_redraw()


func set_fill(c: Color) -> void:
	fill_color = c
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var ratio := clampf(value / max_value, 0.0, 1.0)
	draw_rect(Rect2(0.0, h - 2.0, w, 2.0), track_color)
	for i in range(1, segments):
		var tx := roundf(w * float(i) / float(segments))
		draw_rect(Rect2(tx, 0.0, 1.0, maxf(1.0, h - 3.0)), tick_color)
	var fw := roundf(w * ratio)
	if fw > 0.0:
		draw_rect(Rect2(0.0, h - 4.0, fw, 4.0), fill_color)
		# A brighter leading edge makes the current value readable at 1x.
		draw_rect(Rect2(maxf(0.0, fw - 1.0), 0.0, 1.0, maxf(1.0, h - 3.0)),
			fill_color.lightened(0.3))
