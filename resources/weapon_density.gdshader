shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float effect_phase : hint_range(0.0,1.0) = 0.0;
uniform float flow = 0.1;
uniform float shear = 0.0;
uniform float opacity_gain = 1.0;
varying vec4 draw_tint;
void vertex() { draw_tint=COLOR; }
void fragment() {
	// The original grayscale image is a density field, never an opaque black quad.
	// Continuous UV transport keeps mist airy; no binary noise/dissolve thresholds.
	vec2 uv=UV;
	uv.x+=flow*effect_phase*0.16*sin(UV.y*3.14159265);
	uv.y+=shear*0.025*effect_phase*sin(UV.x*9.0+effect_phase*3.0);
	float inside=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
	vec3 ink=texture(TEXTURE,clamp(uv,vec2(0.0),vec2(1.0))).rgb;
	float density=max(0.0,dot(ink,vec3(0.2126,0.7152,0.0722))-0.012)/0.988;
	COLOR=vec4(draw_tint.rgb,pow(density,0.95)*draw_tint.a*opacity_gain*inside);
}
