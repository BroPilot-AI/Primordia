// Continuous water sheet for the Civ stage: one plane across the whole map at water level.
// Ripples drift in world space, the colour runs from turquoise shallows at the coast to deep
// blue in open water, and lines of surf roll in along the shore.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.20, 0.52, 0.62);
uniform vec3 deep_color : source_color = vec3(0.04, 0.16, 0.30);
uniform vec3 fresnel_color : source_color = vec3(0.55, 0.78, 0.85);
uniform vec3 foam_color : source_color = vec3(0.90, 0.97, 0.96);
uniform sampler2D water_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_water_normal_tex = false;
// Distance from land: 0 on land, 1 in open water, laid over the map in world space.
uniform sampler2D shore_map : filter_linear, repeat_disable;
uniform bool use_shore_map = false;
uniform vec2 shore_origin = vec2(0.0);  // world XZ of the shore map's first corner
uniform vec2 shore_size = vec2(1.0);    // world XZ span of the shore map
uniform float wave_scale = 0.06;     // ripple cells per world unit
uniform float wave_speed = 0.35;     // ripple scroll speed
uniform float wave_strength = 0.18;  // normal-perturb amount (how choppy)

const float SHALLOWS_WOBBLE = 1.6;   // world units the shallows are bent by, so they are not hex-straight
const float LIP_WIDTH = 0.42;        // world units of steady white where water meets land
const float SURF_SPACING = 1.9;      // world units between one line of surf and the next

varying vec3 world_pos;


// Integer lattice hash: a sin-based hash breaks into hard blocks on some GPUs.
uint mix_bits(uint x) {
	x ^= x >> 16u;
	x *= 2146121005u;
	x ^= x >> 15u;
	x *= 2221713035u;
	x ^= x >> 16u;
	return x;
}

float hash21(vec2 p) {
	ivec2 i = ivec2(floor(p));
	uint h = mix_bits(uint(i.x) + mix_bits(uint(i.y)));
	return float(h >> 8u) * (1.0 / 16777216.0);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
			mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
			u.y);
}

float fbm(vec2 p) {
	const mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = turn * p * 2.03;
		a *= 0.5;
	}
	return v / 0.875;
}

vec3 unpack_normal(vec3 n) {
	return normalize(n * 2.0 - 1.0);
}

// Signed distance to a pointy-top hexagon whose flat sides sit `apothem` from its centre.
float hexagon(vec2 p, float apothem) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p = abs(p.yx);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * apothem, k.z * apothem), apothem);
	return length(p) * sign(p.y);
}

// World distance from `p` to the nearest land tile, exact out to `reach` (which must stay under
// 1.4 apothems: the search covers one ring of tiles, and a tile two rows off can be that near).
float coast_distance(vec2 p, float reach) {
	ivec2 size = textureSize(shore_map, 0);
	vec2 texel = shore_size / vec2(size);    // half a column wide, one row tall
	vec2 local = p - shore_origin;
	int row = int(floor(local.y / texel.y));
	float nearest = reach;
	for (int dy = -1; dy <= 1; dy++) {
		int y = row + dy;
		if (y < 0 || y >= size.y) {
			continue;
		}
		int odd = y & 1;    // odd rows start one texel later
		int col = int(floor((local.x / texel.x - float(odd)) * 0.5));
		for (int dx = -1; dx <= 1; dx++) {
			int first = (col + dx) * 2 + odd;
			if (first < 0 || first + 1 >= size.x || texelFetch(shore_map, ivec2(first, y), 0).r > 0.0) {
				continue;
			}
			vec2 centre = vec2(float(first + 1) * texel.x, (float(y) + 0.5) * texel.y);
			nearest = min(nearest, hexagon(local - centre, texel.x));
		}
	}
	return max(nearest, 0.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = world_pos.xz;
	float t = TIME * wave_speed;
	// Two counter-drifting ripple layers for a non-repeating animated sheet.
	float r1 = fbm(w * wave_scale + vec2(t, t * 0.6) * 0.25);
	float r2 = fbm(w * wave_scale * 1.75 - vec2(t * 0.4, t) * 0.25);
	float ripple = (r1 + r2) * 0.5;

	// Depth: shallow at the coast, deep in open water; without a shore map it is all open water.
	float depth = 1.0;
	float foam = 0.0;
	if (use_shore_map) {
		vec2 bend = vec2(noise(w * 0.22 + 3.1), noise(w * 0.22 + 7.7)) - 0.5;
		float shore = texture(shore_map, (w + bend * 2.0 * SHALLOWS_WOBBLE - shore_origin) / shore_size).r;
		depth = smoothstep(0.14, 0.86, shore);
		float reach = shore_size.x / float(textureSize(shore_map, 0).x) * 1.3;
		float coast = coast_distance(w, reach);
		// Surf: bright lines that roll in toward the land, breaking up along their length and
		// fading out to sea.
		float line = sin(coast * 6.2831853 / SURF_SPACING + t * 3.2 + ripple * 6.0);
		float breakup = smoothstep(0.32, 0.62, noise(w * 0.6 + vec2(t * 0.5, 0.0)));
		foam = smoothstep(0.80, 0.97, line) * breakup * (1.0 - smoothstep(0.35, 0.92, coast / reach)) * 0.8;
		// A thin steady lip of white where the water meets the land, a little ragged.
		float lip = LIP_WIDTH * (0.6 + 0.8 * noise(w * 1.1 + vec2(0.0, t * 0.6)));
		foam = max(foam, 1.0 - smoothstep(lip * 0.6, lip, coast));
	}

	// Swells: ripple crests read as slightly shallower, lighter water.
	vec3 base = mix(shallow_color, deep_color, clamp(depth + (0.5 - ripple) * 0.7, 0.0, 1.0));

	// Fresnel rim: brighter at grazing angles, like real water.
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), normalize(NORMAL)), 0.0, 1.0), 3.0);
	ALBEDO = mix(mix(base, fresnel_color, fres * 0.6), foam_color, foam);

	// Perturb the normal so specular highlights shimmer across the ripples.
	float nx = fbm(w * wave_scale * 1.5 + vec2(t, 0.0) * 0.25) - 0.5;
	float nz = fbm(w * wave_scale * 1.5 + vec2(0.0, t) * 0.25 + 31.0) - 0.5;
	vec3 proc_normal = normalize(vec3(nx * wave_strength * 2.0, nz * wave_strength * 2.0, 1.0));
	vec3 tex_normal_a = unpack_normal(texture(water_normal_tex, w * 0.050 + vec2(t, t * 0.6) * 0.16).rgb);
	vec3 tex_normal_b = unpack_normal(texture(water_normal_tex, w * 0.086 - vec2(t * 0.4, t) * 0.10).rgb);
	vec3 tex_normal = normalize(vec3((tex_normal_a.xy + tex_normal_b.xy * 0.65) * 0.55, 1.0));
	NORMAL_MAP = (use_water_normal_tex ? normalize(mix(proc_normal, tex_normal, 0.62)) : proc_normal) * 0.5 + 0.5;

	METALLIC = 0.0;
	ROUGHNESS = mix(0.08 + ripple * 0.12, 0.9, foam);
	SPECULAR = 0.6;
}
