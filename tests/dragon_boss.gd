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

func dragon(s: TideSession) -> Dictionary:
	for e in s.enemies:
		if e.get("dragon_boss",false): return e
	return {}

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1741)
	s.set_physics_process(false)
	s.spawn_timer=9999
	check(dragon(s).is_empty(),"Dragon does not replace day-one guardians")
	s.enemies.clear()
	s.expedition.prepare_day(s,2)
	var e := dragon(s)
	check(not e.is_empty(),"Day two spawns the frostbone dragon")
	if not e.is_empty():
		var habitats: Array=[]
		for other in s.enemies:
			if other.get("mini_boss",false): habitats.append(int(other.habitat))
		check(habitats.size()==3 and habitats.size()==habitats.duplicate().size(),"Three optional bosses spawn on day two")
		check(habitats[0]!=habitats[1] and habitats[0]!=habitats[2] and habitats[1]!=habitats[2],"Dragon gets its own lair")
		var p: Dictionary=s.players[1]
		p.p=e.p+Vector2(180,0)
		s.raid.hazards.clear()
		s.dragon_boss.cast(s,e,p,"tail",Vector2.RIGHT)
		var tail: Dictionary=s.raid.hazards[0]
		check(tail.shape=="arc","Tail uses a dedicated annular arc hit shape")
		check(s.expedition.hazard_contains(tail,e.p+Vector2(-190,0)),"Tail hits behind the dragon")
		check(not s.expedition.hazard_contains(tail,e.p+Vector2(190,0)),"Tail leaves the front safe")
		check(not s.expedition.hazard_contains(tail,e.p),"Tail does not hit the inner safe area")
		s.raid.hazards.clear()
		s.dragon_boss.cast(s,e,p,"breath",Vector2.RIGHT)
		var pools := 0
		for h in s.raid.hazards:
			if h.has("pulse_interval"): pools+=1
		check(pools==3,"Breath deposits three lingering frost patches")
		var pool: Dictionary={}
		for h in s.raid.hazards:
			if h.has("pulse_interval"):
				pool=h
				break
		pool.fired=true
		pool.time=-0.10
		s.raid.hazards=[pool]
		s.expedition.update_hazards(s,0.70)
		check(float(pool.next_pulse)>0.75 and s.raid.hazards.has(pool),"Frost patch pulses after its first impact and remains active")
		e.hp=e.max_hp*0.45
		s.dragon_boss.update(s,e,0.01)
		check(int(e.phase)==2,"Dragon changes phase at half health")
		s.raid.hazards.clear()
		s.dragon_boss.cast(s,e,p,"breath",Vector2.RIGHT)
		check(s.raid.hazards.size()==8,"Second phase has four breath sweeps and four frost patches")
		check(Presentation.cue({"action":"release","dragon_boss":true,"boss_kind":3,"shape":"arc"})=="dragon-sweep","Dragon has its own sound bank")
		e.hp=0
		s.simulate(0.01)
		check(s.raid.get("dragon_slain",false),"Dragon defeat records a separate accomplishment")
		var reward := false
		for chest in s.ruins.chests:
			if str(chest.get("title","")).contains("龙巢遗珍"): reward=true
		check(reward,"Dragon drops a unique lair chest")
	var art: Texture2D=load("res://assets/bosses/dragon/frostbone-dragon.png")
	check(art!=null and art.get_width()>1000,"Dragon cutout art imports")
	var music: AudioStreamOggVorbis=load("res://assets/audio/music/dragon.ogg")
	check(music!=null and music.get_length()>60,"Dragon Suno BGM imports")
	print("dragon_boss: ",checks," checks, ",failures," failures")
	quit(1 if failures>0 else 0)
