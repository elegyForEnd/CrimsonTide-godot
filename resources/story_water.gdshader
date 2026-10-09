shader_type spatial;
render_mode specular_disabled, cull_disabled;
varying vec3 world_pos;
uniform vec4 water_tint : source_color = vec4(.12,.23,.25,1.0);
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_pos.xz;
 float waves=sin(p.x*4.0+TIME*.7+sin(p.y*2.5))*sin(p.y*3.0-TIME*.4);
 float streak=pow(max(0.0,sin(p.x*2.0+p.y*4.0+TIME*.5)),12.0);
 ALBEDO=water_tint.rgb+vec3(.022,.027,.026)*waves+vec3(.035)*streak;
 ROUGHNESS=.52;
 NORMAL_MAP=normalize(vec3(waves*.07,streak*.08,1.0))*.5+.5;
}
