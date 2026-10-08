extends SceneTree
const Art=preload("res://scripts/weapon_image_art.gd")
const M=preload("res://scripts/weapon_mechanics.gd")
const Atlas=preload("res://scripts/weapon_atlas_frames.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var library := Atlas.new()
	var rows := []
	for id in range(600,648):
		var w := Catalog.weapon(id)
		var normal := M.normal_role(id)
		var art_role := M.strike_role(id,{"attack_kind":w.art.kind})
		var heroes := {}
		for hero in 4:
			var states := {}
			for state in ["idle","walk","run","dodge","attack","art"]:
				states[state]=library.count(hero,id,state)
			heroes[str(hero)]=states
		var projectile := M.projectile_role(id,str(w.spell))
		var burst := M.burst_role(id,str(w.spell))
		rows.append({"id":id,"name":w.name,"family":Catalog.weapon_family(id),"normal_role":normal,"normal_source":Art.release_source(id,normal,0),"art":w.art,"art_role":art_role,"art_source":Art.release_source(id,art_role,0,true),"projectile_role":projectile,"projectile_source":Art.payload_source(id,"projectile",projectile),"burst_role":burst,"burst_source":Art.payload_source(id,"burst",burst),"characters":heroes})
	var output := FileAccess.open("res://build/weapon-asset-inventory.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(rows,"\t"))
	print("Recorded concrete source/state coverage for all 48 weapons and 4 heroes")
	quit()
