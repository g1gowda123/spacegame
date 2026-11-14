extends Control
## Between-sector debrief and field refit shop.

var r: Dictionary = {}
var shop_root: Control
var toast: Label
var funds_label: Label
var owned_label: Label
var footer_title: Label
var footer_sub: Label
var next_btn: Button

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
	_build()


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
	var stamp := UIKit.label("MISSION SUCCESS" if success else "MISSION FAILED", 16,
		UIKit.CYAN if success else UIKit.RED, true)
	stamp.position = Vector2(10, 8)
	stamp.size = Vector2(286, 22)
	c.add_child(stamp)
	var reason := UIKit.label(
		"ALL QUOTAS MET" if success else "AGENCY REVIEW FLAGGED", 7,
		UIKit.GREEN if success else UIKit.RED, true)
	reason.position = Vector2(10, 30)
	reason.size = Vector2(286, 12)
	c.add_child(reason)

	var rows := [
		["DATA DELIVERED", "%d / %d NODES" % [int(r.get("delivered", 0)), int(r.get("quota", 3))], UIKit.GREEN],
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
	var lock := GameState.hull()
	var vehicle := GameState.vehicle()
	var obj := GameState.objective()
	var info := UIKit.label(
		"OBJECTIVE  %s\nHULL  %s\nLAUNCH  %s\nORBIT  LOW INSERTION\nPAYLOAD  %d INSTRUMENTS" % [
			str(obj.get("name", "—")).to_upper(),
			str(lock.get("name", "—")).to_upper(),
			str(vehicle.get("name", "—")).to_upper(),
			GameState.run.get("instruments", []).size(),
		], 7, UIKit.MUTED, false)
	info.position = Vector2(10, 148)
	info.size = Vector2(286, 90)
	info.add_theme_constant_override("line_spacing", 1)
	c.add_child(info)


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
		shop_root.add_child(_offer_card(up, i, i * 68.0))


func _offer_card(up: Dictionary, idx: int, y: float) -> Control:
	var cost := float(up["cost"])
	var afford := float(GameState.run.get("budget", 0)) >= cost
	var card := Control.new()
	card.position = Vector2(0, y)
	card.size = Vector2(288, 62)
	var bg := UIKit.panel(Color("#0c1726"), Color("#263d55"))
	bg.position = Vector2.ZERO
	bg.size = card.size
	card.add_child(bg)

	var nm := UIKit.label(str(up["name"]), 9, UIKit.TEXT, true)
	nm.position = Vector2(8, 6)
	nm.size = Vector2(198, 12)
	card.add_child(nm)
	var kind := UIKit.label(str(up["kind"]), 5, UIKit.CYAN, true, HORIZONTAL_ALIGNMENT_RIGHT)
	kind.position = Vector2(188, 8)
	kind.size = Vector2(80, 10)
	card.add_child(kind)
	var desc := UIKit.label(str(up["desc"]), 7, UIKit.MUTED, false)
	desc.position = Vector2(8, 20)
	desc.size = Vector2(190, 24)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc)
	var pr := UIKit.label("$%dM" % int(cost), 10, UIKit.AMBER if afford else UIKit.RED, true)
	pr.position = Vector2(8, 42)
	pr.size = Vector2(80, 14)
	card.add_child(pr)

	var buy := UIKit.button("INSTALL", Vector2(72, 22), afford)
	buy.position = Vector2(206, 34)
	buy.disabled = not afford
	buy.pressed.connect(_on_buy.bind(idx))
	card.add_child(buy)
	return card


func _on_buy(idx: int) -> void:
	if idx < 0 or idx >= GameState.shop_offers.size():
		return
	var up: Dictionary = GameState.shop_offers[idx]
	if GameState.buy_offer(idx):
		_show_toast("INSTALLED  %s" % str(up["name"]), UIKit.GREEN)
		_refresh_shop()
	else:
		_show_toast("INSUFFICIENT GRANTS", UIKit.RED)


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
	footer_title = UIKit.label(
		"FINAL REPORT READY" if final else "NEXT: EXOPLANET TARGET DRAFT", 10,
		UIKit.CYAN if final else UIKit.AMBER, true)
	footer_title.position = Vector2(12, 6)
	footer_title.size = Vector2(340, 14)
	c.add_child(footer_title)
	footer_sub = UIKit.label(
		"Agency ledger and final grade." if final else "Three new targets. Choose where the grants go.",
		7, UIKit.MUTED, false)
	footer_sub.position = Vector2(12, 22)
	footer_sub.size = Vector2(360, 14)
	c.add_child(footer_sub)

	next_btn = UIKit.button("FILE FINAL REPORT >" if final else "SELECT NEXT TARGET >", Vector2(206, 28), true)
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
	GameState.roll_draft()
	get_tree().change_scene_to_file("res://scenes/draft.tscn")


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
