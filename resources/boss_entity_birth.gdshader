shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float reveal = 1.0;
uniform float opacity = 1.0;
uniform float flash = 0.0;
uniform bool from_ground = false;
uniform bool clip_ground = false;
uniform vec2 mask_x = vec2(1.0,0.0);
uniform vec2 mask_y = vec2(0.0,1.0);
uniform vec2 mask_origin = vec2(0.0);
uniform float radius = 1.0;
uniform float inner = 0.0;
uniform float arc = 1.05;
uniform float gap = .5;
uniform int shape = 0;
varying vec2 sprite_point;
void vertex() { sprite_point=VERTEX; }
float footprint(vec2 p) {
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
void fragment() {
	vec4 art=texture(TEXTURE,UV);
	float boundary=1.0-reveal;
	float grow=from_ground?smoothstep(boundary-.018,boundary+.018,UV.y):1.0;
	float rim=from_ground?exp(-abs(UV.y-boundary)*100.0)*(1.0-step(.99,reveal)):0.0;
	float clip=clip_ground?footprint(mask_origin+mask_x*sprite_point.x+mask_y*sprite_point.y):1.0;
	COLOR=vec4(mix(art.rgb,vec3(1.0,.98,.92),clamp(flash+rim*.55,0.0,.8)),art.a*opacity*grow*clip);
}
