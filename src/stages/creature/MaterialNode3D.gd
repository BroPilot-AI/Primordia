class_name MaterialNode3D extends Area3D

signal collected(node: MaterialNode3D)

@export var material_id: String = "fiber"

var _color: Color = Color(0.46, 0.78, 0.26)
var _player: Node3D = null


func _ready() -> void:
	add_to_group("materials")
	body_entered.connect(_on_body_entered)
	match material_id:
		"food":    _color = Color(0.95, 0.82, 0.30)
		"fiber":   _color = Color(0.46, 0.78, 0.26)
		"wood":    _color = Color(0.57, 0.37, 0.18)
		"stone":   _color = Color(0.55, 0.55, 0.57)
		"shell":   _color = Color(0.88, 0.84, 0.74)
		"crystal": _color = Color(0.53, 0.28, 0.86)
		"clay":    _color = Color(0.76, 0.45, 0.29)
	_build_pickup()
	_player = get_tree().get_first_node_in_group("player")


func _build_pickup() -> void:
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.6, 0.4, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color
	mat.roughness = 0.9
	body.material_override = mat
	add_child(body)
	var cshape := CollisionShape3D.new()
	cshape.shape = SphereShape3D.new()
	cshape.shape.radius = 2.5
	add_child(cshape)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	collected.emit(self)
	var stage: Node = get_parent()
	if stage != null and stage.has_method("gather"):
		stage.gather(material_id, 1)
	queue_free()
