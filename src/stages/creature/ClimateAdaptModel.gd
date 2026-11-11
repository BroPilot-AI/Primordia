class_name ClimateAdaptModel

# Constants for tuning
const TEMPERATE_POINT: float = 0.0
const WINTER_TEMP: float = -1.0
const SUMMER_TEMP: float = 1.0
const SPRING_TEMP: float = -0.5
const AUTUMN_TEMP: float = 0.0

const WARMTH_DRAIN_MAX: float = 1.0  # Extra multiplier at worst fit
const MOVE_PENALTY_MAX: float = 0.4  # Maximum slowdown penalty

# Returns temperature for a given season (-1.0 to 1.0, 0 is temperate)
static func temp_at(season: String) -> float:
	match season:
		"winter":
			return WINTER_TEMP
		"spring":
			return SPRING_TEMP
		"summer":
			return SUMMER_TEMP
		"autumn":
			return AUTUMN_TEMP
		_:
			return TEMPERATE_POINT

# Returns how well insulation suits temperature (0.0 to 1.0)
# Cold needs high insulation, heat needs low insulation
static func adaptation_fit(insulation: float, temp: float) -> float:
	var ideal_insulation: float = 0.5 - 0.5 * temp
	var fit: float = 1.0 - abs(insulation - ideal_insulation)
	return clamp(fit, 0.0, 1.0)

# Returns warmth drain multiplier (>=1.0; worse fit drains faster)
static func warmth_drain_mult(fit: float) -> float:
	return 1.0 + (1.0 - fit) * WARMTH_DRAIN_MAX

# Returns movement penalty (0.0 to ~0.4 slowdown when ill-adapted)
static func move_penalty(fit: float) -> float:
	return (1.0 - fit) * MOVE_PENALTY_MAX