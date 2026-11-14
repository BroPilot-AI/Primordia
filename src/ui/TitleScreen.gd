class_name TitleScreen
extends CanvasLayer
## Front door. Pick where life begins (which LOCKS your lineage branch for the whole run)
## or take a random origin, then the run starts. Built entirely in code — StageChrome brand.

signal start_requested(branch: int)  # a Genome.Branch int, or -1 for the seeded/random origin
signal continue_requested()          # resume from the checkpoint save

const BACKDROP_SHADER := preload("res://assets/shaders/title_backdrop.gdshader")
const OPTIONS := [
	{label = "Freshwater Pool", branch = Genome.Branch.FRESHWATER, lineage = "human lineage", tip = "Lakes & rivers"},
	{label = "Saltwater Coast", branch = Genome.Branch.SALTWATER, lineage = "short alien lineage", tip = "Tidal shallows"},
	{label = "Deep Ocean", branch = Genome.Branch.DEEP_OCEAN, lineage = "tall grey lineage", tip = "Abyss"},
	{label = "Inland Soil", branch = Genome.Branch.INLAND, lineage = "reptilian lineage", tip = "Wet soil"},
]


func _build(planet_label: String) -> void:
	layer = 50

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sky := ShaderMaterial.new()
	sky.shader = BACKDROP_SHADER
	backdrop.material = sky
	add_child(backdrop)

	var inner := StageChrome.modal_card(self, 520.0)

	if ResourceLoader.exists("res://assets/sprites/game_title_logo.png"):
		var logo := TextureRect.new()
		logo.texture = load("res://assets/sprites/game_title_logo.png")
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(logo)
	else:
		inner.add_child(StageChrome.hero_label("PRIMORDIA"))
	var sub := StageChrome.banner_label("A new life on %s" % planet_label)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(sub)
	inner.add_child(StageChrome.h_sep())

	# Resume from the furthest stage reached (checkpoint save).
	if SaveManager.has_save():
		var cont := StageChrome.make_button("▶  Continue", "Resume your checkpoint", func() -> void:
			continue_requested.emit()
			queue_free(), true)
		inner.add_child(cont)

	var prompt := StageChrome.section_label("CHOOSE WHERE LIFE BEGINS")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(prompt)

	for opt in OPTIONS:
		var b := StageChrome.make_button("%s  ·  %s" % [opt.label, opt.lineage], str(opt.tip), _on_origin_pressed.bind(int(opt.branch)), true)
		inner.add_child(b)

	inner.add_child(StageChrome.make_button("Random Origin", "Seed picks a biome for you", _on_origin_pressed.bind(-1), true))
	inner.add_child(StageChrome.h_sep())
	inner.add_child(StageChrome.make_button("Quit", "Leave Primordia", func() -> void: get_tree().quit()))
	var hint := StageChrome.hint_label("Your origin locks lineage for the whole run")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(hint)


func _on_origin_pressed(branch: int) -> void:
	_choose(branch)


func _choose(branch: int) -> void:
	start_requested.emit(branch)
	queue_free()
