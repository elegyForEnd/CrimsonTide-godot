extends Node2D
## Story adapter uses actual campaign events; rules and saves stay in Campaign.
const TONES := [Color("ef607f"),Color("94dbef"),Color("b99ae8")]
var screen
var finish=preload("res://scripts/combat_finish.gd").new()
var primary=preload("res://scripts/stylized_vfx.gd").new()
var lights=preload("res://scripts/combat_light_pool.gd").new()
var casts: Dictionary={}
var drops: Array=[]
var payloads: Array=[]
var weapon_world: Node3D
var weapon_flights: Node3D
var flight_serial := 0

var text: Node2D

func _ready() -> void:
	add_child(finish); add_child(primary)
	text=preload("res://scripts/combat_text.gd").new()
	text.projector=screen.project
	text.z_index=50
	add_child(text)
	screen.world.add_child(lights)
	weapon_world=preload("res://scripts/weapon_combat_vfx_3d.gd").new()
	weapon_world.camera=screen.world.view_camera
	weapon_world.height_at=func(p: Vector2): return screen.campaign.map.height_at(p)
	weapon_world.socket_provider=world_socket
	screen.world.add_child(weapon_world)
	weapon_flights=preload("res://scripts/weapon_projectile_vfx_3d.gd").new()
	weapon_flights.camera=screen.world.view_camera
	weapon_flights.height_at=weapon_world.height_at
	screen.world.add_child(weapon_flights)
	finish.projector=screen.project
	finish.lights=lights.pulse
	lights.height_at=func(p: Vector2): return screen.campaign.map.height_at(p)
	primary.socket_provider=socket
	screen.campaign.combat_event.connect(event)
	screen.campaign.location_changed.connect(reset)
	for i in 3: primary.set_skin(i,TONES[i])

func world_socket(id: int) -> Dictionary:
	# StoryWorld returns native viewport pixels, before the campaign Canvas scale.
	return screen.world.weapon_effect_socket(id)

func socket(id: int) -> Dictionary:
	if screen.has_method("weapon_effect_socket"):
		var mounted: Dictionary=screen.weapon_effect_socket(id)
		if not mounted.is_empty():
			for key in ["tip","grip","stroke_tip","stroke_pivot","stroke_center"]:
				if mounted.has(key): mounted[key]=get_global_transform()*Vector2(mounted[key])
			for key in ["aim","blade_axis"]:
				if mounted.has(key): mounted[key]=get_global_transform().basis_xform(Vector2(mounted[key])).normalized()
			return mounted
	if not casts.has(id): return {}
	var cast: Dictionary=casts[id]
	var ground: Transform2D=screen.ground_transform()
	var at: Vector2=get_global_transform()*Vector2(screen.project(cast.p))-Vector2(0,28)
	var aim: Vector2=ground.basis_xform(cast.aim).normalized()
	return {"tip":at+aim*40,"grip":at,"stroke_tip":at+aim*40,"stroke_pivot":at,"aim":aim,"blade_axis":aim,"active":true}

func event(data: Dictionary) -> void:
	if not screen.active: return
	text.on_event(data)
	if data.kind=="windup":
		casts[int(data.hero)]=data.duplicate()
		if weapon_world.event(data,int(data.hero)): return
		primary.transform=screen.ground_transform()
		var prep := data.duplicate()
		prep.p=primary.get_global_transform().affine_inverse()*(get_global_transform()*Vector2(screen.project(data.p)))
		prep.weapon=Catalog.weapon_family(int(data.weapon_index))
		primary.event(prep,int(data.hero)); return
	if data.kind in ["weapon_drop","equipment_drop"]:
		var drop := data.duplicate(true); drop.time=1.6
		drops.append(drop)
		queue_redraw(); return
	if data.kind!="story_attack":
		if weapon_world.event(data,int(data.get("hero",0))):
			if data.kind=="impact": lights.pulse(data.p,preload("res://scripts/weapon_vfx.gd").profile(int(data.weapon_index)).color,.7,.16)
			return
		var fx := data.duplicate()
		# True terrain projection owns contact height; no flat-plane offset.
		fx["contact_p"]=fx.p
		fx["contact_lift"]=24.0 if fx.kind=="impact" else 0.0
		finish.event(fx); return
	var hero: int=data.hero
	casts[hero]=data.duplicate()
	var special: int=data.special
	var weapon: int=int(data.get("weapon_index",[1,5,19][hero]))
	primary.transform=screen.ground_transform()
	var reach: float=data.radius
	var ground: Transform2D=primary.get_global_transform()
	var at: Vector2=ground.affine_inverse()*(get_global_transform()*Vector2(screen.project(data.p)))
	if special==2:
		primary.event({"kind":"skill","p":at,"aim":data.aim,"hero":hero,"id":hero},hero)
	else:
		weapon_world.event({"kind":"strike","p":data.p,"aim":data.aim,"hero":hero,"id":hero,"weapon":Catalog.weapon_family(weapon),
			"weapon_index":weapon,"reach":reach,"combo":0 if special==0 else 2,"vfx_action":"normal" if special==0 else "art"},hero)
		if Catalog.weapon_family(weapon) in [0,3]:
			var spell: String=str(Catalog.weapon(weapon).get("spell","star"))
			if spell=="prism":
				weapon_world.event({"kind":"spell_beam","p":data.p,"aim":data.aim,"hero":hero,"id":hero,"weapon":3,"weapon_index":weapon,"reach":reach,"width":30,"vfx_action":"normal" if special==0 else "art"},hero)
			else:
				var role := preload("res://scripts/weapon_mechanics.gd").projectile_role(weapon,spell)
				var mount := socket(hero)
				var lift := Vector2(0,-28)
				if not mount.is_empty(): lift=get_global_transform().affine_inverse()*Vector2(mount.tip)-Vector2(screen.project(data.p))
				flight_serial+=1
				# Campaign attacks resolve instantly; this is the same short visual
				# travel as before, now rendered in the world instead of on the UI.
				payloads.append({"p":data.p,"end":Vector2(data.p)+Vector2(data.aim)*reach,"lift":lift,"age":0.0,"life":.24,"weapon":weapon,"role":role,"hero":hero,"fx_id":-flight_serial,"vfx_action":"normal" if special==0 else "art"})
	if special==2:
		finish.event({"kind":"story_skill","p":data.p,"aim":data.aim,"radius":reach,"tone":TONES[hero],
			"weapon_index":weapon,"cone":TAU if special==2 else acos(-.1)*2 if special==1 else acos(.25)*2})

func advance(dt: float) -> void:
	for payload in payloads: payload.age+=dt
	payloads=payloads.filter(func(payload): return payload.age<payload.life)
	for drop in drops: drop.time-=dt
	drops=drops.filter(func(drop): return drop.time>0)
	queue_redraw()
	primary.transform=screen.ground_transform()
	primary.advance(dt); finish.advance(dt); lights.advance(dt)
	if is_instance_valid(weapon_world): weapon_world.advance(dt)
	if is_instance_valid(weapon_flights):
		weapon_flights.advance(dt)
		var visual_flights: Array=[]
		for payload in payloads:
			var progress := clampf(float(payload.age)/float(payload.life),0,1)
			visual_flights.append({"fx_id":payload.fx_id,"weapon_index":payload.weapon,"p":Vector2(payload.p).lerp(payload.end,progress),"height":55.0,"v":(Vector2(payload.end)-Vector2(payload.p))/float(payload.life),"vfx_action":payload.vfx_action})
		weapon_flights.observe(visual_flights,dt)

func reset() -> void:
	if is_instance_valid(weapon_world): weapon_world.reset()
	if is_instance_valid(weapon_flights): weapon_flights.reset()
	casts.clear(); drops.clear(); payloads.clear(); primary.reset(); finish.reset(); lights.reset(); text.reset(); queue_redraw()

func _draw() -> void:
	for payload in payloads:
		if is_instance_valid(weapon_flights): continue
		var progress: float=clampf(float(payload.age)/float(payload.life),0,1)
		var from: Vector2=Vector2(screen.project(payload.p))+Vector2(payload.lift)
		var to: Vector2=Vector2(screen.project(payload.end))+Vector2(payload.lift)
		var source := preload("res://scripts/weapon_image_art.gd").payload_source(int(payload.weapon),"projectile",str(payload.role))
		draw_set_transform(from.lerp(to,progress),(to-from).angle())
		preload("res://scripts/weapon_image_art.gd").stamp_mechanic(self,source,Vector2(90,42),Color(1,1,1,1.0-smoothstep(.7,1.0,progress)))
		draw_set_transform(Vector2.ZERO)
	for drop in drops:
		var progress := 1.0-float(drop.time)/1.6
		var color: Color=preload("res://scripts/story_inventory.gd").TONES[int(drop.quality)]
		color.a=minf(1,float(drop.time)*2)
		var at: Vector2=screen.project(drop.p)
		draw_arc(at,12+progress*25,0,TAU,32,Color(color,.45*color.a),2,true)
		var icon: Texture2D
		if drop.kind=="equipment_drop": icon=preload("res://scripts/story_ui_skin.gd").item_icon(str(drop.base))
		else:
			var canonical := preload("res://scripts/weapon_image_art.gd").canonical(int(drop.weapon_index))
			icon=preload("res://scripts/rogue_build_art.gd").item_icon({"kind":"weapon","weapon":canonical})
		var raised := at-Vector2(0,48+progress*34)
		if icon!=null: draw_texture_rect(icon,Rect2(raised-Vector2(18,36),Vector2(36,36)),false,Color(1,1,1,color.a))
		var label: String=str(drop.get("name",Catalog.weapon_name(int(drop.get("weapon_index",1)))))
		var font := ThemeDB.fallback_font
		draw_string(font,raised-Vector2(font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x*.5,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,17,color)
