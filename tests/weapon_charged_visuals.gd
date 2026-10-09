extends SceneTree
## Actual production renderer, four mouse directions, original authored geometry.
const FX=preload("res://scripts/stylized_vfx.gd")
const Hold=preload("res://scripts/weapon_hold_attack.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
const Mechanics=preload("res://scripts/weapon_mechanics.gd")
const Probe=preload("res://tests/weapon_full_visual_audit.gd")
const OUT="res://build/weapon-charged-audit/"
class Actor extends Node2D:
	var pose: Dictionary
	var at: Vector2
	var facing := 1.0
	func _draw() -> void:
		draw_set_transform(at,0,Vector2(facing,1)); draw_texture_rect(pose.texture,pose.rect,false)
class Board extends Node2D:
	var tiles: Array=[]
	var weapon := 600
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,1520),Color("142030"))
		draw_string(font,Vector2(20,35),"%d · %s · 独立蓄力特效" % [weapon,Catalog.weapon(weapon).name],HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color.WHITE)
		for i in tiles.size():
			var tile: Dictionary=tiles[i]
			var corner := Vector2((i%2)*720,60+(i/2)*720)
			draw_rect(Rect2(corner+Vector2(8,8),Vector2(704,704)),Color("1c2b3e"))
			draw_texture_rect(tile.viewport.get_texture(),Rect2(corner+Vector2(20,20),Vector2(680,680)),false)
			draw_string(font,corner+Vector2(20,695),["右","下","左","上"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
var frames := CharacterFrames.new()
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func tile(board, weapon: int, aim: Vector2) -> Dictionary:
	var move := Hold.profile(weapon)
	var family := Catalog.weapon_family(weapon)
	var span := maxf(900,float(move.reach)+220) if move.kind in ["beam","burst"] else 900.0
	if move.kind=="burst": span+=float(move.radius)*2
	var v := SubViewport.new(); v.size=Vector2i(int(span),int(span)); v.transparent_bg=true; v.render_target_update_mode=SubViewport.UPDATE_ALWAYS; board.add_child(v)
	var body := Vector2.ONE*span*.5
	if move.kind in ["beam","burst"]: body-=aim*float(move.reach)*.5
	var p := {"weapon":weapon,"hero":0,"swing_total":.6,"swing_time":.47,"cast_time":0.0,"strike_aim":aim,"build_strike_kind":move.kind,"build_strike_windup":.12}
	var actor := Actor.new(); actor.pose=frames.equipped_attack_frame(p); actor.at=body; actor.facing=-1.0 if aim.x<0 else 1.0; v.add_child(actor)
	var facing := Vector2(actor.facing,1)
	var aimed := CharacterMetrics.aimed_mount(body+CharacterMetrics.FOOT_OFFSET,actor.pose.grip*facing,actor.pose.socket*facing,aim)
	var mount := {"tip":body+(CharacterMetrics.FOOT_OFFSET+actor.pose.socket)*facing,"grip":body+(CharacterMetrics.FOOT_OFFSET+actor.pose.grip)*facing,"stroke_tip":aimed.tip,"stroke_pivot":aimed.pivot,"aim":aim}
	var fx := FX.new(); v.add_child(fx); fx.socket_provider=func(_id): return mount
	fx.event({"kind":"strike","p":body,"aim":aim,"id":1,"weapon":family,"weapon_index":weapon,"combo":2,"attack_kind":move.kind,"reach":move.reach,"width":move.width,"radius":move.radius,"charged":true})
	if move.kind=="beam": fx.event({"kind":"spell_beam","p":body,"aim":aim,"id":1,"weapon_index":weapon,"reach":move.reach,"width":move.width,"spell":move.spell,"charged":true})
	if move.kind=="burst": fx.event({"kind":"spell_burst","p":body+aim*float(move.reach),"aim":aim,"id":1,"weapon_index":weapon,"radius":move.radius,"spell":move.spell,"charged":true})
	var flights
	if move.kind=="volley":
		flights=Probe.Flights.new(); v.add_child(flights); flights.field.camera=body
		for i in int(move.count):
			var direction := aim.rotated((i-(int(move.count)-1)*.5)*float(move.spread))
			flights.bullets.append({"p":body+direction*150,"v":direction*700,"weapon_index":weapon,"owner":1,"spell":move.spell,"charged":true})
	fx.set_process(false); fx.particles.set_process(false); fx.advance(.10)
	var source := "charged_%d_v1" % weapon
	if move.kind!="volley":
		check(fx.effects.any(func(e): return e.get("art_source","")==source),"Charged paint selected %d" % weapon)
	else:
		check(Art.charged_source(weapon,"projectile","")==source,"Charged flight selected %d" % weapon)
	check(Art.charged_source(weapon,"release" if family in [1,2] else "projectile" if move.kind=="volley" else move.kind,"fallback")==source,"Correct payload %d" % weapon)
	return {"viewport":v,"fx":fx,"source":source,"aim":aim}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1440,1520); root.content_scale_size=root.size
	var sources: Dictionary={}
	var hashes: Dictionary={}
	var alpha_hashes: Dictionary={}
	for index in 17:
		var move := Hold.profile(index)
		var family := Catalog.weapon_family(index)
		var payload: String="release" if family in [1,2] else "projectile" if move.kind=="volley" else str(move.kind)
		check(Art.charged_source(index,payload,"")=="charged_%d_v1" % Art.canonical(index),"Campaign charged move matches shared painting %d" % index)
	var selected: Array=range(600,648)
	var args := OS.get_cmdline_user_args()
	if args.size()>0: selected=[int(args[0])]
	for weapon in selected:
		var source := "charged_%d_v1" % weapon
		Art.load_mechanic_manifest()
		check(Art.mechanics.has(source),"Missing new original %d" % weapon)
		if not Art.mechanics.has(source): continue
		var entry: Dictionary=Art.mechanics[source]
		check(not hashes.has(entry.sha256),"Reused original %d" % weapon); hashes[entry.sha256]=weapon
		check(not alpha_hashes.has(entry.alpha_sha256),"Reused alpha silhouette %d" % weapon); alpha_hashes[entry.alpha_sha256]=weapon
		var wrong: String="projectile" if entry.payload!="projectile" else "burst"
		check(Art.charged_source(weapon,wrong,"fallback")=="fallback","Wrong-payload painting rejected %d" % weapon)
		check(Art.payload_source(weapon,entry.payload,"projectile_star")!=source,"Ordinary payload keeps original painting %d" % weapon)
		var image := Art.mechanic_texture(source).get_image()
		var ink := Art.mechanic_ink(source)
		check(image!=null and ink.size.x>0 and ink.size.y>0,"Readable alpha ink %d" % weapon)
		var normal := Mechanics.normal_role(weapon)
		check(Art.release_source(weapon,normal,0,false)!=source,"Tap cannot select charged paint %d" % weapon)
		var board := Board.new(); board.weapon=weapon; root.add_child(board)
		for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]: board.tiles.append(tile(board,weapon,direction))
		await process_frame; RenderingServer.force_draw(false)
		board.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"weapon-%d.png" % weapon)
		sources[str(weapon)]={"source":source,"payload":entry.payload,"plane":entry.plane,"file":entry.file}
		board.queue_free(); await process_frame
	var file := FileAccess.open(OUT+"coverage.json",FileAccess.WRITE); file.store_string(JSON.stringify({"weapons":sources,"checks":checks,"failures":failures},"\t")); file.close()
	print("CHARGED VISUALS: %d checks; %d failures" % [checks,failures]); quit(1 if failures else 0)
