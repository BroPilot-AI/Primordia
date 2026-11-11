class_name EconomyModel

static func income(owned_systems: Array) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ResourceModel.all_ids():
		result[id] = 0.0
	for system: Variant in owned_systems:
		var bodies_value: Variant = null
		if system is Dictionary:
			bodies_value = (system as Dictionary).get("bodies", [])
		elif system is Object:
			bodies_value = (system as Object).get("bodies")
		if not (bodies_value is Array):
			continue
		var bodies: Array = bodies_value
		for body_value: Variant in bodies:
			var body: String = str(body_value)
			if not result.has(body):
				continue
			result[body] = float(result[body]) + ResourceModel.base_rate(body)
	return result

static func can_afford(treasury: Dictionary, cost: Dictionary) -> bool:
	for key: String in cost.keys():
		if float(treasury.get(key, 0.0)) < float(cost[key]):
			return false
	return true

static func spend(treasury: Dictionary, cost: Dictionary) -> Dictionary:
	var result: Dictionary = treasury.duplicate()
	for key: String in cost.keys():
		result[key] = float(result.get(key, 0.0)) - float(cost[key])
	return result


# A refinery turns the side resources into the two that build fleets: water -> metal and
# biomass -> energy, at REFINERY_YIELD, up to REFINERY_RATE per second each per refinery.
const REFINERY_RATE: Dictionary = {"water": 6.0, "biomass": 4.0}
const REFINERY_OUTPUT: Dictionary = {"water": "metal", "biomass": "energy"}
const REFINERY_YIELD: float = 0.5

static func refine(treasury: Dictionary, refineries: int, delta: float) -> Dictionary:
	var result: Dictionary = treasury.duplicate()
	if refineries <= 0 or delta <= 0.0:
		return result
	for src: String in REFINERY_RATE.keys():
		var held: float = float(result.get(src, 0.0))
		var amount: float = minf(held, float(REFINERY_RATE[src]) * refineries * delta)
		if amount <= 0.0:
			continue
		var dst: String = REFINERY_OUTPUT[src]
		result[src] = held - amount
		result[dst] = float(result.get(dst, 0.0)) + amount * REFINERY_YIELD
	return result
