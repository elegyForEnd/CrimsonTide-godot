extends SceneTree
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
const Paint=preload("res://scripts/weapon_hybrid_material.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var identities := {}
	var families := {}
	for weapon in range(600,648)+[17,18,19,20]:
		for action in ["normal","heavy","art"]:
			var profile := Profiles.action_profile(weapon,"",action)
			var mat := Paint.material(profile)
			var identity: Texture2D=mat.get_shader_parameter("identity_texture")
			var detail: Texture2D=mat.get_shader_parameter("painted_detail")
			identities[identity.resource_path]=true
			families[Paint.material_key(profile)]=true
			check(identity!=null and detail!=null,"Every weapon/action has both an identity surface and a painted material")
			check(Paint.manifest.has(Paint.material_key(profile)),"No weapon silently uses a missing family texture")
			check(not identity.resource_path.begins_with("res://art/") and not detail.resource_path.begins_with("res://art/"),"A complete reference screenshot never enters runtime")
			var rect: Vector4=mat.get_shader_parameter("identity_rect")
			check(rect.x>=0 and rect.y>=0 and rect.z>0 and rect.w>0 and rect.x+rect.z<=1.001 and rect.y+rect.w<=1.001,"Measured UVs stay inside the original source")
	check(identities.size()==52,"52 identities retain 52 independent original material surfaces")
	check(families.size()==15,"All fifteen material vocabularies are present")
	for row in Paint.manifest.values():
		var texture: Texture2D=load(str(row.file))
		var image := texture.get_image()
		check(image!=null and image.has_mipmaps(),"Painted originals have stable reduced-size sampling")
	print("WEAPON HYBRID MATERIALS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
