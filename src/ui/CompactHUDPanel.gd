class_name CompactHUDPanel extends PanelContainer
## Soup-style collapsible shell shared by the Creature, Tribe, and Civilization HUDs.
## It keeps information dense at 720p and leaves only a small Kenney arrow on-screen
## when the player wants an unobstructed view of the world.

const EDGE_MARGIN := 12.0
const TOP_MARGIN := 12.0
const TOGGLE_WIDTH := 34.0
const COLLAPSE_ICON := "res://assets/ui/kenney/arrow_collapse.png"
const EXPAND_ICON := "res://assets/ui/kenney/arrow_expand.png"
## Shared brand colors (kept local so this shell never hard-depends on StageChrome load order).
const _BG := Color(0.02, 0.05, 0.07, 0.90)
const _BORDER := Color(0.42, 0.86, 0.78, 0.72)
const _TITLE := Color(0.66, 1.0, 0.90, 1.0)

var content: VBoxContainer
var _title: Label
var _toggle: Button
var _open_width := 300.0
var _right_side := false
var _expanded := true
var _built := false


func configure(title: String, width: float = 300.0, right_side: bool = false) -> void:
	_open_width = maxf(width, 220.0)
	_right_side = right_side
	if not _built:
		_build_shell()
	_title.text = title
	content.custom_minimum_size.x = _open_width - TOGGLE_WIDTH - 18.0
	_place_at_edge()
	set_expanded(true)


func _ready() -> void:
	if not _built:
		_build_shell()
		_place_at_edge()
		set_expanded(_expanded)


func _build_shell() -> void:
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	grow_vertical = Control.GROW_DIRECTION_END
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = _BG
	panel_style.border_color = _BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 8.0
	panel_style.content_margin_right = 8.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", panel_style)

	var shell := HBoxContainer.new()
	shell.name = "HUDShell"
	shell.add_theme_constant_override("separation", 6)
	add_child(shell)

	content = VBoxContainer.new()
	content.name = "HUDContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 4)

	_toggle = Button.new()
	_toggle.name = "CollapseHUD"
	_toggle.custom_minimum_size = Vector2(TOGGLE_WIDTH, 34.0)
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.flat = true
	_toggle.expand_icon = true
	_toggle.add_theme_constant_override("icon_max_width", 18)
	_toggle.tooltip_text = "Hide HUD"
	_toggle.pressed.connect(func() -> void:
		AudioManager.ui_click()
		set_expanded(not _expanded))

	if _right_side:
		shell.add_child(content)
		shell.add_child(_toggle)
	else:
		shell.add_child(_toggle)
		shell.add_child(content)

	_title = Label.new()
	_title.name = "HUDTitle"
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", _TITLE)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_title.add_theme_constant_override("outline_size", 3)
	content.add_child(_title)
	# Subtle brand rule under the title so every stage panel opens the same way.
	var rule := HSeparator.new()
	rule.add_theme_constant_override("separation", 2)
	content.add_child(rule)


func _place_at_edge() -> void:
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_top = TOP_MARGIN
	offset_bottom = TOP_MARGIN
	if _right_side:
		anchor_left = 1.0
		anchor_right = 1.0
		offset_right = -EDGE_MARGIN
	else:
		anchor_left = 0.0
		anchor_right = 0.0
		offset_left = EDGE_MARGIN
	_apply_width()


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	if content == null:
		return
	content.visible = expanded
	_toggle.tooltip_text = "Hide HUD" if expanded else "Show HUD"
	var collapse_left := not _right_side
	var icon_path := COLLAPSE_ICON if (expanded == collapse_left) else EXPAND_ICON
	_toggle.icon = load(icon_path) if ResourceLoader.exists(icon_path) else null
	_toggle.text = ("<" if collapse_left else ">") if expanded else (">" if collapse_left else "<")
	if _toggle.icon != null:
		_toggle.text = ""
	_apply_width()


func _apply_width() -> void:
	var width := _open_width if _expanded else TOGGLE_WIDTH + 14.0
	if _right_side:
		offset_left = offset_right - width
	else:
		offset_right = offset_left + width


func current_width() -> float:
	return absf(offset_right - offset_left)


func title_text() -> String:
	return _title.text if _title != null else ""
