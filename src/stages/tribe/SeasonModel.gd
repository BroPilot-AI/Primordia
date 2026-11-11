class_name SeasonModel

# DESIGN PILLAR: hazards SLOW progress, they NEVER kill.
# Winter without firewood PAUSES/slows population growth, never reduces population.
# All multipliers are clamped to [0.0, 1.0]; zero output never causes death.

const SEASONS: Array[String] = ["summer", "autumn", "winter", "spring"]
const YEAR_LENGTH: float = 240.0
const WINTER_WARMTH_MULT: float = 3.0
const WINTER_FUEL_PER_POP: float = 5.0

static func season_at(time: float, year_length: float = YEAR_LENGTH) -> String:
	var season_len: float = year_length * 0.25
	var idx: int = int(time / season_len) % 4
	return SEASONS[idx]

static func warmth_decay(season: String, base_rate: float) -> float:
	if season == "winter":
		return base_rate * WINTER_WARMTH_MULT
	return base_rate

static func fuel_needed(season: String, pop: int) -> float:
	if season == "winter":
		return WINTER_FUEL_PER_POP * float(pop)
	return 0.0

static func growth_multiplier(fuel_on_hand: float, fuel_needed: float) -> float:
	if fuel_needed <= 0.0:
		return 1.0
	return clampf(fuel_on_hand / fuel_needed, 0.0, 1.0)
