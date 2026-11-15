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
var _arsenal_layer: CanvasLayer
var _more: Panel
var arsenal_open := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(COL * 3.0, STEP * MAX_ROWS)
	GameState.changed.connect(_on_state_changed)

	# A single porthole at the foot of the rack opens the full sheet. Icons
	# alone do not advertise that a readable list exists.
	_more = Panel.new()
	_more.position = Vector2(0, STEP * MAX_ROWS + 2.0)
	_more.size = Vector2(CHIP, 15)
	_more.pivot_offset = Vector2(CHIP, 15) * 0.5
	_more.mouse_filter = Control.MOUSE_FILTER_STOP
	_more.add_theme_stylebox_override("panel", _chip_style(UIKit.STEEL, false))
	# Three bars read as "list" at this size; text LABEL was both too wide
	# and clipped by the 22 px rack column.
	var bars: Array[ColorRect] = []
	for i in range(3):
		var bar := ColorRect.new()
		bar.color = UIKit.MUTED_C
		bar.position = Vector2(7, 4 + i * 4)
		bar.size = Vector2(8, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_more.add_child(bar)
		bars.append(bar)
	_more.mouse_entered.connect(func():
		_more.add_theme_stylebox_override("panel", _chip_style(UIKit.CYAN, true))
		for bar in bars:
			bar.color = UIKit.CREAM
		_tween_chip(_more, 1.14)
	)
	_more.mouse_exited.connect(func():
		_more.add_theme_stylebox_override("panel", _chip_style(UIKit.STEEL, false))
		for bar in bars:
			bar.color = UIKit.MUTED_C
		_tween_chip(_more, 1.0)
	)
	_more.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				toggle_arsenal()
	)
	_more.visible = false
	add_child(_more)
	UIKit.hover_info(_more, "ARSENAL",
		"Open the full installed-systems sheet.\nEvery refit and field commission is listed with its exact effect.\n\nTAB or click any chip also opens this.",
		UIKit.CYAN)

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
	if "--rack-dump" in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var dump: Array[String] = []
		for e in _entries:
			dump.append("%s x%d" % [str(e["id"]), int(e["count"])])
		print("RACK ", " | ".join(dump))
	var counts: Dictionary = {}
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		var chip := _build_chip(e)
		chip.position = Vector2(
			float(i / MAX_ROWS) * COL,
			float(i % MAX_ROWS) * STEP
		)
		chip.set_meta("accent", e["accent"])
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
	if _more != null:
		_more.visible = not _entries.is_empty()
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

	var icon_path := "res://assets/sprites/modules/%s.png" % str(e["id"])
	if str(e.get("kind", "")) == "BUFF":
		icon_path = "res://assets/sprites/buffs_hd/%s.png" % str(e["icon"])
		if not ResourceLoader.exists(icon_path):
			icon_path = "res://assets/sprites/buffs/%s.png" % str(e["icon"])
	if not ResourceLoader.exists(icon_path):
		icon_path = "res://assets/sprites/buffs/%s.png" % str(e["icon"])
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		# Set the expand mode before the size: TextureRect clamps its minimum
		# to the texture until it is told to ignore it, which made 48 px art
		# overflow a 22 px chip.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(icon_path) as Texture2D
		icon.position = Vector2(3, 3)
		icon.size = Vector2(16, 16)
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
	chip.set_meta("tip_title", str(e["name"]))
	chip.set_meta("tip_body", body)
	chip.set_meta("tip_accent", accent)
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
	s.border_color = accent if lit else Color(accent.r, accent.g, accent.b, 0.74)
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


## Hovering a HUD stat lights every chip that feeds it, so "why is my hull
## 10?" points straight at the armor/commission hardware instead of the
## player having to read each dossier.
func highlight(stat: String) -> void:
	for i in range(_chips.size()):
		if i >= _entries.size():
			break
		if not ((_entries[i]["stats"] as Array).has(stat)):
			continue
		var chip: Control = _chips[i]
		chip.add_theme_stylebox_override("panel",
			_chip_style(chip.get_meta("accent", UIKit.CYAN), true))
		_tween_chip(chip, 1.12)


func clear_highlight() -> void:
	for chip in _chips:
		if not is_instance_valid(chip):
			continue
		chip.add_theme_stylebox_override("panel",
			_chip_style(chip.get_meta("accent", UIKit.CYAN), false))
		_tween_chip(chip, 1.0)


func preview_tip(index: int) -> void:
	## QA hook: show the dossier for one chip without moving the mouse.
	if index < 0 or index >= _chips.size():
		return
	var chip: Control = _chips[index]
	UITip.preview(chip, str(chip.get_meta("tip_title", "")),
		str(chip.get_meta("tip_body", "")), chip.get_meta("tip_accent", UIKit.CYAN))


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
	# A dedicated layer keeps the sheet above the sector HUD *and* the fx
	# canvas (layer 26) where the rig banner lives, but below UITip (60).
	_arsenal_layer = CanvasLayer.new()
	_arsenal_layer.layer = 55
	get_parent().add_child(_arsenal_layer)
	_arsenal = Control.new()
	_arsenal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arsenal.mouse_filter = Control.MOUSE_FILTER_STOP
	_arsenal_layer.add_child(_arsenal)

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

	var title := UIKit.head("ARSENAL // UPGRADE TREE", 10, UIKit.CREAM)
	title.position = Vector2(14, 10)
	title.size = Vector2(400, 16)
	panel.add_child(title)
	var sub := UIKit.mono("7 SYSTEMS · 2 PATHS EACH · TIER 2 NEEDS TIER 1 · %d INSTALLED · TAB / ESC CLOSE" % GameState.owned.size(), 7, UIKit.MUTED_C)
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
	var tree := Control.new()
	tree.name = "Rows"
	tree.position = Vector2(12, 44)
	tree.size = Vector2(564, 170)
	tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tree)

	var systems := [
		"PROPULSION", "POWER", "THERMAL", "STRUCTURE",
		"COMMS", "SCIENCE", "SUPPORT",
	]
	var centers: Array[float] = [42.0, 122.0, 202.0, 282.0, 362.0, 442.0, 522.0]
	var root := Vector2(282.0, 24.0)
	# Root bus: one hull silhouette feeding all seven systems.
	_tree_icon(tree, "res://assets/sprites/ships/pathfinder_2x.png",
		Vector2(252.0, 2.0), Vector2(60.0, 22.0), UIKit.STEEL, false, false,
		"LANDER BUS", "The common spacecraft bus. Every system branch grows from here.")
	var root_label := UIKit.mono("LANDER BUS", 5, UIKit.MUTED_C,
		HORIZONTAL_ALIGNMENT_CENTER)
	root_label.position = Vector2(222.0, 24.0)
	root_label.size = Vector2(120.0, 8.0)
	tree.add_child(root_label)

	for i in range(systems.size()):
		var system := str(systems[i])
		var sx: float = centers[i]
		var sys_color := Color(str(GameState.SYSTEM_COLOR.get(system, "#e8dfc8")))
		_tree_line(tree, root, Vector2(sx, 32.0), Color(
			UIKit.STEEL.r, UIKit.STEEL.g, UIKit.STEEL.b, 0.42))
		_tree_icon(tree, "res://assets/sprites/modules/branches/%s_A.png" % system,
			Vector2(sx - 15.0, 32.0), Vector2(30.0, 30.0), sys_color, false, false,
			system, "Two paths: A and B. Buy across either branch; tier 2 needs its tier 1.")
		var sys_label := UIKit.mono(system, 5, sys_color,
			HORIZONTAL_ALIGNMENT_CENTER)
		sys_label.position = Vector2(sx - 40.0, 63.0)
		sys_label.size = Vector2(80.0, 8.0)
		tree.add_child(sys_label)

		var a: Array = []
		var b: Array = []
		for up in GameState.UPGRADES:
			if str(up.get("branch", "")) != system:
				continue
			if str(up.get("path", "A")) == "B":
				b.append(up)
			else:
				a.append(up)
		a.sort_custom(func(x: Dictionary, z: Dictionary) -> bool:
			return int(x.get("tier", 1)) < int(z.get("tier", 1)))
		b.sort_custom(func(x: Dictionary, z: Dictionary) -> bool:
			return int(x.get("tier", 1)) < int(z.get("tier", 1)))
		_tree_lane(tree, a, sx - 16.0, sys_color)
		_tree_lane(tree, b, sx + 16.0, sys_color)


func _tree_lane(tree: Control, parts: Array, cx: float, sys_color: Color) -> void:
	for i in range(parts.size()):
		var up: Dictionary = parts[i]
		var id := str(up.get("id", ""))
		var path := str(up.get("path", "A"))
		var tier := int(up.get("tier", 1))
		var installed := id in GameState.owned
		var req := str(up.get("requires", ""))
		var locked := req != "" and not (req in GameState.owned)
		var y := 76.0 if tier == 1 else 116.0
		_tree_line(tree, Vector2(cx, 32.0 if tier == 1 else 106.0),
			Vector2(cx, y), Color(sys_color.r, sys_color.g, sys_color.b, 0.50))
		_tree_icon(tree, "res://assets/sprites/modules/%s.png" % id,
			Vector2(cx - 15.0, y), Vector2(30.0, 30.0), sys_color,
			installed, locked, str(up.get("name", id)),
			"%s\n\n%s\nCOST $%dM%s" % [
				str(up.get("plain", up.get("desc", ""))),
				"TIER 2 LOCKED · BUY TIER 1 FIRST" if locked else
					("INSTALLED" if installed else "AVAILABLE IN REFIT"),
				int(up.get("cost", 0.0)),
				("\nREQUIRES " + req) if req != "" else "",
			])
		var short := str(up.get("name", id)).split(" ")[0]
		var label := UIKit.mono("%s%d %s" % [path, tier, short], 5,
			UIKit.CREAM if installed else UIKit.MUTED_C,
			HORIZONTAL_ALIGNMENT_CENTER)
		label.position = Vector2(cx - 24.0, y + 31.0)
		label.size = Vector2(48.0, 8.0)
		tree.add_child(label)


func _tree_icon(parent: Control, path: String, pos: Vector2, size: Vector2,
		border: Color, installed: bool, locked: bool, title: String,
		body: String) -> void:
	var card := Panel.new()
	card.position = pos
	card.size = size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UIKit.PAPER if not locked else Color(0.10, 0.11, 0.12, 0.94)
	var line := UIKit.GREEN if installed else border
	if locked:
		line = Color(border.r, border.g, border.b, 0.32)
	card.add_theme_stylebox_override("panel", UIKit.style_panel(bg, line, 0, 1))
	parent.add_child(card)
	if ResourceLoader.exists(path):
		var icon := TextureRect.new()
		icon.texture = load(path) as Texture2D
		icon.position = Vector2(2, 2)
		icon.size = size - Vector2(4, 4)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate = Color(1, 1, 1, 0.38 if locked else 1.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
	UIKit.hover_info(card, title, body, line)


func _tree_line(parent: Control, a: Vector2, b: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([a, b])
	line.width = 1.0
	line.default_color = color
	line.antialiased = true
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _rebuild_arsenal() -> void:
	if _arsenal == null or not is_instance_valid(_arsenal):
		return
	_close_arsenal()
	_open_arsenal()


func _close_arsenal() -> void:
	arsenal_open = false
	if _arsenal_layer != null and is_instance_valid(_arsenal_layer):
		_arsenal_layer.queue_free()
	_arsenal_layer = null
	_arsenal = null



