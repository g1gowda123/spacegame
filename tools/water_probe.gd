extends SceneTree

# Water-coalescing + diagonal-shore review probe (agent b).
#
# Measures water/land fragmentation on the REAL generator (same noise, same
# _sample_terrain/_pick_terrain and _smooth_cell path as the game), then
# compares candidate coalescing operators on the resulting binary mask.
# With --diagcheck it also builds the real TileSet and reports which tile the
# renderer actually selects for each coastal cell.
#
# Run:
#   godot --headless --path . --script tools/water_probe.gd -- --seed=26758 --biome=temperate --diagcheck
#   godot --headless --path . --script tools/water_probe.gd -- --seeds=26758,29607 --biome=ocean --png
#   # same seed through the pre-coalescing generator, for an A/B baseline:
#   godot --headless --path . --script tools/water_probe.gd -- --seed=26758 --biome=temperate --legacy
#
# Output: one JSON line per seed plus optional 1 px/cell preview PNGs.

const OUT_DIR := "/tmp/opencode"
const WATER_SHAPER := preload("res://scripts/water_shaper.gd")

var gen: Node2D
var biome: Dictionary
var chunk_n := 8  # 8x8 chunks = 128x128 world cells
var water_keys: Dictionary = {}


func _initialize() -> void:
	var args := _parse_args()
	var script: Script = load("res://scripts/map_generator.gd")
	if script == null:
		print("FAIL: could not load map_generator.gd")
		quit(1)
		return
	gen = script.new()
	var seeds: Array = args.get("seeds", [26758, 29607, 43255])
	var biome_id: String = str(args.get("biome", "temperate"))
	var build_tiles := bool(args.get("diagcheck", false))
	chunk_n = int(args.get("chunks", 8))
	if args.has("shape"):
		# --shape=<radius>,<passes>,<wet>,<dry>; same knobs as the map scene's
		# --water= flag so probe numbers and captures use one implementation.
		var parts: PackedStringArray = str(args["shape"]).split(",")
		if parts.size() == 4:
			WATER_SHAPER.configure(
				int(parts[0]), int(parts[1]), float(parts[2]), float(parts[3])
			)
	if build_tiles:
		gen._build_tileset()
	for s in seeds:
		run(int(s), biome_id, bool(args.get("png", false)), build_tiles, bool(args.get("legacy", false)))
	quit(0)


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		var key := body if eq < 0 else body.substr(0, eq)
		var val := "" if eq < 0 else body.substr(eq + 1)
		if key == "seed":
			out["seeds"] = [int(val)]
		elif key == "seeds":
			var arr: Array = []
			for p in val.split(","):
				arr.append(int(p))
			out["seeds"] = arr
		elif key == "biome":
			out["biome"] = val
		elif key == "png":
			out["png"] = true
		elif key == "diagcheck":
			out["diagcheck"] = true
		elif key == "legacy":
			out["legacy"] = true
		elif key == "chunks":
			out["chunks"] = int(val)
		elif key == "shape":
			out["shape"] = val
	return out


func run(seed_value: int, biome_id: String, save_png: bool, diagcheck: bool, legacy: bool) -> void:
	gen.seed_value = seed_value
	var idx := 0
	for i in gen.BIOMES.size():
		if str(gen.BIOMES[i]["id"]) == biome_id:
			idx = i
			break
	gen.biome_index = idx
	biome = gen.BIOMES[idx]
	gen.water_shaping = not legacy
	gen._init_noise()
	water_keys = _water_keys_for(biome)

	var w: int = chunk_n * int(gen.CHUNK)
	var h: int = chunk_n * int(gen.CHUNK)
	var grid: Array = []
	grid.resize(w * h)
	for cy in chunk_n:
		for cx in chunk_n:
			var data: Dictionary = gen._generate_chunk(Vector2i(cx, cy))
			var arr: Array = data["terrain"]
			for ly in gen.CHUNK:
				for lx in gen.CHUNK:
					var tile := str(arr[ly * gen.CHUNK + lx])
					grid[(cy * gen.CHUNK + ly) * w + cx * gen.CHUNK + lx] = (
						1 if water_keys.has(tile) else 0
					)

	var base := analyze(grid, w, h, "baseline")
	var candidates := {
		"r1_p1_h60_l40": coalesce_mean(grid, w, h, 1, 1, 0.60, 0.40),
		"r1_p2_h60_l40": coalesce_mean(grid, w, h, 1, 2, 0.60, 0.40),
		"r1_p1_h58_l42": coalesce_mean(grid, w, h, 1, 1, 0.58, 0.42),
		"r2_p1_h58_l42": coalesce_mean(grid, w, h, 2, 1, 0.58, 0.42),
		"compMin_then_r1": coalesce_component_min(grid, w, h, 6, 4),
	}

	var result := {
		"seed": seed_value,
		"biome": biome_id,
		"archetype": gen.archetype_name,
		"water_keys": water_keys.keys(),
		"baseline": base,
		"candidates": {},
	}
	for name in candidates.keys():
		result["candidates"][name] = analyze(candidates[name], w, h, name)

	if diagcheck:
		result["diagcheck"] = diagcheck_real(w, h)

	print("JSON " + JSON.stringify(result))

	if save_png:
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
		_save_mask(grid, w, h, "%s/probe_%s_%d_baseline.png" % [OUT_DIR, biome_id, seed_value])
		for name in candidates.keys():
			_save_mask(
				candidates[name], w, h,
				"%s/probe_%s_%d_%s.png" % [OUT_DIR, biome_id, seed_value, name]
			)


func _water_keys_for(b: Dictionary) -> Dictionary:
	# Measurement only: what counts as water in the *rendered* world. This is
	# deliberately wider than `WaterShaper.water_keys()`, because ocean-style
	# biomes (water stored in base/detail, land built from beach/reef) are
	# measured even though they are not shaped.
	var keys := {}
	var water := str(b.get("water", ""))
	if water != "":
		keys[water] = true
	elif str(b.get("profile", "")) == "ocean":
		keys[str(b.get("base", ""))] = true
		keys[str(b.get("detail", ""))] = true
	return keys


func jag_profile(grid: Array, w: int, h: int) -> Dictionary:
	# rough_noise is the low-frequency amplitude mask: negative stretches are
	# meant to stay clean, positive stretches are meant to fray. If coalescing
	# flattens both to the same value it is fighting the shoreline mask.
	var lo_coast := 0
	var lo_frayed := 0
	var hi_coast := 0
	var hi_frayed := 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if int(grid[y * w + x]) != 0:
				continue
			var edges := 0
			edges += int(grid[(y - 1) * w + x])
			edges += int(grid[(y + 1) * w + x])
			edges += int(grid[y * w + x - 1])
			edges += int(grid[y * w + x + 1])
			if edges == 0:
				continue
			var frayed := edges >= 2
			if gen.rough_noise.get_noise_2d(float(x), float(y)) >= 0.0:
				hi_coast += 1
				if frayed:
					hi_frayed += 1
			else:
				lo_coast += 1
				if frayed:
					lo_frayed += 1
	var lo := float(lo_frayed) / maxf(1.0, float(lo_coast))
	var hi := float(hi_frayed) / maxf(1.0, float(hi_coast))
	return {
		"rough_lo_frayed": snappedf(lo, 0.001),
		"rough_hi_frayed": snappedf(hi, 0.001),
		# Positive = the frayed stretch really is fringier than the clean one.
		"personality_gap": snappedf(hi - lo, 0.001),
	}


func diagcheck_real(w: int, h: int) -> Dictionary:
	# Walk the same render path as _render_window: t is the *rendered*
	# material (shore ring applied), then _transition_choice picks a key.
	var prio: Dictionary = gen._priority_map(biome)
	var coastal := 0
	var single_corner := 0
	var diag_selected := 0
	var diag_by_material := {}
	var diag_by_pair := {}
	var missing_by_material := {}
	var missing_by_pair := {}
	var missing_by_key := {}
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var t: String = gen._render_terrain_world(x, y)
			if water_keys.has(t):
				continue
			var edges := 0
			for d in gen.EDGE_DIRS:
				if water_keys.has(gen._render_terrain_world(x + d.x, y + d.y)):
					edges += 1
			var corners := 0
			for d in gen.CORNER_DIRS:
				if water_keys.has(gen._render_terrain_world(x + d.x, y + d.y)):
					corners += 1
			if edges == 0 and corners == 0:
				continue
			coastal += 1
			if edges != 0 or corners != 1:
				continue
			single_corner += 1
			var key: String = gen._transition_choice(t, x, y, prio)
			if key.begins_with("diag|"):
				diag_selected += 1
				diag_by_material[t] = int(diag_by_material.get(t, 0)) + 1
				# diag|<a>|<b>|<corner> -> the material pair that was resolved.
				var parts := key.split("|")
				if parts.size() >= 3:
					var pair := str(parts[1]) + "|" + str(parts[2])
					diag_by_pair[pair] = int(diag_by_pair.get(pair, 0)) + 1
			else:
				missing_by_material[t] = int(missing_by_material.get(t, 0)) + 1
				# Attribute the miss to every candidate pair that fell back to a
				# right-angle tile instead of a diagonal, i.e. every pair the
				# renderer had to step over to find a usable key.
				for pair in _non_diag_pair_keys(t, x, y):
					missing_by_pair[pair] = int(missing_by_pair.get(pair, 0)) + 1
				missing_by_key[key] = int(missing_by_key.get(key, 0)) + 1
	return {
		"coastal_cells": coastal,
		"single_corner_cells": single_corner,
		"diag_selected_cells": diag_selected,
		"diag_selected_by_material": diag_by_material,
		"diag_selected_by_pair": diag_by_pair,
		"diag_missing_by_material": missing_by_material,
		"diag_missing_by_pair": missing_by_pair,
		"diag_missing_by_key": missing_by_key,
	}


func _non_diag_pair_keys(t: String, x: int, y: int) -> Array:
	# Neighbouring materials that have a transition table entry but resolve to
	# something other than a diagonal tile for this corner pattern. A pair with
	# no art at all and a pair with only a right-angle fallback are both "not
	# diagonal"; only the latter shows up as a corner in the render.
	# Measurement only; the render path is untouched.
	var out: Array = []
	var seen := {}
	var dirs: Array[Vector2i] = []
	dirs.append_array(gen.EDGE_DIRS)
	dirs.append_array(gen.CORNER_DIRS)
	for d in dirs:
		var n: String = gen._render_terrain_world(x + d.x, y + d.y)
		if n == t or seen.has(n):
			continue
		seen[n] = true
		var pair_key := t + "|" + n
		if not gen.transition_pairs.has(pair_key):
			continue
		var info: Dictionary = gen.transition_pairs[pair_key]
		var data: Dictionary = gen._pattern_data(t, n, x, y, info)
		var k := str(data.get("key", ""))
		if k == "" or not k.begins_with("diag|"):
			out.append(pair_key)
	return out


func coalesce_mean(grid: Array, w: int, h: int, radius: int, passes: int, hi: float, lo: float) -> Array:
	var cur := grid.duplicate()
	for _p in passes:
		var nxt := cur.duplicate()
		for y in h:
			for x in w:
				var wet := 0
				var total := 0
				for oy in range(-radius, radius + 1):
					var yy := y + oy
					if yy < 0 or yy >= h:
						continue
					for ox in range(-radius, radius + 1):
						var xx := x + ox
						if xx < 0 or xx >= w:
							continue
						wet += int(cur[yy * w + xx])
						total += 1
				var frac := float(wet) / float(total)
				var i := y * w + x
				if int(cur[i]) == 0 and frac >= hi:
					nxt[i] = 1
				elif int(cur[i]) == 1 and frac <= lo:
					nxt[i] = 0
		cur = nxt
	return cur


func coalesce_component_min(grid: Array, w: int, h: int, min_water: int, min_land: int) -> Array:
	var cur := grid.duplicate()
	# Water components smaller than min_water become land; land islands
	# smaller than min_land become water. Border-touching components are left
	# alone because their true size is outside the measured window.
	for target in [1, 0]:
		var seen := {}
		for y in h:
			for x in w:
				var i := y * w + x
				if seen.has(i) or int(cur[i]) != target:
					continue
				var stack: Array = [i]
				var comp: Array = []
				var touch := false
				seen[i] = true
				while not stack.is_empty():
					var c: int = stack.pop_back()
					comp.append(c)
					var cx := c % w
					var cy := c / w
					if cx == 0 or cy == 0 or cx == w - 1 or cy == h - 1:
						touch = true
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nx: int = cx + int(d.x)
						var ny: int = cy + int(d.y)
						if nx < 0 or ny < 0 or nx >= w or ny >= h:
							continue
						var ni := ny * w + nx
						if not seen.has(ni) and int(cur[ni]) == target:
							seen[ni] = true
							stack.append(ni)
				if touch:
					continue
				var limit := min_water if target == 1 else min_land
				if comp.size() < limit:
					for c in comp:
						cur[c] = 1 - target
	# One gentle pass to round the new edges without re-fragmenting.
	return coalesce_mean(cur, w, h, 1, 1, 0.60, 0.40)


func analyze(grid: Array, w: int, h: int, label: String) -> Dictionary:
	var water := 0
	var component_sizes: Array = []
	var land_sizes: Array = []
	for target in [1, 0]:
		var seen := {}
		for y in h:
			for x in w:
				var i := y * w + x
				if seen.has(i) or int(grid[i]) != target:
					continue
				var stack: Array = [i]
				var size := 0
				var touch := false
				seen[i] = true
				while not stack.is_empty():
					var c: int = stack.pop_back()
					size += 1
					var cx := c % w
					var cy := c / w
					if cx == 0 or cy == 0 or cx == w - 1 or cy == h - 1:
						touch = true
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nx: int = cx + int(d.x)
						var ny: int = cy + int(d.y)
						if nx < 0 or ny < 0 or nx >= w or ny >= h:
							continue
						var ni := ny * w + nx
						if not seen.has(ni) and int(grid[ni]) == target:
							seen[ni] = true
							stack.append(ni)
				if target == 1:
					water += size
				if not touch:
					if target == 1:
						component_sizes.append(size)
					else:
						land_sizes.append(size)

	component_sizes.sort()
	land_sizes.sort()
	var tiny_water := 0
	var tiny_water_cells := 0
	for s in component_sizes:
		if s <= 2:
			tiny_water += 1
			tiny_water_cells += s
	var tiny_land := 0
	var tiny_land_cells := 0
	for s in land_sizes:
		if s <= 2:
			tiny_land += 1
			tiny_land_cells += s

	# Exact trigger for the hand-authored 45-degree split on the RAW mask:
	# the cell is land, zero orthogonal water neighbours, exactly one diagonal
	# water neighbour.
	var diag_cells := 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if int(grid[y * w + x]) != 0:
				continue
			var edges := 0
			edges += int(grid[(y - 1) * w + x])
			edges += int(grid[(y + 1) * w + x])
			edges += int(grid[y * w + x - 1])
			edges += int(grid[y * w + x + 1])
			if edges != 0:
				continue
			var corners := 0
			corners += int(grid[(y - 1) * w + x - 1])
			corners += int(grid[(y - 1) * w + x + 1])
			corners += int(grid[(y + 1) * w + x + 1])
			corners += int(grid[(y + 1) * w + x - 1])
			if corners == 1:
				diag_cells += 1

	# Perimeter / area: a simple roughness proxy. Coalescing should reduce it,
	# but a collapse toward a rectangle is a fail.
	var perimeter := 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if int(grid[y * w + x]) != 1:
				continue
			if int(grid[(y - 1) * w + x]) == 0:
				perimeter += 1
			if int(grid[(y + 1) * w + x]) == 0:
				perimeter += 1
			if int(grid[y * w + x - 1]) == 0:
				perimeter += 1
			if int(grid[y * w + x + 1]) == 0:
				perimeter += 1

	var out := {
		"label": label,
		"water_frac": snappedf(float(water) / float(w * h), 0.001),
		"water_components": component_sizes.size(),
		"land_components": land_sizes.size(),
		"tiny_water_comps_le2": tiny_water,
		"tiny_water_cells": tiny_water_cells,
		"tiny_land_islands_le2": tiny_land,
		"tiny_land_cells": tiny_land_cells,
		"diag_trigger_cells": diag_cells,
		"perimeter": perimeter,
		"perimeter_per_area": snappedf(float(perimeter) / maxf(1.0, float(water)), 0.0001),
	}
	out.merge(jag_profile(grid, w, h))
	return out


func _save_mask(grid: Array, w: int, h: int, path: String) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var wet := int(grid[y * w + x]) == 1
			img.set_pixel(x, y, Color(0.12, 0.32, 0.42) if wet else Color(0.36, 0.42, 0.24))
	var err := img.save_png(path)
	print("png: %s err=%d" % [path, err])
