class_name CivStage3D extends Stage3D

const CITIZEN_NEEDS_MODEL := preload("res://src/stages/civ/CitizenNeedsModel.gd")
const PRODUCTION_CHAIN_MODEL := preload("res://src/stages/civ/ProductionChainModel.gd")
const CLIMATE_MODEL := preload("res://src/stages/civ/ClimateModel.gd")
const RIVAL_AI_MODEL := preload("res://src/stages/civ/RivalAIModel.gd")
const CompactHUD := preload("res://src/ui/CompactHUDPanel.gd")
const StatStripScript := preload("res://src/ui/StatStrip.gd")
const StageChromeScript := preload("res://src/ui/StageChrome.gd")
const TacticalBattleScene := preload("res://src/common/TacticalBattle.tscn")
# Cohesion: Civ rivals decide with the SAME weighted-archetype brain as Space empires
# (EmpireAI). Civ keeps its own economy bookkeeping (RivalAIModel.next_state) + army-centric
# combat; only the decision is shared. Thresholds are Civ-scale (rival "gold" is small).
const EMPIRE_AI := preload("res://src/stages/space/EmpireAI.gd")
const RIVAL_EXPAND_BASE := 32.0
const RIVAL_EXPAND_PER_CITY := 16.0
# UI-BUYMENU-REDESIGN: tabbed build panel — Workers / Buildings / Units / Defense / Upgrades.
# Pure layout (no game logic / no callbacks). _update_status still owns enable/disable + text.
const BUILD_PANEL_SIZE := Vector2(380, 0)
## Tactical ortho size — 96 is strategic and hides the starting settler in empty hex.
const CAMERA_SIZE := 44.0

const TD := "res://assets/models/kenney-tower-defense/%s.glb"
const NAT := "res://assets/models/kenney-nature/%s.glb"

const COLS := 56
const ROWS := 40
const TILE_3D := 6.0
# Kenney hexagon tiles (assets/models/kenney-hexagon) are POINTY-TOP hexes whose raw
# mesh footprint is x=1.0 (flat-to-flat) by z=1.1547 (point-to-point). _ground_tile fits
# the larger dim (z) to TILE_3D*1.04, so the rendered footprint — and the tessellation
# pitches derived from it — are:
const HEX_POINT := TILE_3D * 1.04          # rendered point-to-point span (world +z)
const HEX_FLAT := HEX_POINT / 1.1547       # rendered flat-to-flat span (world +x)
const HEX_COL_STEP := HEX_FLAT             # pointy-top column pitch = flat-to-flat width
const HEX_ROW_STEP := HEX_POINT * 0.75     # pointy-top row pitch = 3/4 of point-to-point
const WIN_CITY_COUNT := 3
## Rival nations that must be eliminated (every city razed) before Launch to Space unlocks.
const WIN_RIVALS_BEATEN := 1
## Hit points of a city center (player or rival). Cities are real, destructible targets:
## sustained siege razes them — a razed player city stops producing (and can cost the run);
## razing every rival city is the conquest victory.
const CITY_MAX_HP := 500.0
## Food cost of training a Settler (founds a new city; one active settler at a time).
const SETTLER_COST := 12
## First city of a run gets a free production kick so early expansion isn't a dead wait.
const FOUNDING_PROD_BONUS := 2
# Player units now spawn as the rigged advanced species mesh (norm-scaled to ~1 unit tall), so they
# need an explicit body height to match the old Kenney tile-fit size. See [[primordia-rts-animations]].
const UNIT_BODY_HEIGHT := 2.5
# Buildings normalize to a deliberate RTS readability ratio instead of inheriting source-model size.
const BUILDING_TARGET_HEIGHT := 7.0
const BUILDING_MAX_FOOTPRINT_TILES := 1.3
# Buildings all face one way (entrance toward the viewer) instead of random yaw, which read chaotic.
# Tunable once the camera/orientation convention is locked from the art-direction research.
const BUILDING_FACE_YAW := 180.0
const BUILDING_FACE_JITTER := 8.0
# A town spreads over the hexes round its capital: the hexes touching the capital stay open,
# props keep to one ring further out and buildings take the rest.
const TOWN_PLAZA := 1.1          # hex steps round the capital kept clear for its road and new units
const TOWN_REACH := 3.1          # how far a town may spread, in hex steps from the capital
const TOWN_DECOR_RING := 2.0     # the ring of hexes left to props, in hex steps from the capital
const SPAWN_REACH := 6           # how far out, in hexes, a new unit looks for open ground
const TOWN_DECOR_JITTER := 1.0   # how far a prop may sit from the middle of its hex

enum Terrain { WATER, LAND, MOUNTAIN }

# --- MAP DRESSING TUNABLES (RTS map feel) -----------------------------------------------------
# Water: one continuous sheet under the whole map, sitting just below the grass plane so land
# reads as raised above it. Tweak color via the shader uniforms below.
const WATER_LEVEL := -0.35              # Y of the single water plane (below the grass at -0.02)
const HEX_UNDERLAY_LEVEL := -0.08       # Y of the plane that closes the seams under the hex board
const HEX_WATER_LEVEL := 0.06           # Y of the water over the hex board: above the underlay, below the land tops
const HEX_WATER_ROCKS_RAISE := -0.10    # sinks a rocky water tile just far enough to leave its rocks above the water
const WATER_SHALLOW := Color(0.20, 0.52, 0.62)
const WATER_DEEP := Color(0.04, 0.16, 0.30)
# Forests: instead of uniform per-cell scatter, grow a handful of contiguous belts/clumps that act
# as natural walls/chokepoints. Each belt is a random walk of tree-cells; trees block their cell so
# units must route around them. Open clearings are reserved around spawns so nothing is walled off.
const FOREST_BELTS := 5                 # number of contiguous forest clumps grown across the map
const FOREST_BELT_STEPS := 15           # cells per belt (belt length)
const FOREST_BELT_WIDTH := 0            # half-width: 0 = single-cell line, 1 = 3-cell-wide belt
const FOREST_TREES_PER_CELL := 2        # trees packed into each forested cell (dense canopy)
const FOREST_CLEAR_RADIUS := 5          # cells around each city/settler kept tree-free (clearings)
const START_CLEAR_RADIUS := 2           # cells around each start kept free of lone trees and rocks
const FOREST_GAP_EVERY := 7             # leave a 1-cell gap every Nth belt step so belts stay porous
const FOREST_CROSS_LANE_BIAS := 0.72    # chance random belts run E/W across the N-S base approaches
const MIDFIELD_CLEAR_RADIUS := 5         # keep the center open for the decisive fight/resource contest
const MIRRORED_RIVAL_SPACING := 13       # horizontal spacing around the mirrored player main
const HOME_CHOKE_DISTANCE := FOREST_CLEAR_RADIUS + 2
const HOME_CHOKE_HALF_WIDTH := 8
const HOME_CHOKE_GAP_HALF_WIDTH := 0     # 0 = one-cell entrance gap
const EXPOSED_EXPANSION_DISTANCE := FOREST_CLEAR_RADIUS + 4
const EXPANSION_TREE_CELLS := 3
const EXPANSION_BERRY_BUSHES := 4
# Berry patches: clustered, obviously-fruiting bushes so FOOD is visible on the map.
const BERRY_PATCHES := 7                # number of distinct berry clusters
const BERRY_BUSHES_PER_PATCH := 5       # bushes per patch
const BERRY_PATCH_RADIUS := 7.0         # world-units spread of a patch around its center
const MIDFIELD_BERRY_BUSHES := 5
const MIDFIELD_STONE_ROCKS := 3
# Loose ambient scatter on open land (sparse — the belts carry the forest mass now).
const SCATTER_TREE_CHANCE := 0.01       # lone trees outside belts (open grassland flavor)
const SCATTER_ROCK_CHANCE := 0.05
const SCATTER_GROUNDCOVER_MIN := 1
const SCATTER_GROUNDCOVER_MAX := 2
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const TECHS := [
	{"name": "Agriculture", "cost": 30, "effect": "production", "value": 1},
	{"name": "Metalworking", "cost": 70, "effect": "defense", "value": 1},
	{"name": "Architecture", "cost": 140, "effect": "population", "value": 2},
	{"name": "Engineering", "cost": 260, "effect": "production", "value": 2},
	{"name": "Computing", "cost": 420, "effect": "production", "value": 2},
]

const AGES := ["Stone", "Bronze", "Iron", "Industrial", "Modern", "Near-Future"]
# Civ is meant to be the longest stage. Each age also needs its tech (TECHS[age] before age + 1).
# Sized against compounding city production (+1/city per age, production techs) and
# ECONOMY_PACE: the bot's spaceflight win lands around 25-35 game-minutes.
const AGE_COST := [0, 180, 400, 750, 1300, 2000]
const WORKER_YIELD := 0.42
## Pace of all player income (cities, workers, granary). At 1.0 a fresh capital paid for a
## worker every ~1 s and three cities were up in ~20 s. 0.16 stretches the stage to ~30 min.
const ECONOMY_PACE := 0.16
const WORKER_COST := 4
const WORKER_SPEED := 4.0
const WORKER_GATHER_TIME := 2.5   # seconds spent playing the gather clip at a node before hauling back

const RES := ["food", "wood", "stone"]
const BUILD_TIME := 7.0

const BUILDINGS := {
	"House":    {cost = {wood = 3},            effect = "popcap",    value = 5,   tint = Color(0.85,0.8,0.6)},
	"Granary":  {cost = {wood = 2, stone = 1}, effect = "food_rate", value = 1.0, tint = Color(0.5,0.85,0.4)},
	"Barracks": {cost = {wood = 4, stone = 3}, effect = "military",   value = 1,   tint = Color(0.8,0.4,0.4)},
	"Spaceport": {cost = {wood = 8, stone = 8}, effect = "spaceport", value = 0, tint = Color(0.6,0.9,1.0), min_age = 5},
}

const UNITS := {
	"Soldier": {cost = {wood = 2},            min_age = 0, max_hp = 30.0, damage = 6.0, attack_range = 3.5, attack_cooldown = 1.0, move_speed = 6.0},
	"Archer":  {cost = {wood = 1, stone = 1}, min_age = 0, max_hp = 18.0, damage = 4.0, attack_range = 15.0, attack_cooldown = 1.2, move_speed = 5.5},
	"Spearman":     {cost = {wood = 2, stone = 1}, min_age = 1, max_hp = 38, damage = 7,  attack_range = 4.0, attack_cooldown = 1.0, move_speed = 6},
	"Swordsman":    {cost = {wood = 3, stone = 2}, min_age = 2, max_hp = 48, damage = 9,  attack_range = 3.5, attack_cooldown = 1.0, move_speed = 6},
	"Rifleman":     {cost = {wood = 2, stone = 1}, min_age = 3, max_hp = 26, damage = 7,  attack_range = 18, attack_cooldown = 1.0, move_speed = 6},
	"LaserTank":    {cost = {wood = 4, stone = 4}, min_age = 4, max_hp = 70, damage = 14, attack_range = 19, attack_cooldown = 1.3, move_speed = 5},
	"Drone":        {cost = {wood = 2, stone = 2}, min_age = 4, max_hp = 14, damage = 5,  attack_range = 15, attack_cooldown = 0.6, move_speed = 10},
	"TeslaTrooper": {cost = {wood = 3, stone = 4}, min_age = 5, max_hp = 34, damage = 9,  attack_range = 11, attack_cooldown = 1.1, move_speed = 5.5},
	"PrismTank":    {cost = {wood = 5, stone = 5}, min_age = 5, max_hp = 40, damage = 12, attack_range = 21, attack_cooldown = 1.4, move_speed = 5},
}

# UNIT-TYPE-IDENTITY: every humanoid unit (player/rival/restored) renders from the SAME rigged
# species mesh, so type readability comes from PROCEDURAL cues only — a per-type body scale, a few
# emissive primitives forming a role prop (blade/bow/rifle/cannon/hover-orb), and an accent color.
# `scale` multiplies the spawned node's uniform scale; `accent` is the prop's emission base (faction
# tint is mixed in on top); `weapon` selects the prop builder. Covers every key in UNITS; DEFAULT
# fills any future key. Visual only — never touches UNITS stats.
const UNIT_VISUAL_DEFAULT := {scale = 1.0, accent = Color(0.8, 0.8, 0.85), weapon = "blade"}
const UNIT_VISUAL := {
	"Soldier":      {scale = 1.0,  accent = Color(0.85, 0.85, 0.9),  weapon = "blade"},
	"Archer":       {scale = 0.95, accent = Color(0.55, 0.9, 0.55),  weapon = "bow"},
	"Spearman":     {scale = 1.0,  accent = Color(0.9, 0.62, 0.3),   weapon = "spear"},
	"Swordsman":    {scale = 1.08, accent = Color(0.78, 0.82, 0.92), weapon = "blade"},
	"Rifleman":     {scale = 1.0,  accent = Color(0.7, 0.75, 0.85),  weapon = "rifle"},
	"LaserTank":    {scale = 1.45, accent = Color(0.4, 0.85, 1.0),   weapon = "cannon"},
	"Drone":        {scale = 0.7,  accent = Color(1.0, 0.55, 0.2),   weapon = "orb"},
	"TeslaTrooper": {scale = 1.05, accent = Color(0.55, 0.6, 1.0),   weapon = "coil"},
	"PrismTank":    {scale = 1.5,  accent = Color(0.95, 0.5, 1.0),   weapon = "cannon"},
}

const DEFENSES := {
	"LaserTurret": {cost = {wood = 3, stone = 3}, min_age = 4, max_hp = 90,  damage = 10, attack_range = 21, attack_cooldown = 1.0},
	"TeslaCoil":   {cost = {wood = 4, stone = 5}, min_age = 5, max_hp = 120, damage = 11, attack_range = 19, attack_cooldown = 1.2},
	"PrismTower":  {cost = {wood = 5, stone = 6}, min_age = 5, max_hp = 100, damage = 13, attack_range = 25, attack_cooldown = 1.5},
}

const UNIT_MODELS := {
	"Soldier": "character-male-a", "Archer": "character-male-b", "Rifleman": "character-male-c",
	"Spearman": "character-male-a", "Swordsman": "character-male-a",
	"LaserTank": "character-male-d", "Drone": "character-male-e",
	"TeslaTrooper": "character-male-f", "PrismTank": "character-female-a",
}

const WORKER_MODEL := "character-female-b"
const BANDIT_MODEL := "enemy-ufo-d"

# Rival predator archetypes reuse the 5 rigged species meshes (best-effort distinct from the common
# player species), so rivals are animated lineages too. Player units use the player's own species.
const RIVAL_SPECIES := {
	"hydra": "hydra", "sea_jelly": "tall_grey", "lurker": "short_alien",
	"nematode": "reptilian", "tribe": "human",
}

# Which attack animation a unit type plays on its strike beat. Soldier swings a sword, Archer looses
# an arrow; everything else uses the rifle "Shoot" (the "attack" state). See [[primordia-rts-animations]].
const ATTACK_STATE := {
	"Soldier": "melee", "Archer": "bowshoot", "Spearman": "melee", "Swordsman": "melee",
}

const DEFENSE_MODELS := {
	"LaserTurret": "weapon-turret", "TeslaCoil": "tower-round-top-c", "PrismTower": "tower-square-top-c",
}

const BUILDING_MODELS := {
	"House": "tower-round-base", "Granary": "spawn-round",
	"Barracks": "wood-structure", "Spaceport": "tower-round-build-f",
}

# Realistic CC0 building models (Poly by Google) per structure — the "living biome" Civ look.
# Spaceport intentionally stays Kenney (sci-fi capstone). "City" = the town-center building.
# A model id may name a pack dir ("generated/civ_modern/factory_brick"); a bare id defaults to
# the Ultimate Fantasy RTS kit (civ_buildings) — see _model_path().
const CIV_BLDG := "res://assets/models/civ_buildings/%s.glb"
const MODELS_ROOT := "res://assets/models/%s.glb"
const CIV_MODERN_PREFIX := "generated/civ_modern/"
const REAL_BLDG := {"House": "house", "Granary": "storage", "Barracks": "barracks", "City": "farmhouse"}
const BUILDING_HEIGHT_MULTIPLIERS := {
	"house": 0.8,
	"storage": 0.8,
}

# Ambient props scattered around a city, per Age (0..5). Each age modernises the town: rustic
# huts → medieval village → industrial brick → modern city blocks ("each age
# replaces or augments the prior"). RTS kit = bare ids; village/city packs are dir-qualified.
const TOWN_DECOR_BY_AGE := [
	# 0 Stone — crude huts + a rough farm
	["cabin", "logcabin", "farm", "medieval_village/well"],
	# 1 Bronze — first proper village
	["house", "barn", "farm", "windmill", "medieval_village/well", "medieval_village/marketstand"],
	# 2 Iron — full medieval town with walls + trades
	["house", "market", "windmill", "medieval_village/blacksmith", "medieval_village/mill",
		"medieval_village/sawmill", "medieval_village/stable", "medieval_village/inn",
		"medieval_village/belltower", "walltowers", "watchtower", "stonewall"],
	# 3 Industrial — brick blocks creep in beside the old town
	["medieval_village/blacksmith", "medieval_village/mill", "storage", "market",
		"generated/civ_modern/factory_brick", "generated/civ_modern/warehouse_brick",
		"generated/civ_modern/tenement_brick", "generated/civ_modern/water_tower",
		"generated/civ_modern/clock_tower"],
	# 4 Modern — a real city skyline
	["generated/civ_modern/office_tower_glass", "generated/civ_modern/apartment_block",
		"generated/civ_modern/retail_mall", "generated/civ_modern/parking_structure",
		"generated/civ_modern/gas_station"],
	# 5 Near-Future — dense towers + signage
	["generated/civ_modern/arcology_dome", "generated/civ_modern/skyscraper_future",
		"generated/civ_modern/maglev_station", "generated/civ_modern/solar_spire"],
]

# The player's capital evolves with Age: settlement → castle → modern tower. Indexed by _age (0..5).
const CITY_TIERS := ["towncenter", "woodencastle", "castlefortress",
	"generated/civ_modern/clock_tower", "generated/civ_modern/office_tower_glass",
	"generated/civ_modern/skyscraper_future"]

const FACTION_COLORS := [
	Color(0.5, 0.7, 1.0),
	Color(1.0, 0.45, 0.40),
	Color(0.75, 0.50, 0.95),
	Color(0.50, 0.85, 0.55),
]

const BANDIT_FAC := 90
const WILD_FAC := 80
const PREDATOR_FAC := 81
const MAX_BANDITS := 4
const MAX_WILDLIFE := 18

const TRUCE_DURATION := 70.0
const TRUCE_COST := {wood = 4, stone = 4}
const PEACE_DURATION := 70.0

const RIVAL_COUNT := 3
const RIVAL_TRAIN_COST := 5.0
const RIVAL_CITY_COST := 26.0
const RIVAL_THINK_INTERVAL := 5.0
## How far an idle/moving player unit picks fights on its own. Rivals and bandits hunt map-wide
## (200), but at 200 the player's army razed rival cities unordered — conquest won itself.
const PLAYER_GUARD_RADIUS := 35.0
## Seconds per rival age-up; keeps rivals' unit tier roughly level with the (slow) player age ladder.
const RIVAL_AGE_INTERVAL := 300.0
const CIV_SIM_INTERVAL := 1.4
## Lower = rivals retrain faster (was 1.75 — felt passive vs player economy).
const RIVAL_TRAIN_INTERVAL_MULT := 1.35
## Treasury per rival city per second. Raised (was 0.8) so rivals keep up with the slower player economy.
const RIVAL_INCOME_PER_CITY := 1.5
const BANDIT_SPAWN_MIN := 42.0
const BANDIT_SPAWN_MAX := 85.0
const WILDLIFE_SPAWN_MIN := 14.0
const WILDLIFE_SPAWN_MAX := 28.0
const DIPLOMACY_INTERVAL_MIN := 46.0
const DIPLOMACY_INTERVAL_MAX := 80.0

const MELEE_LADDER := [[0, "Soldier"], [1, "Spearman"], [2, "Swordsman"], [4, "LaserTank"], [5, "TeslaTrooper"]]
const RANGED_LADDER := [[0, "Archer"], [3, "Rifleman"], [4, "Drone"], [5, "PrismTank"]]

var _grid_offset := Vector3.ZERO
var _ground_tone := GroundTone.new(hash(EvolutionState.world_seed + "_ground_tone"))
var _terr_noise: FastNoiseLite = null
# MultiMesh batching: cached mesh parts per source GLB path (loaded once, reused for every
# instance of that tile/groundcover type), and groundcover placements collected during
# _build_ground and flushed into MultiMeshInstance3D nodes at the end (see _flush_groundcover_multimesh).
var _mesh_parts_cache: Dictionary = {}
var _groundcover_records: Dictionary = {}
var _age := 0
var _stage_done := false
var _res := {"food": 0, "wood": 0, "stone": 0}
var _res_f := {"food": 0.0, "wood": 0.0, "stone": 0.0}
var _granary_bonus := 0.0
var _bonus_production := 0
var _defense_bonus := 0
var _extra_move := 0
var _expansion := 0
var _tech_index := 0
var _has_barracks := false
var _has_spaceport := false
var _weapon_tier := 0
var _armor_tier := 0

var _cities: Array[Dictionary] = []
var _structures: Array[Dictionary] = []   # {kind, cell of the city it was built in} for the homeworld view
var _units: Array[Dictionary] = []
var _workers: Array[Node3D] = []
# Harvest targets recorded at map-gen so workers path to real sites: wood=trees, stone=rocks/mountains,
# food=bushes. Workers run a seek→gather→carry→deposit loop against these (income math unchanged).
var _resource_nodes: Dictionary = {"food": [], "wood": [], "stone": []}
var _bandits: Array[Dictionary] = []
var _wildlife: Array[Dictionary] = []
var _build_queue: Array = []
var _selected: Array[Dictionary] = []
var _rivals: Array[Dictionary] = []

var _sel_box: Control = null      # drag-selection rectangle overlay (SelectionBox2D)
var _drag_start := Vector2.ZERO
var _dragging := false
const DRAG_THRESHOLD := 8.0       # px of movement before a click becomes a box-drag
var _battle_open := false
var _battle_friend_ids: Array = []   # indices into _units for the live fight
var _battle_foe_ids: Array = []
var _siege_prompt_cd := 0.0
const SIEGE_PROMPT_COOLDOWN := 18.0
## Auto-open defense when a city is pressed below this HP fraction.
const SIEGE_AUTO_HP_FRAC := 0.5
var _battle_tutorial_shown := false
var _siege_auto_opened_cities: Dictionary = {}  # city instance id -> true (once per city crisis)

var _nav: AStarGrid2D = null      # grid pathfinder: units route around water/mountains/buildings/trees
var _spawn_turns := {}            # capital Vector2i -> units appeared beside it so far
var _obstacle_cells := {}         # Vector2i -> true (props + buildings that block a whole cell)
const GROUND_FOLLOW_SPEED := 4.0   # units/s a walker eases up or down a hill
var _hill_cells: Dictionary = {}  # Vector2i -> that hill tile's yaw in degrees
var _hill_field: TileHeightfield = null  # surface of the hill tile, in its own mesh space
var _hill_fit := 1.0              # uniform scale the hill tile is drawn at
var _flat_top := 0.0              # world height of an ordinary grass tile's top

var _settler: Node3D = null
var _settler_pos := Vector3.ZERO
var _truce_until := 0.0
var _at_peace := {}
var _offer_pending := false
var _bandit_t := 38.0
var _wildlife_t := 21.0
var _diplo_t := 62.0
var _elapsed := 0.0
var _civ_sim_t := 0.0
var _unrest := 0.0
var _needs_production_mult := 1.0
var _climate_co2 := 280.0
var _warming_deg := 0.0
var _climate_production_mult := 1.0
var _civ_buildings_by_type := {"town_center": 0}
var _chain_stock := {"wood": 0, "ore": 0, "grain": 0, "planks": 0, "ingots": 0, "tools": 0, "bread": 0}
var _chain_raw_progress := {"wood": 0.0, "ore": 0.0, "grain": 0.0}
var _chain_progress := {"planks": 0.0, "ingots": 0.0, "tools": 0.0, "bread": 0.0}
var _chain_production_mult := 1.0
var _bread_demand_acc := 0.0
var _rival_activity := "scouting"

var _status: Label
var _stat_strip
var _train_btns: Array[Button] = []
var _unit_btns: Array[Button] = []
var _build_btns: Array[Button] = []
var _defense_btns: Array[Button] = []
var _truce_btn: Button
var _age_btn: Button
var _research_btn: Button
var _launch_btn: Button
var _settler_btn: Button = null
var _upgrade_btns: Array[Button] = []


func _ready() -> void:
	_apply_traits()
	_apply_carryforward()
	_build_environment("outdoor")
	_build_sun()
	_build_ground()
	_build_nav()
	_ensure_traversable()   # safety: forests must shape lanes, never wall a region off
	_spawn_settler()
	_spawn_rivals()
	_build_camera(_settler_pos, CAMERA_SIZE)
	# Let the camera roam across the larger map (zoom range is the camera's two-level bands).
	for c in get_children():
		if c is Camera3D:
			c.set("bounds", Vector2(COLS * TILE_3D * 0.5, ROWS * TILE_3D * 0.5))
			break
	_build_ui()
	_build_selection_overlay()
	_build_minimap()
	for r in RES:
		_res[r] = int(_res_f[r])


func _apply_traits() -> void:
	for t in EvolutionState.traits:
		if "movement" in t: _extra_move += 1
		if "defense" in t: _defense_bonus += 1
		if "production" in t: _bonus_production += 1
		if "expansion" in t: _expansion += 1
	# Continuous genome axes stack on top of named trait strings.
	_bonus_production += GenomeBonus.city_prod_bonus(EvolutionState.genome)
	_defense_bonus += GenomeBonus.housing_bonus(EvolutionState.genome) / 2


func _apply_carryforward() -> void:
	var total := 0
	for id in EvolutionState.creature_inventory:
		total += int(EvolutionState.creature_inventory[id])
	_res_f["food"] += float(total * 2)
	if EvolutionState.discovered_fire:
		_bonus_production += 1
	if EvolutionState.tribe_population > 0:
		# Tribe pop seeds food AND a modest settler runway (3-city path stays reachable).
		_res_f["food"] += float(EvolutionState.tribe_population * 3 + 6)
	call_deferred("_emit_civ_open_brief")


func _emit_civ_open_brief() -> void:
	Events.notify.emit(GenomeBonus.foreshadow_line(EvolutionState.genome))
	Events.notify.emit(
		"Win paths: %d cities + Spaceport + one rival eliminated, then Launch  ·or·  raze every rival capital"
		% WIN_CITY_COUNT
	)


# Coherent terrain: one large landmass (cored, water only as rim + a few lakes) with
# mountain ranges on the high ridges. Far less water than the old 40%-per-cell random.
func terrain_at(x: int, y: int) -> int:
	if _terr_noise == null:
		_terr_noise = FastNoiseLite.new()
		_terr_noise.seed = int(hash(EvolutionState.world_seed))
		_terr_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_terr_noise.frequency = 0.07
		_terr_noise.fractal_octaves = 3
	# Radial falloff so the map is land in the middle and trails to water at the edges.
	var nx: float = (float(x) / float(COLS - 1)) * 2.0 - 1.0
	var ny: float = (float(y) / float(ROWS - 1)) * 2.0 - 1.0
	var edge: float = maxf(absf(nx), absf(ny))
	var e: float = _terr_noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5  # 0..1
	e -= smoothstep(0.74, 1.05, edge) * 0.5  # only the far rim trails into water
	if e < 0.20: return Terrain.WATER   # coherent lakes/coast only (~12% of map)
	if e > 0.80: return Terrain.MOUNTAIN
	return Terrain.LAND


func _tile_pos(cx: int, cy: int) -> Vector3:
	# Kenney's terrain pieces are pointy-top hexagons. Stagger every other ROW by
	# half a column so flat edges meet flush and points interlock — visual terrain,
	# cities, units, and navigation all share this one coherent world layout.
	var row_offset := HEX_COL_STEP * 0.5 if (cy & 1) == 1 else 0.0
	return _grid_offset + Vector3(cx * HEX_COL_STEP + row_offset, 0, cy * HEX_ROW_STEP)


func _cell_at(wpos: Vector3) -> Vector2i:
	var local := wpos - _grid_offset
	# Invert _tile_pos: rows resolve first (no offset), then columns net of the
	# row's half-column stagger.
	var cy := int(round(local.z / HEX_ROW_STEP))
	var row_offset := HEX_COL_STEP * 0.5 if (cy & 1) == 1 else 0.0
	var cx := int(round((local.x - row_offset) / HEX_COL_STEP))
	# Screen-to-ground picks can land just beyond the terrain mesh. Keep those
	# commands in the playable grid rather than passing an invalid cell to terrain_at.
	return Vector2i(clampi(cx, 0, COLS - 1), clampi(cy, 0, ROWS - 1))


func _land_tiles() -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			if terrain_at(x, y) == Terrain.LAND:
				r.append(Vector2i(x, y))
	return r


func _random_land(salt: int) -> Vector2i:
	var lands := _land_tiles()
	if lands.is_empty(): return Vector2i.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_settler_%d" % [EvolutionState.world_seed, salt])
	return lands[rng.randi_range(0, lands.size() - 1)]


func _find_land_near(c: Vector2i) -> Vector2i:
	for radius in range(0, maxi(COLS, ROWS)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var t := Vector2i(clampi(c.x + dx, 0, COLS - 1), clampi(c.y + dy, 0, ROWS - 1))
				if terrain_at(t.x, t.y) == Terrain.LAND:
					return t
	return Vector2i.ZERO


func _terrain_component(anchor: Vector2i) -> Dictionary:
	var start := _find_land_near(anchor)
	var reached: Dictionary[Vector2i, bool] = {start: true}
	var frontier: Array[Vector2i] = [start]
	var head := 0
	while head < frontier.size():
		var current := frontier[head]
		head += 1
		for dir in DIRS4:
			var next := current + dir
			if next.x < 0 or next.y < 0 or next.x >= COLS or next.y >= ROWS:
				continue
			if reached.has(next) or terrain_at(next.x, next.y) != Terrain.LAND:
				continue
			reached[next] = true
			frontier.append(next)
	return reached


func _connected_land_near(wanted: Vector2i, anchor: Vector2i) -> Vector2i:
	var component := _terrain_component(anchor)
	for radius in range(0, maxi(COLS, ROWS)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell := Vector2i(clampi(wanted.x + dx, 0, COLS - 1), clampi(wanted.y + dy, 0, ROWS - 1))
				if component.has(cell):
					return cell
	return _find_land_near(anchor)


func _player_start_cell() -> Vector2i:
	# Start south on the main landmass so center and rival routes always exist through terrain.
	return _connected_land_near(Vector2i(COLS / 2, ROWS - 5), Vector2i(COLS / 2, ROWS / 2))


func _rival_start_cell(i: int) -> Vector2i:
	# Rivals start north from the rotational mirror of the south player main, then fan out evenly.
	var p := _player_start_cell()
	var mirrored := Vector2i(COLS - 1 - p.x, ROWS - 1 - p.y)
	var centered_i := float(i) - float(RIVAL_COUNT - 1) * 0.5
	var col := clampi(int(round(float(mirrored.x) + centered_i * float(MIRRORED_RIVAL_SPACING))), 2, COLS - 3)
	return _connected_land_near(Vector2i(col, clampi(mirrored.y, 2, ROWS / 2 - 3)), p)


const HEX_TILE_ROOT := "res://assets/models/kenney-hexagon/"
const HEX_GRASS_TILE := HEX_TILE_ROOT + "grass.glb"
const HEX_FOREST_TILE := HEX_TILE_ROOT + "grass-forest.glb"
const HEX_HILL_TILE := HEX_TILE_ROOT + "grass-hill.glb"
const HEX_SAND_TILE := HEX_TILE_ROOT + "sand.glb"
const HEX_WATER_TILE := HEX_TILE_ROOT + "water.glb"
const HEX_WATER_ROCKS_TILE := HEX_TILE_ROOT + "water-rocks.glb"
const HEX_MOUNTAIN_TILE := HEX_TILE_ROOT + "stone-mountain.glb"
const HEX_STONE_HILL_TILE := HEX_TILE_ROOT + "stone-hill.glb"
const HEX_PATH_CROSSING_TILE := HEX_TILE_ROOT + "path-crossing.glb"
const HEX_PATH_STRAIGHT_TILE := HEX_TILE_ROOT + "path-straight.glb"


# Spawn a Quaternius floor tile size-normalized to fill a TILE_3D cell footprint
# (fit by the larger of X/Z, slightly oversized so neighbours overlap with no seam).
func _ground_tile(path: String, pos: Vector3, raise: float = 0.0) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node: Node3D = packed.instantiate()
	add_child(node)
	matte_materials(node)
	var box := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.transform * mi.mesh.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	var foot: float = maxf(box.size.x, box.size.z)
	if foot > 0.0:
		node.scale = Vector3.ONE * (TILE_3D * 1.04 / foot)
	node.position = pos + Vector3(0, raise, 0)
	return node


func _build_ground() -> void:
	# Centre the staggered board on the origin so the camera starts over the middle
	# instead of the map drifting into one corner.
	var map_width := HEX_COL_STEP * float(COLS)
	var map_depth := HEX_ROW_STEP * float(ROWS - 1) + HEX_POINT
	_grid_offset = Vector3(-map_width * 0.5, 0, -map_depth * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_ground_dec" % EvolutionState.world_seed)
	# The supplied Kenney hex kit gives land, coast, hills and mountains a readable
	# game-board silhouette. Headless tests retain the lightweight procedural plane.
	var use_hex_tiles := DisplayServer.get_name() != "headless"
	if use_hex_tiles:
		_build_hex_underlay()
		_build_hex_terrain(rng)
		_build_water_sheet(HEX_WATER_LEVEL)
	else:
		_build_grass_plane()
		_build_water_sheet()
	# Mountains (kept as-is) + sparse open-land flavor. Forests/berries come after so they can avoid
	# the reserved city clearings (computed deterministically to match the spawners).
	var clearings := _reserved_clearings()
	for y in ROWS:
		for x in COLS:
			var t := terrain_at(x, y)
			var pos := _tile_pos(x, y)
			if t == Terrain.MOUNTAIN:
				_resource_nodes["stone"].append(pos)
				if not use_hex_tiles:
					var mtn := WorldProps.spawn_at(self, CIV_BLDG % "mountain", pos, TILE_3D * 1.7)
					if mtn != null:
						mtn.rotation.y = rng.randf() * TAU
					else:
						var rock := spawn_model(TD % "tile-rock", pos, TILE_3D, rng.randf() * 90)
						if rock:
							rock.scale = Vector3(TILE_3D, TILE_3D * 1.4, TILE_3D)
				continue
			if t == Terrain.LAND:
				_scatter_life(pos, rng, clearings)
	# RTS shaping: contiguous forest belts (chokepoints) + visible berry patches (food).
	_grow_forest_belts(rng, clearings)
	_place_exposed_expansions(rng, clearings)
	_place_midfield_contest(rng, clearings)
	_scatter_berry_patches(rng, clearings)
	_flush_groundcover_multimesh()


func _build_hex_terrain(rng: RandomNumberGenerator) -> void:
	# PERF: 2,240 cells used to each instantiate an individual GLB scene (thousands of draw
	# calls + a slow build hitch). Instead, group every cell by its tile GLB and pick a rotation
	# now (same rng draws, same order, as the old per-cell loop), then batch each distinct tile
	# type into MultiMeshInstance3D below. Visual result is identical; instance count drops from
	# ~2,240 nodes to ~1 MultiMeshInstance3D per distinct tile GLB (submesh).
	var by_path: Dictionary = {}
	for y in ROWS:
		for x in COLS:
			var terrain: int = terrain_at(x, y)
			var path := _hex_tile_for(terrain, x, y, rng)
			var raise := 0.0
			if terrain == Terrain.WATER:
				raise = HEX_WATER_ROCKS_RAISE if path == HEX_WATER_ROCKS_TILE else -0.35
			# Kenney's symmetric hexes support 60-degree rotations; varied grass and
			# water breakup reads natural without fighting the square navigation grid.
			var rot := float(rng.randi_range(0, 5) * 60)
			if not by_path.has(path):
				by_path[path] = []
			by_path[path].append({x = x, y = y, raise = raise, rot = rot})
			if path == HEX_HILL_TILE:
				_hill_cells[Vector2i(x, y)] = rot
	for path in by_path:
		_build_tile_multimesh(path, by_path[path])
	_build_hill_field()


# Hill tiles carry rocks well above an ordinary tile; remember their surface so walkers can
# stand on it. Needs only the meshes, so it also works without the drawn terrain.
func _build_hill_field() -> void:
	var hill_parts := _load_mesh_parts(HEX_HILL_TILE)
	var grass_parts := _load_mesh_parts(HEX_GRASS_TILE)
	if hill_parts.is_empty() or grass_parts.is_empty():
		return
	var grass_box := _merged_box(grass_parts)
	_hill_fit = _tile_fit(_merged_box(hill_parts))
	_flat_top = grass_box.end.y * _tile_fit(grass_box) * _hex_height_multiplier(HEX_GRASS_TILE)
	_hill_field = TileHeightfield.from_parts(hill_parts)


func _tile_fit(box: AABB) -> float:
	var foot: float = maxf(box.size.x, box.size.z)
	return (TILE_3D * 1.04 / foot) if foot > 0.0 else 1.0


# How far the ground under `pos` stands above an ordinary flat tile top.
func _ground_lift(pos: Vector3) -> float:
	if _hill_field == null:
		return 0.0
	var cell := _cell_at(pos)
	if not _hill_cells.has(cell):
		return 0.0
	# Undo the tile instance's placement (see _build_tile_multimesh) to land in mesh space.
	var local := (pos - _tile_pos(cell.x, cell.y)).rotated(Vector3.UP, -deg_to_rad(float(_hill_cells[cell]))) / _hill_fit
	var top := _hill_field.sample(Vector2(local.x, local.z)) * _hill_fit * _hex_height_multiplier(HEX_HILL_TILE)
	return maxf(0.0, top - _flat_top)


# Walkers keep their own base height; only the eased hill delta rides on top (visual only).
func _follow_ground(walker: Variant, delta: float) -> void:
	if not is_instance_valid(walker):
		return
	var node: Node3D = walker
	var want := _ground_lift(node.position)
	var have := float(node.get_meta("ground_lift", 0.0))
	if is_equal_approx(want, have):
		return
	var now := move_toward(have, want, GROUND_FOLLOW_SPEED * delta)
	node.position.y += now - have
	node.set_meta("ground_lift", now)


func _tick_ground_follow(delta: float) -> void:
	if _hill_field == null:
		return
	for u in _units:
		_follow_ground(u.node, delta)
	for w in _workers:
		_follow_ground(w, delta)
	_follow_ground(_settler, delta)


# Saves keep the base height, not the hill-lifted one.
func _unlifted(node: Node3D) -> Vector3:
	return node.position - Vector3(0.0, float(node.get_meta("ground_lift", 0.0)), 0.0)


# Batch every cell using the same tile GLB into one MultiMeshInstance3D (one per submesh, if
# the GLB has more than one MeshInstance3D). Reproduces _ground_tile's uniform fit-scale,
# _hex_height_multiplier's Y compression, tint_model's flat per-tile color (now per-instance
# via MultiMesh.use_colors), and the per-cell world position + Y rotation.
func _build_tile_multimesh(path: String, records: Array) -> void:
	var parts := _load_mesh_parts(path)
	if parts.is_empty():
		return
	var fit := _tile_fit(_merged_box(parts))
	var height_mult := _hex_height_multiplier(path)
	var color := _hex_tile_color(path)
	var board_aabb := _board_aabb()
	for part_idx in parts.size():
		var part: Dictionary = parts[part_idx]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		if path == HEX_HILL_TILE:
			# Grass base like the plain grass tiles around it, bare rock like the mountain tiles.
			mm.mesh = _mesh_with_two_tone_albedo(part.mesh, _hex_tile_color(HEX_GRASS_TILE), _hex_tile_color(HEX_MOUNTAIN_TILE), true)
		else:
			mm.mesh = _mesh_with_albedo_tint(part.mesh, color, true)
		mm.instance_count = records.size()
		for i in records.size():
			var rec: Dictionary = records[i]
			var pos: Vector3 = _hex_tile_pos(rec.x, rec.y) + Vector3(0, rec.raise, 0)
			var root_basis := Basis(Vector3.UP, deg_to_rad(rec.rot)).scaled(Vector3(fit, fit * height_mult, fit))
			var xform: Transform3D = Transform3D(root_basis, pos) * part.xform
			mm.set_instance_transform(i, xform)
			mm.set_instance_color(i, _ground_tone.at(pos))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.custom_aabb = board_aabb   # MultiMeshInstance3D doesn't auto-grow its culling AABB
		mmi.name = "HexTerrainMM_%s_%d" % [path.get_file().get_basename(), part_idx]
		# Preserve the Kenney surface material and colormap. A blank override here
		# erased the actual asset art and reduced every terrain type to a flat tint.
		add_child(mmi)


# Loads `path` once and returns its MeshInstance3D children as {mesh, xform} parts (xform is
# each child's transform relative to the scene root, matching how _ground_tile/_fit_height
# already read these GLBs). Cached per path since the same tile/groundcover type recurs
# hundreds of times.
func _load_mesh_parts(path: String) -> Array:
	if _mesh_parts_cache.has(path):
		return _mesh_parts_cache[path]
	var parts: Array = []
	var packed := load(path) as PackedScene
	if packed != null:
		var node: Node3D = packed.instantiate()
		for n in node.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh != null:
				parts.append({mesh = mi.mesh, xform = mi.transform})
		# Temporary import root never enters the SceneTree, so free it immediately.
		node.free()
	_mesh_parts_cache[path] = parts
	return parts


func _merged_box(parts: Array) -> AABB:
	var box := AABB()
	var first := true
	for part in parts:
		var mesh: Mesh = part.mesh
		var b: AABB = part.xform * mesh.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


# Generous world-space AABB covering the whole hex board (+ margin for raised mountains), used
# as the MultiMeshInstance3D custom_aabb so instances never get culled early when the camera moves.
func _board_aabb() -> AABB:
	var map_width := HEX_COL_STEP * float(COLS)
	var map_depth := HEX_ROW_STEP * float(ROWS - 1) + HEX_POINT
	return AABB(_grid_offset + Vector3(-TILE_3D, -10.0, -TILE_3D),
		Vector3(map_width + TILE_3D * 2.0, 30.0, map_depth + TILE_3D * 2.0))


func _hex_tile_pos(x: int, y: int) -> Vector3:
	# Keep visual tiles registered to gameplay cells; a dark underlay fills the
	# deliberately visible hex seams without distorting buildings or navigation.
	return _tile_pos(x, y)


func _hex_height_multiplier(path: String) -> float:
	if path == HEX_MOUNTAIN_TILE:
		return 0.55
	if path == HEX_STONE_HILL_TILE or path == HEX_HILL_TILE:
		return 0.30
	return 0.20


func _hex_tile_color(path: String) -> Color:
	if path == HEX_WATER_ROCKS_TILE:
		return Color(0.60, 0.62, 0.64)   # its rocks stand clear of the water sheet
	if path == HEX_WATER_TILE:
		return Color(0.08, 0.34, 0.58)
	if path == HEX_SAND_TILE:
		return Color(0.78, 0.72, 0.50)
	if path == HEX_MOUNTAIN_TILE or path == HEX_STONE_HILL_TILE:
		return Color(0.74, 0.68, 0.52)   # warms the kit's lavender stone to a plain grey
	# Reds above 1 pull the kit's teal grass toward leaf green, as in the Tribe stage. Forest
	# tiles take the grass tint so their ground runs into the grass around them; hills tint their
	# grass and rock separately (_build_tile_multimesh).
	return Color(1.26, 0.68, 0.36)


func _build_hex_underlay() -> void:
	var base := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var map_width := HEX_COL_STEP * float(COLS)
	var map_depth := HEX_ROW_STEP * float(ROWS - 1) + HEX_POINT
	plane.size = Vector2(map_width + TILE_3D * 2.0, map_depth + TILE_3D * 2.0)
	base.mesh = plane
	var mat := StandardMaterial3D.new()
	# Match the grass palette so hex seams provide depth rather than reading as
	# bottomless black gaps between otherwise playable terrain cells.
	mat.albedo_color = Color(0.30, 0.62, 0.55)
	mat.roughness = 1.0
	base.material_override = mat
	base.position = Vector3(0, HEX_UNDERLAY_LEVEL, 0)
	add_child(base)


# Settlement roads are visual-only: they give capitals a readable footprint but
# do not alter the RTS grid, resources, or pathfinding permissions.
func _dress_city_roads(cell: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_place_road_tile(cell, HEX_PATH_CROSSING_TILE, 0.0)
	_place_road_tile(cell + Vector2i(-1, 0), HEX_PATH_STRAIGHT_TILE, 0.0)
	_place_road_tile(cell + Vector2i(1, 0), HEX_PATH_STRAIGHT_TILE, 0.0)


func _place_road_tile(cell: Vector2i, path: String, yaw: float) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return
	if terrain_at(cell.x, cell.y) != Terrain.LAND:
		return
	var road := _ground_tile(path, _tile_pos(cell.x, cell.y), 0.035)
	if road == null:
		return
	road.name = "SettlementRoad"
	road.scale.y *= 0.20
	road.rotation_degrees.y = yaw


func _hex_tile_for(terrain: int, x: int, y: int, rng: RandomNumberGenerator) -> String:
	if terrain == Terrain.WATER:
		return HEX_WATER_ROCKS_TILE if rng.randf() < 0.12 else HEX_WATER_TILE
	if terrain == Terrain.MOUNTAIN:
		return HEX_MOUNTAIN_TILE if rng.randf() < 0.65 else HEX_STONE_HILL_TILE
	# Give shorelines and interior elevation a distinct read before props are added.
	if _nearest_terrain_distance(Vector2i(x, y), Terrain.WATER, 2) <= 1:
		return HEX_SAND_TILE
	if _terr_noise != null and _terr_noise.get_noise_2d(float(x) + 71.0, float(y) - 23.0) > 0.45:
		return HEX_HILL_TILE
	return HEX_FOREST_TILE if rng.randf() < 0.07 else HEX_GRASS_TILE


func _bind_shader_texture(mat: ShaderMaterial, param: String, texture_path: String) -> bool:
	# Ground textures are presentation-only. An unimported or unavailable texture
	# must leave the shader on its procedural fallback rather than emit a resource
	# loader error every time Civ builds its map (notably in headless tests).
	if not ResourceLoader.exists(texture_path, "Texture2D"):
		push_warning("Missing civ shader texture: %s" % texture_path)
		return false
	var tex := load(texture_path)
	if tex is Texture2D:
		mat.set_shader_parameter(param, tex)
		return true
	push_warning("Missing civ shader texture: %s" % texture_path)
	return false


# One seamless lush-grass plane (procedural shader: organic tone + dirt break-up + normal relief).
func _build_grass_plane() -> void:
	var base := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(COLS * TILE_3D + TILE_3D * 2.0, ROWS * TILE_3D + TILE_3D * 2.0)
	base.mesh = pm
	var smat := ShaderMaterial.new()
	smat.shader = load("res://assets/shaders/ground_grass.gdshader")
	smat.set_shader_parameter("terrain_lookup", _build_ground_lookup_texture())
	smat.set_shader_parameter("terrain_grid_origin", Vector2(_grid_offset.x, _grid_offset.z))
	smat.set_shader_parameter("terrain_grid_size", Vector2(COLS * TILE_3D, ROWS * TILE_3D))
	smat.set_shader_parameter("terrain_grid_tiles", Vector2(COLS, ROWS))
	# Automated test and simulation runs use Godot's headless renderer, where
	# these optional presentation textures are unnecessary. Keeping that path
	# procedural avoids resource-loader noise from incomplete local imports.
	var albedo_ok := false
	var normal_ok := false
	if DisplayServer.get_name() != "headless":
		albedo_ok = _bind_shader_texture(smat, "grass_albedo", "res://assets/textures/ground_grass_albedo.png")
		albedo_ok = _bind_shader_texture(smat, "dirt_albedo", "res://assets/textures/ground_dirt_albedo.png") and albedo_ok
		albedo_ok = _bind_shader_texture(smat, "rock_albedo", "res://assets/textures/ground_rock_albedo.png") and albedo_ok
		normal_ok = _bind_shader_texture(smat, "grass_normal", "res://assets/textures/ground_grass_normal.png")
		normal_ok = _bind_shader_texture(smat, "dirt_normal", "res://assets/textures/ground_dirt_normal.png") and normal_ok
		normal_ok = _bind_shader_texture(smat, "rock_normal", "res://assets/textures/ground_rock_normal.png") and normal_ok
	smat.set_shader_parameter("use_ground_albedo_textures", albedo_ok)
	smat.set_shader_parameter("use_ground_normal_textures", normal_ok)
	base.material_override = smat
	base.position = Vector3(0, -0.02, 0)
	add_child(base)


func _build_ground_lookup_texture() -> ImageTexture:
	# RGB: terrain id, distance to water, distance to mountain; one texel per civ tile.
	var img := Image.create(COLS, ROWS, false, Image.FORMAT_RGB8)
	for y in ROWS:
		for x in COLS:
			var t := terrain_at(x, y)
			var terrain_id := 0.5
			if t == Terrain.WATER:
				terrain_id = 0.0
			elif t == Terrain.MOUNTAIN:
				terrain_id = 1.0
			var water_dist := clampf(float(_nearest_terrain_distance(Vector2i(x, y), Terrain.WATER, 5)) / 5.0, 0.0, 1.0)
			var mountain_dist := clampf(float(_nearest_terrain_distance(Vector2i(x, y), Terrain.MOUNTAIN, 4)) / 4.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(terrain_id, water_dist, mountain_dist))
	return ImageTexture.create_from_image(img)


func _nearest_terrain_distance(cell: Vector2i, target: int, max_radius: int) -> int:
	if terrain_at(cell.x, cell.y) == target:
		return 0
	for radius in range(1, max_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var x := cell.x + dx
				var y := cell.y + dy
				if x < 0 or y < 0 or x >= COLS or y >= ROWS:
					continue
				if terrain_at(x, y) == target:
					return radius
	return max_radius + 1


# A SINGLE continuous animated water sheet spanning the whole map at `level` (below the land).
# Land cells sit above it, so water only reads where the terrain dips to water —
# no per-cell flat boxes, no grid seams.
func _build_water_sheet(level := WATER_LEVEL) -> void:
	var water := MeshInstance3D.new()
	water.name = "WaterSheet"
	var wm := PlaneMesh.new()
	wm.size = Vector2(COLS * TILE_3D + TILE_3D * 4.0, ROWS * TILE_3D + TILE_3D * 4.0)
	water.mesh = wm
	var smat := ShaderMaterial.new()
	smat.shader = load("res://assets/shaders/water_surface.gdshader")
	smat.set_shader_parameter("shallow_color", WATER_SHALLOW)
	smat.set_shader_parameter("deep_color", WATER_DEEP)
	smat.set_shader_parameter("use_water_normal_tex", _bind_shader_texture(smat, "water_normal_tex", "res://assets/textures/water_normal.png"))
	_bind_shore_map(smat)
	smat.render_priority = -1
	water.material_override = smat
	water.position = Vector3(0, level, 0)
	add_child(water)


# Tells the water where the coast is, so it can paint shallows and surf along it. The map's
# texels are half a column wide and one row tall, starting at the first tile's corner.
func _bind_shore_map(smat: ShaderMaterial) -> void:
	var water := PackedByteArray()
	water.resize(COLS * ROWS)
	for y in ROWS:
		for x in COLS:
			water[y * COLS + x] = 1 if terrain_at(x, y) == Terrain.WATER else 0
	smat.set_shader_parameter("shore_map", ImageTexture.create_from_image(ShoreMap.image(water, COLS)))
	smat.set_shader_parameter("shore_origin",
			Vector2(_grid_offset.x - HEX_COL_STEP * 0.5, _grid_offset.z - HEX_ROW_STEP * 0.5))
	smat.set_shader_parameter("shore_size", Vector2(HEX_COL_STEP * (COLS + 0.5), HEX_ROW_STEP * ROWS))
	smat.set_shader_parameter("use_shore_map", true)


func _jitter(rng: RandomNumberGenerator, r: float) -> Vector3:
	return Vector3(rng.randf_range(-r, r), 0, rng.randf_range(-r, r))


# Sparse open-land flavor: lone trees, occasional rocks, and a groundcover carpet. The forest MASS
# is grown separately as belts; this just keeps open grassland from looking empty. Trees + rocks
# block their cell so units route around them.
func _scatter_life(pos: Vector3, rng: RandomNumberGenerator, clearings: Array[Vector2i]) -> void:
	var cell := _cell_at(pos)
	var open := not _near_midfield(cell, MIDFIELD_CLEAR_RADIUS)
	# A start draws the same random numbers as any other cell, so maps from existing seeds do not
	# shift, but its tree or rock is taken away again: nobody should begin hidden behind one.
	var keep := not _near_clearing(cell, clearings, START_CLEAR_RADIUS)
	if rng.randf() < SCATTER_TREE_CHANCE and open:
		var tp := pos + _jitter(rng, 2.4)
		var tree := WorldProps.spawn_tree(self, tp, rng)
		if keep:
			_mark_obstacle_cell(cell)
			_resource_nodes["wood"].append(tp)
		elif tree != null:
			tree.free()
	if rng.randf() < SCATTER_ROCK_CHANCE and open:
		var rp := pos + _jitter(rng, 2.6)
		var rock := WorldProps.spawn_rock(self, rp, rng)
		if keep:
			_mark_obstacle_cell(cell)
			_resource_nodes["stone"].append(rp)
		elif rock != null:
			rock.free()
	for _g in rng.randi_range(SCATTER_GROUNDCOVER_MIN, SCATTER_GROUNDCOVER_MAX):
		_collect_groundcover(pos + _jitter(rng, 2.9), rng)


# Record a groundcover placement instead of spawning it immediately (PERF: ~2,000+ individual
# scenes across the map). Mirrors WorldProps.spawn_groundcover's rng draws exactly, in the same
# order (path pick, height jitter, rotation), so the rng sequence — and therefore every other
# random placement drawn from the same stream afterward — is unchanged. Batched into
# MultiMeshInstance3D by _flush_groundcover_multimesh once the whole map is built.
func _collect_groundcover(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var path: String = WorldProps.GROUNDCOVER[rng.randi_range(0, WorldProps.GROUNDCOVER.size() - 1)]
	var stem: String = path.get_file().get_basename()
	var h: float = float(WorldProps.GROUNDCOVER_H.get(stem, 0.5)) * rng.randf_range(0.85, 1.15)
	var rot: float = rng.randf() * TAU
	if not _groundcover_records.has(path):
		_groundcover_records[path] = []
	_groundcover_records[path].append({pos = pos, h = h, rot = rot})


# Emit one MultiMeshInstance3D per groundcover mesh type (per submesh) from everything
# _collect_groundcover recorded. Reproduces WorldProps._fit_height's per-instance uniform scale
# (height / mesh height) and _spawn's random Y rotation; groundcover keeps its native GLB
# material (WorldProps never tints it), so no material_override/use_colors here.
func _flush_groundcover_multimesh() -> void:
	var board_aabb := _board_aabb()
	for path in _groundcover_records:
		var records: Array = _groundcover_records[path]
		var parts := _load_mesh_parts(path)
		if parts.is_empty():
			continue
		var box := _merged_box(parts)
		if box.size.y <= 0.0:
			continue
		for part_idx in parts.size():
			var part: Dictionary = parts[part_idx]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _mesh_with_albedo_tint(part.mesh, Color.WHITE)   # untinted copy, made matte
			mm.instance_count = records.size()
			for i in records.size():
				var rec: Dictionary = records[i]
				var scale_k: float = rec.h / box.size.y
				var root_basis := Basis(Vector3.UP, rec.rot).scaled(Vector3.ONE * scale_k)
				var xform: Transform3D = Transform3D(root_basis, rec.pos) * part.xform
				mm.set_instance_transform(i, xform)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.custom_aabb = board_aabb
			mmi.name = "GroundcoverMM_%s_%d" % [path.get_file().get_basename(), part_idx]
			add_child(mmi)
	_groundcover_records.clear()


# Cells to keep tree-free (city/settler spawn areas) so nothing is walled off. Mirrors how
# _spawn_settler / _spawn_rivals choose their cells, so clearings line up with real spawns.
func _reserved_clearings() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.append(_player_start_cell())   # player settler/first city
	for i in RIVAL_COUNT:
		out.append(_rival_start_cell(i))
	return out


func _near_clearing(cell: Vector2i, clearings: Array[Vector2i], radius: int) -> bool:
	for c in clearings:
		if absi(c.x - cell.x) <= radius and absi(c.y - cell.y) <= radius:
			return true
	return false


func _near_midfield(cell: Vector2i, radius: int) -> bool:
	var mid := Vector2i(COLS / 2, ROWS / 2)
	return absi(cell.x - mid.x) <= radius and absi(cell.y - mid.y) <= radius


func _base_approach_dir(cell: Vector2i) -> Vector2i:
	return Vector2i(0, -1) if cell.y >= ROWS / 2 else Vector2i(0, 1)


# Grow contiguous forest belts via short random walks. Each belt becomes a natural wall/chokepoint:
# every forested cell is marked solid so units must route around the belt, but periodic GAP cells are
# left open (porous belts) and spawn clearings are skipped — so the AStar always keeps a route through.
func _grow_forest_belts(rng: RandomNumberGenerator, clearings: Array[Vector2i]) -> void:
	_grow_home_chokes(rng, clearings)
	for _b in FOREST_BELTS:
		# Start each belt on open land away from spawns.
		var start := _random_belt_start(rng, clearings)
		if start.x < 0:
			continue
		var cur := start
		var dir := _biased_belt_dir(rng)
		for step in FOREST_BELT_STEPS:
			# Occasionally turn so belts curve naturally rather than running dead straight.
			if rng.randf() < 0.30:
				dir = _biased_belt_dir(rng)
			cur = Vector2i(cur.x + dir.x, cur.y + dir.y)
			if cur.x < 1 or cur.y < 1 or cur.x >= COLS - 1 or cur.y >= ROWS - 1:
				break
			# Leave a periodic gap so belts never fully seal a region.
			if step % FOREST_GAP_EVERY == FOREST_GAP_EVERY - 1:
				continue
			_forest_cell(cur, rng, clearings)
			# Widen into a belt by foresting the perpendicular neighbours.
			if FOREST_BELT_WIDTH > 0:
				var perp := Vector2i(dir.y, dir.x)
				for w in range(1, FOREST_BELT_WIDTH + 1):
					_forest_cell(Vector2i(cur.x + perp.x * w, cur.y + perp.y * w), rng, clearings)
					_forest_cell(Vector2i(cur.x - perp.x * w, cur.y - perp.y * w), rng, clearings)


func _biased_belt_dir(rng: RandomNumberGenerator) -> Vector2i:
	if rng.randf() < FOREST_CROSS_LANE_BIAS:
		return Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(-1, 0)
	return Vector2i(0, 1) if rng.randf() < 0.5 else Vector2i(0, -1)


func _grow_home_chokes(rng: RandomNumberGenerator, clearings: Array[Vector2i]) -> void:
	for base in clearings:
		var dir := _base_approach_dir(base)
		var row := clampi(base.y + dir.y * HOME_CHOKE_DISTANCE, 1, ROWS - 2)
		for dx in range(-HOME_CHOKE_HALF_WIDTH, HOME_CHOKE_HALF_WIDTH + 1):
			if absi(dx) <= HOME_CHOKE_GAP_HALF_WIDTH:
				continue
			_forest_cell(Vector2i(base.x + dx, row), rng, clearings)


func _random_belt_start(rng: RandomNumberGenerator, clearings: Array[Vector2i]) -> Vector2i:
	for _try in 24:
		var c := Vector2i(rng.randi_range(2, COLS - 3), rng.randi_range(2, ROWS - 3))
		if terrain_at(c.x, c.y) == Terrain.LAND and not _near_clearing(c, clearings, FOREST_CLEAR_RADIUS) \
				and not _near_midfield(c, MIDFIELD_CLEAR_RADIUS):
			return c
	return Vector2i(-1, -1)


# Forest one cell: pack several trees into it (dense canopy), block the cell for nav, and record the
# tree positions as wood nodes. Skips water/mountain/already-blocked cells and reserved clearings.
func _forest_cell(cell: Vector2i, rng: RandomNumberGenerator, clearings: Array[Vector2i]) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return
	if terrain_at(cell.x, cell.y) != Terrain.LAND:
		return
	if _near_midfield(cell, MIDFIELD_CLEAR_RADIUS):
		return
	if _near_clearing(cell, clearings, FOREST_CLEAR_RADIUS) or _obstacle_cells.has(cell):
		return
	var pos := _tile_pos(cell.x, cell.y)
	_mark_obstacle_cell(cell)
	for _t in FOREST_TREES_PER_CELL:
		var tp := pos + _jitter(rng, 2.6)
		WorldProps.spawn_tree(self, tp, rng)
		_resource_nodes["wood"].append(tp)


func _place_exposed_expansions(rng: RandomNumberGenerator, clearings: Array[Vector2i]) -> void:
	for base in clearings:
		var dir := _base_approach_dir(base)
		var wanted := Vector2i(base.x, base.y + dir.y * EXPOSED_EXPANSION_DISTANCE)
		var center := _open_land_near(wanted, clearings, 4, 1)
		if center.x < 0:
			continue
		for i in EXPANSION_TREE_CELLS:
			var side := -2 + i * 2
			_place_tree_resource_cell(Vector2i(center.x + side, center.y), rng, clearings)
		var cpos := _tile_pos(center.x, center.y)
		for _b in EXPANSION_BERRY_BUSHES:
			var bp := cpos + _jitter(rng, BERRY_PATCH_RADIUS * 0.65)
			WorldProps.spawn_berry_bush(self, bp, rng)
			_resource_nodes["food"].append(bp)


func _place_midfield_contest(rng: RandomNumberGenerator, clearings: Array[Vector2i]) -> void:
	var center := _open_land_near(Vector2i(COLS / 2, ROWS / 2), clearings, MIDFIELD_CLEAR_RADIUS, 3)
	if center.x < 0:
		return
	var cpos := _tile_pos(center.x, center.y)
	for _b in MIDFIELD_BERRY_BUSHES:
		var bp := cpos + _jitter(rng, BERRY_PATCH_RADIUS)
		WorldProps.spawn_berry_bush(self, bp, rng)
		_resource_nodes["food"].append(bp)
	for _s in MIDFIELD_STONE_ROCKS:
		var rp := cpos + _jitter(rng, BERRY_PATCH_RADIUS * 0.8)
		WorldProps.spawn_rock(self, rp, rng)
		_resource_nodes["stone"].append(rp)


func _place_tree_resource_cell(cell: Vector2i, rng: RandomNumberGenerator, clearings: Array[Vector2i]) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return
	if terrain_at(cell.x, cell.y) != Terrain.LAND or _obstacle_cells.has(cell):
		return
	if _near_clearing(cell, clearings, 1) or _near_midfield(cell, 2):
		return
	var pos := _tile_pos(cell.x, cell.y)
	_mark_obstacle_cell(cell)
	for _t in FOREST_TREES_PER_CELL:
		var tp := pos + _jitter(rng, 2.4)
		WorldProps.spawn_tree(self, tp, rng)
		_resource_nodes["wood"].append(tp)


# Visible FOOD: clusters of obviously-fruiting berry bushes (bushflowers) so the player can SEE
# where workers gather food. Patches sit on open passable land (bushes don't block nav). Each
# bush position is appended to _resource_nodes["food"] (the worker economy reads this).
func _scatter_berry_patches(rng: RandomNumberGenerator, clearings: Array[Vector2i]) -> void:
	for _p in BERRY_PATCHES:
		var center := _open_land_cell(rng, clearings)
		if center.x < 0:
			continue
		var cpos := _tile_pos(center.x, center.y)
		for _i in BERRY_BUSHES_PER_PATCH:
			var bp := cpos + Vector3(rng.randf_range(-BERRY_PATCH_RADIUS, BERRY_PATCH_RADIUS),
				0, rng.randf_range(-BERRY_PATCH_RADIUS, BERRY_PATCH_RADIUS))
			WorldProps.spawn_berry_bush(self, bp, rng)
			_resource_nodes["food"].append(bp)


# A passable open land cell (not water/mountain, not tree-blocked) for placing a berry patch.
func _open_land_cell(rng: RandomNumberGenerator, clearings: Array[Vector2i]) -> Vector2i:
	for _try in 30:
		var c := Vector2i(rng.randi_range(1, COLS - 2), rng.randi_range(1, ROWS - 2))
		if terrain_at(c.x, c.y) == Terrain.LAND and not _obstacle_cells.has(c) \
				and not _near_clearing(c, clearings, 2) and not _near_midfield(c, MIDFIELD_CLEAR_RADIUS):
			return c
	return Vector2i(-1, -1)


func _open_land_near(cell: Vector2i, clearings: Array[Vector2i], max_radius: int, clearing_radius: int) -> Vector2i:
	cell.x = clampi(cell.x, 1, COLS - 2)
	cell.y = clampi(cell.y, 1, ROWS - 2)
	for radius in range(0, max_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := Vector2i(clampi(cell.x + dx, 1, COLS - 2), clampi(cell.y + dy, 1, ROWS - 2))
				if terrain_at(c.x, c.y) == Terrain.LAND and not _obstacle_cells.has(c) \
						and not _near_clearing(c, clearings, clearing_radius):
					return c
	return Vector2i(-1, -1)


func _spawn_settler() -> void:
	var center := _player_start_cell()
	if _expansion > 0:
		_add_city_at(center)
		center = _random_land(0)
	_create_settler_node(_tile_pos(center.x, center.y))


## Build the settler pawn (model + ground ring) at a world position. Shared by the initial
## spawn, save-restore, and training a replacement settler from a city.
func _create_settler_node(pos: Vector3) -> void:
	_settler_pos = pos
	var sp: String = EvolutionState.species_name if EvolutionState.species_name != "" else "human"
	_settler = _spawn_species_unit(sp, _settler_pos + Vector3(0, 0.2, 0))   # your own people found the first city
	if _settler != null:
		SpeciesVisuals.express(_settler, EvolutionState.genome, false)
	if _settler == null:
		_settler = Node3D.new()
		_settler.position = _settler_pos + Vector3(0, 0.5, 0)
		add_child(_settler)
	var ring := MeshInstance3D.new()
	ring.mesh = TorusMesh.new()
	ring.mesh.outer_radius = 1.2
	ring.mesh.inner_radius = 1.0
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1, 1, 0.4)
	ring_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	ring.position = Vector3(0, 0.05, 0)   # TorusMesh already lies flat; the old 90° tilt stood it up as an arch
	_settler.add_child(ring)


func _place_settler(cell: Vector2i) -> void:
	_settler.position = _tile_pos(cell.x, cell.y) + Vector3(0, 0.2, 0)   # same ground height as other units
	_settler.set_meta("ground_lift", 0.0)   # the snap dropped any hill lift; _follow_ground eases it back in


func _base_income_rate(res: String) -> float:
	match res:
		"food":
			var rate := 0.0
			for c in _cities: rate += float(c.production_rate)
			for w in _workers:
				if w.get_meta("res", "food") == "food": rate += WORKER_YIELD
			rate += _granary_bonus
			return rate
		"wood":
			var rate := 0.0
			for w in _workers:
				if w.get_meta("res", "wood") == "wood": rate += WORKER_YIELD
			return rate
		"stone":
			var rate := 0.0
			for w in _workers:
				if w.get_meta("res", "stone") == "stone": rate += WORKER_YIELD
			return rate
	return 0.0


func _income_rate(res: String) -> float:
	return _base_income_rate(res) * _production_mult() * ECONOMY_PACE


func _production_mult() -> float:
	return clampf(_needs_production_mult * _climate_production_mult * _chain_production_mult, 0.15, 1.20)


func _can_afford(cost: Dictionary) -> bool:
	for r in cost:
		if _res.get(r, 0) < int(cost[r]): return false
	return true


func _spend(cost: Dictionary) -> void:
	for r in cost:
		_res_f[r] -= float(cost[r])
		_res[r] = int(_res_f[r])


func _add_city_at(cell: Vector2i) -> void:
	var pos := _tile_pos(cell.x, cell.y)
	_dress_city_roads(cell)
	var node := _capital_model(pos)
	if node == null:
		node = Node3D.new()
		node.position = pos + Vector3(0, 0.3, 0)
		add_child(node)
	# Include the per-age bonus so cities founded after an age-up produce like the older ones
	# (_advance_age grants existing cities +1 production per age).
	var founding: int = FOUNDING_PROD_BONUS if _cities.is_empty() else 0
	var pr := 1 + _bonus_production + _age + founding
	var city := {
		node = node, faction = 0, cell = cell, position = pos,
		production_rate = pr,
		max_population = 5 + (_expansion * 2) + GenomeBonus.housing_bonus(EvolutionState.genome),
		tint = Color(0.5, 0.7, 1.0),
		hp = CITY_MAX_HP, max_hp = CITY_MAX_HP,
		buildings = [],   # the models of what was built here, each tagged with its town hex
	}
	_cities.append(city)
	if _cities.size() == 1:
		StageObjectives.complete("civ_first_city", "Capital stands — train workers & settlers")
	elif _cities.size() == 2:
		StageObjectives.complete("civ_second_city", "Second city founded — expansion underway")
		Events.notify.emit("Expansion: 2/%d cities · train a Settler for the third" % WIN_CITY_COUNT)
	elif _cities.size() >= WIN_CITY_COUNT:
		StageObjectives.complete("civ_third_city", "City trio ready for spaceflight")
		if _launch_ready():
			Events.notify.emit("Spaceflight path OPEN — launch when ready (or keep conquering).")
		else:
			Events.notify.emit("Cities ready — launch also needs a Spaceport (Age 5+) and %d rival eliminated" % WIN_RIVALS_BEATEN)
	_count_civ_building("town_center")
	_mark_obstacle_cell(cell)   # units path around the city footprint
	_decorate_town(city)
	EvolutionState.civ_cities = _cities.size()
	_update_status()


func _found_city() -> void:
	if _settler == null: return
	var cell := _cell_at(_settler.position)
	if terrain_at(cell.x, cell.y) != Terrain.LAND: return
	if _city_on_cell(cell):
		Events.notify.emit("A city already stands here — move the Settler to open land first")
		return
	if _built_plots().has(cell):
		Events.notify.emit("A building stands here — move the Settler to open land first")
		return
	_add_city_at(cell)
	_settler.queue_free()
	_settler = null
	_update_status()


func _city_on_cell(cell: Vector2i) -> bool:
	for c in _cities:
		if c.cell == cell: return true
	for r in _rivals:
		for p in r.cities:
			if _cell_at(p) == cell: return true
	return false


## Train a new settler from the newest city — without this the one free settler is consumed
## on founding and the player can never reach the 3-city victory threshold again.
func _train_settler() -> void:
	if _cities.is_empty() or _settler != null:
		return
	if not _can_afford({food = SETTLER_COST}):
		return
	_spend({food = SETTLER_COST})
	_create_settler_node(_cities.back().position)
	_update_status()


func _train_worker(res: String) -> void:
	if _cities.is_empty() or not _can_afford({food = WORKER_COST}): return
	_spend({food = WORKER_COST})
	var home: Vector3 = _cities.back().position
	var sp: String = EvolutionState.species_name if EvolutionState.species_name != "" else "human"
	var w := _spawn_species_unit(sp, _spawn_spot(home, 2.0), 0.85)
	if w == null: return
	_set_on_ground(w)
	SpeciesVisuals.express(w, EvolutionState.genome, false)   # workers are your lineage too, slightly smaller
	# Light genome parts so the army of gatherers still reads as YOUR body plan.
	GenomeFeatures3D.apply(w, EvolutionState.genome, sp, 0.25)
	w.set_meta("res", res)
	w.set_meta("home", home)
	w.set_meta("phase", "seek")
	w.set_meta("speed_mult", GenomeBonus.speed_mult(EvolutionState.genome))
	w.set_meta("target", _nearest_node(res, w.position))
	_workers.append(w)
	_update_status()


func _train_unit(name: String) -> void:
	if _cities.is_empty() or not _has_barracks: return
	var spec: Dictionary = UNITS[name]
	if not _can_afford(spec.cost): return
	_spend(spec.cost)
	var home: Vector3 = _cities.back().position
	# Units ARE your lineage: spawn the rigged advanced species mesh (the 22-clip rig), not a generic
	# Kenney char. No flat tint here — tint_model would replace the textured material; express() applies
	# the species skin instead. Role/identity reads from skin + scale, not a different mesh.
	var sp: String = EvolutionState.species_name if EvolutionState.species_name != "" else "human"
	var node := _spawn_species_unit(sp, _spawn_spot(home, 3.0))
	if node == null: return
	_set_on_ground(node)
	var g: Genome = EvolutionState.genome
	SpeciesVisuals.express(node, g, false)   # species skin; no genome rescale (keep tile-fit)
	# Iconic genome parts at low intensity — soldiers carry horns/fangs from Soup→Creature.
	GenomeFeatures3D.apply(node, g, sp, 0.4)
	_apply_unit_identity(node, name, 0)      # per-type scale + emissive role prop (player faction)
	var entry := {
		node = node, faction = 0, unit_type = name,
		max_hp = float(spec.max_hp) * _armor_mult() * GenomeBonus.hp_mult(g),
		hp = float(spec.max_hp) * _armor_mult() * GenomeBonus.hp_mult(g),
		damage = float(spec.damage) * _weapon_mult() * GenomeBonus.dmg_mult(g),
		attack_range = float(spec.attack_range) * GenomeBonus.range_mult(g),
		attack_cd = float(spec.attack_cooldown), cd = 0.0,
		speed = float(spec.move_speed) * GenomeBonus.speed_mult(g), target = null,
		commanded = false, command_pos = Vector3.ZERO,
	}
	_units.append(entry)
	# If the training city has a rally point, the new unit walks there instead of loitering.
	var rally: Variant = _cities.back().get("rally")
	if rally is Vector3:
		_order_move(entry, rally)
	_update_status()


func _queue_building(name: String) -> void:
	if _cities.is_empty() or _build_queue.size() > 0: return
	if not BUILDINGS.has(name) and not DEFENSES.has(name): return
	var spec = BUILDINGS.get(name, DEFENSES.get(name))
	if not _can_afford(spec.cost): return
	_spend(spec.cost)
	_build_queue.append({name = name, time_left = BUILD_TIME})


# Resolve a model id to its res:// path. Dir-qualified ids ("generated/civ_modern/x") load from that
# pack; bare ids default to the Ultimate Fantasy RTS kit so existing call sites keep working.
func _model_path(model_id: String) -> String:
	if model_id.contains("/"):
		return MODELS_ROOT % model_id
	return CIV_BLDG % model_id


func _is_generated_civ_modern(model_id: String) -> bool:
	return model_id.begins_with(CIV_MODERN_PREFIX)


func _model_stem(model_id: String) -> String:
	return model_id.get_file().get_basename()


func _building_target_height(model_id: String, height_mult: float = 1.0) -> float:
	return BUILDING_TARGET_HEIGHT * float(BUILDING_HEIGHT_MULTIPLIERS.get(_model_stem(model_id), 1.0)) * height_mult


func _modern_target_height(model_id: String, height_mult: float = 1.0) -> float:
	return _building_target_height(model_id, height_mult)


# Bounding box of every mesh under `node`, in `node`-local space. Accumulates the FULL transform
# chain up to the root (not just each MeshInstance's local one) so a large scale parked on an
# intermediate node — common in these CC0 packs — is counted; otherwise the fit balloons ~100x.
func _root_aabb(node: Node3D) -> AABB:
	var box := AABB()
	var have := false
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for n in meshes:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = _local_to_root(mi, node) * mi.mesh.get_aabb()
		if not have:
			box = b
			have = true
		else:
			box = box.merge(b)
	return box if have else AABB(Vector3.ZERO, Vector3.ONE)


func _local_to_root(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != root:
		t = cur.transform * t
		cur = cur.get_parent() as Node3D
	return t


func _fit_and_seat(root: Node3D, height: float, footprint_tiles: float = 1.0) -> void:
	var box := _root_aabb(root)
	if box.size.y <= 0.001:
		return
	var scale_factor: float = height / box.size.y
	var footprint_dim: float = maxf(box.size.x, box.size.z)
	if footprint_dim > 0.001:
		var max_footprint: float = TILE_3D * minf(footprint_tiles, BUILDING_MAX_FOOTPRINT_TILES)
		scale_factor = minf(scale_factor, max_footprint / footprint_dim)
	root.scale = Vector3.ONE * scale_factor
	# Seat the middle of the model's base on the spot, whichever way the model is turned.
	var center := box.get_center()
	root.position -= root.basis * Vector3(center.x, box.position.y, center.z)


# Spawn a realistic building model normalized to ~a tile wide, feet on ground. Returns null if the
# kind has no realistic model (caller falls back to the Kenney kit — e.g. the Spaceport capstone).
func _real_building(kind: String, pos: Vector3) -> Node3D:
	if not REAL_BLDG.has(kind):
		return null
	return _civ_model(str(REAL_BLDG[kind]), pos, 0.95)


# Load + height-normalize any building model (by id), clamped to a fraction of the cell footprint.
func _civ_model(model_id: String, pos: Vector3, dim_frac: float = 1.0, height_mult: float = 1.0) -> Node3D:
	var is_modern_generated := _is_generated_civ_modern(model_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_bldg_yaw_%s_%d_%d" % [EvolutionState.world_seed, model_id, roundi(pos.x), roundi(pos.z)])
	var yaw := BUILDING_FACE_YAW + rng.randf_range(-BUILDING_FACE_JITTER, BUILDING_FACE_JITTER)
	var node := spawn_model(_model_path(model_id), pos, 1.0, 0.0 if is_modern_generated else yaw)
	if node == null:
		return null
	var target_height := _modern_target_height(model_id, height_mult) if is_modern_generated else _building_target_height(model_id, height_mult)
	_fit_and_seat(node, target_height, dim_frac)
	if is_modern_generated:
		node.rotation_degrees.y = yaw
	return node


# The player capital model for the current Age (grand cities get a bit more footprint).
func _capital_model(pos: Vector3) -> Node3D:
	var tier: int = clampi(_age, 0, CITY_TIERS.size() - 1)
	var frac: float = 0.95 + 0.06 * float(tier)   # later castles sprawl a touch larger
	return _civ_model(CITY_TIERS[tier], pos, frac, 1.25)


# Re-render a player city's central building to the current Age tier (called on age-up), and
# re-skin its surrounding props so the whole town modernises with the player, not just the keep.
func _upgrade_city_visual(c: Dictionary) -> void:
	var old: Node3D = c.get("node")
	var fresh := _capital_model(c.position)
	if fresh == null:
		return
	c.node = fresh
	if is_instance_valid(old):
		old.queue_free()
	_decorate_town(c)


# Decor pool appropriate to the current Age (clamped to the table).
func _town_decor_for_age() -> Array:
	return TOWN_DECOR_BY_AGE[clampi(_age, 0, TOWN_DECOR_BY_AGE.size() - 1)]


# Scatter a few age-appropriate props round `center`, one to a hex on the town's prop ring, and
# return the spawned nodes. Purely cosmetic (no game logic); sits clear of the central capital,
# its buildings and unit space. `seed_key` keeps each town's layout stable per age. Shared by
# player cities and rival cities.
func _scatter_decor(center: Vector3, age: int, seed_key: String) -> Array[Node3D]:
	var decor: Array[Node3D] = []
	var pool: Array = TOWN_DECOR_BY_AGE[clampi(age, 0, TOWN_DECOR_BY_AGE.size() - 1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key)
	var plots := _town_plots(_cell_at(center), true)
	for _i in mini(rng.randi_range(4, 6), plots.size()):
		var plot: Vector2i = plots.pop_at(rng.randi_range(0, plots.size() - 1))
		var p: Vector3 = _tile_pos(plot.x, plot.y) + _jitter(rng, TOWN_DECOR_JITTER)
		var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
		var n := _stand_decor(pick, p)
		if n != null:
			decor.append(n)
	return decor


# One prop, tagged with its model and spot so a save can stand it back up on the same hex.
func _stand_decor(model_id: String, spot: Vector3) -> Node3D:
	var n := _civ_model(model_id, spot, 0.55)
	if n != null:
		n.set_meta("model_id", model_id)
		n.set_meta("spot", spot)
	return n


# The open, flat, empty land hexes of the town round a capital, nearest first and the viewer's
# side before the far side. Props keep to one ring (`decor`), buildings and turrets take the
# rest; the capital's own hex and the six that touch it stay clear.
func _town_plots(city_cell: Vector2i, decor: bool) -> Array[Vector2i]:
	var center := _tile_pos(city_cell.x, city_cell.y)
	var gathered := {}   # hexes that hold berries, rocks or trees
	for res: String in _resource_nodes:
		for p: Vector3 in _resource_nodes[res]:
			gathered[_cell_at(p)] = true
	var reach := ceili(TOWN_REACH)
	var plots: Array[Vector2i] = []
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := city_cell + Vector2i(dx, dy)
			var steps := _tile_pos(cell.x, cell.y).distance_to(center) / HEX_COL_STEP
			if steps <= TOWN_PLAZA or steps > TOWN_REACH or (absf(steps - TOWN_DECOR_RING) < 0.1) != decor:
				continue
			if not _cell_walkable(cell) or _hill_cells.has(cell) or gathered.has(cell):
				continue
			plots.append(cell)
	var rank := func(cell: Vector2i) -> float:
		var off := _tile_pos(cell.x, cell.y) - center
		return snappedf(off.length(), 0.5) * 100.0 - off.z + off.x * 0.01
	plots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return rank.call(a) < rank.call(b))
	return plots


# Open land a unit can stand on: inside the map, not water or mountain, not a forest or a city.
func _cell_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return false
	return terrain_at(cell.x, cell.y) == Terrain.LAND and not _obstacle_cells.has(cell)


# The town hexes that already hold one of the player's buildings or a turret.
func _built_plots() -> Dictionary:
	var built := {}
	for c in _cities:
		for b: Node3D in c.buildings:
			built[b.get_meta("plot")] = true
	for u in _units:
		if DEFENSES.has(u.get("unit_type", "")) and not bool(u.get("dying", false)) and is_instance_valid(u.get("node")):
			built[_cell_at(u.node.position)] = true
	return built


# The hex a city's next building or turret goes on: the nearest open town hex (built hexes are
# blocked, so they never show up). A town that has run out of room doubles up on its capital's
# hex rather than refuse the build.
func _next_plot(city_cell: Vector2i) -> Vector2i:
	var plots := _town_plots(city_cell, false)
	return city_cell if plots.is_empty() else plots[0]


# Open a hex a building or turret stood on, unless a city holds it.
func _release_cell(cell: Vector2i) -> void:
	if _city_on_cell(cell):
		return
	_obstacle_cells.erase(cell)
	if _nav != null:
		_nav.set_point_solid(cell, false)


# Where a newly trained unit appears: an open hex touching the capital (the nearest open hexes
# further out if that ring is blocked), taking the hexes in turn. The base height is returned;
# `_set_on_ground` lifts the unit onto a hill. With no open hex it falls back to the old scatter.
func _spawn_spot(capital: Vector3, scatter: float) -> Vector3:
	var city_cell := _cell_at(capital)
	var best := INF
	var open: Array[Vector2i] = []
	for dy in range(-SPAWN_REACH, SPAWN_REACH + 1):
		for dx in range(-SPAWN_REACH, SPAWN_REACH + 1):
			var cell := city_cell + Vector2i(dx, dy)
			if cell == city_cell or not _cell_walkable(cell):
				continue
			var steps := snappedf(_tile_pos(cell.x, cell.y).distance_to(capital) / HEX_COL_STEP, 0.1)
			if steps > best:
				continue
			if steps < best:
				open.clear()
				best = steps
			open.append(cell)
	if open.is_empty():
		return capital + Vector3(randf_range(-scatter, scatter), 0.2, randf_range(-scatter, scatter))
	var turn: int = int(_spawn_turns.get(city_cell, 0))
	_spawn_turns[city_cell] = turn + 1
	var spot := open[turn % open.size()]
	var room := HEX_COL_STEP * 0.25   # keeps the jitter well inside the hex
	return _tile_pos(spot.x, spot.y) + Vector3(randf_range(-room, room), 0.2, randf_range(-room, room))


# Raise a node onto the hill rock under it; `_follow_ground` keeps it there as it walks.
func _set_on_ground(node: Node3D) -> void:
	var lift := _ground_lift(node.position)
	node.position.y += lift
	node.set_meta("ground_lift", lift)


# Stand a building's model on a free hex of its city's town.
func _place_building(city: Dictionary, kind: String) -> void:
	_stand_building(city, kind, _next_plot(city.cell))


func _stand_building(city: Dictionary, kind: String, plot: Vector2i) -> void:
	var bpos := _tile_pos(plot.x, plot.y)
	var b := _real_building(kind, bpos)
	if b == null:
		b = spawn_model(TD % str(BUILDING_MODELS.get(kind, "tower-round-base")), bpos, TILE_3D * 0.5, randf_range(0, 360))
	if b == null:
		return
	b.set_meta("plot", plot)
	b.set_meta("kind", kind)
	_mark_obstacle_cell(plot)
	city.buildings.append(b)


# (Re)decorate a player city; decor nodes are tracked on the city dict so an age-up can clear
# and re-scatter a more modern set.
func _decorate_town(city: Dictionary) -> void:
	for old in city.get("decor", []):
		if is_instance_valid(old):
			old.queue_free()
	var key := "town_%s_%s_%d" % [EvolutionState.world_seed, city.get("cell", Vector2i.ZERO), _age]
	city["decor"] = _scatter_decor(city.position, _age, key)


func _count_civ_building(id: String) -> void:
	if id.is_empty():
		return
	_civ_buildings_by_type[id] = int(_civ_buildings_by_type.get(id, 0)) + 1


func _uncount_civ_building(id: String) -> void:
	if not id.is_empty():
		_civ_buildings_by_type[id] = maxi(0, int(_civ_buildings_by_type.get(id, 0)) - 1)


func _climate_building_id(name: String) -> String:
	match name:
		"House":
			return "house"
		"Granary":
			return "farm"
		"Barracks":
			return "barracks"
		"Spaceport":
			return "castle"
		"LaserTurret", "TeslaCoil", "PrismTower":
			return "tower"
	return ""


func _complete_building(name: String) -> void:
	if _cities.is_empty():
		return   # last city lost while this build was queued — drop it rather than crash on .back()
	AudioManager.play_sfx("civ_build")
	if BUILDINGS.has(name):
		var spec: Dictionary = BUILDINGS[name]
		_place_building(_cities.back(), name)
		_count_civ_building(_climate_building_id(name))
		_structures.append({kind = name, cell = _cities.back().cell})
		match spec.effect:
			"popcap":
				_cities.back().max_population += int(spec.value) * _cities.size()   # the same total, held by this city so razing it takes it back
			"food_rate":
				_granary_bonus += float(spec.value)
			"military":
				_has_barracks = true
			"spaceport":
				_has_spaceport = true
				StageObjectives.complete("civ_spaceport", "Spaceport online")
				if _cities.size() >= WIN_CITY_COUNT and _rivals_beaten() >= WIN_RIVALS_BEATEN:
					Events.notify.emit("Spaceport + cities + a beaten rival — LAUNCH path open (or finish conquest).")
				else:
					Events.notify.emit("Spaceport online — launch needs %d cities and %d rival eliminated" % [WIN_CITY_COUNT, WIN_RIVALS_BEATEN])
	elif DEFENSES.has(name):
		var spec: Dictionary = DEFENSES[name]
		var model: String = DEFENSE_MODELS.get(name, "weapon-turret")
		var plot := _next_plot(_cities.back().cell)
		var node := spawn_model(TD % model, _tile_pos(plot.x, plot.y), TILE_3D * 0.5, randf_range(0, 360))
		if node == null: return
		_mark_obstacle_cell(plot)
		_count_civ_building(_climate_building_id(name))
		var entry := {
			node = node, faction = 0, unit_type = name,
			max_hp = float(spec.max_hp) * _armor_mult(),
			hp = float(spec.max_hp) * _armor_mult(),
			damage = float(spec.damage) * _weapon_mult(),
			attack_range = float(spec.attack_range),
			attack_cd = float(spec.attack_cooldown), cd = 0.0,
			speed = 0.0, target = null,
			commanded = false, command_pos = Vector3.ZERO,
		}
		_units.append(entry)
	_update_status()


func _research() -> void:
	if _tech_index >= TECHS.size(): return
	var tech: Dictionary = TECHS[_tech_index]
	if not _can_afford({food = int(tech.cost)}): return
	_spend({food = int(tech.cost)})
	match str(tech.effect):
		"production":
			_bonus_production += int(tech.value)
			for c in _cities: c.production_rate += int(tech.value)
		"defense":
			_defense_bonus += int(tech.value)
		"population":
			for c in _cities: c.max_population += int(tech.value)
	_tech_index += 1
	_update_status()
	Events.tech_researched.emit(str(tech.get("name", "Tech")))


func _advance_age() -> void:
	if _age + 1 >= AGES.size(): return
	if _tech_index <= _age: return   # the age's tech comes first
	var next := _age + 1
	if not _can_afford({food = AGE_COST[next]}): return
	_spend({food = AGE_COST[next]})
	_age = next
	for c in _cities:
		if int(c.get("faction", 0)) == 0:
			_upgrade_city_visual(c)   # capital grows: settlement → … → grand castle
			_pulse_city_age_glow(c)
	for c in _cities: c.production_rate += 1
	for u in _units:
		if u.faction != 0: continue
		u.max_hp += 0.15 * u.max_hp
		u.hp = u.max_hp
	_update_status()
	AudioManager.play_sfx("civ_ageup")
	Events.notify.emit("Age of %s begins — cities shine with progress." % AGES[_age])
	_toast_age_unlocks(_age)
	StageObjectives.complete("civ_ageup", "Advanced to %s" % AGES[_age])


## List units/defenses whose min_age matches the new era so age-ups feel like unlocks.
func _toast_age_unlocks(age: int) -> void:
	var unlocked: PackedStringArray = []
	for uname in UNITS.keys():
		var spec: Dictionary = UNITS[uname]
		if int(spec.get("min_age", 0)) == age:
			unlocked.append(str(uname))
	for dname in DEFENSES.keys():
		var dspec: Dictionary = DEFENSES[dname]
		if int(dspec.get("min_age", 0)) == age:
			unlocked.append(str(dname))
	# Buildings gated by age (e.g. Spaceport at 5).
	for bname in BUILDINGS.keys():
		var bspec: Dictionary = BUILDINGS[bname]
		if int(bspec.get("min_age", 0)) == age:
			unlocked.append(str(bname))
	if unlocked.is_empty():
		return
	Events.notify.emit("Unlocked (Age %s): %s" % [AGES[age], ", ".join(unlocked)])
	StageObjectives.complete("civ_age_unlock_%d" % age, "Unlocked %s-era units" % AGES[age])


## Brief gold/cyan corona under player cities when the era advances.
func _pulse_city_age_glow(city: Dictionary) -> void:
	var node: Node3D = city.get("node")
	if not is_instance_valid(node):
		return
	var glow: MeshInstance3D = node.get_node_or_null("AgeGlow")
	if glow == null:
		glow = MeshInstance3D.new()
		glow.name = "AgeGlow"
		var torus := TorusMesh.new()
		torus.inner_radius = 1.6
		torus.outer_radius = 2.2
		glow.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.albedo_color = Color(1.0, 0.85, 0.35, 0.75)
		mat.emission = Color(1.0, 0.82, 0.3)
		mat.emission_energy_multiplier = 3.5
		glow.material_override = mat
		glow.position = Vector3(0, 0.12, 0)
		node.add_child(glow)
	else:
		var mat2: StandardMaterial3D = glow.material_override as StandardMaterial3D
		if mat2 != null:
			mat2.emission_energy_multiplier = 3.5
			mat2.albedo_color.a = 0.75
	glow.visible = true
	var mat3: StandardMaterial3D = glow.material_override as StandardMaterial3D
	if mat3 == null:
		return
	var tw := glow.create_tween()   # bound to the glow: dies with it if a quick age-up swaps the model
	tw.tween_property(mat3, "emission_energy_multiplier", 0.6, 1.4)
	tw.parallel().tween_property(mat3, "albedo_color:a", 0.0, 1.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(glow):
			glow.visible = false)


func _weapon_mult() -> float: return pow(1.2, _weapon_tier)
func _armor_mult() -> float: return pow(1.2, _armor_tier)
func _upgrade_cost(tier: int) -> Dictionary: return {wood = 3 * (tier + 1), stone = 2 * (tier + 1)}


func _buy_weapon_upgrade() -> void:
	var c := _upgrade_cost(_weapon_tier)
	if not _can_afford(c): return
	_spend(c)
	_weapon_tier += 1
	for u in _units:
		if u.faction == 0:
			u.damage *= 1.2
			if int(u.get("veterancy", 0)) > 0:
				_refresh_veteran_glow(u, true)
	Events.notify.emit("Weapons +%d — army edge sharpened." % _weapon_tier)


func _buy_armor_upgrade() -> void:
	var c := _upgrade_cost(_armor_tier)
	if not _can_afford(c): return
	_spend(c)
	_armor_tier += 1
	Events.notify.emit("Armor +%d — veterans hold the line." % _armor_tier)
	for u in _units:
		if u.faction == 0:
			u.max_hp *= 1.2
			u.hp *= 1.2


func _now() -> float: return _elapsed
func _truce_active() -> bool: return _now() < _truce_until


func _offer_truce() -> void:
	if _truce_active() or not _can_afford(TRUCE_COST): return
	_spend(TRUCE_COST)
	_truce_until = _now() + TRUCE_DURATION


## Dual-win meter: spaceflight (cities + Spaceport) vs conquest (rivals eliminated).
func _win_paths_readout() -> String:
	var space_bit: String
	var beaten: String = "rivals beaten %d/%d" % [mini(_rivals_beaten(), WIN_RIVALS_BEATEN), WIN_RIVALS_BEATEN]
	if _launch_ready():
		space_bit = "Spaceport READY — Launch"
	elif _has_spaceport:
		space_bit = "Spaceport online · cities %d/%d · %s" % [_cities.size(), WIN_CITY_COUNT, beaten]
	else:
		var age_need: String = "need Age 5+" if _age < 5 else "build Spaceport"
		space_bit = "Spaceflight: cities %d/%d · %s · %s" % [_cities.size(), WIN_CITY_COUNT, beaten, age_need]
	var alive_rivals: int = 0
	for r in _rivals:
		if not (r.cities as Array).is_empty():
			alive_rivals += 1
	var conquest_bit: String = "Conquest: %d rival%s left" % [alive_rivals, "" if alive_rivals == 1 else "s"]
	if alive_rivals == 0:
		conquest_bit = "Conquest: planet secured"
	return "%s\n%s" % [space_bit, conquest_bit]


func _win_civ(kind: String) -> void:
	if _stage_done: return
	_stage_done = true
	EvolutionState.civ_cities = _cities.size()
	EvolutionState.civ_age = _age
	EvolutionState.civ_army = _units.size()
	EvolutionState.civ_victory = kind
	StageObjectives.complete("civ_win", "Homeworld secured via %s" % kind)
	var roster := {}
	for u in _units:
		if u.faction == 0:
			var t: String = u.unit_type
			roster[t] = int(roster.get(t, 0)) + 1
	EvolutionState.civ_army_roster = roster
	var vet_total := 0
	for u in _units:
		if u.faction == 0: vet_total += int(u.get("veterancy", 0))
	EvolutionState.civ_army_veterancy = vet_total
	EvolutionState.civ_weapon_tier = _weapon_tier
	EvolutionState.civ_armor_tier = _armor_tier
	EvolutionState.civ_planet_snapshot = _planet_snapshot()
	if kind == "spaceflight":
		Events.notify.emit("★ Launch window open — the stars await.")
	else:
		Events.notify.emit("★ Planet secured by conquest — ascend.")
	AudioManager.play_sfx("win")
	Events.stage_complete.emit(EvolutionState.current_stage)


## City cells + the buildings of cities still held, redrawn modern by Space's HomePlanetView.
func _planet_snapshot() -> Dictionary:
	var snap := {cities = [], structures = []}
	for c in _cities: snap.cities.append(c.cell)
	for st in _structures:
		if snap.cities.has(st.cell):
			snap.structures.append(st.duplicate())
	return snap


## Rival nations with every city razed.
func _rivals_beaten() -> int:
	var n: int = 0
	for r in _rivals:
		if (r.cities as Array).is_empty():
			n += 1
	return n


func _launch_ready() -> bool:
	return _has_spaceport and _cities.size() >= WIN_CITY_COUNT and _rivals_beaten() >= WIN_RIVALS_BEATEN


func launch_to_space() -> void:
	if not _launch_ready(): return
	_win_civ("spaceflight")


func _launch_to_space() -> void:
	GameShell.confirm("Launch to Space now?\nThis ends the conquest of your homeworld and begins the galactic finale.", launch_to_space)


# --- Rival AI ---

func _rival_archetype_pool() -> Array:
	var pool: Array = []
	for row in Genome.LINEAGES.values():
		if row.has("civ_archetype"):
			pool.append(row["civ_archetype"])
	pool.append({archetype = "tribe", tint = Color(0.85, 0.55, 0.40), prefer = "Archer", hp_mult = 1.0, dmg_mult = 1.0, aggression = 0.6, expand = 0.40, train_interval = 3.5})
	return pool


func _spawn_rivals() -> void:
	var pool := _rival_archetype_pool()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_rivalcivs" % EvolutionState.world_seed)
	var n := mini(RIVAL_COUNT, pool.size())
	for i in n:
		var idx := rng.randi_range(0, pool.size() - 1)
		var cfg: Dictionary = pool[idx]
		pool.remove_at(idx)
		var lands := _land_tiles()
		if lands.is_empty(): continue
		var cell := _rival_start_cell(i)
		var pos := _tile_pos(cell.x, cell.y)
		var fac := i + 1
		var color: Color = cfg.get("tint", FACTION_COLORS[fac % FACTION_COLORS.size()])
		var archetype := str(cfg.get("archetype", "tribe"))
		var prefer := str(cfg.get("prefer", "Soldier"))
		var rng3 := RandomNumberGenerator.new()
		rng3.seed = hash("%s_rival_%d" % [EvolutionState.world_seed, fac])
		var r := {
			faction = fac, cities = [], city_nodes = [], city_decor = [], city_targets = [],
			treasury = 8.0, age = 0, age_t = 0.0,
			train_t = 0.0, think_t = 0.0, expand_salt = 0,
			tint = color, archetype = archetype, prefer = prefer,
			hp_mult = float(cfg.get("hp_mult", 1.0)), dmg_mult = float(cfg.get("dmg_mult", 1.0)),
			aggression = float(cfg.get("aggression", 0.6)), expand = float(cfg.get("expand", 0.4)),
			train_interval = float(cfg.get("train_interval", 3.5)) * RIVAL_TRAIN_INTERVAL_MULT,
			units = [], rng = rng3, model_army = 0, last_action = "founding",
		}
		_rival_add_city(r, pos)
		_rivals.append(r)


# Age-appropriate rival capital (same tier ladder as the player's). Kept textured — distinguished
# by its surrounding faction-tinted units rather than a flat building tint (which would erase the art).
func _rival_capital(pos: Vector3, age: int) -> Node3D:
	var tier: int = clampi(age, 0, CITY_TIERS.size() - 1)
	var node := _civ_model(CITY_TIERS[tier], pos, 0.95 + 0.06 * float(tier), 1.25)
	if node == null:
		node = Node3D.new()
		node.position = pos
		add_child(node)
	return node


# Found a new rival city: build its age-tier capital + matching town decor, tracked in parallel
# arrays on the rival so an age-up can re-skin every one of its settlements.
func _rival_add_city(r: Dictionary, pos: Vector3) -> void:
	r.cities.append(pos)
	var cell := _cell_at(pos)
	_dress_city_roads(cell)
	_mark_obstacle_cell(cell)   # units path around rival cities too
	r.city_nodes.append(_rival_capital(pos, int(r.age)))
	# A live target dict so the city is attackable (conquest): real hp, dies by razing.
	r.city_targets.append({
		node = r.city_nodes.back(), hp = CITY_MAX_HP, max_hp = CITY_MAX_HP,
		position = pos, rival_owner = r,
	})
	var key := "rivaltown_%d_%d_%d" % [int(r.faction), r.cities.size(), int(r.age)]
	r.city_decor.append(_scatter_decor(pos, int(r.age), key))


# On a rival age-up, re-render each of its cities (capital + decor) to the new, more modern tier.
func _upgrade_rival_visual(r: Dictionary) -> void:
	for i in r.cities.size():
		var pos: Vector3 = r.cities[i]
		var old: Node3D = r.city_nodes[i]
		r.city_nodes[i] = _rival_capital(pos, int(r.age))
		if i < r.city_targets.size():
			r.city_targets[i]["node"] = r.city_nodes[i]   # keep the attack target's node live
		if is_instance_valid(old):
			old.queue_free()
		for d in r.city_decor[i]:
			if is_instance_valid(d):
				d.queue_free()
		var key := "rivaltown_%d_%d_%d" % [int(r.faction), i + 1, int(r.age)]
		r.city_decor[i] = _scatter_decor(pos, int(r.age), key)


func _rival_unit_for_age(r: Dictionary) -> String:
	var ladder: Array = RANGED_LADDER if r.prefer == "Archer" else MELEE_LADDER
	var pick: String = ladder[0][1]
	for entry in ladder:
		if r.age >= int(entry[0]): pick = str(entry[1])
	return pick


func _rival_spawn_unit(r: Dictionary) -> void:
	if r.cities.is_empty(): return
	var name := _rival_unit_for_age(r)
	var spec: Dictionary = UNITS.get(name, {})
	if spec.is_empty(): return
	var home: Vector3 = r.cities[0]
	var pos := _spawn_spot(home, 3.0)
	# Rivals render as their archetype's rigged species mesh (animated), distinct per lineage.
	var node: Node3D = _spawn_species_unit(str(RIVAL_SPECIES.get(str(r.archetype), "human")), pos)
	if node == null: return
	_set_on_ground(node)
	_apply_unit_identity(node, name, int(r.faction))   # per-type scale + emissive role prop (rival)
	var entry := {
		node = node, faction = r.faction, unit_type = name,
		max_hp = float(spec.max_hp) * r.hp_mult,
		hp = float(spec.max_hp) * r.hp_mult,
		damage = float(spec.damage) * r.dmg_mult,
		attack_range = float(spec.attack_range),
		attack_cd = float(spec.attack_cooldown), cd = 0.0,
		speed = float(spec.move_speed), target = null,
		commanded = false, command_pos = Vector3.ZERO,
	}
	_units.append(entry)
	r.units.append(entry)


func _rival_expand(r: Dictionary) -> void:
	var lands := _land_tiles()
	if lands.is_empty(): return
	# Only settle genuinely free cells — obstacle cells hold existing cities (player or rival)
	# or blocking props, and stacking a second capital on one produced overlapping towns.
	var free: Array = []
	for c in lands:
		if not _obstacle_cells.has(c):
			free.append(c)
	if free.is_empty(): return
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = hash("%s_rivalcell_%d" % [EvolutionState.world_seed, r.faction * 100 + r.expand_salt])
	r.expand_salt += 1
	var cell: Vector2i = free[rng2.randi_range(0, free.size() - 1)]
	var pos := _tile_pos(cell.x, cell.y)
	_rival_add_city(r, pos)


func _rival_order_attack(r: Dictionary) -> void:
	if r.cities.is_empty(): return
	if _truce_active() or _now() < float(_at_peace.get(r.faction, 0.0)): return
	var from: Vector3 = r.cities[0]
	# Prefer weak / underdefended player cities over pure nearest (real siege pressure).
	var best := Vector3.ZERO
	var best_score := -INF
	var target_label := "your forces"
	for c in _cities:
		if bool(c.get("dying", false)):
			continue
		if not is_instance_valid(c.get("node")):
			continue
		var max_hp: float = maxf(1.0, float(c.get("max_hp", CITY_MAX_HP)))
		var hp: float = float(c.get("hp", max_hp))
		var frac: float = hp / max_hp
		var guards := 0
		for u in _units:
			if int(u.get("faction", -1)) != 0 or float(u.get("hp", 0.0)) <= 0.0:
				continue
			if not is_instance_valid(u.get("node")):
				continue
			if u.node.position.distance_to(c.position) < 28.0:
				guards += 1
		var dist: float = from.distance_to(c.position)
		# Higher score = better attack target: low HP, few guards, not too far.
		var score: float = (1.15 - frac) * 40.0 - float(guards) * 6.0 - dist * 0.04
		if score > best_score:
			best_score = score
			best = c.position
			target_label = "a city (%.0f%% HP · %d guards)" % [frac * 100.0, guards]
	# Fall back: nearest player unit if no cities (should be rare mid-run).
	if best == Vector3.ZERO:
		var best_d := INF
		for u in _units:
			if u.faction != 0 or not is_instance_valid(u.node):
				continue
			var d: float = from.distance_squared_to(u.node.position)
			if d < best_d:
				best_d = d
				best = u.node.position
				target_label = "your army"
	if best == Vector3.ZERO:
		best = _grid_offset + Vector3(COLS * TILE_3D, 0, ROWS * TILE_3D) * 0.5
	var marched := 0
	for ue in r.units:
		if is_instance_valid(ue.node):
			_order_move(ue, best)   # routed attack-move
			marched += 1
	if marched > 0:
		Events.notify.emit("⚔ %s sieges %s — %d units · B to drop in" % [
			_rival_short_name(r), target_label, marched])


func _tick_rivals(delta: float) -> void:
	for r in _rivals:
		if r.cities.is_empty(): continue
		r.treasury += (r.cities.size() * RIVAL_INCOME_PER_CITY + 0.3) * delta
		if r.age < 5:
			r.age_t += delta
			if r.age_t >= RIVAL_AGE_INTERVAL:
				r.age_t = 0
				r.age += 1
				_upgrade_rival_visual(r)   # rival town modernises with its age, like the player's


# --- Roamers ---

func _spawn_bandit() -> void:
	var pos := _grid_offset + Vector3(randf_range(0, COLS * TILE_3D), 0, randf_range(0, ROWS * TILE_3D))
	var node := spawn_model(TD % BANDIT_MODEL, pos + Vector3(0, 0.3, 0), 0.6, 0, Color(0.6, 0.45, 0.3))
	if node == null: return
	var entry := {
		node = node, faction = BANDIT_FAC, unit_type = "Bandit",
		max_hp = 50.0, hp = 50.0, damage = 8.0,
		attack_range = 3.5, attack_cd = 1.0, cd = 0.0,
		speed = 8.0, target = null,
		commanded = false, command_pos = Vector3.ZERO,
	}
	_units.append(entry)
	_bandits.append(entry)
	if not _cities.is_empty():
		var target_pos: Vector3 = _cities[randi() % _cities.size()].position
		_order_move(entry, target_pos)   # march on a city, routing around obstacles
		Events.notify.emit("⚔ Bandits ride for your cities — train troops or drop in (B)")
		StageObjectives.complete("civ_bandits", "Bandits on the map — defend the realm")


func _spawn_wildlife() -> void:
	var roll := randf()
	var kind := "deer"
	if roll > 0.40: kind = "stag"
	if roll > 0.55: kind = "fox"
	if roll > 0.70: kind = "boar"
	if roll > 0.85: kind = "wolf"
	# Only the wolf deals damage — every other animal is passive prey (it just roams/flees).
	var stats := {
		"deer": {hp = 12.0, dmg = 0.0, spd = 10.0}, "stag": {hp = 18.0, dmg = 0.0, spd = 9.0},
		"fox": {hp = 8.0, dmg = 0.0, spd = 12.0}, "boar": {hp = 45.0, dmg = 0.0, spd = 5.5},
		"wolf": {hp = 22.0, dmg = 6.0, spd = 11.0},
	}
	var s: Dictionary = stats[kind]
	var tints := {
		"deer": Color(0.72, 0.56, 0.36), "stag": Color(0.6, 0.45, 0.3), "fox": Color(0.85, 0.45, 0.2),
		"boar": Color(0.4, 0.3, 0.25), "wolf": Color(0.55, 0.55, 0.62),
	}
	var pos := _grid_offset + Vector3(randf_range(0, COLS * TILE_3D), 0, randf_range(0, ROWS * TILE_3D))
	var node: Node3D = AnimalModels.attach(self, kind, TILE_3D * 0.28)
	if node == null:
		node = spawn_model(TD % "detail-rocks-large", pos + Vector3(0, 0.2, 0), 0.5, 0)
	if node != null:
		node.position = pos
	if node == null: return
	node.set_meta("wild", true)
	node.set_meta("food", {"deer": 4, "stag": 6, "fox": 2, "boar": 10, "wolf": 3}.get(kind, 4))
	var entry := {
		node = node, faction = WILD_FAC if kind != "wolf" else PREDATOR_FAC,
		unit_type = kind, max_hp = s.hp, hp = s.hp, damage = s.dmg,
		attack_range = 3.5, attack_cd = 1.0, cd = 0.0,
		speed = s.spd, target = null,
		commanded = false, command_pos = Vector3.ZERO,
	}
	_units.append(entry)
	_wildlife.append(entry)


func _tick_roamers(delta: float) -> void:
	_bandit_t -= delta
	if _bandit_t <= 0.0:
		_bandit_t = randf_range(BANDIT_SPAWN_MIN, BANDIT_SPAWN_MAX)
		if _bandits.size() < MAX_BANDITS: _spawn_bandit()
	_wildlife_t -= delta
	if _wildlife_t <= 0.0:
		_wildlife_t = randf_range(WILDLIFE_SPAWN_MIN, WILDLIFE_SPAWN_MAX)
		if _wildlife.size() < MAX_WILDLIFE: _spawn_wildlife()
		for w in _wildlife:
			if is_instance_valid(w.node):
				var target := _grid_offset + Vector3(randf_range(0, COLS * TILE_3D), 0, randf_range(0, ROWS * TILE_3D))
				_order_move(w, target)   # wander, routing around water/obstacles
	_bandits = _bandits.filter(func(b): return is_instance_valid(b.node))
	_wildlife = _wildlife.filter(func(w): return is_instance_valid(w.node))


func _tick_diplomacy(delta: float) -> void:
	_diplo_t -= delta
	if _diplo_t > 0.0 or _offer_pending or _truce_active(): return
	_diplo_t = randf_range(DIPLOMACY_INTERVAL_MIN, DIPLOMACY_INTERVAL_MAX)
	var mine := _cities.size()
	for r in _rivals:
		if r.cities.is_empty(): continue
		var theirs: int = r.cities.size()
		if theirs > 0 and theirs < mine:
			_offer_pending = true
			var bribe := 6 + maxi(1, mine - theirs) * 4
			var rival_name: String = Genome.archetype_label(str(r.archetype))
			GameShell.confirm("%s sues for peace — offering %d food.\nAccept a truce (%ds)?" % [rival_name, bribe, int(PEACE_DURATION)],
				func() -> void:
					_at_peace[r.faction] = _now() + PEACE_DURATION
					_res_f["food"] += float(bribe)
					_res["food"] = int(_res_f["food"])
					_offer_pending = false,
				func() -> void: _offer_pending = false,
				"Accept", "Decline")
			return


func _check_endgame() -> void:
	if _stage_done: return
	# Spaceflight is won only by pressing Launch (launch_to_space) — the player picks the moment.
	var alive := 0
	for r in _rivals:
		if not r.cities.is_empty(): alive += 1
	if alive == 0:
		_win_civ("conquest")


## Combat-kill routing: unit targets die via the death sequence; city targets are RAZED —
## torn out of the owning side's city list so they stop producing income, housing, and
## win-condition count (the old 999hp throwaway wrappers left immortal "ghost cities").
func _kill_target(t: Dictionary) -> void:
	if t.has("rival_owner"):
		_raze_rival_city(t["rival_owner"], t)
	elif _cities.has(t):
		_on_city_destroyed(t.cell)
	else:
		_begin_death(t)


## Raze a player city: burn the capital (death-fade), free decor + rally marker, reopen its
## nav cell, and drop it from _cities. Losing the last city with no settler in reserve = defeat.
func _on_city_destroyed(cell: Vector2i) -> void:
	var idx := -1
	for i in _cities.size():
		if _cities[i].cell == cell: idx = i; break
	if idx < 0: return
	var c := _cities[idx]
	_cities.remove_at(idx)
	_begin_death(c)   # fades + frees the capital node; marks the dict dying/hp=0
	for d in c.get("decor", []):
		if is_instance_valid(d): d.queue_free()
	for b: Node3D in c.get("buildings", []):
		if is_instance_valid(b):
			_release_cell(b.get_meta("plot", cell))
			_take_back_building(str(b.get_meta("kind", "")))
			b.queue_free()
	for i in range(_structures.size() - 1, -1, -1):
		if _structures[i].cell == cell:
			_structures.remove_at(i)
	_has_barracks = _any_city_has("Barracks")
	_has_spaceport = _any_city_has("Spaceport")
	_raze_turrets_of(c)
	var marker: Node3D = c.get("rally_marker")
	if is_instance_valid(marker): marker.queue_free()
	_obstacle_cells.erase(cell)
	if _nav != null:
		_nav.set_point_solid(cell, false)
	EvolutionState.civ_cities = _cities.size()
	Events.notify.emit("🔥 Your city has fallen! %d remain — train a Settler or counterattack." % _cities.size())
	AudioManager.play_sfx("lose")
	_update_status()
	if _cities.is_empty() and _settler == null and not _stage_done:
		_stage_done = true
		Events.game_lost.emit("Your civilization was wiped from the planet.")


# Undo what one building of a razed city gave: its food rate and its emissions.
func _take_back_building(kind: String) -> void:
	if not BUILDINGS.has(kind):
		return
	if BUILDINGS[kind].effect == "food_rate":
		_granary_bonus = maxf(0.0, _granary_bonus - float(BUILDINGS[kind].value))
	_uncount_civ_building(_climate_building_id(kind))


func _any_city_has(kind: String) -> bool:
	for city: Dictionary in _cities:
		for b: Node3D in city.buildings:
			if is_instance_valid(b) and b.get_meta("kind", "") == kind:
				return true
	return false


# The turrets of a razed city fall with it: those nearer to it than to any city that remains.
func _raze_turrets_of(razed: Dictionary) -> void:
	for u: Dictionary in _units:
		var node: Node3D = u.get("node")
		if int(u.get("faction", -1)) != 0 or not DEFENSES.has(u.get("unit_type", "")) or bool(u.get("dying", false)) or not is_instance_valid(node):
			continue
		var kept := INF
		for city: Dictionary in _cities:
			kept = minf(kept, node.position.distance_squared_to(city.position))
		if node.position.distance_squared_to(razed.position) < kept:
			_uncount_civ_building(_climate_building_id(str(u.unit_type)))
			_begin_death(u)


## Raze a rival city: burn the capital, free its decor, reopen the nav cell, and remove it from
## the rival's parallel arrays. A rival with no cities left is eliminated (conquest progress).
func _raze_rival_city(r: Dictionary, t: Dictionary) -> void:
	var i: int = r.city_targets.find(t)
	if i < 0:
		return
	_begin_death(t)   # fades + frees r.city_nodes[i] via the target's node ref
	for d in r.city_decor[i]:
		if is_instance_valid(d): d.queue_free()
	var cell := _cell_at(r.cities[i])
	_obstacle_cells.erase(cell)
	if _nav != null:
		_nav.set_point_solid(cell, false)
	r.cities.remove_at(i)
	r.city_nodes.remove_at(i)
	r.city_decor.remove_at(i)
	r.city_targets.remove_at(i)
	var remaining: int = int((r.get("cities", []) as Array).size())
	if remaining <= 0:
		Events.notify.emit("Conquest: %s eliminated!" % _rival_short_name(r))
		if _launch_ready() and _rivals_beaten() == WIN_RIVALS_BEATEN:
			Events.notify.emit("A rival is beaten — Launch to Space is open.")
		AudioManager.play_sfx("win")
	else:
		Events.notify.emit("Razed a %s city — %d left." % [_rival_short_name(r), remaining])
	StageObjectives.complete("civ_raze", "Razed a rival city — conquest path open")
	_update_status()
	_check_endgame()


# --- Combat ---

func _find_enemy(from: Vector3, faction: int, aggro: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := aggro * aggro
	for u in _units:
		if u.faction == faction or u.hp <= 0: continue
		if not is_instance_valid(u.node): continue
		var d := from.distance_squared_to(u.node.position)
		if d < best_d: best_d = d; best = u
	# Player cities are real targets (the dict itself carries hp/max_hp) — a razed city is
	# removed from _cities entirely (no 999hp ghosts that keep producing after burning).
	for c in _cities:
		if c.faction == faction: continue
		if bool(c.get("dying", false)): continue
		if not is_instance_valid(c.node): continue
		var d := from.distance_squared_to(c.position)
		if d < best_d: best_d = d; best = c
	# Rival cities are conquest targets too — razing all of a rival's cities eliminates them.
	# Only the player razes them: rival infighting must not hand out conquest progress.
	if faction != 0:
		return best
	for r in _rivals:
		if int(r.faction) == faction: continue
		for t: Dictionary in r.get("city_targets", []):
			if bool(t.get("dying", false)): continue
			if not is_instance_valid(t.get("node")): continue
			var d := from.distance_squared_to(t.position)
			if d < best_d: best_d = d; best = t
	return best


# --- Pathfinding (AStarGrid2D over the tile grid) ---

# Build the walkability grid: water/mountain tiles and any registered obstacle cells are solid.
func _build_nav() -> void:
	_nav = AStarGrid2D.new()
	_nav.region = Rect2i(0, 0, COLS, ROWS)
	_nav.cell_size = Vector2(TILE_3D, TILE_3D)
	_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_nav.update()
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var solid: bool = terrain_at(x, y) != Terrain.LAND or _obstacle_cells.has(cell)
			_nav.set_point_solid(cell, solid)


func _mark_obstacle_cell(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return
	_obstacle_cells[cell] = true
	if _nav != null:
		_nav.set_point_solid(cell, true)


# Safety net: after nav is built, confirm the player clearing can reach every other spawn clearing
# and the map center. If a forest belt sealed a region, clear tree obstacles along a real land route;
# water/mountain terrain stays solid and the belts still shape lanes everywhere else.
func _ensure_traversable() -> void:
	if _nav == null:
		return
	var clearings := _reserved_clearings()
	if clearings.is_empty():
		return
	var hub := _nearest_walkable(clearings[0])
	if hub.x < 0:
		hub = _nearest_walkable(Vector2i(COLS / 2, ROWS / 2))
	if hub.x < 0:
		return
	var targets: Array[Vector2i] = [Vector2i(COLS / 2, ROWS / 2)]
	for i in range(1, clearings.size()):
		targets.append(clearings[i])
	for tgt in targets:
		var t := _connected_land_near(tgt, clearings[0])
		if t.x < 0:
			continue
		if _nav.get_id_path(hub, t).is_empty():
			_carve_corridor(hub, t)
		if _nav.get_id_path(hub, t).is_empty():
			push_error("Civ layout target remains unreachable after corridor repair: %s" % t)


# Open a 1-cell corridor along a terrain-valid route by clearing only generated prop obstacles.
func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	for c in _terrain_route(a, b):
		if _obstacle_cells.has(c) and terrain_at(c.x, c.y) == Terrain.LAND:
			_obstacle_cells.erase(c)
			_nav.set_point_solid(c, false)


func _terrain_route(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if terrain_at(a.x, a.y) != Terrain.LAND or terrain_at(b.x, b.y) != Terrain.LAND:
		return empty
	var came_from: Dictionary[Vector2i, Vector2i] = {a: a}
	var frontier: Array[Vector2i] = [a]
	var head := 0
	while head < frontier.size() and not came_from.has(b):
		var current := frontier[head]
		head += 1
		for dir in DIRS4:
			var next := current + dir
			if next.x < 0 or next.y < 0 or next.x >= COLS or next.y >= ROWS:
				continue
			if came_from.has(next) or terrain_at(next.x, next.y) != Terrain.LAND:
				continue
			came_from[next] = current
			frontier.append(next)
	if not came_from.has(b):
		return empty
	var route: Array[Vector2i] = []
	var cell := b
	while cell != a:
		route.push_front(cell)
		cell = came_from[cell]
	route.push_front(a)
	return route


# Nearest non-solid cell to `cell` (so a unit standing on / commanded onto a blocked tile still
# gets a usable path endpoint). Returns (-1,-1) if nothing free is found nearby.
func _nearest_walkable(cell: Vector2i) -> Vector2i:
	cell.x = clampi(cell.x, 0, COLS - 1)
	cell.y = clampi(cell.y, 0, ROWS - 1)
	if not _nav.is_point_solid(cell):
		return cell
	for r in range(1, 7):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := Vector2i(cell.x + dx, cell.y + dy)
				if c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS and not _nav.is_point_solid(c):
					return c
	return Vector2i(-1, -1)


# World-space waypoints from `from` to `to`, routing around solid cells. Falls back to a straight
# line if no grid or no route exists.
func _find_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _nav == null:
		out.append(to)
		return out
	var fc := _nearest_walkable(_cell_at(from))
	var tc := _nearest_walkable(_cell_at(to))
	if fc.x < 0 or tc.x < 0:
		out.append(to)
		return out
	var cells := _nav.get_id_path(fc, tc)
	for i in range(1, cells.size()):   # skip the cell the unit already stands in
		out.append(_tile_pos(cells[i].x, cells[i].y))
	out.append(to)                     # exact destination for precise arrival/melee
	return out


# Issue a move order with a routed path (replaces bare commanded/command_pos assignment).
func _order_move(u: Dictionary, dest: Vector3) -> void:
	if not is_instance_valid(u.get("node")):
		return   # unit died between selection and this command — don't deref a freed node
	u["commanded"] = true
	u["command_pos"] = dest
	u["path"] = _find_path(u.node.position, dest)
	u["path_i"] = 0


# Step a unit along its routed path; returns true when the final waypoint is reached.
func _follow_path(u: Dictionary, delta: float) -> bool:
	var path: Array = u.get("path", [])
	var i: int = u.get("path_i", 0)
	if path.is_empty() or i >= path.size():
		return _step_toward(u.node, u.command_pos, u.speed, delta)
	if _step_toward(u.node, path[i], u.speed, delta):
		u["path_i"] = i + 1
		return u.path_i >= path.size()
	return false


# Chase a (possibly moving) destination via pathfinding, recomputing on a throttle or when the
# target drifts more than a tile — routes chasers around water/obstacles, not straight through them.
func _pathed_step(u: Dictionary, dest: Vector3, delta: float) -> void:
	u["repath_t"] = float(u.get("repath_t", 0.0)) - delta
	var pd: Variant = u.get("path_dest", null)
	var stale: bool = (
		(u.get("path", []) as Array).is_empty()
		or pd == null
		or (pd is Vector3 and (pd as Vector3).distance_to(dest) > TILE_3D)
		or float(u.repath_t) <= 0.0
	)
	if stale:
		u["path"] = _find_path(u.node.position, dest)
		u["path_i"] = 0
		u["path_dest"] = dest
		u["repath_t"] = 0.4
	var path: Array = u.get("path", [])
	var i: int = u.get("path_i", 0)
	if path.is_empty() or i >= path.size():
		_step_toward(u.node, dest, u.speed, delta)
		return
	if _step_toward(u.node, path[i], u.speed, delta):
		u["path_i"] = i + 1


# Move a unit node toward a target on the ground plane at `speed`, facing its direction of travel.
# Returns true once it has arrived. This is the actual unit locomotion (the old move_to delegation
# was a no-op — the glb unit models carry no script). Obstacle pathfinding layers on top of this.
func _step_toward(node: Node3D, target: Vector3, speed: float, delta: float) -> bool:
	if not is_instance_valid(node) or speed <= 0.0:
		return true
	var pos: Vector3 = node.position
	var flat: Vector3 = Vector3(target.x, pos.y, target.z)
	var to: Vector3 = flat - pos
	var dist: float = to.length()
	if dist < 0.05:
		return true
	node.rotation.y = atan2(to.x, to.z)
	var step: float = speed * delta
	if step >= dist:
		node.position = flat
		return true
	node.position = pos + to / dist * step
	return false


# Idle behaviour with best-effort turn-in-place: if the unit's facing changed by a large delta since
# the last idle frame (e.g. it stopped out of a chase pointing the wrong way), play the matching
# TurnLeft/TurnRight clip to reorient in place; otherwise settle into idle. The turn states fall back
# to idle on rigs without turn clips, so this is always safe. Heading is tracked per-unit in the dict.
const TURN_THRESHOLD := 0.6   # radians of heading change that triggers a turn-in-place clip

func _idle_or_turn(u: Dictionary) -> void:
	var node: Node3D = u.get("node")
	if not is_instance_valid(node):
		return
	var heading: float = node.rotation.y
	var prev: float = float(u.get("idle_heading", heading))
	var delta_h: float = wrapf(heading - prev, -PI, PI)
	u["idle_heading"] = heading
	if absf(delta_h) >= TURN_THRESHOLD:
		UnitAnimator.play(node, "turnleft" if delta_h > 0.0 else "turnright")
		return
	UnitAnimator.play(node, "idle")


# Rotate a unit to face a flat (ground-plane) target without moving it. Guards against a zero-length
# heading like _step_toward does, so a unit standing on its target keeps its current facing.
func _face_toward(node: Node3D, target: Vector3) -> void:
	if not is_instance_valid(node):
		return
	var to: Vector3 = Vector3(target.x, node.position.y, target.z) - node.position
	to.y = 0.0
	if to.length() < 0.05:
		return
	node.rotation.y = atan2(to.x, to.z)


# Selection feedback: a flat glowing ring under a selected unit (counter-scaled so it reads the
# same world size regardless of the unit model's own normalisation scale).
func _set_selected_visual(u: Dictionary, on: bool) -> void:
	var nv: Variant = u.get("node")   # untyped first: a dead unit's node may already be freed
	if not is_instance_valid(nv):
		return
	var node: Node3D = nv
	var ring: MeshInstance3D = node.get_node_or_null("SelRing")
	if on:
		if ring == null:
			ring = MeshInstance3D.new()
			ring.name = "SelRing"
			var torus := TorusMesh.new()
			torus.inner_radius = 1.1
			torus.outer_radius = 1.5
			ring.mesh = torus
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.45, 1.0, 0.55)
			mat.emission_enabled = true
			mat.emission = Color(0.3, 1.0, 0.4)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ring.material_override = mat
			node.add_child(ring)
		var s: float = maxf(node.scale.x, 0.001)
		ring.scale = Vector3.ONE / s        # keep the ring a constant world size
		ring.position = Vector3(0, 0.15 / s, 0)
	elif ring != null:
		ring.queue_free()


# Floating health bar above a unit (red bg + green fill, billboarded, counter-scaled to a constant
# world size). Created on first damage; fill width tracks the hp ratio. Hidden at full health.
func _update_health_bar(u: Dictionary, ratio: float) -> void:
	var node: Node3D = u.get("node")
	if not is_instance_valid(node):
		return
	var bar: Node3D = node.get_node_or_null("HpBar")
	if bar == null:
		bar = Node3D.new()
		bar.name = "HpBar"
		node.add_child(bar)
		bar.add_child(_hp_quad(Color(0.1, 0.0, 0.0, 0.85)))   # bg
		var fill := _hp_quad(Color(0.3, 1.0, 0.35, 1.0))       # fill
		fill.name = "Fill"
		fill.position.z = 0.01
		bar.add_child(fill)
	var s: float = maxf(node.scale.x, 0.001)
	bar.scale = Vector3.ONE / s
	bar.position = Vector3(0, 2.4 / s, 0)
	var fill2: MeshInstance3D = bar.get_node_or_null("Fill")
	if fill2 != null:
		var rc: float = clampf(ratio, 0.0, 1.0)
		fill2.scale.x = rc
		fill2.position.x = -(1.0 - rc) * 0.6   # keep the bar left-anchored as it shrinks
	bar.visible = ratio < 0.999


func _hp_quad(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 0.18)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	mi.material_override = m
	return mi


# Attack feedback: a quick lunge toward the target and back — reads as a strike for any unit
# (characters + rigged animals keep their walk/idle clip underneath), no cheesy scale-pop.
func _play_hit(u: Dictionary, toward: Vector3) -> void:
	var node: Node3D = u.get("node")
	if not is_instance_valid(node):
		return
	var dir: Vector3 = toward - node.position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var base: Vector3 = node.position
	var lunge: Vector3 = base + dir.normalized() * 0.6
	var t := create_tween()
	t.tween_property(node, "position", lunge, 0.07)
	t.tween_property(node, "position", base, 0.10)


# Damage feedback: a brief red emissive pulse on the struck target. Kept cheap for big brawls — one
# reusable overlay material applied as material_overlay across the target's meshes (no per-mesh clones,
# no shared base-material edits), tweened from a bright flash back to transparent, then removed.
func _flash_hit(target: Dictionary) -> void:
	var node: Node3D = target.get("node")
	if not is_instance_valid(node):
		return
	if bool(node.get_meta("_flashing", false)):
		return   # don't stack overlapping flashes on a unit hit several times a tick
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.2, 0.15, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.15)
	mat.emission_energy_multiplier = 2.0
	for m in meshes:
		(m as MeshInstance3D).material_overlay = mat
	node.set_meta("_flashing", true)
	var t := node.create_tween()   # bound to the target: dies with it if it's freed mid-flash
	t.tween_method(func(a: float) -> void: mat.albedo_color.a = a, 0.55, 0.0, 0.22)
	t.tween_callback(func() -> void:
		if not is_instance_valid(node):
			return
		for m in node.find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).material_overlay == mat:
				(m as MeshInstance3D).material_overlay = null
		node.set_meta("_flashing", false))


# Boids-style separation: a small push away from nearby same-faction units so groups spread out
# instead of stacking on one point (complements grid formations + pathing).
func _separation(node: Node3D, faction: int) -> Vector3:
	var push := Vector3.ZERO
	var pos: Vector3 = node.position
	for o in _units:
		if o.faction != faction or not is_instance_valid(o.node) or o.node == node:
			continue
		var d: Vector3 = pos - o.node.position
		var dist: float = d.length()
		if dist < 0.01:
			push += Vector3(randf() - 0.5, 0.0, randf() - 0.5).normalized() * 2.0  # break exact overlap
		elif dist < 2.2:
			push += d / dist * (2.2 - dist)
	return push


# Per-kill veterancy: survivors of combat get steadily stronger (Extinction Eclipse carryover idea).
func _gain_veterancy(u: Dictionary) -> void:
	u["veterancy"] = int(u.get("veterancy", 0)) + 1
	u["damage"] = float(u.damage) * 1.06
	u["max_hp"] = float(u.max_hp) * 1.04
	u["hp"] = minf(float(u.hp) + 0.04 * float(u.max_hp), float(u.max_hp))
	_refresh_veteran_glow(u)


## Gold ground ring under veterans — intensity scales with rank.
func _refresh_veteran_glow(u: Dictionary, pulse: bool = false) -> void:
	var node: Node3D = u.get("node")
	if not is_instance_valid(node):
		return
	var vet: int = int(u.get("veterancy", 0))
	if vet <= 0:
		var old: Node = node.get_node_or_null("VetGlow")
		if old != null:
			old.queue_free()
		return
	var glow: MeshInstance3D = node.get_node_or_null("VetGlow")
	if glow == null:
		glow = MeshInstance3D.new()
		glow.name = "VetGlow"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.9
		torus.outer_radius = 1.15
		glow.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		glow.material_override = mat
		node.add_child(glow)
	var s: float = maxf(node.scale.x, 0.001)
	glow.scale = Vector3.ONE / s
	glow.position = Vector3(0, 0.1 / s, 0)
	var t: float = clampf(float(vet) / 6.0, 0.15, 1.0)
	var mat2: StandardMaterial3D = glow.material_override as StandardMaterial3D
	if mat2 == null:
		return
	mat2.albedo_color = Color(1.0, 0.82, 0.28, 0.5 + 0.4 * t)
	mat2.emission = Color(1.0, 0.78, 0.22)
	var base_e: float = 1.0 + float(mini(vet, 8)) * 0.28
	mat2.emission_energy_multiplier = base_e * (1.85 if pulse else 1.0)
	if pulse:
		var tw := create_tween()
		tw.tween_property(mat2, "emission_energy_multiplier", base_e, 0.55)


func _tick_combat(delta: float) -> void:
	for u in _units:
		if not is_instance_valid(u.node) or u.hp <= 0: continue
		if bool(u.get("dying", false)): continue   # corpse mid-fade — never acts
		# Passive wildlife (everything but the wolf) never hunts — it only wanders. The wolf is
		# PREDATOR_FAC and behaves like a roaming bandit, so it falls through to normal targeting.
		var passive: bool = u.faction == WILD_FAC
		if u.target != null:
			var tnv: Variant = u.target.get("node")
			if not is_instance_valid(tnv) or u.target.hp <= 0: u.target = null
		if u.target == null and not passive:
			var aggro: float = 200.0 if u.speed > 0 else u.attack_range * 2.0
			if u.faction == 0 and u.speed > 0: aggro = PLAYER_GUARD_RADIUS
			u.target = _find_enemy(u.node.position, u.faction, aggro)
		if u.target == null or u.target.is_empty():
			if u.commanded:
				UnitAnimator.play(u.node, "run")
				if _follow_path(u, delta):
					u.commanded = false
			else:
				_idle_or_turn(u)
			continue
		var tnv2: Variant = u.target.get("node")
		if not is_instance_valid(tnv2):
			u.target = null
			continue
		var tnode: Node3D = tnv2
		var tpos: Vector3 = tnode.position
		var dist: float = u.node.position.distance_to(tpos)
		if dist > u.attack_range and u.speed > 0:
			UnitAnimator.play(u.node, "run")   # closing on the target
			_pathed_step(u, tpos, delta)   # chase via pathfinding (routes around water/obstacles)
		elif dist > u.attack_range:
			# Immobile defense (speed 0): it can't chase — drop locks on targets that wandered
			# out of range so it can re-acquire something it can actually hit.
			u.target = null
		else:
			u.cd -= delta
			if u.cd <= 0.0:
				u.cd = u.attack_cd
				_face_toward(u.node, tpos)   # stop sliding-facing — square up before striking
				UnitAnimator.trigger(u.node, ATTACK_STATE.get(str(u.get("unit_type", "")), "attack"))   # per-role: melee/bow/rifle
				if u.target.hp > 0:
					u.target.hp -= u.damage
				_play_hit(u, tpos)
				_flash_hit(u.target)   # brief emissive pulse on the struck target
				if u.target.max_hp > 0:
					_update_health_bar(u.target, clampf(u.target.hp / u.target.max_hp, 0.0, 1.0))
				if int(u.faction) != 0:
					_maybe_city_under_fire(u.target)
				# Throttled via the per-key cooldown in AudioManager.play_sfx so a melee
				# brawl (many units, short cooldowns) doesn't machine-gun the SFX bus.
				AudioManager.play_sfx("civ_combat")
				if u.faction == 0:
					_maybe_battle_tutorial()
				if u.target.hp <= 0:
					if u.faction == 0: _gain_veterancy(u)
					# Route the kill: units die via _begin_death; city targets are RAZED (removed
					# from the owning player/rival so they stop producing and counting for win/lose).
					_kill_target(u.target)
					u.target = null

	_apply_separation(delta)


# Per-tick boids separation pass: gently nudge units apart, but never into water/blocked cells.
func _apply_separation(delta: float) -> void:
	for u in _units:
		if not is_instance_valid(u.node) or u.speed <= 0.0:
			continue
		if bool(u.get("dying", false)):
			continue   # leave corpses to their death-fade tween — don't fight it with separation
		var sep: Vector3 = _separation(u.node, u.faction)
		if sep == Vector3.ZERO:
			continue
		var np: Vector3 = u.node.position + sep.limit_length(u.speed * delta * 0.8)
		var c: Vector2i = _cell_at(np)
		if c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS and terrain_at(c.x, c.y) == Terrain.LAND:
			u.node.position = np

# How long a corpse lingers (death clip + fade) before its node is freed.
const DEATH_FADE_S := 1.2

# Start a unit's death sequence: play the death clip, then fade/scale it out and free the node after
# a short delay. The unit is marked "dying" and forced to hp = 0 immediately, so every hp-gated check
# (targeting, combat tick, win/lose unit counts) treats it as dead right now — only the visible corpse
# lingers. The "dying" flag is the idempotency guard: a unit already dying is never re-processed, and
# _cleanup_dead leaves it alone until the fade tween frees the node itself.
func _begin_death(u: Dictionary) -> void:
	if bool(u.get("dying", false)):
		return   # already dying — never start a second sequence or free twice
	u["dying"] = true
	u["hp"] = 0.0          # count as dead for targeting / combat / win-lose checks
	u["target"] = null     # stop it from acting
	u["commanded"] = false
	var node: Node3D = u.get("node")
	if not is_instance_valid(node):
		return
	if int(u.get("faction", -1)) == 0 and DEFENSES.has(u.get("unit_type", "")):
		_release_cell(_cell_at(node.position))   # the turret's hex opens up again
	_set_selected_visual(u, false)
	var bar: Node3D = node.get_node_or_null("HpBar")
	if bar != null:
		bar.visible = false
	UnitAnimator.trigger(node, "death")   # plays the death clip (falls back to idle until a death pack is merged)
	# Fade + sink the corpse, then free it. Tween is bound to the node, so it auto-cancels if the node
	# is freed for any other reason; the final callback re-checks validity before freeing.
	var sink: Vector3 = node.position + Vector3(0, -0.6, 0)
	var t := node.create_tween()
	t.set_parallel(true)
	t.tween_property(node, "scale", node.scale * 0.05, DEATH_FADE_S).set_delay(DEATH_FADE_S * 0.35)
	t.tween_property(node, "position", sink, DEATH_FADE_S).set_delay(DEATH_FADE_S * 0.35)
	t.chain().tween_callback(func() -> void:
		if is_instance_valid(node):
			node.queue_free())


func _cleanup_dead() -> void:
	_units = _units.filter(func(u):
		# A unit still in its death animation stays in the list (so its corpse can finish fading) but
		# already reads as hp = 0 everywhere; its own fade tween frees the node. Don't yank it here.
		if bool(u.get("dying", false)):
			return is_instance_valid(u.node)
		if not is_instance_valid(u.node) or u.hp <= 0:
			if is_instance_valid(u.node): _begin_death(u)
			return is_instance_valid(u.node)   # keep until the death fade frees it
		return true
	)


# --- Input ---

var _minimap: Minimap2D = null

func _build_minimap() -> void:
	# Static terrain image: one pixel per tile (water/mountain/land).
	var img := Image.create(COLS, ROWS, false, Image.FORMAT_RGB8)
	for y in ROWS:
		for x in COLS:
			var col: Color
			match terrain_at(x, y):
				Terrain.WATER: col = Color(0.16, 0.34, 0.55)
				Terrain.MOUNTAIN: col = Color(0.45, 0.43, 0.40)
				_: col = Color(0.30, 0.50, 0.26)
			img.set_pixel(x, y, col)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_minimap = Minimap2D.new()
	_minimap.title = "WORLD"
	_minimap.terrain_tex = ImageTexture.create_from_image(img)
	_minimap.world_origin = Vector2(_grid_offset.x, _grid_offset.z)
	_minimap.world_size = Vector2(COLS * TILE_3D, ROWS * TILE_3D)
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_minimap.offset_left = 12
	_minimap.offset_top = -176
	_minimap.offset_right = 12 + 200
	_minimap.offset_bottom = -12
	_minimap.pan_requested.connect(func(wp: Vector3) -> void:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		if cam.has_method("zoom_tactical"):
			cam.zoom_tactical(wp)   # click minimap = pan + drop to tactical
		elif cam.has_method("set_focus"):
			cam.set_focus(wp))
	layer.add_child(_minimap)


func _update_minimap() -> void:
	if _minimap == null:
		return
	var dots: Array = []
	for c in _cities:
		dots.append({p = Vector2(c.position.x, c.position.z), c = _faction_color(int(c.get("faction", 0))), r = 3.0})
	for u in _units:
		if is_instance_valid(u.node):
			dots.append({p = Vector2(u.node.position.x, u.node.position.z), c = _faction_color(int(u.faction)), r = 1.6})
	if is_instance_valid(_settler):
		dots.append({p = Vector2(_settler.position.x, _settler.position.z), c = FACTION_COLORS[0], r = 2.4})
	var focus := Vector2.ZERO
	var half := Vector2.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam:
		# Use the camera's ground FOCUS (where it's actually looking) — the camera node hangs
		# back_dist behind/above the focus, so its global_position misplaces the view rect.
		var look: Vector3 = cam.get_focus() if cam.has_method("get_focus") else cam.global_position
		focus = Vector2(look.x, look.z)
		var aspect: float = get_viewport().get_visible_rect().size.aspect()
		half = Vector2(cam.size * aspect * 0.5, cam.size * 0.5)
	_minimap.set_data(dots, focus, half)


func _faction_color(fac: int) -> Color:
	match fac:
		WILD_FAC: return Color(0.8, 0.8, 0.5)        # passive wildlife
		PREDATOR_FAC: return Color(0.9, 0.5, 0.9)    # wolf
		BANDIT_FAC: return Color(0.9, 0.3, 0.3)      # bandits
		_: return FACTION_COLORS[fac % FACTION_COLORS.size()]


func _build_selection_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0   # above the 3D viewport, below the HUD panel (its own layer)
	add_child(layer)
	_sel_box = load("res://src/common/SelectionBox2D.gd").new()
	layer.add_child(_sel_box)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click:
			_double_click_tactical(event.position)
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			_begin_left_action(event.position)
		else:
			_end_left_action(event.position)
	elif event is InputEventMouseMotion and _dragging:
		# A left-button RELEASE consumed by a MOUSE_FILTER_STOP control (build panel,
		# minimap) never reaches _unhandled_input — without this, _dragging would stick
		# true and a phantom rubber-band would follow the cursor until the next click.
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_left_action(event.position)
		elif _sel_box != null:
			_sel_box.update_to(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_command_selected()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_focus_selection_tactical()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_B:
			if _try_open_drop_in_battle():
				get_viewport().set_input_as_handled()
			return
		_handle_control_group_key(event)


# Control groups: Ctrl+1..9 stores the current selection under that digit; 1..9 reselects it.
# Arrow keys are the camera's pan (RTSCamera3D), so digit keys are free for this. Groups hold unit
# dicts; dead/freed members are pruned on reselect so a wiped-out group just selects nothing.
var _control_groups: Dictionary = {}   # int digit (1..9) -> Array[Dictionary] of unit dicts

func _handle_control_group_key(event: InputEventKey) -> void:
	var digit := _digit_for_key(event.keycode)
	if digit <= 0:
		return
	if event.ctrl_pressed:
		_control_groups[digit] = _selected.duplicate()
		get_viewport().set_input_as_handled()
	elif not (_control_groups.get(digit, []) as Array).is_empty():
		# Consume the digit so GameSpeed (1/2/3 = speed) doesn't also fire; unbound digits fall through.
		_select_control_group(digit)
		get_viewport().set_input_as_handled()


# Map KEY_1..KEY_9 (and numpad 1..9) to 1..9; returns 0 for anything else.
func _digit_for_key(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1 + 1
	if keycode >= KEY_KP_1 and keycode <= KEY_KP_9:
		return keycode - KEY_KP_1 + 1
	return 0


func _select_control_group(digit: int) -> void:
	var group: Array = _control_groups.get(digit, [])
	_clear_selection()
	for u in group:
		if u is Dictionary and int(u.get("faction", -1)) == 0 \
				and is_instance_valid(u.get("node")) and u.get("hp", 0.0) > 0 \
				and not bool(u.get("dying", false)):
			_selected.append(u)
			_set_selected_visual(u, true)


func _begin_left_action(screen_pos: Vector2) -> void:
	_drag_start = screen_pos
	_dragging = true
	if _sel_box != null:
		_sel_box.begin(screen_pos)


func _end_left_action(screen_pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var box := Rect2(_drag_start, Vector2.ZERO)
	if _sel_box != null:
		box = _sel_box.finish()
	# A real drag → box-select (troops stay selectable while a settler waits to found);
	# a near-stationary click → move the settler if one is out, else single nearest-unit pick.
	if box.size.length() >= DRAG_THRESHOLD:
		_box_select(box)
	elif _settler != null:
		var cell := _cell_at(ground_point(screen_pos))
		if cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS and terrain_at(cell.x, cell.y) == Terrain.LAND:
			var dist: int = maxi(absi(cell.x - _cell_at(_settler.position).x), absi(cell.y - _cell_at(_settler.position).y))
			if dist <= 1 + _extra_move:
				_place_settler(cell)
	else:
		_click_select(screen_pos)


# Select every player unit whose on-screen position falls inside the drag rectangle
# (open-rts / gameidea pattern: Camera3D.unproject_position screen-space hit test).
func _box_select(box: Rect2) -> void:
	_clear_selection()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for u in _units:
		if u.faction != 0 or not is_instance_valid(u.node):
			continue
		if box.has_point(cam.unproject_position(u.node.position)):
			_selected.append(u)
			_set_selected_visual(u, true)


func _click_select(_screen_pos: Vector2) -> void:
	_clear_selection()
	var mp := ground_point(get_viewport().get_mouse_position())
	var best: Dictionary = {}
	var best_d := 4.0 * 4.0
	for u in _units:
		if u.faction != 0 or not is_instance_valid(u.node): continue
		var d := mp.distance_squared_to(u.node.position)
		if d < best_d: best_d = d; best = u
	if not best.is_empty():
		_selected.append(best)
		_set_selected_visual(best, true)


## Double-click: enemy + selection → drop-in battle; else zoom tactical on subject.
func _double_click_tactical(screen_pos: Vector2) -> void:
	var mp := ground_point(screen_pos)
	var target := mp
	var picked: Dictionary = {}
	var best_d := 5.0 * 5.0
	for u in _units:
		if not is_instance_valid(u.node):
			continue
		var d := mp.distance_squared_to(u.node.position)
		if d < best_d:
			best_d = d
			picked = u
			target = u.node.position
	# Double-click a hostile with troops selected = full drop-in battle.
	if not picked.is_empty() and int(picked.get("faction", 0)) != 0 and not _selected.is_empty():
		if _try_open_drop_in_battle():
			return
	if not picked.is_empty() and int(picked.get("faction", -1)) == 0:
		_clear_selection()
		_selected.append(picked)
		_set_selected_visual(picked, true)
	elif picked.is_empty():
		for c in _cities:
			if mp.distance_squared_to(c.position) < 7.0 * 7.0:
				target = c.position
				break
		for r in _rivals:
			for t: Dictionary in r.get("city_targets", []):
				if mp.distance_squared_to(t.position) < 7.0 * 7.0:
					target = t.position
	_zoom_tactical_at(target)


func _focus_selection_tactical() -> void:
	if not _selected.is_empty():
		var c := Vector3.ZERO
		var n := 0
		for u in _selected:
			if is_instance_valid(u.get("node")):
				c += u.node.position
				n += 1
		if n > 0:
			_zoom_tactical_at(c / float(n))
			return
	if not _cities.is_empty():
		_zoom_tactical_at(_cities[0].position)


func _zoom_tactical_at(pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.has_method("zoom_tactical"):
		cam.zoom_tactical(pos)


func _clear_selection() -> void:
	for u in _selected:
		_set_selected_visual(u, false)
	_selected.clear()


func _command_selected() -> void:
	var screen := get_viewport().get_mouse_position()
	# No units selected → a right-click on the ground sets the city rally point (newly trained units
	# walk there). Right-clicking an enemy with nothing selected is ignored (nothing to command).
	if _selected.is_empty():
		if _enemy_under_cursor(screen).is_empty():
			_set_rally_point(ground_point(screen))
		return
	# Right-click on an enemy unit/city = attack-move: lock that target and route the group onto it.
	# Right-click on bare ground = a plain routed move with a formation spread.
	var foe := _enemy_under_cursor(screen)
	if not foe.is_empty():
		_attack_move_selected(foe)
		return
	var mp := ground_point(screen)
	# Marching formation: spread the group into a centred grid around the target so they don't
	# stack on one point; each unit then paths to its own slot (routes around obstacles).
	var offs := _formation_offsets(_selected.size(), TILE_3D * 0.6)
	for i in _selected.size():
		var u: Dictionary = _selected[i]
		u["target"] = null          # a ground move cancels any held attack target
		_order_move(u, mp + offs[i])


# Order the whole selection to attack-move a foe: set it as their target (combat tick chases +
# strikes via pathfinding) AND issue a routed move onto it so they close even from across the map.
# `foe` is the live unit/city dict (carries node/hp/position) — re-targeting freed foes is guarded
# in _tick_combat, so passing the same dict to every unit is safe.
func _attack_move_selected(foe: Dictionary) -> void:
	var fnode: Node3D = foe.get("node")
	if not is_instance_valid(fnode):
		return
	var dest: Vector3 = fnode.position
	var offs := _formation_offsets(_selected.size(), TILE_3D * 0.6)
	for i in _selected.size():
		var u: Dictionary = _selected[i]
		u["target"] = foe
		_order_move(u, dest + offs[i])
	# First combat engagement: teach drop-in battles once.
	_maybe_battle_tutorial()
	if _selected.size() >= 1:
		Events.notify.emit("B — Drop into tactical battle")


func _maybe_battle_tutorial() -> void:
	if _battle_tutorial_shown:
		return
	_battle_tutorial_shown = true
	Events.notify.emit(
		"Tip: Press B near hostiles to DROP INTO a full tactical battle — fight live, auto-resolve, or retreat for loot & veterans."
	)
	StageObjectives.complete("civ_battle_tutorial", "Learned drop-in battles (B)")


# A battle combatant that shows the very map unit (TacticalBattle copies `look`) and swings its
# role's attack clip, instead of a stand-in capsule.
func _with_look(combatant: Dictionary, u: Dictionary) -> Dictionary:
	return combatant.merged({
		"look": u.get("node"),
		"attack_anim": ATTACK_STATE.get(str(u.get("unit_type", "")), "attack"),
	})


## Gather selected friendlies + nearby hostiles and open the drop-in arena.
func _try_open_drop_in_battle() -> bool:
	if _battle_open:
		return false
	var friends: Array = []
	var friend_ids: Array = []
	for u in _selected:
		if int(u.get("faction", -1)) != 0 or float(u.get("hp", 0.0)) <= 0.0:
			continue
		if not is_instance_valid(u.get("node")):
			continue
		var idx: int = _units.find(u)
		if idx < 0:
			continue
		friend_ids.append(idx)
		friends.append(_with_look(BattleModel.make_combatant(
			idx, str(u.get("unit_type", "Soldier")), 0,
			float(u.hp), float(u.max_hp), float(u.damage), float(u.attack_range),
			float(u.speed), float(u.get("attack_cd", 1.0))), u))
	if friends.is_empty():
		# Fall back: any player combat units near a selected foe or near the camera focus.
		var anchor: Vector3 = _cities[0].position if not _cities.is_empty() else Vector3.ZERO
		if not _selected.is_empty() and is_instance_valid(_selected[0].get("node")):
			anchor = _selected[0].node.position
		for i in _units.size():
			var u: Dictionary = _units[i]
			if int(u.get("faction", -1)) != 0 or float(u.get("hp", 0.0)) <= 0.0:
				continue
			if not is_instance_valid(u.get("node")):
				continue
			if u.node.position.distance_to(anchor) > 28.0:
				continue
			friend_ids.append(i)
			friends.append(_with_look(BattleModel.make_combatant(
				i, str(u.get("unit_type", "Soldier")), 0,
				float(u.hp), float(u.max_hp), float(u.damage), float(u.attack_range),
				float(u.speed), float(u.get("attack_cd", 1.0))), u))
	if friends.is_empty():
		Events.notify.emit("Select soldiers before dropping into battle.")
		return false
	var foes: Array = []
	var foe_ids: Array = []
	var center: Vector3 = Vector3.ZERO
	var n := 0
	for id in friend_ids:
		center += _units[id].node.position
		n += 1
	center /= float(maxi(n, 1))
	for i in _units.size():
		var u: Dictionary = _units[i]
		if int(u.get("faction", 0)) == 0 or float(u.get("hp", 0.0)) <= 0.0:
			continue
		if not is_instance_valid(u.get("node")):
			continue
		if u.node.position.distance_to(center) > 36.0:
			continue
		foe_ids.append(i)
		foes.append(_with_look(BattleModel.make_combatant(
			i, str(u.get("unit_type", "Bandit")), 1,
			float(u.hp), float(u.max_hp), float(u.damage), float(u.attack_range),
			float(u.speed), float(u.get("attack_cd", 1.0))), u))
	# Include a rival city as a tough "structure" foe if nearby.
	for r in _rivals:
		for t: Dictionary in r.get("city_targets", []):
			if bool(t.get("dying", false)) or float(t.get("hp", 0.0)) <= 0.0:
				continue
			if not is_instance_valid(t.get("node")):
				continue
			if t.position.distance_to(center) > 40.0:
				continue
			var cid := "city_%s" % str(t.get("node").get_instance_id())
			foe_ids.append(cid)
			foes.append(BattleModel.make_combatant(
				cid, "City", 1, float(t.hp), float(t.get("max_hp", t.hp)),
				0.0, 0.5, 0.0, 9.0).merged({"look": t.get("node")}))   # the rival's actual capital
	if foes.is_empty():
		Events.notify.emit("No hostiles nearby — march closer, then press B.")
		return false
	_battle_friend_ids = friend_ids
	_battle_foe_ids = foe_ids
	_battle_open = true
	var battle: TacticalBattle = TacticalBattleScene.instantiate()
	battle.configure({
		"mode": "ground",
		"title": "GROUND BATTLE — %s" % (EvolutionState.planet_name if EvolutionState.planet_name != "" else "homeworld"),
		"friends": friends,
		"foes": foes,
		"seed": hash("%s_civ_battle_%d" % [EvolutionState.world_seed, Time.get_ticks_msec()]),
	})
	battle.finished.connect(_on_tactical_battle_finished)
	# Parent under the stage root so the overlay survives alongside stage UI.
	var root: Node = StageManager.stage_root()
	if root != null:
		root.add_child(battle)
	else:
		add_child(battle)
	StageObjectives.complete("civ_drop_in", "Dropped into a ground battle")
	return true


func _on_tactical_battle_finished(result: Dictionary) -> void:
	_battle_open = false
	var falive: Array = result.get("friend_alive", [])
	var fhp: Dictionary = result.get("friend_hp", {})
	var ealive: Array = result.get("foe_alive", [])
	var ehp: Dictionary = result.get("foe_hp", {})
	# Apply friend HP / deaths.
	for id in _battle_friend_ids:
		if id is int and id >= 0 and id < _units.size():
			var u: Dictionary = _units[id]
			if falive.has(id):
				u["hp"] = float(fhp.get(id, u.hp))
			else:
				u["hp"] = 0.0
				_kill_target(u)
	# Apply foe unit deaths.
	for id in _battle_foe_ids:
		if id is int and id >= 0 and id < _units.size():
			var u: Dictionary = _units[id]
			if ealive.has(id):
				u["hp"] = float(ehp.get(id, u.hp))
			else:
				u["hp"] = 0.0
				_kill_target(u)
		elif id is String and str(id).begins_with("city_"):
			# Match city targets by surviving id.
			for r in _rivals:
				for t: Dictionary in r.get("city_targets", []):
					if not is_instance_valid(t.get("node")):
						continue
					var cid := "city_%s" % str(t.node.get_instance_id())
					if cid != id:
						continue
					if ealive.has(id):
						t["hp"] = float(ehp.get(id, t.hp))
					else:
						t["hp"] = 0.0
						_kill_target(t)
	# Fanfare already played win/lose SFX — keep parent notify short.
	if bool(result.get("won", false)) and not bool(result.get("retreated", false)):
		_apply_battle_rewards(result)
		Events.notify.emit("Battle spoils claimed.")
	elif bool(result.get("retreated", false)):
		Events.notify.emit("Retreated from battle.")
	else:
		Events.notify.emit("Battle lost — survivors limp home.")
	_battle_friend_ids.clear()
	_battle_foe_ids.clear()
	_update_status()
	_check_endgame()


func _apply_battle_rewards(result: Dictionary) -> void:
	var loot: Dictionary = result.get("loot", {})
	if not loot.is_empty():
		_res_f["food"] = float(_res_f.get("food", 0.0)) + float(loot.get("food", 0))
		_res_f["wood"] = float(_res_f.get("wood", 0.0)) + float(loot.get("wood", 0))
		_res_f["stone"] = float(_res_f.get("stone", 0.0)) + float(loot.get("stone", 0))
		for r in RES:
			_res[r] = int(_res_f[r])
		Events.notify.emit("Loot: +%d food · +%d wood · +%d stone" % [
			int(loot.get("food", 0)), int(loot.get("wood", 0)), int(loot.get("stone", 0))])
	var vet: int = int(result.get("veterancy", 0))
	if vet <= 0:
		return
	var stacks := 0
	for id in _battle_friend_ids:
		if id is int and id >= 0 and id < _units.size():
			var u: Dictionary = _units[id]
			if float(u.get("hp", 0.0)) <= 0.0 or not is_instance_valid(u.get("node")):
				continue
			for _i in vet:
				_gain_veterancy(u)
			_refresh_veteran_glow(u, true)
			stacks += 1
	if stacks > 0:
		Events.notify.emit("Veterans hardened: %d units +%d ranks" % [stacks, vet])


var _city_fire_toast_cd := 0.0


## Hostile chips a player city — danger toast when HP crosses thresholds (throttled).
func _maybe_city_under_fire(target: Dictionary) -> void:
	if target.is_empty() or _city_fire_toast_cd > 0.0:
		return
	var is_player_city := false
	for c in _cities:
		if c == target or (c.get("node") == target.get("node") and is_instance_valid(c.get("node"))):
			is_player_city = true
			break
	if not is_player_city:
		return
	var max_hp: float = maxf(1.0, float(target.get("max_hp", CITY_MAX_HP)))
	var frac: float = float(target.get("hp", max_hp)) / max_hp
	if frac > 0.85:
		return
	_city_fire_toast_cd = 6.0
	if frac <= 0.25:
		Events.notify.emit("🔥 City critical (%.0f%%) — B for emergency defense!" % (frac * 100.0))
	elif frac <= 0.5:
		Events.notify.emit("⚔ City under heavy siege (%.0f%% HP)" % (frac * 100.0))
	else:
		Events.notify.emit("City under attack (%.0f%% HP)" % (frac * 100.0))


## When hostiles press a player city: toast (throttled). If city HP < 50%, auto-open defense once.
func _tick_siege_prompt(delta: float) -> void:
	_city_fire_toast_cd = maxf(0.0, _city_fire_toast_cd - delta)
	_siege_prompt_cd = maxf(0.0, _siege_prompt_cd - delta)
	if _battle_open or _cities.is_empty():
		return
	for c in _cities:
		if int(c.get("faction", 0)) != 0:
			continue
		if bool(c.get("dying", false)):
			continue
		var cpos: Vector3 = c.position
		var max_hp: float = maxf(1.0, float(c.get("max_hp", CITY_MAX_HP)))
		var hp: float = float(c.get("hp", max_hp))
		var frac: float = hp / max_hp
		var attackers: Array = []
		for u in _units:
			if int(u.get("faction", 0)) == 0 or float(u.get("hp", 0.0)) <= 0.0:
				continue
			if not is_instance_valid(u.get("node")):
				continue
			if u.node.position.distance_to(cpos) < 14.0:
				attackers.append(u)
		if attackers.is_empty():
			continue
		# Critical: city below half HP under fire → auto drop-in defense (once per crisis).
		var city_key: String = str(c.get("node").get_instance_id()) if is_instance_valid(c.get("node")) else str(cpos)
		if frac < SIEGE_AUTO_HP_FRAC and not bool(_siege_auto_opened_cities.get(city_key, false)):
			_siege_auto_opened_cities[city_key] = true
			_siege_prompt_cd = SIEGE_PROMPT_COOLDOWN
			Events.notify.emit("⚔ City critical! Dropping into DEFENSE battle…")
			_auto_defense_battle(c)
			return
		if _siege_prompt_cd <= 0.0:
			_siege_prompt_cd = SIEGE_PROMPT_COOLDOWN
			Events.notify.emit("⚔ Siege! Press B to drop into a defense battle")
			StageObjectives.complete("civ_siege_prompt", "A city is under siege — defend it")
			_maybe_battle_tutorial()
			return


## Select nearby defenders and open a battle focused on the threatened city.
func _auto_defense_battle(city: Dictionary) -> void:
	if _battle_open:
		return
	_clear_selection()
	var cpos: Vector3 = city.position
	for u in _units:
		if int(u.get("faction", -1)) != 0 or float(u.get("hp", 0.0)) <= 0.0:
			continue
		if not is_instance_valid(u.get("node")):
			continue
		if u.node.position.distance_to(cpos) <= 32.0:
			_selected.append(u)
			_set_selected_visual(u, true)
	# Even with no nearby army, try open — _try_open_drop_in will pull nearby friendlies.
	if not _try_open_drop_in_battle():
		# Reset once-flag so a later attempt can fire if the first failed (no foes).
		if is_instance_valid(city.get("node")):
			_siege_auto_opened_cities.erase(str(city.node.get_instance_id()))


# Rally point: with no units selected, a right-click on the ground tells the city where freshly
# trained units should gather. Stored on the player city that trains units (_cities.back(), the same
# one _train_unit / _train_worker spawn from) so it survives extra cities being founded. A small
# flag marker is shown at the point. Cleared/replaced on each set. Robust to having no city yet.
func _set_rally_point(dest: Vector3) -> void:
	if _cities.is_empty():
		return
	var city: Dictionary = _cities.back()
	if int(city.get("faction", 0)) != 0:
		return
	city["rally"] = dest
	_show_rally_marker(city, dest)


# A flat glowing disc marking a city's rally point. One marker per city, re-seated on each set.
func _show_rally_marker(city: Dictionary, dest: Vector3) -> void:
	var marker: Node3D = city.get("rally_marker")
	if not is_instance_valid(marker):
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.9
		cyl.bottom_radius = 0.9
		cyl.height = 0.08
		mi.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.9, 0.35, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.2)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		add_child(mi)
		marker = mi
		city["rally_marker"] = marker
	marker.position = dest + Vector3(0, 0.1, 0)


# Pick the closest enemy unit OR enemy city whose on-screen position is within a small pixel radius
# of the cursor (screen-space hit test, matching the box/click-select approach). Returns {} on a miss.
# Player faction is 0; dying/dead units are skipped so they can't be targeted.
const TARGET_PICK_RADIUS := 36.0   # px around the cursor that still counts as clicking a unit/city

func _enemy_under_cursor(screen: Vector2) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var best: Dictionary = {}
	var best_d := TARGET_PICK_RADIUS * TARGET_PICK_RADIUS
	for u in _units:
		if u.faction == 0 or u.hp <= 0 or bool(u.get("dying", false)):
			continue
		if not is_instance_valid(u.node):
			continue
		var sp: Vector2 = cam.unproject_position(u.node.position)
		var d: float = screen.distance_squared_to(sp)
		if d < best_d:
			best_d = d
			best = u
	# Rival city centers are valid right-click targets (conquest) — same live target dicts
	# _find_enemy hands out, so ordered attacks chip real city hp.
	for r in _rivals:
		for t: Dictionary in r.get("city_targets", []):
			if bool(t.get("dying", false)) or not is_instance_valid(t.get("node")):
				continue
			var sp2: Vector2 = cam.unproject_position(t.position)
			var d2: float = screen.distance_squared_to(sp2)
			if d2 < best_d:
				best_d = d2
				best = t
	return best


# Centred square-ish grid of ground offsets for `count` units, `spacing` apart.
func _formation_offsets(count: int, spacing: float) -> Array[Vector3]:
	var offs: Array[Vector3] = []
	if count <= 1:
		offs.append(Vector3.ZERO)
		return offs
	var cols: int = int(ceil(sqrt(float(count))))
	for i in count:
		offs.append(Vector3(float(i % cols) * spacing, 0.0, float(i / cols) * spacing))
	# Recentre on the true centroid so the group lands on the target regardless of a partial row.
	var centroid := Vector3.ZERO
	for o in offs:
		centroid += o
	centroid /= float(offs.size())
	for i in offs.size():
		offs[i] -= centroid
	return offs


# --- HUD ---
# UI-BUYMENU-REDESIGN: a tabbed build panel (Workers / Buildings / Units / Defense / Upgrades) holds
# every buildable. The longest tab (Units, 7 items) fits 2 columns × 4 rows inside the side panel
# at 1920×1080 with no scrollbar. _update_status still owns enable/disable + text — the layout is
# a pure refactor (callbacks + button text + the `btn.text.begins_with("Train X")` lookup in
# _update_status are preserved verbatim).

func _build_ui() -> void:
	# Shared StageChrome shell (right edge so the map stays open — same chrome as left stages).
	var ui := StageChromeScript.make_layer(self)
	var panel = CompactHUD.new()
	panel.configure("CIVILIZATION", BUILD_PANEL_SIZE.x, true)
	panel.tooltip_text = "Left-click selects. Right-click commands. Ctrl+1–9 stores control groups."
	ui.add_child(panel)

	var root: VBoxContainer = panel.content
	root.add_child(StageChromeScript.identity_row(54))
	root.add_child(StageChromeScript.h_sep())
	_stat_strip = StatStripScript.new()
	root.add_child(_stat_strip)
	_status = StageChromeScript.status_label()
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(_status)

	var tabs := BuildTabs.new()
	tabs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	var workers_grid := _make_build_grid()
	tabs.add_tab("Work", workers_grid)
	for kv in [["Forager", "food"], ["Logger", "wood"], ["Miner", "stone"]]:
		var btn := _make_build_button("Train %s (%d food)" % [kv[0], WORKER_COST],
			"Train a %s villager — produces %s passively" % [kv[0].to_lower().substr(0, 1).to_upper() + kv[0].to_lower().substr(1), kv[1]],
			_train_worker.bind(kv[1]))
		workers_grid.add_child(btn)
		_train_btns.append(btn)
	_settler_btn = _make_build_button("Train Settler (%d food)" % SETTLER_COST,
		"Train a settler at your newest city — move it (left-click) and Found City to expand",
		_train_settler)
	workers_grid.add_child(_settler_btn)
	var found_btn := _make_build_button("Found City (at settler)",
		"Found a new city at the currently selected settler",
		_found_city)
	workers_grid.add_child(found_btn)

	var buildings_grid := _make_build_grid()
	tabs.add_tab("Build", buildings_grid)
	for name in BUILDINGS:
		var spec: Dictionary = BUILDINGS[name]
		var cost_parts: PackedStringArray = []
		for r in spec.cost: cost_parts.append("%d %s" % [int(spec.cost[r]), r])
		var btn := _make_build_button("Build %s (%s)" % [name, ", ".join(cost_parts)],
			"%s — cost %s" % [name, str(spec.cost)],
			_queue_building.bind(name))
		buildings_grid.add_child(btn)
		_build_btns.append(btn)

	var units_grid := _make_build_grid()
	tabs.add_tab("Units", units_grid)
	for name in UNITS:
		var spec: Dictionary = UNITS[name]
		var cost_parts: PackedStringArray = []
		for r in spec.cost: cost_parts.append("%d %s" % [int(spec.cost[r]), r])
		var btn := _make_build_button("Train %s (%s)" % [name, ", ".join(cost_parts)],
			"%s\nHP %d · DMG %d · range %d" % [name, int(spec.max_hp), int(spec.damage), int(spec.attack_range)],
			_train_unit.bind(name))
		units_grid.add_child(btn)
		_unit_btns.append(btn)

	var defense_grid := _make_build_grid()
	tabs.add_tab("Def", defense_grid)
	for name in DEFENSES:
		var spec: Dictionary = DEFENSES[name]
		var cost_parts: PackedStringArray = []
		for r in spec.cost: cost_parts.append("%d %s" % [int(spec.cost[r]), r])
		var btn := _make_build_button("Build %s (%s)" % [name, ", ".join(cost_parts)],
			"%s — cost %s" % [name, str(spec.cost)],
			_queue_building.bind(name))
		defense_grid.add_child(btn)
		_defense_btns.append(btn)

	var upgrades_grid := _make_build_grid()
	tabs.add_tab("Tech", upgrades_grid)
	_age_btn = _make_build_button("Advance Age", "Advance civilization to the next era", _advance_age)
	upgrades_grid.add_child(_age_btn)
	_research_btn = _make_build_button("Research Next Tech", "Research the next available technology", _research)
	upgrades_grid.add_child(_research_btn)
	var wbtn := _make_build_button("Weapons +N", "Buy the next weapon tier (dmg +15% per tier)", _buy_weapon_upgrade)
	upgrades_grid.add_child(wbtn)
	_upgrade_btns.append(wbtn)
	var abtn := _make_build_button("Armor +N", "Buy the next armor tier (HP +15% per tier)", _buy_armor_upgrade)
	upgrades_grid.add_child(abtn)
	_upgrade_btns.append(abtn)
	_launch_btn = _make_build_button("Launch to Space", "Launch to the Space stage (requires a Spaceport, %d cities and %d rival eliminated)" % [WIN_CITY_COUNT, WIN_RIVALS_BEATEN], _launch_to_space)
	_launch_btn.disabled = true
	upgrades_grid.add_child(_launch_btn)
	_truce_btn = _make_build_button("☮ Ceasefire", "Buy a temporary ceasefire with rival civs", _offer_truce)
	upgrades_grid.add_child(_truce_btn)
	var battle_btn := _make_build_button("⚔ Drop-In Battle (B)",
		"Open a full tactical ground battle with selected soldiers vs nearby hostiles",
		func() -> void: _try_open_drop_in_battle())
	upgrades_grid.add_child(battle_btn)

	_update_status()


# 2-column GridContainer shared by every build tab. Compact spacing (4px) keeps the longest tab
# (Units, 7 items) inside the side panel at 1920×1080.
func _make_build_grid() -> GridContainer:
	return StageChromeScript.build_grid(1)


# Compact build button — text is set later by _update_status for the dynamic upgrades + age + truce
# buttons. Tooltip carries the full details. _update_status still uses `btn.text.begins_with("Train X")`
# / `btn.text.begins_with("Build X")` to identify the spec, so the prefixes MUST stay intact.
func _make_build_button(initial_text: String, tooltip: String, callback: Callable) -> Button:
	# Shared button chrome — clip_text true for long cost strings in the tight RTS panel.
	var btn := StageChromeScript.make_button(initial_text, tooltip, callback)
	btn.clip_text = true
	return btn


func _unrest_readout() -> String:
	var status: String = CITIZEN_NEEDS_MODEL.status(_unrest)
	return "%s %d%% (prod %d%%)" % [status, int(round(_unrest * 100.0)), int(round(_needs_production_mult * 100.0))]


func _climate_readout() -> String:
	var status := "stable"
	if CLIMATE_MODEL.is_crisis(_warming_deg):
		status = "crisis"
	elif _warming_deg >= 1.5:
		status = "strained"
	elif _warming_deg >= 0.5:
		status = "warming"
	return "%s %.1fC (prod %d%%)" % [status, _warming_deg, int(round(_climate_production_mult * 100.0))]


func _chain_readout() -> String:
	var tools := int(_chain_stock.get("tools", 0))
	var planks := int(_chain_stock.get("planks", 0))
	var ingots := int(_chain_stock.get("ingots", 0))
	var bread := int(_chain_stock.get("bread", 0))
	var bonus := int(round((_chain_production_mult - 1.0) * 100.0))
	return "%dt/%dp/%di · %d bread (+%d%%)" % [tools, planks, ingots, bread, bonus]


func _update_status() -> void:
	if _status == null: return
	if _stat_strip != null:
		_stat_strip.begin()
		_stat_strip.set_chip("food", "●", "%d" % _res["food"], Color(0.88, 0.80, 0.38), "Food (%+.1f/s)" % _income_rate("food"))
		_stat_strip.set_chip("wood", "▲", "%d" % _res["wood"], Color(0.55, 0.82, 0.48), "Wood (%+.1f/s)" % _income_rate("wood"))
		_stat_strip.set_chip("stone", "◆", "%d" % _res["stone"], Color(0.72, 0.76, 0.82), "Stone (%+.1f/s)" % _income_rate("stone"))
		_stat_strip.prune()
	var next_tech := "(all researched)"
	if _tech_index < TECHS.size(): next_tech = "%s (%d)" % [TECHS[_tech_index].name, int(TECHS[_tech_index].cost)]
	var building_line := ""
	if _build_queue.size() > 0: building_line = " · %s %.0fs" % [_build_queue[0].name, _build_queue[0].time_left]
	var alive_rivals: int = 0
	for r in _rivals:
		if not (r.cities as Array).is_empty():
			alive_rivals += 1
	_status.text = "%s · %d/%d cities · %d rival%s\nNext %s%s" % [
		AGES[_age],
		_cities.size(),
		WIN_CITY_COUNT,
		alive_rivals,
		"" if alive_rivals == 1 else "s",
		next_tech,
		building_line,
	]
	_status.tooltip_text = "%s\nRivals: %s\nUnrest %s\nClimate %s\nGoods %s" % [
		_win_paths_readout(), _rival_activity, _unrest_readout(), _climate_readout(), _chain_readout(),
	]
	var has_city := not _cities.is_empty()
	for btn in _train_btns: btn.disabled = not has_city or not _can_afford({food = WORKER_COST})
	if _settler_btn != null:
		_settler_btn.disabled = not has_city or _settler != null or not _can_afford({food = SETTLER_COST})
	var has_city_barracks := has_city and _has_barracks
	for btn in _unit_btns:
		var spec_name := ""
		for name in UNITS:
			if btn.text.begins_with("Train " + name): spec_name = name; break
		var ok := has_city_barracks
		if spec_name != "" and UNITS.has(spec_name):
			ok = ok and _can_afford(UNITS[spec_name].cost)
			ok = ok and _age >= UNITS[spec_name].get("min_age", 0)
		btn.disabled = not ok
	for btn in _build_btns:
		var spec_name := ""
		for name in BUILDINGS:
			if btn.text.begins_with("Build " + name): spec_name = name; break
		var ok := has_city and _build_queue.is_empty()
		if spec_name != "" and BUILDINGS.has(spec_name):
			ok = ok and _can_afford(BUILDINGS[spec_name].cost)
			ok = ok and _age >= BUILDINGS[spec_name].get("min_age", 0)
		btn.disabled = not ok
	for btn in _defense_btns:
		var spec_name := ""
		for name in DEFENSES:
			if btn.text.begins_with("Build " + name): spec_name = name; break
		var ok := has_city and _build_queue.is_empty()
		if spec_name != "" and DEFENSES.has(spec_name):
			ok = ok and _can_afford(DEFENSES[spec_name].cost)
			ok = ok and _age >= DEFENSES[spec_name].get("min_age", 0)
		btn.disabled = not ok
	if _launch_btn: _launch_btn.disabled = not _launch_ready()
	if _age + 1 < AGES.size():
		if _tech_index <= _age:
			_age_btn.text = "Advance to %s — research %s first" % [AGES[_age + 1], TECHS[_age].name]
			_age_btn.disabled = true
		else:
			_age_btn.text = "Advance to %s (%d food)" % [AGES[_age + 1], AGE_COST[_age + 1]]
			_age_btn.disabled = not _can_afford({food = AGE_COST[_age + 1]})
	else:
		_age_btn.text = "Advance to %s (MAX)" % AGES[_age]
		_age_btn.disabled = true
	if _tech_index < TECHS.size():
		var tech: Dictionary = TECHS[_tech_index]
		_research_btn.text = "Research %s (%d food)" % [tech.name, int(tech.cost)]
		_research_btn.disabled = not _can_afford({food = int(tech.cost)})
	else:
		_research_btn.text = "All techs researched"
		_research_btn.disabled = true
	if _upgrade_btns.size() == 2:
		var wc := _upgrade_cost(_weapon_tier)
		var ac := _upgrade_cost(_armor_tier)
		_upgrade_btns[0].text = "Weapons +%d (%dw %ds)" % [_weapon_tier + 1, int(wc.wood), int(wc.stone)]
		_upgrade_btns[1].text = "Armor +%d (%dw %ds)" % [_armor_tier + 1, int(ac.wood), int(ac.stone)]
		_upgrade_btns[0].disabled = not _can_afford(wc)
		_upgrade_btns[1].disabled = not _can_afford(ac)
	if _truce_btn:
		if _truce_active():
			_truce_btn.text = "Ceasefire active"
			_truce_btn.disabled = true
		else:
			_truce_btn.text = "☮ Buy Ceasefire (%dw %ds)" % [int(TRUCE_COST.wood), int(TRUCE_COST.stone)]
			_truce_btn.disabled = not _can_afford(TRUCE_COST)


# --- Civ Sim Models ---

func _tick_civ_sim(delta: float) -> void:
	if delta <= 0.0:
		return
	if _cities.is_empty():
		_needs_production_mult = 1.0
	else:
		var needs := _current_needs()
		var unrest_delta: float = CITIZEN_NEEDS_MODEL.unrest_delta(needs, delta)
		_unrest = CITIZEN_NEEDS_MODEL.apply_unrest(_unrest, unrest_delta)
		_needs_production_mult = CITIZEN_NEEDS_MODEL.production_mult(_unrest)
	_step_production_chains(delta)
	_step_climate(delta)
	_step_rival_models()


func _current_needs() -> Dictionary:
	var population := _citizen_population()
	var bread := int(_chain_stock.get("bread", 0))
	# Bread is a luxury food: each loaf tops up basic satiation (worth ~2 food)
	# AND feeds a separate morale "luxury" need that only ever lowers unrest.
	var food_supply := float(_res.get("food", 0)) + _income_rate("food") * 8.0 + float(bread) * 2.0
	var housing_capacity := 0
	for c in _cities:
		housing_capacity += int(c.get("max_population", 0))
	var safety_supply := float(_cities.size() * 2 + _player_unit_count(false)) + float(_player_defense_count() * 2 + _defense_bonus * 2)
	if _truce_active():
		safety_supply += 2.0
	var safety_need := float(maxi(1, _cities.size() * 2)) + _hostile_pressure()
	return {
		"food_ratio": clampf(food_supply / maxf(1.0, float(population) * 2.0), 0.0, 1.0),
		"housing_ratio": clampf(float(housing_capacity) / maxf(1.0, float(population)), 0.0, 1.0),
		"safety_ratio": clampf(safety_supply / maxf(1.0, safety_need), 0.0, 1.0),
		"luxury_ratio": clampf(float(bread) / maxf(1.0, float(population) * 0.5), 0.0, 1.0),
	}


func _citizen_population() -> int:
	return maxi(1, _cities.size() * 2 + _workers.size() + _player_unit_count(false))


func _player_unit_count(include_defenses: bool) -> int:
	var count := 0
	for u in _units:
		if int(u.get("faction", -1)) != 0 or not is_instance_valid(u.get("node")):
			continue
		if include_defenses or float(u.get("speed", 0.0)) > 0.0:
			count += 1
	return count


func _player_defense_count() -> int:
	var count := 0
	for u in _units:
		if int(u.get("faction", -1)) == 0 and is_instance_valid(u.get("node")) and float(u.get("speed", 0.0)) <= 0.0:
			count += 1
	return count


func _hostile_pressure() -> float:
	var pressure := float(_bandits.size()) * 1.5
	for u in _units:
		if not is_instance_valid(u.get("node")):
			continue
		var fac := int(u.get("faction", -1))
		if fac == PREDATOR_FAC:
			pressure += 0.6
		elif fac > 0 and fac != WILD_FAC:
			pressure += 0.35
	return pressure


func _step_climate(delta: float) -> void:
	# Climate is a LATE-game pressure (gentle-early / brutal-late pillar): a Stone-age
	# town must not drive global warming. Emissions only count from the Industrial age
	# on, then ramp hard through Modern / Near-Future.
	var added: float = CLIMATE_MODEL.emissions(_civ_buildings_by_type, delta) * _climate_age_factor()
	var green_offset := float(_cities.size()) * 0.03
	_climate_co2 = CLIMATE_MODEL.accumulate_co2(_climate_co2, added, green_offset, delta)
	_warming_deg = CLIMATE_MODEL.warming(_climate_co2)
	_climate_production_mult = clampf(1.0 - CLIMATE_MODEL.production_penalty(_warming_deg), 0.50, 1.0)


# Industrial-age emission multiplier. Pre-industrial ages (Stone/Bronze/Iron) emit
# nothing; warming only becomes a threat once the civ industrializes.
func _climate_age_factor() -> float:
	match _age:
		0, 1, 2:
			return 0.0
		3:
			return 1.0
		4:
			return 1.6
		_:
			return 2.2


func _step_production_chains(delta: float) -> void:
	_add_chain_raw("wood", _base_income_rate("wood") * 0.35 * delta)
	_add_chain_raw("ore", _base_income_rate("stone") * 0.25 * delta)
	# Grain is the agricultural surplus skimmed from food output; bakers turn
	# 3 grain into 1 loaf of bread — a luxury food that actively lifts morale.
	_add_chain_raw("grain", _base_income_rate("food") * 0.40 * delta)
	var workers := maxi(1, _cities.size() + int(floor(float(_workers.size()) / 3.0)))
	_advance_chain_recipe("planks", workers, delta)
	_advance_chain_recipe("ingots", workers, delta)
	_advance_chain_recipe("tools", maxi(1, int(floor(float(workers) / 2.0))), delta)
	_advance_chain_recipe("bread", workers, delta)
	# The population eats bread; keeping the bakeries ahead of demand is what
	# sustains the happiness bonus (a stockpile alone decays as people consume it).
	_bread_demand_acc += float(_citizen_population()) * 0.035 * delta
	var eaten := int(floor(_bread_demand_acc))
	if eaten > 0:
		_bread_demand_acc -= float(eaten)
		_chain_stock["bread"] = maxi(0, int(_chain_stock.get("bread", 0)) - eaten)
	_chain_production_mult = 1.0 + minf(float(_chain_stock.get("tools", 0)) * 0.015, 0.12)


func _add_chain_raw(id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	_chain_raw_progress[id] = float(_chain_raw_progress.get(id, 0.0)) + amount
	while float(_chain_raw_progress[id]) >= 1.0:
		_chain_raw_progress[id] = float(_chain_raw_progress[id]) - 1.0
		_chain_stock[id] = int(_chain_stock.get(id, 0)) + 1


func _advance_chain_recipe(id: String, workers: int, delta: float) -> void:
	if not PRODUCTION_CHAIN_MODEL.has_recipe(id):
		return
	_chain_progress[id] = float(_chain_progress.get(id, 0.0)) + PRODUCTION_CHAIN_MODEL.throughput(id, workers, delta)
	while float(_chain_progress[id]) >= 1.0 and PRODUCTION_CHAIN_MODEL.can_make(id, _chain_stock):
		_chain_stock = PRODUCTION_CHAIN_MODEL.make(id, _chain_stock)
		_chain_progress[id] = float(_chain_progress[id]) - 1.0
	if not PRODUCTION_CHAIN_MODEL.can_make(id, _chain_stock):
		_chain_progress[id] = minf(float(_chain_progress[id]), 1.0)


func _step_rival_models() -> void:
	var summaries: PackedStringArray = []
	for r in _rivals:
		if r.cities.is_empty():
			continue
		r.units = (r.units as Array).filter(func(u): return is_instance_valid(u.get("node")) and float(u.get("hp", 0.0)) > 0.0)
		var living_army := int((r.units as Array).size())
		var state := {
			"gold": float(r.get("treasury", 0.0)),
			"army": maxi(living_army, int(r.get("model_army", living_army))),
			"aggression": clampf(float(r.get("aggression", 0.0)), 0.0, 1.0),
			"expansion": clampf(float(r.get("expand", 0.0)), 0.0, 1.0),
		}
		# Decision via the SHARED EmpireAI brain (same engine Space empires use). Civ rivals
		# carry inline traits; thresholds are Civ-scale. EmpireAI's vocabulary has "research"
		# instead of "build_army" — map it to Civ's military investment so the action applies.
		var decision := {
			"treasury": float(r.get("treasury", 0.0)),
			"systems": int((r.cities as Array).size()),
			"aggression": clampf(float(r.get("aggression", 0.0)), 0.0, 1.0),
			"expand": clampf(float(r.get("expand", 0.0)), 0.0, 1.0),
			"tech_focus": clampf(float(r.get("tech_focus", 0.35)), 0.0, 1.0),
		}
		var action: String = EMPIRE_AI.choose_action(decision, r.get("rng"), RIVAL_EXPAND_BASE, RIVAL_EXPAND_PER_CITY)
		if action == "research":
			action = "build_army"
		if not _rival_can_apply_action(action, state):
			action = "idle"
		var next_state: Dictionary = RIVAL_AI_MODEL.next_state(state, action)
		r["treasury"] = float(next_state.get("gold", state.gold))
		r["model_army"] = int(next_state.get("army", state.army))
		_apply_rival_action(r, action)
		r["last_action"] = action
		if summaries.size() < 2:
			summaries.append("%s %s" % [_rival_short_name(r), action.replace("_", " ")])
	if summaries.is_empty():
		_rival_activity = "watching borders"
	else:
		_rival_activity = "; ".join(summaries)


func _rival_can_apply_action(action: String, state: Dictionary) -> bool:
	match action:
		"expand":
			return float(state.get("gold", 0.0)) >= 50.0
		"build_army":
			return float(state.get("gold", 0.0)) >= 30.0
		"attack":
			return float(state.get("gold", 0.0)) >= 12.0 and RIVAL_AI_MODEL.should_attack(state, _player_strength())
		"fortify":
			return float(state.get("gold", 0.0)) >= 40.0
	return true


func _apply_rival_action(r: Dictionary, action: String) -> void:
	match action:
		"expand":
			_rival_expand(r)
		"build_army":
			_rival_spawn_unit(r)
		"attack":
			_rival_order_attack(r)
		"fortify":
			r["hp_mult"] = minf(float(r.get("hp_mult", 1.0)) + 0.02, 1.6)


func _player_strength() -> float:
	return maxf(1.0, float(_cities.size() * 2 + _player_unit_count(true) + _defense_bonus))


func _rival_short_name(r: Dictionary) -> String:
	return Genome.archetype_label(str(r.get("archetype", "tribe")))


# --- Process ---

func _process(delta: float) -> void:
	_elapsed += delta
	_civ_sim_t += delta
	if _civ_sim_t >= CIV_SIM_INTERVAL:
		var sim_delta := _civ_sim_t
		_civ_sim_t = 0.0
		_tick_civ_sim(sim_delta)
	for r in RES:
		_res_f[r] += _income_rate(r) * delta
		_res[r] = int(_res_f[r])
	if _build_queue.size() > 0:
		_build_queue[0].time_left -= delta
		if _build_queue[0].time_left <= 0.0:
			var done: Dictionary = _build_queue.pop_front()
			_complete_building(done.name)
	_tick_workers(delta)
	_tick_roamers(delta)
	_tick_rivals(delta)
	_tick_combat(delta)
	_tick_ground_follow(delta)
	_tick_siege_prompt(delta)
	_cleanup_dead()
	_tick_diplomacy(delta)
	_check_endgame()
	_update_status()
	_update_minimap()


func _tick_workers(delta: float) -> void:
	for w in _workers:
		if not is_instance_valid(w): continue
		var home: Vector3 = w.get_meta("home", Vector3.ZERO)
		var res: String = str(w.get_meta("res", "food"))
		match str(w.get_meta("phase", "seek")):
			"gather":
				UnitAnimator.play(w, "gather")   # working the node: dig/plant/water/pick/pull (farm pack)
				var gt := float(w.get_meta("gather_t", 0.0)) - delta
				if gt <= 0.0:
					w.set_meta("phase", "carry")
					w.set_meta("target", _nearest_city_pos(w.position))
				else:
					w.set_meta("gather_t", gt)
			"carry":
				# hauling the load home (HoldWalk / Barrow set), then deposit and seek a fresh node
				if _walk_worker_to(w, w.get_meta("target", home), delta, "carry"):
					w.set_meta("phase", "seek")
					w.set_meta("target", _nearest_node(res, w.position))
			_:
				if _walk_worker_to(w, w.get_meta("target", home), delta, "walk"):
					w.set_meta("phase", "gather")
					w.set_meta("gather_t", WORKER_GATHER_TIME)


# Step a worker toward `target` on the ground plane; plays `move_state` while walking, faces travel,
# and returns true once it arrives. The economy loop drives phase changes off this.
func _walk_worker_to(w: Node3D, target: Vector3, delta: float, move_state: String) -> bool:
	var flat := Vector3(target.x, w.position.y, target.z)
	var to := flat - w.position
	var d := to.length()
	if d < 1.2:
		return true
	UnitAnimator.play(w, move_state)
	var motion := to / d
	var spd: float = WORKER_SPEED * float(w.get_meta("speed_mult", 1.0))
	w.position += motion * spd * delta
	var look := w.global_position + motion
	if w.global_position.distance_to(look) > 0.1:
		w.look_at(look, Vector3.UP, true)   # species front is +Z (matches _step_toward's atan2 facing)
	return false


# Nearest recorded harvest site of a resource (falls back to a spot near a city if none exist).
func _nearest_node(res: String, from: Vector3) -> Vector3:
	var best := from
	var best_d := INF
	for n: Variant in _resource_nodes.get(res, []):
		var dd: float = from.distance_squared_to(n)
		if dd < best_d:
			best_d = dd
			best = n
	if best_d == INF:
		return _nearest_city_pos(from) + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	return best


func _nearest_city_pos(from: Vector3) -> Vector3:
	var best := from
	var best_d := INF
	for c in _cities:
		var dd: float = from.distance_squared_to(c.position)
		if dd < best_d:
			best_d = dd
			best = c.position
	return best


func capture() -> Dictionary:
	return {
		"version": 1,
		"age": _age,
		"stage_done": _stage_done,
		"res": _res.duplicate(),
		"res_f": _res_f.duplicate(),
		"granary_bonus": _granary_bonus,
		"bonus_production": _bonus_production,
		"defense_bonus": _defense_bonus,
		"extra_move": _extra_move,
		"expansion": _expansion,
		"tech_index": _tech_index,
		"has_barracks": _has_barracks,
		"has_spaceport": _has_spaceport,
		"weapon_tier": _weapon_tier,
		"armor_tier": _armor_tier,
		"cities": _capture_cities(),
		"workers": _capture_workers(),
		"units": _capture_units(),
		"rivals": _capture_rivals(),
		"build_queue": _capture_build_queue(),
		"settler": _capture_settler(),
		"truce_until": _truce_until,
		"at_peace": _at_peace.duplicate(),
		"bandit_timer": _bandit_t,
		"wildlife_timer": _wildlife_t,
		"diplo_timer": _diplo_t,
		"elapsed": _elapsed,
		"civ_sim_timer": _civ_sim_t,
		"unrest": _unrest,
		"needs_production_mult": _needs_production_mult,
		"climate_co2": _climate_co2,
		"warming_deg": _warming_deg,
		"climate_production_mult": _climate_production_mult,
		"civ_buildings_by_type": _civ_buildings_by_type.duplicate(),
		"structures": _structures.map(func(st: Dictionary) -> Dictionary:
			return {"kind": st.kind, "cell": _vec2i_to_dict(st.cell)}),
		"chain_stock": _chain_stock.duplicate(),
		"chain_raw_progress": _chain_raw_progress.duplicate(),
		"chain_progress": _chain_progress.duplicate(),
		"chain_production_mult": _chain_production_mult,
		"bread_demand_acc": _bread_demand_acc,
		"rival_activity": _rival_activity,
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	_age = clampi(int(data.get("age", _age)), 0, AGES.size() - 1)
	_stage_done = bool(data.get("stage_done", _stage_done))
	_restore_number_dictionary(data.get("res_f", {}), _res_f, true)
	for r: String in RES:
		_res[r] = int(_res_f.get(r, 0.0))
	_restore_number_dictionary(data.get("res", {}), _res, false)
	_granary_bonus = _finite_float(data.get("granary_bonus", _granary_bonus), _granary_bonus)
	_bonus_production = int(data.get("bonus_production", _bonus_production))
	_defense_bonus = int(data.get("defense_bonus", _defense_bonus))
	_extra_move = int(data.get("extra_move", _extra_move))
	_expansion = int(data.get("expansion", _expansion))
	_tech_index = clampi(int(data.get("tech_index", _tech_index)), 0, TECHS.size())
	_has_barracks = bool(data.get("has_barracks", _has_barracks))
	_has_spaceport = bool(data.get("has_spaceport", _has_spaceport))
	_weapon_tier = maxi(0, int(data.get("weapon_tier", _weapon_tier)))
	_armor_tier = maxi(0, int(data.get("armor_tier", _armor_tier)))
	_clear_dynamic_state()
	_restore_cities(data.get("cities", []))
	_restore_settler(data.get("settler", {}))
	_restore_rivals(data.get("rivals", []))
	_restore_workers(data.get("workers", []))
	_restore_units(data.get("units", []))
	_restore_build_queue(data.get("build_queue", []))
	_truce_until = _finite_float(data.get("truce_until", _truce_until), _truce_until)
	_restore_int_key_dictionary(data.get("at_peace", {}), _at_peace)
	_bandit_t = _finite_float(data.get("bandit_timer", _bandit_t), _bandit_t)
	_wildlife_t = _finite_float(data.get("wildlife_timer", _wildlife_t), _wildlife_t)
	_diplo_t = _finite_float(data.get("diplo_timer", _diplo_t), _diplo_t)
	_elapsed = _finite_float(data.get("elapsed", _elapsed), _elapsed)
	_civ_sim_t = _finite_float(data.get("civ_sim_timer", _civ_sim_t), _civ_sim_t)
	_unrest = clampf(_finite_float(data.get("unrest", _unrest), _unrest), 0.0, 1.0)
	_needs_production_mult = _finite_float(data.get("needs_production_mult", _needs_production_mult), _needs_production_mult)
	_climate_co2 = _finite_float(data.get("climate_co2", _climate_co2), _climate_co2)
	_warming_deg = _finite_float(data.get("warming_deg", _warming_deg), _warming_deg)
	_climate_production_mult = _finite_float(data.get("climate_production_mult", _climate_production_mult), _climate_production_mult)
	_restore_number_dictionary(data.get("civ_buildings_by_type", {}), _civ_buildings_by_type, false)
	_structures.clear()
	for st: Variant in data.get("structures", []):
		if st is Dictionary and BUILDINGS.has(str(st.get("kind", ""))):
			_structures.append({kind = str(st.kind), cell = _dict_to_vec2i(st.get("cell", {}), Vector2i.ZERO)})
	_restore_number_dictionary(data.get("chain_stock", {}), _chain_stock, false)
	_restore_number_dictionary(data.get("chain_raw_progress", {}), _chain_raw_progress, true)
	_restore_number_dictionary(data.get("chain_progress", {}), _chain_progress, true)
	_chain_production_mult = _finite_float(data.get("chain_production_mult", _chain_production_mult), _chain_production_mult)
	_bread_demand_acc = _finite_float(data.get("bread_demand_acc", _bread_demand_acc), _bread_demand_acc)
	_rival_activity = str(data.get("rival_activity", _rival_activity))
	EvolutionState.civ_cities = _cities.size()
	EvolutionState.civ_age = _age
	EvolutionState.civ_army = _player_unit_count(true)
	_update_status()
	_update_minimap()


func _capture_cities() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for city_val: Variant in _cities:
		if not (city_val is Dictionary):
			continue
		var city: Dictionary = city_val
		out.append({
			"cell": _vec2i_to_dict(city.get("cell", Vector2i.ZERO)),
			"faction": int(city.get("faction", 0)),
			"production_rate": int(city.get("production_rate", 1)),
			"max_population": int(city.get("max_population", 5)),
			"tint": city.get("tint", Color(0.5, 0.7, 1.0)),
			"buildings": _capture_buildings(city),
			"decor": _capture_decor(city),
		})
	return out


func _capture_buildings(city: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Node3D in city.get("buildings", []):
		if is_instance_valid(b):
			out.append({"kind": str(b.get_meta("kind", "")), "plot": _vec2i_to_dict(b.get_meta("plot", city.get("cell", Vector2i.ZERO)))})
	return out


func _capture_decor(city: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Node3D in city.get("decor", []):
		if is_instance_valid(d) and d.has_meta("model_id"):
			out.append({"model": str(d.get_meta("model_id")), "spot": _vec3_to_dict(d.get_meta("spot"))})
	return out


func _capture_workers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for worker: Node3D in _workers:
		if not is_instance_valid(worker):
			continue
		out.append({
			"res": str(worker.get_meta("res", "food")),
			"position": _vec3_to_dict(_unlifted(worker)),
			"home": _vec3_to_dict(worker.get_meta("home", worker.position)),
			"wander_target": _vec3_to_dict(worker.get_meta("wander_target", worker.position)),
		})
	return out


func _capture_units() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for unit_val: Variant in _units:
		if not (unit_val is Dictionary):
			continue
		var unit: Dictionary = unit_val
		var node: Node3D = unit.get("node", null)
		if not is_instance_valid(node):
			continue
		out.append({
			"faction": int(unit.get("faction", 0)),
			"unit_type": str(unit.get("unit_type", "Soldier")),
			"position": _vec3_to_dict(_unlifted(node)),
			"max_hp": _finite_float(unit.get("max_hp", 1.0), 1.0),
			"hp": _finite_float(unit.get("hp", 1.0), 1.0),
			"damage": _finite_float(unit.get("damage", 1.0), 1.0),
			"attack_range": _finite_float(unit.get("attack_range", 3.5), 3.5),
			"attack_cd": _finite_float(unit.get("attack_cd", 1.0), 1.0),
			"cd": _finite_float(unit.get("cd", 0.0), 0.0),
			"speed": _finite_float(unit.get("speed", 0.0), 0.0),
			"commanded": bool(unit.get("commanded", false)),
			"command_pos": _vec3_to_dict(unit.get("command_pos", Vector3.ZERO)),
		})
	return out


func _capture_rivals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rival_val: Variant in _rivals:
		if not (rival_val is Dictionary):
			continue
		var rival: Dictionary = rival_val
		var city_positions: Array[Dictionary] = []
		for pos_val: Variant in rival.get("cities", []):
			city_positions.append(_vec3_to_dict(pos_val))
		out.append({
			"faction": int(rival.get("faction", 1)),
			"cities": city_positions,
			"treasury": _finite_float(rival.get("treasury", 0.0), 0.0),
			"age": int(rival.get("age", 0)),
			"age_t": _finite_float(rival.get("age_t", 0.0), 0.0),
			"train_t": _finite_float(rival.get("train_t", 0.0), 0.0),
			"think_t": _finite_float(rival.get("think_t", 0.0), 0.0),
			"expand_salt": int(rival.get("expand_salt", 0)),
			"tint": rival.get("tint", FACTION_COLORS[1]),
			"archetype": str(rival.get("archetype", "tribe")),
			"prefer": str(rival.get("prefer", "Soldier")),
			"hp_mult": _finite_float(rival.get("hp_mult", 1.0), 1.0),
			"dmg_mult": _finite_float(rival.get("dmg_mult", 1.0), 1.0),
			"aggression": _finite_float(rival.get("aggression", 0.6), 0.6),
			"expand": _finite_float(rival.get("expand", 0.4), 0.4),
			"train_interval": _finite_float(rival.get("train_interval", 3.5), 3.5),
			"model_army": int(rival.get("model_army", 0)),
			"last_action": str(rival.get("last_action", "idle")),
		})
	return out


func _capture_build_queue() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry_val: Variant in _build_queue:
		if entry_val is Dictionary:
			var entry: Dictionary = entry_val
			out.append({"name": str(entry.get("name", "")), "time_left": _finite_float(entry.get("time_left", 0.0), 0.0)})
	return out


func _capture_settler() -> Dictionary:
	return {
		"active": _settler != null and is_instance_valid(_settler),
		"position": _vec3_to_dict(_unlifted(_settler) if _settler != null and is_instance_valid(_settler) else _settler_pos),
	}


func _clear_dynamic_state() -> void:
	for city_val: Variant in _cities:
		if city_val is Dictionary:
			var city_node: Node3D = (city_val as Dictionary).get("node", null)
			if is_instance_valid(city_node):
				city_node.queue_free()
			var rally_marker: Node3D = (city_val as Dictionary).get("rally_marker", null)
			if is_instance_valid(rally_marker):
				rally_marker.queue_free()
			for decor_val: Variant in (city_val as Dictionary).get("decor", []):
				if is_instance_valid(decor_val):
					(decor_val as Node).queue_free()
	for worker: Node3D in _workers:
		if is_instance_valid(worker):
			worker.queue_free()
	for unit_val: Variant in _units:
		if unit_val is Dictionary:
			var unit_node: Node3D = (unit_val as Dictionary).get("node", null)
			if is_instance_valid(unit_node):
				unit_node.queue_free()
	for rival_val: Variant in _rivals:
		if not (rival_val is Dictionary):
			continue
		var rival: Dictionary = rival_val
		for node_val: Variant in rival.get("city_nodes", []):
			if is_instance_valid(node_val):
				(node_val as Node).queue_free()
		for decor_list: Variant in rival.get("city_decor", []):
			if decor_list is Array:
				for decor_val: Variant in decor_list:
					if is_instance_valid(decor_val):
						(decor_val as Node).queue_free()
	if _settler != null and is_instance_valid(_settler):
		_settler.queue_free()
	_settler = null
	_cities.clear()
	_units.clear()
	_workers.clear()
	_bandits.clear()
	_wildlife.clear()
	_selected.clear()
	_control_groups.clear()   # held unit dicts are about to be freed/replaced
	_rivals.clear()
	_build_queue.clear()


func _restore_cities(value: Variant) -> void:
	if not (value is Array):
		return
	for item: Variant in value:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item
		var cell: Vector2i = _dict_to_vec2i(entry.get("cell", {}), Vector2i.ZERO)
		_add_city_at(cell)
		var city: Dictionary = _cities.back()
		city["faction"] = int(entry.get("faction", 0))
		city["production_rate"] = int(entry.get("production_rate", city.get("production_rate", 1)))
		city["max_population"] = int(entry.get("max_population", city.get("max_population", 5)))
		city["tint"] = entry.get("tint", city.get("tint", Color(0.5, 0.7, 1.0)))
		var saved_buildings: Variant = entry.get("buildings", [])
		if saved_buildings is Array:
			for b_val: Variant in saved_buildings:
				if b_val is Dictionary and BUILDINGS.has(str((b_val as Dictionary).get("kind", ""))):
					var b: Dictionary = b_val
					_stand_building(city, str(b.kind), _dict_to_vec2i(b.get("plot", {}), city.cell))
		_restore_decor(city, entry.get("decor", null))


# Stand the saved props back up verbatim: re-rolling them here would see a different set of
# blocked hexes (turrets and later cities are not back yet). An old save has none and keeps the roll.
func _restore_decor(city: Dictionary, saved: Variant) -> void:
	if not (saved is Array):
		return
	for old: Node3D in city.get("decor", []):
		if is_instance_valid(old):
			old.queue_free()
	var decor: Array[Node3D] = []
	for d_val: Variant in saved:
		if d_val is Dictionary:
			var d: Dictionary = d_val
			var n := _stand_decor(str(d.get("model", "")), _dict_to_vec3(d.get("spot", {}), city.position))
			if n != null:
				decor.append(n)
	city["decor"] = decor


func _restore_settler(value: Variant) -> void:
	if not (value is Dictionary):
		return
	var entry: Dictionary = value
	if not bool(entry.get("active", false)):
		return
	var pos := _dict_to_vec3(entry.get("position", {}), _settler_pos)
	pos.y = 0.0   # the save holds the pawn's raised height; _create_settler_node raises it again
	_create_settler_node(pos)


func _restore_workers(value: Variant) -> void:
	if not (value is Array):
		return
	var sp: String = EvolutionState.species_name if EvolutionState.species_name != "" else "human"
	for item: Variant in value:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item
		var res_id: String = str(entry.get("res", "food"))
		var pos: Vector3 = _dict_to_vec3(entry.get("position", {}), Vector3.ZERO)
		var worker := _spawn_species_unit(sp, pos, 0.85)
		if worker == null:
			continue
		SpeciesVisuals.express(worker, EvolutionState.genome, false)
		GenomeFeatures3D.apply(worker, EvolutionState.genome, sp, 0.25)
		worker.set_meta("res", res_id)
		worker.set_meta("home", _dict_to_vec3(entry.get("home", {}), pos))
		worker.set_meta("phase", "seek")
		worker.set_meta("speed_mult", GenomeBonus.speed_mult(EvolutionState.genome))
		worker.set_meta("target", _nearest_node(res_id, pos))
		_workers.append(worker)


func _restore_units(value: Variant) -> void:
	if not (value is Array):
		return
	for item: Variant in value:
		if item is Dictionary:
			_restore_unit(item)


func _restore_unit(entry: Dictionary) -> void:
	var unit_type: String = str(entry.get("unit_type", "Soldier"))
	var faction: int = int(entry.get("faction", 0))
	var pos: Vector3 = _dict_to_vec3(entry.get("position", {}), Vector3.ZERO)
	var node: Node3D = _spawn_unit_visual(unit_type, faction, pos, _finite_float(entry.get("speed", 0.0), 0.0))
	if node == null:
		return
	var unit := {
		"node": node,
		"faction": faction,
		"unit_type": unit_type,
		"max_hp": _finite_float(entry.get("max_hp", 1.0), 1.0),
		"hp": _finite_float(entry.get("hp", 1.0), 1.0),
		"damage": _finite_float(entry.get("damage", 1.0), 1.0),
		"attack_range": _finite_float(entry.get("attack_range", 3.5), 3.5),
		"attack_cd": _finite_float(entry.get("attack_cd", 1.0), 1.0),
		"cd": _finite_float(entry.get("cd", 0.0), 0.0),
		"speed": _finite_float(entry.get("speed", 0.0), 0.0),
		"target": null,
		"commanded": bool(entry.get("commanded", false)),
		"command_pos": _dict_to_vec3(entry.get("command_pos", {}), Vector3.ZERO),
	}
	_units.append(unit)
	if faction == 0 and DEFENSES.has(unit_type):
		_mark_obstacle_cell(_cell_at(pos))
	if faction == BANDIT_FAC:
		_bandits.append(unit)
	elif faction == WILD_FAC or faction == PREDATOR_FAC:
		_wildlife.append(unit)
	else:
		for rival_val: Variant in _rivals:
			if rival_val is Dictionary and int((rival_val as Dictionary).get("faction", -1)) == faction:
				((rival_val as Dictionary).get("units", []) as Array).append(unit)
				break


# Spawn a humanoid unit as a rigged species mesh (the animated RTS look), idle by default. No flat
# tint — that would replace the texture; callers express() the player genome where they have one.
func _spawn_species_unit(species: String, pos: Vector3, height_mult: float = 1.0) -> Node3D:
	var node := spawn_model(SpeciesVisuals.model_path(species), pos, SpeciesVisuals.norm_scale(species) * UNIT_BODY_HEIGHT * height_mult, 0)
	if node != null:
		UnitAnimator.play(node, "idle")
	return node


# UNIT-TYPE-IDENTITY: make unit TYPES distinct at a glance without recoloring the textured body.
# Applies a per-type body-scale tweak and bolts on a small emissive role prop. Called from every
# humanoid spawn path (player/rival/restore) right after the mesh + skin are set up. The species
# skin (express) is untouched; we only add a child node and nudge the node's uniform scale.
func _apply_unit_identity(node: Node3D, unit_type: String, faction: int) -> void:
	if node == null:
		return
	var vis: Dictionary = UNIT_VISUAL.get(unit_type, UNIT_VISUAL_DEFAULT)
	# Per-type body scale: tanks read bigger, drones smaller, infantry baseline. The node already
	# carries the norm→tile-fit scale, so we multiply rather than overwrite.
	node.scale *= float(vis.get("scale", 1.0))
	# Accent = type's base hue tinted toward the faction color so allegiance + type both read.
	var fac_col: Color = FACTION_COLORS[clampi(faction, 0, FACTION_COLORS.size() - 1)]
	var accent: Color = (vis.get("accent", Color.WHITE) as Color).lerp(fac_col, 0.35)
	# Measure the body first (node-local, so the scale above does not matter): the prop is built for a
	# body 1 tall with its feet at 0, then scaled and seated on that measured box.
	var body := _root_aabb(node)
	var height := maxf(body.size.y, 0.0001)
	var prop := _build_unit_prop(str(vis.get("weapon", "blade")), accent, body.size.x * 0.5 / height)
	if prop != null:
		prop.name = "TypeProp"
		prop.position = Vector3(body.get_center().x, body.position.y, body.get_center().z)
		prop.scale = Vector3.ONE * height
		node.add_child(prop)


# Builds a unit's role prop from a few unshaded/emissive primitives. Sized for a body 1 unit tall with
# its feet at y=0 (the caller scales and seats it on the measured body); `half_width` is the body's
# half-width in those units, so side props sit on the body. Every prop is held or worn at hand,
# shoulder, back or chest height, never floating; precision isn't needed at RTS tile scale.
func _build_unit_prop(weapon: String, accent: Color, half_width: float) -> Node3D:
	var root := Node3D.new()
	var side := half_width * 0.6
	match weapon:
		"blade":   # short sword held at the right side
			_add_prim(root, BoxMesh.new(), Vector3(0.07, 0.45, 0.07), Vector3(side, 0.5, 0.05), accent)
		"spear":   # long pole taller than the bearer (Bronze-age spear)
			_add_prim(root, CylinderMesh.new(), Vector3(0.04, 1.35, 0.04), Vector3(side, 0.7, 0.05), accent)
		"bow":     # tall thin rod (the bow stave) plus a notch
			_add_prim(root, CylinderMesh.new(), Vector3(0.05, 0.55, 0.05), Vector3(side, 0.6, 0.0), accent)
		"rifle":   # boxy long arm held forward
			_add_prim(root, BoxMesh.new(), Vector3(0.1, 0.12, 0.5), Vector3(side, 0.6, 0.15), accent)
		"cannon":  # fat cylinder barrel at chest height pointing forward (tanks)
			_add_prim(root, CylinderMesh.new(), Vector3(0.16, 0.5, 0.16), Vector3(0.0, 0.65, 0.25), accent, Vector3(90, 0, 0))
		"coil":    # emissive rod worn on the back, rising past the shoulders (tesla)
			_add_prim(root, CylinderMesh.new(), Vector3(0.09, 0.5, 0.09), Vector3(0.0, 0.8, -0.05), accent)
		"orb":     # small sphere at the shoulder (drone)
			_add_prim(root, SphereMesh.new(), Vector3(0.28, 0.28, 0.28), Vector3(side, 0.8, 0.0), accent)
		_:
			_add_prim(root, BoxMesh.new(), Vector3(0.1, 0.1, 0.1), Vector3(side, 0.7, 0.0), accent)
	return root


# Attach one emissive primitive to `root`. `size` sets the mesh extents, `offset` its local position,
# `rot_deg` an optional rotation. Material is unshaded + emissive so the prop pops regardless of light.
func _add_prim(root: Node3D, mesh: Mesh, size: Vector3, offset: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		c.height = size.y
		c.top_radius = size.x * 0.5
		c.bottom_radius = size.x * 0.5
	elif mesh is SphereMesh:
		var s := mesh as SphereMesh
		s.radius = size.x * 0.5
		s.height = size.y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat   # override (not surface material) so the emissive prop reads regardless of mesh surfaces
	mi.position = offset
	mi.rotation_degrees = rot_deg
	root.add_child(mi)


# The species mesh a rival faction renders as (its archetype → one of the 5 rigs). Falls back to human.
func _rival_species_for_faction(faction: int) -> String:
	for rv: Variant in _rivals:
		if rv is Dictionary and int((rv as Dictionary).get("faction", -1)) == faction:
			return str(RIVAL_SPECIES.get(str((rv as Dictionary).get("archetype", "tribe")), "human"))
	return "human"


func _spawn_unit_visual(unit_type: String, faction: int, pos: Vector3, speed: float) -> Node3D:
	if unit_type in DEFENSES or speed <= 0.0:
		var def_model: String = DEFENSE_MODELS.get(unit_type, "weapon-turret")
		return spawn_model(TD % def_model, pos, TILE_3D * 0.5, 0, FACTION_COLORS[clampi(faction, 0, FACTION_COLORS.size() - 1)])
	if faction == BANDIT_FAC:
		return spawn_model(TD % BANDIT_MODEL, pos, 0.6, 0, Color(0.6, 0.45, 0.3))
	if faction == WILD_FAC or faction == PREDATOR_FAC:
		var animal := AnimalModels.attach(self, unit_type, TILE_3D * 0.28)
		if animal != null:
			animal.position = pos
		return animal
	# Humanoid combat units: player faction = your lineage; rival factions = their archetype's species.
	var species: String = (EvolutionState.species_name if EvolutionState.species_name != "" else "human") if faction == 0 else _rival_species_for_faction(faction)
	var node := _spawn_species_unit(species, pos)
	if node != null and faction == 0:
		SpeciesVisuals.express(node, EvolutionState.genome, false)
	if node != null:
		_apply_unit_identity(node, unit_type, faction)   # per-type scale + emissive role prop (restore)
	return node


func _restore_rivals(value: Variant) -> void:
	if not (value is Array):
		return
	for item: Variant in value:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item
		var fac: int = int(entry.get("faction", _rivals.size() + 1))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s_rival_%d" % [EvolutionState.world_seed, fac])
		var tint_val: Variant = entry.get("tint", FACTION_COLORS[fac % FACTION_COLORS.size()])
		var tint: Color = tint_val if tint_val is Color else FACTION_COLORS[fac % FACTION_COLORS.size()]
		var rival := {
			"faction": fac,
			"cities": [],
			"city_nodes": [],
			"city_decor": [],
			"city_targets": [],
			"treasury": _finite_float(entry.get("treasury", 8.0), 8.0),
			"age": clampi(int(entry.get("age", 0)), 0, AGES.size() - 1),
			"age_t": _finite_float(entry.get("age_t", 0.0), 0.0),
			"train_t": _finite_float(entry.get("train_t", 0.0), 0.0),
			"think_t": _finite_float(entry.get("think_t", 0.0), 0.0),
			"expand_salt": int(entry.get("expand_salt", 0)),
			"tint": tint,
			"archetype": str(entry.get("archetype", "tribe")),
			"prefer": str(entry.get("prefer", "Soldier")),
			"hp_mult": _finite_float(entry.get("hp_mult", 1.0), 1.0),
			"dmg_mult": _finite_float(entry.get("dmg_mult", 1.0), 1.0),
			"aggression": _finite_float(entry.get("aggression", 0.6), 0.6),
			"expand": _finite_float(entry.get("expand", 0.4), 0.4),
			"train_interval": _finite_float(entry.get("train_interval", 3.5), 3.5),
			"units": [],
			"rng": rng,
			"model_army": int(entry.get("model_army", 0)),
			"last_action": str(entry.get("last_action", "idle")),
		}
		for city_pos_val: Variant in entry.get("cities", []):
			_rival_add_city(rival, _dict_to_vec3(city_pos_val, Vector3.ZERO))
		_rivals.append(rival)


func _restore_build_queue(value: Variant) -> void:
	_build_queue.clear()
	if not (value is Array):
		return
	for item: Variant in value:
		if item is Dictionary:
			var entry: Dictionary = item
			_build_queue.append({"name": str(entry.get("name", "")), "time_left": maxf(0.0, _finite_float(entry.get("time_left", 0.0), 0.0))})


func _restore_number_dictionary(value: Variant, target: Dictionary, floats: bool) -> void:
	if not (value is Dictionary):
		return
	target.clear()
	for key: Variant in (value as Dictionary).keys():
		target[str(key)] = _finite_float((value as Dictionary)[key], 0.0) if floats else int((value as Dictionary)[key])


func _restore_int_key_dictionary(value: Variant, target: Dictionary) -> void:
	target.clear()
	if not (value is Dictionary):
		return
	for key: Variant in (value as Dictionary).keys():
		target[int(str(key))] = _finite_float((value as Dictionary)[key], 0.0)


func _vec2i_to_dict(value: Variant) -> Dictionary:
	var v: Vector2i = value if value is Vector2i else Vector2i.ZERO
	return {"x": v.x, "y": v.y}


func _dict_to_vec2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		return Vector2i(int(d.get("x", fallback.x)), int(d.get("y", fallback.y)))
	return fallback


func _vec3_to_dict(value: Variant) -> Dictionary:
	var v: Vector3 = value if value is Vector3 else Vector3.ZERO
	return {"x": v.x, "y": v.y, "z": v.z}


func _dict_to_vec3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		return Vector3(
			_finite_float(d.get("x", fallback.x), fallback.x),
			_finite_float(d.get("y", fallback.y), fallback.y),
			_finite_float(d.get("z", fallback.z), fallback.z)
		)
	return fallback


func _finite_float(value: Variant, fallback: float) -> float:
	var f: float = float(value)
	return f if is_finite(f) else fallback
