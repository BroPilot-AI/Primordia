class_name MutationModel

const BASE_MUT_RATE: float = 0.01

static func mutate(genome: Dictionary, hotspot_intensity: float, rng: RandomNumberGenerator) -> Dictionary:
	var new_genome: Dictionary = genome.duplicate()
	for key in new_genome.keys():
		var value = new_genome[key]
		if value is float:
			var drift: float = (rng.randf() * 2.0 - 1.0) * BASE_MUT_RATE * (1.0 + hotspot_intensity)
			new_genome[key] = value + drift
	return new_genome

static func in_hotspot(pos: Vector2, hotspots: Array, radius: float) -> float:
	if hotspots.size() == 0:
		return 0.0
	var min_distance: float = INF
	for hotspot in hotspots:
		var distance: float = pos.distance_to(hotspot)
		if distance < min_distance:
			min_distance = distance
	if min_distance >= radius:
		return 0.0
	return 1.0 - (min_distance / radius)