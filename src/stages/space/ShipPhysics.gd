class_name ShipPhysics
## Pure, stateless ship loadout physics helpers.
##
## Mass is intentionally derived from existing stat surfaces instead of a new mass table:
## - hull mass: max_hp/hp * HULL_HP_MASS, because hit points are the existing hull-size proxy.
## - weapon mass: damage * WEAPON_DAMAGE_MASS, adjusted by kind/attack_kind for heavier ordnance.
## - armor mass: armor_tier adds plating proportional to hull hp plus a small fixed tier cost.
## Specs can be raw SpaceUnits.FLEET rows or richer loadouts with `hull`/`ship` and `weapon` IDs
## that resolve through ShipStats/WeaponStats.

const DEFAULT_MASS: float = 24.0
const MIN_MASS: float = 1.0
const HULL_HP_MASS: float = 0.42
const WEAPON_DAMAGE_MASS: float = 0.75
const ARMOR_TIER_BASE_MASS: float = 3.0
const ARMOR_TIER_HP_MASS: float = 0.08
const TURN_REFERENCE_MASS: float = 24.0
const MIN_TURN_RATE: float = 0.15


static func ship_mass(spec: Dictionary) -> float:
	var hull_hp: float = _hull_hp(spec)
	var weapon_mass: float = _weapon_mass(spec)
	var armor_tier: float = _armor_tier(spec)
	var armor_mass: float = armor_tier * (ARMOR_TIER_BASE_MASS + hull_hp * ARMOR_TIER_HP_MASS)
	var mass: float = hull_hp * HULL_HP_MASS + weapon_mass + armor_mass
	if not is_finite(mass) or mass <= 0.0:
		return DEFAULT_MASS
	return maxf(mass, MIN_MASS)


static func max_accel(thrust: float, mass: float) -> float:
	var safe_thrust: float = thrust
	if not is_finite(safe_thrust) or safe_thrust <= 0.0:
		return 0.0
	var safe_mass: float = _safe_mass(mass)
	return safe_thrust / safe_mass


static func max_turn_rate(mass: float, base_turn: float) -> float:
	var safe_base_turn: float = base_turn
	if not is_finite(safe_base_turn) or safe_base_turn <= 0.0:
		safe_base_turn = MIN_TURN_RATE
	var safe_mass: float = _safe_mass(mass)
	var turn: float = safe_base_turn * sqrt(TURN_REFERENCE_MASS / safe_mass)
	return maxf(turn, MIN_TURN_RATE)


static func apply_accel_limit(
	current_vel: Vector3,
	desired_vel: Vector3,
	max_accel_value: float,
	delta: float,
) -> Vector3:
	if not _finite_vec3(current_vel):
		current_vel = Vector3.ZERO
	if not _finite_vec3(desired_vel):
		return current_vel
	if not is_finite(max_accel_value) or max_accel_value <= 0.0:
		return current_vel
	if not is_finite(delta) or delta <= 0.0:
		return current_vel
	var change: Vector3 = desired_vel - current_vel
	var max_change: float = max_accel_value * delta
	var change_len: float = change.length()
	if change_len <= max_change or change_len <= 0.0:
		return desired_vel
	return current_vel + change * (max_change / change_len)


static func _hull_hp(spec: Dictionary) -> float:
	var hull_id: String = str(spec.get("hull", spec.get("ship", spec.get("ship_id", "")))).to_lower()
	if hull_id != "" and ShipStats.has_ship(hull_id):
		var hull: Dictionary = ShipStats.get_ship(hull_id)
		return _positive_float(hull.get("hp", DEFAULT_MASS), DEFAULT_MASS)
	return _positive_float(spec.get("max_hp", spec.get("hp", DEFAULT_MASS)), DEFAULT_MASS)


static func _weapon_mass(spec: Dictionary) -> float:
	var weapon_id: String = str(spec.get("weapon", spec.get("weapon_id", ""))).to_lower()
	var damage: float = 0.0
	var kind: String = ""
	if weapon_id != "" and WeaponStats.has_weapon(weapon_id):
		var weapon: Dictionary = WeaponStats.get_weapon(weapon_id)
		damage = _positive_float(weapon.get("damage", spec.get("damage", 0.0)), 0.0)
		kind = str(weapon.get("kind", spec.get("attack_kind", "single"))).to_lower()
	else:
		damage = _positive_float(spec.get("damage", spec.get("weapon_damage", 0.0)), 0.0)
		kind = str(spec.get("kind", spec.get("attack_kind", "single"))).to_lower()
	var kind_mult: float = _weapon_kind_mass_mult(kind)
	return damage * WEAPON_DAMAGE_MASS * kind_mult


static func _weapon_kind_mass_mult(kind: String) -> float:
	match kind:
		"energy", "laser", "single":
			return 0.95
		"kinetic", "railgun":
			return 1.05
		"explosive", "missile", "splash", "flak":
			return 1.35
		"chain", "ion", "ion_beam":
			return 1.20
		"beam_split", "plasma":
			return 1.25
		_:
			return 1.0


static func _armor_tier(spec: Dictionary) -> float:
	var tier: float = _positive_float(spec.get("armor_tier", spec.get("armor", 0.0)), 0.0)
	return maxf(tier, 0.0)


static func _positive_float(value: Variant, fallback: float) -> float:
	if value == null:
		return fallback
	var out: float = float(value)
	if not is_finite(out) or out < 0.0:
		return fallback
	return out


static func _safe_mass(mass: float) -> float:
	if not is_finite(mass) or mass <= 0.0:
		return DEFAULT_MASS
	return maxf(mass, MIN_MASS)


static func _finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
