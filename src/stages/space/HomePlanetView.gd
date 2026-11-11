## "Return to your homeworld" overlay (Space). Regenerates a modern-era view of the Civ planet
## from EvolutionState.civ_planet_snapshot (city cells remapped from the full Civ grid) and
## StageChrome chrome. Opened from the home system / Homeworld button; close returns to stars.
class_name HomePlanetView
extends CanvasLayer

const CIV_BLDG := "res://assets/models/civ_buildings/%s.glb"
const MODERN_DIR := "res://assets/models/generated/civ_modern/"
const MODERN_BUILDINGS: Array[String] = [
	"apartment_block", "office_tower_glass", "tenement_brick", "clock_tower", "warehouse_brick",
]
## Civ stage grid (snapshot cells are written in this space).
const CIV_COLS := 56
const CIV_ROWS := 40
const COLS := 18
const ROWS := 12
const TILE := 2.0
## Civ building kind -> the same farm-era model it used, steel-upgraded around its city.
const STRUCTURE_MODELS := {"House": "house", "Granary": "storage", "Barracks": "barracks", "Spaceport": "port"}
const STRUCTURES_PER_RING := 6
const MAX_STRUCTURES_PER_CITY := 12

const C_WATER := Color(0.07, 0.15, 0.33)
const C_LAND := Color(0.20, 0.38, 0.30)
const STEEL := Color(0.55, 0.75, 0.98)


func _ready() -> void:
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var dim := StageChrome.dim_rect()
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dim)

	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cont)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(1280, 720)
	cont.add_child(vp)
	_build_scene(vp)

	var title := StageChrome.era_label("HOME — %s · modern era" % _planet_label())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(title)

	var hint := StageChrome.hint_label("Your Civ cities and buildings, steel-arcology upgrade · Esc / button to return")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 72
	hint.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hint)

	var close := StageChrome.make_button("↩ Return to the stars", "Close homeworld overlay", _close)
	close.process_mode = Node.PROCESS_MODE_ALWAYS
	close.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	close.offset_top = -64
	close.offset_bottom = -24
	close.offset_left = -160
	close.offset_right = 160
	add_child(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	get_tree().paused = false
	queue_free()


func _planet_label() -> String:
	if EvolutionState.planet_name != "":
		return EvolutionState.planet_name
	return "your world"


func _build_scene(vp: SubViewport) -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.48, 0.82)
	sky_mat.sky_horizon_color = Color(0.78, 0.84, 0.90)
	sky_mat.ground_bottom_color = Color(0.08, 0.12, 0.16)
	sky_mat.ground_horizon_color = Color(0.35, 0.42, 0.48)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.45, 0.55, 0.68)
	env.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	vp.add_child(sun)

	var world := Node3D.new()
	vp.add_child(world)
	var land_w := COLS * TILE
	var land_d := ROWS * TILE
	_add_colored_box(world, Vector3(land_w * 1.6, 0.18, land_d * 1.6), Vector3(0, -0.2, 0), C_WATER)
	_add_colored_box(world, Vector3(land_w, 0.45, land_d), Vector3(0, 0.05, 0), C_LAND)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(EvolutionState.world_seed) + "_home")
	var cities: Array = EvolutionState.civ_planet_snapshot.get("cities", [])
	var city_pos: Array[Vector3] = []
	for cell_v in cities:
		var cell: Vector2i = _as_cell(cell_v)
		var hx: int = _remap(cell.x, CIV_COLS, COLS)
		var hy: int = _remap(cell.y, CIV_ROWS, ROWS)
		city_pos.append(Vector3(
			(float(hx) + 0.5) * TILE - land_w * 0.5,
			0.3,
			(float(hy) + 0.5) * TILE - land_d * 0.5,
		))
	if city_pos.is_empty():
		city_pos = [
			Vector3(-3.0, 0.3, -2.0), Vector3(1.5, 0.3, -1.2), Vector3(3.2, 0.3, 1.8),
			Vector3(-1.0, 0.3, 2.4), Vector3(0.2, 0.3, 0.0),
		]
	for i in city_pos.size():
		_place_modern(world, city_pos[i], i)
	_place_structures(world, cities, city_pos)
	for _t in 8:
		var tp := Vector3(rng.randf_range(-land_w * 0.44, land_w * 0.44), 0.3, rng.randf_range(-land_d * 0.44, land_d * 0.44))
		var blocked := false
		for cpos in city_pos:
			if tp.distance_to(cpos) < 4.5:
				blocked = true
				break
		if not blocked:
			WorldProps.spawn_tree(world, tp, rng)

	var cam := Camera3D.new()
	vp.add_child(cam)
	var span: float = maxf(COLS, ROWS) * TILE
	cam.look_at_from_position(Vector3(0, span * 0.48, span * 0.78), Vector3(0, 0.4, 0), Vector3.UP)
	cam.current = true


func _add_colored_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var tile := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	tile.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	tile.material_override = m
	tile.position = pos
	parent.add_child(tile)


func _modern_path(index: int) -> String:
	var stem: String = MODERN_BUILDINGS[index % MODERN_BUILDINGS.size()]
	var path := MODERN_DIR + stem + ".glb"
	if ResourceLoader.exists(path):
		return path
	return CIV_BLDG % "farmhouse"


func _place_modern(world: Node3D, pos: Vector3, index: int) -> void:
	var path := _modern_path(index)
	var packed := load(path) as PackedScene
	if packed == null:
		_add_colored_box(world, Vector3(TILE * 0.7, TILE * 0.9, TILE * 0.7), pos + Vector3(0, TILE * 0.45, 0), STEEL)
		return
	var b: Node3D = packed.instantiate()
	world.add_child(b)
	b.position = pos
	_fit(b, TILE * 2.4)
	if not path.begins_with(MODERN_DIR):
		_steel(b)
	else:
		Stage3D.matte_materials(b)


## Each saved Civ structure stands, steel-upgraded, in rings around the city it was built in.
func _place_structures(world: Node3D, cities: Array, city_pos: Array[Vector3]) -> void:
	var per_city := {}
	for s in EvolutionState.civ_planet_snapshot.get("structures", []):
		if not (s is Dictionary):
			continue
		var ci := -1
		var cell: Vector2i = _as_cell(s.get("cell"))
		for i in cities.size():
			if _as_cell(cities[i]) == cell:
				ci = i
		var slot: int = int(per_city.get(ci, 0))
		if ci < 0 or slot >= MAX_STRUCTURES_PER_CITY:
			continue
		per_city[ci] = slot + 1
		var ang: float = TAU * float(slot % STRUCTURES_PER_RING) / STRUCTURES_PER_RING
		var radius: float = TILE * (1.3 + 0.9 * floorf(float(slot) / STRUCTURES_PER_RING))
		var pos: Vector3 = city_pos[ci] + Vector3(cos(ang), 0.0, sin(ang)) * radius
		var packed := load(CIV_BLDG % STRUCTURE_MODELS.get(str(s.get("kind", "")), "house")) as PackedScene
		if packed == null:
			_add_colored_box(world, Vector3.ONE * TILE * 0.4, pos + Vector3(0, TILE * 0.2, 0), STEEL)
			continue
		var b: Node3D = packed.instantiate()
		world.add_child(b)
		b.position = pos
		_fit(b, TILE * 0.9)
		_steel(b)


func _as_cell(v: Variant) -> Vector2i:
	if v is Vector2i:
		return v
	if v is Dictionary:
		return Vector2i(int(v.get("x", 0)), int(v.get("y", 0)))
	if v is Array and (v as Array).size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i(COLS / 2, ROWS / 2)


func _remap(v: int, from_max: int, to_max: int) -> int:
	if from_max <= 1:
		return to_max / 2
	var t: float = clampf(float(v) / float(from_max - 1), 0.0, 1.0)
	return clampi(int(round(t * float(to_max - 1))), 0, to_max - 1)


func _fit(node: Node3D, target: float) -> void:
	var box := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.transform * mi.mesh.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	var dim: float = maxf(box.size.x, box.size.z)
	if dim > 0.0:
		node.scale = Vector3.ONE * (target / dim)


func _steel(node: Node3D) -> void:
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
			m.albedo_color = m.albedo_color.lerp(STEEL, 0.5)
			m.metallic = 0.6
			m.roughness = 0.35
			m.emission_enabled = true
			m.emission = Color(0.3, 0.7, 1.0)
			m.emission_energy_multiplier = 0.25
			mi.set_surface_override_material(s, m)
