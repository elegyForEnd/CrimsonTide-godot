extends RefCounted
## Transient effects; checkpoints restart these along with the encounter phase.
var owner_ref: WeakRef
var campaign:
	get: return owner_ref.get_ref()
var barrier := 0.0
var barrier_time := 0.0
var dash_ready := [false,false,false]
var attack_count := [0,0,0]
var strike_bonus := [0.0,0.0,0.0]

func _init(host) -> void: owner_ref=weakref(host)

func reset() -> void:
	barrier=0; barrier_time=0; dash_ready=[false,false,false]; attack_count=[0,0,0]; strike_bonus=[0.0,0.0,0.0]

func mods(hero: int = -1) -> Dictionary: return campaign.inventory.modifiers(hero)

func begin_strike(hero: int, special: int) -> void:
	strike_bonus[hero]=0.0
	if special!=0: return
	var m := mods(hero)
	attack_count[hero]+=1
	if attack_count[hero]%3==0: strike_bonus[hero]+=float(m.get("third_hit",0))
	if dash_ready[hero]: strike_bonus[hero]+=float(m.get("dash_damage",0)); dash_ready[hero]=false

func outgoing(e: Dictionary, amount: float, hero: int, special: int) -> float:
	var m := mods(hero)
	var bonus := float(m.get("boss_damage",0)) if e.get("boss",false) else 0.0
	if e.hp<float(e.maxhp)*.30: bonus+=float(m.get("execute",0))
	bonus+=float(e.get("rpg_vulnerable",0)) if float(e.get("rpg_vulnerable_time",0))>0 else 0.0
	if special==1: bonus+=float(m.get("skill_damage",0))
	if special==0: bonus+=float(strike_bonus[hero])
	if campaign.loot_rng.randf()*100<float(m.get("crit",0)):
		amount*=1.5+float(m.get("crit_damage",0))/100.0
	return amount*(1.0+bonus/100.0)

func after_hit(e: Dictionary, actual: float, hero: int, special: int) -> void:
	if actual<=0: return
	var m := mods(hero)
	# Shared active HP belongs to the controlled hero; AI cannot heal them by leeching.
	if hero==int(campaign.state.hero):
		var healing := minf(3.0,actual*float(m.get("leech",0))/100.0)
		if e.hp<=0: healing+=float(m.get("kill_heal",0))
		campaign.state.hp=minf(campaign.max_hp(),campaign.state.hp+healing)
	if e.hp<=0: return
	if float(m.get("slow",0))>0:
		e.rpg_slow=maxf(float(m.slow),float(e.get("rpg_slow",0))) if float(e.get("rpg_slow_time",0))>0 else float(m.slow)
		e.rpg_slow_time=2.0
	if float(m.get("vulnerable",0))>0:
		e.rpg_vulnerable=maxf(float(m.vulnerable),float(e.get("rpg_vulnerable",0))) if float(e.get("rpg_vulnerable_time",0))>0 else float(m.vulnerable)
		e.rpg_vulnerable_time=4.0
	if not e.get("boss",false) and campaign.loot_rng.randf()*100<float(m.get("stagger",0)):
		e.stagger=maxf(float(e.get("stagger",0)),.4)
	if special==0 and float(m.get("bleed",0))>0:
		# Refresh the strongest wound, never multiply stacks by attack speed or squad size.
		var dot := actual*float(m.bleed)/300.0
		if float(e.get("rpg_bleed_time",0))<=0 or dot>=float(e.get("rpg_bleed",0)):
			e.rpg_bleed=dot; e.rpg_bleed_hero=hero
		e.rpg_bleed_time=3.0

func dodge() -> void:
	var m := mods()
	dash_ready[int(campaign.state.hero)]=true
	barrier=float(m.get("dodge_barrier",0)); barrier_time=3.0

func incoming(amount: float, element: String = "physical", escort: bool = false) -> float:
	var m := mods()
	if escort: return maxf(0,amount*(1.0-float(m.get("escort_guard",0))/100.0))
	amount=maxf(5.0,amount-int(campaign.state.armor_rank)*1.6-int(campaign.state.gear.get("armor",0))*2.0)
	amount*=1.0-float(m.get("reduction",0))/100.0
	if element!="physical": amount*=1.0-float(m.get("resist",0))/100.0
	if campaign.state.hp<campaign.max_hp()*.35: amount*=1.0-float(m.get("low_guard",0))/100.0
	var absorbed := minf(barrier,amount)
	barrier-=absorbed
	return maxf(0,amount-absorbed)

func tick(dt: float) -> void:
	barrier_time=maxf(0,barrier_time-dt)
	if barrier_time<=0: barrier=0
	if campaign.state.hp>0: campaign.state.hp=minf(campaign.max_hp(),campaign.state.hp+float(mods().get("regen",0))*dt)
	for e in campaign.combat.enemies.duplicate():
		if e.hp<=0: continue
		for key in ["rpg_slow_time","rpg_vulnerable_time"]: e[key]=maxf(0,float(e.get(key,0))-dt)
		if float(e.get("rpg_bleed_time",0))<=0: continue
		var duration := minf(dt,float(e.rpg_bleed_time))
		e.rpg_bleed_time-=duration
		campaign.combat.hit(e,float(e.get("rpg_bleed",0))*duration,int(e.get("rpg_bleed_hero",0)),0,false)
		if not campaign.combat.running or campaign.combat.phase_pending: break
