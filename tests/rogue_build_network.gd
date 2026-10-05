extends SceneTree
const Content = preload("res://scripts/rogue_content.gd")
const Build = preload("res://scripts/rogue_build.gd")
var s: TideSession
var authority_mode := false
var age := 0.0
var failures := 0
var checks := 0
var stage := 0
var requested := false
var client_completed := false
var expected := 2
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	authority_mode="--server" in OS.get_cmdline_user_args()
	expected=4 if "--four" in OS.get_cmdline_user_args() else 2
	s=TideSession.new(); s.name="Session"; root.add_child(s)
	s.finished.connect(done)
	var config := {"name":"Host" if authority_mode else "Client","hero":0 if authority_mode else 1,"mode":"roguelike"}
	var error: Error=s.host(config) if authority_mode else s.join("127.0.0.1",config)
	check(error==OK,"ENet connection starts")
func claim(p: Dictionary) -> void:
	if p.rogue_selection.is_empty(): return
	s.action("rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
func _process(dt: float) -> bool:
	age+=dt
	if age>35: check(false,"Network timeout at stage%d" % stage); quit(1); return false
	if not s.running:
		if authority_mode and stage==0 and s.players.size()==expected:
			for p in s.players.values():
				if not p.ready: return false
			check(s.launch(false,991),"Host launches all peers")
			claim(s.players[1]); stage=1
		elif not authority_mode and not s.players.is_empty() and not s.players.get(s.my_id(),{}).get("ready",false):
			s.configure({"name":"Client","hero":1,"ready":true,"mode":"roguelike"})
		return false
	var p: Dictionary=s.players[s.my_id()]
	if not authority_mode:
		if s.raid.phase=="rogue_prepare" and not p.rogue_selection.is_empty():
			claim(p)
		elif s.raid.get("build_net_stage",0)==1 and not client_completed:
			check(p.build_version==3 and p.flask==100,"Build version and flask snapshot")
			check(int(p.weapon)>=600 and p.equipped.weapon.build_id.begins_with("W"),"New weapon ID replicated")
			check(Build.attributes(p).intelligence==21,"Hero initial attributes replicated")
			check(p.build_level==2 and p.build_xp==0 and p.build_attribute_points==2,"Shared XP level and earned attribute points replicated")
			check(p.build_forge_level==3 and p.build_forge_bound==p.equipped.weapon.instance_id,"Forge item binding replicated")
			s.action("rogue_build",{"verb":"core","id":"WC010","version":p.rogue_inventory_revision-1})
			s.action("rogue_build",{"verb":"core","id":"WC010","version":p.rogue_inventory_revision})
			client_completed=true
		elif s.raid.get("build_net_stage",0)==2 and stage<2:
			check(p.build_core=="WC010","Client core intent validated by host")
			check(p.build_talents.get("T049",0)==1,"Run talents replicated")
			s.action("heal"); s.action("jump"); stage=2
		elif s.raid.get("build_net_stage",0)==3 and stage<3 and p.flask_time<=0 and p.jump_cd<=0:
			check(p.flask==75,"Committed flask capacity replicated")
			s.action("jump"); stage=3
		elif s.raid.get("build_net_stage",0)==4 and stage<4:
			check(p.height>0,"Aerial state replicated")
			s.action("dash"); stage=4
		elif s.raid.get("build_net_stage",0)==5 and stage<5:
			check(p.air_dodge and p.dash>0,"Air dodge state and shared cooldown replicated")
			s.action("rogue_loot"); stage=5
		elif s.raid.get("build_net_stage",0)==6 and not p.rogue_selection.is_empty(): claim(p)
		return false
	if stage==1:
		if s.raid.phase!="rogue_combat": return false
		s.raid.phase="rogue_exit"
		Build.enemy_experience(s,{"hp":0.0,"build_xp_reward":40})
		for actor in s.players.values():
			actor.invuln=999; actor.p=Vector2(330+30*stage,s.ruins.lane_center(330))
			s.roguelike.equip(s,actor,Content.make_weapon(36,2))
			actor.build_forge_level=3; actor.build_forge_bound=actor.equipped.weapon.instance_id
			actor.build_cultivation=3; actor.build_library=["T049"]
			Build.activate(s,actor,"T049",1)
			actor.hp=actor.max_hp*.3
		s.raid["build_net_stage"]=1; stage=2
	elif stage==2:
		for actor in s.players.values():
			if actor.id!=1 and actor.build_core!="WC010": return false
		check(true,"Remote core selection rejected stale then accepted current version")
		s.raid.phase="rogue_combat"; s.raid.build_net_stage=2; stage=3
	elif stage==3:
		for actor in s.players.values():
			if actor.id!=1 and actor.flask!=75: return false
		check(true,"Remote healing settled on authority")
		s.raid.build_net_stage=3; stage=4
	elif stage==4:
		for actor in s.players.values():
			if actor.id!=1 and actor.height<=0: return false
		check(true,"Remote jump settled on authority")
		s.raid.build_net_stage=4; stage=5
	elif stage==5:
		for actor in s.players.values():
			if actor.id!=1 and not actor.air_dodge: return false
		check(true,"Remote air dodge consumes host cooldown")
		s.enemies.clear(); s.raid.wave=3; s.roguelike.clear_room(s)
		for actor in s.players.values():
			actor.rogue_selection={}; actor.build_reward_queue=[]; actor.height=0; actor.dodge_time=0; actor.cast_time=0
		var opener: Dictionary=s.players[1]; opener.p=s.raid.reward_chest.p; s.perform(1,"rogue_loot"); s.elapsed+=2
		var drop: Dictionary=s.raid.reward_drops[0]
		var selection_payload := {"id":-1,"version":0,"index":0}
		opener.p=drop.p; s.perform(1,"rogue_loot")
		selection_payload.id=opener.rogue_selection.id
		s.perform(1,"rogue_selection_drop",selection_payload)
		var shared: Dictionary=s.raid.reward_drops.back()
		for actor in s.players.values():
			if actor.id!=1: actor.p=shared.p; break
		s.raid.build_net_stage=5; stage=6
	elif stage==6:
		var found := false
		for actor in s.players.values():
			if actor.id!=1 and actor.equipped.weapon.get("build_id","")!="W037": found=true
			if actor.id!=1 and not actor.rogue_selection.is_empty(): s.raid.build_net_stage=6
		if not found: return false
		check(true,"Shared newly painted weapon claimed through network")
		for actor in s.players.values(): actor.status="extracted"
		s.roguelike.settle(s); stage=7
	return false
func done() -> void:
	check(s.results.size()==expected and s.results.has(s.my_id()),"All peers receive results")
	print("BUILD NETWORK %s: %d checks, %d failures" % ["HOST" if authority_mode else "CLIENT",checks,failures])
	await create_timer(.5).timeout
	quit(1 if failures>0 else 0)
