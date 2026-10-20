shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D painted_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 painted_rect=vec4(0.0,0.0,1.0,1.0);
uniform vec3 retint_color : source_color=vec3(1.0);
uniform float retint_amount=0.0;
uniform bool ribbon_mode=true;
uniform float phase=0.0;
varying vec4 pigment;
void vertex(){pigment=COLOR;}
void fragment(){
 vec4 art=texture(painted_texture,painted_rect.xy+UV*painted_rect.zw);
 // Preserve transparent padding, but stop mid-opacity paint from disappearing
 // when the large source texture is reduced to a few pixels in the game.
 float coverage=pow(art.a,ribbon_mode ? .57 : .76)*smoothstep(.008,.05,art.a);
 float alpha=clamp(coverage*1.20,0.0,1.0)*pigment.a;
 if(ribbon_mode){
  // Geometry reveals the unwrapped material as the blade moves; no sliding screenshot.
  alpha*=smoothstep(.0,.025,UV.x)*(1.0-smoothstep(.975,1.0,UV.x));
 }
 if(alpha<.004)discard;
 float luminance=dot(art.rgb,vec3(.2126,.7152,.0722));
 vec3 color=max(vec3(0.0),mix(vec3(luminance),art.rgb,1.18));
 color=mix(color,vec3(luminance)*retint_color*1.4,retint_amount);
 ALBEDO=color*1.28;
 // Highlights carry the energy; dark reflected facets remain legible.
 EMISSION=color*(.30+.26*smoothstep(.28,.80,luminance));
 ALPHA=clamp(alpha,0.0,1.0);
}
