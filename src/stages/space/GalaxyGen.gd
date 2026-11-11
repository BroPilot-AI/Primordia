class_name GalaxyGen
## Procedural galaxy generator. Pure data, no nodes — produces an Array[Dictionary]
## of star systems deterministically from a string seed. Used by SpaceStage3D to
## spawn StarSystem3D instances on first load and from save data on reload.
##
## Layout uses a jittered grid (jitter ≤ 0.4 × cell_size) so systems spread evenly
## across a 1000×1000 area without clumping. Greek-letter + catalog-number names
## are stable per seed (same seed → same galaxy).

const AREA_SIZE: float = 1000.0
const AREA_HALF: float = AREA_SIZE * 0.5
const JITTER_FRAC: float = 0.4
const MARGIN: float = 16.0
const MIN_PLANETS: int = 1
const MAX_PLANETS: int = 4

# 24-letter Greek alphabet (lowercase) — alpha through omega.
const GREEK_LETTERS: Array[String] = [
	"alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta",
	"iota", "kappa", "lambda", "mu", "nu", "xi", "omicron", "pi",
	"rho", "sigma", "tau", "upsilon", "phi", "chi", "psi", "omega",
]

# Stellar color palette — loosely Morgan–Keenan, biased toward common types.
# Weighted implicitly by duplicate entries.
const STAR_PALETTE: Array[Color] = [
	Color(0.62, 0.72, 1.00), # O blue
	Color(0.72, 0.82, 1.00), # B blue-white
	Color(0.94, 0.96, 1.00), # A white
	Color(1.00, 0.98, 0.86), # F yellow-white
	Color(1.00, 0.93, 0.62), # G yellow (Sun-like)
	Color(1.00, 0.76, 0.46), # K orange
	Color(1.00, 0.52, 0.42), # M red
	Color(1.00, 0.45, 0.30), # Red giant
	Color(0.85, 0.90, 1.00), # White dwarf
]

static func generate(seed_str: String, count: int) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(seed_str)
	var systems: Array[Dictionary] = []
	if count <= 0:
		return systems
	var cell_size: float = _cell_size(count)
	var cols: int = _grid_cols(count)
	for i: int in range(count):
		var system: Dictionary = _make_system(rng, i, cell_size, cols)
		systems.append(system)
	return systems

static func _cell_size(count: int) -> float:
	if count <= 1:
		return AREA_SIZE
	return AREA_SIZE / float(ceili(sqrt(float(count))))

static func _grid_cols(count: int) -> int:
	if count <= 1:
		return 1
	return int(ceili(sqrt(float(count))))

static func _make_system(
	rng: RandomNumberGenerator,
	idx: int,
	cell_size: float,
	cols: int,
) -> Dictionary:
	var pos: Vector2 = _jittered_pos(rng, idx, cell_size, cols)
	var star_color: Color = STAR_PALETTE[rng.randi() % STAR_PALETTE.size()]
	var name: String = _make_name(rng, idx)
	var planets: Array[Dictionary] = _make_planets(rng)
	return {
		"id": idx,
		"name": name,
		"pos": pos,
		"star_color": star_color,
		"planets": planets,
	}

static func _jittered_pos(
	rng: RandomNumberGenerator,
	idx: int,
	cell_size: float,
	cols: int,
) -> Vector2:
	var col: int = idx % cols
	var row: int = idx / cols
	var base_x: float = float(col) * cell_size - AREA_HALF + cell_size * 0.5
	var base_y: float = float(row) * cell_size - AREA_HALF + cell_size * 0.5
	var jitter_x: float = rng.randf_range(-JITTER_FRAC, JITTER_FRAC) * cell_size
	var jitter_y: float = rng.randf_range(-JITTER_FRAC, JITTER_FRAC) * cell_size
	var x: float = clampf(base_x + jitter_x, -AREA_HALF + MARGIN, AREA_HALF - MARGIN)
	var y: float = clampf(base_y + jitter_y, -AREA_HALF + MARGIN, AREA_HALF - MARGIN)
	return Vector2(x, y)

static func _make_name(rng: RandomNumberGenerator, idx: int) -> String:
	var letter_idx: int = idx % GREEK_LETTERS.size()
	var catalog: int = (idx / GREEK_LETTERS.size()) + rng.randi_range(100, 9999)
	return "%s-%d" % [GREEK_LETTERS[letter_idx], catalog]

static func _make_planets(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var count: int = rng.randi_range(MIN_PLANETS, MAX_PLANETS)
	var planets: Array[Dictionary] = []
	for _i: int in range(count):
		var type_id: String = PlanetTypes.random_type(rng)
		var data: Dictionary = PlanetTypes.get_planet(type_id)
		var habitability: float = float(data.get("habitability", 0.0))
		var resource_bias: String = String(data.get("resource_bias", ""))
		planets.append({
			"type": type_id,
			"habitability": habitability,
			"resource_bias": resource_bias,
		})
	return planets
