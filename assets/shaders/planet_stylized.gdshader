// Stylized procedural planet surface — banded/posterized value-noise over object space, lit with
// toon diffuse so it reads as FLAT low-poly (complements the Kenney/Quaternius look, not photoreal
// PBR). Domain-warped fbm makes organic "continents"; the top band is an accent (ice cap / lava /
// sand); an optional emission band gives lava/gas a subtle glow. Per-planet palette via uniforms.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec3 color_low : source_color = vec3(0.15, 0.28, 0.5);
uniform vec3 color_high : source_color = vec3(0.45, 0.6, 0.35);
uniform vec3 color_accent : source_color = vec3(0.92, 0.9, 0.78);
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_strength = 0.0;
uniform float bands = 4.0;        // fewer = flatter / more poster-like
uniform float noise_scale = 2.6;
uniform float warp = 0.45;
uniform float accent_threshold = 0.78;
uniform float seed = 0.0;

varying vec3 v_local;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
				   mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
				   mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float v = 0.0;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.02;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 p = normalize(v_local) * noise_scale + vec3(seed);
	// domain warp for organic landmasses
	float w = fbm(p);
	float n = fbm(p + warp * vec3(w, w * 0.7, w * 1.3));
	// posterize into flat bands
	float band = floor(n * bands) / max(bands - 1.0, 1.0);
	vec3 col = mix(color_low, color_high, clamp(band, 0.0, 1.0));
	// accent the high band (caps / lava flows / sand)
	float acc = smoothstep(accent_threshold, accent_threshold + 0.12, n);
	col = mix(col, color_accent, acc);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	if (emission_strength > 0.0) {
		EMISSION = emission_color * emission_strength * acc;
	}
}
