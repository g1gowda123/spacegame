extends Node
## Dev-only continuous demo recorder driver.
##
## Movie Maker mode records every rendered frame, so this director scripts ONE
## deterministic playthrough and writes `markers.json` for the caption pass.
## There are no per-frame screenshots and no debug stills.
##
## Usage:
##   godot --path . --fixed-fps 30 \
##         --write-movie demo/capture/raw.avi \
##         -- --record-demo --demo-out=demo/capture
##
## `tools/record_demo.py` wraps the above and then calls
## `tools/make_demo_from_capture.py` to produce the captioned MP4.
##
## The director is inert unless `--record-demo` is passed, so it is harmless
## in the Web export (which cannot pass command-line arguments).

const FPS := 30
const DEMO_SEED := 20260414

var _active := false
var _fast := false
var _out_dir := "res://demo/capture"
var _t := 0.0
var _beats: Array = []


func _ready() -> void:
	for raw in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var arg := str(raw)
		if arg == "--record-demo":
			_active = true
		elif arg == "--demo-fast":
			_fast = true
		elif arg.begins_with("--demo-out="):
			_out_dir = arg.substr(11)
	if not _active:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Let the main scene finish _ready before the first beat starts.
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func _process(delta: float) -> void:
	if _active:
		_t += delta


# ---------------------------------------------------------------------------
# Beat tracking
# ---------------------------------------------------------------------------

func _beat(id: String, title: String, sub: String) -> void:
	if not _active:
		return
	if not _beats.is_empty():
		_beats[-1]["end"] = _t
	_beats.append({
		"id": id,
		"start": _t,
		"end": _t,
		"title": title,
		"sub": sub,
	})


func _wait(seconds: float) -> void:
	var s := seconds * (0.25 if _fast else 1.0)
	await get_tree().create_timer(s).timeout


func _scene_ready() -> void:
	# `change_scene_to_file` is deferred; three frames is enough for the new
	# scene's _ready plus one rendered frame for the movie writer.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _write_markers() -> void:
	# Close the open beat; it is only closed when the next one starts.
	if not _beats.is_empty():
		_beats[-1]["end"] = _t
	var dir := _out_dir
	if not (dir.begins_with("res://") or dir.begins_with("user://")
			or dir.begins_with("/") or dir.substr(1, 1) == ":"):
		dir = "res://" + dir.trim_prefix("./")
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var path := abs_dir.path_join("markers.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("demo markers: cannot write " + path)
		return
	f.store_string(JSON.stringify({
		"fps": FPS,
		"seconds": _t,
		"seed": DEMO_SEED,
		"beats": _beats,
	}, "  "))
	f.close()
	print("DEMO_MARKERS ", path)


# ---------------------------------------------------------------------------
# The scripted run
# ---------------------------------------------------------------------------

func _run() -> void:
	# Deterministic campaign: same planets, same drafts, same terrain on every
	# capture. Seed both the shared GameState RNG and the global RNG used by
	# Array.shuffle() in roll_draft().
	seed(DEMO_SEED)
	GameState.rng.seed = DEMO_SEED
	GameState.new_run()

	# 01 — title -------------------------------------------------------------
	_beat("title", "ORBIT + OUTPLAY",
		"A mission-design roguelite powered by real NASA exoplanet data.")
	await _wait(3.0)

	# 02 — mission design -----------------------------------------------------
	get_tree().change_scene_to_file("res://scenes/design.tscn")
	await _scene_ready()
	_beat("design", "01  DESIGN THE MISSION",
		"Balance mass, power, heat, delta-v and a $500M budget.")
	await _wait(2.0)
	GameState.select_orbit("polar")
	await _wait(1.4)
	GameState.select_hull("cryo")
	await _wait(1.4)
	GameState.select_hull("pathfinder")
	GameState.select_orbit("low")
	await _wait(1.4)
	GameState.commit_design()

	# 03 — target draft -------------------------------------------------------
	get_tree().change_scene_to_file("res://scenes/draft.tscn")
	await _scene_ready()
	_beat("draft", "02  DRAFT A REAL EXOPLANET",
		"Measured temperature, gravity and distance become the hazards.")
	await _wait(2.0)
	if GameState.draft.size() > 1:
		get_tree().current_scene.call("_select", str(GameState.draft[1]["id"]))
	await _wait(2.8)

	# 04 — surface sector -----------------------------------------------------
	var planet: Dictionary = GameState.draft[1] if GameState.draft.size() > 1 else GameState.draft[0]
	GameState.begin_sector(planet)
	get_tree().change_scene_to_file("res://scenes/sector.tscn")
	await _scene_ready()
	await _wait(1.6)
	_beat("sector", "03  SURVIVE THE SECTOR",
		"One move per turn. See the path, cost and hazard before you commit.")
	for _i in range(12):
		if not _sector_alive():
			break
		_sector_preview_move()
		await _wait(0.9)
		_sector_commit()
		await _wait(1.15)
		# Extract as soon as the quota is banked; otherwise keep walking.
		var sec: Dictionary = get_tree().current_scene.get("sec")
		if int(sec.get("data", 0)) >= int(sec.get("quota", 3)):
			break

	# 05 — extraction overlay -------------------------------------------------
	if _sector_alive():
		_sector_extract()
	await _wait(0.9)
	_beat("extract", "04  EXTRACT WITH THE DATA",
		"Meet the quota. A full four-node sweep pays more.")
	await _wait(2.0)

	# 06 — debrief / refit ----------------------------------------------------
	get_tree().change_scene_to_file("res://scenes/debrief.tscn")
	await _scene_ready()
	_beat("debrief", "05  REFIT AND STACK SYNERGIES",
		"Spend grants on modules. No single build survives every planet.")
	await _wait(1.6)
	if not GameState.shop_offers.is_empty():
		GameState.buy_offer(0)
	await _wait(2.6)

	# 07 — final report -------------------------------------------------------
	# The demo's last shot is the real report screen. The remaining two sectors
	# are settled through the same GameState calls the game uses so the ledger
	# is internally consistent; the capture does not pretend they were flown
	# on camera.
	for _i in range(2):
		if GameState.draft.is_empty():
			GameState.roll_draft()
		GameState.begin_sector(GameState.draft[0])
		GameState.finish_sector(true, 3, GameState.current_sector)
		GameState.make_shop()
	get_tree().change_scene_to_file("res://scenes/report.tscn")
	await _scene_ready()
	_beat("report", "THREE SECTORS. ONE AGENCY.",
		"Can you keep the lights on?")
	await _wait(4.5)

	_write_markers()
	await _wait(0.3)
	get_tree().quit()


# ---------------------------------------------------------------------------
# Sector helpers — drive the real turn loop, not a shortcut
# ---------------------------------------------------------------------------

func _sector_alive() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return not bool(scene.get("done"))


func _sector_preview_move() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player: Vector2i = scene.get("player_cell")
	var move_range := int(scene.get("move_range"))
	var objectives: Array = scene.get("objectives")
	var collected: Array = scene.get("collected")
	var hazards: Array = scene.get("hazards")
	var hazard_cells := {}
	for h in hazards:
		for c in (h.get("cells", []) as Array):
			hazard_cells[c] = true

	var best := player
	var best_score := -1.0e9
	# True walking distance to the nearest uncollected node. A Manhattan
	# guess sends the lander into water and costs the demo turns.
	var uncollected: Array = []
	for i in range(objectives.size()):
		if not bool(collected[i]):
			uncollected.append(objectives[i])
	var field := _node_distance_field(scene, uncollected)
	for dx in range(-move_range, move_range + 1):
		for dy in range(-move_range, move_range + 1):
			if dx == 0 and dy == 0:
				continue
			var cell := player + Vector2i(dx, dy)
			var path: Array = scene.call("_find_path", player, cell, move_range)
			if path.is_empty():
				continue
			var nodes := 0
			var crossed := 0
			for c in path:
				for i in range(objectives.size()):
					if not bool(collected[i]) and objectives[i] == c:
						nodes += 1
				if hazard_cells.has(c):
					crossed += 1
			var approach := int(field.get(cell, 60))
			# Prefer data, then short safe routes, then close the real walking
			# distance to the nearest uncollected node.
			var score := float(nodes) * 100.0 - float(path.size()) * 2.0 \
				- float(crossed) * 40.0 - float(approach) * 4.0
			if score > best_score:
				best_score = score
				best = cell
	scene.call("_select_cell", best)


func _node_distance_field(scene: Node, goals: Array) -> Dictionary:
	## Multi-source BFS over walkable cells, so the route planner knows how far
	## a candidate cell really is from the data nodes.
	var dist := {}
	if goals.is_empty():
		return dist
	var queue: Array = []
	for g in goals:
		if not dist.has(g):
			dist[g] = 0
			queue.append(g)
	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if int(dist[cur]) >= 28:
			continue
		for d in dirs:
			var n: Vector2i = cur + d
			if dist.has(n):
				continue
			if not bool(scene.call("_is_walkable_world", n)):
				continue
			dist[n] = int(dist[cur]) + 1
			queue.append(n)
	return dist


func _sector_commit() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		scene.call("_execute_path")


func _sector_extract() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		scene.call("_extract")
