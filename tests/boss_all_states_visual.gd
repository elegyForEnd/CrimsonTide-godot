extends SceneTree
const Choreo=preload("res://scripts/boss_choreography.gd")
const Art=preload("res://scripts/boss_effect_art.gd")
const Visual=preload("res://scripts/boss_damage_visual.gd")
var s: TideSession
var field: Node2D
var visual: Node2D
var bodies=preload("res://scripts/enemy_body.gd").new()
var sprites: Dictionary={}
class Rogue extends RefCounted:
	func active(_s) -> bool: return false
class Proxy extends RefCounted:
	var raid: Dictionary={"hazards":[]}
	var enemies: Array=[]
	var bullets: Array=[]
	var roguelike=Rogue.new()
class Field extends Node2D:
	var camera=Vector2.ZERO
	var session=Proxy.new()
func _initialize() -> void: call_deferred("run")
func fixture(key: String, slot: int, at: Vector2) -> Dictionary:
	var identity: String=Choreo.TIMELINE_BASE.get(key,key)
	var e := {"id":900,"p":at,"hp":5000.0,"max_hp":5000.0,"type":4,"last":1,"phase":2,"sequence":0,"cd":0.0,"stagger":0.0,"attack_time":0.0,"attack_total":0.0,"facing":1.0,"flash":0.0,"motion_phase":0.0,"moving":false,"guard_time":0.0,"art_key":identity,"boss_name":identity}
	if key in ["grove","furnace","astral","wing","obsidian","rq_bell","rq_earth","rq_abyss"]:
		e.merge({"rogue_guardian":true,"rogue_skin":0,"boss_art":Art.ROGUE.find(identity),"boss_skill":slot,"choreo_key":key})
	else:
		match identity:
			"bell","thorn","queen": e["raid_boss"]=true; e["boss_kind"]=["bell","thorn","queen"].find(identity)
			"hidden": e["raid_boss"]=true; e["boss_kind"]=2; e["hidden_final"]=true
			"moon": e["raid_boss"]=true; e["boss_kind"]=2; e["final_form"]=true
			"mirror","ember": e["mini_boss"]=true; e["boss_kind"]=0; e["mini_kind"]=["mirror","ember"].find(identity)
			"earth","storm","abyss": e["mini_boss"]=true; e["boss_kind"]=2; e["wild_boss"]=true; e["wild_kind"]=["earth","storm","abyss"].find(identity)
			"dragon": e["mini_boss"]=true; e["boss_kind"]=3; e["dragon_boss"]=true
	s.enemies=[e]; return e
func step(to: float, e: Dictionary) -> void:
	while float(e.choreo_elapsed)<to-.0001:
		var dt := minf(.02,to-float(e.choreo_elapsed))
		Choreo.advance(s,dt)
		e.attack_time=maxf(0,float(e.attack_total)-float(e.choreo_elapsed))
		s.expedition.update_hazards(s,dt); s.roguelike.combat.tick(s,dt); s.update_bullets(dt)
		refresh(dt)
func refresh(dt: float) -> void:
	field.session.raid.hazards=s.raid.hazards.duplicate()
	field.session.raid.hazards.append_array(s.roguelike.combat.effects)
	field.session.enemies=s.enemies; field.session.bullets=s.bullets
	for sprite in sprites.values(): sprite.visible=false
	for e in s.enemies:
		if e.get("boss_construct",false): continue
		if not sprites.has(e.id):
			var sprite := Sprite2D.new(); sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; field.add_child(sprite); sprites[e.id]=sprite
		var sprite: Sprite2D=sprites[e.id]; sprite.visible=true
		var body: Dictionary=bodies.pose(e,float(e.get("choreo_elapsed",0)),bool(e.get("rogue_guardian",false)))
		sprite.texture=body.texture; sprite.region_enabled=body.region.size!=Vector2.ZERO; sprite.region_rect=body.region
		var size: Vector2=body.region.size if body.region.size!=Vector2.ZERO else body.texture.get_size()
		sprite.scale=body.rect.size/size*Vector2(float(body.facing),1)
		sprite.position=visual.transform*e.p+body.rect.get_center()*Vector2(float(body.facing),1)
	visual._process(dt)
func capture(key: String, slot: int, state: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/boss-all-states-v5/%s-%02d-%s.png" % [key,slot,state])
func run() -> void:
	root.size=Vector2i(1280,800); root.content_scale_size=Vector2i(1280,800)
	s=TideSession.new(); root.add_child(s); s.solo({"hero":0}); s.launch(false,1729); s.set_physics_process(false); s.raid.floor=1
	s.players[1].invuln=9999
	field=Field.new(); root.add_child(field)
	var bg := ColorRect.new(); bg.size=Vector2(1280,800); bg.color=Color("18202a"); field.add_child(bg)
	var title := Label.new(); title.position=Vector2(40,32); title.add_theme_font_size_override("font_size",26); field.add_child(title)
	visual=Visual.new(); visual.field=field; field.add_child(visual); visual.set_process(false); visual.z_index=2
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/boss-all-states-v5"))
	var total := 0
	var start: Vector2=s.players[1].p+Vector2(100,0)
	for key in Choreo.MOVES:
		for slot in Choreo.MOVES[key].size():
			s.enemies=[]; s.bullets=[]; s.raid.hazards=[]; s.roguelike.combat.reset(); visual.reset()
			var e := fixture(key,slot,start)
			field.camera=start+Vector2(130,0)
			visual.transform=Transform2D(Vector2(1,0),Vector2(0,.68),Vector2(490,530)-Vector2(start.x,start.y*.68))
			Choreo.start(s,e,str(Choreo.MOVES[key][slot]),Vector2.RIGHT,start+Vector2(180,0))
			var impact := INF
			var records: Array=s.raid.hazards.duplicate(); records.append_array(s.roguelike.combat.effects)
			for h in records:
				if float(h.damage)>0: impact=minf(impact,float(h.get("windup",h.get("total",.8))))
			if not is_finite(impact): impact=float(e.windup)
			title.text=key+" / "+str(slot+1)+" / "+str(e.move_name)+" / PREPARE"
			step(maxf(.01,impact-.14),e); await capture(key,slot,"prepare")
			title.text=key+" / "+str(slot+1)+" / "+str(e.move_name)+" / CONTACT"
			step(impact+.045,e); await capture(key,slot,"contact")
			title.text=key+" / "+str(slot+1)+" / "+str(e.move_name)+" / SUSTAIN"
			step(minf(float(e.attack_total)-.1,impact+.50),e); await capture(key,slot,"sustain")
			title.text=key+" / "+str(slot+1)+" / "+str(e.move_name)+" / RECOVER (NO DAMAGE)"
			s.raid.hazards=[]; s.roguelike.combat.effects=[]; s.bullets=[]
			for prop in s.enemies:
				if prop.get("boss_construct",false): prop.hp=0
			refresh(.12); await capture(key,slot,"recover")
			total+=1
		print("STATE RENDER ",key," complete")
	field.queue_free(); s.queue_free(); await process_frame
	print("ALL BOSS STATES: ",total," moves, ",total*4," real rendered state captures")
	quit()
