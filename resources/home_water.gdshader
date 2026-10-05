shader_type spatial;
render_mode cull_disabled;
uniform vec4 water_color : source_color = vec4(0.08, 0.32, 0.36, 1.0);
void vertex() {
	VERTEX.y += sin(VERTEX.x * 2.0 + TIME * 1.3) * 0.025 + cos(VERTEX.z * 2.5 + TIME) * 0.018;
}
void fragment() {
	float ripple = sin(UV.x * 32.0 + TIME * 0.45 + sin(UV.y * 21.0 + TIME * 0.3) * 1.5);
	ALBEDO = water_color.rgb + vec3(0.012, 0.018, 0.025) * smoothstep(0.93, 1.0, ripple);
	ROUGHNESS = 0.42;
	METALLIC = 0.08;
	EMISSION = vec3(0.003, 0.006, 0.010) * smoothstep(0.97, 1.0, ripple);
}
