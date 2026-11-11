class_name ShipStats

const SHIPS: Dictionary = {
	"scout": {
		"metal": 30,
		"energy": 10,
		"hp": 40.0,
		"damage": 4.0,
		"range": 180.0,
		"speed": 320.0,
		"build_time": 4.0,
		"role": "recon",
		"min_tier": 1,
	},
	"fighter": {
		"metal": 60,
		"energy": 20,
		"hp": 90.0,
		"damage": 12.0,
		"range": 220.0,
		"speed": 240.0,
		"build_time": 7.0,
		"role": "interceptor",
		"min_tier": 1,
	},
	"corvette": {
		"metal": 120,
		"energy": 45,
		"hp": 180.0,
		"damage": 22.0,
		"range": 280.0,
		"speed": 210.0,
		"build_time": 12.0,
		"role": "skirmisher",
		"min_tier": 2,
	},
	"frigate": {
		"metal": 220,
		"energy": 90,
		"hp": 360.0,
		"damage": 38.0,
		"range": 340.0,
		"speed": 170.0,
		"build_time": 20.0,
		"role": "line",
		"min_tier": 2,
	},
	"cruiser": {
		"metal": 480,
		"energy": 200,
		"hp": 780.0,
		"damage": 70.0,
		"range": 420.0,
		"speed": 140.0,
		"build_time": 36.0,
		"role": "heavy",
		"min_tier": 3,
	},
	"battleship": {
		"metal": 950,
		"energy": 420,
		"hp": 1600.0,
		"damage": 140.0,
		"range": 520.0,
		"speed": 100.0,
		"build_time": 70.0,
		"role": "capital",
		"min_tier": 4,
	},
	"ion_dread": {
		"metal": 2200,
		"energy": 1100,
		"hp": 3800.0,
		"damage": 320.0,
		"range": 680.0,
		"speed": 70.0,
		"build_time": 150.0,
		"role": "dreadnought",
		"min_tier": 5,
	},
}

static func has_ship(id: String) -> bool:
	return SHIPS.has(id)

static func get_ship(id: String) -> Dictionary:
	if SHIPS.has(id):
		return SHIPS[id]
	return {}

static func ships_for_tier(tier: int) -> Array[String]:
	var result: Array[String] = []
	for id: String in SHIPS.keys():
		var entry: Dictionary = SHIPS[id]
		if int(entry["min_tier"]) <= tier:
			result.append(id)
	return result
