## Single source for wildlife 3D models — Quaternius "Animated Animal Pack" (CC0). Each model
## ships an AnimationPlayer; attach() size-normalizes by AABB to a natural height and starts a
## looping motion clip so the creatures are visibly ALIVE (walking/idling) on the RTS map.
## `height` is the model's natural in-game height at body_mult 1.0; stages pass body_mult > 1
## to enlarge for visibility. Shared by TribeAnimal3D, Predator3D, and CivStage3D wildlife.
class_name AnimalModels

const DIR := "res://assets/models/animals_animated/%s.glb"

const _DATA := {
	"deer":  {model = "deer",  height = 1.7},
	"stag":  {model = "stag",  height = 1.9},
	"wolf":  {model = "wolf",  height = 1.2},
	"fox":   {model = "fox",   height = 0.8},
	"cow":   {model = "cow",   height = 1.6},
	"bull":  {model = "bull",  height = 1.6},
	"boar":  {model = "bull",  height = 1.4},   # legacy alias — no boar in the pack
	"horse": {model = "horse", height = 1.9},
	"whitehorse": {model = "whitehorse", height = 1.9},
	"donkey": {model = "donkey", height = 1.5},
	"alpaca": {model = "alpaca", height = 1.6},
	"husky": {model = "husky", height = 1.0},
	"shiba": {model = "shiba", height = 0.8},
}
const FALLBACK := "deer"
# Preferred loop clip (case-insensitive substring), first match wins; else the first clip.
const _CLIP_PREF := ["walk", "gallop", "run", "idle"]


static func has_kind(kind: String) -> bool:
	return _DATA.has(kind)


static func model_path(kind: String) -> String:
	return DIR % str(_DATA.get(kind, _DATA[FALLBACK]).model)


static func _height(kind: String) -> float:
	return float(_DATA.get(kind, _DATA[FALLBACK]).height)


## Spawn the animal as a child of `parent`, AABB-fit to height × body_mult, feet at `foot_offset`,
## and start a looping motion animation. Returns the model node, or null if missing.
static func attach(parent: Node3D, kind: String, body_mult: float = 1.0, foot_offset: float = 0.0) -> Node3D:
	var packed := load(model_path(kind)) as PackedScene
	if packed == null:
		push_warning("AnimalModels: missing model for %s" % kind)
		return null
	var model: Node3D = packed.instantiate()
	parent.add_child(model)
	model.position = Vector3(0, foot_offset, 0)
	_fit_height(model, _height(kind) * body_mult)
	Stage3D.matte_materials(model)   # GLBs export metallic 0.4, which dulls the fur
	_play_loop(model)
	return model


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
	# Desync herds so they don't march in lockstep.
	ap.seek(randf() * maxf(0.1, anim.length if anim != null else 1.0), true)


# Scale a model so it stands `h` units tall regardless of its source's native size.
static func _fit_height(node: Node3D, h: float) -> void:
	var box := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		# Accumulate every transform from the mesh up to `node`, not just mi.transform —
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
