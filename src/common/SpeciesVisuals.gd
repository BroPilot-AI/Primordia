## Single source for per-species 3D avatar models + the scale that normalizes each model to a
## ~1.0-unit-tall reference creature (tall/short character baked in: Tall Grey reads taller,
## Short Alien shorter). Stages multiply `norm_scale` by the body height they want.
##
## Human reuses the Kenney character kit; the alien lineages use CC0 Quaternius "Ultimate Monsters"
## models (flat-shaded low-poly, baked baseColorFactor colors — same look as the Kenney kits).
## "hydra" is the freshwater lineage's RIVAL species (not playable yet — promoting it to a 5th
## playable lineage is a future task).
class_name SpeciesVisuals

const _DATA := {
	# RIGGED + ANIMATED models (walk/idle).
	# BASE rigged + animated humanoid (Quaternius, CC0, walk/idle). We BUILD on this rig — genome
	# deforms the Skeleton3D bones + stage swaps the dressing (caveman→…→astronaut). NOT copy-paste.
	"human":       {model = "res://assets/models/generated/species_rigged/human.glb", model_adv = "res://assets/models/generated/species_rigged_adv/human.glb", norm_adv = 1.0, norm = 1.0},  # TRELLIS creature + Mixamo rig (Walk/Idle, textured)
	"short_alien": {model = "res://assets/models/generated/species_rigged/short_alien.glb", model_adv = "res://assets/models/generated/species_rigged_adv/short_alien.glb", norm_adv = 1.0, norm = 1.0},  # TRELLIS + Mixamo
	"tall_grey":   {model = "res://assets/models/generated/species_rigged/tall_grey.glb", model_adv = "res://assets/models/generated/species_rigged_adv/tall_grey.glb", norm_adv = 1.0, norm = 1.0},    # TRELLIS + Mixamo
	"reptilian":   {model = "res://assets/models/generated/species_rigged/reptilian.glb", model_adv = "res://assets/models/generated/species_rigged_adv/reptilian.glb", norm_adv = 1.0, norm = 1.0},  # TRELLIS + Mixamo
	"hydra":       {model = "res://assets/models/generated/species_rigged/hydra.glb", model_adv = "res://assets/models/generated/species_rigged_adv/hydra.glb", norm_adv = 1.0, norm = 1.0},  # TRELLIS + Mixamo
}
const FALLBACK := "human"
## Stage index (EvolutionState.Stage) at/after which a lineage reads ADVANCED (civilized/spacefaring)
## instead of primitive (caveman). CIV=3. Early stages use `model`; CIV+ use `model_adv` if present.
const ADV_FROM_STAGE := 3

# Per-stage "dressing": appearance = (genome body) × (stage tech level). The deformed BODY persists
# across stages; this shifts the material palette + finish so the same creature reads caveman in
# Creature and astronaut by Space. Keyed by EvolutionState.Stage (1=CREATURE … 4=SPACE).
const _STAGE_DRESS := {
	1: {"tint": Color(0.55, 0.42, 0.30), "amt": 0.35, "rough": 1.0, "metal": 0.0},   # CREATURE — caveman, earthy/bare
	2: {"tint": Color(0.52, 0.40, 0.28), "amt": 0.25, "rough": 0.95, "metal": 0.0},  # TRIBE — tribal earth tones
	3: {"tint": Color(0.66, 0.66, 0.70), "amt": 0.06, "rough": 0.6, "metal": 0.05},  # CIV — light, preserve adv texture
	4: {"tint": Color(0.80, 0.85, 0.95), "amt": 0.12, "rough": 0.5, "metal": 0.12},  # SPACE — light sheen, keep texture
}
const _TRAIT_MATERIAL_TWEAKS := {
	"carapace": {"metal": 0.18, "rough": -0.12, "darken": 0.10, "normal": "carapace"},
	"armor": {"metal": 0.20, "rough": -0.14, "darken": 0.12, "normal": "armor"},
	"shell": {"metal": 0.16, "rough": -0.10, "darken": 0.10, "normal": "shell"},
	"plate": {"metal": 0.14, "rough": -0.08, "darken": 0.08, "normal": "plate"},
	"fang": {"red": 0.12, "rough": 0.08, "normal": "fang"},
	"claw": {"red": 0.10, "rough": 0.07, "normal": "claw"},
	"predator": {"red": 0.14, "rough": 0.10},
	"cilia": {"rough": -0.06, "normal": "cilia"},
	"fin": {"rough": -0.07, "normal": "fin"},
	"swim": {"rough": -0.06},
	"eye": {"emit": 0.08, "normal": "eye"},
	"sense": {"emit": 0.07},
	"antenna": {"emit": 0.08, "normal": "antenna"},
}
const _AXIS_MATERIAL_TWEAKS := {
	"defense": {"metal": 0.16, "rough": -0.10, "darken": 0.10, "normal": "armor"},
	"carnivory": {"red": 0.16, "rough": 0.10},
	"locomotion": {"rough": -0.06},
	"senses": {"emit": 0.08},
}
const _META_BASE_ALBEDO := "species_visuals_base_albedo"
const _META_BASE_ALBEDO_TEXTURE := "species_visuals_base_albedo_texture"
const _META_BASE_NORMAL_TEXTURE := "species_visuals_base_normal_texture"
const _META_BASE_NORMAL_SCALE := "species_visuals_base_normal_scale"
const _META_BASE_MODEL_SCALE := "species_visuals_base_model_scale"


static func _advanced() -> bool:
	return int(EvolutionState.current_stage) >= ADV_FROM_STAGE


static func model_path(species: String) -> String:
	var e: Dictionary = _DATA.get(species, _DATA[FALLBACK])
	if _advanced() and e.has("model_adv"):
		return str(e["model_adv"])   # CIV/Space → civilized/spacefaring mesh
	return str(e["model"])           # Creature/Tribe → primitive mesh


## Scale that makes the model ~1.0 unit tall. Multiply by the desired body height per stage.
static func norm_scale(species: String) -> float:
	var e: Dictionary = _DATA.get(species, _DATA[FALLBACK])
	if _advanced() and e.has("norm_adv"):
		return float(e["norm_adv"])
	return float(e["norm"])


## Spawn the species avatar as a child of `parent`, scaled to `body_height` units tall and dropped
## so its feet sit at the parent origin. Returns the model node (or null if the model is missing).
static func attach(parent: Node3D, species: String, body_height: float = 1.0, foot_offset: float = 0.0) -> Node3D:
	var packed := load(model_path(species)) as PackedScene
	if packed == null:
		push_warning("SpeciesVisuals: missing model for %s" % species)
		return null
	var model: Node3D = packed.instantiate()
	model.scale = Vector3.ONE * norm_scale(species) * body_height
	model.position = Vector3(0, foot_offset, 0)
	parent.add_child(model)
	return model


## Express the genome on a cohesive humanoid base — the ONE source of truth, used by every stage
## + the morph + the HUD portrait. NO glued-on parts: diet→color blend, size→bulk, defense→armored
## metallic sheen. Preserves each surface's own albedo/texture so the model never flattens to a blob.
static func express(model: Node3D, genome, reshape: bool = true) -> void:
	if model == null or genome == null:
		return
	if reshape and not _advanced():
		# Deform only the PRIMITIVE early mesh. Advanced (Civ/Space) meshes are pre-styled and their
		# transferred skin weights DISTORT under bone-scaling — render them as authored.
		_attach_deformer(model, genome, genome.resolved_species())
	# Dressing matches where you are in the evolution arc (caveman→…→astronaut).
	_express_tint(model, genome, EvolutionState.current_stage)


# Attach a GenomeDeformer to the model's Skeleton3D so the genome reshapes the ANIMATED rig (size/
# defense/carnivory → bone scales). Falls back to a whole-model bulk scale only if there's no rig.
static func _attach_deformer(model: Node3D, genome, species: String) -> void:
	for c in model.find_children("*", "Skeleton3D", true, false):
		for ex in (c as Node).get_children():
			if ex is GenomeDeformer:
				ex.queue_free()   # idempotent: live re-express (diet/trait/stage change) replaces the deformer
		var d := GenomeDeformer.new()
		(c as Node).add_child(d)
		d.setup(genome, species)
		return
	if not model.has_meta(_META_BASE_MODEL_SCALE):
		model.set_meta(_META_BASE_MODEL_SCALE, model.scale)
	var base_scale: Vector3 = model.get_meta(_META_BASE_MODEL_SCALE, model.scale)
	model.scale = base_scale * (0.8 + clampf(genome.size, 0.0, 1.0) * 0.8)   # static-model fallback


static func _express_tint(node: Node, genome, stage: int) -> void:
	if genome == null:
		return
	var diet: Color = genome.color
	var defense: float = clampf(float(genome.defense), 0.0, 1.0)
	var dress: Dictionary = _STAGE_DRESS.get(stage, _STAGE_DRESS[1])
	var tweaks: Dictionary = _skin_tweaks(genome)
	_express_tint_walk(node, diet, defense, dress, tweaks)


static func _express_tint_walk(node: Node, diet: Color, defense: float, dress: Dictionary, tweaks: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		var base_state: Dictionary = _base_material_state(mi)
		var mat := StandardMaterial3D.new()
		var base: Color = base_state.get("albedo", Color(0.72, 0.72, 0.72))
		var base_albedo_texture: Texture2D = base_state.get("albedo_texture", null) as Texture2D
		if base_albedo_texture != null:
			mat.albedo_texture = base_albedo_texture
		else:
			# Flat model (no texture) → generate a real mottled/scaled skin pattern in the genome color.
			mat.albedo_texture = _procedural_skin_albedo(str(tweaks.get("normal", "skin")))
			mat.uv1_scale = Vector3(3.0, 3.0, 3.0)
		# base color → genome diet (species identity) → stage palette (dressing)
		var albedo: Color = base.lerp(diet, 0.30).lerp(dress["tint"], float(dress["amt"]))
		albedo = albedo.lerp(Color(0.50, 0.04, 0.06), clampf(float(tweaks.get("red", 0.0)), 0.0, 0.45))
		albedo = albedo.darkened(clampf(float(tweaks.get("darken", 0.0)), 0.0, 0.45))
		mat.albedo_color = albedo
		mat.metallic = clampf(maxf(defense * 0.3, float(dress["metal"])) + float(tweaks.get("metal", 0.0)), 0.0, 1.0)
		mat.roughness = clampf(float(dress["rough"]) + float(tweaks.get("rough", 0.0)), 0.0, 1.0)
		_apply_skin_normal(mat, base_state, str(tweaks.get("normal", "")))
		var emit: float = clampf(float(tweaks.get("emit", 0.0)), 0.0, 0.20)
		if emit > 0.0:
			mat.emission_enabled = true
			mat.emission = Color(0.36, 0.68, 1.0).lerp(albedo.lightened(0.25), 0.35)
			mat.emission_energy_multiplier = emit
		mi.material_override = mat
		# The override hides any surface overrides; keeping both made Godot print
		# 'Parameter "material" is null' each time the unit was freed.
		for s in mi.get_surface_override_material_count():
			mi.set_surface_override_material(s, null)
	for c in node.get_children():
		_express_tint_walk(c, diet, defense, dress, tweaks)


static func _base_material_state(mi: MeshInstance3D) -> Dictionary:
	if not mi.has_meta(_META_BASE_ALBEDO):
		var orig := mi.get_active_material(0)
		var base := Color(0.72, 0.72, 0.72)
		var albedo_texture: Texture2D = null
		var normal_texture: Texture2D = null
		var normal_scale: float = 1.0
		if orig is StandardMaterial3D:
			var smat := orig as StandardMaterial3D
			base = smat.albedo_color
			albedo_texture = smat.albedo_texture
			normal_texture = smat.normal_texture
			normal_scale = smat.normal_scale
		mi.set_meta(_META_BASE_ALBEDO, base)
		if albedo_texture != null:
			mi.set_meta(_META_BASE_ALBEDO_TEXTURE, albedo_texture)
		if normal_texture != null:
			mi.set_meta(_META_BASE_NORMAL_TEXTURE, normal_texture)
		mi.set_meta(_META_BASE_NORMAL_SCALE, normal_scale)
	return {
		"albedo": mi.get_meta(_META_BASE_ALBEDO) if mi.has_meta(_META_BASE_ALBEDO) else Color(0.72, 0.72, 0.72),
		"albedo_texture": mi.get_meta(_META_BASE_ALBEDO_TEXTURE) if mi.has_meta(_META_BASE_ALBEDO_TEXTURE) else null,
		"normal_texture": mi.get_meta(_META_BASE_NORMAL_TEXTURE) if mi.has_meta(_META_BASE_NORMAL_TEXTURE) else null,
		"normal_scale": float(mi.get_meta(_META_BASE_NORMAL_SCALE)) if mi.has_meta(_META_BASE_NORMAL_SCALE) else 1.0,
	}


static func _skin_tweaks(genome) -> Dictionary:
	var out := {"metal": 0.0, "rough": 0.0, "darken": 0.0, "red": 0.0, "emit": 0.0, "normal": ""}
	for trait_name in EvolutionState.traits:
		var lowered: String = str(trait_name).to_lower()
		for key in _TRAIT_MATERIAL_TWEAKS.keys():
			var keyword: String = str(key)
			if lowered.find(keyword) >= 0:
				_apply_skin_tweak(out, _TRAIT_MATERIAL_TWEAKS[keyword], 1.0)
	_apply_skin_tweak(out, _AXIS_MATERIAL_TWEAKS["defense"], _axis_skin_amount(float(genome.defense)))
	_apply_skin_tweak(out, _AXIS_MATERIAL_TWEAKS["carnivory"], _axis_skin_amount(float(genome.carnivory)))
	_apply_skin_tweak(out, _AXIS_MATERIAL_TWEAKS["locomotion"], _axis_skin_amount(float(genome.locomotion)))
	_apply_skin_tweak(out, _AXIS_MATERIAL_TWEAKS["senses"], _axis_skin_amount(float(genome.senses)))
	out["metal"] = clampf(float(out["metal"]), 0.0, 0.55)
	out["rough"] = clampf(float(out["rough"]), -0.40, 0.40)
	out["darken"] = clampf(float(out["darken"]), 0.0, 0.45)
	out["red"] = clampf(float(out["red"]), 0.0, 0.45)
	out["emit"] = clampf(float(out["emit"]), 0.0, 0.20)
	# Every creature gets a skin: scales for reptilian, soft skin for the rest (procedural normal).
	if str(out.get("normal", "")) == "":
		out["normal"] = "scale" if str(genome.resolved_species()) == "reptilian" else "skin"
	return out


static func _apply_skin_tweak(target: Dictionary, tweak: Dictionary, amount: float) -> void:
	var a: float = clampf(amount, 0.0, 1.0)
	if a <= 0.0:
		return
	target["metal"] = float(target.get("metal", 0.0)) + float(tweak.get("metal", 0.0)) * a
	target["rough"] = float(target.get("rough", 0.0)) + float(tweak.get("rough", 0.0)) * a
	target["darken"] = float(target.get("darken", 0.0)) + float(tweak.get("darken", 0.0)) * a
	target["red"] = float(target.get("red", 0.0)) + float(tweak.get("red", 0.0)) * a
	target["emit"] = float(target.get("emit", 0.0)) + float(tweak.get("emit", 0.0)) * a
	if str(target.get("normal", "")) == "" and str(tweak.get("normal", "")) != "":
		target["normal"] = str(tweak["normal"])


static func _axis_skin_amount(value: float) -> float:
	return clampf((clampf(value, 0.0, 1.0) - 0.58) / 0.42, 0.0, 1.0)


static var _skin_noise_cache: Dictionary = {}


# Procedurally generate a skin/scale normal map (no art assets needed) — gives the bare model real
# surface detail instead of flat plastic. Cached per key (noise bake is expensive).
static func _procedural_skin_normal(key: String) -> Texture2D:
	if _skin_noise_cache.has(key):
		return _skin_noise_cache[key]
	var hard: bool = key in ["scale", "carapace", "armor", "shell", "plate"]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.09 if hard else 0.04
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 7.0 if hard else 3.0
	nt.noise = noise
	_skin_noise_cache[key] = nt
	return nt


static var _skin_albedo_cache: Dictionary = {}


# Procedural skin PATTERN (grayscale, multiplied by the genome skin color) — cells/scales for
# reptilian+armor traits, soft mottle for skin. Turns a flat-colored model into a patterned creature.
static func _procedural_skin_albedo(key: String) -> Texture2D:
	if _skin_albedo_cache.has(key):
		return _skin_albedo_cache[key]
	var hard: bool = key in ["scale", "carapace", "armor", "shell", "plate"]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR if hard else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.11 if hard else 0.05
	if hard:
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2
	var grad := Gradient.new()
	grad.set_color(0, Color(0.78, 0.78, 0.78))   # mottle low (kept bright so the pattern doesn't darken the skin)
	grad.set_color(1, Color(1.0, 1.0, 1.0))
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.color_ramp = grad
	nt.noise = noise
	_skin_albedo_cache[key] = nt
	return nt


static func _apply_skin_normal(mat: StandardMaterial3D, base_state: Dictionary, normal_key: String) -> void:
	var tex: Texture2D = null
	if normal_key != "":
		var path := "res://assets/textures/skin_%s.png" % normal_key
		tex = (load(path) as Texture2D) if ResourceLoader.exists(path) else _procedural_skin_normal(normal_key)
	if tex == null:
		tex = base_state.get("normal_texture", null) as Texture2D
	if tex != null:
		mat.normal_enabled = true
		mat.normal_texture = tex
		mat.normal_scale = maxf(float(base_state.get("normal_scale", 1.0)), 1.0)


## Distinct base color per species so avatars aren't plain grey.
static func species_tint(species: String) -> Color:
	return _DATA.get(species, _DATA[FALLBACK]).get("tint", Color(0.72, 0.72, 0.74))


static func _apply_tint(node: Node, col: Color) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		(node as MeshInstance3D).material_override = m
	for c in node.get_children():
		_apply_tint(c, col)
