shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 tint : source_color = vec4(0.8, 0.5, 1.0, 1.0);
uniform float age = 0.0;
uniform float life = 0.8;
uniform float seed = 0.0;
uniform int form = 0; // eruption, lance, annulus, sweep, gathering
uniform float inner = 0.0;
uniform float opening = 1.05;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);
}
float cloud(vec2 p) {
	return noise(p)*0.57 + noise(p*2.03+17.1)*0.29 + noise(p*4.11+31.7)*0.14;
}
void fragment() {
	float t = clamp(age/life,0.0,1.0);
	vec2 p = UV*2.0-1.0;
	float r = length(p);
	float a = atan(p.y,p.x);
	vec2 wind = vec2(seed*1.71+age*.65,-age*2.7);
	float n = cloud(p*4.5+wind);
	float wisps = cloud(p*vec2(9.0,4.0)+n*3.5+wind*1.8);
	float veins = pow(max(0.0,1.0-abs(wisps*2.0-1.0)),9.0);
	float mask = 0.0;
	float core = 0.0;
	float envelope = smoothstep(0.0,.045,t)*pow(1.0-t,1.35);
	if (form == 0) {
		// Rising volumetric flame, not a static disc: broad body, torn tips, hot foot.
		float height = clamp((.78-p.y)/1.7,0.0,1.0);
		float width = (.16+.46*(1.0-height))*(.65+.65*sin(t*2.8));
		float edge = abs(p.x)+(n-.5)*.22;
		mask = (1.0-smoothstep(width*.25,width,edge))*smoothstep(-1.0,-.45+n*.5,p.y)*(1.0-smoothstep(.65,.95,p.y));
		mask *= .22+wisps*.65+veins*.6;
		core = exp(-length(vec2(p.x*2.3,(p.y-.53)*2.2))*9.0)*2.0;
	} else if (form == 1) {
		float width = .035+(1.0-t)*.17;
		float tail = 1.0-smoothstep(.82,1.0,abs(p.x));
		float warp = sin(p.x*14.0-age*23.0)*.022+(n-.5)*.13;
		mask = exp(-abs(p.y+warp)/(width+.01))*(.3+veins*1.8+wisps*.7)*tail;
		core = exp(-abs(p.y+warp*.25)/.018)*tail;
	} else if (form == 2) {
		float front = mix(inner+.045,.92,1.0-pow(1.0-t,3.0));
		float width = .04+(1.0-t)*.12;
		mask = exp(-abs(r-front+(n-.5)*.07)/width)*(.35+wisps+veins);
		core = exp(-abs(r-front)/.018)*.65;
		// Damage-free centre is completely transparent, even under turbulence.
		mask *= smoothstep(inner,inner+.025,r)*(1.0-smoothstep(.96,1.0,r));
		core *= step(inner,r)*(1.0-smoothstep(.96,1.0,r));
	} else if (form == 3) {
		float head = mix(-opening,opening,min(t*3.0,1.0));
		float arc = smoothstep(head-1.9,head-.15,a)*(1.0-smoothstep(head-.02,head+.07,a));
		arc *= step(-opening,a)*step(a,opening);
		mask = exp(-abs(r-.78+(n-.5)*.045)/(.025+(1.0-t)*.12))*arc*(.55+veins);
		core = exp(-abs(r-.82)/.013)*arc;
	} else {
		float spiral = sin(a*5.0+r*17.0+age*11.0+n*3.0);
		mask = pow(max(0.0,spiral),5.0)*smoothstep(.08,.25,r)*(1.0-smoothstep(.45,.95,r))*(.35+wisps);
		core = exp(-r*18.0)*(.5+t);
		envelope = (.2+t*.8)*(1.0-smoothstep(.9,1.0,t));
	}
	float edge = smoothstep(0.0,.04,UV.x)*smoothstep(0.0,.04,UV.y)*smoothstep(0.0,.04,1.0-UV.x)*smoothstep(0.0,.04,1.0-UV.y);
	vec3 color = tint.rgb*mask*.95 + mix(tint.rgb,vec3(1.0,.96,.92),.65)*core*.65;
	COLOR = vec4(color,clamp((mask+core)*envelope*edge*tint.a,0.0,.78));
}
