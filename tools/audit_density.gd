extends SceneTree

# A2 — density vs footprint audit.
#
# Measures how much of each 16x16 chunk's walkable area is consumed by *major*
# landforms (3x3+ footprints, piece assemblies, or a rendered width >= 4 tiles),
# then prints the per-biome summary and the worst example chunks. This is the
# evidence behind the formula in docs/AUDIT_FIXES.md §6.
#
# Run:
#   godot --headless --path . --script tools/audit_density.gd
#   godot --headless --path . --script tools/audit_density.gd -- --seeds=10 --chunks=8
#   godot --headless --path . --script tools/audit_density.gd -- --gate
#
# Default exit is 0 (measurement). `--gate` exits 1 when any chunk exceeds the
# 25% budget, so the budget becomes enforceable once the cap is wired.

const BIOME_DEFAULT := "temperate,arid,cryo,volcanic,ocean,barren"
const BUDGET := 0.25
const OVERHANG := 1.0   # spec allows at most one tile of visual overhang

var gen: Node2D
var examples: Array = []


func _initialize() -> void:
	var args := _parse_args()
	var script: Script = load("res://scripts/map_generator.gd")
	if script == null:
		print("FAIL: could not load map_generator.gd")
		quit(1)
		return
	gen = script.new()
	var seeds := int(args.get("seeds", 5))
	var seed0 := int(args.get("seed0", 1000))
	var step := int(args.get("step", 137))
	var grid := int(args.get("chunks", 6))
	var gate := bool(args.get("gate", false))
	var biome_ids: Array = str(args.get("biomes", BIOME_DEFAULT)).split(",")

	print("DENSITY audit: %d seeds x %d biomes x %dx%d chunks (budget %.0f%%)" % [
		seeds, biome_ids.size(), grid, grid, BUDGET * 100.0
	])
	var total_chunks := 0
	var total_over := 0
	for biome_id in biome_ids:
		var id := str(biome_id).strip_edges()
		if id == "":
			continue
		var idx := _biome_index(id)
		if idx < 0:
			print("  SKIP unknown biome '%s'" % id)
			continue
		var bio := {
			"chunks": 0, "walkable": 0, "major": 0, "max": 0.0, "over": 0,
			"worst_seed": -1, "worst_coord": Vector2i.ZERO,
		}
		for i in range(seeds):
			var seed_value := seed0 + i * step
			_measure_seed(id, idx, seed_value, grid, bio)
		total_chunks += int(bio["chunks"])
		total_over += int(bio["over"])
		var mean := 0.0
		if int(bio["walkable"]) > 0:
			mean = 100.0 * float(bio["major"]) / float(bio["walkable"])
		print("  %-9s chunks=%4d walkable=%6d major=%5d mean=%5.1f%% max=%5.1f%% over25=%d (seed=%d chunk=%s)" % [
			id, int(bio["chunks"]), int(bio["walkable"]), int(bio["major"]),
			mean, float(bio["max"]) * 100.0, int(bio["over"]),
			int(bio["worst_seed"]), str(bio["worst_coord"])
		])

	print("TOTAL chunks=%d over25=%d" % [total_chunks, total_over])
	examples.sort_custom(func(a, b): return float(a["coverage"]) > float(b["coverage"]))
	print("EXAMPLES (worst %d chunks)" % mini(3, examples.size()))
	for i in range(mini(3, examples.size())):
		var e: Dictionary = examples[i]
		print("  seed=%d biome=%-9s chunk=(%d,%d) walkable=%d major=%d coverage=%.1f%% keys=%s" % [
			int(e["seed"]), str(e["biome"]), int(e["chunk"].x), int(e["chunk"].y),
			int(e["walkable"]), int(e["major"]), float(e["coverage"]) * 100.0,
			str(e["keys"])
		])

	var formula := _formula(total_chunks)
	print("FORMULA")
	for line in formula:
		print("  %s" % line)

	if gate and total_over > 0:
		print("DENSITY FAIL: %d chunk(s) over the %.0f%% budget" % [total_over, BUDGET * 100.0])
		quit(1)
	else:
		var tail := "" if total_over == 0 else " — %d chunk(s) over budget" % total_over
		print("DENSITY OK (measurement)%s" % tail)
		quit(0)


func _measure_seed(biome_id: String, idx: int, seed_value: int, grid: int, bio: Dictionary) -> void:
	gen.seed_value = seed_value
	gen.biome_index = idx
	gen.chunks.clear()
	gen.rng.seed = seed_value
	gen._init_noise()
	for cy in range(grid):
		for cx in range(grid):
			var coord := Vector2i(cx, cy)
			var data: Dictionary = gen._get_chunk(coord)
			var walkable := 0
			for t in data["terrain"]:
				if not (str(t) in gen.BLOCKED):
					walkable += 1
			if walkable == 0:
				continue
			var major := 0
			var keys := {}
			for s in data["structures"]:
				var key := str(s["key"])
				var info: Dictionary = gen.STRUCTURES[key]
				if _is_major(info):
					major += int(s["w"]) * int(s["h"])
					keys[key] = int(keys.get(key, 0)) + 1
			var coverage := float(major) / float(walkable)
			bio["chunks"] = int(bio["chunks"]) + 1
			bio["walkable"] = int(bio["walkable"]) + walkable
			bio["major"] = int(bio["major"]) + major
			if coverage > float(bio["max"]):
				bio["max"] = coverage
				bio["worst_seed"] = seed_value
				bio["worst_coord"] = coord
			if coverage > BUDGET:
				bio["over"] = int(bio["over"]) + 1
			examples.append({
				"seed": seed_value, "biome": biome_id, "chunk": coord,
				"walkable": walkable, "major": major, "coverage": coverage,
				"keys": keys,
			})


func _is_major(info: Dictionary) -> bool:
	# Major = 3x3+ collision footprint, a piece assembly, or a rendered width
	# of at least four tiles. Medium 2x2 landforms (mesa, iceberg, coral spire,
	# geyser) stay outside the budget.
	if info.has("pieces"):
		return true
	var w := int(info.get("w", 1))
	var h := int(info.get("h", 1))
	if w * h >= 9:
		return true
	var scale := float(info.get("sprite_scale", 1.0))
	return float(w) * scale >= 4.0


func _formula(total_chunks: int) -> Array:
	# Use the measured mean walkable area per chunk, then solve the budget for
	# the common footprints. Collision area is the spec metric ("occupy
	# walkable cells"); the visual envelope adds the allowed one-tile overhang
	# and is the stricter readability number.
	var lines: Array = []
	var w_avg := 256.0 * 0.68
	if not examples.is_empty():
		var sum := 0
		for e in examples:
			sum += int(e["walkable"])
		w_avg = float(sum) / float(examples.size())
	var massif := int(floor(BUDGET * w_avg / 16.0))
	var crater := int(floor(BUDGET * w_avg / 9.0))
	var ridge := int(floor(BUDGET * w_avg / 4.0))
	var massif_v := int(floor(BUDGET * w_avg / _eff_area(4, 4)))
	var crater_v := int(floor(BUDGET * w_avg / _eff_area(3, 3)))
	var ridge_v := int(floor(BUDGET * w_avg / _eff_area(2, 2)))
	lines.append("W_walk = measured walkable cells per 16x16 chunk (mean %.0f here)." % w_avg)
	lines.append("Budget: sum(w*h of major landforms) <= %.2f * W_walk." % BUDGET)
	lines.append("Max counts at this W_walk: 4x4 massif/volcano = %d · 3x3 crater/outpost = %d · 2x2 range = %d" % [
		massif, crater, ridge
	])
	lines.append("Stricter visual-envelope variant, A_eff=(w+2)*(h+2) for <=1 tile overhang: %d · %d · %d" % [
		massif_v, crater_v, ridge_v
	])
	lines.append("Placement rule: draw a major landform only while the chunk's accumulated")
	lines.append("footprint stays <= 0.25*W_walk; otherwise fall back to a medium feature or props.")
	lines.append("Sparse chunks (low W_walk) must use medium 2x2 features, not one oversized landmark.")
	lines.append("Equivalent per-cell probability: p_major = max_landforms / placement_slots.")
	return lines


func _eff_area(w: int, h: int) -> float:
	return (float(w) + 2.0 * OVERHANG) * (float(h) + 2.0 * OVERHANG)


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
