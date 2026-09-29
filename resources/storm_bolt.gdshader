shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
// Procedural lightning ribbon. The mesh supplies a jagged strip; this shader
// adds the torn plasma edge, the travelling surge and the hot white core.

uniform vec3 core_color : source_color = vec3(0.92, 0.96, 1.0);
uniform vec3 edge_color : source_color = vec3(0.46, 0.60, 0.98);
uniform vec3 hot_color : source_color = vec3(1.0, 0.98, 0.92);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float age = 0.0;
uniform float life = 0.52;
uniform float width : hint_range(0.01, 1.0) = 1.0;
uniform float shiver = 0.010;
uniform float seed = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + 1.0), f.x), f.y);
}

varying float v_t;
varying float v_side;

void vertex() {
	v_t = UV.y;
	v_side = UV.x;
	// Lateral tremble keyed off the ribbon height, so the bolt never looks drawn.
	float jitter = (noise(vec2(v_t * 26.0 + seed * 13.0, age * 9.0)) - 0.5) * shiver * (1.0 - v_t);
	VERTEX.x += jitter;
	VERTEX.z += jitter * 0.6;
}

void fragment() {
	// Torn edges: the outer skirt of the ribbon keeps breaking apart.
	float ragged = 0.55 + 0.45 * noise(vec2(v_t * 42.0, seed * 21.0 + age * 5.0));
	float body = 1.0 - smoothstep(0.0, 0.5, abs(v_side - 0.5) * 2.0 / max(width, 0.02));
	body = pow(max(body, 0.0), 1.35) * ragged;

	// A surge running from the cloud end down to the ground end.
	float surge = pow(max(0.0, 1.0 - abs(fract(v_t * 0.5 - age * 1.6) - 0.5) * 4.0), 6.0);
	float fade = smoothstep(0.0, 0.05, age) * pow(max(1.0 - age / max(life, 0.01), 0.0), 0.8);
	// Real lightning restrikes: two hard re-ignitions inside one flash.
	float strobe = 1.0
		+ 1.8 * exp(-pow((age - 0.15) / 0.025, 2.0))
		+ 0.9 * exp(-pow((age - 0.29) / 0.035, 2.0))
		+ 0.5 * exp(-pow((age - 0.42) / 0.04, 2.0));

	float core = pow(max(body, 0.0), 5.0);
	vec3 color = edge_color * body * 0.75 + core_color * core * 1.15 + hot_color * surge * 0.35;
	ALBEDO = color * brightness * fade * strobe;
	ALPHA = clamp(body * fade * strobe, 0.0, 1.0);
}
