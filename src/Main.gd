## Root node. Shows the title screen; on a chosen origin it hands itself to StageManager
## as the container for stage scenes, and shows the per-stage story card on each transition.
## Also owns the end-of-game screens (victory / defeat) — full-screen overlays that pause
## the sim and present the run's payoff.
extends Node2D

const EvolutionCutsceneScene := preload("res://src/common/EvolutionCutscene.gd")
## CanvasLayer.layer for end-of-game overlays. Above GameShell (200)? No — we want the
## pause menu accessible in theory, but the end card is terminal (Play Again / Main Menu /
## Retry Stage), so we sit above Toasts/StageIntro (150/120) and share the top band.
const END_CARD_LAYER := 210
## Saved Engine.time_scale snapshot for restoring the sim after the end card closes.
## Set in `_open_end_card`; read in `_close_end_card`. 0 means "clock was already paused".
var _saved_speed: float = 0.0


func _ready() -> void:
	Events.stage_changed.connect(_on_stage_changed)
	Events.game_won.connect(_on_game_won)
	Events.game_lost.connect(_on_game_lost)
	_show_title()


func _show_title() -> void:
	var title := TitleScreen.new()
	add_child(title)
	title.start_requested.connect(_on_start_requested)
	title.continue_requested.connect(_on_continue_requested)
	title._build(EvolutionState.planet_name)


## DEBUG stage-jump: Shift+1..5 loads any stage instantly (1=soup, 2=creature, 3=tribe, 4=civ,
## 5=space) with a ready genome. Debug builds only.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed and not event.echo and event.shift_pressed):
		return
	var k: int = (event as InputEventKey).keycode
	if k < KEY_1 or k > KEY_5:
		return
	for c in get_children():
		if c is TitleScreen:
			c.queue_free()
	StageManager.debug_jump(self, k - KEY_1)
	Events.notify.emit("DEBUG → stage %d" % (k - KEY_1 + 1))


func _on_start_requested(branch: int) -> void:
	if branch >= 0:
		EvolutionState.set_starting_biome(branch)
	# Start a fresh run clock — covers both "New Run" and the "Play Again" / "Main Menu"
	# paths (those reload the scene, then the player re-picks origin, then we land here).
	EvolutionState.start_run_clock()
	StageManager.start(self)


## Resume from the checkpoint save: SaveManager restores EvolutionState, then we load that stage.
func _on_continue_requested() -> void:
	var idx := SaveManager.load_into_state()
	if idx < 0:
		EvolutionState.start_run_clock()
		StageManager.start(self)
	else:
		# Continue restarts the clock so the elapsed-time readout reflects the current
		# session. The save doesn't carry the original start time, and freezing the clock
		# mid-session would feel wrong.
		EvolutionState.start_run_clock()
		StageManager.continue_at(self, idx, SaveManager.consume_stage_snapshot())


## Each stage shows its intro card (story + how-to-play) with `{biome}` filled in from
## the run's seeded biome. The StageIntro autoload owns the copy + the "?" button, so this
## hook just hands it the new stage index. From the second stage on, an evolution morph
## (your genome growing into the new body) plays first, then the intro card.
func _on_stage_changed(index: int) -> void:
	if StageManager.debug_jumping:
		return   # debug jump drops straight into the stage — skip the morph cutscene + intro card
	if not StageIntro.STAGE_CARDS.has(index):
		return
	var show_card := func() -> void: StageIntro.show_for_stage(index)

	# Stage 0 has no prior form to morph from — straight to the card. Later stages get the
	# evolution morph first, so the player watches their traits shape the new body.
	if index <= 0:
		show_card.call()
	else:
		var cutscene := EvolutionCutsceneScene.new()
		cutscene.begin(EvolutionState.genome, _morph_caption(index), show_card, index)
		add_child(cutscene)


func _morph_caption(index: int) -> String:
	match index:
		1: return "Life crawls ashore…"
		2: return "A people takes shape…"
		3: return "Bands rise into civilization…"
		4: return "Reaching for the stars…"
		_: return "Evolving…"


# -----------------------------------------------------------------------------------
# End-of-game screens — victory and defeat
# -----------------------------------------------------------------------------------
# Both fire from a single Events signal and pause the sim, build a full-screen card,
# and present a recap plus action buttons. The sim is only resumed when the player
# picks a button (Play Again / Retry Stage / Main Menu) — the card has no other
# dismissal path so a win/loss can't be skipped by accident.
#
# Space completion is the only producer of `game_won` (StageManager._on_final_stage_complete),
# so the win card here is the terminal frame. Defeat is fired from CivStage3D / SpaceStage3D
# when the player loses all cities / systems.

func _on_game_won() -> void:
	# Run complete — wipe the checkpoint so a "Continue" on the title screen can't
	# resurrect the won run. Stop the clock so the elapsed value freezes the moment
	# the card appears (matches the recap-line contract).
	SaveManager.clear()
	EvolutionState.stop_run_clock()

	# Defensive: if a previous EndCard is still on screen (e.g. a back-to-back win/loss),
	# free it so we don't stack overlays.
	_close_existing_end_card()

	var screen: CanvasLayer = _open_end_card(
		Color(0.02, 0.05, 0.04, 0.97),   # dim: warm dark green, opaque
		Color(0.86, 0.96, 0.78, 1.0),    # headline tint: pale jade
	)
	_build_card_into(
		screen,
		"LIFE HAS CONQUERED THE GALAXY",
		_win_recap(),
		[
			["Play Again", func() -> void: _play_again(screen)],
			["Main Menu",  func() -> void: _main_menu(screen)],
		],
	)


func _on_game_lost(reason: String) -> void:
	# Defeat — wipe the checkpoint (it would re-load the run that just lost) and freeze
	# the clock so the elapsed time shown on the card is the moment of death.
	SaveManager.clear()
	EvolutionState.stop_run_clock()

	# See _on_game_won — drop any prior EndCard before building a new one.
	_close_existing_end_card()

	var screen: CanvasLayer = _open_end_card(
		Color(0.05, 0.01, 0.01, 0.97),   # dim: deep blood-red, opaque
		Color(0.96, 0.78, 0.74, 1.0),    # headline tint: faded rose
	)
	var elapsed: String = EvolutionState.format_elapsed(EvolutionState.run_elapsed_seconds())
	var body := "%s\n\nRun time: %s\n%s" % [reason, elapsed, _chronicle_block()]
	_build_card_into(
		screen,
		"EXTINCTION",
		body,
		[
			["Retry Stage", func() -> void: _retry_stage(screen)],
			["Main Menu",   func() -> void: _main_menu(screen)],
		],
	)


func _hide_title_behind_end_card() -> void:
	for child in get_children():
		if child is TitleScreen:
			child.visible = false


## Free any existing EndCard on this Main without touching the sim. Used as a
## defensive pre-step when building a new end card so re-emits don't stack.
func _close_existing_end_card() -> void:
	for child in get_children():
		if child is CanvasLayer and child.name == "EndCard":
			# Remove from the tree IMMEDIATELY (not just queue_free) so the freshly built
			# EndCard added right after doesn't collide on the "EndCard" name — a deferred
			# free leaves the old node in-tree, and Godot would auto-rename the new one,
			# breaking every name-based lookup (the defeat-card re-emit bug).
			remove_child(child)
			child.queue_free()


# --- screen lifecycle ---------------------------------------------------------------

## Build a full-screen dim + card scaffold, pause the sim, and return the layer so the
## caller can populate it. The matching `_close_end_card` is invoked by the action
## buttons (Play Again / Retry Stage / Main Menu) to resume the sim and free the overlay.
func _open_end_card(dim_color: Color, headline_tint: Color) -> CanvasLayer:
	# Snapshot the current speed verbatim — a pre-existing 0.0 (the player was in
	# GameShell pause) stays 0.0 on close, and a positive speed is restored exactly.
	# This matches the StoryCard / StageIntro pause contract.
	_saved_speed = Engine.time_scale
	get_tree().paused = true
	Engine.time_scale = 0.0

	_hide_title_behind_end_card()

	var screen := CanvasLayer.new()
	screen.name = "EndCard"
	screen.layer = END_CARD_LAYER
	screen.process_mode = Node.PROCESS_MODE_ALWAYS   # dim card must accept clicks
	screen.set_meta("headline_tint", headline_tint)
	add_child(screen)

	# Catch-all root — eats every click behind the overlay so the dimmed stage can't
	# eat an event intended for our buttons.
	var root := Control.new()
	root.name = "EndCardRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(root)

	var dim := ColorRect.new()
	dim.name = "EndCardDim"
	dim.color = dim_color
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "EndCardCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	# Card panel — opaque so the dim doesn't bleed through. Reuses the StoryCard color
	# palette (the same forest-green + ivory theme the rest of the UI uses) so the end
	# card feels like a continuation, not a foreign element.
	var panel := PanelContainer.new()
	panel.name = "EndCardPanel"
	panel.custom_minimum_size = Vector2(760, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", StageChrome.modal_panel_style())
	center.add_child(panel)

	var inner := VBoxContainer.new()
	inner.name = "EndCardInner"
	inner.add_theme_constant_override("separation", 14)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)

	return screen


## Populate the card scaffold with a headline, body, and button row. The inner VBox
## is reached by walking the well-known names — keeps the wiring explicit.
func _build_card_into(screen: CanvasLayer, headline: String, body: String, buttons: Array) -> void:
	var inner: VBoxContainer = screen.find_child("EndCardInner", true, false) as VBoxContainer
	if inner == null:
		push_error("Main: EndCardInner missing — _open_end_card must be called first.")
		return

	var headline_label := StageChrome.era_label(headline)
	headline_label.name = "EndCardHeadline"
	headline_label.add_theme_color_override("font_color", screen.get_meta("headline_tint", StageChrome.TITLE))
	inner.add_child(headline_label)

	inner.add_child(StageChrome.h_sep())

	var body_label := StageChrome.body_label(body)
	body_label.name = "EndCardBody"
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.custom_minimum_size = Vector2(680, 0)
	inner.add_child(body_label)

	inner.add_child(StageChrome.h_sep())

	var row := HBoxContainer.new()
	row.name = "EndCardButtons"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(row)

	for spec: Array in buttons:
		var label_text: String = String(spec[0])
		var callback: Callable = spec[1] as Callable
		var btn := Button.new()
		btn.name = "EndCardBtn_" + label_text.replace(" ", "")
		btn.text = label_text
		StageChrome.style_button(btn, true)
		btn.custom_minimum_size = Vector2(200, StageChrome.BUTTON_HEIGHT_LG)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func() -> void:
			AudioManager.ui_click()
			_disable_buttons(row)
			if callback.is_valid():
				callback.call())
		row.add_child(btn)

	# Grab focus on the first button so Enter / Space dismisses the card (the buttons
	# are the only way out — there is no click-to-dismiss).
	var first_btn: Button = null
	for child in row.get_children():
		if child is Button:
			first_btn = child
			break
	if first_btn != null:
		first_btn.call_deferred("grab_focus")

	# Fade the card in — same cheap modulate tween the rest of the overlays use.
	# Must ignore time scale: the card opens at Engine.time_scale == 0.0, which would
	# otherwise freeze the tween at alpha 0 and leave the card content invisible.
	inner.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(inner, "modulate:a", 1.0, 0.35)


func _disable_buttons(row: HBoxContainer) -> void:
	for child in row.get_children():
		if child is Button:
			(child as Button).disabled = true


## Free the overlay and restore the sim to its pre-open state. Safe to call from any
## of the action buttons — idempotent on already-freed overlays. Always drops the
## SceneTree pause; restores the saved Engine.time_scale verbatim (0.0 if the player
## had GameShell-paused before the card opened, the original speed otherwise).
func _close_end_card(screen: CanvasLayer) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	Engine.time_scale = _saved_speed
	get_tree().paused = false


# --- action button handlers ---------------------------------------------------------

## Play Again — clear save, reset the run, reload the scene to the title. Identical
## semantics to Main Menu, but the label matches the player's intent.
func _play_again(screen: CanvasLayer) -> void:
	_close_end_card(screen)
	_save_and_return_to_title()


## Main Menu — same as Play Again. Kept as a separate handler so the button label
## matches what the player pressed (analytics / accessibility).
func _main_menu(screen: CanvasLayer) -> void:
	_close_end_card(screen)
	_save_and_return_to_title()


## Retry Stage — keep the carried-over cross-stage state (genome, traits, biomass,
## civ_*, etc.) and reload the current stage fresh. Defeat-only path. Forces the
## engine to 1.0 after the card closes — the retried stage must progress, even if
## the player had GameShell-paused before the card opened.
func _retry_stage(screen: CanvasLayer) -> void:
	_close_end_card(screen)
	Engine.time_scale = 1.0
	# Don't reset EvolutionState — the player's lineage survives, only the stage does.
	# StageManager.retry_current_stage preserves the cross-stage state and reloads
	# the current stage index with reset_for_stage (per-stage progress → 0).
	StageManager.retry_current_stage()
	Events.notify.emit("Retrying the current stage.")


func _save_and_return_to_title() -> void:
	SaveManager.clear()
	EvolutionState.new_run()
	# Force the engine to 1.0 before the scene reload — the next-run path is
	# always live, regardless of the pre-defeat pause state.
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# --- recap copy ---------------------------------------------------------------------

## Journey recap for the victory card — the arc from a single mote to owning the galaxy,
## plus the lineage, the run time, and a chronicle line. Pure: reads EvolutionState only.
func _win_recap() -> String:
	var g: Genome = EvolutionState.genome
	var species: String = g.species_label() if g != null else "Your lineage"
	var weapon: String = g.superweapon() if g != null else "unmatched"
	var biome: String = g.biome_label() if g != null else "the primordial waters"
	var elapsed: String = EvolutionState.format_elapsed(EvolutionState.run_elapsed_seconds())
	return (
		"mote  \u2192  creature  \u2192  tribe  \u2192  civilization  \u2192  galaxy\n\n"
		+ "The %s have conquered the galaxy.\n" % species
		+ "From %s to the stars \u2014 the %s silenced every rival.\n\n" % [biome, weapon]
		+ "One cell became a creature, a people, a civilization, an empire.\n\n"
		+ "Run time: %s\n" % elapsed
		+ _chronicle_block()
	)


## A compact stats line for the end screens — the run's footprint. Pure.
func _chronicle_block() -> String:
	var es := EvolutionState
	var traits_text: String = ", ".join(es.traits) if not es.traits.is_empty() else "none"
	var world: String = es.planet_name if es.planet_name != "" else "Primordia"
	var origin: String = es.genome.species_label() if es.genome != null else "unknown"
	var victory: String = es.civ_victory if es.civ_victory != "" else "galactic conquest"
	var axes: String = GenomeBonus.axes_readout(es.genome)
	var diet_top: String = _top_diet_label()
	var army: int = es.civ_army
	return (
		"\u2014 Chronicle \u2014\n"
		+ "World: %s   \u00b7   Origin: %s\n" % [world, origin]
		+ "Body axes: %s\n" % axes
		+ "Diet shaped by: %s\n" % diet_top
		+ "Traits evolved: %s\n" % traits_text
		+ "Civilization: %d cities \u00b7 era %d \u00b7 army %d\n" % [es.civ_cities, es.civ_age, army]
		+ "Homeworld victory: %s" % victory
	)


## Most-eaten soup food/microbe species for the chronicle (empty diet → "unknown").
func _top_diet_label() -> String:
	var diet: Dictionary = EvolutionState.diet
	if diet.is_empty():
		return "unknown"
	var best_k: String = ""
	var best_v: int = -1
	for k in diet:
		var v: int = int(diet[k])
		if v > best_v:
			best_v = v
			best_k = str(k)
	return "%s (×%d)" % [best_k, best_v] if best_k != "" else "unknown"
