extends Node3D
## Presentation-only bridge from authoritative combat events into the 3D world.
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
const Mechanics=preload("res://scripts/weapon_mechanics.gd")
const Weapon=preload("res://scripts/weapon_vfx.gd")
const Release=preload("res://scripts/weapon_release_vfx_3d.gd")
const MAX_EFFECTS=96
var camera: Camera3D
var height_at: Callable
var socket_provider: Callable
# Flat roguelike artwork needs a broader release silhouette at its native scale.
var body_gain := 1.0
var melee_reach_gain := 1.0
var effects: Array=[]
var charges: Dictionary={}
var marks: Dictionary={}
var clock := 0.0

func terrain(p: Vector2) -> float: return float(height_at.call(p)) if height_at.is_valid() else 0.0
func point(p: Vector2,height: float=0) -> Vector3: return Vector3(p.x*.01,(terrain(p)+height)*.01,p.y*.01)

func socket_world(data: Dictionary) -> Vector3:
	var p: Vector2=data.p
	var fallback := point(p,float(data.get("height",0))+62)
	if not socket_provider.is_valid() or camera==null: return fallback
	var socket: Dictionary=socket_provider.call(int(data.get("id",data.get("hero",0))))
	if socket.is_empty(): return fallback
	var weapon := int(data.get("weapon_index",-1))
	var family := Catalog.weapon_family(weapon) if weapon>=0 else -1
	var at_tip := str(data.get("kind",""))=="hold_charge" or family in [0,3]
	var screen_point: Vector2=socket.get("tip") if at_tip else socket.get("stroke_pivot",socket.get("grip",socket.tip))
	var global_height := to_global(fallback).y
	var hit: Variant=Plane(Vector3.UP,global_height).intersects_ray(camera.project_ray_origin(screen_point),camera.project_ray_normal(screen_point))
	return to_local(hit) if hit!=null else fallback

func remove_effect(fx) -> void:
	if not is_instance_valid(fx): return
	if fx.get_parent(): fx.get_parent().remove_child(fx)
	fx.queue_free()

func cancel_charge(id: int) -> void:
	if not charges.has(id): return
	var fx=charges[id]; charges.erase(id); effects.erase(fx); remove_effect(fx)

func reset() -> void:
	for fx in effects: remove_effect(fx)
	effects.clear(); charges.clear(); marks.clear(); clock=0

func event(data: Dictionary,hero: int=0) -> bool:
	var kind := str(data.get("kind",""))
	if kind=="hold_cancel": cancel_charge(int(data.get("id",hero))); return true
	if kind=="hold_ready":
		var charge=charges.get(int(data.get("id",hero)),null)
		if is_instance_valid(charge): charge.data["ready"]=true; charge.data["ready_age"]=charge.age
		return true
	var index := int(data.get("weapon_index",-1))
	if index<0: return false
	if kind not in ["windup","hold_charge","strike","impact","spell_beam","spell_arc","spell_burst"]: return false
	if kind=="impact" and float(data.get("damage",1))<=0: return true
	var id := int(data.get("id",hero))
	var shape_prepared := false
	if kind=="strike" and charges.has(id):
		var preparation=charges[id]
		shape_prepared=preparation.authored!=null and str(preparation.data.source_event.get("kind",""))=="windup" and preload("res://scripts/weapon_actual_shape.gd").available(int(preparation.profile.canonical)) and preparation.authored.get("actual_shape")!=null
	var contact_art_covered := false
	var contact_sequence: Dictionary={}
	if kind=="impact":
		for at in range(effects.size()-1,-1,-1):
			var previous=effects[at]
			if previous.kind=="release" and int(previous.data.weapon_index)==index and int(previous.data.source_event.get("id",-2))==id and previous.age<.30:
				for key in ["sequence_step","sequence_shape","sequence_final"]:
					if previous.data.has(key): contact_sequence[key]=previous.data[key]
				break
		var key := str(id)+":"+str(data.get("enemy_id",data.p))
		if clock-float(marks.get(key,-10))<.06: return true
		marks[key]=clock
		var canonical := preload("res://scripts/weapon_motion_design.gd").identity(index)
		for released in effects:
			if int(released.data.weapon_index)!=index or int(released.data.get("source_event",{}).get("id",-2))!=id: continue
			if released.age>.35: continue
			if released.kind=="burst" and not preload("res://scripts/weapon_hybrid_material.gd").impact_key(released.profile).is_empty(): contact_art_covered=true
			if released.kind=="release" and canonical!=600 and (released.authored.slam or bool(released.profile.get("ground_break",false))): contact_art_covered=true
		if Catalog.weapon_family(index) in [1,2]:
			# Confirmed contact catches the blade; misses never slow an emitted stroke.
			for released in effects:
				if released.kind!="release" or int(released.data.get("source_event",{}).get("id",-2))!=id: continue
				if int(released.data.weapon_index)!=index or released.data.get("contact_caught",false): continue
				if released.age>.30: continue
				released.data["contact_caught"]=true
				if preload("res://scripts/weapon_batch_art.gd").enabled(canonical):
					released.authored.catch_contact(point(Vector2(data.p),float(data.get("height",0))+55))
					if not bool(released.data.get("shape_prepared",false)): released.age=maxf(released.age,released.emission_time*.90)
					released.data["batch_contact_age"]=released.age
					released.contact_hold=0.0
					contact_art_covered=false
					released.rebuild()
					continue
				if canonical==600 and released.action=="art":
					released.data["crystal_contact"]=point(Vector2(data.p),float(data.get("height",0))+55)
				if canonical==600:
					released.age=maxf(released.age,.025)
					released.contact_hold=.040 if released.action=="normal" else .060
				else:
					released.age=maxf(released.age,.018)
					var weight := Catalog.weapon_family(index)==2
					released.contact_hold=(.055 if released.action=="normal" else .080) if weight else (.032 if released.action=="normal" else .048)
					if released.authored.slam and canonical!=600:
						released.authored.landing=point(Vector2(data.p))+Vector3.UP*.025
						released.age=maxf(released.age,released.emission_time*.98)
				released.rebuild()
	if kind in ["strike","windup","hold_charge"]: cancel_charge(id)
	if effects.size()>=MAX_EFFECTS:
		var old=effects.pop_front()
		for source in charges.keys():
			if charges[source]==old: charges.erase(source)
		remove_effect(old)
	var role := Mechanics.strike_role(index,data)
	var vfx_kind := "charge" if kind in ["windup","hold_charge"] else "impact" if kind=="impact" else "beam" if kind in ["spell_beam","spell_arc"] else "burst" if kind=="spell_burst" else "release"
	var action := "heavy" if kind=="hold_charge" else Profiles.action_of(data)
	var spec := Profiles.action_profile(index,role,action)
	var p: Vector2=data.p
	var aim2: Vector2=Vector2(data.get("aim",Vector2.RIGHT)).normalized()
	if aim2.length_squared()<.01: aim2=Vector2.RIGHT
	var origin := point(p,float(data.get("height",0))+(20 if kind=="spell_burst" else 55)) if kind in ["impact","spell_burst"] else socket_world(data)
	var r := float(data.get("reach",Catalog.weapon(index).get("reach",150)))
	if kind in ["impact","spell_burst"]: r=float(data.get("radius",34 if kind=="impact" else 100))
	if Mechanics.body_centered(role): origin=point(p,float(data.get("height",0))+48)
	if kind=="spell_arc" and data.has("target"):
		aim2=(Vector2(data.target)-p).normalized(); r=p.distance_to(data.target)
	var fx := Release.new()
	fx.name="Weapon%d_%s" % [index,vfx_kind]
	fx.detail=2 if effects.size()>40 else 1 if effects.size()>16 else 0
	fx.camera=camera
	fx.data={"profile":spec,"weapon_index":index,"vfx_kind":vfx_kind,"origin":origin,"ground":point(p),"aim":Vector3(aim2.x,0,aim2.y),"reach":r,"width":float(data.get("width",30)),"combo":int(data.get("combo",0)),"charged":bool(data.get("charged",false)),"windup":float(data.get("windup",.3)),"color":Weapon.profile(index).color,"source_event":data.duplicate()}
	fx.data["body_gain"]=body_gain
	fx.data["contact_art_covered"]=contact_art_covered
	fx.data["action"]=action
	fx.data["shape_prepared"]=shape_prepared
	for key in ["sequence_step","sequence_shape","sequence_final"]:
		if data.has(key): fx.data[key]=data[key]
		elif contact_sequence.has(key): fx.data[key]=contact_sequence[key]
	if index==617 and vfx_kind=="release" and socket_provider.is_valid() and camera!=null:
		var socket: Dictionary=socket_provider.call(id)
		if not socket.is_empty():
			var grip: Vector2=socket.get("stroke_pivot",socket.get("grip",socket.tip))
			var hit: Variant=Plane(Vector3.UP,to_global(origin).y).intersects_ray(camera.project_ray_origin(grip),camera.project_ray_normal(grip))
			if hit!=null: fx.data["reference_pivot"]=to_local(hit)
	if index in [606,607,608] and vfx_kind in ["release","charge"] and socket_provider.is_valid() and camera!=null:
		var socket: Dictionary=socket_provider.call(id)
		if not socket.is_empty():
			var tip: Vector2=socket.get("stroke_tip",socket.tip)
			var hit: Variant=Plane(Vector3.UP,to_global(origin).y).intersects_ray(camera.project_ray_origin(tip),camera.project_ray_normal(tip))
			if hit!=null: fx.data["reference_tip"]=to_local(hit)
	if kind=="hold_charge": fx.data.windup=maxf(.12,float(data.get("hold_time",.6)))
	if vfx_kind=="beam": fx.data["beam_end"]=point(p+aim2*r,float(data.get("height",0))+55)
	add_child(fx); effects.append(fx)
	if kind in ["windup","hold_charge"]: charges[id]=fx
	if kind=="hold_charge" and socket_provider.is_valid(): update_charge_sites(fx,socket_provider.call(id))
	return true

func update_charge_sites(fx, socket: Dictionary) -> void:
	if camera==null or socket.is_empty(): return
	var sites: Array=socket.get("charge_points",[]).duplicate()
	if sites.is_empty(): sites=[socket.get("grip",socket.tip),socket.tip]
	var plane_height := to_global(fx.origin).y
	var points: Array=[]
	# Sample the entire weapon instead of dropping everything beyond point 24.
	for i in mini(24,sites.size()):
		var index := roundi(float(i)*float(sites.size()-1)/maxf(1,mini(24,sites.size())-1))
		var hit: Variant=Plane(Vector3.UP,plane_height).intersects_ray(camera.project_ray_origin(sites[index]),camera.project_ray_normal(sites[index]))
		if hit!=null: points.append(to_local(hit))
	fx.data["charge_sites"]=points
	var tracks: Array=[]
	for source: Array in socket.get("charge_paths",[sites]):
		var track: Array=[]
		for i in mini(24,source.size()):
			var index := roundi(float(i)*float(source.size()-1)/maxf(1,mini(24,source.size())-1))
			var hit: Variant=Plane(Vector3.UP,plane_height).intersects_ray(camera.project_ray_origin(source[index]),camera.project_ray_normal(source[index]))
			if hit!=null: track.append(to_local(hit))
		if track.size()>1: tracks.append(track)
	fx.data["charge_paths"]=tracks

func advance(dt: float) -> void:
	clock+=maxf(0,dt)
	for i in range(effects.size()-1,-1,-1):
		var fx=effects[i]
		fx.detail=2 if effects.size()>40 else 1 if effects.size()>16 else 0
		if fx.kind=="charge":
			var id := -1
			for source in charges:
				if charges[source]==fx: id=source; break
			if id>=0 and socket_provider.is_valid():
				var socket: Dictionary=socket_provider.call(id)
				if socket.is_empty() or (not bool(socket.get("active",true)) and str(fx.data.source_event.kind)!="hold_charge"):
					cancel_charge(id); continue
				fx.origin=socket_world(fx.data.source_event)
				if fx.authored!=null and preload("res://scripts/weapon_batch_art.gd").enabled(int(fx.profile.canonical)):
					if int(fx.data.get("sequence_step",-1))>=0 and socket.has("actor_p"):
						var event: Dictionary=fx.data.source_event.duplicate()
						event.p=socket.actor_p; event.height=socket.get("actor_height",0)
						fx.origin=socket_world(event); fx.ground=point(socket.actor_p)
						fx.authored.follow_actor()
					if int(fx.profile.canonical) in [607,608]:
						var screen_tip: Vector2=socket.get("stroke_tip",socket.tip)
						var tip: Variant=Plane(Vector3.UP,to_global(fx.origin).y).intersects_ray(camera.project_ray_origin(screen_tip),camera.project_ray_normal(screen_tip))
						if tip!=null: fx.authored.root=to_local(tip)
				if str(fx.data.source_event.kind)=="hold_charge": update_charge_sites(fx,socket)
		fx.advance(dt)
		if fx.age>=fx.life:
			for source in charges.keys():
				if charges[source]==fx: charges.erase(source)
			effects.remove_at(i); remove_effect(fx)
	for key in marks.keys():
		if clock-float(marks[key])>1: marks.erase(key)
