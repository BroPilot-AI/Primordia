extends Node
## Global game-speed / pause control for the long sim stages. Number keys 1/2/3 set speed,
## P toggles pause. Drives every delta-based system via Engine.time_scale. (Between-stage cutscenes
## use get_tree().paused separately, so this never fights them.) Autoload.

const PAUSED := 0.0
const NORMAL := 1.0
const FAST := 2.0
const FASTER := 3.0
const VALID_SPEEDS: Array[float] = [PAUSED, NORMAL, FAST, FASTER]

var _last_speed := NORMAL


func _ready() -> void:
	set_speed(NORMAL, false)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	# Modified digits belong to stages (Ctrl+1..9 = Civ control groups) — never also change speed.
	if key.ctrl_pressed or key.shift_pressed or key.alt_pressed or key.meta_pressed:
		return
	match key.keycode:
		KEY_1:
			set_speed(NORMAL)
		KEY_2:
			set_speed(FAST)
		KEY_3:
			set_speed(FASTER)
		KEY_P:
			toggle_pause()


func set_speed(speed: float, notify: bool = true) -> void:
	var next: float = _normalize_speed(speed)
	if next > PAUSED:
		_last_speed = next
	Engine.time_scale = next
	Events.speed_changed.emit(next)
	if notify:
		Events.notify.emit("%s" % ("Paused (P)" if next == PAUSED else "Speed %.0fx" % next))


func toggle_pause() -> void:
	if Engine.time_scale > PAUSED:
		set_speed(PAUSED)
	else:
		set_speed(_last_speed)


func current_speed() -> float:
	return _normalize_speed(Engine.time_scale)


func _normalize_speed(speed: float) -> float:
	for valid_speed: float in VALID_SPEEDS:
		if is_equal_approx(speed, valid_speed):
			return valid_speed
	return NORMAL
