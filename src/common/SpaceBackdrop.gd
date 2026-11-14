class_name SpaceBackdrop
## The deep-space sky: one big plane under the board carrying the nebula + parallax starfield
## shader. The sky is seeded, so a galaxy keeps the same sky on its map and in its battles.

const SHADER := preload("res://assets/shaders/space_backdrop.gdshader")
const DEPTH := 160.0   # below the board; RTSCamera3D.SHADOW_FAR is sized to keep it in view
const SIZE := 2400.0
# Two cloud hues and a dust accent per sky.
const PALETTES := [
	[Color(0.10, 0.34, 0.60), Color(0.46, 0.15, 0.52), Color(0.62, 0.34, 0.16)],   # blue / violet
	[Color(0.08, 0.42, 0.40), Color(0.16, 0.20, 0.62), Color(0.55, 0.42, 0.20)],   # teal / indigo
	[Color(0.52, 0.16, 0.24), Color(0.20, 0.18, 0.58), Color(0.66, 0.40, 0.14)],   # crimson / indigo
	[Color(0.14, 0.44, 0.30), Color(0.40, 0.14, 0.44), Color(0.50, 0.46, 0.22)],   # emerald / plum
]


static func build(sky_seed: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = sky_seed
	var palette: Array = PALETTES[rng.randi() % PALETTES.size()]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("seed_offset", Vector2(rng.randf_range(0.0, 64.0), rng.randf_range(0.0, 64.0)))
	material.set_shader_parameter("nebula_a", palette[0])
	material.set_shader_parameter("nebula_b", palette[1])
	material.set_shader_parameter("dust", palette[2])
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	var backdrop := MeshInstance3D.new()
	backdrop.name = "StarfieldBackdrop"
	backdrop.mesh = plane
	backdrop.position = Vector3(0.0, -DEPTH, 0.0)
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return backdrop


## The sky every scene of the current galaxy shares.
static func for_current_galaxy() -> MeshInstance3D:
	return build(hash("%s_sky" % EvolutionState.world_seed))
