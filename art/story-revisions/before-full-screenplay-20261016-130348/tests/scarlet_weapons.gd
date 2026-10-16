extends SceneTree
const Campaign=preload("res://scripts/scarlet/campaign.gd")
const Inventory=preload("res://scripts/story_inventory.gd")
const View=preload("res://scripts/scarlet/render_campaign.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func make():
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false; c.inventory.initialize(); c.loot_rng.seed=731
	return c
func count_weapons(c) -> int:
	var total:=0
	for item in c.state.bag+c.state.stash+c.state.overflow:
		if item.slot=="blade": total+=1
	return total
func run() -> void:
	var c=make()
	var frames=preload("res://scripts/character_frames.gd").new()
	var view=View.new(c)
	for hero in 3:
		c.state.hero=hero
		for weapon in Inventory.WEAPON_POOLS[hero]:
			var item: Dictionary=c.inventory.make(["sword","staff","dagger"][hero],2,1)
			item.weapon_index=weapon; item.name=Catalog.weapon_name(weapon)
			c.state.equipment[hero].blade=item
			check(c.equipped_weapon()==weapon,"equipment resolves concrete weapon %d/%d" % [hero,weapon])
			check(view.hero_pose(frames,hero).weapon_identity==preload("res://scripts/weapon_image_art.gd").canonical(weapon),"idle uses equipped weapon atlas")
			c.moving=true; c.move_phase=2
			check(view.hero_pose(frames,hero).texture!=null,"equipped walk resolves")
			c.dodge_time=.12
			check(view.hero_pose(frames,hero).texture!=null,"equipped dodge resolves")
			c.dodge_time=0; c.moving=false
			c.action_weapon=weapon; c.action_time=.2; c.action_total=.5
			check(view.hero_pose(frames,hero).texture!=null,"equipped attack resolves")
			c.action_time=0
	check(Inventory.valid_data(c.state),"all weapon instances validate")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(c.state))
	check(c.valid_save(saved),"weapon identity survives JSON schema validation")
	c.state=saved; c.inventory.restore_numeric()
	check(c.equipped_weapon()==int(c.state.equipment[2].blade.weapon_index),"JSON weapon identity restored")
	var legacy=make()
	check(legacy.valid_save(legacy.state) and legacy.equipped_weapon()==Inventory.DEFAULT_WEAPONS[0],"legacy equipment without identity remains valid")
	var malformed: Dictionary=c.state.duplicate(true); malformed.equipment[0].blade.weapon_index=5
	check(not Inventory.valid_data(malformed),"incompatible weapon family rejected")
	c=make(); c.state.zone="1:1"; c.state.stage=1; c.hero_at=c.spawn_at()
	var chest: Dictionary={}
	for n in c.objective_nodes():
		if n.kind=="original_cache": chest=n; break
	check(not chest.is_empty(),"real exploration chest exists")
	if not chest.is_empty():
		c.hero_at=chest.p
		var before:=count_weapons(c)
		check(c.use(chest) and count_weapons(c)==before+1,"real chest grants a weapon")
		check(not c.use(chest) and count_weapons(c)==before+1,"opened chest cannot duplicate reward")
	# Full containers must retain the incoming instance in overflow.
	c=make()
	for container in ["bag","stash"]:
		var bounds:=Inventory.bounds(container)
		for y in bounds.y:
			for x in bounds.x:
				var item: Dictionary=c.inventory.make("potion"); item.x=x; item.y=y; c.state[container].append(item)
	c.grant_weapon(Vector2.ZERO,true)
	check(c.state.overflow.size()==1 and c.state.overflow[0].slot=="blade","full bag and stash preserve weapon in overflow")
	check(Inventory.valid_data(c.state),"overflow save remains valid")
	c=make(); c.state.zone="1:1"; c.state.stage=1
	c.combat.start("R-1-02","drop-fixture","",4)
	var before:=count_weapons(c)
	for e in c.enemies.duplicate(): c.combat.hit(e,10000,0)
	check(count_weapons(c)>before,"four actual minion deaths guarantee at least one weapon")
	var granted:=count_weapons(c)
	c.combat.start("R-1-02","drop-fixture","",4)
	for e in c.enemies.duplicate(): c.combat.hit(e,10000,0)
	check(count_weapons(c)==granted,"replaying checkpoint cannot duplicate minion loot")
	c=make(); c.state.zone="1:1"; c.state.stage=1; c.hero_at=c.spawn_at()
	c.state.equipment[0].blade.weapon_index=2
	var foe: Dictionary={"id":"timing","p":c.hero_at,"hp":10000.0,"maxhp":10000.0,"boss":false,"flash":0.0}
	c.combat.enemies=[foe]
	check(c.attack(Vector2.RIGHT),"heavy attack begins")
	check(foe.hp==10000,"windup does not deal instant damage")
	check(not c.switch_hero(1) and not c.dodge(Vector2.RIGHT),"switch and dodge cannot desync pending strike")
	for i in 6: c.update(.05,Vector2.ZERO)
	check(foe.hp==10000,"heavy windup respected")
	c.update(.05,Vector2.ZERO)
	check(foe.hp<10000 and c.pending_strike.is_empty(),"damage commits on authored release frame")
	var hp: float=foe.hp
	c.update(.05,Vector2.ZERO)
	check(foe.hp==hp,"strike commits exactly once")
	c.action_time=0; c.attack_cd=0
	c.attack(Vector2.RIGHT); c.combat.retry()
	check(c.pending_strike.is_empty() and c.action_time==0,"retry clears the interrupted attack")
	c=make()
	var earned: Dictionary=c.inventory.make_weapon(0,2,1,c.loot_rng)
	c.inventory.receive(earned)
	check(c.inventory.equip("bag",earned.uid,0),"dropped weapon equips through real inventory transaction")
	check(c.equipped_weapon()==int(earned.weapon_index),"inventory equip updates battle weapon")
	c.state.world["weapon_loot:fixture"]=true; c.state.world.weapon_drop_misses=2
	c.path="user://scarlet-weapon-fixture-%d.json" % OS.get_process_id(); c.save_enabled=true
	check(c.save_campaign(),"new weapon saves to disk")
	var loaded=Campaign.new()
	check(loaded.load_campaign(c.path) and loaded.equipped_weapon()==int(earned.weapon_index),"disk reload retains equipped weapon")
	check(loaded.state.world.get("weapon_loot:fixture",false) and int(loaded.state.world.weapon_drop_misses)==2,"disk reload retains loot receipts and pity")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(c.path+suffix): DirAccess.remove_absolute(c.path+suffix)
	print("SCARLET_WEAPONS %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
