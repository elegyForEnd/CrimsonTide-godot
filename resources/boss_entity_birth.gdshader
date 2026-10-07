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
// Reveal along the painted slash itself, independent of any warning footprint.
uniform bool stroke_mode = false;
uniform float stroke_phase = 0.0;
uniform float stroke_arc = 1.05;
uniform bool stroke_reverse = false;
// Readability shell for live projectiles: an outline traced from the sprite's
// own alpha, plus the bloom it throws outward, so a boss bolt keeps its painted
// shape but stops disappearing into the background.  Zero for every other
// staged boss entity, which leaves their look untouched.
uniform float rim_strength = 0.0;
uniform vec4 rim_tone : source_color = vec4(1.0);
// One pixel in UV, times how far the bloom reaches, supplied by the caller:
// canvas_item shaders have no TEXEL_SIZE builtin.
uniform vec2 rim_step = vec2(0.0);
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
	vec3 rgb=mix(art.rgb,vec3(1.0,.98,.92),clamp(flash+rim*.55,0.0,.8));
	float alpha=art.a*opacity*grow*clip;
	if(stroke_mode) {
		vec2 q=UV-vec2(.5);
		float a=atan(q.y,q.x)*(stroke_reverse?-1.0:1.0);
		float head=mix(-stroke_arc,stroke_arc,stroke_phase);
		float ink=smoothstep(head-.90,head-.55,a)*(1.0-smoothstep(head+.02,head+.20,a));
		alpha*=ink;
	}
	if(rim_strength>0.001) {
		// The filled sprite gets a saturated skin at its edge; the ink outside
		// that edge is the bloom, and it fades out over `rim_step` in UV.
		vec2 step_uv=rim_step;
		float solid=step(.55,art.a);
		if(solid>.5) {
			rgb=mix(rgb,rim_tone.rgb,.42);
			alpha=max(alpha,art.a*opacity*clip);
		} else {
			float ink=0.0;
			ink=max(ink,texture(TEXTURE,UV+vec2(step_uv.x,0.0)).a);
			ink=max(ink,texture(TEXTURE,UV-vec2(step_uv.x,0.0)).a);
			ink=max(ink,texture(TEXTURE,UV+vec2(0.0,step_uv.y)).a);
			ink=max(ink,texture(TEXTURE,UV-vec2(0.0,step_uv.y)).a);
			ink=max(ink,texture(TEXTURE,UV+step_uv*.7).a);
			ink=max(ink,texture(TEXTURE,UV-step_uv*.7).a);
			ink=max(ink,texture(TEXTURE,UV+vec2(step_uv.x,-step_uv.y)*.7).a);
			ink=max(ink,texture(TEXTURE,UV+vec2(-step_uv.x,step_uv.y)*.7).a);
			float glow=step(.30,ink)*(1.0-step(.55,ink));
			if(glow>0.001) {
				rgb=mix(rgb,rim_tone.rgb,.85);
				alpha=max(alpha,glow*.90*opacity*clip);
			}
		}
	}
	COLOR=vec4(rgb,alpha);
}
