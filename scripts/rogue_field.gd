extends Control

const Semantics = preload("res://scripts/effect_semantics.gd")
const OPEN_CHEST = preload("res://assets/ui/rewards/open-chest-v1.png")
const BuildArt = preload("res://scripts/rogue_build_art.gd")

var session: TideSession
const Idle = preload("res://scripts/character_idle.gd")
var idle = Idle.new()
var idle_meshes: Dictionary={}
var frames: CharacterFrames
var art = preload("res://scripts/rogue_art.gd").new()
var clock := 0.0
var move_phases: Dictionary={}
var camera_x := 0.0
var camera_y := 0.0
const CAMERA_DEAD_ZONE := Rect2(590,440,260,160)
var camera := Vector2(720,575)
var combat: CombatVisuals
var enemy_fx: Node2D
var backdrop: Node2D
const HERO_SCALE := 1.15
var area_signature := ""
var vision_overlay: ColorRect
const TONES := [Color("6cedce"),Color("ff9b56"),Color("bfa1ff"),Color("83dcff"),Color("ff638a")]

func _ready() -> void:
	size=Vector2(1440,900)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	backdrop=preload("res://scripts/rogue_backdrop.gd").new()
	backdrop.field=self
	add_child(backdrop)
	frames=CharacterFrames.new()
	session.enemy_bodies.rogue_art=art
	combat=CombatVisuals.new()
	combat.field=self
	combat.modulate=Color.WHITE
	add_child(combat)
	enemy_fx=preload("res://scripts/rogue_enemy_vfx.gd").new()
	enemy_fx.field=self
	add_child(enemy_fx)
	vision_overlay=ColorRect.new()
	vision_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	vision_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fog_material := ShaderMaterial.new()
	fog_material.shader=preload("res://shaders/rogue_vision.gdshader")
	vision_overlay.material=fog_material
	vision_overlay.visible=false
	add_child(vision_overlay)
	session.combat_event.connect(func(data: Dictionary):
		if visible and session.roguelike.active(session):
			combat.event(data)
			enemy_fx.event(data))
	session.effect.connect(func(kind: String, at: Vector2):
		if visible and session.roguelike.active(session): combat.legacy(kind,at))
	session.started.connect(reset_effects)

func reset_effects() -> void:
	combat.reset()
	enemy_fx.reset()
	move_phases.clear()

func ground_transform() -> Transform2D:
	return Transform2D(0,-camera_offset())

func camera_offset() -> Vector2:
	return Vector2(camera_x,camera_y)

func camera_target(at: Vector2) -> Vector2:
	var target := camera_offset()
	var screen := at-target
	if screen.x<CAMERA_DEAD_ZONE.position.x: target.x=at.x-CAMERA_DEAD_ZONE.position.x
	elif screen.x>CAMERA_DEAD_ZONE.end.x: target.x=at.x-CAMERA_DEAD_ZONE.end.x
	if screen.y<CAMERA_DEAD_ZONE.position.y: target.y=at.y-CAMERA_DEAD_ZONE.position.y
	elif screen.y>CAMERA_DEAD_ZONE.end.y: target.y=at.y-CAMERA_DEAD_ZONE.end.y
	return target.clamp(Vector2.ZERO,(session.ruins.extent-Vector2(1440,900)).max(Vector2.ZERO))

func weapon_effect_socket(source: int) -> Dictionary:
	var p: Dictionary=session.players.get(source,{})
	if p.is_empty() or p.status!="active": return {}
	var family := Catalog.weapon_family(p.weapon)
	var frame := CharacterFrames.attack_pose_frame(p)
	var aim: Vector2=p.strike_aim if p.swing_time>0 else p.aim
	var tip := frames.equipped_weapon_tip(p)*Vector2(-1 if aim.x<0 else 1,1)
	var origin: Vector2=p.p-camera_offset()+CharacterMetrics.FOOT_OFFSET*HERO_SCALE-Vector2(0,float(p.get("height",0)))
	var pose := frames.equipped_attack_frame(p)
	var grip: Vector2=Vector2(pose.get("grip",pose.get("socket",Vector2.ZERO)))*Vector2(-1 if aim.x<0 else 1,1)
	var stroke_pivot: Vector2=origin+grip*HERO_SCALE
	var stroke_tip: Vector2=stroke_pivot+aim.normalized()*tip.distance_to(grip)*HERO_SCALE
	return {"tip":origin+tip*HERO_SCALE,"stroke_tip":stroke_tip,"stroke_pivot":stroke_pivot,"aim":aim.normalized(),
		"grip":origin+grip*HERO_SCALE,"blade_axis":(tip-grip).normalized(),"frame":int(pose.get("frame",2)),"weapon_identity":preload("res://scripts/weapon_image_art.gd").canonical(p.weapon),"active":p.swing_time>0 or p.cast_time>0}

func _process(dt: float) -> void:
	if not visible: return
	var viewer: Dictionary=session.players.get(session.my_id(),{})
	var vision := float(session.rogue_mods(viewer).get("vision",0.0)) if not viewer.is_empty() else 0.0
	vision_overlay.visible=vision<0.0
	if vision_overlay.visible:
		var fog_material: ShaderMaterial=vision_overlay.material
		fog_material.set_shader_parameter("viewport_size",size)
		fog_material.set_shader_parameter("focus",viewer.p-camera_offset()-Vector2(0,45))
		fog_material.set_shader_parameter("radius",640.0*clampf(1.0+vision,.4,1.0))
	clock+=dt
	for actor: Dictionary in session.players.values():
		idle.tick(actor,dt)
		if actor.motion in ["walk","run"]:
			var cadence: float=frames.weapon_atlases.rate(actor.hero,actor.weapon,actor.motion,11.5 if actor.motion=="run" else 7.0)
			move_phases[actor.id]=float(move_phases.get(actor.id,0.0))+dt*cadence
		else: move_phases[actor.id]=0.0
	var p: Dictionary=session.players.get(session.my_id(),{})
	var at: Vector2=p.get("p",Vector2(720,520))
	var desired := camera_target(at)
	var follow := 1.0-exp(-dt*8)
	camera_x=lerpf(camera_x,desired.x,follow)
	camera_y=lerpf(camera_y,desired.y,follow)
	var signature := "%d:%d" % [session.raid.floor,session.raid.area]
	if signature!=area_signature:
		area_signature=signature
		var initial := (at-Vector2(720,520)).clamp(Vector2.ZERO,(session.ruins.extent-Vector2(1440,900)).max(Vector2.ZERO))
		camera_x=initial.x
		camera_y=initial.y
		art.animation_cache.clear()
		art.region_backgrounds.clear()
		reset_effects()
	camera=camera_offset()+Vector2(720,450)
	backdrop.queue_redraw()
	queue_redraw()

func aim() -> Vector2:
	var p: Dictionary=session.players.get(session.my_id(),{})
	return (get_local_mouse_position()+camera_offset()-p.get("p",Vector2(720,575))).normalized()

func glow(at: Vector2, tone: Color, radius: float) -> void:
	draw_circle(at,radius*2,Color(tone,0.035))
	draw_circle(at,radius,Color(tone,0.1))
	draw_circle(at,radius*0.3,Color(tone,0.7))

func icon(texture: Texture2D, at: Vector2, dimensions: Vector2) -> void:
	if texture==null: return
	draw_texture_rect(texture,Rect2(at-dimensions/2,dimensions),false)

func route_label_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(.035,.045,.06,.86)
	style.set_corner_radius_all(6)
	return style

func draw_rewards() -> void:
	var me: Dictionary=session.players.get(session.my_id(),{})
	var nearest := -1
	var distance := 80.0
	for packet in session.raid.get("reward_drops",[]):
		var d: float=me.get("p",Vector2.ZERO).distance_to(packet.p)
		if d<distance: nearest=packet.id; distance=d
	var chest: Dictionary=session.raid.get("reward_chest",{})
	if not chest.is_empty():
		var at: Vector2=chest.p
		var tone: Color=Catalog.BAG_TIERS[int(chest.tier)].color
		glow(at,tone,42)
		var opened: bool=chest.opened
		var texture: Texture2D=OPEN_CHEST if opened else art.item_icons[11]
		icon(texture,at+Vector2(0,-38),Vector2(126,112) if opened else Vector2(100,88))
		if not opened:
			draw_string(get_theme_default_font(),at+Vector2(-75,-100),"%s宝箱 · E 开启" % Catalog.BAG_TIERS[int(chest.tier)].quality,HORIZONTAL_ALIGNMENT_LEFT,210,16,tone)
		elif session.elapsed-float(chest.get("opened_at",0))<1.2:
			var t: float=(session.elapsed-float(chest.opened_at))/1.2
			Semantics.reward(self,at-Vector2(0,40),tone,t,clock,true)
	for drop in session.raid.get("reward_drops",[]):
		var age: float=maxf(0,session.elapsed-float(drop.born))
		var at: Vector2=drop.p
		var tone: Color=Catalog.BAG_TIERS[int(drop.tier)].color
		var travel: float=clampf(age/maxf(0.01,float(drop.delay)),0,1)
		if travel<1 and not chest.is_empty(): at=chest.p.lerp(at,travel)+Vector2(0,-sin(travel*PI)*100)
		glow(at,tone,22)
		var category_name: String={"gear":"装备","weapon":"武器","boon":"天赋","attribute":"属性灵晶"}.get(drop.get("category","gear"),"秘藏")
		var picture: Texture2D=art.item_icons[{"gear":4,"weapon":0,"boon":12}.get(drop.get("category","gear"),10)] if drop.offer.is_empty() else art.offer_icon(drop.offer)
		draw_texture_rect(picture,Rect2(at+Vector2(-24,-46-sin(clock*2.5+drop.id)*4),Vector2(48,48)),false,tone if drop.offer.is_empty() else Color.WHITE)
		Semantics.reward(self,at-Vector2(0,18),tone,0,clock+drop.id,false)
		var drop_label: String="属性灵晶 +1" if drop.offer.has("attribute_points") else (Catalog.BAG_TIERS[int(drop.tier)].quality+category_name if drop.offer.is_empty() else Catalog.BAG_TIERS[int(drop.tier)].quality)
		draw_string(get_theme_default_font(),at+Vector2(-35,24),drop_label,HORIZONTAL_ALIGNMENT_LEFT,110,13,tone)
		if drop.id==nearest and travel>=1:
			var caption: String="%s · E 三选一" % category_name if drop.offer.is_empty() else "%s · E 拾取" % drop.offer.name
			draw_string(get_theme_default_font(),at+Vector2(-80,56),caption,HORIZONTAL_ALIGNMENT_LEFT,230,14,tone)

func _draw() -> void:
	if session==null or not session.roguelike.active(session): return
	var r=session.ruins
	var floor_index: int=int(session.raid.floor)-1
	var tone: Color=TONES[floor_index]
	draw_set_transform(-camera_offset())
	for pool in r.terrain_hazards:
		icon(art.prop_icons[10],pool.p,pool.radius*2)
		glow(pool.p,Color("ff8c43"),28)
		for i in 2:
			var ember: Vector2= pool.p+Vector2(sin(clock*0.8+i*4)*70,-fposmod(clock*20+i*11,65))
			draw_circle(ember,2,Color(1.0,0.6,0.2,0.45))
	var opened: bool=session.raid.phase in ["rogue_exit","rogue_shop"]
	draw_rewards()
	for index in session.raid.get("exits",[]).size():
		var exit_at: Vector2=r.exit_position(index)
		var destination: Dictionary=session.raid.exits[index]
		var exit_tone := Color("d3bb85") if destination.room in ["shop","treasure","talent"] else tone
		var near: bool=session.players.get(session.my_id(),{}).get("p",Vector2.ZERO).distance_to(exit_at)<=64
		# The two open path ends share ground-plane movement and carry route labels.
		if opened:
			if near:
				draw_arc(exit_at,25,0,TAU,28,Color(exit_tone,.65),2,true)
			var font := get_theme_default_font()
			var title: String=("直行 · " if index==0 else "斜向 · ")+destination.name+(" · E" if near else "")
			# Center each label over its own road end and show its ground anchor.
			draw_arc(exit_at,12,0,TAU,28,Color(exit_tone,.6),1.5,true)
			draw_line(exit_at+Vector2(0,-15),exit_at+Vector2(0,-42),Color(exit_tone,.45),1,true)
			var title_at := exit_at+Vector2(-97,-75)
			draw_style_box(route_label_style(),Rect2(title_at-Vector2(8,23),Vector2(210,54)))
			draw_string(font,title_at,title,HORIZONTAL_ALIGNMENT_LEFT,198,17,exit_tone)
			draw_string(font,title_at+Vector2(0,23),destination.desc,HORIZONTAL_ALIGNMENT_LEFT,198,12,Color("b4bbc5"))
	for fx in session.roguelike.combat.effects: draw_spell(fx)
	for corpse in session.raid.get("rogue_corpses",[]):
		if corpse.time<=0: continue
		# 与存活时的取帧规则一致：身体立绘优先按身份（boss_art），缺帧时回落到楼层。
		var texture: Texture2D=art.boss_animation(int(corpse.get("boss_art",corpse.floor)),11,int(corpse.floor)).texture
		var h := 255.0
		var w: float=h*texture.get_width()/texture.get_height()
		draw_set_transform(corpse.p-camera_offset(),0,Vector2(corpse.facing,1))
		draw_texture_rect(texture,Rect2(-w/2,-h,w,h),false,Color(1.0,0.65,0.65,corpse.time/corpse.total))
		draw_set_transform(-camera_offset())
	var actors: Array=session.enemies.duplicate()
	actors.append_array(session.players.values())
	for prop in r.obstacles: actors.append({"p":prop.p,"prop":prop})
	actors.sort_custom(func(a,b): return a.p.y<b.p.y)
	for actor in actors:
		if actor.get("boss_construct",false): continue
		var at: Vector2=actor.p
		if at.x<camera_x-200 or at.x>camera_x+1640: continue
		if actor.has("prop"):
			var prop: Dictionary=actor.prop
			var texture: Texture2D=art.prop_icons[prop.icon]
			var w := 135.0
			var h: float=w*texture.get_height()/texture.get_width()
			draw_texture_rect(texture,Rect2(at+Vector2(-w/2,-h+22),Vector2(w,h)),false,Color(.72,.76,.78))
			continue
		draw_set_transform(at-camera_offset(),0,Vector2(1,0.3))
		draw_circle(Vector2.ZERO,19 if actor.has("hero") else 27,Color(0.02,0.01,0.03,0.4))
		draw_set_transform(-camera_offset())
		if actor.has("hero") and not actor.get("rogue_mirror",false):
			at.y-=float(actor.get("height",0))
			if actor.status not in ["active","down"]: continue
			var pose: Dictionary
			if actor.swing_time>0 or actor.cast_time>0:
				pose=frames.equipped_attack_frame(actor)
			elif actor.get("height",0)>0:
				pose=frames.held_jump_frame(actor,float(actor.get("height_velocity",0)),float(actor.height))
			elif actor.get("build_landing_time",0)>0:
				pose=frames.held_jump_frame(actor,-200,0,float(actor.build_landing_time))
			elif Idle.active(actor): pose=frames.held_idle_frame(actor.hero,actor.weapon,float(idle.sample(actor).time))
			else: pose=frames.held_motion_frame(actor,actor.motion,float(move_phases.get(actor.id,0)),actor.dodge_time)
			var facing_aim: Vector2=actor.strike_aim if actor.swing_time>0 else actor.aim
			draw_set_transform(at-camera_offset(),0,Vector2(-1 if facing_aim.x<0 else 1,1)*HERO_SCALE)
			if Idle.active(actor) and not pose.get("weapon_atlas",false):
				var state := idle.sample(actor)
				var side: float=float(pose.get("hand_side",1.0))
				var mesh_data := Idle.geometry(pose,actor.weapon,state.time,state.blend,side)
				idle_meshes[actor.id]=Idle.mesh(mesh_data)
				draw_mesh(idle_meshes[actor.id],mesh_data.texture)
			else:
				draw_texture_rect(pose.texture,pose.rect,false,Color.WHITE if actor.status=="active" else Color("a77d8e"))
			if actor.status=="active":
				for glint in preload("res://scripts/weapon_held_glow.gd").samples(pose,clock):
					draw_texture_rect(glint.texture,glint.rect,false,glint.tint)
			draw_set_transform(-camera_offset())
			# [2026-06 禁用] 这段"新武器手持贴图叠加绘制"会把 weapons-*-v1.png 图集里的
			# 青色尖刺剪影画到角色手上，与旧立绘自带的武器美术冲突。用户要求保留旧立绘、
			# 不再显示该叠加。用 `false and` 短路守卫整块绘制（可逆：去掉 `false and ` 即恢复）。
			# 块内变量均只在本块使用，块外逻辑（楼层标记等）不受影响。
			if false and actor.status=="active" and int(actor.weapon)>=600 and (Catalog.weapon_family(actor.weapon)!=0 or Idle.active(actor)):
				var weapon_texture: Texture2D=preload("res://scripts/rogue_build_art.gd").item_icon(actor.equipped.weapon)
				if weapon_texture!=null:
					var length := 54.0 if Catalog.weapon_family(actor.weapon)==2 else 42.0
					var dimensions: Vector2=weapon_texture.get_size()*length/maxf(weapon_texture.get_width(),weapon_texture.get_height())
					var turn: float=sin((1.0-actor.swing_time/maxf(.01,actor.swing_total))*PI)*.5 if actor.swing_time>0 else 0.0
					var grip := Vector2(10 if facing_aim.x>=0 else -10,-40)
					if Idle.active(actor):
						var state := idle.sample(actor)
						var local_grip: Vector2=pose.get("grip",Vector2(14,-30))
						local_grip+=Idle.displacement(local_grip,CharacterMetrics.FOOT_OFFSET,actor.weapon,state.time,state.blend)
						grip=local_grip*HERO_SCALE*Vector2(1 if facing_aim.x>=0 else -1,1)
						turn=sin(state.time*TAU/float(Idle.profile(actor.weapon)[0]))*float(Idle.profile(actor.weapon)[3])*state.blend
					draw_set_transform(at-camera_offset()+grip,facing_aim.angle()+PI/4-turn)
					draw_texture_rect(weapon_texture,Rect2(Vector2(-dimensions.x*.24,-dimensions.y*.7),dimensions),false)
					draw_set_transform(-camera_offset())
			draw_colored_polygon(PackedVector2Array([at+Vector2(-5,-106),at+Vector2(5,-106),at+Vector2(0,-98)]),tone)
		elif actor.get("rogue_mirror",false):
			var pose: Dictionary=frames.held_motion_frame(actor,"walk" if actor.moving else "idle",float(actor.motion_phase),0.0)
			if float(actor.attack_time)>0:
				pose=frames.attack_frame(int(actor.hero),maxi(1,Catalog.weapon_family(int(actor.weapon))),clampi(int((1.0-float(actor.attack_time)/float(actor.attack_total))*4),0,3))
			draw_set_transform(at-camera_offset(),0,Vector2(float(actor.facing),1)*HERO_SCALE)
			draw_texture_rect(pose.texture,pose.rect,false,Color(1.4,.8,1.8,.85) if actor.flash>0 else Color(.6,.4,.85,.9))
			draw_set_transform(-camera_offset())
			draw_rect(Rect2(at+Vector2(-30,-125),Vector2(60,5)),Color("211d2c"))
			draw_rect(Rect2(at+Vector2(-30,-125),Vector2(60*clampf(actor.hp/actor.max_hp,0,1),5)),Color("c58aff"))
			draw_string(get_theme_default_font(),at+Vector2(-55,-137),str(actor.rogue_name),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d9baff"))
		else:
			at.y-=float(actor.get("height",0))
			var big: bool=actor.get("rogue_guardian",false)
			var height := 255.0 if big else 78.0+(int(actor.get("rogue_variant",0))%4)*3.0
			# Rendering and authoritative damage use the same pose and foot pivot.
			var pose: Dictionary=session.enemy_bodies.pose(actor,session.elapsed,true)
			var texture: Texture2D=pose.texture
			draw_set_transform((at-camera_offset()+Vector2(0,float(pose.hover))).round(),0,Vector2(float(pose.facing),1))
			var tint := Color(1.6,1.2,1.2) if actor.get("flash",0)>0 else Color.WHITE
			if pose.region.size!=Vector2.ZERO: draw_texture_rect_region(texture,pose.rect,pose.region,tint)
			else: draw_texture_rect(texture,pose.rect,false,tint)
			draw_set_transform(-camera_offset())
			draw_rect(Rect2(at+Vector2(-25,-height-13),Vector2(50,5)),Color("211d2c"))
			draw_rect(Rect2(at+Vector2(-25,-height-13),Vector2(50*maxf(0,actor.hp/actor.max_hp),5)),tone)
			if float(actor.get("rogue_shield",0))>0: draw_arc(at-Vector2(0,height*.45),height*.6,0,TAU,32,Color(tone,.8),2,true)
			if float(actor.get("buff_time",0))>0:
				draw_string(get_theme_default_font(),at+Vector2(-18,-height-20),"↑",HORIZONTAL_ALIGNMENT_LEFT,-1,18,tone)
			if float(actor.get("guard_time",0))>0:
				var guard: Vector2=actor.get("guard_aim",Vector2.RIGHT)
				draw_arc(at,45,guard.angle()-1.0,guard.angle()+1.0,18,tone,4,true)
			if actor.get("attack_time",0)>0 and not big and not actor.get("attack_released",false) and int(actor.get("rogue_variant",0))<2:
				var dir: Vector2=actor.get("attack_aim",Vector2.RIGHT)
				draw_arc(at,64,dir.angle()-0.85,dir.angle()+0.85,18,Color(tone,.45*smoothstep(0,.18,(float(actor.attack_total)-float(actor.attack_time))/maxf(.01,float(actor.get("minion_windup",.55))))),2,true)
	for p in session.players.values():
		if p.get("flask_time",0)>0:
			var anchor: Vector2=p.p-Vector2(0,126)
			draw_texture_rect(art.flask_icon,Rect2(anchor+Vector2(-16,-38),Vector2(32,32)),false)
			draw_rect(Rect2(anchor-Vector2(25,0),Vector2(50,4)),Color("272031"))
			draw_rect(Rect2(anchor-Vector2(25,0),Vector2(50*(1-float(p.flask_time)/.75),4)),Color("e3667e"))
		if p.get("build_landing_time",0)>0:
			draw_arc(p.p,lerpf(42,14,float(p.build_landing_time)/.18),0,TAU,28,Color(.85,.65,.9,float(p.build_landing_time)/.18),2,true)
		for soul in p.get("build_summons",[]):
			glow(soul.p-Vector2(0,42),Color("b888ec"),22)
			draw_arc(soul.p-Vector2(0,42),12,clock*2,clock*2+PI*1.6,16,Color("d2c5ef"),2,true)
		for zone in p.get("build_fields",[]):
			draw_arc(zone.p,float(zone.radius),0,TAU,32,Color(.75,.26,.42,.35),3,true)
		if float(p.get("build_shield",0))>0: draw_arc(p.p-Vector2(0,35+float(p.get("height",0))),45,0,TAU,40,Color(.45,.7,1,.65),2,true)
		if float(p.get("build_combo_time",0))>0:
			draw_string(get_theme_default_font(),p.p-Vector2(65,130+float(p.get("height",0))),str(p.build_combo_label),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f0d18f"))
	for zone in session.fire_zones:
		if zone.has("p"): glow(zone.p,Color("bc7cff"),45)
	if session.raid.room in ["shop","treasure"]:
		icon(art.item_icons[11 if session.raid.room=="treasure" else 15],Vector2(720,r.lane_center(720)),Vector2(100,100))
	elif session.raid.room=="talent":
		var shrine_at := Vector2(720,r.lane_center(720))
		glow(shrine_at-Vector2(0,45),Color("b888ec"),75)
		icon(BuildArt.icon("T008"),shrine_at-Vector2(0,35),Vector2(120,120))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0,0,1440,112),Color(0.02,0.015,0.035,0.53))
	draw_rect(Rect2(0,776,1440,124),Color(0.02,0.015,0.035,0.74))
	for boss in session.enemies:
		if not boss.get("rogue_guardian",false): continue
		draw_rect(Rect2(365,115,710,15),Color("251827"))
		draw_rect(Rect2(365,115,710*clampf(boss.hp/boss.max_hp,0,1),15),tone)
		var label: String=boss.boss_name+(" · 狂暴" if boss.boss_enraged else "")
		if boss.attack_time>0:
			# The move table is keyed by guardian identity, not by floor, so a pooled
			# guardian must read its own row.
			var moves: Array=session.roguelike.combat.moves_of(boss)
			var skill := int(boss.boss_skill)
			var move_name := str(boss.get("move_name",""))
			if move_name=="" and skill>=0 and skill<moves.size(): move_name=str(moves[skill].name)
			if move_name!="": label+=" · "+move_name
		draw_string(get_theme_default_font(),Vector2(365,153),label,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)

func draw_spell(_fx: Dictionary) -> void:
	pass # Shared staged damage renderer owns both minion and guardian zones.
