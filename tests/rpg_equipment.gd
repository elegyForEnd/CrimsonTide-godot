extends SceneTree
const Campaign=preload("res://scripts/scarlet/campaign.gd")
const Items=preload("res://scripts/story_inventory.gd")
const Rules=preload("res://scripts/rpg_equipment.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func fixture():
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false; c.inventory.initialize(); c.loot_rng.seed=21833
	c.state.equipment=[{},{},{}]; c.inventory.sync_gear(); return c
func foe(boss: bool=false) -> Dictionary:
	return {"id":"fixture","p":Vector2.ZERO,"hp":10000.0,"maxhp":10000.0,"boss":boss,"flash":0.0,"stagger":0.0}
func worn(c, id: String, hero: int=0) -> Dictionary:
	var u := Rules.unique(id)
	var item: Dictionary=c.inventory.make_loot(hero,int(u.act),4,c.loot_rng,u.slot)
	item.unique_id=id; item.name=u.name
	c.state.equipment[hero][u.slot]=item; c.inventory.sync_gear(); return item
func fill_bag(c) -> void:
	c.state.bag=[]
	for y in Items.BAG.y:
		for x in Items.BAG.x:
			var item: Dictionary=c.inventory.make("potion",1,0,5); item.x=x; item.y=y; c.state.bag.append(item)
func run() -> void:
	var c=fixture()
	check(Rules.data().affixes.size()==32 and Rules.data().uniques.size()==30,"authored equipment catalog loaded")
	# Every rarity / chapter / hero / slot travels through generation, schema and JSON.
	for act in range(1,7):
		for hero in 3:
			for slot in Items.SLOTS:
				for quality in 5:
					var item: Dictionary=c.inventory.make_loot(hero,act,quality,c.loot_rng,slot,"chest")
					check(Items.valid_item(item,{}),"generated item schema %d/%d/%s/%d" % [act,hero,slot,quality])
					var saved: Dictionary=JSON.parse_string(JSON.stringify(item)); Items.canonical_numbers(saved)
					check(Items.valid_item(saved,{}) and saved.affixes==item.affixes,"rolled values survive JSON unchanged")
					check(Items.describe(item).contains("来源："),"complete readable description")
	for u in Rules.data().uniques:
		var hero := maxi(0,int(u.hero))
		var item: Dictionary=worn(c,u.id,hero)
		check(Items.valid_item(item,{}),"unique template valid "+u.id)
		check(not Rules.item_mods(item).is_empty() and Items.describe(item).contains(u.effect),"unique mechanics have visible descriptions "+u.id)
	# Roll stream deterministic when seed matches, values remain independent per instance.
	var a=fixture(); var b=fixture()
	check(a.inventory.make_loot(0,3,2,a.loot_rng)==b.inventory.make_loot(0,3,2,b.loot_rng),"seeded generation reproducible")
	# Two / three piece effects, one hero only; capped total cannot grow indefinitely.
	c=fixture()
	for slot in Items.SLOTS:
		c.state.equipment[0][slot]=c.inventory.make_loot(0,5,3,c.loot_rng,slot)
	var mods: Dictionary=c.inventory.modifiers(0)
	check(mods.get("escort_guard",0)>=15 and mods.get("dash_damage",0)>=35,"three-piece homeward set activates")
	check(c.inventory.modifiers(1).is_empty(),"sets do not count across party members")
	c.state.equipment[0].erase("blade")
	check(c.inventory.modifiers(0).get("dash_damage",0)<35,"removing third piece removes full-set bonus")
	for hero in 3:
		for slot in Items.SLOTS:
			c.state.equipment[hero][slot]=c.inventory.make_loot(hero,6,2,c.loot_rng,slot)
	mods=c.inventory.modifiers()
	for key in Rules.CAPS: check(float(mods.get(key,0))<=float(Rules.CAPS[key]),"stat cap respected "+key)
	# Reject corrupt or forged fields before the entire save is accepted.
	var good: Dictionary=c.inventory.make_loot(0,4,2,c.loot_rng,"blade")
	var bad := good.duplicate(true); bad.affixes[0].value=9999
	check(not Items.valid_item(bad,{}),"out-of-range roll rejected")
	bad=good.duplicate(true); bad.affixes[1]=bad.affixes[0].duplicate(true)
	check(not Items.valid_item(bad,{}),"duplicate affix family rejected")
	bad=good.duplicate(true); bad.affixes[0].id="does-not-exist"
	check(not Items.valid_item(bad,{}),"unknown affix rejected")
	bad=good.duplicate(true); bad.unique_id="a6-blade-0"
	check(not Items.valid_item(bad,{}),"unique injected into rare rejected")
	bad=good.duplicate(true); bad.rune="ember"
	check(not Items.valid_item(bad,{}),"rune without socket rejected")
	bad=good.duplicate(true); bad.reforges=-1
	check(not Items.valid_item(bad,{}),"negative reforge count rejected")
	bad=good.duplicate(true); bad.erase("affix_revision")
	check(not Items.valid_item(bad,{}),"schema downgrade cannot hide affixes")
	var normalized: Dictionary=c.inventory.normalize(good)
	check(normalized.affixes==good.affixes and normalized.quality==good.quality,"normalization preserves equipment rolls")
	# Full-container crafts and insufficient-resource rerolls must be completely atomic.
	c=fixture(); c.state.act=4; c.state.coins=100000; c.state.materials=10000
	c.inventory.receive(c.inventory.make("crystal",1,0,5))
	var crystal_count: int=c.inventory.count("crystal")
	check(c.inventory.craft_set("unbound","armor"),"targeted set recipe produces selected slot")
	check(c.inventory.count("crystal")==crystal_count-1 and c.state.materials==10000-22,"set recipe consumes real stacks and wallet exactly once")
	var item: Dictionary=c.state.bag[-1]; var uid: String=item.uid
	check(item.set_id=="unbound" and item.slot=="armor","set recipe chapter and slot match")
	check(not c.inventory.craft_set("dawn","charm"),"future chapter recipe blocked")
	fill_bag(c)
	var snapshot := JSON.stringify(c.state)
	check(not c.inventory.craft_set("unbound","blade") and snapshot==JSON.stringify(c.state),"full bag set recipe has no side effects")
	c=fixture(); item=c.inventory.make_loot(0,3,2,c.loot_rng,"blade"); c.inventory.receive(item); uid=item.uid
	snapshot=JSON.stringify(c.state)
	check(not c.inventory.reforge("bag",uid,0) and snapshot==JSON.stringify(c.state),"unaffordable reforge preserves complete state")
	c.state.coins=10000; c.state.materials=1000
	var instance: Dictionary=c.inventory.item_at("bag",uid); var old := instance.duplicate(true)
	check(c.inventory.reforge("bag",uid,1),"single selected roll can be reforged")
	check(instance.uid==old.uid and instance.affixes[0]==old.affixes[0] and instance.affixes[2]==old.affixes[2] and instance.reforges==1,"reforge preserves other rolls and identity")
	check(Items.valid_item(instance,{}),"reforged item remains schema-valid")
	c.inventory.toggle_lock("bag",uid); snapshot=JSON.stringify(c.state)
	check(not c.inventory.sell(uid) and not c.inventory.forge("bag",uid,"salvage") and not c.inventory.reforge("bag",uid,0) and snapshot==JSON.stringify(c.state),"locked item cannot be sold, salvaged or reforged")
	c.inventory.toggle_lock("bag",uid)
	c.inventory.receive(c.inventory.make("gem_ember",1,0,2))
	check(c.inventory.inscribe("bag",uid,"ember") and c.inventory.item_at("bag",uid).rune=="ember" and c.inventory.count("gem_ember")==1,"rune consumes one actual crystal")
	c.inventory.receive(c.inventory.make("gem_rime"))
	check(c.inventory.inscribe("bag",uid,"rime") and c.inventory.item_at("bag",uid).rune=="rime" and c.inventory.count("gem_rime")==0,"replacement consumes crystal and replaces old effect")
	check(c.inventory.sell(uid) and c.inventory.buy(uid,true) and c.inventory.item_at("bag",uid).affixes==instance.affixes,"buyback preserves original rolls and rune")
	# Functional effects through the real encounter authority.
	c=fixture(); c.state.stage=1; c.state.zone="4:1"; c.state.act=4
	worn(c,"a4-blade-0")
	var enemy := foe(); c.combat.enemies=[enemy]; c.combat.running=true
	c.state.hp=50
	c.combat.hit(enemy,100,0)
	check(enemy.get("rpg_vulnerable_time",0)>0 and c.state.hp>50,"actual hit applies vulnerability and leech")
	var first := 10000.0-float(enemy.hp); var previous := float(enemy.hp)
	c.combat.hit(enemy,100,0)
	check(previous-float(enemy.hp)>=first,"vulnerability increases following hit")
	c=fixture(); worn(c,"a2-blade-2",2); c.state.hero=2; c.inventory.sync_gear()
	enemy=foe(); c.combat.enemies=[enemy]; c.combat.running=true; c.combat.hit(enemy,100,2)
	previous=enemy.hp; c.equipment_combat.tick(.05)
	check(enemy.hp<previous and enemy.rpg_bleed_time<3,"bleed deals periodic damage without a new attack")
	var old_dot := float(enemy.rpg_bleed); enemy.rpg_bleed_time=0
	c.combat.hit(enemy,1,2)
	check(enemy.rpg_bleed<old_dot,"expired wound cannot retain an old high damage roll forever")
	c=fixture(); worn(c,"a3-blade-1",1); c.state.hero=1; c.inventory.sync_gear()
	enemy=foe(); c.combat.enemies=[enemy]; c.combat.running=true; c.combat.hit(enemy,100,1)
	check(enemy.rpg_slow>=16 and enemy.rpg_slow_time==2,"cold weapon applies timed slow")
	enemy.rpg_slow=35; c.combat.hit(enemy,100,1)
	check(enemy.rpg_slow==35,"weaker squad slow refreshes without downgrading an active effect")
	c=fixture(); worn(c,"a3-blade-0")
	c.equipment_combat.begin_strike(0,0); var regular: float=c.equipment_combat.strike_bonus[0]
	c.equipment_combat.begin_strike(0,0); c.equipment_combat.begin_strike(0,0)
	check(c.equipment_combat.strike_bonus[0]>=regular+40,"third-hit unique changes actual strike bonus")
	c=fixture(); worn(c,"a1-blade-2",2); c.state.hero=2; c.inventory.sync_gear()
	c.equipment_combat.dodge(); c.equipment_combat.begin_strike(2,0)
	check(c.equipment_combat.strike_bonus[2]>=28 and not c.equipment_combat.dash_ready[2],"dash bonus consumed once by next basic strike")
	c=fixture(); worn(c,"a5-armor--1")
	c.equipment_combat.dodge(); var shield: float=c.equipment_combat.barrier
	var hurt: float=c.equipment_combat.incoming(25)
	check(hurt<25 and c.equipment_combat.barrier<shield,"dodge shield absorbs real incoming damage")
	c.equipment_combat.dodge(); c.equipment_combat.tick(3.1)
	check(c.equipment_combat.barrier==0,"dodge shield expires")
	c=fixture(); worn(c,"a5-blade-1",1); c.state.hero=1; c.inventory.sync_gear()
	check(c.equipment_combat.incoming(50,"tide",true)<50,"equipment protects escorted survivors")
	c=fixture(); worn(c,"a2-blade-1",1); c.state.hero=1; c.inventory.sync_gear()
	check(c.skill_cooldown()<5,"cooldown unique changes real Q cooldown")
	c=fixture(); worn(c,"a1-blade-1",1); c.state.hero=1; c.inventory.sync_gear(); c.state.hp=50
	c.equipment_combat.tick(1)
	check(c.state.hp>50,"regeneration changes active health")
	# Attack speed changes the authored release timing, with a hard cap even for stacked sources.
	c=fixture(); item=worn(c,"a5-blade-2",2); c.state.hero=2; c.inventory.sync_gear()
	item.affixes=[{"id":"swift","value":11.2},{"id":"precise","value":9.8},{"id":"keen","value":12.0}]
	item.socket=true; item.rune="gale"
	check(Items.valid_item(item,{}) and c.inventory.modifiers(2).haste==30,"multiple legal haste sources saturate at thirty percent")
	c.state.act=5; c.state.zone="5:1"; c.state.stage=1; c.hero_at=c.spawn_at()
	var spec: Dictionary=Catalog.weapon(c.equipped_weapon())
	check(c.attack(Vector2.UP) and c.action_total<float(spec.rate) and c.action_windup<float(spec.windup),"real attack total and windup respond to haste")
	# Secondary damage is visible in the actual strike path, once per target, without status recursion.
	c=fixture(); worn(c,"a3-blade-1",1); c.state.hero=1; c.inventory.sync_gear()
	c.state.act=3; c.state.zone="3:1"; c.state.stage=1
	var scale: float=c.terrain().speed_scale()
	var found := false
	for p in c.terrain().cells:
		if c.walkable(p+Vector2(100,0)*scale) and c.sight(p,p+Vector2(100,0)*scale): c.hero_at=p; found=true; break
	check(found,"splash fixture uses visible walkable authored floor")
	enemy=foe(); enemy.p=c.hero_at
	var secondary := foe(); secondary.id="secondary"; secondary.p=c.hero_at+Vector2(100,0)*scale
	c.combat.enemies=[enemy,secondary]; c.combat.running=true
	check(c.attack(Vector2.UP),"splash attack begins with real equipped weapon")
	c.pending_strike.radius=50*scale; c.release_strike()
	check(secondary.hp<10000 and enemy.hp<secondary.hp,"released attack splashes a nearby target outside direct radius")
	check(not secondary.has("rpg_slow_time") and not secondary.has("rpg_bleed_time"),"secondary damage does not recursively apply statuses")
	# Maximum damage and status effects never skip authored boss barriers or finale decisions.
	for row in [[1,"inquisitor"],[2,"judge"],[3,"vein"],[4,"surgeon"],[5,"admiral"],[6,"queen"]]:
		c=fixture(); c.state.act=row[0]; c.state.stage=6; c.state.zone="%d:6" % row[0]
		worn(c,"a6-blade-0")
		c.combat.start("R-%d-06" % row[0],"fixture",row[1],1)
		if row[1] in ["vein","admiral"]: c.combat.phase=1; c.combat.spawn_phase()
		if row[1]=="queen": c.combat.phase=2; c.combat.spawn_phase()
		enemy=c.enemies[0]; var phase: int=c.combat.phase
		c.combat.hit(enemy,1000000,0)
		check(enemy.hp>0 and c.combat.phase==phase,"equipment cannot skip boss mechanism "+str(row[1]))
		c.combat.hit(enemy,1000000,0,0,false)
		check(enemy.hp>0 and c.combat.phase==phase,"secondary damage obeys mechanism "+str(row[1]))
	# Every chapter has useful rewards, permanent receipts, and full-container fallback.
	c=fixture()
	for act in range(1,7):
		c.state.act=act; var before: int=c.state.item_serial
		c.boss_equipment_drop("boss-%d" % act,Vector2.ZERO)
		check(c.state.item_serial==before+3,"boss grants unique, set, crystal for chapter %d" % act)
		before=c.state.item_serial; c.boss_equipment_drop("boss-%d" % act,Vector2.ZERO)
		check(c.state.item_serial==before,"boss receipt prevents duplicate reward")
	check(Items.valid_data(c.state),"all six chapters' drops form a valid save")
	c.path="user://rpg-equipment-test-%d.json" % OS.get_process_id(); c.save_enabled=true
	check(c.save_campaign(),"equipment campaign saves to disk")
	var d=Campaign.new(); d.save_enabled=false
	check(d.load_campaign(c.path),"equipment campaign reloads using actual save validation")
	check(JSON.stringify(d.state.bag)==JSON.stringify(c.state.bag) and d.state.world==c.state.world,"saved item rolls and loot receipts retained exactly")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(c.path+suffix): DirAccess.remove_absolute(c.path+suffix)
	print("RPG_EQUIPMENT %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
