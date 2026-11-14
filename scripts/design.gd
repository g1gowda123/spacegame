extends Control
const SHIP_BUILD := preload("res://scripts/ship_build.gd")

var hull_cards: Dictionary = {}
var vehicle_cards: Dictionary = {}
var objective_cards: Dictionary = {}
var instrument_cards: Dictionary = {}
var diagram: ShipDiagram
var build_label: Label
var mass_bar: UIGauge
var power_bar: UIGauge
var dv_bar: UIGauge
var hull_bar: UIGauge
var thermal_bar: UIGauge
var data_bar: UIGauge
var mass_val: Label
var power_val: Label
var dv_val: Label
var hull_val: Label
var thermal_val: Label
var data_val: Label
var warning_label: Label
var budget_label: Label
var cost_label: Label
var confirm_btn: Button
var orbit_buttons: Dictionary = {}
var orbit_desc_label: Label
var requirement_label: Label
var instrument_requirement: Label
var objective_note: Label
var vehicle_requirement: Label


func _ready() -> void:
	MusicDirector.play("design")
	# Start with a valid, conservative mission so the screen reads as a
	# spacecraft immediately; QUICK LOADOUT remains a one-click reset and the
	# player can change every card.
	if str(GameState.run.get("hull", "")) == "":
		GameState.quick_loadout()
	var bg := SpaceBackdrop.new()
	add_child(bg)
	bg.configure({"planet_on": false, "dim": 0.42})
	_build()
	GameState.changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var header := UIKit.head("MISSION DESIGN", 12, UIKit.TEXT)
	header.position = Vector2(10, 6)
	add_child(header)

	var step := UIKit.mono("01 / 03   ·   ENGINEERING TRADE STUDY", 7, UIKit.DIM)
	step.position = Vector2(10, 22)
	add_child(step)

	# Required-state sits in the header instead of a second title row.
	requirement_label = UIKit.mono("REQUIRED: SELECT A HULL", 7, UIKit.AMBER,
		HORIZONTAL_ALIGNMENT_RIGHT)
	requirement_label.position = Vector2(286, 8)
	requirement_label.size = Vector2(196, 13)
	add_child(requirement_label)

	budget_label = UIKit.head("BUDGET $500M", 10, UIKit.AMBER,
		HORIZONTAL_ALIGNMENT_RIGHT)
	budget_label.position = Vector2(490, 5)
	budget_label.size = Vector2(140, 15)
	add_child(budget_label)
	var appr := UIKit.mono("APPROVAL %d" % int(GameState.run.get("approval", 62)), 7, UIKit.MUTED,
		HORIZONTAL_ALIGNMENT_RIGHT)
	appr.position = Vector2(490, 20)
	appr.size = Vector2(140, 12)
	add_child(appr)
	UIKit.hairline(self, 10, 36, 620)

	_build_left()
	_build_center()
	_build_right()
	_build_footer()


func _column(x: float, w: float, title: String) -> VBoxContainer:
	var p := UIKit.sheet(self, x, 39, w, 282)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var head := UIKit.mono(title, 8, UIKit.MUTED)
	v.add_child(head)
	UIKit.hairline(v, 0, 0, w - 16, UIKit.LINE)
	v.add_child(UIKit.vspace(3))
	return v


func _subhead(v: VBoxContainer, text: String) -> void:
	v.add_child(UIKit.vspace(0))
	v.add_child(UIKit.mono(text, 7, UIKit.DIM))


func _build_left() -> void:
	var v := _column(10, 198, "HULL BUS")
	for h in GameState.HULLS:
		var card := UIKit.option_card(
			v, Rect2(0, 0, 184, 40), str(h["name"]),
			"%s · %s" % [str(h["class"]), str(h["perk"])],
			UIKit.CYAN, 9, 7,
			"%dKG · $%dM" % [int(h["mass"]), int(h["cost"])], false
		)
		card["button"].pressed.connect(_pick_hull.bind(str(h["id"])))
		hull_cards[str(h["id"])] = card

	_subhead(v, "LAUNCH VEHICLE")
	vehicle_requirement = UIKit.mono("REQUIRED", 7, UIKit.AMBER)
	v.add_child(vehicle_requirement)
	for veh in GameState.VEHICLES:
		var card := UIKit.option_card(
			v, Rect2(0, 0, 184, 20), str(veh["name"]), "",
			UIKit.CYAN, 9, 7,
			"%.0fKG CAP" % float(veh["capacity"]), false
		)
		card["button"].pressed.connect(_pick_vehicle.bind(str(veh["id"])))
		vehicle_cards[str(veh["id"])] = card
		card["button"].tooltip_text = str(veh["note"])


func _build_center() -> void:
	var p := UIKit.sheet(self, 216, 39, 204, 278)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	v.add_child(UIKit.mono("SPACECRAFT", 8, UIKit.MUTED))
	UIKit.hairline(v, 0, 0, 190, UIKit.LINE)

	diagram = ShipDiagram.new()
	diagram.custom_minimum_size = Vector2(190, 60)
	diagram.size = Vector2(190, 60)
	v.add_child(diagram)

	build_label = UIKit.mono("", 7, UIKit.DIM)
	build_label.custom_minimum_size = Vector2(190, 10)
	v.add_child(build_label)

	mass_bar = _stat_row(v, "MASS", "kg")
	power_bar = _stat_row(v, "POWER", "W")
	dv_bar = _stat_row(v, "DELTA-V", "dv")
	hull_bar = _stat_row(v, "HULL", "int")
	thermal_bar = _stat_row(v, "THERMAL", "res")
	data_bar = _stat_row(v, "DATA", "cap")
	mass_val = _stat_value(mass_bar)
	power_val = _stat_value(power_bar)
	dv_val = _stat_value(dv_bar)
	hull_val = _stat_value(hull_bar)
	thermal_val = _stat_value(thermal_bar)
	data_val = _stat_value(data_bar)

	warning_label = UIKit.mono("Select hull, vehicle, objective and two instruments.", 7, UIKit.AMBER)
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.custom_minimum_size = Vector2(188, 24)
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(warning_label)

	orbit_desc_label = UIKit.mono("ORBIT · BALANCED GLOBAL SURVEY", 7, UIKit.MUTED)
	orbit_desc_label.custom_minimum_size = Vector2(190, 10)
	v.add_child(orbit_desc_label)
	var orbit_row := HBoxContainer.new()
	orbit_row.add_theme_constant_override("separation", 4)
	for o in GameState.ORBITS:
		var b := UIKit.button(str(o["name"]), Vector2(60, 20))
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(_pick_orbit.bind(str(o["id"])))
		orbit_buttons[str(o["id"])] = b
		orbit_row.add_child(b)
	v.add_child(orbit_row)

	var conops := UIKit.mono(
		"CONOPS  LAUNCH · CRUISE · INSERTION\nSURFACE · DOWNLINK · END",
		6, UIKit.DIM)
	conops.custom_minimum_size = Vector2(190, 14)
	conops.add_theme_constant_override("line_spacing", 0)
	v.add_child(conops)


func _stat_row(v: VBoxContainer, name: String, unit: String) -> UIGauge:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.custom_minimum_size = Vector2(190, 13)
	v.add_child(h)
	var l := UIKit.mono(name, 7, UIKit.MUTED)
	l.custom_minimum_size = Vector2(50, 12)
	h.add_child(l)
	var pb := UIKit.bar(88, 5, UIKit.CYAN)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pb)
	var val := UIKit.mono("—", 8, UIKit.TEXT)
	val.custom_minimum_size = Vector2(42, 12)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.name = "Value"
	h.add_child(val)
	return pb


func _stat_value(pb: UIGauge) -> Label:
	return pb.get_parent().get_node("Value") as Label


func _build_right() -> void:
	var v := _column(428, 202, "MISSION OBJECTIVE")
	for o in GameState.OBJECTIVES:
		var card := UIKit.option_card(
			v, Rect2(0, 0, 188, 20), str(o["name"]), "",
			UIKit.CYAN, 9, 7, "", false
		)
		card["button"].pressed.connect(_pick_objective.bind(str(o["id"])))
		objective_cards[str(o["id"])] = card
		card["button"].tooltip_text = str(o["perk"])
	objective_note = UIKit.mono("", 7, UIKit.DIM)
	objective_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_note.custom_minimum_size = Vector2(188, 22)
	objective_note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(objective_note)

	_subhead(v, "INSTRUMENTS  ·  PICK 2")
	instrument_requirement = UIKit.mono("0 / 2 SELECTED", 7, UIKit.AMBER)
	v.add_child(instrument_requirement)
	var short_names := {
		"camera": "MULTISPECTRAL", "spectrometer": "SPECTROMETER",
		"radar": "RADAR SOUNDER", "thermal": "THERMAL IMAGER",
		"magnetometer": "MAGNETOMETER", "drill": "SUBSURFACE",
	}
	for inst in GameState.INSTRUMENTS:
		var card := UIKit.option_card(
			v, Rect2(0, 0, 188, 16),
			str(short_names.get(str(inst["id"]), str(inst["name"]))), "",
			UIKit.CYAN, 9, 7,
			"%.0fKG · $%.0fM" % [float(inst["mass"]), float(inst["cost"])], false
		)
		card["button"].pressed.connect(_toggle_instrument.bind(str(inst["id"])))
		card["button"].tooltip_text = str(inst["perk"])
		instrument_cards[str(inst["id"])] = card


func _build_footer() -> void:
	UIKit.hairline(self, 10, 323, 620)
	var back := UIKit.button("< BACK", Vector2(68, 24))
	back.position = Vector2(10, 328)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	add_child(back)

	var quick := UIKit.button("QUICK LOADOUT", Vector2(124, 24))
	quick.position = Vector2(84, 328)
	quick.pressed.connect(func():
		GameState.quick_loadout()
		GameState.sfx("confirm")
	)
	add_child(quick)

	cost_label = UIKit.mono("MISSION COST  $0M", 7, UIKit.DIM,
		HORIZONTAL_ALIGNMENT_RIGHT)
	cost_label.position = Vector2(216, 332)
	cost_label.size = Vector2(172, 14)
	add_child(cost_label)

	confirm_btn = UIKit.button("CONFIRM DESIGN >", Vector2(232, 26), true)
	confirm_btn.position = Vector2(398, 327)
	confirm_btn.pressed.connect(_confirm)
	add_child(confirm_btn)


func _pick_orbit(id: String) -> void:
	GameState.select_orbit(id)


func _pick_hull(id: String) -> void:
	GameState.select_hull(id)


func _pick_vehicle(id: String) -> void:
	GameState.select_vehicle(id)


func _pick_objective(id: String) -> void:
	GameState.select_objective(id)


func _toggle_instrument(id: String) -> void:
	GameState.toggle_instrument(id)


func _confirm() -> void:
	if not GameState.commit_design():
		GameState.sfx("alarm")
		_flash_requirement()
		return
	GameState.sfx("confirm")
	get_tree().change_scene_to_file("res://scenes/draft.tscn")


func _refresh() -> void:
	var s := GameState.ship()
	for id in orbit_buttons:
		orbit_buttons[id].button_pressed = str(GameState.run.get("orbit", "low")) == id
	orbit_desc_label.text = "ORBIT · " + str(GameState.orbit().get("desc", "")).to_upper()
	for id in hull_cards:
		UIKit.select_card(hull_cards[id], str(GameState.run.get("hull", "")) == id)
	for id in vehicle_cards:
		UIKit.select_card(vehicle_cards[id], str(GameState.run.get("vehicle", "")) == id)
	var chosen_objective := str(GameState.run.get("objective", ""))
	for id in objective_cards:
		UIKit.select_card(objective_cards[id], chosen_objective == id)
	if objective_note != null:
		var ob := GameState.objective()
		objective_note.text = str(ob.get("perk", ""))
		objective_note.add_theme_color_override("font_color",
			UIKit.MUTED if not chosen_objective.is_empty() else UIKit.DIM)
	var chosen: Array = GameState.run.get("instruments", [])
	for id in instrument_cards:
		UIKit.select_card(instrument_cards[id], id in chosen)
		var locked: bool = chosen.size() >= 2 and not (id in chosen)
		instrument_cards[id]["root"].modulate = Color(1, 1, 1, 0.32) if locked else Color.WHITE
		instrument_cards[id]["button"].disabled = locked
		instrument_cards[id]["enabled"] = not locked

	diagram.set_ship(str(GameState.run.get("hull", "")), chosen)
	var tier: Dictionary = diagram.tier()
	build_label.text = "BUILD  %s  ·  %d PAYLOAD" % [str(tier["name"]), diagram.module_count()]
	build_label.add_theme_color_override("font_color", tier["color"])
	var cap := maxf(1.0, float(s.get("capacity", 1.0)))
	mass_val.text = "%d/%d" % [int(s.get("mass", 0)), int(cap)]
	UIKit.set_bar(mass_bar, float(s.get("mass", 0)), cap)
	var over_mass := float(s.get("mass", 0)) > cap
	UIKit.set_bar_color(mass_bar, UIKit.RED if over_mass else UIKit.CYAN)
	mass_val.add_theme_color_override("font_color", UIKit.RED if over_mass else UIKit.TEXT)
	power_val.text = "%d/%dW" % [int(s.get("power_draw", 0)), int(s.get("power_gen", 0))]
	var power_net := float(s.get("power_gen", 0)) - float(s.get("power_draw", 0))
	UIKit.set_bar(power_bar, maxf(0.0, power_net), maxf(1.0, float(s.get("power_gen", 0))))
	UIKit.set_bar_color(power_bar, UIKit.RED if power_net < 0.0 else UIKit.CYAN)
	power_val.add_theme_color_override("font_color", UIKit.RED if power_net < 0.0 else UIKit.TEXT)
	dv_val.text = "%d" % int(s.get("delta_v", 0))
	UIKit.set_bar(dv_bar, float(s.get("delta_v", 0)), 45.0)
	UIKit.set_bar_color(dv_bar, UIKit.AMBER if int(s.get("delta_v", 0)) <= 5 else UIKit.CYAN)
	hull_val.text = "x%d" % int(s.get("integrity", 0))
	UIKit.set_bar(hull_bar, float(s.get("integrity", 0)), 7.0)
	UIKit.set_bar_color(hull_bar, UIKit.RED if int(s.get("integrity", 0)) <= 1 else UIKit.CYAN)
	thermal_val.text = "%d" % int(s.get("thermal_res", 0))
	UIKit.set_bar(thermal_bar, float(s.get("thermal_res", 0)), 24.0)
	UIKit.set_bar_color(thermal_bar, UIKit.CYAN)
	data_val.text = "%d" % int(s.get("data_cap", 0))
	UIKit.set_bar(data_bar, float(s.get("data_cap", 0)), 18.0)
	UIKit.set_bar_color(data_bar, UIKit.CYAN)

	var cost := float(s.get("cost", 0))
	cost_label.text = "MISSION COST  $%dM" % int(cost)
	budget_label.text = "BUDGET  $%dM" % int(GameState.run.get("budget", 0))
	var chosen_count: int = chosen.size()
	instrument_requirement.text = "%d / 2 SELECTED" % chosen_count
	instrument_requirement.add_theme_color_override(
		"font_color", UIKit.GREEN if chosen_count == 2 else UIKit.AMBER
	)
	var capacity := float(s.get("capacity", 0.0))
	if float(s.get("mass", 0.0)) > capacity:
		vehicle_requirement.text = "OVER CAPACITY"
		vehicle_requirement.add_theme_color_override("font_color", UIKit.RED)
	else:
		vehicle_requirement.text = "%dkg / %dkg CAP" % [
			int(s.get("mass", 0)), int(capacity)
		]
		vehicle_requirement.add_theme_color_override("font_color", UIKit.DIM)
	if bool(s.get("valid", false)):
		var cm := GameState.cml()
		warning_label.text = "CML %d %s  ·  READY TO DRAFT" % [int(cm["level"]), str(cm["label"])]
		if bool(s.get("science_fit", false)):
			warning_label.text += "\nSCIENCE FIT +10%"
		warning_label.add_theme_color_override("font_color", UIKit.GREEN)
		requirement_label.text = "ALL REQUIRED FIELDS SET"
		requirement_label.add_theme_color_override("font_color", UIKit.GREEN)
		confirm_btn.disabled = false
	else:
		var warns: Array = s.get("warnings", [])
		warning_label.text = "\n".join(warns)
		warning_label.add_theme_color_override("font_color", UIKit.AMBER)
		requirement_label.text = "REQUIRED: " + str(warns[0] if warns.size() > 0 else "CHECK MISSION")
		requirement_label.add_theme_color_override("font_color", UIKit.AMBER)
		confirm_btn.disabled = true


func _flash_requirement() -> void:
	if requirement_label == null:
		return
	requirement_label.modulate = Color(1.35, 0.8, 0.7)
	var tw := create_tween()
	tw.tween_property(requirement_label, "modulate", Color.WHITE, 0.45)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		elif event.keycode == KEY_ENTER:
			_confirm()
