## Global game shell (autoload): the always-available QOL layer over every stage —
##   • Esc → pause menu (Resume / Settings / Quit to Title)
##   • game-speed control (Pause / 1x / 2x / 3x) for the strategic stages
##   • Settings: Master/Music/SFX volume + fullscreen, persisted to user://settings.cfg
##   • a per-stage objective + controls hint, updated on stage_changed
## Runs with PROCESS_MODE_ALWAYS so it works while the tree is paused.
extends CanvasLayer

const SETTINGS_PATH := "user://settings.cfg"
const OBJECTIVES := {
	0: "PRIMORDIAL  ·  Eat motes & microbes to evolve. Avoid hazards — they set you back.",
	1: "CREATURE  ·  Grow · Tools · Kindling → FIRE. Hide at night.  F = focus self.",
	2: "TRIBE  ·  Zones · huts · research · pop + shelter.  F = focus chief.",
	3: "CIV  ·  Dual win paths.  Select army near foes · B = DROP-IN BATTLE.  F/T zoom · minimap jump.",
	4: "SPACE  ·  Capture systems.  Near hostiles · B = FLEET BATTLE.  F/T zoom · minimap routes fleet.",
}

## Soft idle tips when the player stalls (teaches systems without a wiki).
## Arrays rotate so long stalls surface multiple coaching lines.
const IDLE_TIPS := {
	0: [
		"Tip: different microbes shape your diet — variety evolves better axes.",
		"Tip: hazards set you back — circle around them rather than tanking hits.",
	],
	1: [
		"Tip: night hunters can't follow you into green thickets or firelight.",
		"Tip: craft tools then kindling — fire is the stage gate.",
		"Tip: grow + tools + kindling = FIRE. The HUD tracks all three.",
		"Tip: later nights spawn more predators — campfire is the answer.",
	],
	2: [
		"Tip: research Hunting, then run down deer and boar — every catch feeds more.",
		"Tip: build huts to raise pop cap — shelter gates growth.",
		"Tip: research at the fire — keep your leader nearby to think.",
		"Tip: pop, Stone Tools, Shelter tech, and 2 huts unlock civilization.",
	],
	3: [
		"Tip: Train Settler from a city when you need the 3rd city for spaceflight.",
		"Tip: Select army near hostiles and press B — drop-in battle for loot + veterans.",
		"Tip: Cities under siege below 50% HP auto-open a defense battle.",
		"Tip: Gold rings mark veterans — survivors of battles hit harder.",
		"Tip: rivals retrain and march — idle economy loses wars.",
		"Tip: bandits hit cities — keep a home guard or drop in (B).",
	],
	4: [
		"Tip: park the flagship on a system to capture it. Speed 2x/3x helps late war.",
		"Tip: Near hostiles, press B for a fleet battle — salvage + seasoned crews.",
		"Tip: Local fleet HP under 50% near hostiles auto-opens a defense battle.",
		"Tip: Losing empires may sue for peace — accept for a bilateral ceasefire + metal/energy tribute.",
		"Tip: capture pays salvage — hold position until the system flips.",
		"Tip: a Refinery turns spare water into metal and biomass into energy.",
		"Tip: double-click your home system to visit the surface arcology.",
	],
}

const IDLE_TIP_AFTER := 42.0
const OBJECTIVE_BOTTOM_GAP := 18.0
const OBJECTIVE_ROW_HEIGHT := 44.0

var _idle_t := 0.0
var _idle_stage := -1
var _idle_tip_i := 0
var _paused := false
var _pause_root: Control
var _settings_panel: Control
var _objective: Label
var _objective_pill: PanelContainer
var _speed_buttons: Dictionary = {}
var _vol := {"Master": 0.9, "Music": 0.8, "SFX": 0.9}
var _fullscreen := false


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_settings()
	_build_objective()
	_build_pause_menu()
	_apply_settings()
	Events.stage_changed.connect(_on_stage_changed)
	Events.speed_changed.connect(_on_speed_changed)
	_on_speed_changed(Engine.time_scale)


# --- audio buses so the volume sliders have real targets (audio players route here later) ---
func _ensure_buses() -> void:
	for name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(name) < 0:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")


func _process(delta: float) -> void:
	# Idle coaching — only while a stage is live and the sim is running.
	if _paused or get_tree().paused or Engine.time_scale <= 0.0:
		return
	if StageManager.current_stage_node() == null:
		return
	_idle_t += delta
	if _idle_t < IDLE_TIP_AFTER:
		return
	_idle_t = 0.0
	var tips: Variant = IDLE_TIPS.get(_idle_stage, [])
	if tips is Array and not (tips as Array).is_empty():
		var arr: Array = tips
		var tip: String = str(arr[_idle_tip_i % arr.size()])
		_idle_tip_i += 1
		if tip != "":
			Events.notify.emit(tip)
	elif tips is String and str(tips) != "":
		Events.notify.emit(str(tips))


func _on_stage_changed(stage: int) -> void:
	_idle_t = 0.0
	_idle_tip_i = 0
	_idle_stage = stage
	if _objective != null:
		_objective.text = String(OBJECTIVES.get(stage, ""))
		_objective_pill.visible = OBJECTIVES.has(stage)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _toggle_pause() -> void:
	_paused = not _paused
	_pause_root.visible = _paused
	if not _paused and _settings_panel != null:
		_settings_panel.visible = false
	if _paused:
		GameSpeed.set_speed(0.0)
	elif Engine.time_scale <= 0.0:
		GameSpeed.toggle_pause()


func _resume_from_pause_menu() -> void:
	if not _paused:
		return
	_paused = false
	_pause_root.visible = false
	if _settings_panel != null:
		_settings_panel.visible = false
	if Engine.time_scale <= 0.0:
		GameSpeed.toggle_pause()


func _save_run_from_pause_menu() -> void:
	# The pause menu is reachable from the title screen (Esc) — saving there would
	# overwrite the checkpoint with wiped title state and destroy the real run.
	if StageManager.current_stage_node() == null:
		Events.notify.emit("No active run to save.")
		return
	var err: int = SaveManager.save_current()
	if err == OK:
		Events.notify.emit("Run saved.")
	else:
		Events.notify.emit("Save failed (err %d)." % err)


func _load_run_from_pause_menu() -> void:
	if not SaveManager.has_save():
		Events.notify.emit("No run save found.")
		return
	var idx: int = SaveManager.load_into_state()
	if idx < 0:
		Events.notify.emit("Load failed.")
		return
	var root: Node = StageManager.stage_root()
	if root == null:
		Events.notify.emit("Load failed: no active stage root.")
		return
	get_tree().paused = false
	_paused = false
	_pause_root.visible = false
	if _settings_panel != null:
		_settings_panel.visible = false
	GameSpeed.set_speed(1.0, false)
	StageManager.continue_at(root, idx, SaveManager.consume_stage_snapshot())
	Events.notify.emit("Run loaded.")


# --- objective / controls hint (bottom-center, subtle) ---
func _build_objective() -> void:
	# Readable text on a dark pill, centred at the bottom; none of it may take a click.
	var row := CenterContainer.new()
	row.name = "ObjectiveRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_bottom = -OBJECTIVE_BOTTOM_GAP
	row.offset_top = -OBJECTIVE_BOTTOM_GAP - OBJECTIVE_ROW_HEIGHT
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_objective_pill = PanelContainer.new()
	_objective_pill.name = "ObjectivePill"
	_objective_pill.add_theme_stylebox_override("panel", StageChrome.toast_panel_style())
	_objective_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_pill.visible = false
	row.add_child(_objective_pill)
	_objective = StageChrome.status_label("")
	_objective.autowrap_mode = TextServer.AUTOWRAP_OFF
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_pill.add_child(_objective)


# --- pause menu + settings ---
func _build_pause_menu() -> void:
	_pause_root = Control.new()
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.visible = false
	_pause_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_root)

	_pause_root.add_child(StageChrome.dim_rect())
	var box := StageChrome.modal_card(_pause_root, 420.0)

	box.add_child(StageChrome.era_label("PAUSED"))
	box.add_child(StageChrome.hint_label("Esc resumes · 1/2/3 set speed"))
	box.add_child(StageChrome.h_sep())

	box.add_child(StageChrome.make_button("Continue", "Resume the run", _resume_from_pause_menu, true))
	box.add_child(StageChrome.make_button("Save Run", "Write a checkpoint", _save_run_from_pause_menu))
	box.add_child(StageChrome.make_button("Load Run", "Restore the checkpoint", _load_run_from_pause_menu))

	# Speed row (applies via GameSpeed, the single Engine.time_scale owner).
	var speed_row := HBoxContainer.new()
	speed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_row.add_theme_constant_override("separation", 6)
	box.add_child(speed_row)
	var speed_lbl := StageChrome.section_label("SPEED")
	speed_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	speed_row.add_child(speed_lbl)
	var speed_options: Array[Dictionary] = [
		{"label": "Pause", "scale": 0.0},
		{"label": "1x", "scale": 1.0},
		{"label": "2x", "scale": 2.0},
		{"label": "3x", "scale": 3.0},
	]
	for option: Dictionary in speed_options:
		var mult: float = float(option["scale"])
		var b := StageChrome.make_button(str(option["label"]), "Set speed %s" % str(option["label"]), _on_speed_button.bind(mult))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size = Vector2(72, StageChrome.BUTTON_HEIGHT)
		speed_row.add_child(b)
		_speed_buttons[mult] = b

	box.add_child(StageChrome.make_button("Settings", "Audio & display", _toggle_settings))
	box.add_child(StageChrome.make_button("Quit to Title", "Abandon this run for the title screen", _quit_to_title))

	_build_settings_panel(box)


func _build_settings_panel(parent: Node) -> void:
	_settings_panel = VBoxContainer.new()
	_settings_panel.add_theme_constant_override("separation", 6)
	_settings_panel.visible = false
	parent.add_child(_settings_panel)

	for bus in ["Master", "Music", "SFX"]:
		var row := HBoxContainer.new()
		var lbl := StageChrome.hint_label("%s vol" % bus)
		lbl.custom_minimum_size = Vector2(90, 0)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = _vol[bus]
		slider.custom_minimum_size = Vector2(180, 0)
		slider.value_changed.connect(_on_volume_changed.bind(bus))
		row.add_child(slider)
		_settings_panel.add_child(row)

	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = _fullscreen
	fs.toggled.connect(_on_fullscreen_toggled)
	StageChrome.style_button(fs)
	_settings_panel.add_child(fs)


func _toggle_settings() -> void:
	if _settings_panel != null:
		_settings_panel.visible = not _settings_panel.visible


func _set_speed(mult: float) -> void:
	GameSpeed.set_speed(mult)
	if _paused and mult > 0.0:
		_paused = false
		_pause_root.visible = false
		if _settings_panel != null:
			_settings_panel.visible = false


# Speed buttons (1x/2x/3x/Pause) are a single shared click SFX — keeps the mixer quiet while
# letting the player feel the input.
func _on_speed_button(mult: float) -> void:
	_set_speed(mult)


func _on_speed_changed(mult: float) -> void:
	for key: Variant in _speed_buttons.keys():
		var button: Button = _speed_buttons[key] as Button
		button.button_pressed = is_equal_approx(float(key), mult)
	if _paused and mult > 0.0:
		_paused = false
		_pause_root.visible = false
		if _settings_panel != null:
			_settings_panel.visible = false


func _on_volume_changed(value: float, bus: String) -> void:
	_vol[bus] = value
	_apply_volume(bus, value)
	_save_settings()


func _on_fullscreen_toggled(on: bool) -> void:
	_fullscreen = on
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_save_settings()


func _apply_volume(bus: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(value, 0.0001, 1.0)))


func _apply_settings() -> void:
	for bus in _vol:
		_apply_volume(bus, _vol[bus])
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _quit_to_title() -> void:
	get_tree().paused = false
	_paused = false
	# GameShell is an autoload and survives reload_current_scene() — hide the pause
	# menu + settings explicitly or they'd linger over the title screen.
	_pause_root.visible = false
	if _settings_panel != null:
		_settings_panel.visible = false
	GameSpeed.set_speed(1.0, false)
	# StageIntro is an autoload too — dismiss any open story/how-to card so it
	# doesn't cover the title screen after the reload.
	StageIntro.close()
	# Fresh-run state for the next New Run (this autoload persists; see new_run's doc).
	EvolutionState.new_run()
	get_tree().reload_current_scene()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in _vol:
		_vol[bus] = float(cfg.get_value("audio", bus, _vol[bus]))
	_fullscreen = bool(cfg.get_value("video", "fullscreen", false))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in _vol:
		cfg.set_value("audio", bus, _vol[bus])
	cfg.set_value("video", "fullscreen", _fullscreen)
	cfg.save(SETTINGS_PATH)


## Reusable confirm modal. `on_yes`/`on_cancel` fire on the respective button; labels customizable
## (e.g. Accept/Decline for diplomacy offers). Blocks clicks underneath via an opaque-to-input dim.
func confirm(text: String, on_yes: Callable, on_cancel := Callable(), yes_text := "Confirm", no_text := "Cancel") -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.04, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # eat clicks meant for the UI behind
	root.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	var yes := Button.new()
	yes.text = yes_text
	yes.pressed.connect(func() -> void:
		AudioManager.ui_click()
		root.queue_free()
		if on_yes.is_valid():
			on_yes.call())
	row.add_child(yes)

	var no := Button.new()
	no.text = no_text
	no.pressed.connect(func() -> void:
		AudioManager.ui_click()
		root.queue_free()
		if on_cancel.is_valid():
			on_cancel.call())
	row.add_child(no)
