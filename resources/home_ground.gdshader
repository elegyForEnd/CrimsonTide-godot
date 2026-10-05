shader_type spatial;
render_mode specular_disabled;
varying vec2 ground_uv;
uniform sampler2D meadow : source_color, filter_linear_mipmap, repeat_enable;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { ground_uv = VERTEX.xz; }
void fragment() {
	float patches = noise(ground_uv*0.45)*0.65 + noise(ground_uv*1.6)*0.35;
	float blades = smoothstep(0.72,0.95,noise(ground_uv*35.0));
	vec3 painted = texture(meadow,ground_uv/4.0).rgb;
	vec3 turf = mix(vec3(0.075,0.105,0.12),vec3(0.15,0.20,0.18),patches);
	ALBEDO = mix(turf, painted * vec3(0.35,0.43,0.44), 0.07) + blades*vec3(0.004,0.009,0.002);
	ROUGHNESS = 1.0;
}
