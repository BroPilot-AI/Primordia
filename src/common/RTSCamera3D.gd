## Reusable orthographic RTS camera, patterned on godot-open-rts' IsometricCamera3D
## (~/godot-refs/godot-open-rts/source/match/IsometricCamera3D.gd): orthographic projection,
## screen->ground via project_ray (see Stage3D.ground_point), yaw-aware pan scaled by zoom size,
## and middle-mouse map rotation around the focus. Extension beyond open-rts: TWO zoom levels —
## a tactical band (close, shallow angle — see building sides/units) and a strategic band (far,
## steep top-down — read the whole map). Wheel zooms within a band and SNAPS to the neighbour when
## scrolled past the seam, easing the tilt across. Shared by every 3D stage via _build_camera; the
## camera owns its own placement (focus + tilt + yaw).
extends Camera3D

@export var pan_speed: float = 28.0
@export var edge_margin: int = 6
@export var zoom_step: float = 6.0
@export var bounds: Vector2 = Vector2(140, 140)
@export var back_dist: float = 150.0      # camera distance from focus (ortho: framing only, not zoom)
@export var tilt_ease: float = 7.0        # how fast the tilt eases when switching levels
@export var rotate_speed: float = 0.006   # map rotation per pixel of middle-mouse drag (open-rts style)

# Two zoom levels. size = orthographic extent (smaller = closer); tilt = degrees below horizontal.
const TACTICAL := 0
const STRATEGIC := 1
const BAND_MIN := [12.0, 50.0]     # min ortho size per level
const BAND_MAX := [48.0, 150.0]    # max ortho size per level (strategic wide enough for big maps)
const BAND_TILT := [45.0, 66.0]    # tactical = shallow, strategic = top-down
const DEFAULT_YAW := 0.0           # camera south of focus, looking north (-Z) so north is up-screen

var _focus: Vector3 = Vector3.ZERO
var _yaw: float = DEFAULT_YAW
var _level: int = TACTICAL
var _tilt_cur: float = BAND_TILT[TACTICAL]
var _has_seen_mouse_motion: bool = false
var _rotating: bool = false


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	_yaw = DEFAULT_YAW
	_level = STRATEGIC if size >= BAND_MIN[STRATEGIC] else TACTICAL
	size = clampf(size, BAND_MIN[_level], BAND_MAX[_level])
	_tilt_cur = BAND_TILT[_level]
	_place()


func _process(delta: float) -> void:
	# Reconcile the orbit-drag flag against the real button state: a middle-button
	# RELEASE consumed by a HUD control (MOUSE_FILTER_STOP) or outside the window never
	# reaches _unhandled_input, which would leave _rotating stuck true and orbit the map
	# on plain mouse motion.
	if _rotating and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_rotating = false
	# Ease the tilt toward the active level's angle (smooth level transition).
	var target: float = BAND_TILT[_level]
	if absf(_tilt_cur - target) > 0.01:
		_tilt_cur = lerpf(_tilt_cur, target, clampf(tilt_ease * delta, 0.0, 1.0))

	var mv := _pan_vector()
	if mv != Vector2.ZERO:
		# Pan in the camera's ground plane (yaw-aware), scaled by zoom so it feels constant.
		var world := Vector3(mv.x, 0, mv.y).rotated(Vector3.UP, _yaw)
		_focus += world * pan_speed * delta * (size / 30.0)
		_focus.x = clampf(_focus.x, -bounds.x, bounds.x)
		_focus.z = clampf(_focus.z, -bounds.y, bounds.y)
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_has_seen_mouse_motion = true
		if _rotating:
			_yaw += event.relative.x * rotate_speed   # drag to orbit the map (open-rts)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_step)   # zoom in
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_step)    # zoom out
	if event is InputEventKey and event.pressed and not event.echo:
		# T = toggle tactical/strategic band (explicit "zoom levels" without hunting the wheel).
		if event.keycode == KEY_T:
			toggle_band()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_HOME:
			# Home = strategic overview of current focus.
			zoom_strategic()
			get_viewport().set_input_as_handled()


# Apply a zoom delta, snapping to the neighbouring level when scrolling past the band seam.
func _zoom(delta_size: float) -> void:
	var ns := size + delta_size
	if _level == TACTICAL and ns > BAND_MAX[TACTICAL]:
		_level = STRATEGIC
		size = BAND_MIN[STRATEGIC]            # continue zooming OUT into the strategic band
	elif _level == STRATEGIC and ns < BAND_MIN[STRATEGIC]:
		_level = TACTICAL
		size = BAND_MAX[TACTICAL]             # continue zooming IN into the tactical band
	else:
		size = clampf(ns, BAND_MIN[_level], BAND_MAX[_level])


func _pan_vector() -> Vector2:
	if not get_window().has_focus():
		return Vector2.ZERO
	var v := Vector2.ZERO
	v.x = Input.get_axis("ui_left", "ui_right")
	v.y = Input.get_axis("ui_up", "ui_down")
	if edge_margin > 0 and _has_seen_mouse_motion:
		var m := get_viewport().get_mouse_position()
		var vs := Vector2(get_viewport().get_visible_rect().size)
		if m.x <= edge_margin: v.x = -1
		elif m.x >= vs.x - edge_margin: v.x = 1
		if m.y <= edge_margin: v.y = -1
		elif m.y >= vs.y - edge_margin: v.y = 1
	return v


# Position the camera back+above the focus at the current tilt, then aim at it. look_at keeps the
# orientation correct regardless of euler sign conventions.
func _place() -> void:
	var a := deg_to_rad(_tilt_cur)
	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))   # ground direction behind the focus
	global_position = _focus + back * (back_dist * cos(a)) + Vector3(0.0, back_dist * sin(a), 0.0)
	look_at(_focus, Vector3.UP)


func set_focus(p: Vector3) -> void:
	_focus = Vector3(p.x, 0.0, p.z)
	_place()


## The ground point the camera is looking at. Note this is NOT the camera node's
## global_position — the camera hangs back_dist behind/above the focus, so using its
## position for view-center math (e.g. the minimap view rect) is off by the back offset.
func get_focus() -> Vector3:
	return _focus


func get_band() -> int:
	return _level


## Snap to the tactical (close) or strategic (wide) band. Optional focus re-centers first.
func set_band(level: int, focus: Vector3 = Vector3.INF) -> void:
	if focus != Vector3.INF:
		set_focus(focus)
	_level = clampi(level, TACTICAL, STRATEGIC)
	# Land mid-band so wheel still has room either way.
	size = lerpf(BAND_MIN[_level], BAND_MAX[_level], 0.35 if _level == TACTICAL else 0.30)
	_place()


func toggle_band(focus: Vector3 = Vector3.INF) -> void:
	set_band(STRATEGIC if _level == TACTICAL else TACTICAL, focus)


## Drop into tactical over a ground point (double-click unit / hotkey).
func zoom_tactical(at: Vector3) -> void:
	set_band(TACTICAL, at)


func zoom_strategic(at: Vector3 = Vector3.INF) -> void:
	set_band(STRATEGIC, at)


func reset_orientation() -> void:
	_yaw = DEFAULT_YAW
	_place()
