class_name CivBalance

# =============================================================================
# Civ — unrest balance sheet (pure data).
#
# These are the ONLY civ tunables read at runtime: CitizenNeedsModel pulls the
# unrest thresholds + growth/decay rates through `value()`.
#
# The live economy (income, build times, costs, train costs, pop caps, ages,
# veterancy) is NOT here — it lives directly in `CivStage3D.gd` as the
# `BUILDINGS` / `UNITS` / `DEFENSES` dicts, `AGE_COST`, `WORKER_YIELD`, etc.
#
# No engine calls, no state, fully static. `value(name, fallback)` returns the
# caller's fallback on a miss; missing keys never raise.
# =============================================================================

# --- Unrest thresholds (0..1 scale) ------------------------------------------
const UNREST_THRESHOLD_CONTENT: float = 0.20
const UNREST_THRESHOLD_RESTLESS: float = 0.45
const UNREST_THRESHOLD_REVOLTING: float = 0.75
const UNREST_THRESHOLD_REVOLT: float = 1.00

# --- Unrest growth / decay rates ---------------------------------------------
const UNREST_GROWTH_PER_UNMET_NEED: float = 0.028
const UNREST_GROWTH_PER_OVERCROWD: float = 0.055
const UNREST_DECAY_PER_TAX_RELIEF: float = 0.08

# --- Flat lookup table (string key -> numeric value) -------------------------
const _TABLE: Dictionary = {
	"unrest_threshold_content": UNREST_THRESHOLD_CONTENT,
	"unrest_threshold_restless": UNREST_THRESHOLD_RESTLESS,
	"unrest_threshold_revolting": UNREST_THRESHOLD_REVOLTING,
	"unrest_threshold_revolt": UNREST_THRESHOLD_REVOLT,
	"unrest_growth_per_unmet_need": UNREST_GROWTH_PER_UNMET_NEED,
	"unrest_growth_per_overcrowd": UNREST_GROWTH_PER_OVERCROWD,
	"unrest_decay_per_tax_relief": UNREST_DECAY_PER_TAX_RELIEF,
}


# Safely look up a tunable by string name. Returns `fallback` on miss or on
# any non-numeric value. Int constants are coerced to float for the caller.
static func value(name: String, fallback: float) -> float:
	if _TABLE.has(name):
		var v: Variant = _TABLE[name]
		if v is float:
			return v
		if v is int:
			return float(v)
	return fallback


static func has(name: String) -> bool:
	return _TABLE.has(name)
