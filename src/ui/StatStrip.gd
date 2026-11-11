extends HFlowContainer
## (No class_name — referenced via preload from stages so it never depends on the global class cache
## being rescanned, which is what broke the first wiring attempt.)
## Age-of-Empires-style resource bar: a row of [glyph][count] chips across the top of a build panel.
## The theme font (DynaPuff, a display face) has no dingbat glyphs, so chips render with a system
## SYMBOL font — real glyphs, not tofu boxes. Per refresh: begin(), set_chip(...) per live stat, prune().
##
## Usage:
##     _strip.begin()
##     _strip.set_chip("credits", "¤", "120", Color(1,0.88,0.4), "Interstellar credits")
##     _strip.prune()

var _chips: Dictionary = {}
var _seen: Dictionary = {}
var _font: SystemFont


func _init() -> void:
	add_theme_constant_override("h_separation", 10)
	add_theme_constant_override("v_separation", 2)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font = SystemFont.new()
	# Windows symbol/emoji faces first, then generic fallbacks — covers ¤ ◆ ⚡ ● ▲ ★ ☻ ⌂ etc.
	_font.font_names = PackedStringArray(["Segoe UI Symbol", "Segoe UI Emoji", "Arial", "Sans-Serif"])


## Start a refresh pass. Any chip not re-set before prune() is removed.
func begin() -> void:
	_seen.clear()


## Add or update a chip. `glyph` is a unicode symbol; `value` is the count text beside it.
func set_chip(key: String, glyph: String, value: String, color: Color = Color(0.92, 0.97, 1.0), tip: String = "") -> void:
	_seen[key] = true
	var lbl: Label = _chips.get(key, null)
	if lbl == null:
		lbl = Label.new()
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("outline_size", 3)
		add_child(lbl)
		_chips[key] = lbl
	lbl.text = "%s %s" % [glyph, value]
	lbl.add_theme_color_override("font_color", color)
	lbl.tooltip_text = tip
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE


## Remove chips that weren't set this pass.
func prune() -> void:
	for key in _chips.keys():
		if not _seen.has(key):
			_chips[key].queue_free()
			_chips.erase(key)
