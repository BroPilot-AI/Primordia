class_name BiomeBackdrop
extends Control
## A screensaver-style animated backdrop for the primordial soup, themed per biome:
## shader-painted water (see soup_backdrop.gdshader) plus drifting ambient life (bubbles rising
## in freshwater, marine snow falling in the deep, drifting motes in saltwater, and dust +
## crawling "worms" on land). Pure code — no background art needed. Lives on a CanvasLayer
## behind gameplay and fills the screen; the water and the specks slide against the camera,
## each at its own depth.

const WATER_SHADER := preload("res://assets/shaders/soup_backdrop.gdshader")
const WRAP_MARGIN := 12.0
const FAR_DEPTH := 0.12    # share of camera movement the smallest specks slide by
const NEAR_DEPTH := 0.45   # ...and the biggest
# caustics / shafts: how much rippling light and how many sun shafts reach this water (0..1).
# soil: land has no water to ripple, so it shows damp soil crumbs instead (0..1).
const CFG := {
	"freshwater": {top = Color(0.10, 0.34, 0.24), bottom = Color(0.03, 0.13, 0.10), pcol = Color(0.78, 0.98, 0.93, 0.55), n = 46, vy = -42.0, smin = 3.0, smax = 9.0, critter = false, caustics = 1.0, shafts = 1.0, soil = 0.0},
	"saltwater": {top = Color(0.07, 0.28, 0.34), bottom = Color(0.02, 0.10, 0.16), pcol = Color(0.80, 0.95, 1.0, 0.50), n = 52, vy = -28.0, smin = 2.0, smax = 7.0, critter = false, caustics = 0.8, shafts = 0.6, soil = 0.0},
	"deep_ocean": {top = Color(0.03, 0.08, 0.15), bottom = Color(0.0, 0.015, 0.05), pcol = Color(0.85, 0.90, 1.0, 0.45), n = 64, vy = 26.0, smin = 1.5, smax = 5.0, critter = false, caustics = 0.15, shafts = 0.0, soil = 0.0},
	"inland": {top = Color(0.20, 0.13, 0.08), bottom = Color(0.07, 0.045, 0.03), pcol = Color(0.58, 0.44, 0.30, 0.55), n = 28, vy = 9.0, smin = 2.0, smax = 6.0, critter = true, caustics = 0.0, shafts = 0.0, soil = 1.0},
}

var biome := "freshwater"
var _cfg: Dictionary = {}
var _water: ShaderMaterial
var _scroll := Vector2.ZERO
var _parts: Array = []
var _critters: Array = []
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cfg = CFG.get(biome, CFG["freshwater"])
	_build_water()
	_spawn()
	resized.connect(_spawn)


## Where a drifting speck sits after the camera moved: nearer ones (higher depth) slide
## further, and one that leaves an edge comes back in on the opposite one.
static func parallax_shift(pos: Vector2, camera_moved: Vector2, depth: float, view: Vector2) -> Vector2:
	var shifted := pos - camera_moved * depth
	return Vector2(
		wrapf(shifted.x, -WRAP_MARGIN, view.x + WRAP_MARGIN),
		wrapf(shifted.y, -WRAP_MARGIN, view.y + WRAP_MARGIN))


func _build_water() -> void:
	_water = ShaderMaterial.new()
	_water.shader = WATER_SHADER
	_water.set_shader_parameter("top_color", _cfg.top)
	_water.set_shader_parameter("bottom_color", _cfg.bottom)
	_water.set_shader_parameter("caustics", _cfg.caustics)
	_water.set_shader_parameter("shafts", _cfg.shafts)
	_water.set_shader_parameter("soil", _cfg.soil)
	var rect := ColorRect.new()
	rect.name = "Water"
	rect.material = _water
	rect.show_behind_parent = true
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)


func _spawn() -> void:
	var s := _view()
	_parts.clear()
	for i in int(_cfg.n):
		var r := randf_range(_cfg.smin, _cfg.smax)
		_parts.append({
			pos = Vector2(randf() * s.x, randf() * s.y),
			r = r,
			depth = remap(r, _cfg.smin, _cfg.smax, FAR_DEPTH, NEAR_DEPTH),
			vx = randf_range(-12.0, 12.0),
			ph = randf() * TAU,
		})
	_critters.clear()
	if bool(_cfg.get("critter", false)):
		for i in 5:
			_critters.append({
				pos = Vector2(randf() * s.x, randf() * s.y),
				vx = randf_range(8.0, 22.0) * (1.0 if randf() < 0.5 else -1.0),
				ph = randf() * TAU,
			})


func _view() -> Vector2:
	return get_viewport_rect().size


func _process(delta: float) -> void:
	_t += delta
	var s := _view()
	var vy := float(_cfg.vy)
	var cam := get_viewport().get_camera_2d()
	var scroll := cam.get_screen_center_position() * cam.zoom if cam != null else Vector2.ZERO
	var camera_moved := scroll - _scroll
	_scroll = scroll
	_water.set_shader_parameter("scroll", scroll)
	for p in _parts:
		p.pos.y += vy * delta
		p.pos.x += (p.vx + sin(_t * 1.5 + p.ph) * 8.0) * delta
		p.pos = parallax_shift(p.pos, camera_moved, p.depth, s)
	for c in _critters:
		c.pos.x += c.vx * delta
		c.pos.y += sin(_t * 2.0 + c.ph) * 8.0 * delta
		if c.pos.x < -50.0:
			c.pos.x = s.x + 50.0
		elif c.pos.x > s.x + 50.0:
			c.pos.x = -50.0
	queue_redraw()


func _draw() -> void:
	var pcol: Color = _cfg.pcol
	for p in _parts:
		draw_circle(p.pos, p.r, pcol)
		draw_arc(p.pos, p.r, -1.0, 1.3, 6, Color(1, 1, 1, pcol.a * 0.5), 1.0)
	# Land critters: short segmented "worms" that wiggle along.
	var ccol := Color(0.22, 0.13, 0.08, 0.65)
	for c in _critters:
		var face := signf(c.vx)
		for seg in 4:
			var off := Vector2(-face * seg * 7.0, sin(_t * 8.0 + c.ph + float(seg)) * 3.0)
			draw_circle(c.pos + off, 5.0 - float(seg) * 0.8, ccol)
