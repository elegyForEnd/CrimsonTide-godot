extends RefCounted
## Original combat VFX use native terrain coordinates, as before.
var view_ref: WeakRef
var world:
	get: return view_ref.get_ref().original
var campaign:
	get: return view_ref.get_ref().facade
var active: bool:
	get: return view_ref.get_ref().is_visible_in_tree()
func _init(view): view_ref=weakref(view)
func canvas_inverse() -> Transform2D:
	return view_ref.get_ref().combat_fx.get_global_transform_with_canvas().affine_inverse()
func project(p: Vector2) -> Vector2:
	# Camera projection is already in viewport pixels. The effects live under
	# the scaled/centred campaign UI, so cross that boundary exactly once.
	return canvas_inverse()*world.project(p)
func ground_transform() -> Transform2D:
	return canvas_inverse()*world.ground_transform()
func weapon_effect_socket(hero: int) -> Dictionary:
	var mounted: Dictionary=world.weapon_effect_socket(hero)
	var inverse := canvas_inverse()
	for key in ["tip","grip","stroke_tip","stroke_pivot","stroke_center"]:
		if mounted.has(key): mounted[key]=inverse*Vector2(mounted[key])
	for key in ["aim","blade_axis"]:
		if mounted.has(key): mounted[key]=inverse.basis_xform(Vector2(mounted[key])).normalized()
	return mounted
