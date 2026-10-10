shader_type fog;
uniform float density=.028;
void fog(){
 float edge=1.0-smoothstep(.15,.5,length(UVW.xz-.5));
 DENSITY=density*edge*(1.0-smoothstep(.1,.95,UVW.y));
 ALBEDO=vec3(.52,.61,.69);
}
