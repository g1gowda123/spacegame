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
var sell_layer: Control
var tree_rack: UpgradeStrip


func _ready() -> void:
	MusicDirector.play("debrief")
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
		if str(raw).begins_with("--buy-id="):
			call_deferred("_dev_buy_id", str(raw).substr(9))
	if "--sell" in cli:
		call_deferred("_open_sell_panel")
	if "--tree" in cli:
		call_deferred("_open_tree_panel")
	if "--sell-first" in cli:
		call_deferred("_dev_sell_first")



func _dev_buy_id(id: String) -> void:
	for i in range(GameState.shop_offers.size()):
		if str(GameState.shop_offers[i].get("id", "")) == id:
			_dev_buy(i)
			return
	for up in GameState.UPGRADES:
		if str(up.get("id", "")) == id:
			GameState.shop_offers = [up]
			_refresh_shop()
			_dev_buy(0)
			return
	print("DEVBUYID missing ", id)


func _dev_sell_first() -> void:
	if GameState.owned.is_empty():
		print("DEVSELL none")
		return
	var id := str(GameState.owned[0])
	var res := GameState.sell_upgrade(id)
	print("DEVSELL ", id, " ok=", res.get("ok", false),
		" refund=", int(res.get("refund", 0)), " funds=", int(GameState.run.get("budget", 0)))
	GameState.make_shop()
	_refresh_shop()
	_refresh_ship()


func _dev_buy(idx: int) -> void:
	if idx < 0 or idx >= GameState.shop_offers.size():
		return
	var name := str(GameState.shop_offers[idx].get("name", "?"))
	_on_buy(idx)
	print("DEVBUY ", name, " owned=", GameState.owned.size())
	var ids: Array[String] = []
	for o in GameState.shop_offers:
		ids.append(str(o.get("id", "")))
	print("SHOPOFFERS ", ids)


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

	var title := UIKit.head("SECTOR DEBRIEF", 12, UIKit.NIGHT_TEXT)
	title.position = Vector2(10, 6)
	title.size = Vector2(340, 16)
	add_child(title)
	var sub := UIKit.mono(
		"%s  ·  %s  ·  SURFACE OPERATIONS REPORT" % [
			str(planet.get("name", "—")).to_upper(),
			GameState.biome_name(str(planet.get("biome", "barren"))).to_upper()
		], 7, UIKit.NIGHT_MUTED)
	sub.position = Vector2(10, 22)
	sub.size = Vector2(430, 12)
	add_child(sub)

	funds_label = UIKit.head("FUNDS $0M", 10, UIKit.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	funds_label.position = Vector2(480, 5)
	funds_label.size = Vector2(140, 15)
	add_child(funds_label)
	var approval_now := int(GameState.run.get("approval", 0))
	var appr_color := UIKit.RED if approval_now <= 20 else (UIKit.AMBER if approval_now <= 40 else UIKit.NIGHT_MUTED)
	var appr := UIKit.mono("APPROVAL %d" % approval_now, 7, appr_color, HORIZONTAL_ALIGNMENT_RIGHT)
	appr.position = Vector2(480, 20)
	appr.size = Vector2(140, 12)
	add_child(appr)
	UIKit.hairline(self, 10, 36, 620, UIKit.NIGHT_LINE)

	_build_summary()
	_build_shop()
	_build_footer()


func _build_summary() -> void:
	var p := UIKit.sheet(self, 10, 39, 306, 256)
	var c := UIKit.fill(p)
	var success := bool(r.get("success", false))
	var relay := str(r.get("mode", "survey")) == "relay"
	var stamp := UIKit.head("MISSION SUCCESS" if success else "MISSION FAILED", 15,
		UIKit.ORANGE_DARK if success else UIKit.SIGNAL)
	stamp.position = Vector2(12, 9)
	stamp.size = Vector2(280, 20)
	c.add_child(stamp)
	var reason := UIKit.mono(
		("RELAY CHAIN ONLINE" if relay else "ALL QUOTAS MET") if success else "AGENCY REVIEW FLAGGED", 7,
		UIKit.TEAL if success else UIKit.SIGNAL)
	reason.position = Vector2(12, 30)
	reason.size = Vector2(280, 12)
	c.add_child(reason)
	UIKit.hairline(c, 12, 44, 282, UIKit.LINE)

	var rows := [
		["BEACONS PLACED" if relay else "DATA DELIVERED", "%d / %d %s" % [
			int(r.get("delivered", 0)), int(r.get("quota", 3)), "RELAYS" if relay else "NODES"
		], UIKit.AMBER if relay else UIKit.TEAL],
		["SCIENCE VALUE", "+%d PTS" % int(r.get("science", 0)), UIKit.CYAN],
		["GRANT AWARDED", "+$%dM" % int(r.get("grant", 0)), UIKit.ORANGE_DARK],
		["APPROVAL CHANGE", "%+d" % int(r.get("approval_delta", 0)), UIKit.TEAL if success else UIKit.SIGNAL],
		["HULL INTEGRITY", "%d / %d" % [int(r.get("integrity_left", 0)), int(GameState.ship().get("integrity", 4))], UIKit.INK],
		["DELTA-V LEFT", "%d" % int(r.get("delta_v_left", 0)), UIKit.INK],
		["COMMS LOSS", "-%d%%" % int(r.get("comms_loss", 0)), UIKit.INK_SOFT],
	]
	var y := 52.0
	for row in rows:
		c.add_child(_row(12, y, row[0], row[1], row[2]))
		y += 14.0

	UIKit.hairline(c, 12, 154, 282, UIKit.LINE)
	var build_head := UIKit.mono("SHIP BUILD  //  LIVE REFIT", 7, UIKit.INK_SOFT)
	build_head.position = Vector2(12, 158)
	build_head.size = Vector2(286, 12)
	c.add_child(build_head)
	build_label = UIKit.mono("", 7, UIKit.INK_FAINT, HORIZONTAL_ALIGNMENT_RIGHT)
	build_label.position = Vector2(150, 158)
	build_label.size = Vector2(144, 12)
	c.add_child(build_label)
	ship_diagram = ShipDiagram.new()
	ship_diagram.position = Vector2(38, 166)
	ship_diagram.size = Vector2(232, 78)
	c.add_child(ship_diagram)
	build_line = UIKit.mono("", 7, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	build_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_line.position = Vector2(12, 248)
	build_line.size = Vector2(282, 18)
	c.add_child(build_line)
	_refresh_ship()


func _build_shop() -> void:
	var p := UIKit.sheet(self, 326, 39, 304, 256)
	var c := UIKit.fill(p)
	var head := UIKit.head("FIELD REFIT", 9, UIKit.NAME)
	head.position = Vector2(12, 9)
	head.size = Vector2(160, 12)
	c.add_child(head)
	var store := UIKit.mono("AGENCY STORE", 7, UIKit.INK_SOFT)
	store.position = Vector2(108, 10)
	c.add_child(store)
	owned_label = UIKit.mono("", 7, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	owned_label.position = Vector2(196, 10)
	owned_label.size = Vector2(94, 12)
	c.add_child(owned_label)
	UIKit.hairline(c, 12, 24, 280, UIKit.LINE)

	shop_root = Control.new()
	shop_root.position = Vector2(10, 30)
	shop_root.size = Vector2(284, 216)
	shop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(shop_root)
	var hover_hint := UIKit.mono("2 PATHS · TIER 2 NEEDS 1", 6, UIKit.INK_SOFT)
	hover_hint.position = Vector2(12, 225)
	hover_hint.size = Vector2(94, 12)
	c.add_child(hover_hint)
	var tree_btn := UIKit.button("TREE", Vector2(72, 18), false)
	tree_btn.position = Vector2(112, 220)
	tree_btn.size = Vector2(72, 18)
	tree_btn.pressed.connect(_open_tree_panel)
	c.add_child(tree_btn)
	var sell_btn := UIKit.button("SELL PARTS", Vector2(82, 18), false)
	sell_btn.position = Vector2(198, 220)
	sell_btn.size = Vector2(88, 18)
	sell_btn.pressed.connect(_open_sell_panel)
	c.add_child(sell_btn)
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
		shop_root.add_child(_offer_card(up, i, i * 64.0))


func _offer_card(up: Dictionary, idx: int, y: float) -> Control:
	var cost := float(up["cost"])
	var afford := float(GameState.run.get("budget", 0)) >= cost
	var card := Control.new()
	card.position = Vector2(0, y)
	card.size = Vector2(284, 64)
	card.pivot_offset = Vector2(142, 30)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	UIKit.sheet(card, 0, 0, 284, 60)
	card.mouse_entered.connect(func():
		card.z_index = 2
		var tw: Tween = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2(1.025, 1.025), 0.14)
		tw.tween_property(card, "position:y", y - 2.0, 0.14)
	)
	card.mouse_exited.connect(func():
		card.z_index = 0
		var tw: Tween = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.14)
		tw.tween_property(card, "position:y", y, 0.14)
	)

	# Every offer gets a physical module portrait, so the shop reads as a
	# catalogue of hardware rather than three identical text rows.
	var icon_frame := Panel.new()
	icon_frame.position = Vector2(6, 6)
	icon_frame.size = Vector2(52, 52)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sys_id := str(up.get("branch", "SUPPORT"))
	var sys_color := Color(str(GameState.SYSTEM_COLOR.get(sys_id, "#e8dfc8")))
	# Cream technical-drawing tile: the mono module line art needs contrast,
	# and a paper inset makes the shop feel like a parts catalogue.
	icon_frame.add_theme_stylebox_override("panel", UIKit.style_panel(
		UIKit.PAPER, sys_color, 0
	))
	card.add_child(icon_frame)
	# Prefer a dedicated 128 px module portrait; buff icons remain the
	# fallback while VEGA fills the module set.
	var icon_path := "res://assets/sprites/modules/%s.png" % str(up["id"])
	if not ResourceLoader.exists(icon_path):
		icon_path = "res://assets/sprites/buffs/%s.png" % str(up.get("icon", "cache"))
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path) as Texture2D
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 3
		icon.offset_top = 3
		icon.offset_right = -3
		icon.offset_bottom = -3
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(icon)

	var nm := UIKit.label(str(up["name"]), 9, UIKit.NAME, true)
	nm.position = Vector2(64, 7)
	nm.size = Vector2(128, 13)
	card.add_child(nm)
	var kind_text := "HARDWARE" if str(up["kind"]) == "MODULE" else "SOFTWARE"
	var kind := UIKit.mono(kind_text, 6, UIKit.ORANGE_DARK, HORIZONTAL_ALIGNMENT_RIGHT)
	card.add_child(kind)
	kind.position = Vector2(186, 8)
	kind.size = Vector2(74, 11)
	var sys := str(up.get("branch", "SUPPORT"))
	var path := str(up.get("path", "A"))
	var role: String = str(GameState.BRANCH_ROLE.get(sys, {}).get(path, ""))
	var branch := UIKit.mono("%s %s%d%s" % [
		sys, path, int(up.get("tier", 1)),
		(" · " + role) if role != "" else ""
	], 6, sys_color)
	branch.position = Vector2(64, 21)
	branch.size = Vector2(118, 9)
	card.add_child(branch)
	var glyph_path := "res://assets/sprites/modules/branches/%s_%s.png" % [sys.to_lower(), path]
	if ResourceLoader.exists(glyph_path):
		var glyph := TextureRect.new()
		glyph.texture = load(glyph_path) as Texture2D
		glyph.position = Vector2(186, 19)
		glyph.size = Vector2(16, 16)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(glyph)
	var pr := UIKit.label("$%dM" % int(cost), 9, UIKit.ORANGE_DARK if afford else UIKit.SIGNAL, true)
	pr.position = Vector2(58, 32)
	pr.size = Vector2(70, 12)
	card.add_child(pr)

	# A one-line effect readout so the card explains itself before hover. The
	# full plain-language copy still lives in the dossier.
	var effect := UIKit.mono(str(up.get("desc", "")), 6, UIKit.MUTED)
	effect.position = Vector2(64, 47)
	effect.size = Vector2(144, 10)
	effect.clip_text = true
	card.add_child(effect)

	var buy := UIKit.button("BUY", Vector2(58, 20), afford)
	buy.position = Vector2(218, 26)
	buy.size = Vector2(58, 20)
	buy.disabled = not afford
	buy.pressed.connect(_on_buy.bind(idx))
	card.add_child(buy)
	var tip_title := str(up["name"])
	var tip_body := "%s\n\nCOST $%dM · %s" % [
		str(up.get("plain", up["desc"])), int(cost), kind_text.to_upper()
	]
	var tip_accent := UIKit.ORANGE if afford else UIKit.SIGNAL
	UIKit.hover_info(card, tip_title, tip_body, tip_accent)
	UIKit.hover_info(buy, tip_title, tip_body, tip_accent)
	return card


func _on_buy(idx: int) -> void:
	if idx < 0 or idx >= GameState.shop_offers.size():
		return
	var up: Dictionary = GameState.shop_offers[idx]
	if GameState.buy_offer(idx):
		var info := GameState.consume_last_upgrade()
		var delta := str(info.get("text", ""))
		var line := "INSTALLED  %s" % str(up["name"])
		if not delta.is_empty():
			line += "  ·  " + delta
		_show_toast(line, UIKit.GREEN)
		# buy_offer already removes this card. Rebuilding the shop here rerolled
		# the other two offers after every purchase; keep the stop's inventory.
		_refresh_shop()
		_refresh_ship()
		if ship_diagram != null:
			ship_diagram.flash_build()
		_show_upgrade_pop(delta)
	else:
		_show_toast("INSUFFICIENT GRANTS", UIKit.RED)


func _show_upgrade_pop(text: String) -> void:
	## A short rising stat tag on the ship card: the purchase should read as a
	## change to the craft, not only a line of toast at the bottom.
	if text.is_empty() or build_label == null:
		return
	var parent := build_label.get_parent()
	if parent == null:
		return
	var pop := UIKit.label(text, 8, UIKit.GREEN, true)
	pop.position = build_label.position + Vector2(0, -12)
	pop.size = Vector2(280, 14)
	parent.add_child(pop)
	pop.move_to_front()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pop, "position:y", pop.position.y - 10, 0.75) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "modulate:a", 0.0, 0.55).set_delay(0.35)
	tw.chain().tween_callback(pop.queue_free)


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
	build_label.add_theme_color_override("font_color", UIKit.INK_SOFT)
	build_line.text = ship_diagram.module_line()
	build_line.add_theme_color_override("font_color", UIKit.INK_SOFT)


func _build_footer() -> void:
	var p := UIKit.sheet(self, 10, 304, 620, 46)
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
	footer_title = UIKit.head(next_title, 10,
		UIKit.ORANGE_DARK if final else UIKit.INK)
	footer_title.position = Vector2(12, 6)
	footer_title.size = Vector2(340, 14)
	c.add_child(footer_title)
	footer_sub = UIKit.mono(next_sub, 7, UIKit.INK_SOFT)
	footer_sub.position = Vector2(12, 22)
	footer_sub.size = Vector2(360, 14)
	c.add_child(footer_sub)

	next_btn = UIKit.button(next_button, Vector2(206, 28), true)
	next_btn.position = Vector2(398, 9)
	next_btn.pressed.connect(_on_next.bind(final))
	c.add_child(next_btn)

	toast = UIKit.mono("", 8, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
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

	var p := UIKit.sheet(root, 96, 44, 448, 272)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)

	var kicker := UIKit.label("BETWEEN MISSIONS  //  AGENCY EVENT", 7, UIKit.ORANGE, true)
	kicker.position = Vector2(14, 10)
	kicker.size = Vector2(420, 12)
	c.add_child(kicker)
	var title := UIKit.label(str(card.get("title", "EVENT")), 13, UIKit.ORANGE_DARK, true)
	title.position = Vector2(14, 25)
	title.size = Vector2(420, 18)
	c.add_child(title)
	var body := UIKit.label(str(card.get("body", "")), 7, UIKit.INK_SOFT, false)
	body.position = Vector2(14, 47)
	body.size = Vector2(420, 26)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(body)

	var opts: Array = card.get("options", [])
	for i in range(opts.size()):
		var opt: Dictionary = opts[i]
		var y := 80.0 + i * 78.0
		var row := UIKit.sheet(c, 14, y, 420, 66)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.mouse_entered.connect(func():
			row.add_theme_stylebox_override("panel", UIKit.style_panel(
				Color(0, 0, 0, 0), UIKit.SAGE, 0, 1
			))
		)
		row.mouse_exited.connect(func():
			row.add_theme_stylebox_override("panel", UIKit.style_panel(
				Color(0, 0, 0, 0), UIKit.SHEET_LINE, 0, 1
			))
		)
		var rc := Control.new()
		rc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rc)
		var lab := UIKit.label(str(opt.get("label", "CHOOSE")), 9, UIKit.INK, true)
		lab.position = Vector2(10, 8)
		lab.size = Vector2(280, 14)
		rc.add_child(lab)
		var desc := UIKit.label(str(opt.get("desc", "")), 7, UIKit.INK_SOFT, false)
		desc.position = Vector2(10, 28)
		desc.size = Vector2(290, 26)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rc.add_child(desc)
		var btn := UIKit.button("CHOOSE", Vector2(86, 24), true)
		btn.position = Vector2(318, 20)
		btn.pressed.connect(_on_event_choice.bind(i))
		rc.add_child(btn)

	var hint := UIKit.mono("This choice carries into the next sector.", 7, UIKit.INK_FAINT,
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


func _open_tree_panel() -> void:
	if tree_rack == null or not is_instance_valid(tree_rack):
		tree_rack = UpgradeStrip.new()
		tree_rack.position = Vector2(-200, -200)
		tree_rack.visible = false
		add_child(tree_rack)
		tree_rack.refresh()
	if tree_rack.arsenal_open:
		tree_rack.toggle_arsenal()
	else:
		tree_rack.toggle_arsenal()


func _upgrade_info(id: String) -> Dictionary:
	for up in GameState.UPGRADES:
		if str(up.get("id", "")) == id:
			return up
	return {}


func _open_sell_panel() -> void:
	if sell_layer != null and is_instance_valid(sell_layer):
		sell_layer.queue_free()
	sell_layer = Control.new()
	sell_layer.position = Vector2(326, 39)
	sell_layer.size = Vector2(304, 256)
	sell_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_layer.z_index = 60
	add_child(sell_layer)
	var backing := ColorRect.new()
	backing.color = UIKit.HULL
	backing.position = Vector2.ZERO
	backing.size = Vector2(304, 256)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sell_layer.add_child(backing)
	var p := UIKit.sheet(sell_layer, 0, 0, 304, 256)
	var c := UIKit.fill(p)
	var head := UIKit.head("RESALE BAY", 9, UIKit.NAME)
	head.position = Vector2(12, 8)
	head.size = Vector2(160, 12)
	c.add_child(head)
	var sub := UIKit.mono("50% RECOVERY  ·  PULL A PART", 6, UIKit.INK_SOFT)
	sub.position = Vector2(12, 22)
	c.add_child(sub)
	var close := UIKit.button("CLOSE", Vector2(58, 17), false)
	close.position = Vector2(232, 6)
	close.size = Vector2(58, 17)
	close.pressed.connect(_close_sell_panel)
	c.add_child(close)
	UIKit.hairline(c, 12, 36, 280, UIKit.LINE)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 42)
	scroll.size = Vector2(284, 202)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(280, 0)
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	if GameState.owned.is_empty():
		var none := UIKit.label("NO PAID PARTS INSTALLED", 8, UIKit.DIM, true,
			HORIZONTAL_ALIGNMENT_CENTER)
		none.custom_minimum_size = Vector2(280, 30)
		list.add_child(none)
		return
	for raw in GameState.owned:
		var id := str(raw)
		var up := _upgrade_info(id)
		if up.is_empty():
			continue
		list.add_child(_sell_row(up))


func _sell_row(up: Dictionary) -> Control:
	var id := str(up["id"])
	var row := Control.new()
	row.custom_minimum_size = Vector2(280, 24)
	var nm := UIKit.mono(str(up.get("name", id)), 7, UIKit.INK, true)
	nm.position = Vector2(2, 2)
	nm.size = Vector2(152, 11)
	nm.clip_text = true
	row.add_child(nm)
	var branch := UIKit.mono("%s %s%d" % [
		str(up.get("branch", "SUPPORT")), str(up.get("path", "A")),
		int(up.get("tier", 1))
	], 6, UIKit.INK_FAINT)
	branch.position = Vector2(2, 13)
	branch.size = Vector2(130, 9)
	row.add_child(branch)
	var refund := int(floor(float(up.get("cost", 0.0)) * 0.5))
	var price := UIKit.mono("+$%dM" % refund, 7, UIKit.GREEN,
		HORIZONTAL_ALIGNMENT_RIGHT)
	price.position = Vector2(156, 3)
	price.size = Vector2(62, 12)
	row.add_child(price)
	var sell := UIKit.button("SELL", Vector2(52, 17), false)
	sell.position = Vector2(222, 2)
	sell.size = Vector2(52, 17)
	sell.pressed.connect(_sell_part.bind(id))
	row.add_child(sell)
	UIKit.hairline(row, 0, 23, 278, UIKit.LINE)
	return row


func _sell_part(id: String) -> void:
	var res := GameState.sell_upgrade(id)
	if bool(res.get("ok", false)):
		_show_toast("PULLED %s  ·  +$%dM" % [
			str(res.get("name", id)), int(res.get("refund", 0))
		], UIKit.GREEN)
		GameState.make_shop()
		_refresh_ship()
		_refresh_shop()
		_open_sell_panel()
	else:
		_show_toast("CANNOT SELL  ·  %s" % str(res.get("reason", "?")), UIKit.RED)


func _close_sell_panel() -> void:
	if sell_layer != null and is_instance_valid(sell_layer):
		sell_layer.queue_free()
	sell_layer = null
