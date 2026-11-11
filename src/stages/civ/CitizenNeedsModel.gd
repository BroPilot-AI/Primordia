class_name CitizenNeedsModel

const NEED_WEIGHTS: Dictionary[String, float] = {
	"food": 0.45,
	"housing": 0.30,
	"safety": 0.25,
}

const _DEFAULT_NEED_RATIO: float = 1.0
const _MAX_PRODUCTION_PENALTY: float = 0.65
const _MIN_PRODUCTION_MULT: float = 0.25

# Luxury (bread) is asymmetric: a full supply actively pulls unrest DOWN on top of
# basic satiation, but its absence is never penalised (default ratio 0.0). Food
# keeps citizens from being unhappy; bread makes them happy.
const _LUXURY_RELIEF: float = 0.07


static func unrest_delta(needs: Dictionary, delta: float) -> float:
	if delta <= 0.0:
		return 0.0

	var food_ratio: float = _ratio(needs, "food_ratio", _DEFAULT_NEED_RATIO)
	var housing_ratio: float = _ratio(needs, "housing_ratio", _DEFAULT_NEED_RATIO)
	var safety_ratio: float = _ratio(needs, "safety_ratio", _DEFAULT_NEED_RATIO)
	var luxury_ratio: float = _ratio(needs, "luxury_ratio", 0.0)

	var growth_rate: float = CivBalance.value("unrest_growth_per_unmet_need", 0.05)
	var housing_growth_rate: float = CivBalance.value("unrest_growth_per_overcrowd", 0.10)
	var decay_rate: float = CivBalance.value("unrest_decay_per_tax_relief", 0.08)
	var content_threshold: float = CivBalance.value("unrest_threshold_content", 0.20)

	var unmet_rate: float = 0.0
	unmet_rate += (1.0 - food_ratio) * NEED_WEIGHTS["food"] * growth_rate
	unmet_rate += (1.0 - housing_ratio) * NEED_WEIGHTS["housing"] * housing_growth_rate
	unmet_rate += (1.0 - safety_ratio) * NEED_WEIGHTS["safety"] * growth_rate

	var met_score: float = 0.0
	met_score += food_ratio * NEED_WEIGHTS["food"]
	met_score += housing_ratio * NEED_WEIGHTS["housing"]
	met_score += safety_ratio * NEED_WEIGHTS["safety"]

	var recovery_start: float = clampf(1.0 - content_threshold, 0.0, 1.0)
	var recovery_pressure: float = 0.0
	if recovery_start < 1.0 and met_score > recovery_start:
		recovery_pressure = inverse_lerp(recovery_start, 1.0, met_score)

	return (unmet_rate - decay_rate * recovery_pressure - _LUXURY_RELIEF * luxury_ratio) * delta


static func apply_unrest(current: float, d: float) -> float:
	return clampf(current + d, 0.0, 1.0)


static func production_mult(unrest: float) -> float:
	var bounded_unrest: float = clampf(unrest, 0.0, 1.0)
	var content_threshold: float = clampf(CivBalance.value("unrest_threshold_content", 0.20), 0.0, 1.0)
	var revolt_threshold: float = clampf(CivBalance.value("unrest_threshold_revolt", 1.0), 0.0, 1.0)
	if revolt_threshold <= content_threshold:
		content_threshold = 0.20
		revolt_threshold = 1.0
	var pressure: float = inverse_lerp(content_threshold, revolt_threshold, bounded_unrest)
	var penalty: float = clampf(pressure, 0.0, 1.0) * _MAX_PRODUCTION_PENALTY
	return clampf(1.0 - penalty, _MIN_PRODUCTION_MULT, 1.0)


static func status(unrest: float) -> String:
	var bounded_unrest: float = clampf(unrest, 0.0, 1.0)
	var restless_threshold: float = CivBalance.value("unrest_threshold_restless", 0.45)
	var revolting_threshold: float = CivBalance.value("unrest_threshold_revolting", 0.75)
	var revolt_threshold: float = CivBalance.value("unrest_threshold_revolt", 1.0)

	if bounded_unrest >= revolt_threshold:
		return "revolt"
	if bounded_unrest >= revolting_threshold:
		return "revolting"
	if bounded_unrest >= restless_threshold:
		return "restless"
	return "content"


static func _ratio(needs: Dictionary, key: String, default_value: float) -> float:
	if not needs.has(key):
		return clampf(default_value, 0.0, 1.0)
	return clampf(_to_float(needs[key], default_value), 0.0, 1.0)


static func _to_float(value: Variant, default_value: float) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is bool:
		return 1.0 if value else 0.0
	return default_value
