class_name GalaxySim
## Pure-logic for the living galaxy: per-empire strength, strength-based
## attack resolution, war costs, and the "watch worlds mature" evolution ring color.
## No nodes, no state — every function is static + deterministic (RNG passed in), so
## the whole living-galaxy ruleset is unit-testable without spinning up the 3D stage.
## SpaceStage3D owns the systems/empires and calls these; StarSystem3D calls
## evo_ring_color() to tint a neutral world's ownership ring as it climbs the ladder.

## Evolution ladder length: Primordial(0) → Creature(1) → Tribe(2) → Civ(3) → Space(4).
const EVO_MAX_STAGE: float = 4.0

## Strength weights — systems dominate, treasury & tech are the multipliers that let a
## rich/advanced empire punch above its system count (and a broke sprawl get overrun).
const STRENGTH_PER_SYSTEM: float = 1.0
const STRENGTH_PER_TREASURY: float = 0.01
const STRENGTH_PER_TECH: float = 0.6

## War costs the attacker a slice of its treasury whether it wins or loses — stops an
## empire from cheaply machine-gunning attacks every tick and makes expansion a choice.
const ATTACK_COST_FRACTION: float = 0.45

## Attack win-chance is clamped so the galaxy never becomes deterministic: even a much
## stronger empire can be repelled (drama), and an underdog always has a puncher's chance.
const ATTACK_MIN_CHANCE: float = 0.10
const ATTACK_MAX_CHANCE: float = 0.92

## AI empire development: same structure identities as SpaceStage3D, but kept scalar
## so non-player empires can spend their one-number treasury without touching nodes.
const DEVELOP_NONE: String = ""
const DEVELOP_KIND_BASTION: String = "Bastion"
const DEVELOP_KIND_MINING_RIG: String = "MiningRig"
const DEVELOP_KIND_RESEARCH_LAB: String = "ResearchLab"
const DEVELOP_STRUCTURE_COSTS: Dictionary = {
	DEVELOP_KIND_BASTION: 14.0,
	DEVELOP_KIND_MINING_RIG: 16.0,
	DEVELOP_KIND_RESEARCH_LAB: 22.0,
}
const DEVELOP_MIN_STAGE: Dictionary = {
	DEVELOP_KIND_BASTION: 0,
	DEVELOP_KIND_MINING_RIG: 0,
	DEVELOP_KIND_RESEARCH_LAB: 2,
}


## Overall fighting strength of an empire. `systems` is its owned-system count,
## `treasury` its accrued resources (float total), `tech` its research level.
static func empire_strength(systems: int, treasury: float, tech: float) -> float:
	var sys_f: float = maxf(0.0, float(systems))
	var tre_f: float = maxf(0.0, treasury) if is_finite(treasury) else 0.0
	var tech_f: float = maxf(0.0, tech) if is_finite(tech) else 0.0
	return sys_f * STRENGTH_PER_SYSTEM + tre_f * STRENGTH_PER_TREASURY + tech_f * STRENGTH_PER_TECH


## Probability in [ATTACK_MIN_CHANCE, ATTACK_MAX_CHANCE] that `attacker` beats `defender`.
static func attack_win_chance(attacker_strength: float, defender_strength: float) -> float:
	var a: float = maxf(0.0, attacker_strength) if is_finite(attacker_strength) else 0.0
	var d: float = maxf(0.0, defender_strength) if is_finite(defender_strength) else 0.0
	var total: float = a + d
	if total <= 0.0:
		return 0.5
	return clampf(a / total, ATTACK_MIN_CHANCE, ATTACK_MAX_CHANCE)


## Resolve one attack. True = attacker captures the target; false = repelled.
static func resolve_attack(attacker_strength: float, defender_strength: float, rng: RandomNumberGenerator) -> bool:
	if rng == null:
		return attacker_strength > defender_strength
	return rng.randf() < attack_win_chance(attacker_strength, defender_strength)


## Treasury an empire spends to press an attack (paid win or lose).
static func attack_cost(treasury: float) -> float:
	if not is_finite(treasury) or treasury <= 0.0:
		return 0.0
	return treasury * ATTACK_COST_FRACTION


## True when a scalar empire treasury can pay a scalar development cost.
static func can_develop(treasury: float, cost: float) -> bool:
	if not is_finite(treasury) or not is_finite(cost):
		return false
	return cost > 0.0 and treasury >= cost


## Pick the structure and candidate-system index an AI empire should develop this turn.
## Candidates are dictionaries with {index, evo_stage, structure, income, threat}. Returns
## {kind, index, cost}, or DEVELOP_NONE/-1/0.0 when no affordable eligible system exists.
static func choose_development(
	action: String,
	archetype: String,
	treasury: float,
	candidates: Array[Dictionary],
	costs: Dictionary = DEVELOP_STRUCTURE_COSTS,
) -> Dictionary:
	var choice: Dictionary = {"kind": DEVELOP_NONE, "index": -1, "cost": 0.0}
	var priority: Array[String] = development_priority(action, archetype)
	if priority.is_empty():
		return choice
	for kind: String in priority:
		var cost: float = float(costs.get(kind, DEVELOP_STRUCTURE_COSTS.get(kind, INF)))
		if not can_develop(treasury, cost):
			continue
		var min_stage: int = int(DEVELOP_MIN_STAGE.get(kind, 0))
		var best_index: int = -1
		var best_score: float = -INF
		for candidate: Dictionary in candidates:
			if str(candidate.get("structure", "")) != "":
				continue
			if int(candidate.get("evo_stage", 0)) < min_stage:
				continue
			var index: int = int(candidate.get("index", -1))
			if index < 0:
				continue
			var score: float = _development_candidate_score(kind, candidate)
			if best_index < 0 or score > best_score:
				best_index = index
				best_score = score
		if best_index >= 0:
			choice["kind"] = kind
			choice["index"] = best_index
			choice["cost"] = cost
			return choice
	return choice


static func development_priority(action: String, archetype: String) -> Array[String]:
	var arch: String = archetype.to_lower()
	if action == "fortify":
		if arch == "diplomat":
			return [DEVELOP_KIND_MINING_RIG, DEVELOP_KIND_BASTION, DEVELOP_KIND_RESEARCH_LAB]
		if arch == "scholar" or arch == "technocrat":
			return [DEVELOP_KIND_BASTION, DEVELOP_KIND_RESEARCH_LAB, DEVELOP_KIND_MINING_RIG]
		return [DEVELOP_KIND_BASTION, DEVELOP_KIND_MINING_RIG, DEVELOP_KIND_RESEARCH_LAB]
	if action == "research":
		if arch == "fortifier" or arch == "isolationist":
			return [DEVELOP_KIND_BASTION, DEVELOP_KIND_RESEARCH_LAB, DEVELOP_KIND_MINING_RIG]
		if arch == "diplomat" or arch == "expansionist":
			return [DEVELOP_KIND_MINING_RIG, DEVELOP_KIND_RESEARCH_LAB, DEVELOP_KIND_BASTION]
		return [DEVELOP_KIND_RESEARCH_LAB, DEVELOP_KIND_MINING_RIG, DEVELOP_KIND_BASTION]
	return []


static func _development_candidate_score(kind: String, candidate: Dictionary) -> float:
	var income: float = maxf(0.0, float(candidate.get("income", 0.0)))
	var threat: float = maxf(0.0, float(candidate.get("threat", 0.0)))
	var stage: float = maxf(0.0, float(candidate.get("evo_stage", 0)))
	if kind == DEVELOP_KIND_BASTION:
		return threat * 100.0 + income * 0.1 + stage
	if kind == DEVELOP_KIND_RESEARCH_LAB:
		return stage * 10.0 + income
	if kind == DEVELOP_KIND_MINING_RIG:
		return income * 10.0 + stage
	return 0.0


## Empire decision cadence: starts at `base` seconds and tightens as the game runs on,
## floored at `min_interval` so the late galaxy churns faster than the early one.
static func expansion_interval(base: float, elapsed: float, min_interval: float) -> float:
	var e: float = maxf(0.0, elapsed) if is_finite(elapsed) else 0.0
	return maxf(min_interval, base - e * 0.04)


## Ownership-ring color for a NEUTRAL world, tinted by how far up the evolution ladder
## it has climbed: a cold dim ember at Primordial, warming to a vivid bio-green as it
## nears spacefaring — so the player literally watches life arise across the galaxy.
## `base` is the system's neutral grey (used only as a faint floor tint).
static func evo_ring_color(base: Color, evo_stage: int, evo_progress: float) -> Color:
	var stage_f: float = clampf(float(evo_stage), 0.0, EVO_MAX_STAGE)
	var prog: float = clampf(evo_progress, 0.0, 1.0) if is_finite(evo_progress) else 0.0
	var t: float = clampf((stage_f + prog) / EVO_MAX_STAGE, 0.0, 1.0)
	# Cold dormant ember → quickening green-cyan. Value (brightness) ramps with t so a
	# maturing world visibly glows brighter as it approaches emergence.
	var cold: Color = Color(0.26, 0.28, 0.38)
	var ripe: Color = Color(0.35, 0.95, 0.70)
	var col: Color = cold.lerp(ripe, t)
	# Blend a whisper of the system's own neutral grey at the cold end so freshly-seeded
	# worlds don't all read identically, and brighten the whole thing toward emergence.
	col = col.lerp(base, 0.12 * (1.0 - t))
	return col.lerp(Color.WHITE, 0.18 * t)


## Weight [0.1, 1.0] — how threatening a target's owner strength is relative to the
## strongest known rival. 1.0 for the strongest rival; never below 0.1 so even the
## weakest target still registers and isn't completely ignored when nothing else exists.
static func threat_weight(target_strength: float, max_strength: float) -> float:
	if max_strength <= 0.0 or not is_finite(max_strength):
		return 0.1
	var s: float = maxf(0.0, target_strength) if is_finite(target_strength) else 0.0
	return clampf(s / max_strength, 0.1, 1.0)


## Score an enemy system as a target for an empire. Combines distance (closer = better)
## and owner strength (stronger = more threatening = higher priority). Higher return =
## more desirable target. Returns -INF for unreachable (non-finite distance).
## Used by SpaceStage3D._empire_pick_target so a runaway leader draws coordinated fire.
static func score_enemy_target(
	nearest_dist: float,
	owner_strength: float,
	max_rival_strength: float,
) -> float:
	var d: float = maxf(0.0, nearest_dist) if is_finite(nearest_dist) else INF
	if not is_finite(d):
		return -INF
	var tw: float = threat_weight(owner_strength, max_rival_strength)
	return tw * 200.0 - d


## True once a world has reached spacefaring (stage 4) and is ready to birth an empire.
static func is_emergent(evo_stage: int) -> bool:
	return evo_stage >= int(EVO_MAX_STAGE)
