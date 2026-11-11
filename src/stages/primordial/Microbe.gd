class_name Microbe
extends Area2D
## A biome food / microorganism. The generator sets `food` (a FoodRoster entry plus a
## derived `radius`) before adding it. Renders `food_<id>.png` if that art exists, else a
## tinted circle (fallback), and gives it a gentle desynced wiggle (bob + sway + pulse) so
## the soup feels alive. Edible is SIZE-GATED — only eaten when you are at least as big as
## it; bigger edibles bite back. Hazards always set you back + keep a red danger ring.

const TEX_SIZE := 256.0
const RECHECK_INTERVAL := 0.25   # s between re-tries on food the germ is already touching
const CompoundFieldModel := preload("res://src/stages/primordial/CompoundField.gd")

var food: Dictionary = {}
var radius := 22.0
var ambient_atp := 0.0

var _has_sprite := false
var _spr: Sprite2D
var _base_scale := 1.0
var _compound_scale := 1.0
var _compound_glow := Color(1, 1, 1)
var _home := Vector2.INF
var _t := 0.0
var _phase := 0.0
var _bob := 4.0
var _sway := 0.12
var _freq := 2.0
var _recheck_t := 0.0


func _ready() -> void:
	# (monitoring defaults to true; setting it here errors when spawned mid-physics-flush)
	collision_mask = 1  # detect the player germ (body layer 1)
	radius = float(food.get("radius", 22.0))

	# Per-instance motion so the field isn't synchronized.
	_phase = randf() * TAU
	_freq = randf_range(1.8, 3.2)
	_bob = randf_range(6.0, 12.0)
	_sway = randf_range(0.18, 0.42)

	var path := "res://assets/sprites/food_%s.png" % String(food.get("id", ""))
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex != null:
			_base_scale = radius * 2.0 / TEX_SIZE
			_spr = Sprite2D.new()
			_spr.texture = tex
			_spr.scale = Vector2.ONE * _base_scale
			add_child(_spr)
			_has_sprite = true
	queue_redraw()

	var c := CircleShape2D.new()
	c.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = c
	add_child(shape)

	body_entered.connect(_on_body_entered)


# Gentle organic motion: bob around the spawn point, sway, and (with a sprite) pulse.
func _process(delta: float) -> void:
	if _home == Vector2.INF:
		_home = position
	_t += delta
	position = _home + Vector2(sin(_t * _freq + _phase), cos(_t * _freq * 0.8 + _phase) * 0.7) * _bob
	rotation = sin(_t * _freq * 0.7 + _phase) * _sway
	if _spr != null:
		_spr.scale = Vector2.ONE * (_base_scale * _compound_scale * (1.0 + sin(_t * _freq * 1.4 + _phase) * 0.14))
		_spr.modulate = _spr.modulate.lerp(_compound_glow, delta * 2.5)
	ambient_atp = maxf(0.0, ambient_atp - delta * 0.5)
	_recheck_t -= delta
	if _recheck_t <= 0.0:
		_recheck_t = RECHECK_INTERVAL
		_eat_outgrown_overlaps()


func _draw() -> void:
	var hazard := String(food.get("type", "EDIBLE")) == "HAZARD"
	var draw_radius := radius * _compound_scale
	if not _has_sprite:
		var tint: Color = food.get("tint", Color(0.6, 0.8, 0.6))
		draw_circle(Vector2.ZERO, draw_radius, tint.lerp(_compound_glow, 0.18))
		var ring := Color(1, 0.25, 0.25) if hazard else tint.darkened(0.3)
		draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, 28, ring, 3.0 if hazard else 2.0)
	elif hazard:
		draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, 28, Color(1, 0.25, 0.25), 3.0)


func absorb_compounds(compounds: Dictionary, delta: float) -> void:
	var glucose := CompoundFieldModel.sample(float(compounds.get("glucose", 0.0)))
	var oxygen := CompoundFieldModel.sample(float(compounds.get("oxygen", 0.0)))
	var ammonia := CompoundFieldModel.sample(float(compounds.get("ammonia", 0.0)))
	var phosphates := CompoundFieldModel.sample(float(compounds.get("phosphates", 0.0)))
	var target_atp := clampf(glucose * 0.010 + oxygen * 0.006 + ammonia * 0.004 + phosphates * 0.004, 0.0, 16.0)
	ambient_atp = lerpf(ambient_atp, target_atp, clampf(delta * 3.5, 0.0, 1.0))
	_compound_scale = 1.0 + clampf(ambient_atp / 120.0, 0.0, 0.10)
	_compound_glow = Color(1.0, 1.0, 1.0).lerp(Color(0.70, 1.0, 0.82), clampf(ambient_atp / 20.0, 0.0, 0.35))
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if String(food.get("type", "EDIBLE")) == "HAZARD":
		if body.has_method("harm"):
			body.harm(0.5)
		Events.player_harmed.emit(PrimordialBalance.VIRUS_SETBACK)   # toxin/virus = setback
		Events.food_consumed.emit(food)
		queue_free()
		return

	if not _try_eat(body) and body.has_method("harm"):
		# Bigger than you — it bites back. Setback, but you survive (non-lethal).
		body.harm(0.5)


# Edible: size-gated. Only eat what is (roughly) not bigger than you.
func _try_eat(body: Node) -> bool:
	var pr := 24.0
	if body.has_method("get_radius"):
		pr = body.get_radius()
	if pr < radius * 0.85:
		return false
	if body.has_method("grow"):
		body.grow(float(food.get("nutrition", 0.1)))
	Events.food_consumed.emit(food)
	queue_free()
	return true


# body_entered fires once per contact: a germ that outgrows food it is pressed against eats it now.
func _eat_outgrown_overlaps() -> void:
	if String(food.get("type", "EDIBLE")) == "HAZARD":
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and _try_eat(body):
			return
