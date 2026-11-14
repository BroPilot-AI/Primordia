class_name ShoreMap extends RefCounted
## How far each water tile of the hex board lies from land, baked into a small image the water
## shader reads to paint shallows and surf along the coast. The board is pointy-top hexes whose
## odd rows sit half a column to the right.

const REACH := 3   # tile steps from land at which water counts as open sea

const EVEN_ROW_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, -1), Vector2i(0, -1),
	Vector2i(-1, 1), Vector2i(0, 1),
]
const ODD_ROW_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(0, 1), Vector2i(1, 1),
]


## Steps from each tile to the nearest land tile, capped at REACH. `water` holds one byte per
## tile, row by row: 0 for land, anything else for water.
static func steps_from_land(water: PackedByteArray, cols: int) -> PackedByteArray:
	@warning_ignore("integer_division")
	var rows := water.size() / cols
	var steps := PackedByteArray()
	steps.resize(water.size())
	steps.fill(REACH)
	var frontier: Array[Vector2i] = []
	for i in water.size():
		if water[i] == 0:
			steps[i] = 0
			@warning_ignore("integer_division")
			frontier.append(Vector2i(i % cols, i / cols))
	for step in range(1, REACH):
		var reached: Array[Vector2i] = []
		for cell in frontier:
			var offsets := ODD_ROW_NEIGHBOURS if (cell.y & 1) == 1 else EVEN_ROW_NEIGHBOURS
			for offset in offsets:
				var next := cell + offset
				if next.x < 0 or next.y < 0 or next.x >= cols or next.y >= rows:
					continue
				var index := next.y * cols + next.x
				if steps[index] > step:
					steps[index] = step
					reached.append(next)
		frontier = reached
	return steps


## The steps as a one-channel image: 0 on land, 1 on open water. Every tile covers two texels
## and odd rows start one texel later, so the staggered rows land on a plain grid of texels half
## a column wide and one row tall.
static func image(water: PackedByteArray, cols: int) -> Image:
	@warning_ignore("integer_division")
	var rows := water.size() / cols
	var steps := steps_from_land(water, cols)
	var width := cols * 2 + 1
	var texels := PackedByteArray()
	texels.resize(width * rows)
	texels.fill(255)
	for y in rows:
		var row_start := y * width + (y & 1)
		for x in cols:
			@warning_ignore("integer_division")
			var value := steps[y * cols + x] * 255 / REACH
			texels[row_start + x * 2] = value
			texels[row_start + x * 2 + 1] = value
	return Image.create_from_data(width, rows, false, Image.FORMAT_R8, texels)
