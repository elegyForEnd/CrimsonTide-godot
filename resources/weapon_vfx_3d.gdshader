shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform float phase=0.0;
uniform float flow=0.7;
uniform float shear=0.2;
uniform float edge=0.85;
uniform int material_kind=0;
uniform sampler2D flow_texture:filter_linear,repeat_disable;
uniform vec4 flow_rect=vec4(0.0,0.0,1.0,1.0);
uniform bool flow_vertical=false;
uniform float flow_repeat=1.0;
uniform float dissolve=0.0;
uniform sampler2D blade_texture:filter_linear,repeat_disable;
uniform vec4 blade_rect=vec4(0.0,0.0,1.0,1.0);
varying float textured_body;
void vertex(){ textured_body=UV2.x; }
void fragment(){
 float v=clamp(UV.y,0.0,1.0);
 float soft=pow(max(0.0,sin(v*3.14159265)),1.4);
 float fold=sin(UV.x*15.0-phase*flow*6.0+v*shear*11.0);
 float striation=0.88+0.08*fold+0.04*sin(v*24.0+UV.x*9.0-phase*flow*3.0);
 float core=pow(max(0.0,1.0-abs(v-.27)*9.0),1.4)*edge;
 float painted_light=0.0;
 if(material_kind==1) striation*=.72+.28*step(.15,sin(UV.x*38.0+v*2.0));
 if(material_kind==2) core+=pow(max(0.0,1.0-abs(v-.66)*22.0),3.0)*.6;
 // Only the moving ribbon samples the flow painting. Charge sparks, rock
 // fragments and signature contours retain their crisp geometry (UV2.x=0).
 if(textured_body>.5){
  float travel=UV.x*flow_repeat-phase*flow*.28;
  float segment=fract(travel);
  // Mirrored transport avoids a hard seam when the original is not tileable.
  float along=1.0-abs(segment*2.0-1.0);
  vec2 p=vec2(along,clamp(v+fold*shear*.025,0.0,1.0));
  if(flow_vertical) p=vec2(p.y,1.0-p.x);
  vec3 field=texture(flow_texture,flow_rect.xy+p*flow_rect.zw).rgb;
  float density=dot(field,vec3(.299,.587,.114));
  float coverage=smoothstep(dissolve*.64-.12,dissolve*.64+.20,density);
  striation*=mix(.52,1.12,sqrt(max(density,0.0)))*mix(1.0,coverage,dissolve);
  soft*=1.0-dissolve*.45*(1.0-density);
  // The RGBA blade painting owns the visible silhouette and broad brushwork.
  // Its empty spaces must stay empty, even under the procedural bright core.
  vec2 blade_uv=vec2(clamp(UV.x,0.0,1.0),1.0-v);
  blade_uv.y=clamp(blade_uv.y+sin(UV.x*7.0-phase*flow)*shear*.012,0.0,1.0);
  vec4 blade=texture(blade_texture,blade_rect.xy+blade_uv*blade_rect.zw);
  painted_light=dot(blade.rgb,vec3(.299,.587,.114));
  soft=blade.a;
  // Keep the gray membrane readable at gameplay size without filling the
  // alpha cutouts or whitening the entire painted cutting edge.
  striation=(.30+.76*sqrt(max(painted_light,0.0)))*mix(1.0,coverage,dissolve);
  core=smoothstep(.76,1.0,painted_light)*edge*.42;
 }
 vec3 pigment=mix(COLOR.rgb,vec3(1.0),core*.78);
 ALBEDO=pigment;
 EMISSION=pigment*(textured_body>.5 ? .45+painted_light*.55 : 1.05+core*1.8);
 ALPHA=clamp(COLOR.a*soft*striation*(1.0+core*.7),0.0,1.0);
}
