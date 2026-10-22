shader_type canvas_item;
render_mode unshaded, blend_add;
#include "res://resources/vfx_release_mask.gdshaderinc"
uniform float effect_phase : hint_range(0.0,1.0) = 0.0;
varying vec4 draw_tint;
void vertex() { draw_tint=COLOR; }
void fragment() {
	vec4 art=texture(TEXTURE,UV);
	float retained=release_mask(art,UV,effect_phase);
	vec2 step_uv=max(TEXTURE_PIXEL_SIZE*24.0,fwidth(UV)*3.5);
	float halo=art.a*retained*0.20;
	for (int i=0;i<8;i++) {
		float angle=float(i)*0.785398;
		vec2 sample_uv=UV+vec2(cos(angle),sin(angle))*step_uv;
		vec4 nearby=texture(TEXTURE,sample_uv);
		halo+=nearby.a*release_mask(nearby,sample_uv,effect_phase)*0.14;
	}
	float hot=art.a*retained*smoothstep(0.68,0.98,max(art.r,max(art.g,art.b)));
	vec3 light_color=mix(draw_tint.rgb,vec3(1.9),hot*0.10);
	COLOR=vec4(light_color,(halo+hot*0.50)*draw_tint.a);
}
