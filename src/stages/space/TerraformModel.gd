class_name TerraformModel

const SYNERGY: Dictionary = {
	"flora": {
		"boosts": ["water", "mineral"],
		"base_yield": 5.0,
	},
	"fauna": {
		"boosts": ["flora"],
		"base_yield": 8.0,
	},
	"mineral": {
		"boosts": [],
		"base_yield": 3.0,
	},
	"water": {
		"boosts": [],
		"base_yield": 2.0,
	},
}

const BONUS_PER_NEIGHBOR: float = 1.5

static func has_type(t: String) -> bool:
	return SYNERGY.has(t)

static func synergy_bonus(tile_type: String, neighbor_types: Array) -> float:
	if not SYNERGY.has(tile_type):
		return 0.0
	var boosts: Array = SYNERGY[tile_type]["boosts"]
	var count: int = 0
	for nt in neighbor_types:
		if boosts.has(nt):
			count += 1
	return float(count) * BONUS_PER_NEIGHBOR

static func tile_yield(tile_type: String, neighbor_types: Array) -> float:
	if not SYNERGY.has(tile_type):
		return 0.0
	var base: float = SYNERGY[tile_type]["base_yield"]
	return base + synergy_bonus(tile_type, neighbor_types)

static func habitability_gain(tiles: Array, delta: float) -> float:
	var total: float = 0.0
	for item in tiles:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var tile_type: String = item.get("type", "")
		var neighbors: Array = item.get("neighbors", [])
		total += tile_yield(tile_type, neighbors)
	return total * delta
