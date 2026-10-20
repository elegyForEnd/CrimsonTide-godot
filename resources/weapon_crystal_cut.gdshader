shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform bool ribbon_mode=true;
uniform float phase=0.0;
varying vec4 pigment;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){pigment=COLOR;}
void fragment(){
 vec3 c=pigment.rgb;
 float alpha=pigment.a;
 if(ribbon_mode){
  float v=UV.y;
  float line=exp(-pow((v-.84)*32.0,2.0));
  float silk=.5+.5*sin(UV.x*21.0+v*16.0-phase*2.0);
  c=mix(c*vec3(.52,.32,.48),c, .35+v*.40+silk*.13);
  float cell=floor(UV.x*17.0+v*1.8);
  float facet=fract(sin(cell*127.1)*43758.5453);
  float diagonal=fract(UV.x*17.0+v*1.8);
  c=mix(c*.38,c*1.12,step(.48,diagonal+v*.36));
  c=mix(c,vec3(.97,.77,.87),step(.79,facet)*step(.55,v)*.58);
  c=mix(c,vec3(1.0,.87,.93),line*.90);
  alpha*=smoothstep(.0,.12,v)*(1.0-smoothstep(.94,1.0,v));
 }else{
  float reflection=noise(UV*5.0+vec2(phase*.12,-phase*.15));
  c*=.65+reflection*.42;
  float reflected_edge=exp(-pow((UV.x+UV.y*.34-.68)*35.0,2.0));
  c=mix(c,vec3(.99,.84,.92),reflected_edge*.34);
 }
 if(alpha<.004)discard;
 ALBEDO=c; EMISSION=c*.42; ALPHA=alpha;
}
