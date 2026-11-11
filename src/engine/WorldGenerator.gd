## Abstract base class for infinite, streaming, deterministic 2D worlds.
##
## Ported from GDQuest's SpaceInfiniteGeneration demo
## (gdquest-demos/godot-4-procedural-generation), cleaned and typed for Godot 4.6.
##
## The world is an unbounded grid of square `sectors`. We keep roughly
## `sector_axis_count`^2 sectors loaded around the player. As the player crosses a
## sector boundary, we generate a new row/column ahead of them and free the one
## behind. Content is deterministic: `make_seed_for(x, y)` hashes the sector
## coordinates against the world seed, so revisiting a region always reproduces it.
##
## Subclass and override `_generate_sector()` to decide what lives in each sector.
## Subclasses are expected to:
##   - call `generate()` once in `_ready()`
##   - in `_physics_process()`, detect when the player has crossed a sector and call
##     `_update_sectors(offset)`
## See `SoupGenerator.gd` for a node-spawning implementation.
class_name WorldGenerator
extends Node2D

## Axis identifiers used when streaming new sectors in the direction of travel.
enum { AXIS_X, AXIS_Y }

## Size of one sector, in pixels.
@export var sector_size := 1000.0
## Number of sectors to keep loaded along each axis (a square window around the player).
@export var sector_axis_count := 10
## Base seed string. Combined with sector coordinates to make each sector deterministic.
@export var start_seed := "world_generation"

## Per-sector storage. Key: Vector2 sector coords. Value: subclass-defined
## (an Array of spawned nodes for node-based generators, or a data Dictionary).
var _sectors := {}
## Sector the player currently occupies; the streaming window is centered here.
var _current_sector := Vector2.ZERO
# These three are part of the protected API for subclasses (e.g. SoupGenerator),
# so they read as "unused" from this base class alone — suppress that false positive.
## Seeded RNG. Reseed per sector via `make_seed_for()` before generating content.
@warning_ignore("unused_private_class_variable")
var _rng := RandomNumberGenerator.new()

@warning_ignore("unused_private_class_variable")
@onready var _half_sector_size := sector_size / 2.0
@warning_ignore("unused_private_class_variable")
@onready var _sector_size_squared := sector_size * sector_size
@onready var _half_sector_count := int(sector_axis_count / 2.0)


## Generates the initial square block of sectors around the origin.
func generate() -> void:
	for x in range(-_half_sector_count, _half_sector_count):
		for y in range(-_half_sector_count, _half_sector_count):
			_generate_sector(x, y)


## Deterministic integer seed for a sector. `custom_data` lets a subclass derive
## independent sub-streams for different content layers within the same sector
## (e.g. "food" vs "hazards") without them correlating.
func make_seed_for(x_id: int, y_id: int, custom_data := "") -> int:
	var new_seed := "%s_%s_%s" % [start_seed, x_id, y_id]
	if not custom_data.is_empty():
		new_seed = "%s_%s" % [new_seed, custom_data]
	return new_seed.hash()


## Streams sectors after the player moves by `difference` (in sector cells).
func _update_sectors(difference: Vector2) -> void:
	_update_along_axis(AXIS_X, difference.x)
	_update_along_axis(AXIS_Y, difference.y)


## Override this. Generate the content of sector (x_id, y_id) and record it in
## `_sectors[Vector2(x_id, y_id)]`. Reseed `_rng` with `make_seed_for()` first.
func _generate_sector(_x_id: int, _y_id: int) -> void:
	pass


## Frees the entries stored for a sector. Default assumes an Array of Nodes
## (node-based generators). Data-only subclasses should override.
func _free_sector(key: Vector2) -> void:
	if not _sectors.has(key):
		return
	var contents = _sectors[key]
	if contents is Array:
		for item in contents:
			if is_instance_valid(item):
				item.queue_free()
	_sectors.erase(key)


## Walks one axis in the direction of travel: generates the new leading row/column
## and frees the trailing one that fell out of the window.
func _update_along_axis(axis: int, difference: float) -> void:
	if difference == 0 or (axis != AXIS_X and axis != AXIS_Y):
		return

	# Correction for the asymmetry between moving in the positive vs negative
	# direction, so sectors are added/removed on time at both edges.
	var axis_modifier := int(difference > 0)
	var sector_axis_coordinate := _current_sector.x if axis == AXIS_X else _current_sector.y
	var new_sector_line_index := int(
		sector_axis_coordinate + (_half_sector_count - axis_modifier) * difference + difference
	)

	# Range of the perpendicular axis (the full width of the new row/column).
	var other_axis_position := _current_sector.y if axis == AXIS_X else _current_sector.x
	var other_axis_min := other_axis_position - _half_sector_count
	var other_axis_max := other_axis_position + _half_sector_count

	# Generate the leading edge.
	for other_axis_coordinate in range(other_axis_min, other_axis_max):
		var x := new_sector_line_index if axis == AXIS_X else other_axis_coordinate
		var y := other_axis_coordinate if axis == AXIS_X else new_sector_line_index
		_generate_sector(x, y)

	# Free the trailing edge.
	var obsolete_sector_line_index := int(new_sector_line_index + sector_axis_count * -difference)
	for other_axis_coordinate in range(other_axis_min, other_axis_max):
		var key := Vector2(
			obsolete_sector_line_index if axis == AXIS_X else other_axis_coordinate,
			other_axis_coordinate if axis == AXIS_X else obsolete_sector_line_index
		)
		_free_sector(key)

	if axis == AXIS_X:
		_current_sector.x += difference
	else:
		_current_sector.y += difference
