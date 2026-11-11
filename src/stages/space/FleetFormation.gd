class_name FleetFormation
## Pure-logic helpers for multi-ship fleet formation steering in 3D.
## No nodes, no `extends` — fully typed static API. Used by SpaceStage3D's
## `_idle_move` when 2+ player ships share a move order, so the fleet travels
## as a coherent wing (wedge/V) instead of stacking onto a single point.
## Mirrors the boids separation pattern from CivStage3D (ported to 3D) and
## adds a deterministic wedge slot generator with stable index → slot mapping.
## All functions return defensive defaults on bad input (zero/negative count,
## NaN, INF, non-Vector3 entries).

## Wedge/V spacing in world units between adjacent slots. ~5 reads as a
## comfortable spread for the Quaternius hulls at SPACE_SCALE=0.11.
const DEFAULT_SPACING: float = 5.0
## Boids separation radius (world units) — wingmates within this push apart.
## Sized just above the wedge spacing so wingtips never overlap.
const DEFAULT_SEPARATION_RADIUS: float = 4.5
## When two ships coincide exactly, the separation emits a small lateral nudge
## of this magnitude to break the tie deterministically (avoids NaN at zero
## distance without resorting to RNG — the angle advances with frame time).
const SEPARATION_TIE_BREAK: float = 2.0


## Build deterministic, stable local-space wedge slots for `count` ships.
## Convention: local +Z is the fleet's travel direction, -Z is "behind" the
## leader, ±X fans out to the sides. slot[0] is the leader (apex of the V);
## remaining ships pair into trailing rows (row 1 = left+right behind the
## leader, row 2 = next pair further back, …). Index → slot mapping is
## stable across calls (no reshuffle when the fleet size changes), so
## ship i always ends up at slot i.
static func slots(count: int, spacing: float = DEFAULT_SPACING) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not is_finite(float(count)) or count <= 0:
		return out
	if not is_finite(spacing) or spacing <= 0.0:
		spacing = DEFAULT_SPACING
	out.append(Vector3.ZERO)  # leader at the apex
	var remaining: int = count - 1
	var row: int = 0
	while remaining > 0:
		row += 1
		var lateral: float = float(row) * spacing
		var back: float = -float(row) * spacing
		out.append(Vector3(-lateral, 0.0, back))  # left wingmate
		remaining -= 1
		if remaining > 0:
			out.append(Vector3(lateral, 0.0, back))  # right wingmate
			remaining -= 1
	return out


## Boids separation push for a ship at `self_pos` away from `others`
## (an Array of Vector3 world positions; non-Vector3 entries are skipped).
## Each other within `radius` contributes a unit-away vector scaled by
## (radius - dist); the sum is the push. If two ships coincide exactly, a
## small lateral nudge (magnitude = SEPARATION_TIE_BREAK) breaks the tie
## without introducing NaN. Returns Vector3.ZERO on no neighbours.
static func separation(self_pos: Vector3, others: Array, radius: float = DEFAULT_SEPARATION_RADIUS) -> Vector3:
	if not is_finite(radius) or radius <= 0.0:
		radius = DEFAULT_SEPARATION_RADIUS
	if not is_finite(self_pos.x):
		return Vector3.ZERO
	var push: Vector3 = Vector3.ZERO
	for o in others:
		if not (o is Vector3):
			continue
		var other_pos: Vector3 = o
		var d: Vector3 = self_pos - other_pos
		var dist: float = d.length()
		if dist < 0.01:
			# Break exact overlap: small lateral push in a slowly-rotating
			# direction so a stack of ships drifts apart over a few frames
			# without needing RNG (deterministic given the same frame time).
			var phase: float = float(Time.get_ticks_usec() % 10000) * 0.000628
			push += Vector3(cos(phase), 0.0, sin(phase)) * SEPARATION_TIE_BREAK
		elif dist < radius:
			push += (d / dist) * (radius - dist)
	return push


## Blend seek-to-slot with the separation push, clamped to `max_speed`.
## `slot_world_target` is the world-space point the ship is steering toward
## (e.g. leader_pos + rotated local slot); `separation_vec` is the boids
## push from `separation(...)`. Returns the desired velocity vector in
## units/sec — the caller multiplies by delta and integrates position.
static func desired_velocity(
	ship_pos: Vector3,
	slot_world_target: Vector3,
	separation_vec: Vector3,
	max_speed: float,
) -> Vector3:
	if not is_finite(max_speed) or max_speed <= 0.0:
		return Vector3.ZERO
	if not is_finite(ship_pos.x) or not is_finite(slot_world_target.x):
		return Vector3.ZERO
	if not is_finite(separation_vec.x):
		return Vector3.ZERO
	var seek: Vector3 = slot_world_target - ship_pos
	var desired: Vector3 = seek + separation_vec
	var mag: float = desired.length()
	if mag > max_speed and mag > 0.0:
		desired = desired * (max_speed / mag)
	return desired
