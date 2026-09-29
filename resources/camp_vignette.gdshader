shader_type canvas_item;
render_mode unshaded;
// Camp vignette: the storm closes the frame in. Samples the rendered 3D map and
// darkens, cools and slightly desaturates the border so the eye stays on the
// fire and on the player. Requires a BackBufferCopy with copy_mode = Viewport.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.2) = 0.82;
uniform float inner : hint_range(0.0, 1.0) = 0.30;
uniform float outer : hint_range(0.2, 2.0) = 1.24;
uniform vec3 edge_tint : source_color = vec3(0.045, 0.075, 0.135);
uniform float saturation : hint_range(0.0, 2.0) = 0.86;

void fragment() {
	vec2 p = (SCREEN_UV - 0.5) * vec2(1.0, 0.94);
	float mask = smoothstep(inner, outer, length(p)) * strength;
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, saturation);
	color = mix(color, edge_tint, mask * 0.6);
	color *= 1.0 - mask * 0.68;
	COLOR = vec4(color, 1.0);
}
