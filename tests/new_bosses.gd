extends SceneTree
const Presentation = preload("res://scripts/boss_presentation.gd")
var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func raid_boss(s: TideSession) -> Dictionary:
	for e in s.enemies:
		if e.get("raid_boss",false): return e
	return {}

func mini_boss(s: TideSession) -> Dictionary:
	for e in s.enemies:
		if e.get("mini_boss",false): return e
	return {}

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	s.spawn_timer=9999
	s.enemies.clear()
	s.mini_bosses.spawn(s,1,0)
	var mini := mini_boss(s)
	check(not mini.is_empty() and int(mini.mini_kind)==0,"Mirror-Tomb Weaver can occupy the weak roster slot")
	if not mini.is_empty():
		var player: Dictionary=s.players[1]
		player.p=mini.p+Vector2(150,0)
		s.mini_bosses.cast(s,mini,player,"mirror_cross",Vector2.RIGHT)
		check(s.raid.hazards.size()==2,"Mirror cross has two timed hit shapes")
		check(s.raid.hazards[0].total<s.raid.hazards[1].total,"Mirror cross alternates fast and slow beats")
		check(Presentation.cue({"action":"release","boss_kind":3,"mini_kind":0,"shape":"line"})=="mirror-lance","Mirror has its own sound bank")
		mini.hp=0
		s.simulate(0.01)
		var reward := false
		for chest in s.ruins.chests:
			if str(chest.get("title","")).contains("守卫秘藏"):
				reward=true
				check(chest.items.any(func(item): return str(item.kind)=="mirror_fate_ledger"),"Mirror Weaver leaves its unique collectible")
				check(chest.items.any(func(item): return str(item.kind)=="mirror_thread"),"Mirror Weaver keeps its original thread relic")
		check(reward,"Defeated mini boss grants a reward chest")
	s.enemies.clear()
	s.expedition.prepare_day(s,2)
	s.mini_bosses.spawn(s,2,1)
	mini=mini_boss(s)
	check(not mini.is_empty() and int(mini.mini_kind)==1,"Ashen Vesper can occupy a strong roster slot")
	if not mini.is_empty():
		var player: Dictionary=s.players[1]
		s.mini_bosses.cast(s,mini,player,"ash_cross",Vector2.RIGHT)
		check(s.raid.hazards.size()==2,"Ashen Vesper combines line and cone attacks")
		s.mini_bosses.defeated(s,mini)
		var vesper_reward := false
		for chest in s.ruins.chests:
			if chest.items.any(func(item): return str(item.kind)=="vesper_last_page"):
				vesper_reward=true
				check(chest.items.any(func(item): return str(item.kind)=="ember_heart"),"Ashen Vesper keeps its original ember relic")
		check(vesper_reward,"Ashen Vesper leaves its unique collectible")
		s.raid.map_boss_defeats.clear()
	s.enemies.clear()
	s.expedition.prepare_day(s,3)
	var queen := raid_boss(s)
	check(not queen.is_empty() and not queen.get("final_form",false),"Day three begins with Blood Queen")
	if not queen.is_empty():
		queen.hp=0
		s.simulate(0.01)
	var final_boss := raid_boss(s)
	check(not final_boss.is_empty() and final_boss.get("final_form",false),"Queen defeat starts Nameless Blood Moon")
	check(s.raid.phase=="boss","Final form keeps the encounter active")
	if not final_boss.is_empty():
		var player: Dictionary=s.players[1]
		player.p=final_boss.p+Vector2(150,0)
		s.expedition.cast_boss(s,final_boss,player,"last_light",Vector2.RIGHT,player.p)
		check(s.raid.hazards.size()>=3,"Final move has ring, beam and targeted impact")
		check(Presentation.cue({"action":"phase","boss_kind":2,"final_form":true})=="moon-ritual","Final form has its own sound bank")
		final_boss.hp=0
		s.simulate(0.01)
	check(s.raid.phase=="complete","Only the final form clears the expedition")
	check(s.ruins.chests.any(func(chest): return chest.items.any(func(item): return str(item.kind)=="bloodmoon_nightwomb")),"Final Blood Moon reward contains red 3x3 nightwomb")
	for cue in ["mirror","ember","final"]:
		var stream: AudioStreamOggVorbis=load("res://assets/audio/music/%s.ogg" % cue)
		check(stream!=null and stream.get_length()>60,"Boss music imports: "+cue)
	for image_name in ["mirror-weaver","ashen-vesper","nameless-moon"]:
		check(load("res://assets/bosses/new/%s.png" % image_name)!=null,"Boss art imports: "+image_name)
	print("new_bosses: ",checks," checks, ",failures," failures")
	quit(1 if failures>0 else 0)
