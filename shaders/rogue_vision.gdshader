shader_type canvas_item;
render_mode unshaded;
uniform vec2 viewport_size = vec2(1440.0, 900.0);
uniform vec2 focus = vec2(720.0, 450.0);
uniform float radius = 420.0;
void fragment() {
	vec2 pixel = UV * viewport_size;
	float fog = smoothstep(radius - 65.0, radius + 65.0, length(pixel - focus));
	// Preserve the HUD strips above and below the playfield.
	float world_band = step(112.0, pixel.y) * (1.0 - step(776.0, pixel.y));
	COLOR = vec4(0.025, 0.015, 0.055, fog * 0.94 * world_band);
}
