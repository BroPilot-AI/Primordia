class_name FactionTraits
## AI empire archetypes (data only). Modifiers 0.0–2.0; consumed by the Space living-galaxy sim.

const ARCHETYPES := {
	"militarist": {"label": "Militarist", "aggression": 1.8, "expand": 0.6, "tech_focus": 0.4, "dmg_mult": 1.5, "hp_mult": 1.2},
	"expansionist": {"label": "Expansionist", "aggression": 0.4, "expand": 1.8, "tech_focus": 0.6, "dmg_mult": 0.8, "hp_mult": 1.4},
	"technocrat": {"label": "Technocrat", "aggression": 0.3, "expand": 0.4, "tech_focus": 1.8, "dmg_mult": 1.0, "hp_mult": 0.8},
	"swarm": {"label": "Swarm", "aggression": 1.6, "expand": 1.6, "tech_focus": 0.2, "dmg_mult": 0.5, "hp_mult": 0.6},
	"isolationist": {"label": "Isolationist", "aggression": 0.2, "expand": 0.2, "tech_focus": 0.3, "dmg_mult": 1.4, "hp_mult": 1.6},
}

static func get_archetype(id: String) -> Dictionary:
	return ARCHETYPES.get(id, {})

static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(ARCHETYPES.keys())   # .keys() is untyped Array; coerce to typed
	return ids

static func roll(rng: RandomNumberGenerator) -> String:
	var ids := all_ids()
	return ids[rng.randi_range(0, ids.size() - 1)]
