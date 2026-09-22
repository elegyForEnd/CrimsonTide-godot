class_name Battlefield
extends Node2D

var session: TideSession
var camera := Vector2(300,1100)
var offset := Vector2.ZERO
var clock := 0.0
var map_open := false
var font: Font
var follow_id := 1
var explored: Dictionary = {}
var sentinels: Texture2D
var smooth_positions: Dictionary = {}
var ground: Texture2D
var enemy_art: Texture2D
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
	enemy_art=load("res://assets/enemies.png")
	for kind in Catalog.ITEMS:
		loot_icons[kind]=load("res://assets/icons/"+kind+".svg")
	combat=CombatVisuals.new()
	combat.field=self
	add_child(combat)
	character_frames=CharacterFrames.new()
	session.effect.connect(combat.legacy)
	session.combat_event.connect(combat.event)
	session.started.connect(func(): combat.reset(); smooth_positions.clear(); previous_positions.clear(); velocity_visual.clear(); move_phases.clear())

func _process(dt: float) -> void:
	if not visible:
		return
	clock+=dt
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
		target=target.clamp(half,Ruins.SIZE-half)
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
	draw_rect(Rect2(Vector2.ZERO,Ruins.SIZE),Color("171c25"))
	# Painterly stone material preserves readability without flat debug tiles.
	for x in range(0,2800,420):
		for y in range(0,2200,420):
			if Vector2(x,y).distance_to(camera)>1050:
				continue
			draw_texture_rect(ground,Rect2(x,y,420,420),false,Color(0.56,0.56,0.64,1))
	for y in [1100]:
		draw_rect(Rect2(50,y-93,2700,186),Color(0.23,0.18,0.23,0.23))
		for x in range(70,2720,100):
			draw_line(Vector2(x,y-84),Vector2(x+96,y-84),Color("625360"),1)
			draw_line(Vector2(x,y+84),Vector2(x+96,y+84),Color("625360"),1)
	for site in world.sites:
		var rect: Rect2=site.rect
		draw_rect(rect.grow(12),Color("0e111a"))
		draw_texture_rect(ground,rect,false,Color(0.68,0.52,0.57,1) if site.tier==2 else Color(0.5,0.57,0.66,1))
		for i in 5:
			draw_line(rect.position+Vector2(30+i*90,20),rect.position+Vector2(30+i*90,rect.size.y-20),Color("30313c"),1)
		draw_circle(site.p,105,Color(0.4,0.19,0.25,0.09))
		draw_arc(site.p,104,0,TAU,64,Color("463440"),1.5)
		draw_line(site.p-Vector2(90,0),site.p+Vector2(90,0),Color("41323e"),1)
		draw_line(site.p-Vector2(0,90),site.p+Vector2(0,90),Color("41323e"),1)
		label(site.p+Vector2(-90,-155),site.name,18,Color("777987"))
		for side in [-1,1]:
			var candle: Vector2=site.p+Vector2(side*(rect.size.x/2-55),-100)
			for glow in range(4,0,-1):
				draw_circle(candle,float(glow*16),Color(0.9,0.37,0.19,0.022))
			draw_line(candle,candle+Vector2(0,30),Color("151521"),6)
			draw_line(candle+Vector2(-11,6),candle+Vector2(11,6),Color("685344"),2)
			for flame in [-9,0,9]:
				draw_line(candle+Vector2(flame,4),candle+Vector2(flame,-5),Color("b69873"),3)
				draw_circle(candle+Vector2(flame,-7),2.5+sin(clock*7+flame)*0.5,Color("efb47a"))
	for stone in world.decor:
		if stone.p.distance_to(camera)>1000:
			continue
		if stone.type==0:
			draw_rect(Rect2(stone.p,Vector2(stone.r*2,stone.r)),Color("383c48"))
		elif stone.type==1:
			draw_line(stone.p,stone.p+Vector2(17,9),Color("101720"),2)
		else:
			draw_circle(stone.p,stone.r*2,Color(0.28,0.07,0.12,0.18))
	# Broken memorials in the outer lanes frame the ruined city.
	for i in 22:
		var grave := Vector2(140+i*120,110 if i%2==0 else 2075)
		draw_rect(Rect2(grave+Vector2(-14,-21),Vector2(28,42)),Color("303544"))
		draw_arc(grave-Vector2(0,21),14,PI,TAU,16,Color("5c6070"),3)
		cross(grave-Vector2(0,7),8,Color("60616c"))
		draw_rect(Rect2(grave+Vector2(-20,19),Vector2(40,7)),Color("3d4050"))
	for wall in world.walls:
		draw_rect(Rect2(wall.position+Vector2(5,8),wall.size+Vector2(5,14)),Color(0,0,0,0.48))
		draw_rect(wall,Color("292b37"))
		var top := Rect2(wall.position-Vector2(0,12),wall.size)
		draw_texture_rect(ground,top,false,Color(0.95,0.83,0.86,1))
		draw_rect(top,Color("65606d"),false,1)
		draw_line(top.position,top.position+Vector2(top.size.x,0),Color("99909a"),1)
		if wall.size.y>100:
			for y in range(int(wall.position.y),int(wall.end.y),40):
				draw_line(Vector2(wall.position.x,y),Vector2(wall.end.x,y),Color("262b35"),2)
		else:
			for x in range(int(wall.position.x),int(wall.end.x),38):
				draw_line(Vector2(x,wall.position.y),Vector2(x,wall.end.y),Color("262b35"),1)
		for endpoint in [wall.position,wall.end-Vector2(18,18)]:
			var cap: Vector2=endpoint+Vector2(9,-4)
			draw_rect(Rect2(cap-Vector2(13,13),Vector2(26,26)),Color("252430"))
			draw_rect(Rect2(cap-Vector2(10,13),Vector2(20,19)),Color("53505d"))
			draw_rect(Rect2(cap-Vector2(10,13),Vector2(20,19)),Color("817784"),false,1)
			diamond(cap-Vector2(0,3),5,Color("aea090"))
	for i in world.exits.size():
		var pos: Vector2=world.exits[i]
		var pulse := 0.5+sin(clock*2)*0.12
		draw_circle(pos,83,Color(0.32,0.74,0.66,0.07))
		draw_arc(pos,70+sin(clock*2)*4,0,TAU,60,Color(0.4,0.8,0.73,pulse),2)
		draw_arc(pos,50,0,TAU,48,Color("467b77"),1)
		cross(pos,20,Color("80cabc"))
		label(pos+Vector2(-52,103),["西门撤离点","东门撤离点","北门撤离点"][i],15,Color("89b8b0"))
	for shrine in world.shrines:
		var pos: Vector2=shrine.p
		var color := Color("7accb4") if shrine.done else Color("ddb675")
		draw_circle(pos,40,Color(color,0.07))
		draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-30),pos+Vector2(19,0),pos+Vector2(0,20),pos+Vector2(-19,0)]),Color("353446"))
		cross(pos-Vector2(0,12),15,color)
		label(pos+Vector2(-40,45),"已点亮" if shrine.done else "晨钟封印",14,color)
	for chest in world.chests:
		var pos: Vector2=chest.p
		var empty: bool=chest.items.is_empty()
		draw_rect(Rect2(pos-Vector2(21,12),Vector2(46,31)),Color(0,0,0,0.35))
		draw_rect(Rect2(pos-Vector2(21,18),Vector2(42,29)),Color("333039") if empty else Color("665544"))
		draw_rect(Rect2(pos-Vector2(21,18),Vector2(42,29)),Color("4a4650") if empty else Color("c2a277"),false,1.5)
		draw_line(pos+Vector2(-20,-5),pos+Vector2(20,-5),Color("29242b"),3)
		draw_rect(Rect2(pos-Vector2(3,7),Vector2(6,12)),Color("5a555a") if empty else Color("e1ba76"))
		if not empty:
			draw_circle(pos+Vector2(0,-23),2+sin(clock*3),Color("e2c186"))
	for drop in session.drops:
		var color: Color=Catalog.ITEMS[drop.kind].color
		draw_circle(drop.p,17,Color(color,0.1))
		draw_texture_rect(loot_icons[drop.kind],Rect2(drop.p+Vector2(-12,-16+sin(clock*3)*2),Vector2(24,24)),false)
	for e in session.enemies:
		monster(e)
	for p in session.players.values():
		if p.status!="extracted":
			actor(p)
	for number in combat.numbers:
		var alpha: float=1.0-number.age/0.7
		var at: Vector2=number.p+Vector2(12*number.age,-44*number.age)
		label(at+Vector2(1,2),number.value,23 if number.heavy else 17,Color(0.05,0.02,0.03,alpha))
		label(at,number.value,23 if number.heavy else 17,Color(1,0.82,0.48,alpha) if number.heavy else Color(1,0.96,0.85,alpha))
	# Translucent fog outside the shrinking safety circle.
	var safe := session.safe_radius()
	for x in range(0,2800,100):
		for y in range(0,2200,100):
			var dist := Vector2(x+50,y+50).distance_to(Ruins.CENTER)
			if dist>safe:
				draw_rect(Rect2(x,y,100,100),Color(0.34,0.11,0.28,clampf((dist-safe)/220,0,0.44)))
	draw_arc(Ruins.CENTER,safe,0,TAU,160,Color(0.79,0.31,0.47,0.65),4)
	draw_set_transform(Vector2.ZERO)
	var size := get_viewport_rect().size
	# Framing and a restrained red ambience.
	draw_rect(Rect2(0,0,size.x,110),Color(0.02,0.025,0.04,0.38))
	draw_rect(Rect2(0,size.y-100,size.x,100),Color(0.02,0.025,0.04,0.36))
	for i in 30:
		var pt := Vector2(fmod(i*127.1+clock*(5+i%4),size.x),fmod(i*79.3-clock*9+size.y*100,size.y))
		draw_circle(pt,1.2,Color(0.9,0.45,0.48,0.18))
	draw_map(Rect2(size.x-250,124,220,174),false)
	if map_open:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.01,0.015,0.025,0.88))
		draw_map(Rect2(size/2-Vector2(490,340),Vector2(980,690)),true)
		label(size/2+Vector2(-470,-360),"废墟战术地图   /   M 关闭     绿色：撤离  ·  金色：目标  ·  红色：毒雾",19,Color("dad3c9"))
		label(size/2+Vector2(-470,380),"保持通讯。每位守夜人都可以独立撤离。",17,Color("969caa"))
	else:
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
		var windup: float=Catalog.WEAPONS[p.weapon].windup/maxf(0.001,p.swing_total)
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
	elif p.weapon>0:
		var pose := character_frames.attack_frame(p.hero,p.weapon,frame)
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
		var seconds := 4.0 if p.target.begins_with("exit") else (3.0 if p.target.begins_with("shrine") or p.target.begins_with("revive") else 0.6)
		draw_arc(pos,37,-PI/2,-PI/2+TAU*minf(1,p.channel/seconds),40,Color("d9ca91"),4)

func monster(e: Dictionary) -> void:
	var pos: Vector2=e.p
	var color: Color=[Color("a66172"),Color("a68abf"),Color("847b88"),Color("e05870")][e.type]
	var radius := 25.0 if e.type==3 else 17.0
	draw_circle(pos+Vector2(0,10),radius+3,Color(0,0,0,0.3))
	var dims := enemy_art.get_size()
	var bounds: Array=[Vector2(0,0.25),Vector2(0.25,0.5),Vector2(0.5,0.79),Vector2(0.79,1.0)]
	var interval: Vector2=bounds[e.type]
	var region := Rect2(interval.x*dims.x,0,(interval.y-interval.x)*dims.x,dims.y)
	var height: float=[80.0,92.0,104.0,132.0][e.type]
	var width := height*region.size.x/region.size.y
	var sway := sin(clock*(3 if e.type==1 else 7)+e.id)*2
	draw_texture_rect_region(enemy_art,Rect2(pos+Vector2(-width/2,-height+20+sway),Vector2(width,height)),region,Color(3.5,3.2,3.0,1) if float(e.get("flash",0))>0 else Color(1.15,1.06,1.1,1))
	if e.type==3:
		draw_arc(pos+Vector2(0,9),35,0,TAU,40,Color(color,0.25),2,true)
		label(pos+Vector2(-28,-height+8),"血香猎手",12,color)
	if e.hp<e.max_hp:
		draw_rect(Rect2(pos+Vector2(-18,-height-1),Vector2(36,3)),Color("292431"))
		draw_rect(Rect2(pos+Vector2(-18,-height-1),Vector2(36*maxf(0,e.hp/e.max_hp),3)),color)

func draw_map(rect: Rect2, big: bool) -> void:
	var outer := rect.grow(7)
	var cut := 16.0
	var corners := PackedVector2Array([outer.position+Vector2(cut,0),Vector2(outer.end.x-cut,outer.position.y),Vector2(outer.end.x,outer.position.y+cut),outer.end-Vector2(0,cut),outer.end-Vector2(cut,0),Vector2(outer.position.x+cut,outer.end.y),Vector2(outer.position.x,outer.end.y-cut),outer.position+Vector2(0,cut)])
	draw_colored_polygon(corners,Color(0.035,0.035,0.055,0.91))
	corners.append(corners[0])
	draw_polyline(corners,Color("7b6471"),1,true)
	for corner in [rect.position,rect.end,Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y)]:
		diamond(corner,3,Color("ba9d84"))
	var scale := rect.size/Ruins.SIZE
	for site in session.ruins.sites:
		draw_rect(Rect2(rect.position+site.rect.position*scale,site.rect.size*scale),Color("3f3d49"))
		if big:
			label(rect.position+site.p*scale+Vector2(-48,-16),site.name,14,Color("9793a3"))
	for shrine in session.ruins.shrines:
		diamond(rect.position+shrine.p*scale,6 if big else 3,Color("7bc0af") if shrine.done else Color("e0b86e"))
	for pos in session.ruins.exits:
		cross(rect.position+pos*scale,8 if big else 4,Color("82cabb"))
	for p in session.players.values():
		if p.status in ["active","down"]:
			draw_circle(rect.position+p.p*scale,5 if big else 3,Catalog.HEROES[p.hero].color)
			if big:
				label(rect.position+p.p*scale+Vector2(8,4),p.name,12,Color("efdfd0"))
	# Fog radius is clipped mathematically to the map rectangle.
	var center := rect.position+Ruins.CENTER*scale
	var prev := Vector2.ZERO
	for i in 181:
		var point := center+Vector2.from_angle(float(i)/180*TAU)*session.safe_radius()*scale
		if i>0 and rect.has_point(point) and rect.has_point(prev):
			draw_line(prev,point,Color("b65074"),1.5)
		prev=point

func label(at: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func diamond(pos: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-radius),pos+Vector2(radius,0),pos+Vector2(0,radius),pos+Vector2(-radius,0)]),color)

func cross(pos: Vector2, radius: float, color: Color) -> void:
	draw_line(pos-Vector2(0,radius),pos+Vector2(0,radius),color,2)
	draw_line(pos-Vector2(radius*0.7,0),pos+Vector2(radius*0.7,0),color,2)
