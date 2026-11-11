class_name CreatureBalance

## Player traversal speed (units/sec). DERIVED, not guessed: the arena (CreatureStage3D.ARENA) is
## a radius-130 circle, so a full traversal is the 260u diameter. Target a brisk-but-controllable
## ~5s crossing at full tilt => 260 / 5 = 52.0. (Original was 360 — a ~0.4s crossing, unplayable;
## then 32 for the old radius-80 arena, rescaled here for the larger radius-130 map.)
const player_speed: float = 52.0

## --- Predator chase feel (mirrors the escapable-hunter design in primordial/SoupHunter.gd) ---
## Cruise speed while actively hunting but not lunging. Kept clearly BELOW player_speed (0.6x) so
## a player who just runs away always opens distance — the predator can only close the gap with a
## lunge burst (below).
const predator_cruise_speed: float = player_speed * 0.6
## Per-day cruise escalation (added once per day past day 1) and its hard ceiling — always kept
## under player_speed so no amount of day-scaling can make the predator unescapable at cruise pace.
## (Old scaling let effective speed reach speed*2.2 = 484 vs a 360 player speed: literally faster
## than the player, which is why predators felt "glued" and impossible to outrun.)
const predator_day_speed_step: float = 1.0
const predator_cruise_speed_cap: float = player_speed * 0.85

## Lunge: a short catch-up burst, not a sustained top speed. Capped at 0.9x player_speed so a
## lunge is a real threat but a player who breaks line before it lands still escapes.
const predator_lunge_speed: float = player_speed * 0.9
const predator_lunge_range: float = 12.0     # distance at which a lunge can trigger
const predator_lunge_time: float = 0.5       # burst duration (seconds)
const predator_lunge_cooldown: float = 2.0   # recovery between lunges

## Catch only lands this close — effectively requires landing a lunge (or the player standing
## still/closing distance themselves), since cruise speed alone can't close the gap on a fleeing
## player.
const predator_catch_radius: float = 3.0

## Aggro radius: was 600 — bigger than the entire arena, so predators homed in from literally
## anywhere the instant night fell. A sane fraction of the radius-130 arena (well under it), bumped
## from 34 when the arena grew from radius-80 to radius-130.
const predator_aggro_radius: float = 48.0

## Breakoff: the fix for "perfectly glued, unescapable" predators. If a predator has chased for
## this long without landing a catch, it gives up and stands down for predator_reaggro_cooldown
## before it can hunt again — no more permanent pursuit.
const predator_chase_giveup_time: float = 6.0
const predator_reaggro_cooldown: float = 4.0

## Kept for the value()/fallback lookup below (legacy alias — see predator_cruise_speed for the
## tunable that actually drives chase speed now).
const predator_speed: float = predator_cruise_speed

## Fire deterrent: a lit Campfire3D (built from the Craft menu) is a night SAFE ZONE. Predators
## within this radius of a fire flee outward and cannot enter; a player standing inside is safe.
## Readable as a warm glowing ground ring (see Campfire3D). Tune the bubble size here.
const fire_repel_radius: float = 13.0

const day_length: float = 36.0
const night_length: float = 22.0
const hide_break_time: float = 5.0
# Growth points/sec while digesting (CreatureStage3D.GROW_INTERVAL = 1/this).
const growth_rate: float = 0.08
const maturity_threshold: float = 24.0

static func value(name: String, fallback: float) -> float:
	match name:
		"player_speed":
			return player_speed
		"predator_speed":
			return predator_speed
		"predator_cruise_speed":
			return predator_cruise_speed
		"predator_lunge_speed":
			return predator_lunge_speed
		"predator_aggro_radius":
			return predator_aggro_radius
		"day_length":
			return day_length
		"night_length":
			return night_length
		"hide_break_time":
			return hide_break_time
		"growth_rate":
			return growth_rate
		"maturity_threshold":
			return maturity_threshold
		_:
			return fallback
