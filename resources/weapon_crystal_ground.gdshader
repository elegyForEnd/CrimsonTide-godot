shader_type canvas_item;
render_mode blend_add, unshaded;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float r=dot(p,p);
 float light=exp(-r*4.5)*(1.0-smoothstep(.70,1.0,r));
 COLOR=vec4(COLOR.rgb,COLOR.a*light);
}
