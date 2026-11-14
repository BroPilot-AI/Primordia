// Title backdrop: a young, lifeless world seen from orbit at dawn. Nebula and stars above, the
// planet's horizon across the lower screen, its air lit by a sun that is just clearing the edge.
// The ground slides slowly toward the viewer, as if the camera were in orbit.
shader_type canvas_item;

// All positions are in screen heights from the screen centre, y up.
const vec2 PLANET_CENTRE = vec2(0.25, -2.17);
const float PLANET_RADIUS = 2.05;
const vec3 SUN_DIR = vec3(-0.260, 0.614, -0.745);   // unit; z points at the viewer, so the sun is beyond the horizon
const float SPIN = 0.010;                           // radians per second
const float EXPOSURE = 1.5;

const vec2 SKY_OFFSET = vec2(13.0, 4.0);
const vec3 VOID_COLOR = vec3(0.0015, 0.0022, 0.0075);
const vec3 NEBULA_A = vec3(0.10, 0.34, 0.60);
const vec3 NEBULA_B = vec3(0.46, 0.15, 0.52);
const vec3 DUST = vec3(0.62, 0.34, 0.16);

const vec3 SEA_DEEP = vec3(0.004, 0.035, 0.11);
const vec3 SEA_SHALLOW = vec3(0.02, 0.22, 0.24);
const vec3 LAND_RUST = vec3(0.21, 0.075, 0.035);
const vec3 LAND_OCHRE = vec3(0.36, 0.22, 0.10);
const vec3 LAND_HIGH = vec3(0.30, 0.27, 0.24);
const vec3 CLOUD = vec3(0.92);
const vec3 NIGHT_FILL = vec3(0.012, 0.02, 0.04);
const vec3 AIR = vec3(0.10, 0.36, 0.95);
const vec3 DAWN = vec3(1.0, 0.50, 0.20);
const vec3 SUN_COLOR = vec3(1.0, 0.86, 0.66);


// Integer lattice hash: exact at any offset, so the clouds never crack along the grid.
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

// Nebula: two warped cloud fields, a warm dust seam where they overlap, dark lanes, then stars.
vec3 sky(vec2 p) {
	vec2 q = p * 1.35 + SKY_OFFSET;
	vec2 warp = vec2(fbm(q + vec2(1.7, 9.2)), fbm(q + vec2(8.3, 2.8)));
	float cloud_a = smoothstep(0.40, 0.82, fbm(q + 1.7 * warp + TIME * 0.003));
	float cloud_b = smoothstep(0.46, 0.86, fbm(q * 1.6 - 1.3 * warp + vec2(31.4, 12.9)));
	float lanes = smoothstep(0.42, 0.74, fbm(q * 2.7 + 2.2 * warp + vec2(5.0, 40.0)));
	vec3 color = VOID_COLOR;
	color += NEBULA_A * cloud_a * 0.15;
	color += NEBULA_B * cloud_b * 0.13;
	color += DUST * cloud_a * cloud_b * 0.22;
	color *= mix(1.0, 0.35, lanes * (cloud_a + cloud_b) * 0.5);

	float clear = 1.0 - 0.45 * clamp(cloud_a + cloud_b, 0.0, 1.0);
	vec3 stars = star_layer(p + SKY_OFFSET, 46.0, 0.55, 1u, 0.0) * 0.55;
	stars += star_layer(p + SKY_OFFSET, 25.0, 0.42, 2u, 0.25) * 0.85;
	stars += star_layer(p + SKY_OFFSET, 11.0, 0.30, 3u, 1.0) * 1.25;
	return color + stars * clear;
}

// The lit surface at a point on the disc; n is the outward normal there.
vec3 ground(vec3 n) {
	// Ground coordinates wrap around the left-right axis: the pinch at their poles stays
	// off-screen, and spinning slides the ground from the horizon toward the viewer.
	vec2 s = vec2(asin(n.x), atan(n.z, n.y) - TIME * SPIN) * 3.0 + vec2(4.0, 20.0);
	vec2 warp = vec2(fbm(s * 1.4 + vec2(3.1, 7.7)), fbm(s * 1.4 + vec2(9.4, 1.3)));
	float height = fbm(s + 0.9 * warp);
	float land = smoothstep(0.50, 0.53, height);
	float shallows = smoothstep(0.44, 0.50, height);
	vec3 sea = mix(SEA_DEEP, SEA_SHALLOW, shallows * shallows);
	vec3 rock = mix(LAND_RUST, LAND_OCHRE, smoothstep(0.35, 0.65, fbm(s * 4.0 + vec2(17.0, 3.0))));
	rock = mix(rock, LAND_HIGH, smoothstep(0.60, 0.72, height));
	float cloud = smoothstep(0.54, 0.80, fbm(s * 2.6 + 2.2 * warp + vec2(TIME * 0.006, 50.0)));
	vec3 albedo = mix(mix(sea, rock, land), CLOUD, cloud * 0.9);

	float sun = dot(n, SUN_DIR);
	float day = smoothstep(-0.10, 0.75, sun);
	vec3 light = mix(DAWN, vec3(1.0), smoothstep(0.05, 0.55, sun)) * day * 1.5 + NIGHT_FILL;
	vec3 color = albedo * light;
	// Sun glitter on open water.
	vec3 mirror = normalize(SUN_DIR + vec3(0.0, 0.0, 1.0));
	color += SUN_COLOR * pow(max(dot(n, mirror), 0.0), 90.0) * (1.0 - land) * (1.0 - cloud) * 1.2;
	// Air: the nearer the horizon, the more of it the eye looks through.
	float haze = pow(1.0 - n.z, 5.0);
	return mix(color, AIR * (0.20 + 1.3 * day), haze * 0.85);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = vec2((UV.x - 0.5) * aspect, 0.5 - UV.y);
	vec2 d = (p - PLANET_CENTRE) / PLANET_RADIUS;
	float r = length(d);
	float pixel = SCREEN_PIXEL_SIZE.y / PLANET_RADIUS;
	float disc = smoothstep(1.0 + pixel, 1.0 - pixel, r);

	vec3 color = vec3(0.0);
	if (disc < 1.0) {
		color = sky(p) * (1.0 - disc);
	}
	if (disc > 0.0) {
		float inside = min(r, 1.0);
		color += ground(vec3(d / r * inside, sqrt(1.0 - inside * inside))) * disc;
	}

	// The sun sits on the horizon where the horizon faces it.
	vec2 sun_side = normalize(SUN_DIR.xy);
	vec2 sun_at = PLANET_CENTRE + PLANET_RADIUS * sun_side;
	float sun_dist = length(p - sun_at);
	float near_sun = exp(-sun_dist * 4.0);

	// Air above the horizon: a thin bright line and a wide faint one, both strongest toward the
	// sun, burning orange low down where the light has crossed the most air.
	float altitude = max(r - 1.0, 0.0);
	float lit_air = pow(max(dot(d / r, sun_side), 0.0), 6.0);
	float glow = exp(-altitude / 0.004) * 1.3 + exp(-altitude / 0.022) * 0.35;
	vec3 air = mix(AIR, mix(DAWN, SUN_COLOR, smoothstep(0.0, 0.01, altitude)), near_sun);
	color += air * glow * (0.12 + lit_air) * (1.0 - disc);

	// Sun glare, dimmer where the planet is in front of it.
	float glare = exp(-sun_dist * 60.0) * 6.0 + exp(-sun_dist * 16.0) * 1.1 + exp(-sun_dist * 5.0) * 0.30;
	color += SUN_COLOR * glare * mix(1.0, 0.3, disc);

	COLOR = vec4(1.0 - exp(-color * EXPOSURE), 1.0);
}
