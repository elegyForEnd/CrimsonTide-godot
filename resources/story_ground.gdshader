shader_type spatial;
render_mode specular_disabled;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D road_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 earth : source_color = vec4(0.32,0.35,0.29,1.0);
uniform vec4 road : source_color = vec4(0.38,0.34,0.27,1.0);
varying vec3 world_pos;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 vec2 p=world_pos.xz;
 float variation=noise(p*.32)*.6+noise(p*2.1)*.3+noise(p*10.0)*.1;
 float trail=smoothstep(.12,.83,COLOR.a+(noise(p*2.0)-.5)*.20);
 vec3 soil=texture(ground_tex,p*.22).rgb;
 vec3 track=texture(road_tex,p*.35).rgb;
 ALBEDO=mix(mix(earth.rgb,soil,.38),mix(road.rgb,track,.28),trail)*(.76+variation*.37);
 ROUGHNESS=.96;
}
