class_name RivalBand3D extends Node3D

const CHAR := "res://assets/models/kenney-characters/%s.glb"

var _speed: float = 80.0
var _wander_radius: float = 500.0
var _raid_cooldown: float = 8.0
var _raid_range: float = 120.0
var _raid_t: float = 0.0
var _wander_t: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _wander_interval: float = 3.0
var _models: Array[Node3D] = []
var _player: Node3D = null
var _stage: Node = null


func _ready() -> void:
	add_to_group("rival")
	_stage = get_parent()
	_player = get_tree().get_first_node_in_group("player")
	var stems: Array[String] = ["character-male-a", "character-male-b", "character-female-a", "character-female-b"]
	for i in mini(3, stems.size()):
		var stem: String = stems[i]
		var node: Node3D = spawn_char(stem)
		if node:
			node.position = Vector3(i * 1.5 - 1.5, 0, 0)
	_pick_wander_target()


func spawn_char(stem: String) -> Node3D:
	var packed: PackedScene = load(CHAR % stem) as PackedScene
	if packed == null:
		return null
	var inst: Node3D = packed.instantiate()
	inst.scale = Vector3.ONE * 0.5
	add_child(inst)
	var tint: Color = Color(0.7, 0.2, 0.2)
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = tint
		m.roughness = 0.85
		mi.set_surface_override_material(0, m)
	return inst


func _process(delta: float) -> void:
	_wander_t += delta
	if _wander_t >= _wander_interval:
		_wander_t = 0.0
		_pick_wander_target()
	var dir: Vector3 = (_wander_target - global_position).normalized()
	global_position += dir * _speed * delta
	if global_position.distance_to(_wander_target) < 5.0:
		_pick_wander_target()
	if _player == null:
		return
	var dist: float = global_position.distance_to(_player.global_position)
	_raid_t += delta
	if _raid_t >= _raid_cooldown and dist < _raid_range:
		_raid_t = 0.0
		if _stage != null and _stage.has_method("raid"):
			_stage.raid(1)


func _pick_wander_target() -> void:
	_wander_target = Vector3(
		randf_range(-_wander_radius, _wander_radius),
		0,
		randf_range(-_wander_radius, _wander_radius)
	)
	if global_position.distance_to(_wander_target) > 0.1:
		look_at(_wander_target, Vector3.UP, true)   # Kenney characters' front is +Z
