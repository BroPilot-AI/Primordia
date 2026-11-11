class_name DefenseStats

const DEFENSES: Dictionary = {
	"flak_turret": {
		"metal": 80,
		"energy": 30,
		"hp": 200.0,
		"damage": 6.0,
		"range": 240.0,
		"fire_rate": 3.5,
		"role": "anti_fighter",
		"min_tier": 1,
	},
	"laser_platform": {
		"metal": 180,
		"energy": 90,
		"hp": 380.0,
		"damage": 14.0,
		"range": 360.0,
		"fire_rate": 1.8,
		"role": "precise",
		"min_tier": 2,
	},
	"missile_battery": {
		"metal": 420,
		"energy": 180,
		"hp": 720.0,
		"damage": 60.0,
		"range": 520.0,
		"fire_rate": 0.6,
		"role": "siege",
		"min_tier": 3,
	},
	"shield_node": {
		"metal": 280,
		"energy": 320,
		"hp": 540.0,
		"damage": 0.0,
		"range": 320.0,
		"fire_rate": 0.0,
		"role": "shield",
		"min_tier": 3,
	},
	"ion_cannon": {
		"metal": 1100,
		"energy": 700,
		"hp": 1500.0,
		"damage": 220.0,
		"range": 780.0,
		"fire_rate": 0.18,
		"role": "anti_capital",
		"min_tier": 4,
	},
}

static func has_defense(id: String) -> bool:
	return DEFENSES.has(id)

static func get_defense(id: String) -> Dictionary:
	if DEFENSES.has(id):
		return DEFENSES[id]
	return {}

static func defenses_for_tier(tier: int) -> Array[String]:
	var result: Array[String] = []
	for id: String in DEFENSES.keys():
		var entry: Dictionary = DEFENSES[id]
		if int(entry["min_tier"]) <= tier:
			result.append(id)
	return result
