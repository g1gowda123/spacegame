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
	panel.position = Vector2(4, 4)
	panel.size = Vector2(632, 352)
	panel.pivot_offset = panel.size * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := UIKit.style_panel(Color(0.039, 0.075, 0.078, 0.98), UIKit.STEEL, 0, 1)
	sb.border_color = UIKit.STEEL_HI
	panel.add_theme_stylebox_override("panel", sb)
	_arsenal.add_child(panel)

	var title := UIKit.head("ARSENAL // UPGRADE TREE", 10, UIKit.CREAM)
	title.position = Vector2(14, 10)
	title.size = Vector2(440, 16)
	panel.add_child(title)
	var syns: Array = GameState.active_synergies()
	var sub := UIKit.mono("7 SYSTEMS · 2 PATHS · TIER 2 NEEDS 1 · %d INSTALLED · %d SYNERGY · TAB / ESC CLOSE" % [
		GameState.owned.size(), syns.size()
	], 7, UIKit.MUTED_C)
	sub.position = Vector2(14, 27)
	sub.size = Vector2(570, 12)
	panel.add_child(sub)
	var syn_text := "No cross-system pair active."
	if not syns.is_empty():
		var names: Array[String] = []
		for syn in syns:
			names.append("%s — %s" % [str(syn.get("name", "")), str(syn.get("desc", ""))])
		syn_text = "\n".join(names)
	UIKit.hover_info(sub, "CROSS-SYSTEM SYNERGY", syn_text, UIKit.AMBER)
	UIKit.hairline(panel, 12, 44, 608, Color(0.33, 0.39, 0.46, 0.55))

	_build_arsenal_rows(panel)

	var close := UIKit.button("CLOSE", Vector2(58, 18))
	close.position = Vector2(560, 10)
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
	tree.position = Vector2(12, 48)
	tree.size = Vector2(608, 300)
	tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tree)

	var systems := [
		"PROPULSION", "POWER", "THERMAL", "STRUCTURE",
		"COMMS", "SCIENCE", "SUPPORT",
	]
	for si in range(systems.size()):
		var system := str(systems[si])
		var col := si % 3
		var row := si / 3
		_tree_block(tree, system, float(col) * 204.0, float(row) * 98.0)


func _tree_block(tree: Control, system: String, bx: float, by: float) -> void:
	var sys_color := Color(str(GameState.SYSTEM_COLOR.get(system, "#e8dfc8")))
	var system_owned := false
	for uid in GameState.owned:
		var u := _upgrade(str(uid))
		if str(u.get("branch", "")) == system:
			system_owned = true
	var title := UIKit.mono(system, 6, sys_color if system_owned else UIKit.MUTED_C)
	title.position = Vector2(bx, by)
	title.size = Vector2(110.0, 10.0)
	tree.add_child(title)
	_tree_icon(tree, "res://assets/sprites/modules/branches/%s_A.png" % system.to_lower(),
		Vector2(bx, by + 18.0), Vector2(22.0, 22.0), UIKit.STEEL, false, false,
		false, system, "Two paths: A and B. Tier 2 needs its own tier 1.")
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
	# Shared system bus splits into a left (A) and right (B) lane.
	var a_owned := false
	for up in a:
		if str(up.get("id", "")) in GameState.owned:
			a_owned = true
	var b_owned := false
	for up in b:
		if str(up.get("id", "")) in GameState.owned:
			b_owned = true
	var a_line := UIKit.GREEN if a_owned else Color(0.33, 0.39, 0.46, 0.30)
	var b_line := UIKit.GREEN if b_owned else Color(0.33, 0.39, 0.46, 0.30)
	# Fork from the system root, not a bus through A1. The B lane sits one
	# text-row lower so the two paths visibly split instead of sharing a line.
	var root_c := Vector2(bx + 11.0, by + 29.0)
	_tree_line(tree, root_c, Vector2(bx + 61.0, by + 27.0), a_line)
	_tree_line(tree, root_c, Vector2(bx + 151.0, by + 45.0), b_line)
	_tree_block_lane(tree, a, bx + 50.0, by + 16.0, sys_color, "A")
	_tree_block_lane(tree, b, bx + 140.0, by + 34.0, sys_color, "B")


func _tree_block_lane(tree: Control, parts: Array, x: float, y: float,
		sys_color: Color, path: String) -> void:
	for i in range(parts.size()):
		var up: Dictionary = parts[i]
		var id := str(up.get("id", ""))
		var tier := int(up.get("tier", 1))
		var installed := id in GameState.owned
		var req := str(up.get("requires", ""))
		var locked := req != "" and not (req in GameState.owned)
		var next_up := req != "" and (req in GameState.owned) and not installed
		var ny := y + float(i) * 34.0
		var prev_owned := i > 0 and str(parts[i - 1].get("id", "")) in GameState.owned
		var link := Color(0.33, 0.39, 0.46, 0.30)
		if prev_owned and installed:
			link = UIKit.GREEN
		elif prev_owned and next_up:
			link = UIKit.AMBER
		if i > 0:
			_tree_line(tree, Vector2(x + 11.0, ny - 12.0), Vector2(x + 11.0, ny), link)
		_tree_icon(tree, "res://assets/sprites/modules/%s.png" % id,
			Vector2(x, ny), Vector2(22.0, 22.0), sys_color, installed, locked,
			next_up, str(up.get("name", id)),
			"%s\n\n%s\nCOST $%dM%s" % [
				str(up.get("plain", up.get("desc", ""))),
				"TIER 2 LOCKED · BUY TIER 1 FIRST" if locked else
					("INSTALLED" if installed else
						("NEXT UPGRADE" if next_up else "AVAILABLE IN REFIT")),
				int(up.get("cost", 0.0)),
				("\nREQUIRES " + req) if req != "" else "",
			])
		var short := str(up.get("name", id)).split(" ")[0]
		var role := str(GameState.BRANCH_ROLE.get(str(up.get("branch", "")), {}).get(path, ""))
		var tag_text := "%s%d %s" % [path, tier, role if role != "" else short]
		var tag_color := UIKit.CREAM if installed else (UIKit.AMBER if next_up else UIKit.MUTED_C)
		var tag := UIKit.mono(tag_text, 6, tag_color)
		tag.position = Vector2(x - 6.0, ny + 24.0)
		tag.size = Vector2(56.0, 9.0)
		tree.add_child(tag)


func _tree_icon(parent: Control, path: String, pos: Vector2, size: Vector2,
		border: Color, installed: bool, locked: bool, next_up: bool, title: String,
		body: String) -> void:
	var card := Panel.new()
	card.position = pos
	card.size = size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UIKit.PAPER if installed else Color(0.09, 0.10, 0.11, 0.96)
	var line := UIKit.GREEN if installed else Color(0.33, 0.39, 0.46, 0.60)
	if next_up:
		line = UIKit.AMBER
	elif locked:
		line = Color(border.r, border.g, border.b, 0.22)
	card.add_theme_stylebox_override("panel", UIKit.style_panel(bg, line, 0, 1))
	parent.add_child(card)
	if ResourceLoader.exists(path):
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(path) as Texture2D
		icon.position = Vector2(2, 2)
		icon.size = size - Vector2(4, 4)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate = Color(1, 1, 1,
			1.0 if installed else (0.72 if next_up else (0.34 if locked else 0.45)))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
	UIKit.hover_info(card, title, body, line)


func _tree_line(parent: Control, a: Vector2, b: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([a, b])
	line.width = 1.0
	line.default_color = color
	line.antialiased = true
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



