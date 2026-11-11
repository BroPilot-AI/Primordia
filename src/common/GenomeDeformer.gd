class_name GenomeDeformer extends SkeletonModifier3D
## Builds an evolved creature FROM a rigged + animated base by deforming its Skeleton3D bones per
## genome — the body reshapes (size/defense/carnivory) while Walk/Idle keep playing. Runs in the
## skeleton modification phase so genome scale composes ON TOP of the animation. Works on BOTH the
## Quaternius Rigify rig (DEF-* bones) and Mixamo rigs (mixamorig_* bones) via candidate-name lists.

# Per-lineage SILHOUETTE — distinct species shapes from the SAME rig (head/height/torso/limbs).
const _SPECIES_PROFILE := {
	"human":       {"head": 1.0, "height": 1.0, "torso": 1.0, "limb": 1.0},
	"short_alien": {"head": 1.42, "height": 0.84, "torso": 1.14, "limb": 0.92},  # squat, larger head
	"tall_grey":   {"head": 1.24, "height": 1.22, "torso": 0.88, "limb": 1.1},   # tall, slender
	"reptilian":   {"head": 1.14, "height": 1.03, "torso": 1.1, "limb": 1.02},   # upright, sturdy
}

# Each entry: {"scale": Vector3, "bones": [candidate names]} — applied to whichever bone exists.
var _parts: Array = []


func setup(genome, species: String = "human") -> void:
	_parts.clear()
	var prof: Dictionary = _SPECIES_PROFILE.get(species, _SPECIES_PROFILE["human"])
	var size: float = 0.5
	var defense: float = 0.5
	var carnivory: float = 0.5
	if genome != null:
		size = clampf(genome.size, 0.0, 1.0)
		defense = clampf(genome.defense, 0.0, 1.0)
		carnivory = clampf(genome.carnivory, 0.0, 1.0)
	var height: float = float(prof["height"])
	var torso: float = float(prof["torso"])
	var limb: float = float(prof["limb"])
	var head: float = float(prof["head"])

	_add(Vector3.ONE * (1.0 + size * 0.26), ["DEF-hips", "mixamorig_Hips"])                   # overall bulk
	_add(Vector3(1.0, height, 1.0), ["DEF-spine.001", "mixamorig_Spine"])                     # tall / short
	_add(Vector3(1.0, height, 1.0), ["DEF-spine.002", "mixamorig_Spine1"])
	_add(Vector3(torso + defense * 0.28, 1.0, torso + defense * 0.2), ["DEF-spine.003", "mixamorig_Spine2"])
	var sh := Vector3.ONE * (1.0 + defense * 0.3)
	_add(sh, ["DEF-shoulder.L", "mixamorig_LeftShoulder"])
	_add(sh, ["DEF-shoulder.R", "mixamorig_RightShoulder"])
	_add(Vector3.ONE * (head * (1.0 + carnivory * 0.2)), ["DEF-head", "mixamorig_Head"])      # head size
	var lb := Vector3.ONE * limb
	_add(lb, ["DEF-upper_arm.L", "mixamorig_LeftArm"])
	_add(lb, ["DEF-upper_arm.R", "mixamorig_RightArm"])
	_add(lb, ["DEF-thigh.L", "mixamorig_LeftUpLeg"])
	_add(lb, ["DEF-thigh.R", "mixamorig_RightUpLeg"])


func _add(scale: Vector3, bones: Array) -> void:
	_parts.append({"scale": scale, "bones": bones})


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for p in _parts:
		for bn in p["bones"]:
			var idx := sk.find_bone(String(bn))
			if idx >= 0:
				sk.set_bone_pose_scale(idx, p["scale"])
				break
