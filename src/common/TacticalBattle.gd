## Full drop-in tactical battle overlay. Pauses the parent stage, runs a real-time
## skirmish in its own SubViewport world, then emits `finished` with survivor IDs/HP
## so Civ/Space can apply losses. Supports ground (outdoor) and space arenas.
class_name TacticalBattle
extends CanvasLayer

signal finished(result: Dictionary)

const ARENA_HALF := 26.0

var _mode: String = "ground"
var _title: String = "TACTICAL BATTLE"
var _friends_spec: Array = []
var _foes_spec: Array = []
var _units: Array = []   # live combatants {node, spec, faction, ...}
var _selected: Array = []
var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _status: Label
var _drag_start := Vector2.ZERO
var _dragging := false
var _done := false
var _time_left := 90.0
var _rng := RandomNumberGenerator.new()
var _shake_t := 0.0
var _cam_base := Vector3.ZERO
var _kills_player := 0
var _kills_enemy := 0
var _fx_root: Node3D
## One tip banner per process (first drop-in this session).
static var _session_tip_shown := false
var _fanfare_skip := false
var _kill_feed_t := 0.0
var _kill_feed_line := ""


func configure(spec: Dictionary) -> void:
	_mode = str(spec.get("mode", "ground"))
	_title = str(spec.get("title", "TACTICAL BATTLE"))
	_friends_spec = spec.get("friends", [])
	_foes_spec = spec.get("foes", [])
	_time_left = float(spec.get("time_limit", 90.0))
	_rng.seed = int(spec.get("seed", hash(str(Time.get_ticks_msec()))))


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cont)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.handle_input_locally = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.size = Vector2i(1280, 720)
	cont.add_child(_vp)
	_build_world()
	_spawn_sides()
	_build_hud()
	_maybe_show_battle_tip()


func _build_world() -> void:
	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	if _mode == "space":
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.03, 0.08)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.4, 0.45, 0.6)
		env.ambient_light_energy = 0.85
		env.glow_enabled = true
	else:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.28, 0.48, 0.78)
		sky_mat.sky_horizon_color = Color(0.75, 0.82, 0.88)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.6   # match the Civ map (Stage3D "outdoor") so a unit reads the same in both
		env.ssao_enabled = true
		env.glow_enabled = true
		env.glow_intensity = 0.3
		env.glow_bloom = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.55 if _mode != "space" else 1.1
	sun.shadow_enabled = _mode != "space"
	_world.add_child(sun)

	if _mode != "space":
		var ground := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(ARENA_HALF * 2.4, 0.4, ARENA_HALF * 2.4)
		ground.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.28, 0.42, 0.26)
		ground.material_override = mat
		ground.position.y = -0.2
		_world.add_child(ground)
	else:
		# Faint grid disc so ships have spatial reference.
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = ARENA_HALF * 1.1
		cyl.bottom_radius = ARENA_HALF * 1.1
		cyl.height = 0.05
		disc.mesh = cyl
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.08, 0.12, 0.22, 0.35)
		dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc.material_override = dmat
		_world.add_child(disc)
		_world.add_child(SpaceBackdrop.for_current_galaxy())

	_fx_root = Node3D.new()
	_fx_root.name = "BattleFX"
	_world.add_child(_fx_root)

	_cam = Camera3D.new()
	_cam.set_script(load("res://src/common/RTSCamera3D.gd"))
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 38.0 if _mode == "ground" else 48.0
	_cam.current = true
	_world.add_child(_cam)
	if _cam.has_method("set_focus"):
		_cam.set_focus(Vector3.ZERO)
	if _cam.has_method("set_band"):
		_cam.set_band(0)
	_cam_base = _cam.global_position


func _spawn_sides() -> void:
	var fslots := BattleModel.formation_slots(_friends_spec.size(), 0, ARENA_HALF)
	var eslots := BattleModel.formation_slots(_foes_spec.size(), 1, ARENA_HALF)
	for i in _friends_spec.size():
		_spawn_one(_friends_spec[i], fslots[i] if i < fslots.size() else Vector3(-12, 0, 0), 0)
	for i in _foes_spec.size():
		_spawn_one(_foes_spec[i], eslots[i] if i < eslots.size() else Vector3(12, 0, 0), 1)


func _spawn_one(spec: Dictionary, pos: Vector3, faction: int) -> void:
	var node := Node3D.new()
	node.position = pos
	_world.add_child(node)
	var height := _build_body(node, str(spec.get("kind", "Soldier")), faction, spec.get("look"))
	var u := {
		"node": node,
		"id": spec.get("id"),
		"kind": str(spec.get("kind", "Soldier")),
		"faction": faction,
		"hp": float(spec.get("hp", 20.0)),
		"max_hp": float(spec.get("max_hp", 20.0)),
		"damage": float(spec.get("damage", 5.0)),
		"attack_range": float(spec.get("attack_range", 4.0)),
		"speed": float(spec.get("speed", 6.0)),
		"attack_cd": float(spec.get("attack_cd", 1.0)),
		"attack_anim": str(spec.get("attack_anim", "attack")),
		"cd": 0.0,
		"target": null,
		"command": null,
		"selected": false,
	}
	# Space ranges are in large galaxy units — clamp to arena scale.
	if _mode == "space":
		u["attack_range"] = clampf(float(u["attack_range"]) * 0.08, 3.0, 14.0)
		u["speed"] = clampf(float(u["speed"]) * 0.06, 4.0, 18.0)
	_units.append(u)
	_make_hpbar(u, height)


# Builds the unit's visible body under `node`; returns its height (for the HP bar), 0 = default.
func _build_body(node: Node3D, kind: String, faction: int, look: Variant = null) -> float:
	var col := Color(0.45, 0.85, 1.0) if faction == 0 else Color(0.95, 0.35, 0.35)
	if _mode == "ground" and look is Node3D and is_instance_valid(look):
		# Show the very unit from the map (species mesh, skin, genome parts, role prop). No GROUPS/SIGNALS:
		# the copy must not join the map's unit groups or fire its handlers.
		var src := look as Node3D
		var body := src.duplicate(Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION) as Node3D
		body.transform = Transform3D(Basis.from_scale(src.scale), Vector3.ZERO)
		for overlay in ["HpBar", "SelRing"]:   # the map's own overlays; the battle adds its own
			var o := body.get_node_or_null(overlay)
			if o != null:
				body.remove_child(o)
				o.free()
		for m in body.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D   # own copy: the hit flash must not edit the map unit's skin
			if mi.material_override != null:
				mi.material_override = mi.material_override.duplicate()
		var box := Stage3D.model_aabb(body)
		body.position.y = -box.position.y * src.scale.y   # feet on the arena floor (buildings are seated off-origin)
		node.add_child(body)
		UnitAnimator.play(node, "idle")
		_add_sel_ring(node, col)
		return box.size.y * src.scale.y
	if _mode == "space":
		# Same hull the galaxy map draws for this ship kind.
		var path := SpaceUnits.HULL_PATH % str(SpaceUnits.HULL.get(kind, "fighter"))
		if ResourceLoader.exists(path):
			var packed := load(path) as PackedScene
			if packed != null:
				var inst: Node3D = packed.instantiate()
				node.add_child(inst)
				Stage3D.fit_scale(inst, SpaceUnits.hull_size(kind))
				SpaceUnits.orient_hull(inst, kind)   # lead with the nose under look_at
				Stage3D.tint_model(inst, col)   # faction color so the two sides read apart
				_add_sel_ring(node, col)
				return 0.0
	# Ground unit or model fallback: simple capsule + tint.
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.45
	cap.height = 1.6 if _mode == "ground" else 0.9
	body.mesh = cap
	body.position.y = 0.9 if _mode == "ground" else 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col * 0.35
	body.material_override = mat
	node.add_child(body)
	_add_sel_ring(node, col)
	return 0.0


# Hidden selection ring under a combatant; shown while it's selected (see SelRing lookups).
func _add_sel_ring(node: Node3D, col: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.7
	ring.mesh = torus
	ring.position.y = 0.05
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = col
	rmat.emission_enabled = true
	rmat.emission = col
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	ring.visible = false
	ring.name = "SelRing"
	node.add_child(ring)


func _make_hpbar(u: Dictionary, body_height: float = 0.0) -> void:
	var bar := Label3D.new()
	bar.text = "100%"
	bar.font_size = 28
	var y := 2.2 if _mode == "ground" else 1.4
	if body_height > 0.0:
		y = body_height + 0.5   # clear the head of a real (taller) unit model
	bar.position = Vector3(0, y, 0)
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.modulate = Color(0.9, 1.0, 0.9)
	u.node.add_child(bar)
	u["hpbar"] = bar


func _build_hud() -> void:
	var top := StageChrome.status_label(_title)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 12
	top.add_theme_font_size_override("font_size", 22)
	top.add_theme_color_override("font_color", StageChrome.TITLE)
	add_child(top)

	_status = StageChrome.status_label("Select friendlies · RMB move/attack · B auto-resolve · Esc retreat")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_bottom = -18
	_status.offset_top = -48
	add_child(_status)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_top = -96
	row.offset_bottom = -56
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	row.add_child(StageChrome.make_button("Auto-Resolve", "Dice the rest of the fight", _auto_resolve))
	row.add_child(StageChrome.make_button("Retreat", "Flee — keep survivors, concede the field", _retreat))
	for c in row.get_children():
		if c is Control:
			(c as Control).process_mode = Node.PROCESS_MODE_ALWAYS


## Brief first-open tip so the arena controls are obvious.
func _maybe_show_battle_tip() -> void:
	if _session_tip_shown:
		return
	_session_tip_shown = true
	var tip := PanelContainer.new()
	tip.process_mode = Node.PROCESS_MODE_ALWAYS
	tip.add_theme_stylebox_override("panel", StageChrome.toast_panel_style())
	tip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tip.offset_top = 56
	tip.offset_left = -280
	tip.offset_right = 280
	tip.offset_bottom = 120
	tip.modulate.a = 0.0
	add_child(tip)
	var lab := StageChrome.body_label(
		"LMB select · RMB move/attack · Auto-Resolve ends the fight · Esc retreats"
	)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_child(lab)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_property(tip, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.6)
	tw.tween_property(tip, "modulate:a", 0.0, 0.4)
	tw.tween_callback(tip.queue_free)


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	if _kill_feed_t > 0.0:
		_kill_feed_t = maxf(0.0, _kill_feed_t - delta)
	_tick_combat(delta)
	_tick_shake(delta)
	_update_status()
	if _friends_alive() == 0:
		_end_battle(false)
	elif _foes_alive() == 0:
		_end_battle(true)
	elif _time_left <= 0.0:
		_end_battle(_friends_alive() >= _foes_alive())


func _tick_shake(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	if _shake_t > 0.0:
		_shake_t = maxf(0.0, _shake_t - delta)
		var amp: float = 0.35 * (_shake_t / 0.18)
		_cam.global_position = _cam_base + Vector3(
			_rng.randf_range(-amp, amp), 0.0, _rng.randf_range(-amp, amp))
	else:
		_cam.global_position = _cam_base


func _shake(amount: float = 0.18) -> void:
	_shake_t = maxf(_shake_t, amount)
	if is_instance_valid(_cam):
		_cam_base = _cam.global_position


func _tick_combat(delta: float) -> void:
	for u in _units:
		if float(u.get("hp", 0.0)) <= 0.0 or not is_instance_valid(u.get("node")):
			continue
		if u.faction == 1 or (u.faction == 0 and u.get("command") == null and u.get("target") == null):
			# AI / idle friendlies auto-acquire.
			if u.get("target") == null or not _is_live_target(u.target):
				u["target"] = _nearest_enemy(u)
		var t: Variant = u.get("target")
		if t is Dictionary and _is_live_target(t):
			var tpos: Vector3 = t.node.position
			var dist: float = u.node.position.distance_to(tpos)
			if dist > float(u.attack_range) and float(u.speed) > 0.0:
				var dir: Vector3 = (tpos - u.node.position)
				dir.y = 0.0
				if dir.length() > 0.01:
					dir = dir.normalized()
					u.node.position += dir * float(u.speed) * delta
					_face(u.node, dir)
					UnitAnimator.play(u.node, "run")
			else:
				u["cd"] = float(u.get("cd", 0.0)) - delta
				if float(u["cd"]) <= 0.0:
					u["cd"] = float(u.attack_cd)
					var aim: Vector3 = tpos - u.node.position
					aim.y = 0.0
					if aim.length() > 0.01:
						_face(u.node, aim.normalized())
					UnitAnimator.trigger(u.node, str(u.get("attack_anim", "attack")))
					var dmg: float = float(u.damage)
					t["hp"] = float(t.hp) - dmg
					_spawn_hit_fx(u.node.position, tpos, int(u.faction) == 0)
					_spawn_damage_float(tpos, dmg, int(t.faction) == 0)
					_flash_unit(t)
					_refresh_hpbar(t)
					if float(t.hp) <= 0.0:
						_kill(t)
						u["target"] = null
						if int(u.faction) == 0:
							_kills_player += 1
						else:
							_kills_enemy += 1
		elif u.get("command") is Vector3 and float(u.speed) > 0.0:
			var dest: Vector3 = u.command
			var d2: Vector3 = dest - u.node.position
			d2.y = 0.0
			if d2.length() < 0.6:
				u["command"] = null
			else:
				var step: Vector3 = d2.normalized() * float(u.speed) * delta
				u.node.position += step
				_face(u.node, step.normalized())
				UnitAnimator.play(u.node, "run")
		else:
			UnitAnimator.play(u.node, "idle")
		_refresh_hpbar(u)


# Turn a combatant to `dir`. Species models face +Z (use_model_front, or they march backwards); ship
# hulls are turned by SpaceUnits.orient_hull to lead along -Z, so space keeps plain look_at.
func _face(node: Node3D, dir: Vector3) -> void:
	node.look_at(node.position + dir, Vector3.UP, _mode == "ground")


func _is_live_target(t: Variant) -> bool:
	return t is Dictionary and is_instance_valid(t.get("node")) and float(t.get("hp", 0.0)) > 0.0


func _nearest_enemy(u: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for o in _units:
		if int(o.faction) == int(u.faction):
			continue
		if float(o.get("hp", 0.0)) <= 0.0 or not is_instance_valid(o.get("node")):
			continue
		var d: float = u.node.position.distance_squared_to(o.node.position)
		if d < bd:
			bd = d
			best = o
	return best


func _refresh_hpbar(u: Dictionary) -> void:
	var bar: Label3D = u.get("hpbar")
	if bar == null or not is_instance_valid(bar):
		return
	var frac: float = clampf(float(u.hp) / maxf(float(u.max_hp), 1.0), 0.0, 1.0)
	bar.text = "%d%%" % int(round(frac * 100.0))
	bar.modulate = Color(0.4, 1.0, 0.45) if frac > 0.5 else (Color(1.0, 0.85, 0.3) if frac > 0.25 else Color(1.0, 0.35, 0.3))


func _kill(u: Dictionary) -> void:
	u["hp"] = 0.0
	var kind: String = str(u.get("kind", "Unit"))
	if int(u.faction) == 0:
		_push_kill_feed("Ally %s down" % kind)
	else:
		_push_kill_feed("%s destroyed" % kind)
	if is_instance_valid(u.get("node")):
		# Prefer local position — SubViewport combatants can lack a global transform.
		var pos: Vector3 = u.node.position
		if u.node.is_inside_tree():
			pos = u.node.global_position
		_spawn_death_pop(pos, int(u.faction) == 0)
		_shake(0.22)
		if _mode == "space":
			AudioManager.play_sfx("space_explosion")
		else:
			AudioManager.play_sfx("civ_combat")
		var hpbar: Variant = u.get("hpbar")
		if hpbar is Label3D and is_instance_valid(hpbar):
			(hpbar as Label3D).visible = false
		if u.node.find_children("*", "AnimationPlayer", true, false).is_empty():
			u.node.visible = false
		else:
			# A rigged unit falls (death clip), then sinks out — like on the map.
			UnitAnimator.trigger(u.node, "death")
			var tw: Tween = (u.node as Node3D).create_tween()
			tw.tween_interval(1.2)
			tw.tween_property(u.node, "position:y", u.node.position.y - 1.5, 0.8)
			tw.tween_callback(u.node.hide)


func _push_kill_feed(line: String) -> void:
	_kill_feed_line = line
	_kill_feed_t = 1.6


func _spawn_damage_float(at: Vector3, amount: float, hit_friend: bool) -> void:
	if _fx_root == null or amount <= 0.0:
		return
	var lab := Label3D.new()
	lab.text = "-%d" % maxi(1, int(round(amount)))
	lab.font_size = 40
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1.0, 0.35, 0.32) if hit_friend else Color(1.0, 0.92, 0.35)
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	lab.outline_size = 8
	lab.position = at + Vector3(_rng.randf_range(-0.4, 0.4), 1.6 if _mode == "ground" else 1.1, 0)
	_fx_root.add_child(lab)
	var rise: float = lab.position.y + 1.5
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_property(lab, "position:y", rise, 0.55)
	tw.parallel().tween_property(lab, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lab.queue_free)


func _spawn_hit_fx(from: Vector3, to: Vector3, player_shot: bool) -> void:
	if _fx_root == null:
		return
	var mid: Vector3 = (from + to) * 0.5 + Vector3(0, 0.8, 0)
	var spark := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	spark.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.92, 0.45) if player_shot else Color(1.0, 0.4, 0.35)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.material_override = mat
	_fx_root.add_child(spark)   # in the tree before global_position / look_at — they need it
	spark.global_position = mid
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_property(spark, "scale", Vector3.ONE * 2.2, 0.12)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(spark.queue_free)
	# Thin bolt
	var bolt := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length: float = from.distance_to(to)
	box.size = Vector3(0.08, 0.08, maxf(0.2, length))
	bolt.mesh = box
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = mat.albedo_color
	bmat.emission_enabled = true
	bmat.emission = mat.albedo_color
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt.material_override = bmat
	_fx_root.add_child(bolt)
	bolt.global_position = mid
	if length > 0.05:
		bolt.look_at(to + Vector3(0, 0.8, 0), Vector3.UP)
	var tw2 := create_tween()
	tw2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.set_ignore_time_scale(true)
	tw2.tween_property(bmat, "albedo_color:a", 0.0, 0.12)
	tw2.tween_callback(bolt.queue_free)


func _flash_unit(u: Dictionary) -> void:
	if not is_instance_valid(u.get("node")):
		return
	for m in u.node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.material_override == null:
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat == null:
			continue
		var base_e: float = mat.emission_energy_multiplier
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 4.0
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.set_ignore_time_scale(true)
		tw.tween_property(mat, "emission_energy_multiplier", base_e, 0.15)


func _spawn_death_pop(pos: Vector3, was_friend: bool) -> void:
	if _fx_root == null:
		return
	for i in 6:
		var p := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.18
		s.height = 0.36
		p.mesh = s
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.5, 0.9, 1.0) if was_friend else Color(1.0, 0.45, 0.25)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		p.material_override = mat
		p.position = pos + Vector3(0, 0.6, 0)
		_fx_root.add_child(p)
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.4, 1.2), _rng.randf_range(-1, 1)).normalized()
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.set_ignore_time_scale(true)
		tw.tween_property(p, "position", pos + dir * _rng.randf_range(1.5, 3.0), 0.35)
		tw.parallel().tween_property(p, "scale", Vector3.ONE * 0.1, 0.35)
		tw.tween_callback(p.queue_free)


func _friends_alive() -> int:
	var n := 0
	for u in _units:
		if int(u.faction) == 0 and float(u.hp) > 0.0:
			n += 1
	return n


func _foes_alive() -> int:
	var n := 0
	for u in _units:
		if int(u.faction) == 1 and float(u.hp) > 0.0:
			n += 1
	return n


func _update_status() -> void:
	if _status == null:
		return
	var base := "Allies %d  ·  Enemies %d  ·  %.0fs  ·  Select + RMB · Auto-Resolve · Esc retreat" % [
		_friends_alive(), _foes_alive(), maxf(0.0, _time_left),
	]
	if _kill_feed_t > 0.0 and _kill_feed_line != "":
		_status.text = "%s\n%s" % [base, _kill_feed_line]
	else:
		_status.text = base


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_start = mb.position
				_dragging = true
			elif _dragging:
				_dragging = false
				var rect := Rect2(_drag_start, mb.position - _drag_start).abs()
				if rect.size.length() < 6.0:
					_click_select(mb.position)
				else:
					_box_select(rect)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_command_selected(mb.position)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_retreat()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B:
			_auto_resolve()
			get_viewport().set_input_as_handled()


func _click_select(screen: Vector2) -> void:
	_clear_sel()
	var best: Dictionary = {}
	var bd := 36.0
	for u in _units:
		if int(u.faction) != 0 or float(u.hp) <= 0.0 or not is_instance_valid(u.node):
			continue
		var sp: Vector2 = _vp.get_camera_3d().unproject_position(u.node.global_position)
		var d: float = sp.distance_to(screen)
		if d < bd:
			bd = d
			best = u
	if not best.is_empty():
		_set_sel(best, true)


func _box_select(rect: Rect2) -> void:
	_clear_sel()
	var cam := _vp.get_camera_3d()
	for u in _units:
		if int(u.faction) != 0 or float(u.hp) <= 0.0 or not is_instance_valid(u.node):
			continue
		if rect.has_point(cam.unproject_position(u.node.global_position)):
			_set_sel(u, true)


func _set_sel(u: Dictionary, on: bool) -> void:
	u["selected"] = on
	if on and not _selected.has(u):
		_selected.append(u)
	var ring: Node = u.node.get_node_or_null("SelRing")
	if ring != null:
		ring.visible = on


func _clear_sel() -> void:
	for u in _selected:
		_set_sel(u, false)
	_selected.clear()


func _command_selected(screen: Vector2) -> void:
	if _selected.is_empty():
		return
	var cam := _vp.get_camera_3d()
	# Prefer attack enemy under cursor.
	var foe: Dictionary = {}
	var bd := 40.0
	for u in _units:
		if int(u.faction) != 1 or float(u.hp) <= 0.0 or not is_instance_valid(u.node):
			continue
		var d: float = cam.unproject_position(u.node.global_position).distance_to(screen)
		if d < bd:
			bd = d
			foe = u
	var dest: Vector3 = _screen_to_ground(screen)
	for u in _selected:
		if float(u.hp) <= 0.0:
			continue
		if not foe.is_empty():
			u["target"] = foe
			u["command"] = null
		else:
			u["target"] = null
			u["command"] = dest


func _screen_to_ground(screen: Vector2) -> Vector3:
	var cam := _vp.get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return Vector3.ZERO
	var t: float = -origin.y / dir.y
	var p: Vector3 = origin + dir * t
	p.x = clampf(p.x, -ARENA_HALF, ARENA_HALF)
	p.z = clampf(p.z, -ARENA_HALF, ARENA_HALF)
	p.y = 0.0
	return p


func _auto_resolve() -> void:
	if _done:
		return
	var friends: Array = []
	var foes: Array = []
	for u in _units:
		var snap := BattleModel.make_combatant(
			u.get("id"), str(u.kind), int(u.faction), float(u.hp), float(u.max_hp),
			float(u.damage), float(u.attack_range), float(u.speed), float(u.attack_cd))
		if int(u.faction) == 0 and float(u.hp) > 0.0:
			friends.append(snap)
		elif int(u.faction) == 1 and float(u.hp) > 0.0:
			foes.append(snap)
	var result := BattleModel.auto_resolve(friends, foes, _rng)
	_apply_auto_result(result)
	# Re-snapshot so loot/kills match the live arena after auto-resolve.
	_finish(_snapshot_result(bool(result.get("won", false))))


func _apply_auto_result(result: Dictionary) -> void:
	var fhp: Dictionary = result.get("friend_hp", {})
	var ehp: Dictionary = result.get("foe_hp", {})
	var falive: Array = result.get("friend_alive", [])
	var ealive: Array = result.get("foe_alive", [])
	for u in _units:
		var id: Variant = u.get("id")
		var before: float = float(u.hp)
		if int(u.faction) == 0:
			if falive.has(id):
				u["hp"] = float(fhp.get(id, u.hp))
			else:
				u["hp"] = 0.0
		else:
			if ealive.has(id):
				u["hp"] = float(ehp.get(id, u.hp))
			else:
				u["hp"] = 0.0
		if before > 0.0 and float(u.hp) <= 0.0:
			if int(u.faction) == 1:
				_kills_player += 1
			else:
				_kills_enemy += 1
			_kill(u)
	# Auto-resolve still awards loot via _snapshot_result path — rebuild from live state.
	# Re-pack so kills count is correct.
	pass


func _retreat() -> void:
	if _done:
		return
	# Retreat = keep friend survivors, foes keep remaining HP (no wipe credit).
	var result := _snapshot_result(false)
	result["retreated"] = true
	_finish(result)


func _end_battle(won: bool) -> void:
	if _done:
		return
	_finish(_snapshot_result(won))


func _snapshot_result(won: bool) -> Dictionary:
	var friend_alive: Array = []
	var foe_alive: Array = []
	var friend_hp := {}
	var foe_hp := {}
	for u in _units:
		var id: Variant = u.get("id")
		if int(u.faction) == 0:
			if float(u.hp) > 0.0:
				friend_alive.append(id)
				friend_hp[id] = float(u.hp)
		else:
			if float(u.hp) > 0.0:
				foe_alive.append(id)
				foe_hp[id] = float(u.hp)
	# Rewards scale with kills and remaining survivors.
	var loot_food := 0
	var loot_wood := 0
	var loot_stone := 0
	var loot_salvage := 0.0
	var vet_stacks := 0
	if won:
		loot_food = 4 + _kills_player * 2
		loot_wood = 2 + _kills_player
		loot_stone = 1 + int(_kills_player / 2)
		loot_salvage = 6.0 + float(_kills_player) * 3.5
		vet_stacks = mini(3, maxi(1, _kills_player / 2))
	return {
		"won": won,
		"friend_alive": friend_alive,
		"foe_alive": foe_alive,
		"friend_hp": friend_hp,
		"foe_hp": foe_hp,
		"retreated": false,
		"mode": _mode,
		"kills_player": _kills_player,
		"kills_enemy": _kills_enemy,
		"loot": {
			"food": loot_food,
			"wood": loot_wood,
			"stone": loot_stone,
			"salvage": loot_salvage,
		},
		"veterancy": vet_stacks,
	}


func _finish(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	# Keep tree paused during fanfare so the world stays frozen under the card.
	await _show_fanfare(result)
	get_tree().paused = false
	finished.emit(result)
	queue_free()


## Full-screen win/loss card with loot line. Click / Continue / Enter skips after a short beat.
func _show_fanfare(result: Dictionary) -> void:
	_fanfare_skip = false
	var won: bool = bool(result.get("won", false)) and not bool(result.get("retreated", false))
	var retreated: bool = bool(result.get("retreated", false))
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.08, 0.05, 0.0) if won else Color(0.08, 0.02, 0.02, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dim)
	var card := PanelContainer.new()
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.add_theme_stylebox_override("panel", StageChrome.modal_panel_style())
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(520, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var headline := "VICTORY" if won else ("RETREAT" if retreated else "DEFEAT")
	var head := StageChrome.era_label(headline)
	if won:
		head.add_theme_color_override("font_color", StageChrome.TITLE)
	elif retreated:
		head.add_theme_color_override("font_color", StageChrome.ACCENT_WARN)
	else:
		head.add_theme_color_override("font_color", StageChrome.ACCENT_DANGER)
	col.add_child(head)
	var body_text: String
	if won:
		var loot: Dictionary = result.get("loot", {})
		if _mode == "space":
			body_text = "Fleet triumphant.\nSalvage recovered · crews seasoned ×%d\nKills: %d" % [
				int(result.get("veterancy", 0)),
				int(result.get("kills_player", 0)),
			]
		else:
			body_text = "The field is yours.\nLoot +%d food · +%d wood · +%d stone\nVeterans +%d · Kills %d" % [
				int(loot.get("food", 0)),
				int(loot.get("wood", 0)),
				int(loot.get("stone", 0)),
				int(result.get("veterancy", 0)),
				int(result.get("kills_player", 0)),
			]
		AudioManager.play_sfx("win")
	elif retreated:
		body_text = "You withdraw with the survivors.\nNo loot — live to fight again."
	else:
		body_text = "The line breaks.\nSurvivors limp home empty-handed."
		AudioManager.play_sfx("lose")
	var body := StageChrome.body_label(body_text)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(body)
	var hint := StageChrome.hint_label("Continue · Space / Enter · click")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	var cont := StageChrome.make_button("Continue", "Return to the campaign", func() -> void: _fanfare_skip = true)
	cont.process_mode = Node.PROCESS_MODE_ALWAYS
	col.add_child(cont)
	var can_skip := {"ok": false}
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if can_skip["ok"] and ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_fanfare_skip = true)
	await get_tree().process_frame
	card.position = (get_viewport().get_visible_rect().size - card.size) * 0.5
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_property(dim, "color:a", 0.72, 0.25)
	card.modulate.a = 0.0
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.3)
	await tw.finished
	# Brief hold so the card isn't skipped mid-fade, then accept input / auto-continue.
	await get_tree().create_timer(0.45, true, false, true).timeout
	can_skip["ok"] = true
	var hold := 1.55 if won else 1.15
	var elapsed := 0.0
	while not _fanfare_skip and elapsed < hold:
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER):
			_fanfare_skip = true
			break
		await get_tree().process_frame
		elapsed += get_process_delta_time()
