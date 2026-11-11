class_name Spore
extends Node2D
## A defensive spore budded off the player at evolution milestones. It seeks out and homes in
## on the NEAREST predator, then pops it on contact — but ONE spore kills ONE hunter, so it's
## a guided strike, not a lawnmower. Scarce by design (a handful per run) and it fades out
## after its lifetime. Distance-polled (no Area2D) so it never touches the physics-flush
## monitoring trap. Strength (the genome's defense axis) sizes/extends/speeds it.

const TEX_SIZE := 256.0
const PopBurstScript := preload("res://src/stages/primordial/PopBurst.gd")

const SEEK_SPEED := 135.0   # cruising speed once locked onto a target
const TURN_RATE := 4.0      # how hard it can curve toward the target (higher = tighter)

var radius := 16.0

var _life := 7.0
var _age := 0.0
var _vel := Vector2.ZERO
var _spr: Sprite2D


func setup(strength: float) -> void:
	radius = 14.0 + clampf(strength, 0.0, 1.0) * 10.0
	_life = 6.0 + clampf(strength, 0.0, 1.0) * 3.0


func _ready() -> void:
	# Drop where the player budded it, drifting gently in a random direction.
	_vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(18.0, 34.0)
	# Use spore.png if it exists; else the procedural draw below.
	var path := "res://assets/sprites/spore.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex != null:
			_spr = Sprite2D.new()
			_spr.texture = tex
			_spr.scale = Vector2.ONE * (radius * 2.4 / TEX_SIZE)
			add_child(_spr)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	modulate.a = 1.0 if _age < _life - 1.5 else maxf(0.0, (_life - _age) / 1.5)
	if _age >= _life:
		queue_free()
		return

	# Lock onto the nearest predator and curve toward it; idle-drift if the soup is clear.
	var target := _nearest_predator()
	if target != null:
		var desired := (target.global_position - global_position).normalized() * (SEEK_SPEED + radius * 1.5)
		_vel = _vel.lerp(desired, clampf(delta * TURN_RATE, 0.0, 1.0))
	else:
		_vel = _vel.lerp(Vector2.ZERO, delta * 0.8)  # ease to a near-stop
	position += _vel * delta
	queue_redraw()

	# On contact with the locked target, pop it (one spore, one kill).
	if target != null and is_instance_valid(target):
		var pr: float = float(target.radius) if "radius" in target else 30.0
		if global_position.distance_to(target.global_position) < radius + pr * 0.8:
			_pop_at(target.global_position, pr)
			if target.has_method("kill"):
				target.kill()
			queue_free()
			return


# The closest live predator anywhere in the world, or null if the soup is currently clear.
func _nearest_predator() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("predator"):
		if not is_instance_valid(p):
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


# Spawn a one-shot pop burst as a sibling (deferred — we're mid-physics callback).
func _pop_at(at: Vector2, scale_r: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var burst := PopBurstScript.new()
	burst.color = Color(0.55, 1.0, 0.45)
	burst.spread = 40.0 + scale_r
	burst.position = at
	parent.call_deferred("add_child", burst)


func _draw() -> void:
	if _spr != null:
		return
	var c := Color(0.55, 1.0, 0.45)
	draw_circle(Vector2.ZERO, radius, Color(c.r, c.g, c.b, 0.30))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, c, 2.0)
	for i in 10:
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 10.0 + _age * 1.5)
		draw_line(dir * radius, dir * (radius * 1.4), c, 2.0)
