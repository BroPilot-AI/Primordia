## Owns the stage lifecycle: instantiates the current stage scene, frees the old
## one on transition, and advances when a stage reports completion. Autoload.
##
## Stage order is the array below; index aligns with EvolutionState.Stage.
extends Node

const STAGE_SCENES := [
	"res://src/stages/primordial/PrimordialStage.tscn",    # 0 PRIMORDIAL
	"res://src/stages/creature/CreatureStage3D.tscn",      # 1 CREATURE — 3D survival
	"res://src/stages/tribe/TribeStage3D.tscn",            # 2 TRIBE — 3D forage
	"res://src/stages/civ/CivStage3D.tscn",                # 3 CIV — 3D RTS
	"res://src/stages/space/SpaceStage3D.tscn",            # 4 SPACE (terminal)
]

const TRANSITION_CARDS := {
	0: {
		"asset": "res://assets/sprites/transition_microbe_creature.png",
		"caption": "From the soup, a body. The first creature hauls itself into the world.",
	},
	1: {
		"asset": "res://assets/sprites/transition_creature_tribe.png",
		"caption": "No longer alone. Your kind gathers around the first fire.",
	},
	2: {
		"asset": "res://assets/sprites/transition_tribe_civ.png",
		"caption": "Huts become walls. The dawn of civilization breaks.",
	},
	3: {
		"asset": "res://assets/sprites/transition_civ_space.png",
		"caption": "The planet can no longer hold you. Life reaches for the stars.",
	},
}

## Node the stage scenes are parented under (provided by Main).
var _root: Node
var _current: Node
var _index := 0
var _transition_open := false
var debug_jumping := false   ## true while a DEBUG stage-jump loads (Main skips the morph cutscene)


func _ready() -> void:
	Events.stage_complete.connect(_on_stage_complete)


## Called once by Main to kick off a fresh run.
func start(root: Node) -> void:
	_root = root
	_index = 0
	_load_current(true, {})


## Resume from a saved checkpoint — load a specific stage (EvolutionState already restored by
## SaveManager). reset_for_stage (in _load_current) preserves the carried state, only re-zeroing
## per-stage progress, so the restored genome/traits/payload survive.
func continue_at(root: Node, index: int, stage_snapshot: Dictionary = {}) -> void:
	_root = root
	_index = clampi(index, 0, STAGE_SCENES.size() - 1)
	_load_current(false, stage_snapshot)


## Re-runs the current stage in-place (preserves the carried-over cross-stage state in
## EvolutionState — genome, biomass, traits, civ_*, etc. — but resets the per-stage
## progress bar and reloads the stage scene fresh). Used by the defeat screen's
## "Retry Stage" button.
func retry_current_stage() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_load_current(true, {})


## DEBUG: jump straight to any stage with a ready default genome so a stage can be tested
## without playing through the earlier ones. Skips the morph cutscene (Main checks `debug_jumping`).
func debug_jump(root: Node, index: int) -> void:
	_root = root
	_index = clampi(index, 0, STAGE_SCENES.size() - 1)
	if EvolutionState.genome == null:
		EvolutionState.set_starting_biome(0)   # default FRESHWATER lineage so later stages have state
	EvolutionState.start_run_clock()
	debug_jumping = true
	_load_current(true, {})
	debug_jumping = false


func current_stage_node() -> Node:
	return _current if _current != null and is_instance_valid(_current) else null


func stage_root() -> Node:
	return _root if _root != null and is_instance_valid(_root) else null


func _load_current(reset_state: bool, stage_snapshot: Dictionary) -> void:
	if _current and is_instance_valid(_current):
		var parent: Node = _current.get_parent()
		if parent != null:
			parent.remove_child(_current)
		_current.queue_free()
	if reset_state:
		EvolutionState.reset_for_stage(_index)
	else:
		EvolutionState.current_stage = _index
	var packed: PackedScene = load(STAGE_SCENES[_index])
	_current = packed.instantiate()
	_root.add_child(_current)
	if not stage_snapshot.is_empty() and _current.has_method("restore"):
		_current.call("restore", stage_snapshot)
	Events.evolution_progress_changed.emit(EvolutionState.progress)
	Events.stage_changed.emit(_index)


func _on_stage_complete(_stage: int) -> void:
	if _transition_open:
		return
	if _index >= STAGE_SCENES.size() - 1:
		_on_final_stage_complete()
		return
	if not TRANSITION_CARDS.has(_index):
		_advance_to_next_stage()
		return

	_transition_open = true
	var data: Dictionary = TRANSITION_CARDS[_index]
	StoryCard.show_transition_card(
		_transition_parent(),
		"EVOLUTION LEAP",
		String(data.get("caption", "")),
		String(data.get("asset", "")),
		Callable(self, "_on_transition_card_dismissed")
	)


func _on_transition_card_dismissed() -> void:
	_transition_open = false
	_advance_to_next_stage()


func _advance_to_next_stage() -> void:
	if _index >= STAGE_SCENES.size() - 1:
		_on_final_stage_complete()
		return
	_index += 1
	_load_current(true, {})


func _on_final_stage_complete() -> void:
	# SPACE completion is terminal: Main shows the victory card on `game_won`.
	Events.game_won.emit()


func _transition_parent() -> Node:
	return _root if _root != null and is_instance_valid(_root) else self
