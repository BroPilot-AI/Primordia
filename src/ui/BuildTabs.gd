class_name BuildTabs extends PanelContainer
## Compact tabbed build menu: a horizontal tab strip at the top swaps which
## category's container is visible below it. The tab content scrolls internally
## so all buildables fit inside a slim left-column panel (~330px at 1080p).
##
## Usage (in a stage's _build_ui):
##     var tabs := BuildTabs.new()
##     ui.add_child(tabs)
##     var fleet_box := GridContainer.new()
##     fleet_box.columns = 2
##     var fleet_idx := tabs.add_tab("Fleet", fleet_box)
##     var btn := Button.new()
##     btn.text = "Fighter (3 cr)"
##     fleet_box.add_child(btn)
##
## The stage keeps references to the buttons it adds (same as before) and updates
## their `disabled`/`text` state in `_update_status` — this component is a pure
## layout shell, it does not own any game logic or callbacks.

signal tab_changed(index: int)

const TAB_STRIP_HEIGHT := 26.0
const CONTENT_PADDING := 4
const PANEL_MIN_WIDTH := 280
const CONTENT_MIN_HEIGHT := 180.0

var _tabs: Array[Dictionary] = []
var _active_index: int = -1
var _tab_strip: HBoxContainer
var _content_host: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0)
	# Subtle inset so tabs read as part of the parent CompactHUD, not a second floating panel.
	var inset := StyleBoxFlat.new()
	inset.bg_color = Color(0.01, 0.03, 0.04, 0.35)
	inset.border_color = Color(0.42, 0.86, 0.78, 0.28)
	inset.set_border_width_all(1)
	inset.set_corner_radius_all(6)
	inset.content_margin_left = 4.0
	inset.content_margin_right = 4.0
	inset.content_margin_top = 4.0
	inset.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", inset)
	_build_chrome()


func _build_chrome() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	_tab_strip = HBoxContainer.new()
	_tab_strip.custom_minimum_size = Vector2(0, TAB_STRIP_HEIGHT)
	_tab_strip.add_theme_constant_override("separation", 2)
	_tab_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_tab_strip)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 0)
	root.add_child(sep)

	_scroll = ScrollContainer.new()
	_scroll.name = "ActionScroll"
	_scroll.custom_minimum_size = Vector2(0, CONTENT_MIN_HEIGHT)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(_scroll)

	_content_host = VBoxContainer.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_host.add_theme_constant_override("separation", CONTENT_PADDING)
	_scroll.add_child(_content_host)


# Add a tab. `container` is any Control the caller owns — typically a
# GridContainer (2 cols) for buildables or a VBoxContainer for one-button rows.
# The container is hidden until its tab is activated. Returns the new tab index.
func add_tab(label: String, container: Control) -> int:
	if container == null:
		push_error("BuildTabs.add_tab: container is null for label '%s'" % label)
		return -1
	var idx := _tabs.size()
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, TAB_STRIP_HEIGHT - 4.0)
	btn.add_theme_font_size_override("font_size", 13)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # tabs share the strip width — full labels, no "Cra"
	btn.clip_text = false
	btn.pressed.connect(_on_tab_pressed.bind(idx))
	_tab_strip.add_child(btn)
	container.visible = false
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.add_child(container)
	_tabs.append({"label": label, "button": btn, "container": container})
	if _active_index < 0:
		set_active(0)
	return idx


# Return the container the caller passed in for the given tab index. The caller
# adds its buttons directly to the returned container.
func get_container(index: int) -> Control:
	if index < 0 or index >= _tabs.size():
		return null
	return _tabs[index]["container"]


# Currently active tab index, or -1 if none.
func get_active() -> int:
	return _active_index


# Switch active tab. Hides every other container. No-op if the index is invalid
# or already active.
func set_active(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	if _active_index == index:
		return
	for i in _tabs.size():
		var entry: Dictionary = _tabs[i]
		var is_active: bool = i == index
		(entry["button"] as Button).button_pressed = is_active
		(entry["container"] as Control).visible = is_active
	_active_index = index
	tab_changed.emit(index)


func _on_tab_pressed(index: int) -> void:
	AudioManager.ui_click()
	# Clicking the already-active tab toggles its button OFF while its container stays
	# visible (set_active no-ops on the same index) — re-assert the pressed state so the
	# button can't fall out of sync with the visible tab.
	if index == _active_index and index >= 0 and index < _tabs.size():
		(_tabs[index]["button"] as Button).button_pressed = true
		return
	set_active(index)
