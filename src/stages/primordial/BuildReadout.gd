class_name BuildReadout
extends PanelContainer
## Compact primordial build panel: diet trend, nearby dissolved compounds, and a
## lightweight organelle editor backed by OrganelleEditorModel.

const OrganelleEditor := preload("res://src/stages/primordial/OrganelleEditorModel.gd")
const ORDERED_ORGANELLES := [
	"cytoplasm",
	"flagellum",
	"toxin_vacuole",
	"chloroplast",
	"mitochondria",
]

var _trend_label: Label
var _net_label: Label
var _stats_label: Label
var _pressure_label: Label
var _empty_label: Label
var _button_box: VBoxContainer
var _toggle_button: Button
var _content_box: VBoxContainer
var _buttons := {}
var _player: Node
var _expanded := true


func _ready() -> void:
	custom_minimum_size = Vector2(360, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Match StageChrome / CompactHUD brand so Soup reads like every later stage.
	add_theme_stylebox_override("panel", StageChrome.panel_style())

	var shell := HBoxContainer.new()
	shell.add_theme_constant_override("separation", 6)
	add_child(shell)

	# Same collapse toggle as CompactHUDPanel (left-side panel: "<" hides, ">" shows).
	_toggle_button = Button.new()
	_toggle_button.focus_mode = Control.FOCUS_NONE
	_toggle_button.custom_minimum_size = Vector2(CompactHUDPanel.TOGGLE_WIDTH, 34)
	_toggle_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_toggle_button.flat = true
	_toggle_button.expand_icon = true
	_toggle_button.add_theme_constant_override("icon_max_width", 18)
	_toggle_button.pressed.connect(_on_toggle_pressed)
	_sync_toggle()
	shell.add_child(_toggle_button)

	_content_box = VBoxContainer.new()
	_content_box.custom_minimum_size = Vector2(300, 0)
	_content_box.add_theme_constant_override("separation", 4)
	shell.add_child(_content_box)

	var title := StageChrome.title_label("PRIMORDIAL")
	_content_box.add_child(title)
	_content_box.add_child(StageChrome.h_sep())

	# Four glanceable lines; the detailed flows live in the NET / stats tooltips.
	_net_label = _label(24)
	_trend_label = _label()
	_stats_label = _label()
	_pressure_label = _label()
	_empty_label = _label()
	_empty_label.text = "No affordable organelles"
	_content_box.add_child(_net_label)
	_content_box.add_child(_stats_label)
	_content_box.add_child(_pressure_label)
	_content_box.add_child(_trend_label)

	_button_box = VBoxContainer.new()
	_button_box.add_theme_constant_override("separation", 3)
	_content_box.add_child(_button_box)
	_content_box.add_child(_empty_label)

	for id in ORDERED_ORGANELLES:
		var button := StageChrome.make_button(_button_text(id), "Add %s organelle" % id, _on_add_pressed.bind(id))
		_button_box.add_child(button)
		_buttons[id] = button

	Events.evolution_progress_changed.connect(_refresh_progress)
	_refresh()
	set_process(true)


func _process(_delta: float) -> void:
	_refresh()


func _refresh_progress(_p: float) -> void:
	_refresh()


func _refresh() -> void:
	_player = _player if is_instance_valid(_player) else get_tree().get_first_node_in_group("player")
	var g := EvolutionState.genome
	_trend_label.text = "Trending: %s" % g.dominant_trait() if g != null else ""
	if _player == null or not _player.has_method("get_editor_snapshot"):
		_net_label.text = "NET -- ATP/s"
		_net_label.tooltip_text = ""
		_stats_label.text = ""
		_stats_label.tooltip_text = ""
		_pressure_label.text = ""
		_set_editor_available(false)
		return

	var snapshot: Dictionary = _player.get_editor_snapshot()
	var metabolism: Dictionary = snapshot.get("metabolism", {})
	var net := float(snapshot.get("net_atp_per_second", metabolism.get("net", 0.0)))
	var production := float(metabolism.get("production", 0.0))
	var capacity := float(metabolism.get("production_capacity", production))
	var osmo := float(metabolism.get("osmo_upkeep", 0.0))
	var movement := float(metabolism.get("movement_upkeep", 0.0))
	_net_label.text = "NET %s%.1f ATP/s" % [_sign(net), absf(net)]
	_net_label.add_theme_color_override("font_color", _net_color(net))
	_net_label.tooltip_text = "Gain +%.1f/%.1f  Osmosis -%.1f  Move -%.1f\n%s" % [
		production, capacity, osmo, movement,
		_organelle_flow_text(snapshot.get("organelle_flows", {})),
	]

	var nearby: Dictionary = snapshot.get("nearby_compounds", snapshot.get("compounds", {}))
	var nearby_text := "Nearby  Glc %.0f  O2 %.0f  NH3 %.0f  PO4 %.0f" % [
		float(nearby.get("glucose", 0.0)),
		float(nearby.get("oxygen", 0.0)),
		float(nearby.get("ammonia", 0.0)),
		float(nearby.get("phosphates", 0.0)),
	]
	var compounds: Dictionary = snapshot.get("compounds", {})
	var stored_text := "Stored  Glc %.1f  O2 %.1f  cap %.0f  Burn %.2f/%.2f" % [
		float(compounds.get("glucose", 0.0)),
		float(compounds.get("oxygen", 0.0)),
		float(snapshot.get("compound_storage_capacity", 0.0)),
		float(metabolism.get("glucose_per_second", 0.0)),
		float(metabolism.get("oxygen_per_second", 0.0)),
	]
	var pressure := float(metabolism.get("starvation_pressure", 0.0))
	_pressure_label.text = "Pressure %.0f%%  Efficiency %.0f%%  Growth x%.2f" % [
		pressure * 100.0,
		float(snapshot.get("efficiency", 1.0)) * 100.0,
		float(metabolism.get("growth_multiplier", 1.0)),
	]
	_pressure_label.add_theme_color_override("font_color", _pressure_color(pressure))
	var growth_state := "" if bool(snapshot.get("can_grow", true)) else " · Growth stalled"
	# The starter germ runs an ATP deficit: with no producer, growth never resumes — say what to buy.
	var owned: Array = snapshot.get("layout", [])
	if growth_state != "" and not owned.has("mitochondria") and not owned.has("chloroplast"):
		growth_state += ": add Mitochondria"
	_stats_label.text = "ATP %.0f/%.0f · MP %d · Size %.1f%s" % [
		float(snapshot.get("atp", snapshot.get("total_atp", 0.0))),
		float(snapshot.get("atp_capacity", 0.0)),
		int(snapshot.get("mp", 0)),
		float(snapshot.get("size", 0.0)),
		growth_state,
	]
	_stats_label.tooltip_text = "Speed %.0f\n%s\n%s" % [
		float(snapshot.get("speed", 0.0)), nearby_text, stored_text]

	var any_affordable := false
	var layout: Array = snapshot.get("layout", [])
	var mp := int(snapshot.get("mp", 0))
	for id in ORDERED_ORGANELLES:
		var can_afford := OrganelleEditor.can_add(layout, id, mp)
		var button: Button = _buttons[id]
		button.visible = can_afford
		button.disabled = not can_afford
		if can_afford:
			any_affordable = true
	_empty_label.visible = not any_affordable


func _on_add_pressed(id: String) -> void:
	AudioManager.ui_click()
	_player = _player if is_instance_valid(_player) else get_tree().get_first_node_in_group("player")
	if _player != null and _player.has_method("add_organelle"):
		_player.add_organelle(id)
	_refresh()


func _on_toggle_pressed() -> void:
	AudioManager.ui_click()
	_expanded = not _expanded
	# Collapse like CompactHUDPanel: hide the content and shrink to just the toggle, so the
	# toggle stays on screen (sliding the panel off-screen took the toggle with it).
	_content_box.visible = _expanded
	custom_minimum_size.x = 360.0 if _expanded else 0.0
	reset_size()
	_sync_toggle()


func _sync_toggle() -> void:
	_toggle_button.tooltip_text = "Hide HUD" if _expanded else "Show HUD"
	var icon_path := CompactHUDPanel.COLLAPSE_ICON if _expanded else CompactHUDPanel.EXPAND_ICON
	_toggle_button.icon = load(icon_path) if ResourceLoader.exists(icon_path) else null
	_toggle_button.text = "" if _toggle_button.icon != null else ("<" if _expanded else ">")


func _label(font_size: int = 14) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", StageChrome.STATUS if font_size < 20 else StageChrome.TITLE)
	label.add_theme_color_override("font_outline_color", StageChrome.OUTLINE)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_PASS   # so tooltip_text shows on hover
	return label


func _set_editor_available(available: bool) -> void:
	for id in ORDERED_ORGANELLES:
		var button: Button = _buttons[id]
		button.visible = available
		button.disabled = not available
	_empty_label.visible = not available


func _button_text(id: String) -> String:
	var data: Dictionary = OrganelleEditor.ORGANELLES[id]
	var atp := float(data.get("atp", 0.0))
	return "%s  %d MP  %s%.1f ATP  %.1f size" % [
		id.replace("_", " ").capitalize(),
		int(data.get("mp_cost", 0)),
		_sign(atp),
		absf(atp),
		float(data.get("size", 0.0)),
	]


func _net_color(net: float) -> Color:
	if net >= 0.5:
		return Color(0.62, 1.0, 0.55)
	if net <= -0.5:
		return Color(1.0, 0.42, 0.38)
	return Color(1.0, 0.88, 0.42)


func _pressure_color(pressure: float) -> Color:
	if pressure <= 0.05:
		return Color(0.72, 1.0, 0.68)
	if pressure >= 0.65:
		return Color(1.0, 0.42, 0.38)
	return Color(1.0, 0.88, 0.42)


func _sign(value: float) -> String:
	return "+" if value >= 0.0 else "-"


func _organelle_flow_text(flows: Dictionary) -> String:
	var producers: Dictionary = flows.get("producers", {})
	var consumers: Dictionary = flows.get("consumers", {})
	return "Produce: %s\nUse: %s" % [
		_flow_bucket_text(producers, true),
		_flow_bucket_text(consumers, false),
	]


func _flow_bucket_text(bucket: Dictionary, positive: bool) -> String:
	var parts: Array[String] = []
	for id in ORDERED_ORGANELLES:
		if not bucket.has(id):
			continue
		var data: Dictionary = bucket[id]
		var total := absf(float(data.get("total", 0.0)))
		parts.append("%s x%d %s%.1f" % [
			id.replace("_", " "),
			int(data.get("count", 0)),
			"+" if positive else "-",
			total,
		])
	if parts.is_empty():
		return "none"
	return ", ".join(parts)
