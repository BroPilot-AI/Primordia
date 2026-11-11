class_name BiomeBackdrop
extends Control
## A screensaver-style animated backdrop for the primordial soup, themed per biome:
## a smooth vertical gradient plus drifting ambient life (bubbles rising in freshwater,
## marine snow falling in the deep, drifting motes in saltwater, and dust + crawling
## "worms" on land). Pure code — no background art needed. Lives on a CanvasLayer behind
## gameplay, so it fills the screen and doesn't scroll.

const CFG := {
	"freshwater": {top = Color(0.10, 0.34, 0.24), bottom = Color(0.03, 0.13, 0.10), pcol = Color(0.78, 0.98, 0.93, 0.55), n = 46, vy = -42.0, smin = 3.0, smax = 9.0, critter = false},
	"saltwater": {top = Color(0.07, 0.28, 0.34), bottom = Color(0.02, 0.10, 0.16), pcol = Color(0.80, 0.95, 1.0, 0.50), n = 52, vy = -28.0, smin = 2.0, smax = 7.0, critter = false},
	"deep_ocean": {top = Color(0.03, 0.08, 0.15), bottom = Color(0.0, 0.015, 0.05), pcol = Color(0.85, 0.90, 1.0, 0.45), n = 64, vy = 26.0, smin = 1.5, smax = 5.0, critter = false},
	"inland": {top = Color(0.20, 0.13, 0.08), bottom = Color(0.07, 0.045, 0.03), pcol = Color(0.58, 0.44, 0.30, 0.55), n = 28, vy = 9.0, smin = 2.0, smax = 6.0, critter = true},
}

var biome := "freshwater"
var _cfg: Dictionary = {}
var _grad: GradientTexture2D
var _parts: Array = []
var _critters: Array = []
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cfg = CFG.get(biome, CFG["freshwater"])
	_build_gradient()
	_spawn()
	resized.connect(_spawn)


func _build_gradient() -> void:
	var g := Gradient.new()
	g.set_color(0, _cfg.top)
	g.set_color(1, _cfg.bottom)
	_grad = GradientTexture2D.new()
	_grad.gradient = g
	_grad.fill_from = Vector2(0, 0)
	_grad.fill_to = Vector2(0, 1)
	_grad.width = 8
	_grad.height = 256


func _spawn() -> void:
	var s := _view()
	_parts.clear()
	for i in int(_cfg.n):
		_parts.append({
			pos = Vector2(randf() * s.x, randf() * s.y),
			r = randf_range(_cfg.smin, _cfg.smax),
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
	for p in _parts:
		p.pos.y += vy * delta
		p.pos.x += (p.vx + sin(_t * 1.5 + p.ph) * 8.0) * delta
		if vy < 0.0 and p.pos.y < -12.0:
			p.pos = Vector2(randf() * s.x, s.y + 12.0)
		elif vy > 0.0 and p.pos.y > s.y + 12.0:
			p.pos = Vector2(randf() * s.x, -12.0)
		if p.pos.x < -12.0:
			p.pos.x = s.x + 12.0
		elif p.pos.x > s.x + 12.0:
			p.pos.x = -12.0
	for c in _critters:
		c.pos.x += c.vx * delta
		c.pos.y += sin(_t * 2.0 + c.ph) * 8.0 * delta
		if c.pos.x < -50.0:
			c.pos.x = s.x + 50.0
		elif c.pos.x > s.x + 50.0:
			c.pos.x = -50.0
	queue_redraw()


func _draw() -> void:
	var s := _view()
	draw_texture_rect(_grad, Rect2(Vector2.ZERO, s), false)
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
