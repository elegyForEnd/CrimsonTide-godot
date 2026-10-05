shader_type canvas_item;
render_mode unshaded;

uniform float phase = 0.0;
uniform vec2 image_size = vec2(1254.0, 1254.0);
uniform float strength = 1.0;

void fragment() {
	// Move only the exposed trailing locks; the face, roots and limbs stay put.
	float locks = (1.0 - smoothstep(0.32, 0.47, UV.x))
		* smoothstep(0.34, 0.46, UV.y)
		* (1.0 - smoothstep(0.65, 0.73, UV.y))
		* smoothstep(0.11, 0.15, UV.x);
	float rear_hand = 1.0 - smoothstep(0.75, 1.2,
		length((UV - vec2(0.34, 0.60)) / vec2(0.085, 0.085)));
	locks *= 1.0 - rear_hand;
	float ribbons = 1.0 - smoothstep(0.65, 1.0,
		length((UV - vec2(0.39, 0.33)) / vec2(0.075, 0.055)));
	float curl = (1.0 - smoothstep(0.18, 0.21, UV.y))
		* (1.0 - smoothstep(0.7, 1.0,
		length((UV - vec2(0.59, 0.17)) / vec2(0.065, 0.045))));
	vec2 displacement = locks * vec2(
		14.0 * sin(phase),
		10.0 * (sin(2.0 * phase - 0.8) + sin(0.8)));
	displacement += ribbons * vec2(4.0 * (sin(phase - 0.5) + sin(0.5)),
		6.0 * (sin(2.0 * phase - 0.9) + sin(0.9)));
	displacement += curl * vec2(3.0 * sin(phase), 1.0 * sin(2.0 * phase));
	COLOR = texture(TEXTURE, UV - strength * displacement / image_size);
}
