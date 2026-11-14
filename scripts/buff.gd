extends Control
## Soul Knight-style free field-commission draft between planets.
## Three cards, one pick, no grant spent. The shop is still the paid refit
## screen; this screen is the milestone reward.

const CARD_W := 154.0
const CARD_H := 212.0
const CARD_GAP := 15.0
const CARD_Y := 72.0

const RARITY_COLORS := {
	"common": Color("#8ba0b6"),
	"rare": Color("#54e6d1"),
	"epic": Color("#b692ff"),
}

var cards: Array = []
var card_nodes: Array = []
var focus := 0
var picked := false
var status_label: Label
var hint_label: Label


func _ready() -> void:
	if GameState.run.is_empty():
		GameState.new_run()
		GameState.quick_loadout()
	if not GameState.has_pending_buff():
		GameState.run["sector"] = maxi(2, int(GameState.run.get("sector", 1)))
		GameState.roll_buff_choices()
	cards = GameState.pending_buff_cards()
	_build()
	for raw in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var arg := str(raw)
		if arg.begins_with("--buff-pick="):
			call_deferred("_pick", int(arg.substr(12)))


func _build() -> void:
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({
		"planet_center": Vector2(0.50, 1.26),
		"planet_size": 0.92,
		"planet_asset": "ringed",
		"dim": 0.62,
	})
	bg.modulate.a = 0.46

	var kicker := UIKit.label("AGENCY REVIEW  //  FIELD COMMISSION", 6, UIKit.AMBER, true,
		HORIZONTAL_ALIGNMENT_CENTER)
	kicker.position = Vector2(0, 14)
	kicker.size = Vector2(640, 10)
	add_child(kicker)

	var title := UIKit.label("SELECT FIELD COMMISSION", 18, UIKit.CYAN, true,
		HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 25)
	title.size = Vector2(640, 24)
	add_child(title)

	var milestone := GameState.buff_milestone_number()
	var sub := UIKit.label(
		"MILESTONE %d OF %d  ·  ONE FREE UPGRADE  ·  NO GRANT SPENT" % [
			milestone if milestone > 0 else 1,
			GameState.BUFF_MILESTONES.size(),
		], 7, UIKit.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 51)
	sub.size = Vector2(640, 12)
	add_child(sub)

	var total_w := CARD_W * 3.0 + CARD_GAP * 2.0
	var start_x := (640.0 - total_w) * 0.5
	for i in range(cards.size()):
		_make_card(i, cards[i], start_x + i * (CARD_W + CARD_GAP), CARD_Y)

	status_label = UIKit.label("", 9, UIKit.GREEN, true, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.position = Vector2(0, 294)
	status_label.size = Vector2(640, 14)
	add_child(status_label)

	hint_label = UIKit.label("1  2  3   ·   CLICK A CARD   ·   CHOOSE ONE", 6, UIKit.DIM, true,
		HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.position = Vector2(0, 324)
	hint_label.size = Vector2(640, 12)
	add_child(hint_label)
	_update_focus()


func _make_card(index: int, buff: Dictionary, x: float, y: float) -> void:
	var rarity := str(buff.get("rarity", "common"))
	var color: Color = RARITY_COLORS.get(rarity, UIKit.MUTED)
	var card := Panel.new()
	card.position = Vector2(x, y)
	card.size = Vector2(CARD_W, CARD_H)
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _card_style(color, false))
	card.gui_input.connect(_card_input.bind(index))
	card.mouse_entered.connect(_on_hover.bind(index, true))
	card.mouse_exited.connect(_on_hover.bind(index, false))
	add_child(card)
	card_nodes.append(card)

	var strip := ColorRect.new()
	strip.color = color
	strip.position = Vector2(0, 0)
	strip.size = Vector2(CARD_W, 2)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(strip)

	var title_label := UIKit.label(str(buff.get("name", "COMMISSION")), 8, UIKit.TEXT, true,
		HORIZONTAL_ALIGNMENT_CENTER)
	title_label.position = Vector2(4, 9)
	title_label.size = Vector2(CARD_W - 8, 14)
	title_label.clip_text = true
	card.add_child(title_label)

	var tag := UIKit.label(rarity.to_upper(), 5, color, true, HORIZONTAL_ALIGNMENT_CENTER)
	tag.position = Vector2(4, 24)
	tag.size = Vector2(CARD_W - 8, 9)
	card.add_child(tag)

	var icon_panel := Panel.new()
	icon_panel.position = Vector2(27, 37)
	icon_panel.size = Vector2(100, 100)
	icon_panel.add_theme_stylebox_override("panel", UIKit.style_panel(
		Color("#050a12"), Color("#1c3044"), 1, 1))
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon_panel)

	var icon := TextureRect.new()
	icon.position = Vector2(4, 4)
	icon.size = Vector2(92, 92)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_name := str(buff.get("icon", "legacy"))
	var icon_path := "res://assets/sprites/buffs/%s.png" % icon_name
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	icon_panel.add_child(icon)

	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.text = "[center]%s[/center]" % str(buff.get("desc", ""))
	desc.fit_content = false
	desc.scroll_active = false
	desc.position = Vector2(8, 143)
	desc.size = Vector2(CARD_W - 16, 48)
	desc.custom_minimum_size = Vector2(CARD_W - 16, 48)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.add_theme_font_override("normal_font", UIKit.body_font)
	desc.add_theme_font_size_override("normal_font_size", 7)
	desc.add_theme_color_override("default_color", Color("#a9bccf"))
	desc.add_theme_constant_override("line_separation", 0)
	card.add_child(desc)

	var num := UIKit.label(str(index + 1), 7, UIKit.DIM, true)
	num.position = Vector2(8, 192)
	num.size = Vector2(20, 12)
	card.add_child(num)
	var free_label := UIKit.label("FREE", 5, UIKit.AMBER, true, HORIZONTAL_ALIGNMENT_RIGHT)
	free_label.position = Vector2(CARD_W - 54, 194)
	free_label.size = Vector2(46, 9)
	card.add_child(free_label)


func _card_style(color: Color, hover: bool) -> StyleBoxFlat:
	var s := UIKit.style_panel(Color("#0b1420"), color.lightened(0.35) if hover else color, 2, 2 if hover else 1)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s


func _update_focus() -> void:
	for i in range(card_nodes.size()):
		var buff: Dictionary = cards[i]
		var color: Color = RARITY_COLORS.get(str(buff.get("rarity", "common")), UIKit.MUTED)
		card_nodes[i].add_theme_stylebox_override("panel", _card_style(color, i == focus))


func _on_hover(index: int, entered: bool) -> void:
	if picked:
		return
	if entered:
		focus = index
	_update_focus()


func _card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick(index)


func _unhandled_input(event: InputEvent) -> void:
	if picked or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_pick(0)
		KEY_2:
			_pick(1)
		KEY_3:
			_pick(2)
		KEY_LEFT:
			focus = maxi(0, focus - 1)
			_update_focus()
		KEY_RIGHT:
			focus = mini(cards.size() - 1, focus + 1)
			_update_focus()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_pick(focus)


func _pick(index: int) -> void:
	if picked or index < 0 or index >= cards.size():
		return
	picked = true
	var chosen: Dictionary = cards[index]
	if not GameState.choose_buff(index):
		picked = false
		return
	for i in range(card_nodes.size()):
		card_nodes[i].modulate = Color(1, 1, 1, 0.42) if i != index else Color.WHITE
	status_label.text = "COMMISSION ACCEPTED  ·  %s" % str(chosen.get("name", "UPGRADE"))
	status_label.add_theme_color_override("font_color", UIKit.CYAN)
	hint_label.text = "INSTALLING BEFORE NEXT TARGET..."
	await get_tree().create_timer(0.55).timeout
	GameState.roll_draft()
	get_tree().change_scene_to_file("res://scenes/draft.tscn")
