class_name Genome
extends RefCounted
## The heritable spine of a run. The Primordial stage WRITES this (the starting biome
## locks the lineage branch; diet nudges the axes + color); every later stage READS it
## for appearance and gameplay bonuses. Pure data, immutable — mutators return a new copy.
##
## Two appearance regimes downstream:
##   pre-Civ (creature) = a parts kit per branch; Civ+ = one of a few humanoid species.

# --- Lineage branch: LOCKED at birth by the starting biome, through the come-on-land
# convergence at Civ. Four distinct biomes, confirmed by the MD (2026-05-25). ---
enum Branch { FRESHWATER, SALTWATER, DEEP_OCEAN, INLAND }
const BRANCH_COUNT := 4

# === LINEAGE REGISTRY — the single source of truth for a lineage across EVERY stage ===========
# ONE row per lineage (keyed by the birth Branch). Every stage reads its per-stage fields through
# the accessor methods below, so adding a NEW lineage — or a new per-stage field — is a ONE-PLACE
# change here that threads through Primordial → Creature → Tribe → Civ → Space automatically.
# To bolt on a new lineage: add a row (+ the matching art/sprites named to its keys) and it flows
# everywhere. (MD 2026-05-30: full modularity — future dev work bolts straight on.)
#
# LOCKED 2026-05-25 (thematic): freshwater pool = baseline life → Human; deep dark ocean =
# large-eyed depth-dwellers → Tall Violet; tidal shallow coast = scrappy amphibians → Tideling;
# dry inland soil → Reptilian. Each lineage also gets its OWN Space-stage superweapon.
# (2026-05-31: labels renamed to match the CC0 species models — ids unchanged. The freshwater
# rival/predator "hydra" displays as "Kraken" to match its Squidle model.)
const LINEAGES := {
	Branch.FRESHWATER: {
		species = "human", species_label = "Human",
		biome = "freshwater", biome_label = "freshwater pools", civ_spawn = "lake",
		legacy_creature = "drifter",
		superweapon = "Planet Annihilator",
		superweapon_flavor = "an orbital lance that cracks a world in a single shot",
		predator = "hydra",   # this biome's micro-predator → its Civ/Space rival archetype
		civ_archetype = {archetype = "hydra", tint = Color(0.80, 0.30, 0.30), prefer = "Soldier", hp_mult = 1.0, dmg_mult = 1.0, aggression = 0.9, expand = 0.55, train_interval = 3.0},
	},
	Branch.SALTWATER: {
		species = "short_alien", species_label = "Tideling",
		biome = "saltwater", biome_label = "saltwater shallows", civ_spawn = "coast",
		legacy_creature = "swarmer",
		superweapon = "Forge Breaker",
		superweapon_flavor = "an industrial siege engine that grinds planets to slag",
		predator = "sea_jelly",
		civ_archetype = {archetype = "sea_jelly", tint = Color(0.70, 0.50, 0.90), prefer = "Archer", hp_mult = 0.7, dmg_mult = 0.8, aggression = 0.7, expand = 0.30, train_interval = 2.0},
	},
	Branch.DEEP_OCEAN: {
		species = "tall_grey", species_label = "Tall Violet",
		biome = "deep_ocean", biome_label = "deep ocean", civ_spawn = "open_coast",
		legacy_creature = "engulfer",
		superweapon = "Mind Lance",
		superweapon_flavor = "a psionic beam that unmakes a world from within",
		predator = "lurker",
		civ_archetype = {archetype = "lurker", tint = Color(0.55, 0.35, 0.65), prefer = "Soldier", hp_mult = 1.4, dmg_mult = 1.1, aggression = 0.4, expand = 0.18, train_interval = 5.0},
	},
	Branch.INLAND: {
		species = "reptilian", species_label = "Reptilian",
		biome = "inland", biome_label = "damp inland soil", civ_spawn = "inland",
		legacy_creature = "verdant",
		superweapon = "World-Eater",
		superweapon_flavor = "a bio-organic swarm that devours a planet whole",
		predator = "nematode",
		civ_archetype = {archetype = "nematode", tint = Color(0.60, 0.55, 0.30), prefer = "Soldier", hp_mult = 1.1, dmg_mult = 0.9, aggression = 0.3, expand = 0.50, train_interval = 4.0},
	},
}

# Player-facing names for rival/predator archetype ids (single source for Civ + Space). "hydra" →
# "Kraken" to match its Squidle model; also avoids ugly bare-capitalize underscores ("Sea_jelly").
const ARCHETYPE_LABELS := {
	"hydra": "Kraken", "sea_jelly": "Sea Jelly", "lurker": "Lurker",
	"nematode": "Nematode", "tribe": "Tribe",
}


static func archetype_label(id: String) -> String:
	return str(ARCHETYPE_LABELS.get(id, id.capitalize()))

# --- State ---
var branch: int = Branch.FRESHWATER          # locked at birth
# Continuous genome axes, 0..1, nudged by diet during the microbe stage:
var size := 0.5
var carnivory := 0.5      # 0 = herbivore .. 0.5 = omnivore .. 1 = carnivore
var locomotion := 0.25    # speed / agility — low baseline so cilia visibly grow with diet
var defense := 0.25       # armor / toxin — low baseline so spikes visibly grow with diet
var senses := 0.25
var color := Color(0.72, 0.74, 0.68)   # neutral start; diet pushes it. Follows you onto later sprites.
# Resolved when we "come on land" (entering Civ):
var humanoid_species := ""


func clone() -> Genome:
	var g := Genome.new()
	g.branch = branch
	g.size = size
	g.carnivory = carnivory
	g.locomotion = locomotion
	g.defense = defense
	g.senses = senses
	g.color = color
	g.humanoid_species = humanoid_species
	return g


# Returns a NEW genome with the food's effect applied (immutable update). `effect` keys
# (all optional): size / carnivory / locomotion / defense / senses (float nudges) and
# `tint` (Color blended toward, by `tint_weight`).
func with_food(effect: Dictionary) -> Genome:
	var g := clone()
	g.size = clampf(g.size + float(effect.get("size", 0.0)), 0.0, 1.0)
	g.carnivory = clampf(g.carnivory + float(effect.get("carnivory", 0.0)), 0.0, 1.0)
	g.locomotion = clampf(g.locomotion + float(effect.get("locomotion", 0.0)), 0.0, 1.0)
	g.defense = clampf(g.defense + float(effect.get("defense", 0.0)), 0.0, 1.0)
	g.senses = clampf(g.senses + float(effect.get("senses", 0.0)), 0.0, 1.0)
	if effect.has("tint"):
		g.color = g.color.lerp(effect["tint"], float(effect.get("tint_weight", 0.30)))
	return g


## The full lineage record for this genome's branch — the single source every stage reads from.
func lineage() -> Dictionary:
	return LINEAGES.get(branch, LINEAGES[Branch.FRESHWATER])

## The lineage's bipedal species (resolved at the Creature stage): human / short_alien /
## tall_grey / reptilian.
func resolved_species() -> String:
	return str(lineage().species)

## Human-readable species name for narration / UI.
func species_label() -> String:
	return str(lineage().species_label)

## Starting position on the Civ/AoE strategic map.
func spawn_point() -> String:
	return str(lineage().civ_spawn)

func branch_name() -> String:
	return str(lineage().biome)


func biome_label() -> String:
	return str(lineage().biome_label)

func legacy_creature() -> String:
	return str(lineage().legacy_creature)

## This lineage's Space-stage superweapon (the planet-killer tier) + its flavor line.
func superweapon() -> String:
	return str(lineage().superweapon)

func superweapon_flavor() -> String:
	return str(lineage().superweapon_flavor)


## The genome's dominant Civ axis (keyword CivStage reads: movement/defense/expansion/
## production). Used for the carried-forward bonus.
func dominant_axis() -> String:
	var scores := {
		"movement": locomotion,
		"defense": maxf(defense, size),
		"expansion": senses,
		"production": 1.0 - carnivory,
	}
	var best := "movement"
	var best_v := -1.0
	for k in scores:
		if float(scores[k]) > best_v:
			best_v = float(scores[k])
			best = k
	return best


## A Civ-stage bonus string — so your diet shapes your civilization.
func dominant_bonus() -> String:
	return "%s lineage: +1 %s" % [branch_name(), dominant_axis()]


## Player-facing "what is my diet pushing hardest?" — scored vs the starting baselines so it
## reflects CHANGE, not the static start. Drives the on-screen build readout.
func dominant_trait() -> String:
	var scores := {
		"Carnivorous": carnivory - 0.5,
		"Hardy": size - 0.5,
		"Armored": defense - 0.25,
		"Fast": locomotion - 0.25,
		"Keen-sensed": senses - 0.25,
	}
	var best := ""
	var best_v := 0.04  # floor: below this nothing stands out yet
	for k in scores:
		if float(scores[k]) > best_v:
			best_v = float(scores[k])
			best = k
	return best if best != "" else "Unspecialized"


# --- Serialization (for the Save/Load pillar) ---
func to_dict() -> Dictionary:
	return {
		branch = branch, size = size, carnivory = carnivory,
		locomotion = locomotion, defense = defense, senses = senses,
		color = color.to_html(), humanoid_species = humanoid_species,
	}

static func from_dict(d: Dictionary) -> Genome:
	var g := Genome.new()
	g.branch = int(d.get("branch", Branch.FRESHWATER))
	g.size = float(d.get("size", 0.5))
	g.carnivory = float(d.get("carnivory", 0.5))
	g.locomotion = float(d.get("locomotion", 0.25))
	g.defense = float(d.get("defense", 0.25))
	g.senses = float(d.get("senses", 0.25))
	g.color = Color.from_string(str(d.get("color", "b8bcae")), Color(0.72, 0.74, 0.68))
	g.humanoid_species = str(d.get("humanoid_species", ""))
	return g


# Pick a starting branch deterministically from the run seed. PLACEHOLDER until the
# biome-select UI lands — CONFIRM whether the player picks the pool or it's seeded.
static func branch_from_seed(seed_text: String) -> int:
	return absi(hash(seed_text)) % BRANCH_COUNT


# PLACEHOLDER food->axis table keyed by the existing microbe species. Replaced by the
# full food roster data table. Lets diet move the genome NOW.
const FOOD_EFFECTS := {
	"bacterium":  {locomotion = 0.06, tint = Color(0.45, 0.8, 1.0)},
	"amoeba":     {carnivory = 0.08, defense = 0.04, tint = Color(0.8, 0.5, 0.9)},
	"paramecium": {locomotion = 0.05, senses = 0.05, tint = Color(0.5, 0.9, 0.85)},
	"algae":      {carnivory = -0.06, size = 0.05, tint = Color(0.5, 0.9, 0.45)},
}

static func food_effect_for(species: String) -> Dictionary:
	return FOOD_EFFECTS.get(species, {})
