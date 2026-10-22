shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 frame_rects[4];
uniform vec2 frame_bounds[4];
uniform float phase=0.0;
uniform float reveal=1.0;
uniform float tail_start=0.0;
uniform float canvas_aspect=1.6;
uniform vec2 pivot=vec2(.2,.7);
uniform vec2 contact=vec2(.9,.9);
uniform int reveal_mode=0;
uniform float dissolve=0.0;
uniform float face_density=1.0;
uniform float coverage_power=1.0;
varying vec4 pigment;
void vertex(){pigment=COLOR;}
vec4 stage(int index,vec2 p){
 vec4 r=frame_rects[index];
 vec2 uv=r.xy+p*r.zw;
 vec2 limits=frame_bounds[index];
 if(uv.y<limits.x || uv.y>limits.y)return vec4(0.0);
 return texture(atlas,uv);
}
void fragment(){
 int a=int(clamp(floor(phase),0.0,3.0));
 int b=min(a+1,3);
 float f=fract(clamp(phase,0.0,3.0));
 vec4 x=stage(a,UV), y=stage(b,UV), peak=stage(1,UV);
 // One registered contour and one bright rim. Stage keys modulate density;
 // they never overlay two displaced luminous silhouettes.
 float density=mix(x.a,y.a,f);
 float opacity=peak.a;
 vec3 color=peak.rgb;
 if(phase<1.0){
  opacity*=mix(.72,1.0,phase);
 }else{
  float remaining=clamp(density/max(.035,peak.a),0.0,1.0);
  opacity*=mix(1.0,remaining,smoothstep(1.0,1.45,phase));
 }
 vec2 d=(UV-pivot)*vec2(1.0,1.0/canvas_aspect);
 float angle=atan(-d.y,d.x);
 float along=(1.90-angle)/2.15;
 if(reveal_mode!=0){
  vec2 end=(contact-pivot)*vec2(1.0,1.0/canvas_aspect);
  along=dot(d,end)/max(.001,dot(end,end));
  if(reveal_mode==3)along=length(d)/max(.001,length(end));
 }
 float leading=1.0-smoothstep(reveal-.025,reveal+.025,along);
 float trailing=smoothstep(tail_start-.05,tail_start+.05,along);
 float alpha=pow(opacity,coverage_power)*pigment.a*leading*trailing;
 // Continuous loss of pigment also animates a single painted peak source.
 alpha*=1.0-smoothstep(1.0,3.0,phase)*.78;
 if(alpha<.003)discard;
 float light=dot(color,vec3(.2126,.7152,.0722));
 alpha*=mix(face_density,1.0,smoothstep(.72,.97,light));
 ALBEDO=color;
 EMISSION=color*(.06+.20*smoothstep(.65,.98,light));
 ALPHA=clamp(alpha,0.0,1.0);
}
