extends SceneTree
## Verify source identity before tinting, and real dimensions through live events.
const Art=preload("res://scripts/weapon_image_art.gd")
const M=preload("res://scripts/weapon_mechanics.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var fx := FX.new(); root.add_child(fx)
	var sources := {}
	var shapes := {}
	for id in range(600,648):
		var w := Catalog.weapon(id)
		var radii := {}
		for stage in 3:
			fx.reset()
			fx.event({"kind":"strike","p":Vector2(200,200),"aim":Vector2.RIGHT,"weapon_index":id,"weapon":Catalog.weapon_family(id),"combo":stage,"reach":w.reach})
			var effect: Dictionary=fx.effects[0]
			var source: String=effect.get("art_source","")
			check(source.begins_with("weapon_") or source.begins_with("identity_"),"Weapon %d stage %d consumes authored identity, not a tinted generic"%[id,stage])
			check(effect.art_role==M.normal_role(id),"Painting preserves authoritative attack role")
			check(Art.mechanic_texture(source)!=null,"Chosen authored original is imported")
			radii[float(effect.radius)]=true
			if stage==0:
				sources[source]=true
				var image := Art.mechanic_texture(source).get_image()
				# Alpha silhouette alone excludes differences caused only by RGB palette.
				image.resize(64,64,Image.INTERPOLATE_BILINEAR)
				var alpha := PackedByteArray()
				for y in 64:
					for x in 64: alpha.append(roundi(image.get_pixel(x,y).a*255))
				shapes[hash(alpha)]=true
		if Catalog.weapon_family(id) in [1,2]: check(radii.size()==1,"Normal combo never expands actual attack reach")
	check(sources.size()==48,"All 48 weapons have different consumed source images")
	check(shapes.size()==48,"All 48 source alpha silhouettes differ before color or particles")
	for id in [610,612,618,623]:
		for stage in 3:
			check(Art.release_source(id,M.normal_role(id),stage)=="identity_%d_cut_v2"%id,"Audited blade cut is consumed in every stage")
	for id in [637,639]:
		check(Art.payload_source(id,"burst",M.burst_role(id,str(Catalog.weapon(id).spell)))=="audit_%d_burst_v2"%id,"Audited area burst replaces the vortex painting")
	for pair in [[13,602],[12,601],[2,612],[0,624]]:
		check(Art.release_source(pair[0],M.normal_role(pair[0]),0)==Art.release_source(pair[1],M.normal_role(pair[1]),0),"Same weapon name shares compatible painting across modes")
	check(Art.release_source(15,M.normal_role(15),0)!=Art.release_source(614,M.normal_role(614),0),"Campaign ground slam and run spin keep different motion paintings")
	fx.queue_free(); await process_frame
	print("AUTHORED WEAPON IDENTITY ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
