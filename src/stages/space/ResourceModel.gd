class_name ResourceModel

const RESOURCES: Dictionary = {
	"metal": {
		"label": "Metal",
		"base_rate": 12.0,
		"from": "asteroid",
		"color": Color("#8a9ba8"),
	},
	"energy": {
		"label": "Energy",
		"base_rate": 8.0,
		"from": "star",
		"color": Color("#f5d742"),
	},
	"water": {
		"label": "Water",
		"base_rate": 6.0,
		"from": "moon",
		"color": Color("#4a9eff"),
	},
	"biomass": {
		"label": "Biomass",
		"base_rate": 4.0,
		"from": "planet",
		"color": Color("#5dbf6e"),
	},
}

static func get_resource(id: String) -> Dictionary:
	if RESOURCES.has(id):
		return RESOURCES[id]
	return {}

static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in RESOURCES.keys():
		ids.append(id)
	return ids

static func base_rate(id: String) -> float:
	if RESOURCES.has(id):
		return float(RESOURCES[id]["base_rate"])
	return 0.0
