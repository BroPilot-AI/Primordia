class_name WorkAreaModel

static func make_area(pos: Vector3, radius: float, kind: String, max_workers: int) -> Dictionary:
	return {
		"pos": pos,
		"radius": radius,
		"kind": kind,
		"max_workers": max_workers
	}

static func in_area(pos: Vector3, area: Dictionary) -> bool:
	var to_pos: Vector3 = pos - area["pos"]
	# Ignore Y axis for distance check
	var xz_distance: float = sqrt(to_pos.x * to_pos.x + to_pos.z * to_pos.z)
	return xz_distance <= area["radius"]

static func assign(worker_positions: Array, areas: Array) -> Dictionary:
	var assignments: Dictionary = {}
	var worker_count: int = worker_positions.size()
	var area_count: int = areas.size()
	
	# Initialize assignments to -1 (no area)
	for i in worker_count:
		assignments[i] = -1
	
	# Track current worker count per area
	var area_workers: Array = []
	for i in area_count:
		area_workers.append(0)
	
	# For each worker, find nearest area with available slot
	for worker_idx in worker_count:
		var worker_pos: Vector3 = worker_positions[worker_idx]
		var best_area_idx: int = -1
		var best_distance: float = INF
		
		for area_idx in area_count:
			# Skip if area is full
			if area_workers[area_idx] >= areas[area_idx]["max_workers"]:
				continue
			
			var to_area: Vector3 = worker_pos - areas[area_idx]["pos"]
			var xz_distance: float = sqrt(to_area.x * to_area.x + to_area.z * to_area.z)
			
			if xz_distance < best_distance:
				best_distance = xz_distance
				best_area_idx = area_idx
		
		if best_area_idx != -1:
			assignments[worker_idx] = best_area_idx
			area_workers[best_area_idx] += 1
	
	return assignments

static func yield_for(kind: String, worker_count: int, delta: float) -> float:
	# Map zone kinds to balance keys explicitly — "hunt"→hunt_yield, gathers→gather_rate.
	var rate: float = TribeBalance.value("hunt_yield" if kind == "hunt" else "gather_rate", 1.0)
	return worker_count * rate * delta