class_name Boids3D

func steer(pos: Vector3, vel: Vector3, neighbors: Array[Vector3], target: Vector3, max_speed: float) -> Vector3:
	var separation: Vector3 = Vector3.ZERO
	var cohesion: Vector3 = Vector3.ZERO
	var alignment: Vector3 = Vector3.ZERO
	var seek: Vector3 = Vector3.ZERO
	
	var neighbor_count: int = neighbors.size()
	
	if neighbor_count > 0:
		# Separation - push away from nearby neighbors
		for n in neighbors:
			var to_neighbor: Vector3 = pos - n
			if to_neighbor.length() < 6.0 and to_neighbor.length() > 0.0:
				separation += to_neighbor.normalized() / to_neighbor.length()
		
		# Cohesion - move toward neighbor centroid
		var centroid: Vector3 = Vector3.ZERO
		for n in neighbors:
			centroid += n
		centroid /= neighbor_count
		cohesion = (centroid - pos).normalized()
		
		# Alignment - skip if no neighbor velocities (not provided in parameters)
		# alignment remains ZERO as instructed
	
	# Seek - move toward target
	var to_target: Vector3 = target - pos
	if to_target.length() > 0.0:
		seek = to_target.normalized()
	
	# Combine all forces
	var steering: Vector3 = separation + cohesion + alignment + seek
	
	# If steering is zero, return current velocity
	if steering.length() == 0.0:
		return vel
	
	# Normalize and scale to max_speed
	steering = steering.normalized() * max_speed
	
	# Return the new velocity (steering force added to current velocity, then clamped)
	var new_vel: Vector3 = vel + steering
	if new_vel.length() > max_speed:
		new_vel = new_vel.normalized() * max_speed
	
	return new_vel