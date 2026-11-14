## Pure-logic mapping from `organelle_layout` → 2D visual feature counts.
##
## Lives separately from Germ.gd so it's unit-testable without spinning up a scene
## (per [[godot]] integration-test rules). The Germ node walks this table to spawn /
## update child visual nodes (Polygon2D / Line2D) — see Germ._rebuild_features.
##
## Feature keys (string) → drawn primitive on the Germ:
##   tail   → Line2D wavy whip at the rear (one per flagellum, fanned for many)
##   spike  → triangular Polygon2D on the membrane perimeter (toxin defense)
##   patch  → green Polygon2D blob INSIDE the body (chloroplast)
##   ova    → small orange-red Polygon2D ellipse INSIDE the body (mitochondria)
##   bump   → soft Polygon2D blister on the membrane (cytoplasm structure)
##
## Adding a NEW organelle visual: register one row in ORGANELLE_VISUALS and add the
## matching build_* / animation branch in Germ.gd — no other site changes.
class_name GermAppearance

## ORGANELLE id → {feature: <key>, per_count: <int>}.
## Keys are QUOTED strings — bareword `flagellum:` would compile-error at load
## (see godot 4.6 dictionary-key gotcha in the [[godot]] skill).
const ORGANELLE_VISUALS: Dictionary = {
	"flagellum":     {"feature": "tail",  "per_count": 1},
	"toxin_vacuole": {"feature": "spike", "per_count": 4},
	"chloroplast":   {"feature": "patch", "per_count": 3},
	"mitochondria":  {"feature": "ova",   "per_count": 2},
	"cytoplasm":     {"feature": "bump",  "per_count": 1},
}


## Sum the feature counts for a given organelle layout. Unknown ids are skipped
## defensively (returns an EMPTY {} on an empty layout, NOT {tail: 0, ...}).
static func feature_counts(layout: Array) -> Dictionary:
	var counts: Dictionary = {}
	for entry: Variant in layout:
		if not (entry is String):
			continue
		var id := String(entry)
		if not ORGANELLE_VISUALS.has(id):
			continue
		var feat := String(ORGANELLE_VISUALS[id]["feature"])
		var per := int(ORGANELLE_VISUALS[id]["per_count"])
		counts[feat] = int(counts.get(feat, 0)) + per
	return counts


## Cheap, deterministic key for "has the layout changed since last rebuild?". Order
## matters (flagellum,cytoplasm differs from cytoplasm,flagellum) which is fine
## because OrganelleEditor.add() appends — same insertions produce the same key.
static func layout_signature(layout: Array) -> String:
	var parts: Array[String] = []
	for entry: Variant in layout:
		parts.append(String(entry))
	return ",".join(parts)


## Has at least one of the named feature for this layout — convenience for tests
## and call-sites that just want a boolean ("does this cell sprout a tail?").
static func has_feature(layout: Array, feature: String) -> bool:
	return int(feature_counts(layout).get(feature, 0)) > 0


## The player's body/membrane colour: the genome colour pushed to a vivid, bright version so
## "you" pops against pastel motes and other cells. A near-grey genome (the start) has no
## usable hue, so it gets a hot coral instead; a tinted genome keeps its own hue.
static func player_body_color(genome_color: Color) -> Color:
	var hue := genome_color.h if genome_color.s > 0.15 else 0.97
	return Color.from_hsv(hue, maxf(genome_color.s, 0.80), 1.0)
