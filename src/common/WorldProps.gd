## Realistic CC0 world props (Poly by Google) for the pre-Space biomes — trees / rocks / bushes,
## spawned size-NORMALIZED (sources vary in native scale) + randomly rotated. The genome-driven
## CHARACTERS stay as they are; only the WORLD goes realistic, for a living-biome look.
##
## Usage: WorldProps.spawn_tree(self, pos, rng)  /  spawn_rock(...)  /  spawn_bush(...)
class_name WorldProps

# Cohesive single-artist flora from Quaternius' Stylized Nature MegaKit (CC0) for a lush,
# living biome. (The earlier mixed nature_realistic set is superseded by this kit.)
const MK := "res://assets/models/megakit/%s.glb"
const TREES := [
	"res://assets/models/megakit/tree1.glb",
	"res://assets/models/megakit/tree2.glb",
	"res://assets/models/megakit/pine.glb",
	"res://assets/models/megakit/twistedtree.glb",
]
const ROCKS := [
	"res://assets/models/megakit/rockmed.glb",
	"res://assets/models/megakit/pebbleround.glb",
	"res://assets/models/megakit/pebblesquare.glb",
]
const BUSHES := [
	"res://assets/models/megakit/bush.glb",
	"res://assets/models/megakit/bushflowers.glb",
	"res://assets/models/megakit/plant.glb",
	"res://assets/models/megakit/plantbig.glb",
]
# Low ground cover — clover, grasses, ferns, flowers, mushrooms — for lush, living biomes.
const GROUNDCOVER := [
	"res://assets/models/megakit/clover.glb",
	"res://assets/models/megakit/grass.glb",
	"res://assets/models/megakit/grasswispy.glb",
	"res://assets/models/megakit/tallgrass.glb",
	"res://assets/models/megakit/fern.glb",
	"res://assets/models/megakit/flowergroup.glb",
	"res://assets/models/megakit/flowersingle.glb",
	"res://assets/models/megakit/mushroom.glb",
	"res://assets/models/megakit/mushroomlaeti.glb",
]
# Per-type ground-plant heights (units), keyed by file stem. Flowers/mushrooms are tiny, ferns/grass
# low — ALL well under trees (7-12). A single 0.5-1.2 range made flowers giant + ferns tree-sized.
const GROUNDCOVER_H := {
	"clover": 0.3, "grass": 0.5, "grasswispy": 0.5, "tallgrass": 0.85,
	"fern": 0.9, "flowergroup": 0.5, "flowersingle": 0.35,
	"mushroom": 0.3, "mushroomlaeti": 0.3,
}
const CAMPFIRE := "res://assets/models/tribe_cc0/bonfire.glb"


static func spawn_tree(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	return _spawn(parent, TREES[rng.randi_range(0, TREES.size() - 1)], pos, rng.randf_range(7.0, 12.0), rng)


static func spawn_rock(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	return _spawn(parent, ROCKS[rng.randi_range(0, ROCKS.size() - 1)], pos, rng.randf_range(0.6, 1.4), rng)


static func spawn_bush(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	return _spawn(parent, BUSHES[rng.randi_range(0, BUSHES.size() - 1)], pos, rng.randf_range(1.0, 1.8), rng)


# A readable FOOD source: always the flowering/fruiting bush so the player can SEE where workers
# gather food (plain leafy bushes were ambiguous). Used to build visible berry patches.
const BERRY_BUSH := "res://assets/models/megakit/bushflowers.glb"
static func spawn_berry_bush(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	return _spawn(parent, BERRY_BUSH, pos, rng.randf_range(1.2, 1.7), rng)


static func spawn_groundcover(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var path: String = GROUNDCOVER[rng.randi_range(0, GROUNDCOVER.size() - 1)]
	var stem: String = path.get_file().get_basename()
	var h: float = float(GROUNDCOVER_H.get(stem, 0.5)) * rng.randf_range(0.85, 1.15)
	return _spawn(parent, path, pos, h, rng)


static func spawn_at(parent: Node3D, path: String, pos: Vector3, target_h: float) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node: Node3D = packed.instantiate()
	parent.add_child(node)
	Stage3D.matte_materials(node)
	node.position = pos
	_fit_height(node, target_h)
	return node


static func _spawn(parent: Node3D, path: String, pos: Vector3, target_h: float, rng: RandomNumberGenerator) -> Node3D:
	var node := spawn_at(parent, path, pos, target_h)
	if node != null:
		node.rotation.y = rng.randf() * TAU
	return node


# Scale a model so it stands `h` units tall, regardless of its source's native size.
static func _fit_height(node: Node3D, h: float) -> void:
	var box := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.transform * mi.mesh.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	if box.size.y > 0.0:
		node.scale = Vector3.ONE * (h / box.size.y)
