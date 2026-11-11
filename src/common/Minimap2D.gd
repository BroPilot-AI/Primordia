## Reusable RTS minimap/radar Control. The stage feeds it a static terrain texture (one pixel per
## tile) plus per-frame dots (units/cities) and the camera focus/view box; clicking pans the camera.
## Chrome matches StageChrome brand (teal frame + title strip).
class_name Minimap2D
extends Control

signal pan_requested(world_pos: Vector3)

const FRAME := Color(0.42, 0.86, 0.78, 0.85)
const FRAME_INNER := Color(0.02, 0.05, 0.07, 0.55)
const VIEW_COL := Color(1.0, 0.90, 0.45, 0.90)
const TITLE_H := 16.0

var world_origin: Vector2 = Vector2.ZERO   # world (x,z) of tile (0,0)
var world_size: Vector2 = Vector2.ONE      # world (x,z) extent of the whole map
var terrain_tex: Texture2D = null
var dots: Array = []                        # [{p: Vector2 world-xz, c: Color, r: float}]
var focus_world: Vector2 = Vector2.ZERO
var view_half: Vector2 = Vector2.ZERO       # camera view half-extent in world units
var title: String = "MAP"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(200, 160)
	size = custom_minimum_size


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var map_rect := _map_rect()
		var local: Vector2 = (event as InputEventMouseButton).position
		if not map_rect.has_point(local):
			return
		var u: Vector2 = (local - map_rect.position) / map_rect.size   # 0..1 within the map
		u = u.clamp(Vector2.ZERO, Vector2.ONE)
		pan_requested.emit(Vector3(
			world_origin.x + u.x * world_size.x, 0.0, world_origin.y + u.y * world_size.y))


func set_data(new_dots: Array, focus: Vector2, half: Vector2) -> void:
	dots = new_dots
	focus_world = focus
	view_half = half
	queue_redraw()


func _map_rect() -> Rect2:
	# Leave a title strip on top; map fills the rest with 2px pad.
	return Rect2(2.0, TITLE_H + 2.0, size.x - 4.0, size.y - TITLE_H - 4.0)


func _w2l(w: Vector2) -> Vector2:
	var mr := _map_rect()
	return mr.position + Vector2(
		(w.x - world_origin.x) / world_size.x,
		(w.y - world_origin.y) / world_size.y) * mr.size


func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	# Outer chrome (StageChrome teal).
	draw_rect(outer, Color(0.02, 0.05, 0.07, 0.88))
	draw_rect(outer, FRAME, false, 1.5)
	# Title strip.
	draw_rect(Rect2(0, 0, size.x, TITLE_H), Color(0.04, 0.10, 0.09, 0.95))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(6, TITLE_H - 4),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(0.66, 1.0, 0.90, 1.0))
	var mr := _map_rect()
	if terrain_tex != null:
		draw_texture_rect(terrain_tex, mr, false)
	else:
		draw_rect(mr, FRAME_INNER)
	draw_rect(mr, FRAME, false, 1.0)
	for d in dots:
		var p: Vector2 = _w2l(d.p)
		if mr.has_point(p):
			draw_circle(p, float(d.get("r", 2.0)), d.c)
	if view_half != Vector2.ZERO:
		var c := _w2l(focus_world)
		var hw := view_half.x / world_size.x * mr.size.x
		var hh := view_half.y / world_size.y * mr.size.y
		draw_rect(Rect2(c - Vector2(hw, hh), Vector2(hw, hh) * 2.0), VIEW_COL, false, 1.2)
