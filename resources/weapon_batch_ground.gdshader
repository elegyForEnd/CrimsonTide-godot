shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
varying vec4 pigment;
void vertex(){pigment=COLOR;}
void fragment(){
 ALBEDO=pigment.rgb;
 EMISSION=pigment.rgb*.28;
 ALPHA=pigment.a;
}
