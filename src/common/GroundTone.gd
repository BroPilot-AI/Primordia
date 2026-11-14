class_name GroundTone extends RefCounted
## Per-tile tone for a hex ground field: broad lighter and darker patches plus a faint flicker from
## tile to tile, so a plain of identical tiles reads as land instead of one flat sheet of paint.
## Multiply it into the tile colour (MultiMesh instance colour).

const PATCH_FREQUENCY := 0.022   # one light-to-dark swing every eight or so tiles
const PATCH_DEPTH := 0.20        # how far a patch lightens or darkens
const WARMTH := 0.07             # light patches lean sunlit yellow, dark ones lean cool
const FLICKER := 0.045           # tile-to-tile jitter that lets single hexes just show

var _noise := FastNoiseLite.new()


func _init(tone_seed: int) -> void:
	_noise.seed = tone_seed
	_noise.frequency = PATCH_FREQUENCY


func at(pos: Vector3) -> Color:
	var patch := _noise.get_noise_2d(pos.x, pos.z)
	var cell := Vector2i(roundi(pos.x * 8.0), roundi(pos.z * 8.0))
	var flicker := float(hash(cell) % 1024) / 1023.0 * 2.0 - 1.0
	var value := 1.0 + patch * PATCH_DEPTH + flicker * FLICKER
	return Color(value * (1.0 + patch * WARMTH), value, value * (1.0 - patch * WARMTH))
