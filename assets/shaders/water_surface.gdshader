// Continuous water sheet for the Civ stage — one plane under the whole map at water level.
// Animated ripples (scrolling fbm), depth-fade transparency, and a fresnel rim so the surface
// reads as believable water rather than flat blue boxes.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_always;

uniform vec3 shallow_color : source_color = vec3(0.20, 0.52, 0.62);
uniform vec3 deep_color : source_color = vec3(0.04, 0.16, 0.30);
uniform vec3 fresnel_color : source_color = vec3(0.55, 0.78, 0.85);
uniform sampler2D water_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_water_normal_tex = false;
uniform float wave_scale = 0.08;     // size of the ripple pattern
uniform float wave_speed = 0.35;     // ripple scroll speed
uniform float wave_strength = 0.18;  // normal-perturb amount (how choppy)
uniform float surface_alpha = 0.82;  // base transparency of the sheet

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
		p = p * 2.0 + 11.0;
		a *= 0.5;
	}
	return v;
}

vec3 unpack_normal(vec3 n) {
	return normalize(n * 2.0 - 1.0);
}

void fragment() {
	vec2 w = (UV - 0.5) * 64.0;
	float t = TIME * wave_speed;
	// Two counter-scrolling ripple layers for a non-repeating animated sheet.
	float r1 = fbm(w * wave_scale * 4.0 + vec2(t, t * 0.6));
	float r2 = fbm(w * wave_scale * 7.0 - vec2(t * 0.4, t));
	float ripple = (r1 + r2) * 0.5;

	// Tonal depth: ripple troughs read as deeper water.
	vec3 base = mix(deep_color, shallow_color, smoothstep(0.35, 0.75, ripple));

	// Fresnel rim — brighter at grazing angles, like real water.
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), normalize(NORMAL)), 0.0, 1.0), 3.0);
	ALBEDO = mix(base, fresnel_color, fres * 0.6);

	// Perturb the normal so specular highlights shimmer across the ripples.
	float nx = fbm(w * wave_scale * 6.0 + vec2(t, 0.0)) - 0.5;
	float nz = fbm(w * wave_scale * 6.0 + vec2(0.0, t)) - 0.5;
	vec3 proc_normal = normalize(vec3(nx * wave_strength * 2.0, nz * wave_strength * 2.0, 1.0));
	vec3 tex_normal_a = unpack_normal(texture(water_normal_tex, UV * 18.0 + vec2(t, t * 0.6) * 0.16).rgb);
	vec3 tex_normal_b = unpack_normal(texture(water_normal_tex, UV * 31.0 - vec2(t * 0.4, t) * 0.10).rgb);
	vec3 tex_normal = normalize(vec3((tex_normal_a.xy + tex_normal_b.xy * 0.65) * 0.55, 1.0));
	NORMAL_MAP = (use_water_normal_tex ? normalize(mix(proc_normal, tex_normal, 0.62)) : proc_normal) * 0.5 + 0.5;

	METALLIC = 0.0;
	ROUGHNESS = 0.08 + ripple * 0.12;
	SPECULAR = 0.6;
	ALPHA = surface_alpha + fres * (1.0 - surface_alpha);
}
