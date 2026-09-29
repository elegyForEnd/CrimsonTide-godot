shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;
// The initial camp's sky. One inverted dome carries the whole thunderhead:
// layered rolling cloud, the blood moon low on the horizon, and the flash
// term the storm drives so a strike lights the cloud deck from inside.

uniform vec3 horizon : source_color = vec3(0.055, 0.075, 0.125);
uniform vec3 zenith : source_color = vec3(0.008, 0.013, 0.028);
uniform vec3 cloud_dark : source_color = vec3(0.030, 0.038, 0.062);
uniform vec3 cloud_lit : source_color = vec3(0.30, 0.35, 0.49);
uniform vec3 flash_color : source_color = vec3(0.88, 0.94, 1.0);
uniform vec3 moon_direction = vec3(0.36, 0.16, 0.92);
uniform vec3 moon_color : source_color = vec3(0.86, 0.24, 0.30);
uniform float moon_size : hint_range(0.9, 0.999) = 0.988;
uniform float moon_glow : hint_range(0.0, 4.0) = 1.2;
uniform float coverage : hint_range(0.0, 1.0) = 0.66;
uniform float speed : hint_range(0.0, 1.0) = 0.035;
uniform float flash : hint_range(0.0, 3.0) = 0.0;
uniform float flash_bias = 0.0;
uniform float bolt_seed = 0.0;
uniform float time_scale = 1.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
	               mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
	               mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float total = 0.0;
	float amplitude = 0.56;
	for (int i = 0; i < 5; i++) {
		total += noise(p) * amplitude;
		p = p * 2.03 + vec3(11.3, 7.7, 3.1);
		amplitude *= 0.49;
	}
	return total;
}

void fragment() {
	vec3 dir = normalize(-VIEW);
	float drift = TIME * speed * time_scale;
	// Flatten the lookup so the cloud deck reads as a heavy ceiling, not a ball.
	vec3 sample_point = vec3(dir.x, max(dir.y, 0.02) * 1.9 + 0.12, dir.z) * 2.4;
	sample_point.xz += drift * vec2(1.0, 0.42);
	float base = fbm(sample_point);
	float detail = fbm(sample_point * 3.1 + vec3(drift * 2.2, 0.0, -drift * 1.4));
	float density = base * 0.74 + detail * 0.26;

	// The flash bias lets a nearby strike ignite only its own quarter of the sky.
	float seed_shift = hash(vec3(floor(bolt_seed * 7.0), 1.0, 2.0)) * 6.283;
	float sector = 0.5 + 0.5 * cos(atan(dir.z, dir.x) - seed_shift);
	float ignition = clamp(flash * (0.35 + 0.65 * sector) + flash_bias, 0.0, 3.0);

	float sky_height = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 sky = mix(horizon, zenith, pow(sky_height, 0.62));

	float cloud = smoothstep(coverage, coverage + 0.52, density + ignition * 0.30);
	vec3 cloud_color = mix(cloud_dark, cloud_lit, clamp(density * 0.55 + ignition * 0.95, 0.0, 1.6));
	// Underside of the deck catches the released charge first.
	cloud_color += flash_color * ignition * (0.30 + 0.70 * (1.0 - sky_height)) * (0.35 + 0.65 * density);

	vec3 color = mix(sky, cloud_color, cloud);

	// Blood moon: the one warm light this map allows.
	float moon = dot(dir, normalize(moon_direction));
	float disc = smoothstep(moon_size, moon_size + 0.0016, moon);
	float halo = pow(max(moon, 0.0), 220.0) * moon_glow;
	color += moon_color * (disc * 1.35 + halo * 0.30);
	// Clouds eat the moon instead of sitting behind it.
	color = mix(color, cloud_color, cloud * (1.0 - disc) * 0.85);

	// Storm drizzle haze right above the horizon line.
	color += horizon * smoothstep(0.18, -0.06, dir.y) * 0.22;
	ALBEDO = color;
	EMISSION = color * (0.22 + ignition * 0.55);
}
