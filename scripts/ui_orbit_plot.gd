class_name UIOrbitPlot
extends Control
## A small technical transfer plot for the title console: two ellipses, the
## departure body, and a live transfer marker. It gives the empty side of the
## title a mission artefact instead of another card.

var accent := UIKit.ORANGE
var live := UIKit.LIVE


func _draw() -> void:
	var c := size * 0.5
	var rx := minf(size.x * 0.44, 62.0)
	var ry := size.y * 0.34
	_ellipse(c, rx, ry, Color(UIKit.STEEL, 0.55))
	_ellipse(c, rx * 0.62, ry * 0.62, Color(UIKit.STEEL, 0.32))
	# crosshair ticks
	draw_line(c - Vector2(4, 0), c + Vector2(4, 0), Color(UIKit.STEEL_HI, 0.5), 1.0)
	draw_line(c - Vector2(0, 4), c + Vector2(0, 4), Color(UIKit.STEEL_HI, 0.5), 1.0)
	draw_circle(c, 2.2, accent)
	var t := 0.75
	var p := Vector2(c.x + cos(t) * rx, c.y + sin(t) * ry)
	draw_line(p - Vector2(3, 0), p + Vector2(3, 0), live, 1.0)
	draw_line(p - Vector2(0, 3), p + Vector2(0, 3), live, 1.0)
	draw_circle(p, 1.5, live)


func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(49):
		var a := TAU * float(i) / 48.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, color, 1.0)
