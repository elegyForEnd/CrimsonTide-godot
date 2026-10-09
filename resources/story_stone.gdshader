shader_type spatial;
render_mode specular_disabled, cull_disabled;
uniform vec4 stone : source_color = vec4(.32,.32,.34,1);
uniform bool wood=false;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,73.8)))*43758.5453); }
void fragment() {
 vec3 p=world_pos*3.0;
 float grain=hash(floor(p*18.0));
 vec2 wall=abs(world_normal.y)>.7 ? p.xz : vec2((abs(world_normal.x)>.5 ? p.z : p.x)+mod(floor(p.y),2.0)*.65,p.y);
 vec2 edge=abs(fract(wall/vec2(2.2,.8))-.5);
 float mortar=smoothstep(.455,.495,max(edge.x,edge.y));
 float band=wood ? .84+.15*sin(p.x*20.0+p.z*17.0) : mix(1.0,.54,mortar);
 ALBEDO=stone.rgb*band*(.80+grain*.3);
 ROUGHNESS=.94;
}
