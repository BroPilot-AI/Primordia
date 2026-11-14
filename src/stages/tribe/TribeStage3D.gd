class_name TribeStage3D extends Stage3D

const NAT := "res://assets/models/kenney-nature/%s.glb"
const CHAR := "res://assets/models/kenney-characters/%s.glb"
const CompactHUD := preload("res://src/ui/CompactHUDPanel.gd")
const StageChromeScript := preload("res://src/ui/StageChrome.gd")
const HEX_ROOT := "res://assets/models/kenney-hexagon/"
const HEX_GRASS := HEX_ROOT + "grass.glb"
const HEX_FOREST := HEX_ROOT + "grass-forest.glb"
const HEX_HILL := HEX_ROOT + "grass-hill.glb"
const HEX_DIRT := HEX_ROOT + "dirt.glb"
const HEX_SAND := HEX_ROOT + "sand.glb"
const HEX_SAND_ROCKS := HEX_ROOT + "sand-rocks.glb"
const HEX_STONE := HEX_ROOT + "stone.glb"
const HEX_STONE_HILL := HEX_ROOT + "stone-hill.glb"
const HEX_MOUNTAIN := HEX_ROOT + "stone-mountain.glb"
const HEX_WATER := HEX_ROOT + "water.glb"
const HEX_WATER_ROCKS := HEX_ROOT + "water-rocks.glb"
const HEX_POINT := 6.24
const HEX_FLAT := HEX_POINT / 1.1547
const HEX_COL_STEP := HEX_FLAT
const HEX_ROW_STEP := HEX_POINT * 0.75

const FIELD := 80.0
const SPAWN_INTERVAL := 4.5
const MAX_NODES := 24
const MAX_ANIMALS := 7
const ANIMAL_INTERVAL := 10.5
const HERD_RECYCLE_MIN_DIST := 15.0   # never recycle an animal the leader may be chasing
const PASSIVE_FOOD_RATE := 0.10
const TARGET_POP := 18           # a real village, earned in ~5min (measured by pace sim); 30 was a ~16min grind
const START_POP := 4
const HUT_COST := {wood = 3}
const TREE_COUNT := 96
const CAMERA_SIZE := 28.0
const PLAYER_MODEL := preload("res://assets/models/kenney-characters/character-male-a.glb")
# Preload by PATH (not bare class_name) so a stale global-class cache can't break the load.
const Villagers := preload("res://src/stages/tribe/VillagerModels.gd")
const Camp := preload("res://src/stages/tribe/CampProps.gd")
const BAND_SCALE := 1.9          # villager body_mult → ~3u, the band must clearly read
const MAX_BAND := 18             # cap visible bodies = TARGET_POP so the whole village is on screen
const CAMP_CENTER := Vector3.ZERO
const LIT_FIRE_SCALE := 2.4      # Existing lit bonfire kit asset; generated props fit by AABB.
const YEAR_LEN := 44.0           # seconds per in-game year; generations turn within a session
const Season := preload("res://src/stages/tribe/SeasonModel.gd")
const Lifecycle := preload("res://src/stages/tribe/LifecycleModel.gd")
const WorkArea := preload("res://src/stages/tribe/WorkAreaModel.gd")
const Ecology := preload("res://src/stages/tribe/EcologyModel.gd")
const ZONE_RADIUS := 18.0
const ZONE_MAX_WORKERS := 4
const MAX_ZONES := 4
const ECO_CAP := 100.0           # per-resource local supply capacity (Ancient Cities depletion)
const ECO_REGROW := 0.028        # logistic regrow rate toward capacity
const Thinker := preload("res://src/stages/tribe/ThinkerModel.gd")
const THINK_RADIUS := 22.0           # leader must be within this of the fire to advance research (Kainga)
const THINK_RATE := 0.085            # research progress/sec at the fire (was 0.07 — felt sticky)
const DAY_LEN := 36.0                # seconds per day/night cycle (sun sweep + night dim)
const HUT_CAPACITY := 2              # adults a hut shelters; ONLY housed adults bear children
const BASE_SHELTER := 2              # the campfire/founders' shelter houses the first couple
# Matches MaterialNode3D's sphere — the leader collects by walking over.
const PICKUP_RADIUS := 2.5
# UI-BUYMENU-REDESIGN: tabbed build panel — Learn / Build. Pure layout refactor; refresh logic + the
# `b.text.begins_with(name + " (")` lookup in _refresh_tech_buttons is preserved verbatim.
const BUILD_PANEL_SIZE := Vector2(360, 0)
const BIOMES := {
	"human": {"ground": Color(0.34, 0.50, 0.30), "name": "Grassland"},
	"short_alien": {"ground": Color(0.26, 0.46, 0.42), "name": "Wetland"},
	"tall_grey": {"ground": Color(0.43, 0.50, 0.53), "name": "Highland Tundra"},
	"reptilian": {"ground": Color(0.55, 0.47, 0.32), "name": "Arid Scrub"},
}
const BIOME_FALLBACK := {"ground": Color(0.34, 0.50, 0.30), "name": "Grassland"}

const RESEARCH_TECHS := {
	"Stone Tools": {stone = 2},
	"Foraging": {fiber = 3},
	"Hunting": {stone = 3},
	"Stone Weapons": {stone = 3, wood = 2},
	"Shelter": {wood = 3, fiber = 2},
}

var population: int = START_POP
var food: int = 0
var inventory: Dictionary = {}
var food_bonus: int = 0
## Extra food per successful hunt — granted by the "Hunting" tech (previously a no-op purchase).
var _hunt_bonus: int = 0
var _raid_factor: float = 1.0
var _researched: Dictionary = {}
var _wolf_resist: float = 1.0
var _huts: int = 0
var _spawn_t: float = 0.0
var _animal_t: float = 0.0
var _food_accum: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _player: Node3D = null
var _appear_sig: String = ""
var _anim: AnimationPlayer = null
var _cur_anim: String = ""
var _walk_anim: String = ""
var _idle_anim: String = ""
var _species: String = "human"   # the lineage you evolved — the WHOLE tribe is this species
var _rival: Node3D = null
var _villagers: Array[Node3D] = []
var _people: Array = []          # lifecycle villager dicts {age,sex,stage}; `population` is derived from this
var _elapsed: float = 0.0
var _year: int = 0
var _season: String = "summer"
var _zones: Array = []           # each: {"area":WorkArea dict, "marker":Node3D}
var _eco: Dictionary = {}        # resource id -> current local supply (depletes/regrows)
var _work_accum: Dictionary = {} # fractional yield carry per resource
var _active_research: String = ""
var _research_progress: float = 0.0
var _research_half_toasted := false
var _research_away_toasted := false
var _think_glow: OmniLight3D = null
var _sun: DirectionalLight3D = null
var _env: Environment = null
var _ground_mat: StandardMaterial3D = null
var _melt_disc: MeshInstance3D = null
var _melt_steam: CPUParticles3D = null
var _camp_fire_glow: OmniLight3D = null
var _biome: Dictionary = BIOME_FALLBACK
var _terrain_cover_spots: Array[Vector3] = []
var _terrain_mesh_cache: Dictionary = {}
var _ground_tone := GroundTone.new(hash(EvolutionState.world_seed + "_ground_tone"))
var _cam_free_t: float = 0.0

var _status: Label = null
var _pop_label: Label = null
var _food_label: Label = null
var _mat_label: Label = null
var _goal_label: Label = null
var _season_label: Label = null
var _found_btn: Button = null
var _hut_btn: Button = null
var _tech_names: Array[String] = []
var _tech_buttons: Array[Button] = []


func _ready() -> void:
	add_to_group("tribe_stage")
	_rng.seed = hash(EvolutionState.world_seed + "_tribe3d")
	_species = EvolutionState.genome.resolved_species() if EvolutionState.genome != null else "human"
	_biome = BIOMES.get(_species, BIOME_FALLBACK)
	_apply_genome_bonuses()
	_init_people()
	_init_eco()
	_build_environment("outdoor")
	_build_sun()
	_grab_world_refs()
	_build_ground()
	_spawn_player()
	_build_camera(_player.position, CAMERA_SIZE)
	_spawn_trees()
	_build_camp()
	for _i in 14:
		_spawn_node()
	_sync_band()
	_build_ui()
	_refresh()
	_rival = RivalBand3D.new()
	add_child(_rival)
	_rival.position = Vector3(_rng.randf_range(-FIELD * 0.5, FIELD * 0.5), 0, _rng.randf_range(-FIELD * 0.5, FIELD * 0.5))
	# Soft open tips — first goal after a beat so it doesn't stack on StageIntro dismiss.
	call_deferred("_emit_open_goals")


## Lineage axes shape the band: carnivores hunt better; tanky lineages lose less to raids/wolves.
func _apply_genome_bonuses() -> void:
	var g = EvolutionState.genome
	var hunt_m: float = GenomeBonus.hunt_mult(g)
	# Convert mult above 1.0 into flat food bonus on kills (tech still stacks on top).
	_hunt_bonus = maxi(_hunt_bonus, int(round((hunt_m - 1.0) * 4.0)))
	_wolf_resist = clampf(_wolf_resist * GenomeBonus.raid_loss_mult(g), 0.25, 1.2)
	_raid_factor = clampf(_raid_factor * GenomeBonus.raid_loss_mult(g), 0.25, 1.2)


func _emit_open_goals() -> void:
	Events.notify.emit(GenomeBonus.foreshadow_line(EvolutionState.genome))


func _grab_world_refs() -> void:
	# Stage3D adds the WorldEnvironment + sun as plain children; grab them to drive day/night + seasons.
	for c in get_children():
		if c is WorldEnvironment and _env == null:
			_env = (c as WorldEnvironment).environment
		elif c is DirectionalLight3D and _sun == null:
			_sun = c as DirectionalLight3D


func _build_ground() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "TribeGroundBase"
	ground.mesh = BoxMesh.new()
	ground.mesh.size = Vector3(FIELD * 2.5, 0.3, FIELD * 2.5)
	var gmat: StandardMaterial3D = StandardMaterial3D.new()
	gmat.albedo_color = (_biome.get("ground", Color(0.30, 0.45, 0.28)) as Color).darkened(0.28)
	gmat.roughness = 0.95
	ground.material_override = gmat
	_ground_mat = gmat
	ground.position.y = -0.15
	add_child(ground)
	_build_tribe_hex_field()


# Compose a real landscape around the camp. The settlement starts in a broad clearing, paths
# provide visual structure, noise creates coherent cover/elevation regions, and the outer band
# closes the field with water or high ground depending on the evolved lineage's biome.
func _build_tribe_hex_field() -> void:
	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed = int(hash(EvolutionState.world_seed + "_tribe_terrain"))
	terrain_noise.frequency = 0.035
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = terrain_noise.seed + 911
	detail_noise.frequency = 0.075
	var half_cols := int(ceil(FIELD / HEX_COL_STEP)) + 2
	var half_rows := int(ceil(FIELD / HEX_ROW_STEP)) + 2
	var by_path: Dictionary = {}
	_terrain_cover_spots.clear()
	for cy in range(-half_rows, half_rows + 1):
		for cx in range(-half_cols, half_cols + 1):
			var pos := _tribe_hex_pos(cx, cy)
			var dist := Vector2(pos.x, pos.z).length()
			if dist > FIELD + HEX_POINT:
				continue
			var path := _tribe_tile_for(pos, dist, terrain_noise, detail_noise)
			if not by_path.has(path):
				by_path[path] = []
			var rotation := float(_rng.randi_range(0, 5) * 60)
			by_path[path].append({pos = pos, rot = rotation})
			if path == HEX_FOREST or path == HEX_HILL or path == HEX_STONE_HILL:
				_terrain_cover_spots.append(pos)
	for path in by_path:
		_build_tribe_tile_batch(path, by_path[path])


func _tribe_hex_pos(cx: int, cy: int) -> Vector3:
	var row_offset := HEX_COL_STEP * 0.5 if (cy & 1) == 1 else 0.0
	return Vector3(cx * HEX_COL_STEP + row_offset, 0.0, cy * HEX_ROW_STEP)


func _tribe_tile_for(pos: Vector3, dist: float, terrain_noise: FastNoiseLite, detail_noise: FastNoiseLite) -> String:
	var edge := dist / FIELD
	var n := terrain_noise.get_noise_2d(pos.x, pos.z)
	var d := detail_noise.get_noise_2d(pos.x, pos.z)
	# The camp is a deliberate open clearing with three readable dirt approaches.
	if dist < 3.0:
		return HEX_DIRT
	if dist < 24.0 and absf(pos.z) < 1.0:
		return HEX_DIRT
	if dist < 18.0:
		return HEX_SAND if _species == "reptilian" else HEX_GRASS
	match _species:
		"short_alien":
			if edge > 0.91 or n < -0.48: return HEX_WATER_ROCKS if d > 0.2 else HEX_WATER
			if n > 0.30: return HEX_FOREST
			if d > 0.42: return HEX_HILL
			return HEX_GRASS
		"tall_grey":
			if edge > 0.91: return HEX_MOUNTAIN if d > 0.0 else HEX_STONE_HILL
			if n > 0.28: return HEX_STONE_HILL
			if n < -0.42: return HEX_STONE
			return HEX_GRASS
		"reptilian":
			if edge > 0.91: return HEX_MOUNTAIN if d > 0.15 else HEX_STONE_HILL
			if n > 0.34: return HEX_SAND_ROCKS
			if n < -0.42: return HEX_DIRT
			return HEX_SAND
		_:
			if edge > 0.94: return HEX_WATER_ROCKS if d > 0.15 else HEX_WATER
			if edge > 0.88: return HEX_STONE_HILL if n > 0.0 else HEX_DIRT
			if n > 0.30: return HEX_FOREST
			if d > 0.42: return HEX_HILL
			if n < -0.48: return HEX_DIRT
			return HEX_GRASS


func _build_tribe_tile_batch(path: String, records: Array) -> void:
	var parts := _tribe_mesh_parts(path)
	if parts.is_empty():
		return
	var box := _tribe_merged_box(parts)
	var foot := maxf(box.size.x, box.size.z)
	var fit := HEX_POINT / foot if foot > 0.0 else 1.0
	var color := _tribe_tile_tint(path)
	var height_mult := 0.26
	if path == HEX_MOUNTAIN:
		height_mult = 0.58
	elif path == HEX_STONE_HILL or path == HEX_HILL:
		height_mult = 0.34
	var map_box := AABB(Vector3(-FIELD - 10.0, -10.0, -FIELD - 10.0), Vector3(FIELD * 2.0 + 20.0, 24.0, FIELD * 2.0 + 20.0))
	for part_idx in parts.size():
		var part: Dictionary = parts[part_idx]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		if path == HEX_HILL:
			# Grass base like the plain grass tiles around it, bare rock like the stone tiles.
			mm.mesh = _mesh_with_two_tone_albedo(part.mesh, _tribe_tile_tint(HEX_GRASS), _tribe_tile_tint(HEX_STONE), true)
		else:
			mm.mesh = _mesh_with_albedo_tint(part.mesh, color, true)
		mm.instance_count = records.size()
		for i in records.size():
			var rec: Dictionary = records[i]
			var basis := Basis(Vector3.UP, deg_to_rad(rec.rot)).scaled(Vector3(fit, fit * height_mult, fit))
			mm.set_instance_transform(i, Transform3D(basis, rec.pos) * part.xform)
			mm.set_instance_color(i, _ground_tone.at(rec.pos))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "TribeTerrain_%s_%d" % [path.get_file().get_basename(), part_idx]
		mmi.multimesh = mm
		mmi.custom_aabb = map_box
		mmi.add_to_group("tribe_terrain")
		# Native Kenney surface materials stay attached to the source mesh.
		add_child(mmi)


func _tribe_tile_tint(path: String) -> Color:
	match path:
		HEX_WATER, HEX_WATER_ROCKS:
			return Color(0.70, 0.84, 0.92)
		HEX_DIRT:
			return Color(0.60, 0.68, 0.60)
		HEX_SAND, HEX_SAND_ROCKS:
			return Color(0.82, 0.72, 0.48)
		HEX_STONE, HEX_STONE_HILL, HEX_MOUNTAIN:
			return Color(0.58, 0.62, 0.68)
		# The kit paints grass teal (#4ac6a7); red above 1 pulls it round to leaf green. Hills tint
		# their grass and rock separately (_build_tribe_tile_batch). Forest floor is grass: the
		# trees mark the wood, not a dark hexagon under them.
		_:
			if _species == "tall_grey":
				return Color(0.56, 0.66, 0.58)
			if _species == "short_alien":
				return Color(0.36, 0.68, 0.54)
			return Color(1.26, 0.68, 0.36)


func _tribe_mesh_parts(path: String) -> Array:
	if _terrain_mesh_cache.has(path):
		return _terrain_mesh_cache[path]
	var parts: Array = []
	var packed := load(path) as PackedScene
	if packed != null:
		var root := packed.instantiate()
		for found in root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := found as MeshInstance3D
			if mesh_instance.mesh != null:
				parts.append({mesh = mesh_instance.mesh, xform = mesh_instance.transform})
		root.free()
	_terrain_mesh_cache[path] = parts
	return parts


func _tribe_merged_box(parts: Array) -> AABB:
	var box := AABB()
	var first := true
	for part in parts:
		var part_box: AABB = part.xform * (part.mesh as Mesh).get_aabb()
		box = part_box if first else box.merge(part_box)
		first = false
	return box


func _spawn_player() -> void:
	# Per-species avatar (Human → Kenney character; alien lineages → Quaternius models), shown in
	# its natural model colors. ~2.5u tall so it reads against the RTS-scale clearing.
	var species: String = EvolutionState.genome.resolved_species() if EvolutionState.genome != null else "human"
	_species = species
	_player = SpeciesVisuals.attach(self, species, 2.5)
	if _player != null:
		SpeciesVisuals.express(_player, EvolutionState.genome)  # your evolved body carries into the Tribe
		GenomeFeatures3D.apply(_player, EvolutionState.genome, species, 0.55)
		_appear_sig = _appearance_signature()
	if _player == null:
		_player = PLAYER_MODEL.instantiate()
		_player.scale = Vector3.ONE * 0.6
		add_child(_player)
	_player.add_to_group("player")
	_setup_anim(_player)


func _setup_anim(model: Node) -> void:
	for c in model.find_children("*", "AnimationPlayer", true, false):
		_anim = c as AnimationPlayer
		break
	if _anim == null:
		return
	# Resolve walk/idle by KEYWORD so any rig works — Quaternius "Rig|Walk", Mixamo "Walk", etc.
	_walk_anim = _find_clip(["walk", "run", "jog"])
	_idle_anim = _find_clip(["idle", "breath"])
	if _idle_anim == "":
		_idle_anim = _walk_anim
	_play(_idle_anim)


func _find_clip(keys: Array) -> String:
	if _anim == null:
		return ""
	var list := _anim.get_animation_list()
	for n in list:
		var l := String(n).to_lower()
		for k in keys:
			if l.find(k) >= 0:
				return String(n)
	return String(list[0]) if list.size() > 0 else ""


func _play(anim_name: String) -> void:
	if _anim == null or _cur_anim == anim_name or not _anim.has_animation(anim_name):
		return
	var a := _anim.get_animation(anim_name)
	if a != null:
		a.loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name)
	_cur_anim = anim_name


func _play_idle_on(model: Node) -> void:
	for c in model.find_children("*", "AnimationPlayer", true, false):
		var anim := c as AnimationPlayer
		if anim == null:
			continue
		# KEYWORD-resolve idle so Mixamo "Idle" and Quaternius "Rig|Idle" both work.
		var clip := ""
		for n in anim.get_animation_list():
			if String(n).to_lower().find("idle") >= 0:
				clip = String(n)
				break
		if clip == "" and anim.get_animation_list().size() > 0:
			clip = String(anim.get_animation_list()[0])
		if clip == "":
			continue
		var a := anim.get_animation(clip)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
		anim.play(clip)
		break


func _appearance_signature() -> String:
	var g = EvolutionState.genome
	if g == null:
		return ""
	return "%.3f|%.3f|%.3f|%.3f|%.3f|%d|%s" % [
		float(g.size),
		float(g.defense),
		float(g.carnivory),
		float(g.senses),
		float(g.locomotion),
		EvolutionState.current_stage,
		str(EvolutionState.traits),
	]


func _refresh_player_appearance_if_needed() -> void:
	if _player == null or not is_instance_valid(_player) or EvolutionState.genome == null:
		return
	var sig := _appearance_signature()
	if sig == "" or sig == _appear_sig:
		return
	SpeciesVisuals.express(_player, EvolutionState.genome)
	var sp: String = EvolutionState.genome.resolved_species() if EvolutionState.genome != null else _species
	GenomeFeatures3D.apply(_player, EvolutionState.genome, sp, 0.55)
	_appear_sig = sig


func _spawn_trees() -> void:
	for _i in TREE_COUNT:
		var pos: Vector3
		if not _terrain_cover_spots.is_empty() and _rng.randf() < 0.72:
			pos = _terrain_cover_spots[_rng.randi_range(0, _terrain_cover_spots.size() - 1)]
			pos += Vector3(_rng.randf_range(-4.0, 4.0), 0, _rng.randf_range(-4.0, 4.0))
		else:
			pos = Vector3(_rng.randf_range(-FIELD, FIELD), 0, _rng.randf_range(-FIELD, FIELD))
		if pos.length() < 8.0:
			continue
		WorldProps.spawn_tree(self, pos, _rng)
	for _r in 22:
		var rpos: Vector3 = Vector3(_rng.randf_range(-FIELD, FIELD), 0, _rng.randf_range(-FIELD, FIELD))
		if rpos.length() > 8.0:
			WorldProps.spawn_rock(self, rpos, _rng)
	for _b in 28:
		var bpos: Vector3 = Vector3(_rng.randf_range(-FIELD, FIELD), 0, _rng.randf_range(-FIELD, FIELD))
		if bpos.length() > 8.0:
			WorldProps.spawn_bush(self, bpos, _rng)
	for _g in 72:
		var gpos: Vector3 = Vector3(_rng.randf_range(-FIELD, FIELD), 0, _rng.randf_range(-FIELD, FIELD))
		if gpos.length() > 8.0:
			WorldProps.spawn_groundcover(self, gpos, _rng)


func _build_camp() -> void:
	# A campfire anchors the settlement; scattered props give the ground detail/life.
	var hearth: Node3D = Camp.spawn_structure(self, "campfire", CAMP_CENTER, 0.0)
	# CC0 stone bonfire (Poly Pizza) stays as the lit flame model over the generated hearth.
	var fire: Node3D = spawn_model("res://assets/models/tribe_cc0/bonfire.glb", CAMP_CENTER, LIT_FIRE_SCALE)
	if fire == null:
		fire = hearth
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.25)
	glow.light_energy = 4.0
	glow.omni_range = 18.0
	glow.position = CAMP_CENTER + Vector3(0, 1.5, 0)
	add_child(glow)
	_camp_fire_glow = glow
	# Brighter pulse while the Thinker researches at the fire.
	_think_glow = OmniLight3D.new()
	_think_glow.light_color = Color(0.55, 0.85, 1.0)
	_think_glow.light_energy = 0.0
	_think_glow.omni_range = 14.0
	_think_glow.position = CAMP_CENTER + Vector3(0, 2.2, 0)
	add_child(_think_glow)
	Camp.scatter_props(self, 22, 38.0, _rng)
	# Winter snow-melt: bare ground the fire keeps clear — radius/glow scale with fuel stock.
	_melt_disc = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 14.0
	disc.bottom_radius = 14.0
	disc.height = 0.18
	_melt_disc.mesh = disc
	var dmat: StandardMaterial3D = StandardMaterial3D.new()
	dmat.albedo_color = _biome.get("ground", Color(0.30, 0.45, 0.28))
	dmat.roughness = 0.95
	dmat.emission_enabled = true
	dmat.emission = Color(0.35, 0.55, 0.28)
	dmat.emission_energy_multiplier = 0.0
	_melt_disc.material_override = dmat
	_melt_disc.position = CAMP_CENTER + Vector3(0, 0.02, 0)
	_melt_disc.visible = false
	add_child(_melt_disc)
	# Soft heat haze particles over the melt zone (winter only, intensity scales with fuel).
	_melt_steam = CPUParticles3D.new()
	_melt_steam.emitting = false
	_melt_steam.amount = 18
	_melt_steam.lifetime = 2.2
	_melt_steam.explosiveness = 0.05
	_melt_steam.randomness = 0.4
	_melt_steam.direction = Vector3(0, 1, 0)
	_melt_steam.spread = 55.0
	_melt_steam.initial_velocity_min = 0.4
	_melt_steam.initial_velocity_max = 1.6
	_melt_steam.gravity = Vector3(0, 0.35, 0)
	_melt_steam.scale_amount_min = 0.15
	_melt_steam.scale_amount_max = 0.45
	_melt_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_melt_steam.emission_sphere_radius = 12.0
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	_melt_steam.mesh = sm
	_melt_steam.position = CAMP_CENTER + Vector3(0, 0.4, 0)
	add_child(_melt_steam)


func _sync_band() -> void:
	# Render the population as actual bodies milling around camp (was just an int).
	var want: int = mini(population, MAX_BAND)
	while _villagers.size() < want:
		# The whole band is YOUR evolved species (the leader's lineage), not generic humans.
		var role: String = _band_role()
		# The leader also gets GenomeFeatures3D bulk (~1.08x), so 2.5 still reads a bit smaller than the chief.
		var member_h: float = 1.6 if role == "child" else 2.5
		var v: Node3D = SpeciesVisuals.attach(self, _species, member_h)
		if v != null:
			# Same genome expression as the leader: without it the raw model reads dark and drab.
			SpeciesVisuals.express(v, EvolutionState.genome)
		if v == null:
			v = Villagers.attach(self, role, BAND_SCALE)   # fallback to a generic humanoid
		if v == null:
			break
		_play_idle_on(v)
		v.position = CAMP_CENTER + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8))
		v.set_meta("wt", _rng.randf_range(0.0, 3.0))
		v.set_meta("wgoal", _band_goal())
		v.set_meta("zone", -1)
		v.set_meta("zoff", Vector3(_rng.randf_range(-ZONE_RADIUS * 0.5, ZONE_RADIUS * 0.5), 0, _rng.randf_range(-ZONE_RADIUS * 0.5, ZONE_RADIUS * 0.5)))
		_villagers.append(v)
	while _villagers.size() > want:
		var rem: Node3D = _villagers.pop_back()
		if is_instance_valid(rem):
			rem.queue_free()


func _band_role() -> String:
	var r: float = _rng.randf()
	return "male" if r < 0.42 else ("female" if r < 0.84 else "child")


func _band_goal() -> Vector3:
	return CAMP_CENTER + Vector3(_rng.randf_range(-15, 15), 0, _rng.randf_range(-15, 15))


func _wander_band(delta: float) -> void:
	for v in _villagers:
		if not is_instance_valid(v):
			continue
		var zone_idx: int = int(v.get_meta("zone", -1))
		var goal: Vector3
		if zone_idx >= 0 and zone_idx < _zones.size():
			# Assigned to a work zone: walk there and work (offset so they don't stack).
			goal = Vector3(_zones[zone_idx]["area"]["pos"]) + v.get_meta("zoff", Vector3.ZERO)
		else:
			# Idle: mill around camp.
			var t: float = float(v.get_meta("wt", 0.0)) - delta
			if t <= 0.0:
				t = _rng.randf_range(2.5, 5.5)
				v.set_meta("wgoal", _band_goal())
			v.set_meta("wt", t)
			goal = v.get_meta("wgoal", v.position)
		var to: Vector3 = goal - v.position
		to.y = 0.0
		if to.length() > 0.6:
			var dir: Vector3 = to.normalized()
			v.position += dir * 22.0 * delta
			var look_target := Vector3(v.position.x + dir.x, v.position.y, v.position.z + dir.z)
			if v.position.distance_to(look_target) > 0.1:
				v.look_at(look_target, Vector3.UP, true)   # models' front is +Z; plain look_at walks them backwards


func _init_people() -> void:
	# Seed the founding band as lifecycle villagers (mixed sexes, working-age adults).
	_people.clear()
	for i in START_POP:
		var sex: String = "m" if i % 2 == 0 else "f"
		_people.append(Lifecycle.make_villager(_rng.randf_range(16.0, 45.0), sex, _rng))
	population = _people.size()


func _tick_year() -> void:
	# One year passes: villagers age, elders die of old age, fertile pairs may bear children.
	# Births are gated by prosperity (food surplus) and winter fuel — scarcity SLOWS growth,
	# it NEVER kills (non-lethal pillar; only old age removes a villager).
	var adults: int = 0
	for v in _people:
		if str(v.get("stage", "")) == "adult":
			adults += 1
	var capacity: int = _capacity()
	# Only adults sheltered in huts bear children — build huts to raise the housed fraction.
	var housing_mult: float = clampf(float(capacity) / maxf(1.0, float(adults)), 0.0, 1.0)
	# The year turns at the summer boundary — gate on the winter just past,
	# not on "summer" (always 0).
	var fuel_need: float = Season.fuel_needed("winter", _people.size())
	var fuel_mult: float = Season.growth_multiplier(float(inventory.get("wood", 0)), fuel_need)
	var food_mult: float = clampf(float(food) / maxf(1.0, float(_people.size()) * 2.0), 0.0, 1.0)
	var birth_gate: float = fuel_mult * food_mult * housing_mult
	var res: Dictionary = Lifecycle.advance(_people, 1.0, _rng)
	var people2: Array = res.get("villagers", _people)
	var born: int = int(res.get("born", 0))
	var died: int = int(res.get("died", 0))
	# Apply the prosperity gate by leaving some newborns (age 0) unborn this year.
	var remove_n: int = maxi(0, born - int(round(float(born) * birth_gate)))
	if remove_n > 0:
		var filtered: Array = []
		var removed: int = 0
		for v in people2:
			if removed < remove_n and float(v.get("age", 1.0)) <= 0.0:
				removed += 1
				continue
			filtered.append(v)
		people2 = filtered
		born -= removed
	_people = people2
	var prev_pop: int = population
	population = _people.size()
	food = maxi(0, food - _people.size())   # the band eats from the stock; running out only slows births
	if food < _people.size() * 2:
		Events.notify.emit("Food runs thin — forage or hunt before the next year.")
	if fuel_mult < 1.0:
		Events.notify.emit("The winter fire ran low (needs %d wood) — fewer children this year."
			% ceili(fuel_need))
	if died > 0:
		Events.notify.emit("An elder passed of old age, full of years. (Year %d)" % _year)
	if born > 0:
		Events.notify.emit("%d %s born — the band is %d." % [born, ("children" if born > 1 else "child"), population])
	if population >= TARGET_POP and prev_pop < TARGET_POP:
		Events.notify.emit("Your band is large enough to found a settlement!")
	if adults > capacity:
		Events.notify.emit("%d adults have no hut — no new children for them. Build shelter to grow."
			% (adults - capacity))
	_sync_band()
	_refresh()


func _capacity() -> int:
	return BASE_SHELTER + _huts * HUT_CAPACITY


func _atmos_tick() -> void:
	# Day/night sweep: the sun arcs overhead and dims at night; ambient follows.
	var phase: float = fmod(_elapsed + DAY_LEN * 0.5, DAY_LEN) / DAY_LEN   # open at noon, not midnight
	var daylight: float = 0.5 - 0.5 * cos(phase * TAU)            # 0 = midnight, 1 = noon
	if _sun != null:
		_sun.light_energy = lerpf(0.12, 1.4, daylight)
		_sun.rotation_degrees = Vector3(-18.0 - daylight * 42.0, phase * 360.0, 0.0)
		_sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(0.55, 0.62, 0.85), 1.0 - daylight)
	if _env != null:
		_env.ambient_light_energy = lerpf(0.12, 0.55, daylight)
	# Season ground tint (winter = snow); the campfire melt disc shows only in winter.
	if _ground_mat != null:
		var base: Color = _biome.get("ground", Color(0.30, 0.45, 0.28))
		var col: Color = base
		match _season:
			"winter": col = base.lerp(Color(0.90, 0.93, 0.98), 0.82)
			"autumn": col = base.lerp(Color(0.70, 0.55, 0.30), 0.40)
			"spring": col = base.lerp(Color(0.60, 0.85, 0.50), 0.30)
		_ground_mat.albedo_color = col.darkened((1.0 - daylight) * 0.45)
	_update_winter_melt(daylight)


## Winter melt zone grows with fuel stock — well-stocked fires keep a larger bare camp.
func _update_winter_melt(daylight: float) -> void:
	if _melt_disc == null:
		return
	var winter: bool = (_season == "winter")
	_melt_disc.visible = winter
	if _melt_steam != null and is_instance_valid(_melt_steam):
		_melt_steam.emitting = winter
	if not winter:
		if _camp_fire_glow != null and is_instance_valid(_camp_fire_glow):
			_camp_fire_glow.omni_range = 18.0
			# Don't fight research glow — base energy only when not researching hard.
			if _active_research == "":
				_camp_fire_glow.light_energy = lerpf(2.2, 4.0, daylight)
		return
	var wood: float = float(inventory.get("wood", 0))
	var need: float = maxf(1.0, float(Season.fuel_needed(_season, _people.size())))
	# 0 = starved fire, 1 = fully stocked (2× need or more).
	var intensity: float = clampf(wood / (need * 2.0), 0.15, 1.0)
	# Disc radius 8 → 22 world units with fuel.
	var radius: float = lerpf(8.0, 22.0, intensity)
	var mesh: CylinderMesh = _melt_disc.mesh as CylinderMesh
	if mesh != null:
		mesh.top_radius = radius
		mesh.bottom_radius = radius
	var mat: StandardMaterial3D = _melt_disc.material_override as StandardMaterial3D
	if mat != null:
		var base: Color = _biome.get("ground", Color(0.30, 0.45, 0.28))
		# Thawed earth warms as fuel rises; slight green under snowline.
		mat.albedo_color = base.lerp(Color(0.42, 0.55, 0.32), intensity * 0.55)
		mat.emission = Color(0.55, 0.35, 0.12).lerp(Color(1.0, 0.55, 0.2), intensity)
		mat.emission_energy_multiplier = lerpf(0.15, 1.35, intensity) * (0.55 + 0.45 * daylight)
	if _melt_steam != null and is_instance_valid(_melt_steam):
		_melt_steam.amount = clampi(int(round(8.0 + intensity * 28.0)), 8, 40)
		_melt_steam.initial_velocity_max = lerpf(0.8, 2.4, intensity)
		# Spread steam over the melt radius.
		_melt_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_melt_steam.emission_sphere_radius = radius * 0.85
	if _camp_fire_glow != null and is_instance_valid(_camp_fire_glow):
		_camp_fire_glow.omni_range = lerpf(14.0, 28.0, intensity)
		if _active_research == "":
			_camp_fire_glow.light_energy = lerpf(3.0, 7.5, intensity)


func _init_eco() -> void:
	# Local resource supplies that deplete on harvest and regrow slowly (Ancient Cities).
	for k in ["food", "wood", "stone", "fiber"]:
		_eco[k] = ECO_CAP


func _designate_zone(kind: String) -> void:
	# Drop a circular work zone at the leader's feet; idle villagers auto-gather there.
	if _zones.size() >= MAX_ZONES:
		var old: Dictionary = _zones.pop_front()
		var om: Node3D = old.get("marker")
		if is_instance_valid(om):
			om.queue_free()
	var pos: Vector3 = _player.position if _player != null else CAMP_CENTER
	pos.y = 0.0
	var area: Dictionary = WorkArea.make_area(pos, ZONE_RADIUS, kind, ZONE_MAX_WORKERS)
	var marker: Node3D = _make_zone_marker(kind, pos)
	add_child(marker)
	_zones.append({"area": area, "marker": marker})
	Events.notify.emit("Work zone set: %s — idle hands will gather here." % _zone_label(kind))
	StageObjectives.complete("tribe_zone", "Designated a work zone (%s)" % _zone_label(kind))


func _make_zone_marker(kind: String, pos: Vector3) -> Node3D:
	var marker: Node3D = Node3D.new()
	marker.position = pos
	var ring: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = ZONE_RADIUS
	cyl.bottom_radius = ZONE_RADIUS
	cyl.height = 0.2
	ring.mesh = cyl
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var c: Color = _zone_color(kind)
	c.a = 0.22
	mat.albedo_color = c
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = _zone_color(kind)
	mat.emission_energy_multiplier = 0.3
	ring.material_override = mat
	ring.position = Vector3(0, 0.06, 0)
	marker.add_child(ring)
	Camp.spawn_structure(marker, Camp.work_area_type(kind), Vector3.ZERO, _rng.randf() * TAU)
	return marker


func _zone_resource(kind: String) -> String:
	match kind:
		"gather_wood": return "wood"
		"gather_stone": return "stone"
		"hunt": return "food"
		_: return "food"


func _zone_label(kind: String) -> String:
	match kind:
		"gather_wood": return "Wood"
		"gather_stone": return "Stone"
		"hunt": return "Hunting"
		_: return "Foraging"


func _zone_color(kind: String) -> Color:
	match kind:
		"gather_wood": return Color(0.65, 0.45, 0.22)
		"gather_stone": return Color(0.6, 0.62, 0.68)
		"hunt": return Color(0.85, 0.32, 0.3)
		_: return Color(0.4, 0.82, 0.42)


func _work_tick(delta: float) -> void:
	# Local supplies regrow toward capacity each frame.
	for k in _eco:
		_eco[k] = Ecology.regrow(float(_eco[k]), ECO_CAP, ECO_REGROW, delta)
	if _zones.is_empty() or _villagers.is_empty():
		for v in _villagers:
			if is_instance_valid(v):
				v.set_meta("zone", -1)
		return
	# Auto-assign idle villagers to the nearest zone with a free slot (Dawn of Man).
	var positions: Array = []
	for v in _villagers:
		positions.append(v.global_position if is_instance_valid(v) else Vector3.ZERO)
	var areas: Array = []
	for z in _zones:
		areas.append(z["area"])
	var assigns: Dictionary = WorkArea.assign(positions, areas)
	var counts: Array = []
	for i in _zones.size():
		counts.append(0)
	for wi in assigns:
		var ai: int = int(assigns[wi])
		var idx: int = int(wi)
		if idx >= 0 and idx < _villagers.size() and is_instance_valid(_villagers[idx]):
			_villagers[idx].set_meta("zone", ai)
		if ai >= 0 and ai < counts.size():
			counts[ai] += 1
	# Each worked zone yields its resource, scaled by local supply health, depleting it.
	for i in _zones.size():
		if counts[i] <= 0:
			continue
		var kind: String = str(_zones[i]["area"]["kind"])
		var resid: String = _zone_resource(kind)
		var supply: float = float(_eco.get(resid, ECO_CAP))
		var health: float = clampf(supply / ECO_CAP, 0.0, 1.0)
		var g_mult: float = GenomeBonus.hunt_mult(EvolutionState.genome) if kind == "hunt" else GenomeBonus.forage_mult(EvolutionState.genome)
		var produced: float = WorkArea.yield_for(kind, counts[i], delta) * health * g_mult
		if produced <= 0.0:
			continue
		_eco[resid] = Ecology.harvest(supply, produced)
		_work_accum[resid] = float(_work_accum.get(resid, 0.0)) + produced
		var whole: int = int(_work_accum[resid])
		if whole >= 1:
			_work_accum[resid] -= float(whole)
			if resid == "food":
				food += whole
			else:
				inventory[resid] = int(inventory.get(resid, 0)) + whole
	_refresh()
	_refresh_tech_buttons()


func _process(delta: float) -> void:
	_refresh_player_appearance_if_needed()
	_elapsed += delta
	var prev_season: String = _season
	_season = Season.season_at(_elapsed, YEAR_LEN)
	var yr: int = int(_elapsed / YEAR_LEN)
	if _season != prev_season and prev_season != "":
		Events.notify.emit("Season turns to %s (Year %d)." % [_season.capitalize(), yr])
		AudioManager.play_sfx("blip")
	if yr > _year:
		_year = yr
		_tick_year()
	_atmos_tick()
	_spawn_t += delta
	if _spawn_t >= SPAWN_INTERVAL:
		_spawn_t = 0.0
		var mats: Array = get_tree().get_nodes_in_group("materials")
		if mats.size() >= MAX_NODES:
			# Recycle the oldest uncollected pickup — a cluttered field must never starve fiber.
			mats[0].remove_from_group("materials")
			mats[0].queue_free()
		_spawn_node()
	_animal_t += delta
	if _animal_t >= ANIMAL_INTERVAL:
		_animal_t = 0.0
		var herd: Array = get_tree().get_nodes_in_group("animals")
		if herd.size() >= MAX_ANIMALS:
			# Recycle the oldest far-off animal — an unhunted herd must never stop wolves coming.
			for a in herd:
				if _player == null or a.position.distance_to(_player.position) > HERD_RECYCLE_MIN_DIST:
					a.remove_from_group("animals")
					a.queue_free()
					break
		if get_tree().get_nodes_in_group("animals").size() < MAX_ANIMALS:
			_spawn_animal()
	# Keen-senses / agile lineages forage faster (genome shapes the Tribe economy).
	_food_accum += (population * PASSIVE_FOOD_RATE + _huts * 0.2) * GenomeBonus.forage_mult(EvolutionState.genome) * delta
	if _food_accum >= 1.0:
		var whole: int = int(_food_accum)
		_food_accum -= whole
		_add_food(whole)
	_move_player(delta)
	_collect_pickups()
	_follow_player()
	_work_tick(delta)
	_research_tick(delta)
	_wander_band(delta)


func _move_player(delta: float) -> void:
	if _player == null:
		return
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var motion: Vector3 = Vector3(dir.x, 0, dir.y) * 360.0 * delta
	_player.position += motion
	if dir.length() > 0.1:
		var look_target := Vector3(_player.position.x + dir.x, _player.position.y, _player.position.z + dir.y)
		if _player.position.distance_to(look_target) > 0.1:
			_player.look_at(look_target, Vector3.UP, true)   # +Z model front leads (see PlayerCreature3D)
		_play(_walk_anim)
	else:
		_play(_idle_anim)


func _collect_pickups() -> void:
	# The leader is a plain model with no physics body, so MaterialNode3D.body_entered never fires
	# here — collect by proximity instead (fiber exists ONLY as pickups and Shelter needs it).
	if _player == null:
		return
	for n in get_tree().get_nodes_in_group("materials"):
		var m := n as MaterialNode3D
		if m == null or m.get_parent() != self:
			continue
		var to: Vector3 = m.position - _player.position
		to.y = 0.0
		if to.length() <= PICKUP_RADIUS:
			m.remove_from_group("materials")
			gather(m.material_id, 1)
			m.queue_free()


func _follow_player() -> void:
	if _player == null:
		return
	if _cam_free_t > 0.0:
		_cam_free_t = maxf(0.0, _cam_free_t - get_process_delta_time())
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null and cam.has_method("set_focus"):
		cam.set_focus(_player.position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_cam_free_t = 3.0
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null and cam.has_method("zoom_tactical") and _player != null:
			cam.zoom_tactical(_player.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_T or event.keycode == KEY_HOME):
		_cam_free_t = 3.0


func _spawn_animal() -> void:
	var roll: float = _rng.randf()
	var kind: String = "deer" if roll < 0.55 else ("boar" if roll < 0.8 else "wolf")
	var a: TribeAnimal3D = TribeAnimal3D.new()
	a.kind = kind
	add_child(a)
	var c: Vector3 = _player.position if _player != null else Vector3.ZERO
	a.position = c + Vector3(_rng.randf_range(-FIELD, FIELD), 0, _rng.randf_range(-FIELD, FIELD))


func _spawn_node() -> void:
	var m: MaterialNode3D = MaterialNode3D.new()
	var r: float = _rng.randf()
	m.material_id = "food" if r < 0.6 else ["wood", "stone", "fiber"][_rng.randi() % 3]
	add_child(m)
	var c: Vector3 = _player.position if _player != null else Vector3.ZERO
	m.position = c + Vector3(_rng.randf_range(-FIELD, FIELD), 0, _rng.randf_range(-FIELD, FIELD))


func gather(id: String, amt: int) -> void:
	if id == "food":
		_add_food(amt + food_bonus)
	else:
		inventory[id] = int(inventory.get(id, 0)) + amt
		_refresh()
		_refresh_tech_buttons()


func _add_food(amt: int) -> void:
	# Food is now a stock that feeds the lifecycle (gates yearly births); population growth
	# happens in _tick_year via LifecycleModel, not directly from food.
	food += amt
	_refresh()
	_refresh_tech_buttons()


func hunt(kind: String, amt: int) -> void:
	var gained: int = amt + _hunt_bonus
	_add_food(gained)
	Events.notify.emit("Hunted a %s — +%d food" % [kind, gained])
	StageObjectives.complete("tribe_hunt", "Landed a hunt — meat for the band")


func wolf_scatter() -> void:
	var lost: int = roundi(8 * _wolf_resist * maxf(0.3, 1.0 - _huts * 0.15))
	food = maxi(0, food - lost)
	_refresh()
	Events.notify.emit("A wolf scattered your foragers! -%d food" % lost)
	StageObjectives.complete("tribe_wolf", "Survived a wolf scatter")


func raid(amount: int) -> void:
	var lost: int = roundi(amount * _raid_factor)
	food = maxi(0, food - lost)
	_refresh()
	Events.notify.emit("Rival raided! -%d food" % lost)
	StageObjectives.complete("tribe_raid", "Endured a rival raid")


func _build_hut() -> void:
	if int(inventory.get("wood", 0)) < int(HUT_COST.wood):
		return
	inventory["wood"] = int(inventory["wood"]) - int(HUT_COST.wood)
	_huts += 1
	StageObjectives.complete("tribe_hut", "Raised a hut — housing unlocks growth")
	# Keep the hearth clear (same exclusion the flora scatter already uses) — a hut landing on
	# top of the campfire/glow light was a real risk with a pure random box and no min radius.
	var pos: Vector3 = CAMP_CENTER
	for _try in 8:
		pos = CAMP_CENTER + Vector3(_rng.randf_range(-16, 16), 0, _rng.randf_range(-16, 16))
		if pos.length() >= 6.0:
			break
	var kind: String = Camp.dwelling_type(_huts - 1)
	Camp.spawn_structure(self, kind, pos, _rng.randf() * TAU)
	Events.notify.emit("Camp grows — a new %s (%d shelters)." % [kind.replace("_", " "), _huts])
	_refresh()
	_refresh_tech_buttons()


func _on_tech_pressed(tech_name: String) -> void:
	# Begin studying a tech. It does NOT complete instantly — the leader (the Thinker) must
	# stay at the fire for the band to think it through (Kainga). One study at a time.
	if _researched.get(tech_name, false) or _active_research != "":
		return
	var cost: Dictionary = RESEARCH_TECHS[tech_name]
	for id in cost:
		if int(inventory.get(id, 0)) < cost[id]:
			return
	for id in cost:
		inventory[id] = inventory[id] - cost[id]
	_active_research = tech_name
	_research_progress = 0.0
	_research_half_toasted = false
	_research_away_toasted = false
	Events.notify.emit("The band begins studying %s — keep your leader at the fire to think it through." % tech_name)
	if _think_glow != null and is_instance_valid(_think_glow):
		_think_glow.light_energy = 3.0
	_refresh()
	_refresh_tech_buttons()


func _apply_tech(tech_name: String) -> void:
	_researched[tech_name] = true
	match tech_name:
		"Stone Tools":
			food_bonus += 1
			StageObjectives.complete("tribe_tech_tools", "Researched Stone Tools")
		"Foraging":
			food_bonus += 1
			StageObjectives.complete("tribe_tech_forage", "Researched Foraging")
		"Hunting":
			_hunt_bonus += 2
			StageObjectives.complete("tribe_tech_hunt", "Researched Hunting — kills feed more")
		"Stone Weapons":
			_wolf_resist = 0.35
			_raid_factor *= 0.5
			StageObjectives.complete("tribe_tech_weapons", "Researched Stone Weapons")
		"Shelter":
			_raid_factor *= 0.5
			StageObjectives.complete("tribe_tech_shelter", "Researched Shelter")


func _research_tick(delta: float) -> void:
	if _active_research == "":
		if _think_glow != null and is_instance_valid(_think_glow):
			_think_glow.light_energy = maxf(0.0, _think_glow.light_energy - delta * 6.0)
		return
	var lp: Vector3 = _player.global_position if _player != null else CAMP_CENTER
	var rate: float = Thinker.research_rate(lp, CAMP_CENTER, THINK_RADIUS, THINK_RATE)
	var at_fire: bool = rate > 0.0
	if _think_glow != null and is_instance_valid(_think_glow):
		var target_e: float = 5.5 if at_fire else 0.4
		_think_glow.light_energy = lerpf(_think_glow.light_energy, target_e, clampf(delta * 4.0, 0.0, 1.0))
	if not at_fire and not _research_away_toasted:
		_research_away_toasted = true
		Events.notify.emit("Study paused — return to the fire to keep thinking %s." % _active_research)
	elif at_fire:
		_research_away_toasted = false
	var prev: float = _research_progress
	_research_progress = Thinker.progress(_research_progress, rate, delta)
	if prev < 0.5 and _research_progress >= 0.5 and not _research_half_toasted:
		_research_half_toasted = true
		Events.notify.emit("Half-done on %s — stay at the fire…" % _active_research)
		AudioManager.play_sfx("blip")
	if Thinker.is_complete(_research_progress):
		var done: String = _active_research
		_active_research = ""
		_research_progress = 0.0
		_research_half_toasted = false
		_research_away_toasted = false
		_apply_tech(done)
		Events.notify.emit("Discovered %s!" % done)
		AudioManager.play_sfx("chime")
		if _think_glow != null and is_instance_valid(_think_glow):
			_think_glow.light_energy = 8.0
		_refresh()
	_refresh_tech_buttons()


func _can_found() -> bool:
	# Founding a settlement is earned: a grown band that has discovered tools + shelter and built a camp.
	return population >= TARGET_POP and bool(_researched.get("Stone Tools", false)) and bool(_researched.get("Shelter", false)) and _huts >= 2


func _advance() -> void:
	if not _can_found():
		return
	EvolutionState.tribe_population = population
	Events.notify.emit("Civilization dawns — the band becomes a people.")
	AudioManager.play_sfx("win")
	Events.stage_complete.emit(EvolutionState.current_stage)


func _build_ui() -> void:
	# Shared StageChrome shell. _refresh_tech_buttons still uses
	# `b.text.begins_with(name + " (")` so button text MUST keep that shape.
	var ui: CanvasLayer = StageChromeScript.make_layer(self)
	var panel = CompactHUD.new()
	panel.configure("TRIBE", BUILD_PANEL_SIZE.x, false)
	panel.tooltip_text = "Gather resources, research survival skills, house the band, then found a settlement."
	ui.add_child(panel)
	var root: VBoxContainer = panel.content
	root.add_child(StageChromeScript.identity_row(48))
	root.add_child(StageChromeScript.h_sep())
	_season_label = StageChromeScript.status_label()
	root.add_child(_season_label)
	_pop_label = StageChromeScript.status_label()
	root.add_child(_pop_label)
	_food_label = StageChromeScript.status_label()
	root.add_child(_food_label)
	_mat_label = StageChromeScript.status_label()
	root.add_child(_mat_label)
	_goal_label = StageChromeScript.goal_label()
	root.add_child(_goal_label)
	_found_btn = StageChromeScript.make_button("FOUND CIVILIZATION", "Advance to the Civ stage when milestones are met", _advance)
	root.add_child(_found_btn)

	var tabs := BuildTabs.new()
	tabs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	var learn_grid := StageChromeScript.build_grid(1)
	tabs.add_tab("Learn", learn_grid)
	for name in RESEARCH_TECHS:
		var cost: Dictionary = RESEARCH_TECHS[name]
		var parts: PackedStringArray = []
		for id in cost:
			parts.append("%s %s" % [cost[id], id])
		var b: Button = StageChromeScript.make_button(
			"%s (%s)" % [name, " · ".join(parts)],
			"Research %s" % name,
			_on_tech_pressed.bind(name))
		learn_grid.add_child(b)
		_tech_names.append(name)
		_tech_buttons.append(b)
	_hut_btn = StageChromeScript.make_button("Build Hut", "Raise a hut to house growth", _build_hut)
	learn_grid.add_child(_hut_btn)

	var build_grid := _make_build_grid()
	tabs.add_tab("Build", build_grid)
	for z in [["gather_food", "Forage"], ["hunt", "Hunt"], ["gather_wood", "Wood"], ["gather_stone", "Stone"]]:
		var zb: Button = StageChromeScript.make_button(
			"Designate %s zone" % z[1],
			"Idle villagers will gather here",
			_designate_zone.bind(z[0]))
		build_grid.add_child(zb)
	_refresh()
	_refresh_tech_buttons()


func _make_build_grid() -> GridContainer:
	return StageChromeScript.build_grid(1)


func _refresh() -> void:
	if _season_label:
		_season_label.text = "Year %d · %s · %s" % [_year, _season.capitalize(), str(_biome.get("name", "Grassland"))]
	if _pop_label:
		var ch: int = 0
		var ad: int = 0
		var el: int = 0
		for v in _people:
			match str(v.get("stage", "adult")):
				"child": ch += 1
				"elder": el += 1
				_: ad += 1
		var cap2: int = _capacity()
		_pop_label.text = "Pop %d/%d · housed %d/%d · %dc %da %de" % [
			population, TARGET_POP, mini(ad, cap2), cap2, ch, ad, el,
		]
	if _food_label:
		_food_label.text = "Food %d" % food
	if _mat_label:
		var parts: PackedStringArray = []
		for id in inventory:
			parts.append("%s %d" % [id, inventory[id]])
		_mat_label.text = "Materials " + (" · ".join(parts) if parts.size() > 0 else "—")
	var can_found: bool = _can_found()
	if _goal_label:
		if can_found:
			_goal_label.text = "READY · found your civilization"
			if not bool(get_meta("_found_ready_toasted", false)):
				set_meta("_found_ready_toasted", true)
				Events.notify.emit("Band ready — Found Civilization when you are.")
				StageObjectives.complete("tribe_ready", "Found gates met — launch civilization")
		else:
			var needs: PackedStringArray = []
			if population < TARGET_POP:
				needs.append("pop %d/%d" % [population, TARGET_POP])
			if not _researched.get("Stone Tools", false):
				needs.append("Stone Tools")
			if not _researched.get("Shelter", false):
				needs.append("Shelter")
			if _huts < 2:
				needs.append("huts %d/2" % _huts)
			_goal_label.text = "Goal · " + " · ".join(needs)
			# One-left coaching so the last gate is obvious.
			if needs.size() == 1 and not bool(get_meta("_one_left_toasted", false)):
				set_meta("_one_left_toasted", true)
				Events.notify.emit("Almost a settlement — still need: %s" % needs[0])
	if _found_btn:
		_found_btn.disabled = not can_found


func _refresh_tech_buttons() -> void:
	for i in _tech_buttons.size():
		var tname: String = _tech_names[i]
		var btn: Button = _tech_buttons[i]
		if _researched.get(tname, false):
			btn.disabled = true
			btn.text = tname + " ✓"
		elif tname == _active_research:
			btn.disabled = true
			btn.text = "%s … thinking %d%%" % [tname, int(round(_research_progress * 100.0))]
		else:
			var cost: Dictionary = RESEARCH_TECHS[tname]
			var affordable: bool = true
			for id in cost:
				if int(inventory.get(id, 0)) < cost[id]:
					affordable = false
					break
			# Can't begin a new study while the Thinker is busy with one.
			btn.disabled = (not affordable) or (_active_research != "")
			var parts: PackedStringArray = []
			for id in cost:
				parts.append("%s %s" % [cost[id], id])
			btn.text = "%s (%s)" % [tname, " · ".join(parts)]
	if _hut_btn:
		_hut_btn.text = "Build Hut (%d wood) — huts: %d" % [int(HUT_COST.wood), _huts]
		_hut_btn.disabled = int(inventory.get("wood", 0)) < int(HUT_COST.wood)


func capture() -> Dictionary:
	return {
		"version": 1,
		"population": population,
		"food": food,
		"inventory": inventory.duplicate(),
		"food_bonus": food_bonus,
		"hunt_bonus": _hunt_bonus,
		"raid_factor": _raid_factor,
		"researched": _researched.duplicate(),
		"wolf_resist": _wolf_resist,
		"huts": _huts,
		"spawn_timer": _spawn_t,
		"animal_timer": _animal_t,
		"food_accum": _food_accum,
		"species": _species,
		"people": _capture_people(),
		"elapsed": _elapsed,
		"year": _year,
		"season": _season,
		"zones": _capture_zones(),
		"eco": _eco.duplicate(),
		"work_accum": _work_accum.duplicate(),
		"active_research": _active_research,
		"research_progress": _research_progress,
		"player_position": _vec3_to_dict(_player.position if _player != null else CAMP_CENTER),
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	population = maxi(1, int(data.get("population", population)))
	food = maxi(0, int(data.get("food", food)))
	var inv_val: Variant = data.get("inventory", {})
	if inv_val is Dictionary:
		inventory = (inv_val as Dictionary).duplicate()
	food_bonus = int(data.get("food_bonus", food_bonus))
	_hunt_bonus = int(data.get("hunt_bonus", _hunt_bonus))
	_raid_factor = _finite_float(data.get("raid_factor", _raid_factor), _raid_factor)
	var researched_val: Variant = data.get("researched", {})
	if researched_val is Dictionary:
		_researched = (researched_val as Dictionary).duplicate()
	_wolf_resist = _finite_float(data.get("wolf_resist", _wolf_resist), _wolf_resist)
	_huts = maxi(0, int(data.get("huts", _huts)))
	_spawn_t = maxf(0.0, _finite_float(data.get("spawn_timer", _spawn_t), _spawn_t))
	_animal_t = maxf(0.0, _finite_float(data.get("animal_timer", _animal_t), _animal_t))
	_food_accum = maxf(0.0, _finite_float(data.get("food_accum", _food_accum), _food_accum))
	_species = str(data.get("species", _species))
	_restore_people(data.get("people", []))
	_elapsed = maxf(0.0, _finite_float(data.get("elapsed", _elapsed), _elapsed))
	_year = maxi(0, int(data.get("year", _year)))
	_season = str(data.get("season", _season))
	_restore_dictionary(data.get("eco", {}), _eco)
	_restore_dictionary(data.get("work_accum", {}), _work_accum)
	_active_research = str(data.get("active_research", _active_research))
	_research_progress = clampf(_finite_float(data.get("research_progress", _research_progress), _research_progress), 0.0, 1.0)
	if _player != null:
		_player.position = _dict_to_vec3(data.get("player_position", {}), _player.position)
	_restore_hut_visuals()
	_restore_zones(data.get("zones", []))
	_sync_band()
	_refresh()
	_refresh_tech_buttons()


func _capture_people() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for person_val: Variant in _people:
		if person_val is Dictionary:
			out.append((person_val as Dictionary).duplicate())
	return out


func _restore_people(value: Variant) -> void:
	_people.clear()
	if value is Array:
		for person_val: Variant in value:
			if person_val is Dictionary:
				_people.append((person_val as Dictionary).duplicate())
	if _people.is_empty():
		_init_people()
	else:
		population = _people.size()


func _capture_zones() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for zone_val: Variant in _zones:
		if not (zone_val is Dictionary):
			continue
		var zone: Dictionary = zone_val
		var area: Dictionary = zone.get("area", {})
		out.append({
			"kind": str(area.get("kind", "gather_food")),
			"pos": _vec3_to_dict(area.get("pos", CAMP_CENTER)),
			"radius": _finite_float(area.get("radius", ZONE_RADIUS), ZONE_RADIUS),
			"max_workers": int(area.get("max_workers", ZONE_MAX_WORKERS)),
		})
	return out


func _restore_zones(value: Variant) -> void:
	for zone_val: Variant in _zones:
		if zone_val is Dictionary:
			var marker: Node3D = (zone_val as Dictionary).get("marker", null)
			if is_instance_valid(marker):
				marker.queue_free()
	_zones.clear()
	if not (value is Array):
		return
	for item: Variant in value:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item
		var kind: String = str(entry.get("kind", "gather_food"))
		var pos: Vector3 = _dict_to_vec3(entry.get("pos", {}), CAMP_CENTER)
		var area: Dictionary = WorkArea.make_area(pos, _finite_float(entry.get("radius", ZONE_RADIUS), ZONE_RADIUS), kind, int(entry.get("max_workers", ZONE_MAX_WORKERS)))
		var marker: Node3D = _make_zone_marker(kind, pos)
		add_child(marker)
		_zones.append({"area": area, "marker": marker})


func _restore_hut_visuals() -> void:
	for i: int in range(_huts):
		var pos: Vector3 = CAMP_CENTER + Vector3(-16.0 + float(i % 6) * 6.0, 0.0, 12.0 + float(i / 6) * 5.0)
		Camp.spawn_structure(self, Camp.dwelling_type(i), pos, float(i) * 0.41)


func _restore_dictionary(value: Variant, target: Dictionary) -> void:
	if not (value is Dictionary):
		return
	target.clear()
	for key: Variant in (value as Dictionary).keys():
		target[str(key)] = (value as Dictionary)[key]


func _vec3_to_dict(value: Variant) -> Dictionary:
	var v: Vector3 = value if value is Vector3 else Vector3.ZERO
	return {"x": v.x, "y": v.y, "z": v.z}


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
