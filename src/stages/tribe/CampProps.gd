class_name CampProps

const STRUCTURES: Dictionary[String, String] = {
	"tent": "hut_small",
	"tent_canvas": "hut_hide",
	"hut_small": "hut_small",
	"hut_hide": "hut_hide",
	"lean_to": "lean_to",
	"campfire": "fire_pit",
	"storage": "storage_baskets",
	"crate": "storage_baskets",
	"barrel": "wood_pile",
	"bedroll": "lean_to",
	"drying_rack": "drying_rack",
	"knapping_station": "knapping_station",
	"granary_basket": "granary_basket",
	"totem_pole": "totem_pole",
	"standing_stones": "standing_stones",
	"palisade_segment": "palisade_segment",
}

const PROPS: Array[String] = [
	"storage_baskets",
	"wood_pile",
	"totem_pole",
	"standing_stones",
	"palisade_segment",
]

const _MODEL_PATH: String = "res://assets/models/generated/%s.glb"
const _DWELLINGS: Array[String] = ["hut_small", "hut_hide", "lean_to"]
const _WORK_AREAS: Dictionary[String, String] = {
	"gather_food": "granary_basket",
	"hunt": "drying_rack",
	"gather_stone": "knapping_station",
	"gather_wood": "wood_pile",
}
const _TARGET_HEIGHTS: Dictionary[String, float] = {
	"hut_small": 3.8,
	"hut_hide": 3.4,
	"lean_to": 2.4,
	"fire_pit": 0.45,
	"drying_rack": 2.1,
	"knapping_station": 1.2,
	"granary_basket": 1.35,
	"storage_baskets": 1.1,
	"wood_pile": 0.85,
	"totem_pole": 3.6,
	"standing_stones": 2.3,
	"palisade_segment": 2.7,
}
# Albedo gain per generated model whose texture came out dark against the bright ground. Models
# that already read well (baskets, huts, lean-to) are left out.
const BRIGHTEN_GAIN: Dictionary[String, float] = {
	"totem_pole": 1.5,
	"standing_stones": 1.25,
	"palisade_segment": 1.7,
	"knapping_station": 2.2,
	"wood_pile": 1.4,
}


static func has_structure(type: String) -> bool:
	return STRUCTURES.has(type)


static func structure_path(type: String) -> String:
	if not STRUCTURES.has(type):
		return ""
	return _MODEL_PATH % STRUCTURES[type]


static func dwelling_type(index: int) -> String:
	return _DWELLINGS[posmod(index, _DWELLINGS.size())]


static func work_area_type(kind: String) -> String:
	return str(_WORK_AREAS.get(kind, "granary_basket"))


static func spawn_structure(parent: Node3D, type: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	if parent == null or not has_structure(type):
		return null
	var scene: PackedScene = load(structure_path(type))
	if scene == null:
		return null
	var inst: Node3D = scene.instantiate() as Node3D
	if inst == null:
		return null
	parent.add_child(inst)
	Stage3D.matte_materials(inst)
	_brighten(inst, str(STRUCTURES[type]))
	inst.position = pos
	_fit_and_seat(inst, _target_height(type))
	inst.rotation.y = yaw
	return inst


static func scatter_props(parent: Node3D, count: int, area_radius: float, rng: RandomNumberGenerator, min_radius: float = 5.0) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if parent == null or count <= 0 or PROPS.is_empty() or rng == null:
		return spawned
	var n: int = PROPS.size()
	for i in count:
		var stem: String = PROPS[rng.randi() % n]
		var scene: PackedScene = load(_MODEL_PATH % stem)
		if scene == null:
			continue
		var inst: Node3D = scene.instantiate() as Node3D
		if inst == null:
			continue
		var angle: float = rng.randf() * TAU
		# Uniform-area sample of the [min_radius, area_radius] annulus — keeps decor off the hearth
		# (a plain sqrt(randf())*area_radius could place a prop right on top of the campfire).
		var r: float = sqrt(rng.randf() * (area_radius * area_radius - min_radius * min_radius) + min_radius * min_radius)
		inst.position = Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		parent.add_child(inst)
		Stage3D.matte_materials(inst)
		_brighten(inst, stem)
		_fit_and_seat(inst, _target_height(stem) * rng.randf_range(0.88, 1.14))
		inst.rotation.y = rng.randf() * TAU
		spawned.append(inst)
	return spawned


static func _brighten(inst: Node3D, stem: String) -> void:
	if BRIGHTEN_GAIN.has(stem):
		Stage3D.gain_materials(inst, BRIGHTEN_GAIN[stem])


static func _target_height(type: String) -> float:
	var stem: String = str(STRUCTURES.get(type, type))
	return float(_TARGET_HEIGHTS.get(stem, 1.5))


static func _fit_and_seat(root: Node3D, height: float) -> void:
	var box := _root_aabb(root)
	if box.size.y <= 0.001:
		return
	var scale_factor: float = height / box.size.y
	root.scale = Vector3.ONE * scale_factor
	var center_x: float = box.position.x + box.size.x * 0.5
	var center_z: float = box.position.z + box.size.z * 0.5
	root.position.x -= center_x * scale_factor
	root.position.y -= box.position.y * scale_factor
	root.position.z -= center_z * scale_factor


static func _root_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var have := false
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = _local_to_root(mi, root) * mi.mesh.get_aabb()
		if not have:
			box = b
			have = true
		else:
			box = box.merge(b)
	return box if have else AABB(Vector3.ZERO, Vector3.ONE)


static func _local_to_root(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != root:
		t = cur.transform * t
		cur = cur.get_parent() as Node3D
	return t
