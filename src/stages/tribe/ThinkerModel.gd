# DESIGN PILLAR: research is a "position-and-protect" loop.
# The Thinker leader must be physically AT a research node to advance it; standing
# at the node exposes the leader to nearby threats, so exploration-for-research
# always carries tactical risk (Kainga-style "Thinker" leader).

class_name ThinkerModel


# Per-second research contribution for a leader at `leader_pos` relative to a
# research node at `node_pos` with effective radius `radius`.
# - XZ-plane distance only (Y is ignored so the leader can stand on terrain).
# - Returns 0.0 when the leader is outside the radius.
# - Returns `base_rate` when the leader is exactly at the node.
# - Linear falloff from `base_rate` (center) to 0.0 (edge) inside the radius.
static func research_rate(leader_pos: Vector3, node_pos: Vector3, radius: float, base_rate: float) -> float:
	var r: float = maxf(0.0, radius)
	if r <= 0.0:
		return 0.0
	var dx: float = leader_pos.x - node_pos.x
	var dz: float = leader_pos.z - node_pos.z
	var dist_xz: float = sqrt(dx * dx + dz * dz)
	if dist_xz >= r:
		return 0.0
	return base_rate * (1.0 - dist_xz / r)


# Advances research progress by `rate * delta`, clamped at 1.0 (complete).
# Only the upper bound is clamped; negative inputs flow through unchanged.
static func progress(current: float, rate: float, delta: float) -> float:
	return minf(1.0, current + rate * delta)


static func is_complete(progress: float) -> bool:
	return progress >= 1.0


# True if any threat in `threat_positions` is within `danger_radius` of the leader
# on the XZ plane. Empty array or no in-radius threats returns false. Non-Vector3
# entries are skipped defensively.
static func is_vulnerable(leader_pos: Vector3, threat_positions: Array, danger_radius: float) -> bool:
	if threat_positions.is_empty():
		return false
	for t in threat_positions:
		if not (t is Vector3):
			continue
		var threat: Vector3 = t
		var dx: float = threat.x - leader_pos.x
		var dz: float = threat.z - leader_pos.z
		var dist_xz: float = sqrt(dx * dx + dz * dz)
		if dist_xz <= danger_radius:
			return true
	return false
