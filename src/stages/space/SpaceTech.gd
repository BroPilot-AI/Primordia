class_name SpaceTech

const TECHS: Dictionary = {
	"basic_propulsion": {
		"cost": 80,
		"prereq": "",
		"tier": 1,
		"effect": "ship_speed",
		"value": 0.10,
		"label": "Basic Propulsion",
	},
	"mining_efficiency": {
		"cost": 100,
		"prereq": "",
		"tier": 1,
		"effect": "metal_yield",
		"value": 0.15,
		"label": "Mining Efficiency",
	},
	"improved_armor": {
		"cost": 220,
		"prereq": "basic_propulsion",
		"tier": 2,
		"effect": "ship_hp",
		"value": 0.20,
		"label": "Improved Armor",
	},
	"targeting_systems": {
		"cost": 260,
		"prereq": "mining_efficiency",
		"tier": 2,
		"effect": "ship_damage",
		"value": 0.18,
		"label": "Targeting Systems",
	},
	"shield_harmonics": {
		"cost": 540,
		"prereq": "improved_armor",
		"tier": 3,
		"effect": "defense_hp",
		"value": 0.25,
		"label": "Shield Harmonics",
	},
	"plasma_weapons": {
		"cost": 620,
		"prereq": "targeting_systems",
		"tier": 3,
		"effect": "ship_damage",
		"value": 0.30,
		"label": "Plasma Weapons",
	},
	"ion_drive": {
		"cost": 1200,
		"prereq": "plasma_weapons",
		"tier": 4,
		"effect": "ship_speed",
		"value": 0.35,
		"label": "Ion Drive",
	},
	"quantum_computing": {
		"cost": 1400,
		"prereq": "shield_harmonics",
		"tier": 4,
		"effect": "build_speed",
		"value": 0.40,
		"label": "Quantum Computing",
	},
}

static func get_tech(id: String) -> Dictionary:
	if TECHS.has(id):
		return TECHS[id]
	return {}

static func unlocked(researched: Array) -> Array[String]:
	var result: Array[String] = []
	for id: String in TECHS.keys():
		if researched.has(id):
			continue
		var entry: Dictionary = TECHS[id]
		var prereq: String = String(entry["prereq"])
		if prereq == "" or researched.has(prereq):
			result.append(id)
	return result

static func tech_label(id: String) -> String:
	if TECHS.has(id):
		var entry: Dictionary = TECHS[id]
		return String(entry["label"])
	return ""
