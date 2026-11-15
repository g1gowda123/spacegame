extends Node
## Trailer capture director — inert unless `--trailer-shot=<name>` is passed.
##
## One run per shot keeps the trailer footage swappable: re-record only the
## shot that changed, drop the new clip into `trailer/clips/`, rebuild. Each
## run writes `marks_<shot>.json` so the edit can land cuts on real game beats
## instead of guessed timestamps.
##
## Usage:
##   godot --path . --resolution 1920x1080 --fixed-fps 30 \
##         --write-movie trailer/raw/sector_volcanic.avi \
##         -- --trailer-shot=sector_volcanic --trailer-out=trailer/raw
##
## Shots: title, crew, design, draft, launch, sector_volcanic, sector_cryo,
##        debrief, report.

const FPS := 30
const SEED := 20261115

var _active := false
var _shot := ""
var _out_dir := "res://trailer/raw"
var _seed := SEED
var _t := 0.0
var _marks: Array = []


func _ready() -> void:
	for raw in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var arg := str(raw)
		if arg.begins_with("--trailer-shot="):
			_shot = arg.substr(15)
			_active = true
		elif arg.begins_with("--trailer-out="):
			_out_dir = arg.substr(14)
		elif arg.begins_with("--trailer-seed="):
			_seed = int(arg.substr(15))
	if not _active:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func _process(delta: float) -> void:
	if _active:
		_t += delta


# ---------------------------------------------------------------------------
# Beat tracking / timing
# ---------------------------------------------------------------------------

func _mark(id: String) -> void:
	_marks.append({"id": id, "t": snappedf(_t, 0.001)})
	print("TRAILER_MARK ", id, " @", snappedf(_t, 0.01))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _scene_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _write_marks() -> void:
	_mark("end")
	var dir := _out_dir
	if not (dir.begins_with("res://") or dir.begins_with("user://")
			or dir.begins_with("/") or dir.substr(1, 1) == ":"):
		dir = "res://" + dir.trim_prefix("./")
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var path := abs_dir.path_join("marks_%s.json" % _shot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("trailer marks: cannot write " + path)
		return
	f.store_string(JSON.stringify({
		"fps": FPS,
		"shot": _shot,
		"seconds": _t,
		"seed": _seed,
		"marks": _marks,
	}, "  "))
	f.close()
	print("TRAILER_MARKS ", path)


# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

func _pick_planet(biome: String) -> Dictionary:
	var fallback: Dictionary = {}
	for p in GameState.planets:
		if str(p.get("biome", "")) == biome:
			if fallback.is_empty():
				fallback = p
			# Prefer the famous systems — the trailer card reads better with a
			# name the audience has seen in a press release.
			var n := str(p.get("name", ""))
			if n.begins_with("TRAPPIST") or n.begins_with("Kepler-442") \
					or n.begins_with("Proxima") or n.begins_with("TOI-"):
				return p
	if fallback.is_empty() and not GameState.planets.is_empty():
		fallback = GameState.planets[0]
	return fallback


func _prepared_run(biome: String = "volcanic") -> Dictionary:
	seed(_seed)
	GameState.rng.seed = _seed
	GameState.new_run()
	GameState.quick_loadout()
	GameState.commit_design()
	var planet := _pick_planet(biome)
	GameState.begin_sector(planet)
	return planet


# ---------------------------------------------------------------------------
# Shots
# ---------------------------------------------------------------------------

func _run() -> void:
	seed(_seed)
	GameState.rng.seed = _seed
	match _shot:
		"title": await _shot_title()
		"crew": await _shot_crew()
		"design": await _shot_design()
		"draft": await _shot_draft()
		"launch": await _shot_launch()
		"sector_volcanic": await _shot_sector("volcanic")
		"sector_cryo": await _shot_sector("cryo")
		"debrief": await _shot_debrief()
		"report": await _shot_report()
		"tech": await _shot_tech()
		"resale": await _shot_resale()
		"event": await _shot_event()
		"briefing": await _shot_briefing()
		"story": await _shot_story()
		_:
			push_error("trailer: unknown shot " + _shot)
	_write_marks()
	await _wait(0.3)
	get_tree().quit()


func _shot_title() -> void:
	GameState.new_run()
	get_tree().change_scene_to_file("res://scenes/title.tscn")
	await _scene_ready()
	_mark("title.settled")
	await _wait(8.0)


func _shot_crew() -> void:
	GameState.new_run()
	get_tree().change_scene_to_file("res://scenes/crew.tscn")
	await _scene_ready()
	await _wait(1.2)
	_mark("crew.settled")
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_set_players"):
		scene.call("_set_players", 4)
		await _wait(1.8)
		_mark("crew.players4")
		if scene.has_method("_set_difficulty"):
			scene.call("_set_difficulty", "director")
		await _wait(2.4)


func _shot_design() -> void:
	GameState.new_run()
	get_tree().change_scene_to_file("res://scenes/design.tscn")
	await _scene_ready()
	await _wait(1.2)
	_mark("design.settled")
	GameState.select_hull("cryo")
	await _wait(1.6)
	_mark("design.hull_cryo")
	GameState.select_hull("relay")
	await _wait(1.5)
	_mark("design.hull_relay")
	GameState.select_hull("pathfinder")
	GameState.select_orbit("polar")
	await _wait(1.7)
	_mark("design.orbit_polar")
	GameState.select_orbit("low")
	await _wait(1.4)
	_mark("design.orbit_low")
	GameState.toggle_instrument("spectrometer")
	await _wait(1.2)
	_mark("design.instrument")
	await _wait(1.0)


func _shot_draft() -> void:
	GameState.new_run()
	get_tree().change_scene_to_file("res://scenes/draft.tscn")
	await _scene_ready()
	await _wait(1.4)
	_mark("draft.settled")
	for i in range(mini(3, GameState.draft.size())):
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("_select"):
			scene.call("_select", str(GameState.draft[i]["id"]))
		_mark("draft.card_%d" % i)
		await _wait(2.6)
	await _wait(0.8)


func _shot_launch() -> void:
	_prepared_run("volcanic")
	get_tree().change_scene_to_file("res://scenes/launch.tscn")
	await _scene_ready()
	_mark("launch.pad")
	await _wait(30.0)


func _shot_sector(biome: String) -> void:
	_prepared_run(biome)
	# A trailer sector is a highlight reel, not a rules demo: raise the quota
	# so the run does not self-extract after three moves, and keep the planet
	# name honest on the HUD.
	GameState.current_sector["quota"] = 6
	get_tree().change_scene_to_file("res://scenes/sector.tscn")
	await _scene_ready()
	await _wait(2.2)
	_mark("sector.settled")
	var taken := 0
	for i in range(14):
		if not _sector_alive():
			break
		_sector_preview_move(i == 2)
		_mark("move_%d.preview" % (i + 1))
		await _wait(1.3)
		_sector_commit()
		_mark("move_%d.commit" % (i + 1))
		await _wait(1.45)
		taken += 1
		var sec: Dictionary = get_tree().current_scene.get("sec")
		if int(sec.get("data", 0)) >= int(sec.get("quota", 3)):
			break
	if _sector_alive():
		_mark("extract.press")
		_sector_extract()
		await _wait(3.2)
	_mark("sector.end")
	await _wait(0.6)


func _shot_debrief() -> void:
	var planet := _prepared_run("temperate")
	var sec: Dictionary = GameState.current_sector
	GameState.finish_sector(true, 4, sec)
	GameState.make_shop()
	get_tree().change_scene_to_file("res://scenes/debrief.tscn")
	await _scene_ready()
	await _wait(1.6)
	_mark("debrief.settled")
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_dev_buy"):
		scene.call("_dev_buy", 0)
	await _wait(3.0)
	_mark("debrief.bought")
	await _wait(2.0)


func _shot_tech() -> void:
	var planet := _prepared_run("temperate")
	GameState.finish_sector(true, 4, GameState.current_sector)
	GameState.make_shop()
	get_tree().change_scene_to_file("res://scenes/debrief.tscn")
	await _scene_ready()
	await _wait(1.4)
	_mark("tech.settled")
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_open_tree_panel"):
		scene.call("_open_tree_panel")
		await _wait(2.4)
		_mark("tech.tree")
		if scene.has_method("_dev_buy_id"):
			scene.call("_dev_buy_id", "rw8")
		await _wait(2.2)
		_mark("tech.bought")
	await _wait(4.0)


func _shot_resale() -> void:
	var planet := _prepared_run("temperate")
	GameState.finish_sector(true, 4, GameState.current_sector)
	GameState.make_shop()
	get_tree().change_scene_to_file("res://scenes/debrief.tscn")
	await _scene_ready()
	await _wait(1.4)
	_mark("resale.settled")
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_open_sell_panel"):
		scene.call("_open_sell_panel")
		await _wait(2.2)
		_mark("resale.panel")
		if scene.has_method("_dev_sell_first"):
			scene.call("_dev_sell_first")
		await _wait(2.0)
		_mark("resale.sold")
	await _wait(4.0)


func _shot_event() -> void:
	var planet := _prepared_run("temperate")
	GameState.finish_sector(true, 4, GameState.current_sector)
	GameState.make_shop()
	get_tree().change_scene_to_file("res://scenes/debrief.tscn")
	await _scene_ready()
	await _wait(1.2)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_show_event"):
		scene.call("_show_event")
		await _wait(1.4)
		_mark("event.shown")
		if scene.has_method("_on_event_choice") and GameState.run.get("event", {}).size() > 0:
			scene.call("_on_event_choice", 0)
		elif scene.has_method("_pick_event_choice"):
			scene.call("_pick_event_choice", 0)
		await _wait(3.0)
		_mark("event.chose")
	await _wait(3.4)


func _shot_briefing() -> void:
	GameState.new_run()
	get_tree().change_scene_to_file("res://scenes/briefing.tscn")
	await _scene_ready()
	await _wait(2.0)
	_mark("briefing.settled")
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_advance"):
		for i in range(3):
			scene.call("_advance")
			await _wait(2.4)
		_mark("briefing.beats")
	await _wait(2.6)


func _shot_story() -> void:
	GameState.new_run()
	get_tree().change_scene_to_file("res://scenes/briefing.tscn")
	await _scene_ready()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_advance"):
		for i in range(4):
			scene.call("_advance")
			await _wait(0.4)
	await _wait(1.2)
	_mark("story.beat")
	await _wait(8.0)


func _shot_report() -> void:
	_prepared_run("crystal")
	for _i in range(2):
		if GameState.draft.is_empty():
			GameState.roll_draft()
		GameState.begin_sector(GameState.draft[0])
		GameState.finish_sector(true, 3, GameState.current_sector)
		GameState.make_shop()
	get_tree().change_scene_to_file("res://scenes/report.tscn")
	await _scene_ready()
	await _wait(1.0)
	_mark("report.settled")
	await _wait(11.0)


# ---------------------------------------------------------------------------
# Sector helpers — drive the real turn loop
# ---------------------------------------------------------------------------

func _sector_alive() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return not bool(scene.get("done"))


func _sector_preview_move(risk: bool) -> void:
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
			var score := float(nodes) * 100.0 - float(path.size()) * 2.0 \
				- float(crossed) * 40.0 - float(approach) * 4.0
			# One planned-risk beat: take a route that crosses a live hazard so
			# the trailer can show the telegraph resolving into damage.
			if risk and crossed > 0 and nodes > 0:
				score += 260.0
			if score > best_score:
				best_score = score
				best = cell
	scene.call("_select_cell", best)


func _node_distance_field(scene: Node, goals: Array) -> Dictionary:
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
