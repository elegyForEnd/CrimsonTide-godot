shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
varying vec4 pigment;
void vertex(){pigment=COLOR;}
void fragment(){
 vec2 p=UV*2.0-1.0;
 float soft=exp(-dot(p,p)*4.5)*(1.0-smoothstep(.55,1.0,dot(p,p)));
 ALBEDO=pigment.rgb; ALPHA=pigment.a*soft;
}
