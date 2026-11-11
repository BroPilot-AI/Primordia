class_name StationStats

const STATIONS := {
	"outpost": {
		"metal": 120,
		"energy": 60,
		"hp": 220.0,
		"build_time": 25.0,
		"role": "frontier",
		"min_tier": 1,
	},
	"refinery": {
		"metal": 220,
		"energy": 130,
		"hp": 280.0,
		"build_time": 55.0,
		"role": "economy",
		"min_tier": 1,
	},
	"sensor_array": {
		"metal": 160,
		"energy": 110,
		"hp": 170.0,
		"build_time": 40.0,
		"role": "intel",
		"min_tier": 1,
	},
	"shipyard": {
		"metal": 380,
		"energy": 220,
		"hp": 420.0,
		"build_time": 95.0,
		"role": "production",
		"min_tier": 2,
	},
	"defense_grid": {
		"metal": 460,
		"energy": 280,
		"hp": 560.0,
		"build_time": 115.0,
		"role": "military",
		"min_tier": 2,
	},
}

static func has_station(id: String) -> bool:
	return STATIONS.has(id)

static func get_station(id: String) -> Dictionary:
	if STATIONS.has(id):
		return STATIONS[id]
	return {}

static func stations_for_tier(tier: int) -> Array[String]:
	var result: Array[String] = []
	for id: String in STATIONS:
		if int(STATIONS[id]["min_tier"]) == tier:
			result.append(id)
	return result


# Stations buildable at the given system tier — i.e. ALL stations whose `min_tier`
# is at most the supplied tier. Mirrors DefenseStats.defenses_for_tier so a tier-3
# system can build a tier-1 refinery. Use this for the live build-gate; the
# `stations_for_tier` (exact match) is kept for data-classification callers.
static func buildable_stations_for_tier(tier: int) -> Array[String]:
	var result: Array[String] = []
	for id: String in STATIONS:
		if int(STATIONS[id]["min_tier"]) <= tier:
			result.append(id)
	return result
