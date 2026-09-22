shader_type canvas_item;
render_mode blend_add, unshaded;

void fragment() {
	// Soft tile boundaries suppress the hard rectangles of packed glow art.
	vec2 tile_uv = fract(UV * 3.0);
	vec2 edge_distance = min(tile_uv, 1.0 - tile_uv);
	float feather = smoothstep(0.0, 0.085, min(edge_distance.x, edge_distance.y));
	COLOR.rgb *= feather;
	COLOR.a *= feather;
}
