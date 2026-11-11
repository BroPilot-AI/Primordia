## Reusable drag-selection rectangle overlay, patterned on godot-open-rts'
## RectangularSelection2D. A full-screen, input-transparent Control that draws the live drag
## rectangle. The owning stage feeds it screen-space points and reads back the final Rect2, then
## tests each unit via Camera3D.unproject_position (screen-space hit test — the simple selection-box
## approach from the gameidea.org RTS tutorial). Add to a CanvasLayer above the 3D viewport.
extends Control

const FILL := Color(0.45, 0.85, 1.0, 0.15)
const BORDER := Color(0.55, 0.9, 1.0, 0.9)

var _active: bool = false
var _start: Vector2 = Vector2.ZERO
var _end: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eat clicks meant for the map/HUD


func begin(p: Vector2) -> void:
	_start = p
	_end = p
	_active = true
	queue_redraw()


func update_to(p: Vector2) -> void:
	if not _active:
		return
	_end = p
	queue_redraw()


# Stop drawing and return the final rectangle in screen space.
func finish() -> Rect2:
	_active = false
	queue_redraw()
	return rect()


func cancel() -> void:
	_active = false
	queue_redraw()


func rect() -> Rect2:
	var tl := Vector2(minf(_start.x, _end.x), minf(_start.y, _end.y))
	var br := Vector2(maxf(_start.x, _end.x), maxf(_start.y, _end.y))
	return Rect2(tl, br - tl)


func _draw() -> void:
	if not _active:
		return
	var r := rect()
	draw_rect(r, FILL, true)
	draw_rect(r, BORDER, false, 1.5)
