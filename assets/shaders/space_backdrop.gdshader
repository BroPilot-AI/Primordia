// Deep-space backdrop: nebula clouds behind three parallax star layers.
// Drawn in screen space, so stars stay pin-points at every zoom and tilt, and scrolled by the
// camera's ground focus, each layer slower than the one in front of it. The galaxy board then
// floats over real depth instead of sliding across a flat wallpaper.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec2 seed_offset = vec2(0.0);   // per galaxy: every run gets its own sky
uniform vec3 nebula_a : source_color = vec3(0.10, 0.34, 0.60);
uniform vec3 nebula_b : source_color = vec3(0.46, 0.15, 0.52);
uniform vec3 dust : source_color = vec3(0.62, 0.34, 0.16);
uniform float nebula_strength = 1.0;
uniform float star_strength = 1.0;
uniform float focus_dist = 150.0;       // RTSCamera3D.back_dist: camera to its ground focus

const vec3 VOID_COLOR = vec3(0.0015, 0.0022, 0.0075);
const float NEBULA_DRIFT = 0.0012;      // parallax, in screen heights per world unit
const float FAR_DRIFT = 0.0020;
const float MID_DRIFT = 0.0036;
const float NEAR_DRIFT = 0.0062;


// Integer hash of a lattice point. A float hash (fract of a big product) is not safe here: the
// seed offset pushes coordinates high enough that two ways of rounding the same corner disagree,
// which cracks the clouds into hard-edged shards.
uint mix_bits(uint x) {
	x ^= x >> 16u;
	x *= 2146121005u;
	x ^= x >> 15u;
	x *= 2221713035u;
	x ^= x >> 16u;
	return x;
}

float hash21(vec2 p, uint salt) {
	ivec2 i = ivec2(floor(p));
	uint h = mix_bits(uint(i.x) + mix_bits(uint(i.y) + mix_bits(salt)));
	return float(h >> 8u) * (1.0 / 16777216.0);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
			mix(hash21(i, 0u), hash21(i + vec2(1.0, 0.0), 0u), u.x),
			mix(hash21(i + vec2(0.0, 1.0), 0u), hash21(i + vec2(1.0, 1.0), 0u), u.x),
			u.y);
}

float fbm(vec2 p) {
	const mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));   // rotate each octave: no grid streaks
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = turn * p * 2.03;
		a *= 0.5;
	}
	return v;
}

vec2 rotated(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// One star per grid cell at most, kept clear of the cell edge so a single lookup is enough.
vec3 star_layer(vec2 p, float density, float fill, uint layer, float glint) {
	vec2 g = rotated(p, float(layer) * 0.7) * density;
	vec2 cell = floor(g);
	uint salt = layer * 16u;
	float pick = hash21(cell, salt);
	if (pick > fill) {
		return vec3(0.0);
	}
	vec2 centre = 0.25 + 0.5 * vec2(hash21(cell, salt + 1u), hash21(cell, salt + 2u));
	vec2 delta = fract(g) - centre;
	float d = length(delta);
	float big = pow(hash21(cell, salt + 3u), 5.0);             // a few large, most small
	float core = smoothstep(mix(0.045, 0.11, big), 0.0, d);
	float rays = max(0.0, 1.0 - abs(delta.x * delta.y) * 1400.0) * smoothstep(0.24, 0.0, d);
	float twinkle = 0.78 + 0.22 * sin(TIME * (0.8 + 2.4 * pick / fill) + pick * 97.0);
	vec3 tint = mix(vec3(0.66, 0.80, 1.0), vec3(1.0, 0.84, 0.64), hash21(cell, salt + 4u));
	float light = core * core * mix(0.55, 2.6, big) + rays * big * glint;
	return tint * light * twinkle;
}

void fragment() {
	// Screen position in screen heights, turned into world X/Z directions so the sky turns with
	// the map when the camera orbits.
	vec2 screen = VERTEX.xy * abs(PROJECTION_MATRIX[1][1]) * 0.5;
	vec2 right = normalize(INV_VIEW_MATRIX[0].xz);
	vec2 up = normalize(INV_VIEW_MATRIX[1].xz);
	vec2 sky = screen.x * right + screen.y * up;
	vec2 focus = (CAMERA_POSITION_WORLD - INV_VIEW_MATRIX[2].xyz * focus_dist).xz;

	// Nebula: two warped cloud fields, a warm dust seam where they overlap, dark lanes on top.
	vec2 q = (sky + focus * NEBULA_DRIFT) * 1.35 + seed_offset;
	vec2 warp = vec2(fbm(q + vec2(1.7, 9.2)), fbm(q + vec2(8.3, 2.8)));
	float cloud_a = smoothstep(0.40, 0.82, fbm(q + 1.7 * warp + TIME * 0.003));
	float cloud_b = smoothstep(0.46, 0.86, fbm(q * 1.6 - 1.3 * warp + vec2(31.4, 12.9)));
	float lanes = smoothstep(0.42, 0.74, fbm(q * 2.7 + 2.2 * warp + vec2(5.0, 40.0)));
	vec3 color = VOID_COLOR;
	color += nebula_a * cloud_a * 0.26 * nebula_strength;
	color += nebula_b * cloud_b * 0.23 * nebula_strength;
	color += dust * cloud_a * cloud_b * 0.36 * nebula_strength;
	color *= mix(1.0, 0.35, lanes * (cloud_a + cloud_b) * 0.5);

	// Stars: fewer where the clouds are thick, so the nebula reads as being in front of them.
	float clear = 1.0 - 0.45 * clamp(cloud_a + cloud_b, 0.0, 1.0);
	vec3 stars = star_layer(sky + focus * FAR_DRIFT + seed_offset, 46.0, 0.55, 1u, 0.0) * 0.55;
	stars += star_layer(sky + focus * MID_DRIFT + seed_offset, 25.0, 0.42, 2u, 0.25) * 0.85;
	stars += star_layer(sky + focus * NEAR_DRIFT + seed_offset, 11.0, 0.30, 3u, 1.0) * 1.25;
	color += stars * clear * star_strength;

	ALBEDO = color;
}
