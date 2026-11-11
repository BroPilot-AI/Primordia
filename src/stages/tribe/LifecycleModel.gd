# DESIGN PILLAR: death is ONLY natural old age - a lifecycle feature.
# Hazards, winter, wolves, and starvation never kill villagers; they only SLOW growth per the non-lethal pillar.

class_name LifecycleModel

const CHILD_UNTIL: float = 14.0
const ELDER_FROM: float = 55.0
const MAX_AGE: float = 75.0
const BIRTH_RATE_PER_ADULT_PAIR_PER_YEAR: float = 1.0  # tuned by pace sim: 0.5→16min grind, 1.0 (+ TARGET_POP 18) ≈ 5min to a full village

static func make_villager(age: float, sex: String, rng: RandomNumberGenerator) -> Dictionary:
	var safe_age: float = maxf(0.0, age)
	var safe_sex: String = sex
	if safe_sex != "m" and safe_sex != "f":
		safe_sex = "m" if rng.randf() < 0.5 else "f"
	return {
		"age": safe_age,
		"sex": safe_sex,
		"stage": stage_for(safe_age),
	}

static func stage_for(age: float) -> String:
	if age < CHILD_UNTIL:
		return "child"
	if age >= ELDER_FROM:
		return "elder"
	return "adult"

static func is_fertile(v: Dictionary) -> bool:
	return str(v.get("stage", stage_for(float(v.get("age", 0.0))))) == "adult"

static func advance(villagers: Array, years_delta: float, rng: RandomNumberGenerator, rate_override: float = -1.0) -> Dictionary:
	var birth_rate: float = BIRTH_RATE_PER_ADULT_PAIR_PER_YEAR if rate_override < 0.0 else rate_override
	var elapsed_years: float = maxf(0.0, years_delta)
	var aged_villagers: Array[Dictionary] = []
	var fertile_males: int = 0
	var fertile_females: int = 0
	var died: int = 0

	for villager: Variant in villagers:
		if not villager is Dictionary:
			continue

		var source: Dictionary = villager
		var aged_age: float = maxf(0.0, float(source.get("age", 0.0)) + elapsed_years)
		if aged_age > MAX_AGE:
			died += 1
			continue

		var aged_stage: String = stage_for(aged_age)
		var aged_sex: String = str(source.get("sex", ""))
		var aged_villager: Dictionary = {
			"age": aged_age,
			"sex": aged_sex,
			"stage": aged_stage,
		}
		aged_villagers.append(aged_villager)

		if aged_stage == "adult":
			if aged_sex == "m":
				fertile_males += 1
			elif aged_sex == "f":
				fertile_females += 1

	var pair_count: int = mini(fertile_males, fertile_females)
	var expected_births: float = float(pair_count) * birth_rate * elapsed_years
	var born: int = int(floorf(expected_births))
	var fractional_birth: float = expected_births - float(born)
	if fractional_birth > 0.0 and rng.randf() < fractional_birth:
		born += 1

	for index: int in range(born):
		var newborn_sex: String = "m" if rng.randf() < 0.5 else "f"
		aged_villagers.append(make_villager(0.0, newborn_sex, rng))

	return {
		"villagers": aged_villagers,
		"born": born,
		"died": died,
	}
