extends Node2D
## One released painting owns its material phase; source UVs and anchors stay intact.
var host: Node2D
var effect: Dictionary={}
var glow: Node2D
var surface_material: ShaderMaterial
var glow_material: ShaderMaterial
var mist: Node2D
var ribbon: Node2D
const Art=preload("res://scripts/weapon_image_art.gd")

func _ready() -> void:
	surface_material=ShaderMaterial.new()
	surface_material.shader=preload("res://resources/vfx_release.gdshader")
	material=surface_material
	glow=Node2D.new()
	glow_material=ShaderMaterial.new()
	glow_material.shader=preload("res://resources/vfx_release_glow.gdshader")
	glow.material=glow_material
	glow.draw.connect(func():
		if is_instance_valid(host) and not effect.is_empty(): host.draw_mechanic(glow,effect,true))
	add_child(glow)
	setup_footprint()
	# A dim moving density layer carries the material; the original painting is
	# the short readable edge. Both share the captured release transform.
	if effect.has("art_role") and effect.has("identity"):
		if preload("res://scripts/weapon_motion_ribbon.gd").supported(effect):
			ribbon=preload("res://scripts/weapon_motion_ribbon.gd").new()
			ribbon.host=host; ribbon.effect=effect
			add_child(ribbon)
		mist=preload("res://scripts/weapon_release_mist.gd").new()
		mist.host=host; mist.effect=effect
		add_child(mist)
	sync()

func setup_footprint() -> void:
	Art.load_mechanic_manifest()
	var source := str(effect.get("art_source",""))
	var revised := source.begins_with("renewal_") or str(Art.mechanics.get(source,{}).get("vfx_version",""))=="layered-v2"
	var clipped := revised and str(effect.get("art_role","")) in ["motion_spin","motion_heavy_spin","motion_quake"]
	if not clipped: return
	var texture := Art.mechanic_texture(source)
	if texture==null: return
	var ink := Art.mechanic_ink(source)
	var extent := texture.get_size()
	# The body-centered painter fits inside 2*reach. Clip source alpha before
	# projection so new open folds/fissures cannot extend past its real footprint.
	var radius_uv := Vector2.ONE*maxf(ink.size.x,ink.size.y)*.5/extent
	for shader_material in [surface_material,glow_material]:
		shader_material.set_shader_parameter("clip_footprint",true)
		shader_material.set_shader_parameter("footprint_center",ink.get_center()/extent)
		shader_material.set_shader_parameter("footprint_radius_uv",radius_uv)

func sync() -> void:
	var age := float(effect.get("age",-1.0))
	var life := maxf(.00001,float(effect.get("life",.00001)))
	var phase := clampf(age/life,0.0,1.0)
	var lifetime := maxf(life,float(effect.get("mist_life",life))) if is_instance_valid(mist) else life
	visible=not effect.is_empty() and age>=0.0 and age<lifetime
	if surface_material: surface_material.set_shader_parameter("effect_phase",phase)
	if glow_material: glow_material.set_shader_parameter("effect_phase",phase)
	if is_instance_valid(mist): mist.sync()
	if is_instance_valid(ribbon): ribbon.sync()
	queue_redraw()
	if is_instance_valid(glow): glow.queue_redraw()

func _draw() -> void:
	if is_instance_valid(host) and not effect.is_empty(): host.draw_mechanic(self,effect,false)
