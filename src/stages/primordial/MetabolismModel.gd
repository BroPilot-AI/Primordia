class_name MetabolismModel
## Pure-logic ATP + osmoregulation model for the primordial microbe stage.
## Mirrors the Thrive-style split: aerobic respiration in mitochondria turns
## (glucose, oxygen) into ATP, while every organelle the cell carries costs a
## baseline ATP drain to maintain osmotic balance. Starvation is non-lethal:
## ATP debt creates slowdown, stalled growth, and reversible efficiency / mass
## pressure. Data class only: no scene refs, no signals, no @onready. All inputs
## are defensive (miss -> 0).

const OrganelleEditor := preload("res://src/stages/primordial/OrganelleEditorModel.gd")

const ATP_PER_GLUCOSE: float = 32.0
const OXYGEN_PER_GLUCOSE: float = 6.0
const COMPOUND_SATURATION: float = 18.0
const COMPOUND_STORAGE_BASE: float = 24.0
const COMPOUND_STORAGE_PER_SIZE: float = 8.0
const COMPOUND_STORAGE_PER_BODY_SIZE: float = 12.0
const ATP_CAPACITY_BASE: float = 42.0
const ATP_CAPACITY_PER_SIZE: float = 12.0
const OSMO_BASE_COST: float = 0.18
const OSMO_COST_PER_SIZE: float = 0.34
const OSMO_COST_PER_ORGANELLE: float = 0.16
const OSMO_COST_PER_BODY_SIZE: float = 0.45
const MOVEMENT_BASE_COST: float = 0.18
const MOVEMENT_COST_PER_SIZE: float = 0.035
const MOVEMENT_COST_PER_FLAGELLUM: float = 0.22
const LOW_ATP_RATIO: float = 0.25
const MIN_STARVED_EFFICIENCY: float = 0.65
const STARVING_THRESHOLD: float = 0.0


static func net_atp(organelles: Dictionary, compounds: Dictionary) -> float:
	var glucose: float = float(compounds.get("glucose", 0.0))
	var oxygen: float = float(compounds.get("oxygen", 0.0))
	var mitochondria: int = int(organelles.get("mitochondria", 0))
	var total_organelles: int = _total_organelles(organelles)

	var glucose_limited: float = minf(glucose, oxygen / OXYGEN_PER_GLUCOSE)
	var atp_produced: float = glucose_limited * ATP_PER_GLUCOSE * float(mitochondria)
	var atp_drain: float = osmo_cost(total_organelles)
	return atp_produced - atp_drain


static func osmo_cost(organelle_count: int) -> float:
	if organelle_count <= 0:
		return 0.0
	return OSMO_COST_PER_ORGANELLE * float(organelle_count)


static func is_starving(net_atp_rate: float) -> bool:
	return net_atp_rate < STARVING_THRESHOLD


static func atp_capacity(layout: Array, body_size: float = 1.0) -> float:
	var layout_size := OrganelleEditor.total_size(layout)
	return maxf(ATP_CAPACITY_BASE, ATP_CAPACITY_BASE + (layout_size + maxf(0.0, body_size - 1.0)) * ATP_CAPACITY_PER_SIZE)


static func compound_storage_capacity(layout: Array, body_size: float = 1.0) -> float:
	var layout_size := OrganelleEditor.total_size(layout)
	return maxf(COMPOUND_STORAGE_BASE, COMPOUND_STORAGE_BASE + layout_size * COMPOUND_STORAGE_PER_SIZE + maxf(0.0, body_size - 1.0) * COMPOUND_STORAGE_PER_BODY_SIZE)


static func absorb_compounds(stored: Dictionary, nearby: Dictionary, layout: Array, body_size: float, delta: float) -> Dictionary:
	var rates := compound_uptake_rates(layout, body_size)
	var capacity := compound_storage_capacity(layout, body_size)
	var safe_delta := maxf(0.0, delta)
	var next := {}
	for id in ["glucose", "oxygen", "ammonia", "phosphates"]:
		var amount := _compound(stored, id)
		var nearby_level := _compound(nearby, id)
		var uptake := nearby_level * float(rates.get(id, 0.0)) * safe_delta
		next[id] = clampf(amount + uptake, 0.0, capacity)
	return next


static func production_atp_per_second(layout: Array, compounds: Dictionary, efficiency: float = 1.0) -> float:
	return float(_production_report(layout, compounds, 1.0, efficiency).get("production", 0.0))


static func osmo_upkeep_per_second(layout: Array, body_size: float = 1.0) -> float:
	var layout_size := OrganelleEditor.total_size(layout)
	var count := OrganelleEditor.total_count(layout)
	var growth_size := maxf(0.0, body_size - 1.0)
	if layout_size <= 0.0 and count <= 0:
		return 0.0
	return OSMO_BASE_COST + layout_size * OSMO_COST_PER_SIZE + float(count) * OSMO_COST_PER_ORGANELLE + growth_size * OSMO_COST_PER_BODY_SIZE


static func movement_upkeep_per_second(layout: Array, moving: bool) -> float:
	if not moving:
		return 0.0
	var layout_size := OrganelleEditor.total_size(layout)
	var flagella := OrganelleEditor.count(layout, "flagellum")
	return MOVEMENT_BASE_COST + layout_size * MOVEMENT_COST_PER_SIZE + float(flagella) * MOVEMENT_COST_PER_FLAGELLUM


static func compound_factor(compounds: Dictionary) -> float:
	var glucose := _compound(compounds, "glucose")
	var oxygen := _compound(compounds, "oxygen")
	var glucose_limited := minf(glucose, oxygen / OXYGEN_PER_GLUCOSE)
	return clampf(glucose_limited / COMPOUND_SATURATION, 0.0, 1.0)


static func telemetry(layout: Array, compounds: Dictionary, body_size: float, moving: bool, efficiency: float = 1.0) -> Dictionary:
	var production_report := _production_report(layout, compounds, 1.0, efficiency)
	var production := float(production_report.get("production", 0.0))
	var osmo := osmo_upkeep_per_second(layout, body_size)
	var movement := movement_upkeep_per_second(layout, moving)
	var upkeep := osmo + movement
	return {
		"production": production,
		"production_capacity": production_report.get("production_capacity", 0.0),
		"osmo_upkeep": osmo,
		"movement_upkeep": movement,
		"total_upkeep": upkeep,
		"net": production - upkeep,
		"compound_factor": production_report.get("compound_factor", 0.0),
		"efficiency": clampf(efficiency, MIN_STARVED_EFFICIENCY, 1.0),
		"glucose": _compound(compounds, "glucose"),
		"oxygen": _compound(compounds, "oxygen"),
		"glucose_per_second": production_report.get("glucose_per_second", 0.0),
		"oxygen_per_second": production_report.get("oxygen_per_second", 0.0),
	}


static func step_atp(current_atp: float, capacity: float, layout: Array, compounds: Dictionary, delta: float, body_size: float, moving: bool, efficiency: float = 1.0) -> Dictionary:
	var safe_capacity := maxf(1.0, capacity)
	var safe_delta := maxf(0.0, delta)
	var production_report := _production_report(layout, compounds, safe_delta, efficiency)
	var osmo := osmo_upkeep_per_second(layout, body_size)
	var movement := movement_upkeep_per_second(layout, moving)
	var upkeep := osmo + movement
	var production := float(production_report.get("production", 0.0))
	var report := {
		"production": production,
		"production_capacity": production_report.get("production_capacity", 0.0),
		"osmo_upkeep": osmo,
		"movement_upkeep": movement,
		"total_upkeep": upkeep,
		"net": production - upkeep,
		"compound_factor": production_report.get("compound_factor", 0.0),
		"efficiency": clampf(efficiency, MIN_STARVED_EFFICIENCY, 1.0),
		"glucose": _compound(compounds, "glucose"),
		"oxygen": _compound(compounds, "oxygen"),
		"glucose_per_second": production_report.get("glucose_per_second", 0.0),
		"oxygen_per_second": production_report.get("oxygen_per_second", 0.0),
		"compound_consumed": production_report.get("compound_consumed", {}),
		"next_compounds": production_report.get("next_compounds", compounds.duplicate()),
	}
	var next_atp := clampf(maxf(0.0, current_atp) + float(report.get("net", 0.0)) * safe_delta, 0.0, safe_capacity)
	var pressure := starvation_pressure(next_atp, safe_capacity, float(report.get("net", 0.0)))
	report["atp"] = next_atp
	report["atp_capacity"] = safe_capacity
	report["atp_ratio"] = clampf(next_atp / safe_capacity, 0.0, 1.0)
	report["starvation_pressure"] = pressure
	report["can_grow"] = growth_multiplier(next_atp, safe_capacity, float(report.get("net", 0.0))) > 0.0
	report["growth_multiplier"] = growth_multiplier(next_atp, safe_capacity, float(report.get("net", 0.0)))
	report["next_efficiency"] = next_efficiency(efficiency, pressure, safe_delta)
	report["size_shed_per_second"] = size_shed_per_second(pressure, body_size)
	return report


static func starvation_pressure(current_atp: float, capacity: float, net_rate: float) -> float:
	var ratio := clampf(current_atp / maxf(1.0, capacity), 0.0, 1.0)
	if net_rate >= 0.0 and ratio > 0.02:
		return 0.0
	return clampf((LOW_ATP_RATIO - ratio) / LOW_ATP_RATIO, 0.0, 1.0)


static func growth_multiplier(current_atp: float, capacity: float, net_rate: float) -> float:
	var ratio := clampf(current_atp / maxf(1.0, capacity), 0.0, 1.0)
	if ratio <= 0.02 and net_rate < 0.0:
		return 0.0
	return clampf((ratio - 0.02) / 0.28, 0.0, 1.0)


static func movement_power_factor(current_atp: float, capacity: float) -> float:
	var ratio := clampf(current_atp / maxf(1.0, capacity), 0.0, 1.0)
	if ratio <= 0.35:
		return lerpf(0.38, 1.0, ratio / 0.35)
	return 1.0 + clampf((ratio - 0.65) * 0.16, 0.0, 0.08)


static func next_efficiency(current_efficiency: float, pressure: float, delta: float) -> float:
	var target := 1.0 - clampf(pressure, 0.0, 1.0) * (1.0 - MIN_STARVED_EFFICIENCY)
	var rate := 0.05 if pressure > 0.0 else 0.16
	return move_toward(clampf(current_efficiency, MIN_STARVED_EFFICIENCY, 1.0), target, maxf(0.0, delta) * rate)


static func size_shed_per_second(pressure: float, body_size: float) -> float:
	if pressure <= 0.0:
		return 0.0
	return clampf(pressure, 0.0, 1.0) * maxf(1.0, body_size) * 0.045


static func compound_uptake_rates(layout: Array, body_size: float = 1.0) -> Dictionary:
	var layout_size := OrganelleEditor.total_size(layout)
	var metabolic_pull := maxf(0.0, OrganelleEditor.net_atp(layout)) * 0.004
	var base := 0.10 + layout_size * 0.014 + maxf(0.0, body_size - 1.0) * 0.01
	return {
		"glucose": base + metabolic_pull,
		"oxygen": base + metabolic_pull * OXYGEN_PER_GLUCOSE * 0.35,
		"ammonia": base * 0.28,
		"phosphates": base * 0.28,
	}


static func _production_report(layout: Array, compounds: Dictionary, delta: float, efficiency: float) -> Dictionary:
	var safe_delta := maxf(0.0, delta)
	var production_capacity := maxf(0.0, OrganelleEditor.net_atp(layout)) * clampf(efficiency, MIN_STARVED_EFFICIENCY, 1.0)
	if production_capacity <= 0.0 or safe_delta <= 0.0:
		return _empty_production_report(production_capacity, compounds)

	var requested_glucose := production_capacity / ATP_PER_GLUCOSE * safe_delta
	var requested_oxygen := requested_glucose * OXYGEN_PER_GLUCOSE
	var stored_glucose := _compound(compounds, "glucose")
	var stored_oxygen := _compound(compounds, "oxygen")
	var glucose_factor := 1.0 if requested_glucose <= 0.0 else clampf(stored_glucose / requested_glucose, 0.0, 1.0)
	var oxygen_factor := 1.0 if requested_oxygen <= 0.0 else clampf(stored_oxygen / requested_oxygen, 0.0, 1.0)
	var factor := minf(glucose_factor, oxygen_factor)
	var consumed_glucose := requested_glucose * factor
	var consumed_oxygen := requested_oxygen * factor
	var production := production_capacity * factor

	var next_compounds := compounds.duplicate()
	next_compounds["glucose"] = maxf(0.0, stored_glucose - consumed_glucose)
	next_compounds["oxygen"] = maxf(0.0, stored_oxygen - consumed_oxygen)
	for id in ["ammonia", "phosphates"]:
		next_compounds[id] = _compound(compounds, id)

	return {
		"production": production,
		"production_capacity": production_capacity,
		"compound_factor": factor,
		"glucose_per_second": consumed_glucose / safe_delta,
		"oxygen_per_second": consumed_oxygen / safe_delta,
		"compound_consumed": {
			"glucose": consumed_glucose,
			"oxygen": consumed_oxygen,
		},
		"next_compounds": next_compounds,
	}


static func _empty_production_report(production_capacity: float, compounds: Dictionary) -> Dictionary:
	return {
		"production": 0.0,
		"production_capacity": production_capacity,
		"compound_factor": 0.0,
		"glucose_per_second": 0.0,
		"oxygen_per_second": 0.0,
		"compound_consumed": {
			"glucose": 0.0,
			"oxygen": 0.0,
		},
		"next_compounds": compounds.duplicate(),
	}


static func _compound(compounds: Dictionary, id: String) -> float:
	var value := float(compounds.get(id, 0.0))
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(0.0, value)


static func _total_organelles(organelles: Dictionary) -> int:
	var total: int = 0
	for v in organelles.values():
		total += int(v)
	return total
