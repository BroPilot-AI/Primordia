class_name Campfire3D extends Node3D
## A lit camp — warms the player AND, since fire keeps predators back, acts as a night SAFE ZONE.
## The warm glowing ground ring shows the deterrent bubble (CreatureBalance.fire_repel_radius) so
## the player can read the safety it grants; Predator3D queries the "campfires" group and flees it.

var _warm_radius: float = 6.0
var _player: Node3D = null
var _stage: Node = null
var _flame_light: OmniLight3D = null
var _t: float = 0.0


func _ready() -> void:
	add_to_group("structures")
	add_to_group("campfires")   # Predator3D flees any node in this group (fire deterrent)
	_player = get_tree().get_first_node_in_group("player")
	_stage = get_tree().get_first_node_in_group("creature_stage")
	# CC0 stone bonfire (Quaternius, same model as the Tribe camp) + a warm flickering glow.
	if WorldProps.spawn_at(self, WorldProps.CAMPFIRE, Vector3.ZERO, 1.4) == null:
		var fallback := MeshInstance3D.new()      # primitive fallback if the model's missing
		fallback.mesh = SphereMesh.new()
		var fmat := StandardMaterial3D.new()
		fmat.emission_enabled = true
		fmat.emission = Color(1.0, 0.5, 0.0)
		fmat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		fallback.material_override = fmat
		fallback.position.y = 0.5
		add_child(fallback)
	_flame_light = OmniLight3D.new()
	_flame_light.light_color = Color(1.0, 0.6, 0.25)
	_flame_light.light_energy = 3.5
	_flame_light.omni_range = 14.0
	_flame_light.position.y = 1.2
	add_child(_flame_light)
	_build_safe_ring()


# A warm, softly-glowing ground ring at the predator-repel radius — the visible "safe bubble" that
# reads as fire-lit ground (orange), distinct from the teal hiding thickets and purple mutation
# pools. Sits flat on the ground, grounded, semi-transparent so flora shows through.
func _build_safe_ring() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "SafeZoneRing"
	var torus := TorusMesh.new()
	torus.outer_radius = CreatureBalance.fire_repel_radius
	torus.inner_radius = CreatureBalance.fire_repel_radius - 0.35
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.18, 0.72)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.52, 0.16)
	mat.emission_energy_multiplier = 1.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position.y = 0.08
	ring.rotation_degrees.x = 90.0
	add_child(ring)


func _process(_delta: float) -> void:
	# Flicker the flame light so the camp feels alive (soup's ambient-motion quality bar).
	_t += _delta
	if _flame_light != null:
		_flame_light.light_energy = 3.2 + sin(_t * 11.0) * 0.4 + sin(_t * 4.3) * 0.25
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) < _warm_radius:
		if _stage != null and _stage.has_method("warm"):
			_stage.warm(0.25 * _delta)
