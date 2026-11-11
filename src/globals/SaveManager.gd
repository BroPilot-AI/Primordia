## Save/Load (autoload): one JSON run save containing EvolutionState plus the
## active stage's own lightweight snapshot. Stages own their capture/restore shape;
## this manager owns slot paths, JSON safety, and defensive EvolutionState restore.
extends Node

const SAVE_DIR := "user://saves"
const FILE_EXT := ".json"
const DEFAULT_SLOT := "auto"
const LEGACY_SAVE_PATH := "user://primordia_save.cfg"

const EVOLUTION_FIELDS: Array[String] = [
	"current_stage", "progress", "world_seed", "planet_name", "biomass", "traits",
	"civ_cities", "civ_age", "civ_army", "civ_victory", "civ_army_roster",
	"civ_army_veterancy", "civ_weapon_tier", "civ_armor_tier", "civ_planet_snapshot",
	"creature_inventory", "discovered_fire", "discovered_tools",
	"tribe_population", "diet", "creature_species", "creature_name",
	"species_name", "civ_spawn",
]

var _loaded_stage_snapshot: Dictionary = {}


func _ready() -> void:
	Events.stage_changed.connect(_on_stage_changed)


func path_for(slot: String = DEFAULT_SLOT) -> String:
	var clean: String = slot.strip_edges()
	if clean == "":
		clean = DEFAULT_SLOT
	return SAVE_DIR + "/run_" + clean + FILE_EXT


func has_save(slot: String = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(path_for(slot)) or (slot == DEFAULT_SLOT and FileAccess.file_exists(LEGACY_SAVE_PATH))


func _on_stage_changed(_stage: int) -> void:
	var scene: Node = get_tree().current_scene
	if autosave_allowed(scene.scene_file_path if scene != null else ""):
		save_current(DEFAULT_SLOT)


## Only the real game autosaves; test harnesses load stages from their own
## scenes and must not overwrite the player's Continue save.
func autosave_allowed(scene_path: String) -> bool:
	return scene_path != "" and scene_path == ProjectSettings.get_setting("application/run/main_scene", "")


func save_current(slot: String = DEFAULT_SLOT) -> int:
	var state: Dictionary = {
		"version": 1,
		"current_stage": EvolutionState.current_stage,
		"evolution": capture_evolution_state(),
		"stage_snapshot": _capture_active_stage(),
	}
	return _write_slot(slot, state)


func capture_evolution_state() -> Dictionary:
	var out: Dictionary = {"version": 1}
	for field: String in EVOLUTION_FIELDS:
		out[field] = _json_safe(EvolutionState.get(field))
	if EvolutionState.genome != null:
		out["genome"] = _json_safe(EvolutionState.genome.to_dict())
	var next_spore: Variant = EvolutionState.get("_next_spore_at")
	if next_spore != null:
		out["next_spore_at"] = float(next_spore)
	return out


func restore_evolution_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	for field: String in EVOLUTION_FIELDS:
		if not data.has(field):
			continue
		var value: Variant = _from_json_value(data[field])
		if field == "traits" and value is Array:
			EvolutionState.traits.assign(value)
		else:
			EvolutionState.set(field, value)
	var genome_data: Variant = _from_json_value(data.get("genome", {}))
	if genome_data is Dictionary and not (genome_data as Dictionary).is_empty():
		EvolutionState.genome = Genome.from_dict(genome_data)
	elif EvolutionState.genome == null:
		EvolutionState.genome = Genome.new()
	if data.has("next_spore_at"):
		EvolutionState.set("_next_spore_at", float(data.get("next_spore_at", EvolutionState.SPORE_BASE_INTERVAL)))
	Events.evolution_progress_changed.emit(EvolutionState.progress)


## Restore the saved run into EvolutionState. Returns the stage index to resume at (or -1 if none).
func load_into_state(slot: String = DEFAULT_SLOT) -> int:
	_loaded_stage_snapshot = {}
	var state: Dictionary = _read_slot(slot)
	if state.is_empty():
		return _load_legacy_checkpoint() if slot == DEFAULT_SLOT else -1
	var evo_data: Variant = state.get("evolution", {})
	if evo_data is Dictionary:
		restore_evolution_state(evo_data)
	else:
		restore_evolution_state(state)
	var snapshot: Variant = _from_json_value(state.get("stage_snapshot", {}))
	if snapshot is Dictionary:
		_loaded_stage_snapshot = snapshot
	return int(state.get("current_stage", EvolutionState.current_stage))


func consume_stage_snapshot() -> Dictionary:
	var out: Dictionary = _loaded_stage_snapshot
	_loaded_stage_snapshot = {}
	return out


func clear(slot: String = DEFAULT_SLOT) -> void:
	var p: String = path_for(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if slot == DEFAULT_SLOT and FileAccess.file_exists(LEGACY_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH))


func _capture_active_stage() -> Dictionary:
	if not StageManager.has_method("current_stage_node"):
		return {}
	var stage: Node = StageManager.current_stage_node()
	if stage != null and is_instance_valid(stage) and stage.has_method("capture"):
		var data: Variant = stage.call("capture")
		if data is Dictionary:
			return _json_safe(data)
	return {}


func _write_slot(slot: String, state: Dictionary) -> int:
	var dir_abs: String = ProjectSettings.globalize_path(SAVE_DIR)
	if not DirAccess.dir_exists_absolute(dir_abs):
		var mk: int = DirAccess.make_dir_recursive_absolute(dir_abs)
		if mk != OK and mk != ERR_ALREADY_EXISTS:
			return mk
	var f: FileAccess = FileAccess.open(path_for(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(_json_safe(state), "\t"))
	f.close()
	return OK


func _read_slot(slot: String) -> Dictionary:
	var p: String = path_for(slot)
	if not FileAccess.file_exists(p):
		return {}
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var txt: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return _from_json_value(parsed)
	return {}


func _load_legacy_checkpoint() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_SAVE_PATH) != OK:
		return -1
	for field: String in EVOLUTION_FIELDS:
		var value: Variant = cfg.get_value("run", field, null)
		if value == null:
			continue
		if field == "traits" and value is Array:
			EvolutionState.traits.assign(value)
		else:
			EvolutionState.set(field, value)
	var gdict: Variant = cfg.get_value("run", "genome", {})
	if gdict is Dictionary and not (gdict as Dictionary).is_empty():
		EvolutionState.genome = Genome.from_dict(gdict)
	return int(cfg.get_value("run", "stage", EvolutionState.current_stage))


func _json_safe(value: Variant) -> Variant:
	if value is Vector2:
		var v2: Vector2 = value
		return {"__type": "Vector2", "x": v2.x, "y": v2.y}
	if value is Vector2i:
		var v2i: Vector2i = value
		return {"__type": "Vector2i", "x": v2i.x, "y": v2i.y}
	if value is Vector3:
		var v3: Vector3 = value
		return {"__type": "Vector3", "x": v3.x, "y": v3.y, "z": v3.z}
	if value is Color:
		var c: Color = value
		return {"__type": "Color", "html": c.to_html()}
	if value is Dictionary:
		var out: Dictionary = {}
		var d: Dictionary = value
		for key: Variant in d.keys():
			out[str(key)] = _json_safe(d[key])
		return out
	if value is Array:
		var arr: Array = value
		var out_arr: Array = []
		for item: Variant in arr:
			out_arr.append(_json_safe(item))
		return out_arr
	return value


func _from_json_value(value: Variant) -> Variant:
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_from_json_value(item))
		return result
	if value is Dictionary:
		var d: Dictionary = value
		var type_name: String = str(d.get("__type", ""))
		match type_name:
			"Vector2":
				return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
			"Vector2i":
				return Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
			"Vector3":
				return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))
			"Color":
				return Color.from_string(str(d.get("html", "ffffff")), Color.WHITE)
		var out: Dictionary = {}
		for key: Variant in d.keys():
			out[str(key)] = _from_json_value(d[key])
		return out
	return value
