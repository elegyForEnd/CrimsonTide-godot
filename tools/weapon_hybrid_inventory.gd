extends SceneTree
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
const Mechanics=preload("res://scripts/weapon_mechanics.gd")
const Paint=preload("res://scripts/weapon_hybrid_material.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
func _initialize() -> void:
	var inventory: Array=[]
	for weapon in range(600,648)+[17,18,19,20]:
		var profile := Profiles.profile(weapon)
		var mat := Paint.material(profile)
		var item := {"weapon":weapon,"name":Catalog.weapon(weapon).name,"material":Paint.material_key(profile),"surface":mat.get_shader_parameter("identity_texture").resource_path,"paint":mat.get_shader_parameter("painted_detail").resource_path,"payloads":{}}
		var impact_key := Paint.impact_key(profile)
		if Paint.manifest.has(impact_key): item["impact"]=Paint.manifest[impact_key].file
		if weapon==600:
			item.paint="res://assets/combat/crystal-cut-v1/ribbon.png"
			item.surface="res://assets/combat/crystal-cut-v1/shard.png"
		for action in ["normal","heavy","art"]:
			var move: Dictionary=preload("res://scripts/weapon_hold_attack.gd").profile(weapon) if action=="heavy" else WeaponArts.of(weapon)
			if Catalog.weapon_family(weapon) not in [0,3]: continue
			if action!="normal" and str(move.kind)!="volley": continue
			var spell := str(Catalog.weapon(weapon).get("spell","star")) if action=="normal" else str(move.get("spell",Catalog.weapon(weapon).get("spell","star")))
			if spell=="prism": continue
			var role := Mechanics.projectile_role(weapon,spell)
			var source := Art.payload_source(weapon,"projectile",role)
			if action=="heavy": source=Art.charged_source(weapon,"projectile",source)
			var texture: Texture2D=Art.mechanic_texture(source)
			if texture!=null: item.payloads[action]=texture.resource_path
		inventory.append(item)
	FileAccess.open("res://build/vfx-hybrid/inventory.json",FileAccess.WRITE).store_string(JSON.stringify(inventory,"\t"))
	print("HYBRID INVENTORY ",inventory.size())
	quit()
