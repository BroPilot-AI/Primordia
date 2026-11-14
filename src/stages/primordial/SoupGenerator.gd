## Primordial-soup stage generator. Node-based subclass of WorldGenerator: each sector
## is populated with abundant food motes (filler) plus the biome's microorganisms from
## FoodRoster. The biome is the player's LOCKED lineage branch (freshwater / saltwater /
## deep_ocean / inland), so what lives here — and what you can become — is set at birth.
class_name SoupGenerator
extends WorldGenerator

const MicrobeScene := preload("res://src/stages/primordial/Microbe.tscn")
const BuildReadoutScript := preload("res://src/stages/primordial/BuildReadout.gd")
const CompoundFieldModel := preload("res://src/stages/primordial/CompoundField.gd")

const COMPOUND_CELL_SIZE := 150.0
const CLOUD_REACH := 1.15   # a cell's puff spreads this many cell sizes out, well into its neighbours
const COMPOUND_DIFFUSE_RATE := 0.62
const COMPOUND_DECAY_RATE := 0.075
const COMPOUND_PRUNE_THRESHOLD := 0.08
const COMPOUND_KEYS := ["glucose", "oxygen", "ammonia", "phosphates"]
const COMPOUND_COLORS := {
	"glucose": Color(0.55, 1.00, 0.42, 0.0),
	"oxygen": Color(0.38, 0.78, 1.00, 0.0),
	"ammonia": Color(1.00, 0.92, 0.34, 0.0),
	"phosphates": Color(0.95, 0.48, 1.00, 0.0),
}
const NEIGHBOR_OFFSETS := [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

# Vivid mote colors — each mote is one of these; eating mostly one color leans your hue.
const MOTE_PALETTE := [
	Color(0.96, 0.84, 0.25),  # yellow
	Color(0.32, 0.85, 0.36),  # green
	Color(0.95, 0.52, 0.20),  # orange
	Color(0.26, 0.72, 0.96),  # cyan
	Color(0.85, 0.32, 0.78),  # magenta
	Color(0.78, 0.46, 0.26),  # brown
]

# Announced once as each growth tier's threats arrive (keys = threat tier).
const TIER_TOASTS := {
	1: "You're a cell now — hazards drift in. Red-ringed microbes set your growth back.",
	2: "Maturity — a predator has caught your scent. Finish growing while you evade it.",
}

## Food mote scene spawned into sectors (abundant filler).
@export var mote_scene: PackedScene
## How many motes per sector. Higher = denser soup = faster early growth.
@export var mote_density := PrimordialBalance.MOTE_DENSITY

var _branch_key := "freshwater"
var _foods: Array = []
var _compound_cells := {}
var _cloud_texture := cloud_texture()
var _compound_vents: Array = []
var _sector_vents := {}
var _survival_mp_timer := 0.0
var _threat_tier := 0

@onready var _player: Node2D = $Player


func _ready() -> void:
	# Tie generation + biome to the run's seed and the player's locked lineage branch.
	start_seed = EvolutionState.world_seed
	_branch_key = EvolutionState.genome.branch_name() if EvolutionState.genome else "freshwater"
	_foods = FoodRoster.foods_for(_branch_key)
	_add_background()
	generate()
	_build_legend()
	_add_readout()
	Events.mote_eaten.connect(_on_mote_eaten)
	_threat_tier = threat_tier(EvolutionState.progress)
	Events.evolution_progress_changed.connect(_on_progress_tier)
	Events.food_consumed.connect(_on_food_consumed)


# A tiny live readout of which trait the diet is pushing — steer your build for later stages.
func _add_readout() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var r := BuildReadoutScript.new()
	r.position = Vector2(20, 84)   # below the evolution bar + its progress label (which end ~y80)
	ui.add_child(r)


func _add_background() -> void:
	# Animated, screensaver-style biome backdrop (gradient + drifting ambient life).
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var backdrop := BiomeBackdrop.new()
	backdrop.biome = _branch_key
	layer.add_child(backdrop)


# On-screen legend so the player can tell each biome thing apart. Each row uses a tiny
# icon of the actual sprite (matching what's in the water), with a color-swatch fallback.
func _build_legend() -> void:
	if _foods.is_empty():
		return
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	# Legend in a StageChrome-styled panel, bottom-left (clears the top BuildReadout column).
	var legend := PanelContainer.new()
	legend.add_theme_stylebox_override("panel", StageChrome.panel_style())
	legend.anchor_top = 1.0
	legend.anchor_bottom = 1.0
	legend.grow_vertical = Control.GROW_DIRECTION_BEGIN
	legend.offset_left = 12.0
	legend.offset_right = 12.0 + 320.0
	legend.offset_top = -12.0
	legend.offset_bottom = -12.0
	ui.add_child(legend)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	legend.add_child(box)

	var label := EvolutionState.genome.biome_label() if EvolutionState.genome != null else _branch_key
	box.add_child(StageChrome.section_label("LIFE IN THE %s" % label.to_upper()))

	for f in _foods:
		var hazard := String(f.get("type", "EDIBLE")) == "HAZARD"
		var text := "%s — %s" % [f.get("display_name", "?"), "AVOID (hazard)" if hazard else "edible"]
		box.add_child(_legend_row(
			"res://assets/sprites/food_%s.png" % String(f.get("id", "")),
			f.get("tint", Color.WHITE), text,
			StageChrome.ACCENT_DANGER if hazard else StageChrome.STATUS))

	var pred := FoodRoster.predator_for(_branch_key)
	if not pred.is_empty():
		box.add_child(_legend_row(
			"res://assets/sprites/predator_%s.png" % String(pred.get("id", "")),
			pred.get("tint", Color(0.8, 0.3, 0.3)),
			"%s — DANGER (slow hunter, avoid)" % pred.get("display_name", "?"),
			StageChrome.ACCENT_DANGER))


# One legend row: a 28px icon (the real sprite if present, else a color swatch) + a label.
func _legend_row(icon_path: String, tint: Color, text: String, text_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	else:
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(18, 18)
		sw.color = tint
		row.add_child(sw)
	var lbl := StageChrome.status_label(text)
	lbl.add_theme_color_override("font_color", text_color)
	row.add_child(lbl)
	return row


func _physics_process(_delta: float) -> void:
	var sector_location := _current_sector * sector_size
	if _player.global_position.distance_squared_to(sector_location) <= _sector_size_squared:
		return
	var sector_offset := (_player.global_position - sector_location) / sector_size
	sector_offset.x = int(sector_offset.x)
	sector_offset.y = int(sector_offset.y)
	_update_sectors(sector_offset)


func _process(delta: float) -> void:
	_update_compound_field(delta)
	_absorb_compounds(delta)
	_survival_mp_timer += delta
	if _survival_mp_timer >= PrimordialBalance.SURVIVAL_MP_INTERVAL:
		_survival_mp_timer = 0.0
		_award_mutation_points(1)
	queue_redraw()


func _generate_sector(x_id: int, y_id: int) -> void:
	var sector_data: Array = []

	# Abundant filler food.
	_rng.seed = make_seed_for(x_id, y_id, "soup")
	if mote_scene != null:
		for _i in mote_density:
			var mote := mote_scene.instantiate()
			mote.tint = MOTE_PALETTE[_rng.randi() % MOTE_PALETTE.size()]
			add_child(mote)
			mote.position = _random_position_in(x_id, y_id)
			sector_data.append(mote)

	# Biome microorganisms from the roster (rarer; these shape the genome).
	_rng.seed = make_seed_for(x_id, y_id, "foods")
	if not _foods.is_empty():
		for _i in _rng.randi_range(PrimordialBalance.MICROBES_PER_SECTOR_MIN, PrimordialBalance.MICROBES_PER_SECTOR_MAX):
			var m := MicrobeScene.instantiate()
			m.food = _food_with_radius(_pick_food())
			add_child(m)
			m.position = _random_position_in(x_id, y_id)
			sector_data.append(m)

	# A slow biome predator to avoid (never in the starting sector).
	if not (x_id == 0 and y_id == 0):
		_rng.seed = make_seed_for(x_id, y_id, "hunter")
		var pred := FoodRoster.predator_for(_branch_key)
		if not pred.is_empty() and EvolutionState.progress >= PrimordialBalance.HUNTER_TIER_AT and _rng.randf() < 0.30:
			var h := SoupHunter.new()
			h.data = pred
			add_child(h)
			h.position = _random_position_in(x_id, y_id)
			sector_data.append(h)

	_generate_vents(x_id, y_id)
	_sectors[Vector2(x_id, y_id)] = sector_data


func _free_sector(key: Vector2) -> void:
	var sector_key := Vector2i(int(key.x), int(key.y))
	_sector_vents.erase(sector_key)
	var kept: Array = []
	for vent in _compound_vents:
		if vent.get("sector", Vector2i.ZERO) != sector_key:
			kept.append(vent)
	_compound_vents = kept
	super._free_sector(key)


## A soft round puff, full in the middle and nothing at the rim, so the puffs of neighbouring
## cells melt into one cloud.
static func cloud_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.34), Color(1.0, 1.0, 1.0, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _draw() -> void:
	var reach := Vector2.ONE * COMPOUND_CELL_SIZE * CLOUD_REACH
	for key in _compound_cells.keys():
		var compounds: Dictionary = _compound_cells[key]
		var total := _compound_total(compounds)
		if total < 3.0:
			continue
		var col := _compound_color(compounds)
		col.a = clampf(total / 3000.0, 0.02, 0.12)
		draw_texture_rect(_cloud_texture, Rect2(_cell_center(key) - reach, reach * 2.0), false, col)

	for vent in _compound_vents:
		var pos: Vector2 = vent.get("position", Vector2.ZERO)
		var pulse := 1.0 + sin(Time.get_ticks_msec() / 420.0 + pos.x * 0.01) * 0.08
		draw_circle(pos, 15.0 * pulse, Color(1.0, 0.70, 0.34, 0.38))
		draw_arc(pos, 28.0 * pulse, 0.0, TAU, 32, Color(0.45, 0.95, 1.0, 0.45), 2.0)


## 0 = Speck (no threats), 1 = Cell (hazards), 2 = Maturity (predator microbe).
static func threat_tier(progress: float) -> int:
	if progress >= PrimordialBalance.HUNTER_TIER_AT:
		return 2
	if progress >= PrimordialBalance.HAZARD_TIER_AT:
		return 1
	return 0


func _on_progress_tier(progress: float) -> void:
	var tier := threat_tier(progress)
	if tier > _threat_tier:
		_threat_tier = tier
		Events.notify.emit(TIER_TOASTS[tier])


# Edibles are common; the single hazard per biome is rarer — and absent until the Cell tier.
func _pick_food() -> Dictionary:
	var total := 0.0
	for f in _foods:
		total += _food_weight(f)
	var roll := _rng.randf() * total
	for f in _foods:
		roll -= _food_weight(f)
		if roll <= 0.0 and _food_weight(f) > 0.0:
			return f
	return _foods[0]


func _food_weight(f: Dictionary) -> float:
	if String(f.get("type", "EDIBLE")) == "EDIBLE":
		return PrimordialBalance.EDIBLE_WEIGHT
	return 0.35 if EvolutionState.progress >= PrimordialBalance.HAZARD_TIER_AT else 0.0


# Derive a body radius so high-nutrition (animal) foods are bigger — bigger = a predator
# until you outgrow it (size-gating). Stored on a copy so the const roster is untouched.
func _food_with_radius(entry: Dictionary) -> Dictionary:
	var f := entry.duplicate()
	# Much bigger than motes (radius ~8). Low-nutrition foods stay small enough to eat
	# early; rich animal foods are large = prey you must grow into (size-gating).
	f["radius"] = 15.0 + absf(float(entry.get("nutrition", 0.2))) * 55.0
	return f


func _random_position_in(x_id: int, y_id: int) -> Vector2:
	var center := Vector2(x_id * sector_size, y_id * sector_size)
	return center + Vector2(
		_rng.randf_range(-_half_sector_size, _half_sector_size),
		_rng.randf_range(-_half_sector_size, _half_sector_size)
	)


func _generate_vents(x_id: int, y_id: int) -> void:
	_rng.seed = make_seed_for(x_id, y_id, "vents")
	var sector_key := Vector2i(x_id, y_id)
	var vent_count := 0
	if x_id == 0 and y_id == 0:
		vent_count = 1
	elif _rng.randf() < _vent_chance():
		vent_count = _rng.randi_range(1, 2 if _branch_key == "deep_ocean" else 1)
	if vent_count <= 0:
		return

	if not _sector_vents.has(sector_key):
		_sector_vents[sector_key] = []
	for _i in vent_count:
		var vent := {
			"sector": sector_key,
			"position": _random_position_in(x_id, y_id),
			"strength": _rng.randf_range(34.0, 58.0) * _vent_strength_multiplier(),
			"mix": _vent_mix(),
		}
		_compound_vents.append(vent)
		_sector_vents[sector_key].append(vent)


func _update_compound_field(delta: float) -> void:
	for vent in _compound_vents:
		var key := _cell_at(vent.get("position", Vector2.ZERO))
		var cell := _compound_cell(key)
		var mix: Dictionary = vent.get("mix", {})
		var strength := float(vent.get("strength", 0.0))
		for id in COMPOUND_KEYS:
			var amount := CompoundFieldModel.vent_output(strength * float(mix.get(id, 0.0)), delta)
			cell[id] = CompoundFieldModel.emit(float(cell.get(id, 0.0)), amount)

	var snapshot := _compound_snapshot()
	var update_keys := _compound_update_keys(snapshot)
	var next_cells := {}
	for key in update_keys:
		var next := {}
		for id in COMPOUND_KEYS:
			var here := _snapshot_value(snapshot, key, id)
			var neighbor_avg := 0.0
			for offset in NEIGHBOR_OFFSETS:
				neighbor_avg += _snapshot_value(snapshot, key + offset, id)
			neighbor_avg /= float(NEIGHBOR_OFFSETS.size())
			var diffused := CompoundFieldModel.diffuse(here, neighbor_avg, COMPOUND_DIFFUSE_RATE, delta)
			next[id] = CompoundFieldModel.decay(diffused, COMPOUND_DECAY_RATE, delta)
		if _compound_total(next) > COMPOUND_PRUNE_THRESHOLD and _field_key_near_player(key):
			next_cells[key] = next
	_compound_cells = next_cells


func _absorb_compounds(delta: float) -> void:
	if _player != null and _player.has_method("absorb_compounds"):
		var player_sample := sample_compounds_at(_player.global_position)
		_player.absorb_compounds(player_sample, delta)
		if _player.has_method("get_compound_uptake_rates"):
			_drain_compounds_at_rates(_player.global_position, _player.get_compound_uptake_rates(), delta)
		else:
			var uptake := 0.16
			if _player.has_method("get_compound_uptake_rate"):
				uptake = float(_player.get_compound_uptake_rate())
			_drain_compounds_at(_player.global_position, uptake, delta)

	for contents in _sectors.values():
		if not (contents is Array):
			continue
		for item in contents:
			if not is_instance_valid(item) or not item.has_method("absorb_compounds"):
				continue
			item.absorb_compounds(sample_compounds_at(item.global_position), delta)
			_drain_compounds_at(item.global_position, 0.045, delta)


func sample_compounds_at(world_position: Vector2) -> Dictionary:
	var center := _cell_at(world_position)
	var sampled := CompoundFieldModel.COMPOUNDS.duplicate()
	var total_weight := 0.0
	for x in range(-1, 2):
		for y in range(-1, 2):
			var key := center + Vector2i(x, y)
			var cell_center := _cell_center(key)
			var weight := 1.0 / maxf(1.0, world_position.distance_to(cell_center) / COMPOUND_CELL_SIZE)
			total_weight += weight
			for id in COMPOUND_KEYS:
				sampled[id] = float(sampled.get(id, 0.0)) + CompoundFieldModel.sample(_snapshot_value(_compound_cells, key, id)) * weight
	if total_weight <= 0.0:
		return sampled
	for id in COMPOUND_KEYS:
		sampled[id] = CompoundFieldModel.sample(float(sampled.get(id, 0.0)) / total_weight)
	return sampled


func _compound_cell(key: Vector2i) -> Dictionary:
	if not _compound_cells.has(key):
		_compound_cells[key] = CompoundFieldModel.COMPOUNDS.duplicate()
	return _compound_cells[key]


func _compound_snapshot() -> Dictionary:
	var snapshot := {}
	for key in _compound_cells.keys():
		snapshot[key] = (_compound_cells[key] as Dictionary).duplicate()
	return snapshot


func _compound_update_keys(snapshot: Dictionary) -> Array:
	var keys := {}
	for key in snapshot.keys():
		if _compound_total(snapshot[key]) <= COMPOUND_PRUNE_THRESHOLD:
			continue
		keys[key] = true
		for offset in NEIGHBOR_OFFSETS:
			keys[key + offset] = true
	return keys.keys()


func _snapshot_value(snapshot: Dictionary, key: Vector2i, id: String) -> float:
	if not snapshot.has(key):
		return 0.0
	return float((snapshot[key] as Dictionary).get(id, 0.0))


func _drain_compounds_at(world_position: Vector2, rate: float, delta: float) -> void:
	var key := _cell_at(world_position)
	if not _compound_cells.has(key):
		return
	var cell: Dictionary = _compound_cells[key]
	for id in COMPOUND_KEYS:
		cell[id] = CompoundFieldModel.decay(float(cell.get(id, 0.0)), rate, delta)


func _drain_compounds_at_rates(world_position: Vector2, rates: Dictionary, delta: float) -> void:
	var key := _cell_at(world_position)
	if not _compound_cells.has(key):
		return
	var cell: Dictionary = _compound_cells[key]
	for id in COMPOUND_KEYS:
		cell[id] = CompoundFieldModel.decay(float(cell.get(id, 0.0)), float(rates.get(id, 0.0)), delta)


func _cell_at(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / COMPOUND_CELL_SIZE), floori(world_position.y / COMPOUND_CELL_SIZE))


func _cell_center(key: Vector2i) -> Vector2:
	return Vector2(float(key.x) + 0.5, float(key.y) + 0.5) * COMPOUND_CELL_SIZE


func _field_key_near_player(key: Vector2i) -> bool:
	if _player == null:
		return true
	var max_dist := sector_size * (float(_half_sector_count) + 1.0)
	return _cell_center(key).distance_squared_to(_player.global_position) <= max_dist * max_dist


func _compound_total(compounds: Dictionary) -> float:
	var total := 0.0
	for id in COMPOUND_KEYS:
		total += CompoundFieldModel.sample(float(compounds.get(id, 0.0)))
	return total


func _compound_color(compounds: Dictionary) -> Color:
	var total := maxf(_compound_total(compounds), 0.001)
	var color := Color(0.0, 0.0, 0.0, 0.0)
	for id in COMPOUND_KEYS:
		var c: Color = COMPOUND_COLORS[id]
		var weight := CompoundFieldModel.sample(float(compounds.get(id, 0.0))) / total
		color.r += c.r * weight
		color.g += c.g * weight
		color.b += c.b * weight
	return color


func _vent_chance() -> float:
	match _branch_key:
		"deep_ocean":
			return 0.82
		"saltwater":
			return 0.58
		"inland":
			return 0.46
		_:
			return 0.54


func _vent_strength_multiplier() -> float:
	return 1.35 if _branch_key == "deep_ocean" else 1.0


func _vent_mix() -> Dictionary:
	match _branch_key:
		"deep_ocean":
			return {"glucose": 0.45, "oxygen": 0.25, "ammonia": 1.15, "phosphates": 1.0}
		"saltwater":
			return {"glucose": 0.75, "oxygen": 1.05, "ammonia": 0.45, "phosphates": 1.05}
		"inland":
			return {"glucose": 1.05, "oxygen": 0.60, "ammonia": 0.95, "phosphates": 0.70}
		_:
			return {"glucose": 1.0, "oxygen": 0.95, "ammonia": 0.65, "phosphates": 0.82}


func _on_mote_eaten(_amount: float) -> void:
	_award_mutation_points(1)


func _on_food_consumed(food: Dictionary) -> void:
	if String(food.get("type", "EDIBLE")) != "EDIBLE":
		return
	var nutrition := float(food.get("nutrition", 0.0))
	_award_mutation_points(maxi(2, int(round(nutrition * 10.0))))


func _award_mutation_points(amount: int) -> void:
	if _player != null and _player.has_method("earn_mutation_points"):
		_player.earn_mutation_points(amount)


func capture() -> Dictionary:
	return {
		"version": 1,
		"branch_key": _branch_key,
		"current_sector": _vec2_to_dict(_current_sector),
		"survival_mp_timer": _survival_mp_timer,
		"player": _capture_player(),
		"compound_cells": _capture_compound_cells(),
		"compound_vents": _capture_compound_vents(),
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	_branch_key = str(data.get("branch_key", _branch_key))
	_current_sector = _dict_to_vec2(data.get("current_sector", _vec2_to_dict(_current_sector)), _current_sector)
	_survival_mp_timer = _finite_float(data.get("survival_mp_timer", _survival_mp_timer), _survival_mp_timer)
	_restore_player(data.get("player", {}))
	_regenerate_sector_window()
	_restore_compound_cells(data.get("compound_cells", []))
	_restore_compound_vents(data.get("compound_vents", []))
	Events.evolution_progress_changed.emit(EvolutionState.progress)


func _capture_player() -> Dictionary:
	var out: Dictionary = {"position": _vec2_to_dict(Vector2.ZERO)}
	if _player == null:
		return out
	out["position"] = _vec2_to_dict(_player.global_position)
	if _player is Germ:
		var germ: Germ = _player as Germ
		var editor: Dictionary = germ.get_editor_snapshot()
		out["mutation_points"] = germ.mutation_points
		out["organelle_layout"] = germ.organelle_layout.duplicate()
		out["atp"] = germ.atp
		out["ambient_atp"] = germ.ambient_atp
		out["body_size"] = float(editor.get("body_size", 1.0))
		out["efficiency"] = float(editor.get("efficiency", 1.0))
		out["compounds"] = editor.get("compounds", {})
	return out


func _restore_player(value: Variant) -> void:
	if not (value is Dictionary) or _player == null:
		return
	var data: Dictionary = value
	_player.global_position = _dict_to_vec2(data.get("position", {}), _player.global_position)
	if _player is Germ:
		var germ: Germ = _player as Germ
		germ.mutation_points = int(data.get("mutation_points", germ.mutation_points))
		var layout_val: Variant = data.get("organelle_layout", germ.organelle_layout)
		if layout_val is Array:
			germ.organelle_layout.assign(layout_val)
		germ.atp = _finite_float(data.get("atp", germ.atp), germ.atp)
		germ.ambient_atp = _finite_float(data.get("ambient_atp", germ.ambient_atp), germ.ambient_atp)
		germ.set("_size", _finite_float(data.get("body_size", 1.0), 1.0))
		germ.set("_metabolic_efficiency", _finite_float(data.get("efficiency", 1.0), 1.0))
		var compounds_val: Variant = data.get("compounds", {})
		if compounds_val is Dictionary:
			germ.set("_last_compounds", compounds_val)
		germ.call("_apply_organelle_stats")


func _regenerate_sector_window() -> void:
	var keys: Array = _sectors.keys()
	for key: Variant in keys:
		if key is Vector2:
			_free_sector(key)
	_compound_vents.clear()
	_sector_vents.clear()
	for x: int in range(int(_current_sector.x) - _half_sector_count, int(_current_sector.x) + _half_sector_count):
		for y: int in range(int(_current_sector.y) - _half_sector_count, int(_current_sector.y) + _half_sector_count):
			_generate_sector(x, y)


func _capture_compound_cells() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: Variant in _compound_cells.keys():
		if not (key is Vector2i):
			continue
		out.append({
			"cell": _vec2i_to_dict(key),
			"compounds": (_compound_cells[key] as Dictionary).duplicate(),
		})
	return out


func _restore_compound_cells(value: Variant) -> void:
	_compound_cells.clear()
	if not (value is Array):
		return
	for item: Variant in value:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item
		var cell: Vector2i = _dict_to_vec2i(entry.get("cell", {}), Vector2i.ZERO)
		var compounds_val: Variant = entry.get("compounds", {})
		if compounds_val is Dictionary:
			var clean: Dictionary = CompoundFieldModel.COMPOUNDS.duplicate()
			for id: String in COMPOUND_KEYS:
				clean[id] = _finite_float((compounds_val as Dictionary).get(id, 0.0), 0.0)
			_compound_cells[cell] = clean


func _capture_compound_vents() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for vent_val: Variant in _compound_vents:
		if not (vent_val is Dictionary):
			continue
		var vent: Dictionary = vent_val
		out.append({
			"sector": _vec2i_to_dict(vent.get("sector", Vector2i.ZERO)),
			"position": _vec2_to_dict(vent.get("position", Vector2.ZERO)),
			"strength": _finite_float(vent.get("strength", 0.0), 0.0),
			"mix": (vent.get("mix", {}) as Dictionary).duplicate() if vent.get("mix", {}) is Dictionary else {},
		})
	return out


func _restore_compound_vents(value: Variant) -> void:
	_compound_vents.clear()
	_sector_vents.clear()
	if not (value is Array):
		return
	for item: Variant in value:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item
		var sector: Vector2i = _dict_to_vec2i(entry.get("sector", {}), Vector2i.ZERO)
		var vent: Dictionary = {
			"sector": sector,
			"position": _dict_to_vec2(entry.get("position", {}), Vector2.ZERO),
			"strength": _finite_float(entry.get("strength", 0.0), 0.0),
			"mix": entry.get("mix", {}) if entry.get("mix", {}) is Dictionary else {},
		}
		_compound_vents.append(vent)
		if not _sector_vents.has(sector):
			_sector_vents[sector] = []
		_sector_vents[sector].append(vent)


func _vec2_to_dict(value: Variant) -> Dictionary:
	var v: Vector2 = value if value is Vector2 else Vector2.ZERO
	return {"x": v.x, "y": v.y}


func _vec2i_to_dict(value: Variant) -> Dictionary:
	var v: Vector2i = value if value is Vector2i else Vector2i.ZERO
	return {"x": v.x, "y": v.y}


func _dict_to_vec2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		return Vector2(_finite_float(d.get("x", fallback.x), fallback.x), _finite_float(d.get("y", fallback.y), fallback.y))
	return fallback


func _dict_to_vec2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		return Vector2i(int(d.get("x", fallback.x)), int(d.get("y", fallback.y)))
	return fallback


func _finite_float(value: Variant, fallback: float) -> float:
	var f: float = float(value)
	return f if is_finite(f) else fallback
