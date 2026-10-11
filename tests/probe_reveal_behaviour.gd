extends SceneTree
## Probe: the cached occluder reveal must still fade, and restore, exactly as before.
const Screen=preload("res://scripts/story_screen.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("PROBE_FAIL "+message)
	print("PROBE %s %s" % ["PASS" if ok else "FAIL",message])
func reveal_values(kit, node) -> Array:
	var cache: Dictionary=kit.reveal_cache.get(node,{})
	var values: Array=[]
	for mesh in cache.values():
		if is_instance_valid(mesh): values.append(float(mesh.get_meta("reveal_amount",-9.0)))
	return values
func run() -> void:
	var screen=Screen.new(); root.add_child(screen)
	screen.campaign.save_enabled=false
	screen.start("user://probe-reveal-unused.json")
	var c=screen.campaign
	c.state=c.new_state()
	c.enter(1,7)
	screen.set_active(true)
	var env=screen.world.environment_builder
	var kit=env.kit
	# Pick a tall occluder and stand the hero just in front of it, low on screen.
	var subject: Dictionary={}
	for item in env.occluders:
		if float(item.height)>=250.0 and is_instance_valid(item.node): subject=item; break
	check(not subject.is_empty(),"cave has a tall occluder to test (%d occluders)" % env.occluders.size())
	if subject.is_empty(): quit(1); return
	# The reveal test drives the projection directly: place the hero between the camera
	# and the occluder so the occluder covers them.
	c.hero_at=Vector2(subject.p)+Vector2(0,-140)
	screen.world.sync_story(screen.size,1.0/60.0)
	var settled := reveal_values(kit,subject.node)
	check(settled.size()>0,"tall occluder carries fade surfaces (%d)" % settled.size())
	var blocked: bool=false
	for i in 200:
		c.hero_at=Vector2(subject.p)+Vector2(0,-40)
		screen.world.sync_story(screen.size,1.0/60.0)
		var values := reveal_values(kit,subject.node)
		if values.size()>0 and float(values[0])<=0.001:
			blocked=true
			break
	check(blocked,"occluder in front of the hero fades to 0 with the cached path")
	var hidden: bool=not subject.node.visible
	check(hidden,"fully faded occluder is hidden")
	# Stepping away must restore the original amount in full.
	var restored := false
	for i in 200:
		c.hero_at=Vector2(subject.p)+Vector2(0,1400)
		screen.world.sync_story(screen.size,1.0/60.0)
		var values := reveal_values(kit,subject.node)
		if values.size()>0 and is_equal_approx(float(values[0]),1.0):
			restored=true
			break
	check(restored,"occluder restores to amount 1.0 once the hero steps away")
	check(subject.node.visible,"restored occluder is visible again")
	# A repeated unchanged frame must not touch RenderingServer: the cached meta stays.
	c.hero_at=Vector2(subject.p)+Vector2(0,1400)
	screen.world.sync_story(screen.size,1.0/60.0)
	var before := reveal_values(kit,subject.node)
	screen.world.sync_story(screen.size,1.0/60.0)
	var after := reveal_values(kit,subject.node)
	check(before==after,"unchanged reveal keeps a stable cached amount")
	# Region rebuild must drop stale cache entries.
	var cached_before: int=kit.reveal_cache.size()
	c.enter(1,1)
	var cached_after: int=kit.reveal_cache.size()
	check(cached_after<=cached_before,"rebuilt region refreshes the reveal cache (%d -> %d)" % [cached_before,cached_after])
	check(cached_after>0 or screen.world.environment_builder.occluders.is_empty(),"new region re-registers its own occluders")
	print("PROBE done %d checks %d failures" % [checks,failures])
	quit(1 if failures else 0)
