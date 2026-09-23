class_name Battlefield
extends Node2D
var session: TideSession
var camera := Ruins.SPAWN
var offset := Vector2.ZERO
var clock := 0.0
var map_open := false
var waypoint := Vector2(-1,-1)
var map_filter := 0
var world_art: WorldArt
var font: Font
var follow_id := 1
var explored: Dictionary = {}
var sentinels: Texture2D
var smooth_positions: Dictionary = {}
var ground: Texture2D
var enemy_frames: EnemyFrames
var boss_frames: BossFrames
var boss_seen: Dictionary={}
var boss_health: Dictionary={}
var defeated_enemies: Array = []
var velocity_visual: Dictionary = {}
var previous_positions: Dictionary = {}
var loot_icons: Dictionary = {}
var combat: CombatVisuals
var character_frames: CharacterFrames
var move_phases: Dictionary = {}

func _ready() -> void:
	var face := FontVariation.new()
	face.base_font=load("res://assets/NotoSansSC.ttf")
	face.variation_opentype={"wght":450.0}
	font=face
	sentinels=load("res://assets/sentinels.png")
	ground=load("res://assets/courtyard.png")
	world_art=WorldArt.new()
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	enemy_frames=EnemyFrames.new()
	boss_frames=BossFrames.new()
	var boss_layer := CanvasLayer.new()
	boss_layer.layer=1
	add_child(boss_layer)
	var boss_hud := preload("res://scripts/boss_hud.gd").new()
	boss_hud.field=self
	boss_layer.add_child(boss_hud)
	for kind in Catalog.ITEMS:
		loot_icons[kind]=load("res://assets/icons/"+Catalog.kind_icon(kind)+".svg")
	# Field equipment resolves to its own weapon / slot icon, so preload those too.
	for icon in Catalog.WEAPON_ICONS+Catalog.GEAR_ICONS:
		loot_icons[icon]=load("res://assets/icons/"+icon+".svg")
	combat=CombatVisuals.new()
	combat.field=self
	add_child(combat)
	character_frames=CharacterFrames.new()
	session.effect.connect(combat.legacy)
	session.combat_event.connect(combat.event)
	session.combat_event.connect(func(event: Dictionary):
		if event.kind=="enemy_defeated":
			var fallen := event.duplicate()
			fallen["age"]=0.0
			defeated_enemies.append(fallen))
	session.map_changed.connect(func(): waypoint=Vector2(-1,-1); explored.clear(); defeated_enemies.clear(); combat.reset(); smooth_positions.clear(); previous_positions.clear(); camera=session.players.get(session.my_id(),{"p":RoyalCity.GATE}).p)
	session.started.connect(func(): boss_seen.clear(); boss_health.clear(); waypoint=Vector2(-1,-1); map_filter=0; defeated_enemies.clear(); combat.reset(); smooth_positions.clear(); previous_positions.clear(); velocity_visual.clear(); move_phases.clear())

func _process(dt: float) -> void:
	if not visible:
		return
	clock+=dt
	for e in session.enemies:
		if not e.get("raid_boss",false): continue
		if not boss_seen.has(e.id): boss_seen[e.id]=clock
		var ratio: float=clampf(e.hp/e.max_hp,0,1)
		boss_health[e.id]=move_toward(float(boss_health.get(e.id,ratio)),ratio,dt*0.35)
	for i in range(defeated_enemies.size()-1,-1,-1):
		defeated_enemies[i].age+=dt
		if defeated_enemies[i].age>=(1.6 if defeated_enemies[i].get("boss_kind",-1)>=0 else 0.55):
			defeated_enemies.remove_at(i)
	var p: Dictionary=session.players.get(session.my_id(),{})
	if not p.is_empty():
		if p.status in ["active","down"]:
			follow_id=session.my_id()
		elif not session.players.has(follow_id) or session.players[follow_id].status!="active":
			for ally in session.players.values():
				if ally.status=="active":
					follow_id=ally.id
		var target: Vector2=session.players.get(follow_id,p).p
		var half := get_viewport_rect().size/2
		target=target.clamp(half,session.ruins.extent-half)
		camera=camera.lerp(target,1-exp(-dt*10))
		for ally in session.players.values():
			var old_pos: Vector2=previous_positions.get(ally.id,ally.p)
			velocity_visual[ally.id]=float(velocity_visual.get(ally.id,0.0))*0.8+old_pos.distance_to(ally.p)/maxf(dt,0.001)*0.2
			previous_positions[ally.id]=ally.p
			var cadence := 11.5 if ally.motion=="run" else 7.0
			if ally.motion in ["walk","run"]:
				move_phases[ally.id]=float(move_phases.get(ally.id,0.0))+dt*cadence
			else:
				move_phases[ally.id]=0.0
			var last: Vector2=smooth_positions.get(ally.id,ally.p)
			smooth_positions[ally.id]=last.lerp(ally.p,1-exp(-dt*22)) if last.distance_to(ally.p)<220 else ally.p
		for x in range(-2,3):
			for y in range(-2,3):
				explored[Vector2i(target/160)+Vector2i(x,y)]=true
	offset=get_viewport_rect().size/2-camera
	offset+=Vector2(sin(clock*89),cos(clock*107))*combat.trauma*combat.trauma*13
	queue_redraw()

func aim() -> Vector2:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return Vector2.RIGHT
	return (get_global_mouse_position()-offset-p.p).normalized()

func _draw() -> void:
	if not session or session.ruins.sites.is_empty():
		return
	draw_set_transform(offset)
	var world := session.ruins
	world_art.terrain(self,world,camera,clock)
	var gate := session.portal_position()
	draw_arc(gate,45,0,TAU,48,Color("a5ebed"),4,true)
	label(gate+Vector2(-95,-58),("返回月冠边境 [E]" if world.interior else "进入晨曦王城 [E]") if session.can_travel() else "血潮封锁 · 城门关闭",18,Color("ecdfba"))
	for site in world.sites:
		if site.p.distance_to(camera)<1000:
			label(site.p+Vector2(-80,-site.rect.size.y/2-45),site.name,19,Color("fff1db"))
	for i in world.exits.size():
		var pos: Vector2=world.exits[i]
		var pulse := 0.5+sin(clock*2)*0.12
		draw_circle(pos,83,Color(0.32,0.74,0.66,0.07))
		draw_arc(pos,70+sin(clock*2)*4,0,TAU,60,Color(0.4,0.8,0.73,pulse),2)
		draw_arc(pos,50,0,TAU,48,Color("467b77"),1)
		cross(pos,20,Color("80cabc"))
		label(pos+Vector2(-52,103),Ruins.EXIT_NAMES[i]+(" · 封锁" if not session.can_extract() else ""),15,Color("89b8b0"))
	for shrine in world.shrines:
		var pos: Vector2=shrine.p
		var color := Color("7accb4") if shrine.done else Color("ddb675")
		draw_circle(pos,40,Color(color,0.07))
		draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-30),pos+Vector2(19,0),pos+Vector2(0,20),pos+Vector2(-19,0)]),Color("353446"))
		cross(pos-Vector2(0,12),15,color)
		label(pos+Vector2(-40,45),"已点亮" if shrine.done else "晨钟封印",14,color)
	for chest in world.chests:
		var pos: Vector2=chest.p
		var empty: bool=chest.open and chest.items.is_empty()
		if chest.get("fixed_loot",false) and not empty:
			var reward_color: Color=Catalog.BAG_TIERS[int(chest.get("reward_tier",4))].color
			draw_circle(pos,48,Color(reward_color,0.16))
			draw_line(pos,pos-Vector2(0,85),Color(reward_color,0.5),5,true)
			var caption := session.container_title(chest)+" · [F] 搜索"
			label(pos+Vector2(-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x/2,-94),caption,16,reward_color)
		var deep: bool=int(chest.get("class",1))>=2
		var revealed: int=int(chest.get("searched",0))
		draw_rect(Rect2(pos-Vector2(21,12),Vector2(46,31)),Color(0,0,0,0.35))
		draw_rect(Rect2(pos-Vector2(21,18),Vector2(42,29)),Color("333039") if empty else (Color("554466") if deep else Color("665544")))
		draw_rect(Rect2(pos-Vector2(21,18),Vector2(42,29)),Color("6a5a7a") if deep else Color("c2a277"),false,1.5)
		draw_line(pos+Vector2(-20,-5),pos+Vector2(20,-5),Color("29242b"),3)
		draw_rect(Rect2(pos-Vector2(3,7),Vector2(6,12)),Color("5a555a") if empty else Color("e1ba76"))
		if not empty and revealed>0:
			draw_circle(pos+Vector2(0,-23),2+sin(clock*3),Color("e2c186"))
		# A chest being searched shows a small progress arc above the lid.
		var units := 0
		for item in Catalog.container_items(chest):
			units+=int(item.get("count",1)) if Catalog.stacks(str(item.kind)) else 1
		if revealed>0 and revealed<units:
			draw_arc(pos+Vector2(0,-30),9,-PI/2,-PI/2+TAU*float(revealed)/float(maxi(1,units)),20,Color("9fd0c2"),3)
	# Bags dropped by dead players, and loose enemy loot.
	for bag in session.world_drops:
		var at: Vector2=bag.p
		var is_bag := str(bag.get("key","")).begins_with("bag:")
		if is_bag:
			var bag_colour: Color=Catalog.tier(str(bag.key).substr(4)).color
			draw_rect(Rect2(at-Vector2(13,15),Vector2(26,30)),Color(bag_colour.darkened(0.68),0.95))
			draw_rect(Rect2(at-Vector2(13,15),Vector2(26,30)),Color(bag_colour,0.9),false,1.5)
			draw_arc(at-Vector2(0,15),10,PI,TAU,14,Color(bag_colour.lightened(0.2)),2.5)
			draw_line(at-Vector2(13,0),at+Vector2(13,0),Color(bag_colour.darkened(0.3)),1)
			label(at+Vector2(-30,-40),Catalog.bag_quality({"key":str(bag.key).substr(4)})+"背包",12,bag_colour.lightened(0.25))
		else:
			for item in Catalog.container_items(bag):
				var colour: Color=Catalog.item_color(item)
				draw_circle(at,17,Color(colour,0.1))
				draw_texture_rect(loot_icons[Catalog.item_icon(item)],Rect2(at+Vector2(-12,-16+sin(clock*3)*2),Vector2(24,24)),false)
				draw_arc(at,20+sin(clock*2)*2,0,TAU,24,Color(colour,0.45),1)
	for fallen in defeated_enemies:
		if int(fallen.get("boss_kind",-1))>=0:
			var kind: int=fallen.boss_kind
			draw_set_transform(offset+fallen.p,0,Vector2(fallen.facing,1))
			draw_texture_rect_region(boss_frames.sheets[kind],boss_frames.sprite_rect(kind),BossFrames.region(11),Color(1,1,1,1-fallen.age/1.6))
			draw_set_transform(offset)
			continue
		draw_set_transform(offset+fallen.p,0,Vector2(fallen.facing,1))
		draw_texture_rect_region(enemy_frames.sheets[int(fallen.type)],EnemyFrames.sprite_rect(int(fallen.type)),enemy_frames.region(11),Color(1,1,1,1-fallen.age/0.55))
		draw_set_transform(offset)
	if not world.interior:
		draw_raid_world()
	# Sort architecture, trees, actors and enemies together by their ground anchor.
	var drawables: Array=[]
	for item in world.decor:
		if item.p.distance_to(camera)<1150: drawables.append({"p":item.p,"kind":0,"data":item})
	for e in session.enemies:
		if e.p.distance_to(camera)<1100: drawables.append({"p":e.p,"kind":1,"data":e})
	for p in session.players.values():
		if p.status!="extracted": drawables.append({"p":p.p,"kind":2,"data":p})
	drawables.sort_custom(func(a: Dictionary,b: Dictionary): return a.p.y<b.p.y)
	var me: Vector2=session.players.get(session.my_id(),{"p":camera}).p
	for item in drawables:
		match item.kind:
			0: world_art.prop(self,item.data,camera,me,clock)
			1: monster(item.data)
			2: actor(item.data)
	if waypoint.x>=0:
		draw_arc(waypoint,28+sin(clock*3)*3,0,TAU,32,Color("ffe1a1"),2)
		diamond(waypoint-Vector2(0,40),9,Color("ffe1a1"))
	for number in combat.numbers:
		var alpha: float=1.0-number.age/0.7
		var at: Vector2=number.p+Vector2(12*number.age,-44*number.age)
		label(at+Vector2(1,2),number.value,23 if number.heavy else 17,Color(0.05,0.02,0.03,alpha))
		label(at,number.value,23 if number.heavy else 17,Color(1,0.82,0.48,alpha) if number.heavy else Color(1,0.96,0.85,alpha))
	# Translucent fog outside the shrinking safety circle.
	var safe := session.safe_radius()
	for x in range(maxi(0,int((camera.x-900)/100)*100),mini(int(session.ruins.extent.x),int(camera.x+900)),100):
		for y in range(maxi(0,int((camera.y-600)/100)*100),mini(int(session.ruins.extent.y),int(camera.y+600)),100):
			var dist := Vector2(x+50,y+50).distance_to(session.safe_center())
			if dist>safe:
				draw_rect(Rect2(x,y,100,100),Color(0.34,0.11,0.28,clampf((dist-safe)/220,0,0.44)))
	draw_arc(session.safe_center(),safe,0,TAU,160,Color(0.79,0.31,0.47,0.65),4)
	draw_set_transform(Vector2.ZERO)
	var size := get_viewport_rect().size
	if world.interior:
		for e in session.enemies:
			if e.type!=4 or e.p.distance_to(me)>850: continue
			var bar := Rect2(size.x/2-240,130,480,10)
			draw_rect(Rect2(bar.position-Vector2(15,42),Vector2(510,88)),Color(0.12,0.1,0.17,0.85))
			draw_rect(bar,Color("342c3a"))
			draw_rect(Rect2(bar.position,Vector2(bar.size.x*maxf(0,e.hp/e.max_hp),10)),Color("d6af83"))
			label(bar.position+Vector2(0,-14),"失乡骑士 · 王庭守誓者"+("  /  风暴觉醒" if e.hp<=e.max_hp*0.5 else ""),20,Color("f7e1b6"))
			label(bar.position+Vector2(0,32),"观察金色预警 · 闪避后反击 · 连续攻击使其失衡",14,Color("ead0b8"))
	# Night air outdoors; warm drifting motes in the candlelit palace.
	draw_rect(Rect2(0,0,size.x,110),Color(0.02,0.025,0.04,0.38))
	draw_rect(Rect2(0,size.y-100,size.x,100),Color(0.02,0.025,0.04,0.36))
	for i in 30:
		var pt := Vector2(fmod(i*127.1+clock*(5+i%4),size.x),fmod(i*79.3-clock*9+size.y*100,size.y))
		draw_circle(pt,1.2,Color(1,0.72,0.38,0.20) if world.interior else Color(1,0.25,0.34,0.25))
	draw_map(Rect2(size.x-250,124,220,174),false)
	if map_open:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.01,0.015,0.025,0.88))
		draw_map(map_rect(),true)
		label(size/2+Vector2(-470,-352),("晨曦王城" if world.interior else "月冠边境")+"  /  M 关闭   ·   左键标记目的地   ·   右键清除",19,Color("dad3c9"))
		label(size/2+Vector2(-470,389),"当前显示："+["全部地标","已探索物资","封印与撤离","怪物栖息区"][map_filter],13,Color("e2c795"))
		label(size/2+Vector2(-470,369),"1 全部  ·  2 物资  ·  3 封印与撤离   4 栖息区   |   金菱形：封印   绿十字：撤离   红圈：血潮边界",17,Color("969caa"))
	else:
		label(Vector2(32,325),"晨曦王城 · 烛火长夜" if world.interior else Ruins.BIOME_NAMES[world.biome_at(me)]+" · 血月之夜",22,Color("f1dfbf"))
		if not world.interior:
			var moon := Vector2(46,394)
			for radius in [25,21,17]: draw_circle(moon,radius,Color(0.8,0.08,0.16,0.07))
			draw_circle(moon,12,Color("cc485a"))
			draw_circle(moon+Vector2(-4,-3),3,Color(0.32,0.05,0.11,0.35))
			draw_circle(moon+Vector2(4,4),4,Color(0.32,0.05,0.11,0.25))
			label(Vector2(68,400),"血月当空",13,Color("d794a2"))
		if waypoint.x>=0: label(Vector2(32,355),"目的地  %d m" % int(me.distance_to(waypoint)/40),15,Color("e4c7a1"))
		var mouse := get_global_mouse_position()
		draw_arc(mouse,7,0,TAU,20,Color("e4c7b2"),1)
		draw_line(mouse-Vector2(12,0),mouse-Vector2(4,0),Color("e4c7b2"),1)
		draw_line(mouse+Vector2(4,0),mouse+Vector2(12,0),Color("e4c7b2"),1)

func actor(p: Dictionary) -> void:
	var pos: Vector2=smooth_positions.get(p.id,p.p)
	var h: Dictionary=Catalog.HEROES[p.hero]
	var color: Color=h.color
	var hair: Color=h.hair
	if p.status=="dead":
		draw_line(pos-Vector2(13,13),pos+Vector2(13,13),Color("85747b"),4)
		draw_line(pos+Vector2(13,-13),pos+Vector2(-13,13),Color("85747b"),4)
		return
	if p.status=="down":
		draw_circle(pos,25,Color(0.8,0.12,0.25,0.2))
		cross(pos,13,Color("e77a84"))
		label(pos+Vector2(-40,-36),"倒地  %ds" % p.bleed,13,Color("ed9d9e"))
		return
	draw_set_transform(offset+pos)
	draw_circle(Vector2(0,12),20,Color(0,0,0,0.35))
	if p.id==session.my_id():
		draw_arc(Vector2(0,8),22,0,TAU,36,Color(color,0.65),1.5)
	var moving := minf(1.0,float(velocity_visual.get(p.id,0.0))/100)
	var sway := sin(clock*(4+moving*9)+p.id)*(1.3+moving*2.0)
	var travelling: bool=p.motion in ["walk","run","dodge"] and p.swing_time<=0 and p.cast_time<=0
	var direction: Vector2=p.move_dir if travelling else p.strike_aim if p.swing_time>0 else p.aim
	if p.motion=="dodge":
		direction=p.dodge_dir
	var facing := -1.0 if direction.x<0 else 1.0
	var progress := 1.0-float(p.swing_time)/maxf(0.001,p.swing_total)
	var frame := 0
	var lean := 0.0
	var lunge := Vector2.ZERO
	if p.swing_time>0:
		var windup: float=Catalog.weapon(p.weapon).windup/maxf(0.001,p.swing_total)
		frame=1 if progress<windup else (2 if progress<windup+0.23 else 3)
		lean=(-0.08 if frame==1 else 0.12 if frame==2 else 0.04)*facing
		lunge=direction*(12 if frame==2 else -3 if frame==1 else 4)
	if p.cast_time>0:
		frame=1 if p.cast_time>0.55 else 2 if p.cast_time>0.2 else 3
		lean=-0.06*facing
	if travelling:
		var pose := character_frames.motion_frame(p.hero,p.motion,float(move_phases.get(p.id,0)),p.dodge_time)
		if p.motion=="dodge":
			for ghost in [3,2,1]:
				draw_set_transform(offset+pos-direction*ghost*17,0,Vector2(facing,1))
				draw_texture_rect(pose.texture,pose.rect,false,Color(color,0.21/ghost))
		draw_set_transform(offset+pos,0,Vector2(facing,1))
		draw_texture_rect(pose.texture,pose.rect,false)
	elif Catalog.weapon_family(p.weapon)>0:
		var pose := character_frames.attack_frame(p.hero,Catalog.weapon_family(p.weapon),frame)
		var sprite_rect: Rect2=pose.rect
		sprite_rect.position.y+=sway*0.35
		if frame==2 and p.swing_time>0:
			for ghost in [2,1]:
				draw_set_transform(offset+pos+lunge-direction*ghost*12,lean,Vector2(facing,1))
				draw_texture_rect(pose.texture,sprite_rect,false,Color(color,0.12/ghost))
		draw_set_transform(offset+pos+lunge,lean,Vector2(facing,1))
		draw_texture_rect(pose.texture,sprite_rect,false)
	else:
		var sheet_size := sentinels.get_size()
		draw_set_transform(offset+pos-direction*(5 if p.swing_time>0 else 0),lean,Vector2(facing,1))
		draw_texture_rect_region(sentinels,Rect2(-31,-70+sway,62,91),Rect2(p.hero*sheet_size.x/3,0,sheet_size.x/3,sheet_size.y))
	draw_set_transform(offset+pos)
	if p.invuln>0:
		draw_arc(Vector2.ZERO,32,0,TAU,40,Color(color,0.55),2)
	draw_set_transform(offset)
	label(pos+Vector2(-27,-88),p.name,12,color.lightened(0.25))
	draw_rect(Rect2(pos+Vector2(-23,-80),Vector2(46,3)),Color("322a35"))
	draw_rect(Rect2(pos+Vector2(-23,-80),Vector2(46*maxf(0,p.hp/p.max_hp),3)),color)
	if p.channel>0:
		var seconds := float(p.get("channel_total",4.0))
		draw_arc(pos,37,-PI/2,-PI/2+TAU*minf(1,p.channel/maxf(0.05,seconds)),40,Color("d9ca91"),4)

func monster(e: Dictionary) -> void:
	if e.get("raid_boss",false):
		draw_boss(e)
		return
	var pos: Vector2=e.p
	var kind: int=e.type
	var color: Color=EnemyFrames.COLORS[kind]
	var height: float=EnemyFrames.HEIGHTS[kind]
	var frame := EnemyFrames.pose(e,clock)
	var facing: float=e.get("facing",1.0)
	var biome: int=Ecology.BIOMES[kind] if kind>=5 else (session.ruins.biome_at(pos) if not session.ruins.interior else 5)
	var aura: Color=Ruins.COLORS[biome].darkened(0.28)
	draw_circle(pos+Vector2(0,8),Ecology.RADIUS[kind]+(5 if kind>=14 else 2),Color(aura,0.22 if kind>=5 else 0.0))
	draw_circle(pos+Vector2(0,8),Ecology.RADIUS[kind],Color(0,0,0,0.24))
	if float(e.get("attack_time",0))>0 and not e.get("attack_released",false):
		var aim: Vector2=e.get("attack_aim",Vector2.RIGHT)
		var progress: float=clampf((e.attack_total-e.attack_time)/Ecology.WINDUP[kind],0,1)
		draw_arc(pos,26+progress*8,aim.angle()-0.65,aim.angle()+0.65,20,Color(color,0.4+progress*0.5),2.5,true)
	if kind>=5 and float(e.get("attack_time",0))>0 and not e.get("attack_released",false):
		var aim: Vector2=e.attack_aim
		if kind in [8,10,11]:
			var point: Vector2=e.get("attack_point",pos)
			var radius := 60.0 if kind==11 else (76.0 if kind==8 else 100.0)
			draw_circle(point,radius,Color(color,0.16))
			draw_arc(point,radius,0,TAU,48,Color(color,0.85),2,true)
			if kind==11: draw_line(pos,point,Color(color,0.55),2,true)
		elif kind==7:
			draw_line(pos,pos+aim*235,Color(color,0.17),65,true)
			draw_line(pos,pos+aim*235,Color(color,0.9),2,true)
		elif kind==9:
			draw_arc(pos,85,0,TAU,40,Color(color,0.65),2,true)
		elif kind==12:
			for angle in [-0.5,0.0,0.5]:
				draw_line(pos,pos+aim.rotated(angle)*195,Color(color,0.4),2,true)
		elif kind==13:
			var sector := PackedVector2Array([pos])
			for i in 25: sector.append(pos+aim.rotated(lerpf(-1.05,1.05,i/24.0))*190)
			draw_colored_polygon(sector,Color(color,0.15))
			draw_arc(pos,190,aim.angle()-1.05,aim.angle()+1.05,32,Color(color,0.8),2,true)
		elif kind==14:
			draw_circle(pos,135,Color(color,0.13))
			draw_arc(pos,135,0,TAU,48,Color(color,0.85),3,true)
			for n in 12: draw_line(pos+Vector2.from_angle(n*TAU/12)*55,pos+Vector2.from_angle(n*TAU/12)*135,Color(color,0.42),2,true)
		elif kind==15:
			draw_arc(pos,145,0,TAU,48,Color(color,0.75),3,true)
			draw_arc(pos,85,0,TAU,40,Color(color,0.4),2,true)
		elif kind==16:
			var point: Vector2=e.get("attack_point",pos)
			draw_circle(point,145,Color(color,0.15))
			draw_arc(point,145,0,TAU,48,Color(color,0.85),3,true)
			draw_line(pos,point,Color(color,0.6),3,true)
	if kind==13 and e.get("attack_released",false) and float(e.get("attack_time",0))>0.35:
		var aim: Vector2=e.attack_aim
		var sweep: float=clampf((e.attack_total-e.attack_time-Ecology.WINDUP[kind])/0.25,0,1)
		var end: Vector2=pos+aim.rotated(lerpf(-1.05,1.05,sweep))*190
		draw_dashed_line(pos,end,Color("bd9874"),3,8,true)
		draw_circle(end,9,Color("d6b88c"))
	if kind==4 and not e.get("raid_boss",false): knight_telegraph(e)
	var hover := sin(clock*4+e.id)*3 if kind in [1,5,6,9,12] else 0.0
	if kind==11 and float(e.get("attack_time",0))>0:
		var progress: float=clampf((e.attack_total-e.attack_time-Ecology.WINDUP[kind])/0.48,0,1)
		hover=-sin(progress*PI)*44
	# All frames share a fixed canvas and foot anchor; mirroring never shifts feet.
	draw_set_transform(offset+pos+Vector2(0,hover),0,Vector2(facing,1))
	var tint := Color(1.6,1.5,1.5) if float(e.get("flash",0))>0 else Color.WHITE
	draw_texture_rect_region(enemy_frames.sheets[kind],EnemyFrames.sprite_rect(kind),enemy_frames.region(frame),tint)
	draw_set_transform(offset)
	if frame==6:
		var aim: Vector2=e.get("attack_aim",Vector2.RIGHT)
		if kind==1:
			draw_arc(pos+aim*24,12,0,TAU,24,Color(color,0.8),2,true)
		else:
			draw_arc(pos,38 if kind!=2 else 46,aim.angle()-0.8,aim.angle()+0.8,20,Color(color,0.85),3 if kind!=2 else 5,true)
	if kind in [3,4] or kind>=14:
		draw_arc(pos+Vector2(0,9),Ecology.RADIUS[kind]+8,0,TAU,40,Color(color,0.25),2,true)
		label(pos+Vector2(-28,-height-6),str(e.get("boss_name",EnemyFrames.NAMES[kind])),12,color)
	if e.hp<e.max_hp:
		var width := 80.0 if kind>=14 else 36.0
		draw_rect(Rect2(pos+Vector2(-width/2,-height-1),Vector2(width,4 if kind>=14 else 3)),Color("292431"))
		draw_rect(Rect2(pos+Vector2(-width/2,-height-1),Vector2(width*maxf(0,e.hp/e.max_hp),4 if kind>=14 else 3)),color)

func draw_map(rect: Rect2, big: bool) -> void:
	var outer := rect.grow(7)
	var cut := 16.0
	var corners := PackedVector2Array([outer.position+Vector2(cut,0),Vector2(outer.end.x-cut,outer.position.y),Vector2(outer.end.x,outer.position.y+cut),outer.end-Vector2(0,cut),outer.end-Vector2(cut,0),Vector2(outer.position.x+cut,outer.end.y),Vector2(outer.position.x,outer.end.y-cut),outer.position+Vector2(0,cut)])
	draw_colored_polygon(corners,Color(0.035,0.035,0.055,0.91))
	corners.append(corners[0])
	draw_polyline(corners,Color("7b6471"),1,true)
	for corner in [rect.position,rect.end,Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y)]:
		diamond(corner,3,Color("ba9d84"))
	var scale := rect.size/session.ruins.extent
	world_art.atlas(self,session.ruins,rect,big)
	var gate := rect.position+session.portal_position()*scale
	diamond(gate,8 if big else 4,Color("9de8f3"))
	if big: label(gate+Vector2(12,30),"城门 · 长按 E 切换地图" if session.can_travel() else "城门 · 血潮封锁",13,Color("9de8f3"))
	for site_index in session.ruins.sites.size():
		var site: Dictionary=session.ruins.sites[site_index]
		var at: Vector2=rect.position+site.p*scale
		var discovered := explored.has(Vector2i(site.p/160))
		if big:
			var ecology_view: bool=not session.ruins.interior and map_filter==3
			if ecology_view:
				var area: Rect2=site.rect.grow(170)
				var corners_block := PackedVector2Array([area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)])
				for polygon in Geometry2D.intersect_polygons(corners_block,session.ruins.regions[int(site.biome)].polygon):
					var outline := PackedVector2Array()
					for point in polygon: outline.append(rect.position+point*scale)
					draw_colored_polygon(outline,Color(0.15,0.12,0.2,0.35))
					outline.append(outline[0])
					draw_polyline(outline,Color("eac698"),1.5,true)
			draw_rect(Rect2(at-Vector2(7,6),Vector2(14,12)),Color("b5a585") if site.tier==1 else Color("c57b8e"),false,2)
			var caption: String=Ecology.RESIDENTS[int(site.biome)] if ecology_view else ("高危 · 珍藏" if site.tier==2 else "野外 · 补给")
			if not session.ruins.interior: caption=Ecology.site_status(session,site_index)
			var width: float=maxf(site.name.length()*14+8,caption.length()*11+8)
			draw_rect(Rect2(at+Vector2(8,-23),Vector2(width,38)),Color(0.06,0.075,0.085,0.93))
			label(at+Vector2(11,-8),site.name,14,Color("fff1d3"))
			label(at+Vector2(11,8),caption,11,Color("eed6ba") if ecology_view else (Color("e1a3b0") if site.tier==2 else Color("b7c8b8")))
		else: draw_circle(at,3 if site.get("cleared",false) else 2,Color("8fc39a") if site.get("cleared",false) else Color("bcb2a0"))
		if discovered: draw_arc(at,11,0,TAU,16,Color("b9d8ba"),1)
	if big and map_filter in [0,1]:
		for chest in session.ruins.chests:
			if not explored.has(Vector2i(chest.p/160)): continue
			var at: Vector2=rect.position+chest.p*scale
			draw_rect(Rect2(at-Vector2(2,2),Vector2(4,4)),Color("847e76") if chest.open and chest.items.is_empty() else Color("f3d794"))
	if not big or map_filter in [0,2]:
		for shrine in session.ruins.shrines:
			diamond(rect.position+shrine.p*scale,6 if big else 3,Color("7bc0af") if shrine.done else Color("ffe0a0"))
		for i in session.ruins.exits.size():
			var pos: Vector2=session.ruins.exits[i]
			cross(rect.position+pos*scale,8 if big else 4,Color("9bf8d6"))
			if big: label(rect.position+pos*scale+Vector2(-28,23),Ruins.EXIT_NAMES[i]+(" · 封锁" if not session.can_extract() else ""),11,Color("aeefce"))
	if waypoint.x>=0:
		var at: Vector2=rect.position+waypoint*scale
		diamond(at,8 if big else 4,Color("fff1a6"))
		var player: Dictionary=session.players.get(session.my_id(),{})
		if not player.is_empty(): draw_dashed_line(rect.position+player.p*scale,at,Color("e7d99d"),1,5)
	for p in session.players.values():
		if p.status in ["active","down"]:
			draw_circle(rect.position+p.p*scale,5 if big else 3,Catalog.HEROES[p.hero].color)
			if big:
				label(rect.position+p.p*scale+Vector2(8,4),p.name,12,Color("efdfd0"))
	if not session.ruins.interior and not session.raid.is_empty():
		var mark := rect.position+session.safe_center()*scale
		diamond(mark,10 if big else 5,Color("ff98b4"))
		if big: label(mark+Vector2(12,-14),"黎明印记 · "+session.expedition.NAMES[int(session.raid.kind)],14,Color("ffb8ca"))
	# Fog radius is clipped mathematically to the map rectangle.
	var center := rect.position+session.safe_center()*scale
	var prev := Vector2.ZERO
	for i in 181:
		var point := center+Vector2.from_angle(float(i)/180*TAU)*session.safe_radius()*scale
		if i>0 and rect.has_point(point) and rect.has_point(prev):
			draw_line(prev,point,Color("b65074"),1.5)
		prev=point

func label(at: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font,at+Vector2(1,1),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0.06,0.08,0.09,color.a*0.9))
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func diamond(pos: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-radius),pos+Vector2(radius,0),pos+Vector2(0,radius),pos+Vector2(-radius,0)]),color)

func cross(pos: Vector2, radius: float, color: Color) -> void:
	draw_line(pos-Vector2(0,radius),pos+Vector2(0,radius),color,2)
	draw_line(pos-Vector2(radius*0.7,0),pos+Vector2(radius*0.7,0),color,2)

func map_rect() -> Rect2:
	return Rect2(get_viewport_rect().size/2-Vector2(440,330),Vector2(880,660))

func _input(event: InputEvent) -> void:
	if not visible or not map_open: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_RIGHT:
			waypoint=Vector2(-1,-1)
		elif event.button_index==MOUSE_BUTTON_LEFT and map_rect().has_point(get_global_mouse_position()):
			var point := (get_global_mouse_position()-map_rect().position)/map_rect().size*session.ruins.extent
			if not session.ruins.blocked(point): waypoint=point
	if event is InputEventKey and event.pressed:
		var code: int=event.physical_keycode if event.physical_keycode else event.keycode
		if code in [KEY_1,KEY_2,KEY_3,KEY_4]: map_filter=code-KEY_1

func knight_telegraph(e: Dictionary) -> void:
	if e.attack_time<=0: return
	var passed: float=e.attack_total-e.attack_time
	var name: String=e.get("move_name","combo")
	var marks: Array=[0.65,1.10,1.65] if name=="combo" else ([0.85] if name=="thrust" else [1.15])
	var last: float=marks.back()
	if passed>last+0.2 and not (name=="thrust" and passed<1.2): return
	var direction: Vector2=e.attack_aim
	var col := Color(1.0,0.61,0.37,0.24+sin(clock*18)*0.06)
	if name=="thrust":
		var side := direction.orthogonal()*48
		draw_colored_polygon(PackedVector2Array([e.p-side,e.p+side,e.p+direction*340+side,e.p+direction*340-side]),col)
		draw_line(e.p,e.p+direction*340,Color("ffdea5"),3,true)
	else:
		var radius := 225.0 if name=="storm" else 155.0
		var arc := PI if name=="storm" else 1.35
		var poly := PackedVector2Array([e.p])
		for i in 49: poly.append(e.p+Vector2.from_angle(direction.angle()-arc+2*arc*i/48)*radius)
		draw_colored_polygon(poly,col)
		draw_arc(e.p,radius,direction.angle()-arc,direction.angle()+arc,48,Color("ffe1b6"),2,true)
	label(e.p+Vector2(-60,-178),{"combo":"誓约三连斩","thrust":"逐风突刺","storm":"失乡风暴"}[name],16,Color("ffe1b6"))

func draw_raid_world() -> void:
	if session.raid.is_empty(): return
	var center := session.safe_center()
	if session.raid.phase=="explore":
		draw_arc(center,65,0,TAU,64,Color("ed8faf"),3,true)
		diamond(center,22,Color("b66d9b"))
		label(center+Vector2(-125,-85),"黎明印记 · 缩圈完成后降临",17,Color("ffd2df"))
	for h in session.raid.hazards:
		var col := Color("e999bd")
		var progress: float=1.0-clampf(h.time/h.total,0,1)
		var fill := Color(col,0.14+progress*0.18 if not h.fired else 0.62)
		var at: Vector2=h.p
		var aim: Vector2=h.aim
		var radius: float=h.radius
		if h.shape=="line":
			var side := aim.orthogonal()*44
			var poly := PackedVector2Array([at-side-aim*22,at+side-aim*22,at+aim*radius+side,at+aim*radius-side])
			draw_colored_polygon(poly,fill)
			poly.append(poly[0])
			draw_polyline(poly,col,2,true)
		elif h.shape=="cone":
			var poly := PackedVector2Array([at])
			for i in 41: poly.append(at+Vector2.from_angle(aim.angle()-1.05+2.1*i/40)*radius)
			draw_colored_polygon(poly,fill)
			draw_arc(at,radius,aim.angle()-1.05,aim.angle()+1.05,40,col,2,true)
		else:
			if h.inner>0:
				for i in 64:
					var a := Vector2.from_angle(TAU*i/64)
					var b := Vector2.from_angle(TAU*(i+1)/64)
					draw_colored_polygon(PackedVector2Array([at+a*h.inner,at+a*radius,at+b*radius,at+b*h.inner]),fill)
				draw_arc(at,h.inner,0,TAU,64,col,2,true)
			else: draw_circle(at,radius,fill)
			draw_arc(at,radius,0,TAU,80,col,2,true)

func draw_boss(e: Dictionary) -> void:
	var kind: int=e.boss_kind
	var pos: Vector2=e.p
	var color: Color=BossFrames.COLORS[kind]
	var hover := sin(clock*2.6)*3.0 if kind!=1 else 0.0
	draw_set_transform(offset+pos,0,Vector2(1,0.34))
	draw_circle(Vector2.ZERO,45,Color(0.04,0.025,0.06,0.40))
	draw_arc(Vector2.ZERO,51,0,TAU,56,Color(color,0.38),3,true)
	draw_set_transform(offset+pos+Vector2(0,hover),0,Vector2(float(e.get("facing",1)),1))
	var tint := Color(1.3,1.2,1.2) if float(e.get("flash",0))>0 else Color.WHITE
	draw_texture_rect_region(boss_frames.sheets[kind],boss_frames.sprite_rect(kind),BossFrames.region(BossFrames.pose(e,clock)),tint)
	draw_set_transform(offset)
