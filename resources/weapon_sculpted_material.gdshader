shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
// Shared material vocabulary. There are deliberately no image samplers here.
uniform int substance=0;
uniform bool ribbon_mode=true;
uniform float phase=0.0;
uniform float wake_opacity=1.0;
uniform float softness=.12;
varying vec4 tint;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fibers(vec2 p){return noise(p)*.57+noise(p*2.13+vec2(3.1,7.4))*.28+noise(p*4.37)*.15;}
void vertex(){tint=COLOR;}
void fragment(){
 float u=UV.x,v=UV.y;
 float field=fibers(vec2(u*12.0-phase*.7,v*5.0));
 float alpha=tint.a*wake_opacity;
 vec3 pigment=tint.rgb;
 if(ribbon_mode){
  float across=abs(v-.5)*2.0;
  float contour=1.0-smoothstep(1.0-softness,1.0,across);
  float edge=exp(-pow((v-.94)*38.0,2.0));
  float fold=.22+.44*v+field*.12;
  if(substance==1 || substance==2 || substance==7 || substance==8 || substance==10){
   contour*=1.0-smoothstep(.82+field*.16,1.0,across);
   fold+=sin(u*14.0+v*11.0-phase*1.6)*.08;
   contour*=smoothstep(.01,.17,v)*(.68+.32*field);
  }
  if(substance==3 || substance==9){
   float facet=hash(floor(vec2(u*11.0+v*2.0,v*4.0)));
   fold=.35+facet*.40;
   contour*=mix(.45,1.0,step(.10,facet));
  }
  if(substance==4){fold=.8;edge*=.40;contour*=.75+.25*sin(u*37.0-phase*5.0);}
  if(substance==5){fold=.25+field*.30;edge*=.12;}
  if(substance==6){fold=.35+field*.40;edge*=field;contour*=smoothstep(.1,.4,field+.40-across*.25);}
  if(substance==7 || substance==8){contour*=.35+field*.65;edge*=.30;}
  pigment=tint.rgb*fold;
  if(substance==1){
   float vein=pow(max(0.0,sin(u*29.0+v*7.0+field*4.0-phase*.8)),18.0);
   pigment=mix(tint.rgb*vec3(.42,.10,.16),tint.rgb,clamp(v*.70+vein*.22,0.0,1.0));
   pigment+=tint.rgb*vein*.28*smoothstep(.18,.8,v);
   alpha*=.78+.22*fibers(vec2(u*35.0,v*4.0-phase));
  }
  if(substance==2){
   float foam=pow(max(0.0,sin(u*53.0+field*7.0+v*9.0-phase*1.7)),8.0)*smoothstep(.35,.95,v);
   pigment=mix(tint.rgb*vec3(.13,.32,.48),tint.rgb*.80,v*.70);
   pigment=mix(pigment,vec3(.70,.92,.98),foam*.65);
   float spray=step(.76,noise(vec2(u*70.0-phase*2.0,v*44.0)))*smoothstep(.50,.95,v);
   pigment=mix(pigment,vec3(.82,.97,1.0),spray*.50);
  }
  if(substance==0 || substance==12){
   float polish=fibers(vec2(u*3.0-phase*.1,v*65.0));
   pigment*=.78+polish*.45;
   pigment+=tint.rgb*exp(-pow((v-.70-field*.08)*48.0,2.0))*.20;
  }
  if(substance==3 || substance==9){
   float split=fract(u*9.0+v*2.0);
   pigment+=tint.rgb*exp(-pow((split-.12)*28.0,2.0))*.28;
  }
  if(substance==5){
   float crack=abs(fibers(vec2(u*14.0,v*9.0))-.50);
   pigment*=mix(.36,1.0,smoothstep(.015,.06,crack));
  }
  if(substance==7 || substance==8 || substance==10 || substance==13){
   float thread=fibers(vec2(u*4.0-phase,v*48.0));
   pigment*=.65+thread*.65;
   alpha*=.65+thread*.35;
  }
  // Only one thin cutting edge reaches a pale highlight; the body stays pigmented.
  pigment=mix(pigment,mix(tint.rgb,vec3(1.0),.48),edge*.85);
  alpha*=contour;
 }else{
  pigment*=.55+noise(UV*5.0)*.40;
 }
 if(alpha<.003)discard;
 ALBEDO=pigment;
 EMISSION=pigment*(substance==4 ? .65 : .22);
 ALPHA=clamp(alpha,0.0,1.0);
}
