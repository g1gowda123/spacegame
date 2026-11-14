extends SceneTree

# Reachability audit (A1).
#
# For N seeds per biome, build the real generator exactly as a sector does
# (noise -> archetype -> start -> opening landmarks -> objectives), then
# flood-fill from the lander across walkable cells and assert every objective
# marker is reachable. Extraction is available anywhere in this game (press E),
# so the lander cell itself is the "extract cell"; it is trivially reachable.
#
# Run:
#   godot --headless --path . --script tools/audit_reach.gd
#   godot --headless --path . --script tools/audit_reach.gd -- --count=200 --biomes=temperate,ocean
#
# Exit code 0 = every seed/biome reachable, 1 = at least one failure.

const BIOME_DEFAULT := "temperate,arid,cryo,volcanic,ocean,barren"
const RADIUS := 30          # objectives spawn within ~14 cells; allow detours
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var gen: Node2D
var failures: Array = []
var totals := {"seeds": 0, "objectives": 0, "unreachable": 0}


func _initialize() -> void:
	var args := _parse_args()
	var script: Script = load("res://scripts/map_generator.gd")
	if script == null:
		print("FAIL: could not load map_generator.gd")
		quit(1)
		return
	gen = script.new()
	var count := int(args.get("count", 100))
	var seed0 := int(args.get("seed0", 1000))
	var step := int(args.get("step", 137))
	var biome_ids: Array = str(args.get("biomes", BIOME_DEFAULT)).split(",")

	print("REACH audit: %d seeds x %d biomes" % [count, biome_ids.size()])
	for biome_id in biome_ids:
		var id := str(biome_id).strip_edges()
		if id == "":
			continue
		var idx := _biome_index(id)
		if idx < 0:
			print("  SKIP unknown biome '%s'" % id)
			continue
		var bio := {"seeds": 0, "objectives": 0, "unreachable": 0, "worst_seed": -1, "worst": 0}
		for i in range(count):
			var seed_value := seed0 + i * step
			var r := _run_seed(id, idx, seed_value)
			bio["seeds"] += 1
			bio["objectives"] += int(r["objectives"])
			bio["unreachable"] += int(r["unreachable"])
			if int(r["unreachable"]) > int(bio["worst"]):
				bio["worst"] = int(r["unreachable"])
				bio["worst_seed"] = seed_value
			totals["seeds"] += 1
			totals["objectives"] += int(r["objectives"])
			totals["unreachable"] += int(r["unreachable"])
		print("  %-9s seeds=%d objectives=%d unreachable=%d worst=%d seed=%d" % [
			id, int(bio["seeds"]), int(bio["objectives"]), int(bio["unreachable"]),
			int(bio["worst"]), int(bio["worst_seed"])
		])
	print("TOTAL seeds=%d objectives=%d unreachable=%d" % [
		int(totals["seeds"]), int(totals["objectives"]), int(totals["unreachable"])
	])
	if failures.is_empty():
		print("REACH OK: every objective reachable from the lander")
		quit(0)
	else:
		print("REACH FAIL: %d seed/biome run(s) with unreachable objectives" % failures.size())
		for f in failures:
			print("  %s" % str(f))
		quit(1)


func _run_seed(biome_id: String, idx: int, seed_value: int) -> Dictionary:
	gen.seed_value = seed_value
	gen.biome_index = idx
	gen.chunks.clear()
	gen.rng.seed = seed_value
	gen._init_noise()
	gen.objectives.clear()
	gen.collected.clear()
	gen.player_cell = gen._find_start()
	# Mirror _generate(): one opening landmark, plus two more for the
	# mountainous archetypes, then the objective placement under audit.
	gen._place_start_landmark()
	if gen.archetype_name in ["Mountainous", "Broken Highlands", "Canyonlands", "Fractured"]:
		for _i in range(2):
			gen._place_start_landmark()
	gen._place_objectives()

	var reach := _flood(gen.player_cell, RADIUS)
	var unreachable: Array = []
	for o in gen.objectives:
		if not reach.has(o):
			unreachable.append(o)
	if not unreachable.is_empty():
		var pairs: Array = []
		for o in unreachable:
			pairs.append("(%d,%d)" % [o.x, o.y])
		failures.append("%s seed=%d player=(%d,%d) unreachable=%s" % [
			biome_id, seed_value, gen.player_cell.x, gen.player_cell.y,
			",".join(pairs)
		])
	return {
		"objectives": gen.objectives.size(),
		"unreachable": unreachable.size(),
	}


func _flood(start: Vector2i, radius: int) -> Dictionary:
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d in DIRS:
			var n: Vector2i = cur + d
			if seen.has(n):
				continue
			if absi(n.x - start.x) > radius or absi(n.y - start.y) > radius:
				continue
			if not gen._is_walkable_world(n):
				continue
			seen[n] = true
			q.append(n)
	return seen


func _biome_index(id: String) -> int:
	for i in range(gen.BIOMES.size()):
		if str(gen.BIOMES[i]["id"]) == id:
			return i
	return -1


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
