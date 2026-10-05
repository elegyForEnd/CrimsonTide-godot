shader_type canvas_item;
render_mode unshaded, blend_add;
// Additive readability shell for live boss projectiles.
//
// The geometry uniforms are exactly the ones boss_geometry.gd hands the damage
// shader, and the rect this runs on is that footprint grown by `margin` on every
// side.  The shell paints nothing inside the footprint (the branch below), so it
// can brighten a bolt without ever suggesting that a safe pixel is dangerous or
// the other way round: the hurt boundary is still Geometry.contains()'s.
uniform vec2 extent;
uniform vec2 center;
uniform float radius;
uniform float inner;
uniform float arc = 1.05;
uniform float gap = 0.5;
uniform int shape = 0;
uniform float margin = 13.0;
uniform vec4 tone : source_color = vec4(1.0);
uniform float clock = 0.0;

// Distance to the same boundary boss_damage_shape.gdshader walks with inside_shape().
// Zero on the edge, positive outside it.
float boundary_distance(vec2 p) {
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
	float sd=boundary_distance(p);
	// Strictly outside: a saturated rim hugging the boundary plus the bloom it
	// throws outward, both fading to nothing well before the rect runs out.
	float rim=exp(-sd/2.2);
	float bloom=exp(-sd/(margin*.55))*.5;
	// A slow breath keeps a live bolt from reading as static decoration.
	float breath=.86+.14*sin(clock*9.0);
	float shell=max(sd,0.0)>0.0?(rim+bloom)*breath:0.0;
	vec3 rgb=mix(tone.rgb,vec3(.97,1.0,1.0),clamp(rim*.55+bloom*.9,0.0,0.9));
	COLOR=vec4(rgb,clamp(shell,0.0,1.0));
}
