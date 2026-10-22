shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D density : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 density_rect=vec4(0.0,0.0,1.0,1.0);
uniform float phase=0.0;
varying vec4 pigment;
void vertex(){pigment=COLOR;}
void fragment(){
 vec2 p=clamp(UV,vec2(.001),vec2(.999));
 vec4 sample_color=texture(density,density_rect.xy+p*density_rect.zw);
 float cloud=sample_color.a*dot(sample_color.rgb,vec3(.3333));
 float alpha=pow(cloud,.75)*pigment.a;
 if(alpha<.003)discard;
 ALBEDO=pigment.rgb*(.70+sample_color.r*.35);
 ALPHA=clamp(alpha,0.0,.65);
}
