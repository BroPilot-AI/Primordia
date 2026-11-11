class_name SpaceUnits

# Warships — built at a Shipyard, commandable. Yuri-style weapon types via attack_kind.
# `sprite` = legacy 2D stem; the 3D hull is HULL[kind] below. Spatial stats
# (attack_range / move_speed / aggro_range / splash_radius) are in 2D pixels — SpaceStage3D
# scales them down (SPACE_SCALE) for the galaxy's unit space.
const FLEET := {
	"Fighter":      {cost = 3.0,  max_hp = 16.0, damage = 5.0,  attack_range = 80.0,  attack_cooldown = 0.6, move_speed = 170.0, aggro_range = 300.0, attack_kind = "single",     is_flying = true,  sprite = "ship_fighter"},
	"Bomber":       {cost = 5.0,  max_hp = 24.0, damage = 11.0, attack_range = 110.0, attack_cooldown = 1.4, move_speed = 120.0, aggro_range = 300.0, attack_kind = "splash",     splash_radius = 70.0, is_flying = true, sprite = "ship_bomber"},
	"Cruiser":      {cost = 7.0,  max_hp = 44.0, damage = 9.0,  attack_range = 120.0, attack_cooldown = 1.0, move_speed = 110.0, aggro_range = 320.0, attack_kind = "single",     sprite = "ship_cruiser"},
	"Battleship":   {cost = 14.0, max_hp = 90.0, damage = 16.0, attack_range = 150.0, attack_cooldown = 1.3, move_speed = 80.0,  aggro_range = 340.0, attack_kind = "single",     sprite = "ship_battleship"},
	"ArcFrigate":   {cost = 9.0,  max_hp = 40.0, damage = 8.0,  attack_range = 120.0, attack_cooldown = 1.1, move_speed = 120.0, aggro_range = 320.0, attack_kind = "chain",      chain_count = 2, sprite = "ship_arcfrigate"},
	"PrismCruiser": {cost = 12.0, max_hp = 55.0, damage = 12.0, attack_range = 170.0, attack_cooldown = 1.4, move_speed = 100.0, aggro_range = 340.0, attack_kind = "beam_split", chain_count = 3, sprite = "ship_prismcruiser"},
	"Carrier":      {cost = 18.0, max_hp = 120.0,damage = 4.0,  attack_range = 90.0,  attack_cooldown = 2.0, move_speed = 70.0,  aggro_range = 300.0, attack_kind = "single",     spawns = "Fighter", sprite = "ship_carrier"},
	"Infestor":     {cost = 11.0, max_hp = 38.0, damage = 7.0,  attack_range = 100.0, attack_cooldown = 1.2, move_speed = 110.0, aggro_range = 320.0, attack_kind = "single",     bio = true, sprite = "ship_infestor"},
}

# Quaternius hulls for the fleet (Space = more serious/realistic than the cute Kenney kits). The
# galaxy map and the fleet battle both draw these, so a ship looks the same in either.
const HULL_PATH := "res://assets/models/quaternius_ships/%s.glb"
const HULL := {
	"Fighter": "fighter", "Bomber": "bomber", "Cruiser": "cruiser", "Battleship": "battleship",
	"ArcFrigate": "frigate", "PrismCruiser": "prism", "Carrier": "carrier", "Infestor": "enemy_flying",
}
# Per-hull orientation fixes (degrees about X) — some models are authored nose-up (launch pose);
# pitch them flat so they fly horizontally nose-forward.
const HULL_PITCH := {"Carrier": -90.0}


# Overall hull length after fitting (capital ships read bigger).
static func hull_size(kind: String) -> float:
	return 3.0 if kind in ["Battleship", "Carrier"] else 2.2


# Turn a hull's content so it leads with its nose under plain look_at (which steers along -Z).
# glTF hulls are authored nose +Z, so they turn 180°; a nose-up hull's pitch already lands its nose
# on -Z. Applied to the children so the ship node's own look_at heading still works.
static func orient_hull(hull: Node3D, kind: String) -> void:
	var turn := Basis(Vector3.UP, PI)
	if HULL_PITCH.has(kind):
		turn = Basis(Vector3.RIGHT, deg_to_rad(float(HULL_PITCH[kind])))
	for c in hull.get_children():
		if c is Node3D:
			(c as Node3D).transform = Transform3D(turn, Vector3.ZERO) * (c as Node3D).transform

# Constructor drone — the space "villager"; built cheap, commanded to build structures.
const DRONE := {cost = 4.0, max_hp = 20.0, move_speed = 130.0, model = "craft_miner"}

# Immobile defenses (spawned with move_speed 0).
const DEFENSES := {
	"OrbitalPlatform": {cost = 6.0,  max_hp = 120.0, damage = 10.0, attack_range = 180.0, attack_cooldown = 1.0, attack_kind = "single", sprite = "struct_orbital_platform", model = "turret_double"},
	"ArcPylon":        {cost = 10.0, max_hp = 140.0, damage = 10.0, attack_range = 160.0, attack_cooldown = 1.2, attack_kind = "chain", chain_count = 3, sprite = "struct_arc_pylon", model = "turret_single"},
	"HubTurret":       {cost = 0.0,  max_hp = 30.0,  damage = 5.0,  attack_range = 140.0, attack_cooldown = 1.5, attack_kind = "single"},
}

# Structures a drone builds on an owned system (non-combat).
const BUILDINGS := {
	"Shipyard":       {cost = 14.0, effect = "shipyard", sprite = "building_shipyard", model = "hangar_largeA"},  # unlocks + builds FLEET at that system
	"SolarCollector": {cost = 8.0,  effect = "income", sprite = "building_solar_collector", model = "machine_generator"},    # +income at that system
	"ResearchLab":    {cost = 18.0, effect = "research", sprite = "building_research_lab", model = "satellite_dish"},
	"HabitatRing":    {cost = 16.0, effect = "population", sprite = "building_habitat_ring", model = "station_large"},
	"MiningRig":      {cost = 12.0, effect = "mining", sprite = "building_mining_rig", model = "station_small"},
	"JumpGate":       {cost = 28.0, effect = "movement", sprite = "building_jump_gate", model = "satellite"},
}
