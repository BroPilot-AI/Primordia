## SPACE — the 3D endgame. A finite, conquerable galaxy rendered in real 3D on the Stage3D base
## (Godot Open-RTS approach: ortho camera, lit models, glow). Fly your flagship (WASD) to a system
## to capture it; rival empires expand on their own and, once neutral worlds run out, come for
## yours. Own EVERY system → you win the galaxy (terminal → game_won). Lose your last → defeat.
##
## All simulation logic (capture, escalating empires, economy, structures, carry-over, win/lose) is
## preserved from the 2D SpaceStage; only the render/camera/unit layer is 3D. Faction ints, data
## tables (SpaceUnits) and EvolutionState carry-over are reused verbatim.
extends Stage3D

const KIT := "res://assets/models/kenney-spacekit/%s.glb"
const SHIP := SpaceUnits.HULL_PATH   # fleet hull table lives in SpaceUnits (shared with TacticalBattle)

const SYSTEM_COUNT := 24
const EMPIRE_COUNT := 4
const GALAXY_EXTENT := 110.0       # systems scatter within ±extent on X/Z (y=0 plane)
const MIN_SEP := 24.0
const CAPTURE_RADIUS := 9.0
const CAPTURE_RATE := 0.009     # ~40 s per system with the Civ escort, ~15 s with a full fleet
const CAPTURE_DECAY := 0.04
const EMPIRE_EXPAND_BASE := 13.0
const EMPIRE_TECH_CAP := 10.0
const SYSTEM_INCOME := 0.5
const EVO_RATE := 0.011
const FLAGSHIP_SPEED := 46.0
const EMPIRE_DEVELOP_LOG_INTERVAL := 32.0

# Real fleet combat (open-rts pattern adapted to a lightweight per-frame ship list). SpaceUnits
# stats are in 2D pixels → scale to galaxy units. Ships acquire nearest enemy in aggro, close to
# attack_range, fire on cooldown with their weapon kind.
const SPACE_SCALE := 0.11
const SHIP_SPEED_SCALE := 0.6
const SHIP_THRUST_PER_SPEED := 80.0
const SHIP_BASE_TURN_RATE := 4.4
const COLLECTIVE_FAC := 99
const CARRIER_SPAWN_INTERVAL := 14.0
const EMPIRE_FLEET_INTERVAL := 10.0
const EMPIRE_SIEGE_RADIUS := 20.0   # an empire warship this close lets its empire assault a player world
const BIO_DEFECT_CHANCE := 0.30

# The Collective — roaming cube ships, hostile to ALL, capture nothing.
const MAX_CUBES := 3
const CUBE_SPAWN_INTERVAL := 40.0
# Cosmic hazards (rare): comets streak through; black holes pull + damage. Damage ALL units.
const HAZARD_MIN := 68.0
const HAZARD_MAX := 140.0
# Easter-egg cargo courier: rare flyover, not ambient traffic.
const COURIER_FIRST_DELAY := 180.0
const COURIER_COOLDOWN_MIN := 300.0
const COURIER_COOLDOWN_MAX := 600.0
const COURIER_LIFETIME := 45.0

# Full warship roster (data-driven from SpaceUnits.FLEET — 8 ships w/ weapon kinds + models).
const SHIPS := SpaceUnits.FLEET
const STRUCTURES := {
	"Shipyard":       {cost = 18.0, min_age = 0, role = "Builds warships at this system."},
	"SolarCollector": {cost = 10.0, min_age = 0, role = "+4 energy income."},
	"Bastion":        {cost = 14.0, min_age = 0, role = "Shields this system from the next empire takeover."},
	"Annihilator":    {cost = 60.0, min_age = 0, role = "Unique superweapon that captures enemy systems on cooldown."},
	"ResearchLab":    {cost = 22.0, min_age = 2, role = "Speeds galactic evolution and discounts fleet upgrades."},
	"HabitatRing":    {cost = 20.0, min_age = 1, role = "Adds colony capacity, increasing local fleet support."},
	"MiningRig":      {cost = 16.0, min_age = 0, role = "+6 metal income."},
	"JumpGate":       {cost = 34.0, min_age = 3, role = "Accelerates player fleet and flagship movement."},
}
const STRUCTURE_INCOME_BONUS := {
	"MiningRig": {"metal": 6.0},
	"SolarCollector": {"energy": 4.0},
}
const ANNIHILATOR_COOLDOWN := 90.0

const FACTION_COLORS := [
	Color(0.40, 0.70, 1.00),   # 0 player — blue
	Color(1.00, 0.45, 0.40),   # 1 — red
	Color(0.75, 0.50, 0.95),   # 2 — violet
	Color(0.50, 0.85, 0.55),   # 3 — green
]

const StarSys := preload("res://src/stages/space/StarSystem3D.gd")
# Strategic-map helpers (pure logic, unit-tested). Avoid duplicating their constants here.
const FleetMv := preload("res://src/stages/space/FleetMovement.gd")
const GalSave := preload("res://src/stages/space/GalaxySave.gd")
# Formation steering for multi-ship fleets. Pure-logic slots/separation/desired_velocity,
# unit-tested. Used by _idle_move when 2+ player ships share a move
# order so the fleet travels as a coherent wedge around the flagship instead of stacking on one
# point. Single-ship orders fall through to the original direct-to-command behaviour.
const FleetForm := preload("res://src/stages/space/FleetFormation.gd")
# Loadout mass -> acceleration/turn-rate physics. Formation steering supplies desired
# velocity; ShipPhysics only limits how quickly each hull can reach and face that velocity.
const ShipPhys := preload("res://src/stages/space/ShipPhysics.gd")
# Additive stations — StationStats.gd holds build costs + build_time + min_tier.
const StatStats := preload("res://src/stages/space/StationStats.gd")
# Living galaxy: pure-logic for empire strength / attack resolution / evo ring.
const GSim := preload("res://src/stages/space/GalaxySim.gd")
# UI-BUYMENU-REDESIGN: tabbed build panel — Fleet / Build / Defenses / Upgrades / Save. Pure layout
# (no game logic / no callbacks). _update_status still owns enable/disable + button text.
const BUILD_PANEL_SIZE := Vector2(330, 880)

# Names given to empires that EMERGE mid-game from a world reaching spacefaring (the
# pre-seeded rivals keep their genome-lineage names). Cycled so each ascension feels named.
const EMERGENT_NAMES: Array[String] = [
	"the Vorlith Ascendancy", "the Khoss Collective", "the Sundered Choir",
	"the Ninth Bloom", "the Pale Concord", "the Iron Drift",
	"the Umbral Reach", "the Verdant Mind", "the Cinder Hegemony", "the Last Chorus",
]
const GALAXY_LOG_MAX := 5

var _systems: Array[StarSystem3D] = []
var _home_system: StarSystem3D = null  # player homeworld system (return-to-home overlay)
var _flagship: Node3D
var _ships: Array = []             # all combat ships: [{node, faction, kind, hp, damage, range, ...}]
# P0 strategic map: when set, the flagship auto-routes to this system (overrides WASD)
# and on arrival capture kicks in via _tick_player_capture. Cleared on arrival / new order.
var _fleet_destination: StarSystem3D = null
# Formation roster: rebuilt each tick in _tick_combat before the per-ship loop. _fleet_roster
# is a parallel list of player ships (faction 0, command != INF) that share a move order; _fleet_slots
# holds their world-space wedge targets (leader_pos + rotated local slot). Index i in both lists
# maps to ship i — stable for the tick. _fleet_arrival_threshold is the per-ship distance to its own
# command at which we dissolve the formation (large enough to cover the wedge spread).
var _fleet_roster: Array = []
var _fleet_slots: Array[Vector3] = []
var _fleet_arrival_threshold: float = 4.0
var _save_slot: String = "auto"
var _empire_fleet_t := EMPIRE_FLEET_INTERVAL
var _bolts: Array = []             # transient weapon-fire visuals [{node, ttl}]
var _cube_t := CUBE_SPAWN_INTERVAL
var _hazards: Array = []           # active cosmic hazards [{type, node, ...}]
var _hazard_t := HAZARD_MIN
var _courier: Node3D = null       # easter-egg roaming ship
var _courier_goal := Vector3.ZERO
var _courier_t: float = COURIER_FIRST_DELAY
var _empires := {}                 # faction_id -> {timer, treasury, tech, peak, name, collapsed}
var _galaxy_log: Array[String] = []  # rolling event feed (ascension/conquest/collapse)
# Per-tick tracking of which faction each empire targets (for gang-up detection).
var _empire_gang_track: Dictionary = {}
var _last_gang_log: float = -INF   # cooldown for the "galaxy turns on X" flavor line
var _elapsed := 0.0
var _treasury: Dictionary = {"metal": 180.0, "energy": 140.0, "water": 40.0, "biomass": 40.0}
var _build_queue: Array[Dictionary] = []
var _done := false
var _annihilator: StarSystem3D = null
var _selected_system: StarSystem3D = null
var _sys_ring: MeshInstance3D = null
var _annih_cd := 0.0
var _superweapon_name := "Annihilator"
var _lineage_dmg_mult := 1.0
var _lineage_hp_mult := 1.0
var _rival_themes: Array = []
var _truce_until := 0.0
## Per-empire ceasefire end times (elapsed). Buyable truce still galaxy-wide via `_truce_until`.
var _at_peace: Dictionary = {}  # faction_id (int) -> until_elapsed (float)
var _weapon_tier := 0
var _armor_tier := 0
var _mining_hub_cd: Dictionary = {}  # system_index (int) -> cooldown remaining for mining node defense turret

# HUD
const StatStripScript := preload("res://src/ui/StatStrip.gd")
const CompactHUD := preload("res://src/ui/CompactHUDPanel.gd")
const StageChromeScript := preload("res://src/ui/StageChrome.gd")
const CAMERA_SIZE := 46.0
const TacticalBattleScene := preload("res://src/common/TacticalBattle.tscn")
var _status: Label
var _stat_strip   # StatStrip instance — preloaded + untyped to avoid the global class_name scan dependency
var _galaxy_minimap: Minimap2D = null
## After a manual zoom/jump, pause flagship camera follow so the player can inspect.
var _cam_free_t: float = 0.0
const CAM_FREE_HOLD := 5.0
var _battle_open := false
var _battle_friend_ids: Array = []
var _battle_foe_ids: Array = []
var _battle_tutorial_shown := false
var _fleet_threat_cd := 0.0
const FLEET_THREAT_COOLDOWN := 18.0
## Auto-open fleet battle when player ships near hostiles average below this HP fraction.
const FLEET_AUTO_HP_FRAC := 0.5
var _fleet_auto_opened := false
var _capture_halfway_toasted: Dictionary = {}  # system instance id -> true
var _peace_block_toasted := 0  # last system we explained the treaty block on
var _capture_meter: ProgressBar = null
var _capture_meter_label: Label = null
var _diplo_t := 55.0
var _offer_pending := false
const DIPLOMACY_INTERVAL_MIN := 48.0
const DIPLOMACY_INTERVAL_MAX := 95.0
const PEACE_DURATION := 90.0
var _ship_btns: Array[Button] = []
var _struct_btns: Array[Button] = []
var _drone_btn: Button
var _defense_btns: Array[Button] = []
var _truce_btn: Button
# Per-station build buttons (parallel to _struct_btns).
var _station_btns: Array[Button] = []
var _upgrade_btns: Array[Button] = []
var _beam: MeshInstance3D
var _beam_ttl := 0.0

# RTS selection state
var _dragging := false
var _drag_start := Vector2.ZERO

const TRUCE_DURATION := 80.0
const TRUCE_COST := 25.0
const UPGRADE_BASE_COST := 20.0
const TREASURY_START := {"metal": 180.0, "energy": 140.0, "water": 40.0, "biomass": 40.0}
const COST_SCALE := 10.0
# Salvage, capture spoils and peace tribute pay half their cost-scale value in metal + energy.
const SALVAGE_RATE := 0.5
const BUILD_KIND_SHIP := "ship"
const BUILD_KIND_DRONE := "drone"
const BUILD_KIND_STRUCTURE := "structure"
const BUILD_KIND_DEFENSE := "defense"
# Additive stations (refinery / sensor_array / outpost / shipyard / defense_grid)
# built ON TOP of a system. Each goes through the shared build queue, has its own
# build_time + metal/energy cost + min_tier (see StationStats.STATIONS). A system can
# hold any number. A "refinery" turns water/biomass into metal/energy (EconomyModel.refine).
const BUILD_KIND_STATION := "station"
const STATION_REFINERY := "refinery"


func _ready() -> void:
	_treasury = _normalize_treasury(_treasury, true)
	var g = EvolutionState.genome
	if g != null:
		_superweapon_name = g.superweapon()
		# Continuous genome bonuses (shared GenomeBonus) — your fleet inherits your evolution.
		_lineage_dmg_mult = GenomeBonus.dmg_mult(g)
		_lineage_hp_mult = GenomeBonus.hp_mult(g)
	_build_rival_themes()
	_build_environment("space")
	_build_sun()
	_build_skybox()
	_generate_galaxy()
	_spawn_flagship()
	# Camera follows the flagship — lock its own panning/edge-scroll off.
	_build_camera(_flagship.position, CAMERA_SIZE)
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.set("edge_margin", 0)
		cam.set("pan_speed", 0.0)
	_ascend_civ_army()
	_build_ui()
	_build_galaxy_minimap()
	for e in EMPIRE_COUNT:
		_empires[e + 1] = {timer = EMPIRE_EXPAND_BASE}
	call_deferred("_emit_space_open_brief")


# Deep-space skybox from an equirectangular nebula panorama.
func _build_skybox() -> void:
	# Ortho cameras smear panorama skies into a radial burst. Keep a flat color sky and put
	# the starfield on a backdrop plane behind the galaxy disk so stars actually read.
	var we: WorldEnvironment = null
	for c in get_children():
		if c is WorldEnvironment:
			we = c
			break
	if we != null:
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = Color(0.015, 0.02, 0.06)
		we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		we.environment.ambient_light_color = Color(0.38, 0.44, 0.62)
		we.environment.ambient_light_energy = 0.55
	var path := "res://assets/textures/space_skybox.png"
	if not ResourceLoader.exists(path):
		path = "res://assets/textures/space_nebula_panorama.png"
	if not ResourceLoader.exists(path):
		return
	var mi := MeshInstance3D.new()
	mi.name = "StarfieldBackdrop"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400, 2400)
	mi.mesh = plane
	mi.position = Vector3(0.0, -160.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = load(path)
	# Tile the 2:1 panorama (square texels) so stars stay pin-points instead of blurry blobs.
	mat.uv1_scale = Vector3(12.0, 24.0, 1.0)
	mat.albedo_color = Color(0.38, 0.42, 0.55)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)


# Deterministic finite galaxy in the XZ plane: scatter systems with a min separation, then hand
# the player one home system and each empire one, leaving the rest neutral to be fought over.
func _generate_galaxy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_galaxy" % EvolutionState.world_seed)
	var positions: Array[Vector3] = []
	var attempts := 0
	while positions.size() < SYSTEM_COUNT and attempts < 3000:
		attempts += 1
		var p := Vector3(rng.randf_range(-GALAXY_EXTENT, GALAXY_EXTENT), 0.0, rng.randf_range(-GALAXY_EXTENT, GALAXY_EXTENT))
		var ok := true
		for q in positions:
			if p.distance_to(q) < MIN_SEP:
				ok = false
				break
		if ok:
			positions.append(p)

	for i in positions.size():
		var sys: StarSystem3D = StarSys.new()
		sys.position = positions[i]
		sys.system_name = "System %d" % (i + 1)
		add_child(sys)
		_systems.append(sys)

	# Home = most central; empires take the farthest-apart systems.
	_systems.sort_custom(func(a, b): return a.position.length_squared() < b.position.length_squared())
	_systems[0].set_faction(0, FACTION_COLORS[0])
	_home_system = _systems[0]
	if EvolutionState.civ_victory == "conquest" and _systems.size() > 1:
		_systems[1].set_faction(0, FACTION_COLORS[0])
	var taken := EvolutionState.civ_victory == "conquest"
	for e in EMPIRE_COUNT:
		var idx := _systems.size() - 1 - e
		if idx > (1 if taken else 0):
			_systems[idx].set_faction(e + 1, _faction_color(e + 1))


func _spawn_flagship() -> void:
	_flagship = spawn_model(SHIP % "flagship", _player_home_pos() + Vector3(0, 1, 0), 1.0, 180.0)
	if _flagship != null:
		fit_scale(_flagship, 4.2)   # hero ship, a bit larger
		SpaceUnits.orient_hull(_flagship, "Flagship")   # nose +Z glTF hull: lead with the nose under look_at
		_stylize_ship(_flagship)
	if _flagship == null:
		_flagship = Node3D.new()
		add_child(_flagship)
		_flagship.position = _player_home_pos() + Vector3(0, 1, 0)


func _player_home_pos() -> Vector3:
	for s in _systems:
		if s.faction == 0:
			return s.position
	return Vector3.ZERO


func _process(delta: float) -> void:
	if _done or _flagship == null:
		return
	_elapsed += delta
	_move_flagship(delta)
	_tick_combat(delta)
	_tick_drones(delta)
	_tick_hub_defense(delta)
	_tick_empire_fleets(delta)
	_tick_collective(delta)
	_tick_hazards(delta)
	_tick_bolts(delta)
	if _courier != null and is_instance_valid(_courier):
		_tick_courier(delta)
	else:
		_courier_t -= delta
		if _courier_t <= 0.0:
			_spawn_courier()
			_courier_t = COURIER_LIFETIME
	_follow_camera()
	_tick_economy(delta)
	_tick_build_queue(delta)
	_tick_player_capture(delta)
	_tick_annihilator(delta)
	_tick_empires(delta)
	_tick_beam(delta)
	_tick_fleet_threat(delta)
	_tick_diplomacy(delta)
	var research_rate := EVO_RATE * _research_mult()
	for s in _systems:
		if s.faction < 0:
			s.tick_evolution(delta, research_rate)
	for s in _systems:
		if s.faction < 0 and s.emergent_ready:
			_emerge_empire(s)
	_check_endgame()
	_update_status()
	_update_galaxy_minimap()


func _build_galaxy_minimap() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_galaxy_minimap = Minimap2D.new()
	_galaxy_minimap.title = "GALAXY · front"
	var extent: float = GALAXY_EXTENT + 24.0
	_galaxy_minimap.world_origin = Vector2(-extent, -extent)
	_galaxy_minimap.world_size = Vector2(extent * 2.0, extent * 2.0)
	# Deep-space field (no tile terrain).
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.02, 0.03, 0.08))
	_galaxy_minimap.terrain_tex = ImageTexture.create_from_image(img)
	_galaxy_minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_galaxy_minimap.offset_left = 12
	_galaxy_minimap.offset_top = -176
	_galaxy_minimap.offset_right = 12 + 200
	_galaxy_minimap.offset_bottom = -12
	_galaxy_minimap.pan_requested.connect(_on_galaxy_minimap_pan)
	layer.add_child(_galaxy_minimap)


func _on_galaxy_minimap_pan(wp: Vector3) -> void:
	# Route flagship toward nearest system at the click (never teleport it to the point).
	var best: StarSystem3D = null
	var bd := INF
	for s in _systems:
		var d: float = s.position.distance_squared_to(wp)
		if d < bd:
			bd = d
			best = s
	if best != null:
		_fleet_destination = best
		Events.notify.emit("Fleet routing to %s." % best.system_name)
		_zoom_tactical_hold(best.position)


func _double_click_opens_battle(cam: Camera3D, screen_pos: Vector2) -> bool:
	for s in _ships:
		if int(s.get("faction", 0)) == 0 or float(s.get("hp", 0.0)) <= 0.0:
			continue
		if not is_instance_valid(s.get("node")):
			continue
		if cam.unproject_position(s.node.global_position).distance_to(screen_pos) < 28.0:
			return _try_open_space_battle()
	return false


func _double_click_tactical(cam: Camera3D, screen_pos: Vector2) -> void:
	# Prefer ship under cursor, then system, then ground under cursor.
	var nearest: Dictionary = {}
	var nd := 28.0
	for s in _ships:
		if s.faction != 0 or not is_instance_valid(s.get("node")):
			continue
		var d: float = cam.unproject_position(s.node.global_position).distance_to(screen_pos)
		if d < nd:
			nd = d
			nearest = s
	if not nearest.is_empty():
		_set_ship_selected(nearest, true)
		_zoom_tactical_hold(nearest.node.global_position)
		return
	var sys: StarSystem3D = _system_under_cursor(cam, screen_pos)
	if sys != null:
		_select_system(sys)
		# Double-click home system → return-to-homeworld overlay (when still owned).
		if sys == _home_system and int(sys.faction) == 0:
			_open_homeworld()
			return
		_zoom_tactical_hold(sys.global_position)
		return
	_zoom_tactical_hold(ground_point(screen_pos))


func _focus_fleet_tactical() -> void:
	for s in _ships:
		if s.faction == 0 and bool(s.get("selected", false)) and is_instance_valid(s.get("node")):
			_zoom_tactical_hold(s.node.global_position)
			return
	if is_instance_valid(_flagship):
		_zoom_tactical_hold(_flagship.position)


func _zoom_tactical_hold(pos: Vector3) -> void:
	_cam_free_t = CAM_FREE_HOLD
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.has_method("zoom_tactical"):
		cam.zoom_tactical(pos)


func _update_galaxy_minimap() -> void:
	if _galaxy_minimap == null:
		return
	var dots: Array = []
	# Front-line systems: owned by player/enemy and near a different faction (war front).
	var front_ids: Dictionary = {}
	const FRONT_DIST := 48.0
	for s in _systems:
		if int(s.faction) < 0:
			continue
		for o in _systems:
			if o == s or int(o.faction) < 0 or int(o.faction) == int(s.faction):
				continue
			if s.position.distance_to(o.position) <= FRONT_DIST:
				front_ids[s.get_instance_id()] = true
				break
	for s in _systems:
		var fac: int = int(s.faction)
		var col: Color = _faction_color(fac) if fac >= 0 else Color(0.45, 0.5, 0.6)
		var r: float = 2.4 if fac == 0 else 1.8
		var is_front: bool = bool(front_ids.get(s.get_instance_id(), false))
		var is_contested: bool = fac != 0 and float(s.capture) > 0.05
		# Contested capture in progress — brighter.
		if is_contested:
			col = Color(1.0, 0.75, 0.25)
			r = 2.8
		elif is_front:
			# War-front ring: hot edge on front-line systems.
			col = col.lerp(Color(1.0, 0.35, 0.2), 0.45)
			r = maxf(r, 2.6)
		dots.append({p = Vector2(s.position.x, s.position.z), c = col, r = r})
		# 3D nameplates only on front / contested / selected — keeps the sky readable.
		var show_plate: bool = is_front or is_contested or s == _selected_system
		if s.has_method("set_nameplate_visible"):
			s.set_nameplate_visible(show_plate, is_front, is_contested)
	# Hostile fleets as small red ticks (war presence).
	for sh in _ships:
		if int(sh.get("faction", 0)) == 0 or not is_instance_valid(sh.get("node")):
			continue
		if float(sh.get("hp", 0.0)) <= 0.0:
			continue
		dots.append({
			p = Vector2(sh.node.position.x, sh.node.position.z),
			c = Color(1.0, 0.25, 0.22, 0.95),
			r = 1.2,
		})
	if is_instance_valid(_flagship):
		dots.append({p = Vector2(_flagship.position.x, _flagship.position.z), c = Color(1.0, 0.95, 0.4), r = 3.2})
	var focus := Vector2.ZERO
	var half := Vector2(22, 18)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var look: Vector3 = cam.get_focus() if cam.has_method("get_focus") else cam.global_position
		focus = Vector2(look.x, look.z)
		var aspect: float = get_viewport().get_visible_rect().size.aspect()
		half = Vector2(cam.size * aspect * 0.5, cam.size * 0.5)
	_galaxy_minimap.set_data(dots, focus, half)


func _move_flagship(delta: float) -> void:
	# P0: when a fleet destination is set, the flagship auto-routes toward it (WASD is
	# ignored so a queued order isn't fought by hand). On arrival (within CAPTURE_RADIUS)
	# the destination clears and capture proceeds. Player can interrupt by clicking empty
	# space or issuing another right-click.
	if _fleet_destination != null and is_instance_valid(_fleet_destination):
		var arrival_r: float = FleetMv.DEFAULT_ARRIVAL_RADIUS
		if FleetMv.has_arrived(_flagship.position, _fleet_destination.position, arrival_r):
			var arrived_sys: StarSystem3D = _fleet_destination
			_fleet_destination = null
			Events.notify.emit("Arrived at %s." % arrived_sys.system_name)
			return
		var to: Vector3 = _fleet_destination.position - _flagship.position
		to.y = 0.0
		var d: float = to.length()
		if d > 0.001:
			var step: float = FLAGSHIP_SPEED * _movement_mult(0) * delta
			var motion: Vector3 = to.normalized() * minf(step, d)
			_flagship.position += motion
			_flagship.position.x = clampf(_flagship.position.x, -GALAXY_EXTENT - 20, GALAXY_EXTENT + 20)
			_flagship.position.z = clampf(_flagship.position.z, -GALAXY_EXTENT - 20, GALAXY_EXTENT + 20)
			if _flagship.global_position.distance_to(_flagship.position + motion) > 0.1:
				_flagship.look_at(_flagship.position + motion, Vector3.UP)
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v == Vector2.ZERO:
		# Fall back to arrow keys if move_* unmapped.
		v = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if v == Vector2.ZERO:
		return
	var motion := Vector3(v.x, 0, v.y) * FLAGSHIP_SPEED * _movement_mult(0) * delta
	_flagship.position += motion
	_flagship.position.x = clampf(_flagship.position.x, -GALAXY_EXTENT - 20, GALAXY_EXTENT + 20)
	_flagship.position.z = clampf(_flagship.position.z, -GALAXY_EXTENT - 20, GALAXY_EXTENT + 20)
	if motion.length() > 0.001:
		if _flagship.global_position.distance_to(_flagship.position + motion) > 0.1:
			_flagship.look_at(_flagship.position + motion, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		# F = tactical focus on flagship (or selected ship).
		_focus_fleet_tactical()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		if _try_open_space_battle():
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.double_click:
				# Double-click a hostile ship with friendlies nearby → full fleet battle.
				if _double_click_opens_battle(cam, mb.position):
					get_viewport().set_input_as_handled()
					return
				_double_click_tactical(cam, mb.position)
				get_viewport().set_input_as_handled()
				return
			if mb.pressed:
				_drag_start = mb.position
				_dragging = true
			elif _dragging:
				_dragging = false
				var rect := Rect2(_drag_start, mb.position - _drag_start).abs()
				var click: bool = rect.size.length() < 6.0
				for s in _ships:
					if s.faction != 0:
						continue
					if not is_instance_valid(s.node):
						continue   # dead-node entries linger a frame after combat prunes
					_set_ship_selected(s, false)
				var nearest: Dictionary = {}
				var nd := INF
				for s in _ships:
					if s.faction != 0:
						continue
					if not is_instance_valid(s.node):
						continue   # _ships holds dead-node entries between combat prunes; don't deref a freed ship
					var sp: Vector2 = cam.unproject_position(s.node.global_position)
					if click:
						var d := sp.distance_to(mb.position)
						if d < 24.0 and d < nd:
							nd = d
							nearest = s
					elif rect.has_point(sp):
						_set_ship_selected(s, true)
				if click and not nearest.is_empty():
					_set_ship_selected(nearest, true)
				elif click:
					_select_nearest_system(cam, mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			# P0: right-click on a system issues a fleet-move to that system. Otherwise
			# fall back to the legacy ground-point order (move selected ships to the cursor).
			var target_sys: StarSystem3D = _system_under_cursor(cam, mb.position)
			if target_sys != null:
				_issue_fleet_destination(target_sys)
			else:
				var dest: Vector3 = ground_point(mb.position)
				var any_selected := false
				for s in _ships:
					if s.faction == 0 and s.get("selected", false):
						s.command = dest
						any_selected = true
				if any_selected:
					Events.notify.emit("Fleet moving out.")


## ----------------------------------------------------------------------------------------------
## Real fleet combat — ships acquire the nearest hostile in aggro, close to attack_range, and fire
## on cooldown with their weapon kind (single / splash / chain / beam_split). Carriers spawn
## fighters; Infestors infect (bio) → infected ships can DEFECT on death. Adapted from godot-open-rts
## (~/godot-refs/godot-open-rts AutoAttacking/AttackingWhileInRange) to a flat per-frame ship list.
## ----------------------------------------------------------------------------------------------
# Click a star system to select + inspect it (the galaxy-map P0 interaction). A glowing ring marks
# the selection and its details go to the notification HUD.
func _select_nearest_system(cam: Camera3D, screen_pos: Vector2) -> void:
	var best: StarSystem3D = null
	var bd := 46.0
	for sys in _systems:
		if not is_instance_valid(sys):
			continue
		var d := cam.unproject_position(sys.global_position).distance_to(screen_pos)
		if d < bd:
			bd = d
			best = sys
	if best != null:
		_select_system(best)


func _select_system(sys: StarSystem3D) -> void:
	_selected_system = sys
	if is_instance_valid(_sys_ring):
		_sys_ring.queue_free()
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 7.0
	torus.outer_radius = 8.6
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 1.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 1.0, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	sys.add_child(ring)
	_sys_ring = ring
	var who := "Yours" if sys.faction == 0 else ("Neutral" if sys.faction < 0 else "Empire %d" % sys.faction)
	var planets: int = (sys._planets as Array).size()
	var extra := " - " + sys.structure if sys.structure != "" else ""
	Events.notify.emit("%s - %s - %d planet%s%s" % [sys.system_name, who, planets, "" if planets == 1 else "s", extra])


# P0: the system closest to a screen point within the same tolerance as selection.
# Returns null if nothing's within range (so the caller can fall back to ground-point).
func _system_under_cursor(cam: Camera3D, screen_pos: Vector2) -> StarSystem3D:
	if cam == null:
		return null
	var best: StarSystem3D = null
	var bd := 46.0
	for sys in _systems:
		if not is_instance_valid(sys):
			continue
		var d := cam.unproject_position(sys.global_position).distance_to(screen_pos)
		if d < bd:
			bd = d
			best = sys
	return best


# P0: route the flagship + every selected player ship to a target system. The flagship's
# _move_flagship will auto-route while _fleet_destination is set; on arrival the
# existing _tick_player_capture handles capture with fleet-power amplification.
## Drop into a space skirmish with nearby friendly ships vs hostiles (or system defenders).
func _try_open_space_battle() -> bool:
	if _battle_open:
		return false
	var friends: Array = []
	var friend_ids: Array = []
	var anchor: Vector3 = _flagship.position if is_instance_valid(_flagship) else Vector3.ZERO
	for i in _ships.size():
		var s: Dictionary = _ships[i]
		if int(s.get("faction", -1)) != 0 or float(s.get("hp", 0.0)) <= 0.0:
			continue
		if not is_instance_valid(s.get("node")):
			continue
		# Prefer selected ships; otherwise any nearby friendlies.
		var selected: bool = bool(s.get("selected", false))
		if not selected and s.node.position.distance_to(anchor) > 35.0:
			continue
		if selected or s.node.position.distance_to(anchor) <= 35.0:
			friend_ids.append(i)
			friends.append(BattleModel.make_combatant(
				i, str(s.get("kind", "Fighter")), 0,
				float(s.hp), float(s.max_hp), float(s.get("damage", 5.0)),
				float(s.get("attack_range", 80.0)), float(s.get("speed", 10.0)),
				float(s.get("attack_cd", 1.0))))
	# Always include flagship presence as a durable combatant if no ships selected.
	if friends.is_empty() and is_instance_valid(_flagship):
		friend_ids.append("flagship")
		friends.append(BattleModel.make_combatant(
			"flagship", "Cruiser", 0, 80.0, 80.0, 10.0, 120.0, 12.0, 1.0))
	if friends.is_empty():
		Events.notify.emit("No fleet to fight with.")
		return false
	var foes: Array = []
	var foe_ids: Array = []
	for i in _ships.size():
		var s: Dictionary = _ships[i]
		if int(s.get("faction", 0)) == 0 or float(s.get("hp", 0.0)) <= 0.0:
			continue
		if not is_instance_valid(s.get("node")):
			continue
		if s.node.position.distance_to(anchor) > 45.0:
			continue
		foe_ids.append(i)
		foes.append(BattleModel.make_combatant(
			i, str(s.get("kind", "Fighter")), 1,
			float(s.hp), float(s.max_hp), float(s.get("damage", 5.0)),
			float(s.get("attack_range", 80.0)), float(s.get("speed", 10.0)),
			float(s.get("attack_cd", 1.0))))
	# Contested system under the flagship adds a defensive picket.
	var park: StarSystem3D = _nearest_system(anchor, 12.0)
	if park != null and park.faction != 0:
		for j in 2:
			var pid := "picket_%d" % j
			foe_ids.append(pid)
			foes.append(BattleModel.make_combatant(
				pid, "Fighter", 1, 16.0, 16.0, 5.0, 80.0, 14.0, 0.7))
	if foes.is_empty():
		Events.notify.emit("No hostiles in range — fly closer, then press B.")
		return false
	_maybe_battle_tutorial()
	_battle_friend_ids = friend_ids
	_battle_foe_ids = foe_ids
	_battle_open = true
	var battle: TacticalBattle = TacticalBattleScene.instantiate()
	battle.configure({
		"mode": "space",
		"title": "FLEET BATTLE",
		"friends": friends,
		"foes": foes,
		"seed": hash("%s_space_battle_%d" % [EvolutionState.world_seed, Time.get_ticks_msec()]),
	})
	battle.finished.connect(_on_space_battle_finished)
	var root: Node = StageManager.stage_root()
	if root != null:
		root.add_child(battle)
	else:
		add_child(battle)
	StageObjectives.complete("space_drop_in", "Dropped into a fleet battle")
	return true


func _on_space_battle_finished(result: Dictionary) -> void:
	_battle_open = false
	var falive: Array = result.get("friend_alive", [])
	var fhp: Dictionary = result.get("friend_hp", {})
	var ealive: Array = result.get("foe_alive", [])
	var ehp: Dictionary = result.get("foe_hp", {})
	for id in _battle_friend_ids:
		if id is int and id >= 0 and id < _ships.size():
			var s: Dictionary = _ships[id]
			if falive.has(id):
				s["hp"] = float(fhp.get(id, s.hp))
			else:
				s["hp"] = 0.0
				if is_instance_valid(s.get("node")):
					s.node.queue_free()
	for id in _battle_foe_ids:
		if id is int and id >= 0 and id < _ships.size():
			var s: Dictionary = _ships[id]
			if ealive.has(id):
				s["hp"] = float(ehp.get(id, s.hp))
			else:
				s["hp"] = 0.0
				if is_instance_valid(s.get("node")):
					s.node.queue_free()
	# Fanfare already played win/lose SFX.
	if bool(result.get("won", false)) and not bool(result.get("retreated", false)):
		_apply_space_battle_rewards(result)
		Events.notify.emit("Salvage secured.")
		_fleet_auto_opened = false  # allow another crisis later after a win
	elif bool(result.get("retreated", false)):
		Events.notify.emit("Withdrew from the engagement.")
	else:
		Events.notify.emit("Fleet battle lost.")
		_fleet_auto_opened = false
	_battle_friend_ids.clear()
	_battle_foe_ids.clear()
	_update_status()


func _apply_space_battle_rewards(result: Dictionary) -> void:
	var loot: Dictionary = result.get("loot", {})
	var salvage: float = float(loot.get("salvage", 0.0))
	if salvage > 0.0:
		Events.notify.emit("Salvage: %s" % _grant_salvage(salvage))
	var vet: int = int(result.get("veterancy", 0))
	if vet <= 0:
		return
	var n := 0
	for id in _battle_friend_ids:
		if id is int and id >= 0 and id < _ships.size():
			var s: Dictionary = _ships[id]
			if float(s.get("hp", 0.0)) <= 0.0 or not is_instance_valid(s.get("node")):
				continue
			s["damage"] = float(s.get("damage", 5.0)) * (1.0 + 0.06 * float(vet))
			s["max_hp"] = float(s.get("max_hp", 20.0)) * (1.0 + 0.04 * float(vet))
			s["hp"] = minf(float(s.hp) + 0.05 * float(s.max_hp), float(s.max_hp))
			s["veterancy"] = int(s.get("veterancy", 0)) + vet
			_refresh_crew_glow(s, true)
			n += 1
	if n > 0:
		Events.notify.emit("Crews seasoned: %d ships hardened" % n)


## Cyan/gold ring under seasoned ships — intensity scales with battle ranks.
func _refresh_crew_glow(s: Dictionary, pulse: bool = false) -> void:
	var node: Node3D = s.get("node")
	if not is_instance_valid(node):
		return
	var vet: int = int(s.get("veterancy", 0))
	if vet <= 0:
		var old: Node = node.get_node_or_null("CrewGlow")
		if old != null:
			old.queue_free()
		return
	var glow: MeshInstance3D = node.get_node_or_null("CrewGlow")
	if glow == null:
		glow = MeshInstance3D.new()
		glow.name = "CrewGlow"
		var torus := TorusMesh.new()
		torus.inner_radius = 1.05
		torus.outer_radius = 1.45
		glow.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		glow.material_override = mat
		glow.position = Vector3(0, -0.35, 0)
		glow.rotate_x(PI / 2.0)
		node.add_child(glow)
	var t: float = clampf(float(vet) / 5.0, 0.2, 1.0)
	var mat2: StandardMaterial3D = glow.material_override as StandardMaterial3D
	if mat2 == null:
		return
	mat2.albedo_color = Color(0.45, 0.95, 1.0, 0.45 + 0.4 * t)
	mat2.emission = Color(0.35, 0.9, 1.0).lerp(Color(1.0, 0.85, 0.35), t * 0.55)
	var base_e: float = 1.1 + float(mini(vet, 8)) * 0.3
	mat2.emission_energy_multiplier = base_e * (1.9 if pulse else 1.0)
	if pulse:
		var tw := create_tween()
		tw.tween_property(mat2, "emission_energy_multiplier", base_e, 0.6)


func _maybe_battle_tutorial() -> void:
	if _battle_tutorial_shown:
		return
	_battle_tutorial_shown = true
	Events.notify.emit(
		"Tip: Press B near hostiles to DROP INTO a fleet battle — fight live, auto-resolve, or retreat for salvage."
	)
	StageObjectives.complete("space_battle_tutorial", "Learned fleet drop-in battles (B)")


## Toast when hostiles press the flagship; auto-open if local fleet HP is critical.
func _tick_fleet_threat(delta: float) -> void:
	_fleet_threat_cd = maxf(0.0, _fleet_threat_cd - delta)
	if _battle_open or not is_instance_valid(_flagship):
		return
	var anchor: Vector3 = _flagship.position
	var hostiles := 0
	var friend_hp := 0.0
	var friend_max := 0.0
	for s in _ships:
		if not is_instance_valid(s.get("node")) or float(s.get("hp", 0.0)) <= 0.0:
			continue
		if s.node.position.distance_to(anchor) > 40.0:
			continue
		if int(s.get("faction", -1)) == 0:
			friend_hp += float(s.hp)
			friend_max += maxf(1.0, float(s.get("max_hp", s.hp)))
		else:
			hostiles += 1
	if hostiles <= 0:
		return
	_maybe_battle_tutorial()
	var frac: float = friend_hp / maxf(1.0, friend_max) if friend_max > 0.0 else 1.0
	# Critical local fleet under fire → auto drop-in (once until next recovery).
	if frac < FLEET_AUTO_HP_FRAC and hostiles >= 1 and not _fleet_auto_opened:
		_fleet_auto_opened = true
		_fleet_threat_cd = FLEET_THREAT_COOLDOWN
		Events.notify.emit("⚔ Fleet critical! Dropping into DEFENSE battle…")
		if not _try_open_space_battle():
			_fleet_auto_opened = false
		return
	if _fleet_threat_cd <= 0.0:
		_fleet_threat_cd = FLEET_THREAT_COOLDOWN
		Events.notify.emit("⚔ Fleet contact! Press B to drop into a fleet battle")
		StageObjectives.complete("space_fleet_threat", "Hostile ships near the flagship")


## Losing empires sue for peace, paying metal + energy tribute (per-empire ceasefire, not galaxy-wide).
func _tick_diplomacy(delta: float) -> void:
	_diplo_t -= delta
	if _diplo_t > 0.0 or _offer_pending or _truce_active():
		return
	_diplo_t = randf_range(DIPLOMACY_INTERVAL_MIN, DIPLOMACY_INTERVAL_MAX)
	var mine := _count_owned(0)
	if mine <= 0:
		return
	for fac in _empires.keys():
		var fid: int = int(fac)
		if _player_at_peace_with(fid):
			continue
		var theirs := _count_owned(fid)
		# Behind the player → sue for peace, paying tribute.
		if theirs <= 0 or theirs >= mine:
			continue
		_offer_pending = true
		var bribe: float = 8.0 + float(maxi(1, mine - theirs)) * 5.0
		var emp_name: String = _faction_name(fid)
		GameShell.confirm(
			"%s sues for peace — offering %s tribute.\nAccept a ceasefire with them (%ds)?" % [
				emp_name, _format_cost(_salvage_value(bribe)), int(PEACE_DURATION)],
			func() -> void:
				_at_peace[fid] = _elapsed + PEACE_DURATION
				var paid := _grant_salvage(bribe)
				Events.notify.emit("☮ Ceasefire with %s. %s · %ds." % [
					emp_name, paid, int(PEACE_DURATION)])
				_offer_pending = false,
			func() -> void:
				Events.notify.emit("War continues with %s." % emp_name)
				_offer_pending = false,
			"Accept", "Decline")
		return


func _issue_fleet_destination(sys: StarSystem3D) -> void:
	if sys == null or not is_instance_valid(sys):
		return
	_fleet_destination = sys
	var dest: Vector3 = sys.position
	var any := false
	for s in _ships:
		if s.faction == 0 and s.get("selected", false):
			s.command = dest
			any = true
	# No ships selected: route the flagship alone (it's always "moving out" with the fleet).
	if not any and _flagship != null:
		pass   # flagship obeys _fleet_destination regardless of selection
	Events.notify.emit("Fleet routing to %s." % sys.system_name)


func _make_ship(faction: int, kind: String, at: Vector3) -> Dictionary:
	var spec: Dictionary = SpaceUnits.FLEET.get(kind, SpaceUnits.FLEET["Fighter"])
	var tint: Color = _faction_color(faction)
	var node := spawn_model(SHIP % str(SpaceUnits.HULL.get(kind, "fighter")), at + Vector3(0, 1, 0), 1.0, 180.0, tint)
	if node == null:
		return {}
	fit_scale(node, SpaceUnits.hull_size(kind))   # normalize mixed-source hull sizes
	SpaceUnits.orient_hull(node, kind)   # lead with the nose under look_at
	_stylize_ship(node)
	var max_speed: float = float(spec.move_speed) * SPACE_SCALE * SHIP_SPEED_SCALE
	var effective_hp: float = float(spec.max_hp) * _armor_mult(faction)
	var effective_damage: float = float(spec.damage) * _weapon_mult(faction)
	var mass_spec: Dictionary = spec.duplicate()
	mass_spec["max_hp"] = effective_hp
	mass_spec["hp"] = effective_hp
	mass_spec["damage"] = effective_damage
	mass_spec["armor_tier"] = _armor_tier if faction == 0 else 0
	var mass: float = ShipPhys.ship_mass(mass_spec)
	var ship := {
		node = node, faction = faction, kind = kind,
		max_hp = effective_hp, hp = effective_hp,
		damage = effective_damage,
		range = float(spec.attack_range) * SPACE_SCALE,
		aggro = float(spec.get("aggro_range", 300.0)) * SPACE_SCALE,
		speed = max_speed,
		mass = mass,
		velocity = Vector3.ZERO,
		heading = Vector3(0.0, 0.0, 1.0),
		max_accel = ShipPhys.max_accel(max_speed * SHIP_THRUST_PER_SPEED, mass),
		max_turn_rate = ShipPhys.max_turn_rate(mass, SHIP_BASE_TURN_RATE),
		cooldown = float(spec.attack_cooldown), cd_t = randf() * 0.5,
		attack_kind = str(spec.get("attack_kind", "single")),
		splash = float(spec.get("splash_radius", 0.0)) * SPACE_SCALE,
		chain = int(spec.get("chain_count", 1)),
		spawns = str(spec.get("spawns", "")), spawn_t = CARRIER_SPAWN_INTERVAL,
		bio = bool(spec.get("bio", false)), infected_by = -1, target = null,
	}
	_ships.append(ship)
	if faction == 0:
		ship.selected = false
		ship.command = Vector3.INF
	var hp_lbl := Label3D.new()
	hp_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_lbl.no_depth_test = true
	hp_lbl.fixed_size = false
	hp_lbl.pixel_size = 0.004
	hp_lbl.font_size = 28
	hp_lbl.outline_size = 6
	hp_lbl.position = Vector3(0, 3.2, 0)
	hp_lbl.modulate = Color(0.3, 1.0, 0.3)
	node.add_child(hp_lbl)
	ship["hpbar"] = hp_lbl
	return ship


func _set_ship_selected(s: Dictionary, on: bool) -> void:
	s.selected = on
	if on:
		if s.node.has_node("SelRing"):
			return
		var ring := MeshInstance3D.new()
		ring.name = "SelRing"
		var mesh := TorusMesh.new()
		mesh.inner_radius = 1.2
		mesh.outer_radius = 1.6
		ring.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = FACTION_COLORS[0]
		mat.albedo_color = FACTION_COLORS[0]
		ring.material_override = mat
		ring.position = Vector3(0, -0.5, 0)
		ring.rotate_x(PI / 2)
		s.node.add_child(ring)
	else:
		var existing: Node = s.node.get_node_or_null("SelRing")
		if existing != null:
			existing.queue_free()


# Stylized cohesion with the planet shader: toon-shaded ships + a subtle faction-less rim, keeping
# each model's own colors (complements the cel planets without the noisy banding).
func _stylize_ship(root: Node3D) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
			# Realistic metallic hull (Space is the serious stage) — sleek + a faint rim, no toon.
			m.metallic = 0.6
			m.metallic_specular = 0.6
			m.roughness = 0.4
			m.rim_enabled = true
			m.rim = 0.3
			mi.set_surface_override_material(s, m)


# Immobile defensive turret (SpaceUnits.DEFENSES) — a ship with speed 0 that rides the combat loop.
func _make_defense(faction: int, kind: String, at: Vector3) -> void:
	var spec: Dictionary = SpaceUnits.DEFENSES.get(kind, SpaceUnits.DEFENSES["OrbitalPlatform"])
	var node := spawn_model(KIT % str(spec.get("model", "turret_single")), at + Vector3(0, 1, 0), 2.2, 0.0, _faction_color(faction))
	if node == null:
		return
	_stylize_ship(node)
	var rng: float = float(spec.attack_range) * SPACE_SCALE
	var mass: float = ShipPhys.ship_mass(spec)
	_ships.append({
		node = node, faction = faction, kind = kind,
		max_hp = float(spec.max_hp) * _armor_mult(faction), hp = float(spec.max_hp) * _armor_mult(faction),
		damage = float(spec.damage) * _weapon_mult(faction),
		range = rng, aggro = rng * 1.2, speed = 0.0,
		mass = mass, velocity = Vector3.ZERO, heading = Vector3(0.0, 0.0, 1.0),
		max_accel = 0.0, max_turn_rate = ShipPhys.max_turn_rate(mass, SHIP_BASE_TURN_RATE),
		cooldown = float(spec.attack_cooldown), cd_t = 0.0,
		attack_kind = str(spec.get("attack_kind", "single")),
		splash = 0.0, chain = int(spec.get("chain_count", 1)),
		spawns = "", spawn_t = 0.0, bio = false, infected_by = -1, target = null,
	})


func _weapon_mult(faction: int) -> float:
	return (_lineage_dmg_mult * (1.0 + 0.15 * _weapon_tier)) if faction == 0 else 1.0


func _armor_mult(faction: int) -> float:
	return (_lineage_hp_mult * (1.0 + 0.15 * _armor_tier)) if faction == 0 else 1.0


# Collective is hostile to everyone; player↔empire honor galaxy or per-empire peace; others fight.
func _allied(a: int, b: int) -> bool:
	if a == COLLECTIVE_FAC or b == COLLECTIVE_FAC:
		return false
	if a == 0 and b != 0:
		return _player_at_peace_with(b)
	if b == 0 and a != 0:
		return _player_at_peace_with(a)
	return false


func _desired_velocity_toward(s: Dictionary, target: Vector3) -> Vector3:
	var dir: Vector3 = target - s.node.position
	dir.y = 0.0
	if dir.length() <= 0.01:
		return Vector3.ZERO
	return dir.normalized() * float(s.get("speed", 0.0)) * _movement_mult(int(s.faction))


func _steer_ship(s: Dictionary, desired_velocity: Vector3, delta: float, face_velocity: bool = true) -> void:
	if not is_instance_valid(s.node):
		return
	var current_velocity: Vector3 = s.get("velocity", Vector3.ZERO)
	var accel: float = float(s.get("max_accel", 0.0))
	var new_velocity: Vector3 = ShipPhys.apply_accel_limit(current_velocity, desired_velocity, accel, delta)
	var max_speed: float = float(s.get("speed", 0.0)) * _movement_mult(int(s.faction))
	if max_speed > 0.0 and new_velocity.length() > max_speed:
		new_velocity = new_velocity.normalized() * max_speed
	if new_velocity.length() > 0.001:
		s.node.position += new_velocity * delta
		if face_velocity:
			_turn_ship_toward(s, new_velocity, delta)
	else:
		new_velocity = Vector3.ZERO
	s.velocity = new_velocity


func _turn_ship_toward(s: Dictionary, direction: Vector3, delta: float) -> void:
	if not is_instance_valid(s.node):
		return
	var target_heading: Vector3 = direction
	target_heading.y = 0.0
	if target_heading.length() <= 0.001:
		return
	target_heading = target_heading.normalized()
	var current_heading: Vector3 = s.get("heading", Vector3(0.0, 0.0, 1.0))
	current_heading.y = 0.0
	if current_heading.length() <= 0.001:
		current_heading = target_heading
	else:
		current_heading = current_heading.normalized()
	var turn_rate: float = float(s.get("max_turn_rate", SHIP_BASE_TURN_RATE))
	var max_step: float = maxf(turn_rate, 0.0) * delta
	var angle: float = current_heading.signed_angle_to(target_heading, Vector3.UP)
	if not is_finite(angle):
		current_heading = target_heading
	elif absf(angle) <= max_step:
		current_heading = target_heading
	else:
		current_heading = current_heading.rotated(Vector3.UP, clampf(angle, -max_step, max_step)).normalized()
	s.heading = current_heading
	if s.node.global_position.distance_to(s.node.position + current_heading) > 0.1:
		s.node.look_at(s.node.position + current_heading, Vector3.UP)


func _tick_combat(delta: float) -> void:
	# Rebuild the formation roster BEFORE the per-ship loop so every _idle_move call
	# inside the loop sees the same per-tick slot assignment (no flicker mid-tick). For a solo
	# player ship the roster stays empty and the original direct-to-command path runs.
	_rebuild_fleet_formation_slots()
	for s in _ships:
		if not is_instance_valid(s.node):
			continue
		if s.hp <= 0.0:
			continue   # dead this tick (killed earlier in the loop) — corpses never act
		if s.has("hpbar") and is_instance_valid(s.hpbar):
			var frac: float = clampf(s.hp / maxf(s.max_hp, 1.0), 0.0, 1.0)
			s.hpbar.text = "%d%%" % int(round(frac * 100.0))
			s.hpbar.modulate = Color(1.0 - frac, frac, 0.25)
		s.cd_t = maxf(0.0, s.cd_t - delta)
		if s.spawns != "":
			s.spawn_t -= delta
			if s.spawn_t <= 0.0:
				s.spawn_t = CARRIER_SPAWN_INTERVAL
				_make_ship(s.faction, s.spawns, s.node.position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
		if s.target == null or not _ship_valid(s.target) or s.target.faction == s.faction or _allied(s.faction, s.target.faction):
			s.target = _acquire_target(s)
		if s.target == null:
			_idle_move(s, delta)
			continue
		var tpos: Vector3 = s.target.node.position
		var d: float = s.node.position.distance_to(tpos)
		if d > s.range:
			_steer_ship(s, _desired_velocity_toward(s, tpos), delta)
		else:
			_steer_ship(s, Vector3.ZERO, delta, false)
			_turn_ship_toward(s, Vector3(tpos.x, s.node.position.y, tpos.z) - s.node.position, delta)
			if s.cd_t <= 0.0:
				s.cd_t = s.cooldown
				_fire_weapon(s)
	_reap_dead()


func _ship_valid(s) -> bool:
	return s != null and is_instance_valid(s.node) and s.hp > 0.0


func _acquire_target(s: Dictionary):
	var best = null
	var bd: float = s.aggro * s.aggro
	for o in _ships:
		if o.faction == s.faction or not _ship_valid(o) or _allied(s.faction, o.faction):
			continue
		var dd: float = s.node.position.distance_squared_to(o.node.position)
		if dd < bd:
			bd = dd
			best = o
	return best


func _fire_weapon(s: Dictionary) -> void:
	var col: Color = Color(0.45, 1.0, 0.45) if s.bio else _weapon_color(str(s.attack_kind), s.faction)
	var p0: Vector3 = s.node.position
	var p1: Vector3 = s.target.node.position
	# One laser/strike SFX per shot (cooldown throttles a 12-ship brawl in AudioManager).
	AudioManager.play_sfx("space_laser")
	match s.attack_kind:
		"splash":
			# Bomber missile → a fat bolt + an expanding impact burst with area damage.
			_spawn_bolt(p0, p1, col, 0.2)
			_spawn_impact(p1, col)
			_damage_ship(s, s.target, 1.0)
			for o in _ships:
				if o.faction == s.faction or not _ship_valid(o) or _allied(s.faction, o.faction):
					continue
				if o != s.target and o.node.position.distance_to(p1) <= s.splash:
					_damage_ship(s, o, 0.6)
		"chain":
			# Tesla → a jagged lightning arc that leaps between targets.
			_spawn_arc(p0, p1, col)
			_damage_ship(s, s.target, 1.0)
			var hit: Array = [s.target]
			var src: Dictionary = s.target
			for i in range(1, s.chain):
				var nxt = _nearest_enemy_excluding(s, src.node.position, hit)
				if nxt == null:
					break
				_damage_ship(s, nxt, pow(0.7, i))
				_spawn_arc(src.node.position, nxt.node.position, col)
				hit.append(nxt)
				src = nxt
		"beam_split":
			# Prism → bright wide beams refracting to several targets at once.
			for t in _nearest_enemies(s, s.chain):
				_damage_ship(s, t, 1.0)
				_spawn_bolt(p0, t.node.position, col, 0.18)
		_:
			# Single → a clean thin laser (bio = green spore lance).
			_spawn_bolt(p0, p1, col, 0.12 if not s.bio else 0.16)
			_damage_ship(s, s.target, 1.0)


# Weapon-kind signature color (lightly tinted toward the faction so sides still read).
func _weapon_color(kind: String, faction: int) -> Color:
	var base: Color
	match kind:
		"splash":
			base = Color(1.0, 0.6, 0.2)      # missile orange
		"chain":
			base = Color(0.55, 1.0, 1.0)     # tesla cyan
		"beam_split":
			base = Color(1.0, 0.45, 1.0)     # prism magenta
		_:
			base = Color(0.7, 0.9, 1.0)      # laser blue-white
	return base.lerp(_faction_color(faction), 0.25)


func _damage_ship(s: Dictionary, t: Dictionary, mult: float) -> void:
	t.hp -= s.damage * mult
	if s.bio:
		t.infected_by = s.faction


func _nearest_enemy_excluding(s: Dictionary, from: Vector3, exclude: Array):
	var best = null
	var bd := INF
	for o in _ships:
		if o.faction == s.faction or not _ship_valid(o) or _allied(s.faction, o.faction) or o in exclude:
			continue
		var dd: float = from.distance_squared_to(o.node.position)
		if dd < bd:
			bd = dd
			best = o
	return best


func _nearest_enemies(s: Dictionary, n: int) -> Array:
	var pool: Array = []
	for o in _ships:
		if o.faction == s.faction or not _ship_valid(o) or _allied(s.faction, o.faction):
			continue
		pool.append(o)
	pool.sort_custom(func(a, b): return s.node.position.distance_squared_to(a.node.position) < s.node.position.distance_squared_to(b.node.position))
	return pool.slice(0, n)


# Player ships loosely escort the flagship; AI ships drift toward the nearest enemy system.
func _idle_move(s: Dictionary, delta: float) -> void:
	if s.faction == 0 and s.get("command", Vector3.INF) != Vector3.INF:
		# When 2+ selected player ships share this move order, they spread into a wedge
		# around the flagship (slots rotated to the travel direction + boids separation). The
		# flagship itself is the leader — it routes independently via _fleet_destination, and the
		# escort ships chase world-space slot targets that follow it. A solo player ship falls
		# through to the original direct-to-command path (behaviour preserved verbatim).
		var idx: int = _fleet_roster.find(s)
		if idx >= 0 and idx < _fleet_slots.size():
			var slot_target: Vector3 = _fleet_slots[idx]
			var others: Array[Vector3] = []
			for j in _fleet_roster.size():
				if j == idx:
					continue
				var other: Dictionary = _fleet_roster[j]
				if is_instance_valid(other.node):
					others.append(other.node.position)
			var sep: Vector3 = FleetForm.separation(s.node.position, others, FleetForm.DEFAULT_SEPARATION_RADIUS)
			var max_speed: float = s.speed * _movement_mult(int(s.faction))
			var desired: Vector3 = FleetForm.desired_velocity(s.node.position, slot_target, sep, max_speed)
			if desired.length() > 0.01:
				_steer_ship(s, desired, delta)
			else:
				_steer_ship(s, Vector3.ZERO, delta)
			# Arrived when this ship is close to the shared command (threshold covers the wedge
			# spread so the wingtip of a 10-ship V clears at the same time as the leader).
			if s.node.position.distance_to(s.command) < _fleet_arrival_threshold:
				s.command = Vector3.INF
			return
		var cmd_dir: Vector3 = s.command - s.node.position
		cmd_dir.y = 0.0
		if cmd_dir.length() < 4.0:
			s.command = Vector3.INF
			_steer_ship(s, Vector3.ZERO, delta)
			return
		if cmd_dir.length() > 0.01:
			_steer_ship(s, _desired_velocity_toward(s, s.command), delta)
		return
	var goal: Vector3
	if s.faction == 0:
		goal = _flagship.position
		if s.node.position.distance_to(goal) < 8.0:
			_steer_ship(s, Vector3.ZERO, delta)
			return
	else:
		var sys := _empire_nearest_enemy_system(s)
		if sys == null:
			_steer_ship(s, Vector3.ZERO, delta)
			return
		goal = sys.position
		if s.node.position.distance_to(goal) < 6.0:
			_steer_ship(s, Vector3.ZERO, delta)
			return
	_steer_ship(s, _desired_velocity_toward(s, goal), delta)


# Rebuild the formation roster (player ships with command != INF), compute their
# world-space wedge targets oriented to the flagship→command travel direction, and record the
# per-tick arrival threshold (covers the wedge spread). With 0 or 1 active ships the roster
# stays empty and _idle_move falls through to its original path. The flagship is the LEADER but
# is NOT a roster member — it auto-routes via _fleet_destination separately, and the escort ships
# chase slot targets that follow the leader position.
func _rebuild_fleet_formation_slots() -> void:
	_fleet_roster.clear()
	_fleet_slots.clear()
	_fleet_arrival_threshold = 4.0
	var fleet: Array = []
	for s in _ships:
		if not _ship_valid(s):
			continue
		if s.faction != 0:
			continue
		if s.get("command", Vector3.INF) == Vector3.INF:
			continue
		fleet.append(s)
	if fleet.size() < 2:
		return
	var local_slots: Array[Vector3] = FleetForm.slots(fleet.size(), FleetForm.DEFAULT_SPACING)
	var leader_pos: Vector3 = _flagship.position if is_instance_valid(_flagship) else Vector3.ZERO
	var goal: Vector3 = fleet[0].command   # all selected ships share the same move order
	var travel: Vector3 = goal - leader_pos
	travel.y = 0.0
	if travel.length() < 0.01:
		travel = Vector3(0, 0, 1)   # arbitrary forward when leader is already at the goal
	var fwd: Vector3 = travel.normalized()
	var angle: float = atan2(fwd.x, fwd.z)
	var rot := Transform3D().rotated(Vector3.UP, angle)
	_fleet_roster = fleet
	_fleet_slots.resize(local_slots.size())
	var max_slot_mag: float = 0.0
	for i in local_slots.size():
		var ls: Vector3 = local_slots[i]
		if ls.length() > max_slot_mag:
			max_slot_mag = ls.length()
		_fleet_slots[i] = leader_pos + rot * ls
	# Dissolve the formation when every ship is close to the shared command point — the wedge
	# spread can push the wingtips ~max_slot_mag away from the command, hence the +spread.
	_fleet_arrival_threshold = 4.0 + max_slot_mag


func _empire_nearest_enemy_system(s: Dictionary) -> StarSystem3D:
	var best: StarSystem3D = null
	var bd := INF
	for sys in _systems:
		if sys.faction == s.faction:
			continue
		var dd: float = s.node.position.distance_squared_to(sys.position)
		if dd < bd:
			bd = dd
			best = sys
	return best


func _reap_dead() -> void:
	var alive: Array = []
	for s in _ships:
		if s.hp > 0.0 and is_instance_valid(s.node):
			alive.append(s)
			continue
		# Bio defection: an infected ship may switch to the infector instead of dying.
		if s.infected_by >= 0 and s.infected_by != s.faction and is_instance_valid(s.node) and randf() < BIO_DEFECT_CHANCE:
			s.faction = s.infected_by
			s.hp = s.max_hp * 0.4
			s.infected_by = -1
			s.target = null
			tint_model(s.node, _faction_color(s.faction))
			Events.notify.emit("☣ A ship defected to %s!" % _faction_name(s.faction))
			alive.append(s)
		elif is_instance_valid(s.node):
			_spawn_explosion(s.node.position)
			s.node.queue_free()
	_ships = alive


# Empires periodically muster a warship at one of their systems to press the war.
func _tick_empire_fleets(delta: float) -> void:
	_empire_fleet_t -= delta
	if _empire_fleet_t > 0.0:
		return
	_empire_fleet_t = EMPIRE_FLEET_INTERVAL
	for fac in _empires.keys():
		var owned := _owned_systems(fac)
		if owned.is_empty():
			continue
		if _count_faction_ships(fac) >= 6:
			continue
		var kind: String = ["Fighter", "Cruiser", "ArcFrigate", "Bomber"][randi() % 4]
		var spawn_sys: StarSystem3D = owned[randi() % owned.size()]
		_make_ship(fac, kind, spawn_sys.position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
		# If they muster near a player system, surface it once in a while.
		if is_instance_valid(_flagship) and spawn_sys.position.distance_to(_flagship.position) < 55.0:
			Events.notify.emit("⚔ %s musters a %s nearby" % [_faction_name(int(fac)), kind])


func _count_faction_ships(fac: int) -> int:
	var n := 0
	for s in _ships:
		if s.faction == fac and _ship_valid(s):
			n += 1
	return n


func _faction_ship_near(fac: int, at: Vector3, radius: float) -> bool:
	for s in _ships:
		if s.faction == fac and _ship_valid(s) and s.node.position.distance_to(at) <= radius:
			return true
	return false


# A brief emissive beam between two points (laser / prism / missile trail).
func _spawn_bolt(from: Vector3, to: Vector3, color: Color, radius: float = 0.12) -> void:
	var bolt := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = from.distance_to(to)
	bolt.mesh = cyl
	bolt.material_override = _fx_mat(color)
	add_child(bolt)
	bolt.global_position = (from + to) * 0.5
	if from.distance_to(to) > 0.01 and not from.is_equal_approx(to):
		if bolt.global_position.distance_to(to) > 0.1:
			bolt.look_at(to, Vector3.UP)
			bolt.rotate_object_local(Vector3.RIGHT, PI / 2)
	_bolts.append({node = bolt, ttl = 0.16})


# A jagged lightning arc (Tesla / ArcFrigate) — several short segments zig-zagging from→to.
func _spawn_arc(from: Vector3, to: Vector3, color: Color) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var axis: Vector3 = (to - from)
	var perp: Vector3 = axis.cross(Vector3.UP)
	if perp.length() < 0.01:
		perp = axis.cross(Vector3.RIGHT)
	perp = perp.normalized()
	var perp2: Vector3 = axis.cross(perp).normalized()
	var segs := 5
	var prev: Vector3 = from
	for i in range(1, segs + 1):
		var pt: Vector3 = from.lerp(to, float(i) / float(segs))
		if i < segs:
			pt += (perp * randf_range(-1.0, 1.0) + perp2 * randf_range(-1.0, 1.0)) * 1.3
		_arc_segment(holder, prev, pt, color)
		prev = pt
	_bolts.append({node = holder, ttl = 0.18})


func _arc_segment(parent: Node3D, a: Vector3, b: Vector3, color: Color) -> void:
	var seg := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = a.distance_to(b)
	seg.mesh = cyl
	seg.material_override = _fx_mat(color)
	parent.add_child(seg)
	seg.global_position = (a + b) * 0.5
	if a.distance_to(b) > 0.01 and not a.is_equal_approx(b):
		if seg.global_position.distance_to(b) > 0.1:
			seg.look_at(b, Vector3.UP)
			seg.rotate_object_local(Vector3.RIGHT, PI / 2)


# A small expanding burst (splash/missile impact).
func _spawn_impact(at: Vector3, color: Color) -> void:
	var e := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	e.mesh = sm
	e.material_override = _fx_mat(color)
	add_child(e)
	e.global_position = at
	e.scale = Vector3.ONE * 0.4
	_bolts.append({node = e, ttl = 0.3, grow = true})


func _fx_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.albedo_color = color
	m.emission = color
	m.emission_energy_multiplier = 2.0
	return m


func _tick_bolts(delta: float) -> void:
	var keep: Array = []
	for b in _bolts:
		b.ttl -= delta
		if b.get("grow", false) and is_instance_valid(b.node):
			b.node.scale *= (1.0 + delta * 3.5)   # explosion fireball expands (modest)
		if b.ttl <= 0.0:
			if is_instance_valid(b.node):
				b.node.queue_free()
		else:
			keep.append(b)
	_bolts = keep


# A brief expanding fireball where a ship died.
func _spawn_explosion(at: Vector3) -> void:
	AudioManager.play_sfx("space_explosion")
	var e := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	e.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.albedo_color = Color(1.0, 0.6, 0.15)
	m.emission = Color(1.0, 0.55, 0.1)
	m.emission_energy_multiplier = 2.5
	e.material_override = m
	add_child(e)
	e.global_position = at
	e.scale = Vector3.ONE * 0.5
	_bolts.append({node = e, ttl = 0.35, grow = true})


# Easter egg: a lone cargo courier drifts across the galaxy on its own, re-routing forever.
# Kenney kit crafts are authored nose −Z, so plain look_at already leads with the nose.
func _spawn_courier() -> void:
	_courier = spawn_model(KIT % "craft_cargoA", _rand_sky_point(), 1.0, 0.0)
	if _courier != null:
		fit_scale(_courier, 5.0)
	_pick_courier_goal()


func _rand_sky_point() -> Vector3:
	return Vector3(randf_range(-GALAXY_EXTENT, GALAXY_EXTENT), 10.0, randf_range(-GALAXY_EXTENT, GALAXY_EXTENT))


func _pick_courier_goal() -> void:
	_courier_goal = _rand_sky_point()


func _tick_courier(delta: float) -> void:
	if _courier == null or not is_instance_valid(_courier):
		return
	_courier_t -= delta
	if _courier_t <= 0.0:
		_courier.queue_free()
		_courier = null
		_courier_t = randf_range(COURIER_COOLDOWN_MIN, COURIER_COOLDOWN_MAX)
		return
	var dir: Vector3 = _courier_goal - _courier.position
	if dir.length() < 6.0:
		_pick_courier_goal()
		return
	_courier.position += dir.normalized() * 22.0 * delta
	if _courier.global_position.distance_to(_courier.position + dir.normalized()) > 0.1:
		_courier.look_at(_courier.position + dir.normalized(), Vector3.UP)


## ----------------------------------------------------------------------------------------------
## The Collective — roaming green cube ships, hostile to ALL (own faction id → everyone fights them,
## they fight everyone). Capture nothing; pure wandering menace. They ride the same combat loop.
## ----------------------------------------------------------------------------------------------
func _tick_collective(delta: float) -> void:
	_cube_t -= delta
	if _cube_t > 0.0:
		return
	_cube_t = CUBE_SPAWN_INTERVAL
	if _count_faction_ships(COLLECTIVE_FAC) >= MAX_CUBES:
		return
	_make_cube(Vector3(randf_range(-GALAXY_EXTENT, GALAXY_EXTENT), 0, randf_range(-GALAXY_EXTENT, GALAXY_EXTENT)))
	Events.notify.emit("◼ A Collective cube uncloaks in the void!")


func _make_cube(at: Vector3) -> void:
	var node := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3, 3, 3)
	node.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.9, 0.3)
	m.emission_enabled = true
	m.emission = Color(0.15, 0.8, 0.25)
	m.emission_energy_multiplier = 1.2
	node.material_override = m
	add_child(node)
	node.global_position = at + Vector3(0, 1, 0)
	var cube_speed: float = 5.0
	var cube_mass: float = ShipPhys.ship_mass({"max_hp": 320.0, "damage": 14.0, "attack_kind": "single"})
	_ships.append({
		node = node, faction = COLLECTIVE_FAC, kind = "Cube",
		max_hp = 320.0, hp = 320.0, damage = 14.0,
		range = 16.0, aggro = 64.0, speed = cube_speed,
		mass = cube_mass,
		velocity = Vector3.ZERO,
		heading = Vector3(0.0, 0.0, 1.0),
		max_accel = ShipPhys.max_accel(cube_speed * SHIP_THRUST_PER_SPEED, cube_mass),
		max_turn_rate = ShipPhys.max_turn_rate(cube_mass, SHIP_BASE_TURN_RATE),
		cooldown = 1.0, cd_t = 0.0, attack_kind = "single",
		splash = 0.0, chain = 1, spawns = "", spawn_t = 0.0,
		bio = false, infected_by = -1, target = null,
	})


## ----------------------------------------------------------------------------------------------
## Cosmic hazards (rare): comets streak across damaging ships they pass; black holes pull + damage
## nearby ships for a few seconds. They hit ALL factions fairly (living-galaxy unpredictability).
## ----------------------------------------------------------------------------------------------
func _tick_hazards(delta: float) -> void:
	var keep: Array = []
	for h in _hazards:
		h.ttl -= delta
		if h.type == "comet":
			h.node.position += h.vel * delta
			for s in _ships:
				if _ship_valid(s) and s.node.position.distance_to(h.node.position) < 7.0:
					s.hp -= 45.0 * delta
		else:
			for s in _ships:
				if not _ship_valid(s):
					continue
				var to_h: Vector3 = h.node.position - s.node.position
				if to_h.length() < 24.0:
					s.node.position += to_h.normalized() * 6.0 * delta
					s.hp -= 12.0 * delta
		if h.ttl > 0.0 and is_instance_valid(h.node):
			keep.append(h)
		elif is_instance_valid(h.node):
			h.node.queue_free()
	_hazards = keep
	if not _hazards.is_empty():
		_reap_dead()
	_hazard_t -= delta
	if _hazard_t > 0.0:
		return
	_hazard_t = randf_range(HAZARD_MIN, HAZARD_MAX)
	if randf() < 0.5:
		_spawn_comet()
	else:
		_spawn_black_hole()


func _spawn_comet() -> void:
	var node := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.0
	sm.height = 4.0
	node.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.albedo_color = Color(0.8, 0.9, 1.0)
	m.emission = Color(0.7, 0.85, 1.0)
	node.material_override = m
	var edge := GALAXY_EXTENT + 20.0
	var from := Vector3(randf_range(-edge, edge), 0, -edge)
	var to := Vector3(randf_range(-edge, edge), 0, edge)
	add_child(node)
	node.global_position = from
	_hazards.append({type = "comet", node = node, vel = (to - from).normalized() * 60.0, ttl = 6.0})
	Events.notify.emit("☄ A comet tears through the sector!")


func _spawn_black_hole() -> void:
	var node := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.0
	sm.height = 6.0
	node.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.02, 0.0, 0.05)
	m.emission_enabled = true
	m.emission = Color(0.45, 0.12, 0.65)
	m.emission_energy_multiplier = 1.6
	node.material_override = m
	add_child(node)
	node.global_position = Vector3(randf_range(-GALAXY_EXTENT * 0.7, GALAXY_EXTENT * 0.7), 0, randf_range(-GALAXY_EXTENT * 0.7, GALAXY_EXTENT * 0.7))
	_hazards.append({type = "black_hole", node = node, ttl = 8.0})
	Events.notify.emit("● A black hole rends spacetime!")


func _follow_camera() -> void:
	if _cam_free_t > 0.0:
		_cam_free_t = maxf(0.0, _cam_free_t - get_process_delta_time())
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("set_focus") and is_instance_valid(_flagship):
		cam.set_focus(_flagship.position)


func _galaxy_income() -> Dictionary:
	return _faction_income(0)


func _resource_total(values: Dictionary) -> float:
	var total := 0.0
	for id: String in ResourceModel.all_ids():
		total += float(values.get(id, 0.0))
	return total


func _treasury_total() -> float:
	return _resource_total(_treasury)


func _faction_income(fac: int) -> Dictionary:
	var income: Dictionary = EconomyModel.income(_owned_systems(fac))
	for s in _systems:
		if s.faction != fac or s.structure == "":
			continue
		var bonus: Dictionary = STRUCTURE_INCOME_BONUS.get(s.structure, {})
		for id: String in bonus.keys():
			income[id] = float(income.get(id, 0.0)) + float(bonus[id])
	return income


func _normalize_treasury(value: Dictionary, use_seed: bool) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ResourceModel.all_ids():
		var default_value: float = float(TREASURY_START.get(id, 0.0)) if use_seed else 0.0
		result[id] = float(value.get(id, default_value))
	return result


func _add(a: Dictionary, b: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ResourceModel.all_ids():
		result[id] = float(a.get(id, 0.0)) + float(b.get(id, 0.0))
	return result


func _scale(values: Dictionary, factor: float) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ResourceModel.all_ids():
		result[id] = float(values.get(id, 0.0)) * factor
	return result


func _can_afford(cost: Dictionary) -> bool:
	return EconomyModel.can_afford(_treasury, cost)


func _pay(cost: Dictionary) -> void:
	_treasury = EconomyModel.spend(_treasury, cost)


func _cost_from_scalar(amount: float, metal_ratio: float = 0.65) -> Dictionary:
	var total: float = amount * COST_SCALE
	return {
		"metal": total * metal_ratio,
		"energy": total * (1.0 - metal_ratio),
	}


func _ship_cost(ship_name: String) -> Dictionary:
	var spec: Dictionary = SHIPS.get(ship_name, {})
	if spec.has("metal") or spec.has("energy"):
		return {"metal": float(spec.get("metal", 0.0)), "energy": float(spec.get("energy", 0.0))}
	return _cost_from_scalar(float(spec.get("cost", 0.0)), 0.7)


func _drone_cost() -> Dictionary:
	var spec: Dictionary = SpaceUnits.DRONE
	if spec.has("metal") or spec.has("energy"):
		return {"metal": float(spec.get("metal", 0.0)), "energy": float(spec.get("energy", 0.0))}
	return _cost_from_scalar(float(spec.get("cost", 0.0)), 0.6)


func _structure_cost(kind: String) -> Dictionary:
	var ratio := 0.65
	if kind == "SolarCollector":
		ratio = 0.4
	elif kind == "MiningRig" or kind == "Bastion" or kind == "Annihilator":
		ratio = 0.75
	elif kind == "ResearchLab" or kind == "JumpGate":
		ratio = 0.5
	var spec: Dictionary = SpaceUnits.BUILDINGS.get(kind, STRUCTURES.get(kind, {}))
	if spec.has("metal") or spec.has("energy"):
		return {"metal": float(spec.get("metal", 0.0)), "energy": float(spec.get("energy", 0.0))}
	return _cost_from_scalar(float(spec.get("cost", 0.0)), ratio)


func _defense_cost(kind: String) -> Dictionary:
	var spec: Dictionary = SpaceUnits.DEFENSES.get(kind, {})
	if spec.has("metal") or spec.has("energy"):
		return {"metal": float(spec.get("metal", 0.0)), "energy": float(spec.get("energy", 0.0))}
	return _cost_from_scalar(float(spec.get("cost", 0.0)), 0.75)


# Station costs come from StationStats.STATIONS (real metal+energy
# values, not the synthetic cost-scalar), so we use them directly. Pure passthrough;
# `get_station` returns {} on miss and the can_afford check naturally rejects it.
func _station_cost(kind: String) -> Dictionary:
	var spec: Dictionary = StatStats.get_station(kind)
	return {"metal": float(spec.get("metal", 0.0)), "energy": float(spec.get("energy", 0.0))}


# A station is buildable on this system iff its min_tier <= the system's
# current evo_stage (mirrors how STRUCTURES gate on min_age, but uses StationStats
# naming). Returns false for unknown kinds.
func _station_tier_ok(sys: StarSystem3D, kind: String) -> bool:
	if sys == null:
		return false
	var allowed: Array[String] = StatStats.buildable_stations_for_tier(sys.evo_stage)
	return allowed.has(kind)


# Is there already a queued station-build for this system (any kind)? Mirrors
# _has_pending_structure so the queue UI can disable the buttons correctly.
func _has_pending_station(system_index: int, kind: String = "") -> bool:
	for entry: Dictionary in _build_queue:
		if str(entry.get("kind", "")) != BUILD_KIND_STATION:
			continue
		if int(entry.get("system_index", -1)) != system_index:
			continue
		if kind == "" or str(entry.get("item", "")) == kind:
			return true
	return false


# Per-frame economy: system income, then every player refinery refines water/biomass.
func _tick_economy(delta: float) -> void:
	_treasury = _add(_treasury, _scale(_galaxy_income(), delta))
	_treasury = EconomyModel.refine(_treasury, _refinery_count(), delta)


func _refinery_count() -> int:
	var n := 0
	for s in _systems:
		if s.faction == 0 and s.has_station(STATION_REFINERY):
			n += 1
	return n


func _salvage_value(amount: float) -> Dictionary:
	return _cost_from_scalar(amount * SALVAGE_RATE)


# Battle loot, capture salvage and peace tribute pay out metal + energy at SALVAGE_RATE.
# Returns the "+N M / N E" text for the toast.
func _grant_salvage(amount: float) -> String:
	var gain := _salvage_value(amount)
	_treasury = _add(_treasury, gain)
	return "+" + _format_cost(gain)


func _truce_cost() -> Dictionary:
	return _cost_from_scalar(TRUCE_COST, 0.2)


func _upgrade_cost_dict(tier: int) -> Dictionary:
	return _cost_from_scalar(_upgrade_cost(tier), 0.5)


func _format_cost(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: String in ResourceModel.all_ids():
		var amount := float(cost.get(id, 0.0))
		if amount <= 0.0:
			continue
		parts.append("%d %s" % [int(ceil(amount)), id.substr(0, 1).to_upper()])
	return " / ".join(parts)


func _format_resources(values: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: String in ResourceModel.all_ids():
		parts.append("%s %d" % [id.substr(0, 1).to_upper(), int(floor(float(values.get(id, 0.0))))])
	return "  ".join(parts)


func _fleet_power() -> float:
	var p := 1.0 + _structure_count("HabitatRing") * 1.5
	for s in _ships:
		if s.faction == 0 and _ship_valid(s) and s.node.position.distance_to(_flagship.position) < 40.0:
			p += s.damage * 0.1 + s.max_hp * 0.02
	return p


func _structure_count(kind: String) -> int:
	return _structure_count_for_faction(0, kind)


func _structure_count_for_faction(fac: int, kind: String) -> int:
	var count := 0
	for s in _systems:
		if s.faction == fac and s.structure == kind:
			count += 1
	return count


func _research_mult() -> float:
	return minf(2.5, 1.0 + _structure_count("ResearchLab") * 0.35)


func _movement_mult(faction: int) -> float:
	if faction != 0:
		return 1.0
	return minf(1.6, 1.0 + _structure_count("JumpGate") * 0.15)


# The system the flagship is parked on (or the fleet's destination it just reached) captures
# toward the player; systems it left decay back. Capture-rate math is the pure FleetMovement
# helper so the formula is unit-tested.
func _tick_player_capture(delta: float) -> void:
	var here: StarSystem3D = _nearest_system(_flagship.position, CAPTURE_RADIUS)
	var fp: float = _fleet_power()
	for s in _systems:
		var present: bool = s == here and s.faction != 0
		# A treaty protects that empire's worlds: parking on them doesn't start a siege.
		if present and int(s.faction) > 0 and _player_at_peace_with(int(s.faction)):
			present = false
			if _peace_block_toasted != s.get_instance_id():
				_peace_block_toasted = s.get_instance_id()
				Events.notify.emit("At peace with %s — %s can't be captured until the treaty ends" % [
					_faction_name(int(s.faction)), s.system_name])
		if present:
			s.contender = 0
			s.capture += FleetMv.capture_delta(true, fp, delta, CAPTURE_RATE, CAPTURE_DECAY)
			var cap: float = float(s.capture)
			var sid: int = s.get_instance_id()
			# Halfway toast once per system so parking-to-capture is readable.
			if cap >= 0.5 and cap < 1.0 and not bool(_capture_halfway_toasted.get(sid, false)):
				_capture_halfway_toasted[sid] = true
				Events.notify.emit("Capturing %s… hold position (fleet power %.1f)" % [s.system_name, fp])
			if FleetMv.capture_complete(s.capture):
				var was_enemy: bool = int(s.faction) > 0
				s.set_faction(0, FACTION_COLORS[0])
				_capture_halfway_toasted.erase(sid)
				var salvage: float = 4.0 + (6.0 if was_enemy else 0.0) + fp * 0.35
				Events.notify.emit("★ Secured %s · salvage %s" % [s.system_name, _grant_salvage(salvage)])
				StageObjectives.complete("space_capture", "Captured a system — expand the frontier")
				AudioManager.play_sfx("chime")
		elif s.contender == 0 and s.faction != 0:
			s.capture = maxf(0.0, s.capture + FleetMv.capture_delta(false, 0.0, delta, CAPTURE_RATE, CAPTURE_DECAY))


# Each empire expands on a timer that SHORTENS as the war drags on (escalating difficulty).
# EmpireAI.choose_action gates the move: expand/attack push the frontier, while
# research/fortify can spend treasury to develop an owned world.
func _tick_empires(delta: float) -> void:
	var interval := GSim.expansion_interval(EMPIRE_EXPAND_BASE, _elapsed, 3.0)
	_empire_gang_track.clear()
	for fac in _empires.keys():
		var emp: Dictionary = _empires[fac]
		var owned_n := _count_owned(fac)
		# Rise & fall: track the empire's high-water mark; the first time a once-living
		# empire is reduced to zero systems it collapses (logged once) and goes dormant.
		emp["peak"] = maxf(float(emp.get("peak", 0.0)), float(owned_n))
		if owned_n == 0:
			if float(emp.get("peak", 0.0)) > 0.0 and not bool(emp.get("collapsed", false)):
				emp["collapsed"] = true
				_log_galaxy("✖ %s has collapsed." % _faction_name(fac))
			continue
		emp["collapsed"] = false
		# Real per-empire economy: treasury accrues from THIS empire's own systems' income
		# every frame (no longer a shared fake number), so a sprawling rich empire is
		# genuinely stronger and a starving one can be ground down.
		emp["treasury"] = float(emp.get("treasury", 0.0)) + _empire_income(fac) * delta
		emp["timer"] = float(emp.get("timer", interval)) - delta
		if emp["timer"] > 0.0:
			continue
		emp["timer"] = interval
		var empire_state: Dictionary = {
			"archetype": _empire_archetype(fac),
			"treasury": float(emp.get("treasury", 0.0)),
			"systems": owned_n,
		}
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash("%s_%d_%d" % [EvolutionState.world_seed, int(fac), int(_elapsed * 10.0)])
		var action: String = EmpireAI.choose_action(empire_state, rng)
		if action == EmpireAI.ACTION_RESEARCH:
			var developed_kind: String = _empire_try_develop(fac, emp, action, rng)
			if developed_kind != GSim.DEVELOP_NONE:
				var tech_gain := 1.0 if developed_kind == GSim.DEVELOP_KIND_RESEARCH_LAB else 0.35
				emp["tech"] = minf(EMPIRE_TECH_CAP, float(emp.get("tech", 0.0)) + tech_gain)
			continue
		if action == EmpireAI.ACTION_FORTIFY:
			_empire_try_develop(fac, emp, action, rng)
			continue
		if action != EmpireAI.ACTION_EXPAND and action != EmpireAI.ACTION_ATTACK:
			continue
		var target := _empire_pick_target(fac)
		if target == null:
			continue
		# Track which faction each empire targets this tick so we can
		# detect coordinated gang-ups against a runaway leader.
		if target.faction >= 0:
			var target_fac: int = target.faction
			_empire_gang_track[target_fac] = int(_empire_gang_track.get(target_fac, 0)) + 1
		_empire_act_on(fac, emp, target, rng)
	# Sparse flavor: when 3+ empires target the same rival, log it.
	if _elapsed - _last_gang_log > 90.0:
		for target_fac: int in _empire_gang_track.keys():
			if int(_empire_gang_track[target_fac]) >= 3:
				if target_fac != 0 or (_empire_gang_track[target_fac] >= 3 and not _player_at_peace_with(target_fac)):
					_log_galaxy("⚔ The galaxy turns on %s." % _faction_name(target_fac))
					_last_gang_log = _elapsed
					break


# Resolve one empire action against a chosen target. A maturing neutral world is colonized
# outright; a Bastion shield soaks the first hit; an enemy/player world is a real fight
# resolved on relative strength (GalaxySim) and paid for win-or-lose — so fronts form,
# stronger empires advance, and underdogs can still repel an invader.
func _empire_act_on(fac: int, emp: Dictionary, target: StarSystem3D, rng: RandomNumberGenerator) -> void:
	if target.faction == 0 and not _faction_ship_near(fac, target.position, EMPIRE_SIEGE_RADIUS):
		return  # player worlds fall only to a fleet that's actually there — kill it to hold the line
	if target.shielded:
		target.shielded = false
		target.set_structure("")
		return
	if target.faction < 0:
		target.set_faction(fac, _faction_color(fac))
		return
	var defender: int = target.faction
	emp["treasury"] = maxf(0.0, float(emp.get("treasury", 0.0)) - GSim.attack_cost(float(emp.get("treasury", 0.0))))
	if not GSim.resolve_attack(_faction_strength(fac), _faction_strength(defender), rng):
		return  # repelled — the front holds (kept quiet to spare the feed)
	var sys_name: String = target.system_name
	var loser: String = _faction_name(defender)
	target.set_faction(fac, _faction_color(fac))
	_log_galaxy("⚔ %s took %s from %s." % [_faction_name(fac), sys_name, loser])
	if defender == 0:
		Events.notify.emit("⚠ %s seized %s from you!" % [_faction_name(fac), sys_name])


func _empire_try_develop(fac: int, emp: Dictionary, action: String, rng: RandomNumberGenerator) -> String:
	var candidates: Array[Dictionary] = _empire_development_candidates(fac)
	if candidates.is_empty():
		return GSim.DEVELOP_NONE
	var choice: Dictionary = GSim.choose_development(
		action,
		_empire_archetype(fac),
		float(emp.get("treasury", 0.0)),
		candidates,
		_empire_development_costs(),
	)
	var kind: String = str(choice.get("kind", GSim.DEVELOP_NONE))
	if kind == GSim.DEVELOP_NONE:
		return GSim.DEVELOP_NONE
	var sys := _system_at_index(int(choice.get("index", -1)))
	if sys == null or sys.faction != fac or sys.structure != "" or not _structure_age_ok(sys, kind):
		return GSim.DEVELOP_NONE
	emp["treasury"] = maxf(0.0, float(emp.get("treasury", 0.0)) - float(choice.get("cost", 0.0)))
	sys.set_structure(kind)
	_log_empire_development(fac, emp, sys, kind, rng)
	return kind


func _empire_development_costs() -> Dictionary:
	var costs: Dictionary = {}
	for kind: String in GSim.DEVELOP_STRUCTURE_COSTS.keys():
		var spec: Dictionary = STRUCTURES.get(kind, {})
		costs[kind] = float(spec.get("cost", GSim.DEVELOP_STRUCTURE_COSTS[kind]))
	return costs


func _empire_development_candidates(fac: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(_systems.size()):
		var s: StarSystem3D = _systems[i]
		if s.faction != fac or s.structure != "":
			continue
		out.append({
			"index": i,
			"evo_stage": s.evo_stage,
			"structure": s.structure,
			"income": _system_base_income(s),
			"threat": _system_threat_score(fac, s),
		})
	return out


func _system_base_income(sys: StarSystem3D) -> float:
	if sys == null:
		return 0.0
	var total := 0.0
	for v in EconomyModel.income([sys]).values():
		total += float(v)
	return total


func _system_threat_score(fac: int, sys: StarSystem3D) -> float:
	if sys == null:
		return 0.0
	var nearest := INF
	for other in _systems:
		if other.faction == fac or other.faction < 0:
			continue
		if other.faction == 0 and _player_at_peace_with(fac):
			continue
		nearest = minf(nearest, sys.position.distance_to(other.position))
	if not is_finite(nearest):
		return 0.0
	return 1.0 / maxf(1.0, nearest)


func _log_empire_development(
	fac: int,
	emp: Dictionary,
	sys: StarSystem3D,
	kind: String,
	rng: RandomNumberGenerator,
) -> void:
	var last_log: float = float(emp.get("develop_log_at", -INF))
	if _elapsed - last_log < EMPIRE_DEVELOP_LOG_INTERVAL and (rng == null or rng.randf() > 0.15):
		return
	emp["develop_log_at"] = _elapsed
	var verb := "developed"
	if kind == "Bastion":
		verb = "fortified"
	elif kind == "MiningRig":
		verb = "industrialized"
	elif kind == "ResearchLab":
		verb = "advanced"
	_log_galaxy("✦ %s %s %s." % [_faction_name(fac), verb, sys.system_name])


# Scalar sum of an empire's multi-resource EconomyModel income across its owned systems.
func _empire_income(fac: int) -> float:
	var total := 0.0
	for v in _faction_income(fac).values():
		total += float(v)
	return total


# Fighting strength of any faction (0 = player, >=1 = empire) from systems + treasury + tech.
func _faction_strength(fac: int) -> float:
	if fac == 0:
		var ptech := float(_structure_count("ResearchLab")) * 2.0 + float(_weapon_tier + _armor_tier)
		return GSim.empire_strength(_count_owned(0), _treasury_total(), ptech) + _faction_structure_strength(fac)
	if _empires.has(fac):
		var e: Dictionary = _empires[fac]
		return GSim.empire_strength(_count_owned(fac), float(e.get("treasury", 0.0)), float(e.get("tech", 0.0))) + _faction_structure_strength(fac)
	return GSim.empire_strength(_count_owned(fac), 0.0, 0.0) + _faction_structure_strength(fac)


func _faction_structure_strength(fac: int) -> float:
	var bonus := 0.0
	bonus += float(_structure_count_for_faction(fac, "Bastion")) * 1.5
	bonus += float(_structure_count_for_faction(fac, "ResearchLab")) * 0.4
	return bonus


# Push an event onto the rolling galaxy feed (capped) and surface it as a toast.
func _log_galaxy(msg: String) -> void:
	_galaxy_log.append(msg)
	while _galaxy_log.size() > GALAXY_LOG_MAX:
		_galaxy_log.pop_front()
	Events.notify.emit(msg)


# Map an empire faction id to an EmpireAI archetype (defaults to expansionist).
func _empire_archetype(fac: int) -> String:
	# The rival themes list is built 1:1 with the empire ids in _ready(); the first few
	# rival empire themes come from the genome lineages table (civ_archetype row).
	if fac >= 1 and fac <= _rival_themes.size():
		var t: Dictionary = _rival_themes[fac - 1]
		# Genome labels map onto FactionTraits ids consumed by EmpireAI.
		var name_lc: String = str(t.get("name", "")).to_lower()
		if "aggressor" in name_lc or "warmonger" in name_lc:
			return "militarist"
		if "scholar" in name_lc or "sage" in name_lc:
			return "technocrat"
		if "fortifier" in name_lc or "defender" in name_lc:
			return "isolationist"
		if "raider" in name_lc:
			return "swarm"
		if "diplomat" in name_lc or "trader" in name_lc:
			return "isolationist"
	return EmpireAI.FALLBACK_ARCHETYPE


# The superweapon: on a cooldown it strikes the nearest enemy system, instantly capturing it.
func _tick_annihilator(delta: float) -> void:
	if _annihilator == null:
		return
	# Structure check too: after a save/load the tracked system can keep faction 0 while
	# no longer hosting the weapon — don't fire a ghost beam from a system without one.
	if not is_instance_valid(_annihilator) or _annihilator.faction != 0 or _annihilator.structure != "Annihilator":
		_annihilator = null
		return
	_annih_cd -= delta
	if _annih_cd > 0.0:
		return
	var target := _empire_nearest_to(_annihilator.position)
	if target != null:
		_fire_beam(_annihilator.position, target.position)
		target.set_faction(0, FACTION_COLORS[0])
		_annih_cd = ANNIHILATOR_COOLDOWN


func _fire_beam(from: Vector3, to: Vector3) -> void:
	if _beam == null:
		_beam = MeshInstance3D.new()
		_beam.mesh = CylinderMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.albedo_color = Color(1.0, 0.4, 0.3)
		m.emission = Color(1.0, 0.4, 0.3)
		_beam.material_override = m
		add_child(_beam)
	var mid := (from + to) * 0.5 + Vector3(0, 2, 0)
	var len := from.distance_to(to)
	(_beam.mesh as CylinderMesh).top_radius = 0.4
	(_beam.mesh as CylinderMesh).bottom_radius = 0.4
	(_beam.mesh as CylinderMesh).height = len
	_beam.position = mid
	if _beam.global_position.distance_to(to + Vector3(0, 2, 0)) > 0.1:
		_beam.look_at(to + Vector3(0, 2, 0), Vector3.UP)
		_beam.rotate_object_local(Vector3.RIGHT, PI / 2)
	_beam.visible = true
	_beam_ttl = 0.6


func _tick_beam(delta: float) -> void:
	if _beam_ttl > 0.0:
		_beam_ttl -= delta
		if _beam_ttl <= 0.0 and _beam:
			_beam.visible = false


func _system_index(sys: StarSystem3D) -> int:
	for i: int in range(_systems.size()):
		if _systems[i] == sys:
			return i
	return -1


func _system_at_index(index: int) -> StarSystem3D:
	if index < 0 or index >= _systems.size():
		return null
	return _systems[index]


func _vec3_to_dict(pos: Vector3) -> Dictionary:
	return {"x": pos.x, "y": pos.y, "z": pos.z}


func _dict_to_vec3(value: Variant, fallback: Vector3) -> Vector3:
	if not (value is Dictionary):
		return fallback
	var p: Dictionary = value
	return Vector3(float(p.get("x", fallback.x)), float(p.get("y", fallback.y)), float(p.get("z", fallback.z)))


func _enqueue_build(entry: Dictionary) -> void:
	_build_queue.append(entry.duplicate())


func _has_pending_structure(system_index: int, kind: String = "") -> bool:
	for entry: Dictionary in _build_queue:
		if str(entry.get("kind", "")) != BUILD_KIND_STRUCTURE:
			continue
		if int(entry.get("system_index", -1)) != system_index:
			continue
		if kind == "" or str(entry.get("item", "")) == kind:
			return true
	return false


## True if an Annihilator exists anywhere: built on any owned system, tracked live, or
## still pending in the build queue. The uniqueness rule for the superweapon.
func _annihilator_exists_anywhere() -> bool:
	if _annihilator != null and is_instance_valid(_annihilator):
		return true
	for sys in _systems:
		if sys.faction == 0 and sys.structure == "Annihilator":
			return true
	for entry: Dictionary in _build_queue:
		if str(entry.get("kind", "")) == BUILD_KIND_STRUCTURE and str(entry.get("item", "")) == "Annihilator":
			return true
	return false


func _tick_build_queue(delta: float) -> void:
	if _build_queue.is_empty():
		return
	var pending: Array[Dictionary] = []
	for entry: Dictionary in _build_queue:
		var updated: Dictionary = entry.duplicate()
		var time_left: float = maxf(0.0, float(updated.get("time_left", 0.0)) - delta)
		updated["time_left"] = time_left
		if time_left <= 0.0:
			_complete_build(updated)
		else:
			pending.append(updated)
	_build_queue = pending


func _complete_build(entry: Dictionary) -> void:
	var kind := str(entry.get("kind", ""))
	var item := str(entry.get("item", ""))
	match kind:
		BUILD_KIND_SHIP:
			var yard := _system_at_index(int(entry.get("system_index", -1)))
			if yard != null and yard.faction == 0 and yard.has_shipyard:
				_make_ship(0, item, yard.position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
				Events.notify.emit("%s launched from %s." % [item, yard.system_name])
		BUILD_KIND_DRONE:
			var at: Vector3 = _dict_to_vec3(entry.get("position", {}), _flagship.position if _flagship else _player_home_pos())
			_spawn_drone_at(at)
			Events.notify.emit("Constructor Drone launched.")
		BUILD_KIND_STRUCTURE:
			var sys := _system_at_index(int(entry.get("system_index", -1)))
			if sys != null and sys.faction == 0 and sys.structure == "":
				sys.set_structure(item)
				if item == "Annihilator":
					_annihilator = sys
					_annih_cd = ANNIHILATOR_COOLDOWN
					Events.notify.emit("%s is online." % _superweapon_name)
				elif item != "Bastion":
					Events.notify.emit("%s built at %s." % [_structure_label(item), sys.system_name])
		BUILD_KIND_DEFENSE:
			var sys := _system_at_index(int(entry.get("system_index", -1)))
			if sys != null and sys.faction == 0:
				_make_defense(0, item, sys.position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
				Events.notify.emit("%s deployed at %s." % [item, sys.system_name])
		BUILD_KIND_STATION:
			var sys := _system_at_index(int(entry.get("system_index", -1)))
			if sys != null and sys.faction == 0 and not sys.has_station(item):
				sys.add_station(item)
				Events.notify.emit("%s online at %s." % [_station_label(item), sys.system_name])
	_update_status()


func _build_ship(ship_name: String) -> void:
	if not SHIPS.has(ship_name):
		return
	var yard := _nearest_shipyard_system(_flagship.position)
	if yard == null:
		Events.notify.emit("Build a Shipyard before producing warships.")
		return
	var spec: Dictionary = SHIPS[ship_name]
	var cost := _ship_cost(ship_name)
	if not _can_afford(cost):
		return
	_pay(cost)
	_enqueue_build({
		"kind": BUILD_KIND_SHIP,
		"item": ship_name,
		"time_left": maxf(2.5, 2.5 + float(spec.get("cost", 0.0)) * 0.45),
		"system_index": _system_index(yard),
	})
	Events.notify.emit("%s queued at %s." % [ship_name, yard.system_name])
	_update_status()


func _build_drone() -> void:
	var cost := _drone_cost()
	if not _can_afford(cost):
		return
	_pay(cost)
	_enqueue_build({
		"kind": BUILD_KIND_DRONE,
		"item": "Drone",
		"time_left": 4.0,
		"position": _vec3_to_dict(_flagship.position),
	})
	Events.notify.emit("Constructor Drone queued.")
	_update_status()


func _spawn_drone_at(at: Vector3) -> void:
	var node := spawn_model(KIT % str(SpaceUnits.DRONE.get("model", "craft_miner")), at, 1.2, 180.0, FACTION_COLORS[0])
	if node == null:
		return
	_stylize_ship(node)
	var max_speed: float = float(SpaceUnits.DRONE.move_speed) * SPACE_SCALE * SHIP_SPEED_SCALE
	var mass: float = ShipPhys.ship_mass(SpaceUnits.DRONE)
	var drone := {
		node = node, faction = 0, kind = "Drone", is_drone = true,
		max_hp = float(SpaceUnits.DRONE.max_hp), hp = float(SpaceUnits.DRONE.max_hp),
		damage = 0.0, range = 0.0, aggro = 0.0,
		speed = max_speed,
		mass = mass,
		velocity = Vector3.ZERO,
		heading = Vector3(0.0, 0.0, 1.0),
		max_accel = ShipPhys.max_accel(max_speed * SHIP_THRUST_PER_SPEED, mass),
		max_turn_rate = ShipPhys.max_turn_rate(mass, SHIP_BASE_TURN_RATE),
		cooldown = 1.0, cd_t = 0.0, attack_kind = "single", splash = 0.0, chain = 1,
		spawns = "", spawn_t = 0.0, bio = false, infected_by = -1, target = null,
		selected = false, command = Vector3.INF,
	}
	_ships.append(drone)
	var hub_spec: Dictionary = SpaceUnits.DEFENSES["HubTurret"]
	drone.hub_cd_t = 0.0
	drone.hub_range = float(hub_spec.attack_range) * SPACE_SCALE
	drone.hub_damage = float(hub_spec.damage)
	drone.hub_cooldown = float(hub_spec.attack_cooldown)


func _tick_drones(_delta: float) -> void:
	for s in _ships:
		if not s.get("is_drone", false):
			continue
		if not is_instance_valid(s.node):
			continue
		if s.hp <= 0.0:
			continue
		var sys: StarSystem3D = _nearest_system(s.node.position, 7.0)
		if sys == null or sys.faction != 0 or sys.structure != "":
			continue
		# A queued structure at this system wins — otherwise the drone insta-builds a
		# SolarCollector and the queued build silently completes into nothing (cost lost).
		if _has_pending_structure(_system_index(sys)):
			continue
		sys.set_structure("SolarCollector")
		s.node.queue_free()
		s.hp = -1.0
		Events.notify.emit("Drone built a Solar Collector at %s." % sys.system_name)


func _tick_hub_defense(delta: float) -> void:
	var hub_spec: Dictionary = SpaceUnits.DEFENSES["HubTurret"]
	var hub_range: float = float(hub_spec.attack_range) * SPACE_SCALE
	var hub_damage: float = float(hub_spec.damage)
	var bolt_color: Color = Color(0.7, 0.9, 1.0)
	# Drone hub defense — drones fire at nearby hostiles instead of being free kills.
	for s in _ships:
		if not _ship_valid(s):
			continue
		if not s.get("is_drone", false):
			continue
		if s.get("hub_cd_t", null) == null:
			continue
		s.hub_cd_t = maxf(0.0, s.hub_cd_t - delta)
		var hostiles: Array = []
		for o in _ships:
			if o.faction == s.faction or not _ship_valid(o) or _allied(s.faction, o.faction):
				continue
			hostiles.append(o)
		var idx := HubDefense.acquire_target(s.node.position, hostiles, hub_range)
		if idx < 0:
			continue
		var target: Dictionary = hostiles[idx]
		if is_instance_valid(s.node):
			var tpos: Vector3 = target.node.position
			_turn_ship_toward(s, Vector3(tpos.x, s.node.position.y, tpos.z) - s.node.position, delta)
		if HubDefense.can_fire(s.hub_cd_t):
			s.hub_cd_t = HubDefense.next_cooldown(hub_spec)
			target.hp -= hub_damage
			_spawn_bolt(s.node.position, target.node.position, bolt_color, 0.1)
	# Mining node hub defense — systems with MiningRig or SolarCollector auto-defend.
	# Untyped Array: keys are ints at runtime, and a typed Array[String] append errors
	# every frame once a mining system is lost (its int key can't be collected).
	var stale_keys: Array = []
	for key in _mining_hub_cd.keys():
		var sys_idx := int(key)
		if sys_idx < 0 or sys_idx >= _systems.size():
			stale_keys.append(key)
			continue
		var sys: StarSystem3D = _systems[sys_idx]
		if sys.faction != 0 or sys.structure not in ["MiningRig", "SolarCollector"]:
			stale_keys.append(key)
	for key in stale_keys:
		_mining_hub_cd.erase(key)
	for sys in _systems:
		if sys.faction != 0:
			continue
		if sys.structure not in ["MiningRig", "SolarCollector"]:
			continue
		var sys_idx := _system_index(sys)
		var cd_t: float = float(_mining_hub_cd.get(sys_idx, 0.0))
		cd_t = maxf(0.0, cd_t - delta)
		var hostiles: Array = []
		for o in _ships:
			if o.faction == 0 or not _ship_valid(o) or _allied(0, o.faction):
				continue
			hostiles.append(o)
		var tgt_idx := HubDefense.acquire_target(sys.position, hostiles, hub_range)
		if tgt_idx < 0:
			_mining_hub_cd[sys_idx] = cd_t
			continue
		var target: Dictionary = hostiles[tgt_idx]
		if HubDefense.can_fire(cd_t):
			cd_t = HubDefense.next_cooldown(hub_spec)
			target.hp -= hub_damage
			_spawn_bolt(sys.position, target.node.position, bolt_color, 0.1)
			# Mining rig fires its own low-key beam (separate SFX from capital-ship lasers).
			if sys.structure == "MiningRig":
				AudioManager.play_sfx("space_mining_beam")
		_mining_hub_cd[sys_idx] = cd_t


# --- Structures (flagship parked on your system) ---------------------------------------------
func _parked_owned_system() -> StarSystem3D:
	var here := _nearest_system(_flagship.position, CAPTURE_RADIUS)
	if here != null and here.faction == 0:
		return here
	return null


func _nearest_shipyard_system(from: Vector3) -> StarSystem3D:
	var best: StarSystem3D = null
	var best_dist := INF
	for s in _systems:
		if s.faction != 0 or not s.has_shipyard:
			continue
		var dist := from.distance_squared_to(s.position)
		if dist < best_dist:
			best_dist = dist
			best = s
	return best


func _structure_min_age(kind: String) -> int:
	if not STRUCTURES.has(kind):
		return 0
	return int(STRUCTURES[kind].get("min_age", 0))


func _structure_age_ok(sys: StarSystem3D, kind: String) -> bool:
	return sys != null and sys.evo_stage >= _structure_min_age(kind)


func _structure_age_label(age: int) -> String:
	return StarSystem3D.EVO_NAMES[clampi(age, 0, StarSystem3D.EVO_NAMES.size() - 1)]


func _structure_label(kind: String) -> String:
	if kind == "Annihilator":
		return _superweapon_name
	var labels := {
		"SolarCollector": "Solar Collector",
		"ResearchLab": "Research Lab",
		"HabitatRing": "Habitat Ring",
		"MiningRig": "Mining Rig",
		"JumpGate": "Jump Gate",
	}
	return str(labels.get(kind, kind))


func _build_structure(kind: String) -> void:
	if not STRUCTURES.has(kind):
		return
	# The superweapon is unique across the WHOLE galaxy: check completed structures AND
	# pending builds at every system, not just _annihilator / this parked system — queuing
	# at a second system inside the first's build window used to buy two for one working unit.
	if kind == "Annihilator" and _annihilator_exists_anywhere():
		Events.notify.emit("%s already exists." % _superweapon_name)
		return
	var sys := _parked_owned_system()
	if sys == null or sys.structure != "":
		return
	if not _structure_age_ok(sys, kind):
		Events.notify.emit("%s needs a %s-era system." % [_structure_label(kind), _structure_age_label(_structure_min_age(kind))])
		return
	var system_index := _system_index(sys)
	if _has_pending_structure(system_index):
		return
	var cost := _structure_cost(kind)
	if not _can_afford(cost):
		return
	_pay(cost)
	_enqueue_build({
		"kind": BUILD_KIND_STRUCTURE,
		"item": kind,
		"time_left": maxf(5.0, 4.0 + float(STRUCTURES[kind].cost) * 0.5),
		"system_index": system_index,
	})
	Events.notify.emit("%s queued at %s." % [_structure_label(kind), sys.system_name])
	_update_status()


# Build an immobile defensive turret at the system the flagship is parked on.
func _build_defense(kind: String) -> void:
	if not SpaceUnits.DEFENSES.has(kind):
		return
	var sys := _parked_owned_system()
	if sys == null:
		return
	var cost := _defense_cost(kind)
	if not _can_afford(cost):
		return
	_pay(cost)
	_enqueue_build({
		"kind": BUILD_KIND_DEFENSE,
		"item": kind,
		"time_left": maxf(3.0, 3.0 + float(SpaceUnits.DEFENSES[kind].cost) * 0.35),
		"system_index": _system_index(sys),
	})
	Events.notify.emit("%s queued at %s." % [kind, sys.system_name])
	_update_status()


# Queue a station build (refinery / sensor_array / outpost / etc.) at the
# system the flagship is parked on. Stations are ADDITIVE to `sys.structure` — a
# system can hold a Shipyard and a refinery at the same time. Build time + cost +
# min_tier come from StationStats.STATIONS; we route through the shared queue so
# build progress shows up in the status readout like everything else.
func _build_station(kind: String) -> void:
	if not StatStats.has_station(kind):
		return
	var sys := _parked_owned_system()
	if sys == null:
		Events.notify.emit("Park on your system to build a station.")
		return
	if sys.has_station(kind):
		Events.notify.emit("%s already built at %s." % [_station_label(kind), sys.system_name])
		return
	var system_index := _system_index(sys)
	if _has_pending_station(system_index, kind):
		Events.notify.emit("%s already building at %s." % [_station_label(kind), sys.system_name])
		return
	if not _station_tier_ok(sys, kind):
		var tier: int = sys.evo_stage
		Events.notify.emit("%s needs tier %d (this system is tier %d)." % [_station_label(kind), _station_min_tier(kind), tier])
		return
	var cost := _station_cost(kind)
	if not _can_afford(cost):
		return
	_pay(cost)
	var build_time: float = float(StatStats.get_station(kind).get("build_time", 30.0))
	_enqueue_build({
		"kind": BUILD_KIND_STATION,
		"item": kind,
		"time_left": build_time,
		"system_index": system_index,
	})
	Events.notify.emit("%s queued at %s." % [_station_label(kind), sys.system_name])
	_update_status()


# Pretty-print a station id. Mirrors _structure_label for the additive stations.
func _station_label(kind: String) -> String:
	var labels := {
		"outpost": "Outpost",
		"refinery": "Refinery",
		"sensor_array": "Sensor Array",
		"shipyard": "Shipyard Station",
		"defense_grid": "Defense Grid",
	}
	return str(labels.get(kind, kind))


# Tooltip line for a station: its role, plus what a refinery actually converts.
func _station_blurb(kind: String) -> String:
	var role := str(StatStats.get_station(kind).get("role", ""))
	if kind != STATION_REFINERY:
		return role
	return "%s · refines up to %d water/s → metal and %d biomass/s → energy (%d%% yield)" % [
		role, int(EconomyModel.REFINERY_RATE["water"]), int(EconomyModel.REFINERY_RATE["biomass"]),
		int(EconomyModel.REFINERY_YIELD * 100.0)]


# Helper: pull the min_tier out of StationStats for a station id, 99 if unknown
# (so the build button is disabled rather than a free pass).
func _station_min_tier(kind: String) -> int:
	var spec: Dictionary = StatStats.get_station(kind)
	if spec.is_empty():
		return 99
	return int(spec.get("min_tier", 1))


# --- Diplomacy (light): buy galaxy-wide ceasefire; AI offers are per-empire -----------------
func _truce_active() -> bool:
	return _elapsed < _truce_until


func _player_at_peace_with(fac: int) -> bool:
	if fac == 0 or fac == COLLECTIVE_FAC:
		return false
	if _truce_active():
		return true
	return _elapsed < float(_at_peace.get(fac, 0.0))


func _offer_truce() -> void:
	var cost := _truce_cost()
	if _truce_active() or not _can_afford(cost):
		return
	_pay(cost)
	_truce_until = _elapsed + TRUCE_DURATION
	Events.notify.emit("☮ Ceasefire bought — all empires stand down for %ds." % int(TRUCE_DURATION))


# --- Fleet upgrades --------------------------------------------------------------------------
func _upgrade_cost(tier: int) -> float:
	var lab_discount := maxf(0.65, 1.0 - _structure_count("ResearchLab") * 0.10)
	return UPGRADE_BASE_COST * (tier + 1) * lab_discount


func _buy_weapon_upgrade() -> void:
	var c := _upgrade_cost_dict(_weapon_tier)
	if not _can_afford(c):
		return
	_pay(c)
	_weapon_tier += 1
	Events.notify.emit("Fleet Weapons upgraded → +%d" % _weapon_tier)


func _buy_armor_upgrade() -> void:
	var c := _upgrade_cost_dict(_armor_tier)
	if not _can_afford(c):
		return
	_pay(c)
	_armor_tier += 1
	Events.notify.emit("Fleet Armor upgraded → +%d" % _armor_tier)


# --- Carry-over: the Civ army ascends as starting fleet power --------------------------------
const CIV_TO_SPACE := {
	"Soldier": "Fighter", "Archer": "Bomber", "Rifleman": "Cruiser",
	"LaserTank": "Battleship", "Drone": "Fighter",
	"TeslaTrooper": "ArcFrigate", "PrismTank": "PrismCruiser",
}


func _emit_space_open_brief() -> void:
	Events.notify.emit(GenomeBonus.space_brief())
	StageObjectives.complete("space_enter", "Entered the void — claim systems, build fleets")


func _ascend_civ_army() -> void:
	_weapon_tier = EvolutionState.civ_weapon_tier
	_armor_tier = EvolutionState.civ_armor_tier
	var roster: Dictionary = EvolutionState.civ_army_roster
	if roster.is_empty():
		return
	var lines: Array = []
	for civ_type in roster:
		var n: int = int(roster[civ_type])
		if n <= 0:
			continue
		var ship_name: String = CIV_TO_SPACE.get(civ_type, "Fighter")
		var base: Vector3 = _flagship.position if _flagship else _player_home_pos()
		var launched: int = mini(n, 6)   # cap the visible escort swarm
		for i in launched:
			_make_ship(0, ship_name, base + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
		lines.append("%d %s → %d %s" % [n, civ_type, launched, ship_name])
	if not lines.is_empty():
		Events.notify.emit("Your army ascends to the stars: " + ", ".join(lines))
		StageObjectives.complete("space_army", "Civ army ascended as escort fleet")


# --- Empire helpers --------------------------------------------------------------------------
func _empire_nearest_to(pos: Vector3) -> StarSystem3D:
	var best: StarSystem3D = null
	var bd := INF
	for s in _systems:
		if s.faction == 0:
			continue
		var d := pos.distance_squared_to(s.position)
		if d < bd:
			bd = d
			best = s
	return best


func _empire_pick_target(fac: int) -> StarSystem3D:
	var owned := _owned_systems(fac)
	if owned.is_empty():
		return null
	var best_neutral: StarSystem3D = null
	var best_enemy: StarSystem3D = null
	var bn := INF

	# Compute max rival strength so enemy targets are scored by
	# distance + threat weight — biases toward the strongest rival's systems.
	var max_rival_str: float = 0.0
	for rival_fac: int in _empires.keys():
		if rival_fac == fac:
			continue
		max_rival_str = maxf(max_rival_str, _faction_strength(rival_fac))
	var player_str: float = _faction_strength(0)
	if not _player_at_peace_with(fac):
		max_rival_str = maxf(max_rival_str, player_str)

	var best_enemy_score := -INF
	for s in _systems:
		if s.faction == fac:
			continue
		var d := _nearest_dist(s.position, owned)
		if s.faction < 0:
			if d < bn:
				bn = d
				best_neutral = s
		else:
			if s.faction == 0 and _player_at_peace_with(fac):
				continue
			var owner_str: float = _faction_strength(s.faction)
			var score: float = GSim.score_enemy_target(d, owner_str, max_rival_str)
			if score > best_enemy_score:
				best_enemy_score = score
				best_enemy = s
	return best_neutral if best_neutral != null else best_enemy


func _faction_color(fac: int) -> Color:
	if fac == 0:
		return FACTION_COLORS[0]
	if fac >= 1 and fac <= _rival_themes.size():
		return _rival_themes[fac - 1].color
	return Color.from_hsv(fmod(fac * 0.137, 1.0), 0.55, 1.0)


func _faction_name(fac: int) -> String:
	if fac == 0:
		return "You"
	# Empires that emerged mid-game carry their own ascension name.
	if _empires.has(fac):
		var nm: String = str((_empires[fac] as Dictionary).get("name", ""))
		if nm != "":
			return nm
	if fac >= 1 and fac <= _rival_themes.size():
		return str(_rival_themes[fac - 1].name)
	return "Empire %d" % fac


func _build_rival_themes() -> void:
	for row in Genome.LINEAGES.values():
		if row.has("civ_archetype"):
			var a: Dictionary = row.civ_archetype
			_rival_themes.append({color = a.tint, name = Genome.archetype_label(str(a.archetype))})


func _emerge_empire(sys: StarSystem3D) -> void:
	var fac := EMPIRE_COUNT
	for k in _empires:
		fac = maxi(fac, k)
	fac += 1
	var nm: String = EMERGENT_NAMES[maxi(0, fac - EMPIRE_COUNT - 1) % EMERGENT_NAMES.size()]
	# A newborn empire starts with a small war-chest so it can act before its economy ramps.
	_empires[fac] = {timer = EMPIRE_EXPAND_BASE, treasury = 60.0, tech = 0.0, peak = 1.0, name = nm, collapsed = false}
	sys.emergent_ready = false
	sys.set_faction(fac, _faction_color(fac))
	_log_galaxy("✦ %s ascended to spacefaring at %s." % [nm, sys.system_name])


func _check_endgame() -> void:
	if _done:
		return
	var total := _systems.size()
	var player := _count_owned(0)
	if player >= total and total > 0:
		_done = true
		Events.notify.emit("★ Galaxy conquered — every system flies your colors.")
		AudioManager.play_sfx("win")
		Events.stage_complete.emit(EvolutionState.current_stage)
	elif player == 0:
		_done = true
		Events.game_lost.emit("Your empire was driven from the galaxy.")


func _nearest_system(from: Vector3, radius: float) -> StarSystem3D:
	var best: StarSystem3D = null
	var bd := radius * radius
	for s in _systems:
		var d := from.distance_squared_to(s.position)
		if d < bd:
			bd = d
			best = s
	return best


func _owned_systems(fac: int) -> Array[StarSystem3D]:
	var out: Array[StarSystem3D] = []
	for s in _systems:
		if s.faction == fac:
			out.append(s)
	return out


func _count_owned(fac: int) -> int:
	var n := 0
	for s in _systems:
		if s.faction == fac:
			n += 1
	return n


func _nearest_dist(from: Vector3, group: Array[StarSystem3D]) -> float:
	var best := INF
	for s in group:
		var d := from.distance_to(s.position)
		if d < best:
			best = d
	return best


# --- Contained HUD (anchored, fixed-width, no-scroll — tabbed build panel) -------------------
# UI-BUYMENU-REDESIGN: a tabbed build panel (Fleet / Build / Defenses / Upgrades / Save) holds all
# the buttons that used to live in a single long ScrollContainer. Each tab is a 2-column
# GridContainer so the longest tab (Fleet, 9 items) still fits inside the side panel at 1920×1080
# with no scrollbar. _update_status still owns the enable/disable logic + button text + tooltip
# text — this is a pure layout refactor (callbacks + logic untouched).
func _build_ui() -> void:
	# Same CompactHUD + StageChrome language as Creature/Tribe/Civ (left edge, collapsible).
	var ui := StageChromeScript.make_layer(self)
	var panel = CompactHUD.new()
	panel.configure("SPACE", StageChromeScript.PANEL_WIDTH_RTS, false)
	panel.tooltip_text = "WASD fly · park to capture · own every system to win."
	ui.add_child(panel)

	var root: VBoxContainer = panel.content
	root.add_child(StageChromeScript.identity_row(64))
	root.add_child(StageChromeScript.h_sep())
	_stat_strip = StatStripScript.new()
	root.add_child(_stat_strip)
	_status = StageChromeScript.status_label()
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(_status)

	var tabs := BuildTabs.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	var fleet_grid := _make_build_grid()
	tabs.add_tab("Fleet", fleet_grid)
	for ship_name in SHIPS:
		var spec: Dictionary = SHIPS[ship_name]
		var btn := _make_build_button("Build %s (%s)" % [ship_name, _format_cost(_ship_cost(ship_name))],
			"%s\nCost %s · HP %d · DMG %d · %s" % [ship_name, _format_cost(_ship_cost(ship_name)), int(spec.max_hp), int(spec.damage), str(spec.get("attack_kind", "single"))],
			_build_ship.bind(ship_name))
		fleet_grid.add_child(btn)
		_ship_btns.append(btn)
	_drone_btn = _make_build_button("Drone (%s)" % _format_cost(_drone_cost()),
		"Constructor Drone — builds structures on your system",
		_build_drone)
	fleet_grid.add_child(_drone_btn)
	fleet_grid.add_child(_make_build_button("⚔ Fleet Battle (B)",
		"Drop into a full tactical fleet battle vs nearby hostiles",
		func() -> void: _try_open_space_battle()))

	var build_grid := _make_build_grid()
	tabs.add_tab("Build", build_grid)
	for kind in STRUCTURES:
		var label: String = _structure_label(kind)
		var btn := _make_build_button("Build %s (%s)" % [label, _format_cost(_structure_cost(kind))],
			"%s\nCost %s · Requires %s era\n%s" % [
				label,
				_format_cost(_structure_cost(kind)),
				_structure_age_label(_structure_min_age(kind)),
				str(STRUCTURES[kind].get("role", "")),
			],
			_build_structure.bind(kind))
		build_grid.add_child(btn)
		_struct_btns.append(btn)

	var defense_grid := _make_build_grid()
	tabs.add_tab("Defenses", defense_grid)
	for kind in SpaceUnits.DEFENSES:
		if kind == "HubTurret":
			continue   # internal auto-defense (cost 0) — never player-buildable
		var dbtn := _make_build_button("Build %s (%s)" % [kind, _format_cost(_defense_cost(kind))],
			"%s — immobile turret · costs %s" % [kind, _format_cost(_defense_cost(kind))],
			_build_defense.bind(kind))
		defense_grid.add_child(dbtn)
		_defense_btns.append(dbtn)
	# Additive stations (refinery / sensor_array / etc.) live in the Defenses tab
	# because they're all "park on your system" buildables gated by tier + cost + parked. Mirrors
	# the old single-VBox structure; just rolled into a shared 2-col grid so it fits on one page.
	for kind in StatStats.STATIONS:
		var sbtn := _make_build_button("Build %s (%s)" % [_station_label(kind), _format_cost(_station_cost(kind))],
			"%s\nCost %s · Build time %.0fs · Min tier %d\n%s" % [
				_station_label(kind),
				_format_cost(_station_cost(kind)),
				float(StatStats.get_station(kind).get("build_time", 30.0)),
				_station_min_tier(kind),
				_station_blurb(kind),
			],
			_build_station.bind(kind))
		defense_grid.add_child(sbtn)
		_station_btns.append(sbtn)

	var upgrade_grid := _make_build_grid()
	tabs.add_tab("Upgrades", upgrade_grid)
	var wbtn := _make_build_button("Weapons +N", "Buy the next weapon tier (dmg +15% per tier)", _buy_weapon_upgrade)
	upgrade_grid.add_child(wbtn)
	var abtn := _make_build_button("Armor +N", "Buy the next armor tier (HP +15% per tier)", _buy_armor_upgrade)
	upgrade_grid.add_child(abtn)
	_upgrade_btns = [wbtn, abtn]
	_truce_btn = _make_build_button("☮ Ceasefire", "Buy a temporary ceasefire with all rival empires", _offer_truce)
	upgrade_grid.add_child(_truce_btn)
	var home_btn := _make_build_button("⌂ Homeworld", "Open the 3D homeworld overlay (your Civ planet)", _open_homeworld)
	upgrade_grid.add_child(home_btn)

	var save_grid := _make_build_grid()
	tabs.add_tab("Save", save_grid)
	var save_btn := _make_build_button("💾 Save Galaxy",
		"Snapshot the current galaxy (systems, ownership, structures, treasury, fleet power) to user://saves/galaxy_<slot>.json",
		_on_save_galaxy)
	save_grid.add_child(save_btn)
	var load_btn := _make_build_button("📂 Load Galaxy",
		"Restore the galaxy from the saved slot (overwrites current systems in place).",
		_on_load_galaxy)
	save_grid.add_child(load_btn)

	_update_status()


func _make_build_grid() -> GridContainer:
	return StageChromeScript.build_grid(1)


# Compact build button — text is set later by _update_status (so live cost + disabled state work
# exactly as before). Tooltip carries the full details so they don't crowd the button label.
func _make_build_button(initial_text: String, tooltip: String, callback: Callable) -> Button:
	return StageChromeScript.make_button(initial_text, tooltip, callback)


# Open the 3D homeworld overlay (your Civ planet, modern era). Requires a snapshot and still
# owning the home system (or any homeworld record if home was never tagged).
func _open_homeworld() -> void:
	if EvolutionState.civ_planet_snapshot.is_empty():
		Events.notify.emit("No homeworld on record — you ascended without founding cities.")
		return
	if _home_system != null and is_instance_valid(_home_system) and int(_home_system.faction) != 0:
		Events.notify.emit("Home system lost — reclaim it to visit the surface.")
		return
	# Don't stack overlays.
	for c in get_children():
		if c is HomePlanetView:
			return
	var root: Node = StageManager.stage_root() if StageManager != null else null
	var host: Node = root if root != null else self
	host.add_child(HomePlanetView.new())
	StageObjectives.complete("space_homeworld", "Visited the homeworld from orbit")


# P0: galaxy save/load handlers. Snapshot the live stage → write JSON → restore by index
# on load. Defensive: if the save file is missing/corrupt, just notify and continue.
func _on_save_galaxy() -> void:
	var state: Dictionary = GalSave.capture(self)
	if state.is_empty():
		Events.notify.emit("Save failed: nothing to capture.")
		return
	var err: int = GalSave.save_slot(_save_slot, state)
	if err == OK:
		err = SaveManager.save_current()   # the run save title-screen Continue loads
	if err == OK:
		var sys_count: int = int((state.get("systems", []) as Array).size())
		Events.notify.emit("Galaxy saved to slot '%s' (%d systems)." % [_save_slot, sys_count])
	else:
		Events.notify.emit("Save failed (err %d)." % err)


func _on_load_galaxy() -> void:
	if not GalSave.has_slot(_save_slot):
		Events.notify.emit("No save in slot '%s'." % _save_slot)
		return
	var state: Dictionary = GalSave.load_slot(_save_slot)
	if state.is_empty():
		Events.notify.emit("Save file in slot '%s' is empty or corrupt." % _save_slot)
		return
	var ok: bool = GalSave.restore(self, state)
	if ok:
		_rederive_annihilator()
		var sys_count: int = int((state.get("systems", []) as Array).size())
		Events.notify.emit("Galaxy loaded from slot '%s' (%d systems)." % [_save_slot, sys_count])
		_update_status()
	else:
		Events.notify.emit("Load failed: stage rejected the save data.")


func capture() -> Dictionary:
	return GalSave.capture(self)


func restore(data: Dictionary) -> void:
	if GalSave.restore(self, data):
		_rederive_annihilator()
		_update_status()


## Rebuild the saved player fleet + turrets (GalaxySave), replacing the fresh stage's escort.
func _restore_fleet(entries: Array) -> void:
	var kept: Array = []
	for s in _ships:
		if s.faction == 0 and (SpaceUnits.FLEET.has(s.kind) or SpaceUnits.DEFENSES.has(s.kind)):
			if is_instance_valid(s.node):
				s.node.queue_free()
		else:
			kept.append(s)
	_ships = kept
	for e in entries:
		if not (e is Dictionary):
			continue
		var kind := str(e.get("kind", ""))
		var at := Vector3(float(e.get("x", 0.0)), 0.0, float(e.get("z", 0.0)))
		if not at.is_finite():
			continue
		var n := _ships.size()
		if SpaceUnits.FLEET.has(kind):
			_make_ship(0, kind, at)
		elif SpaceUnits.DEFENSES.has(kind):
			_make_defense(0, kind, at)
		if _ships.size() > n:
			var ship: Dictionary = _ships.back()
			var hp := float(e.get("hp", ship.max_hp))
			if is_finite(hp):
				ship.hp = clampf(hp, 1.0, ship.max_hp)


# _annihilator isn't part of the save payload — re-derive it from restored structures
# (or clear it: an older save without the weapon must silence a live beam).
func _rederive_annihilator() -> void:
	_annihilator = null
	for sys in _systems:
		if sys.faction == 0 and sys.structure == "Annihilator":
			_annihilator = sys
			return


func _ensure_capture_meter() -> void:
	if _capture_meter != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 12
	layer.name = "CaptureMeterLayer"
	add_child(layer)
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	wrap.offset_left = -180
	wrap.offset_right = 180
	wrap.offset_top = -110
	wrap.offset_bottom = -58
	wrap.add_theme_constant_override("separation", 4)
	layer.add_child(wrap)
	_capture_meter_label = StageChromeScript.hint_label("Capturing…")
	_capture_meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(_capture_meter_label)
	_capture_meter = ProgressBar.new()
	_capture_meter.min_value = 0.0
	_capture_meter.max_value = 1.0
	_capture_meter.show_percentage = false
	_capture_meter.custom_minimum_size = Vector2(360, 14)
	StageChromeScript.style_progress(_capture_meter, Color(0.35, 0.9, 1.0))
	wrap.add_child(_capture_meter)
	wrap.visible = false
	_capture_meter.set_meta("wrap", wrap)


func _update_capture_meter() -> void:
	_ensure_capture_meter()
	var wrap: Control = _capture_meter.get_meta("wrap") if _capture_meter != null else null
	if wrap == null or _flagship == null:
		return
	var here: StarSystem3D = _nearest_system(_flagship.position, CAPTURE_RADIUS)
	var capturing: bool = here != null and int(here.faction) != 0 and float(here.capture) > 0.02
	wrap.visible = capturing
	if not capturing:
		return
	var frac: float = clampf(float(here.capture), 0.0, 1.0)
	_capture_meter.value = frac
	var owner: String = "neutral" if int(here.faction) < 0 else _faction_name(int(here.faction))
	_capture_meter_label.text = "Capturing %s (%s)  %d%%  · hold position" % [
		here.system_name, owner, int(round(frac * 100.0))]


func _update_status() -> void:
	if _status == null:
		return
	var annih := ("  ⚠ %s ONLINE" % _superweapon_name.to_upper()) if _annihilator != null else ""
	# Resource chips across the top (AoE-style) — replaces the old Treasury/Credits/Systems text block.
	if _stat_strip != null:
		_stat_strip.begin()
		var inc := _galaxy_income()
		var refineries := _refinery_count()
		var refine_tip := (" · %d refinery converting it" % refineries) if refineries > 0 else " · build a Refinery to convert it"
		_stat_strip.set_chip("metal", "◆", "%d" % int(_treasury.get("metal", 0.0)), Color(0.80, 0.84, 0.92), "Metal  (%+.1f/s)" % float(inc.get("metal", 0.0)))
		_stat_strip.set_chip("energy", "⚡", "%d" % int(_treasury.get("energy", 0.0)), Color(0.65, 0.88, 1.0), "Energy  (%+.1f/s)" % float(inc.get("energy", 0.0)))
		_stat_strip.set_chip("water", "●", "%d" % int(_treasury.get("water", 0.0)), Color(0.45, 0.72, 1.0), "Water  (%+.1f/s) → metal%s" % [float(inc.get("water", 0.0)), refine_tip])
		_stat_strip.set_chip("biomass", "▲", "%d" % int(_treasury.get("biomass", 0.0)), Color(0.60, 0.95, 0.55), "Biomass  (%+.1f/s) → energy%s" % [float(inc.get("biomass", 0.0)), refine_tip])
		_stat_strip.set_chip("systems", "★", "%d/%d" % [_count_owned(0), _systems.size()], Color(1.0, 0.95, 0.60), "Systems owned / total in the galaxy")
		_stat_strip.prune()
	var lines := "Fleet %.0f%s" % [_fleet_power(), annih]
	if not _build_queue.is_empty():
		var entry: Dictionary = _build_queue[0]
		lines += " · %s %ds" % [
			str(entry.get("item", entry.get("kind", "?"))),
			int(ceil(float(entry.get("time_left", 0.0)))),
		]
	var scan := _nearest_system(_flagship.position, 18.0) if _flagship else null
	if scan != null:
		var scan_struct := "empty" if scan.structure == "" else _structure_label(scan.structure)
		lines += "\n%s · %s · %s" % [scan.system_name, scan.evo_name().to_lower(), scan_struct]
		if scan.faction < 0 and scan.evo_stage < 4:
			lines += " (%d%%)" % int(round(scan.evo_progress * 100.0))
	_update_capture_meter()
	var tip_bits: PackedStringArray = []
	if _structure_count("ResearchLab") > 0:
		tip_bits.append("research x%.2f" % _research_mult())
	if _structure_count("HabitatRing") > 0:
		tip_bits.append("habitat +%.1f" % (_structure_count("HabitatRing") * 1.5))
	if _structure_count("JumpGate") > 0:
		tip_bits.append("jump x%.2f" % _movement_mult(0))
	if not _galaxy_log.is_empty():
		tip_bits.append(_galaxy_log[_galaxy_log.size() - 1])
	_status.tooltip_text = " · ".join(tip_bits) if not tip_bits.is_empty() else "Park on a system to capture it"
	_status.text = lines

	var has_shipyard := _nearest_shipyard_system(_flagship.position) != null
	for i in _ship_btns.size():
		var nm: String = SHIPS.keys()[i]
		_ship_btns[i].disabled = not has_shipyard or not _can_afford(_ship_cost(nm))
	if _drone_btn:
		_drone_btn.disabled = not _can_afford(_drone_cost())
	var parked := _parked_owned_system()
	var can_here := parked != null and parked.structure == ""
	for i in _struct_btns.size():
		var kind: String = STRUCTURES.keys()[i]
		var system_index := _system_index(parked) if parked != null else -1
		var ok := can_here and not _has_pending_structure(system_index) and _can_afford(_structure_cost(kind)) and _structure_age_ok(parked, kind)
		if kind == "Annihilator" and _annihilator != null:
			ok = false
		_struct_btns[i].disabled = not ok
	for i in _defense_btns.size():
		var kind: String = SpaceUnits.DEFENSES.keys()[i]
		_defense_btns[i].disabled = parked == null or not _can_afford(_defense_cost(kind))
	# Station build buttons. Each is gated by: parked on an owned system
	# + station not already present + no pending build of the same kind + tier ok +
	# can afford. Mirrors _struct_btns gate logic so behaviour is consistent.
	for i in _station_btns.size():
		var kind: String = StatStats.STATIONS.keys()[i]
		var system_index := _system_index(parked) if parked != null else -1
		var station_ok := parked != null \
			and not parked.has_station(kind) \
			and not _has_pending_station(system_index, kind) \
			and _station_tier_ok(parked, kind) \
			and _can_afford(_station_cost(kind))
		_station_btns[i].disabled = not station_ok
	if _upgrade_btns.size() == 2:
		_upgrade_btns[0].text = "Weapons +%d (%s)" % [_weapon_tier + 1, _format_cost(_upgrade_cost_dict(_weapon_tier))]
		_upgrade_btns[1].text = "Armor +%d (%s)" % [_armor_tier + 1, _format_cost(_upgrade_cost_dict(_armor_tier))]
		_upgrade_btns[0].disabled = not _can_afford(_upgrade_cost_dict(_weapon_tier))
		_upgrade_btns[1].disabled = not _can_afford(_upgrade_cost_dict(_armor_tier))
	if _truce_btn:
		if _truce_active():
			_truce_btn.text = "Galaxy ceasefire (%ds)" % int(_truce_until - _elapsed)
			_truce_btn.disabled = true
		else:
			var bilateral := 0
			for fac in _at_peace.keys():
				if _elapsed < float(_at_peace[fac]):
					bilateral += 1
			var bil_bit := " · %d treaty" % bilateral if bilateral > 0 else ""
			_truce_btn.text = "☮ Galaxy Ceasefire (%s)%s" % [_format_cost(_truce_cost()), bil_bit]
			_truce_btn.disabled = not _can_afford(_truce_cost())
