class_name UIKit
extends RefCounted
## Shared visual language for every screen.
##
## Navy console grammar: one textured sheet per decision area, flat rows inside
## it, a hairline rule between regions, and an accent that only marks the
## current choice. Cyan is an accent, not the default border.

const BG := Color("#070a11")
const PANEL := Color("#0e1624")
const PANEL_2 := Color("#131f31")
const PANEL_3 := Color("#1a2940")
const LINE := Color("#27384f")
const TEXT := Color("#e8eff7")
const MUTED := Color("#8ba0b6")
const DIM := Color("#5d7186")
const CYAN := Color("#54e6d1")
const CYAN_DARK := Color("#1f7f78")
const AMBER := Color("#ffc45c")
const RED := Color("#ff5d6c")
const GREEN := Color("#7fe08a")
const PURPLE := Color("#b692ff")
const BLUE := Color("#7cc8ff")

# Surface tokens (flatter than the old panel-on-panel stack).
const SHEET := Color("#0b1522")
const SHEET_LINE := Color("#22364c")
const ROW_BG := Color("#0b1725")
const ROW_HOVER := Color("#102030")
const ROW_SELECTED := Color("#0d2630")

# Aliases used by the briefing/title cards; keep them on the original palette.
const PAPER := PANEL
const INK := TEXT
const ORANGE := CYAN
const SIGNAL := RED
const NIGHT := BG
const BOARD := PANEL
const RAIL := LINE
const STRIP := PANEL_2
const STRIP_DIM := PANEL
const CRT := GREEN

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


static func sheet(parent: Control, x: float, y: float, w: float, h: float) -> PanelContainer:
	## A major decision surface: dark navy 9-slice, no nested card borders.
	var p := PanelContainer.new()
	var sb := _skin("panel")
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.custom_minimum_size = Vector2(w, h)
	parent.add_child(p)
	return p


static func hairline(parent: Control, x: float, y: float, w: float,
	color: Color = LINE) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.position = Vector2(x, y)
	line.size = Vector2(w, 1)
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
	# Accent button: dark ink fill with a cyan edge. High contrast, not a slab
	# of saturated colour.
	var base := style_panel(Color("#0e3336"), CYAN_DARK, 2)
	base.content_margin_left = 6
	base.content_margin_right = 6
	var hover := style_panel(Color("#124a4d"), CYAN, 2)
	var press := style_panel(Color("#123f42"), CYAN, 2)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color("#d9fbf5"))
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	b.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	b.add_theme_color_override("font_disabled_color", DIM)
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
	var st := style_panel(Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.7),
		Color(color.r, color.g, color.b, 0.32), 2)
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
		s.border_width_left = 2
	else:
		s.bg_color = ROW_HOVER if hovered else ROW_BG
		s.border_color = LINE
		s.border_width_left = 1 if hovered else 0
	s.set_corner_radius_all(2)
	s.content_margin_left = 8
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


static func option_card(
	parent: Control, rect: Rect2, title: String, subtitle: String,
	accent: Color = CYAN, title_size: int = 8, sub_size: int = 7
) -> Dictionary:
	var root := Control.new()
	root.position = rect.position
	root.size = rect.size
	root.custom_minimum_size = rect.size
	parent.add_child(root)

	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_theme_stylebox_override("panel", row_style(false, false, accent))
	root.add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)

	var t := label(title, maxi(8, title_size), TEXT, true)
	t.clip_text = true
	v.add_child(t)
	var s: Label = null
	if subtitle != "":
		s = label(subtitle, sub_size, MUTED, false)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(max(10.0, rect.size.x - 20.0), 0)
		s.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		s.clip_text = rect.size.y < 34.0
		v.add_child(s)

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
	var p: PanelContainer = card["panel"]
	var title: Label = card["title"]
	if on:
		p.add_theme_stylebox_override("panel", row_style(true, false, accent))
		title.add_theme_color_override("font_color", CYAN)
	else:
		p.add_theme_stylebox_override("panel", row_style(false, false, accent))
		title.add_theme_color_override("font_color", TEXT)
