class_name EmpireAI
## AI empire decision logic. Pure data, no nodes — chooses one action per
## empire turn from a weighted distribution driven by FactionTraits archetype
## modifiers and current empire state (treasury, systems held).
##
## Actions: "expand", "attack", "research", "fortify", "idle".
## Higher aggression → "attack"; higher expand + enough treasury → "expand";
## higher tech_focus → "research"; isolationist / poor / sprawling → "fortify".
## Falls back to "idle" if all weights collapse to zero.

const ACTION_EXPAND: String = "expand"
const ACTION_ATTACK: String = "attack"
const ACTION_RESEARCH: String = "research"
const ACTION_FORTIFY: String = "fortify"
const ACTION_IDLE: String = "idle"

const EXPAND_TREASURY_BASE: float = 100.0
const EXPAND_TREASURY_PER_SYSTEM: float = 50.0
const EXPAND_SATURATION: int = 12
const LOW_TREASURY_THRESHOLD: float = 50.0
const FORTIFY_SYSTEM_THRESHOLD: int = 5
const FORTIFY_BASELINE: float = 0.3
const IDLE_BASELINE: float = 0.2
const LOW_TREASURY_FORTIFY_BONUS: float = 0.5
const FORTIFY_PER_EXTRA_SYSTEM: float = 0.1
const FALLBACK_ARCHETYPE: String = "expansionist"

## Shared decision engine for BOTH Space empires and Civ rival nations (cohesion backport).
## `empire` carries treasury + systems and EITHER inline trait floats
## (aggression/expand/tech_focus — used by Civ rivals, which carry their own personality)
## OR an `archetype` name looked up in FactionTraits (Space empires). `expand_base` /
## `expand_per_system` let a caller match its own economy scale (Civ gold is much smaller
## than a Space treasury) without changing the weighting logic.
static func choose_action(
	empire: Dictionary,
	rng: RandomNumberGenerator,
	expand_base: float = EXPAND_TREASURY_BASE,
	expand_per_system: float = EXPAND_TREASURY_PER_SYSTEM,
) -> String:
	var treasury: float = float(empire.get("treasury", 0.0))
	var systems: int = int(empire.get("systems", 0))
	var aggression: float
	var expand: float
	var tech_focus: float
	if empire.has("aggression") or empire.has("expand") or empire.has("tech_focus"):
		# Inline traits (Civ rivals supply their own).
		aggression = float(empire.get("aggression", 0.5))
		expand = float(empire.get("expand", 0.5))
		tech_focus = float(empire.get("tech_focus", 0.5))
	else:
		# Archetype lookup (Space empires).
		var archetype: String = String(empire.get("archetype", FALLBACK_ARCHETYPE))
		var traits: Dictionary = FactionTraits.get_archetype(archetype)
		if traits.is_empty():
			traits = FactionTraits.get_archetype(FALLBACK_ARCHETYPE)
		aggression = float(traits.get("aggression", 0.5))
		expand = float(traits.get("expand", 0.5))
		tech_focus = float(traits.get("tech_focus", 0.5))
	var weights: Array = _build_weights(aggression, expand, tech_focus, treasury, systems, expand_base, expand_per_system)
	return _pick_weighted(weights, rng)

static func describe(action: String) -> String:
	match action:
		ACTION_EXPAND: return "Establish a new colony in an unclaimed system."
		ACTION_ATTACK: return "Launch an offensive against a rival empire's holdings."
		ACTION_RESEARCH: return "Fund research to unlock the next technology tier."
		ACTION_FORTIFY: return "Reinforce defenses and consolidate current systems."
		ACTION_IDLE: return "Hold position and reassess strategic priorities."
		_: return "Unknown action."

static func _build_weights(
	aggression: float,
	expand: float,
	tech_focus: float,
	treasury: float,
	systems: int,
	expand_base: float = EXPAND_TREASURY_BASE,
	expand_per_system: float = EXPAND_TREASURY_PER_SYSTEM,
) -> Array:
	var attack_w: float = maxf(aggression, 0.0)
	var needed_treasury: float = expand_base + float(systems) * expand_per_system
	var expand_w: float = 0.0
	if treasury >= needed_treasury and systems < EXPAND_SATURATION:
		var saturation: float = clampf(float(systems) / float(EXPAND_SATURATION), 0.0, 1.0)
		expand_w = maxf(expand, 0.0) * (1.0 - saturation)
	var research_w: float = maxf(tech_focus, 0.0)
	var fortify_w: float = FORTIFY_BASELINE
	if treasury < LOW_TREASURY_THRESHOLD:
		fortify_w += LOW_TREASURY_FORTIFY_BONUS
	if systems >= FORTIFY_SYSTEM_THRESHOLD:
		fortify_w += FORTIFY_PER_EXTRA_SYSTEM * float(systems - FORTIFY_SYSTEM_THRESHOLD + 1)
	var idle_w: float = IDLE_BASELINE
	return [
		[ACTION_EXPAND, expand_w],
		[ACTION_ATTACK, attack_w],
		[ACTION_RESEARCH, research_w],
		[ACTION_FORTIFY, fortify_w],
		[ACTION_IDLE, idle_w],
	]

static func _pick_weighted(weights: Array, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for entry: Array in weights:
		total += float(entry[1])
	if total <= 0.0:
		return ACTION_IDLE
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for entry: Array in weights:
		acc += float(entry[1])
		if roll <= acc:
			return entry[0]
	return ACTION_IDLE
