class_name ClimateModel

const EMISSION_BY_TYPE: Dictionary = {
	"house": 0.30,
	"farm": 0.15,
	"lumber_camp": 0.10,
	"mine": 0.60,
	"market": 0.25,
	"barracks": 0.20,
	"archery": 0.20,
	"stable": 0.25,
	"siege_workshop": 0.80,
	"blacksmith": 0.50,
	"town_center": 0.40,
	"wall": 0.05,
	"tower": 0.10,
	"castle": 0.70,
}

const PREINDUSTRIAL_CO2: float = 280.0
const WARMING_SENSITIVITY: float = 3.0
const CRISIS_WARMING: float = 3.5
const MAX_PRODUCTION_PENALTY: float = 0.50
const PENALTY_EXPONENT: float = 1.8
const PENALTY_HALF_WARMING: float = 2.5


static func emissions(buildings: Dictionary, delta: float) -> float:
	if delta <= 0.0 or buildings.is_empty():
		return 0.0
	var total: float = 0.0
	for building_type: String in buildings:
		if EMISSION_BY_TYPE.has(building_type):
			total += _to_float(buildings[building_type]) * EMISSION_BY_TYPE[building_type]
	return total * delta


static func accumulate_co2(current: float, added: float, green_offset: float, delta: float) -> float:
	if delta <= 0.0:
		return maxf(current, 0.0)
	return maxf(current + added - green_offset * delta, 0.0)


static func warming(co2: float) -> float:
	var safe_co2: float = maxf(co2, 0.0)
	if safe_co2 < 1.0:
		return 0.0
	var ratio: float = safe_co2 / PREINDUSTRIAL_CO2
	if ratio <= 1.0:
		return 0.0
	return WARMING_SENSITIVITY * log(ratio) / log(2.0)


static func production_penalty(warming_deg: float) -> float:
	if warming_deg <= 0.0:
		return 0.0
	var w: float = pow(warming_deg, PENALTY_EXPONENT)
	var h: float = pow(PENALTY_HALF_WARMING, PENALTY_EXPONENT)
	return clampf(MAX_PRODUCTION_PENALTY * (w / (h + w)), 0.0, MAX_PRODUCTION_PENALTY)


static func is_crisis(warming_deg: float) -> bool:
	return warming_deg >= CRISIS_WARMING


static func _to_float(value: Variant) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	return 0.0
