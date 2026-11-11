## Global signal bus. Autoload (loaded first). Decouples stages, UI, and state so
## nothing needs a direct reference to anything else.
##
## Also registers the movement input actions in code, so the project doesn't depend
## on a hand-edited [input] block in project.godot.
extends Node

# Signals on a bus are emitted/consumed by other classes, so the "unused in this
# class" warning is a false positive here.
@warning_ignore_start("unused_signal")
## Emitted when the player germ consumes a food mote. `amount` is nutrition (0..1 of the bar).
signal mote_eaten(amount: float)
## Emitted whenever evolution progress for the current stage changes (0..1).
signal evolution_progress_changed(progress: float)
## Emitted when the current stage's win condition is met. `stage` is an EvolutionState.Stage int.
signal stage_complete(stage: int)
## Emitted by StageManager after a new stage scene is loaded.
signal stage_changed(stage: int)
## Emitted when the final stage is completed.
signal game_won()
## Emitted when the run is lost (e.g. all your Civ-stage cities are razed). `reason` is shown.
signal game_lost(reason: String)
## Generic transient on-screen notice (toast). Any stage can emit; the Toasts autoload shows it.
signal notify(text: String)
## Emitted when the global sim speed changes. `scale` is always 0, 1, 2, or 3.
signal speed_changed(scale: float)
## Emitted when a city is founded. `position` is its world position.
signal city_created(position: Vector2)
## Emitted when a tech finishes researching.
signal tech_researched(tech_name: String)
## Emitted when the player takes damage (e.g. touches a virus). `amount` is the evolution setback.
signal player_harmed(amount: float)
## Emitted when the player eats an edible microbe. `species` feeds the diet → creature mechanic.
signal microbe_eaten(species: String)
## Emitted when the player consumes a roster food. Carries the full FoodRoster entry
## (id/type/nutrition/nudges/tint) so EvolutionState can apply progress + the genome change.
signal food_consumed(food: Dictionary)
## Emitted when evolution progress crosses a budding milestone — the player ejects a
## defensive spore. `strength` is the genome's defense axis (sizes/extends the spore).
signal spore_budded(strength: float)
@warning_ignore_restore("unused_signal")


func _ready() -> void:
	_register_input()


func _register_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])


func _add_action(action_name: String, keys: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action_name, ev)
