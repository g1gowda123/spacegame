extends Node
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
			if str(up["id"]) == id and not (id in GameState.owned):
				GameState.owned.append(id)
				break


func _route() -> void:
	# Optional crew-mode shortcuts for screenshots and smoke tests:
	#   --crew=3 --difficulty=director
	var crew := 0
	var diff := "standard"
	var daily := false
	var forced_biome := ""
	var owned_csv := ""
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
	if _screen == "crew":
		get_tree().change_scene_to_file("res://scenes/crew.tscn")
		return
	if daily:
		CrewDirector.begin_run("daily", 1, "standard")
	elif crew > 0:
		CrewDirector.begin_run("campaign", crew, diff)
	else:
		GameState.new_run()
	_apply_owned(owned_csv)
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
	if GameState.draft.is_empty():
		GameState.roll_draft()
	var planet: Dictionary = GameState.draft[0]
	if forced_biome != "":
		for fp in GameState.planets:
			if str(fp.get("biome", "")) == forced_biome:
				planet = fp
				break
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
	for i in range(2):
		if GameState.draft.is_empty():
			GameState.roll_draft()
		var p2: Dictionary = GameState.draft[i % GameState.draft.size()]
		GameState.begin_sector(p2)
		GameState.finish_sector(true, 3, GameState.current_sector)
		GameState.make_shop()
	get_tree().change_scene_to_file("res://scenes/report.tscn")
