extends Node2D

const SPRITE_DIR := "res://assets/sprites"

var _sprites: Array[String] = []
var _index := 0


func _ready() -> void:
	_sprites = _scan()
	if _sprites.is_empty():
		$Info.text = "no sprites in " + SPRITE_DIR
		return
	_show(0)


func _scan() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(SPRITE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png") and not file_name.ends_with("_preview.png"):
			out.append(SPRITE_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _show(i: int) -> void:
	_index = (i + _sprites.size()) % _sprites.size()
	var sprite := $Sprite as Sprite2D
	sprite.texture = load(_sprites[_index]) as Texture2D
	var sprite_name := _sprites[_index].get_file().get_basename()
	$Info.text = "%s  (%d/%d)   [left/right] cycle   [R] rescan" % [sprite_name, _index + 1, _sprites.size()]
	_fit()


func _fit() -> void:
	var sprite := $Sprite as Sprite2D
	if sprite.texture == null:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	var s := minf(280.0 / tex_size.y, 320.0 / tex_size.x)
	s = maxf(1.0, floorf(s))
	sprite.scale = Vector2(s, s)


func _unhandled_input(event: InputEvent) -> void:
	if _sprites.is_empty():
		return
	if event.is_action_pressed("ui_right"):
		_show(_index + 1)
	elif event.is_action_pressed("ui_left"):
		_show(_index - 1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		var keep := _index
		_sprites = _scan()
		if not _sprites.is_empty():
			_show(mini(keep, _sprites.size() - 1))
