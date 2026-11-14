// Soup backdrop: a column of living water. A depth gradient, slow murk clouds, a web of light
// ripples and slanting sun shafts, each sliding at its own rate as the camera moves, so the
// water has depth instead of being a flat card behind the cells.
shader_type canvas_item;

uniform vec3 top_color : source_color = vec3(0.10, 0.34, 0.24);
uniform vec3 bottom_color : source_color = vec3(0.03, 0.13, 0.10);
uniform vec2 scroll = vec2(0.0);    // camera centre, in screen pixels
uniform float caustics = 1.0;       // light ripples: bright in the shallows, none on land
uniform float shafts = 1.0;         // sun shafts from the surface
uniform float soil = 0.0;           // damp soil crumbs: land only, where there is nothing to ripple

const float MURK_DRIFT = 0.10;      // parallax, as a share of the camera's movement
const float RIPPLE_DRIFT = 0.24;
const float SHAFT_DRIFT = 0.06;


// Integer lattice hash: stays exact however far the camera has swum.
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

// A drifting cell web: 0 on a cell border, rising toward each cell's middle.
float web(vec2 p, float t) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float nearest = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 h = vec2(hash21(cell + o, 1u), hash21(cell + o, 2u));
			vec2 point = o + 0.5 + 0.38 * sin(t + 6.2831853 * h);
			float d = length(point - f);
			if (d < nearest) {
				second = nearest;
				nearest = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return second - nearest;
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = vec2(UV.x * aspect, UV.y);                    // in screen heights
	vec2 drift = scroll * SCREEN_PIXEL_SIZE.y;

	vec3 color = mix(top_color, bottom_color, smoothstep(0.0, 1.0, UV.y));

	// Murk: big slow clouds of lighter and darker water far behind everything.
	float murk = fbm((p + drift * MURK_DRIFT) * 2.1 + vec2(TIME * 0.012, 0.0));
	color *= mix(0.66, 1.34, murk);

	// Ripples: two bent webs of light, brightest where they cross, fading with depth.
	vec2 q = p + drift * RIPPLE_DRIFT;
	vec2 bend = vec2(fbm(q * 3.5 + 3.1), fbm(q * 3.5 + 7.7)) - 0.5;
	float fine = 1.0 - smoothstep(0.0, 0.10, web(q * 6.2 + bend * 2.4, TIME * 0.40));
	float broad = 1.0 - smoothstep(0.0, 0.42, web(q * 3.3 - bend * 1.4 + 11.0, TIME * 0.25 + 2.0));
	float ripple = fine * fine * (0.12 + 0.88 * broad);
	color += mix(top_color, vec3(1.0), 0.35) * ripple * 0.30 * caustics * mix(1.0, 0.30, UV.y);

	// Soil: still crumbs, lighter in the middle, with dark damp seams between them.
	if (soil > 0.0) {
		float crumb = web(q * 5.6 + bend * 2.2, 0.0);
		float seam = 1.0 - smoothstep(0.0, 0.11, crumb);
		color *= 1.0 + soil * (0.22 * smoothstep(0.10, 0.50, crumb) - 0.38 * seam);
	}

	// Sun shafts: slanted bands from the surface that die out on the way down.
	float band = noise(vec2((p.x + p.y * 0.38 + drift.x * SHAFT_DRIFT) * 2.6, TIME * 0.05));
	float shaft = smoothstep(0.48, 0.82, band) * pow(1.0 - UV.y, 1.5);
	color += mix(top_color, vec3(1.0), 0.30) * shaft * 0.36 * shafts;

	// Darker corners keep the eye on the middle of the dish.
	vec2 v = UV - 0.5;
	color *= 1.0 - 0.85 * dot(v, v);

	COLOR = vec4(color, 1.0);
}
