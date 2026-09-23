extends SceneTree

# The hidden ending and the recruit it unlocks, end to end:
#   * the knight's amulet is a red 1x1 trinket worth 666 that the banished
#     knight always leaves behind;
#   * three lit bells plus that amulet in the backpack turn the queen's fall
#     into a fourth encounter instead of the ordinary report;
#   * killing it recruits 墓煜, and a profile only offers her after that;
#   * 墓煜's ultimate is a rectangle: one heavy rune-sword hit, six seconds of
#     underworld fire pulsing every half second, and a burn that outlives it.
# It runs on its own so a failure here cannot be mistaken for one elsewhere.

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("HIDDEN ENDING FAIL: "+description)

func fresh() -> TideSession:
	var session := TideSession.new()
	root.add_child(session)
	session.solo({"hero":0})
	session.launch(false,20250924)
	session.set_physics_process(false)
	session.enemies.clear()
	session.spawn_timer=999999
	return session

func loot(kind: String) -> Dictionary:
	return Catalog.ITEMS[kind]

func run() -> void:
	# --- the trinket ---------------------------------------------------------
	var amulet: Dictionary=loot("amulet")
	check(Catalog.ITEMS.has("amulet"),"the knight's amulet is a real item kind")
	check(amulet.size==Vector2i(1,1),"the amulet takes a single cell")
	check(int(amulet.value)==666,"the amulet is worth 666")
	check(int(amulet.tier)==5,"the amulet is red quality")
	check(Catalog.quality_name(int(amulet.tier))=="红色","red is the sixth quality band")
	check(Catalog.item_color({"kind":"amulet","tier":5})==Catalog.quality_color(5),"the amulet paints itself red")
	check(Catalog.item_name({"kind":"amulet"})=="骑士的护身符","the amulet names itself")
	check(not Catalog.is_equipment("amulet"),"the amulet is a trinket, not equipment")
	check(not Catalog.slot_operable("amulet"),"the amulet has no verb on the item bar")
	check(Catalog.ITEMS.has(Catalog.kind_icon("amulet")),"the amulet has an icon of its own")

	# --- the knight always carries it ---------------------------------------
	var session := fresh()
	var knight := {"id":900,"type":4,"hp":10,"max_hp":10,"difficulty":3}
	check(str(session.enemy_loot(knight).kind)=="amulet","the banished knight leaves the amulet")
	check(str(session.enemy_loot(knight).kind)!="amulet","one knight only ever carries one amulet")
	var other := {"id":901,"type":7,"hp":10,"max_hp":10,"difficulty":2}
	check(str(session.enemy_loot(other).kind)!="amulet","an ordinary monster never drops the amulet")

	# --- three bells plus the amulet ----------------------------------------
	var walker: Dictionary=session.players[1]
	check(not session.hidden_ending_ready(),"a raid with cold bells is not ready")
	check(session.bells_lit()==0,"no bell is lit at the start")
	session.seal_bell(0)
	session.seal_bell(1)
	check(session.bells_lit()==2 and not session.hidden_ending_ready(),"two bells are not three")
	session.seal_bell(2)
	check(session.bells_lit()==3,"all three bells are lit")
	check(not session.hidden_ending_ready(),"three bells without the amulet are not enough")
	check(Catalog.add_item(walker.backpack,"amulet"),"the amulet fits in the backpack")
	check(session.carries_amulet(walker),"the backpack is searched for the amulet, not the pocket")
	check(session.amulet_carrier().id==1,"the carrier is the player actually holding it")
	check(session.hidden_ending_ready(),"three bells and the amulet together open the hidden ending")

	# The pocket deliberately does not count: the trinket has to be carried.
	var hoarder := fresh()
	hoarder.seal_bell(0)
	hoarder.seal_bell(1)
	hoarder.seal_bell(2)
	check(Catalog.add_item(hoarder.players[1].pocket,"amulet"),"the amulet fits in the pocket")
	check(not hoarder.hidden_ending_ready(),"an amulet sunk into the pocket does not count")

	# --- the queen's fall becomes the hidden encounter ----------------------
	var raid := fresh()
	raid.seal_bell(0)
	raid.seal_bell(1)
	raid.seal_bell(2)
	Catalog.add_item(raid.players[1].backpack,"amulet")
	raid.raid.day=3
	raid.raid.phase="boss"
	raid.expedition.spawn_boss(raid,true)
	check(raid.raid.get("final_spawned",false),"the queen's final form is on the field")
	var queen: Dictionary=raid.enemies[0]
	queen.hp=0
	raid.simulate(0.016)
	check(raid.raid.get("hidden_spawned",false),"her fall raises the hidden encounter")
	check(raid.raid.phase=="boss","the run is still a boss fight")
	check(raid.enemies.size()==1,"only the hidden encounter stands")
	var boss: Dictionary=raid.enemies[0]
	check(boss.get("hidden_final",false),"the arrival is the hidden encounter")
	check(not boss.get("final_form",false),"she is not the ordinary final form")
	check(str(boss.boss_name)==raid.expedition.HIDDEN_NAME,"the hidden encounter names itself")
	check(is_equal_approx(float(boss.max_hp),raid.expedition.HIDDEN_HEALTH),"she uses her own health pool")

	# --- killing her settles the hidden ending ------------------------------
	boss.hp=0
	raid.simulate(0.016)
	check(raid.raid.get("hidden_slain",false),"the hidden encounter records its death")
	check(raid.raid.phase=="complete","the run settles into the complete phase")
	check(bool(raid.players[1].get("hidden_ending",false)),"the survivors are marked with the hidden ending")
	check(int(raid.players[1].get("boss_reward",0))>=raid.expedition.HIDDEN_REWARD,"the hidden ending pays its own reward")
	var chests: int=0
	for chest in raid.ruins.chests:
		if str(chest.get("title","")).begins_with("冥火尸王"): chests+=1
	check(chests==1,"the hidden ending leaves one reward chest")

	# --- the ordinary ending is still reachable -----------------------------
	var plain := fresh()
	plain.raid.day=3
	plain.raid.phase="boss"
	plain.expedition.spawn_boss(plain,true)
	plain.enemies[0].hp=0
	plain.simulate(0.016)
	check(not plain.raid.get("hidden_spawned",false),"no bells and no amulet leaves the ordinary ending")

	# --- the recruit is earned, never assumed -------------------------------
	var profile := Profile.new()
	profile.path="user://test-hidden-profile.json"
	profile.data.hero=0
	check(profile.roster_size()==Catalog.BASE_ROSTER,"a fresh save offers only the three shipped heroes")
	check(not profile.has_recruit(3),"the recruit is locked on a fresh save")
	check(profile.has_recruit(0) and profile.has_recruit(2),"the shipped heroes are always available")
	check(profile.unlock("muyu"),"the hidden ending unlocks her once")
	check(not profile.unlock("muyu"),"the same unlock is never granted twice")
	check(profile.has_recruit(3),"the recruit joins the roster")
	check(profile.roster_size()==4,"the roster grew by exactly one")
	var saved: Dictionary={"version":1,"hero":0,"unlocks":{"muyu":true}}
	var reloaded := Profile.new()
	reloaded.path="user://test-hidden-profile-reload.json"
	reloaded.apply_data(saved)
	check(reloaded.has_recruit(3),"the unlock survives a save round trip")

	# --- the catalog carries her ---------------------------------------------
	check(Catalog.HEROES.size()==4,"the catalog has a fourth hero row")
	check(str(Catalog.HEROES[3].name)=="墓煜","the recruit is named 墓煜")
	check(str(Catalog.HEROES[3].skill)=="冥火剑雨","her ultimate is named 冥火剑雨")
	check(Catalog.STARTER_WEAPONS.size()==Catalog.HEROES.size(),"every hero still issues one weapon")
	check(Catalog.is_starter(Catalog.starter_index(3)),"her issue weapon is an issue weapon")
	check(Catalog.weapon_name(Catalog.starter_index(3))=="湮魂之镰","she issues the soul reaper scythe")
	check(Catalog.weapon_icon(Catalog.starter_index(3))=="soul_scythe","her issue weapon has its own icon")
	check(ResourceLoader.exists("res://assets/icons/soul_scythe.svg"),"the scythe icon ships")

	# --- 墓煜's ultimate -------------------------------------------------------
	var necro := fresh()
	var girl: Dictionary=necro.players[1]
	girl.hero=TideSession.NECROMANCER
	girl.weapon=Catalog.starter_index(TideSession.NECROMANCER)
	girl.talents=[0,0,0]
	girl.gear=0
	girl.equipped={"weapon":{},"gear":[{},{},{}]}
	var aim := Vector2.RIGHT
	necro.enemies.clear()
	var front := {"id":1,"p":girl.p+Vector2(200,0),"type":5,"hp":5000.0,"max_hp":5000.0,"cd":99.0,"wander":Vector2.ZERO,"facing":1.0,"motion_phase":0.0,"moving":false,"attack_time":0.0,"attack_total":0.0,"attack_released":false,"attack_aim":Vector2.RIGHT,"sequence":0,"phase":1,"flash":0.0,"stagger":0.0,"last":1}
	var behind := {"id":2,"p":girl.p+Vector2(-200,0),"type":5,"hp":5000.0,"max_hp":5000.0,"cd":99.0,"wander":Vector2.ZERO,"facing":-1.0,"motion_phase":0.0,"moving":false,"attack_time":0.0,"attack_total":0.0,"attack_released":false,"attack_aim":Vector2.LEFT,"sequence":0,"phase":1,"flash":0.0,"stagger":0.0,"last":1}
	var flank := {"id":3,"p":girl.p+Vector2(200,400),"type":5,"hp":5000.0,"max_hp":5000.0,"cd":99.0,"wander":Vector2.ZERO,"facing":1.0,"motion_phase":0.0,"moving":false,"attack_time":0.0,"attack_total":0.0,"attack_released":false,"attack_aim":Vector2.RIGHT,"sequence":0,"phase":1,"flash":0.0,"stagger":0.0,"last":1}
	necro.enemies=[front,behind,flank]
	necro.cast_soul_reap(girl,aim)
	check(necro.soul_reaps.size()==1,"the rain is queued at release")
	check(necro.fire_zones.is_empty(),"no fire burns before the rain lands")
	var aimed: float=float(necro.soul_reaps[0].damage)
	check(aimed>=TideSession.SOUL_REAP_DAMAGE,"the rain pays at least the ultimate's base damage")

	necro.update_soul_reaps(TideSession.SOUL_REAP_DELAY+0.01)
	check(necro.enemies[0].hp<5000.0,"the rectangle hits what stands in front of her")
	check(necro.enemies[1].hp==5000.0,"nothing behind her is hit")
	check(necro.enemies[2].hp==5000.0,"the rectangle has a real half width")
	check(necro.fire_zones.size()==1,"the rain leaves a patch of underworld fire")
	check(is_equal_approx(float(necro.fire_zones[0].time),TideSession.FIRE_DURATION),"the patch burns for six seconds")
	var rain_damage: float=5000.0-float(front.hp)

	# The patch runs its twelve pulses over the six seconds it is alive, and the
	# debuff ticks alongside it at its own cadence of one pulse per 0.6 seconds.
	var frames := int(TideSession.FIRE_DURATION/0.05)
	for i in frames:
		necro.update_fire_zones(0.05)
		necro.update_burns(0.05)
	var fire_damage: float=float(rain_damage)+12.0*TideSession.FIRE_TICK_DAMAGE
	var burn_damage: float=5000.0-float(front.hp)-fire_damage
	check(burn_damage>=48.0 and burn_damage<=72.0,"the patch's own ten seconds of burn landed (%.0f over six seconds of fire)" % burn_damage)
	check(is_equal_approx(fmod(burn_damage,TideSession.BURN_TICK_DAMAGE),0.0),"the burn only ever lands in whole 6 damage pulses")

	# The patch is gone; the debuff is walked out on its own. The tail is whatever
	# the last refresh granted, so it is a whole number of pulses too.
	var tail := 0
	while front.has("burn_time") and tail<120:
		necro.update_burns(0.05)
		tail+=1
	check(not front.has("burn_time"),"an expired burn leaves no state behind")
	var total_burn: float=5000.0-float(front.hp)-fire_damage
	var tail_damage: float=total_burn-burn_damage
	check(tail_damage>0.0,"the burn keeps ticking after the fire expires")
	check(is_equal_approx(fmod(tail_damage,TideSession.BURN_TICK_DAMAGE),0.0),"the tail is whole pulses as well")
	check(is_equal_approx(total_burn,float(int(round(total_burn/TideSession.BURN_TICK_DAMAGE)))*TideSession.BURN_TICK_DAMAGE),"nothing lands after the burn is spent")
	check(5000.0-float(front.hp)==fire_damage+total_burn,"the monster paid the patch and the burn exactly once each")

	# Re-entering the fire refreshes the debuff instead of stacking another.
	front.hp=5000.0
	front.erase("burn_time")
	front.erase("burn_next")
	necro.fire_zones=[{"owner":1,"at":girl.p,"aim":aim,"time":TideSession.FIRE_DURATION,"next":0.0,"pulses":0}]
	necro.update_fire_zones(0.01)
	var after_entry: float=5000.0-float(front.hp)
	check(is_equal_approx(after_entry,TideSession.FIRE_TICK_DAMAGE),"walking into the fire takes one pulse")
	check(float(front.burn_time)>TideSession.BURN_DURATION-TideSession.BURN_TICK,"walking into the fire starts a fresh six second burn")
	check(is_equal_approx(float(front.burn_next),TideSession.BURN_TICK),"the burn's first tick is scheduled one interval out")
	necro.update_fire_zones(TideSession.FIRE_TICK)
	check(float(front.burn_time)>TideSession.BURN_DURATION-TideSession.BURN_TICK,"a second pulse refreshes the burn rather than stacking it")
	check(not front.has("burn_stack"),"the burn never stacks")
	necro.update_burns(TideSession.BURN_TICK)
	check(is_equal_approx(5000.0-float(front.hp),2.0*TideSession.FIRE_TICK_DAMAGE+1.0*TideSession.BURN_TICK_DAMAGE),"two fire pulses and one burn pulse landed")

	# A rectangle test shared by aiming, damage and the drawn patch.
	var origin := Vector2(100,100)
	check(TideSession.inside_reap(origin+Vector2(240,0),origin,Vector2.RIGHT,TideSession.FIRE_LENGTH),"the far edge of the rectangle is inside")
	check(not TideSession.inside_reap(origin+Vector2(TideSession.FIRE_LENGTH+40,0),origin,Vector2.RIGHT,TideSession.FIRE_LENGTH),"past the end is outside")
	check(not TideSession.inside_reap(origin+Vector2(200,TideSession.FIRE_HALF_WIDTH+10),origin,Vector2.RIGHT,TideSession.FIRE_LENGTH),"past the side is outside")
	check(TideSession.inside_reap(origin+Vector2(200,-TideSession.FIRE_HALF_WIDTH),origin,Vector2.RIGHT,TideSession.FIRE_LENGTH),"the near side is inside")
	check(not TideSession.inside_reap(origin-Vector2(60,0),origin,Vector2.RIGHT,TideSession.FIRE_LENGTH),"the ground she stands on is outside")

	# The purple outline is drawn from the same shape, transformed by the caster
	# and the aim, so its whole area has to be ground the fire burns - and a patch
	# that reached behind her or off to one side would be visible as a lie.
	var aims: Array[Vector2] = [Vector2.RIGHT,Vector2.UP,Vector2(-0.6,0.8).normalized()]
	for aim_dir in aims:
		var frame := Transform2D(aim_dir.angle(),origin)
		var drawn := CombatVisuals.patch_local_rect(TideSession.FIRE_LENGTH,TideSession.FIRE_HALF_WIDTH)
		var inset := drawn.grow(-0.5)
		for corner in [inset.position,Vector2(inset.end.x,inset.position.y),
				Vector2(inset.position.x,inset.end.y),inset.end]:
			check(TideSession.inside_reap(frame*corner,origin,aim_dir,TideSession.FIRE_LENGTH),
				"the drawn patch corner %s is ground the fire burns" % corner)
		check(not TideSession.inside_reap(frame*(drawn.position+Vector2(0,-16)),origin,aim_dir,TideSession.FIRE_LENGTH),
			"nothing beside the drawn patch burns")
		check(not TideSession.inside_reap(frame*(drawn.end+Vector2(16,0)),origin,aim_dir,TideSession.FIRE_LENGTH),
			"nothing past the drawn patch burns")

	# The windup is the cut-in, so a hero the manifest does not know still casts.
	var unknown := {"hero":99}
	check(TideSession.ONLINE_ULTIMATE_DURATION==necro.ultimate_seconds(unknown),"an unknown hero falls back to the short cut-in")
	check(necro.ultimate_seconds(girl)>0.1,"墓煜's cut-in holds for her recorded lines")

	session.queue_free()
	raid.queue_free()
	plain.queue_free()
	hoarder.queue_free()
	necro.queue_free()
	print("HIDDEN ENDING TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
