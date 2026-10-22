extends SceneTree
## Actual spatial VFX capture: the same world renderers used by both modes.
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
const Flights=preload("res://scripts/weapon_projectile_vfx_3d.gd")
const Frames=preload("res://scripts/character_frames.gd")
const OUT="res://build/vfx-3d/"
const TILE=Vector2i(480,340)
var tiles: Array=[]
var frames=Frames.new()
var checks := 0
var failures := 0
var full_preview := false
class Board extends Node2D:
	var tiles: Array=[]
	var font: Font=load("res://assets/NotoSansSC.ttf")
	var caption := ""
	func _draw() -> void:
		draw_rect(Rect2(0,0,1920,1150),Color("0c111a"))
		draw_string(font,Vector2(20,34),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e1edf5"))
		for tile in tiles:
			var at: Vector2=tile.at
			draw_texture_rect(tile.view.get_texture(),Rect2(at,Vector2(TILE)),false)
			draw_string(font,at+Vector2(12,322),"%d · %s" % [tile.weapon,Catalog.weapon(tile.weapon).name],HORIZONTAL_ALIGNMENT_LEFT,460,18,Color("dce9ee"))
			draw_string(font,at+Vector2(12,301),str(tile.mode),HORIZONTAL_ALIGNMENT_LEFT,460,14,Color("98b1c2"))
func _initialize() -> void: call_deferred("run")
func create_tile(weapon: int,number: int,board: Board) -> Dictionary:
	var view := SubViewport.new(); view.size=TILE; view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var world := Node3D.new(); view.add_child(world)
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=6.5; world.add_child(camera)
	var focus_x := 0.0
	if full_preview:
		var normal := Catalog.weapon(weapon)
		var art := WeaponArts.of(weapon)
		var heavy := preload("res://scripts/weapon_hold_attack.gd").profile(weapon)
		var reach := maxf(float(normal.reach),maxf(float(art.reach),float(heavy.reach)))
		var surrounding: bool=str(art.kind)=="circle" or str(heavy.kind)=="circle" or str(normal.get("pattern","")) in ["spin","quake"]
		var span := maxf(600,reach*(2.25 if surrounding else 1.28))
		camera.size=span*TILE.y/TILE.x*.01
		focus_x=-1.45 if surrounding else (-145+reach*.40)*.01
	camera.position=Vector3(focus_x,7,5.5); camera.look_at(Vector3(focus_x,.4,0)); camera.make_current()
	var env := WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("111d2a")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color("b4c4da"); env.environment.ambient_light_energy=.7
	world.add_child(env)
	var floor_node := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size=Vector2(12,9)
	floor_node.mesh=plane; var mat := StandardMaterial3D.new(); mat.albedo_color=Color("1b2935"); floor_node.material_override=mat; world.add_child(floor_node)
	var fx=Combat.new(); fx.camera=camera; world.add_child(fx)
	var flights=Flights.new(); flights.camera=camera; world.add_child(flights)
	var origin := Vector2(-145,55)
	var spec := Catalog.weapon(weapon)
	var player := {"weapon":weapon,"hero":0,"swing_total":1.5,"swing_time":1.5-float(spec.windup)-.025,"cast_time":0.0,"strike_aim":Vector2.RIGHT}
	var pose := frames.equipped_attack_frame(player)
	var actor := Sprite3D.new(); actor.texture=pose.texture; actor.pixel_size=.01; actor.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	actor.alpha_cut=SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	var factor: Vector2=pose.rect.size/actor.texture.get_size()
	actor.scale=Vector3(factor.x,factor.y/maxf(.1,camera.global_basis.y.dot(Vector3.UP)),1)
	actor.offset=Vector2(pose.rect.get_center().x/factor.x,-pose.rect.get_center().y/factor.y)
	actor.position=Vector3(origin.x*.01,.02,origin.y*.01); actor.modulate=Color(.70,.75,.82); world.add_child(actor)
	var actor_screen := camera.unproject_position(actor.position)
	var pixel_scale := float(TILE.y)/(camera.size*100.0)
	var grip: Vector2=pose.get("grip",Vector2(12,-45))
	var tip: Vector2=pose.get("socket",frames.equipped_weapon_tip(player))
	var projected_aim := (camera.unproject_position(actor.position+Vector3.RIGHT)-actor_screen).normalized()
	var mount := CharacterMetrics.aimed_mount(actor_screen,grip*pixel_scale,tip*pixel_scale,projected_aim)
	var charge_sites: Array=[]
	for site in preload("res://scripts/weapon_held_glow.gd").charge_sites(pose): charge_sites.append(actor_screen+Vector2(site)*pixel_scale)
	var mounted := {"tip":actor_screen+tip*pixel_scale,"grip":actor_screen+grip*pixel_scale,"stroke_tip":mount.tip,"stroke_pivot":mount.pivot,"charge_points":charge_sites,"active":true}
	fx.socket_provider=func(_id): return mounted
	var tile := {"weapon":weapon,"view":view,"world":world,"fx":fx,"flights":flights,"bullets":[],"origin":origin,"at":Vector2((number%4)*480,54+(number/4)*350),"mode":"真实3D释放 / 动态网格 / 粒子 / 烟雾"}
	board.tiles.append(tile); return tile
func strike(tile: Dictionary,art: bool=false,heavy: bool=false) -> void:
	var weapon: int=tile.weapon
	var spec := Catalog.weapon(weapon)
	tile.bullets.clear(); tile.flights.reset()
	var event := {"kind":"strike","p":tile.origin,"aim":Vector2.RIGHT,"weapon_index":weapon,"reach":float(spec.reach),"id":1,"combo":2 if art else 0}
	var active := art or heavy
	var move := preload("res://scripts/weapon_hold_attack.gd").profile(weapon) if heavy else WeaponArts.of(weapon)
	event["charged"]=heavy; event["vfx_action"]="heavy" if heavy else "art" if art else "normal"
	if active:
		event.attack_kind=move.kind; event.reach=move.reach; event.radius=move.get("radius",move.reach); event.width=move.get("width",30)
		tile.mode=("蓄力重击 · " if heavy else "战技 · ")+str(move.name)
	tile.fx.event(event)
	var spell := str(move.get("spell",spec.get("spell","star"))) if active else str(spec.get("spell","star"))
	var ranged := Catalog.weapon_family(weapon) in [0,3]
	if (active and move.kind=="volley") or (not active and ranged and spell!="prism"):
		var count := int(move.get("count",1)) if active else 5 if spell=="scatter" else 1
		for i in count:
			var dir := Vector2.RIGHT.rotated((i-(count-1)*.5)*float(move.get("spread",.12)))
			tile.bullets.append({"fx_id":i,"p":tile.origin+dir*23,"height":55.0,"v":dir*float(spec.get("speed",850)),"weapon_index":weapon,"spell":spell,"charged":heavy,"vfx_action":event.vfx_action})
		tile.flights.observe(tile.bullets,0)
	if not active and spell=="prism":
		var beam := event.duplicate(); beam.kind="spell_beam"; beam.width=30
		tile.fx.event(beam)
	if active and str(move.kind) in ["beam","burst"]:
		var payload := event.duplicate(); payload.kind="spell_beam" if move.kind=="beam" else "spell_burst"
		if move.kind=="burst": payload.p=tile.origin+Vector2.RIGHT*float(move.reach)
		tile.fx.event(payload)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"frames"))
	root.size=Vector2i(1920,1110); root.content_scale_size=root.size
	if "--all" in OS.get_cmdline_user_args():
		full_preview=true
		var weapons: Array=range(600,648)+range(21)
		var coverage: Array=[]
		for page in ceili(float(weapons.size())/8):
			var selected := weapons.slice(page*8,mini((page+1)*8,weapons.size()))
			var folder := "all/page-%02d" % page
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+folder))
			await motion(selected,folder,"全部武器 · %d / 9 · 普攻 → 蓄力 → 满蓄力 → 重击 → 战技 · 按招式范围取景" % (page+1))
			for i in selected.size(): coverage.append({"weapon":selected[i],"name":Catalog.weapon(selected[i]).name,"page":page,"slot":i,"folder":folder})
			print("ALL WEAPON PREVIEW page ",page," complete: ",selected)
		FileAccess.open(OUT+"all/coverage.json",FileAccess.WRITE).store_string(JSON.stringify(coverage,"\t"))
		print("ALL WEAPON PREVIEW COMPLETE ",coverage.size()," weapons, 9 pages, 175 frames each")
		quit(); return
	if "--designs" in OS.get_cmdline_user_args():
		await action_comparison([612,615,619,613])
		await motion([612,613,614,615,616,617,619,623],"frames","武器重设计 · 大剑弧线 / 重锤裂地 · 普攻 → 蓄力 → 重击 → 战技")
		quit(); return
	if "--actions" in OS.get_cmdline_user_args():
		await action_comparison(); await motion(); quit(); return
	for page in 4:
		var board := Board.new(); root.add_child(board)
		board.caption="三维武器 VFX · 48 把武器 · %d / 4 · 同倍率世界相机" % (page+1)
		tiles.clear()
		for slot in 12:
			var tile := create_tile(600+page*12+slot,slot,board); tiles.append(tile)
			strike(tile,true)
			for sample in 5: step(tile,.02)
		for frame in 6: board.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OUT+"weapons-%d.png" % page)
		for tile in tiles:
			checks+=1
			if tile.fx.effects.is_empty(): failures+=1
			for effect in tile.fx.effects:
				checks+=1
				if not effect.ribbon.visible: failures+=1
			tile.view.queue_free()
		board.queue_free(); await process_frame
		print("WORLD VFX PAGE ",page," saved")
	if "--motion" in OS.get_cmdline_user_args(): await motion()
	print("WORLD VFX PREVIEW ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func motion(selected: Array=[],folder: String="frames",caption: String="") -> void:
	root.size=Vector2i(1920,760); root.content_scale_size=root.size
	var board := Board.new(); board.caption=caption if not caption.is_empty() else "三维武器 VFX · 连续动态演示 · 原生世界网格与粒子"; root.add_child(board)
	tiles.clear()
	if selected.is_empty(): selected=[600,613,616,622,629,638,643,647]
	for slot in selected.size(): tiles.append(create_tile(selected[slot],slot,board))
	for frame in 175:
		if frame in [0,80,125]:
			for tile in tiles: tile.fx.reset(); strike(tile,frame==125,frame==80)
		if frame==45:
			for tile in tiles:
				tile.fx.reset(); tile.bullets.clear(); tile.flights.reset()
				tile.mode="重击蓄力 · 能量聚集"
				tile.fx.event({"kind":"hold_charge","p":tile.origin,"aim":Vector2.RIGHT,"weapon_index":tile.weapon,"id":1,"hold_time":.4})
		if frame==65:
			for tile in tiles:
				tile.mode="满蓄力 · 保持 / 松手释放"
				tile.fx.event({"kind":"hold_ready","id":1})
		for tile in tiles:
			step(tile,1.0/50)
			if frame in [12,92,137]: tile.fx.event({"kind":"impact","p":tile.origin+Vector2(200,0),"aim":Vector2.RIGHT,"weapon_index":tile.weapon,"damage":20,"id":1,"enemy_id":frame,"vfx_action":"heavy" if frame==92 else "art" if frame==137 else "normal"})
		# Explicit offscreen submission also works when the preview window is
		# covered/minimized; waiting for an automatic window redraw can stall.
		board.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OUT+folder+"/%03d.png" % frame)
		if frame==129: root.get_texture().get_image().save_png(OUT+folder+"/poster.png")
	for tile in tiles: tile.view.queue_free()
	board.queue_free(); await process_frame

func step(tile: Dictionary,dt: float) -> void:
	tile.fx.advance(dt); tile.flights.advance(dt)
	for bullet in tile.bullets: bullet.p+=Vector2(bullet.v)*dt
	tile.flights.observe(tile.bullets,dt)

func action_comparison(selected: Array=[600,613,638,643]) -> void:
	root.size=Vector2i(1440,1470); root.content_scale_size=root.size
	var board := Board.new(); board.caption="同一武器的三种动作 · 左：普攻 / 中：蓄力重击 / 右：战技"; root.add_child(board)
	for row in 4:
		for column in 3:
			var tile := create_tile(selected[row],0,board)
			tile.at=Vector2(column*480,54+row*350)
			strike(tile,column==2,column==1)
			if column==0: tile.mode="普攻 · 短刀光 / 快速收势"
			for frame in (3 if column==0 else 11 if column==1 else 8): step(tile,.02)
	for frame in 6: board.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT+"action-comparison.png")
	for tile in board.tiles: tile.view.queue_free()
	board.queue_free(); await process_frame
