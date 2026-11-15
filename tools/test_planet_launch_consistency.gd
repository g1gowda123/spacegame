extends SceneTree
## Verifies planet-consistent spacecraft launch animation across distinct exoplanet biomes.

var _game_state: Node

func _initialize() -> void:
	print("==================================================================")
	print("STARTING TEST: PLANET-CONSISTENT SPACECRAFT LAUNCH VERIFICATION")
	print("==================================================================")

	_game_state = root.get_node_or_null("GameState")
	if _game_state == null:
		var gs_class = load("res://scripts/game_state.gd")
		_game_state = gs_class.new()
		_game_state.name = "GameState"
		root.add_child(_game_state)
		_game_state.call("_load_planets")

	var test_planets := [
		{
			"name": "K2-141b",
			"biome": "volcanic",
			"distance_ly": 202.0,
			"gravity_g": 1.5,
			"eq_temp_k": 2300.0,
			"star": "K2-141",
			"star_type": "K7V",
			"escape_kms": 18.0
		},
		{
			"name": "OGLE-2005-BLG-390Lb",
			"biome": "cryo",
			"distance_ly": 21500.0,
			"gravity_g": 0.85,
			"eq_temp_k": 50.0,
			"star": "OGLE-390",
			"star_type": "M4V",
			"escape_kms": 9.2
		},
		{
			"name": "KEPLER-10b",
			"biome": "arid",
			"distance_ly": 564.0,
			"gravity_g": 1.4,
			"eq_temp_k": 1800.0,
			"star": "KEPLER-10",
			"star_type": "G",
			"escape_kms": 16.5
		}
	]

	var failures: int = 0
	var recorded_palettes: Array[Dictionary] = []

	for p_data in test_planets:
		print("\n--- TESTING PLANET: %s (BIOME: %s) ---" % [p_data.name, p_data.biome])
		var ok := _test_single_planet(p_data, recorded_palettes)
		if not ok:
			failures += 1
			print("[-] FAIL: Planet consistency verification failed for: ", p_data.name)
		else:
			print("[+] PASS: Planet-consistent launch verified for: ", p_data.name)

	# Verify all tested planets had completely distinct environmental palettes
	if recorded_palettes.size() == 3:
		if recorded_palettes[0]["ground"] == recorded_palettes[1]["ground"] or \
		   recorded_palettes[1]["ground"] == recorded_palettes[2]["ground"] or \
		   recorded_palettes[0]["sky"] == recorded_palettes[1]["sky"]:
			failures += 1
			print("[-] FAIL: Generic or duplicate background detected across distinct biomes!")
		else:
			print("[+] PASS: Distinct biome palettes confirmed: Volcanic, Cryo, Arid are visually unique.")

	print("\n==================================================================")
	if failures == 0:
		print("ALL PLANET-CONSISTENCY LAUNCH TESTS PASSED CLEANLY (EXIT 0)!")
	else:
		print("PLANET-CONSISTENCY TESTS FINISHED WITH %d FAILURES." % failures)
	print("==================================================================")

	quit(failures)


func _test_single_planet(p_data: Dictionary, out_palettes: Array[Dictionary]) -> bool:
	_game_state.new_run()
	_game_state.run["sector"] = 1
	_game_state.current_sector = {
		"planet": p_data,
		"sector": 1
	}

	var launch_scene = load("res://scenes/launch.tscn")
	var instance = launch_scene.instantiate()
	root.add_child(instance)
	instance._ready()

	# 1. Verify launch begins with the actual selected planet
	if instance._planet_name != p_data.name.to_upper():
		print("Error: Planet name mismatch: got %s, expected %s" % [instance._planet_name, p_data.name.to_upper()])
		_clean_up(instance)
		return false
	if instance._planet_biome != p_data.biome:
		print("Error: Biome mismatch: got %s, expected %s" % [instance._planet_biome, p_data.biome])
		_clean_up(instance)
		return false
	if instance._departure_biome != p_data.biome:
		print("Error: Departure biome must match selected planet: got %s, expected %s" % [instance._departure_biome, p_data.biome])
		_clean_up(instance)
		return false

	# 2. Verify surface visually matches the planet's biome
	var ground_col: Color = instance._env_ground_base_color
	var sky_col: Color = instance._env_sky_zenith
	out_palettes.append({"ground": ground_col, "sky": sky_col})

	if instance._ground_root == null or not instance._ground_root.visible:
		print("Error: Ground root missing or invisible")
		_clean_up(instance)
		return false

	# 3. Verify Engine ignition occurs on surface with illumination
	instance._enter_ignition_phase()
	instance._update_ignition_phase()
	if instance._engine_light_glow < 0.1:
		print("Error: Ground engine illumination did not ignite")
		_clean_up(instance)
		return false
	if instance._ground_root.modulate.a < 0.99:
		print("Error: Ground faded out during ignition")
		_clean_up(instance)
		return false

	# 4. Verify liftoff and 3-4 SECONDS OF ATMOSPHERIC FLIGHT
	instance._enter_liftoff_phase()
	if instance._phase != instance.Phase.LIFTOFF:
		print("Error: Not in LIFTOFF phase")
		_clean_up(instance)
		return false

	# Step through 3.5 seconds of atmospheric flight
	var sim_time: float = 0.0
	var step_delta: float = 0.25
	while sim_time < 3.5:
		instance._update_liftoff_phase(step_delta)
		sim_time += step_delta
		# DURING THIS ENTIRE PHASE: Space background must be 0.0 opacity, ground must be 1.0
		if instance._space_root != null and instance._space_root.modulate.a > 0.001:
			print("Error: Space background appeared during atmospheric flight at t=%.2fs" % sim_time)
			_clean_up(instance)
			return false
		if instance._ground_root != null and instance._ground_root.modulate.a < 0.99:
			print("Error: Ground terrain faded out during atmospheric flight at t=%.2fs" % sim_time)
			_clean_up(instance)
			return false
		# Multi-speed parallax: ground moves faster downward than distant mountains
		if instance._ground_root.position.y <= instance._distant_mountains_root.position.y:
			print("Error: Parallax speed inversion: ground must move faster than distant mountains")
			_clean_up(instance)
			return false

	print("  -> Verified: Rocket remained in planet atmosphere for %.1f seconds with active parallax and visible surface." % sim_time)

	# 5. Verify Upper Atmosphere phase (Phase D)
	instance._phase_time = 3.8
	instance._update_liftoff_phase(0.1) # Triggers transition to ASCENT
	if instance._phase != instance.Phase.ASCENT:
		print("Error: Did not transition to ASCENT after atmospheric flight")
		_clean_up(instance)
		return false

	# Advance into upper atmosphere: sky darkens, stars emerge gradually
	instance._phase_time = 1.6
	instance._update_ascent_phase(0.1)
	if instance._space_root.modulate.a <= 0.01:
		print("Error: Stars did not emerge in upper atmosphere")
		_clean_up(instance)
		return false

	# 6. Verify Space transition (Phase E)
	instance._phase_time = 3.2
	instance._update_ascent_phase(0.1)
	if instance._phase != instance.Phase.SPACE:
		print("Error: Did not enter SPACE phase")
		_clean_up(instance)
		return false

	_clean_up(instance)
	return true


func _clean_up(node: Node) -> void:
	if node != null:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
