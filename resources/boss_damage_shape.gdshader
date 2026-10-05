shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform sampler2D art_texture : source_color, filter_linear_mipmap;
uniform vec4 tone : source_color = vec4(1.0);
uniform vec2 extent;
uniform vec2 center;
uniform vec2 art_size = vec2(1280.0);
uniform float radius;
uniform float inner;
uniform float arc = 1.05;
uniform float gap = 0.5;
uniform int shape = 0;
uniform bool active = false;
uniform float progress = 0.0;
uniform float opacity = 1.0;
uniform float clock = 0.0;
uniform float arrival = 1.0;
uniform float impact_age = 1.0;
uniform int stream_style = 0;
uniform int entity_style = 0;
uniform int motif = 0;
uniform int attack_family = -1;
uniform int cover_count = 0;
uniform vec3 covers[8];
// A visible shell around the authoritative footprint.  It is painted only on
// pixels OUTSIDE inside_shape(), so the damage boundary the player must respect
// and the boundary the eye reads stay the same line: the halo can never make a
// capsule look hittable where it is not, or safe where it is.
uniform float halo_strength = 0.0;
uniform float halo_width = 14.0;

float inside_shape(vec2 p) {
	float d=length(p);
	float a=abs(atan(p.y,p.x));
	if(shape==7) return float(length(vec2(p.x-clamp(p.x,0.0,radius),p.y))<=inner);
	if(shape==3) return float(p.x>=-22.0 && p.x<=radius && abs(p.y)<=44.0);
	if(shape==4) return float(p.x>=0.0 && p.x<=radius && abs(p.y)<=inner);
	if(d>radius) return 0.0;
	if(shape==2) return float(a<=arc);
	if(d<inner) return 0.0;
	if(shape==5) return float(a>gap);
	if(shape==6) return float(a<=arc);
	return 1.0;
}
// Signed distance to the same boundary, used only to paint the outer shell.
// Positive is outside the damage footprint, negative is inside it.
float signed_distance(vec2 p) {
	if(shape==7) return length(vec2(p.x-clamp(p.x,0.0,radius),p.y))-inner;
	if(shape==3) {
		vec2 c=vec2(clamp(p.x,-22.0,radius),clamp(p.y,-44.0,44.0));
		float inside=float(p.x>=-22.0 && p.x<=radius && abs(p.y)<=44.0);
		return mix(length(p-c),-length(p-c),inside);
	}
	if(shape==4) {
		vec2 c=vec2(clamp(p.x,0.0,radius),clamp(p.y,-inner,inner));
		float inside=float(p.x>=0.0 && p.x<=radius && abs(p.y)<=inner);
		return mix(length(p-c),-length(p-c),inside);
	}
	float d=length(p);
	float a=abs(atan(p.y,p.x));
	if(shape==2) return max(d-radius,(a-arc)*max(d,1.0));
	if(shape==5) return max(max(inner-d,d-radius),(gap-a)*max(d,1.0));
	if(shape==6) return max(max(inner-d,d-radius),(a-arc)*max(d,1.0));
	return max(inner-d,d-radius);
}
void fragment() {
	vec2 p=(UV-vec2(.5))*extent+center;
	float mask=inside_shape(p);
	for(int i=0;i<8;i++) {
		if(i>=cover_count) break;
		vec2 q=p*clamp(dot(covers[i].xy,p)/max(dot(p,p),.001),0.0,1.0);
		if(distance(q,covers[i].xy)<covers[i].z && length(covers[i].xy)<length(p)-25.0) mask=0.0;
	}
	// Every visible ground pixel is inside the same exact boundary as contains().
	float edge=0.0;
	edge=max(edge,1.0-inside_shape(p+vec2(2.0,0.0)));
	edge=max(edge,1.0-inside_shape(p-vec2(2.0,0.0)));
	edge=max(edge,1.0-inside_shape(p+vec2(0.0,2.0)));
	edge=max(edge,1.0-inside_shape(p-vec2(0.0,2.0)));
	// Continuous world-space material: no repeated PNGs and no stretched sprites.
	float phase=clock*5.0;
	float energy=0.0;
	if(shape==3 || shape==4 || shape==7) {
		float width=shape==3?44.0:max(inner,1.0);
		float u=clamp(p.x/max(radius,1.0),0.0,1.0);
		float lateral=abs(p.y)/width;
		float filament=abs(p.y-sin(p.x*.043-phase)*width*.19);
		if(stream_style==1) { // Electrical branches with a single continuous conductor.
			float segment=floor(p.x/26.0);
			float tick=floor(clock*12.0);
			float y0=sin(segment*127.1+tick*17.0)*.75;
			float y1=sin((segment+1.0)*127.1+tick*17.0)*.75;
			float zig=mix(y0,y1,fract(p.x/26.0));
			energy=exp(-abs(p.y-zig*width*.27)/2.3);
			energy+=exp(-abs(p.y+zig*width*.43)/1.3)*.45;
		} else if(stream_style==2) { // Flame / frost breath flows from its source.
			energy=pow(max(0.0,1.0-lateral),1.6)*(.42+.42*sin(p.x*.035-phase+sin(p.y*.13)));
		} else if(stream_style==3) { // Wind and tidal ribbons.
			energy=exp(-filament/3.0)+exp(-abs(p.y+sin(p.x*.027-phase)*width*.6)/2.0)*.5;
		} else if(stream_style==4) { // Broken rock / root fault, never tiled art.
			float fault=sin(p.x*.08)*width*.15+sin(p.x*.19)*width*.12;
			energy=exp(-abs(p.y-fault)/3.0)*(.6+.4*sin(p.x*.13-phase));
		} else if(stream_style==5) { // Taut threads / chains, two continuous rails.
			energy=exp(-abs(abs(p.y)-width*.35)/1.8)*.75+exp(-abs(p.y)/2.0)*.5;
		} else { // Optical lance and blade streak.
			energy=exp(-abs(p.y)/(width*.16+1.0))*(.65+.25*sin(p.x*.028-phase));
		}
		energy*=smoothstep(0.0,.035,u+.005)*smoothstep(1.03,.96,u);
	} else {
		float d=length(p);
		float rings=.5+.5*sin(d*.09-phase);
		float a=atan(p.y,p.x);
		// No generic rotating radial decoration. The contact's material defines its motion.
		energy=exp(-abs(d-radius*clamp(impact_age*5.0,0.0,1.0))/3.0)*max(0.0,1.0-impact_age*3.0);
		if(entity_style==0) energy=pow(rings,6.0)*.48; // Bell resonances.
		if(entity_style==1 || entity_style==12) energy=exp(-abs(sin(a*7.0+sin(d*.027))*d)/3.0)*.52; // Root forks.
		if(entity_style==2 || entity_style==3 || entity_style==16) { // Blade cuts stay on the locked attack direction.
			float cut_angle=mix(-arc,arc,clamp(impact_age*6.0,0.0,1.0));
			float cut=shape==2?abs(sin(a-cut_angle))*d:abs(p.y);
			energy=exp(-cut/2.3)*exp(-impact_age*5.0)*.85;
			if(entity_style==16 && motif==3) energy=exp(-abs(max(abs(p.x),abs(p.y))-radius*.58)/2.0)*.5;
		}
		if(entity_style==4) energy=exp(-abs(p.x-sin(p.y*.045)*6.0)/2.0)*.65; // Upright ground fissure.
		if(entity_style==5 || entity_style==14) energy=exp(-abs(sin(a*4.0)*d-25.0)/2.0)*.5; // Refraction planes.
		if(entity_style==6 || entity_style==13) { // Burning ground: irregular local combustion, not a spiral.
			float flame=sin(p.x*.09+sin(p.y*.06)*2.0+phase)*sin(p.y*.07-phase*1.7);
			energy=pow(max(0.0,flame),2.0)*.72;
		}
		if(entity_style==7) energy=exp(-abs(d-radius*(.22+.55*fract(clock*.7)))/3.0)*.6; // Inward blood tide.
		if(entity_style==8 || entity_style==11) energy=exp(-abs(sin(a*5.0+floor(d*.045)*.7)*d)/2.3)*.5; // Faults / crystal ribs.
		if(entity_style==9) { // Fixed electrical paths flicker, never turn a giant feather.
			float jitter=sin(floor(d/17.0)*31.7+floor(clock*14.0)*7.1)*.045;
			energy=exp(-abs(sin(a*5.0+jitter))*d/1.8)*(.35+.35*sin(clock*38.0)*sin(clock*38.0));
			if(inner>0.0) energy=exp(-abs(d-(inner+radius)*.5-jitter*radius)/2.1)*.8;
		}
		if(entity_style==10) energy=pow(.5+.5*sin(d*.07-phase*1.2+sin(a*4.0)*.3),8.0)*.55; // Outward tidal crests.
		if(entity_style==15) { // Thin flowing air bands; only the authored cyclone circles its centre.
			energy=exp(-abs(p.y-sin(p.x*.035-phase)*radius*.16)/2.0)*.6;
			if(motif==2) energy=exp(-abs(d-radius*(.35+.18*sin(a*2.0-phase)))/2.0)*.65;
		}
		energy+=exp(-abs(d-radius*clamp(impact_age*4.0,0.0,1.0))/3.0)*max(0.0,1.0-impact_age*2.0);
	}
	if(attack_family>=0) {
		// Semantic material lives in the authoritative footprint, never a weapon stamp.
		float d=length(p);
		float a=atan(p.y,p.x);
		float sweep=clamp(impact_age*7.0,0.0,1.0);
		float band=exp(-abs(d-radius*(.35+.55*sweep))/3.0);
		if(attack_family==0) energy=band*.85+exp(-abs(a-mix(-arc,arc,sweep))*d/2.0)*.45;
		if(attack_family==1) {
			float tongues=sin(p.x*.065-phase*2.4+sin(p.y*.1))*sin(p.y*.12+phase);
			energy=max(0.0,tongues)*.8+exp(-abs(p.y)/(8.0+max(p.x,0.0)*.16))*.45;
		}
		if(attack_family==2) energy=exp(-abs(p.y-sin(p.x*.13+sin(p.x*.31)+clock*16.0)*12.0)/1.8)*.9+band*.28;
		if(attack_family==3) energy=pow(.5+.5*sin(a*3.0-d*.075+phase*1.6),16.0)*.75;
		if(attack_family==4) energy=exp(-abs(p.y-sin(p.x*.11)*8.0-sin(p.x*.23)*4.0)/2.0)*.85+exp(-abs(sin(a*5.0+.4))*d/2.0)*.4;
		if(attack_family==5) energy=(.5+.5*sin(p.x*.047+sin(p.y*.06)+phase*.35))*.18;
		if(attack_family==6) energy=exp(-abs(d-radius*.64)/1.8)*.6+exp(-abs(sin(a*3.0))*d/1.8)*.5;
		if(attack_family==7) energy=band*.8;
		if(attack_family==8) energy=exp(-abs(d-radius*.65)/2.0)*.4;
		if(attack_family==9) energy=exp(-abs(d-radius*.8)/2.0)*.45;
		if(attack_family==10) energy=exp(-abs(p.y)/2.0)*.65+exp(-abs(sin(a*4.0))*d/1.5)*.4;
		if(attack_family==11) energy=exp(-abs(p.y-sin(p.x*.05-phase)*6.0)/2.0)*.6;
	}
	float warning_in=smoothstep(0.0,1.0,arrival);
	float warning_fill=.024+.035*progress;
	float warning_edge=(.14+.32*progress)*warning_in;
	float body=active?(.065+energy*.48):warning_fill*warning_in;
	float border=active?.30:warning_edge;
	float flash=active?exp(-impact_age*16.0)*.14:0.0;
	// Outer shell, strictly outside the damage boundary: a hard saturated rim
	// plus the soft bloom it throws, both in the attack's own tone.
	float sd=signed_distance(p);
	float halo=0.0;
	if(halo_strength>0.0) {
		float rim=exp(-max(sd,0.0)/2.2);
		float bloom=exp(-max(sd,0.0)/halo_width)*.60;
		halo=(rim+bloom)*halo_strength*float(sd>0.0);
	}
	// The halo rides on top of the body's own coverage instead of being gated by
	// it, so a dim core cannot swallow its own shell.
	float core=mask*opacity*max(body+flash,edge*border);
	vec3 rgb=mix(tone.rgb,vec3(.96,.99,1.0),clamp(energy*.6+flash+edge*.15+halo*.55,0.0,.85));
	COLOR=vec4(rgb,clamp(core+halo*opacity,0.0,1.0));
}
