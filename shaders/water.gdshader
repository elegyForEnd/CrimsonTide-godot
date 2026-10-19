shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;

// Stylised high-quality water. Opaque single-pass: depth colour, animated
// caustic reflections, drifting wave bands, Fresnel sky tint and sun glints.
// No layered transparency, so rivers entering lakes never fight over sorting.
uniform vec4 shallow_color : source_color = vec4(0.24, 0.66, 0.60, 1.0);
uniform vec4 deep_color : source_color = vec4(0.060, 0.235, 0.360, 1.0);
uniform vec4 sky_color : source_color = vec4(0.55, 0.75, 0.88, 1.0);
uniform vec4 glint_color : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform vec4 caustic_color : source_color = vec4(0.62, 1.0, 0.94, 1.0);
uniform float wave_strength : hint_range(0.0, 2.5) = 1.0;
uniform float wave_scale : hint_range(0.002, 12.0) = 1.6;
uniform float detail : hint_range(0.0, 1.0) = 1.0;
uniform float glint : hint_range(0.0, 2.0) = 1.0;
uniform float caustic_strength : hint_range(0.0, 2.0) = 1.0;
uniform float seed : hint_range(0.0, 12.0) = 0.0;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

float surface_height(vec2 p, float t) {
	float a = fbm(p * 0.95 + vec2(t * 0.55, t * 0.31));
	float b = fbm(p * 2.10 - vec2(t * 0.37, -t * 0.44) + vec2(11.0, 5.0));
	float c = sin(p.x * 3.1 + p.y * 1.7 + t * 2.2) * 0.035;
	return a + b * 0.55 + c;
}

float caustic(vec2 p, float t) {
	vec2 q = p * 0.65;
	float a = fbm(q + vec2(t * 0.28, t * 0.22));
	float b = fbm(q * 1.75 - vec2(t * 0.24, -t * 0.30) + vec2(4.0, 7.0));
	float ridge = (1.0 - abs(a * 2.0 - 1.0)) * (1.0 - abs(b * 2.0 - 1.0));
	return pow(clamp(ridge, 0.0, 1.0), 2.1);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bob = sin(world_pos.x * 0.08 + TIME * 0.9 + seed)
		* cos(world_pos.z * 0.095 - TIME * 0.7 + seed);
	// Surface is 0.0052 m high; keep troughs well above the ground plane.
	VERTEX.y += bob * 0.0012 * wave_strength;
}

void fragment() {
	float depth01 = clamp(COLOR.r, 0.0, 1.0);
	vec2 p = world_pos.xz * wave_scale + vec2(seed * 3.7);
	float t = TIME * 0.42;

	float h = surface_height(p, t);
	float e = 0.16;
	float hx = surface_height(p + vec2(e, 0.0), t) - surface_height(p - vec2(e, 0.0), t);
	float hz = surface_height(p + vec2(0.0, e), t) - surface_height(p - vec2(0.0, e), t);
	vec3 normal_world = normalize(vec3(-hx * 2.0 * wave_strength, 1.0, -hz * 2.0 * wave_strength));
	NORMAL = normalize(NORMAL + vec3(-hx * 1.5 * wave_strength, 0.0, -hz * 1.5 * wave_strength));

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fresnel = pow(1.0 - clamp(dot(normal_world, view_dir), 0.0, 1.0), 3.2);

	vec3 base = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.02, 0.92, depth01));
	vec3 color = mix(base, sky_color.rgb, fresnel * 0.12);
	color = mix(color, color * 1.22 + vec3(0.015, 0.055, 0.065), smoothstep(0.46, 0.80, h) * 0.50 * detail);

	float caus = caustic(world_pos.xz * 0.55, TIME) * (1.0 - smoothstep(0.10, 0.82, depth01));
	color += caustic_color.rgb * caus * 0.20 * caustic_strength * detail;

	// Drifting bands make the motion legible even on a still screenshot.
	float band_a = sin(world_pos.x * 2.4 + world_pos.z * 1.4 + TIME * 1.15 + fbm(p * 0.55) * 3.0);
	float band_b = sin(world_pos.x * 1.3 - world_pos.z * 2.8 - TIME * 0.95 + fbm(p * 0.42 + 9.0) * 3.0);
	float bands = smoothstep(0.86, 0.99, band_a) * 0.65 + smoothstep(0.91, 0.995, band_b) * 0.35;
	color += vec3(0.20, 0.42, 0.45) * bands * 0.09 * detail;

	float sparkle = pow(smoothstep(0.66, 0.94, h), 5.0) * glint;
	color += glint_color.rgb * sparkle * 0.24;
	float sheen = smoothstep(0.58, 0.86, h) * 0.06 * detail;
	color += glint_color.rgb * sheen;

	ALBEDO = color;
	ROUGHNESS = mix(0.16, 0.055, detail);
	METALLIC = 0.0;
	SPECULAR = 0.58;
}
