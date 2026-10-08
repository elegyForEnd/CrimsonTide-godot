extends SceneTree
## Per-weapon contact sheets from the production renderer, with original reach.
const FX=preload("res://scripts/stylized_vfx.gd")
const M=preload("res://scripts/weapon_mechanics.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
const OUT="res://build/weapon-full-audit/"
class DummyField extends Node2D:
	var camera := Vector2(240,180)
class Flights extends CombatVisuals:
	var bullets: Array=[]
	func _ready() -> void:
		field=DummyField.new(); add_child(field)
		# CombatVisuals creates these nodes before _ready; own them even in this probe.
		add_child(stylized); add_child(particles); add_child(energy)
		var body := ShaderMaterial.new(); body.shader=preload("res://resources/stylized_texture.gdshader"); material=body
		spell_light=Node2D.new(); add_child(spell_light)
		var glow := ShaderMaterial.new(); glow.shader=preload("res://resources/weapon_edge_glow.gdshader"); spell_light.material=glow
		spell_light.draw.connect(func():
			for bullet in bullets: draw_run_projectile(spell_light,bullet,true))
	func _process(_dt: float) -> void: pass
	func _draw() -> void:
		for bullet in bullets: draw_run_projectile(self,bullet,false)
class Actor extends Node2D:
	var pose: Dictionary
	var at := Vector2.ZERO
	var facing := 1.0
	func _draw() -> void:
		draw_set_transform(at,0,Vector2(facing,1)); draw_texture_rect(pose.texture,pose.rect,false)
class Board extends Node2D:
	var weapon := 0
	var tiles: Array=[]
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,1950),Color("101722"))
		draw_string(font,Vector2(20,33),"%d · %s · 四角色逐项原比例缩略预览"%[weapon,Catalog.weapon(weapon).name],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
		for tile in tiles:
			draw_rect(Rect2(tile.at,Vector2(350,232)),Color("1b2637"))
			var fit: Vector2=tile.viewport.size
			fit*=minf(340/fit.x,202/fit.y)
			draw_texture_rect(tile.viewport.get_texture(),Rect2(tile.at+Vector2(175,103)-fit*.5,fit),false)
			draw_string(font,tile.at+Vector2(8,222),tile.label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c1cee2"))
var frames := CharacterFrames.new()
var checks := 0
var failures := 0
var records: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func make_tile(board, weapon: int, hero: int, state: int) -> void:
	var spec := Catalog.weapon(weapon)
	var move := WeaponArts.of(weapon)
	var family := Catalog.weapon_family(weapon)
	var direction := Vector2.LEFT if hero==2 else Vector2.RIGHT
	var viewport := SubViewport.new(); viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var reach := float(move.reach) if state==3 else float(spec.reach)
	var span := 480.0 if family in [0,3] else maxf(480,reach*2.6+100)
	if state==3 and move.kind=="beam": span=maxf(480,float(move.reach)+180)
	if state==5 and move.kind=="burst": span=maxf(480,float(move.radius)*2.3)
	viewport.size=Vector2i(int(span),int(span*.75))
	board.add_child(viewport)
	var body := Vector2(span*.5,span*.50)
	if state==3 and move.kind=="beam": body.x=span*.18 if direction.x>0 else span*.82
	var p := {"weapon":weapon,"hero":hero,"swing_total":1.5,"swing_time":1.5-float(spec.windup)-.025,"cast_time":0.0,"strike_aim":direction}
	var actor := Actor.new(); actor.pose=frames.equipped_attack_frame(p); actor.at=body; actor.facing=direction.x; viewport.add_child(actor)
	var tip := frames.equipped_weapon_tip(p)
	var socket := {"tip":body+CharacterMetrics.FOOT_OFFSET+tip*Vector2(direction.x,1),"aim":direction,"active":true}
	var fx := FX.new(); viewport.add_child(fx); fx.socket_provider=func(_id): return socket
	var label: String=["普攻1","普攻2","普攻3","战技","普攻飞行 / 蓄力","战技飞行 / 爆发","命中","蓄力"][state]
	var data := {"kind":"strike","p":body,"aim":direction,"id":1,"weapon":family,"weapon_index":weapon,"reach":spec.reach,"combo":mini(state,2),"pattern":spec.get("pattern","")}
	var expected := true
	if state<=3:
		if state==3:
			data["attack_kind"]=move.kind; data.reach=move.reach; data.combo=2
		fx.event(data,hero)
		if state==3 and move.kind=="beam": fx.event({"kind":"spell_beam","p":body,"aim":direction,"weapon_index":weapon,"reach":move.reach,"width":move.width,"spell":move.spell,"id":1},hero)
	elif state==4 or state==5:
		var spell: String=spec.get("spell","star") if state==4 else move.get("spell","star")
		var count := (5 if spell=="scatter" else 1) if state==4 else int(move.get("count",1))
		if (state==4 and family in [0,3] and spell!="prism") or (state==5 and move.kind=="volley"):
			actor.hide()
			var flights := Flights.new(); viewport.add_child(flights)
			flights.field.camera=body
			for shot in count:
				var aim := direction.rotated((shot-(count-1)*.5)*(.15 if state==4 else .12))
				flights.bullets.append({"p":body+Vector2(0,(shot-(count-1)*.5)*26),"v":aim*700,"weapon_index":weapon,"owner":1,"spell":spell,"height":0})
			label+=" · %d枚"%count
		elif state==5 and move.kind=="burst":
			actor.hide(); fx.event({"kind":"spell_burst","p":body,"aim":direction,"weapon_index":weapon,"radius":move.radius,"spell":spell,"id":1},hero)
		elif state==4 and family==3 and spell=="prism": fx.event({"kind":"spell_beam","p":body-direction*120,"aim":direction,"weapon_index":weapon,"reach":240,"width":30,"spell":spell,"id":1},hero)
		else:
			expected=false; label="— 无独立弹体 / 爆发"
	elif state==6:
		fx.event({"kind":"impact","p":socket.tip+Vector2(0,24),"contact_p":socket.tip,"aim":direction,"weapon":family,"weapon_index":weapon,"heavy":family==2,"id":1,"enemy_id":9},hero)
	else:
		if float(spec.windup)>0: fx.event({"kind":"windup","p":body,"aim":direction,"weapon":family,"weapon_index":weapon,"windup":spec.windup,"id":1},hero)
		else: expected=false; label="— 无蓄力"
	fx.advance(.055 if state!=7 else maxf(.025,float(spec.windup)*.4))
	board.tiles.append({"at":Vector2(5+hero*360,50+state*237),"viewport":viewport,"label":"H%d %s"%[hero,label],"expected":expected,"fx":fx,"state":state,"actor":actor})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1440,1950); root.content_scale_size=root.size
	for weapon in range(21)+range(600,648):
		var board := Board.new(); board.weapon=weapon; root.add_child(board)
		for state in 8:
			for hero in 4: make_tile(board,weapon,hero,state)
		await process_frame; RenderingServer.force_draw(false)
		board.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OUT+"weapon-%03d.png"%weapon)
		for tile in board.tiles: tile.actor.hide()
		await process_frame; RenderingServer.force_draw(false)
		var roles := {}
		for tile in board.tiles:
			if tile.expected: check(tile.viewport.get_texture().get_image().get_used_rect().has_area(),"Effect visible without actor pixels %d %s"%[weapon,tile.label])
			for effect in tile.fx.effects:
				if effect.has("art_role"): roles[effect.art_role]=true
		records.append({"weapon":weapon,"name":Catalog.weapon(weapon).name,"normal":M.normal_role(weapon),"art":M.strike_role(weapon,{"attack_kind":WeaponArts.of(weapon).kind}),"roles":roles.keys(),"cells":32,"image":"weapon-%03d.png"%weapon})
		board.queue_free(); await process_frame; await process_frame
		print("FULL VISUAL weapon ",weapon," captured")
	var file := FileAccess.open(OUT+"coverage.json",FileAccess.WRITE); file.store_string(JSON.stringify({"weapons":records,"checks":checks,"failures":failures},"\t")); file.close()
	print("FULL WEAPON VISUAL ",checks," checks, ",failures," failures; 69 weapons x 4 heroes x 8 states")
	quit(1 if failures else 0)
