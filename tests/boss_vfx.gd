extends SceneTree
const P = preload("res://scripts/boss_presentation.gd")
var checks := 0
var failures := 0
var events: Array[Dictionary]=[]
var s: TideSession

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	s=TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	s.combat_event.connect(func(data: Dictionary):
		if data.kind=="boss-vfx": events.append(data.duplicate(true)))
	var p: Dictionary=s.players[1]
	p.invuln=999
	var pools := [["bell","marks","quick_bell","slow_bell","cross"],
		["spear","cleave","feint","fan","reap","counter"],
		["crown","lances","coronation","execution","eclipse"]]
	for kind in 3:
		for move in pools[kind]+["dodge","reload"]:
			s.enemies.clear()
			s.raid.hazards=[]
			s.raid.phase="explore"
			s.raid.kind=kind
			s.expedition.spawn_boss(s)
			var e: Dictionary=s.enemies.back()
			e.phase=3 if kind==2 else 2
			p.p=e.p+Vector2(110,0)
			events.clear()
			s.expedition.cast_boss(s,e,p,move,Vector2.RIGHT,p.p)
			check(events.size()==1 and events[0].action=="charge","One charge for "+move)
			var hazards: Array=s.raid.hazards.duplicate(true)
			for h in hazards:
				check(h.boss_kind==kind and h.move==move and h.source==e.id,"Source and theme persist in snapshot")
			# Jump across every strike in a single physics tick: no missing release.
			s.expedition.update_hazards(s,4.0)
			check(events.size()==hazards.size()+1,"All contacts publish exactly one VFX event: "+move)
			for event in events:
				check(ResourceLoader.exists("res://assets/audio/bosses/"+P.cue(event)+".wav"),"Playable matched audio: "+P.cue(event))
			s.expedition.update_hazards(s,.1)
			check(events.size()==hazards.size()+1,"No duplicate release during lingering VFX")
	for move in s.BossTactics.KNIGHT_MOVES:
		s.enemies.clear()
		s.spawn_enemy(s.raid.center,4)
		var e: Dictionary=s.enemies.back()
		e["presentation_seen"]=true
		events.clear()
		s.start_knight_attack(e,move,Vector2.RIGHT)
		s.update_knight(e,3)
		check(events.size()==s.BossTactics.KNIGHT_MOVES[move].marks.size()+1,"Knight multi-hit event count: "+move)
		for event in events:
			check(ResourceLoader.exists("res://assets/audio/bosses/"+P.cue(event)+".wav"),"Knight audio exists")
	var art = preload("res://scripts/boss_effect_art.gd")
	for key in art.KEYS:
		for role in art.ROLES:
			var texture: Texture2D=art.texture(key,role)
			check(not texture is AtlasTexture,"Boss uses whole independent image")
			check(texture.get_width()>=1024,"Native HD boss image")
			check(texture.get_image().detect_alpha()!=Image.ALPHA_NONE,"Original real transparency")
	print("BOSS VFX ",checks," checks, ",failures," failures")
	s.queue_free()
	quit(1 if failures else 0)
