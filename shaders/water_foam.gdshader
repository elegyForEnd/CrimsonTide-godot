shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

// Shoreline foam. COLOR.a is an authored band weight (0 at both edges,
// 1 on the waterline); noise breaks the band into drifting foam.
uniform vec4 foam_color : source_color = vec4(0.82, 0.94, 0.93, 1.0);
uniform float foam_amount : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float band = COLOR.a;
	float n = vnoise(world_pos.xz * 0.055 + vec2(TIME * 0.07, -TIME * 0.05));
	float breakup = smoothstep(0.24, 0.78, n);
	float edge = band * mix(0.35, 1.0, breakup);
	ALBEDO = foam_color.rgb;
	ALPHA = clamp(edge * foam_amount, 0.0, 1.0);
}
