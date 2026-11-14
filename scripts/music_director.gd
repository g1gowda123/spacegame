extends Node
## Screen music: looping beds, crossfaded on context change, ducked while the
## sector shows a live hazard telegraph.
##
## Two things keep a change from sounding like a new track starting:
##
## 1. **Phase-locked handover.** Every bed is 24 bars at 84 BPM (68.571 s) on the
##    same tonal centre (A), so the incoming bed is started at the *playback
##    position the outgoing bed is at* — `play(from_position)` — instead of at
##    0.0. The two beds therefore agree on the bar, the beat and the root, and
##    only the pad colour, filter and texture move.
## 2. **A shared spine.** The sub drone, the soft two-beat pulse and the noise
##    floor are identical in every bed (`tools/make_biome_music.py`), so the
##    crossfade never changes the bass or the pulse placement.
##
## Sector beds are chosen per exoplanet *type* (biome), not per planet: 72
## planets, nine biomes. The context map still lives here rather than in each
## scene, so a sourced stem can replace a generated one at the same path.
##
## Headless runs (smoke tests, capture probes, CI) return before loading
## anything, so the audio-free ObjectDB/resource-leak checks stay green.

const BEDS := {
	"title": "res://assets/music/title.ogg",
	"sector": "res://assets/music/sector.ogg",
	"debrief": "res://assets/music/debrief.ogg",
}

## One ambient bed per biome in `data/exoplanets.json`. Unknown or future biomes
## fall back to the neutral `sector` bed above, so a data change cannot silence
## the game.
const BIOME_BEDS := {
	"temperate": "res://assets/music/sector_temperate.ogg",
	"arid": "res://assets/music/sector_arid.ogg",
	"cryo": "res://assets/music/sector_cryo.ogg",
	"volcanic": "res://assets/music/sector_volcanic.ogg",
	"barren": "res://assets/music/sector_barren.ogg",
	"iron": "res://assets/music/sector_iron.ogg",
	"sulfur": "res://assets/music/sector_sulfur.ogg",
	"ammonia": "res://assets/music/sector_ammonia.ogg",
	"crystal": "res://assets/music/sector_crystal.ogg",
}

## Screens that share a bed. report reuses debrief; design/draft/crew reuse
## title, so moving between the meta screens does not restart the loop.
const CONTEXT_BED := {
	"title": "title",
	"design": "title",
	"draft": "title",
	"crew": "title",
	"sector": "sector",
	"debrief": "debrief",
	"report": "debrief",
}

## Bed level when nothing is threatening. Every bed is mastered to -16 LUFS, so
## one number works for all of them and a handover never steps in level.
const BASE_DB := -7.0
## Hazard telegraph is live: pull the bed under the alarm/thud cues (-6 dB).
const DUCK_DB := -13.0
## 4 s = 1.4 bars at 84 BPM. Long enough to read as a morph rather than a cut,
## short enough that a screen change still feels immediate.
const FADE := 4.0
const DUCK_FADE := 0.35
const SILENT_DB := -60.0

var _players: Array[AudioStreamPlayer] = []
var _gains: Array[float] = []
var _tweens: Array = []
var _streams: Dictionary = {}
var _active := 0
var _context := ""
var _biome := ""
var _bed := ""
var _duck := 1.0
var _ducked := false
var _duck_tween: Tween
var _armed := false
var _log := false


func _ready() -> void:
	_log = _has_arg("--music-log")
	if DisplayServer.get_name() == "headless":
		return
	var paths: Dictionary = BEDS.duplicate()
	paths.merge(BIOME_BEDS, true)
	for bed in paths:
		var stream: AudioStream = load(str(paths[bed]))
		if stream == null:
			push_warning("MusicDirector: missing bed %s" % bed)
			continue
		_streams[bed] = _loop_forever(stream)
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
		_gains.append(0.0)
		_tweens.append(null)
	_armed = _players.size() == 2


func _has_arg(flag: String) -> bool:
	return flag in OS.get_cmdline_args() or flag in OS.get_cmdline_user_args()


func _loop_forever(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = true
		ogg.loop_offset = 0.0
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


## Switch beds. Safe to call every `_ready`; same-bed calls are a no-op, which is
## what lets design -> draft -> title continue the loop instead of restarting,
## and what lets a sector re-entered on the same biome keep playing.
##
## `biome` only matters for the sector context: it selects one of the nine
## per-type beds. Pass "" to get the neutral sector bed.
func play(context: String, biome: String = "") -> void:
	_context = context
	if biome != "":
		_biome = biome
	var bed := _resolve_bed(context, biome)
	if not _armed:
		_bed = bed
		return
	if bed == _bed:
		return
	if not _streams.has(bed):
		return

	var previous: AudioStreamPlayer = _players[_active]
	var phase := _phase_of(previous)
	var next_index := 1 - _active
	var next: AudioStreamPlayer = _players[next_index]

	# If a handover is still in flight, this player is the one already fading
	# out; reuse it and ramp from whatever level it reached, so a fast
	# screen->screen->screen sequence never cuts the bed that is currently up.
	var from_gain := _gains[next_index]
	next.stream = _streams[bed]
	next.play(phase)
	_bed = bed
	_active = next_index

	_ramp_gain(next_index, 1.0, FADE)
	_ramp_gain(1 - next_index, 0.0, FADE)
	if _log:
		print("MUSIC bed=%s context=%s biome=%s phase=%.2fs fade=%.1fs"
			% [bed, context, biome, phase, FADE])


## Called by the sector whenever a telegraph starts or clears.
func set_duck(on: bool) -> void:
	if on == _ducked:
		return
	_ducked = on
	if not _armed:
		return
	var target := db_to_linear(DUCK_DB - BASE_DB) if on else 1.0
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(v: float) -> void:
		_duck = v
		_push_levels()
	, _duck, target, DUCK_FADE)
	if _log:
		print("MUSIC duck=%s db=%.1f" % [str(on), DUCK_DB if on else BASE_DB])


func stop() -> void:
	if not _armed:
		return
	for i in _players.size():
		_kill_tween(i)
		_gains[i] = 0.0
		_players[i].stop()
		_players[i].stream = null
	_bed = ""


func _resolve_bed(context: String, biome: String) -> String:
	if context == "sector" and BIOME_BEDS.has(biome):
		return biome
	return str(CONTEXT_BED.get(context, context))


## The position the outgoing bed is at, in seconds, wrapped to the loop. Starting
## the incoming bed here is what keeps the bar, the beat and the root aligned.
func _phase_of(player: AudioStreamPlayer) -> float:
	if player == null or not player.playing or player.stream == null:
		return 0.0
	var pos: float = player.get_playback_position()
	pos += AudioServer.get_time_since_last_mix()
	pos -= AudioServer.get_output_latency()
	var length: float = player.stream.get_length()
	if length <= 0.0:
		return 0.0
	return fmod(maxf(pos, 0.0), length)


func _ramp_gain(index: int, target: float, seconds: float) -> void:
	var from := _gains[index]
	_kill_tween(index)
	if is_equal_approx(from, target):
		_gains[index] = target
		_push_levels()
		_maybe_release(index)
		return
	var tween := create_tween()
	# Linear, not equal-power. The beds are *correlated*: they share the drone,
	# the pulse and the root, so equal-power sums them coherently and measures a
	# +2.7 to +3.5 dB swell at the midpoint of the fade. A linear ramp keeps the
	# shared spine at constant level and morphs only the part that differs —
	# measured +0.9 to +1.6 dB worst case, mid-fade within 0.1 dB.
	# (`tools/make_music_loop.py` reaches the same conclusion for loop seams.)
	tween.tween_method(func(u: float) -> void:
		_gains[index] = lerpf(from, target, u)
		_push_levels()
	, 0.0, 1.0, seconds)
	tween.tween_callback(_maybe_release.bind(index))
	_tweens[index] = tween


func _kill_tween(index: int) -> void:
	var tween: Tween = _tweens[index]
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens[index] = null


func _push_levels() -> void:
	for i in _players.size():
		var gain: float = maxf(_gains[i], 0.0001) * _duck
		_players[i].volume_db = BASE_DB + linear_to_db(minf(gain, 1.0))


## Silence a voice that has faded out, but only if it is no longer the active
## one — a fast A->B->A switch must not stop the bed that is coming up.
func _maybe_release(index: int) -> void:
	if index == _active:
		return
	if _gains[index] > 0.001:
		return
	_players[index].stop()
	_players[index].stream = null


## Note on shutdown: if the process exits while a Vorbis playback is live,
## Godot checks ObjectDB before the audio server has released the playback, so
## the windowed build can print "N ObjectDB instances were leaked at exit". Those
## instances are the engine's Ogg stream/playback objects, not anything this node
## holds: the references below are dropped, headless never creates a player, and
## the WAV cues do not produce the message. Tracked here so a QA pass does not
## read it as a regression in `game_state.gd`'s teardown.
func _exit_tree() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	for i in _tweens.size():
		_kill_tween(i)
	_tweens.clear()
	for player in _players:
		player.stop()
		player.stream = null
	_players.clear()
	_gains.clear()
	_streams.clear()
	_armed = false
	_bed = ""
