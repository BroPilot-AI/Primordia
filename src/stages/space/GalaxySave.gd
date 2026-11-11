class_name GalaxySave
## Pure-logic galaxy save/restore for the Space stage. No nodes, no `extends` —
## fully typed static API. Snapshot the live SpaceStage3D to a Dictionary, write
## that to a `user://` JSON file, and on reload read it back + apply. Defensive
## on bad input / missing keys (returns {} / false on miss).

const SAVE_DIR := "user://saves"
const FILE_EXT := ".json"
## Empire expansion base interval (mirrors SpaceStage3D.EMPIRE_EXPAND_BASE for capture).
const EMPIRE_EXPAND_BASE: float = 16.0

## All keys we serialize for a single system. Quoted strings (the GDScript 4.6
## gotcha). Used both to capture and to validate a restored entry.
const SYSTEM_KEYS: Array[String] = [
	"system_name", "position", "faction", "structure", "capture",
	"contender", "shielded", "has_shipyard", "evo_stage", "evo_progress",
	"emergent_ready", "bodies", "stations",
]


## Build a `user://` path for a named save slot.
static func path_for(slot: String) -> String:
	if slot == null:
		slot = ""
	var clean: String = slot.strip_edges()
	if clean == "":
		clean = "auto"
	return SAVE_DIR + "/galaxy_" + clean + FILE_EXT


## Capture a snapshot of the live SpaceStage3D into a plain Dictionary suitable
## for JSON serialization. Returns {} if `stage` is null or missing fields.
static func capture(stage) -> Dictionary:
	if stage == null:
		return {}
	var out: Dictionary = {
		"version": 4,
		"treasury": _normalize_treasury({}),
		"build_queue": [],
		"weapon_tier": 0,
		"armor_tier": 0,
		"elapsed": 0.0,
		"selected_index": -1,
		"systems": [],
		"empires": {},
		"truce_until": 0.0,
		"at_peace": {},
	}
	# Treasury + per-stage tunables. Use `get` so a partial/mocked stage still works.
	var treasury_val: Variant = stage.get("_treasury")
	if treasury_val is Dictionary:
		out["treasury"] = _normalize_treasury(treasury_val)
	else:
		var legacy_treasury: Variant = stage.get("_treasury_f")
		if legacy_treasury != null and is_finite(float(legacy_treasury)):
			out["treasury"] = _legacy_treasury(float(legacy_treasury))
	var queue_val: Variant = stage.get("_build_queue")
	if queue_val is Array:
		out["build_queue"] = _capture_queue(queue_val)
	var w = stage.get("_weapon_tier")
	if w != null:
		out["weapon_tier"] = int(w)
	var a = stage.get("_armor_tier")
	if a != null:
		out["armor_tier"] = int(a)
	var el = stage.get("_elapsed")
	if el != null and is_finite(float(el)):
		out["elapsed"] = float(el)
	# Diplomacy: galaxy-wide buyable ceasefire + bilateral AI treaties.
	var truce_val: Variant = stage.get("_truce_until")
	if truce_val != null and is_finite(float(truce_val)):
		out["truce_until"] = float(truce_val)
	var peace_val: Variant = stage.get("_at_peace")
	if peace_val is Dictionary:
		out["at_peace"] = _capture_at_peace(peace_val)
	# Empire state.
	var empires_val = stage.get("_empires")
	if empires_val is Dictionary:
		for fac in empires_val.keys():
			var f: int = int(fac)
			out["empires"][str(f)] = _capture_empire_state(empires_val[fac])
	# Per-system state.
	var systems_val = stage.get("_systems")
	if systems_val is Array:
		var sel_idx: int = -1
		var sel = stage.get("_selected_system")
		for i: int in range(systems_val.size()):
			var s = systems_val[i]
			if s == null:
				continue
			out["systems"].append(_capture_system(s))
			if sel != null and sel == s:
				sel_idx = i
		out["selected_index"] = sel_idx
	# Player fleet + turrets and the flagship. Without them Continue rebuilt only the
	# starting escort and snapped the flagship home.
	var ships_val: Variant = stage.get("_ships")
	if ships_val is Array:
		out["fleet"] = _capture_fleet(ships_val)
	var flag: Variant = stage.get("_flagship")
	if is_instance_valid(flag) and flag is Node3D:
		out["flagship"] = _capture_position((flag as Node3D).position)
	return out


static func _capture_fleet(ships: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in ships:
		if not (s is Dictionary) or int(s.get("faction", -1)) != 0 or float(s.get("hp", 0.0)) <= 0.0:
			continue
		var node: Variant = s.get("node")
		var kind := str(s.get("kind", ""))
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		if not (SpaceUnits.FLEET.has(kind) or SpaceUnits.DEFENSES.has(kind)):
			continue
		var entry: Dictionary = _capture_position((node as Node3D).position)
		entry["kind"] = kind
		entry["hp"] = float(s.hp)
		out.append(entry)
	return out


## Serialize fac→until map with string keys (JSON-safe).
static func _capture_at_peace(peace: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for fac in peace.keys():
		var until: float = float(peace[fac])
		if is_finite(until) and until > 0.0:
			out[str(int(fac))] = until
	return out


static func _normalize_treasury(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ResourceModel.all_ids():
		result[id] = float(value.get(id, 0.0))
	return result


static func _legacy_treasury(value: float) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ResourceModel.all_ids():
		result[id] = 0.0
	result["metal"] = value * 0.65
	result["energy"] = value * 0.35
	return result


static func _capture_queue(queue: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry_val: Variant in queue:
		if not (entry_val is Dictionary):
			continue
		var entry: Dictionary = entry_val
		var clean: Dictionary = {
			"kind": str(entry.get("kind", "")),
			"item": str(entry.get("item", "")),
			"time_left": float(entry.get("time_left", 0.0)),
		}
		if entry.has("system_index"):
			clean["system_index"] = int(entry["system_index"])
		if entry.has("position"):
			clean["position"] = _capture_position(entry["position"])
		out.append(clean)
	return out


static func _capture_empire_state(value: Variant) -> Dictionary:
	var out: Dictionary = {
		"timer": EMPIRE_EXPAND_BASE,
		"treasury": 0.0,
		"tech": 0.0,
		"peak": 0.0,
		"name": "",
		"collapsed": false,
	}
	if value is Dictionary:
		var emp: Dictionary = value
		out["timer"] = _finite_float(emp.get("timer", EMPIRE_EXPAND_BASE), EMPIRE_EXPAND_BASE)
		out["treasury"] = _finite_float(emp.get("treasury", 0.0), 0.0)
		out["tech"] = _finite_float(emp.get("tech", 0.0), 0.0)
		out["peak"] = _finite_float(emp.get("peak", 0.0), 0.0)
		out["name"] = str(emp.get("name", ""))
		out["collapsed"] = bool(emp.get("collapsed", false))
	else:
		out["timer"] = _finite_float(value, EMPIRE_EXPAND_BASE)
	return out


static func _finite_float(value: Variant, fallback: float) -> float:
	var f: float = float(value)
	return f if is_finite(f) else fallback


static func _capture_position(value: Variant) -> Dictionary:
	if value is Vector3:
		var pos: Vector3 = value
		return {"x": pos.x, "y": pos.y, "z": pos.z}
	if value is Dictionary:
		var p: Dictionary = value
		return {"x": float(p.get("x", 0.0)), "y": float(p.get("y", 0.0)), "z": float(p.get("z", 0.0))}
	return {"x": 0.0, "y": 0.0, "z": 0.0}


static func _capture_system(s) -> Dictionary:
	var pos: Vector3 = s.position if s is Node3D else Vector3.ZERO
	return {
		"system_name": str(_prop(s, "system_name", "")),
		"position": {"x": pos.x, "y": pos.y, "z": pos.z},
		"faction": int(_prop(s, "faction", -1)),
		"structure": str(_prop(s, "structure", "")),
		"capture": float(_prop(s, "capture", 0.0)),
		"contender": int(_prop(s, "contender", -1)),
		"shielded": bool(_prop(s, "shielded", false)),
		"has_shipyard": bool(_prop(s, "has_shipyard", false)),
		"evo_stage": int(_prop(s, "evo_stage", 0)),
		"evo_progress": float(_prop(s, "evo_progress", 0.0)),
		"emergent_ready": bool(_prop(s, "emergent_ready", false)),
		"bodies": _capture_bodies(_prop(s, "bodies", [])),
		"stations": _capture_stations(_prop(s, "stations", [])),
	}


static func _capture_bodies(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for body: Variant in value:
		result.append(str(body))
	return result


static func _capture_stations(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for id: Variant in value:
		result.append(str(id))
	return result


## Read a property with a default. Wraps `Object.get` (which returns null on miss
## instead of accepting a default) so callers can pass a typed fallback.
static func _prop(s, key: String, default: Variant) -> Variant:
	if s == null:
		return default
	var v: Variant = s.get(key)
	if v == null:
		return default
	return v


## Apply a captured snapshot back onto the live stage. Returns true on success.
## Defensive: ignores missing systems / extra fields / wrong types.
static func restore(stage, data: Dictionary) -> bool:
	if stage == null or data.is_empty():
		return false
	if not (data is Dictionary):
		return false
	# Restore stage-level tunables.
	if data.has("treasury"):
		var tv: Variant = data["treasury"]
		if tv is Dictionary:
			stage.set("_treasury", _normalize_treasury(tv))
		elif is_finite(float(tv)):
			stage.set("_treasury", _legacy_treasury(float(tv)))
	if data.has("build_queue") and data["build_queue"] is Array:
		stage.set("_build_queue", _capture_queue(data["build_queue"]))
	if data.has("weapon_tier"):
		stage.set("_weapon_tier", int(data["weapon_tier"]))
	if data.has("armor_tier"):
		stage.set("_armor_tier", int(data["armor_tier"]))
	if data.has("elapsed"):
		stage.set("_elapsed", float(data["elapsed"]))
	# Diplomacy (v4+; older saves simply leave live defaults).
	if data.has("truce_until") and is_finite(float(data["truce_until"])):
		stage.set("_truce_until", float(data["truce_until"]))
	if data.has("at_peace") and data["at_peace"] is Dictionary:
		var restored_peace: Dictionary = {}
		for fac_str in (data["at_peace"] as Dictionary).keys():
			var until: float = float(data["at_peace"][fac_str])
			if is_finite(until):
				restored_peace[int(fac_str)] = until
		stage.set("_at_peace", restored_peace)
	# Empire state. Back-compatible with v2 saves where each empire value was only
	# its timer, and permissive enough to restore emergent empire ids.
	if data.has("empires") and data["empires"] is Dictionary:
		var empires_val = stage.get("_empires")
		if empires_val is Dictionary:
			for fac_str in (data["empires"] as Dictionary).keys():
				var fac: int = int(fac_str)
				var saved: Variant = data["empires"][fac_str]
				var clean: Dictionary = _capture_empire_state(saved)
				if empires_val.has(fac):
					var existing: Dictionary = empires_val[fac]
					for key: String in clean.keys():
						existing[key] = clean[key]
				else:
					empires_val[fac] = clean
	# Restore per-system state. Match by index (same seed → same systems).
	if data.has("systems") and data["systems"] is Array:
		var systems_val = stage.get("_systems")
		var saved_systems: Array = data["systems"]
		if systems_val is Array:
			var n: int = mini(saved_systems.size(), systems_val.size())
			for i: int in range(n):
				var entry: Dictionary = saved_systems[i]
				if entry is Dictionary:
					_apply_system(systems_val[i], entry, stage)
			# Selection: by index if in range.
			var sel_idx: int = int(data.get("selected_index", -1))
			if sel_idx >= 0 and sel_idx < systems_val.size():
				stage.set("_selected_system", systems_val[sel_idx])
	# Fleet + flagship (older saves have neither and keep the fresh stage's escort).
	if data.has("fleet") and data["fleet"] is Array and stage.has_method("_restore_fleet"):
		stage.call("_restore_fleet", data["fleet"])
	if data.has("flagship") and data["flagship"] is Dictionary:
		var flag: Variant = stage.get("_flagship")
		if is_instance_valid(flag) and flag is Node3D:
			var fp: Dictionary = data["flagship"]
			var node := flag as Node3D
			node.position = Vector3(_finite_float(fp.get("x", 0.0), node.position.x), node.position.y,
				_finite_float(fp.get("z", 0.0), node.position.z))
	return true


static func _apply_system(s, entry: Dictionary, stage = null) -> void:
	if s == null:
		return
	for key: String in SYSTEM_KEYS:
		if not entry.has(key):
			continue
		match key:
			"system_name": s.set("system_name", str(entry[key]))
			"position":
				var p: Dictionary = entry[key]
				if p is Dictionary:
					s.position = Vector3(
						float(p.get("x", s.position.x)),
						float(p.get("y", s.position.y)),
						float(p.get("z", s.position.z))
					)
			"faction":
				var f: int = int(entry[key])
				# Use the stage's canonical color for the NEW owner — the system's current
				# faction_color is the PRE-load owner's and would mis-tint the ownership ring.
				var col: Color = Color(0.55, 0.55, 0.62)
				if stage != null and stage.has_method("_faction_color"):
					col = stage._faction_color(f)
				if s.has_method("set_faction"):
					s.set_faction(f, col)
				else:
					s.set("faction", f)
			"structure":
				if s.has_method("set_structure"):
					s.set_structure(str(entry[key]))
				else:
					s.set("structure", str(entry[key]))
			"capture": s.set("capture", float(entry[key]))
			"contender": s.set("contender", int(entry[key]))
			"shielded": s.set("shielded", bool(entry[key]))
			"has_shipyard": s.set("has_shipyard", bool(entry[key]))
			"evo_stage": s.set("evo_stage", int(entry[key]))
			"evo_progress": s.set("evo_progress", float(entry[key]))
			"emergent_ready": s.set("emergent_ready", bool(entry[key]))
			"bodies": s.set("bodies", _capture_bodies(entry[key]))
			"stations": s.set("stations", _capture_stations(entry[key]))


## Write a captured Dictionary to a slot on disk. Returns the Error code (OK on
## success). Creates the save dir if missing.
static func save_slot(slot: String, state: Dictionary) -> int:
	if state.is_empty():
		return ERR_INVALID_PARAMETER
	var p: String = path_for(slot)
	var dir_abs: String = ProjectSettings.globalize_path(SAVE_DIR)
	if not DirAccess.dir_exists_absolute(dir_abs):
		var mk: int = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if mk != OK and mk != ERR_ALREADY_EXISTS:
			return mk
	var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(state, "\t"))
	f.close()
	return OK


## Read a slot from disk. Returns the parsed Dictionary, or {} on miss/error.
static func load_slot(slot: String) -> Dictionary:
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
		return parsed
	return {}


## Does a save exist for this slot?
static func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot))


## Remove a save slot. Returns the Error code.
static func delete_slot(slot: String) -> int:
	var p: String = path_for(slot)
	if not FileAccess.file_exists(p):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
