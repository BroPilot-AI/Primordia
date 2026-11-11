class_name EvolutionCutscene
extends CanvasLayer
## Between-stage morph: your genome-driven 3D avatar EMERGES (grows + fades in) into its full
## trait-shaped body over a darkened field, captioned with what your lineage is becoming, then
## hands off to the stage's story card. Uses the SAME 3D avatar system as the in-game creature +
## HUD portrait (SpeciesVisuals + GenomeFeatures3D via SpeciesPortrait), so the morph always matches
## your real run — no separate 2D rig to drift out of sync. begin() BEFORE add_child; built in code.

const LIFE := 2.6

var _on_done := Callable()
var _genome
var _caption := ""
var _stage_index := -1   # >= 3 (Civ/Space) = the lineage's civilized leader reveal
var _paused_tree_by_self := false


func begin(genome, caption: String, on_done: Callable, stage_index: int = -1) -> void:
	_genome = genome
	_caption = caption
	_on_done = on_done
	_stage_index = stage_index


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS   # play over the frozen world
	_paused_tree_by_self = not get_tree().paused
	get_tree().paused = true

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# The morphing avatar — a large render of the player's actual 3D creature, centered.
	var px := 460
	var avatar := SpeciesPortrait.make(_genome if _genome != null else Genome.new(), px)
	avatar.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(px, px) * 0.5
	avatar.pivot_offset = Vector2(px, px) * 0.5
	avatar.scale = Vector2.ONE * 0.18   # emerge from a small seed
	avatar.modulate.a = 0.0
	root.add_child(avatar)

	var cap := Label.new()
	cap.text = _caption
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 30)
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.position.y -= 120
	cap.modulate.a = 0.0
	root.add_child(cap)

	# Grow + fade the body in, caption rises, hold, then fade the field out → story card.
	var t := _make_tween()
	t.tween_property(avatar, "scale", Vector2.ONE, LIFE * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(avatar, "modulate:a", 1.0, LIFE * 0.5)
	t.parallel().tween_property(cap, "modulate:a", 1.0, 0.7)
	t.tween_interval(0.6)
	t.tween_property(root, "modulate:a", 0.0, 0.4)
	t.finished.connect(func() -> void:
		if _on_done.is_valid():
			_on_done.call()
		_resume_if_unclaimed()
		queue_free()
	)


func _make_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)


func _resume_if_unclaimed() -> void:
	if not _paused_tree_by_self:
		return
	var tree := get_tree()
	var intro := tree.root.get_node_or_null("StageIntro")
	if intro != null and intro.has_method("is_open") and bool(intro.call("is_open")):
		return
	tree.paused = false
