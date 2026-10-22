shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D density:filter_linear,repeat_disable;
uniform vec2 ink_origin=vec2(0.0);
uniform vec2 ink_size=vec2(1.0);
uniform float phase=0.0;
uniform float flow=0.5;
uniform int smoke_kind=0;
uniform bool vertical_art=false;
void fragment(){
 // Builder's local +Y points up; image row zero is the top of the painting.
 vec2 p=vec2(UV.x,1.0-UV.y);
 p.x+=sin(p.y*5.0+phase*2.0)*.025*flow;
 if(vertical_art) p.y+=phase*.055*flow;
 else p.x+=phase*.055*flow;
 p.y+=sin(p.x*4.0-phase*3.0)*.025;
 float border=smoothstep(0.0,.12,UV.x)*smoothstep(0.0,.12,1.0-UV.x)*smoothstep(0.0,.16,UV.y)*smoothstep(0.0,.16,1.0-UV.y);
 // Each family has a different broad transport field, kept low-frequency.
 if(smoke_kind==1){p.x+=phase*.035; p.y=mix(.5,p.y,1.0+phase*.08);}
 else if(smoke_kind==2){p.x-=phase*.04; p.y+=sin(p.x*3.0-phase)*.015;}
 else if(smoke_kind==3){p.y+=phase*.07; p.x+=sin(p.y*4.0+phase*2.0)*.04;}
 else if(smoke_kind==4){p.y+=phase*.025;}
 else if(smoke_kind==5||smoke_kind==8){p.y+=phase*.045; p.x+=sin(p.y*4.0-phase*2.0)*.035;}
 else if(smoke_kind==6){vec2 q=p-.5; float a=-phase*.32; p=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*q*(1.0+phase*.09)+.5;}
 else if(smoke_kind==7){p.x+=phase*.10;}
 vec3 tex=texture(density,ink_origin+clamp(p,vec2(0.0),vec2(1.0))*ink_size).rgb;
 float opacity=dot(tex,vec3(.299,.587,.114));
 ALBEDO=COLOR.rgb;
 EMISSION=COLOR.rgb*.18;
 // Broad threshold erosion breaks up the dying veil without noisy bumps.
 float erosion=smoothstep(phase*.32-.10,phase*.32+.16,opacity);
 ALPHA=sqrt(max(opacity,0.0))*COLOR.a*border*mix(1.0,erosion,smoothstep(.25,1.0,phase));
}
