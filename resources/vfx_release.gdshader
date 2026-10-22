shader_type canvas_item;
render_mode unshaded, blend_mix;
#include "res://resources/vfx_release_mask.gdshaderinc"
uniform float effect_phase : hint_range(0.0,1.0) = 0.0;
varying vec4 draw_tint;
void vertex() { draw_tint=COLOR; }
void fragment() {
	vec4 art=texture(TEXTURE,UV);
	float core=smoothstep(0.72,0.97,min(art.r,min(art.g,art.b)));
	vec3 painted=mix(art.rgb*draw_tint.rgb,vec3(max(art.r,max(art.g,art.b))),core);
	COLOR=vec4(painted,art.a*draw_tint.a*release_mask(art,UV,effect_phase));
}
