class_name StoryCard
extends CanvasLayer
## Reusable full-screen story card shown at the start of each stage. Built in code.
## Usage: StoryCard.show_card(parent, title, body, on_done). Fades in, dismisses on
## click/key or after AUTO_DISMISS seconds, then calls on_done and frees itself.
## (Fades a Control wrapper — CanvasLayer itself has no `modulate`.)

const AUTO_DISMISS := 6.0
const TEXT_LAYER := 100
const TRANSITION_LAYER := 1000

# Per-stage narration. [biome]/[planet] placeholders are filled in by the caller.
const STAGE_TEXT := {
	0: {title = "PRIMORDIA", body = "You are a single cell, the first stirring of life in the [biome] of [planet]. What you consume here will echo through every age to come. Eat. Grow. Become."},
	1: {title = "ASHORE", body = "You crawl from the [biome]. The world is vast and hungry — survive its nights, and grow into something greater."},
	2: {title = "THE FIRST PEOPLE", body = "Your kind has found one another. Gather, hunt, endure — the first sparks of a people."},
	3: {title = "CIVILIZATION", body = "From scattered bands, a civilization rises. Build, discover, unite [planet]."},
	4: {title = "TO THE STARS", body = "Your world is yours. But the galaxy teems with others climbing the same ladder. Claim the stars."},
}

var _root: Control
var _on_done: Callable = Callable()
var _dismissed := false
var _last_speed := 1.0
var _freeze_time_scale := false


static func show_card(parent: Node, title: String, body: String, on_done := Callable()) -> void:
	var card := StoryCard.new()
	card._on_done = on_done
	parent.add_child(card)
	card._build_text(title, body)


static func show_transition_card(parent: Node, title: String, body: String, texture_path: String, on_done := Callable()) -> void:
	var card := StoryCard.new()
	card._on_done = on_done
	parent.add_child(card)
	card._build_transition(title, body, texture_path)


func _build_text(title: String, body: String) -> void:
	layer = TEXT_LAYER
	# Freeze the world while the card is up (so enemies don't converge during the read);
	# this node keeps animating + handling input because its process mode is ALWAYS.
	_pause_world(false)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	box.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.custom_minimum_size = Vector2(720, 0)
	body_label.add_theme_font_size_override("font_size", 22)
	box.add_child(body_label)

	var hint := Label.new()
	hint.text = "(click to continue)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	box.add_child(hint)

	_root.modulate.a = 0.0
	_make_tween().tween_property(_root, "modulate:a", 1.0, 0.4)
	var timer: SceneTreeTimer = get_tree().create_timer(AUTO_DISMISS, true, false, true)
	timer.timeout.connect(_dismiss)


func _build_transition(title: String, body: String, texture_path: String) -> void:
	layer = TRANSITION_LAYER
	_pause_world(true)

	_root = Control.new()
	_root.name = "StoryTransitionRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_gui_input)
	add_child(_root)

	var texture: Texture2D = load(texture_path) as Texture2D
	var image := TextureRect.new()
	image.name = "StoryCardImage"
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(image)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.24)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var caption_band := ColorRect.new()
	caption_band.color = Color(0.01, 0.015, 0.02, 0.76)
	caption_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption_band.offset_top = -210.0
	caption_band.offset_bottom = 0.0
	_root.add_child(caption_band)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -210.0
	center.offset_bottom = -18.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(900, 0)
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 0.92))
	box.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.add_theme_font_size_override("font_size", 24)
	body_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.94, 1.0))
	box.add_child(body_label)

	var continue_button := StageChrome.make_button("Continue ▶", "Continue the ascent", _dismiss, true)
	continue_button.name = "ContinueButton"
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.custom_minimum_size = Vector2(200, StageChrome.BUTTON_HEIGHT_LG)
	box.add_child(continue_button)
	continue_button.call_deferred("grab_focus")

	_root.modulate.a = 0.0
	_make_tween().tween_property(_root, "modulate:a", 1.0, 0.35)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _dismiss_event(event):
		_dismiss()
		get_viewport().set_input_as_handled()


func _dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	var t: Tween = _make_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.3)
	t.finished.connect(func() -> void:
		_resume_world()
		if _on_done.is_valid():
			_on_done.call()
		queue_free()
	)


func _pause_world(freeze_time_scale: bool) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_freeze_time_scale = freeze_time_scale
	if Engine.time_scale > 0.0:
		_last_speed = Engine.time_scale
	get_tree().paused = true
	if _freeze_time_scale:
		Engine.time_scale = 0.0


func _resume_world() -> void:
	if _freeze_time_scale:
		Engine.time_scale = _last_speed
	get_tree().paused = false


func _make_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)


func _on_root_gui_input(event: InputEvent) -> void:
	if _dismiss_event(event):
		_dismiss()
		get_viewport().set_input_as_handled()


func _dismiss_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		return mouse_event.pressed
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		return key_event.pressed and not key_event.echo
	return false
