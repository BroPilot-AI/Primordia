class_name Stage3D extends Node3D


func _build_environment(preset: String) -> void:
	var env: Environment = Environment.new()
	match preset:
		"space":
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.03, 0.04, 0.09)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.42, 0.48, 0.64)
			env.ambient_light_energy = 0.9
			env.glow_enabled = true
			env.glow_intensity = 0.18
			env.glow_bloom = 0.04
		"outdoor":
			var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
			sky_mat.sky_top_color = Color(0.32, 0.52, 0.85)
			sky_mat.sky_horizon_color = Color(0.78, 0.85, 0.92)
			sky_mat.ground_horizon_color = Color(0.62, 0.66, 0.60)
			sky_mat.ground_bottom_color = Color(0.42, 0.46, 0.40)
			sky_mat.sun_angle_max = 30.0
			var sky: Sky = Sky.new()
			sky.sky_material = sky_mat
			env.background_mode = Environment.BG_SKY
			env.sky = sky
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_energy = 0.6   # lower = more contrast and warm-sun pop; brighter washes out forms
			# SSAO lays the dark contact crease where props/units meet the
			# ground so nothing reads as a floating sticker. Plus a subtle glow for stylized pop.
			env.ssao_enabled = true
			env.ssao_radius = 1.6
			env.ssao_intensity = 2.2
			env.ssao_power = 1.5
			env.glow_enabled = true
			env.glow_intensity = 0.3
			env.glow_bloom = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_sun() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_energy = 1.55
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.1
	sun.shadow_blur = 1.5            # soft shadow edge — hard edges read cheap on low-poly
	sun.directional_shadow_max_distance = 400.0   # cover the bigger map so distant shadows don't pop
	add_child(sun)


func _build_camera(focus: Vector3, size: float) -> void:
	var cam: Camera3D = Camera3D.new()
	cam.set_script(load("res://src/common/RTSCamera3D.gd"))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	cam.edge_margin = 6
	add_child(cam)
	# The two-level RTSCamera3D owns its own placement (focus + tilt); just hand it the focus.
	cam.set_focus(focus)
	cam.current = true


func spawn_model(path: String, pos: Vector3, scale: float = 1.0, yaw: float = 0.0, tint: Color = Color(0, 0, 0, 0)) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Stage3D: missing model %s" % path)
		return null
	var inst: Node3D = packed.instantiate()
	inst.position = pos
	inst.scale = Vector3.ONE * scale
	inst.rotation_degrees = Vector3(0, yaw, 0)
	add_child(inst)
	matte_materials(inst)   # first: the vertex-color copy then starts matte instead of being edited after
	_enable_vertex_colors(inst)
	if tint.a > 0.0:
		tint_model(inst, tint)
	return inst


# Kenney kits color via a shared `Textures/colormap.png` that isn't shipped with the bare .glb
# downloads, so models import white. Until/unless that atlas is restored, give models a deliberate
# flat albedo by category — the clean low-poly RTS look (Godot Open-RTS style).
static func tint_model(root: Node, color: Color) -> void:
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for n in meshes:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m: StandardMaterial3D = StandardMaterial3D.new()
			m.albedo_color = color
			m.roughness = 0.85
			mi.set_surface_override_material(s, m)


# One matte copy per imported material, shared by every instance. A per-instance copy is freed with
# its mesh while the render instance still holds it ("Parameter "material" is null" on free).
static var _matte_cache := {}


# glTF kits (Kenney nature/spacekit, generated buildings) export metallicFactor 1.0; Godot then
# draws the surface with no diffuse light, so low-poly models render dark. Make untextured metal
# matte on this instance only (the imported resource is left untouched).
static func matte_materials(root: Node) -> void:
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for n in meshes:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat == null or mat.metallic <= 0.0 or mat.metallic_texture != null:
				continue
			if mat == mi.get_surface_override_material(s):
				mat.metallic = 0.0   # already an override on this instance (e.g. a stylized hull)
				continue
			if not _matte_cache.has(mat):
				var matte := mat.duplicate() as BaseMaterial3D
				matte.metallic = 0.0
				_matte_cache[mat] = matte
			mi.set_surface_override_material(s, _matte_cache[mat])


# One brightened copy per material and gain, shared by every instance (see _matte_cache).
static var _gain_cache := {}


# A generated model whose texture came out very dark reads as a silhouette. Multiply its albedo
# by `gain` on this instance only (the imported resource is left untouched).
static func gain_materials(root: Node, gain: float) -> void:
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for n in meshes:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat == null:
				continue
			var key := [mat, gain]
			if not _gain_cache.has(key):
				var lifted := mat.duplicate() as BaseMaterial3D
				var c := mat.albedo_color
				lifted.albedo_color = Color(c.r * gain, c.g * gain, c.b * gain, c.a)
				_gain_cache[key] = lifted
			mi.set_surface_override_material(s, _gain_cache[key])


# Normalize any ship model to a target overall size (hulls come from different sources/scales).
static func fit_scale(root: Node3D, target: float) -> void:
	var box := model_aabb(root)
	var dim: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if dim > 0.0:
		root.scale = Vector3.ONE * (target / dim)


# Bounding box of every mesh under `root`, in root's local space (root's own scale excluded).
# Measures through every parent up to the root: a rigged hull sits under a scaled armature.
static func model_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := mi.transform
		var p := mi.get_parent()
		while p != root and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * mi.mesh.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


# One vertex-color copy per material, shared by every instance (see _matte_cache).
static var _vertex_color_cache := {}


# Kenney low-poly kits bake their palette into VERTEX COLORS; Godot renders those white unless the
# material flags them as albedo. Enable it on every surface so kit models show their real colors.
func _enable_vertex_colors(root: Node) -> void:
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for n in meshes:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			if mat is StandardMaterial3D:
				if not _vertex_color_cache.has(mat):
					var m: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
					m.vertex_color_use_as_albedo = true
					_vertex_color_cache[mat] = m
				mi.set_surface_override_material(s, _vertex_color_cache[mat])


# Preserve an imported mesh's textures and UV-driven detail while shifting its palette.
# A duplicated mesh/material pair keeps the source GLB immutable and avoids the flat-color
# material_override that would erase the Kenney colormap entirely.
# `per_instance_color` lets a MultiMesh shade each instance on top (see GroundTone).
func _mesh_with_albedo_tint(source: Mesh, tint: Color, per_instance_color := false) -> Mesh:
	if source == null:
		return null
	var copy := source.duplicate() as Mesh
	for surface in copy.get_surface_count():
		var original := source.surface_get_material(surface)
		if original is StandardMaterial3D:
			var material := original.duplicate() as StandardMaterial3D
			material.albedo_color *= tint
			if per_instance_color:
				material.vertex_color_use_as_albedo = true
			if material.metallic_texture == null:
				material.metallic = 0.0   # see matte_materials
			copy.surface_set_material(surface, material)
	return copy


# One recoloured swatch texture per source texture and tint pair, shared by every tile batch
# (see _matte_cache).
static var _two_tone_cache := {}


# Per-channel byte -> byte table of what `albedo_color *= tint` renders as. Godot multiplies the
# albedo texture and colour in linear space; an 8-bit texture clamps what exceeds 1.0.
static func _tint_table(tint: float) -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(256)
	var tint_lin := Color(tint, tint, tint).srgb_to_linear().r
	for i in 256:
		var lin := minf(Color(i / 255.0, 0.0, 0.0).srgb_to_linear().r * tint_lin, 1.0)
		table[i] = roundi(Color(lin, 0.0, 0.0).linear_to_srgb().r * 255.0)
	return table


# A recoloured copy of a swatch image: rock swatches carry `stone`, every other pixel `ground`.
# Pure: the source is untouched; null when there is no pixel data to work with.
static func recolor_two_tone(source: Image, ground: Color, stone: Color) -> Image:
	if source == null or source.is_empty():
		return null
	var img := source.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	var g_r := _tint_table(ground.r)
	var g_g := _tint_table(ground.g)
	var g_b := _tint_table(ground.b)
	var s_r := _tint_table(stone.r)
	var s_g := _tint_table(stone.g)
	var s_b := _tint_table(stone.b)
	for i in range(0, data.size(), 4):
		var r := data[i]
		var g := data[i + 1]
		var b := data[i + 2]
		# Kenney's colormap paints rock lavender-grey (blue the strongest channel, low saturation);
		# grass (teal) and dirt (brown) always have another channel on top.
		if b >= r and b >= g and (b - mini(r, g)) * 10 <= b * 3:
			data[i] = s_r[r]
			data[i + 1] = s_g[g]
			data[i + 2] = s_b[b]
		else:
			data[i] = g_r[r]
			data[i + 1] = g_g[g]
			data[i + 2] = g_b[b]
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


# The shared recoloured texture for `source`; null when its pixels are unavailable (headless
# dummy renderer), so callers fall back to a single tint.
static func two_tone_texture(source: Texture2D, ground: Color, stone: Color) -> Texture2D:
	if source == null:
		return null
	var key := [source, ground, stone]
	if not _two_tone_cache.has(key):
		var img := recolor_two_tone(source.get_image(), ground, stone)
		_two_tone_cache[key] = ImageTexture.create_from_image(img) if img != null else null
	return _two_tone_cache[key]


# Like _mesh_with_albedo_tint, but the grass and the rock of one tile take different tints (the
# hill tile's grass would otherwise turn leaf green and its rock salmon under a single tint).
# The tints live in the recoloured colormap, so the material's own albedo_color stays untouched.
func _mesh_with_two_tone_albedo(source: Mesh, ground: Color, stone: Color, per_instance_color := false) -> Mesh:
	if source == null:
		return null
	var copy := source.duplicate() as Mesh
	for surface in copy.get_surface_count():
		var original := source.surface_get_material(surface)
		if not original is StandardMaterial3D:
			continue
		var texture := two_tone_texture((original as StandardMaterial3D).albedo_texture, ground, stone)
		if texture == null:
			return _mesh_with_albedo_tint(source, ground, per_instance_color)
		var material := original.duplicate() as StandardMaterial3D
		material.albedo_texture = texture
		if per_instance_color:
			material.vertex_color_use_as_albedo = true
		if material.metallic_texture == null:
			material.metallic = 0.0   # see matte_materials
		copy.surface_set_material(surface, material)
	return copy


func ground_point(mouse: Vector2) -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var origin: Vector3 = cam.project_ray_origin(mouse)
	var dir: Vector3 = cam.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	var t := -origin.y / dir.y
	return origin + t * dir
