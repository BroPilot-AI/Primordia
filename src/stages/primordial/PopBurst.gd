class_name PopBurst
extends Node2D
## A short, code-drawn "pop": an expanding fading ring plus a spray of flung specks. Lives
## ~0.45s then frees itself. Spawned where a spore pops a predator (or any little death),
## tinted to taste. Pure draw — no art, no physics.

var color := Color(0.6, 1.0, 0.5)
var spread := 46.0

const LIFE := 0.45

var _age := 0.0
var _bits: Array = []


func _ready() -> void:
	for _i in 9:
		_bits.append({
			dir = Vector2.RIGHT.rotated(randf() * TAU),
			dist = randf_range(0.6, 1.0),
			r = randf_range(2.0, 4.5),
		})
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= LIFE:
		queue_free()


func _draw() -> void:
	var k := _age / LIFE                       # 0 -> 1 over the life
	var a := 1.0 - k
	# Expanding shockwave ring.
	draw_arc(Vector2.ZERO, spread * k, 0.0, TAU, 28, Color(color.r, color.g, color.b, a), 3.0 * (1.0 - k * 0.5))
	# Flung specks, easing out.
	var eased := 1.0 - (1.0 - k) * (1.0 - k)
	for b in _bits:
		var p: Vector2 = b.dir * (spread * b.dist * eased)
		draw_circle(p, b.r * a, Color(color.r, color.g, color.b, a))
