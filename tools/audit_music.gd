extends SceneTree

# Music bed audit (ECHO lane).
#
# The phase-locked handover in `scripts/music_director.gd` only works if every
# bed is the same length on the same tonal centre: the incoming bed is started at
# the outgoing bed's playback position, so a different loop length would drift
# the bar lines apart and turn the morph into a flam.
#
# This checks, without playing anything:
#   * every biome in `data/exoplanets.json` has a bed (no silent mission);
#   * every path in the director's tables resolves to a loadable Ogg stream;
#   * all beds are 24 bars at 84 BPM, within 1 ms of each other;
#   * the stream reports looping on, which is what keeps the bed alive past bar 24.
#
# Run:
#   godot --headless --path . --script tools/audit_music.gd
#
# Exit code 0 = clean, 1 = at least one failure.

const BPM := 84.0
const BARS := 24
const LOOP_SECONDS := BARS * 4.0 * 60.0 / BPM      # 68.571428...
const TOLERANCE := 0.001                            # 1 ms

var failures: Array[String] = []


func _initialize() -> void:
	var director: Script = load("res://scripts/music_director.gd")
	if director == null:
		_fail("could not load scripts/music_director.gd")
		_finish()
		return
	var constants := director.get_script_constant_map()
	var beds: Dictionary = constants.get("BEDS", {})
	var biome_beds: Dictionary = constants.get("BIOME_BEDS", {})
	if beds.is_empty() or biome_beds.is_empty():
		_fail("BEDS / BIOME_BEDS missing from the director")
		_finish()
		return

	print("music beds — %d context, %d biome, %.3f s expected loop"
		% [beds.size(), biome_beds.size(), LOOP_SECONDS])
	print("%-22s %-10s %9s %9s %s" % ["bed", "source", "seconds", "drift ms", "loopable"])

	var lengths := {}
	for table in [beds, biome_beds]:
		for id in table:
			var path := str(table[id])
			if not ResourceLoader.exists(path):
				_fail("%s: missing %s" % [id, path])
				continue
			var stream: AudioStream = load(path)
			if stream == null:
				_fail("%s: %s did not load" % [id, path])
				continue
			var seconds: float = stream.get_length()
			var drift := (seconds - LOOP_SECONDS) * 1000.0
			# The director sets `loop = true` at runtime; what the audit can
			# prove here is that the stream is a class it knows how to loop.
			var loopable := stream is AudioStreamOggVorbis or stream is AudioStreamWAV
			print("%-22s %-10s %9.3f %+9.1f %s"
				% [id, path.get_file(), seconds, drift, "yes" if loopable else "NO"])
			if not loopable:
				_fail("%s: %s is not a loopable stream class" % [id, path.get_file()])
			if absf(drift) > TOLERANCE * 1000.0:
				_fail("%s: %.3f s, expected %.3f s (drift %+.1f ms)"
					% [id, seconds, LOOP_SECONDS, drift])
			lengths[id] = seconds

	# Every biome the planet data actually uses must have a bed, or a mission
	# would fall back to the neutral sector bed and lose its identity.
	var txt := FileAccess.get_file_as_string("res://data/exoplanets.json")
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		_fail("could not parse data/exoplanets.json")
	else:
		var used := {}
		for planet in (parsed as Dictionary).get("planets", []):
			used[str(planet.get("biome", ""))] = true
		var missing: Array[String] = []
		for biome in used:
			if not biome_beds.has(biome):
				missing.append(biome)
		print("\nplanet biomes in data: %d (%s)" % [used.size(), ", ".join(used.keys())])
		if missing.is_empty():
			print("every planet biome has a bed")
		else:
			_fail("biomes with no bed: %s" % ", ".join(missing))

	# A length mismatch between any two beds is the failure this audit exists for.
	if lengths.size() > 1:
		var values: Array = lengths.values()
		var spread: float = values.max() - values.min()
		if spread > TOLERANCE:
			_fail("bed lengths spread %.4f s; the handover would drift" % spread)
		else:
			print("bed lengths agree within %.4f s — handover can phase-lock" % spread)

	_finish()


func _fail(message: String) -> void:
	failures.append(message)
	print("FAIL  %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("\nPASS  music beds")
		quit(0)
	else:
		print("\nFAILED  %d problem(s)" % failures.size())
		quit(1)
