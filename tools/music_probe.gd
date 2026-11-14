extends SceneTree

# Handover probe (ECHO lane). Runs with a real audio device, so unlike
# `tools/audit_music.gd` it can measure the thing that actually matters: when the
# bed changes, does the incoming bed start where the outgoing one was, or does it
# restart at 0.0 like a track being pressed play?
#
#   godot --path . --script tools/music_probe.gd -- --music-log
#
# It plays title -> cryo sector -> volcanic sector -> debrief, sampling the
# playback position across each handover, and fails if a handover loses more than
# 200 ms of position (a restart would lose the whole elapsed time).

const TOLERANCE := 0.20
const SETTLE := 0.60

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var script: Script = load("res://scripts/music_director.gd")
	if script == null:
		print("FAIL  could not load scripts/music_director.gd")
		quit(1)
		return
	var director: Node = script.new()
	root.add_child(director)
	await process_frame
	await create_timer(0.2).timeout

	await _handover(director, "title", "", 2.2)
	await _handover(director, "sector", "cryo", SETTLE)
	await _handover(director, "sector", "volcanic", SETTLE)
	await _handover(director, "debrief", "", SETTLE)

	# A fast A -> B -> A sequence must not leave two voices up or cut the bed.
	director.play("sector", "crystal")
	await create_timer(0.4).timeout
	director.play("debrief")
	await create_timer(0.4).timeout
	var total := 0.0
	for gain in director.get("_gains"):
		total += float(gain)
	print("\nrapid switch: combined gain %.2f, active bed=%s"
		% [total, str(director.get("_bed"))])
	if total > 1.35:
		_fail("rapid switch stacks %.2f of gain (two beds audibly up at once)" % total)

	if _failures.is_empty():
		print("\nPASS  handover stays phase-locked")
		quit(0)
	else:
		print("\nFAILED  %d problem(s)" % _failures.size())
		quit(1)


func _handover(director: Node, context: String, biome: String, wait: float) -> void:
	var before := _position(director)
	director.play(context, biome)
	var expected := before + wait
	await create_timer(wait).timeout
	var after := _position(director)
	var drift := after - expected
	var bed := str(director.get("_bed"))
	var label := "%s/%s" % [context, biome] if biome != "" else context
	print("%-18s bed=%-18s before=%6.2fs after=%6.2fs drift=%+.2fs"
		% [label, bed, before, after, drift])
	if absf(drift) > TOLERANCE:
		_fail("%s: playback position jumped %+.2f s (a restart, not a morph)" % [label, drift])


func _position(director: Node) -> float:
	var players: Array = director.get("_players")
	var active: int = int(director.get("_active"))
	if players.is_empty():
		return 0.0
	var player: AudioStreamPlayer = players[active]
	if player == null or not player.playing:
		return 0.0
	return player.get_playback_position()


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL  %s" % message)
