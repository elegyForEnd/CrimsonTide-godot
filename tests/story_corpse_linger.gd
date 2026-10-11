extends SceneTree
## Gate: a defeated story enemy keeps its body for CORPSE_LINGER, then leaves the field
## without ever becoming respawnable.
const Campaign=preload("res://scripts/story_campaign.gd")
const Screen=preload("res://scripts/story_screen.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
	print("%s %s" % ["PASS" if ok else "FAIL",message])
func _initialize() -> void: call_deferred("run")
func corpse_of(c, id: String) -> Dictionary:
	for e in c.enemies:
		if e.id==id: return e
	return {}
func sprites_at(screen, at: Vector2) -> int:
	var total := 0
	for child in screen.world.get_children():
		if child is Sprite3D and child.visible and Vector2(child.position.x,child.position.z).distance_to(at*0.01)<0.05: total+=1
	return total
func run() -> void:
	var screen=Screen.new(); root.add_child(screen)
	screen.campaign.save_enabled=false
	screen.start("user://corpse-linger-unused.json")
	var c=screen.campaign
	c.state=c.new_state()
	c.enter(1,7)
	screen.set_active(true)
	check(is_equal_approx(Campaign.CORPSE_LINGER,10.0),"linger is ten seconds (%f)" % Campaign.CORPSE_LINGER)
	var victim: Dictionary={}
	for e in c.enemies:
		if e.hp>0: victim=e; break
	check(not victim.is_empty(),"a living cave enemy exists")
	if victim.is_empty(): quit(1); return
	var id: String=str(victim.id)
	check(is_equal_approx(float(victim.get("corpse_time",-1.0)),Campaign.CORPSE_LINGER),"spawned enemy carries the linger timer")
	c.hit(victim,999999.0,0,c.hero_at)
	check(victim.hp<=0,"lethal hit defeats the enemy")
	check(bool(c.state.defeated.get(id,false)),"defeated id is recorded for spawn suppression")
	# --- still on the field just before the limit -------------------------------------
	var clock := 0.0
	while clock<9.0:
		c.update(1.0/60.0,Vector2.ZERO); screen._process(1.0/60.0); clock+=1.0/60.0
	var early := corpse_of(c,id)
	check(not early.is_empty(),"corpse is still on the field at %.1fs" % clock)
	check(float(early.get("corpse_time",0.0))>0.0,"corpse timer is still running at %.1fs" % clock)
	check(sprites_at(screen,victim.p)>0,"corpse body is still submitted to the renderer at %.1fs" % clock)
	# The last two seconds fade the body instead of popping it out.
	while clock<9.5:
		c.update(1.0/60.0,Vector2.ZERO); screen._process(1.0/60.0); clock+=1.0/60.0
	check(sprites_at(screen,victim.p)>0,"fading corpse body is still drawn at %.1fs" % clock)
	# --- gone after the limit ---------------------------------------------------------
	var gone_at := -1.0
	while clock<13.0:
		c.update(1.0/60.0,Vector2.ZERO); screen._process(1.0/60.0); clock+=1.0/60.0
		if corpse_of(c,id).is_empty() and gone_at<0.0: gone_at=clock
	check(gone_at<0.0 or (gone_at>Campaign.CORPSE_LINGER-0.2 and gone_at<Campaign.CORPSE_LINGER+0.5),"corpse left the field at %.2fs (limit %.1fs)" % [gone_at,Campaign.CORPSE_LINGER])
	check(corpse_of(c,id).is_empty(),"corpse is gone after the linger window")
	# --- the cleared enemy must never respawn ----------------------------------------
	c.enter(1,7)
	var respawned := not corpse_of(c,id).is_empty()
	for e in c.enemies:
		if e.id==id: respawned=true
	check(not respawned,"re-entering the cave does not respawn a faded corpse")
	c.enter(1,1)
	c.enter(1,7)
	var again := false
	for e in c.enemies:
		if e.id==id: again=true
	check(not again,"leaving and returning does not respawn it either")
	print("corpse linger: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
