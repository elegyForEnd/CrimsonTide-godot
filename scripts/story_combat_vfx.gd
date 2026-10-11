extends Node2D
## Story adapter uses actual campaign events; rules and saves stay in Campaign.
const TONES := [Color("ef607f"),Color("94dbef"),Color("b99ae8")]
var screen
var finish=preload("res://scripts/combat_finish.gd").new()
var primary=preload("res://scripts/stylized_vfx.gd").new()
var lights=preload("res://scripts/combat_light_pool.gd").new()
var casts: Dictionary={}

func _ready() -> void:
	add_child(finish); add_child(primary)
	screen.world.add_child(lights)
	finish.projector=screen.project
	finish.lights=lights.pulse
	lights.height_at=func(p: Vector2): return screen.campaign.map.height_at(p)
	primary.socket_provider=socket
	screen.campaign.combat_event.connect(event)
	screen.campaign.location_changed.connect(reset)
	for i in 3: primary.set_skin(i,TONES[i])

func socket(id: int) -> Dictionary:
	if not casts.has(id): return {}
	var cast: Dictionary=casts[id]
	var ground: Transform2D=screen.ground_transform()
	var at: Vector2=get_global_transform()*Vector2(screen.project(cast.p))-Vector2(0,28)
	var aim: Vector2=ground.basis_xform(cast.aim).normalized()
	return {"tip":at+aim*40,"grip":at,"stroke_tip":at+aim*40,"stroke_pivot":at,"aim":aim,"blade_axis":aim,"active":true}

func event(data: Dictionary) -> void:
	if not screen.active: return
	if data.kind!="story_attack":
		var fx := data.duplicate()
		# True terrain projection owns contact height; no flat-plane offset.
		fx["contact_p"]=fx.p
		fx["contact_lift"]=24.0 if fx.kind=="impact" else 0.0
		finish.event(fx); return
	var hero: int=data.hero
	casts[hero]=data.duplicate()
	var special: int=data.special
	primary.transform=screen.ground_transform()
	var reach: float=data.radius
	var ground: Transform2D=primary.get_global_transform()
	var at: Vector2=ground.affine_inverse()*(get_global_transform()*Vector2(screen.project(data.p)))
	if special==2:
		primary.event({"kind":"skill","p":at,"aim":data.aim,"hero":hero,"id":hero},hero)
	elif hero!=1:
		primary.event({"kind":"strike","p":at,"aim":data.aim,"hero":hero,"id":hero,"weapon":1,
			"weapon_index":1 if hero==0 else 19,"reach":minf(245,reach),"combo":0 if special==0 else 2},hero)
	else:
		primary.event({"kind":"strike","p":at,"aim":data.aim,"hero":hero,"id":hero,"weapon":3,"weapon_index":5,"reach":30,"combo":special},hero)
	if special>0:
		finish.event({"kind":"story_skill","p":data.p,"aim":data.aim,"radius":reach,"tone":TONES[hero],
			"weapon_index":[1,5,19][hero],"cone":TAU if special==2 else acos(-.1)*2 if special==1 else acos(.25)*2})

func advance(dt: float) -> void:
	primary.transform=screen.ground_transform()
	primary.advance(dt); finish.advance(dt); lights.advance(dt)

func reset() -> void:
	casts.clear(); primary.reset(); finish.reset(); lights.reset()
