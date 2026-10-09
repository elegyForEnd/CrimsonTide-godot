class_name Battlefield
extends Node2D
const WorldPresentation = preload("res://scripts/world_3d.gd")
const Idle = preload("res://scripts/character_idle.gd")
var idle = Idle.new()
var idle_billboards = preload("res://scripts/character_idle_billboards.gd").new()
var world_3d: Node3D
var world_pose := Transform2D.IDENTITY
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
var extraction_sigil: Texture2D = preload("res://assets/world/landmarks/extraction-sigil.png")
var boss_sigil: Texture2D = preload("res://assets/world/landmarks/boss-sigil.png")
var shrine_sigil: Texture2D = preload("res://assets/world/landmarks/shrine-sigil.png")
var enemy_frames: EnemyFrames
var boss_frames: BossFrames
# Portrait art for the special encounters, indexed exactly like
# BossFrames.SPECIAL_KEYS so the boss HUD, the cut-in and the boss sprite all
# agree on which creature an index means.
const SPECIAL_BOSS_ART := [preload("res://assets/bosses/new/mirror-weaver.png"),
	preload("res://assets/bosses/new/ashen-vesper.png"),
	preload("res://assets/bosses/new/nameless-moon.png"),
	preload("res://assets/bosses/wild/earthsplitter.png"),
	preload("res://assets/bosses/wild/storm-roc-v2.png"),
	preload("res://assets/bosses/wild/moon-leviathan.png"),
	preload("res://assets/bosses/dragon/frostbone-dragon.png")]
var special_boss_art: Array=SPECIAL_BOSS_ART
var boss_seen: Dictionary={}
var boss_health: Dictionary={}
var defeated_enemies: Array = []
var velocity_visual: Dictionary = {}
var previous_positions: Dictionary = {}
var loot_icons: Dictionary = {}
var combat: CombatVisuals
var boss_fx: Node2D
# The danger pass owns every ordinary enemy windup: saturated colour, charging
# fill, white-hot edge, countdown ring and release flash.
var telegraph = preload("res://scripts/attack_telegraph.gd").new()
var character_frames: CharacterFrames
var move_phases: Dictionary = {}
var blood_tide = preload("res://scripts/blood_tide.gd").new()
var chest_sync_timer := 0.0

func _ready() -> void:
	world_3d=WorldPresentation.new()
	add_child(world_3d)
	world_3d.add_child(idle_billboards)
	visibility_changed.connect(func(): world_3d.visible=visible)
	world_3d.visible=visible
	blood_tide.setup(self)
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
	session.enemy_bodies.enemies=enemy_frames
	session.enemy_bodies.bosses=boss_frames
	var boss_layer := CanvasLayer.new()
	boss_layer.layer=1
	add_child(boss_layer)
	var boss_hud := preload("res://scripts/boss_hud.gd").new()
	boss_hud.field=self
	boss_layer.add_child(boss_hud)
	for kind in Catalog.ITEMS:
		# `TideUIArt.icon()` already knows the shared reliquary atlas, the collectible
		# sheets, the homestead produce atlas and the bespoke SVGs, in that order. Asking it
		# directly is what keeps the six crops, the bait and the three seed packets from
		# looking for an icon file that was never drawn. Only a kind no table knows reaches
		# the legacy SVG path, and that path asks whether the file is there first.
		var art: Texture2D=TideUIArt.icon(kind)
		if art!=null:
			loot_icons[kind]=art
		else:
			var legacy := "res://assets/icons/"+Catalog.kind_icon(kind)+".svg"
			if ResourceLoader.exists(legacy):
				loot_icons[kind]=load(legacy)
	# Field equipment resolves to its own weapon / slot icon, so preload those too,
	# plus any standalone icon a recruit's issue weapon ships with.
	for icon in Catalog.WEAPON_ICONS+Catalog.GEAR_ICONS:
		loot_icons[icon]=TideUIArt.icon(icon)
	for starter in Catalog.STARTER_WEAPONS:
		if starter.has("icon"):
			loot_icons[str(starter.icon)]=TideUIArt.icon(str(starter.icon))
	combat=CombatVisuals.new()
	combat.field=self
	add_child(combat)
	boss_fx=preload("res://scripts/boss_vfx.gd").new()
	boss_fx.field=self
	add_child(boss_fx)
	session.combat_event.connect(boss_fx.event)
	session.map_changed.connect(boss_fx.reset)
	session.started.connect(boss_fx.reset)
	character_frames=CharacterFrames.new()
	session.effect.connect(combat.legacy)
	session.combat_event.connect(combat.event)
	session.combat_event.connect(func(event: Dictionary):
		if event.kind=="enemy_defeated":
			var fallen := event.duplicate()
			fallen["age"]=0.0
			defeated_enemies.append(fallen))
	session.map_changed.connect(func(): chest_sync_timer=0.0; waypoint=Vector2(-1,-1); explored.clear(); defeated_enemies.clear(); combat.reset(); smooth_positions.clear(); previous_positions.clear(); camera=session.players.get(session.my_id(),{"p":RoyalCity.GATE}).p)
	session.started.connect(func(): chest_sync_timer=0.0; boss_seen.clear(); boss_health.clear(); waypoint=Vector2(-1,-1); map_filter=0; defeated_enemies.clear(); combat.reset(); smooth_positions.clear(); previous_positions.clear(); velocity_visual.clear(); move_phases.clear())

func _process(dt: float) -> void:
	if not visible:
		blood_tide.update(self)
		return
	clock+=dt
	for actor: Dictionary in session.players.values(): idle.tick(actor,dt)
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
	world_3d.sync(session.ruins,camera,get_viewport_rect().size)
	chest_sync_timer-=dt
	if chest_sync_timer<=0.0:
		world_3d.sync_chests(session.ruins.chests)
		chest_sync_timer=0.2
	var shake := Vector2(sin(clock*89),cos(clock*107))*combat.trauma*combat.trauma*13
	world_3d.view_camera.h_offset=shake.x*WorldPresentation.UNIT
	world_3d.view_camera.v_offset=shake.y*WorldPresentation.UNIT
	offset=world_3d.project(Vector2.ZERO)
	blood_tide.update(self)
	queue_redraw()

func aim() -> Vector2:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return Vector2.RIGHT
	return (world_3d.unproject(get_global_mouse_position())-p.p).normalized()

## 世界标签里"按键字样"的真值是玩家判定半径（与 session 的交互判定同源，单一来源是
## session.gd 的 GATE_RADIUS / EXIT_RADIUS / SEARCH_RADIUS / DROP_RADIUS 常量）。
## 相机 1500 只决定"纯地名"的可见性，按键字样一律按玩家距离出——远处只显示纯地名，
## 不出 [E]/[F]/[H]。
func key_hint(at: Vector2, radius: float) -> bool:
	var me: Dictionary=session.players.get(session.my_id(),{})
	return (not me.is_empty()) and at.distance_to(me.p)<radius

func _draw() -> void:
	if not session or session.ruins.sites.is_empty():
		return
	world_3d.begin_sprites()
	idle_billboards.begin()
	set_world_transform()
	var world := session.ruins
	var gate := session.portal_position()
	var visible_distance_sq := 1500.0*1500.0
	if gate.distance_squared_to(camera)<visible_distance_sq:
		draw_arc(gate,45,0,TAU,48,Color("a5ebed"),4,true)
		var gate_text: String="血潮封锁 · 城门关闭"
		if session.can_travel():
			gate_text="返回月冠边境" if world.interior else "进入晨曦王城"
			if key_hint(gate,session.GATE_RADIUS):
				gate_text+=" [E]"
		label(gate+Vector2(-95,-58),gate_text,18,Color("ecdfba"))
	for site in world.sites:
		if site.p.distance_to(camera)<1000:
			label(site.p+Vector2(-80,-site.rect.size.y/2-45),site.name,19,Color("fff1db"))
	for i in world.exits.size():
		var pos: Vector2=world.exits[i]
		if pos.distance_squared_to(camera)>visible_distance_sq: continue
		var channel := extraction_progress(i)
		var gate_rect := Rect2(pos-Vector2(105,52),Vector2(210,105))
		if channel>0:
			draw_texture_rect(extraction_sigil,gate_rect.grow(3+channel*7),false,Color(0.30,1.0,0.78,0.15+channel*0.24))
		draw_texture_rect(extraction_sigil,gate_rect,false,Color.WHITE if session.can_extract() else Color(0.48,0.52,0.55,0.74))
		var exit_text: String=Ruins.EXIT_NAMES[i]
		if not session.can_extract():
			exit_text+=" · 封锁"
		elif key_hint(pos,session.EXIT_RADIUS):
			exit_text+=" · [E] 撤离"
		label(pos+Vector2(-58,80),exit_text,15,Color("a5ead6") if session.can_extract() else Color("98a3aa"))
	for shrine in world.shrines:
		var pos: Vector2=shrine.p
		if pos.distance_squared_to(camera)>visible_distance_sq: continue
		var color := Color("9ee7ce") if shrine.done else Color("e8bf81")
		var shrine_rect := Rect2(pos-Vector2(63,31),Vector2(126,63))
		if shrine.done:
			draw_texture_rect(shrine_sigil,shrine_rect.grow(3+sin(clock*2)*2),false,Color(0.48,1.0,0.78,0.16))
		draw_texture_rect(shrine_sigil,shrine_rect,false,Color.WHITE if shrine.done else Color(0.91,0.86,0.83))
		label(pos+Vector2(-40,50),"已点亮" if shrine.done else "晨钟封印",14,color)
	for chest in world.chests:
		var pos: Vector2=chest.p
		if pos.distance_squared_to(camera)>visible_distance_sq: continue
		var empty: bool=chest.open and chest.items.is_empty()
		if chest.get("fixed_loot",false) and not empty:
			var reward_color: Color=Catalog.BAG_TIERS[int(chest.get("reward_tier",4))].color
			draw_circle(pos,48,Color(reward_color,0.16))
			draw_line(pos,pos-Vector2(0,85),Color(reward_color,0.5),5,true)
			var caption := session.container_title(chest)
			if key_hint(pos,session.SEARCH_RADIUS):
				caption+=" · [F] 搜索"
			label(pos+Vector2(-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x/2,-94),caption,16,reward_color)
		var revealed: int=int(chest.get("searched",0))
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
		if at.distance_squared_to(camera)>visible_distance_sq: continue
		var is_bag := str(bag.get("key","")).begins_with("bag:")
		var bundled: bool=session.container_units(bag)>1
		if is_bag:
			var bag_colour: Color=Catalog.tier(str(bag.key).substr(4)).color
			draw_rect(Rect2(at-Vector2(13,15),Vector2(26,30)),Color(bag_colour.darkened(0.68),0.95))
			draw_rect(Rect2(at-Vector2(13,15),Vector2(26,30)),Color(bag_colour,0.9),false,1.5)
			draw_arc(at-Vector2(0,15),10,PI,TAU,14,Color(bag_colour.lightened(0.2)),2.5)
			draw_line(at-Vector2(13,0),at+Vector2(13,0),Color(bag_colour.darkened(0.3)),1)
			var bag_text := Catalog.bag_quality({"key":str(bag.key).substr(4)})+"背包"
			if key_hint(at,session.DROP_RADIUS):
				bag_text+=(" · [H] 搜索" if bundled else " · [F] 拾取")
			label(at+Vector2(-30,-40),bag_text,12,bag_colour.lightened(0.25))
		elif bundled:
			draw_rect(Rect2(at-Vector2(15,13),Vector2(30,26)),Color("625b69"))
			draw_rect(Rect2(at-Vector2(15,13),Vector2(30,26)),Color("b7a6b8"),false,1.5)
			var pack_text := "掉落包"
			if key_hint(at,session.DROP_RADIUS):
				pack_text+=" · [H] 搜索"
			label(at+Vector2(-40,-36),pack_text,12,Color("d3c4d5"))
		else:
			for item in Catalog.container_items(bag):
				var colour: Color=Catalog.item_color(item)
				draw_circle(at,17,Color(colour,0.1))
				draw_texture_rect(loot_icons[Catalog.item_icon(item)],Rect2(at+Vector2(-12,-16+sin(clock*3)*2),Vector2(24,24)),false)
				draw_arc(at,20+sin(clock*2)*2,0,TAU,24,Color(colour,0.45),1)
	for fallen in defeated_enemies:
		if int(fallen.get("boss_kind",-1))>=0:
			var kind: int=clampi(int(fallen.boss_kind),0,2)
			if fallen.get("mini_boss",false) or fallen.get("final_form",false) or fallen.get("abyss_final",false):
				draw_special_boss(fallen,1-fallen.age/1.6)
			else:
				set_world_transform(fallen.p,0,Vector2(fallen.facing,1))
				draw_billboard_region(boss_frames.sheets[kind],boss_frames.sprite_rect(kind),BossFrames.region(11),Color(1,1,1,1-fallen.age/1.6))
				set_world_transform()
			continue
		set_world_transform(fallen.p,0,Vector2(fallen.facing,1))
		draw_billboard_region(enemy_frames.sheets[int(fallen.type)],EnemyFrames.sprite_rect(int(fallen.type)),enemy_frames.region(11),Color(1,1,1,1-fallen.age/0.55))
		set_world_transform()
	if not world.interior:
		draw_raid_world()
	# Stable billboard submission order; the 3D depth buffer handles scenery occlusion.
	var drawables: Array=[]
	for e in session.enemies:
		if e.p.distance_to(camera)<1100: drawables.append({"p":e.p,"kind":1,"data":e})
	for p in session.players.values():
		if p.status!="extracted": drawables.append({"p":p.p,"kind":2,"data":p})
	drawables.sort_custom(func(a: Dictionary,b: Dictionary): return a.p.y<b.p.y)
	var me: Vector2=session.players.get(session.my_id(),{"p":camera}).p
	for item in drawables:
		match item.kind:
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
	world_3d.end_sprites()
	blood_tide.draw(self)
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
		label(size/2+Vector2(-470,369),"1 全部  ·  2 物资  ·  3 封印与撤离   4 栖息区   |   晨钟：封印   青门：撤离   赤晶：Boss 点",17,Color("969caa"))
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
	set_world_transform(pos)
	draw_circle(Vector2.ZERO,20,Color(0,0,0,0.35))
	if p.id==session.my_id():
		draw_arc(Vector2.ZERO,22,0,TAU,36,Color(color,0.65),1.5)
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
		frame=CharacterFrames.attack_pose_frame(p)
		lean=(-0.08 if frame==1 else 0.12 if frame==2 else 0.04)*facing
		lunge=direction*(12 if frame==2 else -3 if frame==1 else 4)
	if p.cast_time>0:
		frame=1 if p.cast_time>0.55 else 2 if p.cast_time>0.2 else 3
		lean=-0.06*facing
	var generated_attack := character_frames.has_generated(p.hero,Catalog.weapon_family(p.weapon))
	if generated_attack:
		if p.swing_time>0:
			frame=GeneratedAttacks.timeline_frame(float(p.swing_total)-float(p.swing_time),float(p.swing_total),float(Catalog.weapon(p.weapon).windup))
		elif p.cast_time>0:
			frame=GeneratedAttacks.timeline_frame(0.75-float(p.cast_time),0.75,0.55)
		lean=0.0
		lunge=Vector2.ZERO
	if travelling:
		var pose := character_frames.held_motion_frame(p,p.motion,float(move_phases.get(p.id,0)),p.dodge_time)
		if p.motion=="dodge":
			for ghost in [3,2,1]:
				set_world_transform(pos-direction*ghost*17,0,Vector2(facing,1))
				draw_billboard(pose.texture,pose.rect,false,Color(color,0.21/ghost))
		set_world_transform(pos,0,Vector2(facing,1))
		draw_billboard(pose.texture,pose.rect,false)
		draw_held_glow(pose)
	elif p.has("weapon_hold") and p.weapon_hold.get("shown",false):
		var pose := character_frames.equipped_attack_frame(p)
		set_world_transform(pos,0,Vector2(facing,1))
		draw_billboard(pose.texture,pose.rect,false)
	elif Idle.active(p):
		var pose := character_frames.held_idle_frame(p.hero,p.weapon,float(idle.sample(p).time))
		if pose.get("weapon_atlas",false):
			set_world_transform(pos,0,Vector2(facing,1))
			draw_billboard(pose.texture,pose.rect,false)
			draw_held_glow(pose)
		else:
			var state := idle.sample(p)
			var side: float=float(pose.get("hand_side",1.0))
			var data := Idle.geometry(pose,p.weapon,state.time,state.blend,side)
			idle_billboards.submit(p.id,data,world_3d.point(pos,2),world_3d.view_camera,facing)
	elif Catalog.weapon_family(p.weapon)==0:
		var pose := character_frames.equipped_attack_frame(p)
		set_world_transform(pos,0,Vector2(facing,1))
		draw_billboard(pose.texture,pose.rect,false)
	elif Catalog.weapon_family(p.weapon)>0 or p.hero==3:
		var pose := character_frames.equipped_attack_frame(p)
		if pose.get("weapon_atlas",false):
			# Authored poses already contain the weight transfer. Translating
			# and rotating the whole canvas again would slide the planted boot.
			lean=0.0
			lunge=Vector2.ZERO
		var sprite_rect: Rect2=pose.rect
		if not generated_attack and not pose.get("weapon_atlas",false): sprite_rect.position.y+=sway*0.35
		if not generated_attack and frame==2 and p.swing_time>0:
			for ghost in [2,1]:
				set_world_transform(pos+lunge-direction*ghost*12,lean,Vector2(facing,1))
				draw_billboard(pose.texture,sprite_rect,false,Color(color,0.12/ghost))
		set_world_transform(pos+lunge,lean,Vector2(facing,1))
		draw_billboard(pose.texture,sprite_rect,false)
	else:
		var sheet_size := sentinels.get_size()
		set_world_transform(pos-direction*(5 if p.swing_time>0 else 0),lean,Vector2(facing,1))
		draw_billboard_region(sentinels,Rect2(-31,-86+sway,62,91),Rect2(p.hero*sheet_size.x/3,0,sheet_size.x/3,sheet_size.y))
	set_world_transform(pos)
	if p.invuln>0:
		draw_arc(Vector2.ZERO,32,0,TAU,40,Color(color,0.55),2)
	set_actor_overlay(pos)
	label(pos+Vector2(-27,-104),p.name,12,color.lightened(0.25))
	preload("res://scripts/weapon_hold_attack.gd").draw_bar(self,p,pos+Vector2(0,-119))
	draw_rect(Rect2(pos+Vector2(-23,-96),Vector2(46,3)),Color("322a35"))
	draw_rect(Rect2(pos+Vector2(-23,-96),Vector2(46*maxf(0,p.hp/p.max_hp),3)),color)
	set_world_transform()
	if p.channel>0:
		var seconds := float(p.get("channel_total",4.0))
		draw_arc(pos,37,-PI/2,-PI/2+TAU*minf(1,p.channel/maxf(0.05,seconds)),40,Color("9af8dc") if str(p.get("target","")).begins_with("exit:") else Color("d9ca91"),4)

func monster(e: Dictionary) -> void:
	if e.get("boss_construct",false): return # Dedicated boss layer draws targetable constructs.
	if e.get("mini_boss",false):
		draw_special_boss(e)
		return
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
	# Danger pass: the whole windup, the countdown and the release flash are
	# painted against the same footprint the damage rule will actually use.
	if kind==4 and not e.get("raid_boss",false):
		knight_telegraph(e)
	elif float(e.get("attack_time",0))>0:
		telegraph.paint(self,ground_transform(),font,e,kind,clock)
	if kind==13 and e.get("attack_released",false) and float(e.get("attack_time",0))>0.35:
		var aim: Vector2=e.attack_aim
		var sweep: float=clampf((e.attack_total-e.attack_time-Ecology.WINDUP[kind])/0.25,0,1)
		var end: Vector2=pos+aim.rotated(lerpf(-1.05,1.05,sweep))*190
		draw_dashed_line(pos,end,Color("ffd27a"),5,8,true)
		draw_circle(end,10,Color("fff2c8"))
	# All frames share a fixed canvas and foot anchor; mirroring never shifts feet.
	var body_pose: Dictionary=session.enemy_bodies.pose(e,session.elapsed,false)
	set_world_transform(pos+Vector2(0,float(body_pose.hover)),0,Vector2(float(body_pose.facing),1))
	# A charging enemy heats up in its own danger colour, so the sprite reads as
	# "about to swing" even when the ground paint sits behind scenery.
	var heat := 0.0
	if float(e.get("attack_time",0))>0 and not e.get("attack_released",false):
		var charge := clampf((float(e.get("attack_total",0))-float(e.get("attack_time",0)))/maxf(.01,float(Ecology.WINDUP[kind])),0,1)
		heat=(0.30+0.70*charge)*(0.72+0.28*sin(clock*(8.0+18.0*charge)+float(e.id)))
	var tint := Color.WHITE
	if float(e.get("flash",0))>0:
		tint=Color(2.7,1.9,1.9)
	elif heat>0.001:
		var hot := telegraph.tint(kind)
		tint=Color.WHITE.lerp(Color(hot.r*2.0,hot.g*2.0,hot.b*2.0),heat*0.62)
	draw_billboard_region(body_pose.texture,body_pose.rect,body_pose.region,tint)
	set_world_transform()
	if frame==6 and kind!=4:
		var aim: Vector2=e.get("attack_aim",Vector2.RIGHT)
		var hot := telegraph.tint(kind)
		if kind==1:
			draw_arc(pos+aim*24,15,0,TAU,24,Color(hot,0.92),4,true)
			draw_arc(pos+aim*24,15,0,TAU,24,Color(1,1,1,0.75),1.8,true)
		else:
			var shock := 46.0 if kind==2 else 38.0
			draw_arc(pos,shock,aim.angle()-0.85,aim.angle()+0.85,22,Color(hot,0.95),5 if kind==2 else 4,true)
			draw_arc(pos,shock,aim.angle()-0.85,aim.angle()+0.85,22,Color(1,1,1,0.8),2,true)
	if kind in [3,4] or kind>=14:
		draw_arc(pos+Vector2(0,9),Ecology.RADIUS[kind]+8,0,TAU,40,Color(color,0.25),2,true)
	set_actor_overlay(pos)
	if kind in [3,4] or kind>=14:
		label(pos+Vector2(-28,-height-6),str(e.get("boss_name",EnemyFrames.NAMES[kind])),12,color)
	if e.hp<e.max_hp:
		var width := 80.0 if kind>=14 else 36.0
		draw_rect(Rect2(pos+Vector2(-width/2,-height-1),Vector2(width,4 if kind>=14 else 3)),Color("292431"))
		draw_rect(Rect2(pos+Vector2(-width/2,-height-1),Vector2(width*maxf(0,e.hp/e.max_hp),4 if kind>=14 else 3)),color)

	set_world_transform()

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
			var marker: Color=Catalog.quality_color(int(chest.cache_tier)) if chest.has("cache_tier") else Color("f3d794")
			draw_rect(Rect2(at-Vector2(2,2),Vector2(4,4)),Color("847e76") if chest.open and chest.items.is_empty() else marker)
	if not big or map_filter in [0,2]:
		for shrine in session.ruins.shrines:
			var icon_at: Vector2=rect.position+shrine.p*scale
			var icon_size := 30.0 if big else 13.0
			draw_texture_rect(shrine_sigil,Rect2(icon_at-Vector2(icon_size/2,icon_size/4),Vector2(icon_size,icon_size/2)),false,Color.WHITE if shrine.done else Color("e7c591"))
		for i in session.ruins.exits.size():
			var pos: Vector2=session.ruins.exits[i]
			var icon_at: Vector2=rect.position+pos*scale
			var icon_size := 32.0 if big else 15.0
			draw_texture_rect(extraction_sigil,Rect2(icon_at-Vector2(icon_size/2,icon_size/4),Vector2(icon_size,icon_size/2)),false,Color.WHITE if session.can_extract() else Color(0.58,0.62,0.65))
			if big: label(icon_at+Vector2(-28,23),Ruins.EXIT_NAMES[i]+(" · 封锁" if not session.can_extract() else ""),11,Color("aeefce"))
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
		var icon_size := 38.0 if big else 18.0
		draw_texture_rect(boss_sigil,Rect2(mark-Vector2(icon_size/2,icon_size/4),Vector2(icon_size,icon_size/2)),false)
		if big: label(mark+Vector2(12,-14),"黎明印记 · "+session.expedition.NAMES[int(session.raid.kind)],14,Color("ffb8ca"))
		for e in session.enemies:
			if not e.get("mini_boss",false) or e.hp<=0: continue
			var mini_at: Vector2=rect.position+e.p*scale
			var mini_color: Color=Color("9ce9ff") if e.get("dragon_boss",false) else [Color("d9aa68"),Color("87dfff")][clampi(int(e.get("wild_kind",0)),0,1)] if e.get("wild_boss",false) else Color("a8dbff") if int(e.mini_kind)==0 else Color("ff8d66")
			diamond(mini_at,8 if big else 5,mini_color)
			if big: label(mini_at+Vector2(12,5),str(e.boss_name)+(" · 龙巢遗珍" if e.get("dragon_boss",false) else " · 异兽遗藏" if e.get("wild_boss",false) else " · 守卫秘藏"),12,mini_color)
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
	guard_telegraph(e)
	if e.get("choreo_cast",false):
		if e.attack_time>0: label(e.p+Vector2(-80,-178),str(e.move_name),15,Color("ffe1b6"))
		return
	if e.attack_time<=0: return
	var passed: float=e.attack_total-e.attack_time
	var name: String=e.get("move_name","combo")
	var spec: Dictionary=TideSession.BossTactics.KNIGHT_MOVES.get(name,TideSession.BossTactics.KNIGHT_MOVES.combo)
	var marks: Array=spec.marks
	var last: float=marks.back()
	if passed>last+0.2 and not (name=="thrust" and passed<1.2): return
	boss_fx.knight(self,e)
	var next_hit := 0.0
	for mark in marks:
		if float(mark)>passed:
			next_hit=float(mark)-passed
			break
	label(e.p+Vector2(-95,-178),str(spec.label)+"  %.1fs" % next_hit,15,Color("ffe1b6"))

func guard_telegraph(e: Dictionary) -> void:
	if float(e.get("stagger",0))>0 and e.get("move_name","")=="架势崩解 · 趁机进攻":
		label(e.p+Vector2(-65,85),"破防 · 进攻窗口",16,Color("ffd891"))
	if float(e.get("guard_time",0))<=0: return
	var raised: bool=e.guard_time<=TideSession.BossTactics.GUARD_DURATION-TideSession.BossTactics.GUARD_WINDUP
	var col := Color("83dcf5") if raised else Color("e8ca87")
	label(e.p+Vector2(-95,85),"正面格挡 · 绕背 / 重击" if raised else "抬剑架势 · 尚未格挡",15,col)

func extraction_progress(index: int) -> float:
	for player in session.players.values():
		if player.status=="active" and str(player.get("target", ""))=="exit:%d" % index:
			return maxf(0.01,clampf(float(player.get("channel",0.0))/4.0,0.0,1.0))
	return 0.0

func draw_raid_world() -> void:
	if session.raid.is_empty(): return
	var center := session.safe_center()
	var sigil_rect := Rect2(center-Vector2(115,57),Vector2(230,115))
	if session.raid.phase=="explore":
		draw_texture_rect(boss_sigil,sigil_rect.grow(4+sin(clock*2.3)*3),false,Color(1,0.22,0.42,0.15))
		draw_texture_rect(boss_sigil,sigil_rect,false)
		label(center+Vector2(-125,80),"黎明印记 · 缩圈完成后降临",17,Color("ffd2df"))
	elif session.raid.phase in ["boss","choice"]:
		draw_texture_rect(boss_sigil,sigil_rect,false,Color(1,1,1,0.74))
	for h in session.raid.hazards:
		var tempo := str(h.get("tempo",""))
		var col := Color("ffa779") if tempo=="快" else (Color("d5a1ff") if tempo=="慢" else Color("e999bd"))
		var at: Vector2=h.p
		var aim: Vector2=h.aim
		var radius: float=h.radius
		boss_fx.hazard(self,h)
		if not tempo.is_empty() and not h.fired:
			var caption_at: Vector2=at+aim*radius*0.85+Vector2(0,18) if h.shape in ["line","cone"] else at+Vector2(-24,radius+18)
			label(caption_at,"%s %.1fs" % [tempo,maxf(0,h.time)],12,col)

func draw_boss(e: Dictionary) -> void:
	if e.get("final_form",false) or e.get("abyss_final",false):
		draw_special_boss(e)
		return
	var kind: int=clampi(int(e.boss_kind),0,2)
	var pos: Vector2=e.p
	var color: Color=BossFrames.COLORS[kind]
	set_world_transform(pos,0,Vector2(1,0.34))
	draw_circle(Vector2.ZERO,45,Color(0.04,0.025,0.06,0.40))
	draw_arc(Vector2.ZERO,51,0,TAU,56,Color(color,0.38),3,true)
	var body_pose: Dictionary=session.enemy_bodies.pose(e,session.elapsed,false)
	set_world_transform(pos+Vector2(0,float(body_pose.hover)),0,Vector2(float(body_pose.facing),1))
	var tint := Color(1.3,1.2,1.2) if float(e.get("flash",0))>0 else Color.WHITE
	draw_billboard_region(body_pose.texture,body_pose.rect,body_pose.region,tint)
	set_world_transform()
	guard_telegraph(e)

func draw_special_boss(e: Dictionary, alpha: float = 1.0) -> void:
	var index: int=6 if e.get("dragon_boss",false) else 3+clampi(int(e.get("wild_kind",0)),0,2) if e.get("wild_boss",false) else 2 if e.get("final_form",false) else clampi(int(e.get("mini_kind",0)),0,1)
	var tex: Texture2D=boss_frames.special_sheet(index)
	var pos: Vector2=e.p
	var sprite: Rect2=boss_frames.special_sprite_rect(index)
	var height: float=BossFrames.SPECIAL_HEIGHTS[index]
	var width: float=sprite.size.x
	var color: Color=[Color("a8dbff"),Color("ff8d66"),Color("ff4a70"),Color("d9aa68"),Color("87dfff"),Color("b86bff"),Color("9ce9ff")][index]
	set_world_transform(pos,0,Vector2(1,0.34))
	draw_circle(Vector2.ZERO,49 if index==2 else 39,Color(0.04,0.015,0.04,0.48*alpha))
	draw_arc(Vector2.ZERO,58 if index==2 else 46,0,TAU,56,Color(color,0.58*alpha),3,true)
	set_world_transform(pos,0,Vector2(float(e.get("facing",1)),1))
	var appearance: float=0.26 if index==3 and e.has("travel_target") else 0.68 if index==4 and e.has("travel_target") else 1.0
	var tint := Color(1.45,1.3,1.3,alpha*appearance) if float(e.get("flash",0))>0 else Color(1,1,1,alpha*appearance)
	var frame := 11 if alpha<1.0 else BossFrames.pose(e,clock)
	if alpha>=1.0:
		var body_pose: Dictionary=session.enemy_bodies.pose(e,session.elapsed,false)
		set_world_transform(pos+Vector2(0,float(body_pose.hover)),0,Vector2(float(body_pose.facing),1))
		draw_billboard_region(body_pose.texture,body_pose.rect,body_pose.region,tint)
	else:
		draw_billboard_region(tex,sprite,BossFrames.region(frame),tint)
	set_world_transform()
	if alpha>=1.0:
		set_actor_overlay(pos)
		label(pos+Vector2(-width/2,-height-12),str(e.get("boss_name","")),13,color)
		var bar := 110.0 if index==2 else 85.0
		draw_rect(Rect2(pos+Vector2(-bar/2,-height-7),Vector2(bar,4)),Color("201924"))
		draw_rect(Rect2(pos+Vector2(-bar/2,-height-7),Vector2(bar*clampf(float(e.hp)/maxf(1,float(e.max_hp)),0,1),4)),color)

	set_world_transform()

## Shared projection contract for ground effects and mouse picking.
func ground_transform() -> Transform2D:
	return world_3d.ground_transform()

func weapon_effect_socket(source: int) -> Dictionary:
	var p: Dictionary=session.players.get(source,{})
	if p.is_empty() or p.status!="active": return {}
	var family := Catalog.weapon_family(p.weapon)
	var active_attack: bool=p.swing_time>0 or p.cast_time>0
	var aim: Vector2=p.strike_aim if p.swing_time>0 else p.aim
	var frame := CharacterFrames.attack_pose_frame(p)
	var facing := -1.0 if aim.x<0 else 1.0
	var upright_weapon: bool=family>0
	var lunge := aim*(12 if frame==2 else -3 if frame==1 else 4) if p.swing_time>0 and upright_weapon else Vector2.ZERO
	var authored: bool=character_frames.equipped_attack_frame(p).get("weapon_atlas",false)
	if authored: lunge=Vector2.ZERO
	var pose := character_frames.equipped_attack_frame(p)
	if not active_attack and p.motion in ["walk","run"]:
		pose=character_frames.held_motion_frame(p,p.motion,float(move_phases.get(p.id,0)),p.dodge_time)
		facing=-1.0 if p.move_dir.x<0 else 1.0
	var tip: Vector2=Vector2(pose.get("socket",character_frames.equipped_weapon_tip(p)))*Vector2(facing,1)
	# submit_sprite uses a two-unit height and ignores the legacy pose lean.
	var pos: Vector2=smooth_positions.get(p.id,p.p)
	var at: Vector2=world_3d.view_camera.unproject_position(world_3d.point(pos+lunge,2))
	var moving := minf(1.0,float(velocity_visual.get(p.id,0.0))/100)
	var sway := sin(clock*(4+moving*9)+p.id)*(1.3+moving*2)
	if upright_weapon and not authored: tip.y+=sway*.35
	var screen_aim := ground_transform().basis_xform(aim).normalized()
	# Release toward mouse aim, including the hand's sideways reach.
	if p.has("weapon_hold"):
		tip=preload("res://scripts/weapon_held_glow.gd").charge_anchor(pose)*Vector2(facing,1)
	var grip: Vector2=Vector2(pose.get("grip",pose.get("socket",Vector2.ZERO)))*Vector2(facing,1)
	var blade_axis := (tip-grip).normalized()
	var mount := CharacterMetrics.aimed_mount(at,grip,tip,screen_aim)
	var stroke_pivot: Vector2=mount.pivot
	var stroke_tip: Vector2=mount.tip
	var charge_points: Array[Vector2]=[]
	if p.has("weapon_hold"):
		for site in preload("res://scripts/weapon_held_glow.gd").charge_sites(pose):
			charge_points.append(at+site*Vector2(facing,1))
	return {"charge_points":charge_points,"tip":at+tip,"stroke_tip":stroke_tip,"stroke_pivot":stroke_pivot,"stroke_center":mount.center,"aim":screen_aim,
		"grip":at+grip,"blade_axis":blade_axis,"frame":int(pose.get("frame",2)),"weapon_identity":preload("res://scripts/weapon_image_art.gd").canonical(p.weapon),"active":active_attack}

func set_world_transform(at: Vector2 = Vector2.ZERO, angle: float = 0.0, scale_value: Vector2 = Vector2.ONE) -> void:
	world_pose=Transform2D(angle,scale_value,0,at)
	draw_set_transform_matrix(ground_transform()*world_pose)

func draw_billboard(texture: Texture2D, rect: Rect2, _tile: bool = false, tint: Color = Color.WHITE) -> void:
	# The 2D atlas pivot intentionally sat 16 pixels below the simulation point.
	# In 3D that would place the boots below the floor. Use the actual foot pivot.
	rect.position-=CharacterMetrics.FOOT_OFFSET
	world_3d.submit_sprite(texture,rect,Rect2(),tint,world_pose)

func draw_held_glow(pose: Dictionary) -> void:
	for glint in preload("res://scripts/weapon_held_glow.gd").samples(pose,clock):
		draw_billboard(glint.texture,glint.rect,false,glint.tint)

func draw_billboard_region(texture: Texture2D, rect: Rect2, region: Rect2, tint: Color = Color.WHITE) -> void:
	world_3d.submit_sprite(texture,rect,region,tint,world_pose)


func set_actor_overlay(at: Vector2) -> void:
	# Nameplates stay upright above billboard heads instead of flattening onto terrain.
	draw_set_transform(world_3d.project(at)-at)
