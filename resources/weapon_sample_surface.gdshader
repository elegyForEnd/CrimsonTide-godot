shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform int surface_kind=0; // 0 blood sheet; 1 pigment/edge; 2 suspended dust
uniform float phase=0.0;
varying vec4 tint;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){tint=COLOR;}
void fragment(){
 vec2 p=UV; float a=tint.a; vec3 c=tint.rgb;
 if(surface_kind==0){
  float n=noise(vec2(p.x*26.0-phase*.8,p.y*9.0));
  float fine=noise(vec2(p.x*74.0+p.y*8.0,p.y*18.0));
  float fold=pow(.5+.5*sin(p.y*29.0+p.x*17.0+n*3.0),5.0);
  float vein=pow(.5+.5*sin(p.x*73.0+p.y*23.0+n*6.0),22.0);
  c=mix(vec3(.15,.002,.019),vec3(.94,.014,.065),p.y*.55+fold*.35+n*.18);
  c+=vec3(.45,.035,.055)*vein*.42;
  float wet=exp(-pow((p.y-.77-.065*sin(p.x*17.0+n*2.0))*23.0,2.0));
  c+=vec3(.60,.14,.18)*wet*(.25+.75*noise(vec2(p.x*11.0,p.y*3.0)));
  float rim=exp(-pow((p.y-.96)*54.0,2.0));
  c=mix(c,vec3(1.0,.64,.66),rim*.95);
  a*=smoothstep(.0,.10,p.y)*(.82+.18*fine);
  a*=1.0-smoothstep(.93+n*.065,1.0,p.y);
 }else if(surface_kind==3){
  float broad=noise(p*5.0); float grain=noise(p*48.0);
  float fracture=abs(noise(p*11.0)-.48);
  c*=.70+broad*.36+grain*.045;
  c*=mix(.42,1.0,smoothstep(.006,.023,fracture));
  c+=vec3(.13,.045,.012)*pow(1.0-smoothstep(.0,.025,fracture),2.0)*.60;
 }else if(surface_kind==5){
  float n=noise(vec2(p.x*7.0,p.y*5.0-phase*2.5));
  float detail=noise(vec2(p.x*19.0+p.y*3.0,p.y*13.0-phase*4.0));
  float radius=abs(p.x-.5)*2.0;
  float boundary=pow(max(0.0,sin(p.y*3.14159)),.60)*(.68+n*.30);
  a*=1.0-smoothstep(boundary-.12,boundary+.04,radius);
  a*=smoothstep(.0,.06,p.y)*(1.0-smoothstep(.72,1.0,p.y));
  float fire=clamp((1.0-p.y)*1.35+n*.40-.40,0.0,1.0);
  c=mix(vec3(.17,.12,.10),vec3(.95,.20,.012),fire);
  c=mix(c,vec3(1.0,.69,.18),pow(fire,4.0)*detail);
  a*=.40+n*.35+fire*.20;
 }else if(surface_kind==4){
  float n=noise(vec2(p.x*13.0-phase*5.0,p.y*4.0));
  float center=pow(1.0-abs(p.y-.5)*2.0,2.0);
  c=mix(vec3(.23,.025,.006),vec3(.98,.29,.028),center*.70+n*.32);
  c=mix(c,vec3(1.0,.73,.29),pow(center,5.0)*.52);
  a*=smoothstep(.0,.09,p.y)*(1.0-smoothstep(.91,1.0,p.y))*(.84+.16*n);
 }else if(surface_kind==2){
  vec2 q=p*2.0-1.0;
  float n=noise(p*5.0+vec2(-phase*.3,phase*.1));
  a*=(1.0-smoothstep(.10,1.0,length(q)))*(.45+.55*n);
  c*=.78+n*.27;
 }else{c*=.90+.10*noise(p*23.0);}
 if(a<.004)discard;
 ALBEDO=c; EMISSION=c*.24; ALPHA=clamp(a,0.0,1.0);
}
