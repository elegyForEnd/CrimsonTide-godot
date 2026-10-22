shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// The transparent 3D viewport already contains alpha-weighted RGB.
// Its canvas pass must not multiply that RGB by the same alpha again.
