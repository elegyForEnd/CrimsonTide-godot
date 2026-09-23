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

func wild_mini(s: TideSession, kind: int) -> Dictionary:
	for e in s.enemies:
		if e.get("wild_boss",false) and int(e.wild_kind)==kind: return e
	return {}

func raid_boss(s: TideSession) -> Dictionary:
	for e in s.enemies:
		if e.get("raid_boss",false): return e
	return {}

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	s.spawn_timer=9999
	s.enemies.clear()
	s.wild_bosses.spawn_mini(s,1,0)
	var worm := wild_mini(s,0)
	check(not worm.is_empty(),"Earthsplitter can occupy the weak roster slot")
	if not worm.is_empty():
		var player: Dictionary=s.players[1]
		player.p=worm.p+Vector2(190,0)
		s.raid.hazards.clear()
		s.wild_bosses.cast(s,worm,player,"burrow",Vector2.RIGHT)
		check(worm.p==worm.home and worm.has("travel_target"),"Burrow telegraphs before relocation")
		s.wild_bosses.update(s,worm,1.1)
		check(worm.p!=worm.home,"Burrow relocates on impact")
		check(s.raid.hazards.any(func(h): return h.shape=="lane"),"Burrow leaves an actual tunnel hit area")
		s.raid.hazards.clear()
		s.wild_bosses.cast(s,worm,player,"burrow",Vector2.RIGHT)
		worm.stagger=0.5
		s.wild_bosses.update(s,worm,0.1)
		check(not worm.has("travel_target") and s.raid.hazards.is_empty(),"Stagger interrupts burrow and cancels its hit areas")
		worm.stagger=0.0
		s.wild_bosses.cast(s,worm,player,"molt",Vector2.RIGHT)
		var h: Dictionary=s.raid.hazards[0]
		check(h.shape=="gap_ring","Molt creates a ring with an angular gap")
		check(not s.expedition.hazard_contains(h,h.p+h.aim*200),"Bright gap is safe")
		check(s.expedition.hazard_contains(h,h.p-h.aim*200),"Opposite arc is dangerous")
		check(Presentation.cue({"action":"release","wild_boss":true,"wild_kind":0,"boss_kind":2,"shape":"lane"})=="earth-lance","Worm has its own sound bank")
		s.raid.hazards.clear()
		worm.hp=0
		s.simulate(0.01)
		check(s.raid.wild_seals.has(0),"Defeating Earthsplitter records first secret seal")
		check(s.ruins.chests.any(func(chest): return chest.items.any(func(item): return str(item.kind)=="fault_pulse_fossil")),"Earthsplitter leaves its unique collectible")
		check(s.ruins.chests.any(func(chest): return chest.items.any(func(item): return str(item.kind)=="fault_scale")),"Earthsplitter keeps its original fault scale")
	s.enemies.clear()
	s.expedition.prepare_day(s,2)
	s.wild_bosses.spawn_mini(s,2,1)
	var roc := wild_mini(s,1)
	check(not roc.is_empty(),"Storm Roc can occupy a strong roster slot")
	if not roc.is_empty():
		var player: Dictionary=s.players[1]
		player.p=roc.p+Vector2(190,0)
		s.raid.hazards.clear()
		s.wild_bosses.cast(s,roc,player,"front",Vector2.RIGHT)
		check(s.raid.hazards.size()==4,"Storm front leaves a deliberate central corridor")
		check(not s.expedition.hazard_contains(s.raid.hazards[0],roc.p+Vector2(180,0)),"Central storm corridor has no hit area")
		check(Presentation.cue({"action":"phase","wild_boss":true,"wild_kind":1,"boss_kind":0})=="storm-ritual","Roc has its own sound bank")
		s.raid.hazards.clear()
		roc.hp=0
		s.simulate(0.01)
		check(s.ruins.chests.any(func(chest): return chest.items.any(func(item): return str(item.kind)=="storm_roc_sunheart")),"Storm Roc leaves its red 3x3 collectible")
		check(s.ruins.chests.any(func(chest): return chest.items.any(func(item): return str(item.kind)=="storm_feather")),"Storm Roc keeps its original feather")
		check(s.ruins.chests.any(func(chest): return chest.items.any(func(item): return str(item.kind)=="thunder_coffin_nail")),"Storm Roc leaves its new coffin nail")
		check(s.raid.wild_seals.size()==2 and s.raid.map_boss_defeats.size()==2,"Two optional victories survive day change")
	s.enemies.clear()
	s.expedition.prepare_day(s,3)
	var queen := raid_boss(s)
	check(not queen.is_empty() and not queen.get("wild_boss",false),"Original Blood Queen remains the day-three boss")
	if not queen.is_empty():
		queen.hp=0
		s.simulate(0.01)
	var moon := raid_boss(s)
	check(not moon.is_empty() and moon.get("final_form",false),"Original Blood Moon phase remains intact")
	if not moon.is_empty():
		moon.hp=0
		s.simulate(0.01)
	var abyss := raid_boss(s)
	check(not abyss.is_empty() and abyss.get("abyss_final",false),"Two optional victories unlock the added secret final boss")
	if not abyss.is_empty():
		var player: Dictionary=s.players[1]
		player.p=abyss.p+Vector2(190,0)
		s.raid.hazards.clear()
		s.wild_bosses.cast(s,abyss,player,"black_tide",Vector2.RIGHT)
		check(s.raid.hazards.size()==3,"Leviathan has three rotating tide walls")
		check(s.raid.hazards[0].aim!=s.raid.hazards[1].aim,"Successive gaps change direction")
		check(Presentation.cue({"action":"phase","wild_boss":true,"wild_kind":2,"boss_kind":2})=="abyss-ritual","Leviathan has its own sound bank")
		abyss.hp=0
		s.simulate(0.01)
	check(s.raid.phase=="complete","Secret final boss clears expedition")
	check(s.ruins.chests.any(func(chest): return chest.items.any(func(item): return str(item.kind)=="abyssal_motherheart")),"Leviathan leaves its red 3x3 collectible")
	check(s.ruins.chests.any(func(chest): return chest.items.any(func(item): return str(item.kind)=="abyss_shedding")),"Leviathan keeps its original serpent shed")
	for chest in s.ruins.chests:
		if str(chest.get("title","")).contains("海母遗珍"):
			check(chest.items.any(func(item): return str(item.kind)=="abyssal_motherheart") and chest.items.any(func(item): return str(item.kind)=="abyss_shedding"),"Leviathan's own chest holds both relics")
	for cue in ["earth","storm","abyss"]:
		var stream: AudioStreamOggVorbis=load("res://assets/audio/music/%s.ogg" % cue)
		check(stream!=null and stream.get_length()>60,"New boss music imports: "+cue)
	for image_name in ["earthsplitter","storm-roc-v2","moon-leviathan"]:
		check(load("res://assets/bosses/wild/%s.png" % image_name)!=null,"New non-humanoid art imports: "+image_name)
	print("wild_bosses: ",checks," checks, ",failures," failures")
	quit(1 if failures>0 else 0)
