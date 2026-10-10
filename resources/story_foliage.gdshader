shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
instance uniform float reveal=1.0;
void vertex() {
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float sway=sin(TIME*1.45+world_pos.x*1.7+world_pos.z*.9);
 VERTEX.x+=sway*.022*max(VERTEX.y,0.0);
}
void fragment() {
 if(fract(52.9829189*fract(dot(floor(FRAGCOORD.xy),vec2(.06711056,.00583715))))>reveal) discard;
 float variation=sin(world_pos.x*5.7+world_pos.z*3.4)*.5+.5;
 ALBEDO=mix(vec3(.12,.17,.095),vec3(.29,.32,.18),variation);
 ROUGHNESS=.94;
}
