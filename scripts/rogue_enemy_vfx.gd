extends Node2D
## Presentation follows authoritative damage zones; never creates damage itself.
const Semantics = preload("res://scripts/effect_semantics.gd")
var field: Control
var energy = preload("res://scripts/energy_bursts.gd").new()
var particles=preload("res://scripts/combat_particles.gd").new()
var elapsed := 0.0
var bosses = preload("res://scripts/rogue_boss_effects.gd").new()
var charge_seen: Dictionary={}
var trails: Array=[]
var support_links: Array=[]
const TONES := [Color("6cedce"),Color("ff9b56"),Color("bfa1ff"),Color("83dcff"),Color("ff638a")]

func _ready() -> void:
	z_index=2
	add_child(energy)
	add_child(particles)
	bosses.field=field
	add_child(bosses)

func reset() -> void:
	bosses.reset()
	particles.reset()
	energy.reset()
	charge_seen.clear()
	trails.clear()
	support_links.clear()

func event(data: Dictionary) -> void:
	bosses.event(data)
	transform=field.ground_transform()
	var kind: String=data.kind
	var floor_index: int=int(data.get("floor",data.get("rogue_floor",-1)))
	if kind=="rogue-zone":
		if absf(data.p.x-field.camera.x)<1050: burst(data.fx)
		return
	if kind=="enemy_defeated" or (kind=="rogue-minion" and data.action=="interrupt"):
		energy.cancel_charge(data.id)
		charge_seen.erase(data.id)
		particles.stop("minion:"+str(data.id))
	if floor_index<0 or data.p.distance_to(field.camera)>1100: return
	var tone: Color=TONES[floor_index]
	var at: Vector2=data.p
	var direction: Vector2=data.get("aim",Vector2.RIGHT)
	if kind=="rogue-minion":
		var variant: int=data.variant
		var style: String=Semantics.style(str(data.get("move","")),floor_index)
		var particle_key := "minion:"+str(data.id)
		if data.action=="charge": particles.start(particle_key,at-Vector2(0,28),direction,tone,style,"gather",float(data.get("duration",.55)),28,28)
		elif data.action=="release": particles.stop(particle_key); particles.burst(at+direction*24-Vector2(0,25),direction,tone,style,16,.9,1.3)
		elif data.action=="interrupt": particles.stop(particle_key)
		match str(data.action):
			"counter":
				energy.spawn(at+direction*30,Vector2(105,40),tone,1,.3,direction.angle())
			"charge":
				charge_seen[data.id]=true
				energy.spawn(at-Vector2(0,28),Vector2.ONE*(42 if variant<2 else 65),Color(tone,.5),4,float(data.get("duration",.55)),0,0,1.05,int(data.id))
				if data.get("move","") in ["heal","sacrifice_heal","repair","shield","haste","armor","speed","power"]:
					support_links.append({"a":at,"b":data.target,"floor":floor_index,"age":0.0,"life":float(data.get("duration",.55)),"source":data.id,"target_id":data.get("target_id",-1),"channel":true})
			"interrupt":
				energy.cancel_charge(data.id)
				charge_seen.erase(data.id)
				energy.particles(at-Vector2(0,30),tone,7,Vector2.UP,150,.3,floor_index)
			"release":
				energy.cancel_charge(data.id)
				charge_seen.erase(data.id)
				match variant:
					1:
						energy.spawn(at-direction*32,Vector2(105,34),tone,1,.3,direction.angle())
						energy.particles(at-direction*45,tone,12,-direction,35,.55,floor_index)
					2:
						energy.spawn(at+direction*24,Vector2.ONE*58,tone,2,.28)
						energy.particles(at+direction*20,tone,12,direction,30,.4,floor_index)
					3:
						energy.particles(at-Vector2(0,30),tone,12,Vector2.UP,100,.4,floor_index)
	elif kind=="rogue-boss-charge":
		pass # Dedicated painted guardian layer owns anticipation.
	elif kind=="rogue-support":
		var style: String=data.style
		var support_tone := Color("8cffc2") if style in ["heal","sacrifice_heal","repair"] else tone
		support_links.append({"a":at,"b":data.target,"floor":floor_index,"age":0.0,"life":.7,"source":data.id,"target_id":data.get("target_id",-1),"channel":false})
		energy.spawn(data.target-Vector2(0,35),Vector2(70,90),support_tone,4 if style=="shield" else 2,.7)
		energy.particles(data.target-Vector2(0,25),support_tone,18,Vector2.UP,60,.55,floor_index)
	elif kind=="impact":
		pass # Weapon layer owns the single directional contact response.
	elif kind=="rogue-projectile-impact":
		energy.spawn(at,Vector2.ONE*48,tone,2,.24)
		energy.particles(at,tone,10,Vector2.UP,180,.35,floor_index)
	elif kind=="enemy_defeated":
		energy.cancel_charge(data.id)
		charge_seen.erase(data.id)
		var big: bool=data.get("rogue_guardian",false)
		if big: return # Dedicated fall event owns the guardian finish.
		energy.spawn(at-Vector2(0,35),Vector2.ONE*(150 if big else 64),tone,2,.6)
		energy.particles(at-Vector2(0,30),tone,38 if big else 15,Vector2.UP,150,1.0 if big else .5,floor_index)

func _process(dt: float) -> void:
	if not field.visible: return
	elapsed+=dt
	transform=field.ground_transform()
	energy.advance(dt)
	for key in particles.emitters.keys():
		if not str(key).begins_with("minion:"): continue
		var found := false
		for e in field.session.enemies:
			if e.id==int(str(key).get_slice(":",1)) and e.hp>0 and e.attack_time>0:
				particles.move(key,e.p-Vector2(0,28)); found=true; break
		if not found: particles.stop(key)
	particles.advance(dt)
	for i in range(support_links.size()-1,-1,-1):
		var link: Dictionary=support_links[i]
		link.age+=dt
		var living := false
		var target_living: bool=int(link.get("target_id",-1))<0
		for e in field.session.enemies:
			if e.id==link.source and e.hp>0 and (not link.channel or e.attack_time>0): living=true; link.a=e.p
			if e.id==int(link.get("target_id",-1)) and e.hp>0: target_living=true; link.b=e.p
		if link.age>=link.life or not living or not target_living: support_links.remove_at(i)
	for i in range(trails.size()-1,-1,-1):
		trails[i].age+=dt
		if trails[i].age>.24: trails.remove_at(i)
	for bullet in field.session.bullets:
		if not bullet.has("rogue_tone") or absf(bullet.p.x-field.camera.x)>1000: continue
		if bullet.get("rogue_guardian",false): continue
		if elapsed>=float(bullet.get("vfx_trail",0)):
			bullet["vfx_trail"]=elapsed+.04
			if trails.size()>=220: trails.pop_front()
			trails.append({"p":bullet.p,"floor":bullet.rogue_tone,"age":0.0,"aim":bullet.v.angle()})
	queue_redraw()

func _draw() -> void:
	for link in support_links:
		var tone: Color=TONES[int(link.floor)]
		var a: Vector2=link.a-Vector2(0,35)
		var b: Vector2=link.b-Vector2(0,35)
		var alpha: float=smoothstep(0,.10,float(link.age))*(1.0-link.age/link.life)
		draw_line(a,b,Color(tone,alpha*.65),3,true)
		for n in 5:
			var at: Vector2=a.lerp(b,fposmod(elapsed*1.4+n*.2,1))
			draw_texture_rect(energy.particle_styles[int(link.floor)],Rect2(at-Vector2.ONE*8,Vector2.ONE*16),false,Color(tone,alpha))
	for m in field.session.roguelike.combat.missiles:
		if m.delay>0: continue
		var at: Vector2=m.p-Vector2(0,m.visual_height)
		Semantics.projectile(self,at,(m.end-m.start).normalized(),int(m.floor),str(m.get("fx_move",m.kind)),elapsed)
		if m.kind in ["throw","mist"]:
			draw_arc(m.end,48,0,TAU,24,Color(TONES[int(m.floor)],smoothstep(0,.16,float(m.get("age",.2)))*.45),2,true)
			draw_circle(m.p,6,Color(0,0,0,.3))
	for trail in trails:
		var fade: float=1.0-trail.age/.24
		draw_set_transform(trail.p,trail.aim)
		draw_line(Vector2.ZERO,Vector2(-12,0),Color(TONES[int(trail.floor)],fade*.25),1.5,true)
	for bullet in field.session.bullets:
		if not bullet.has("rogue_tone") or absf(bullet.p.x-field.camera.x)>1000: continue
		if bullet.get("rogue_guardian",false): continue
		var floor_index: int=bullet.rogue_tone
		draw_set_transform(bullet.p,bullet.v.angle())
		Semantics.projectile(self,bullet.p,bullet.v.normalized(),floor_index,str(bullet.get("fx_move","")),elapsed)
	draw_set_transform(Vector2.ZERO)

func burst(fx: Dictionary) -> void:
	if fx.get("rogue_guardian",false): return
	# A brief source spark accents the real staged zone; never a full-volume duplicate.
	var floor_index := clampi(int(fx.floor),0,4)
	var tone: Color=TONES[floor_index]
	energy.spawn(fx.p,Vector2.ONE*48,Color(tone,.35),2,.22)
	energy.particles(fx.p,tone,5,fx.get("direction",Vector2.UP),40,.25,floor_index)
