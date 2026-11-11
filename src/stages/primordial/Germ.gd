## Player-controlled germ in the primordial soup. Swims with WASD/arrows, grows as it
## eats, and VISIBLY expresses its genome: the body tints toward the diet color, a vivid
## membrane shows that color, and it grows spikes (defensive diet) / cilia (mobile diet).
## Uses germ_base.png (a neutral, fully-tintable base) when present, else germ.png.
class_name Germ
extends CharacterBody2D

const TEXTURE_BODY_RADIUS := 95.0
const SporeScript := preload("res://src/stages/primordial/Spore.gd")
const OrganelleEditor := preload("res://src/stages/primordial/OrganelleEditorModel.gd")
const CompoundFieldModel := preload("res://src/stages/primordial/CompoundField.gd")
const Metabolism := preload("res://src/stages/primordial/MetabolismModel.gd")
const Appearance := preload("res://src/stages/primordial/GermAppearance.gd")

@export var speed := 340.0

# A starving / heavily-grown germ still has to be able to swim AWAY from a cruising soup
# hunter — that's the whole avoid-the-predator design (see SoupHunter docstring). This floor
# MUST stay above the fastest FoodRoster predator cruise (nematode, 104) or the player gets
# trapped at low ATP and can never break the lunge range to eat / bud a defensive spore.
const SWIM_FLOOR := 150.0

var radius := 24.0
var mutation_points := 12
var organelle_layout: Array[String] = ["cytoplasm"]
var ambient_atp := 0.0
var atp := 38.0

var _size := 1.0
var _t := 0.0
var _circle: CircleShape2D
var _sprite: Sprite2D
var _base_speed := 340.0
var _layout_atp := 0.0
var _layout_size := 0.0
var _atp_capacity := 54.0
var _is_moving := false
var _metabolic_efficiency := 1.0
var _last_compounds: Dictionary = CompoundFieldModel.COMPOUNDS.duplicate()
var _nearby_compounds: Dictionary = CompoundFieldModel.COMPOUNDS.duplicate()
var _metabolism_report: Dictionary = {}

# Organelle-driven appearance state. Features are CHILD NODES of `_features_root`
# (Polygon2D / Line2D) — cheap to animate per-frame, free to rebuild on layout change.
# `_features_signature` lets us skip the rebuild when the layout didn't change
# (called every frame from _apply_organelle_stats).
var _features_root: Node2D
var _features_signature := ""
var _features_built_radius := 24.0
var _tail_lines: Array[Line2D] = []
var _spike_polys: Array[Polygon2D] = []
var _patch_polys: Array[Polygon2D] = []
var _ova_polys: Array[Polygon2D] = []
var _bump_polys: Array[Polygon2D] = []


func _ready() -> void:
	add_to_group("player")
	Events.spore_budded.connect(_on_spore_budded)
	_base_speed = speed

	_sprite = Sprite2D.new()
	var base_path := "res://assets/sprites/germ_base.png"
	_sprite.texture = load(base_path) if ResourceLoader.exists(base_path) else load("res://assets/sprites/germ.png")
	add_child(_sprite)

	# Organelle features sit IN FRONT of the body sprite (z=+1) so internal patches /
	# ovas show through the membrane, and rim spikes / bumps clearly extend past it.
	# Tails reach out past the membrane edge so they read regardless of z.
	_features_root = Node2D.new()
	_features_root.z_index = 1
	add_child(_features_root)

	_circle = CircleShape2D.new()
	_circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = _circle
	add_child(shape)

	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()

	_apply_organelle_stats()


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_is_moving = dir.length_squared() > 0.01
	velocity = dir * speed
	move_and_slide()


# Smoothly tint the body toward the genome color, and redraw the genome features.
func _process(delta: float) -> void:
	_t += delta
	_apply_organelle_stats()
	if EvolutionState.genome != null:
		_sprite.modulate = _sprite.modulate.lerp(EvolutionState.genome.color, delta * 3.0)
	_animate_features(delta)
	queue_redraw()


## Increase mass. Growth is sub-linear (sqrt) so the germ doesn't balloon instantly, and
## each meal adds less to a bigger body (diminishing returns) so it can't snowball.
func grow(amount: float) -> void:
	var multiplier := Metabolism.growth_multiplier(atp, _atp_capacity, float(_metabolism_report.get("net", 0.0)))
	if multiplier <= 0.0:
		return
	_size += amount * multiplier / _size
	_apply_size()


## Shrink from damage, floored at the base size — non-lethal setback.
func harm(amount: float) -> void:
	_size = maxf(1.0, _size - amount)
	_apply_size()


func earn_mutation_points(amount: int) -> void:
	if amount <= 0:
		return
	mutation_points = mini(999, mutation_points + amount)


func add_organelle(id: String) -> bool:
	if not OrganelleEditor.can_add(organelle_layout, id, mutation_points):
		return false
	mutation_points -= OrganelleEditor.cost_of(id)
	# OrganelleEditor.add() returns an untyped Array; .assign() copies it into the
	# typed Array[String] without the hard type-mismatch crash that a direct = causes.
	organelle_layout.assign(OrganelleEditor.add(organelle_layout, id))
	_apply_organelle_stats()
	Events.notify.emit("Added %s" % _display_organelle(id))
	AudioManager.play_sfx("soup_mutate")
	return true


func absorb_compounds(compounds: Dictionary, delta: float) -> void:
	for id in CompoundFieldModel.COMPOUNDS.keys():
		_nearby_compounds[id] = CompoundFieldModel.sample(float(compounds.get(id, 0.0)))

	_last_compounds = Metabolism.absorb_compounds(_last_compounds, _nearby_compounds, organelle_layout, _size, delta)

	_atp_capacity = Metabolism.atp_capacity(organelle_layout, _size)
	_metabolism_report = Metabolism.step_atp(
		atp,
		_atp_capacity,
		organelle_layout,
		_last_compounds,
		delta,
		_size,
		_is_moving,
		_metabolic_efficiency
	)
	atp = float(_metabolism_report.get("atp", atp))
	_last_compounds = (_metabolism_report.get("next_compounds", _last_compounds) as Dictionary).duplicate()
	ambient_atp = float(_metabolism_report.get("production", 0.0))
	_metabolic_efficiency = float(_metabolism_report.get("next_efficiency", _metabolic_efficiency))

	var pressure := float(_metabolism_report.get("starvation_pressure", 0.0))
	if pressure > 0.0:
		_size = maxf(1.0, _size - float(_metabolism_report.get("size_shed_per_second", 0.0)) * delta)
	_apply_organelle_stats()


func get_compound_uptake_rate() -> float:
	var rates := Metabolism.compound_uptake_rates(organelle_layout, _size)
	return float(rates.get("glucose", 0.12))


func get_compound_uptake_rates() -> Dictionary:
	return Metabolism.compound_uptake_rates(organelle_layout, _size)


func get_editor_snapshot() -> Dictionary:
	return {
		"mp": mutation_points,
		"layout": organelle_layout.duplicate(),
		"layout_atp": _layout_atp,
		"ambient_atp": ambient_atp,
		"total_atp": atp,
		"atp": atp,
		"atp_capacity": _atp_capacity,
		"net_atp_per_second": float(_metabolism_report.get("net", 0.0)),
		"size": _layout_size,
		"body_size": _size,
		"speed": speed,
		"efficiency": _metabolic_efficiency,
		"can_grow": bool(_metabolism_report.get("can_grow", true)),
		"metabolism": _metabolism_report.duplicate(),
		"organelle_flows": OrganelleEditor.atp_breakdown(organelle_layout),
		"compounds": _last_compounds.duplicate(),
		"nearby_compounds": _nearby_compounds.duplicate(),
		"compound_storage_capacity": Metabolism.compound_storage_capacity(organelle_layout, _size),
	}


func _apply_size() -> void:
	var organelle_bulk := 1.0 + _layout_size * 0.035
	radius = 24.0 * sqrt(_size) * organelle_bulk
	if _circle != null:
		_circle.radius = radius
	if _sprite != null:
		_sprite.scale = Vector2.ONE * (radius / TEXTURE_BODY_RADIUS)
	_update_features_scale()


## Current body radius — read by microbes for size-gated eating.
func get_radius() -> float:
	return radius


func _apply_organelle_stats() -> void:
	_layout_atp = OrganelleEditor.net_atp(organelle_layout)
	_layout_size = OrganelleEditor.total_size(organelle_layout)
	_atp_capacity = Metabolism.atp_capacity(organelle_layout, _size)
	atp = clampf(atp, 0.0, _atp_capacity)
	var flagella := _count_organelle("flagellum")
	var power := Metabolism.movement_power_factor(atp, _atp_capacity)
	var atp_factor := clampf(float(_metabolism_report.get("net", 0.0)) / 24.0, -0.18, 0.12)
	var size_drag := clampf(maxf(0.0, _layout_size - 1.0) * 0.028, 0.0, 0.30)
	var movement_bonus := float(flagella) * 0.16
	speed = maxf(SWIM_FLOOR, _base_speed * power * maxf(0.35, 1.0 + atp_factor + movement_bonus - size_drag))
	_apply_size()
	_maybe_rebuild_features()


func _count_organelle(id: String) -> int:
	var count := 0
	for entry in organelle_layout:
		if entry == id:
			count += 1
	return count


func _display_organelle(id: String) -> String:
	return id.replace("_", " ").capitalize()


# Drop a defensive spore at the current position (budded by EvolutionState at milestones).
# Deferred add — we're inside the eat→progress signal chain (mid physics flush).
func _on_spore_budded(strength: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var spore := SporeScript.new()
	spore.setup(strength)
	spore.position = position
	parent.call_deferred("add_child", spore)


# Diet-color membrane glow + outer arc. Per-organelle features (tails, spikes, etc.)
# live as child nodes built by _rebuild_features() and animated in _animate_features().
func _draw() -> void:
	var g := EvolutionState.genome
	if g == null:
		return
	var col: Color = g.color
	# Vivid diet-colored membrane — the clearest "you are what you eat" signal.
	draw_circle(Vector2.ZERO, radius * 1.16, Color(col.r, col.g, col.b, 0.30))
	draw_arc(Vector2.ZERO, radius * 1.04, 0.0, TAU, 40, col, 4.0)


# === Organelle-driven appearance =============================================================
# Each entry in `organelle_layout` adds a VISIBLE feature so two different builds read
# distinctly at a glance (the 2D analog of GenomeFeatures3D for creatures). Mapping +
# pure-logic counts live in GermAppearance; here we own the Node2D children & animation.

func _maybe_rebuild_features() -> void:
	# Cheap: just a string compare — skips the rebuild every frame when nothing changed.
	if _features_root == null:
		return
	var sig := Appearance.layout_signature(organelle_layout)
	if sig == _features_signature:
		return
	_rebuild_features()


func _rebuild_features() -> void:
	if _features_root == null:
		return
	_features_signature = Appearance.layout_signature(organelle_layout)
	_features_built_radius = maxf(radius, 1.0)
	for c in _features_root.get_children():
		c.queue_free()
	_tail_lines.clear()
	_spike_polys.clear()
	_patch_polys.clear()
	_ova_polys.clear()
	_bump_polys.clear()
	var counts := Appearance.feature_counts(organelle_layout)
	var col: Color = (EvolutionState.genome.color
		if EvolutionState.genome != null else Color(0.72, 0.74, 0.68))
	_build_tails(int(counts.get("tail", 0)), col)
	_build_spikes(int(counts.get("spike", 0)), col)
	_build_patches(int(counts.get("patch", 0)))
	_build_ovas(int(counts.get("ova", 0)), col)
	_build_bumps(int(counts.get("bump", 0)), col)
	_update_features_scale()


func _update_features_scale() -> void:
	if _features_root == null or _features_built_radius <= 0.0:
		return
	_features_root.scale = Vector2.ONE * (radius / _features_built_radius)


func _build_tails(n: int, col: Color) -> void:
	if n <= 0:
		return
	# Fan tails around PI (rear). 1 tail = dead-rear; N tails = ±spread fan.
	var spread := 0.55
	var tail_col := col.darkened(0.20)
	for i in n:
		var fan: float = 0.0 if n <= 1 else (float(i) / float(n - 1) - 0.5) * 2.0
		var angle: float = PI + fan * spread
		var line := Line2D.new()
		line.width = 5.0
		line.default_color = tail_col
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		var dir := Vector2(cos(angle), sin(angle))
		var pts := PackedVector2Array()
		for j in 8:
			var d: float = _features_built_radius * (1.00 + float(j) * 0.22)
			pts.append(dir * d)
		line.points = pts
		line.set_meta("angle", angle)
		line.set_meta("phase", float(i) * 0.7)
		_features_root.add_child(line)
		_tail_lines.append(line)


func _build_spikes(n: int, col: Color) -> void:
	if n <= 0:
		return
	var tip_col := col.darkened(0.30)
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x) * (_features_built_radius * 0.11)
		var base := dir * _features_built_radius
		var tip := dir * (_features_built_radius * 1.42)
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([base - perp, base + perp, tip])
		p.color = tip_col
		p.set_meta("phase", float(i) * 0.5)
		_features_root.add_child(p)
		_spike_polys.append(p)


func _build_patches(n: int) -> void:
	if n <= 0:
		return
	var green := Color(0.30, 0.85, 0.40, 0.85)
	# Deterministic placement keyed off the layout: rebuilding the same build (e.g.
	# after a save/load) puts the chloroplast patches in the SAME spots — no flicker.
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(_features_signature + "patch"))
	for i in n:
		var a: float = rng.randf() * TAU
		var d: float = rng.randf_range(0.25, 0.80) * _features_built_radius
		var s: float = _features_built_radius * rng.randf_range(0.14, 0.22)
		var p := _circle_polygon(s, 10)
		p.color = green
		p.position = Vector2(cos(a), sin(a)) * d
		p.set_meta("phase", rng.randf() * TAU)
		_features_root.add_child(p)
		_patch_polys.append(p)


func _build_ovas(n: int, col: Color) -> void:
	if n <= 0:
		return
	# Mitochondria read as warm internal organelles — orange-red blended slightly toward
	# the diet color so they sit in the cell's palette rather than clashing.
	var ova_col := Color(0.95, 0.55, 0.30, 0.85).lerp(col, 0.18)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(_features_signature + "ova"))
	for i in n:
		var a: float = rng.randf() * TAU
		var d: float = rng.randf_range(0.20, 0.65) * _features_built_radius
		var rx: float = _features_built_radius * 0.11
		var ry: float = _features_built_radius * 0.06
		var p := _ellipse_polygon(rx, ry, 14)
		p.color = ova_col
		p.position = Vector2(cos(a), sin(a)) * d
		p.rotation = a + PI * 0.5
		p.set_meta("phase", rng.randf() * TAU)
		_features_root.add_child(p)
		_ova_polys.append(p)


func _build_bumps(n: int, col: Color) -> void:
	if n <= 0:
		return
	# Cytoplasm = structure → soft blisters that fatten the silhouette around the rim
	# (the "rounder/thicker rim" silhouette tweak called out by the visuals brief).
	var bump_col := col.lerp(Color(1, 1, 1), 0.20)
	bump_col.a = 0.72
	for i in n:
		var a: float = TAU * (float(i) + 0.5) / float(n) + 0.6
		var dir := Vector2(cos(a), sin(a))
		var p := _circle_polygon(_features_built_radius * 0.22, 14)
		p.color = bump_col
		p.position = dir * _features_built_radius * 1.02
		_features_root.add_child(p)
		_bump_polys.append(p)


static func _circle_polygon(r: float, segments: int) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in segments:
		var a: float = TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * r)
	p.polygon = pts
	return p


static func _ellipse_polygon(rx: float, ry: float, segments: int) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in segments:
		var a: float = TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	p.polygon = pts
	return p


# Per-frame animation: tails sway harder while moving, spikes pulse, patches shimmer,
# mitochondria gently breathe. Also re-tints membrane-anchored features toward the
# current genome.color so diet-shift recolors the spikes/bumps/tails smoothly without
# a full rebuild.
func _animate_features(delta: float) -> void:
	if _features_root == null:
		return
	var col: Color = (EvolutionState.genome.color
		if EvolutionState.genome != null else Color(0.72, 0.74, 0.68))
	var lerp_speed: float = delta * 2.4

	# Tails: wave amplitude scales with movement (reuses the existing wiggle feel).
	var wave_amp: float = 0.34 if _is_moving else 0.14
	for tail in _tail_lines:
		if not is_instance_valid(tail):
			continue
		var ang: float = float(tail.get_meta("angle", PI))
		var phase: float = float(tail.get_meta("phase", 0.0))
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array()
		for j in 8:
			var t: float = float(j) / 7.0
			var d: float = _features_built_radius * (1.00 + float(j) * 0.22)
			var wob: float = sin(_t * 7.0 + phase + t * 3.2) * _features_built_radius * wave_amp * t
			pts.append(dir * d + perp * wob)
		tail.points = pts
		tail.default_color = tail.default_color.lerp(col.darkened(0.20), lerp_speed)

	# Spikes: subtle pulse + diet-color tracking.
	var spike_target := col.darkened(0.30)
	for i in _spike_polys.size():
		var sp := _spike_polys[i]
		if not is_instance_valid(sp):
			continue
		var phase: float = float(sp.get_meta("phase", 0.0))
		var s: float = 1.0 + sin(_t * 3.0 + phase) * 0.06
		sp.scale = Vector2.ONE * s
		sp.color = sp.color.lerp(spike_target, lerp_speed)

	# Chloroplast patches: shimmer alpha (photosynthesis "blink").
	for i in _patch_polys.size():
		var pt := _patch_polys[i]
		if not is_instance_valid(pt):
			continue
		var phase: float = float(pt.get_meta("phase", 0.0))
		var a: float = clampf(0.70 + sin(_t * 2.0 + phase) * 0.18, 0.30, 1.0)
		var c := pt.color
		pt.color = Color(c.r, c.g, c.b, a)

	# Mitochondria ovas: gentle stretch/squash (a "breathing" pulse).
	for i in _ova_polys.size():
		var ov := _ova_polys[i]
		if not is_instance_valid(ov):
			continue
		var phase: float = float(ov.get_meta("phase", 0.0))
		var s: float = 1.0 + sin(_t * 4.5 + phase) * 0.10
		ov.scale = Vector2(s, 1.0 / s)

	# Cytoplasm bumps: track the diet color (membrane-tied, so they should follow tint).
	var bump_target := col.lerp(Color(1, 1, 1), 0.20)
	bump_target.a = 0.72
	for b in _bump_polys:
		if not is_instance_valid(b):
			continue
		b.color = b.color.lerp(bump_target, lerp_speed)
