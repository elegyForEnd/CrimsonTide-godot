shader_type canvas_item;
render_mode unshaded, blend_add;
varying vec4 draw_tint;
void vertex() { draw_tint = COLOR; }
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 step_uv = max(TEXTURE_PIXEL_SIZE * 24.0, fwidth(UV) * 3.5);
	float halo = art.a * 0.20;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		vec2 offset = vec2(cos(angle), sin(angle)) * step_uv;
		halo += texture(TEXTURE, UV + offset).a * 0.14;
	}
	float hot = art.a * smoothstep(0.68, 0.98, max(art.r, max(art.g, art.b)));
	vec3 light_color = mix(draw_tint.rgb, vec3(1.9), hot * 0.10);
	COLOR = vec4(light_color, (halo + hot * 0.50) * draw_tint.a);
}
