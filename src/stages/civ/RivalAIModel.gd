class_name RivalAIModel

# Rival state dictionary keys:
# - gold: float (treasury)
# - army: int (military strength)
# - aggression: float [0.0, 1.0] (willingness to attack)
# - expansion: float [0.0, 1.0] (willingness to expand territory)

static func choose_action(state: Dictionary, rng: RandomNumberGenerator) -> String:
	var gold: float = state.get("gold", 0.0)
	var army: int = state.get("army", 0)
	var aggression: float = state.get("aggression", 0.0)
	var expansion: float = state.get("expansion", 0.0)
	
	# Calculate weights for each action
	var expand_weight: float = expansion * gold
	var build_army_weight: float = aggression * gold
	var attack_weight: float = aggression * army
	var fortify_weight: float = (1.0 - aggression) * gold
	var idle_weight: float = 1.0  # Base chance to do nothing
	
	# Avoid zero weights by adding small epsilon
	var epsilon: float = 0.001
	expand_weight += epsilon
	build_army_weight += epsilon
	attack_weight += epsilon
	fortify_weight += epsilon
	idle_weight += epsilon
	
	var total_weight: float = expand_weight + build_army_weight + attack_weight + fortify_weight + idle_weight
	var choice_point: float = rng.randf() * total_weight
	
	if choice_point < expand_weight:
		return "expand"
	elif choice_point < expand_weight + build_army_weight:
		return "build_army"
	elif choice_point < expand_weight + build_army_weight + attack_weight:
		return "attack"
	elif choice_point < expand_weight + build_army_weight + attack_weight + fortify_weight:
		return "fortify"
	else:
		return "idle"

static func should_attack(state: Dictionary, player_strength: float) -> bool:
	var army: int = state.get("army", 0)
	var aggression: float = state.get("aggression", 0.0)
	var effective_strength: float = float(army) * aggression
	# Attack when our effective strength exceeds player strength by 20% margin
	return effective_strength > player_strength * 1.2

static func next_state(state: Dictionary, action: String) -> Dictionary:
	# Create a deep copy of state for immutability
	var new_state: Dictionary = {
		"gold": state.get("gold", 0.0),
		"army": state.get("army", 0),
		"aggression": state.get("aggression", 0.0),
		"expansion": state.get("expansion", 0.0)
	}
	
	match action:
		"expand":
			var cost: float = 50.0
			new_state["gold"] = max(0.0, new_state["gold"] - cost)
			new_state["expansion"] = min(1.0, new_state["expansion"] + 0.1)
		"build_army":
			var cost: float = 30.0
			new_state["gold"] = max(0.0, new_state["gold"] - cost)
			# Must match reality: CivStage3D._apply_rival_action spawns exactly ONE unit per
			# build_army — +5 here made rivals overestimate their strength and suicide-attack.
			new_state["army"] = new_state["army"] + 1
		"attack":
			var gold_cost: float = 20.0
			var army_cost: int = 3
			new_state["gold"] = max(0.0, new_state["gold"] - gold_cost)
			new_state["army"] = max(0, new_state["army"] - army_cost)
		"fortify":
			var cost: float = 40.0
			new_state["gold"] = max(0.0, new_state["gold"] - cost)
			new_state["aggression"] = max(0.0, new_state["aggression"] - 0.1)
			new_state["expansion"] = min(1.0, new_state["expansion"] + 0.05)
		"idle":
			# Passive income
			new_state["gold"] = new_state["gold"] + 10.0
	
	return new_state