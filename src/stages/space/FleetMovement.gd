class_name FleetMovement
## Pure-logic helpers for system-to-system fleet movement and capture rates.
## No nodes, no `extends` — fully typed static API. Used by SpaceStage3D and unit-tested
## directly. All functions return defensive defaults on bad input.

const DEFAULT_FLAGSHIP_SPEED: float = 46.0
const DEFAULT_ARRIVAL_RADIUS: float = 9.0
const DEFAULT_CAPTURE_RATE: float = 0.28
const DEFAULT_CAPTURE_DECAY: float = 0.8
const DEFAULT_CAPTURE_THRESHOLD: float = 1.0
## Empire AI expansion base interval (seconds); mirror SpaceStage3D.
const EMPIRE_EXPAND_BASE: float = 16.0
## Player fleet strength divisor for capture: power / divisor.
const FLEET_POWER_DIVISOR: float = 5.0
## Strength floor for a system to be considered "defended" against assault.
const DEFENSE_FLOOR: float = 1.0


## Travel time in seconds to cross `from → to` at `speed` (units/sec), boosted by
## a movement multiplier (e.g. JumpGate stacked speedup). Returns INF on bad input.
static func travel_time(from: Vector3, to: Vector3, speed: float, movement_mult: float = 1.0) -> float:
	if not is_finite(speed) or speed <= 0.0:
		return INF
	if not is_finite(movement_mult) or movement_mult <= 0.0:
		movement_mult = 1.0
	var d: float = from.distance_to(to)
	if not is_finite(d) or d <= 0.0:
		return 0.0
	return d / (speed * movement_mult)


## Has the fleet arrived at the target? Tolerance is the arrival radius (units).
static func has_arrived(fleet_pos: Vector3, target_pos: Vector3, arrival_radius: float = DEFAULT_ARRIVAL_RADIUS) -> bool:
	if not is_finite(arrival_radius) or arrival_radius <= 0.0:
		arrival_radius = DEFAULT_ARRIVAL_RADIUS
	if not is_finite(fleet_pos.x) or not is_finite(target_pos.x):
		return false
	return fleet_pos.distance_to(target_pos) <= arrival_radius


## Effective speed after the player's JumpGate boost. Mirrors the existing
## `_movement_mult` formula in SpaceStage3D (1.0 + 0.15 per JumpGate, capped at 1.6).
static func movement_mult_from_jumpgates(jumpgate_count: int) -> float:
	if not is_finite(float(jumpgate_count)) or jumpgate_count < 0:
		jumpgate_count = 0
	return minf(1.6, 1.0 + 0.15 * float(jumpgate_count))


## Compute the player's fleet strength at a target — used both for capture rate and
## for assault viability. Combines flagship power (always 1.0) + nearby fleet dps/hp.
static func player_fleet_power(flagship_present: bool, nearby_ship_dps: float, habitat_rings: int) -> float:
	if not is_finite(nearby_ship_dps):
		nearby_ship_dps = 0.0
	if not is_finite(float(habitat_rings)) or habitat_rings < 0:
		habitat_rings = 0
	var p: float = 0.0
	if flagship_present:
		p += 1.0
	p += nearby_ship_dps * 0.1
	p += habitat_rings * 1.5
	return p


## Defender strength for a system: anchored defenses + nearby garrison. Floor at
## DEFENSE_FLOOR so a fully undefended system can be captured by anyone.
static func defender_strength(defense_dps: float, garrison_ship_dps: float) -> float:
	if not is_finite(defense_dps):
		defense_dps = 0.0
	if not is_finite(garrison_ship_dps):
		garrison_ship_dps = 0.0
	return maxf(DEFENSE_FLOOR, defense_dps * 0.05 + garrison_ship_dps * 0.1)


## Whether the player's fleet is strong enough to dislodge the defender. Mirrors the
## gameplay pillar: a single lone flagship can't take a defended world.
static func can_capture_system(fleet_power: float, defense: float) -> bool:
	if not is_finite(fleet_power):
		fleet_power = 0.0
	if not is_finite(defense):
		defense = 0.0
	return fleet_power >= defense


## Delta applied to a system's `capture` value this tick. Positive while the player
## is actively capturing, negative (decay) once they leave. fleet_power amplifies
## the rate; if `present` is false and the player was the contender, we decay.
static func capture_delta(
	present: bool,
	fleet_power: float,
	delta: float,
	rate: float = DEFAULT_CAPTURE_RATE,
	decay: float = DEFAULT_CAPTURE_DECAY,
) -> float:
	if not is_finite(delta) or delta < 0.0:
		delta = 0.0
	if not is_finite(rate) or rate <= 0.0:
		rate = DEFAULT_CAPTURE_RATE
	if not is_finite(decay) or decay <= 0.0:
		decay = DEFAULT_CAPTURE_DECAY
	if not is_finite(fleet_power):
		fleet_power = 0.0
	if present:
		var mult: float = 1.0 + fleet_power * 0.2
		return rate * mult * delta
	return -decay * delta


## Has capture reached the threshold (defaults to 1.0)? Defensive on NaN.
static func capture_complete(capture_value: float, threshold: float = DEFAULT_CAPTURE_THRESHOLD) -> bool:
	if not is_finite(capture_value):
		return false
	if not is_finite(threshold):
		threshold = DEFAULT_CAPTURE_THRESHOLD
	return capture_value >= threshold


## Whether the player is the active contender on a system. A "contender" is the
## faction whose capture progress is currently rising on a system. Defensive.
static func is_player_contender(contender: int, player_faction: int = 0) -> bool:
	return contender == player_faction
