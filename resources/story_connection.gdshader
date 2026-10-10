shader_type spatial;
uniform sampler2D from_ground_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D from_road_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D from_ground_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D from_road_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D from_ground_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D from_road_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D to_ground_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D to_road_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D to_ground_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D to_road_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D to_ground_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D to_road_orm : filter_linear_mipmap, repeat_enable;
uniform vec4 from_earth : source_color;
uniform vec4 from_road : source_color;
uniform vec4 to_earth : source_color;
uniform vec4 to_road : source_color;
uniform float from_paving=0.0;
uniform float to_paving=0.0;
uniform vec2 start;
uniform vec2 finish;
uniform bool stone_bridge=false;
varying vec3 world_pos;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; TANGENT=vec3(1,0,0); BINORMAL=vec3(0,0,1); }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 vec2 p=world_pos.xz;
 vec2 direction=finish-start;
 float t=clamp(dot(p-start,direction)/max(dot(direction,direction),.01),0.,1.);
 float blend=smoothstep(.04,.96,t);
 float variation=noise(p*.32)*.6+noise(p*2.1)*.3+noise(p*10.)*.1;
 float path=smoothstep(.12,.83,COLOR.a+(noise(p*2.)-.5)*.20);
 float a=max(from_paving,path), b=max(to_paving,path);
 vec3 first=mix(texture(from_ground_tex,p*.22).rgb*from_earth.rgb,texture(from_road_tex,p*.35).rgb*from_road.rgb,a);
 vec3 last=mix(texture(to_ground_tex,p*.22).rgb*to_earth.rgb,texture(to_road_tex,p*.35).rgb*to_road.rgb,b);
 ALBEDO=mix(first,last,blend)*(.88+variation*.19);
 if(stone_bridge) {
  float bridge=smoothstep(.0,.12,t)*(1.-smoothstep(.88,1.,t));
  ALBEDO=mix(ALBEDO,texture(from_road_tex,p*.35).rgb*from_road.rgb*(.88+variation*.19),bridge);
 }
 vec3 orm=mix(mix(texture(from_ground_orm,p*.22).rgb,texture(from_road_orm,p*.35).rgb,a),mix(texture(to_ground_orm,p*.22).rgb,texture(to_road_orm,p*.35).rgb,b),blend);
 NORMAL_MAP=mix(mix(texture(from_ground_normal,p*.22).rgb,texture(from_road_normal,p*.35).rgb,a),mix(texture(to_ground_normal,p*.22).rgb,texture(to_road_normal,p*.35).rgb,b),blend);
 NORMAL_MAP_DEPTH=.62;
 float wet=smoothstep(.68,.93,noise(p*.48))*smoothstep(.3,.8,path);
 ALBEDO*=1.-wet*.18;
 ROUGHNESS=clamp(orm.g*.97-wet*.36,.26,.98); AO=orm.r;
}
