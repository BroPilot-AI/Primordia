## Persistent run state that survives across stage transitions. Autoload.
##
## This is the thread connecting germ -> creature -> civilization: the same
## `world_seed` feeds every stage's procedural generation, and `traits` chosen in
## earlier stages carry forward into the Civilization payoff.
extends Node

enum Stage { PRIMORDIAL, CREATURE, TRIBE, CIV, SPACE }

# Tuning knobs for primordial pacing (raise to lengthen the stage). Eating a roster food
# adds nutrition*FOOD_PROGRESS_SCALE to the bar; a filler mote adds amount*MOTE_PROGRESS_SCALE.
const FOOD_PROGRESS_SCALE := PrimordialBalance.FOOD_PROGRESS_SCALE
const MOTE_PROGRESS_SCALE := PrimordialBalance.MOTE_PROGRESS_SCALE
## Progress between defensive-spore buds at baseline defense (a handful per run). Defensive
## diets shorten the interval, so an armored build budgets more spores.
const SPORE_BASE_INTERVAL := 0.16

## Diet → creature archetypes. The most-eaten edible microbe sets your creature.
## `bonus` strings contain the keyword CivStage reads (movement/defense/production/expansion).
const CREATURES := {
	"bacterium": {name = "Swarmer", desc = "a fast flagellate", bonus = "Swarmer body: +1 movement"},
	"amoeba": {name = "Engulfer", desc = "a predatory engulfer", bonus = "Engulfer body: +1 defense"},
	"paramecium": {name = "Drifter", desc = "an agile ciliate", bonus = "Drifter body: +1 expansion"},
	"algae": {name = "Verdant", desc = "a photosynthetic cell", bonus = "Verdant body: +1 production"},
}

## Current stage (int matching Stage enum order, == StageManager index).
var current_stage: int = Stage.PRIMORDIAL
## Evolution meter for the current stage, 0..1.
var progress := 0.0
## Total biomass eaten across the run (lifetime score; not reset between stages).
var biomass := 0.0
## Traits picked in the Creature stage, carried into Civilization.
var traits: Array[String] = []
## Cities founded in the Civilization stage, carried into Space as starting strength.
var civ_cities := 0
## Civ-stage outcome (C6) → feeds Space start strength. victory: "conquest" | "spaceflight" | "".
var civ_age := 0
var civ_army := 0
var civ_victory := ""
## Army carried Civ→Space: {unit_type: count} + the upgrade tiers earned (so the fleet stays veteran).
var civ_army_roster := {}
## Total veterancy (kill-XP) accrued by the surviving player army — carried into the Space fleet.
var civ_army_veterancy := 0
var civ_weapon_tier := 0
var civ_armor_tier := 0
## Homeworld layout snapshot for the persistent "return home" view in Space.
## { cities: [Vector2i...], structures: [{cell: Vector2i, kind: String}...] }
var civ_planet_snapshot := {}
## Survival payload carried from the Creature stage into Civ (Phase 6): gathered materials become
## a founding stockpile; mastering fire/tools gives an industry head start.
var creature_inventory := {}
var discovered_fire := false
var discovered_tools := false
## Band size carried from the Tribe stage into Civ (bigger band → richer founding).
var tribe_population := 0
## Tally of edible microbes eaten this run, keyed by species (drives the creature).
var diet := {}
## Creature determined by diet at the end of the primordial stage.
var creature_species := ""
var creature_name := ""
## The single seed that makes the whole run deterministic, set once at launch.
var world_seed := "primordia"
## Procedural planet name for this run (narration/UI), derived from the seed.
var planet_name := ""
## The heritable genome — the spine every later stage reads (appearance + bonuses).
## Written in the primordial stage (branch locked at birth, axes nudged by diet).
var genome: Genome
## Convergent humanoid species + Civ/AoE map spawn, resolved when we "come on land".
var species_name := ""
var civ_spawn := ""

var _completed := false
## Watermark for the next spore bud (only ever increases — so losing then regaining
## progress can't farm spores).
var _next_spore_at := SPORE_BASE_INTERVAL
## Run-clock state — set by Main when a new run starts; frozen when the win/loss card
## appears so the elapsed value stops advancing the moment the player dies/wins.
## `_run_stopped_at_msec == -1` means "not stopped yet" (the clock is still live).
var _run_started_at_msec: int = 0
var _run_stopped_at_msec: int = -1


func _ready() -> void:
	randomize()
	world_seed = "primordia-%d" % randi()
	genome = Genome.new()
	# Branch is seeded by default; the title screen's biome pick can override it.
	genome.branch = Genome.branch_from_seed(world_seed)
	planet_name = PlanetName.generate(world_seed)
	Events.mote_eaten.connect(_on_mote_eaten)
	Events.player_harmed.connect(_on_player_harmed)
	Events.microbe_eaten.connect(_on_microbe_eaten)
	Events.food_consumed.connect(_on_food_consumed)


## Override the seeded starting biome — called by the title screen's biome pick. Locks
## the lineage branch before the run begins.
func set_starting_biome(b: int) -> void:
	if genome != null:
		genome.branch = b


## Wipe ALL run-scoped state and re-roll the run identity (seed, genome, planet name).
## This autoload persists across `reload_current_scene()`, so without this the previous
## run's genome/traits/carry-overs leak into the next run (duplicate trait entries, same
## planet every run, Space inheriting a dead run's army). Called on the return-to-title
## paths (Play Again / Main Menu / Quit to Title) so the next New Run starts clean;
## the title screen then displays the fresh planet name.
func new_run() -> void:
	current_stage = Stage.PRIMORDIAL
	progress = 0.0
	biomass = 0.0
	traits = []
	civ_cities = 0
	civ_age = 0
	civ_army = 0
	civ_victory = ""
	civ_army_roster = {}
	civ_army_veterancy = 0
	civ_weapon_tier = 0
	civ_armor_tier = 0
	civ_planet_snapshot = {}
	creature_inventory = {}
	discovered_fire = false
	discovered_tools = false
	tribe_population = 0
	diet = {}
	creature_species = ""
	creature_name = ""
	species_name = ""
	civ_spawn = ""
	_completed = false
	_next_spore_at = SPORE_BASE_INTERVAL
	world_seed = "primordia-%d" % randi()
	genome = Genome.new()
	genome.branch = Genome.branch_from_seed(world_seed)
	planet_name = PlanetName.generate(world_seed)


## Called by StageManager when a new stage loads. Resets per-stage progress but
## keeps cross-stage state (seed, traits, biomass).
func reset_for_stage(stage: int) -> void:
	current_stage = stage
	progress = 0.0
	_completed = false
	_next_spore_at = SPORE_BASE_INTERVAL
	# "Come on land": resolve the convergent humanoid species + strategic-map spawn
	# from the locked lineage branch when entering the Civ stage.
	if stage == Stage.CIV and civ_spawn == "":
		# Species is already resolved at the Creature stage; here just fix the strategic-map spawn.
		if species_name == "":
			species_name = genome.resolved_species()
			genome.humanoid_species = species_name
		civ_spawn = genome.spawn_point()
	Events.evolution_progress_changed.emit(progress)


func _on_mote_eaten(amount: float) -> void:
	# Filler food: small progress, no genome change.
	biomass += amount
	_advance_progress(amount * MOTE_PROGRESS_SCALE)
	StageObjectives.complete("soup_eat", "First meal — keep feeding to evolve")


## Eating a roster food drives the genome (axes + color) AND progress. Hazards set you back.
func _on_food_consumed(food: Dictionary) -> void:
	var is_hazard := String(food.get("type", "EDIBLE")) == "HAZARD"
	var nut := float(food.get("nutrition", 0.0))
	if is_hazard:
		_advance_progress(-absf(nut) * FOOD_PROGRESS_SCALE)
		return

	var effect: Dictionary = (food.get("nudges", {}) as Dictionary).duplicate()
	if food.has("tint"):
		effect["tint"] = _vivid(food["tint"])
		effect["tint_weight"] = 0.22
	genome = genome.with_food(effect)

	var fid := String(food.get("id", ""))
	diet[fid] = int(diet.get(fid, 0)) + 1

	biomass += nut
	_advance_progress(nut * FOOD_PROGRESS_SCALE)


## Motes carry pigment too — eating a color leans the cell toward it (cumulative, so a
## diet of mostly one color makes you that color). Primordial only.
func absorb_pigment(tint: Color, weight := 0.05) -> void:
	if current_stage != Stage.PRIMORDIAL or genome == null:
		return
	genome = genome.with_food({tint = tint, tint_weight = weight})


## Punch up a color's saturation so diet pigments read vividly on the cell.
func _vivid(c: Color) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * 1.5 + 0.15, 0.0, 1.0), clampf(c.v * 1.05 + 0.1, 0.0, 1.0), c.a)


## Move the primordial evolution bar and fire completion when it fills.
func _advance_progress(delta: float) -> void:
	if current_stage != Stage.PRIMORDIAL:
		return
	progress = clampf(progress + delta, 0.0, 1.0)
	Events.evolution_progress_changed.emit(progress)
	# Bud a defensive spore each time we cross a milestone. The watermark only rises, so
	# you can't farm spores by losing and regaining progress. Armored diets bud faster.
	while progress >= _next_spore_at and _next_spore_at < 1.0:
		var strength := genome.defense if genome != null else 0.25
		Events.spore_budded.emit(strength)
		_next_spore_at += lerpf(0.18, 0.10, clampf(strength, 0.0, 1.0))
	if progress >= 0.35:
		StageObjectives.complete("soup_mid", "Half-grown — specialize with organelles")
	if progress >= 1.0 and not _completed:
		_completed = true
		StageObjectives.complete("soup_mature", "Evolved from the soup")
		determine_creature()
		Events.stage_complete.emit(current_stage)


func _on_microbe_eaten(species: String) -> void:
	if current_stage != Stage.PRIMORDIAL:
		return
	diet[species] = int(diet.get(species, 0)) + 1
	# Diet nudges the genome axes/color (branch stays locked). Immutable update.
	genome = genome.with_food(Genome.food_effect_for(species))


## One-line HUD identity (species · era · optional trait). Hover `lineage_tooltip` for axes.
func lineage_readout() -> String:
	var sp: String = genome.species_label() if genome != null else "Unknown"
	var eras: Array[String] = ["Primordial", "Creature", "Tribe", "Civ", "Space"]
	var era: String = eras[clampi(current_stage, 0, eras.size() - 1)]
	if traits.is_empty():
		return "%s · %s" % [sp, era]
	return "%s · %s · %s" % [sp, era, ", ".join(traits)]


func lineage_tooltip() -> String:
	var tr: String = ", ".join(traits) if not traits.is_empty() else "none"
	return "Traits: %s\n%s" % [tr, GenomeBonus.axes_readout(genome)]


## Pick the creature from the most-eaten edible microbe; append its Civ bonus.
func determine_creature() -> void:
	# Branch (set by your starting biome) locks your LINEAGE: both the land biome (branch) and
	# the bipedal SPECIES you rise into at the Creature stage — human / short_alien / tall_grey /
	# reptilian. Diet shaped the genome axes along the way. Append a Civ bonus on the dominant axis.
	creature_species = genome.branch_name()
	creature_name = genome.resolved_species()
	species_name = genome.resolved_species()
	genome.humanoid_species = species_name
	traits.append(genome.dominant_bonus())


func _on_player_harmed(amount: float) -> void:
	# Touching a virus sets back the evolution bar (non-lethal). Primordial only.
	if current_stage != Stage.PRIMORDIAL:
		return
	progress = clampf(progress - amount, 0.0, 1.0)
	Events.evolution_progress_changed.emit(progress)


# --- Run clock (whole-run elapsed time, displayed on the win/lose recap) -------------
#
# `start_run_clock` is called by Main when a fresh run begins. `stop_run_clock` is called
# from the win/lose handlers so the elapsed value freezes the moment the end-of-game
# card appears (read on the recap line below the headline). The autoload persists
# across scene reloads, so resetting the clock on the next "Play Again" / "Continue"
# path is the caller's job.

func start_run_clock() -> void:
	_run_started_at_msec = Time.get_ticks_msec()
	_run_stopped_at_msec = -1


func stop_run_clock() -> void:
	# Idempotent: only the first stop captures the freeze time. Repeated calls
	# (e.g. a card closing and re-opening) keep the ORIGINAL stop time so the
	# displayed elapsed never advances.
	if _run_stopped_at_msec < 0 and _run_started_at_msec > 0:
		_run_stopped_at_msec = Time.get_ticks_msec()


## Seconds elapsed since the clock started (frozen at the stop time if `stop_run_clock`
## was called). Returns 0.0 if the clock was never started. Pure: takes the autoload's
## state in only via the two timestamp vars — uses no external mutable state.
func run_elapsed_seconds() -> float:
	if _run_started_at_msec <= 0:
		return 0.0
	var end: int = _run_stopped_at_msec if _run_stopped_at_msec > 0 else Time.get_ticks_msec()
	return float(end - _run_started_at_msec) / 1000.0


## Pure helper: format an elapsed-seconds value as "MM:SS" (under an hour) or "HH:MM:SS"
## (one hour or more). Always two-digit MM and SS, three-digit-safe HH. Negative inputs
## are clamped to 0 — the run clock is monotonic so a negative value would only come from
## external mis-use. Static + testable: no instance state read.
static func format_elapsed(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var secs := total % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]
