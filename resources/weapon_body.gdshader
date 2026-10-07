shader_type canvas_item;
render_mode unshaded, blend_mix;
varying vec4 draw_tint;
// Screen pixels keep the stroke substantial even when a large source is minified.
uniform float stroke_pixels = 1.8;
void vertex() { draw_tint = COLOR; }
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 footprint = fwidth(UV) * stroke_pixels;
	vec4 body = art;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		vec2 offset = vec2(cos(angle), sin(angle)) * footprint;
		vec4 edge = texture(TEXTURE, UV + offset);
		if (edge.a > body.a) { body = edge; }
	}
	for (int i = 0; i < 4; i++) {
		float angle = float(i) * 1.570796;
		vec4 edge = texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * footprint * 0.5);
		if (edge.a > body.a) { body = edge; }
	}
	COLOR = vec4(body.rgb * draw_tint.rgb, body.a * draw_tint.a);
}
