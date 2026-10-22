extends SceneTree
const Finish=preload("res://scripts/combat_finish.gd")
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var finish=Finish.new(); root.add_child(finish)
	finish.position=Vector2(15,20)
	finish.projector=func(p: Vector2): return p*Vector2(1.2,.6)+Vector2(30,40)
	check(finish.mist!=null and finish.mist.z_index==-1,"Persistent mist layer sits below contact paint")
	finish.event({"kind":"strike","p":Vector2.ZERO,"weapon_index":613})
	finish.event({"kind":"impact","p":Vector2.ZERO,"weapon_index":613,"damage":0})
	check(finish.contacts.is_empty() and finish.mist.get_child_count()==0,"Release and zero damage do not fabricate contact mist")
	for weapon in range(600,648):
		finish.reset()
		var data={"kind":"impact","p":Vector2(100,90),"contact_p":Vector2(102,73),"contact_lift":9.0,"height":6.0,"aim":Vector2(.8,.6),"id":1,"enemy_id":20,"weapon_index":weapon,"damage":1.0,"radius":600.0}
		var original: Dictionary=data.duplicate(true)
		finish.event(data)
		check(data==original,"Presentation leaves authoritative hit data unchanged")
		check(finish.contacts.size()==1 and finish.mist.get_child_count()==1,"One real contact owns one bounded mist stamp")
		var contact: Dictionary=finish.contacts[0]
		check(contact.weapon_index==weapon and contact.profile==Profiles.profile(weapon),"Contact captures exact weapon descriptor")
		var state: Dictionary=finish.mist_state(contact)
		check(is_zero_approx(float(state.opacity)),"Mist has zero opacity at the contact instant")
		check(state.point.is_equal_approx(finish.projected(data.contact_p)-Vector2(0,15)),"Contact coordinates, lift and projector remain authoritative")
		var peak: float=clampf(float(contact.profile.attack.lead),.02,.06)
		finish.advance(peak)
		state=finish.mist_state(contact)
		check(state.opacity>0 and state.opacity<=.16,"Mist peaks shortly after contact and stays translucent")
		check(state.extent.x<=60 and state.extent.y<=32,"Oversized ability radius cannot produce oversized contact fog")
		check(state.point.distance_to(finish.projected(data.contact_p)-Vector2(0,15))<7,"Mist stays close to the original projected contact")
		finish.event(data)
		if peak<.075: check(finish.contacts.size()==1,"Rapid repeated target hits retain visual coalescing")
		finish.advance(.7)
		check(finish.contacts.is_empty() and finish.mist.get_child_count()==0,"Expired contacts release all mist nodes")
	finish.reset()
	finish.event({"kind":"spell_burst","p":Vector2.ZERO,"weapon_index":637,"radius":100})
	check(finish.mist.get_child_count()==0,"Spell placement alone does not invent a hit cloud")
	finish.reset()
	for i in 100:
		finish.event({"kind":"impact","p":Vector2(i,0),"id":i,"enemy_id":i,"weapon_index":600+i%48})
	check(finish.contacts.size()==finish.MAX_CONTACTS and finish.mist.get_child_count()==finish.MAX_CONTACTS,"Mist and contacts obey the existing shared budget")
	finish.reset()
	var bullet={"fx_id":101,"p":Vector2(20,30),"weapon_index":638,"height":12.0}
	var authoritative: Dictionary=bullet.duplicate(true)
	finish.observe([bullet],.02)
	check(bullet==authoritative and finish.trails[101].profile==Profiles.profile(638),"Observed projectile keeps immutable source data and exact material profile")
	finish.advance(.02); bullet.p+=Vector2(20,0); finish.observe([bullet],.02)
	check(finish.trails[101].points.size()==2,"Real motion supplies stable-ID wake samples")
	bullet.p+=Vector2(900,0); finish.observe([bullet],.02)
	check(finish.trails[101].points.size()==1,"Teleport discontinuity clears the old trail")
	finish.observe([{"p":Vector2.ZERO,"weapon_index":600}],.02)
	check(finish.trails.size()==1,"Projectiles without stable identity never acquire invented trails")
	var shapes := {}
	for material_weapon in [600,601,605,606,607,613,614,625,630,634,635,636,631,646]:
		shapes[JSON.stringify(finish.trail_behavior(Profiles.profile(material_weapon)))]=true
	check(shapes.size()>=12,"Material wakes differ in shape and decay rather than color alone")
	finish.observe([], .2)
	check(finish.trails.is_empty(),"Gone projectile trails expire using the original timeout")
	var bullets: Array=[]
	for i in 130: bullets.append({"fx_id":i,"p":Vector2(i,0),"weapon_index":624})
	finish.observe(bullets,.02)
	check(finish.trails.size()==finish.MAX_TRAILS,"Material trails preserve the existing budget")
	finish.reset()
	check(finish.contacts.is_empty() and finish.trails.is_empty() and finish.mist.get_child_count()==0,"Reset clears contacts, profiles and mist while retaining its container")
	finish.queue_free(); await process_frame
	print("WEAPON CONTACT LAYERS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
