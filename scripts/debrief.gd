extends Control
const SHIP_BUILD := preload("res://scripts/ship_build.gd")
## Between-sector debrief and field refit shop.

var r: Dictionary = {}
var shop_root: Control
var toast: Label
var funds_label: Label
var owned_label: Label
var footer_title: Label
var footer_sub: Label
var next_btn: Button
var event_layer: CanvasLayer
var ship_diagram: ShipDiagram
var build_label: Label
var build_line: Label

var _toast_tween: Tween


func _ready() -> void:
	if GameState.last_result.is_empty():
		# Safe fallback when opened directly from the editor.
		GameState.new_run()
		GameState.quick_loadout()
		GameState.commit_design()
		GameState.begin_sector(GameState.draft[0])
		GameState.finish_sector(true, 3, GameState.current_sector)
	r = GameState.last_result
	if GameState.shop_offers.is_empty():
		GameState.make_shop()
	var cli: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--skip-event" in cli:
		GameState.run["event_resolved"] = true
		GameState.run["event_card"] = {}
		GameState.event_card = {}
	_build()
	if "--next" in cli:
		call_deferred("_on_next", false)
	if "--event" in OS.get_cmdline_args() or "--event" in OS.get_cmdline_user_args():
		call_deferred("_show_event")
	for raw in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if str(raw) == "--capture-event":
			_capture_event()
			break
		if str(raw).begins_with("--buy="):
			call_deferred("_dev_buy", int(str(raw).substr(6)))


func _dev_buy(idx: int) -> void:
	if idx < 0 or idx >= GameState.shop_offers.size():
		return
	var name := str(GameState.shop_offers[idx].get("name", "?"))
	_on_buy(idx)
	print("DEVBUY ", name, " owned=", GameState.owned.size())


func _capture_event() -> void:
	await get_tree().process_frame
	_show_event()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var err := img.save_png("user://event_capture.png")
		print("EVENTCAP ", ProjectSettings.globalize_path("user://event_capture.png"), " err=", err)
	for raw in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if str(raw).begins_with("--event-choice="):
			var ok := GameState.choose_event(int(str(raw).substr(14)))
			print("EVENTCHOICE ok=", ok, " resolved=", bool(GameState.run.get("event_resolved", false)), " budget=", int(GameState.run.get("budget", 0)))
	get_tree().quit()


func _build() -> void:
	var bg := SpaceBackdrop.new()
	add_child(bg)
	var planet: Dictionary = r.get("planet", {})
	bg.configure({
		"planet_center": Vector2(0.90, 0.68),
		"planet_size": 0.56,
		"planet_asset": SpaceBackdrop.asset_for_planet(planet),
		"dim": 0.22,
	})
	bg.modulate.a = 0.22

	var title := UIKit.label("SECTOR DEBRIEF  //  %02d" % int(r.get("sector", 1)), 14, UIKit.CYAN, true)
	title.position = Vector2(10, 8)
	title.size = Vector2(340, 18)
	add_child(title)
	var sub := UIKit.label(
		"%s  ·  %s  ·  SURFACE OPERATIONS REPORT" % [
			str(planet.get("name", "—")).to_upper(),
			GameState.biome_name(str(planet.get("biome", "barren"))).to_upper()
		], 7, UIKit.MUTED, true)
	sub.position = Vector2(10, 26)
	sub.size = Vector2(430, 12)
	add_child(sub)

	funds_label = UIKit.label("FUNDS $0M", 9, UIKit.AMBER, true, HORIZONTAL_ALIGNMENT_RIGHT)
	funds_label.position = Vector2(470, 8)
	funds_label.size = Vector2(160, 12)
	add_child(funds_label)
	var approval_now := int(GameState.run.get("approval", 0))
	var appr_color := UIKit.RED if approval_now <= 20 else (UIKit.AMBER if approval_now <= 40 else UIKit.MUTED)
	var appr := UIKit.label("APPROVAL %d" % approval_now, 7, appr_color, true, HORIZONTAL_ALIGNMENT_RIGHT)
	appr.position = Vector2(470, 22)
	appr.size = Vector2(160, 12)
	add_child(appr)

	_build_summary()
	_build_shop()
	_build_footer()


func _build_summary() -> void:
	var p := UIKit.panel(Color(0.04, 0.07, 0.11, 0.94), Color("#2b4058"))
	p.position = Vector2(10, 42)
	p.size = Vector2(306, 252)
	add_child(p)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)

	var success := bool(r.get("success", false))
	var relay := str(r.get("mode", "survey")) == "relay"
	var stamp := UIKit.label("MISSION SUCCESS" if success else "MISSION FAILED", 16,
		UIKit.CYAN if success else UIKit.RED, true)
	stamp.position = Vector2(10, 8)
	stamp.size = Vector2(286, 22)
	c.add_child(stamp)
	var reason := UIKit.label(
		("RELAY CHAIN ONLINE" if relay else "ALL QUOTAS MET") if success else "AGENCY REVIEW FLAGGED", 7,
		UIKit.GREEN if success else UIKit.RED, true)
	reason.position = Vector2(10, 30)
	reason.size = Vector2(286, 12)
	c.add_child(reason)

	var rows := [
		["BEACONS PLACED" if relay else "DATA DELIVERED", "%d / %d %s" % [
			int(r.get("delivered", 0)), int(r.get("quota", 3)), "RELAYS" if relay else "NODES"
		], UIKit.AMBER if relay else UIKit.GREEN],
		["SCIENCE VALUE", "+%d PTS" % int(r.get("science", 0)), UIKit.PURPLE],
		["GRANT AWARDED", "+$%dM" % int(r.get("grant", 0)), UIKit.AMBER],
		["APPROVAL CHANGE", "%+d" % int(r.get("approval_delta", 0)), UIKit.GREEN if success else UIKit.RED],
		["HULL INTEGRITY", "%d / %d" % [int(r.get("integrity_left", 0)), int(GameState.ship().get("integrity", 4))], UIKit.TEXT],
		["DELTA-V LEFT", "%d" % int(r.get("delta_v_left", 0)), UIKit.CYAN],
		["COMMS LOSS", "-%d%% DATA" % int(r.get("comms_loss", 0)), UIKit.MUTED],
	]
	var y := 46.0
	for row in rows:
		c.add_child(_row(10, y, row[0], row[1], row[2]))
		y += 14.0

	c.add_child(_hr(10, 140, 286))
	var build_head := UIKit.label("SHIP BUILD  //  LIVE REFIT", 6, UIKit.CYAN, true)
	build_head.position = Vector2(10, 142)
	build_head.size = Vector2(286, 10)
	c.add_child(build_head)
	build_label = UIKit.label("", 6, UIKit.DIM, true, HORIZONTAL_ALIGNMENT_RIGHT)
	build_label.position = Vector2(140, 142)
	build_label.size = Vector2(156, 10)
	c.add_child(build_label)
	ship_diagram = ShipDiagram.new()
	ship_diagram.position = Vector2(58, 152)
	ship_diagram.size = Vector2(190, 70)
	c.add_child(ship_diagram)
	build_line = UIKit.label("", 6, UIKit.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	build_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_line.position = Vector2(10, 223)
	build_line.size = Vector2(286, 18)
	c.add_child(build_line)
	_refresh_ship()


func _build_shop() -> void:
	var p := UIKit.panel(Color(0.04, 0.07, 0.11, 0.94), Color("#2b4058"))
	p.position = Vector2(326, 42)
	p.size = Vector2(304, 252)
	add_child(p)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)
	var head := UIKit.label("FIELD REFIT  //  AGENCY STORE", 9, UIKit.AMBER, true)
	head.position = Vector2(10, 7)
	head.size = Vector2(220, 12)
	c.add_child(head)
	owned_label = UIKit.label("", 6, UIKit.DIM, true, HORIZONTAL_ALIGNMENT_RIGHT)
	owned_label.position = Vector2(150, 8)
	owned_label.size = Vector2(134, 10)
	c.add_child(owned_label)

	shop_root = Control.new()
	shop_root.position = Vector2(8, 24)
	shop_root.size = Vector2(288, 220)
	shop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(shop_root)
	_refresh_shop()


func _refresh_shop() -> void:
	if shop_root == null:
		return
	for child in shop_root.get_children():
		child.queue_free()
	owned_label.text = "%d INSTALLED" % GameState.owned.size()
	funds_label.text = "FUNDS $%dM" % int(GameState.run.get("budget", 0))
	if GameState.shop_offers.is_empty():
		var empty := UIKit.label("STORE EMPTY  ·  FLY THE NEXT SECTOR", 8, UIKit.DIM, true,
			HORIZONTAL_ALIGNMENT_CENTER)
		empty.position = Vector2(0, 80)
		empty.size = Vector2(288, 16)
		shop_root.add_child(empty)
		return
	for i in range(GameState.shop_offers.size()):
		var up: Dictionary = GameState.shop_offers[i]
		shop_root.add_child(_offer_card(up, i, i * 72.0))


func _offer_card(up: Dictionary, idx: int, y: float) -> Control:
	var cost := float(up["cost"])
	var afford := float(GameState.run.get("budget", 0)) >= cost
	var card := Control.new()
	card.position = Vector2(0, y)
	card.size = Vector2(288, 68)
	var bg := UIKit.panel(Color("#0c1726"), Color("#263d55"))
	bg.position = Vector2.ZERO
	bg.size = card.size
	card.add_child(bg)

	# Every offer gets a physical module portrait, so the shop reads as a
	# catalogue of hardware rather than three identical text rows.
	var icon_frame := Panel.new()
	icon_frame.position = Vector2(6, 10)
	icon_frame.size = Vector2(44, 44)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", UIKit.style_panel(
		Color("#08111c"), Color("#1d344a"), 2
	))
	card.add_child(icon_frame)
	var icon_path := "res://assets/sprites/buffs/%s.png" % str(up.get("icon", "cache"))
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path) as Texture2D
		icon.position = Vector2(3, 3)
		icon.size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(icon)

	var nm := UIKit.label(str(up["name"]), 8, UIKit.TEXT, true)
	nm.position = Vector2(56, 5)
	nm.size = Vector2(154, 11)
	card.add_child(nm)
	var kind_text := "HARDWARE" if str(up["kind"]) == "MODULE" else "SOFTWARE"
	var kind := UIKit.label(kind_text, 5, UIKit.CYAN, true, HORIZONTAL_ALIGNMENT_RIGHT)
	kind.position = Vector2(212, 6)
	kind.size = Vector2(68, 9)
	card.add_child(kind)
	var desc := UIKit.label(str(up.get("plain", up["desc"])), 6, UIKit.MUTED, false)
	desc.position = Vector2(56, 18)
	card.add_child(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size = Vector2(158, 30)
	var pr := UIKit.label("$%dM" % int(cost), 8, UIKit.AMBER if afford else UIKit.RED, true)
	pr.position = Vector2(56, 50)
	pr.size = Vector2(70, 11)
	card.add_child(pr)

	var buy := UIKit.button("BUY", Vector2(58, 20), afford)
	buy.position = Vector2(220, 44)
	buy.disabled = not afford
	buy.pressed.connect(_on_buy.bind(idx))
	card.add_child(buy)
	return card


func _on_buy(idx: int) -> void:
	if idx < 0 or idx >= GameState.shop_offers.size():
		return
	var up: Dictionary = GameState.shop_offers[idx]
	if GameState.buy_offer(idx):
		_show_toast("INSTALLED  %s  ·  SHIP UPDATED" % str(up["name"]), UIKit.GREEN)
		_refresh_shop()
		_refresh_ship()
		if ship_diagram != null:
			ship_diagram.flash_build()
	else:
		_show_toast("INSUFFICIENT GRANTS", UIKit.RED)


func _refresh_ship() -> void:
	if ship_diagram == null:
		return
	ship_diagram.set_build(
		str(GameState.run.get("hull", "")),
		GameState.run.get("instruments", []),
		GameState.owned
	)
	var tier: Dictionary = ship_diagram.tier()
	build_label.text = "%s  ·  %d MOD  ·  %d BUFF" % [
		str(tier["name"]), ship_diagram.module_count(), GameState.run.get("buffs", []).size()
	]
	build_label.add_theme_color_override("font_color", tier["color"])
	build_line.text = ship_diagram.module_line()
	build_line.add_theme_color_override("font_color", tier["color"])


func _build_footer() -> void:
	var p := UIKit.panel(Color(0.04, 0.07, 0.11, 0.94), Color("#2b4058"))
	p.position = Vector2(10, 304)
	p.size = Vector2(620, 46)
	add_child(p)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)

	var final := int(r.get("sector", 1)) >= GameState.SECTORS_PER_RUN or bool(r.get("run_over", false))
	var event_pending := not bool(GameState.run.get("event_resolved", true)) \
			and not ((GameState.run.get("event_card", {}) as Dictionary).is_empty())
	var buff_pending := GameState.has_pending_buff()
	var next_title := "FINAL REPORT READY" if final else "NEXT: EXOPLANET TARGET DRAFT"
	var next_sub := "Agency ledger and final grade." if final else "Three new targets. Choose where the grants go."
	var next_button := "FILE FINAL REPORT >" if final else "SELECT NEXT TARGET >"
	if not final and event_pending:
		next_title = "NEXT: MISSION EVENT"
		next_sub = "An agency incident needs a call before the next target."
		next_button = "HANDLE EVENT >"
	elif not final and buff_pending:
		next_title = "NEXT: FIELD COMMISSION"
		next_sub = "Choose one free upgrade before the next target."
		next_button = "CLAIM COMMISSION >"
	footer_title = UIKit.label(next_title, 10,
		UIKit.CYAN if final else UIKit.AMBER, true)
	footer_title.position = Vector2(12, 6)
	footer_title.size = Vector2(340, 14)
	c.add_child(footer_title)
	footer_sub = UIKit.label(next_sub, 7, UIKit.MUTED, false)
	footer_sub.position = Vector2(12, 22)
	footer_sub.size = Vector2(360, 14)
	c.add_child(footer_sub)

	next_btn = UIKit.button(next_button, Vector2(206, 28), true)
	next_btn.position = Vector2(398, 9)
	next_btn.pressed.connect(_on_next.bind(final))
	c.add_child(next_btn)

	toast = UIKit.label("", 8, UIKit.GREEN, true, HORIZONTAL_ALIGNMENT_CENTER)
	toast.position = Vector2(326, 294)
	toast.size = Vector2(304, 12)
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast.add_theme_constant_override("outline_size", 3)
	toast.modulate.a = 0.0
	add_child(toast)


func _on_next(final: bool) -> void:
	if final or int(GameState.run.get("approval", 0)) <= 0:
		get_tree().change_scene_to_file("res://scenes/report.tscn")
		return
	if not bool(GameState.run.get("event_resolved", true)) \
			and not ((GameState.run.get("event_card", {}) as Dictionary).is_empty()):
		_show_event()
		return
	_advance_next()


func _advance_next() -> void:
	if int(GameState.run.get("approval", 0)) <= 0:
		get_tree().change_scene_to_file("res://scenes/report.tscn")
		return
	if GameState.has_pending_buff():
		get_tree().change_scene_to_file("res://scenes/buff.tscn")
		return
	GameState.roll_draft()
	get_tree().change_scene_to_file("res://scenes/draft.tscn")


func _show_event() -> void:
	var card: Dictionary = GameState.run.get("event_card", {})
	if card.is_empty():
		_advance_next()
		return
	event_layer = CanvasLayer.new()
	event_layer.layer = 40
	add_child(event_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var p := UIKit.panel(Color("#0d1522"), UIKit.AMBER)
	p.position = Vector2(96, 44)
	p.size = Vector2(448, 272)
	root.add_child(p)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)

	var kicker := UIKit.label("BETWEEN MISSIONS  //  AGENCY EVENT", 7, UIKit.AMBER, true)
	kicker.position = Vector2(14, 10)
	kicker.size = Vector2(420, 12)
	c.add_child(kicker)
	var title := UIKit.label(str(card.get("title", "EVENT")), 13, UIKit.CYAN, true)
	title.position = Vector2(14, 25)
	title.size = Vector2(420, 18)
	c.add_child(title)
	var body := UIKit.label(str(card.get("body", "")), 7, UIKit.MUTED, false)
	body.position = Vector2(14, 47)
	body.size = Vector2(420, 26)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(body)

	var opts: Array = card.get("options", [])
	for i in range(opts.size()):
		var opt: Dictionary = opts[i]
		var y := 80.0 + i * 78.0
		var row := UIKit.panel(Color("#09111c"), Color("#2b4058"))
		row.position = Vector2(14, y)
		row.size = Vector2(420, 66)
		c.add_child(row)
		var rc := Control.new()
		rc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rc)
		var lab := UIKit.label(str(opt.get("label", "CHOOSE")), 9, UIKit.TEXT, true)
		lab.position = Vector2(10, 8)
		lab.size = Vector2(280, 14)
		rc.add_child(lab)
		var desc := UIKit.label(str(opt.get("desc", "")), 7, UIKit.MUTED, false)
		desc.position = Vector2(10, 28)
		desc.size = Vector2(290, 26)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rc.add_child(desc)
		var btn := UIKit.button("CHOOSE", Vector2(86, 24), i == 0)
		btn.position = Vector2(318, 20)
		btn.pressed.connect(_on_event_choice.bind(i))
		rc.add_child(btn)

	var hint := UIKit.label("This choice carries into the next sector.", 6, UIKit.DIM, true,
		HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(14, 244)
	hint.size = Vector2(420, 12)
	c.add_child(hint)


func _on_event_choice(index: int) -> void:
	if not GameState.choose_event(index):
		return
	if event_layer != null:
		event_layer.queue_free()
		event_layer = null
	call_deferred("_advance_next")


func _hr(x: float, y: float, w: float) -> HSeparator:
	var sep := UIKit.rule()
	sep.position = Vector2(x, y)
	sep.size = Vector2(w, 1)
	sep.custom_minimum_size = Vector2(w, 1)
	return sep


func _row(x: float, y: float, label: String, value: String, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.position = Vector2(x, y)
	h.size = Vector2(276, 14)
	var l := UIKit.label(label, 7, UIKit.MUTED, true)
	l.custom_minimum_size = Vector2(170, 12)
	h.add_child(l)
	var v := UIKit.label(value, 8, color, true, HORIZONTAL_ALIGNMENT_RIGHT)
	v.custom_minimum_size = Vector2(106, 12)
	h.add_child(v)
	return h


func _show_toast(text: String, color: Color) -> void:
	if toast == null:
		return
	toast.text = text
	toast.add_theme_color_override("font_color", color)
	toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
