class_name CompoundField
## Pure-logic dissolved-compound field for the primordial soup stage.
## Thrive-style clouds: compounds (glucose, oxygen, ammonia, phosphates) drift
## in/out of cells via diffusion, decay exponentially, and are emitted by
## nutrient vents. Static helpers only — no nodes, no signals, no scene refs.
## Defensive: NaN/INF or non-finite inputs return 0.0.

const CAP: float = 1000.0
const DEFAULT_DECAY: float = 0.1

const COMPOUNDS: Dictionary = {
	"glucose": 0.0,
	"oxygen": 0.0,
	"ammonia": 0.0,
	"phosphates": 0.0,
}


static func _is_finite(v: float) -> bool:
	return not (is_nan(v) or is_inf(v))


static func emit(concentration: float, amount: float) -> float:
	if not _is_finite(concentration) or not _is_finite(amount):
		return 0.0
	return clampf(concentration + amount, 0.0, CAP)


static func decay(concentration: float, rate: float, delta: float) -> float:
	if not _is_finite(concentration) or not _is_finite(rate) or not _is_finite(delta):
		return 0.0
	if concentration <= 0.0:
		return 0.0
	return concentration * exp(-rate * delta)


static func diffuse(here: float, neighbor_avg: float, rate: float, delta: float) -> float:
	if not _is_finite(here) or not _is_finite(neighbor_avg) or not _is_finite(rate) or not _is_finite(delta):
		return 0.0
	var t: float = clampf(rate * delta, 0.0, 1.0)
	return clampf(here + (neighbor_avg - here) * t, 0.0, CAP)


static func vent_output(vent_strength: float, delta: float) -> float:
	if not _is_finite(vent_strength) or not _is_finite(delta):
		return 0.0
	return maxf(vent_strength * delta, 0.0)


static func sample(concentration: float) -> float:
	if not _is_finite(concentration):
		return 0.0
	return clampf(concentration, 0.0, CAP)
