class_name EcologyModel

static func harvest(pop: float, amount: float) -> float:
	return maxf(0.0, pop - amount)

static func regrow(pop: float, carrying_capacity: float, rate: float, delta: float) -> float:
	var capacity: float = maxf(0.0, carrying_capacity)
	if capacity <= 0.0:
		return maxf(0.0, pop)
	var current: float = clampf(pop, 0.0, capacity)
	var growth: float = rate * current * (1.0 - current / capacity) * delta
	return clampf(current + growth, 0.0, capacity)

static func depleted(pop: float, carrying_capacity: float) -> bool:
	return pop < 0.1 * carrying_capacity
