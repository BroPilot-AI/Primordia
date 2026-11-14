class_name Predator3D extends Node3D
## Escapable night hunter — mirrors the SoupHunter design (primordial/SoupHunter.gd): a cruise
## speed clearly below the player's so fleeing always opens distance, a short capped lunge burst
## for the actual threat, and a breakoff/re-aggro cooldown so a chase that can't land a catch
## eventually gives up instead of staying glued to the player forever. All feel numbers live in
## CreatureBalance.gd — tune there, not here.

const ROAM_RADIUS := 8.0         # off-duty amble leash around the den (spawn point)
const ROAM_SPEED_MULT := 0.3     # lazy pace — the looping walk clip should match real motion

var _cooldown: float = 0.0       # catch cooldown (after landing a hit)
var _lunge_t: float = 0.0        # >0 while mid-lunge
var _lunge_cd: float = 0.0       # lunge recovery
var _chase_t: float = 0.0        # how long we've been actively pursuing without a catch
var _reaggro_cd: float = 0.0     # >0 while disengaged/standing down after a breakoff
var _stage: Node = null
var _player: Node3D = null

var _den: Vector3 = Vector3.ZERO
var _roam_target: Vector3 = Vector3.ZERO
var _roam_t: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("predators")
	_den = position
	_roam_target = position
	_rng.seed = hash(position)   # deterministic per spawn so seeded playtests stay reproducible
	_stage = get_tree().get_first_node_in_group("creature_stage")
	_player = get_tree().get_first_node_in_group("player")
	if AnimalModels.attach(self, "wolf", 2.0) == null:
		var body: MeshInstance3D = MeshInstance3D.new()
		body.mesh = SphereMesh.new()
		var bmat: StandardMaterial3D = StandardMaterial3D.new()
		bmat.albedo_color = Color(0.82, 0.18, 0.18)
		body.material_override = bmat
		body.position.y = 0.6
		add_child(body)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_lunge_cd = maxf(0.0, _lunge_cd - delta)
	_lunge_t = maxf(0.0, _lunge_t - delta)
	_reaggro_cd = maxf(0.0, _reaggro_cd - delta)
	if _stage == null or _player == null:
		return
	# Fire is a deterrent: if we're inside a lit camp's radius, FLEE outward (steer away from the
	# fire, not toward the player) — the fire keeps us back. Runs before the chase so a fire always
	# wins over the hunt.
	var fire := _nearest_fire_in_range()
	if fire != null:
		var away: Vector3 = global_position - fire.global_position
		away.y = 0.0
		if away.length() > 0.01:
			position += away.normalized() * CreatureBalance.predator_cruise_speed * delta
			look_at(global_position + away.normalized(), Vector3.UP, true)   # run away head-first
		_chase_t = 0.0
		return
	# Hard disengage: day, hiding, player-standing-in-a-fire, or cooling down after a breakoff.
	if not _stage.is_night or _player.is_hidden or _player_is_fire_safe() or _reaggro_cd > 0.0:
		_chase_t = 0.0
		_roam(delta)
		return
	var to_player: Vector3 = _player.global_position - global_position
	var d: float = to_player.length()
	if d > CreatureBalance.predator_aggro_radius:
		_chase_t = 0.0
		_roam(delta)
		return
	var day: int = _stage.current_day()
	# Cruise speed nudges up a little per day, hard-capped below player_speed (see CreatureBalance)
	# so day-scaling can never make the predator outrun a fleeing player at cruise pace.
	var cruise: float = minf(
		CreatureBalance.predator_cruise_speed + maxf(0, day - 1) * CreatureBalance.predator_day_speed_step,
		CreatureBalance.predator_cruise_speed_cap
	)
	# Trigger a lunge burst when close enough and recovered — the only way the predator can
	# actually close distance on a moving player.
	if _lunge_t <= 0.0 and _lunge_cd <= 0.0 and d < CreatureBalance.predator_lunge_range and d > CreatureBalance.predator_catch_radius:
		_lunge_t = CreatureBalance.predator_lunge_time
		_lunge_cd = CreatureBalance.predator_lunge_cooldown
	var effective_speed: float = CreatureBalance.predator_lunge_speed if _lunge_t > 0.0 else cruise
	# Move on the GROUND PLANE: the player capsule hovers at ~1.1y, and normalizing the full
	# 3D offset would lift the predator off the ground a little more every chase frame.
	var dir: Vector3 = Vector3(to_player.x, 0.0, to_player.z).normalized()
	position += dir * effective_speed * delta
	# Face the player ON THE GROUND PLANE, and ONLY when we're not right on top of them —
	# look_at() with origin == target spams "same position" errors every frame, which is what
	# froze the game when the predator reached the player.
	var look_target := Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target, Vector3.UP, true)   # wolf GLB front is +Z

	if d < CreatureBalance.predator_catch_radius and _cooldown <= 0.0:
		_cooldown = maxf(0.8, 1.5 - maxf(0, day - 1) * 0.08)
		_chase_t = 0.0
		_stage.on_player_caught(global_position)
		return

	# Breakoff: hunted too long without landing a catch -> give up and stand down, so a chase
	# can always be escaped.
	_chase_t += delta
	if _chase_t > CreatureBalance.predator_chase_giveup_time:
		_chase_t = 0.0
		_reaggro_cd = CreatureBalance.predator_reaggro_cooldown


# Off duty (day, or nothing to hunt): amble between points near the den, steering clear of fires.
func _roam(delta: float) -> void:
	_roam_t -= delta
	var to: Vector3 = _roam_target - position
	to.y = 0.0
	if _roam_t <= 0.0 or to.length() < 0.5:
		_roam_t = _rng.randf_range(3.0, 7.0)
		_roam_target = _pick_roam_target()
		return
	var speed: float = CreatureBalance.predator_cruise_speed * ROAM_SPEED_MULT
	var step: Vector3 = to.normalized() * speed * delta
	position += step if step.length() < to.length() else to
	var look_target := Vector3(_roam_target.x, global_position.y, _roam_target.z)
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target, Vector3.UP, true)   # wolf GLB front is +Z


func _pick_roam_target() -> Vector3:
	for _i in 4:
		var off := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
		var p := _den + (off * ROAM_RADIUS).limit_length(ROAM_RADIUS)
		if not _point_near_fire(p):
			return p
	return position


func _point_near_fire(p: Vector3) -> bool:
	for f in get_tree().get_nodes_in_group("campfires"):
		var fire_pos: Vector3 = (f as Node3D).global_position if f is Node3D else Vector3.INF
		if p.distance_to(fire_pos) < CreatureBalance.fire_repel_radius:
			return true
	return false


# The lit campfire whose safe radius we're currently standing inside (or null). Predators flee it.
func _nearest_fire_in_range() -> Node3D:
	for f in get_tree().get_nodes_in_group("campfires"):
		if f is Node3D and global_position.distance_to((f as Node3D).global_position) < CreatureBalance.fire_repel_radius:
			return f
	return null


# True when the player is standing inside any lit fire's safe radius — then we can't reach them.
func _player_is_fire_safe() -> bool:
	for f in get_tree().get_nodes_in_group("campfires"):
		if f is Node3D and _player.global_position.distance_to((f as Node3D).global_position) < CreatureBalance.fire_repel_radius:
			return true
	return false
