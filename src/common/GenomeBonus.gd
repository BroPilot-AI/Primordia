## Continuous genome axes → stat multipliers, shared by Tribe / Civ / Space so your evolution
## MECHANICALLY shapes every later stage (not just Space's coarse checks). Carnivory→damage,
## defense+size→hp, locomotion→speed, senses→range/forage. Centralized so balance lives in one place.
class_name GenomeBonus


static func dmg_mult(g) -> float:
	if g == null:
		return 1.0
	return 1.0 + (g.carnivory - 0.5) * 0.6   # full carnivore ≈ +30% dmg, herbivore ≈ -30%


static func hp_mult(g) -> float:
	if g == null:
		return 1.0
	return 1.0 + (g.defense - 0.25) * 0.7 + (g.size - 0.5) * 0.4   # tanky/big lineages


static func speed_mult(g) -> float:
	if g == null:
		return 1.0
	return clampf(1.0 + (g.locomotion - 0.25) * 0.6, 0.7, 1.6)


static func range_mult(g) -> float:
	if g == null:
		return 1.0
	return 1.0 + (g.senses - 0.25) * 0.5   # keen senses → longer reach / vision


static func forage_mult(g) -> float:
	if g == null:
		return 1.0
	return clampf(1.0 + (g.senses - 0.25) * 0.6 + (g.locomotion - 0.25) * 0.3, 0.7, 2.0)


## Hunt zone + kill-yield mult (Tribe). Carnivores punch above; pure grazers still hunt OK.
static func hunt_mult(g) -> float:
	if g == null:
		return 1.0
	return clampf(1.0 + (g.carnivory - 0.5) * 0.8 + (g.senses - 0.25) * 0.25, 0.65, 1.9)


## Multiplier on food LOST to wolves/raids (lower = tougher band). Defense + size.
static func raid_loss_mult(g) -> float:
	if g == null:
		return 1.0
	return clampf(1.0 - (g.defense - 0.25) * 0.45 - (g.size - 0.5) * 0.2, 0.45, 1.25)


## Extra production points on new Civ cities (0–2 from axes).
static func city_prod_bonus(g) -> int:
	if g == null:
		return 0
	var score: float = (g.senses - 0.25) * 0.8 + (g.locomotion - 0.25) * 0.5
	return clampi(int(round(score)), 0, 2)


## Flat bonus to city max_population from size axis.
static func housing_bonus(g) -> int:
	if g == null:
		return 0
	return clampi(int(round((g.size - 0.5) * 4.0)), 0, 3)


## Compact axis readout for HUDs / trait panels / chronicle.
static func axes_readout(g) -> String:
	if g == null:
		return "axes unknown"
	return "sz %.0f%% · car %.0f%% · def %.0f%% · sen %.0f%% · loc %.0f%%" % [
		g.size * 100.0, g.carnivory * 100.0, g.defense * 100.0,
		g.senses * 100.0, g.locomotion * 100.0,
	]


## One-line "this will matter later" for trait pick / stage intros.
static func foreshadow_line(g) -> String:
	if g == null:
		return "Your lineage will shape every later age."
	var bits: PackedStringArray = []
	if g.carnivory >= 0.6:
		bits.append("Tribe hunts + Civ soldiers hit harder")
	elif g.carnivory <= 0.4:
		bits.append("gentler hunters · leaner soldiers")
	if g.defense >= 0.5 or g.size >= 0.65:
		bits.append("tougher cities & units")
	if g.senses >= 0.5 or g.locomotion >= 0.5:
		bits.append("faster forage / workers")
	if bits.is_empty():
		bits.append("balanced axes — no extreme bonuses")
	return "Your body: " + " · ".join(bits)


## Short carry-over brief for Space stage open.
static func space_brief() -> String:
	var es := EvolutionState
	var g = es.genome
	var species: String = g.species_label() if g != null else "Your lineage"
	var victory: String = es.civ_victory if es.civ_victory != "" else "ascent"
	var army: int = es.civ_army
	var cities: int = es.civ_cities
	return "%s — %s · %d cities · army %d" % [species, victory, cities, army]
