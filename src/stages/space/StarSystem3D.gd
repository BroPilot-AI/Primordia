class_name StarSystem3D extends Node3D
## A star system as a real 3D body: an emissive star, orbiting textured planets, and a flat
## faction-ownership ring on the galaxy plane (y=0). Mostly data + visuals; SpaceStage3D drives
## capture/ownership. `faction`: -1 neutral, 0 player, >=1 an AI empire. Owning every system wins.
## (Named `faction`, not `owner` — `owner` is a reserved Node property.)

const EVO_NAMES := ["Primordial", "Creature", "Tribe", "Civ", "Space"]

# Real stellar classification (Morgan–Keenan) + two evolved types — weights ≈ galactic frequency.
const STAR_CLASSES := [
	{cls = "O", color = Color(0.62, 0.72, 1.00), size = 1.70, weight = 1,  pmin = 0, pmax = 2, hz = 0.85},
	{cls = "B", color = Color(0.72, 0.82, 1.00), size = 1.45, weight = 3,  pmin = 0, pmax = 3, hz = 0.75},
	{cls = "A", color = Color(0.94, 0.96, 1.00), size = 1.20, weight = 6,  pmin = 1, pmax = 4, hz = 0.62},
	{cls = "F", color = Color(1.00, 0.98, 0.86), size = 1.06, weight = 11, pmin = 1, pmax = 5, hz = 0.55},
	{cls = "G", color = Color(1.00, 0.93, 0.62), size = 1.00, weight = 15, pmin = 2, pmax = 7, hz = 0.45},
	{cls = "K", color = Color(1.00, 0.76, 0.46), size = 0.84, weight = 22, pmin = 2, pmax = 7, hz = 0.36},
	{cls = "M", color = Color(1.00, 0.52, 0.42), size = 0.64, weight = 30, pmin = 1, pmax = 6, hz = 0.26},
	{cls = "Red Giant",   color = Color(1.00, 0.45, 0.30), size = 2.30, weight = 5, pmin = 0, pmax = 2, hz = 0.70},
	{cls = "White Dwarf", color = Color(0.85, 0.90, 1.00), size = 0.40, weight = 4, pmin = 0, pmax = 1, hz = 0.30},
]
const ZONE_HOT := ["volcanic", "barren", "desert"]
const ZONE_HAB := ["terran", "ocean", "jungle", "desert"]
const ZONE_COLD := ["gas", "ice", "barren"]

# Planet kind → (texture stem, tint). We only have 4 real maps; others reuse + tint.
const PLANET_TEX := {
	"terran":   ["planet_terran", Color(1, 1, 1)],
	"ocean":    ["planet_terran", Color(0.7, 0.85, 1.1)],
	"jungle":   ["planet_terran", Color(0.8, 1.05, 0.8)],
	"desert":   ["planet_barren", Color(1.15, 1.0, 0.7)],
	"barren":   ["planet_barren", Color(1, 1, 1)],
	"volcanic": ["planet_lava",   Color(1, 1, 1)],
	"gas":      ["planet_terran", Color(1.1, 0.9, 0.7)],
	"ice":      ["planet_ice",    Color(1, 1, 1)],
}

# Stylized cel/banded planet shader (complements the flat low-poly look — see assets/shaders).
const PLANET_SHADER := preload("res://assets/shaders/planet_stylized.gdshader")
# CC0 moon model — orbits random planets (nested orbits, like real systems).
const MOON_MODEL := preload("res://assets/models/space_structures/moon.glb")
# Living galaxy: neutral worlds tint their ring by evolution stage. Preloaded
# (not the global class_name) so a fresh GalaxySim.gd resolves before an editor rescan.
const GSim := preload("res://src/stages/space/GalaxySim.gd")

# Per-kind palette: low surface, high surface, accent (cap/lava/sand), emission color + strength,
# band count (lower = flatter), noise scale. Tuned subtle so planets read as low-poly, not noisy.
const PLANET_PAL := {
	"terran":   {low = Color(0.10, 0.28, 0.52), high = Color(0.34, 0.54, 0.30), accent = Color(0.84, 0.80, 0.60), emit = Color.BLACK, es = 0.0, bands = 4.0, ns = 2.6},
	"ocean":    {low = Color(0.07, 0.20, 0.46), high = Color(0.18, 0.44, 0.64), accent = Color(0.72, 0.86, 0.90), emit = Color.BLACK, es = 0.0, bands = 4.0, ns = 2.4},
	"jungle":   {low = Color(0.10, 0.30, 0.20), high = Color(0.30, 0.55, 0.25), accent = Color(0.62, 0.70, 0.35), emit = Color.BLACK, es = 0.0, bands = 4.0, ns = 2.8},
	"desert":   {low = Color(0.58, 0.42, 0.24), high = Color(0.80, 0.64, 0.40), accent = Color(0.92, 0.84, 0.62), emit = Color.BLACK, es = 0.0, bands = 4.0, ns = 2.6},
	"barren":   {low = Color(0.28, 0.26, 0.24), high = Color(0.50, 0.46, 0.42), accent = Color(0.66, 0.61, 0.56), emit = Color.BLACK, es = 0.0, bands = 5.0, ns = 3.0},
	"volcanic": {low = Color(0.16, 0.11, 0.10), high = Color(0.34, 0.20, 0.15), accent = Color(1.00, 0.45, 0.12), emit = Color(1.0, 0.35, 0.06), es = 2.2, bands = 4.0, ns = 2.8},
	"gas":      {low = Color(0.50, 0.40, 0.56), high = Color(0.72, 0.60, 0.74), accent = Color(0.88, 0.80, 0.62), emit = Color.BLACK, es = 0.0, bands = 6.0, ns = 2.2},
	"ice":      {low = Color(0.54, 0.70, 0.82), high = Color(0.80, 0.88, 0.95), accent = Color(0.96, 0.98, 1.00), emit = Color.BLACK, es = 0.0, bands = 4.0, ns = 2.6},
}

var system_name := ""
var star_class := "G"
var faction := -1
var faction_color := Color(0.55, 0.55, 0.62)
var contender := -1
var capture := 0.0
var structure := ""        # "" | one of SpaceStage3D.STRUCTURES
# Additive stations built on top of (or in parallel with) `structure`. A system can
# hold any number — refinery/sensor_array/etc. They cost metal+energy + build_time
# and are gated by system tier (see StationStats.stations_for_tier).
var stations: Array[String] = []
var shielded := false
var has_shipyard := false
var evo_stage := 0
var evo_progress := 0.0
var emergent_ready := false
var bodies: Array[String] = []

var _star: MeshInstance3D
var _ring: MeshInstance3D
var _struct_marker: Node3D
var _planets: Array = []   # [{node, radius, angle, speed, moons}]
var _belt: MultiMeshInstance3D = null   # asteroid belt (some systems)
var _nameplate: Label3D = null          # front-line / selected system label


func _ready() -> void:
	add_to_group("system3d")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d_%d" % [EvolutionState.world_seed, int(position.x), int(position.z)])
	var star: Dictionary = _pick_star(rng)
	star_class = str(star.cls)
	bodies = ["energy"]

	# Emissive star sphere — glows under the WorldEnvironment bloom.
	_star = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.6 * float(star.size)
	sm.height = sm.radius * 2.0
	_star.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = star.color
	smat.emission_enabled = true
	smat.emission = star.color
	smat.emission_energy_multiplier = 2.4
	smat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	_star.material_override = smat
	add_child(_star)

	# Ownership ring — flat torus on the galaxy plane.
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.outer_radius = 4.0
	torus.inner_radius = 3.6
	_ring.mesh = torus
	_ring.rotation_degrees = Vector3(90, 0, 0)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = faction_color
	_ring.material_override = rmat
	_ring.position = Vector3(0, 0.05, 0)
	add_child(_ring)

	_generate_planets(rng, star)
	_make_belt(rng, star)
	evo_stage = rng.randi_range(0, 3)
	evo_progress = rng.randf()
	_ensure_nameplate()
	_refresh()


## Billboarding label for war-front / selected systems (driven by SpaceStage3D).
func _ensure_nameplate() -> void:
	if _nameplate != null and is_instance_valid(_nameplate):
		return
	_nameplate = Label3D.new()
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.font_size = 42
	_nameplate.outline_size = 10
	_nameplate.outline_modulate = Color(0, 0, 0, 0.85)
	_nameplate.modulate = Color(1.0, 0.92, 0.75)
	_nameplate.position = Vector3(0, 5.2, 0)
	_nameplate.visible = false
	_nameplate.no_depth_test = true
	add_child(_nameplate)
	_refresh_nameplate_text()


func set_nameplate_visible(on: bool, front: bool = false, contested: bool = false) -> void:
	_ensure_nameplate()
	_nameplate.visible = on
	if not on:
		return
	_refresh_nameplate_text()
	if contested:
		_nameplate.modulate = Color(1.0, 0.82, 0.35)
		_nameplate.text = "⚔ %s" % system_name
	elif front:
		_nameplate.modulate = Color(1.0, 0.55, 0.4)
		_nameplate.text = "▲ %s" % system_name
	else:
		_nameplate.modulate = Color(0.85, 0.95, 1.0)
		_nameplate.text = system_name


func _refresh_nameplate_text() -> void:
	if _nameplate == null:
		return
	if system_name != "":
		_nameplate.text = system_name


func _pick_star(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for s in STAR_CLASSES:
		total += int(s.weight)
	var roll := rng.randi_range(1, total)
	for s in STAR_CLASSES:
		roll -= int(s.weight)
		if roll <= 0:
			return s
	return STAR_CLASSES[4]


func _generate_planets(rng: RandomNumberGenerator, star: Dictionary) -> void:
	var n := rng.randi_range(int(star.pmin), int(star.pmax))
	if n <= 0:
		return
	var hz: float = float(star.hz)
	for i in n:
		var pn := (i + 1.0) / (n + 1.0)
		var pool: Array
		if pn < hz - 0.14:
			pool = ZONE_HOT
		elif pn > hz + 0.16:
			pool = ZONE_COLD
		else:
			pool = ZONE_HAB
		var kind: String = pool[rng.randi_range(0, pool.size() - 1)]
		var node := _make_planet(kind, rng)
		bodies.append("biomass")
		_planets.append({
			node = node,
			radius = 2.6 * float(star.size) + i * 1.3 + rng.randf_range(0.0, 0.6),
			angle = rng.randf() * TAU,
			speed = rng.randf_range(0.15, 0.5) * (1.0 if rng.randf() < 0.5 else -1.0) / (1.0 + i * 0.25),
			moons = _make_moons(node, rng),
		})


# ~45% of planets get a moon (occasionally two) — a real grey cratered moon on a tighter,
# faster orbit around its parent planet. Added as a child so it tracks the planet's motion.
func _make_moons(planet: MeshInstance3D, rng: RandomNumberGenerator) -> Array:
	var moons: Array = []
	if rng.randf() > 0.45:
		return moons
	var pr: float = (planet.mesh as SphereMesh).radius
	var count: int = 1 if rng.randf() < 0.82 else 2
	for j in count:
		var moon: Node3D = MOON_MODEL.instantiate()
		planet.add_child(moon)
		_fit_struct(moon, pr * 0.2)   # tiny vs the planet, like real moons
		bodies.append("water")
		moons.append({
			node = moon,
			radius = pr * (1.5 + j * 0.6),
			angle = rng.randf() * TAU,
			speed = rng.randf_range(1.2, 2.8) * (1.0 if rng.randf() < 0.5 else -1.0),
		})
	return moons


# ~35% of systems get an asteroid belt — a ring of small rocks (MultiMesh for cheap density),
# slowly rotating around the star.
func _make_belt(rng: RandomNumberGenerator, star: Dictionary) -> void:
	if rng.randf() > 0.35:
		return
	bodies.append("metal")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var rock := SphereMesh.new()
	rock.radius = 0.13
	rock.height = 0.26
	rock.radial_segments = 5
	rock.rings = 3
	mm.mesh = rock
	var n := 70
	mm.instance_count = n
	var br: float = 2.0 * float(star.size) + rng.randf_range(3.5, 6.0)
	for i in n:
		var a: float = rng.randf() * TAU
		var rr: float = br + rng.randf_range(-0.7, 0.7)
		var basis := Basis().scaled(Vector3.ONE * rng.randf_range(0.4, 1.6))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(cos(a) * rr, rng.randf_range(-0.25, 0.25), sin(a) * rr)))
	_belt = MultiMeshInstance3D.new()
	_belt.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.40, 0.36)
	mat.roughness = 0.95
	_belt.material_override = mat
	add_child(_belt)


func _make_planet(kind: String, rng: RandomNumberGenerator) -> MeshInstance3D:
	var pal: Dictionary = PLANET_PAL.get(kind, PLANET_PAL["barren"])
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	var r := (1.0 if kind == "gas" else 0.55) + rng.randf_range(0.0, 0.25)
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	var mat := ShaderMaterial.new()
	mat.shader = PLANET_SHADER
	mat.set_shader_parameter("color_low", pal.low)
	mat.set_shader_parameter("color_high", pal.high)
	mat.set_shader_parameter("color_accent", pal.accent)
	mat.set_shader_parameter("emission_color", pal.emit)
	mat.set_shader_parameter("emission_strength", pal.es)
	mat.set_shader_parameter("bands", pal.bands)
	mat.set_shader_parameter("noise_scale", pal.ns)
	mat.set_shader_parameter("seed", rng.randf() * 100.0)
	mi.material_override = mat
	# Gas giants get a Saturn-style ring.
	if kind == "gas":
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r * 1.4
		tm.outer_radius = r * 2.3
		ring.mesh = tm
		ring.rotation_degrees = Vector3(rng.randf_range(12.0, 28.0), 0.0, rng.randf_range(-15.0, 15.0))
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.85, 0.78, 0.6, 0.55)
		rmat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		rmat.cull_mode = StandardMaterial3D.CULL_DISABLED
		ring.material_override = rmat
		mi.add_child(ring)
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	for p in _planets:
		p.angle += p.speed * delta
		p.node.position = Vector3(cos(p.angle), 0.0, sin(p.angle)) * p.radius
		for m in p.get("moons", []):
			m.angle += m.speed * delta
			m.node.position = Vector3(cos(m.angle), 0.0, sin(m.angle)) * m.radius   # orbits the planet (local)
	if _belt != null:
		_belt.rotate_y(delta * 0.05)   # asteroid belt drifts


func set_faction(f: int, col: Color) -> void:
	faction = f
	faction_color = col
	contender = -1
	capture = 0.0
	structure = ""
	stations = []
	shielded = false
	has_shipyard = false
	_refresh()


# True if this system already has the given station built. Used to gate queue + button.
func has_station(kind: String) -> bool:
	return stations.has(kind)


# Add a station id to this system (no-op if already built).
func add_station(kind: String) -> void:
	if not stations.has(kind):
		stations.append(kind)


# Real station models for built structures (generated Space heroes) + target heights.
const STRUCT_MODELS := {
	"Shipyard": "res://assets/models/generated/space/shipyard.glb",
	"SolarCollector": "res://assets/models/generated/space/solar_collector.glb",
	"Bastion": "res://assets/models/generated/space/bastion.glb",
	"Annihilator": "res://assets/models/generated/space/annihilator.glb",
	"ResearchLab": "res://assets/models/generated/space/research_lab.glb",
	"HabitatRing": "res://assets/models/generated/space/habitat_ring.glb",
	"MiningRig": "res://assets/models/generated/space/mining_rig.glb",
	"JumpGate": "res://assets/models/generated/space/jump_gate.glb",
}
const STRUCT_SCALE := {
	"Shipyard": 4.2,
	"SolarCollector": 3.2,
	"Bastion": 3.4,
	"Annihilator": 5.2,
	"ResearchLab": 3.4,
	"HabitatRing": 4.4,
	"MiningRig": 3.3,
	"JumpGate": 4.8,
}


# Normalize a station model to a target height (sources vary wildly in native scale/origin).
func _fit_struct(node: Node3D, target_height: float) -> void:
	var box := _root_aabb(node)
	if box.size.y <= 0.001:
		return
	var scale_factor: float = target_height / box.size.y
	node.scale = Vector3.ONE * scale_factor
	var center_x: float = box.position.x + box.size.x * 0.5
	var center_z: float = box.position.z + box.size.z * 0.5
	node.position.x -= center_x * scale_factor
	node.position.y -= box.position.y * scale_factor
	node.position.z -= center_z * scale_factor


func _root_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var have := false
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = _local_to_root(mi, root) * mi.mesh.get_aabb()
		if not have:
			box = b
			have = true
		else:
			box = box.merge(b)
	return box if have else AABB(Vector3.ZERO, Vector3.ONE)


func _local_to_root(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != root:
		t = cur.transform * t
		cur = cur.get_parent() as Node3D
	return t


func set_structure(kind: String) -> void:
	structure = kind
	shielded = (kind == "Bastion")
	has_shipyard = (kind == "Shipyard")
	_refresh()


func _refresh() -> void:
	_update_ring_tint()
	_refresh_struct_marker()


# Cheap ring recolor (no marker rebuild) — safe to call every frame from tick_evolution.
# Neutral worlds glow by how far up the evolution ladder they've climbed (GalaxySim);
# owned worlds show their flat faction color.
func _update_ring_tint() -> void:
	if _ring == null:
		return
	var col: Color = faction_color
	if faction < 0:
		col = GSim.evo_ring_color(faction_color, evo_stage, evo_progress)
	(_ring.material_override as StandardMaterial3D).albedo_color = col


# A small floating marker above the star for the built structure (dock / shield / death-star).
func _refresh_struct_marker() -> void:
	if _struct_marker != null and is_instance_valid(_struct_marker):
		_struct_marker.queue_free()
	_struct_marker = null
	if structure == "":
		return
	var path: String = str(STRUCT_MODELS.get(structure, ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var node: Node3D = packed.instantiate()
	add_child(node)
	Stage3D.matte_materials(node)
	node.position = Vector3(0, 4.5, 0)
	_fit_struct(node, float(STRUCT_SCALE.get(structure, 3.0)))
	if structure == "Annihilator":
		for n in node.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null:
				continue
			for si in mi.mesh.get_surface_count():
				var src: Material = mi.get_active_material(si)
				var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
				m.albedo_color = m.albedo_color.lerp(Color(0.9, 0.15, 0.15), 0.55)
				m.emission_enabled = true
				m.emission = Color(0.9, 0.1, 0.1)
				m.emission_energy_multiplier = 0.8
				mi.set_surface_override_material(si, m)
	_struct_marker = node


func tick_evolution(delta: float, rate: float) -> void:
	if evo_stage >= 4:
		return
	evo_progress += rate * delta
	if evo_progress >= 1.0:
		evo_progress = 0.0
		evo_stage += 1
		if evo_stage >= 4:
			evo_stage = 4
			emergent_ready = true
	# Brighten the ring as the world matures — the player watches life arise.
	_update_ring_tint()


func evo_name() -> String:
	return EVO_NAMES[clampi(evo_stage, 0, 4)]
