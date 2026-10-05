shader_type canvas_item;
render_mode unshaded, blend_add;
varying float core;
uniform vec4 inherited_tint = vec4(1.0);
void vertex() {
	core = UV.x;
	float size = INSTANCE_CUSTOM.x;
	VERTEX *= mix(size * 1.8, max(0.5, size * 0.25), core);
}
void fragment() {
	COLOR = vec4(mix(COLOR.rgb, inherited_tint.rgb, core), COLOR.a * mix(0.025, 0.08, core));
}
