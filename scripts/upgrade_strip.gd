class_name UpgradeStrip
extends Control
## Persistent, Risk-of-Rain-style rack of everything the lander is carrying:
## paid refits (square, steel) and field commissions (diamond notch, warm).
## Icons only while flying so the map stays readable; every chip carries a
## Balatro dossier on hover, and TAB opens the full arsenal readout.
##
## The strip is deliberately self-contained: add it to a HUD root, call
## refresh(), and feed it stat names from the sector loop.

const CHIP := 22.0
const STEP := 24.0
const MAX_ROWS := 9
const COL := 26.0

const STAT_KEYS := [
	"power_regen", "thermal_res", "dv", "integrity", "data_cap",
	"comms_bonus", "science", "grant", "move_range", "repair",
	"vent_power", "shield", "start_data", "sector_integrity", "score",
]

var _entries: Array = []
var _chips: Array = []
var _known: Dictionary = {}
var _sig := ""
var _first := true
var _arsenal: Control
var arsenal_open := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(COL * 3.0, STEP * MAX_ROWS)
	GameState.changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	# Shop/buff screens mutate GameState while the sector is not visible; a
	# cheap signature check keeps this from rebuilding on every emit.
	var sig := _signature()
	if sig == _sig:
		return
	refresh()


func _signature() -> String:
	var parts: Array[String] = []
	for id in GameState.owned:
		parts.append("r:" + str(id))
	for id in GameState.run.get("buffs", []):
		parts.append("b:" + str(id))
	return "|".join(parts)


## Rebuild the rack from GameState. Duplicate ids stack into one chip with a
## count badge (FIELD REPAIR KIT is repeatable), so the rack never overflows
## just because a module was bought twice.
func refresh() -> void:
	_sig = _signature()
	for c in _chips:
		if is_instance_valid(c):
			c.queue_free()
	_chips.clear()
	_entries = _collect()
	var counts: Dictionary = {}
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		var chip := _build_chip(e)
		chip.position = Vector2(
			float(i / MAX_ROWS) * COL,
			float(i % MAX_ROWS) * STEP
		)
		add_child(chip)
		_chips.append(chip)
		var id := str(e["id"])
		counts[id] = int(counts.get(id, 0)) + 1
		if _first or not _known.has(id):
			_pop_in(chip, i, _first)
		else:
			chip.modulate.a = 1.0
		if _known.has(id) and not _first:
			_flash(chip, e["accent"])
	_known = counts
	_first = false
	if arsenal_open:
		_rebuild_arsenal()


func _collect() -> Array:
	var out: Array = []
	var groups: Dictionary = {}
	for id in GameState.owned:
		var uid := str(id)
		if not groups.has(uid):
			groups[uid] = 0
		groups[uid] = int(groups[uid]) + 1
	for uid in groups:
		var def := _upgrade(uid)
		if def.is_empty():
			continue
		out.append(_entry(def, "REFIT", int(groups[uid])))
	var buffs: Dictionary = {}
	for id in GameState.run.get("buffs", []):
		var bid := str(id)
		buffs[bid] = int(buffs.get(bid, 0)) + 1
	for bid in buffs:
		var def := _buff(bid)
		if def.is_empty():
			continue
		out.append(_entry(def, "BUFF", int(buffs[bid])))
	return out


func _entry(def: Dictionary, kind: String, count: int) -> Dictionary:
	var accent := UIKit.CYAN
	if kind == "BUFF":
		match str(def.get("rarity", "common")):
			"rare":
				accent = UIKit.CYAN
			"epic":
				accent = UIKit.AMBER
			_:
				accent = UIKit.MUTED_C
	elif str(def.get("kind", "MODULE")) == "FIRMWARE":
		accent = UIKit.AMBER
	var stats: Array = []
	for key in STAT_KEYS:
		if def.has(key):
			stats.append(key)
	if def.has("repair"):
		stats.append("integrity")
	return {
		"id": str(def.get("id", "")),
		"name": str(def.get("name", "MODULE")),
		"icon": str(def.get("icon", "cache")),
		"desc": str(def.get("desc", "")),
		"plain": str(def.get("plain", "")),
		"kind": kind,
		"rarity": str(def.get("rarity", "")),
		"firmware": str(def.get("kind", "")) == "FIRMWARE",
		"accent": accent,
		"count": count,
		"stats": stats,
	}


func _upgrade(id: String) -> Dictionary:
	for up in GameState.UPGRADES:
		if str(up.get("id", "")) == id:
			return up
	return {}


func _buff(id: String) -> Dictionary:
	for b in GameState.BUFFS:
		if str(b.get("id", "")) == id:
			return b
	return {}


func _build_chip(e: Dictionary) -> Panel:
	var accent: Color = e["accent"]
	var chip := Panel.new()
	chip.size = Vector2(CHIP, CHIP)
	chip.pivot_offset = Vector2(CHIP, CHIP) * 0.5
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.add_theme_stylebox_override("panel", _chip_style(accent, false))

	var icon_path := "res://assets/sprites/buffs/%s.png" % str(e["icon"])
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path) as Texture2D
		icon.position = Vector2(3, 3)
		icon.size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(icon)
	else:
		var glyph := UIKit.head(str(e["name"]).substr(0, 2), 8, accent,
			HORIZONTAL_ALIGNMENT_CENTER)
		glyph.position = Vector2(0, 4)
		glyph.size = Vector2(CHIP, 14)
		chip.add_child(glyph)

	# Field commissions get a warm corner notch so hardware and firmware read
	# apart even before the dossier opens.
	if str(e["kind"]) == "BUFF":
		var notch := ColorRect.new()
		notch.color = accent
		notch.position = Vector2(CHIP - 5, 1)
		notch.size = Vector2(4, 4)
		notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(notch)

	if int(e["count"]) > 1:
		var badge := UIKit.mono("x%d" % int(e["count"]), 7, UIKit.CREAM,
			HORIZONTAL_ALIGNMENT_RIGHT)
		badge.position = Vector2(-2, 8)
		badge.size = Vector2(CHIP, 13)
		badge.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03, 0.95))
		badge.add_theme_constant_override("outline_size", 3)
		chip.add_child(badge)

	var body := str(e["desc"])
	if str(e["plain"]) != "":
		body += "\n" + str(e["plain"])
	var type_line := "FIELD COMMISSION"
	if str(e["kind"]) == "BUFF":
		if str(e["rarity"]) != "":
			type_line += " · " + str(e["rarity"]).to_upper()
	else:
		type_line = "FIRMWARE" if bool(e["firmware"]) else "HARDWARE"
	body += "\n\n%s · INSTALLED x%d" % [type_line, int(e["count"])]
	UIKit.hover_info(chip, str(e["name"]), body, accent)

	chip.mouse_entered.connect(func():
		chip.add_theme_stylebox_override("panel", _chip_style(accent, true))
		_tween_chip(chip, 1.16)
	)
	chip.mouse_exited.connect(func():
		chip.add_theme_stylebox_override("panel", _chip_style(accent, false))
		_tween_chip(chip, 1.0)
	)
	chip.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				toggle_arsenal()
	)
	return chip


func _chip_style(accent: Color, lit: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.031, 0.063, 0.071, 0.93 if not lit else 0.98)
	s.border_color = accent if lit else Color(accent.r, accent.g, accent.b, 0.62)
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	if lit:
		s.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
		s.shadow_size = 3
	return s


func _pop_in(chip: Control, index: int, all_at_once: bool) -> void:
	chip.modulate.a = 0.0
	chip.scale = Vector2(0.35, 0.35)
	var tw := create_tween()
	tw.set_parallel(true)
	if not all_at_once:
		tw.tween_property(chip, "modulate:a", 1.0, 0.18).set_delay(index * 0.045)
		tw.tween_property(chip, "scale", Vector2.ONE, 0.30).set_delay(index * 0.045) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(chip, "modulate:a", 1.0, 0.18)
		tw.tween_property(chip, "scale", Vector2.ONE, 0.30) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash(chip: Control, accent: Color) -> void:
	## A newly installed chip announces itself once, then settles.
	chip.set_meta("flash", true)
	chip.scale = Vector2(1.4, 1.4)
	chip.modulate = Color.WHITE.lerp(accent, 0.55)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(chip, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(chip, "modulate", Color.WHITE, 0.52)


func _tween_chip(chip: Control, to: float) -> void:
	if chip.has_meta("pulse_tw"):
		var old: Tween = chip.get_meta("pulse_tw")
		if old != null and old.is_valid():
			old.kill()
	var tw := create_tween()
	tw.tween_property(chip, "scale", Vector2(to, to), 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	chip.set_meta("pulse_tw", tw)


## Pulse every chip that feeds a stat the sector just changed. Damage, heat,
## fuel, data and power therefore trace back to the hardware that governs them.
func pulse(stat: String, color: Color = Color.WHITE) -> void:
	for chip in _chips:
		var idx := _chips.find(chip)
		if idx < 0 or idx >= _entries.size():
			continue
		if not ((_entries[idx]["stats"] as Array).has(stat)):
			continue
		pop_chip(chip, color)


func pop_chip(chip: Control, color: Color) -> void:
	if chip.has_meta("pulse_tw"):
		var old: Tween = chip.get_meta("pulse_tw")
		if old != null and old.is_valid():
			old.kill()
	chip.pivot_offset = Vector2(CHIP, CHIP) * 0.5
	chip.scale = Vector2(1.32, 1.32)
	chip.modulate = Color.WHITE.lerp(color, 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(chip, "scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(chip, "modulate", Color.WHITE, 0.36)
	chip.set_meta("pulse_tw", tw)


func toggle_arsenal() -> void:
	if arsenal_open:
		_close_arsenal()
	else:
		_open_arsenal()


func _open_arsenal() -> void:
	if arsenal_open:
		return
	arsenal_open = true
	UITip.hide_tip()
	_arsenal = Control.new()
	_arsenal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arsenal.mouse_filter = Control.MOUSE_FILTER_STOP
	get_parent().add_child(_arsenal)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.025, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_arsenal.add_child(shade)
	shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_close_arsenal()
	)

	var panel := Panel.new()
	panel.position = Vector2(26, 62)
	panel.size = Vector2(588, 224)
	panel.pivot_offset = panel.size * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := UIKit.style_panel(Color(0.039, 0.075, 0.078, 0.98), UIKit.STEEL, 0, 1)
	sb.border_color = UIKit.STEEL_HI
	panel.add_theme_stylebox_override("panel", sb)
	_arsenal.add_child(panel)

	var title := UIKit.head("ARSENAL // INSTALLED SYSTEMS", 10, UIKit.CREAM)
	title.position = Vector2(14, 10)
	title.size = Vector2(400, 16)
	panel.add_child(title)
	var sub := UIKit.mono("%d MODULES · %d FIELD COMMISSIONS · TAB / ESC TO CLOSE" % [
		GameState.owned.size(), GameState.run.get("buffs", []).size()
	], 7, UIKit.MUTED_C)
	sub.position = Vector2(14, 26)
	sub.size = Vector2(520, 12)
	panel.add_child(sub)
	UIKit.hairline(panel, 12, 42, 564, Color(0.33, 0.39, 0.46, 0.55))

	_build_arsenal_rows(panel)

	var close := UIKit.button("CLOSE", Vector2(58, 18))
	close.position = Vector2(514, 10)
	close.add_theme_font_size_override("font_size", 8)
	close.pressed.connect(_close_arsenal)
	panel.add_child(close)

	panel.scale = Vector2(0.96, 0.96)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_arsenal_rows(panel: Control) -> void:
	var old := panel.get_node_or_null("Rows")
	if old != null:
		old.queue_free()
	var rows := Control.new()
	rows.name = "Rows"
	rows.position = Vector2(12, 50)
	rows.size = Vector2(564, 160)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rows)

	if _entries.is_empty():
		var empty := UIKit.mono("No refits or commissions installed yet. Buy hardware in debrief, or pick a field commission between planets.", 8, UIKit.MUTED_C)
		empty.position = Vector2(2, 6)
		empty.size = Vector2(540, 40)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(empty)
		return

	var per_col := 5
	var col_w := 188.0
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		var col := i / per_col
		var row := i % per_col
		var accent: Color = e["accent"]
		var card := Control.new()
		card.position = Vector2(col * col_w, row * 30.0)
		card.size = Vector2(col_w - 8.0, 28)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		rows.add_child(card)

		var icon_frame := Panel.new()
		icon_frame.position = Vector2(0, 3)
		icon_frame.size = Vector2(22, 22)
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_theme_stylebox_override("panel", _chip_style(accent, false))
		card.add_child(icon_frame)
		var icon_path := "res://assets/sprites/buffs/%s.png" % str(e["icon"])
		if ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path) as Texture2D
			icon.position = Vector2(3, 3)
			icon.size = Vector2(16, 16)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_frame.add_child(icon)

		var nm := UIKit.head(str(e["name"]), 8, UIKit.CREAM)
		nm.position = Vector2(28, 1)
		nm.size = Vector2(col_w - 44.0, 12)
		card.add_child(nm)
		var kind := UIKit.mono(
			("x%d  " % int(e["count"]) if int(e["count"]) > 1 else "")
			+ ("COMMISSION" if str(e["kind"]) == "BUFF" else
				("FIRMWARE" if bool(e["firmware"]) else "HARDWARE")),
			6, accent, HORIZONTAL_ALIGNMENT_RIGHT
		)
		kind.position = Vector2(28, 1)
		kind.size = Vector2(col_w - 44.0, 12)
		card.add_child(kind)
		var desc := UIKit.mono(str(e["desc"]), 7, UIKit.MUTED_C)
		desc.position = Vector2(28, 13)
		desc.size = Vector2(col_w - 36.0, 14)
		desc.clip_text = true
		card.add_child(desc)
		UIKit.hover_info(card, str(e["name"]),
			str(e["desc"]) + ("\n" + str(e["plain"]) if str(e["plain"]) != "" else ""),
			accent)


func _rebuild_arsenal() -> void:
	if _arsenal == null or not is_instance_valid(_arsenal):
		return
	_close_arsenal()
	_open_arsenal()


func _close_arsenal() -> void:
	arsenal_open = false
	if _arsenal != null and is_instance_valid(_arsenal):
		_arsenal.queue_free()
	_arsenal = null



