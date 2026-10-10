shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 float radius=length((UV-.5)*2.0);
 ALBEDO=vec3(.025,.032,.052);
 ALPHA=(1.0-smoothstep(.05,1.0,radius))*.32;
}
