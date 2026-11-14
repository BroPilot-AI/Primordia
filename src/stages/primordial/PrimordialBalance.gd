class_name PrimordialBalance
## Primordial-soup stage balance tunables. Data-only: named constants + a single `get`
## helper for string-keyed lookup (e.g. designer hot-tweaks via remote config). Mirrors
## the values currently hard-coded in SoupGenerator and FoodRoster; once downstream
## systems read from here, those literals become editable in one place.

# Food motes per sector. Higher = denser soup = faster early growth.
const MOTE_DENSITY: int = 7
# Filler-mote nutrition and progress scale; together these make baseline evolution deliberate.
# An efficient feeder evolves in about 6 minutes of play.
const MOTE_NUTRITION: float = 0.035
const MOTE_PROGRESS_SCALE: float = 0.025
# Roster-food progress scale. Microbes shape the genome without rushing completion.
const FOOD_PROGRESS_SCALE: float = 0.007
# Passive mutation-point grant cadence.
const SURVIVAL_MP_INTERVAL: float = 14.0
# Weight of an EDIBLE entry in SoupGenerator._pick_food() (relative to hazard).
const EDIBLE_WEIGHT: float = 1.0
# Evolution progress lost when a virus is touched (separate from predator setback).
const VIRUS_SETBACK: float = 0.06
# Growth tiers (DESIGN "Become" loop): a Speck meets no threats, hazards drift in at the Cell
# tier, and the predator microbe only hunts the mature cell. Thresholds are evolution progress.
const HAZARD_TIER_AT: float = 0.15
const HUNTER_TIER_AT: float = 0.5
# Nutrition / evolution progress threshold at which a microbe MATURES into the
# next stage (creature).
const MATURE_AT: float = 1.0
# Microbes (FoodRoster entries) spawned per sector — drives SoupGenerator.
const MICROBES_PER_SECTOR_MIN: int = 1
const MICROBES_PER_SECTOR_MAX: int = 2

const _TABLE: Dictionary = {
	"MOTE_DENSITY": MOTE_DENSITY,
	"MOTE_NUTRITION": MOTE_NUTRITION,
	"MOTE_PROGRESS_SCALE": MOTE_PROGRESS_SCALE,
	"FOOD_PROGRESS_SCALE": FOOD_PROGRESS_SCALE,
	"SURVIVAL_MP_INTERVAL": SURVIVAL_MP_INTERVAL,
	"EDIBLE_WEIGHT": EDIBLE_WEIGHT,
	"VIRUS_SETBACK": VIRUS_SETBACK,
	"HAZARD_TIER_AT": HAZARD_TIER_AT,
	"HUNTER_TIER_AT": HUNTER_TIER_AT,
	"MATURE_AT": MATURE_AT,
	"MICROBES_PER_SECTOR_MIN": MICROBES_PER_SECTOR_MIN,
	"MICROBES_PER_SECTOR_MAX": MICROBES_PER_SECTOR_MAX,
}


static func value_for(name: String, fallback: float) -> float:
	return float(_TABLE.get(name, fallback))
