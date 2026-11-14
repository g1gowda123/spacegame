extends RefCounted

## Deterministic water-body shaping for the chunked surface generator (agent b).
##
## Why this exists
## -------------
## `_sample_terrain()` decides water from a thresholded fBm field plus two
## noise layers: `shore_noise` (frequency 0.14) jitters the shoreline per cell
## and `rough_noise` (frequency 0.045) scales that jitter so some coast reads
## clean and other stretches fray. `_smooth_cell()` then runs a 3x3 vote, which
## removes a *completely* isolated water cell and floods a bay that is already
## 7/8 water. Neither pass can see a 2-cell pond, a 1-cell sand speck, or a
## one-tile spur, so lake-heavy archetypes end up as fields of pinholes and
## islands. On a 64 px tile that is the staircase coast in the debt table
## (docs/TASKS.md item 2).
##
## What this does
## --------------
## A binary cellular automaton over the water mask:
##   * land -> water when at least `wet` of the window is water
##   * water -> land when at most `dry` of the window is water
## With the shipped 3x3 window, a single pass removes 1-2 cell bodies (a lone
## water cell scores 1/9=0.11, a 2x2 body 4/9=0.44) while a straight coastline
## is a fixed point (a land cell on it scores 4/9=0.44 > 0.40, the water cell
## 5/9=0.56 < 0.60, so the coast does not creep outward).
##
## Why a cellular automaton and not a component-size filter
## -------------------------------------------------------
## A component filter ("erase water bodies smaller than N cells") measures
## better on paper (see docs/WORKLOG.md) but it is NOT seam-safe: a 2-cell pond
## touching one chunk window's border is kept there (its true size is unknown)
## and removed in a window where it is interior. Because a chunk's raw terrain
## also feeds its neighbours' transition choices, that disagreement shows up as
## a shore tile next to land and a visible line along the chunk edge. A CA is
## strictly local, so every chunk computes the same value for the cells it
## shares with its neighbour as long as the raw halo is `pad()` cells wide.
##
## Cost: the raw halo grows from 1 to `pad()` cells per chunk plus N compares
## per cell per pass. Cheap enough for a 640x360 WebGL target.

## Neighbourhood radius for the vote (1 = 3x3 window).
static var radius: int = 1
## Vote passes. One pass is enough to kill 1-2 cell bodies; a second pass also
## eats 1-cell spurs but starts eroding land bridges.
static var passes: int = 1
## Land becomes water at or above this wet fraction.
static var wet: float = 0.60
## Water becomes land at or below this wet fraction.
static var dry: float = 0.40


## Extra raw cells the caller must sample around the chunk: one more than the
## furthest cell the vote reads (`_smooth_cell` then reads 1 cell further).
static func pad() -> int:
	return radius * passes + 1


## Tuning override used by `--water=<radius>,<passes>,<wet>,<dry>` on the map
## scene, so parameters can be compared on identical seeds instead of editing
## constants. Not used by the game; the defaults are the shipped values.
static func configure(r: int, p: int, wet_frac: float, dry_frac: float) -> void:
	radius = maxi(1, r)
	passes = maxi(1, p)
	wet = clampf(wet_frac, 0.34, 0.95)
	dry = clampf(dry_frac, 0.05, 0.60)


## Tiles that count as open water for this biome.
##
## Only biomes with a shore ring *and* a named water tile are shaped. A shore
## ring is exactly the case where the coast is a rendered seam
## (`_render_terrain_world` swaps the edge cell to the shore tile), so it is the
## case that reads as a staircase. Two exclusions are deliberate:
##
## * Lava in the caldera profile (`volcanic`, `sulfur`, `obsidian`) is authored
##   by `_smooth_cell`'s volcanic exclusion; a lava lake is a hazard field, not
##   a coastline.
## * Ocean-type biomes keep open water in `base`/`detail` and build land out of
##   beach/reef specks. `_smooth_cell` already resolves an isolated land speck
##   to `base` (= water), so a vote that removes specks first only moves the
##   same work one stage earlier and measurably *increases* water pinholes
##   (10 -> 17 tiny holes on seed 26758). Ocean is an island field, not a lake
##   district.
static func water_keys(biome: Dictionary) -> Dictionary:
	var keys := {}
	if not bool(biome.get("shore_ring", false)):
		return keys
	var water := str(biome.get("water", ""))
	if water != "":
		keys[water] = true
	return keys


## Rewrite `raw` (a `pad()`-padded square of `_sample_terrain()` keys) in place
## so small water bodies and small land specks are merged into their
## surroundings. Returns the number of cells that changed key.
static func apply(raw: Array, pad: int, biome: Dictionary, keys: Dictionary) -> int:
	if keys.is_empty() or pad < radius * passes + 1:
		return 0
	var mask := PackedByteArray()
	mask.resize(pad * pad)
	for i in range(pad * pad):
		mask[i] = 1 if keys.has(str(raw[i])) else 0
	var shaped := _vote(mask, pad, pad)

	var water_fill := str(biome.get("water", ""))
	if water_fill == "":
		water_fill = str(biome.get("base", ""))
	var land_fill := str(biome.get("base", ""))
	if keys.has(land_fill):
		# Ocean-type biome: the base material is water, so a filled-in hole
		# inside an island becomes its shore/rock material instead.
		land_fill = str(biome.get("shore", ""))
		if land_fill == "":
			land_fill = str(biome.get("rock", ""))

	var changed := 0
	for y in range(radius, pad - radius):
		for x in range(radius, pad - radius):
			var i := y * pad + x
			var was_wet := mask[i] == 1
			var is_wet := shaped[i] == 1
			if was_wet == is_wet:
				continue
			raw[i] = water_fill if is_wet else land_fill
			changed += 1
	return changed


## One or more vote passes over a square mask. Only cells with a complete
## neighbourhood are written, which is what makes the result independent of
## where the window starts.
static func _vote(mask: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var cur := mask.duplicate()
	var window := float((2 * radius + 1) * (2 * radius + 1))
	for _pass in passes:
		var nxt := cur.duplicate()
		for y in range(radius, h - radius):
			for x in range(radius, w - radius):
				var wet_count := 0
				for oy in range(-radius, radius + 1):
					var row := (y + oy) * w + x
					for ox in range(-radius, radius + 1):
						wet_count += int(cur[row + ox])
				var frac := float(wet_count) / window
				var i := y * w + x
				if int(cur[i]) == 0:
					if frac >= wet:
						nxt[i] = 1
				elif frac <= dry:
					nxt[i] = 0
		cur = nxt
	return cur
