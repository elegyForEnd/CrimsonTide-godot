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
	COLOR = vec4(art.rgb * draw_tint.rgb, art.a * draw_tint.a);
}
