shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D identity_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D painted_detail : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 identity_rect=vec4(0.0,0.0,1.0,1.0);
uniform vec4 detail_rect=vec4(0.0,0.0,1.0,1.0);
uniform bool ribbon_mode=true;
uniform bool solid_mode=false;
uniform float phase=0.0;
uniform float wake_opacity=1.0;
uniform float energy_gain=1.0;
varying vec4 pigment;
void vertex(){pigment=COLOR;}
void fragment(){
 vec2 p=clamp(UV,vec2(.001),vec2(.999));
 vec4 identity=texture(identity_texture,identity_rect.xy+p*identity_rect.zw);
 vec4 detail=texture(painted_detail,detail_rect.xy+p*detail_rect.zw);
 float structure=dot(identity.rgb,vec3(.2126,.7152,.0722));
 float alpha=pigment.a*wake_opacity;
 vec3 color;
 if(solid_mode){
  // Faceted rocks, arrow shafts and metal penetrators keep their real outline.
  color=pigment.rgb*(.66+structure*.55);
  float vein=pow(max(0.0,dot(detail.rgb,vec3(.33))-.45),2.0);
  color+=detail.rgb*vein*.18;
 }else{
  float coverage=pow(detail.a,.53)*smoothstep(.008,.05,detail.a);
  coverage*=mix(.68,1.0,identity.a);
  alpha*=clamp(coverage*1.45,0.0,1.0);
  // Painted color is the main surface, not a faint wash over a grey mask.
  color=mix(pigment.rgb*(.32+structure*.70),detail.rgb*(.92+structure*.35),.92);
  color*=1.15;
  if(ribbon_mode){
   alpha*=smoothstep(.0,.014,p.x)*(1.0-smoothstep(.987,1.0,p.x));
   float ridge=exp(-pow((p.y-.80-.035*sin(p.x*17.0))*38.0,2.0));
   color+=mix(pigment.rgb,vec3(1.0),.50)*ridge*.14;
  }
 }
 if(alpha<.004)discard;
 ALBEDO=color;
 EMISSION=color*energy_gain*(solid_mode ? .10 : .34);
 ALPHA=clamp(alpha,0.0,1.0);
}
