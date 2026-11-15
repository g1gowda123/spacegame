extends SceneTree
## Automated test suite for the Cinematic Spacecraft Launch Sequence.

var _game_state: Node

func _initialize() -> void:
	print("==================================================================")
	print("STARTING TEST SUITE: CINEMATIC SPACECRAFT LAUNCH SEQUENCE")
	print("==================================================================")

	_game_state = root.get_node_or_null("GameState")
	if _game_state == null:
		var gs_class = load("res://scripts/game_state.gd")
		_game_state = gs_class.new()
		_game_state.name = "GameState"
		root.add_child(_game_state)
		_game_state.call("_load_planets")
	
	_reset_state()

	var failures: int = 0
	
	# Test 1: Test all spacecraft hull variations
	var hulls := ["pathfinder", "cryo", "relay", "hopper"]
	for h_id in hulls:
		var ok := _test_hull_variation(h_id)
		if not ok:
			failures += 1
			print("[-] FAIL: Hull variation: ", h_id)
		else:
			print("[+] PASS: Spacecraft hull variation: ", h_id)

	# Test 2: Test all launch vehicle variations
	var vehicles := ["vector_l", "vector_m", "vector_h"]
	for v_id in vehicles:
		var ok := _test_vehicle_variation(v_id)
		if not ok:
			failures += 1
			print("[-] FAIL: Vehicle variation: ", v_id)
		else:
			print("[+] PASS: Launch vehicle variation: ", v_id)

	# Test 3: Test subsequent planetary mission transition
	var sub_ok := _test_subsequent_transition()
	if not sub_ok:
		failures += 1
		print("[-] FAIL: Subsequent mission transition")
	else:
		print("[+] PASS: Subsequent mission transition (sector > 1)")

	# Test 4: Test skip launch functionality
	var skip_ok := _test_skip_launch()
	if not skip_ok:
		failures += 1
		print("[-] FAIL: Skip launch functionality")
	else:
		print("[+] PASS: Skip launch functionality")

	# Test 5: Test reduced-effects mode
	var red_ok := _test_reduced_effects()
	if not red_ok:
		failures += 1
		print("[-] FAIL: Reduced-effects mode")
	else:
		print("[+] PASS: Reduced-effects mode")

	# Test 7: Target Exoplanet & Departure Planet Linkage
	var link_ok := _test_planet_linkage()
	if not link_ok:
		failures += 1
		print("[-] FAIL: Target planet & departure world linkage")
	else:
		print("[+] PASS: Target planet linkage & departure world visual continuity")

	# Test 8: Planetary Launch Background & Biome Environments
	var env_ok := _test_planetary_background_environments()
	if not env_ok:
		failures += 1
		print("[-] FAIL: Planetary launch background & biome environments")
	else:
		print("[+] PASS: Planetary launch background & 13 biome environments")

	# Test 6: Verify GameState preservation
	var state_ok := _test_gamestate_preservation()
	if not state_ok:
		failures += 1
		print("[-] FAIL: GameState preservation")
	else:
		print("[+] PASS: GameState preservation across launch")

	print("==================================================================")
	if failures == 0:
		print("ALL LAUNCH CINEMATIC TESTS PASSED SUCCESSFULLY!")
	else:
		print("TEST SUITE FINISHED WITH %d FAILURES." % failures)
	print("==================================================================")

	quit(failures)



func _clean_up(node: Node) -> void:
	if node != null:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()

func _reset_state() -> void:
	_game_state.new_run()
	_game_state.quick_loadout()
	_game_state.commit_design()
	if _game_state.draft.is_empty():
		_game_state.roll_draft()
	if not _game_state.draft.is_empty():
		_game_state.begin_sector(_game_state.draft[0])


func _test_hull_variation(h_id: String) -> bool:
	_reset_state()
	_game_state.run["hull"] = h_id
	_game_state.run["vehicle"] = "vector_m"
	_game_state.run["sector"] = 1

	var launch_scene = load("res://scenes/launch.tscn")
	if launch_scene == null:
		return false
	var instance = launch_scene.instantiate()
	if instance == null:
		return false
	root.add_child(instance)
	instance._ready()
	
	# Verify selected hull was assigned and loaded
	var ship_sprite: Sprite2D = instance._ship_sprite
	var loaded_hull_id: String = instance._hull_id
	if loaded_hull_id != h_id or ship_sprite == null or ship_sprite.texture == null:
		_clean_up(instance)
		return false

	# Advance frames & draw
	instance._process(0.1)
	_clean_up(instance)
	return true


func _test_vehicle_variation(v_id: String) -> bool:
	_reset_state()
	_game_state.run["hull"] = "pathfinder"
	_game_state.run["vehicle"] = v_id
	_game_state.run["sector"] = 1

	var launch_scene = load("res://scenes/launch.tscn")
	var instance = launch_scene.instantiate()
	root.add_child(instance)
	instance._ready()

	var loaded_veh_id: String = instance._veh_id
	if loaded_veh_id != v_id:
		_clean_up(instance)
		return false
	_clean_up(instance)
	return true


func _test_subsequent_transition() -> bool:
	_reset_state()
	_game_state.run["sector"] = 2

	var launch_scene = load("res://scenes/launch.tscn")
	var instance = launch_scene.instantiate()
	root.add_child(instance)
	instance._ready()

	var is_sub: bool = instance._is_subsequent
	if not is_sub:
		_clean_up(instance)
		return false

	# In subsequent sector, ground pad should be hidden and orbital flight active
	var ground: Control = instance._ground_root
	if ground != null and ground.visible:
		_clean_up(instance)
		return false

	_clean_up(instance)
	return true


func _test_skip_launch() -> bool:
	_reset_state()
	_game_state.run["sector"] = 1

	var launch_scene = load("res://scenes/launch.tscn")
	var instance = launch_scene.instantiate()
	root.add_child(instance)
	instance._ready()

	# Trigger skip
	instance.call("_skip_launch")
	var is_skipping: bool = instance._skipping
	var is_trans: bool = instance._transitioned
	if not is_skipping or not is_trans:
		_clean_up(instance)
		return false

	_clean_up(instance)
	return true


func _test_reduced_effects() -> bool:
	_reset_state()
	_game_state.run["sector"] = 1

	var launch_scene = load("res://scenes/launch.tscn")
	var instance = launch_scene.instantiate()
	instance.set("_reduced_fx", true)
	root.add_child(instance)
	instance._ready()

	var red: bool = instance._reduced_fx
	if not red:
		_clean_up(instance)
		return false

	instance._update_ignition_phase()
	var shake: float = instance._shake_amount
	if shake > 1.0:
		_clean_up(instance)
		return false

	_clean_up(instance)
	return true



func _test_planet_linkage() -> bool:
	_reset_state()
	_game_state.run["sector"] = 1
	var planet: Dictionary = _game_state.draft[0] if not _game_state.draft.is_empty() else {}
	var expected_biome: String = str(planet.get("biome", "temperate"))

	var launch_scene = load("res://scenes/launch.tscn")
	var instance = launch_scene.instantiate()
	root.add_child(instance)
	instance._ready()

	# Verify target planet info and texture
	if instance._planet_biome != expected_biome:
		_clean_up(instance)
		return false
	if instance._target_planet_rect == null or instance._target_planet_rect.texture == null:
		_clean_up(instance)
		return false
	if instance._departure_biome != "earth":
		_clean_up(instance)
		return false
	if instance._planet_info.is_empty() or not instance._planet_info.has("terrain"):
		_clean_up(instance)
		return false

	_clean_up(instance)

	# Verify sector > 1 departure planet linkage
	_reset_state()
	_game_state.history.append({"planet": {"name": "Testworld", "biome": "volcanic"}})
	_game_state.run["sector"] = 2
	var instance2 = launch_scene.instantiate()
	root.add_child(instance2)
	instance2._ready()

	if instance2._departure_biome != "volcanic":
		_clean_up(instance2)
		return false

	_clean_up(instance2)
	return true

func _test_gamestate_preservation() -> bool:
	_reset_state()
	_game_state.run["sector"] = 1
	_game_state.run["hull"] = "hopper"
	_game_state.run["vehicle"] = "vector_h"
	_game_state.run["objective"] = "geology"
	_game_state.run["budget"] = 420.0
	_game_state.run["approval"] = 92
	var prev_sector: Dictionary = _game_state.current_sector.duplicate(true)

	var launch_scene = load("res://scenes/launch.tscn")
	var instance = launch_scene.instantiate()
	root.add_child(instance)
	instance._ready()

	# Simulate frames across phases
	instance._enter_ignition_phase()
	instance._enter_liftoff_phase()
	instance._enter_ascent_phase()
	instance._enter_space_phase()

	# Verify GameState data was NOT corrupted or reset
	if _game_state.run["hull"] != "hopper" or _game_state.run["vehicle"] != "vector_h":
		_clean_up(instance)
		return false
	if _game_state.run["budget"] != 420.0 or _game_state.run["approval"] != 92:
		_clean_up(instance)
		return false
	if _game_state.current_sector.get("id") != prev_sector.get("id"):
		_clean_up(instance)
		return false

	_clean_up(instance)
	return true


func _test_planetary_background_environments() -> bool:
	var biomes := [
		"volcanic", "cryo", "arid", "temperate", "barren", "ocean",
		"methane", "crystal", "obsidian", "iron", "sulfur", "ammonia", "carbon"
	]
	var launch_scene = load("res://scenes/launch.tscn")
	if launch_scene == null:
		return false

	for b_id in biomes:
		_reset_state()
		_game_state.run["sector"] = 1
		_game_state.current_sector = {
			"planet": {
				"name": b_id.to_upper() + "-MAJOR",
				"biome": b_id,
				"distance_ly": 18.5,
				"gravity_g": 1.05,
				"eq_temp_k": 295.0,
				"star": "SOL",
				"star_type": "G2V",
				"escape_kms": 11.2
			}
		}

		var instance = launch_scene.instantiate()
		root.add_child(instance)
		instance._ready()

		# Verify environment setup
		if instance._env.is_empty():
			_clean_up(instance)
			return false
		
		# Verify sky and terrain are not pitch black
		if instance._env_sky_zenith.v < 0.04 or instance._env_sky_horizon.v < 0.08:
			_clean_up(instance)
			return false
		if instance._env_ground_base_color.v < 0.05:
			_clean_up(instance)
			return false
		if instance._mountain_polygon.size() < 30:
			_clean_up(instance)
			return false
		if instance._midground_polygon.size() < 20:
			_clean_up(instance)
			return false

		# Verify layer components exist and are visible on pad
		if instance._sky_canvas == null or instance._ground_root == null:
			_clean_up(instance)
			return false
		if not instance._ground_root.visible or not instance._distant_mountains_root.visible:
			_clean_up(instance)
			return false
		if instance._foreground_surface == null or instance._ground_illumination == null:
			_clean_up(instance)
			return false

		# Advance into ignition and liftoff to test illumination and parallax
		instance._enter_ignition_phase()
		instance._update_ignition_phase()
		if instance._engine_light_glow < 0.1:
			_clean_up(instance)
			return false

		instance._enter_liftoff_phase()
		instance._update_liftoff_phase(0.1)
		if instance._ground_root.position.y <= 0.0:
			_clean_up(instance)
			return false
		if instance._distant_mountains_root.position.y <= 0.0:
			_clean_up(instance)
			return false

		_clean_up(instance)

	return true
