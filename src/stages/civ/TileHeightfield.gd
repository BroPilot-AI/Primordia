class_name TileHeightfield
extends RefCounted
## The top surface of one tile mesh as a grid of heights in the mesh's own space, so units can
## be placed on bumpy ground (rocks on a hill) without any physics.

const CELLS := 24            # grid squares across the footprint, each way
const EDGE_TOLERANCE := 1e-4  # keeps corners on shared edges and the outer boundary covered
const MIN_AREA := 1e-9        # x/z-projected area below this is a vertical face

var _min := Vector2.ZERO
var _step := Vector2.ONE
var _heights := PackedFloat32Array()   # (CELLS+1)^2 corner heights, 0.0 = nothing there


static func from_parts(parts: Array) -> TileHeightfield:
	var field := TileHeightfield.new()
	field._heights.resize((CELLS + 1) * (CELLS + 1))
	var tris := PackedVector3Array()
	for part in parts:
		var mesh: Mesh = part.mesh
		var xform: Transform3D = part.xform
		for v in mesh.get_faces():
			tris.append(xform * v)
	if tris.is_empty():
		return field
	var lo := Vector2(tris[0].x, tris[0].z)
	var hi := lo
	for v in tris:
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.z))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.z))
	if hi.x - lo.x <= 0.0 or hi.y - lo.y <= 0.0:
		return field
	field._min = lo
	field._step = (hi - lo) / float(CELLS)
	for t in tris.size() / 3:
		field._raise_under(tris[t * 3], tris[t * 3 + 1], tris[t * 3 + 2])
	return field


func sample(at: Vector2) -> float:
	var g := (at - _min) / _step
	if g.x < 0.0 or g.y < 0.0 or g.x > CELLS or g.y > CELLS:
		return 0.0
	var ix := mini(int(g.x), CELLS - 1)
	var iz := mini(int(g.y), CELLS - 1)
	var fx := g.x - ix
	var fz := g.y - iz
	var near := lerpf(_at(ix, iz), _at(ix + 1, iz), fx)
	var far := lerpf(_at(ix, iz + 1), _at(ix + 1, iz + 1), fx)
	return lerpf(near, far, fz)


func _at(ix: int, iz: int) -> float:
	return _heights[iz * (CELLS + 1) + ix]


# Raises every grid corner inside the triangle's x/z projection to the triangle's height there.
func _raise_under(a: Vector3, b: Vector3, c: Vector3) -> void:
	var det := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(det) < MIN_AREA:
		return
	var x0 := clampi(int(floor((minf(a.x, minf(b.x, c.x)) - _min.x) / _step.x)), 0, CELLS)
	var x1 := clampi(int(ceil((maxf(a.x, maxf(b.x, c.x)) - _min.x) / _step.x)), 0, CELLS)
	var z0 := clampi(int(floor((minf(a.z, minf(b.z, c.z)) - _min.y) / _step.y)), 0, CELLS)
	var z1 := clampi(int(ceil((maxf(a.z, maxf(b.z, c.z)) - _min.y) / _step.y)), 0, CELLS)
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var px := _min.x + ix * _step.x
			var pz := _min.y + iz * _step.y
			var wa := ((b.z - c.z) * (px - c.x) + (c.x - b.x) * (pz - c.z)) / det
			var wb := ((c.z - a.z) * (px - c.x) + (a.x - c.x) * (pz - c.z)) / det
			var wc := 1.0 - wa - wb
			if wa < -EDGE_TOLERANCE or wb < -EDGE_TOLERANCE or wc < -EDGE_TOLERANCE:
				continue
			var idx := iz * (CELLS + 1) + ix
			_heights[idx] = maxf(_heights[idx], wa * a.y + wb * b.y + wc * c.y)
