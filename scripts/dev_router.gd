extends Node
const SHIP_BUILD := preload("res://scripts/ship_build.gd")
## Development-only deep links for screenshots and smoke tests.
## `godot --path . -- --screen=draft` boots straight into a screen.

var _screen := ""


func _ready() -> void:
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for raw in args:
		var arg := str(raw)
		if arg.begins_with("--screen="):
			_screen = arg.substr(9)
	if _screen == "" or _screen == "title":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_route()


func _apply_owned(csv: String) -> void:
	if csv.strip_edges() == "":
		return
	for raw_id in csv.split(","):
		var id := raw_id.strip_edges()
		for up in GameState.UPGRADES:
			if str(up["id"]) != id:
				continue
			# Allow a repeated --owned=repair for QA of the rack's xN badge;
			# every other id still dedupes like the real shop.
			if not (id in GameState.owned) or id == "repair":
				GameState.owned.append(id)
			break


func _run_flowtest() -> void:
	GameState.new_run()
	GameState.quick_loadout()
	var launched := GameState.commit_design()
	GameState.begin_sector(GameState.draft[0])
	var base_range := int(GameState.current_sector.get("move_range", 0))
	var base_dv := int(GameState.current_sector.get("delta_v", 0))
	var base_integrity := int(GameState.current_sector.get("integrity", 0))
	GameState.finish_sector(true, 3, GameState.current_sector)
	var buff_pending := GameState.has_pending_buff()
	GameState.run["buff_choices"] = ["harden", "reactor", "ranger"]
	var buff_ok := GameState.choose_buff(0)
	GameState.make_shop()
	GameState.shop_offers = [GameState.UPGRADES[10]]  # ION THRUSTER
	var bought := GameState.buy_offer(0)
	GameState.roll_draft()
	GameState.begin_sector(GameState.draft[0])
	var upgraded_range := int(GameState.current_sector.get("move_range", 0))
	var upgraded_dv := int(GameState.current_sector.get("delta_v", 0))
	print("SHIPFLOW launched=", launched, " buff_pending=", buff_pending, " buff_ok=", buff_ok, " buffs=", GameState.run.get("buffs", []), " integrity=", base_integrity, "->", int(GameState.current_sector.get("integrity", 0)))
	print("SHIPFLOW bought=", bought, " range=", base_range, "->", upgraded_range, " dv=", base_dv, "->", upgraded_dv)
	print("SHIPFLOW owned=", GameState.owned, " modules=", SHIP_BUILD.modules(GameState.run.get("instruments", []), GameState.owned).size(), " tier=", SHIP_BUILD.tier(SHIP_BUILD.refit_count(GameState.owned))["name"])
	for i in range(2):
		GameState.finish_sector(true, 3, GameState.current_sector)
		if int(GameState.run.get("sector", 1)) <= GameState.SECTORS_PER_RUN:
			GameState.roll_draft()
			GameState.begin_sector(GameState.draft[0])
	var score := GameState.calculate_score()
	print("SHIPFLOW report total=", score["total"], " grade=", score["grade"], " successes=", score["successes"])
	GameState.owned = []
	var before := GameState.ship()
	GameState.owned = ["rtg", "armor", "radiator", "wheel", "buffer"]
	var after := GameState.ship()
	print("SHIPFLOW stats power_regen=", int(before["power_regen"]), "->", int(after["power_regen"]), " integrity=", int(before["integrity"]), "->", int(after["integrity"]), " thermal=", int(before["thermal_res"]), "->", int(after["thermal_res"]), " dv=", int(before["delta_v"]), "->", int(after["delta_v"]), " comms=", int(before["comms_bonus"]), "->", int(after["comms_bonus"]))
	get_tree().quit()


func _apply_buffs(csv: String) -> void:
	if csv.strip_edges() == "":
		return
	var current: Array = GameState.run.get("buffs", [])
	for raw_id in csv.split(","):
		var id := raw_id.strip_edges()
		for b in GameState.BUFFS:
			if str(b["id"]) == id and not (id in current):
				current.append(id)
				break
	GameState.run["buffs"] = current


func _route() -> void:
	# Optional crew-mode shortcuts for screenshots and smoke tests:
	#   --crew=3 --difficulty=director
	var crew := 0
	var diff := "standard"
	var daily := false
	var forced_biome := ""
	var owned_csv := ""
	var buffs_csv := ""
	var forced_hull := ""
	var forced_vehicle := ""
	for raw in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var arg := str(raw)
		if arg.begins_with("--crew="):
			crew = int(arg.substr(7))
		elif arg.begins_with("--difficulty="):
			diff = arg.substr(13)
		elif arg == "--daily":
			daily = true
		elif arg.begins_with("--biome="):
			forced_biome = arg.substr(8)
		elif arg.begins_with("--owned="):
			owned_csv = arg.substr(8)
		elif arg.begins_with("--buffs="):
			buffs_csv = arg.substr(8)
		elif arg.begins_with("--hull="):
			forced_hull = arg.substr(7)
		elif arg.begins_with("--vehicle="):
			forced_vehicle = arg.substr(10)
	if _screen == "crew":
		get_tree().change_scene_to_file("res://scenes/crew.tscn")
		return
	if _screen == "briefing":
		get_tree().change_scene_to_file("res://scenes/briefing.tscn")
		return
	if _screen == "flowtest":
		_run_flowtest()
		return
	if _screen == "buff":
		GameState.run["sector"] = 2
		GameState.roll_buff_choices()
		get_tree().change_scene_to_file("res://scenes/buff.tscn")
		return
	if daily:
		CrewDirector.begin_run("daily", 1, "standard")
	elif crew > 0:
		CrewDirector.begin_run("campaign", crew, diff)
	else:
		GameState.new_run()
	_apply_owned(owned_csv)
	_apply_buffs(buffs_csv)
	if forced_hull != "":
		GameState.run["hull"] = forced_hull
	if forced_vehicle != "":
		GameState.run["vehicle"] = forced_vehicle
	match _screen:
		"design":
			if "--loadout" in OS.get_cmdline_user_args() or "--loadout" in OS.get_cmdline_args():
				GameState.quick_loadout()
			get_tree().change_scene_to_file("res://scenes/design.tscn")
			return
	if _screen == "draft":
		GameState.quick_loadout()
		GameState.commit_design()
		get_tree().change_scene_to_file("res://scenes/draft.tscn")
		return
	GameState.quick_loadout()
	GameState.commit_design()
	if forced_hull != "":
		GameState.run["hull"] = forced_hull
	if forced_vehicle != "":
		GameState.run["vehicle"] = forced_vehicle
	if GameState.draft.is_empty():
		GameState.roll_draft()
	var planet: Dictionary = GameState.draft[0]
	if forced_biome != "":
		for fp in GameState.planets:
			if str(fp.get("biome", "")) == forced_biome:
				planet = fp
				break
	if _screen == "launch":
		GameState.begin_sector(planet)
		get_tree().change_scene_to_file("res://scenes/launch.tscn")
		return
	if _screen == "sector":
		GameState.begin_sector(planet)
		get_tree().change_scene_to_file("res://scenes/sector.tscn")
		return
	if _screen == "relay":
		GameState.run["sector"] = 2
		GameState.begin_sector(planet)
		get_tree().change_scene_to_file("res://scenes/sector.tscn")
		return
	# debrief / report simulations
	GameState.begin_sector(planet)
	var sec: Dictionary = GameState.current_sector
	GameState.finish_sector(true, 3, sec)
	if _screen == "debrief":
		GameState.make_shop()
		get_tree().change_scene_to_file("res://scenes/debrief.tscn")
		return
	GameState.roll_draft()
	for i in range(2):
		# Re-roll before every simulated sector: the draft must advance with
		# history, or the fixture flies the same planet twice and the ledger
		# looks like a duplicate-target bug.
		GameState.roll_draft()
		var p2: Dictionary = GameState.draft[0]
		GameState.begin_sector(p2)
		GameState.finish_sector(true, 3, GameState.current_sector)
		GameState.make_shop()
		GameState.roll_draft()
	get_tree().change_scene_to_file("res://scenes/report.tscn")
