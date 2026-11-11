// Lush textured grass ground for the Civ stage - organic green variation + dirt patches,
// tiles seamlessly across one big plane.
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 grass_dark : source_color = vec3(0.18, 0.36, 0.13);
uniform vec3 grass_light : source_color = vec3(0.36, 0.57, 0.24);
uniform vec3 dirt : source_color = vec3(0.31, 0.25, 0.15);
uniform vec3 sand_color : source_color = vec3(0.68, 0.57, 0.34);
uniform vec3 rock_color : source_color = vec3(0.43, 0.44, 0.39);
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terrain_lookup : filter_nearest, repeat_disable;
uniform vec2 terrain_grid_origin = vec2(0.0);
uniform vec2 terrain_grid_size = vec2(1.0);
uniform vec2 terrain_grid_tiles = vec2(1.0);
uniform bool use_ground_albedo_textures = false;
uniform bool use_ground_normal_textures = false;
uniform float ground_tex_scale = 0.12;
uniform float patch_scale = 5.0;   // size of big grass tone patches
uniform float dirt_scale = 14.0;   // frequency of dirt break-up
uniform float dirt_amount = 0.45;
uniform float normal_strength = 1.6;   // depth of the procedural surface break-up

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

vec3 terrain_at_world(vec2 xz) {
	vec2 tile_size = terrain_grid_size / max(terrain_grid_tiles, vec2(1.0));
	vec2 tile = floor((xz - terrain_grid_origin) / tile_size + 0.5);
	tile = clamp(tile, vec2(0.0), terrain_grid_tiles - vec2(1.0));
	vec2 terrain_uv = (tile + vec2(0.5)) / terrain_grid_tiles;
	return texture(terrain_lookup, terrain_uv).rgb;
}

vec3 unpack_normal(vec3 n) {
	return normalize(n * 2.0 - 1.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = UV;
	vec2 tex_uv = world_pos.xz * ground_tex_scale;
	float tone = fbm(w * patch_scale);
	float tone_mask = smoothstep(0.25, 0.75, tone);
	vec3 grass_flat = mix(grass_dark, grass_light, tone_mask);
	float d = fbm(w * dirt_scale + 17.0);
	float dirt_patch = smoothstep(0.6, 0.8, d) * dirt_amount;

	vec3 terrain = terrain_at_world(world_pos.xz);
	float beach = 1.0 - smoothstep(0.18, 0.86, terrain.g);
	float mountain_tile = smoothstep(0.75, 0.95, terrain.r);
	float mountain_near = 1.0 - smoothstep(0.18, 0.90, terrain.b);
	float rock = max(mountain_tile, mountain_near * 0.58);
	float beach_blend = beach * 0.72;
	float rock_blend = rock * 0.62;

	vec3 flat_col = mix(grass_flat, dirt, dirt_patch);
	flat_col = mix(flat_col, sand_color, beach_blend);
	flat_col = mix(flat_col, rock_color, rock_blend);

	vec3 grass_tex = texture(grass_albedo, tex_uv).rgb;
	vec3 dirt_tex = texture(dirt_albedo, tex_uv + vec2(17.0, 3.0)).rgb;
	vec3 rock_tex = texture(rock_albedo, tex_uv * 0.74 + vec2(5.0, 11.0)).rgb;
	vec3 sand_tex = mix(dirt_tex, sand_color, 0.42);
	vec3 tex_col = mix(grass_tex, dirt_tex, dirt_patch);
	tex_col = mix(tex_col, sand_tex, beach_blend);
	tex_col = mix(tex_col, rock_tex, rock_blend);
	tex_col *= 0.94 + 0.12 * tone_mask;

	vec3 col = use_ground_albedo_textures ? tex_col : flat_col;

	// fine speckle so it never looks flat up close
	col *= 0.92 + 0.08 * noise(w * 90.0);
	ALBEDO = col;

	// Procedural normal break-up so the surface catches light unevenly (no flat read).
	float e = 0.002;
	float hl = fbm((w + vec2(e, 0.0)) * dirt_scale);
	float hr = fbm((w - vec2(e, 0.0)) * dirt_scale);
	float hu = fbm((w + vec2(0.0, e)) * dirt_scale);
	float hd = fbm((w - vec2(0.0, e)) * dirt_scale);
	vec3 proc_normal = normalize(vec3((hr - hl) * normal_strength, (hd - hu) * normal_strength, 1.0));
	vec3 map_normal = mix(unpack_normal(texture(grass_normal, tex_uv).rgb), unpack_normal(texture(dirt_normal, tex_uv + vec2(17.0, 3.0)).rgb), dirt_patch);
	map_normal = mix(map_normal, unpack_normal(texture(dirt_normal, tex_uv).rgb), beach_blend);
	map_normal = mix(map_normal, unpack_normal(texture(rock_normal, tex_uv * 0.74 + vec2(5.0, 11.0)).rgb), rock_blend);
	map_normal = normalize(vec3(map_normal.xy + proc_normal.xy * 0.22, max(map_normal.z, 0.25)));
	NORMAL_MAP = (use_ground_normal_textures ? map_normal : proc_normal) * 0.5 + 0.5;

	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
