class_name ShipDiagram
extends Control
## Generated spacecraft portrait. The PNG is produced by ComfyUI through
## tools/gen_asset.py + tools/pixelize_sprite.py; this control never draws a
## vector ship itself.

const SHIP_DIR := "res://assets/sprites/ships/"

var hull_id := "pathfinder"
var accent := Color("#54e6d1")
var instruments: Array = []
var _tex: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_texture()


func set_ship(hull: String, insts: Array) -> void:
	hull_id = hull
	instruments = insts
	match hull:
		"cryo": accent = Color("#7cc8ff")
		"relay": accent = Color("#ffc45c")
		"hopper": accent = Color("#b692ff")
		_: accent = Color("#54e6d1")
	_load_texture()
	queue_redraw()


func _load_texture() -> void:
	var path := SHIP_DIR + hull_id + ".png"
	if not ResourceLoader.exists(path):
		path = SHIP_DIR + "pathfinder.png"
	if ResourceLoader.exists(path):
		_tex = load(path) as Texture2D


func _draw() -> void:
	if _tex == null:
		return
	var box := Rect2(Vector2.ZERO, size)
	if box.size.x < 10.0:
		box.size = Vector2(190, 70)
	draw_texture_rect(_tex, box, false)
