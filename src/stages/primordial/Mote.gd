## Edible food mote — abundant filler. Carries a `tint` (set by the generator) that both
## colors the orb and leans the player's genome color toward it when eaten — so a diet of
## mostly one color makes you that color. Drawn as a vivid little orb (no art needed).
class_name Mote
extends Area2D

@export var nutrition := PrimordialBalance.MOTE_NUTRITION

var radius := 8.0
var tint := Color(0.95, 0.85, 0.35)  # default warm yellow; the soup overrides per-mote


func _ready() -> void:
	# (monitoring defaults to true; setting it here errors when spawned mid-physics-flush)
	collision_mask = 1  # detect the player germ (body layer 1)
	queue_redraw()

	var c := CircleShape2D.new()
	c.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = c
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, tint)
	# Soft highlight for a glossy orb look.
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.35, Color(1, 1, 1, 0.5))


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("grow"):
		body.grow(nutrition)
	EvolutionState.absorb_pigment(tint)
	Events.mote_eaten.emit(nutrition)
	queue_free()
