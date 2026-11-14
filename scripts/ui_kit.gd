class_name UIKit
extends RefCounted
## Shared visual language for every screen.
##
## FLIGHT BINDER // 1975: cream paper dossiers, hard ink rules, agency orange
## for the current action, and a dark night console reserved for the map/HUD.

# FLIGHT BINDER // 1975 — paper, ink, agency orange, night telemetry.
# The map and sector HUD stay night; menu surfaces are paper dossiers.
const PAPER := Color("#e8dfc8")
const PAPER_HI := Color("#f4ecd9")
const PAPER_DEEP := Color("#d8c9ab")
const INK := Color("#1b1a17")
const INK_SOFT := Color("#4a4438")
const INK_FAINT := Color("#75674f")
const NIGHT := Color("#101826")
const NIGHT_2 := Color("#0b1220")
const NIGHT_PANEL := Color("#0e1624")
const NIGHT_LINE := Color("#354253")
const NIGHT_TEXT := Color("#f2ead6")
const NIGHT_MUTED := Color("#bfb39c")
const NIGHT_DIM := Color("#817968")
const ORANGE := Color("#e4572e")
const ORANGE_DARK := Color("#a83a1e")
const SIGNAL := Color("#b8332f")
const TEAL := Color("#5f8f8a")
const LIVE := Color("#54e6d1")
const CAUTION := Color("#ffc45c")

# Legacy names used across the screens. They now resolve to the binder palette
# so the whole UI shifts together; night-specific surfaces use NIGHT_* above.
const BG := NIGHT
const PANEL := PAPER
const PANEL_2 := PAPER_DEEP
const PANEL_3 := Color("#cbb994")
const LINE := Color("#a99779")
const TEXT := INK
const MUTED := INK_SOFT
const DIM := INK_FAINT
const CYAN := ORANGE
const CYAN_DARK := ORANGE_DARK
const AMBER := CAUTION
const RED := SIGNAL
const GREEN := TEAL
const PURPLE := Color("#6f5a8a")
const BLUE := TEAL
const SHEET := PAPER
const SHEET_LINE := Color("#8e7a5c")
const ROW_BG := Color(0, 0, 0, 0)
const ROW_HOVER := Color(1, 1, 1, 0.18)
const ROW_SELECTED := Color("#f2d9b8")
const CRT := TEAL
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


static func sheet(parent: Control, x: float, y: float, w: float, h: float) -> PanelContainer:
	## A major decision surface: a hard-edged paper dossier with a 2 px ink
	## shadow. No rounded panel glow; the paper and rule do the hierarchy.
	var shadow := ColorRect.new()
	shadow.color = Color(0.06, 0.05, 0.04, 0.42)
	shadow.position = Vector2(x + 3, y + 3)
	shadow.size = Vector2(w, h)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shadow)

	var paper := TextureRect.new()
	paper.texture = load("res://assets/ui/skin/paper_texture.png")
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_TILE
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.position = Vector2(x, y)
	paper.size = Vector2(w, h)
	parent.add_child(paper)

	var p := PanelContainer.new()
	var sb := style_panel(Color(0, 0, 0, 0), INK, 0, 1)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.custom_minimum_size = Vector2(w, h)
	parent.add_child(p)
	return p


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
	b.add_theme_stylebox_override("normal", _skin("button_idle"))
	b.add_theme_stylebox_override("hover", _skin("button_hover"))
	b.add_theme_stylebox_override("pressed", _skin("button_pressed"))
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
	s.set_corner_radius_all(radius)
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
	b.add_theme_font_override("font", _font(pixel))
	b.add_theme_font_size_override("font_size", 10 if pixel else 9)
	if not accent:
		b.add_theme_stylebox_override("normal", _paper_skin("tab_idle", 5))
		b.add_theme_stylebox_override("hover", _paper_skin("tab_hover", 5))
		b.add_theme_stylebox_override("pressed", _paper_skin("tab_pressed", 5))
		b.add_theme_stylebox_override("disabled", style_panel(PAPER_DEEP, Color("#8e7a5c"), 0, 1))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
		b.add_theme_color_override("font_disabled_color", INK_FAINT)
		b.pressed.connect(func(): if GameState: GameState.sfx("click"))
		return b
	# Primary action: agency-orange paper with an ink edge and a hard shadow.
	var base := style_panel(ORANGE, INK, 0, 1)
	base.content_margin_left = 6
	base.content_margin_right = 6
	base.shadow_color = Color(0.06, 0.05, 0.04, 0.55)
	base.shadow_size = 2
	base.shadow_offset = Vector2(2, 2)
	var hover := style_panel(Color("#f06a3e"), INK, 0, 1)
	var press := style_panel(ORANGE_DARK, INK, 0, 1)
	var disabled := style_panel(PAPER_DEEP, Color("#8e7a5c"), 0, 1)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_disabled_color", INK_FAINT)
	b.pressed.connect(func(): if GameState: GameState.sfx("click"))
	return b


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
	var st := style_panel(PAPER_HI, color, 0, 1)
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
	parent.add_child(p)
	return p


static func stat_color(v: float, good_high: bool = true) -> Color:
	if good_high:
		return GREEN if v >= 0.66 else (AMBER if v >= 0.33 else RED)
	return GREEN if v <= 0.33 else (AMBER if v <= 0.66 else RED)


static func row_style(selected: bool, hovered: bool = false,
	accent: Color = CYAN) -> StyleBoxFlat:
	## Flat list row. Selected rows get a 2 px left marker instead of a full
	## coloured outline, so a column of options stays quiet.
	var s := StyleBoxFlat.new()
	if selected:
		s.bg_color = ROW_SELECTED
		s.border_color = accent
		s.border_width_left = 3
		s.border_width_bottom = 1
	else:
		s.bg_color = ROW_HOVER if hovered else ROW_BG
		s.border_color = SHEET_LINE
		s.border_width_bottom = 1
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
	parent.add_child(root)

	var p := Panel.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", row_style(false, false, accent))
	root.add_child(p)
	root.clip_contents = true

	# Absolute children, not a VBox: rows must keep the exact height the screen
	# asked for or a long perk wraps and the column overflows its sheet.
	var t := label(title, maxi(8, title_size), TEXT, pixel_title)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p.add_child(t)
	t.position = Vector2(8, 2 if subtitle != "" else maxf(2.0, (rect.size.y - 13.0) * 0.5))
	t.size = Vector2(rect.size.x - (78.0 if meta != "" else 14.0), 13)
	if meta != "":
		var m := label(meta, 7, DIM, false, HORIZONTAL_ALIGNMENT_RIGHT)
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
		"root": root, "panel": p, "title": t, "sub": s, "button": btn,
		"accent": accent, "selected": false, "enabled": true,
		"base_rect": rect,
	}
	btn.mouse_entered.connect(func():
		if card["enabled"] and not card["selected"]:
			p.add_theme_stylebox_override("panel", row_style(false, true, accent))
	)
	btn.mouse_exited.connect(func():
		if card["enabled"] and not card["selected"]:
			p.add_theme_stylebox_override("panel", row_style(false, false, accent))
	)
	return card


static func select_card(card: Dictionary, on: bool) -> void:
	if card.is_empty():
		return
	card["selected"] = on
	var accent: Color = card["accent"]
	var p: Control = card["panel"]
	var title: Label = card["title"]
	if on:
		p.add_theme_stylebox_override("panel", row_style(true, false, accent))
		title.add_theme_color_override("font_color", INK)
	else:
		p.add_theme_stylebox_override("panel", row_style(false, false, accent))
		title.add_theme_color_override("font_color", TEXT)
