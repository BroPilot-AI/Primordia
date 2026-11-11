class_name UnitAnimator
## State -> clip driver for any rigged unit, library-agnostic.
##
## Generalizes PlayerCreature3D._find_clip into the full RTS state set. Given a unit node and a
## state string, plays the matching baked clip resolved BY KEYWORD — so Tribe's walk/idle rigs and
## the advanced 22-clip Mixamo rigs both work through one path (see [[primordia-rts-animations]]).
##
## Per-node cache (AnimationPlayer + resolved clip names + current state) lives in node metadata,
## so it is freed with the unit — no global registry to leak. Unknown/absent clips fall back to idle.

# state -> ordered keyword candidates (first match in the rig's clip list wins)
const STATES := {
	"idle":   ["idle", "breath"],
	"walk":   ["walk"],
	"run":    ["run", "jog", "sprint"],
	# gatherer pack: dig/plant/water/pick/pull/milk all read as "working a spot"
	"gather": ["gather", "harvest", "dig", "plant", "water", "pick", "pull", "milk", "mining", "chop"],
	# hauling: holding / box / wheelbarrow carry sets
	"carry":  ["carry", "hold", "barrow", "box"],
	"build":  ["build", "hammer", "construct"],
	"attack": ["attack", "shoot", "punch", "fire"],   # ranged/gun default -> rifle "Shoot"
	"melee":  ["meleeslash", "slash", "sword", "melee"],   # Soldier sword swing
	"bowshoot": ["bowshoot", "arrow", "bow"],   # Archer draw + loose
	"death":  ["death", "dying", "die"],
	# turn-in-place: the merged human rig ships TurnLeft/TurnRight clips; used to reorient an idle
	# unit by a large heading delta without sliding it around (falls back to idle on rigs that lack them).
	"turnleft":  ["turnleft"],
	"turnright": ["turnright"],
}

# states that play once and hold the last pose rather than looping
const ONE_SHOT := ["attack", "melee", "bowshoot", "death"]


## Play `state` on `unit`. No-op if already in that state, the unit is gone, or it has no rig.
static func play(unit: Node, state: String) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var ap := _player(unit)
	if ap == null:
		return
	if unit.get_meta("_ua_state", "") == state:
		return
	var clip := _clip_for(unit, ap, state)
	if clip == "":
		return
	var anim := ap.get_animation(clip)
	if anim != null:
		anim.loop_mode = Animation.LOOP_NONE if state in ONE_SHOT else Animation.LOOP_LINEAR
	ap.play(clip)
	unit.set_meta("_ua_state", state)


## Force a clip to (re)start from frame 0 even if already in this state — for one-shot actions
## that repeat (e.g. striking again on each attack cooldown), where dedup-by-state would swallow it.
static func trigger(unit: Node, state: String) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var ap := _player(unit)
	if ap == null:
		return
	var clip := _clip_for(unit, ap, state)
	if clip == "":
		return
	var anim := ap.get_animation(clip)
	if anim != null:
		anim.loop_mode = Animation.LOOP_NONE if state in ONE_SHOT else Animation.LOOP_LINEAR
	ap.play(clip)
	ap.seek(0.0, true)
	unit.set_meta("_ua_state", state)


## Current state string (or "" if never set).
static func current(unit: Node) -> String:
	return String(unit.get_meta("_ua_state", "")) if is_instance_valid(unit) else ""


static func _player(unit: Node) -> AnimationPlayer:
	if unit.has_meta("_ua_ap"):
		var cached := unit.get_meta("_ua_ap") as AnimationPlayer
		if is_instance_valid(cached):
			return cached
	for c in unit.find_children("*", "AnimationPlayer", true, false):
		unit.set_meta("_ua_ap", c)
		return c as AnimationPlayer
	return null


# Resolve+cache the clip name for a state. Falls back to idle, then to the first clip.
static func _clip_for(unit: Node, ap: AnimationPlayer, state: String) -> String:
	var cache: Dictionary = unit.get_meta("_ua_clips", {})
	if cache.has(state):
		return String(cache[state])
	var list := ap.get_animation_list()
	var found := _match(list, STATES.get(state, [state]))
	if found == "" and state != "idle":
		found = _match(list, STATES["idle"])
	if found == "" and list.size() > 0:
		found = String(list[0])
	cache[state] = found
	unit.set_meta("_ua_clips", cache)
	return found


static func _match(list: PackedStringArray, keys: Array) -> String:
	# Exact name first so locomotion ("Walk"/"Idle"/"Run") isn't hijacked by carry/farm clips that
	# merely contain the word ("BoxWalk", "HoldIdle"); fall back to substring for the action states.
	for k in keys:
		for n in list:
			if String(n).to_lower() == String(k).to_lower():
				return String(n)
	for n in list:
		var l := String(n).to_lower()
		for k in keys:
			if l.find(String(k)) >= 0:
				return String(n)
	return ""
