class_name HubDefense

static func acquire_target(hub_pos: Vector3, hostiles: Array, range_f: float) -> int:
	var best_idx := -1
	var best_dist_sq := range_f * range_f
	for i in hostiles.size():
		var s = hostiles[i]
		if s == null or not is_instance_valid(s.node) or s.hp <= 0.0:
			continue
		var d_sq := hub_pos.distance_squared_to(s.node.position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_idx = i
	return best_idx

static func can_fire(cooldown_left: float) -> bool:
	return cooldown_left <= 0.0

static func next_cooldown(weapon: Dictionary) -> float:
	var cd := float(weapon.get("attack_cooldown", 0.0))
	if cd > 0.0:
		return cd
	return 1.5
