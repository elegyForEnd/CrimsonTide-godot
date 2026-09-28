shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 foliage : source_color = vec4(1.0);
uniform float empty_amount = 0.0;
uniform bool leaf_surface = false;
uniform bool stone_lift = false;

void fragment() {
	vec4 sample_color = texture(atlas, UV);
	vec3 color = sample_color.rgb;
	// The shared atlas keeps wood and stone intact while leaves follow the biome.
	float green = smoothstep(0.025, 0.12, color.g - max(color.r, color.b));
	if (foliage != vec4(1.0)) {
		color = mix(color, foliage.rgb * (0.6 + max(color.r, max(color.g, color.b)) * 0.65), leaf_surface ? 1.0 : green);
	}
	if (stone_lift) { color = mix(color, vec3(0.55,0.53,0.62), 0.40); }
	float red = smoothstep(0.12, 0.5, color.r - max(color.g, color.b));
	color = mix(color, color * vec3(0.70,0.7,0.9) + vec3(0.02,0.015,0.035), red);
	color = mix(color, vec3(dot(color, vec3(0.299,0.587,0.114))), empty_amount * 0.7);
	ALBEDO = color * tint.rgb * mix(1.0, 0.60, empty_amount);
	ALPHA = leaf_surface ? sample_color.a : 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.95;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float band = mix(0.28, 0.9, smoothstep(-0.10, 0.25, facing));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band / 3.14159265;
}
