shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D density_texture : source_color, filter_linear, repeat_disable;
uniform vec4 source_rect = vec4(0.0,0.0,1.0,1.0);
uniform bool body_mode = false;
uniform bool particle_mode = false;
uniform float effect_phase = 0.0;
uniform float flow = 1.0;
uniform float shear = 0.0;
uniform float material_code = 0.0;
uniform float wake_opacity = 1.0;
uniform bool flow_vertical = false;
uniform float flow_repeat = 1.65;
uniform bool flow_rgba = false;
varying vec4 mesh_tint;
void vertex() { mesh_tint=COLOR; }
void fragment() {
	vec3 tone=mesh_tint.rgb;
	float alpha=mesh_tint.a;
	if (body_mode) {
		vec4 art=texture(density_texture,source_rect.xy+UV*source_rect.zw);
		tone=art.rgb;
		alpha*=art.a;
	} else if (!particle_mode) {
		float transport=effect_phase*flow*1.2;
		float across=clamp(UV.y+sin(UV.x*17.0-transport*4.0)*shear*.07,0.0,1.0);
		float along=1.0-abs(fract(UV.x*flow_repeat-transport)*2.0-1.0);
		vec2 uv=vec2(along,across);
		if(flow_vertical) uv=vec2(across,1.0-along);
		vec4 field=texture(density_texture,source_rect.xy+uv*source_rect.zw);
		float density=dot(field.rgb,vec3(.2126,.7152,.0722));
		float edge=smoothstep(0.0,.24,UV.y)*(1.0-smoothstep(.76,1.0,UV.y));
		float fiber=.38+.62*density;
		if (material_code==2.0) { fiber*=.45+.55*smoothstep(-.2,.6,sin(UV.x*41.0-transport*8.0)); }
		if (material_code==3.0 || material_code==10.0) { fiber*=.6+.4*abs(sin(UV.x*25.0+UV.y*7.0-transport)); }
		if (material_code==1.0) { edge*=exp(-abs(UV.y-.5)*2.5); }
		if (material_code==5.0) { fiber=.15+.85*pow(max(density,0.0),.7); }
		float core=pow(max(0.0,1.0-abs(UV.y-.5)*8.0),2.0);
		tone=mix(tone,vec3(1.0),core*.45);
		fiber+=core*.32;
		// Each weapon's actual RGBA membrane also shapes the flight wake.
		// Empty painted channels stay empty rather than receiving a solid core.
		if(flow_rgba){
			fiber=field.a*(.28+.72*sqrt(max(density,0.0)));
			tone=mix(mesh_tint.rgb,vec3(1.0),smoothstep(.8,1.0,density)*.28);
		}
		alpha*=wake_opacity*edge*fiber*smoothstep(0.0,.07,UV.x)*(1.0-smoothstep(.97,1.0,UV.x));
	}
	if (alpha<.003) { discard; }
	ALBEDO=tone;
	EMISSION=tone*(body_mode ? .45 : .85);
	ALPHA=clamp(alpha,0.0,1.0);
}
