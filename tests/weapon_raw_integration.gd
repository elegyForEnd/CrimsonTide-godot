extends SceneTree
const Atlases=preload("res://scripts/weapon_atlas_frames.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
const Mechanics=preload("res://scripts/weapon_mechanics.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var library := Atlases.new()
	var frames := CharacterFrames.new()
	check(library.manifest.size()==192,"Four heroes each have 48 equipped atlases")
	for hero in 4:
		for weapon in range(600,648):
			var atlas: Dictionary=library.manifest[library.atlas_key(hero,weapon)]
			for state in ["idle","walk","run","dodge","attack","art"]:
				check(library.count(hero,weapon,state)==4,"Every equipped state has four keys")
				var ground: float=atlas.states[state][0].pivot[1]
				for index in 4:
					var pose := library.frame(hero,weapon,state,index,frames.walk_height(hero))
					var texture: AtlasTexture=pose.texture
					check(texture.atlas!=null,"Source imports and loads")
					check(Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region),"Frame stays within source")
					check(pose.weapon_identity==weapon and pose.state==state and pose.frame==index,"State and weapon identity survive selection")
					if not (hero==0 and weapon<=602 and state=="attack"):
						check(atlas.states[state][index].pivot[1]==ground,"Clip uses one ground plane")
				var p := {"hero":hero,"weapon":weapon,"swing_total":.42,"swing_time":.42,"cast_time":0.0,"build_strike_windup":.1}
				if state in ["attack","art"]:
					var previous := -1
					for tick in 43:
						var elapsed := tick*.01
						p.swing_time=.42-elapsed
						var index := library.attack_index(p,state)
						check(index>=previous and index<4,"Attack keys remain chronological")
						check(index<2 if elapsed<.1-.00001 else index>=2,"Contact follows actual windup")
						previous=index
			# Release texture references between weapons to bound this test's memory.
			library.poses.clear()
		for alias in range(17):
			check(library.count(hero,alias,"idle")==4,"Same-name expedition aliases resolve")
		if hero>0:
			check(library.manifest["%d/625"%hero].states.attack==library.manifest["%d/628"%hero].states.attack,"Bow category shares character motion")
			check(library.manifest["%d/624"%hero].states.attack!=library.manifest["%d/627"%hero].states.attack,"Rifle and pistol motion differ")
	var fx := FX.new(); root.add_child(fx)
	for weapon in range(600,648):
		var normal := Art.release_source(weapon,Mechanics.normal_role(weapon),0)
		check(Art.mechanic_texture(normal)!=null,"All normal effects resolve")
		if weapon in range(603,612) or weapon in [621,622]:
			var role := Mechanics.strike_role(weapon,{"attack_kind":WeaponArts.of(weapon).kind})
			fx.reset()
			fx.event({"kind":"strike","p":Vector2.ZERO,"weapon_index":weapon,"weapon":Catalog.weapon_family(weapon),"attack_kind":WeaponArts.of(weapon).kind,"reach":WeaponArts.of(weapon).reach})
			check(fx.effects[0].art_source=="authored_%d_art"%weapon,"Weapon art consumes its unique painting")
			check(fx.effects[0].art_role==role,"Unique painting preserves authoritative motion")
		if weapon>=624 and weapon!=641:
			var source := Art.payload_source(weapon,"projectile",Mechanics.projectile_role(weapon,"star"))
			check(source=="authored_%d_projectile"%weapon and Art.mechanic_texture(source)!=null,"Concrete projectile consumes its original")
		for payload in ["beam","burst"]:
			var source := Art.payload_source(weapon,payload,"projectile_star")
			if source.begins_with("authored_"):
				fx.reset()
				fx.event({"kind":"spell_beam" if payload=="beam" else "spell_burst","p":Vector2.ZERO,"weapon_index":weapon,"weapon":3,"reach":200,"radius":100})
				check(fx.effects[0].art_source==source,"Actual spell event selects concrete payload")
				check(Art.mechanic_texture(source)!=null,"Concrete spell payload loads")
	check(Art.release_source(1,Mechanics.normal_role(1),0)==Art.release_source(600,Mechanics.normal_role(600),0),"Expedition alias shares normal VFX")
	fx.queue_free()
	await process_frame
	print("RAW WEAPON INTEGRATION %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
