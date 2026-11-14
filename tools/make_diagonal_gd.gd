extends SceneTree

# Godot port of `tools/make_diagonal.py` (agent b).
#
# The Python tool is the canonical one, but this machine has no numpy/Pillow,
# so the missing shore pairs are composited here with the same maths: cut the
# cell on the named diagonal, lay water over that half, pull the 1 px land band
# toward the brightest water tone, darken the 1 px water edge by 0.72. Inputs
# and output stay palette-locked because both source tiles already are.
#
# Run:
#   godot --headless --path . --script tools/make_diagonal_gd.gd -- \
#     --land=assets/tilesets/temperate/beach.png \
#     --water=assets/tilesets/temperate/water_lake.png \
#     --outdir=assets/tilesets/transitions/diagonal/temperate_beach_temperate_water_lake
#
# The directory name must be `<land>_<water>` with slashes replaced by
# underscores, matching what `_build_tileset()` looks up.

const CORNERS := ["nw", "ne", "se", "sw"]


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			continue
		args[body.substr(0, eq)] = body.substr(eq + 1)
	for key in ["land", "water", "outdir"]:
		if not args.has(key):
			print("FAIL: missing --%s" % key)
			quit(1)
			return

	var land := _load(str(args["land"]))
	var water := _load(str(args["water"]))
	if land == null or water == null:
		quit(1)
		return
	if land.get_width() != water.get_width() or land.get_height() != water.get_height():
		print("FAIL: size mismatch")
		quit(1)
		return

	var outdir := str(args["outdir"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(outdir))
	var tiles: Array[Image] = []
	for corner in CORNERS:
		var img := _build(land, water, corner)
		var path := "%s/%s.png" % [outdir, corner]
		var err := img.save_png(path)
		if err != OK:
			print("FAIL: save %s err=%d" % [path, err])
			quit(1)
			return
		tiles.append(img)
	_preview(tiles, outdir)
	print("wrote %d tiles + preview in %s" % [tiles.size(), outdir])
	quit(0)


func _load(path: String) -> Image:
	var img := Image.load_from_file(path)
	if img == null:
		print("FAIL: could not load %s" % path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _build(land: Image, water: Image, corner: String) -> Image:
	var size := land.get_width()
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var wet := PackedByteArray()
	wet.resize(size * size)
	for y in size:
		for x in size:
			wet[y * size + x] = 1 if _is_wet(x, y, size, corner) else 0

	# Wet sand: the mean colour of the brightest 2 % of the water tile, so the
	# band picks up this pair's own light tone instead of a hard-coded colour.
	var sums: Array[float] = []
	for i in range(size * size):
		if wet[i] == 0:
			continue
		var wc := water.get_pixel(i % size, i / size)
		sums.append(wc.r + wc.g + wc.b)
	sums.sort()
	var keep := maxi(1, int(float(sums.size()) / 50.0))
	var cutoff := sums[sums.size() - keep] if sums.size() >= keep else 0.0
	var bright := Color(0, 0, 0)
	var counted := 0
	for y in size:
		for x in size:
			if wet[y * size + x] == 0:
				continue
			var col := water.get_pixel(x, y)
			if col.r + col.g + col.b < cutoff - 0.0001:
				continue
			bright.r += col.r
			bright.g += col.g
			bright.b += col.b
			counted += 1
	if counted > 0:
		bright.r /= float(counted)
		bright.g /= float(counted)
		bright.b /= float(counted)

	for y in size:
		for x in size:
			var i := y * size + x
			var col: Color
			if wet[i] == 1:
				col = water.get_pixel(x, y)
				if _has_neighbour(wet, x, y, size, 0):
					col = Color(col.r * 0.72, col.g * 0.72, col.b * 0.72, 1.0)
			else:
				col = land.get_pixel(x, y)
				if _has_neighbour(wet, x, y, size, 1):
					col = Color(
						col.r * 0.55 + bright.r * 0.45,
						col.g * 0.55 + bright.g * 0.45,
						col.b * 0.55 + bright.b * 0.45,
						1.0
					)
			col.a = 1.0
			out.set_pixel(x, y, col)
	return out


func _is_wet(x: int, y: int, size: int, corner: String) -> bool:
	match corner:
		"nw":
			return x + y < size - 1
		"se":
			return x + y > size - 1
		"ne":
			return y < x
		"sw":
			return y > x
	return false


## True when a 4-neighbour of (x, y) has the requested wet state.
func _has_neighbour(wet: PackedByteArray, x: int, y: int, size: int, want: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + int(d.x)
		var ny: int = y + int(d.y)
		if nx < 0 or ny < 0 or nx >= size or ny >= size:
			continue
		if wet[ny * size + nx] == want:
			return true
	return false


func _preview(tiles: Array[Image], outdir: String) -> void:
	var size := tiles[0].get_width()
	var gap := 4
	var sheet := Image.create(size * 4 + gap * 3, size, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(20, 20, 26, 255))
	for i in tiles.size():
		sheet.blit_rect(tiles[i], Rect2i(0, 0, size, size), Vector2i(i * (size + gap), 0))
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var err := sheet.save_png("%s/preview.png" % outdir)
	if err != OK:
		print("preview save failed err=%d" % err)
