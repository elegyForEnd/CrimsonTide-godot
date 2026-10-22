shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform vec4 density_rect = vec4(0.0,0.0,1.0,1.0);
uniform float effect_phase = 0.0;
uniform float flow = 1.0;
uniform float shear = 0.0;
uniform float material_code = 0.0;
varying vec4 ribbon_tint;
void vertex() { ribbon_tint=COLOR; }
void fragment() {
	float along=UV.x;
	float across=UV.y;
	float transport=effect_phase*flow*1.4;
	float ripple=sin(along*15.0-transport*4.0)*shear*0.08;
	vec2 field_uv=vec2(fract(along*1.8-transport),clamp(across+ripple,0.0,1.0));
	vec3 field=texture(TEXTURE,density_rect.xy+field_uv*density_rect.zw).rgb;
	float density=dot(field,vec3(0.2126,0.7152,0.0722));
	float edge=smoothstep(0.0,0.24,across)*(1.0-smoothstep(0.76,1.0,across));
	float fiber=0.32+0.68*density;
	if (material_code==2.0) { // Disconnected electrical filaments, rather than smoke.
		fiber*=0.50+0.50*smoothstep(-0.20,0.65,sin(along*42.0-transport*7.0));
	} else if (material_code==3.0 || material_code==10.0) {
		fiber*=0.60+0.40*abs(sin(along*24.0+across*7.0-transport));
	} else if (material_code==1.0) {
		edge*=exp(-abs(across-0.5)*3.0);
	} else if (material_code==5.0 || material_code==12.0) {
		fiber=0.20+0.80*pow(max(density,0.0),0.7);
	}
	float ends=smoothstep(0.0,0.10,along)*(1.0-smoothstep(0.96,1.0,along));
	float core=exp(-abs(across-0.5)*14.0)*0.18;
	vec3 tone=mix(ribbon_tint.rgb,vec3(max(ribbon_tint.r,max(ribbon_tint.g,ribbon_tint.b))),core);
	COLOR=vec4(tone,ribbon_tint.a*edge*ends*fiber);
}
