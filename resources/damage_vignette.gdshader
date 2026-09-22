shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// Keep the rim equally wide on every side, including ultrawide windows.
	vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 edge_distance = min(UV, vec2(1.0) - UV) * viewport_size;
	float distance_from_edge = min(edge_distance.x, edge_distance.y);
	float rim_width = min(viewport_size.x, viewport_size.y) * 0.22;
	float vignette = 1.0 - smoothstep(0.0, rim_width, distance_from_edge);
	COLOR.a *= vignette;
}
