## Pure battle math for drop-in tactical fights (and auto-resolve). No nodes — stages
## pass unit snapshots and apply the result to live rosters.
class_name BattleModel


## Snapshot a combatant for the arena. `id` is the caller's stable handle (unit dict index
## or ship instance id) so survivors can be matched after the fight.
static func make_combatant(id: Variant, kind: String, faction: int, hp: float, max_hp: float, damage: float, attack_range: float, speed: float, attack_cd: float = 1.0) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"faction": faction,
		"hp": maxf(1.0, hp),
		"max_hp": maxf(1.0, max_hp),
		"damage": maxf(0.5, damage),
		"attack_range": maxf(1.0, attack_range),
		"speed": maxf(0.0, speed),
		"attack_cd": maxf(0.2, attack_cd),
		"cd": 0.0,
	}


## Auto-resolve a fight with a seeded RNG (same seed, same result). Returns a result dict:
## {won, friend_alive: Array[id], foe_alive: Array[id], friend_hp: {id:hp}, foe_hp: {id:hp}}
static func auto_resolve(friends: Array, foes: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	var f: Array = _clone_side(friends)
	var e: Array = _clone_side(foes)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	# Simultaneous-ish rounds until one side is empty (cap to avoid infinite loops).
	for _round in 80:
		_prune_dead(f)
		_prune_dead(e)
		if f.is_empty() or e.is_empty():
			break
		_round_fire(f, e, rng)
		_round_fire(e, f, rng)
	_prune_dead(f)
	_prune_dead(e)
	return _pack_result(f, e)


static func _clone_side(side: Array) -> Array:
	var out: Array = []
	for c in side:
		if c is Dictionary:
			out.append((c as Dictionary).duplicate())
	return out


static func _prune_dead(side: Array) -> void:
	var i := 0
	while i < side.size():
		if float(side[i].get("hp", 0.0)) <= 0.0:
			side.remove_at(i)
		else:
			i += 1


static func _round_fire(attackers: Array, defenders: Array, rng: RandomNumberGenerator) -> void:
	if defenders.is_empty():
		return
	for a in attackers:
		if float(a.get("hp", 0.0)) <= 0.0:
			continue
		var target: Dictionary = defenders[rng.randi_range(0, defenders.size() - 1)]
		var dmg: float = float(a.get("damage", 1.0)) * rng.randf_range(0.85, 1.15)
		target["hp"] = float(target.get("hp", 0.0)) - dmg


static func _pack_result(friends: Array, foes: Array) -> Dictionary:
	var friend_alive: Array = []
	var foe_alive: Array = []
	var friend_hp := {}
	var foe_hp := {}
	for c in friends:
		friend_alive.append(c.get("id"))
		friend_hp[c.get("id")] = float(c.get("hp", 0.0))
	for c in foes:
		foe_alive.append(c.get("id"))
		foe_hp[c.get("id")] = float(c.get("hp", 0.0))
	var won: bool
	if friends.is_empty():
		won = false
	elif foes.is_empty():
		won = true
	else:
		won = _side_hp(friends) >= _side_hp(foes)
	return {
		"won": won,
		"friend_alive": friend_alive,
		"foe_alive": foe_alive,
		"friend_hp": friend_hp,
		"foe_hp": foe_hp,
		"friend_count": friends.size(),
		"foe_count": foes.size(),
	}


static func _side_hp(side: Array) -> float:
	var t := 0.0
	for c in side:
		t += maxf(0.0, float(c.get("hp", 0.0)))
	return t


## Spawn positions for a side on an arena of half-extent `half`.
static func formation_slots(count: int, side: int, half: float = 22.0) -> Array[Vector3]:
	var slots: Array[Vector3] = []
	var cols := mini(4, maxi(1, count))
	var x_base := -half * 0.55 if side == 0 else half * 0.55
	for i in count:
		var row: int = i / cols
		var col: int = i % cols
		var ox: float = (col - (cols - 1) * 0.5) * 3.2
		var oz: float = (row - 1.0) * 3.4
		slots.append(Vector3(x_base + ox * (1.0 if side == 0 else -1.0), 0.0, oz))
	return slots
