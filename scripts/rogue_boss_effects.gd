extends Node2D
## Five guardian identities; zones follow the live authoritative damage record.
const Art = preload("res://scripts/boss_effect_art.gd")
const Language=preload("res://scripts/boss_effect_language.gd")
var field: Control
var pulses: Array[Dictionary]=[]
var seen: Dictionary={}
var damage_visual = preload("res://scripts/boss_damage_visual.gd").new()

func _ready() -> void:
	damage_visual.field=field
	add_child(damage_visual)

func reset() -> void:
	damage_visual.reset()
	pulses.clear()
	seen.clear()
	queue_redraw()

func event(data: Dictionary) -> void:
	if data.kind not in ["rogue-boss-charge","rogue-boss-phase","rogue-boss-fall"]: return
	if data.p.distance_to(field.camera)>1400: return
	if data.kind!="rogue-boss-phase":
		for i in range(pulses.size()-1,-1,-1):
			if pulses[i].id==data.id and pulses[i].kind=="rogue-boss-charge": pulses.remove_at(i)
	if pulses.size()>=32: pulses.pop_front()
	var fx := data.duplicate(true)
	fx["age"]=0.0
	fx["life"]=float(data.get("duration",1.1))
	pulses.append(fx)

func _process(dt: float) -> void:
	if not field.visible: return
	# Parent rogue_enemy_vfx already carries the field ground transform.
	for e in field.session.enemies:
		if not e.get("rogue_guardian",false) or e.hp<=0: continue
		if not seen.has(e.id):
			seen[e.id]=true
			preload("res://scripts/boss_effect_sequence.gd").warm(Art.identity(e))
			event({"kind":"rogue-boss-phase","id":e.id,"p":e.p,"floor":e.rogue_skin,"art_key":Art.identity(e),"duration":1.1})
	for i in range(pulses.size()-1,-1,-1):
		var fx: Dictionary=pulses[i]
		fx.age+=dt
		if fx.kind=="rogue-boss-charge":
			var living := false
			for e in field.session.enemies:
				if e.id==fx.id and e.hp>0 and e.attack_time>0 and not e.get("boss_released",false):
					living=true
					fx.p=e.p
			if not living: pulses.remove_at(i); continue
		if fx.age>=fx.life: pulses.remove_at(i)
	queue_redraw()
	preload("res://scripts/boss_effect_sequence.gd").finish_warming()

func art(key: String, role: String, at: Vector2, diameter: float, angle: float, alpha: float) -> void:
	Art.draw(self,key,role,at,Vector2.ONE*diameter,angle,alpha)

func _draw() -> void:
	for prop in field.session.enemies:
		if prop.get("boss_construct",false) and prop.hp>0:
			var lift := Language.construct_health_lift(prop)
			draw_rect(Rect2(prop.p+Vector2(-24,-lift),Vector2(48,4)),Color("24182c"))
			draw_rect(Rect2(prop.p+Vector2(-24,-lift),Vector2(48*prop.hp/prop.max_hp,4)),Color("b6f4df"))
	for fx in pulses:
		var key: String=str(fx.get("art_key",Art.rogue_key(int(fx.floor))))
		for e in field.session.enemies:
			if e.id==fx.id: key=Art.identity(e); break
		var action := "charge" if fx.kind=="rogue-boss-charge" else "fall" if fx.kind=="rogue-boss-fall" else "phase"
		Language.actor(self,key,fx.p,fx.get("aim",Vector2.RIGHT),action,float(fx.age),float(fx.life))
	# Shared damage renderer owns all ground zones; do not stamp a second full sprite.
	for b in field.session.bullets:
		if b.get("boss_projectile",false): continue
		if not b.get("rogue_guardian",false) or absf(b.p.x-field.camera.x)>1050: continue
		preload("res://scripts/effect_semantics.gd").projectile(self,b.p,b.v.normalized(),int(b.rogue_tone),str(b.get("fx_move","")),field.clock)
