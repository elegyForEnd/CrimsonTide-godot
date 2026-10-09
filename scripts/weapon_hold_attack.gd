extends RefCounted
## Left-button gesture, resolved by the host. Right-button arts keep their cooldown.
const TAP_TIME := .18
const HEAVY_MIN_RATIO := .35
static var charge_bar_box: StyleBoxFlat
const ImageArt=preload("res://scripts/weapon_image_art.gd")

static func profile(index: int) -> Dictionary:
	var w := Catalog.weapon(index)
	var family := Catalog.weapon_family(index)
	# Same-name campaign weapons share the charged move as well as its new image.
	# Otherwise an older campaign volley could accidentally request a new beam.
	var move := WeaponArts.of(ImageArt.canonical(index)).duplicate(true)
	move["hold_time"]={0:.70,1:.65,2:1.05,3:.85}.get(family,.8)
	move["mana"]=float(move.mana)*.35
	move["damage"]=1.65 if family!=2 else 2.15
	move["reach"]=maxf(float(w.reach),float(move.reach)*.85)
	move["recovery"]={0:.30,1:.35,2:.55,3:.40}.get(family,.35)
	move["charged"]=true
	move["spread"]=.06
	move["desc"]="长按蓄力，松开释放；闪避或打开界面取消。"
	if family==0:
		move.kind="volley"
		move.spell=str(w.get("spell","bullet"))
		move.count=5 if move.spell=="scatter" else 1
		move.pierce=3 if move.spell=="arrow" else 2
		move.name="聚能散射" if move.spell=="scatter" else "蓄力贯穿箭" if move.spell=="arrow" else "精准贯穿射击"
		move.mana=0.0
	else:
		move.name="蓄力·"+str(move.name)
	return move

static func parameters(s, p: Dictionary) -> Dictionary:
	var move := profile(int(p.weapon))
	if s.roguelike.active(s):
		var bonuses: Dictionary=s.RogueBuild.charge_stats(p)
		move.hold_time=TAP_TIME+(float(move.hold_time)-TAP_TIME)/(1.0+float(bonuses.speed))
		move.damage*=1.0+float(bonuses.damage)
	return move

static func fraction(seconds: float, full_time: float) -> float:
	return clampf((seconds-TAP_TIME)/maxf(.01,full_time-TAP_TIME),0.0,1.0)

static func damage_at(seconds: float, move: Dictionary) -> float:
	return lerpf(1.0,float(move.damage),fraction(seconds,float(move.hold_time)))

static func draw_bar(target: CanvasItem, p: Dictionary, at: Vector2) -> void:
	var hold: Dictionary=p.get("weapon_hold",{})
	if not hold.get("shown",false): return
	var value := fraction(float(hold.time),float(hold.get("full_time",profile(int(p.weapon)).hold_time)))
	var color := Color("ffe3a1") if value>=1.0 else Color("80dfee")
	target.draw_style_box(bar_background(),Rect2(at-Vector2(35,4),Vector2(70,8)))
	target.draw_rect(Rect2(at-Vector2(33,2),Vector2(66*value,4)),color)
	if value>=1.0: target.draw_circle(at+Vector2(39,0),2.5,color)

static func bar_background() -> StyleBoxFlat:
	if charge_bar_box!=null: return charge_bar_box
	var box := StyleBoxFlat.new()
	box.bg_color=Color("201b2b")
	box.border_color=Color("685875")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	charge_bar_box=box
	return box

static func cancel(s, p: Dictionary) -> void:
	if not p.has("weapon_hold"): return
	p.erase("weapon_hold")
	s.broadcast_combat({"kind":"hold_cancel","p":p.p,"id":p.id})

static func begin(s, p: Dictionary, heavy: bool = false) -> void:
	if p.has("weapon_hold") or p.status!="active" or p.dodge_time>0 or p.reload>0 or p.cast_time>0 or s.pending_ultimates.has(p.id): return
	if s.roguelike.active(s) and (s.raid.phase!="rogue_combat" or p.flask_time>0 or p.height>0 or not p.get("rogue_selection",{}).is_empty()): return
	var move := parameters(s,p)
	p["weapon_hold"]={"heavy":heavy,"weapon":int(p.weapon),"time":0.0,"shown":false,"ready":false,"full_time":float(move.hold_time),"max_damage":float(move.damage)}

static func tick(s, p: Dictionary, cmd: Dictionary, dt: float) -> void:
	if not p.has("weapon_hold"): return
	if p.status!="active" or p.dodge_time>0 or p.reload>0 or p.cast_time>0 or int(p.weapon_hold.weapon)!=int(p.weapon) or bool(cmd.get("fire_blocked",false)) or s.pending_ultimates.has(p.id):
		cancel(s,p); return
	if s.roguelike.active(s) and (p.flask_time>0 or p.height>0 or s.raid.phase!="rogue_combat"):
		cancel(s,p); return
	var hold: Dictionary=p.weapon_hold
	hold.time=minf(30.0,float(hold.time)+dt)
	if p.attack>0 or p.swing_time>0: hold.time=minf(TAP_TIME,float(hold.time))
	var move := parameters(s,p)
	move.hold_time=float(hold.get("full_time",move.hold_time))
	if hold.time>=TAP_TIME and not hold.shown and p.attack<=0 and p.swing_time<=0:
		hold.shown=true
		s.broadcast_combat({"kind":"hold_charge","p":p.p,"aim":p.aim,"id":p.id,"hold_time":float(move.hold_time)-TAP_TIME})
	if hold.time>=float(move.hold_time) and not hold.ready and hold.shown:
		hold.ready=true
		s.broadcast_combat({"kind":"hold_ready","p":p.p,"aim":p.aim,"id":p.id})

static func release(s, p: Dictionary) -> void:
	if not p.has("weapon_hold"): return
	var hold: Dictionary=p.weapon_hold.duplicate()
	cancel(s,p)
	if int(hold.weapon)!=int(p.weapon) or p.status!="active" or p.dodge_time>0 or s.pending_ultimates.has(p.id): return
	var move := parameters(s,p)
	move.hold_time=float(hold.get("full_time",move.hold_time))
	move.damage=float(hold.get("max_damage",move.damage))
	# A tap keeps its combo; every longer hold increases charged damage continuously.
	if float(hold.time)<=TAP_TIME and not bool(hold.get("heavy",false)):
		if s.roguelike.active(s):
			p["build_attack_edge"]=true
			p["build_attack_edge_until"]=s.elapsed+.20
		s.attack(p)
	else:
		var seconds := float(hold.time)
		if hold.get("heavy",false): seconds=maxf(seconds,lerpf(TAP_TIME,float(move.hold_time),HEAVY_MIN_RATIO))
		move["charge_ratio"]=fraction(seconds,float(move.hold_time))
		move.damage=damage_at(seconds,move)
		s.release_weapon_art(p,move)
