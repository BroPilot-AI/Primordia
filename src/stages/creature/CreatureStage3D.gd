class_name CreatureStage3D extends Stage3D

const NAT := "res://assets/models/kenney-nature/%s.glb"
const CompactHUD := preload("res://src/ui/CompactHUDPanel.gd")
const StageChromeScript := preload("res://src/ui/StageChrome.gd")

# --- Stylized HEX GROUND (ports Civ's proven pointy-top hex + MultiMesh batching to this stage's
# CIRCULAR arena). Terrain/nature tiles only — NO buildings. Tune the tile mix in _hex_tile_for. ---
const HEX_ROOT := "res://assets/models/kenney-hexagon/"
const HEX_GRASS := HEX_ROOT + "grass.glb"
const HEX_FOREST := HEX_ROOT + "grass-forest.glb"
const HEX_HILL := HEX_ROOT + "grass-hill.glb"
const HEX_DIRT := HEX_ROOT + "dirt.glb"
const HEX_SAND := HEX_ROOT + "sand.glb"
const HEX_WATER := HEX_ROOT + "water.glb"
const HEX_WATER_ROCKS := HEX_ROOT + "water-rocks.glb"
const HEX_STONE_HILL := HEX_ROOT + "stone-hill.glb"
const HEX_MOUNTAIN := HEX_ROOT + "stone-mountain.glb"
# Pointy-top hex geometry — identical derivation to CivStage3D (raw mesh x=1.0 flat-to-flat,
# z=1.1547 point-to-point; fit the larger dim to HEX_POINT).
const HEX_TILE := 6.0
const HEX_POINT := HEX_TILE * 1.04
const HEX_FLAT := HEX_POINT / 1.1547
const HEX_COL_STEP := HEX_FLAT
const HEX_ROW_STEP := HEX_POINT * 0.75

const BRANCH_MATERIALS := {
	"freshwater": ["fiber", "wood", "stone"],
	"saltwater":  ["fiber", "wood", "shell"],
	"deep_ocean": ["fiber", "wood", "crystal"],
	"inland":     ["fiber", "wood", "clay"],
}

const RECIPES := {
	"Campfire": {"wood": 3},
	"Shelter": {"fiber": 4, "wood": 2},
}

const HARD_MATS: Array[String] = ["stone", "shell", "crystal", "clay"]
const SOFT_MATS: Array[String] = ["fiber", "wood"]
const TOOLS_HARD_NEEDED := 3
const KINDLING_SOFT_NEEDED := 4

const MATURE_AT := int(CreatureBalance.maturity_threshold)
const DAY_LENGTH := CreatureBalance.day_length
const NIGHT_LENGTH := CreatureBalance.night_length
const CAUGHT_SETBACK := 3
# One mauling per pounce — a pack can't stack setbacks in the same instant.
const CAUGHT_GRACE := 1.5
# 12.5 s per growth point -> ~10 min stage.
const GROW_INTERVAL := 1.0 / CreatureBalance.growth_rate
const DUSK_WARNING := 6.0   # seconds of warning before night falls
const HUNGER_DRAIN := 0.010
const WARMTH_NIGHT_DRAIN := 0.025
const WARMTH_DAY_RECOVER := 0.033
const METER_LOW := 0.25
const EAT_REFILL := 0.22
const DAYS_PER_SEASON := 6
const SEASON_NAMES := ["spring", "summer", "autumn", "winter"]
# Easter-egg UFO flyover: rare sighting, not ambient traffic.
const UFO_FIRST_DELAY := 120.0
const UFO_COOLDOWN_MIN := 300.0
const UFO_COOLDOWN_MAX := 600.0
const UFO_LIFETIME := 30.0

# Arena radius. Grown 80 -> 130 (diameter 260) so the map is comparable to Civ/Space, not cramped.
# Counts below are scaled up ~2.6x (the area ratio) to keep the same visual/threat density.
const ARENA := 130.0
const MOTE_COUNT := 60
const PREDATOR_COUNT := 6   # not fully 2.6x (would be brutal) — a moderate bump for the bigger field
const SHELTER_COUNT := 14   # a shelter should usually be reachable when hunted, across the bigger map
# Mutation hotspot zones (research pick #6, Vilmonic) — radiation/toxin pools that drift your
# genome axes while you stand in them. Wires the orphaned MutationModel into the live genome.
const MUTATION_ZONE_COUNT := 4
const MUTATION_ZONE_RADIUS := 7.0
const MUTATION_INTERVAL := 1.6
const MATERIAL_COUNT := 32
const TREE_COUNT := 140
## Tactical ortho size — 50+ is the strategic band and shrinks the avatar to a speck.
const CAMERA_SIZE := 26.0

const TRAITS := [
	{
		name = "Cilia — +1 movement in Civ stage",
		hint = "Faster soldiers & workers across Civ and Space fleets.",
		icon = "res://assets/sprites/trait_cilia.png",
	},
	{
		name = "Carapace — +1 defense in Civ stage",
		hint = "Tougher cities and units — siege & raids hurt less.",
		icon = "res://assets/sprites/trait_carapace.png",
	},
	{
		name = "Symbiosis — +1 production per city",
		hint = "Every city works harder — the economy snowballs earlier.",
		icon = "res://assets/sprites/trait_symbiosis.png",
	},
]
# Tabbed build panel — Craft. _update_build_buttons owns the button state.
const BUILD_PANEL_SIZE := Vector2(360, 0)  # matches StageChrome.PANEL_WIDTH

var is_night: bool = false
var _current_season: String = "spring"
var _adaptation_fit: float = 1.0
var growth: int = 0
var hunger: float = 1.0
var warmth: float = 1.0
var inventory: Dictionary = {}
var _day: int = 1
var _t: float = 0.0
var _digest_t: float = 0.0
var _caught_grace_t: float = 0.0
var _dusk_warned: bool = false
var _fire: bool = false
var _matured: bool = false
var _tools: bool = false
var _knapped: bool = false
var _kindling: bool = false
var _player: Node3D = null
var _hotspots: Array[Vector2] = []
var _mutation_cd: float = 0.0
var _ufo: Node3D = null
var _ufo_goal: Vector3 = Vector3.ZERO
var _ufo_t: float = UFO_FIRST_DELAY
## Brief free-look after F/T/Home so follow-cam does not yank the view back.
var _cam_free_t: float = 0.0

var _status: Label = null
var _day_label: Label = null
var _growth_bar: ProgressBar = null
var _hunger_bar: ProgressBar = null
var _warmth_bar: ProgressBar = null
var _material_label: Label = null
var _discovery_label: Label = null
var _hidden_label: Label = null
var _fire_safe_label: Label = null
var _shown_hide_hint: bool = false
var _build_recipe_names: Array[String] = []
var _build_buttons: Array[Button] = []
var _knap_btn: Button = null

var _mote_objs: Array[Mote3D] = []
var _material_objs: Array[MaterialNode3D] = []
var _tree_nodes: Array[Node3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _world_env: WorldEnvironment = null
var _sun: DirectionalLight3D = null
var _mesh_parts_cache: Dictionary = {}   # hex GLB -> [{mesh, xform}] (ported from CivStage3D)
var _forest_spots: Array[Vector3] = []    # world positions of forest/hill tiles — flora clusters here
var _ground_tone := GroundTone.new(hash(EvolutionState.world_seed + "_ground_tone"))
var _fireflies: CPUParticles3D = null     # night ambient life (toggled by is_night)
var _night_vignette: ColorRect = null     # screen-edge darken at night (fire matters)


func _ready() -> void:
	add_to_group("creature_stage")
	_rng.seed = hash(EvolutionState.world_seed + "_creature3d")
	_build_environment("outdoor")
	_build_sun()
	for c in get_children():
		if c is WorldEnvironment:
			_world_env = c
			break
	_build_ground()
	_spawn_player()
	_build_camera(_player.position, CAMERA_SIZE)
	_spawn_trees()
	_spawn_initial_entities()
	_build_hud()
	_update_season()
	_update_discovery()
	for c in get_children():
		if c is DirectionalLight3D:
			_sun = c
			break
	_build_fireflies()
	_build_night_vignette()
	_ufo_t = UFO_FIRST_DELAY


# Drifting warm fireflies for night ambient life (the soup stage's "living backdrop" quality bar,
# in 3D). Emits only at night — toggled in _process. Skipped headless (no renderer).
func _build_fireflies() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_fireflies = CPUParticles3D.new()
	_fireflies.amount = 120
	_fireflies.lifetime = 7.0
	_fireflies.emitting = false
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fireflies.emission_box_extents = Vector3(ARENA, 5.0, ARENA)
	_fireflies.position = Vector3(0, 4.0, 0)
	_fireflies.gravity = Vector3.ZERO
	_fireflies.direction = Vector3(0, 1, 0)
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 0.8
	_fireflies.initial_velocity_max = 2.4
	_fireflies.scale_amount_min = 0.18
	_fireflies.scale_amount_max = 0.42
	_fireflies.color = Color(1.0, 0.92, 0.5)
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var pmat := StandardMaterial3D.new()
	pmat.emission_enabled = true
	pmat.emission = Color(1.0, 0.9, 0.45)
	pmat.emission_energy_multiplier = 3.0
	pmat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.albedo_color = Color(1.0, 0.9, 0.45, 0.85)
	mesh.material = pmat
	_fireflies.mesh = mesh
	add_child(_fireflies)


func _build_ground() -> void:
	# Base earth slab: fills the whole footprint under the hex field so nothing floats, and gives a
	# thick side so the arena edge doesn't read as a paper sheet in the void. Top just below y=0 so
	# the hex tiles (tops ~0) sit on it and their bodies hide the seams.
	var ground := MeshInstance3D.new()
	ground.mesh = BoxMesh.new()
	ground.mesh.size = Vector3(ARENA * 2.2, 4.0, ARENA * 2.2)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.20, 0.34, 0.18)   # dark earth/grass — reads as ground in the seams
	gmat.roughness = 1.0
	ground.material_override = gmat
	ground.position.y = -2.10
	add_child(ground)
	# Stylized hex-tile field over the circular arena (Civ's kit + MultiMesh batching). Headless
	# runs skip GLB loading (the flat slab above is enough there).
	if DisplayServer.get_name() != "headless":
		_build_hex_field()


# Lay pointy-top hex tiles across the radius-ARENA circle, grouped by GLB and MultiMesh-batched
# (one MultiMeshInstance3D per distinct tile) — the same technique CivStage3D uses for its board.
# Mostly grass, with forest/hill cover clusters (noise), dirt patches, and a water/stone rim that
# frames the arena edge. Also records forest/hill tile positions so flora clusters onto them.
func _build_hex_field() -> void:
	var forest_noise := FastNoiseLite.new()
	forest_noise.seed = int(_rng.randi())
	forest_noise.frequency = 0.020
	var hill_noise := FastNoiseLite.new()
	hill_noise.seed = int(_rng.randi())
	hill_noise.frequency = 0.028
	var half_cols: int = int(ceil(ARENA / HEX_COL_STEP)) + 1
	var half_rows: int = int(ceil(ARENA / HEX_ROW_STEP)) + 1
	var by_path: Dictionary = {}
	_forest_spots.clear()
	for cy in range(-half_rows, half_rows + 1):
		for cx in range(-half_cols, half_cols + 1):
			var pos := _hex_pos(cx, cy)
			var dist := Vector2(pos.x, pos.z).length()
			if dist > ARENA:
				continue
			var path := _hex_tile_for(dist, pos, forest_noise, hill_noise)
			var raise := -0.35 if (path == HEX_WATER or path == HEX_WATER_ROCKS) else 0.0
			var rot := float(_rng.randi_range(0, 5) * 60)
			if not by_path.has(path):
				by_path[path] = []
			by_path[path].append({pos = pos, raise = raise, rot = rot})
			if path == HEX_FOREST or path == HEX_HILL:
				_forest_spots.append(pos)
	for path in by_path:
		_build_hex_multimesh(path, by_path[path])


func _hex_pos(cx: int, cy: int) -> Vector3:
	var row_offset := HEX_COL_STEP * 0.5 if (cy & 1) == 1 else 0.0
	return Vector3(cx * HEX_COL_STEP + row_offset, 0.0, cy * HEX_ROW_STEP)


# Tile mix: a water/stone rim frames the edge; the interior is mostly grass with noise-driven
# forest/hill cover clusters and occasional dirt. Tune the thresholds here for feel.
func _hex_tile_for(dist: float, pos: Vector3, forest_noise: FastNoiseLite, hill_noise: FastNoiseLite) -> String:
	var edge := dist / ARENA
	if edge > 0.94:
		return HEX_WATER_ROCKS if _rng.randf() < 0.22 else HEX_WATER
	if edge > 0.88:
		return HEX_MOUNTAIN if _rng.randf() < 0.35 else HEX_STONE_HILL
	if edge > 0.83:
		return HEX_SAND if _rng.randf() < 0.5 else HEX_DIRT
	var fn := forest_noise.get_noise_2d(pos.x, pos.z)
	var hn := hill_noise.get_noise_2d(pos.x, pos.z)
	if fn > 0.28:
		return HEX_FOREST
	if hn > 0.34:
		return HEX_HILL
	if fn < -0.46:
		return HEX_DIRT
	return HEX_GRASS


# Batch every cell sharing a tile GLB into one MultiMeshInstance3D (per submesh). Ported from
# CivStage3D._build_tile_multimesh: uniform fit-scale + Y compression + flat per-instance tint.
func _build_hex_multimesh(path: String, records: Array) -> void:
	var parts := _load_hex_parts(path)
	if parts.is_empty():
		return
	var box := _merged_hex_box(parts)
	var foot: float = maxf(box.size.x, box.size.z)
	var fit: float = (HEX_POINT / foot) if foot > 0.0 else 1.0
	var height_mult := _hex_height_mult(path)
	var color := _hex_tile_tint(path)
	var board := AABB(Vector3(-ARENA - HEX_TILE, -12.0, -ARENA - HEX_TILE), Vector3(ARENA * 2.0 + HEX_TILE * 2.0, 30.0, ARENA * 2.0 + HEX_TILE * 2.0))
	for part_idx in parts.size():
		var part: Dictionary = parts[part_idx]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mesh_with_albedo_tint(part.mesh, color, true)
		mm.instance_count = records.size()
		for i in records.size():
			var rec: Dictionary = records[i]
			var pos: Vector3 = rec.pos + Vector3(0, rec.raise, 0)
			var root_basis := Basis(Vector3.UP, deg_to_rad(rec.rot)).scaled(Vector3(fit, fit * height_mult, fit))
			mm.set_instance_transform(i, Transform3D(root_basis, pos) * part.xform)
			mm.set_instance_color(i, _ground_tone.at(rec.pos))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.custom_aabb = board
		mmi.name = "HexMM_%s_%d" % [path.get_file().get_basename(), part_idx]
		# Do not override the imported surface material. The kit's colormap carries
		# most of its visual detail; replacing it with a blank vertex-color material
		# makes the map look like a pale, flat board.
		add_child(mmi)


func _load_hex_parts(path: String) -> Array:
	if _mesh_parts_cache.has(path):
		return _mesh_parts_cache[path]
	var parts: Array = []
	var packed := load(path) as PackedScene
	if packed != null:
		var node: Node3D = packed.instantiate()
		for n in node.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh != null:
				parts.append({mesh = mi.mesh, xform = mi.transform})
		# Temporary import root never enters the SceneTree, so free it immediately.
		node.free()
	_mesh_parts_cache[path] = parts
	return parts


func _merged_hex_box(parts: Array) -> AABB:
	var box := AABB()
	var first := true
	for part in parts:
		var b: AABB = part.xform * (part.mesh as Mesh).get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


func _hex_height_mult(path: String) -> float:
	if path == HEX_MOUNTAIN:
		return 0.55
	if path == HEX_STONE_HILL or path == HEX_HILL:
		return 0.34
	return 0.26


func _hex_tile_tint(path: String) -> Color:
	match path:
		HEX_WATER, HEX_WATER_ROCKS:
			return Color(0.11, 0.42, 0.62)
		HEX_DIRT:
			return Color(0.53, 0.62, 0.55)
		HEX_SAND:
			return Color(0.60, 0.53, 0.35)
		HEX_MOUNTAIN, HEX_STONE_HILL:
			return Color(0.40, 0.43, 0.45)
		# The kit paints grass teal (#4ac6a7); red above 1 pulls it round to leaf green.
		HEX_FOREST:
			return Color(0.80, 0.48, 0.26)
		HEX_HILL:
			return Color(0.90, 0.60, 0.30)
		_:
			return Color(1.08, 0.58, 0.30)


func _spawn_player() -> void:
	_player = PlayerCreature3D.new()
	add_child(_player)
	_player.position = Vector3(0, PlayerCreature3D.GROUND_Y, 0)   # feet on the ground, not sunk in it


# Flora with a DENSITY GRADIENT: most trees/bushes cluster onto the forest/hill hex tiles (dense
# cover), the rest scatter thinly for open clearings between them — coherent with the ground read.
func _spawn_trees() -> void:
	var clustered := int(TREE_COUNT * 0.7)
	var scattered := TREE_COUNT - clustered
	for _i in clustered:
		var pos := _near_forest_spot(7.0)
		if pos.length() < 8.0:
			continue
		var node := WorldProps.spawn_tree(self, pos, _rng)
		if node:
			_tree_nodes.append(node)
	for _i in scattered:
		var pos := _rand_arena()
		if pos.length() < 8.0:
			continue
		var node := WorldProps.spawn_tree(self, pos, _rng)
		if node:
			_tree_nodes.append(node)
	for _r in 40:
		var rpos := _rand_arena()
		if rpos.length() > 6.0:
			WorldProps.spawn_rock(self, rpos, _rng)
	for _b in 44:
		# Bushes bias toward cover clusters too, for a layered understory under the trees.
		var bpos := _near_forest_spot(5.0) if _rng.randf() < 0.6 else _rand_arena()
		if bpos.length() > 6.0:
			WorldProps.spawn_bush(self, bpos, _rng)
	for _g in 160:
		var gpos := _rand_arena()
		if gpos.length() > 6.0:
			WorldProps.spawn_groundcover(self, gpos, _rng)


# A jittered position near a random forest/hill tile (falls back to open arena if none recorded,
# e.g. headless). Drives the flora density gradient — clusters where the ground reads as cover.
func _near_forest_spot(jitter: float) -> Vector3:
	if _forest_spots.is_empty():
		return _rand_arena()
	var c: Vector3 = _forest_spots[_rng.randi_range(0, _forest_spots.size() - 1)]
	var off := Vector3(_rng.randf_range(-jitter, jitter), 0.0, _rng.randf_range(-jitter, jitter))
	var p := c + off
	var flat := Vector2(p.x, p.z)
	if flat.length() > ARENA - 2.0:
		flat = flat.normalized() * (ARENA - 2.0)
		p = Vector3(flat.x, 0.0, flat.y)
	return p


func _spawn_initial_entities() -> void:
	var mats: Array[String] = []
	mats.assign(BRANCH_MATERIALS.get(EvolutionState.genome.branch_name() if EvolutionState.genome != null else "freshwater", BRANCH_MATERIALS["freshwater"]))
	for _i in MOTE_COUNT:
		_spawn_mote()
	for _i in MATERIAL_COUNT:
		_spawn_material(mats)
	for _i in PREDATOR_COUNT:
		_spawn_predator()
	for _i in SHELTER_COUNT:
		_spawn_shelter()
	for _i in MUTATION_ZONE_COUNT:
		_spawn_mutation_zone()


# Uniform random point INSIDE the circular arena (polar with sqrt for even area distribution) so
# entities land on the hex field, not out in the void corners of a bounding square.
func _rand_arena() -> Vector3:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * (ARENA - 6.0)
	return Vector3(cos(a) * r, 0.0, sin(a) * r)


func _spawn_mote() -> void:
	var m := Mote3D.new()
	m.nutrition = _rng.randf_range(0.3, 1.0)
	m.position = _rand_arena()
	add_child(m)
	_mote_objs.append(m)


func _spawn_material(mats: Array[String]) -> void:
	var m: MaterialNode3D = MaterialNode3D.new()
	m.material_id = mats[_rng.randi_range(0, mats.size() - 1)]
	m.position = _rand_arena()
	m.collected.connect(_on_material_collected)
	add_child(m)
	_material_objs.append(m)


func _spawn_predator() -> void:
	var p := Predator3D.new()
	p.position = _rand_arena()
	add_child(p)


## Night difficulty scales with day count — short soft first night, later longer hunts.
func _on_night_falls() -> void:
	if not _shown_hide_hint:
		_shown_hide_hint = true
		Events.notify.emit("Night falls — predators hunt. Hide in the glowing green thickets!")
		StageObjectives.complete("cre_first_night", "First night — find cover or fire")
	elif _day >= 4:
		Events.notify.emit("A long night (day %d) — hunters grow bolder." % _day)
	else:
		Events.notify.emit("Night falls again…")


func night_length_for_day() -> float:
	# Day 1 soft; stretches toward a ceiling so late nights demand campfire discipline.
	return clampf(NIGHT_LENGTH * (0.85 + 0.08 * float(_day - 1)), NIGHT_LENGTH * 0.85, NIGHT_LENGTH * 1.45)


func _spawn_shelter() -> void:
	var s := HidingSpot3D.new()
	s.position = _rand_arena()
	add_child(s)


# A visible mutagenic pool. Its ground position feeds MutationModel.in_hotspot; standing in it
# drifts the player's genome axes (see _tick_mutation).
func _spawn_mutation_zone() -> void:
	var pos := _rand_arena()
	_hotspots.append(Vector2(pos.x, pos.z))
	var zone := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = MUTATION_ZONE_RADIUS
	cyl.bottom_radius = MUTATION_ZONE_RADIUS
	cyl.height = 0.4
	zone.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.22, 0.88, 0.32)
	mat.emission_enabled = true
	mat.emission = Color(0.70, 0.28, 1.0)
	mat.emission_energy_multiplier = 1.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone.material_override = mat
	zone.position = Vector3(pos.x, 0.06, pos.z)
	add_child(zone)


# Drift the genome while the player stands in a mutagenic zone (throttled by MUTATION_INTERVAL).
func _tick_mutation(delta: float) -> void:
	_mutation_cd = maxf(0.0, _mutation_cd - delta)
	if _fire or _player == null or EvolutionState.genome == null or _hotspots.is_empty():
		return
	var here := Vector2(_player.global_position.x, _player.global_position.z)
	var intensity := MutationModel.in_hotspot(here, _hotspots, MUTATION_ZONE_RADIUS)
	if intensity <= 0.0 or _mutation_cd > 0.0:
		return
	_mutation_cd = MUTATION_INTERVAL
	var g = EvolutionState.genome
	var gd := {"size": g.size, "carnivory": g.carnivory, "defense": g.defense, "senses": g.senses, "locomotion": g.locomotion}
	# BASE_MUT_RATE (0.01) is tiny per tick; scale by intensity so a deep zone drifts noticeably.
	var md := MutationModel.mutate(gd, intensity * 6.0, _rng)
	g.size = clampf(float(md["size"]), 0.0, 1.0)
	g.carnivory = clampf(float(md["carnivory"]), 0.0, 1.0)
	g.defense = clampf(float(md["defense"]), 0.0, 1.0)
	g.senses = clampf(float(md["senses"]), 0.0, 1.0)
	g.locomotion = clampf(float(md["locomotion"]), 0.0, 1.0)
	Events.notify.emit("Mutagenic zone — your genome is drifting!")
	AudioManager.play_sfx("soup_mutate")


func _pick_ufo_goal() -> void:
	_ufo_goal = Vector3(randf_range(-ARENA, ARENA), randf_range(26.0, 34.0), randf_range(-ARENA, ARENA))


func _tick_ufo(delta: float) -> void:
	if _ufo == null or not is_instance_valid(_ufo):
		return
	_ufo_t -= delta
	if _ufo_t <= 0.0:
		_ufo.queue_free()
		_ufo = null
		_ufo_t = randf_range(UFO_COOLDOWN_MIN, UFO_COOLDOWN_MAX)
		return
	var dir: Vector3 = _ufo_goal - _ufo.position
	if dir.length() < 6.0:
		_pick_ufo_goal()
		return
	_ufo.position += dir.normalized() * 14.0 * delta
	_ufo.rotate_y(delta * 0.8)


func _process(delta: float) -> void:
	if _ufo != null and is_instance_valid(_ufo):
		_tick_ufo(delta)
	else:
		_ufo_t -= delta
		if _ufo_t <= 0.0:
			_ufo = WorldProps.spawn_at(self, "res://assets/models/nature_realistic/saucer1.glb", Vector3(0, 30, 0), 9.0)
			_pick_ufo_goal()
			_ufo_t = UFO_LIFETIME
	if _fire:
		return
	_t += delta
	_digest_t = maxf(0.0, _digest_t - delta)
	_caught_grace_t = maxf(0.0, _caught_grace_t - delta)
	var phase_len: float = night_length_for_day() if is_night else DAY_LENGTH
	if _t >= phase_len:
		_t = 0.0
		is_night = not is_night
		if is_night:
			_dusk_warned = false
			_on_night_falls()
		if not is_night:
			_day += 1
			_update_season()
			Events.notify.emit("Dawn of day %d — forage while the light holds." % _day)
			# Escalating pressure: a hunter each dawn, an extra on even days (both capped).
			var preds: int = get_tree().get_nodes_in_group("predators").size()
			if preds < PREDATOR_COUNT + 5:
				_spawn_predator()
			if _day >= 2 and _day % 2 == 0 and preds + 1 < PREDATOR_COUNT + 5:
				_spawn_predator()
	# Wolves idle by day, often close by — warn ahead of nightfall so cover is a choice, not luck.
	if not is_night and not _dusk_warned and _t >= DAY_LENGTH - DUSK_WARNING:
		_dusk_warned = true
		Events.notify.emit("Dusk — night falls in moments. Get to a thicket or your fire.")
	_update_sun(delta)
	_update_adaptation()
	hunger = clampf(hunger - HUNGER_DRAIN * delta, 0.0, 1.0)
	var drain_mult: float = ClimateAdaptModel.warmth_drain_mult(_adaptation_fit)
	if is_night:
		warmth = clampf(warmth - WARMTH_NIGHT_DRAIN * drain_mult * delta, 0.0, 1.0)
	else:
		warmth = clampf(warmth + WARMTH_DAY_RECOVER / drain_mult * delta, 0.0, 1.0)
	_update_meters()
	_respawn_entities()
	_tick_mutation(delta)
	_follow_player()
	if _hidden_label != null:
		var hid: bool = _player != null and is_instance_valid(_player) and _player.is_hidden
		_hidden_label.visible = hid
		if hid:
			StageObjectives.complete("cre_hide", "Hid from a predator")
	if _fire_safe_label != null:
		_fire_safe_label.visible = _player_in_fire_safe_zone()
	if _fireflies != null:
		_fireflies.emitting = is_night
	_tick_night_vignette(delta)


func _build_night_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	layer.name = "NightVignette"
	add_child(layer)
	_night_vignette = ColorRect.new()
	_night_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_night_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Deep blue-black edges; center stays readable via alpha.
	_night_vignette.color = Color(0.02, 0.04, 0.12, 0.0)
	layer.add_child(_night_vignette)


func _tick_night_vignette(delta: float) -> void:
	if _night_vignette == null:
		return
	# Stronger at night; ease off near fire so camp light "wins".
	var target_a: float = 0.0
	if is_night and not _fire:
		target_a = 0.42
		if _player_in_fire_safe_zone():
			target_a = 0.12
		elif _player != null and is_instance_valid(_player) and bool(_player.is_hidden):
			target_a = 0.22
	var c: Color = _night_vignette.color
	c.a = move_toward(c.a, target_a, 0.55 * delta)
	_night_vignette.color = c


func _update_sun(delta: float) -> void:
	if _sun == null:
		return
	var target: float = -25.0 if is_night else -52.0   # negative pitch = shining down (see Stage3D._build_sun)
	_sun.rotation_degrees.x = move_toward(_sun.rotation_degrees.x, target, 4.0 * delta)
	# Mood: warm low sun by day, dim cool moonlight by night — makes the fire glow matter at night.
	var day_col := Color(1.0, 0.94, 0.82)
	var night_col := Color(0.42, 0.52, 0.78)
	_sun.light_color = _sun.light_color.lerp(night_col if is_night else day_col, clampf(0.6 * delta, 0.0, 1.0))
	_sun.light_energy = move_toward(_sun.light_energy, 0.55 if is_night else 1.55, 0.7 * delta)
	if _world_env:
		var target_ambient: float = 0.10 if is_night else 0.55
		_world_env.environment.ambient_light_energy = move_toward(_world_env.environment.ambient_light_energy, target_ambient, 0.5 * delta)


func _update_season() -> void:
	var season_idx: int = ((_day - 1) / DAYS_PER_SEASON) % SEASON_NAMES.size()
	_current_season = SEASON_NAMES[season_idx]

func _update_adaptation() -> void:
	var insulation: float = EvolutionState.genome.defense if EvolutionState.genome != null else 0.5
	var temp: float = ClimateAdaptModel.temp_at(_current_season)
	_adaptation_fit = ClimateAdaptModel.adaptation_fit(insulation, temp)
	if _player and is_instance_valid(_player):
		_player.climate_slowdown = ClimateAdaptModel.move_penalty(_adaptation_fit)
	_update_hud()

# True when the player stands inside any lit campfire's deterrent radius (a night safe zone).
func _player_in_fire_safe_zone() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	for f in get_tree().get_nodes_in_group("campfires"):
		if f is Node3D and _player.global_position.distance_to((f as Node3D).global_position) < CreatureBalance.fire_repel_radius:
			return true
	return false


func _follow_player() -> void:
	if _player == null:
		return
	if _cam_free_t > 0.0:
		_cam_free_t = maxf(0.0, _cam_free_t - get_process_delta_time())
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam and cam.has_method("set_focus"):
		cam.set_focus(_player.position)


func _unhandled_input(event: InputEvent) -> void:
	# F = snap tactical to the player (survival "where am I").
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_cam_free_t = 3.0
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null and cam.has_method("zoom_tactical") and _player != null:
			cam.zoom_tactical(_player.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_T or event.keycode == KEY_HOME):
		_cam_free_t = 3.0


func _respawn_entities() -> void:
	var mats: Array[String] = []
	mats.assign(BRANCH_MATERIALS.get(EvolutionState.genome.branch_name() if EvolutionState.genome != null else "freshwater", BRANCH_MATERIALS["freshwater"]))
	_mote_objs = _mote_objs.filter(func(m): return is_instance_valid(m))
	while _mote_objs.size() < MOTE_COUNT:
		_spawn_mote()
	_material_objs = _material_objs.filter(func(m): return is_instance_valid(m))
	while _material_objs.size() < MATERIAL_COUNT:
		_spawn_material(mats)


func current_day() -> int:
	return _day


func gather(id: String, amt: int) -> void:
	if id == "food":
		_on_eat(1.0)
	else:
		inventory[id] = int(inventory.get(id, 0)) + amt
		AudioManager.play_sfx("blip")
		_update_materials_label()
		_update_build_buttons()
		_check_discovery()


func _on_eat(_amount: float) -> void:
	if _fire:
		return
	hunger = clampf(hunger + EAT_REFILL, 0.0, 1.0)
	# Growth is paced by digestion (one point per GROW_INTERVAL), not by how fast motes are hoovered.
	if _digest_t > 0.0 and not bool(get_meta("_digest_toasted", false)):
		set_meta("_digest_toasted", true)
		Events.notify.emit("Digesting — each meal grows you once the last one settles.")
	if _digest_t <= 0.0 and hunger > METER_LOW and warmth > METER_LOW:
		_digest_t = GROW_INTERVAL
		growth = mini(growth + 1, MATURE_AT)
		if growth >= 3:
			StageObjectives.complete("cre_grow", "Grew stronger — keep foraging")
		if growth >= MATURE_AT:
			_matured = true
		_check_discovery()
	_update_hud()
	_update_meters()


func on_player_caught(from_pos: Vector3) -> void:
	if _fire or _caught_grace_t > 0.0:
		return
	_caught_grace_t = CAUGHT_GRACE
	growth = maxi(0, growth - CAUGHT_SETBACK)
	_check_discovery()
	_update_hud()
	if _player and _player.has_method("knockback"):
		# A SHOVE, not a launch — a much larger value flings the player off the map.
		var away := _player.global_position - from_pos
		var dir := away.normalized() if away.length() > 0.01 else Vector3(0, 0, 1)
		_player.knockback(Vector2(dir.x, dir.z), 110.0)
	AudioManager.play_sfx("creature_attack")


func warm(amount: float) -> void:
	warmth = clampf(warmth + amount, 0.0, 1.0)


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if int(inventory.get(id, 0)) < cost[id]:
			return false
	return true


func build(recipe_name: String) -> void:
	if not RECIPES.has(recipe_name):
		return
	var cost: Dictionary = RECIPES[recipe_name]
	if not can_afford(cost):
		return
	for id in cost:
		inventory[id] = int(inventory.get(id, 0)) - cost[id]
	match recipe_name:
		"Campfire":
			var cf := Campfire3D.new()
			add_child(cf)
			# Ground level — the player capsule hovers at GROUND_Y, don't inherit its y.
			cf.position = Vector3(_player.position.x, 0.0, _player.position.z)
		"Shelter":
			var s := HidingSpot3D.new()
			add_child(s)
			s.position = Vector3(_player.position.x, 0.0, _player.position.z) + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
	_update_materials_label()
	_update_build_buttons()


func _knap_tools() -> void:
	if _knapped or _sum(HARD_MATS) < TOOLS_HARD_NEEDED:
		return
	_spend_category(HARD_MATS, TOOLS_HARD_NEEDED)
	_knapped = true
	EvolutionState.discovered_tools = true
	Events.notify.emit("Stone tools ready — gather fiber/wood for kindling, then fire.")
	StageObjectives.complete("cre_tools", "Knapped tools — kindling is next")
	_check_discovery()
	_update_build_buttons()


func _spend_category(mats: Array[String], n: int) -> void:
	var left: int = n
	for m in mats:
		if left <= 0:
			break
		var have: int = int(inventory.get(m, 0))
		var take: int = mini(have, left)
		if take > 0:
			inventory[m] = have - take
			left -= take
	_update_materials_label()


func _on_build_pressed(recipe_name: String) -> void:
	build(recipe_name)


func _sum(ids: Array[String]) -> int:
	var t: int = 0
	for i in ids:
		t += int(inventory.get(i, 0))
	return t


func _check_discovery() -> void:
	if _fire:
		return
	var was_matured := _matured
	var was_kindling := _kindling
	_matured = growth >= MATURE_AT
	_tools = _knapped
	_kindling = _sum(SOFT_MATS) >= KINDLING_SOFT_NEEDED
	_update_discovery()
	if _matured and not was_matured:
		Events.notify.emit("Grown strong enough — tools + kindling still gate fire.")
		StageObjectives.complete("cre_mature", "Matured — finish tools & kindling")
	if _kindling and not was_kindling and not _fire:
		Events.notify.emit("Kindling stocked — knap tools if needed, then fire unlocks.")
	# One-away coaching: two of three gates ready (once).
	var ready_n := (1 if _matured else 0) + (1 if _tools else 0) + (1 if _kindling else 0)
	if ready_n == 2 and not (_matured and _tools and _kindling) and not bool(get_meta("_almost_fire_toasted", false)):
		set_meta("_almost_fire_toasted", true)
		var missing := "grow" if not _matured else ("tools" if not _tools else "kindling")
		Events.notify.emit("Almost fire — still need: %s" % missing)
	if _matured and _tools and _kindling:
		_discover_fire()


func _update_discovery() -> void:
	if not _discovery_label:
		return
	if _fire:
		_discovery_label.text = "You made FIRE — evolving..."
		return
	var m: String = "Grow %d/%d" % [growth, MATURE_AT] if not _matured else "Grown ✓"
	var t: String = "Tools %d/%d" % [_sum(HARD_MATS), TOOLS_HARD_NEEDED] if not _knapped else "Tools ✓"
	var k: String = "Kindling %d/%d" % [_sum(SOFT_MATS), KINDLING_SOFT_NEEDED] if not _kindling else "Kindling ✓"
	_discovery_label.text = "FIRE · %s · %s · %s" % [m, t, k]


func _discover_fire() -> void:
	_fire = true
	EvolutionState.creature_inventory = inventory.duplicate()
	EvolutionState.discovered_fire = true
	EvolutionState.discovered_tools = true
	_update_discovery()
	AudioManager.play_sfx("chime")
	Events.notify.emit("FIRE — the night will never own you again.")
	StageObjectives.complete("cre_fire", "Discovered fire — the tribe is next")
	_show_trait_pick()


func _show_trait_pick() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	ui.layer = 11
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(20, 140)
	box.add_theme_constant_override("separation", 10)
	ui.add_child(box)
	var prompt: Label = Label.new()
	prompt.text = "You discovered FIRE! Choose a trait for your people:"
	prompt.add_theme_font_size_override("font_size", 18)
	box.add_child(prompt)
	var body: Label = Label.new()
	body.text = GenomeBonus.foreshadow_line(EvolutionState.genome)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(420, 0)
	body.modulate = Color(0.85, 0.92, 0.78)
	box.add_child(body)
	var axes: Label = Label.new()
	axes.text = GenomeBonus.axes_readout(EvolutionState.genome)
	axes.modulate = Color(0.65, 0.75, 0.8)
	axes.add_theme_font_size_override("font_size", 12)
	box.add_child(axes)
	for t in TRAITS:
		var b: Button = Button.new()
		b.text = "%s  —  %s" % [t.name, t.get("hint", "")]
		b.custom_minimum_size = Vector2(520, 44)
		b.tooltip_text = str(t.get("hint", ""))
		if ResourceLoader.exists(t.icon):
			b.icon = load(t.icon)
		b.pressed.connect(_pick.bind(t.name))
		box.add_child(b)


func _pick(trait_name: String) -> void:
	EvolutionState.traits.append(trait_name)
	Events.notify.emit("Trait chosen: %s" % trait_name)
	Events.stage_complete.emit(EvolutionState.current_stage)


func _on_material_collected(node: MaterialNode3D) -> void:
	var idx: int = _material_objs.find(node)
	if idx >= 0:
		_material_objs.remove_at(idx)


func _build_hud() -> void:
	# Shared StageChrome shell — same panel/type language as Tribe/Civ/Space.
	var ui: CanvasLayer = StageChromeScript.make_layer(self)
	var panel = CompactHUD.new()
	panel.configure("CREATURE", BUILD_PANEL_SIZE.x, false)
	panel.tooltip_text = "Move with WASD. Gather materials, craft shelter, survive night, discover fire."
	ui.add_child(panel)
	var root: VBoxContainer = panel.content
	root.add_child(StageChromeScript.identity_row(48))
	root.add_child(StageChromeScript.h_sep())
	_day_label = StageChromeScript.status_label("Day %d · Spring · Day" % _day)
	_day_label.mouse_filter = Control.MOUSE_FILTER_PASS   # adaptation % lives in the tooltip
	root.add_child(_day_label)
	_growth_bar = ProgressBar.new()
	_growth_bar.min_value = 0
	_growth_bar.max_value = MATURE_AT
	StageChromeScript.style_progress(_growth_bar, StageChromeScript.BORDER)
	root.add_child(_growth_bar)
	_hunger_bar = StageChromeScript.meter_bar(root, "Hunger", StageChromeScript.ACCENT_OK)
	_warmth_bar = StageChromeScript.meter_bar(root, "Warmth", StageChromeScript.ACCENT_OK)
	_material_label = StageChromeScript.status_label()
	root.add_child(_material_label)
	_discovery_label = StageChromeScript.goal_label()
	root.add_child(_discovery_label)
	_hidden_label = StageChromeScript.status_label("HIDDEN — the predator loses your trail")
	_hidden_label.add_theme_color_override("font_color", StageChromeScript.ACCENT_OK)
	_hidden_label.visible = false
	root.add_child(_hidden_label)
	_fire_safe_label = StageChromeScript.status_label("The fire keeps predators back")
	_fire_safe_label.add_theme_color_override("font_color", StageChromeScript.ACCENT_WARN)
	_fire_safe_label.visible = false
	root.add_child(_fire_safe_label)
	var tabs := BuildTabs.new()
	tabs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	var craft_grid := StageChromeScript.build_grid(1)
	tabs.add_tab("Craft", craft_grid)
	for name in RECIPES:
		_build_recipe_names.append(name)
		var cost: Dictionary = RECIPES[name]
		var parts: PackedStringArray = []
		for id in cost:
			parts.append("%s %s" % [cost[id], id])
		var b: Button = StageChromeScript.make_button(
			"%s (%s)" % [name, " · ".join(parts)],
			"Craft %s" % name,
			_on_build_pressed.bind(name))
		craft_grid.add_child(b)
		_build_buttons.append(b)
	_knap_btn = Button.new()
	_knap_btn.pressed.connect(_knap_tools)
	_knap_btn.custom_minimum_size = Vector2(0, 27)
	_knap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_knap_btn.add_theme_font_size_override("font_size", 14)
	_knap_btn.clip_text = false
	craft_grid.add_child(_knap_btn)

	_update_hud()
	_update_meters()
	_update_materials_label()
	_update_discovery()
	_update_build_buttons()


# 2-column GridContainer shared by every build tab. Compact spacing (4px) keeps the buildables
# inside the side panel at 1920×1080.
func _make_build_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid


func _meter_bar(parent: Node, label_text: String, fill: Color) -> ProgressBar:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l: Label = Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(48, 0)
	l.add_theme_font_size_override("font_size", 13)
	row.add_child(l)
	var pb: ProgressBar = ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = 1.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 13)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.modulate = fill
	row.add_child(pb)
	parent.add_child(row)
	return pb


func _update_hud() -> void:
	if _day_label:
		_day_label.text = "Day %d · %s · %s" % [
			_day,
			_current_season.capitalize(),
			"Night" if is_night else "Day",
		]
		_day_label.tooltip_text = "Adaptation %d%%" % int(_adaptation_fit * 100.0)
	if _growth_bar:
		_growth_bar.value = growth


func _update_meters() -> void:
	StageChromeScript.tint_meter(_hunger_bar, hunger)
	StageChromeScript.tint_meter(_warmth_bar, warmth)


func _update_materials_label() -> void:
	if not _material_label:
		return
	var parts: PackedStringArray = []
	for id in inventory:
		parts.append("%s %s" % [id, inventory[id]])
	_material_label.text = "Materials: " + " · ".join(parts) if parts.size() > 0 else "Materials: (none)"


func _update_build_buttons() -> void:
	for i in _build_buttons.size():
		_build_buttons[i].disabled = not can_afford(RECIPES[_build_recipe_names[i]])
	if _knap_btn:
		if _knapped:
			_knap_btn.text = "Stone Tools ✓"
			_knap_btn.disabled = true
		else:
			_knap_btn.text = "Knap Stone Tools (%d hard)" % TOOLS_HARD_NEEDED
			_knap_btn.disabled = _sum(HARD_MATS) < TOOLS_HARD_NEEDED


func capture() -> Dictionary:
	return {
		"version": 1,
		"is_night": is_night,
		"current_season": _current_season,
		"adaptation_fit": _adaptation_fit,
		"growth": growth,
		"hunger": hunger,
		"warmth": warmth,
		"inventory": inventory.duplicate(),
		"day": _day,
		"time": _t,
		"fire": _fire,
		"matured": _matured,
		"tools": _tools,
		"knapped": _knapped,
		"kindling": _kindling,
		"player_position": _vec3_to_dict(_player.position if _player != null else Vector3.ZERO),
		"ufo_timer": _ufo_t,
		"campfires": _capture_node_positions("structures", "Campfire3D"),
		"hiding_spots": _capture_node_positions("hiding_spots", "HidingSpot3D"),
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	is_night = bool(data.get("is_night", is_night))
	_current_season = str(data.get("current_season", _current_season))
	_adaptation_fit = _finite_float(data.get("adaptation_fit", _adaptation_fit), _adaptation_fit)
	growth = int(data.get("growth", growth))
	hunger = clampf(_finite_float(data.get("hunger", hunger), hunger), 0.0, 1.0)
	warmth = clampf(_finite_float(data.get("warmth", warmth), warmth), 0.0, 1.0)
	var inv_val: Variant = data.get("inventory", {})
	if inv_val is Dictionary:
		inventory = (inv_val as Dictionary).duplicate()
	_day = maxi(1, int(data.get("day", _day)))
	_t = maxf(0.0, _finite_float(data.get("time", _t), _t))
	_fire = bool(data.get("fire", _fire))
	_matured = bool(data.get("matured", _matured))
	_tools = bool(data.get("tools", _tools))
	_knapped = bool(data.get("knapped", _knapped))
	_kindling = bool(data.get("kindling", _kindling))
	if _player != null:
		_player.position = _dict_to_vec3(data.get("player_position", {}), _player.position)
	_ufo_t = _finite_float(data.get("ufo_timer", _ufo_t), _ufo_t)
	_restore_campfires(data.get("campfires", []))
	_restore_hiding_spots(data.get("hiding_spots", []))
	_check_discovery()
	_update_hud()
	_update_meters()
	_update_materials_label()
	_update_discovery()
	_update_build_buttons()
	if _fire:
		_show_trait_pick()


func _capture_node_positions(group: String, class_name_text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node_val: Variant in get_tree().get_nodes_in_group(group):
		if not (node_val is Node3D):
			continue
		var node: Node3D = node_val
		# Skip nodes pending deletion: restore() queue_frees the freshly spawned defaults
		# in the same frame the post-load autosave captures, which would otherwise save
		# the doomed nodes AND their replacements (the save would grow every load cycle).
		if node.is_queued_for_deletion():
			continue
		var script: Script = node.get_script()
		var global_name: String = script.get_global_name() if script != null else ""
		if node.get_parent() != self or (node.get_class() != class_name_text and global_name != class_name_text):
			continue
		out.append({"position": _vec3_to_dict(node.position)})
	return out


func _restore_campfires(value: Variant) -> void:
	_remove_own_group_nodes("structures", "Campfire3D")
	if not (value is Array):
		return
	for item: Variant in value:
		if not (item is Dictionary):
			continue
		var cf := Campfire3D.new()
		add_child(cf)
		cf.position = _dict_to_vec3((item as Dictionary).get("position", {}), Vector3.ZERO)


func _restore_hiding_spots(value: Variant) -> void:
	_remove_own_group_nodes("hiding_spots", "HidingSpot3D")
	if not (value is Array):
		return
	for item: Variant in value:
		if not (item is Dictionary):
			continue
		var spot := HidingSpot3D.new()
		add_child(spot)
		spot.position = _dict_to_vec3((item as Dictionary).get("position", {}), Vector3.ZERO)


func _remove_own_group_nodes(group: String, class_name_text: String) -> void:
	for node_val: Variant in get_tree().get_nodes_in_group(group):
		if not (node_val is Node):
			continue
		var node: Node = node_val
		if node.get_parent() != self:
			continue
		var script: Script = node.get_script()
		var global_name: String = script.get_global_name() if script != null else ""
		if node.get_class() == class_name_text or global_name == class_name_text:
			node.queue_free()


func _vec3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _dict_to_vec3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		return Vector3(
			_finite_float(d.get("x", fallback.x), fallback.x),
			_finite_float(d.get("y", fallback.y), fallback.y),
			_finite_float(d.get("z", fallback.z), fallback.z)
		)
	return fallback


func _finite_float(value: Variant, fallback: float) -> float:
	var f: float = float(value)
	return f if is_finite(f) else fallback
