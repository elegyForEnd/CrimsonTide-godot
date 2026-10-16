extends SceneTree
const Campaign=preload("res://scripts/scarlet/campaign.gd")
const Navigation=preload("res://scripts/scarlet/quest_navigation.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false
	var nav=Navigation.new(); nav.campaign=c
	c.hero_at=c.spawn_at(); nav.refresh()
	check(not nav.target.is_empty() and c.walkable(nav.target.p),"current quest resolves to real reachable ground")
	check(nav.path.size()>1,"initial objective has a walkable route")
	for i in range(1,nav.path.size()): check(c.walkable(nav.path[i]),"every route cell respects actual collision")
	check(nav.distance_text().contains("米"),"distance uses physical world scale")
	var q: Dictionary=c.current_main()
	var original_zone: String=q.nodes[0].zone
	for z in ["1:1","1:4","1:5","1:6","2:0"]:
		c.state.zone=z; c.state.act=int(z.get_slice(":",0)); c.state.stage=int(z.get_slice(":",1)); c.hero_at=c.spawn_at()
		nav.refresh()
		check(nav.target.get("transfer",false),"other region points to connecting entrance "+z)
		check(c.walkable(nav.target.p),"connecting entrance is on actual floor "+z)
		check(nav.target.zone==original_zone,"destination remains the tracked quest region")
	c.state.zone="1:0"; c.state.act=1; c.state.stage=0; c.hero_at=c.spawn_at()
	nav.refresh(); c.hero_at=nav.target.p; nav.refresh()
	check(nav.distance_text().contains("附近"),"arrival prompts interaction")
	var map=preload("res://scripts/scarlet/map.gd").new(); map.campaign=c; map.navigator=nav; map.size=Vector2(580,535); root.add_child(map)
	var midpoint: Vector2=map.local(Vector2(900,900))
	check(midpoint.distance_to(map.map_rect().get_center())<.01,"non-square scene keeps actor and photograph coordinates aligned")
	c.state.zone="2:3"; c.state.act=2; c.state.stage=3
	c.combat.start("R-2-06","fixture","judge",1)
	nav.refresh()
	check(nav.target.get("kind","")=="gadget","combat tracking prioritizes actual boss mechanisms")
	c.combat.clear()
	c.state.zone="5:2"; c.state.act=5; c.state.stage=2; c.state.trial_task={"qid":"fixture","node":"fixture","index":0}
	nav.refresh()
	check(nav.target.id=="trial-point","trial tracking follows active sailing marker")
	check(map.map_rect().has_point(map.local(nav.target.p)),"trial marker remains inside extended sea map")
	c.state.trial_task={}
	for z in c.content.zones:
		c.state.zone=z; c.state.act=int(z.get_slice(":",0)); c.state.stage=int(z.get_slice(":",1))
		check(ResourceLoader.exists(c.terrain().scene_path(false)),"actual packed scene exists "+z)
		check(ResourceLoader.exists(c.terrain().scene_path(true)),"compatibility scene exists "+z)
	map.queue_free(); await process_frame
	print("SCARLET_MAP_TRACKING %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
