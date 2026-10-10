shader_type spatial;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D road_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D road_orm : filter_linear_mipmap, repeat_enable;
uniform bool use_pbr = false;
uniform float paving = 0.0;
uniform vec4 earth : source_color = vec4(0.32,0.35,0.29,1.0);
uniform vec4 road : source_color = vec4(0.38,0.34,0.27,1.0);
varying vec3 world_pos;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; TANGENT=vec3(1.0,0.0,0.0); BINORMAL=vec3(0.0,0.0,1.0); }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 vec2 p=world_pos.xz;
 float variation=noise(p*.32)*.6+noise(p*2.1)*.3+noise(p*10.0)*.1;
 float trail=max(paving,smoothstep(.12,.83,COLOR.a+(noise(p*2.0)-.5)*.20));
 vec3 soil=texture(ground_tex,p*.22).rgb;
 vec3 track=texture(road_tex,p*.35).rgb;
 if(use_pbr) {
  ALBEDO=mix(soil*earth.rgb,track*road.rgb,trail)*(.88+variation*.19);
  vec3 orm=mix(texture(ground_orm,p*.22).rgb,texture(road_orm,p*.35).rgb,trail);
  NORMAL_MAP=mix(texture(ground_normal,p*.22).rgb,texture(road_normal,p*.35).rgb,trail);
  NORMAL_MAP_DEPTH=.62;
  float wet=smoothstep(.68,.93,noise(p*.48))*smoothstep(.3,.8,trail);
  ALBEDO*=1.0-wet*.18;
  ROUGHNESS=clamp(orm.g*.97-wet*.36,.26,.98); AO=orm.r;
 } else {
  ALBEDO=mix(mix(earth.rgb,soil,.38),mix(road.rgb,track,.28),trail)*(.76+variation*.37);
  ROUGHNESS=.96;
 }
}
