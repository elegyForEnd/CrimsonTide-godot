shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float phase=0.0;
uniform float flow=0.7;
uniform float shear=0.2;
// UV.x follows emitted history; UV.y crosses the strip. Geometry supplies
// lifetime alpha, so detached portions can die independently of the head.
void fragment(){
 vec2 p=UV;
 float cross_band=pow(max(0.0,sin(p.y*3.14159265)),1.5);
 float fold=sin(p.x*17.0-phase*flow*7.0+p.y*shear*9.0)*0.5+0.5;
 float silk=0.5+0.26*fold+0.24*sin(p.y*28.0+p.x*8.0-phase*flow*4.0);
 float core=pow(max(0.0,1.0-abs(p.y-0.28)*13.0),3.0);
 COLOR.rgb=mix(COLOR.rgb,COLOR.rgb*0.45+vec3(0.55),core*0.65);
 COLOR.a*=cross_band*silk;
}
