class_name FloatingText extends Node2D

var _setup_text: String = ""
var _setup_color: Color = Color.WHITE
var _label: Label


func setup(text: String, color: Color) -> void:
	_setup_text = text
	_setup_color = color
	if _label != null:
		_label.text = text
		_label.modulate = color


func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	if _setup_text != "":
		_label.text = _setup_text
		_label.modulate = _setup_color
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 28.0, 0.8)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(queue_free)   # chain() so free waits for the float+fade


static func spawn(parent: Node2D, at: Vector2, text: String, color: Color) -> void:
	var ft = load("res://src/ui/FloatingText.gd").new()
	ft.position = at
	ft.setup(text, color)
	parent.add_child(ft)
