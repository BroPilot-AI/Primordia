class_name TribeBalance

const gather_rate: float = 0.55
const hunt_yield: float = 2.0
const pop_growth_rate: float = 0.055
const food_per_person: float = 1.0
const work_area_radius: float = 10.0
const winter_fuel_burn: float = 5.0
const territory_cost: float = 20.0
const STARTING_POP: int = 10

static func value(name: String, fallback: float) -> float:
    match name:
        "gather_rate":
            return gather_rate
        "hunt_yield":
            return hunt_yield
        "pop_growth_rate":
            return pop_growth_rate
        "food_per_person":
            return food_per_person
        "work_area_radius":
            return work_area_radius
        "winter_fuel_burn":
            return winter_fuel_burn
        "territory_cost":
            return territory_cost
        "STARTING_POP":
            return float(STARTING_POP)
        _:
            return fallback
