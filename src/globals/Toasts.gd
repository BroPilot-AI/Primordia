## Global toast notifications (autoload): transient banners for key events — emergence, tech,
## rival defeats, superweapon online, etc. Any stage emits `Events.notify(text)`; this shows it.
## Runs with PROCESS_MODE_ALWAYS so toasts still animate while the tree is paused.
## Includes a short inter-toast cooldown and dedup of consecutive identical text so flavor
## quips do not drown out real gameplay notifications.
extends CanvasLayer

const MAX_TOASTS := 5
const COOLDOWN := 1.0
## Suppresses back-to-back repeats of the SAME message (quip spam), but time-bounded —
## an identical message is allowed again after this window so e.g. a second manual
## "Run saved." still confirms visibly.
const DEDUP_WINDOW := 4.0

var _stack: VBoxContainer
var _last_text: String = ""
var _last_time: float = -INF


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS

	_stack = VBoxContainer.new()
	_stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_stack.offset_left = -280.0
	_stack.offset_right = 280.0
	_stack.offset_top = 16.0
	_stack.offset_bottom = 140.0
	_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_stack.add_theme_constant_override("separation", 6)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)

	Events.notify.connect(_toast)
	Events.tech_researched.connect(_on_tech)


func _on_tech(tech_name: String) -> void:
	_toast("Researched: %s" % tech_name)


func _toast(text: String) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_time < COOLDOWN:
		return
	if text == _last_text and now - _last_time < DEDUP_WINDOW:
		return
	_last_text = text
	_last_time = now

	# Keep the stack bounded — drop the oldest if we're full.
	while _stack.get_child_count() >= MAX_TOASTS:
		var oldest := _stack.get_child(0)
		_stack.remove_child(oldest)
		oldest.queue_free()

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", StageChrome.toast_panel_style())
	var label := StageChrome.status_label(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 480.0
	# Goals / danger get accent color so they pop over the stack.
	if text.begins_with("◆ Goal:"):
		label.add_theme_color_override("font_color", StageChrome.GOAL)
	elif text.begins_with("⚠") or text.find("fallen") >= 0 or text.find("EXTINCT") >= 0:
		label.add_theme_color_override("font_color", StageChrome.ACCENT_DANGER)
	panel.add_child(label)
	panel.modulate.a = 0.0
	_stack.add_child(panel)

	# Ignore time scale — toasts fired while paused (GameSpeed 0 / end cards) must
	# still animate and expire instead of popping up stale on resume.
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(panel.queue_free)
