class_name Minimap extends Control
## Simple blip minimap (non-terrain). Brand chrome matches StageChrome / Minimap2D.

const FRAME := Color(0.42, 0.86, 0.78, 0.85)
const TITLE_H := 16.0

var world_rect := Rect2(0, 0, 1000, 1000)
var _blips: Array = []
var title: String = "RADAR"


func configure(r: Rect2) -> void:
	world_rect = r
	queue_redraw()


func set_blips(blips: Array) -> void:
	_blips = blips
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(180, 130)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _map_rect() -> Rect2:
	return Rect2(2.0, TITLE_H + 2.0, size.x - 4.0, size.y - TITLE_H - 4.0)


func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	draw_rect(outer, Color(0.02, 0.05, 0.07, 0.88))
	draw_rect(outer, FRAME, false, 1.5)
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
	draw_rect(mr, Color(0.03, 0.06, 0.06, 0.9))
	draw_rect(mr, FRAME, false, 1.0)
	for blip in _blips:
		var bx: float = world_rect.size.x
		var by: float = world_rect.size.y
		if bx == 0.0 or by == 0.0:
			continue
		var local: Vector2 = mr.position + (blip.pos - world_rect.position) / Vector2(bx, by) * mr.size
		if not mr.has_point(local):
			continue
		draw_circle(local, 3.0 if blip.big else 2.0, blip.color)
