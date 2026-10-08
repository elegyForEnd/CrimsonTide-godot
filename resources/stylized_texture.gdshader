shader_type canvas_item;
render_mode unshaded, blend_mix;
varying vec4 draw_tint;
void vertex() { draw_tint = COLOR; }
float grain(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	// Native ink remains clean throughout its reveal and fade.
	// Saturated weapon rims retain a neutral painted highlight, without HDR clipping.
	float core = smoothstep(0.72, 0.97, min(art.r, min(art.g, art.b)));
	vec3 painted = mix(art.rgb * draw_tint.rgb, vec3(max(art.r, max(art.g, art.b))), core);
	COLOR = vec4(painted, art.a * draw_tint.a);
}
