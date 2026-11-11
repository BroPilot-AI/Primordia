class_name SoupHunter
extends Node2D
## A slow biome predator the player must AVOID. Normally it drifts toward you well below
## your swim speed — but if you wander into range it does a short BURST of speed (a lunge)
## to catch the inattentive, and on contact it NIBBLES: small repeated progress loss +
## shrink (non-lethal). Themed per biome via `data` (a FoodRoster.PREDATORS entry).
## Code-drawn until predator_<id>.png art lands.

const TEX_SIZE := 256.0
const LUNGE_RANGE := 170.0     # how close you must be to trigger a lunge
const LUNGE_TIME := 0.45       # how long the burst lasts
const LUNGE_COOLDOWN := 1.8    # recovery between lunges
const LUNGE_MULT := 2.4        # speed multiplier during the burst (a catch-up lunge, NOT a
                               # top-speed dash — must stay below the player's swim speed so a
                               # fleeing germ can break range; max cruise 104 * 2.4 = 250 << 340)
const NIBBLE_COOLDOWN := 0.6   # time between bites while in contact
const AGGRO_RANGE := 560.0     # only notices (and drifts toward) a germ this close — otherwise
                               # every hunter in the loaded window converges on the player
const PREY_NUTRITION := 0.5    # food value once outgrown and eaten (~ the best microbe): hunters
                               # respawn with their sector, so a bigger meal turns into a farm
const BITE_SETBACK_MULT := 0.15  # progress lost per nibble = setback * this (seconds of feeding)
const MATCH_MIN := 0.6         # a hunter is born at germ radius * a roll in this range, never
const MATCH_MAX := 1.4         # below its base size; the germ outgrows base hunters in ~30 s, and
                               # without this the predator was harmless for the rest of the stage

var data: Dictionary = {}
var radius := 34.0
var _speed := 90.0
var _lunge_t := 0.0
var _lunge_cd := 0.0
var _nibble_cd := 0.0
var _has_sprite := false


func _ready() -> void:
	add_to_group("predator")  # so defensive spores can find + pop us
	radius = float(data.get("radius", 34.0))
	_speed = float(data.get("speed", 90.0))
	var germ := get_tree().get_first_node_in_group("player")
	if germ != null and germ.has_method("get_radius"):
		radius = maxf(radius, germ.get_radius() * randf_range(MATCH_MIN, MATCH_MAX))

	var path := "res://assets/sprites/predator_%s.png" % String(data.get("id", ""))
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex != null:
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.scale = Vector2.ONE * (radius * 2.2 / TEX_SIZE)
			add_child(spr)
			_has_sprite = true
	queue_redraw()


func _physics_process(delta: float) -> void:
	_lunge_cd = maxf(0.0, _lunge_cd - delta)
	_lunge_t = maxf(0.0, _lunge_t - delta)
	_nibble_cd = maxf(0.0, _nibble_cd - delta)

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	var d := to_player.length()
	if d > AGGRO_RANGE:
		modulate = Color(1, 1, 1)
		return

	var pr := 24.0
	if player.has_method("get_radius"):
		pr = player.get_radius()
	var outgrown := pr > radius * 1.1

	# Burst toward the player when you stray into range and it's recovered.
	# (A scaled-up hunter reaches as far past its own edge as a base-size one.)
	var reach := LUNGE_RANGE + radius - float(data.get("radius", radius))
	if not outgrown and _lunge_t <= 0.0 and _lunge_cd <= 0.0 and d < reach and d > radius:
		_lunge_t = LUNGE_TIME
		_lunge_cd = LUNGE_COOLDOWN

	var spd := _speed * (LUNGE_MULT if _lunge_t > 0.0 else 1.0)
	if d > 1.0:
		# Once outgrown it is the prey: it swims away instead of serving itself up.
		global_position += (to_player / d) * spd * delta * (-1.0 if outgrown else 1.0)

	# Telegraph the lunge with a reddish flash.
	modulate = Color(1.0, 0.7, 0.7) if _lunge_t > 0.0 else Color(1, 1, 1)

	# On contact: if you've outgrown the hunter, you turn the tables and EAT it (once its
	# centre is inside your body). Otherwise it nibbles you (small repeated bite + progress loss).
	if d < (pr if outgrown else radius):
		if outgrown:
			_devoured(player)
		elif _nibble_cd <= 0.0:
			_nibble_cd = NIBBLE_COOLDOWN
			# Toxin vacuoles are the germ's defense organelle: each one blunts the bite.
			var layout: Array = player.get("organelle_layout") if "organelle_layout" in player else []
			var sting := 1.0 / (1.0 + layout.count("toxin_vacuole"))
			Events.player_harmed.emit(float(data.get("setback", 0.12)) * BITE_SETBACK_MULT * sting)
			if player.has_method("harm"):
				player.harm(0.25 * sting)


## Popped by a defensive spore — just die.
func kill() -> void:
	queue_free()


# The player has outgrown us and made contact: a big meal + a push toward carnivory/size
# (eating a hunter should make you more of a predator — feeds the genome spine).
func _devoured(player: Node) -> void:
	if player.has_method("grow"):
		player.grow(0.9)
	Events.food_consumed.emit({
		"id": "prey_%s" % String(data.get("id", "")),
		"type": "EDIBLE",
		"nutrition": PREY_NUTRITION,
		"nudges": {"carnivory": 0.12, "size": 0.06, "defense": 0.03},
		"tint": data.get("tint", Color(0.8, 0.3, 0.3)),
	})
	queue_free()


func _draw() -> void:
	if _has_sprite:
		return
	var tint: Color = data.get("tint", Color(0.75, 0.4, 0.7))
	var id := String(data.get("id", ""))
	match id:
		"hydra":
			_draw_tentacled(tint, 7)
		"sea_jelly":
			_draw_bell(tint)
		"lurker":
			_draw_lurker(tint)
		"nematode":
			_draw_worm(tint)
		_:
			_draw_tentacled(tint, 8)


func _draw_tentacled(tint: Color, arms: int) -> void:
	for i in arms:
		var a := TAU * float(i) / float(arms) + 0.2
		var tip := Vector2(cos(a), sin(a)) * radius * 1.55
		draw_line(tip * 0.35, tip, tint.darkened(0.25), 5.0)
		draw_circle(tip, radius * 0.12, tint.lightened(0.08))
	draw_circle(Vector2.ZERO, radius * 0.78, tint)
	draw_circle(Vector2(-radius * 0.18, -radius * 0.1), radius * 0.16, tint.lightened(0.25))
	draw_circle(Vector2(radius * 0.22, -radius * 0.08), radius * 0.12, Color(0.08, 0.05, 0.06, 0.9))


func _draw_bell(tint: Color) -> void:
	draw_arc(Vector2(0, radius * 0.15), radius * 0.95, PI, TAU, 18, tint, 10.0)
	draw_circle(Vector2(0, -radius * 0.05), radius * 0.72, tint)
	for i in 5:
		var x := lerpf(-radius * 0.45, radius * 0.45, float(i) / 4.0)
		draw_line(Vector2(x, radius * 0.15), Vector2(x * 1.15, radius * 1.35), tint.darkened(0.2), 3.0)
	draw_circle(Vector2(-radius * 0.18, -radius * 0.18), radius * 0.14, Color(0.95, 0.92, 1.0, 0.7))


func _draw_lurker(tint: Color) -> void:
	draw_circle(Vector2(0, radius * 0.1), radius * 0.85, tint)
	var jaw := PackedVector2Array([
		Vector2(-radius * 0.55, radius * 0.2),
		Vector2(0, radius * 1.25),
		Vector2(radius * 0.55, radius * 0.2),
	])
	draw_colored_polygon(jaw, tint.lightened(0.08))
	draw_circle(Vector2(0, -radius * 0.15), radius * 0.22, Color(1.0, 0.85, 0.35, 0.95))
	draw_circle(Vector2(0, -radius * 0.15), radius * 0.08, Color(0.05, 0.02, 0.08))


func _draw_worm(tint: Color) -> void:
	for i in 5:
		var t := float(i) / 4.0
		var p := Vector2(lerpf(-radius * 0.9, radius * 0.9, t), sin(t * PI) * radius * 0.22)
		draw_circle(p, radius * lerpf(0.42, 0.22, t), tint.darkened(t * 0.2))
	draw_circle(Vector2(-radius * 0.72, 0.0), radius * 0.12, Color(0.12, 0.08, 0.05))
	draw_circle(Vector2(-radius * 0.55, -radius * 0.12), radius * 0.1, Color(0.12, 0.08, 0.05))
