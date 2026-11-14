extends SceneTree

# A3 — small-island / pinhole metric.
#
# Counts 1-2 cell water bodies ("pinholes") and 1-2 cell land specks ("islets")
# in the real chunk output. The board asks for 1-2-tile water holes per chunk
# across 50 seeds so water coalescing can be tuned against numbers instead of
# eyeballing the map.
#
# How the count stays seam-safe
# -----------------------------
# Chunks are generated through the normal path (`_get_chunk()` -> shaped raw
# terrain -> `_smooth_cell()` -> `_carve_ridges()`), then stitched into one
# 8x8-chunk window. Components are 4-connected over that window, so a 2-cell
# pond split by a chunk seam is counted once, not twice. Components that touch
# the *outside* of the window are ignored because their true size is unknown;
# every other 1-2 cell component is a closed pinhole/islet.
#
# Run:
#   godot --headless --path . --script tools/audit_islands.gd
#   godot --headless --path . --script tools/audit_islands.gd -- --seeds=50 --chunks=8
#   godot --headless --path . --script tools/audit_islands.gd -- --biomes=temperate,methane,carbon
#   godot --headless --path . --script tools/audit_islands.gd -- --gate --max=0.50
#
# Default exit is 0 (measurement). `--gate` exits 1 when mean pinholes per
# chunk exceeds `--max` (default 0.50), so a coalescing change can be enforced.

const BIOME_DEFAULT := "temperate,methane,carbon,ocean"
const WATER_SHAPER := preload("res://scripts/water_shaper.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var gen: Node2D
var key_mode := "water"
var shape_arg := ""
var dump_spec := ""


func _initialize() -> void:
	var args := _parse_args()
	var script: Script = load("res://scripts/map_generator.gd")
	if script == null:
		print("FAIL: could not load map_generator.gd")
		quit(1)
		return
	gen = script.new()
	var seeds := int(args.get("seeds", 50))
	var seed0 := int(args.get("seed0", 1000))
	var step := int(args.get("step", 137))
	var grid := int(args.get("chunks", 8))
	var gate := bool(args.get("gate", false))
	key_mode = str(args.get("keys", "water"))
	dump_spec = str(args.get("dump", ""))
	shape_arg = str(args.get("shape", ""))
	if shape_arg != "":
		var parts: PackedStringArray = shape_arg.split(",")
		if parts.size() == 4:
			WATER_SHAPER.configure(
				int(parts[0]), int(parts[1]), float(parts[2]), float(parts[3])
			)
	var max_holes := float(args.get("max", 0.50))
	var biome_ids: Array = str(args.get("biomes", BIOME_DEFAULT)).split(",")

	print("ISLAND audit: %d seeds x %d biomes x %dx%d chunks" % [
		seeds, biome_ids.size(), grid, grid
	])
	var total_chunks := 0
	var total_holes := 0
	var total_specks := 0
	for biome_id in biome_ids:
		var id := str(biome_id).strip_edges()
		if id == "":
			continue
		var idx := _biome_index(id)
		if idx < 0:
			print("  SKIP unknown biome '%s'" % id)
			continue
		var bio := {
			"seeds": 0, "chunks": 0,
			"h1": 0, "h2": 0, "holes": 0,
			"s1": 0, "s2": 0, "specks": 0,
			"worst_holes": 0, "worst_seed": -1, "worst_chunk": Vector2i.ZERO,
			"hist": {}, "hole_types": {},
		}
		for i in range(seeds):
			var seed_value := seed0 + i * step
			_measure_seed(id, idx, seed_value, grid, bio)
		total_chunks += int(bio["chunks"])
		total_holes += int(bio["holes"])
		total_specks += int(bio["specks"])
		var per_chunk := 0.0
		if int(bio["chunks"]) > 0:
			per_chunk = float(bio["holes"]) / float(bio["chunks"])
		print("  %-9s seeds=%-3d chunks=%-5d holes=%-5d (1c=%-4d 2c=%-4d) per_chunk=%.3f  islets=%-5d (1c=%-4d 2c=%-4d) worst_chunk=%d seed=%d chunk=%s" % [
			id, int(bio["seeds"]), int(bio["chunks"]),
			int(bio["holes"]), int(bio["h1"]), int(bio["h2"]), per_chunk,
			int(bio["specks"]), int(bio["s1"]), int(bio["s2"]),
			int(bio["worst_holes"]), int(bio["worst_seed"]), str(bio["worst_chunk"])
		])
		var hist: Dictionary = bio["hist"]
		print("            per-chunk histogram: 0=%d 1=%d 2=%d 3-5=%d 6+=%d   hole tiles=%s" % [
			int(hist.get("0", 0)), int(hist.get("1", 0)), int(hist.get("2", 0)),
			int(hist.get("3-5", 0)), int(hist.get("6+", 0)), str(bio["hole_types"])
		])

	var mean := 0.0
	if total_chunks > 0:
		mean = float(total_holes) / float(total_chunks)
	print("TOTAL chunks=%d pinholes=%d per_chunk=%.3f islets=%d" % [
		total_chunks, total_holes, mean, total_specks
	])
	if gate and mean > max_holes:
		print("ISLAND FAIL: %.3f pinholes/chunk over the %.3f limit" % [mean, max_holes])
		quit(1)
	else:
		print("ISLAND OK: %.3f pinholes/chunk (limit %.3f)" % [mean, max_holes])
		quit(0)


func _measure_seed(biome_id: String, idx: int, seed_value: int, grid: int, bio: Dictionary) -> void:
	gen.seed_value = seed_value
	gen.biome_index = idx
	gen.chunks.clear()
	gen.rng.seed = seed_value
	gen._init_noise()
	var b: Dictionary = gen.BIOMES[idx]
	var water := _water_keys(b)
	if key_mode == "all":
		# Measurement override: shape every water material, not only the
		# named `water` key. Tests whether the CA can clean shallow pinholes.
		gen.water_shape_keys = water.duplicate()
	var chunk_size: int = int(gen.CHUNK)
	var span: int = grid * chunk_size
	var water_mask := PackedByteArray()
	water_mask.resize(span * span)
	var terrain_keys := PackedStringArray()
	terrain_keys.resize(span * span)
	for cy in range(grid):
		for cx in range(grid):
			var coord := Vector2i(cx, cy)
			var data: Dictionary = gen._get_chunk(coord)
			for ly in range(gen.CHUNK):
				for lx in range(gen.CHUNK):
					var t := str(data["terrain"][ly * gen.CHUNK + lx])
					var wx: int = cx * chunk_size + lx
					var wy: int = cy * chunk_size + ly
					water_mask[wy * span + wx] = 1 if water.has(t) else 0
					terrain_keys[wy * span + wx] = t

	var water_seen := PackedByteArray()
	water_seen.resize(span * span)
	var land_seen := PackedByteArray()
	land_seen.resize(span * span)
	var seed_holes := 0
	var seed_specks := 0
	var chunk_holes := {}
	var chunk_specks := {}
	for y in range(span):
		for x in range(span):
			var i: int = y * span + x
			var wet := water_mask[i] == 1
			var seen := water_seen if wet else land_seen
			if seen[i] == 1:
				continue
			var comp := _collect(x, y, span, wet, water_mask, seen)
			var size: int = int(comp["size"])
			if int(size) > 2 or bool(comp["touches_edge"]) or bool(comp["touches_outside"]):
				continue
			var first: Vector2i = comp["first"]
			var chunk := Vector2i(first.x / chunk_size, first.y / chunk_size)
			var key := "%d,%d" % [chunk.x, chunk.y]
			if wet:
				if int(size) == 1:
					bio["h1"] = int(bio["h1"]) + 1
				else:
					bio["h2"] = int(bio["h2"]) + 1
				bio["holes"] = int(bio["holes"]) + 1
				seed_holes += 1
				chunk_holes[key] = int(chunk_holes.get(key, 0)) + 1
				var tk: String = terrain_keys[i]
				bio["hole_types"][tk] = int(bio["hole_types"].get(tk, 0)) + 1
				if dump_spec != "":
					var spec := "%d,%d,%d" % [seed_value, chunk.x, chunk.y]
					if spec == dump_spec:
						_dump_hole(span, terrain_keys, first, size, chunk_size)
			else:
				if int(size) == 1:
					bio["s1"] = int(bio["s1"]) + 1
				else:
					bio["s2"] = int(bio["s2"]) + 1
				bio["specks"] = int(bio["specks"]) + 1
				seed_specks += 1
				chunk_specks[key] = int(chunk_specks.get(key, 0)) + 1

	bio["seeds"] = int(bio["seeds"]) + 1
	bio["chunks"] = int(bio["chunks"]) + grid * grid
	var hist: Dictionary = bio["hist"]
	for cy in range(grid):
		for cx in range(grid):
			var ck := "%d,%d" % [cx, cy]
			var n := int(chunk_holes.get(ck, 0))
			var bucket := "0" if n == 0 else ("1" if n == 1 else ("2" if n == 2 else ("3-5" if n <= 5 else "6+")))
			hist[bucket] = int(hist.get(bucket, 0)) + 1
			if n > int(bio["worst_holes"]):
				bio["worst_holes"] = n
				bio["worst_seed"] = seed_value
				bio["worst_chunk"] = Vector2i(cx, cy)


func _collect(x: int, y: int, span: int, wet: bool, mask: PackedByteArray, seen: PackedByteArray) -> Dictionary:
	var want: int = 1 if wet else 0
	var q: Array[Vector2i] = [Vector2i(x, y)]
	seen[y * span + x] = 1
	var head := 0
	var size := 0
	var touches_edge := false
	var first := Vector2i(x, y)
	var cells: Array[Vector2i] = []
	while head < q.size():
		var cur := q[head]
		head += 1
		size += 1
		cells.append(cur)
		if cur.x == 0 or cur.y == 0 or cur.x == span - 1 or cur.y == span - 1:
			touches_edge = true
		for d in DIRS:
			var n: Vector2i = cur + d
			if n.x < 0 or n.y < 0 or n.x >= span or n.y >= span:
				continue
			var ni := n.y * span + n.x
			if seen[ni] == 1 or int(mask[ni]) != want:
				continue
			seen[ni] = 1
			q.append(n)
	# A 1-2 cell body that is diagonally adjacent to more water is not a closed
	# hole; it is a corner nub on the coast. Count only bodies whose full
	# 8-neighbourhood outside the component is land, so the metric matches what
	# the board calls a pinhole.
	var in_comp := {}
	for c in cells:
		in_comp[c] = true
	var touches_outside := false
	for c in cells:
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var nn := c + Vector2i(ox, oy)
				if nn.x < 0 or nn.y < 0 or nn.x >= span or nn.y >= span:
					continue
				var ni2 := nn.y * span + nn.x
				if int(mask[ni2]) == want and not in_comp.has(nn):
					touches_outside = true
	return {
		"size": size, "touches_edge": touches_edge,
		"touches_outside": touches_outside, "first": first,
	}



func _code(t: String) -> String:
	var s := t.get_slice("/", 1)
	match s:
		"water_shallow":
			return "SH"
		"water_deep":
			return "DP"
		"water_shelf":
			return "SF"
		"reef":
			return "RE"
		"beach":
			return "BE"
		"rock":
			return "RO"
		"regolith":
			return "RG"
	return s.substr(0, 2)


func _dump_hole(span: int, keys: PackedStringArray, first: Vector2i, size: int, chunk_size: int) -> void:
	print("  DUMP hole size=%d at (%d,%d) chunk=(%d,%d)" % [
		size, first.x, first.y, first.x / chunk_size, first.y / chunk_size
	])
	for y in range(first.y - 2, first.y + 3):
		var row := ""
		for x in range(first.x - 2, first.x + 3):
			if x < 0 or y < 0 or x >= span or y >= span:
				row += " ?? "
				continue
			var t: String = keys[y * span + x]
			row += "%3s " % _code(t)
		print("    %s" % row)


func _water_keys(b: Dictionary) -> Dictionary:
	# Raw terrain has no depth bands; the render pass adds those. Count every
	# key in this biome's palette whose name says "water" (ocean uses
	# water_shallow as `base`) plus the named water tile. Lava is deliberately
	# excluded: it is a hazard field, not a coastline.
	var keys := {}
	for field in ["base", "base_alt", "detail", "water"]:
		var key := str(b.get(field, ""))
		if key.contains("water"):
			keys[key] = true
	for variant in b.get("base_variants", []):
		var key := str(variant)
		if key.contains("water"):
			keys[key] = true
	return keys


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
