class_name UIKit
extends RefCounted
## Shared visual language for every screen.
##
## MISSION OPERATIONS // 2026 — a layered console, not a single colour wash.
# Blue-green hulls, cream names, sage only for selection/live state, amber for
# caution. Primary actions are bone/cream; no neon fill.
const VOID := Color("#0a1115")
const HULL := Color("#101b1e")
const HULL_2 := Color("#0c1518")
const HULL_HI := Color("#17282a")
const HULL_EDGE := Color("#263b3c")
const STEEL := Color("#3b4d4d")
const STEEL_HI := Color("#6b7e79")
const CREAM := Color("#e9e3d2")
const NAME := Color("#f7f1df")
const ON_LIGHT := Color("#191a15")
const ON_LIGHT_SOFT := Color("#4c4a40")
const MUTED_C := Color("#a2b0aa")
const DIM_C := Color("#6d7d79")
const SAGE := Color("#7fa98b")
const SAGE_DARK := Color("#557864")
const SAGE_HI := Color("#b5d0b7")
const AMBER := Color("#d6ad68")
const SIGNAL := Color("#cf7a72")
const LIVE := Color("#9ccfbd")

# Legacy names used across the screens.
const NIGHT := VOID
const NIGHT_2 := HULL_2
const NIGHT_PANEL := HULL
const NIGHT_LINE := STEEL
const NIGHT_TEXT := CREAM
const NIGHT_MUTED := MUTED_C
const NIGHT_DIM := DIM_C
const PAPER := HULL
const PAPER_HI := HULL_HI
const PAPER_DEEP := HULL_2
const INK := CREAM
const INK_SOFT := MUTED_C
const INK_FAINT := DIM_C
const BG := VOID
const PANEL := HULL
const PANEL_2 := HULL_2
const PANEL_3 := HULL_HI
const LINE := STEEL
const TEXT := CREAM
const MUTED := MUTED_C
const DIM := DIM_C
const ORANGE := SAGE
const ORANGE_DARK := SAGE_DARK
const ORANGE_HI := SAGE_HI
const CYAN := SAGE
const CYAN_DARK := SAGE_DARK
const CAUTION := AMBER
const RED := SIGNAL
const GREEN := SAGE
const TEAL := Color("#6f9e8a")
const BLUE := Color("#8fb3bf")
const PURPLE := Color("#8e7f9e")
const SHEET := HULL
const SHEET_LINE := STEEL
const ROW_BG := Color(0, 0, 0, 0)
const ROW_HOVER := Color(0.94, 0.88, 0.76, 0.055)
const ROW_SELECTED := Color("#e9e3d2")
const CRT := LIVE
const NIGHT_SHEET := NIGHT_2

static var pixel_font: Font
static var body_font: Font


static func _font(pixel: bool) -> Font:
	if pixel:
		return pixel_font if pixel_font != null else ThemeDB.fallback_font
	return body_font if body_font != null else ThemeDB.fallback_font


static var _skin_cache := {}

static func _skin(name: String) -> StyleBoxTexture:
	if _skin_cache.has(name):
		return _skin_cache[name]
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/skin_dark/%s.png" % name)
	sb.texture_margin_left = 5
	sb.texture_margin_right = 5
	sb.texture_margin_top = 5
	sb.texture_margin_bottom = 5
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_skin_cache[name] = sb
	return sb


static func _paper_skin(name: String, margin: int = 5) -> StyleBoxTexture:
	if _skin_cache.has(name):
		return _skin_cache[name]
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/skin/%s.png" % name)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_skin_cache[name] = sb
	return sb

static func _ops_skin(name: String, margin: int = 4) -> StyleBoxTexture:
	var key := "ops:" + name
	if _skin_cache.has(key):
		return _skin_cache[key]
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/skin_ops/%s.png" % name)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_skin_cache[key] = sb
	return sb


static func sheet(parent: Control, x: float, y: float, w: float, h: float, with_grid: bool = false) -> PanelContainer:
	## A major decision surface: a machined console bay with a 1 px bevel,
	## a faint blueprint grid and a hard drop shadow. No paper, no glow.
	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.55)
	shadow.position = Vector2(x + 3, y + 3)
	shadow.size = Vector2(w, h)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shadow)

	var fill := ColorRect.new()
	fill.color = Color(HULL.r, HULL.g, HULL.b, 0.96)
	fill.position = Vector2(x, y)
	fill.size = Vector2(w, h)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)

	if with_grid:
		var grid := TextureRect.new()
		grid.texture = load("res://assets/ui/skin_ops/grid.png")
		grid.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		grid.stretch_mode = TextureRect.STRETCH_TILE
		grid.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.position = Vector2(x, y)
		grid.size = Vector2(w, h)
		parent.add_child(grid)

	var p := PanelContainer.new()
	var sb := _ops_skin("panel", 7)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.custom_minimum_size = Vector2(w, h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	_corner_ticks(parent, x, y, w, h)
	return p


static func _corner_ticks(parent: Control, x: float, y: float, w: float, h: float) -> void:
	## Four L-shaped agency-orange registration marks; they read as a machined
	## console bezel rather than a generic rounded card.
	var pts := [
		Vector2(x, y), Vector2(x + w - 1, y),
		Vector2(x, y + h - 1), Vector2(x + w - 1, y + h - 1),
	]
	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		var sx := 1.0 if i % 2 == 0 else -1.0
		var sy := 1.0 if i < 2 else -1.0
		var hbar := ColorRect.new()
		hbar.color = Color(0.62, 0.68, 0.64, 0.42)
		hbar.position = Vector2(p.x if sx > 0 else p.x - 7.0, p.y)
		hbar.size = Vector2(8, 1)
		hbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(hbar)
		var vbar := ColorRect.new()
		vbar.color = Color(0.62, 0.68, 0.64, 0.42)
		vbar.position = Vector2(p.x, p.y if sy > 0 else p.y - 7.0)
		vbar.size = Vector2(1, 8)
		vbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(vbar)


static func hover_info(host: Control, title: String, body: String,
	accent: Color = CYAN) -> void:
	## Attach a Balatro-style hover dossier to any control. The control keeps
	## its compact visible label; the dense technical text lives in the card.
	UITip.bind(host, title, body, accent)


static func hairline(parent: Control, x: float, y: float, w: float,
	color: Color = LINE) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.position = Vector2(x, y)
	line.size = Vector2(w, 1)
	line.custom_minimum_size = Vector2(w, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line


static func skin_button(text: String, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font(true))
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_stylebox_override("normal", _ops_skin("button_idle", 4))
	b.add_theme_stylebox_override("hover", _ops_skin("button_hover", 4))
	b.add_theme_stylebox_override("pressed", _ops_skin("button_pressed", 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	b.add_theme_color_override("font_pressed_color", CYAN)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.pressed.connect(func(): if GameState: GameState.sfx("click"))
	return b


static func style_panel(
	bg: Color = PANEL, border: Color = LINE, radius: int = 3, width: int = 1
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(0)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


static func panel(
	bg: Color = PANEL, border: Color = LINE, radius: int = 3
) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style_panel(bg, border, radius))
	return p


static func label(
	text: String, size: int = 9, color: Color = TEXT, pixel: bool = false,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font(pixel))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func head(text: String, size: int = 9, color: Color = TEXT,
	align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	## Silkscreen is chunky; below 8 px it turns to noise. Use it for headings.
	return label(text, maxi(8, size), color, true, align)


static func mono(text: String, size: int = 8, color: Color = MUTED,
	align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	## Body face: readable at small sizes and mixed case survives.
	return label(text, size, color, false, align)


static func rich(text: String, size: int = 9, color: Color = TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = text
	r.add_theme_font_override("normal_font", _font(false))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.scroll_active = false
	r.fit_content = true
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(
	text: String, min_size: Vector2 = Vector2.ZERO, accent: bool = false,
	pixel: bool = true
) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", _font(pixel))
	b.add_theme_font_size_override("font_size", 10 if pixel else 9)
	if not accent:
		b.add_theme_stylebox_override("normal", _ops_skin("tab_idle", 4))
		b.add_theme_stylebox_override("hover", _ops_skin("tab_hover", 4))
		b.add_theme_stylebox_override("pressed", _ops_skin("tab_pressed", 4))
		b.add_theme_stylebox_override("disabled", style_panel(HULL_2, STEEL, 0, 1))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", CREAM)
		b.add_theme_color_override("font_hover_color", CREAM)
		b.add_theme_color_override("font_pressed_color", ORANGE)
		b.add_theme_color_override("font_disabled_color", DIM)
	else:
		# Primary action: an orange machined key with dark ink and a hard shadow.
		var base := _ops_skin("button_primary", 4)
		var hover := _ops_skin("button_primary_hover", 4)
		var press := _ops_skin("button_primary_pressed", 4)
		var disabled := style_panel(HULL_2, STEEL, 0, 1)
		b.add_theme_stylebox_override("normal", base)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", press)
		b.add_theme_stylebox_override("disabled", disabled)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", Color("#0b160f"))
		b.add_theme_color_override("font_hover_color", Color("#0b160f"))
		b.add_theme_color_override("font_pressed_color", Color("#0b160f"))
		b.add_theme_color_override("font_disabled_color", DIM)

	b.pressed.connect(func():
		if GameState:
			GameState.sfx("click")
		if not b.disabled:
			var ptw: Tween = b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ptw.tween_property(b, "scale", Vector2(1.055 if accent else 1.045, 1.055 if accent else 1.045), 0.08)
			ptw.tween_property(b, "scale", Vector2(1.045 if accent else 1.035, 1.045 if accent else 1.035), 0.10)
	)
	attach_hover_pop(b, 1.045 if accent else 1.035, 2.0)
	return b


static func attach_hover_pop(
	ctrl: Control, scale_mult: float = 1.035, lift_y: float = 2.0
) -> void:
	ctrl.mouse_entered.connect(func():
		if ctrl is Button and ctrl.disabled:
			return
		ctrl.z_index = 2
		if ctrl.size.x > 0 and ctrl.size.y > 0:
			ctrl.pivot_offset = ctrl.size * 0.5
		var old: Tween = ctrl.get_meta("pop_tw", null)
		if old != null and old.is_valid():
			old.kill()
		if not ctrl.has_meta("base_y") or ctrl.scale == Vector2.ONE:
			ctrl.set_meta("base_y", ctrl.position.y)
		var base_y: float = float(ctrl.get_meta("base_y"))
		var tw: Tween = ctrl.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ctrl, "scale", Vector2(scale_mult, scale_mult), 0.14)
		if ctrl.get_parent() != null and ctrl.get_parent() is not Container:
			tw.tween_property(ctrl, "position:y", base_y - lift_y, 0.14)
		ctrl.set_meta("pop_tw", tw)
	)
	ctrl.mouse_exited.connect(func():
		ctrl.z_index = 0
		var old: Tween = ctrl.get_meta("pop_tw", null)
		if old != null and old.is_valid():
			old.kill()
		var base_y: float = float(ctrl.get_meta("base_y", ctrl.position.y))
		var tw: Tween = ctrl.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ctrl, "scale", Vector2.ONE, 0.14)
		if ctrl.get_parent() != null and ctrl.get_parent() is not Container:
			tw.tween_property(ctrl, "position:y", base_y, 0.14)
		ctrl.set_meta("pop_tw", tw)
	)


static func bar(width: float, height: float, color: Color) -> UIGauge:
	return UIGauge.new(width, height, color)


static func set_bar(pb, value: float, maximum: float) -> void:
	if pb == null:
		return
	if pb is UIGauge:
		pb.set_value(value, maximum)
		return
	if pb is ProgressBar:
		pb.max_value = max(1.0, maximum)
		pb.value = clamp(value, 0.0, pb.max_value)


static func set_bar_color(pb, color: Color) -> void:
	if pb is UIGauge:
		pb.set_fill(color)
	elif pb is ProgressBar:
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(1)
		pb.add_theme_stylebox_override("fill", fill)


static func chip(text: String, color: Color, pixel: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var st := style_panel(HULL_HI, color, 0, 1)
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", st)
	var l := label(text, 7, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func rule(color: Color = LINE) -> HSeparator:
	var s := HSeparator.new()
	var st := StyleBoxLine.new()
	st.color = color
	st.thickness = 1
	s.add_theme_stylebox_override("separator", st)
	return s


static func vspace(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hspace(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func fill(parent: Control) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


static func card(parent: Control, x: float, y: float, w: float, h: float,
	bg: Color = PANEL, border: Color = LINE) -> PanelContainer:
	var p := panel(bg, border)
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.custom_minimum_size = Vector2(w, h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	_corner_ticks(parent, x, y, w, h)
	return p


static func stat_color(v: float, good_high: bool = true) -> Color:
	if good_high:
		return GREEN if v >= 0.66 else (AMBER if v >= 0.33 else RED)
	return GREEN if v <= 0.33 else (AMBER if v <= 0.66 else RED)


static func row_style(selected: bool, hovered: bool = false,
	accent: Color = CYAN) -> StyleBoxFlat:
	## Flat list row. Selected rows get a 3-4 px left marker.
	## Hovered rows lift with an accent border and highlight wash.
	var s := StyleBoxFlat.new()
	if selected:
		s.bg_color = ROW_SELECTED.lightened(0.04) if hovered else ROW_SELECTED
		s.border_color = accent.lightened(0.2) if hovered else accent
		s.border_width_left = 4 if hovered else 3
		s.border_width_bottom = 1
		s.border_width_top = 1 if hovered else 0
		s.border_width_right = 1 if hovered else 0
	else:
		s.bg_color = Color(0.20, 0.40, 0.46, 0.22) if hovered else ROW_BG
		s.border_color = accent.lightened(0.15) if hovered else SHEET_LINE
		s.border_width_left = 3 if hovered else 0
		s.border_width_bottom = 1
		s.border_width_top = 1 if hovered else 0
		s.border_width_right = 1 if hovered else 0
	s.set_corner_radius_all(0)
	s.content_margin_left = 8
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


static func option_card(
	parent: Control, rect: Rect2, title: String, subtitle: String,
	accent: Color = CYAN, title_size: int = 8, sub_size: int = 7,
	meta: String = "", pixel_title: bool = true
) -> Dictionary:
	var root := Control.new()
	root.position = rect.position
	root.size = rect.size
	root.custom_minimum_size = rect.size
	root.clip_contents = false
	parent.add_child(root)

	var p := Panel.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.pivot_offset = Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	p.add_theme_stylebox_override("panel", row_style(false, false, accent))
	root.add_child(p)

	# Absolute children, not a VBox: rows must keep the exact height the screen
	# asked for or a long perk wraps and the column overflows its sheet.
	var t := label(title, maxi(8, title_size), NAME, pixel_title)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p.add_child(t)
	t.position = Vector2(8, 2 if subtitle != "" else maxf(2.0, (rect.size.y - 13.0) * 0.5))
	t.size = Vector2(rect.size.x - (78.0 if meta != "" else 14.0), 13)
	var m: Label = null
	if meta != "":
		m = label(meta, 7, DIM, false, HORIZONTAL_ALIGNMENT_RIGHT)
		m.clip_text = true
		p.add_child(m)
		m.position = Vector2(rect.size.x - 70.0, 3)
		m.size = Vector2(62, 10)
	var s: Label = null
	if subtitle != "":
		s = label(subtitle, sub_size, MUTED, false)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		s.clip_text = true
		p.add_child(s)
		s.position = Vector2(8, 15)
		s.size = Vector2(rect.size.x - 14.0, maxf(2.0, rect.size.y - 17.0))

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, empty)
	root.add_child(btn)

	var card := {
		"root": root, "panel": p, "title": t, "sub": s, "meta": m, "button": btn,
		"accent": accent, "selected": false, "enabled": true, "hovered": false,
		"base_rect": rect, "tw": null,
	}
	btn.mouse_entered.connect(func():
		if card.get("enabled", true):
			_hover_option_card(card, true)
	)
	btn.mouse_exited.connect(func():
		_hover_option_card(card, false)
	)
	return card


static func _hover_option_card(card: Dictionary, on: bool) -> void:
	if card.is_empty():
		return
	card["hovered"] = on
	var root: Control = card["root"]
	var p: Panel = card["panel"]
	var selected: bool = bool(card.get("selected", false))
	var accent: Color = card.get("accent", CYAN)

	root.z_index = 3 if on else (1 if selected else 0)
	p.add_theme_stylebox_override("panel", row_style(selected, on, accent))

	var title: Label = card.get("title")
	if title != null:
		if selected:
			title.add_theme_color_override("font_color", ON_LIGHT)
		else:
			title.add_theme_color_override("font_color", Color("#ffffff") if on else NAME)
	var sub: Label = card.get("sub")
	if sub != null and not selected:
		sub.add_theme_color_override("font_color", CREAM if on else MUTED)
	var meta: Label = card.get("meta")
	if meta != null and not selected:
		meta.add_theme_color_override("font_color", CREAM if on else DIM)

	var target_scale := 1.045 if on and selected else (1.035 if on else (1.015 if selected else 1.0))
	var target_pos := Vector2(1.5, -1.5) if on else (Vector2(1.0, 0.0) if selected else Vector2.ZERO)

	var old: Tween = card.get("tw")
	if old != null and old.is_valid():
		old.kill()

	var tw: Tween = p.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "scale", Vector2(target_scale, target_scale), 0.14)
	tw.tween_property(p, "position", target_pos, 0.14)
	card["tw"] = tw


static func select_card(card: Dictionary, on: bool) -> void:
	if card.is_empty():
		return
	var was_selected := bool(card.get("selected", false))
	card["selected"] = on
	var hovered: bool = bool(card.get("hovered", false))
	var accent: Color = card["accent"]
	var root: Control = card["root"]
	var p: Control = card["panel"]
	var title: Label = card["title"]

	root.z_index = 3 if hovered else (1 if on else 0)
	p.add_theme_stylebox_override("panel", row_style(on, hovered, accent))

	if on:
		title.add_theme_color_override("font_color", ON_LIGHT)
	else:
		title.add_theme_color_override("font_color", Color("#ffffff") if hovered else NAME)
	var sub: Label = card.get("sub")
	if sub != null:
		sub.add_theme_color_override("font_color", ON_LIGHT_SOFT if on else (CREAM if hovered else MUTED))
	var meta: Label = card.get("meta")
	if meta != null:
		meta.add_theme_color_override("font_color", ON_LIGHT_SOFT if on else (CREAM if hovered else DIM))

	if on != was_selected:
		var old: Tween = card.get("tw")
		if old != null and old.is_valid():
			old.kill()

		if on:
			p.scale = Vector2(1.055, 1.055)
			p.position = Vector2(2.0, -2.0)
			var target_scale := 1.045 if hovered else 1.015
			var target_pos := Vector2(1.5, -1.5) if hovered else Vector2(1.0, 0.0)
			var tw: Tween = p.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "scale", Vector2(target_scale, target_scale), 0.18)
			tw.tween_property(p, "position", target_pos, 0.18)
			card["tw"] = tw
		else:
			var target_scale := 1.035 if hovered else 1.0
			var target_pos := Vector2(1.5, -1.5) if hovered else Vector2.ZERO
			var tw: Tween = p.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "scale", Vector2(target_scale, target_scale), 0.14)
			tw.tween_property(p, "position", target_pos, 0.14)
			card["tw"] = tw

