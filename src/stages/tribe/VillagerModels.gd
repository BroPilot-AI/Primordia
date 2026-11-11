## Single source for tribal humanoid 3D models - Kenney CC0 character kit. Each model may ship
## an AnimationPlayer; attach() size-normalizes by AABB to a natural height and starts a looping
## idle/walk clip so the band is visibly populated on the RTS map.
class_name VillagerModels

const DIR := "res://assets/models/kenney-characters/%s.glb"

const _DATA := {
	"male": {"model": "character-male-a", "height": 1.7},
	"female": {"model": "character-female-a", "height": 1.65},
	"child": {"model": "character-male-b", "height": 1.1},
	"leader": {"model": "character-male-c", "height": 1.8},
}
const FALLBACK := "male"
# Preferred loop clip (case-insensitive substring), first match wins; else the first clip.
const _CLIP_PREF := ["idle", "walk", "run"]


static func has_role(role: String) -> bool:
	return _DATA.has(role)


static func model_path(role: String) -> String:
	return DIR % str(_DATA.get(role, _DATA[FALLBACK])["model"])


static func _height(role: String) -> float:
	return float(_DATA.get(role, _DATA[FALLBACK])["height"])


## Spawn the villager as a child of `parent`, AABB-fit to height x body_mult, feet at `foot_offset`,
## and start a looping motion animation. Returns the model node, or null if missing.
static func attach(parent: Node3D, role: String, body_mult: float = 1.0, foot_offset: float = 0.0) -> Node3D:
	var packed := load(model_path(role)) as PackedScene
	if packed == null:
		push_warning("VillagerModels: missing model for %s" % role)
		return null
	var model: Node3D = packed.instantiate()
	parent.add_child(model)
	Stage3D.matte_materials(model)
	model.position = Vector3(0, foot_offset, 0)
	_fit_height(model, _height(role) * body_mult)
	_play_loop(model)
	return model


static func roster(count: int, rng: RandomNumberGenerator) -> Array[String]:
	var roles: Array[String] = []
	for i in count:
		if i == 0:
			roles.append("leader")
		else:
			var roll := rng.randf()
			if roll < 0.42:
				roles.append("male")
			elif roll < 0.84:
				roles.append("female")
			else:
				roles.append("child")
	return roles


# Find the model's AnimationPlayer and loop a motion clip so it's never a frozen statue.
static func _play_loop(root: Node) -> void:
	var ap: AnimationPlayer = null
	for n in root.find_children("*", "AnimationPlayer", true, false):
		ap = n as AnimationPlayer
		break
	if ap == null:
		return
	var names := ap.get_animation_list()
	if names.is_empty():
		return
	var chosen: String = names[0]
	for pref in _CLIP_PREF:
		var hit := false
		for a in names:
			if String(a).to_lower().contains(pref):
				chosen = String(a)
				hit = true
				break
		if hit:
			break
	var anim := ap.get_animation(chosen)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	ap.play(chosen)
	# Desync villagers so they don't move in lockstep.
	ap.seek(randf() * maxf(0.1, anim.length if anim != null else 1.0), true)


# Scale a model so it stands `h` units tall regardless of its source's native size.
static func _fit_height(node: Node3D, h: float) -> void:
	var box := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		# Accumulate every transform from the mesh up to `node`, not just mi.transform -
		# rigged glbs park a large (e.g. 100x) scale on an Armature node ABOVE the Skeleton,
		# which mi.transform alone misses, making the measured height ~100x too small and the
		# fitted model balloon to hundreds of units.
		var b: AABB = _local_to_root(mi, node) * mi.mesh.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	if box.size.y > 0.0:
		node.scale = Vector3.ONE * (h / box.size.y)


# Accumulated transform of `mi` expressed in `root`'s local space (independent of tree state).
static func _local_to_root(mi: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node3D = mi
	while cur != null and cur != root:
		t = cur.transform * t
		cur = cur.get_parent() as Node3D
	return t
