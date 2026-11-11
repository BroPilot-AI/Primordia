class_name OrganelleEditorModel

const ORGANELLES: Dictionary = {
	"mitochondria": {
		"mp_cost": 55,
		"atp": 12.0,
		"size": 2.0,
		"role": "aerobic_energy",
	},
	"chloroplast": {
		"mp_cost": 50,
		"atp": 8.0,
		"size": 2.0,
		"role": "photosynthesis",
	},
	"flagellum": {
		"mp_cost": 35,
		"atp": -3.0,
		"size": 1.5,
		"role": "movement",
	},
	"toxin_vacuole": {
		"mp_cost": 40,
		"atp": -2.0,
		"size": 1.0,
		"role": "defense",
	},
	"cytoplasm": {
		"mp_cost": 5,
		"atp": 0.5,
		"size": 1.0,
		"role": "structure",
	},
}


static func has_organelle(id: String) -> bool:
	return ORGANELLES.has(id)


static func can_add(layout: Array, id: String, mutation_points: int) -> bool:
	if not has_organelle(id):
		return false
	if mutation_points < 0:
		return false

	return mutation_points >= cost_of(id)


static func add(layout: Array, id: String) -> Array:
	var next_layout: Array = layout.duplicate()
	if has_organelle(id):
		next_layout.append(id)

	return next_layout


static func net_atp(layout: Array) -> float:
	var total: float = 0.0
	for entry: Variant in layout:
		if entry is String and has_organelle(entry):
			total += float(ORGANELLES[entry]["atp"])

	return total


static func total_size(layout: Array) -> float:
	var total: float = 0.0
	for entry: Variant in layout:
		if entry is String and has_organelle(entry):
			total += float(ORGANELLES[entry]["size"])

	return total


static func total_count(layout: Array) -> int:
	var total := 0
	for entry: Variant in layout:
		if entry is String and has_organelle(entry):
			total += 1

	return total


static func count(layout: Array, id: String) -> int:
	var total := 0
	if not has_organelle(id):
		return 0
	for entry: Variant in layout:
		if entry is String and entry == id:
			total += 1

	return total


static func atp_breakdown(layout: Array) -> Dictionary:
	var producers := {}
	var consumers := {}
	for entry: Variant in layout:
		if not (entry is String) or not has_organelle(entry):
			continue
		var id := String(entry)
		var atp := float(ORGANELLES[id]["atp"])
		var bucket := producers if atp >= 0.0 else consumers
		if not bucket.has(id):
			bucket[id] = {
				"count": 0,
				"atp_each": atp,
				"role": String(ORGANELLES[id].get("role", "")),
				"total": 0.0,
			}
		bucket[id]["count"] = int(bucket[id]["count"]) + 1
		bucket[id]["total"] = float(bucket[id]["total"]) + atp

	return {
		"producers": producers,
		"consumers": consumers,
		"net": net_atp(layout),
		"size": total_size(layout),
		"count": total_count(layout),
	}


static func cost_of(id: String) -> int:
	if not has_organelle(id):
		return 0

	return int(ORGANELLES[id]["mp_cost"])
