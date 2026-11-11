class_name TribeAnimal3D extends Node3D

const SPEED: Dictionary = {"deer": 115.0, "boar": 70.0, "wolf": 135.0}
const FOOD: Dictionary = {"deer": 6, "boar": 14, "wolf": 0}
const HUE: Dictionary = {"deer": Color(0.72, 0.56, 0.36), "boar": Color(0.4, 0.3, 0.25), "wolf": Color(0.55, 0.55, 0.62)}
const FLEE_RADIUS: float = 12.0
const CATCH_RADIUS: float = 2.5
const WOLF_BITE_RADIUS: float = 2.0
const WOLF_RETREAT_TIME: float = 4.0

var kind: String = "deer"
var _wander: Vector3 = Vector3.ZERO
var _wander_t: float = 0.0
var _retreat_t: float = 0.0
var _stage: Node = null
var _player: Node3D = null


func _ready() -> void:
	add_to_group("animals")
	_stage = get_parent()
	_player = get_tree().get_first_node_in_group("player")
	_build_body()
	# Defer the first wander pick: the stage sets our spawn position right after add_child,
	# so computing it here (still at the origin) would make distant spawns beeline to camp.
	call_deferred("_init_wander")


func _init_wander() -> void:
	_wander = position + _rand_offset()


func _build_body() -> void:
	if AnimalModels.attach(self, kind, 1.6) != null:
		return
	var body: MeshInstance3D = MeshInstance3D.new()
	var col: Color = HUE.get(kind, Color.WHITE)
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.0, 0.8, 1.4)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	body.material_override = mat
	body.position.y = 0.5
	add_child(body)


func _rand_offset() -> Vector3:
	return Vector3(randf_range(-20.0, 20.0), 0, randf_range(-20.0, 20.0))


func _process(delta: float) -> void:
	var spd: float = SPEED.get(kind, 100.0)
	if kind == "wolf":
		if _retreat_t > 0.0:
			# Bit once and scattered the band — now it lopes off and leaves (it used to camp on the
			# leader at the fire and bite every 3s forever, draining all food with no counterplay).
			_retreat_t -= delta
			if _player != null:
				var away: Vector3 = global_position - _player.global_position
				away.y = 0.0
				if away.length() > 0.01:
					global_position += away.normalized() * spd * delta
					_face(away)
			if _retreat_t <= 0.0:
				queue_free()
			return
		if _player != null:
			var to_p: Vector3 = _player.global_position - global_position
			to_p.y = 0.0   # ground-plane chase — don't levitate toward the capsule's hover
			if to_p.length() > WOLF_BITE_RADIUS:
				var dir: Vector3 = to_p.normalized()
				global_position += dir * spd * delta
				_face(dir)
			else:
				# In range: bite (scatters the band / steals food). The old `elif` bound to
				# `_player != null`, so this NEVER fired while a player existed.
				_retreat_t = WOLF_RETREAT_TIME
				if _stage and _stage.has_method("wolf_scatter"):
					_stage.wolf_scatter()
		return
	if _player != null:
		var d: float = global_position.distance_to(_player.global_position)
		if d < CATCH_RADIUS:
			if _stage and _stage.has_method("hunt"):
				_stage.hunt(kind, FOOD.get(kind, 4))
			queue_free()
			return
		if d < FLEE_RADIUS:
			var away: Vector3 = (global_position - _player.global_position).normalized()
			global_position += away * spd * delta
			_face(away)
			return
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(2.0, 4.0)
		_wander = position + _rand_offset()
	var wander_dir: Vector3 = (_wander - global_position).normalized()
	global_position += wander_dir * spd * 0.4 * delta
	_face(wander_dir)


# Turn to face travel on the ground plane. The animal GLBs' front is +Z, so aim +Z (use_model_front);
# plain look_at aims -Z and the animal runs backwards. Skips near-zero moves (look_at would error).
func _face(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.01:
		look_at(global_position + flat.normalized(), Vector3.UP, true)
