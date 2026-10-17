extends SceneTree
const Campaign=preload("res://scripts/scarlet/campaign.gd")
const Roster=preload("res://scripts/scarlet/enemy_roster.gd")
const Frames=preload("res://scripts/scarlet/enemy_frames.gd")
const Encounters=preload("res://scripts/scarlet/enemy_encounters.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func make(act: int=1,stage: int=6):
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false
	c.state.act=act; c.state.stage=stage; c.state.zone="%d:%d" % [act,stage]; c.state.party=[0]
	return c
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Roster.data().minions.size()==8,"eight distinct small-enemy identities")
	check(Roster.data().bosses.size()==8,"six chapter bosses and two optional bosses")
	var seen: Dictionary={}
	for act in range(1,7):
		var c=make(act,2)
		c.combat.start("R-%d-02" % act,"fixture","",4)
		check(c.enemies.size()==4,"requested encounter count retained")
		for enemy in c.enemies:
			seen[enemy.key]=true
			check(Roster.profile(enemy.key).name==enemy.name,"simulation uses authored identity")
			check(c.state.world.get("enemy_seen:"+str(enemy.key),false),"bestiary records encounter without advancing quest")
			check(c.walkable(enemy.p),"enemy starts on reachable ground")
	check(seen.size()==8,"all minion designs occur in chapter compositions")
	for key in Roster.data().minions:
		var c=make(); c.combat.start("R-P02","fixture","",1,false,[key]); var e: Dictionary=c.enemies[0]
		c.hero_at=c.safe_place(e.p+Vector2(0,200)*c.terrain().speed_scale())
		for move in Roster.moves(key,0):
			c.combat.hazards.clear(); c.combat.attack_pattern(e)
			check(not c.combat.hazards.is_empty(),"minion has active attacks "+key)
			check(e.windup>=.8 and e.recover>e.windup,"visible windup and punishable recovery "+key)
			var original: Vector2=c.combat.hazards[0].p
			var aim: Vector2=e.aim
			c.hero_at=c.safe_place(c.hero_at+Vector2(180,0)); c.combat.opening_grace=0
			c.combat.tick(.05)
			check(c.combat.hazards[0].p==original and e.aim==aim,"locked tells never follow player after windup "+key)
			var hp: float=e.hp
			c.combat.hit(e,e.maxhp*.2,0,0,false)
			check(e.hp<hp and e.stagger>0 and c.combat.hazards.is_empty(),"strong hit interrupts minion cast "+key)
			e.hp=e.maxhp; e.stagger=0
	for key in Roster.data().bosses:
		var act: int={"inquisitor":1,"judge":2,"vein":3,"surgeon":4,"admiral":5,"queen":6,"beast":3,"warden":6}[key]
		var c=make(act); c.combat.start("R-%d-06" % act,"fixture",key,1)
		check(c.enemies[0].key==key,"boss art identity follows key rather than chapter "+key)
		var phase_count: int=Roster.profile(key).phases.size()
		check(phase_count==c.content.bosses[key].phases.size(),"design phases agree with screenplay "+key)
		for phase in phase_count:
			c.combat.phase=phase; c.combat.spawn_phase()
			for move in Roster.moves(key,phase):
				c.combat.hazards.clear(); c.combat.attack_pattern(c.enemies[0])
				check(c.enemies[0].skill!="" and c.enemies[0].skill_hint!="","named boss move and actual counter")
				for h in c.combat.hazards:
					check(h.delay>=1.0 and h.damage>0 and h.reach>0,"boss attacks are delayed and finite")
					check(h.direction.is_normalized(),"hazard direction normalized")
					if h.shape=="ring":
						check(not c.combat.hazard_contains(h,h.p),"ring's pictured center is genuinely safe")
						check(c.combat.hazard_contains(h,h.p+Vector2.RIGHT*(h.inner+h.radius)*.5),"ring damages only the annulus")
	# Fixed ground tells: no movement while a sword/crossbow is committing.
	var c=make(2); c.combat.start("R-2-01","fixture","",1,false,["royal_arbalist"])
	var e: Dictionary=c.enemies[0]; var before: Vector2=e.p
	c.combat.attack_pattern(e); c.combat.tick(.1)
	check(e.p==before,"enemy holds ground during its aimed tell")
	# Frontal protection has a side/back counter and expires on committed attacks.
	c=make(); c.combat.start("R-P02","fixture","",1,false,["royal_pikeman"]); e=c.enemies[0]
	e.aim=Vector2.DOWN; c.hero_at=e.p+Vector2(0,10); var hp: float=e.hp
	c.combat.hit(e,10,0,0,false); var front: float=hp-e.hp
	e.hp=hp; c.hero_at=e.p-Vector2(0,10); c.combat.hit(e,10,0,0,false)
	check(front<hp-e.hp,"spear guard's rear remains vulnerable")
	e.hp=hp; e.recover=1.0; c.hero_at=e.p+Vector2(0,10); c.combat.hit(e,10,0,0,false)
	check(is_equal_approx(hp-e.hp,10),"spear guard remains open throughout its recovery")
	# Crossbows removed mid-cast lose their existing line as well as future fire.
	c=make(); c.combat.start("R-1-06","fixture","inquisitor",1); c.combat.attack_pattern(c.enemies[0])
	var gadget: Dictionary=c.combat.gadgets()[0]; c.hero_at=gadget.p; c.combat.use_gadget(gadget.id)
	check(not c.combat.hazards.any(func(h): return h.get("mechanism","")==gadget.id),"dismantling turret cancels its queued fire")
	# Field fights are deliberate, independent and permanent; survive real JSON save/load.
	for zone in Encounters.PATROLS:
		c=make(int(zone.get_slice(":",0)),int(zone.get_slice(":",1)))
		var marker: Dictionary=Encounters.nodes(c)[0]
		check(c.walkable(marker.p),"optional encounter is accessible "+zone)
		var steps: Dictionary=c.state.steps.duplicate(true)
		c.hero_at=marker.p; check(c.use(marker),"optional field encounter starts only on explicit E")
		var snap: Dictionary=JSON.parse_string(JSON.stringify(c.combat.snapshot()))
		c.combat.restore(snap)
		check(c.combat.context.has("patrol") and c.walkable(c.hero_at),"patrol checkpoint restores through JSON")
		for foe in c.enemies.duplicate(): c.combat.hit(foe,100000,0,0,false)
		check(not c.combat.running and Encounters.nodes(c).is_empty(),"cleared field pack cannot respawn or farm")
		check(c.state.steps==steps,"optional victory never advances narrative task")
	c=make(4,2); c.path="user://scarlet-enemy-checkpoint-fixture.json"; c.save_enabled=true
	var marker: Dictionary=Encounters.nodes(c)[0]; c.hero_at=marker.p; c.use(marker)
	check(c.save_campaign(),"real encounter checkpoint writes successfully")
	var loaded=Campaign.new(); loaded.save_enabled=false
	check(loaded.load_campaign(c.path),"real encounter checkpoint loads successfully")
	check(loaded.combat.context.get("patrol","")==marker.id and loaded.enemies.map(func(foe): return foe.key)==c.enemies.map(func(foe): return foe.key),"on-disk save restores exact pack and patrol anchor")
	# Every delivered frame is a real transparent texture and is selected by rules.
	for group in [Roster.data().minions,Roster.data().bosses]:
		for key in group:
			var frames:=Frames.prepare(key)
			check(frames.size()==3,"three delivered poses "+key)
			if frames.size()!=3: continue
			var texture: Texture2D=frames[0].texture
			check(texture.get_image().detect_alpha()!=Image.ALPHA_NONE,"actual alpha retained "+key)
			for frame in frames:
				check(frame.region.size.x>50 and frame.region.size.y>50,"real pose pixels "+key)
				check(Rect2(Vector2.ZERO,frame.texture.get_size()).encloses(frame.region),"UV rectangles stay inside texture")
				check(not frame.pieces.is_empty() and frame.pieces.size()<=12,"bounded UV pieces prevent neighboring-pose leakage")
				for piece in frame.pieces:
					check(frame.region.encloses(piece.region),"isolated UV pieces stay inside original figure bounds")
			var actor: Dictionary={"key":key,"hp":10.0,"windup":0.0,"release":0.0,"aim":Vector2.RIGHT}
			check(Frames.pose(actor,0).region==frames[0].region,"idle pose selected")
			actor.windup=1.0; check(Frames.pose(actor,0).region==frames[1].region,"windup pose selected")
			actor.release=.3; check(Frames.pose(actor,0).region==frames[2].region,"strike pose selected at actual impact")
			actor.aim=Vector2.LEFT; check(Frames.pose(actor,0).facing<0,"faces left without shifting footprint")
	for film in c.content.cinematics.values(): check(film.path==null,"cinematic slots remain empty")
	var queen_frames:=Frames.prepare("queen")
	check(queen_frames[0].texture!=queen_frames[1].texture,"queen's windup uses an independent complete sprite")
	check(queen_frames[1].texture!=queen_frames[2].texture,"queen's rapier follow-through never crosses an atlas seam")
	print("SCARLET_ENEMIES ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
