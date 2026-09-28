shader_type canvas_item;
// Write straight alpha into the offscreen texture; the field composites it once.
render_mode unshaded, blend_disabled;

uniform vec2 world_origin;
uniform vec2 world_axis_x = vec2(1.0, 0.0);
uniform vec2 world_axis_y = vec2(0.0, 1.0);
uniform vec2 view_size = vec2(1440.0, 900.0);
uniform vec2 safe_center;
uniform float safe_radius = 540.0;
uniform float elapsed = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float cloud(vec2 p) {
	return noise(p) * 0.57 + noise(p * 2.03 + 17.1) * 0.29
		+ noise(p * 4.11 + 31.7) * 0.14;
}

void fragment() {
	vec2 world = world_origin + world_axis_x * UV.x * view_size.x + world_axis_y * UV.y * view_size.y;
	float distance_out = length(world - safe_center) - safe_radius;
	// World-space advection keeps the mist attached to the terrain while the camera moves.
	vec2 wind = vec2(elapsed * 0.025, -elapsed * 0.043);
	float broad = cloud(world * 0.004 + wind);
	vec2 warp = vec2(broad, cloud(world * 0.006 - wind)) * 2.4;
	float billow = cloud(world * 0.013 + warp + wind * 1.7);
	float fine = noise(world * 0.045 + warp - wind * 2.0);
	float tendrils = pow(1.0 - abs(2.0 * cloud(world * vec2(0.024, 0.009)
		+ warp * 1.8 + wind * 2.3) - 1.0), 6.0);
	float veil = smoothstep(-24.0, 160.0, distance_out + (broad - 0.5) * 64.0);
	float wall = exp(-pow((distance_out - 48.0 - (billow - 0.5) * 92.0) / 69.0, 2.0));
	float deep = smoothstep(65.0, 550.0, distance_out);
	float smoke = veil * (0.17 + 0.25 * broad + 0.15 * billow) + wall * billow * 0.34;
	vec3 shade = mix(vec3(0.075, 0.018, 0.042), vec3(0.34, 0.045, 0.075), billow);
	shade = mix(shade, vec3(0.095, 0.018, 0.038), deep * 0.52);
	// A soft, broken contact glow marks the exact damage boundary beneath the moving fog.
	float contact = exp(-abs(distance_out) / 5.0) * (0.35 + 0.65 * fine);
	float silver = pow(max(0.0, billow * 1.5 - 0.38), 3.0) * wall;
	shade += vec3(0.43, 0.08, 0.095) * wall * billow;
	shade += vec3(0.17, 0.055, 0.06) * wall * tendrils;
	shade += vec3(0.55, 0.22, 0.18) * silver;
	shade = mix(shade, vec3(0.85, 0.22, 0.18), contact * 0.7);
	// Sparse windborne embers, confined to the dangerous side of the boundary.
	vec2 dust = world / 74.0 + vec2(elapsed * 0.09, elapsed * 0.23);
	vec2 cell = floor(dust);
	float seed = hash(cell);
	vec2 spot = vec2(0.2 + seed * 0.6, 0.2 + hash(cell + 9.0) * 0.6);
	vec2 delta = (fract(dust) - spot) * vec2(1.0, 0.6);
	float ember = (1.0 - smoothstep(0.005, 0.037, length(delta)))
		* step(0.79, seed) * smoothstep(0.0, 45.0, distance_out)
		* (0.55 + 0.45 * sin(elapsed * 1.8 + seed * 40.0));
	shade = mix(shade, vec3(1.0, 0.45, 0.24), ember);
	float alpha = clamp(smoke + deep * 0.12 + contact * 0.22 + ember * 0.65, 0.0, 0.72);
	COLOR = vec4(shade, alpha);
}
