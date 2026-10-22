shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D painted_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 painted_rect=vec4(0.0,0.0,1.0,1.0);
uniform bool soft_layer=false;
uniform float dissolve=0.0;
uniform float visible_v_min=0.0;
uniform float visible_v_max=1.0;
uniform float coverage_power=1.0;
varying vec4 pigment;
void vertex(){pigment=COLOR;}
void fragment(){
 vec2 p=clamp(UV,vec2(.001),vec2(.999));
 vec4 art=texture(painted_texture,painted_rect.xy+p*painted_rect.zw);
 float erosion=smoothstep(.0,1.0,dissolve)*.65;
 float breakup=art.a*.78+.22*(.5+.5*sin(p.x*7.0-p.y*4.0));
 float alpha=pow(art.a,coverage_power)*pigment.a*smoothstep(erosion,erosion+.15,breakup);
 alpha*=smoothstep(visible_v_min-.003,visible_v_min+.003,UV.y)*(1.0-smoothstep(visible_v_max-.003,visible_v_max+.003,UV.y));
 if(alpha<.003)discard;
 float luminance=dot(art.rgb,vec3(.2126,.7152,.0722));
 ALBEDO=art.rgb;
 EMISSION=art.rgb*(soft_layer ? .015 : .06+.22*smoothstep(.65,.98,luminance));
 ALPHA=clamp(alpha,0.0,1.0);
}
