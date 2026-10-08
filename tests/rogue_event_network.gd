extends SceneTree
const Events = preload("res://scripts/rogue_events.gd")
var s: TideSession
var host_mode := false
var stage := 0
var age := 0.0
var failures := 0
var checks := 0
var peer_id := 0
var mirror_seen := false
var guest_start_x := 0.0
var victory_age := 0.0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	host_mode="--server" in OS.get_cmdline_user_args()
	s=TideSession.new(); s.name="Session"; root.add_child(s)
	var error: Error=s.host({"name":"Host","hero":0,"mode":"roguelike"}) if host_mode else s.join("127.0.0.1",{"name":"Guest","hero":1,"mode":"roguelike"})
	check(error==OK,"ENet opens")

func done() -> void:
	print("ROGUE EVENT NETWORK %s: %d checks, %d failures" % ["HOST" if host_mode else "CLIENT",checks,failures])
	s.disconnect_room()
	quit(1 if failures else 0)

func _process(dt: float) -> bool:
	age+=dt
	if age>25: check(false,"Event network timeout stage %d" % stage); done(); return false
	if not s.running:
		if not host_mode and not s.players.is_empty() and not s.players.get(s.my_id(),{}).get("ready",false):
			s.configure({"name":"Guest","hero":1,"mode":"roguelike","ready":true})
		if host_mode and stage==0 and s.players.size()==2:
			for p in s.players.values():
				if not p.ready: return false
			check(s.launch(false,171717),"Online launch")
			s.enemies.clear()
			for p in s.players.values():
				p.rogue_selection={}; p.build_reward_queue=[]; p.invuln=999.0
				p.rogue_gold=100; p.rogue_curses=[]
				if int(p.id)!=1: peer_id=int(p.id)
			s.raid.room="event"; s.raid.phase="rogue_exit"
			s.raid.pending_event={"id":"EV02","offer":Events.options_view(Events.find("EV02")),"revision":s.raid.revision}
			s.raid["event_net_stage"]=1
			stage=1
		return false
	if host_mode:
		var guest: Dictionary=s.players[peer_id]
		if stage==1 and s.raid.pending_event.is_empty():
			check(guest.rogue_gold==115,"Client choice pays exact event reward on authority")
			check(s.players[1].rogue_gold==100,"Event reward goes only to chooser")
			s.raid.room="mirror"; s.raid.mirror_state={}
			s.raid["event_net_stage"]=2; s.raid.revision+=1; stage=2
		elif stage==2 and s.raid.mirror_state.get("active",false):
			check(s.enemies.size()==1 and s.enemies[0].get("rogue_mirror",false),"Remote action creates enemy on host")
			check(int(s.raid.mirror_state.owner)==peer_id,"Mirror belongs to the requesting client")
			guest_start_x=float(guest.p.x)
			stage=3
		elif stage==3 and float(guest.p.x)>guest_start_x+20:
			var enemy: Dictionary=s.enemies[0]
			s.damage_enemy(enemy,99999,peer_id,Vector2.RIGHT,0)
			stage=4
		elif stage==4 and s.raid.mirror_state.get("settled",false):
			check(s.raid.mirror_state.win and guest.rogue_gold>115,"Host pays combat victory")
			s.raid["event_net_stage"]=3; stage=5
		elif stage==5:
			victory_age+=dt
			if victory_age>1.5: done()
	else:
		var p: Dictionary=s.players.get(s.my_id(),{})
		if p.is_empty(): return false
		var net_stage := int(s.raid.get("event_net_stage",0))
		if net_stage==1 and stage==0:
			s.action("rogue_event",{"revision":s.raid.revision,"index":2}); stage=1
		elif net_stage==2 and stage==1:
			check(p.rogue_gold==115 and s.raid.pending_event.is_empty(),"Client receives event payout and cleared pending state")
			s.action("rogue_mirror",{"revision":s.raid.revision}); stage=2
		elif stage==2 and not mirror_seen and s.raid.mirror_state.get("active",false) and not s.enemies.is_empty():
			check(s.enemies[0].get("rogue_mirror",false) and s.enemies[0].hero==p.hero and s.enemies[0].weapon==p.weapon,"Mirror identity replicates")
			check(p.rogue_mirror_used,"Consumed challenge replicates")
			mirror_seen=true
			# Reuse an existing authoritative player action as acknowledgement: a harmless
			# movement packet lets the host know this snapshot was received.
			s.local_input={"move":Vector2.RIGHT,"aim":Vector2.RIGHT}
		elif net_stage==3 and stage==2:
			check(mirror_seen and s.raid.mirror_state.get("win",false),"Victory state replicates")
			check(p.rogue_gold>115 and p.rogue_ash_run>0 and not p.rogue_selection.is_empty(),"Currencies and gear selection replicate")
			done()
	return false
