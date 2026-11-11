## Shared HUD visual language for every stage (Soup → Space) and shell overlays
## (title, pause, stage intro, toasts). Stages/shell still own layout; they pull
## colors, styleboxes, and factories from here so chrome reads as one product.
class_name StageChrome

## Panel widths — keep RTS/build menus in the same column.
const PANEL_WIDTH := 360.0
const PANEL_WIDTH_RTS := 380.0
const MODAL_WIDTH := 720.0
const EDGE_MARGIN := 12.0
const TOP_MARGIN := 12.0
const HUD_LAYER := 10

## Palette (teal-jade Primordia brand — matches assets/theme/primordia_theme.tres).
const BG := Color(0.02, 0.05, 0.07, 0.90)
const BG_SOLID := Color(0.04, 0.08, 0.07, 1.0)
const BORDER := Color(0.42, 0.86, 0.78, 0.72)
const TITLE := Color(0.66, 1.0, 0.90, 1.0)
const BANNER := Color(1.0, 0.88, 0.52, 1.0)
const READOUT := Color(0.72, 0.82, 0.86, 1.0)
const STATUS := Color(0.90, 0.94, 0.96, 1.0)
const HINT := Color(0.62, 0.74, 0.78, 1.0)
const GOAL := Color(1.0, 0.90, 0.50, 1.0)
const ACCENT_OK := Color(0.55, 1.0, 0.55, 1.0)
const ACCENT_WARN := Color(1.0, 0.72, 0.35, 1.0)
const ACCENT_DANGER := Color(1.0, 0.50, 0.48, 1.0)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.85)
const DIM := Color(0.02, 0.06, 0.05, 0.94)
const BTN_BG := Color(0.11, 0.21, 0.17, 0.95)
const BTN_BG_HOVER := Color(0.17, 0.32, 0.26, 1.0)
const BTN_BG_PRESSED := Color(0.08, 0.16, 0.13, 1.0)
const BTN_BG_DISABLED := Color(0.09, 0.11, 0.10, 0.55)
const BTN_BORDER := Color(0.4, 0.9, 0.62, 0.55)

const FONT_HERO := 48
const FONT_ERA := 32
const FONT_TITLE := 18
const FONT_BANNER := 14
const FONT_READOUT := 12
const FONT_STATUS := 14
const FONT_HINT := 11
const FONT_BUTTON := 14
const FONT_BODY := 16
const BUTTON_HEIGHT := 28.0
const BUTTON_HEIGHT_LG := 44.0
const METER_HEIGHT := 14.0
const SEPARATION := 4


static func panel_style() -> StyleBoxFlat:
	return _flat(BG, BORDER, 8, 8.0)


static func modal_panel_style() -> StyleBoxFlat:
	return _flat(BG_SOLID, BORDER, 12, 18.0)


static func toast_panel_style() -> StyleBoxFlat:
	var s := _flat(Color(0.03, 0.08, 0.07, 0.92), BORDER, 8, 10.0)
	s.set_border_width_all(1)
	return s


static func dim_rect() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dim


static func make_layer(parent: Node, layer: int = HUD_LAYER) -> CanvasLayer:
	var ui := CanvasLayer.new()
	ui.layer = layer
	ui.name = "StageHUD"
	parent.add_child(ui)
	return ui


## Styled CompactHUD shell. Returns the panel; put content into panel.content.
static func make_shell(parent: Node, title: String, width: float = PANEL_WIDTH, right_side: bool = false) -> PanelContainer:
	var CompactHUD := load("res://src/ui/CompactHUDPanel.gd")
	var panel = CompactHUD.new()
	panel.configure(title, width, right_side)
	parent.add_child(panel)
	return panel


static func title_label(text: String) -> Label:
	return _label(text, FONT_TITLE, TITLE, true)


static func hero_label(text: String) -> Label:
	var l := _label(text, FONT_HERO, TITLE, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func era_label(text: String) -> Label:
	var l := _label(text, FONT_ERA, TITLE, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func banner_label(text: String) -> Label:
	return _label(text, FONT_BANNER, BANNER, true)


static func body_label(text: String) -> Label:
	return _label(text, FONT_BODY, STATUS, true)


static func readout_label(text: String = "") -> Label:
	var l := _label(text if text != "" else EvolutionState.lineage_readout(), FONT_READOUT, READOUT, false)
	if text == "":
		l.tooltip_text = EvolutionState.lineage_tooltip()
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


static func status_label(text: String = "") -> Label:
	return _label(text, FONT_STATUS, STATUS, true)


static func hint_label(text: String) -> Label:
	return _label(text, FONT_HINT, HINT, true)


static func goal_label(text: String = "") -> Label:
	return _label(text, FONT_STATUS, GOAL, true)


static func section_label(text: String) -> Label:
	return _label(text, FONT_HINT, BORDER, false)


static func identity_row(portrait_px: int = 54) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if EvolutionState.genome != null:
		row.add_child(SpeciesPortrait.make(EvolutionState.genome, portrait_px))
	var readout := readout_label()
	readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(readout)
	return row


static func h_sep() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	return sep


static func build_grid(columns: int = 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 3)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g


static func style_button(btn: Button, large: bool = false) -> Button:
	btn.custom_minimum_size = Vector2(0, BUTTON_HEIGHT_LG if large else BUTTON_HEIGHT)
	btn.add_theme_font_size_override("font_size", 18 if large else FONT_BUTTON)
	btn.add_theme_color_override("font_color", Color(0.9, 0.98, 0.93, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.95, 0.8, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.66, 0.63, 0.6))
	btn.add_theme_stylebox_override("normal", _btn_style(BTN_BG, BTN_BORDER))
	btn.add_theme_stylebox_override("hover", _btn_style(BTN_BG_HOVER, Color(0.4, 0.9, 0.62, 0.9)))
	btn.add_theme_stylebox_override("pressed", _btn_style(BTN_BG_PRESSED, BTN_BORDER))
	btn.add_theme_stylebox_override("disabled", _btn_style(BTN_BG_DISABLED, Color(0.3, 0.35, 0.32, 0.4)))
	btn.add_theme_stylebox_override("focus", _btn_style(BTN_BG_HOVER, Color(0.55, 1.0, 0.8, 0.95)))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = false
	btn.focus_mode = Control.FOCUS_ALL
	return btn


static func make_button(text: String, tip: String, callback: Callable, large: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tip
	style_button(btn, large)
	if callback.is_valid():
		btn.pressed.connect(func() -> void:
			AudioManager.ui_click()
			callback.call())
	return btn


static func meter_bar(parent: Control, caption: String, fill: Color) -> ProgressBar:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 1)
	var cap := _label(caption, FONT_HINT, READOUT, false)
	wrap.add_child(cap)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	style_progress(bar, fill)
	wrap.add_child(bar)
	parent.add_child(wrap)
	return bar


static func style_progress(bar: ProgressBar, fill: Color = BORDER) -> void:
	bar.custom_minimum_size = Vector2(0, METER_HEIGHT)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.07, 0.06, 0.9)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)


static func meter_fill_color(t: float) -> Color:
	if t >= 0.55:
		return ACCENT_OK
	if t >= 0.28:
		return ACCENT_WARN
	return ACCENT_DANGER


## Per-frame safe: only rebuilds the styleboxes when the health band actually changes.
static func tint_meter(bar: ProgressBar, t: float) -> void:
	if bar == null:
		return
	bar.value = t
	var want := meter_fill_color(t)
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null or fill.bg_color != want:
		style_progress(bar, want)


## Centered modal card panel (stage intro / pause / title). Returns the inner VBox.
static func modal_card(parent: Node, min_width: float = MODAL_WIDTH) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(min_width, 0)
	card.add_theme_stylebox_override("panel", modal_panel_style())
	center.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(inner)
	return inner


static func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(9)
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s


static func _flat(bg: Color, border: Color, radius: int, margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.85
	s.content_margin_bottom = margin * 0.85
	return s


static func _label(text: String, size: int, color: Color, wrap: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 2 if size >= 14 else 1)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
