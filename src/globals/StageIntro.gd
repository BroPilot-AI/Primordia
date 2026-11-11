## Persistent stage-intro overlay (autoload): on each `Events.stage_changed`, pauses the sim and
## shows a STORY + HOW TO PLAY card for the new stage; a small floating "?" button in the
## bottom-right reopens the same card mid-stage. Pause/resume is symmetric and never blocks
## gameplay after dismiss. One component reused by all five stages — copy is verbatim and
## embedded in STAGE_CARDS (PRIMORDIAL's "{biome}" is filled at display time from
## `EvolutionState.genome.biome_label()`).
##
## Layer sits BELOW GameShell (200) and BELOW Toasts (150) so the pause menu and
## notifications stay accessible. process_mode = ALWAYS so the card + ? button remain
## interactive while the world is frozen.
extends CanvasLayer

const LAYER := 120
const HELP_LAYER := 130

## Verbatim card copy per stage index (matches EvolutionState.Stage + StageManager order).
## `{biome}` is the ONLY placeholder — replaced at display time on PRIMORDIAL with
## `EvolutionState.genome.biome_label()` (e.g. "freshwater pools").
const STAGE_CARDS := {
	0: {
		"era": "PRIMORDIAL",
		"story": "You are a single fragile mote of life, adrift in the {biome} — the primordial soup where life first stirred (~5–10 min). Feed on drifting nutrients, absorb compounds to power your metabolism, and build organelles to specialize. Beware viruses and micro-predators that would slow your growth. Grow, adapt, and evolve toward your first true body.",
		"controls": "MOVE — WASD / arrows to swim.  EAT — drift over glowing motes to grow.  BUILD — spend mutation points on organelles (they change how you look + metabolize).  AVOID — red-ringed hazards; non-lethal, but they set you back.  GOAL — grow and evolve into a creature.",
	},
	1: {
		"era": "CREATURE",
		"story": "You have hauled yourself from the soup as the first creature (~8–15 min). The wilderness is wide and the seasons turn. Hunt and forage to feed, shelter from the cold and from predators. Grow, knap tools, gather kindling — then discover fire, the spark of tribe.",
		"controls": "MOVE — WASD.  GATHER — materials for tools + kindling.  SHELTER — hide in green thickets at night.  WATCH — warmth and the season; adapt or slow.  CRAFT — campfire & shelter.  GOAL — Grow · Tools · Kindling → FIRE.",
	},
	2: {
		"era": "TRIBE",
		"story": "Your kind has gathered into a band around the first fire (~5–10 min). Your lineage axes already shape hunting and raid losses. Forage, raise shelter, research at the Thinker fire, and endure wolves and rival bands until the settlement can dawn into civilization.",
		"controls": "WORK — assign people to forage/hunt zones.  BUILD — huts to house growth.  THINK — research at the fire.  ENDURE — wolves & raids.  GOAL — population + shelter milestones.",
	},
	3: {
		"era": "CIV",
		"story": "Your people have raised the first settlement (~15–40 min). Grow through the ages and contend with rival nations. Two paths off-world: found cities and build a Spaceport, or raze every rival capital. Your evolved traits and genome axes already shape soldiers and production.",
		"controls": "SELECT — drag a box.  COMMAND — right-click attack-move.  B — drop into a full tactical ground battle near hostiles.  T/F — zoom.  Minimap jump.  BUILD / MANAGE / SETTLER.  GOAL — 3 cities + Spaceport OR eliminate all rivals.",
	},
	4: {
		"era": "SPACE",
		"story": "Your civilization has gone interstellar (long finale). The galaxy is ALIVE — worlds climb the ladder of life, empires rise and fall. Your homeworld army, weapon tier, and genome axes already shape the fleet. Own the galaxy to complete life's great ascent.",
		"controls": "FLY — WASD.  CAPTURE — park on a system.  B — drop into a fleet battle near hostiles.  Minimap click — route fleet.  T/F — zoom.  BUILD ships/stations.  SPEED 1x–3x.  GOAL — own every system.",
	},
}

## Pure helper: returns the final card dict for a stage (copy with `{biome}` substituted
## against the live `EvolutionState.genome.biome_label()` when reachable). Public so the test
## suite can assert copy without needing the autoload in the tree.
static func card_for(stage_index: int) -> Dictionary:
	if not STAGE_CARDS.has(stage_index):
		return {}
	var d: Dictionary = STAGE_CARDS[stage_index]
	var story_value: String = String(d.get("story", ""))
	if story_value.find("{biome}") >= 0:
		var biome: String = _resolve_biome()
		if biome != "":
			story_value = story_value.replace("{biome}", biome)
	return {
		"era": String(d.get("era", "")),
		"story": story_value,
		"controls": String(d.get("controls", "")),
	}


## Pure helper: get the biome label from EvolutionState (returns "" if unavailable). Safe
## to call from any context; defensive on missing genome / missing autoload.
static func _resolve_biome() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ""
	var root: Node = tree.root
	if root == null:
		return ""
	var es := root.get_node_or_null("EvolutionState")
	if es == null:
		return ""
	var genome: Object = es.get("genome")
	if genome == null:
		return ""
	if genome.has_method("biome_label"):
		return String(genome.call("biome_label"))
	return ""

var _card: Control
var _help_layer: CanvasLayer
var _help_button: Button
var _current_stage := -1
var _is_open := false
var _last_speed := 1.0


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.stage_changed.connect(_on_stage_changed)
	_build_help_button()
	_help_button.visible = false   # hidden until a stage actually loads


## One-call entry: caller (Main) hands us the new stage index, we look up the copy,
## pause the sim, and show the card. Safe to call repeatedly — re-showing the same
## stage resets the card to a clean state.
func show_for_stage(stage_index: int) -> void:
	if not STAGE_CARDS.has(stage_index):
		# Unknown stage — just ensure the ? button is on so the player can still ask.
		_current_stage = stage_index
		_help_button.visible = stage_index >= 0
		return
	_current_stage = stage_index
	_help_button.visible = true
	_present(STAGE_CARDS[stage_index])


## Public toggle: shows the card for the current stage if hidden, hides it if showing.
## Wired to the persistent "?" button so the player can revisit the briefing any time.
func toggle() -> void:
	if _current_stage < 0:
		return
	if _is_open:
		_dismiss()
	elif STAGE_CARDS.has(_current_stage):
		_present(STAGE_CARDS[_current_stage])


## True when the card is currently visible (used by tests + by external pause menus).
func is_open() -> bool:
	return _is_open


## Manually close the card and resume the sim. Equivalent to clicking "Begin". Used by
## the verify harness and any external UI that wants to dismiss the intro without
## reproducing the click path. (Named to avoid colliding with CanvasLayer's native `hide`.)
func close() -> void:
	_dismiss()


# -- internal --

func _on_stage_changed(stage: int) -> void:
	# Each new stage auto-presents the intro card. Main.gd drives the morph cutscene
	# FIRST and only then calls show_for_stage, but a direct stage_changed listener keeps
	# the "?" button in sync and gives the right default for the load-current path.
	_current_stage = stage
	_help_button.visible = stage >= 0


func _present(card_data: Dictionary) -> void:
	# Re-show: tear down any prior card so the new copy is clean.
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
		_card = null

	# Snapshot current speed so we can restore on dismiss (GameSpeed keeps the true
	# value, but we don't want to depend on the autoload being up for tests).
	if Engine.time_scale > 0.0:
		_last_speed = Engine.time_scale

	# Pause: SceneTree.paused freezes every _process / _physics_process, which matches
	# the existing StoryCard + EvolutionCutscene pattern; Engine.time_scale = 0 is the
	# spec-mandated belt-and-braces (kills any delta-based tickers too).
	get_tree().paused = true
	Engine.time_scale = 0.0

	_card = _build_card(card_data)
	add_child(_card)
	# Grab focus on the Begin button now that it's in the tree — Enter/Space then
	# dismisses the card without the player reaching for the mouse.
	var begin_btn: Button = _card.find_child("BeginButton", true, false) as Button
	if begin_btn != null:
		begin_btn.call_deferred("grab_focus")
	_card.modulate.a = 0.0
	var tween := _make_tween()
	tween.tween_property(_card, "modulate:a", 1.0, 0.35)
	_is_open = true


func _dismiss() -> void:
	if not _is_open:
		return
	_is_open = false
	if _card != null and is_instance_valid(_card):
		var node: Control = _card
		var tween := _make_tween()
		tween.tween_property(node, "modulate:a", 0.0, 0.25)
		tween.finished.connect(func() -> void:
			if is_instance_valid(node):
				node.queue_free()
			)
	# Resume. Use the snapshotted speed (typically 1.0 — never 0). SceneTree.paused must
	# come down BEFORE Engine.time_scale so any per-frame _process picks up at 1x.
	Engine.time_scale = _last_speed
	get_tree().paused = false


# -- UI builders --

func _build_help_button() -> void:
	# The help button lives on its OWN CanvasLayer above the card so it's always clickable,
	# even while the dim+card panel are eating the rest of the input.
	_help_layer = CanvasLayer.new()
	_help_layer.layer = HELP_LAYER
	_help_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_help_layer)

	_help_button = StageChrome.make_button("?", "Show this stage's story + controls", toggle)
	_help_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_help_button.custom_minimum_size = Vector2(40, 40)
	_help_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_help_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_help_button.offset_left = -56
	_help_button.offset_top = -56
	_help_button.offset_right = -16
	_help_button.offset_bottom = -16
	_help_layer.add_child(_help_button)


func _make_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)


func _build_card(data: Dictionary) -> Control:
	var era: String = String(data.get("era", ""))
	var raw_story: String = String(data.get("story", ""))
	var controls: String = String(data.get("controls", ""))
	var story: String = raw_story.replace("{biome}", _resolve_biome()) if raw_story.find("{biome}") >= 0 else raw_story

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # eat clicks behind the card

	root.add_child(StageChrome.dim_rect())
	var inner := StageChrome.modal_card(root, StageChrome.MODAL_WIDTH)

	inner.add_child(StageChrome.era_label(era))
	inner.add_child(StageChrome.section_label("STORY"))
	inner.add_child(StageChrome.body_label(story))
	inner.add_child(StageChrome.h_sep())
	inner.add_child(StageChrome.section_label("HOW TO PLAY"))
	inner.add_child(StageChrome.body_label(controls))

	var begin := StageChrome.make_button("Begin ▶", "Start this stage", _dismiss, true)
	begin.name = "BeginButton"
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.custom_minimum_size = Vector2(200, StageChrome.BUTTON_HEIGHT_LG)
	inner.add_child(begin)
	inner.add_child(StageChrome.hint_label("Enter / Space / click outside to begin"))

	# Click anywhere on the dim (outside the card panel) to also dismiss — matches
	# the legacy StoryCard click-to-continue behavior so muscle memory carries over.
	# (The root Control has mouse_filter = STOP and captures all clicks because the
	# inner dim+center are set to IGNORE — that funnels mouse events here.)
	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_dismiss()
			get_viewport().set_input_as_handled()
			return
		# Keyboard shortcut: Enter / Space dismisses the card so the player can start
		# without reaching for the mouse. Only act on press (not echo).
		if event is InputEventKey and event.pressed and not event.echo:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE or key_event.keycode == KEY_KP_ENTER:
				_dismiss()
				get_viewport().set_input_as_handled()
		)

	return root


func _section_label(text: String) -> Label:
	return StageChrome.section_label(text)
