class_name HidingSpot3D extends Area3D
## A readable "hide here" POI — a dense thicket of the same megakit bushes used for ambient
## flora (visually coherent with the biome) sitting on a soft green ground marker. Deliberately
## GREEN and grounded to read as distinct from the purple emissive mutation pools
## (CreatureStage3D._spawn_mutation_zone, Color(0.62,0.22,0.88)), so players can tell where to hide.

const HIDE_RADIUS: float = 2.6   # generous enough that a shelter is reachable in time
# The visual marker is bigger than the actual trigger radius on purpose — at the strategic-camera
# top-down distance players view the arena from, a marker sized to the trigger alone (2.6u) all
# but disappeared into the grass. A bigger, brighter disc reads as a landmark from across the map.
const MARKER_RADIUS: float = HIDE_RADIUS + 1.4
const MARKER_ALPHA_IDLE: float = 0.55
const MARKER_ALPHA_HIDDEN: float = 0.85
const MARKER_EMISSION_IDLE: float = 2.2
const MARKER_EMISSION_HIDDEN: float = 4.0
# A saturated teal-green, picked to read clearly against both the olive grass AND the purple
# mutation-zone pools (Color(0.62,0.22,0.88)) — no color confusion between the two POI types.
const MARKER_COLOR := Color(0.15, 0.95, 0.55)
# A single, consistent bush model (not the random ambient mix) spawned bigger and denser than
# background flora, so a thicket reads as a deliberate landmark rather than more scattered scenery.
const THICKET_MODEL := "res://assets/models/megakit/bush.glb"
const THICKET_HEIGHT := 2.4

var _marker_mat: StandardMaterial3D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("hiding_spots")
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_rng.seed = hash(position)
	_build_ground_marker()
	_build_thicket()
	var cshape := CollisionShape3D.new()
	cshape.shape = SphereShape3D.new()
	cshape.shape.radius = HIDE_RADIUS
	add_child(cshape)


# A flat, glowing green ground disc — same proven "POI marker" pattern as the mutation-zone
# cylinder, but green (not purple) and dim by default, brightening when the player is inside for
# clear "you are hidden" feedback (see _on_enter/_on_exit).
func _build_ground_marker() -> void:
	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = MARKER_RADIUS
	disc.bottom_radius = MARKER_RADIUS
	disc.height = 0.06
	marker.mesh = disc
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.albedo_color = Color(MARKER_COLOR.r, MARKER_COLOR.g, MARKER_COLOR.b, MARKER_ALPHA_IDLE)
	_marker_mat.emission_enabled = true
	_marker_mat.emission = MARKER_COLOR
	_marker_mat.emission_energy_multiplier = MARKER_EMISSION_IDLE
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = _marker_mat
	marker.position.y = 0.05   # sits just above the ground plane — grounded, not floating
	add_child(marker)


# A dense, UNIFORM bush cluster (deliberately not the random ambient mix — see THICKET_MODEL)
# reads clearly as a landmark. Grounded, individually
# rotated like every other WorldProps prop for visual consistency with the rest of the dressing.
func _build_thicket() -> void:
	_spawn_thicket_bush(Vector3.ZERO, THICKET_HEIGHT)
	var ring_count := 5
	for i in ring_count:
		var a := TAU * float(i) / float(ring_count) + _rng.randf_range(-0.2, 0.2)
		var r := _rng.randf_range(0.9, 1.6)
		var offset := Vector3(cos(a) * r, 0, sin(a) * r)
		_spawn_thicket_bush(offset, THICKET_HEIGHT * _rng.randf_range(0.8, 1.0))


func _spawn_thicket_bush(offset: Vector3, h: float) -> void:
	var node := WorldProps.spawn_at(self, THICKET_MODEL, offset, h)
	if node != null:
		node.rotation.y = _rng.randf() * TAU


func _on_enter(body: Node) -> void:
	if body.is_in_group("player") and "is_hidden" in body:
		body.is_hidden = true
		if _marker_mat != null:
			_marker_mat.emission_energy_multiplier = MARKER_EMISSION_HIDDEN
			_marker_mat.albedo_color.a = MARKER_ALPHA_HIDDEN


func _on_exit(body: Node) -> void:
	if body.is_in_group("player") and "is_hidden" in body:
		# Overlapping thickets: leaving THIS spot must not un-hide the player while they're
		# still inside another one (shelters can be built next to wild thickets, and random
		# spawns occasionally overlap) — only clear hidden when no other spot overlaps them.
		var still_inside := false
		for spot in get_tree().get_nodes_in_group("hiding_spots"):
			if spot != self and spot is Area3D and (spot as Area3D).overlaps_body(body):
				still_inside = true
				break
		if not still_inside:
			body.is_hidden = false
		if _marker_mat != null:
			_marker_mat.emission_energy_multiplier = MARKER_EMISSION_IDLE
			_marker_mat.albedo_color.a = MARKER_ALPHA_IDLE
