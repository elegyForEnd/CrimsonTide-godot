extends SceneTree
## Production renderer contact sheets. Run with a real renderer, not --headless.
const FX=preload("res://scripts/stylized_vfx.gd")
const Finish=preload("res://scripts/combat_finish.gd")
const Flights=preload("res://tests/weapon_full_visual_audit.gd").Flights
const Frames=preload("res://scripts/character_frames.gd")
const OUT="res://build/vfx-v2/"
const WORLD=Vector2i(1024,600)
const PAGE=Vector2i(2400,3420)
const CELL=Vector2(408,262)
const HEADERS=["普攻释放 · 0.055s","真实战技 · 完整释放 / 载荷","有效普攻载荷 · 飞行 / 光束","真实命中 · 0.040s","命中余韵 · 0.200s"]
var frames=Frames.new()
var records: Array=[]
var checks := 0
var failures := 0

class Actor extends Node2D:
	var pose: Dictionary
	var at := Vector2.ZERO
	func _draw() -> void:
		draw_set_transform(at)
		draw_texture_rect(pose.texture,pose.rect,false,Color(.68,.72,.78,.72))
		draw_set_transform(Vector2.ZERO)
		# Feet marker is a positional reference, not a damage boundary.
		draw_line(at+Vector2(-12,0),at+Vector2(12,0),Color(.4,.45,.5,.55),1)

class Board extends Node2D:
	var page := 0
	var tiles: Array=[]
	var rows: Array=[]
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(PAGE)),Color("0d141d"))
		draw_string(font,Vector2(24,40),"武器特效 V2 · %d / 4 · 生产贴图 / 材质流动 / 命中分层" % (page+1),HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("e6edf4"))
		draw_string(font,Vector2(24,70),"统一世界视口 1024 × 600，所有格同倍率；保留真实 reach / count / spell；角色为低亮位置参考，无伤害圈。",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("8a9dac"))
		for col in 5:
			draw_string(font,Vector2(265+col*420,105),HEADERS[col],HORIZONTAL_ALIGNMENT_LEFT,408,17,Color("bfd0df"))
		for row in rows:
			var at := Vector2(18,124+row.number*272)
			draw_string(font,at+Vector2(0,30),"%d · %s" % [row.weapon,row.name],HORIZONTAL_ALIGNMENT_LEFT,232,18,Color("e7edf4"))
			draw_string(font,at+Vector2(0,58),row.art,HORIZONTAL_ALIGNMENT_LEFT,232,14,Color("9ab1c3"))
			draw_string(font,at+Vector2(0,82),"%s / %s" % [row.kind,row.material],HORIZONTAL_ALIGNMENT_LEFT,232,13,Color("7b929f"))
		for tile in tiles:
			draw_rect(Rect2(tile.at,CELL),Color("182431"))
			# Every viewport has exactly the same world size and display scale.
			var size := Vector2(WORLD)*(408.0/WORLD.x)
			draw_texture_rect(tile.viewport.get_texture(),Rect2(tile.at+Vector2(0,1),size),false)
			draw_string(font,tile.at+Vector2(8,256),tile.label,HORIZONTAL_ALIGNMENT_LEFT,392,13,Color("a8bac8"))

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)

func add_actor(viewport: SubViewport, weapon: int, origin: Vector2, art_kind: String="") -> Dictionary:
	var spec := Catalog.weapon(weapon)
	var player := {"weapon":weapon,"hero":0,"swing_total":1.5,"swing_time":1.5-float(spec.windup)-.025,"cast_time":0.0,"strike_aim":Vector2.RIGHT}
	if not art_kind.is_empty(): player["build_strike_kind"]=art_kind
	var actor := Actor.new()
	actor.pose=frames.equipped_attack_frame(player); actor.at=origin
	viewport.add_child(actor)
	var tip := frames.equipped_weapon_tip(player)
	var grip: Vector2=actor.pose.get("grip",tip)
	var mount := CharacterMetrics.aimed_mount(origin+CharacterMetrics.FOOT_OFFSET,grip,tip,Vector2.RIGHT)
	return {"tip":origin+CharacterMetrics.FOOT_OFFSET+tip,"grip":origin+CharacterMetrics.FOOT_OFFSET+grip,
		"stroke_tip":mount.tip,"stroke_pivot":mount.pivot,"aim":Vector2.RIGHT,"active":true,"_actor":actor}

func add_flights(viewport: SubViewport, weapon: int, spell: String, count: int, origin: Vector2) -> Dictionary:
	var flights := Flights.new(); viewport.add_child(flights)
	flights.field.camera=origin
	var finish=Finish.new(); viewport.add_child(finish)
	var speed := float(Catalog.weapon(weapon).get("speed",700))
	var travel := minf(340,speed*.28)
	var bullets: Array=[]
	for shot in count:
		var direction := Vector2.RIGHT.rotated((shot-(count-1)*.5)*.12)
		var bullet := {"fx_id":shot+1,"p":origin+direction*travel,"v":direction*speed,"weapon_index":weapon,"owner":1,"spell":spell,"height":0}
		bullets.append(bullet)
	# Supply actual sampled positions to the production stable-ID trail observer.
	for sample in 6:
		var snapshot: Array=[]
		for bullet in bullets:
			var observed: Dictionary=bullet.duplicate(true)
			observed.p=bullet.p-bullet.v*(.10-sample*.02)
			snapshot.append(observed)
		finish.observe(snapshot,.02); finish.advance(.02)
	flights.bullets=bullets
	flights.queue_redraw(); flights.spell_light.queue_redraw()
	var role := preload("res://scripts/weapon_mechanics.gd").projectile_role(weapon,spell)
	var source := preload("res://scripts/weapon_image_art.gd").payload_source(weapon,"projectile",role)
	return {"role":role,"source":source,"count":count,"kind":"projectile","finish":finish}

func spell_event(fx: Node2D, weapon: int, kind: String, spell: String, origin: Vector2, reach: float, radius: float, width: float) -> void:
	fx.event({"kind":"spell_beam" if kind=="beam" else "spell_burst","p":origin,"aim":Vector2.RIGHT,"weapon_index":weapon,"weapon":Catalog.weapon_family(weapon),"reach":reach,"radius":radius,"width":width,"spell":spell,"id":1},0)

func make_tile(board: Node2D, weapon: int, row: int, column: int) -> void:
	var spec := Catalog.weapon(weapon)
	var move := WeaponArts.of(weapon)
	var family := Catalog.weapon_family(weapon)
	var viewport := SubViewport.new()
	viewport.size=WORLD; viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	board.add_child(viewport)
	var origin := Vector2(230,360)
	var socket := add_actor(viewport,weapon,origin,str(move.kind) if column==1 else "")
	var fx=FX.new(); viewport.add_child(fx)
	fx.socket_provider=func(_source): return socket
	var label := ""
	var payload: Dictionary={}
	var expected := true
	var base := {"kind":"strike","p":origin,"aim":Vector2.RIGHT,"id":1,"weapon":family,"weapon_index":weapon,"reach":spec.reach,"combo":0,"pattern":spec.get("pattern","")}
	if column==0:
		fx.event(base,0)
		label="普攻 · "+preload("res://scripts/weapon_mechanics.gd").normal_role(weapon)
	elif column==1:
		base["attack_kind"]=move.kind; base.reach=move.reach; base["radius"]=move.radius; base["width"]=move.width
		fx.event(base,0)
		var spell := str(move.get("spell",spec.get("spell","star")))
		label=str(move.kind)
		if move.kind=="volley":
			payload=add_flights(viewport,weapon,spell,int(move.get("count",1)),origin-Vector2(0,24))
			label+=" · %d 枚 %s" % [payload.count,spell]
		elif move.kind=="beam":
			spell_event(fx,weapon,"beam",spell,origin,float(move.reach),float(move.radius),float(move.width))
			label+=" · %.0f / 宽 %.0f" % [move.reach,move.width]
		elif move.kind=="burst":
			# The target owns the explosion; it is not attached to the casting hand.
			var target := origin+Vector2.RIGHT*float(move.reach)
			spell_event(fx,weapon,"burst",spell,target,float(move.reach),float(move.radius),float(move.width))
			label+=" · 落点 R%.0f %s" % [move.radius,spell]
		else: label+=" · reach %.0f" % move.reach
	elif column==2:
		if family in [0,3]:
			var spell := str(spec.get("spell","bullet" if family==0 else "star"))
			if spell=="prism":
				spell_event(fx,weapon,"beam",spell,origin,float(spec.reach),100,30)
				label="瞬时贯通 · %.0f" % spec.reach
			else:
				var count := 5 if spell=="scatter" else 1
				payload=add_flights(viewport,weapon,spell,count,origin-Vector2(0,24))
				label="%s · %d 枚 / 实际弹体尺寸" % [spell,count]
		else:
			expected=false; label="— 近战无独立飞行载荷"
	else:
		# A valid impact event drives the same production flash, fragments and mist.
		var hit := {"kind":"impact","p":Vector2(480,370),"contact_p":Vector2(480,341),"contact_lift":0.0,"aim":Vector2.RIGHT,"weapon":family,"weapon_index":weapon,"heavy":family==2,"damage":20.0,"id":1,"enemy_id":9}
		fx.event(hit,0)
		var finish=Finish.new(); viewport.add_child(finish)
		finish.event(hit)
		finish.advance(.04 if column==3 else .20)
		label="有效 impact · %s" % ("峰值 + 材质雾" if column==3 else "碎片 / 烟雾 / 余韵")
	fx.advance(.04 if column==3 else .20 if column==4 else .055)
	fx.set_process(false)
	var sources: Array=[]
	for effect in fx.effects:
		if effect.has("art_source"): sources.append({"role":effect.get("art_role",""),"source":effect.art_source})
	var tile := {"at":Vector2(260+column*420,124+row*272),"viewport":viewport,"label":label,"expected":expected,"fx":fx,"payload":payload,"weapon":weapon,"column":column,"sources":sources,"actor":socket._actor}
	board.tiles.append(tile)
	records.append({"weapon":weapon,"name":spec.name,"page":board.page,"column":column,"action":label,"sources":sources,"payload_role":payload.get("role",""),"payload_source":payload.get("source",""),"world_size":[WORLD.x,WORLD.y],"image":"overview-%d.png" % board.page})

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size=PAGE; root.content_scale_size=PAGE
	for page in 4:
		var board := Board.new(); board.page=page; root.add_child(board)
		for row in 12:
			var weapon := 600+page*12+row
			var move := WeaponArts.of(weapon)
			board.rows.append({"number":row,"weapon":weapon,"name":Catalog.weapon(weapon).name,"art":move.name,"kind":move.kind,"material":preload("res://scripts/weapon_effect_profiles.gd").profile(weapon).material})
			for column in 5: make_tile(board,weapon,row,column)
		# Keep the font owned by Board and allow all SubViewports six rendered frames.
		for frame in 6:
			board.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUT+"overview-%d.png" % page)==OK,"Overview page saves successfully")
		for tile in board.tiles: tile.actor.hide()
		for frame in 6: await process_frame; await RenderingServer.frame_post_draw
		for tile in board.tiles:
			if not str(tile.payload.get("source","")).is_empty():
				check(preload("res://scripts/weapon_image_art.gd").mechanic_texture(tile.payload.source)!=null,"Actual flight source resolves: "+str(tile.weapon))
			check(tile.viewport.size==WORLD,"Every tile retains identical world-to-screen scale")
			var pixels: Image=tile.viewport.get_texture().get_image()
			if tile.expected:
				check(pixels.get_used_rect().has_area(),"Visible production effect independent of actor pixels: %d / %d" % [tile.weapon,tile.column])
			else: check(not pixels.get_used_rect().has_area(),"No fabricated projectile in a melee payload tile")
		board.queue_free(); await process_frame; await process_frame
		print("VFX V2 OVERVIEW page ",page," captured: weapons ",600+page*12,"–",611+page*12)
	FileAccess.open(OUT+"coverage.json",FileAccess.WRITE).store_string(JSON.stringify({"weapons":48,"pages":4,"columns":HEADERS,"tiles":records,"checks":checks,"failures":failures},"\t"))
	print("VFX V2 PREVIEW ",checks," checks, ",failures," failures; 48 weapons, 240 production-rendered tiles")
	quit(1 if failures else 0)
