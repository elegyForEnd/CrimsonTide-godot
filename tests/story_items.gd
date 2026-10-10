extends SceneTree
const Campaign = preload("res://scripts/story_campaign.gd")
const Items = preload("res://scripts/story_inventory.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func fixture():
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state(); c.inventory.initialize(); return c
func fill_bag(c) -> void:
	c.state.bag=[]
	for y in Items.BAG.y:
		for x in Items.BAG.x:
			var item: Dictionary=c.inventory.make("potion",1,0,5); item.x=x; item.y=y; c.state.bag.append(item)
func run() -> void:
	var c=fixture(); var inv=c.inventory
	check(Items.dimensions(inv.make("sword"))==Vector2i(1,4),"long sword occupies four cells")
	check(Items.dimensions(inv.make("staff"))==Vector2i(2,4),"staff occupies eight cells")
	check(Items.dimensions(inv.make("plate"))==Vector2i(2,3),"armor occupies six cells")
	var sword: Dictionary=inv.make("sword",2,1); inv.receive(sword)
	check(inv.move("bag",sword.uid,"bag",Vector2i(9,2)),"exact lower-right vertical placement succeeds")
	var snapshot := JSON.stringify(c.state)
	check(not inv.rotate("bag",sword.uid) and JSON.stringify(c.state)==snapshot,"rotation beyond edge rejected without mutation")
	check(inv.move("bag",sword.uid,"bag",Vector2i(3,2),true),"horizontal rotation uses width4 height1")
	check(Items.dimensions(inv.item_at("bag",sword.uid))==Vector2i(4,1),"rotation persisted")
	var armor: Dictionary=inv.make("plate",3,2); inv.receive(armor)
	snapshot=JSON.stringify(c.state)
	check(not inv.move("bag",armor.uid,"bag",Vector2i(3,2)) and JSON.stringify(c.state)==snapshot,"overlap rejects complete move atomically")
	check(inv.equip("bag",sword.uid),"right hero equips real sword instance")
	check(c.state.gear.blade==2 and c.state.equipment[0].blade.uid==sword.uid,"legacy combat mirror and instance agree")
	check(c.damage()==24+5+22+4,"affix increases actual combat damage")
	c.switch_hero(1)
	check(c.state.gear.blade==0 and c.damage()==29,"other hero gear and affixes independent")
	var staff: Dictionary=inv.make("staff",3,2); inv.receive(staff)
	c.switch_hero(0); snapshot=JSON.stringify(c.state)
	check(not inv.equip("bag",staff.uid) and JSON.stringify(c.state)==snapshot,"incompatible hero equipment does not disappear")
	c.switch_hero(1); check(inv.equip("bag",staff.uid),"caster equips staff")
	c.switch_hero(0); check(inv.equip("bag",armor.uid),"hero equips armor")
	check(c.damage(1)>c.damage(2) and int(c.state.hero)==0,"companion damage reads its own gear without switching active hero")
	check(c.max_hp()==159+54+18+7,"armor and sword hp affixes affect real max hp")
	fill_bag(c); snapshot=JSON.stringify(c.state)
	check(not inv.unequip(0,"blade") and JSON.stringify(c.state)==snapshot,"full bag unequip leaves worn item untouched")
	# Swap must be all-or-nothing when old staff is bigger than the replacement footprint.
	c.state.bag.clear(); c.switch_hero(1)
	var small: Dictionary=inv.make("staff",1); small.rotated=true; Items.place(c.state.bag,small,Items.BAG)
	# Construct blocked spaces leaving only the smaller sword test for slot-compatible amulets.
	c.switch_hero(0); c.state.bag=[]
	var wide: Dictionary=inv.make("raven",3); inv.receive(wide); inv.equip("bag",wide.uid)
	fill_bag(c); c.state.bag.remove_at(0); c.state.bag.remove_at(9)
	var narrow: Dictionary=inv.make("ruby",1); narrow.x=0; narrow.y=0; c.state.bag.append(narrow)
	snapshot=JSON.stringify(c.state)
	check(not inv.equip("bag",narrow.uid) and JSON.stringify(c.state)==snapshot,"swap refuses if removed wide amulet cannot fit")
	# Merchant uses item metadata and persistent stock; not index-based UI inventory.
	c=fixture(); inv=c.inventory; c.state.coins=2000
	var products: Array=inv.stock(); var product: Dictionary=products[0]; var stock_count := int(product.stock)
	var gold := int(c.state.coins)
	check(inv.buy(product.uid),"merchant purchase creates real grid item")
	check(c.state.coins==gold-Items.price(product) and product.stock==stock_count-1,"purchase deducts exact price and finite stock")
	var purchased: Dictionary=c.state.bag[0]; var owned_uid: String=purchased.uid
	check(owned_uid!=product.uid,"merchant template has separate identity")
	check(inv.sell(owned_uid) and c.state.bag.is_empty(),"sell removes the actual instance")
	gold=c.state.coins
	check(inv.buy(owned_uid,true) and c.state.bag[0].uid==owned_uid,"buyback restores original instance")
	check(c.state.coins==gold-Items.sale_price(purchased) and c.state.buyback.is_empty(),"buyback price and removal correct")
	fill_bag(c); snapshot=JSON.stringify(c.state)
	check(not inv.buy(product.uid) and JSON.stringify(c.state)==snapshot,"full bag purchase does not charge or consume stock")
	c.state.coins=0; snapshot=JSON.stringify(c.state)
	check(not inv.buy(product.uid) and JSON.stringify(c.state)==snapshot,"insufficient funds has no side effects")
	c.state.stage=1; snapshot=JSON.stringify(c.state)
	check(not inv.buy(product.uid) and not inv.sell(c.state.bag[0].uid) and JSON.stringify(c.state)==snapshot,"trade blocked outside camp")
	c.state.stage=0; c.state.coins=10000; c.state.bag=[]
	product.stock=0; snapshot=JSON.stringify(c.state)
	check(not inv.buy(product.uid) and JSON.stringify(c.state)==snapshot,"sold out cannot generate duplicates")
	# Exact cell stacks and insufficient stack capacity.
	var p1: Dictionary=inv.make("potion",1,0,3); var p2: Dictionary=inv.make("potion",1,0,3)
	Items.place(c.state.bag,p1,Items.BAG); Items.place(c.state.bag,p2,Items.BAG)
	snapshot=JSON.stringify(c.state)
	check(not inv.move("bag",p2.uid,"bag",Vector2i.ZERO) and JSON.stringify(c.state)==snapshot,"overfull stack exact drop rejected atomically")
	c.state.bag[1].count=2
	check(inv.move("bag",p2.uid,"bag",Vector2i.ZERO) and c.state.bag.size()==1 and c.state.bag[0].count==5,"compatible exact drop merges stack")
	var p3: Dictionary=inv.make("potion",1,0,2); Items.place(c.state.bag,p3,Items.BAG)
	c.state.hp=1
	check(inv.use(p3.uid) and inv.item_at("bag",p3.uid).count==1 and c.state.bag[0].count==5,"use consumes selected stack only")
	check(c.state.hp>1,"inventory potion restores real health")
	c.state.hp=c.max_hp(); c.state.potions=14
	check(inv.use(p3.uid) and c.state.potions==15,"full-health potion refills belt")
	# Warehouse exact positioning, locality, and overflow recovery.
	var garment: Dictionary=inv.make("plate",2); inv.receive(garment)
	check(inv.move("bag",garment.uid,"stash",Vector2i(10,7)),"warehouse exact requested position")
	check(inv.item_at("stash",garment.uid).x==10 and inv.item_at("stash",garment.uid).y==7,"warehouse does not silently auto-place")
	c.state.stage=1; snapshot=JSON.stringify(c.state)
	check(not inv.transfer("stash",garment.uid,"bag") and JSON.stringify(c.state)==snapshot,"warehouse inaccessible in field")
	c.state.stage=0; check(inv.transfer("stash",garment.uid,"bag"),"withdraw can auto-place into bag")
	var identities: Array=[]
	for item in c.state.bag: identities.append(item.uid)
	check(inv.tidy("bag"),"tidy handles real item sizes")
	for uid in identities: check(not inv.item_at("bag",uid).is_empty(),"tidy preserves item identity "+uid)
	# Upgrade, socket and craft change real stats and use materials exactly once.
	c=fixture(); inv=c.inventory; c.state.coins=10000; c.state.materials=100
	sword=inv.make("sword",2,1); inv.receive(sword); inv.equip("bag",sword.uid)
	var attack := c.damage(); var hp := c.max_hp()
	gold=c.state.coins; var material := int(c.state.materials)
	check(inv.forge("equipped:0:blade",sword.uid,"upgrade"),"worn item can be upgraded")
	check(c.damage()==attack+11 and c.state.coins==gold-90 and c.state.materials==material-3,"upgrade applied to combat and exact budget")
	inv.receive(inv.make("crystal",1,0,2)); gold=c.state.coins
	check(inv.forge("equipped:0:blade",sword.uid,"socket"),"physical crystal used for socket")
	check(c.damage()==attack+11+8 and c.max_hp()==hp+12 and inv.count("crystal")==1 and c.state.coins==gold-80,"socket real bonuses and costs")
	snapshot=JSON.stringify(c.state)
	check(not inv.forge("equipped:0:blade",sword.uid,"socket") and JSON.stringify(c.state)==snapshot,"repeat socket rejected without cost")
	for i in 4: check(inv.forge("equipped:0:blade",sword.uid,"upgrade"),"successive upgrade %d" % i)
	snapshot=JSON.stringify(c.state)
	check(not inv.forge("equipped:0:blade",sword.uid,"upgrade") and JSON.stringify(c.state)==snapshot,"upgrade cap enforced atomically")
	check(not inv.forge("equipped:0:blade",sword.uid,"salvage"),"equipped item cannot be accidentally dismantled")
	check(inv.unequip(0,"blade"),"upgraded instance can be removed intact")
	material=c.state.materials
	check(inv.forge("bag",sword.uid,"salvage") and inv.item_at("bag",sword.uid).is_empty() and c.state.materials==material+11,"dismantle deletes one instance and credits iron")
	gold=c.state.coins; material=c.state.materials
	check(inv.craft("sword") and c.state.coins==gold-125 and c.state.materials==material-8,"craft produces real item with exact costs")
	check(c.state.bag[-1].quality==1 and c.state.bag[-1].tier==1,"craft stage-controlled affixed result")
	fill_bag(c); snapshot=JSON.stringify(c.state)
	check(not inv.craft("sword") and JSON.stringify(c.state)==snapshot,"full bag craft restores serial and retains all inputs")
	c.state.bag=[]; sword=inv.make("sword"); inv.receive(sword); c.state.materials=0; c.state.coins=0
	snapshot=JSON.stringify(c.state)
	check(not inv.forge("bag",sword.uid,"upgrade") and JSON.stringify(c.state)==snapshot,"insufficient forge resources do not alter state")
	# Legacy saves keep rank, all loot, and overflowing rewards without losing a single item.
	var legacy=Campaign.new(); legacy.save_enabled=false; legacy.state=legacy.new_state()
	legacy.state.kits[1].blade=4
	for i in 160: legacy.state.bag.append({"slot":"armor","tier":2,"name":"旧装备%d" % i})
	legacy.inventory.initialize()
	check(legacy.state.bag.size()+legacy.state.stash.size()+legacy.state.overflow.size()==160,"large old save migrates every instance")
	check(legacy.state.equipment[1].blade.base=="staff" and legacy.state.kits[1].blade==4,"legacy caster equipment rank retained")
	check(Items.valid_data(legacy.state),"migrated grid and instance structure passes validation")
	var extra: Dictionary=legacy.inventory.make("ruby"); var before: int=legacy.state.overflow.size(); legacy.inventory.receive(extra)
	check(legacy.state.overflow.size()==before+1,"full bag and vault reward enters recoverable overflow")
	legacy.state.bag=[]
	check(legacy.inventory.transfer("overflow",extra.uid,"bag"),"overflow item can be claimed later")
	legacy.path="user://story-item-roundtrip.json"; legacy.save_enabled=true
	check(legacy.save_campaign(),"new inventory save writes atomically")
	var loaded=Campaign.new(); loaded.load_campaign(legacy.path)
	check(loaded.state.bag==legacy.state.bag and loaded.state.overflow==legacy.state.overflow,"instance identity, layout and overflow survive JSON reload")
	check(loaded.state.equipment==legacy.state.equipment,"hero equipment instances survive reload")
	var corrupted: Dictionary=legacy.state.duplicate(true); corrupted.bag[0].base="unknown"
	check(not loaded.valid_save(corrupted),"invalid item base rejected")
	corrupted=legacy.state.duplicate(true); corrupted.overflow.append(corrupted.bag[0].duplicate())
	check(not loaded.valid_save(corrupted),"duplicate instance ids rejected")
	corrupted=legacy.state.duplicate(true); corrupted.bag[0].x=100
	check(not loaded.valid_save(corrupted),"outside-grid save rejected")
	# Full stock and buyback roundtrip validates all identity spaces.
	c=fixture(); c.inventory.stock(); c.state.coins=2000
	c.inventory.buy(c.inventory.stock()[0].uid); c.inventory.sell(c.state.bag[0].uid)
	check(c.valid_save(c.state),"merchant templates and buyback are valid persistent state")
	print("story items: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
