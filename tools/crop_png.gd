extends SceneTree

# Crop / scale / compose PNGs for review evidence (agent b).
#
# The project ships no image tooling beyond Godot itself, and the review frames
# are 1280x720 captures where the interesting coast is a 300 px patch. This
# takes one or more sources, crops the same rectangle out of each, scales it by
# a nearest-neighbour factor, and lays them out left to right on a dark sheet.
#
# Run:
#   godot --headless --path . --script tools/crop_png.gd -- \
#     --src=/tmp/opencode/b_review/before.png,/tmp/opencode/b_review/after.png \
#     --out=/tmp/opencode/b_review/coast_ab.png \
#     --x=380 --y=180 --w=320 --h=240 --scale=3

const GAP := 8
const BACKGROUND := Color8(18, 18, 24, 255)


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
	for key in ["src", "out"]:
		if not args.has(key):
			print("FAIL: missing --%s" % key)
			quit(1)
			return

	var rect := Rect2i(
		int(args.get("x", 0)),
		int(args.get("y", 0)),
		int(args.get("w", 0)),
		int(args.get("h", 0))
	)
	var scale := maxi(1, int(args.get("scale", 1)))
	var paths: PackedStringArray = str(args["src"]).split(",")
	var crops: Array[Image] = []
	for path in paths:
		var img := Image.load_from_file(path)
		if img == null:
			print("FAIL: could not load %s" % path)
			quit(1)
			return
		img.convert(Image.FORMAT_RGBA8)
		var use := rect
		if use.size == Vector2i.ZERO:
			use = Rect2i(0, 0, img.get_width(), img.get_height())
		if use.size.x <= 0 or use.size.y <= 0:
			print("FAIL: empty crop")
			quit(1)
			return
		crops.append(img.get_region(use))

	var cw := crops[0].get_width() * scale
	var ch := crops[0].get_height() * scale
	var sheet := Image.create(cw * crops.size() + GAP * (crops.size() - 1), ch, false, Image.FORMAT_RGBA8)
	sheet.fill(BACKGROUND)
	for i in crops.size():
		crops[i].resize(cw, ch, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(crops[i], Rect2i(0, 0, cw, ch), Vector2i(i * (cw + GAP), 0))

	var err := sheet.save_png(str(args["out"]))
	print("write %s err=%d (%dx%d)" % [args["out"], err, sheet.get_width(), sheet.get_height()])
	quit(0 if err == OK else 1)
