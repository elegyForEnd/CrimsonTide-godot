shader_type canvas_item;
render_mode unshaded, blend_mix;
varying vec4 draw_tint;
void vertex() { draw_tint = COLOR; }
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	// The caster stands just above the captured ground origin. Fade only that
	// small region so the original outer stone/lava silhouette stays readable.
	vec2 local = (UV - vec2(0.5, 0.38)) / vec2(0.14, 0.28);
	float clearance = smoothstep(0.55, 1.0, length(local));
	COLOR = vec4(art.rgb * draw_tint.rgb, art.a * draw_tint.a * clearance);
}
