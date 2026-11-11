## Leader portrait that MATCHES the in-game creature: renders the player's genome avatar
## (SpeciesVisuals model + GenomeFeatures3D) into a transparent SubViewport, returned as a Control
## you drop into any HUD. Because it reuses the exact same model + feature system, the Civ/Space
## "leader portrait" is literally your evolved 3D creature — not a separate 2D drawing.
##
## Usage:  hud_box.add_child(SpeciesPortrait.make(EvolutionState.genome))
class_name SpeciesPortrait


static func make(genome, px: int = 132) -> SubViewportContainer:
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.custom_minimum_size = Vector2(px, px)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp := SubViewport.new()
	vp.size = Vector2i(px * 2, px * 2)            # 2× supersample for crisp low-poly edges
	vp.transparent_bg = true
	vp.own_world_3d = true                        # isolate each portrait's 3D scene (else they pile up)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-22, 35, 0)
	key.light_energy = 1.4
	vp.add_child(key)

	var holder := Node3D.new()
	vp.add_child(holder)
	var species: String = genome.resolved_species() if genome != null else "human"
	var model := SpeciesVisuals.attach(holder, species, 2.0)
	if model != null and genome != null:
		SpeciesVisuals.express(model, genome)
	if model != null:
		# Animate the corner avatar — autoplay a looped Idle (the SubViewport renders continuously).
		# Keyword match so it works for Quaternius "Idle" AND Mixamo "Idle"/"mixamo.com".
		for a in model.find_children("*", "AnimationPlayer", true, false):
			var ap := a as AnimationPlayer
			var clip := _portrait_idle(ap)
			if clip != "":
				ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				ap.autoplay = clip
			break
	holder.rotation_degrees = Vector3(0, 18, 0)   # slight 3/4 turn for a portrait read

	var cam := Camera3D.new()
	cam.fov = 38.0   # longer lens = flatter, portrait-like (less wide-angle distortion)
	vp.add_child(cam)
	# SubViewport isn't in the tree yet → look_at would warn; look_at_from_position works detached.
	# Tight bust: frame head + shoulders (model ~2u tall, head + features near the top).
	cam.look_at_from_position(Vector3(0, 1.62, 5.4), Vector3(0, 1.5, 0), Vector3.UP)
	cam.current = true
	return cont


# First clip matching idle (then walk as fallback), by keyword — works for Quaternius + Mixamo naming.
static func _portrait_idle(ap: AnimationPlayer) -> String:
	for keys in [["idle", "breath"], ["walk", "run"]]:
		for n in ap.get_animation_list():
			var l := String(n).to_lower()
			for k in keys:
				if l.find(k) >= 0:
					return String(n)
	var list := ap.get_animation_list()
	return String(list[0]) if list.size() > 0 else ""
