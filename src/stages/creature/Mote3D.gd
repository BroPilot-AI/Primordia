class_name Mote3D extends Area3D

var nutrition: float = 0.0
var _collected: bool = false
var _player: Node3D = null


func _ready() -> void:
	add_to_group("motes")
	body_entered.connect(_on_body_entered)
	var cshape := CollisionShape3D.new()
	cshape.shape = SphereShape3D.new()
	cshape.shape.radius = 2.5
	add_child(cshape)
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	mi.mesh.radius = 0.4
	mi.mesh.height = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.82, 0.30)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.82, 0.30)
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)
	_player = get_tree().get_first_node_in_group("player")


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	var stage: Node = get_parent()
	if stage != null and stage.has_method("gather"):
		stage.gather("food", 1)
	_collected = true
	visible = false
	await get_tree().create_timer(5.0).timeout
	queue_free()


func _process(_delta: float) -> void:
	if _collected:
		return
	position.y = 0.3 + sin(Time.get_ticks_msec() / 600.0) * 0.15
