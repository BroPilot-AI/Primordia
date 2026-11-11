## Quips (autoload): the world talks. Rare deadpan one-liners as toasts, themed to the current
## stage (primordial/caveman → medieval → space). ALL ORIGINAL comedic lines written to the genre
## TONE — not movie quotes or reworded catchphrases. Fires on a relaxed timer with a chance
## gate so jokes are an occasional garnish, not a constant stream.
extends Node

const INTERVAL_MIN := 25.0
const INTERVAL_MAX := 45.0
const FIRE_CHANCE := 0.45

# Primordial / Creature / Tribe — caveman & critter humor.
const CAVE := [
	"Grok invent wheel. Grok also invent falling off wheel. Progress!",
	"Tribe discovers 'pointy'. Everything is now slightly more dangerous.",
	"Council ruling: fire good. Touching fire — educational.",
	"We named the big rock 'Big Rock'. Naming is hard.",
	"A wolf gave the band a LOOK. We did not care for its attitude.",
	"Breakthrough: mud, but on purpose this time.",
	"The shaman forecasts weather by mood. Wrong often, confident always.",
	"The boar remembers what you did. The boar is patient.",
	"New invention: the stick. Applications: frankly endless.",
	"Elder says back in his day the predators were bigger. Elder is lying.",
	"We have invented 'lunch'. Historians will weep with joy.",
]
# Civ — medieval slapstick.
const MEDIEVAL := [
	"The treasury is 70% taxes and 30% counting the taxes out loud.",
	"A bard wrote a ballad in your honor. It does not rhyme. He is undeterred.",
	"The peasants are revolting — rebelling, we mean. Also the other thing.",
	"The court jester demands hazard pay. We issued a smaller hat.",
	"Catapult crew says 'trust the process.' The process involves much ducking.",
	"Sir Reginald the Adequate has been knighted. The bar: cleared.",
	"The blacksmith insists every problem yields to 'a bigger hammer.'",
	"Royal decree: moats are in this season. Everyone gets a moat.",
	"The town crier has lost his voice. He is, ironically, devastated and quiet.",
	"Alchemist turned lead into a slightly different lead. We applaud politely.",
]
# Space — bridge-crew space-opera deadpan.
const SPACE := [
	"Long-range scan complete. Findings: more space. A concerning amount of space.",
	"The crew voted to stop naming hostile cubes 'Kevin'. The motion failed.",
	"Morale report: everyone is panicking, but professionally.",
	"We colonized a planet that is 80% minerals and 20% disappointment.",
	"Navigation reminds you the galaxy has no 'back' button.",
	"Someone relabeled the self-destruct as 'snack dispenser'. Investigating.",
	"The fleet doubled in size. So, regrettably, did the paperwork.",
	"Status: gloriously overextended. As is tradition.",
	"The engines are making the noise again. The bad noise. We're ignoring it.",
	"Reminder: 'tactical retreat' and 'running away' are legally distinct.",
	"The alien ambassador is made of goo. We are pretending not to notice.",
	"First contact went well until someone asked about the warranty.",
	"Engineering reports the hyperdrive is now a 'suggestion' engine.",
	"We asked the AI for a battle plan. It suggested diplomacy. The AI is being recalibrated.",
	"The captain's log contains forty pages of complaints about the coffee synthesizer.",
	"Our scanners detected a civilization. They waved. We have questions.",
	"The crew unionized. First demand: fewer explosions near lunch.",
	"Ship's computer has developed sarcasm. We cannot prove it is a malfunction.",
	"Diplomatic envoy reports the nebula is 'judging us.' We concur.",
	"The admiral wants a progress report. Update: still in space. That is the update.",
	"Biology team discovered alien life. It bit the biologist. Science marches on.",
	"We found a derelict ship. Its logs consist entirely of the word 'regret'.",
]
# Space combat + emergence flavor (call quip(COMBAT)/quip(EMERGED) on events).
const COMBAT := [
	"Shields holding. Define 'holding'. Define 'shields', honestly.",
	"Enemy fleet doing the menacing slow-drift maneuver again. Rude.",
	"We're winning! Probably. The math is optimistic and slightly drunk.",
	"That explosion was load-bearing. Whoops.",
]
const EMERGED := [
	"A new empire emerged. They seem cocky. Let's schedule a correction.",
	"Sensors detect fresh ambition in the sector. The AUDACITY.",
]

var _t := 8.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_t = _rng.randf_range(INTERVAL_MIN, INTERVAL_MAX)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = _rng.randf_range(INTERVAL_MIN, INTERVAL_MAX)
		if _rng.randf() < FIRE_CHANCE:
			quip(_pool_for_stage())


# Pick the pool matching the current stage (0–2 caveman, 3 medieval, 4 space).
func _pool_for_stage() -> Array:
	match EvolutionState.current_stage:
		3:
			return MEDIEVAL
		4:
			return SPACE
		_:
			return CAVE


## Emit a random line from a pool as a toast.
func quip(pool: Array) -> void:
	if pool.is_empty():
		return
	Events.notify.emit(pool[_rng.randi_range(0, pool.size() - 1)])
