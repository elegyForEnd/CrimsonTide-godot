shader_type spatial;
render_mode specular_disabled;
varying vec2 ground_uv;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap, repeat_enable;
// How much of the albedo the painted ground carries (the rest is flat turf patches).
// Guarded by tests/camp.gd: the ground has to read as material, not as a flat fill.
uniform float texture_mix : hint_range(0.0, 1.0) = 0.85;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { ground_uv = VERTEX.xz; }
void fragment() {
	float patches = noise(ground_uv*0.45)*0.65 + noise(ground_uv*1.6)*0.35;
	float grit = smoothstep(0.72,0.95,noise(ground_uv*35.0));
	vec3 painted = texture(ground_tex,ground_uv/4.0).rgb;
	// Placeholder camp ground: until the camp gets its own ground art it reuses the
	// story-mode soil PBR (assets/story/environment/pbr/soil_albedo.png). The texture
	// carries the albedo and the flat turf only patches it — the old mix weight of 0.07
	// buried the texture under a dark teal turf, which looked like a missing material.
	vec3 turf = mix(vec3(0.085,0.082,0.078),vec3(0.145,0.140,0.132),patches);
	vec3 ground = painted*vec3(1.00,0.97,0.93) + vec3(0.014,0.014,0.015);
	ALBEDO = mix(turf, ground, texture_mix) + grit*vec3(0.010,0.009,0.008);
	ROUGHNESS = 1.0;
}
