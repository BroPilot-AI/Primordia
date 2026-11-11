## Primordial-stage HUD: a progress bar + label that fills as the germ eats, with a cute
## Tardigrade mascot that rides the fill edge and cheers when you're fully evolved.
## Builds its widgets in code; listens to the global bus.
extends CanvasLayer

const BAR_POS := Vector2(20, 20)
const BAR_SIZE := Vector2(380, 26)

var _bar: ProgressBar
var _label: Label
var _mascot: Sprite2D
var _tex_normal: Texture2D
var _tex_happy: Texture2D
var _t := 0.0


func _ready() -> void:
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.001
	StageChrome.style_progress(_bar, StageChrome.BORDER)
	_bar.custom_minimum_size = BAR_SIZE
	_bar.position = BAR_POS
	add_child(_bar)

	_label = StageChrome.status_label("Eat motes to evolve")
	_label.position = Vector2(20, 56)
	_label.size = Vector2(380, 24)
	add_child(_label)

	# Tardigrade mascot rides the bar's fill edge (the player's growth buddy).
	if ResourceLoader.exists("res://assets/sprites/mascot_tardigrade.png"):
		_tex_normal = load("res://assets/sprites/mascot_tardigrade.png")
	if ResourceLoader.exists("res://assets/sprites/mascot_tardigrade_happy.png"):
		_tex_happy = load("res://assets/sprites/mascot_tardigrade_happy.png")
	if _tex_normal != null:
		_mascot = Sprite2D.new()
		_mascot.texture = _tex_normal
		_mascot.scale = Vector2.ONE * (38.0 / float(_tex_normal.get_height()))
		add_child(_mascot)
		_position_mascot(0.0)

	Events.evolution_progress_changed.connect(_on_progress)


func _process(delta: float) -> void:
	if _mascot != null:
		_t += delta
		_mascot.offset.y = sin(_t * 4.0) * 2.5   # gentle bob, riding the bar


func _position_mascot(progress: float) -> void:
	if _mascot == null:
		return
	# Sit on top of the fill edge, clamped within the bar.
	var x := BAR_POS.x + clampf(progress, 0.02, 1.0) * BAR_SIZE.x
	_mascot.position = Vector2(x, BAR_POS.y - 4.0)


func _on_progress(progress: float) -> void:
	_bar.value = progress
	_label.text = "Evolving… %d%%" % int(progress * 100.0)
	_position_mascot(progress)
	if _mascot != null and _tex_happy != null:
		_mascot.texture = _tex_happy if progress >= 0.99 else _tex_normal
