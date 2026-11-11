## Audio (autoload): per-stage ambient MUSIC + event SFX, routed to the Music/SFX buses that
## GameShell creates (so the settings sliders control them). Every file load is GUARDED — if an
## audio file isn't present yet the call is a silent no-op, so the game runs fine with or without
## the assets. Drop the CC0 files into res://assets/audio/ with these
## names and they light up automatically:
##   music_primordial.ogg  music_creature.ogg  music_tribe.ogg  music_civ.ogg  music_space.ogg
##   sfx_blip.ogg  sfx_chime.ogg  sfx_win.ogg  sfx_lose.ogg
extends Node

# Stems only — `_resolve()` finds whichever real extension landed (.ogg / .mp3 / .wav), so the
# exact source format doesn't matter (space music is .mp3, the rest .ogg, etc.).
const MUSIC_FOR_STAGE: Dictionary[int, String] = {
	0: "music_primordial",
	1: "music_creature",
	2: "music_tribe",
	3: "music_civ",
	4: "music_space",
}

# Fallbacks if a stem is missing (ffmpeg-derived stems ship for creature/tribe/civ).
const MUSIC_FALLBACK_FOR_STAGE: Dictionary[int, String] = {
	1: "music_primordial",
	2: "music_primordial",
	3: "music_space",
}
## Near-identity pitch — stems already carry era color; tiny nudge only as safety.
const MUSIC_PITCH_FOR_STAGE: Dictionary[int, float] = {
	0: 1.00,
	1: 1.00,
	2: 1.00,
	3: 1.00,
	4: 1.00,
}
# Key → file stem. SFX live under res://assets/audio/sfx/ as .wav (and the older four under
# res://assets/audio/ as .ogg). The resolver tries .ogg/.mp3/.wav so stems only matter.
const SFX: Dictionary[String, String] = {
	# Universal / legacy (still routed for the four original stems)
	"blip": "sfx_blip", "chime": "sfx_chime", "win": "sfx_win", "lose": "sfx_lose",
	# Primordial
	"soup_eat": "sfx_soup_eat",
	"soup_damage": "sfx_soup_damage",
	"soup_mutate": "sfx_soup_mutate",
	# Creature
	"creature_attack": "sfx_creature_attack",
	# Civ
	"civ_build": "sfx_civ_build",
	"civ_ageup": "sfx_civ_ageup",
	"civ_combat": "sfx_civ_combat",
	# Space
	"space_laser": "sfx_space_laser",
	"space_explosion": "sfx_space_explosion",
	"space_mining_beam": "sfx_space_mining_beam",
	# Cross-stage
	"stage_transition": "sfx_stage_transition",
	"menu_click": "sfx_menu_click",
}
const _EXTS: Array[String] = [".ogg", ".mp3", ".wav"]
const _FULL_VOLUME_DB := 0.0
const _DUCKED_VOLUME_DB := -18.0
const _SILENT_VOLUME_DB := -80.0
const _CROSSFADE_SECONDS := 0.85
const _DUCK_SECONDS := 0.25
# Per-key cooldown (seconds) so rapid-fire events (eating motes, laser volleys, civ combat)
# don't machine-gun the mixer. 0.06s ≈ the threshold where 5+ plays/sec start to clip.
const _SFX_COOLDOWN_SEC := 0.06
const _MENU_CLICK_COOLDOWN_SEC := 0.10

var _music: AudioStreamPlayer
var _music_next: AudioStreamPlayer
var _fade_tween: Tween
var _current_track := ""
var _time_scale_paused := false
var _terminal_screen := false
# _last_play[key] = engine time of the most recent accepted play; used to throttle rapid SFX.
var _last_play: Dictionary[String, float] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = _SILENT_VOLUME_DB
	add_child(_music)

	_music_next = AudioStreamPlayer.new()
	_music_next.bus = "Music"
	_music_next.volume_db = _SILENT_VOLUME_DB
	add_child(_music_next)

	Events.stage_changed.connect(_on_stage_changed)
	Events.speed_changed.connect(_on_speed_changed)
	Events.notify.connect(func(_text: String) -> void: play_sfx("blip"))
	Events.tech_researched.connect(func(_tech_name: String) -> void: play_sfx("chime"))
	# SFX wires (signals preferred so callers don't have to know about AudioManager):
	# Primordial
	Events.mote_eaten.connect(func(_amount: float) -> void: play_sfx("soup_eat"))
	Events.food_consumed.connect(func(_food: Dictionary) -> void: play_sfx("soup_eat"))
	Events.player_harmed.connect(func(_amount: float) -> void: play_sfx("soup_damage"))
	# Cross-stage
	Events.stage_complete.connect(func(_stage: int) -> void: play_sfx("stage_transition"))
	Events.game_won.connect(func() -> void:
		play_sfx("win")
		_on_terminal_screen()
		)
	Events.game_lost.connect(func(_reason: String) -> void:
		play_sfx("lose")
		_on_terminal_screen()
		)
	_update_time_scale_pause(true)


func _process(_delta: float) -> void:
	_update_time_scale_pause(false)


func _exit_tree() -> void:
	# Release active decoders before AudioServer teardown. Pausing a terminal-screen
	# track is not enough: the MP3 playback object otherwise survives until shutdown
	# and is reported as a leaked ObjectDB instance.
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	for player in [_music, _music_next]:
		if player != null:
			player.stop()
			player.stream = null


# First audio file matching the stem at any supported extension; "" if none present.
func _resolve(stem: String) -> String:
	if stem == "":
		return ""
	for ext in _EXTS:
		var p := "res://assets/audio/%s%s" % [stem, ext]
		if ResourceLoader.exists(p):
			return p
	return ""


func _on_stage_changed(stage: int) -> void:
	_terminal_screen = false
	var path := _music_path_for_stage(stage)
	var pitch: float = float(MUSIC_PITCH_FOR_STAGE.get(stage, 1.0))
	# Same file can still change era feel via pitch (creature/tribe share primordial stem).
	var track_key := "%s@%.2f" % [path, pitch]
	if track_key == _current_track:
		_music.stream_paused = false
		_music_next.stream_paused = false
		_music.pitch_scale = pitch
		_retween_music(_DUCK_SECONDS, false)
		return
	_current_track = track_key
	if path == "":
		return
	var stream := ResourceLoader.load(path, "AudioStream") as AudioStream
	if stream == null:
		return
	_set_looping(stream)

	var outgoing := _music
	var incoming := _music_next
	incoming.stop()
	incoming.stream = stream
	incoming.pitch_scale = pitch
	incoming.volume_db = _SILENT_VOLUME_DB
	incoming.stream_paused = false
	incoming.play()

	_music = incoming
	_music_next = outgoing
	_music.stream_paused = false
	_music_next.stream_paused = false
	_retween_music(_CROSSFADE_SECONDS, true)
	# Stage stinger under the crossfade — sells the leap even when music reuses a stem.
	play_sfx("stage_transition")


func _on_speed_changed(_scale: float) -> void:
	_update_time_scale_pause(true)


func _music_path_for_stage(stage: int) -> String:
	var direct := _resolve(MUSIC_FOR_STAGE.get(stage, ""))
	if direct != "":
		return direct
	var fallback := _resolve(MUSIC_FALLBACK_FOR_STAGE.get(stage, ""))
	if fallback != "":
		return fallback
	return _resolve("music_space" if stage >= 3 else "music_primordial")


## True when the preferred stem for a stage exists on disk (used by tests + debug).
func has_music_for_stage(stage: int) -> bool:
	return _resolve(MUSIC_FOR_STAGE.get(stage, "")) != ""


func _set_looping(stream: AudioStream) -> void:
	for property: Dictionary in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", true)
			return


func _update_time_scale_pause(force: bool) -> void:
	var paused := Engine.time_scale <= 0.0
	if not force and paused == _time_scale_paused:
		return
	_time_scale_paused = paused
	if _terminal_screen:
		return
	_music.stream_paused = false
	_music_next.stream_paused = false
	_retween_music(_DUCK_SECONDS, true)


func _on_terminal_screen() -> void:
	_terminal_screen = true
	_retween_music(_DUCK_SECONDS, true)


func _target_music_volume_db() -> float:
	if _terminal_screen:
		return _SILENT_VOLUME_DB
	return _DUCKED_VOLUME_DB if _time_scale_paused else _FULL_VOLUME_DB


func _retween_music(duration: float, stop_faded_player: bool) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null

	var has_current := _music.stream != null and _music.playing
	var has_fading := _music_next.stream != null and _music_next.playing
	if not has_current and not has_fading:
		return

	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.set_ignore_time_scale(true)
	_fade_tween.set_parallel(true)
	if has_current:
		_fade_tween.tween_property(_music, "volume_db", _target_music_volume_db(), duration)
	if has_fading:
		_fade_tween.tween_property(_music_next, "volume_db", _SILENT_VOLUME_DB, duration)
	_fade_tween.finished.connect(func() -> void:
		if stop_faded_player and _music_next.stream != null:
			_music_next.stop()
			_music_next.stream = null
		if _terminal_screen:
			# The terminal card has no music to resume. Release both decoders instead
			# of leaving the silent current track paused and leaking its MP3 playback.
			_music.stop()
			_music.stream = null
			_music_next.stop()
			_music_next.stream = null
			_current_track = ""
		_fade_tween = null
		)


func _play_sfx(key: String) -> void:
	var path := _resolve(SFX.get(key, ""))
	if path == "":
		return
	var stream := ResourceLoader.load(path, "AudioStream") as AudioStream
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Public entry point. Same as the internal _play_sfx but throttled per key so a single
## logical event (eating motes, a salvo of lasers) doesn't machine-gun the mixer. Unknown
## keys are a silent no-op — keep it cheap to call from gameplay.
func play_sfx(key: String, cooldown_sec: float = _SFX_COOLDOWN_SEC) -> void:
	if key == "" or not SFX.has(key):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var last: float = float(_last_play.get(key, -1.0))
	if last >= 0.0 and (now - last) < cooldown_sec:
		return
	_last_play[key] = now
	_play_sfx(key)


## Short alias for "play the UI click sound" so button call sites stay readable:
##     AudioManager.ui_click()
func ui_click() -> void:
	play_sfx("menu_click", _MENU_CLICK_COOLDOWN_SEC)
