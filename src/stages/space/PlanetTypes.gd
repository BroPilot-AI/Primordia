class_name PlanetTypes

const PLANETS := {
	"terran": {
		"label": "Terran",
		"habitability": 0.90,
		"resource_bias": "biomass",
		"color": Color("#3d8a4a"),
	},
	"ocean": {
		"label": "Ocean",
		"habitability": 0.65,
		"resource_bias": "water",
		"color": Color("#2a6cb0"),
	},
	"desert": {
		"label": "Desert",
		"habitability": 0.25,
		"resource_bias": "metal",
		"color": Color("#c89958"),
	},
	"ice": {
		"label": "Ice",
		"habitability": 0.15,
		"resource_bias": "water",
		"color": Color("#cfe4f0"),
	},
	"gas": {
		"label": "Gas Giant",
		"habitability": 0.05,
		"resource_bias": "energy",
		"color": Color("#c89058"),
	},
	"barren": {
		"label": "Barren",
		"habitability": 0.05,
		"resource_bias": "metal",
		"color": Color("#6a625c"),
	},
	"volcanic": {
		"label": "Volcanic",
		"habitability": 0.10,
		"resource_bias": "energy",
		"color": Color("#8a2a1a"),
	},
	"jungle": {
		"label": "Jungle",
		"habitability": 0.85,
		"resource_bias": "biomass",
		"color": Color("#1f5a2a"),
	},
}

static func get_planet(id: String) -> Dictionary:
	if PLANETS.has(id):
		return PLANETS[id]
	return {}

static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in PLANETS:
		ids.append(key)
	return ids

static func random_type(rng: RandomNumberGenerator) -> String:
	var ids: Array[String] = all_ids()
	return ids[rng.randi() % ids.size()]
