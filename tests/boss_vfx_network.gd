extends SceneTree
var s: TideSession
var host_mode := false
var age := 0.0
var launched := false
var stage := -1
var release_themes: Dictionary={}
var actions: Dictionary={}
var snapshots: Dictionary={}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	host_mode="--server" in OS.get_cmdline_user_args()
	s=TideSession.new()
	s.name="Session"
	root.add_child(s)
	s.combat_event.connect(func(data: Dictionary):
		if data.kind!="boss-vfx": return
		actions[data.action]=true
		if data.action=="release": release_themes[data.boss_kind]=true)
	var error: Error=s.host({"hero":0}) if host_mode else s.join("127.0.0.1",{"hero":1,"ready":true})
	if error!=OK: quit(1)

func _process(dt: float) -> bool:
	age+=dt
	if age>22:
		push_error("Boss VFX network timeout: releases %s, actions %s, snapshots %s" % [release_themes,actions,snapshots])
		quit(1)
	if not s: return false
	if host_mode:
		if not launched and s.players.size()==2:
			for p in s.players.values(): p.ready=true
			s.launch(false,1729)
			launched=true
			age=0
		if not launched: return false
		var next_stage := mini(3,int(age/3.0))
		if next_stage!=stage:
			stage=next_stage
			s.enemies.clear()
			s.raid.hazards=[]
			s.raid.phase="explore"
			s.raid.kind=mini(stage,2)
			if stage==3: s.spawn_enemy(s.raid.center,4)
			else: s.expedition.spawn_boss(s)
			var e: Dictionary=s.enemies.back()
			for p in s.players.values():
				p.p=e.p+Vector2(130,60)
				p.invuln=100
			if stage==3:
				s.BossTactics.start_guard(e,Vector2.RIGHT,s)
				s.BossTactics.update_guard(e,.4)
				s.BossTactics.absorb(s,e,100,2)
				e.stagger=0
				s.start_knight_attack(e,"combo",Vector2.RIGHT)
			else:
				s.expedition.cast_boss(s,e,s.players[1],["cross","feint","execution"][stage],Vector2.RIGHT,s.players[1].p)
			s.BossPresentation.send(s,e,"phase")
		if age>12.0 and not actions.has("fall"):
			s.BossPresentation.send(s,s.enemies.back(),"fall")
		if age>14:
			print("BOSS VFX NETWORK HOST PASS")
			s.disconnect_room()
			quit()
	elif s.running:
		for h in s.raid.hazards:
			if h.has("boss_kind") and h.has("move") and h.has("part") and h.has("source"):
				snapshots[h.boss_kind]=true
		if release_themes.size()==4 and snapshots.size()==3 and actions.has("charge") and actions.has("guard") and actions.has("break") and actions.has("phase") and actions.has("fall"):
			print("BOSS VFX NETWORK CLIENT PASS: four themes, timed releases, guard, break, phase, fall and hazard metadata")
			s.disconnect_room()
			quit()
	return false
