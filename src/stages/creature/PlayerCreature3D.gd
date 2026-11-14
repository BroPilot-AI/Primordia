class_name PlayerCreature3D extends CharacterBody3D

## See CreatureBalance.player_speed for the derivation (arena diameter / target crossing time).
@export var speed: float = CreatureBalance.player_speed

## Arena radius bound (CreatureStage3D.ARENA, minus a hair). The player is clamped inside this
## CIRCLE so a predator knockback can't fling you off the map into the empty void at the edge.
const ARENA_BOUND: float = 128.0
## Capsule half-height — the body rests with its feet on the ground (y=0 surface) at this height,
## instead of spawning sunk waist-deep into the floor.
const GROUND_Y: float = 1.1

var is_hidden: bool = false
var climate_slowdown: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _anim: AnimationPlayer = null
var _cur_anim: String = ""
var _walk_anim: String = ""
var _idle_anim: String = ""
var _model: Node3D = null
var _appear_sig: String = ""


func _ready() -> void:
	add_to_group("player")
	var cshape := CollisionShape3D.new()
	cshape.shape = CapsuleShape3D.new()
	cshape.shape.radius = 0.7
	cshape.shape.height = 2.2
	add_child(cshape)
	_build_body()


func _build_body() -> void:
	# Per-species avatar (Human → Kenney character; alien lineages → Quaternius models), in its
	# natural model colors. Sized to fill the ~2.2u collision capsule, feet at the capsule bottom.
	var species := EvolutionState.genome.resolved_species() if EvolutionState.genome != null else "human"
	var model := SpeciesVisuals.attach(self, species, 2.6, -1.1)
	if model != null:
		_model = model
		_express_genome(model, EvolutionState.genome)  # diet→color, size→bulk, defense→armored sheen (NO glued parts)
		_appear_sig = _appearance_signature()
		_setup_anim(model)
		return
	# Fallback: genome-tinted primitive (model missing).
	var col := EvolutionState.genome.color if EvolutionState.genome != null else Color(0.6, 0.75, 0.5)
	var body := MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	body.mesh.radius = 0.7
	body.mesh.height = 2.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	body.material_override = mat
	add_child(body)
	var head := MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.5
	head.mesh.height = 1.0
	head.position = Vector3(0, 1.4, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = col.lightened(0.15)
	hmat.roughness = 0.75
	head.material_override = hmat
	add_child(head)


# Genome expression lives in SpeciesVisuals.express() — the ONE source shared by every stage,
# the morph cutscene, and the HUD portrait. No glued parts.
func _express_genome(model: Node3D, g) -> void:
	SpeciesVisuals.express(model, g)


func _appearance_signature() -> String:
	var g = EvolutionState.genome
	if g == null:
		return ""
	return "%.3f|%.3f|%.3f|%.3f|%.3f|%d|%s" % [
		float(g.size),
		float(g.defense),
		float(g.carnivory),
		float(g.senses),
		float(g.locomotion),
		EvolutionState.current_stage,
		str(EvolutionState.traits),
	]


func _refresh_appearance_if_needed() -> void:
	if _model == null or not is_instance_valid(_model) or EvolutionState.genome == null:
		return
	var sig := _appearance_signature()
	if sig == "" or sig == _appear_sig:
		return
	SpeciesVisuals.express(_model, EvolutionState.genome)
	_appear_sig = sig


# Drive the rig's baked clips (Quaternius "Rig|Walk" / "Rig|Idle"), looped.
func _setup_anim(model: Node) -> void:
	for c in model.find_children("*", "AnimationPlayer", true, false):
		_anim = c as AnimationPlayer
		break
	if _anim == null:
		return
	# Resolve walk/idle by KEYWORD so any rig works — Quaternius "Rig|Walk", Mixamo "Walking", etc.
	_walk_anim = _find_clip(["walk", "run", "jog"])
	_idle_anim = _find_clip(["idle", "breath"])
	if _idle_anim == "":
		_idle_anim = _walk_anim
	_play(_idle_anim)


func _find_clip(keys: Array) -> String:
	if _anim == null:
		return ""
	var list := _anim.get_animation_list()
	for n in list:
		var l := String(n).to_lower()
		for k in keys:
			if l.find(k) >= 0:
				return String(n)
	return String(list[0]) if list.size() > 0 else ""


func _play(anim_name: String) -> void:
	if _anim == null or _cur_anim == anim_name or not _anim.has_animation(anim_name):
		return
	var a := _anim.get_animation(anim_name)
	if a != null:
		a.loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name)
	_cur_anim = anim_name


func _physics_process(delta: float) -> void:
	_refresh_appearance_if_needed()
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var effective_speed := speed * (1.0 - climate_slowdown)
	# Screen-relative: W stays up-screen after the player orbits the camera (middle-drag).
	var cam := get_viewport().get_camera_3d()
	var yaw := cam.global_rotation.y if cam != null else 0.0
	var motion := Vector3(dir.x, 0, dir.y).rotated(Vector3.UP, yaw) * effective_speed
	_knockback = _knockback.move_toward(Vector3.ZERO, 900.0 * delta)
	velocity = motion + _knockback
	move_and_slide()

	# Stay on the ground plane and inside the arena — knockback/drift can't sink you or fling
	# you into the void at the edge.
	global_position.y = GROUND_Y
	# Radial clamp to the circular hex arena (keeps the player on the tiles, not just a square).
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > ARENA_BOUND:
		flat = flat.normalized() * ARENA_BOUND
		global_position.x = flat.x
		global_position.z = flat.y

	# Face the travel direction. The avatar models' visual FRONT is +Z, so we aim the node's +Z
	# (i.e. -Z away) along movement — otherwise the character moonwalks ("moves backwards").
	# Guarded so a near-zero move vector never trips look_at's same-position error.
	if dir.length() > 0.1:
		look_at(global_position - Vector3(dir.x, 0, dir.y), Vector3.UP)
		_play(_walk_anim)
	else:
		_play(_idle_anim)


func grow(_amount: float) -> void:
	var s := minf(scale.x * 1.04, 2.0)
	scale = Vector3.ONE * s


func knockback(dir: Vector2, force: float) -> void:
	_knockback = Vector3(dir.x, 0, dir.y).normalized() * force
