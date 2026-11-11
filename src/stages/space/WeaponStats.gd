class_name WeaponStats

const WEAPONS: Dictionary = {
	"railgun": {
		"label": "Railgun",
		"damage": 50.0,
		"range": 800.0,
		"fire_rate": 0.5,
		"projectile": "res://src/stages/space/projectiles/railgun_bolt.tscn",
		"kind": "kinetic"
	},
	"laser": {
		"label": "Laser",
		"damage": 25.0,
		"range": 600.0,
		"fire_rate": 0.1,
		"projectile": "res://src/stages/space/projectiles/laser_beam.tscn",
		"kind": "energy"
	},
	"missile": {
		"label": "Missile",
		"damage": 100.0,
		"range": 1000.0,
		"fire_rate": 2.0,
		"projectile": "res://src/stages/space/projectiles/missile.tscn",
		"kind": "explosive"
	},
	"flak": {
		"label": "Flak Cannon",
		"damage": 40.0,
		"range": 400.0,
		"fire_rate": 0.3,
		"projectile": "res://src/stages/space/projectiles/flak_shell.tscn",
		"kind": "explosive"
	},
	"ion_beam": {
		"label": "Ion Beam",
		"damage": 35.0,
		"range": 700.0,
		"fire_rate": 0.2,
		"projectile": "res://src/stages/space/projectiles/ion_bolt.tscn",
		"kind": "energy"
	},
	"plasma": {
		"label": "Plasma Cannon",
		"damage": 60.0,
		"range": 500.0,
		"fire_rate": 0.4,
		"projectile": "res://src/stages/space/projectiles/plasma_ball.tscn",
		"kind": "energy"
	}
}

static func has_weapon(id: String) -> bool:
	return WEAPONS.has(id)

static func get_weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, {})

static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in WEAPONS.keys():
		ids.append(key)
	return ids