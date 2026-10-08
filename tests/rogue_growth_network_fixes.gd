extends SceneTree
const Growth = preload("res://scripts/rogue_growth.gd")
const Build = preload("res://scripts/rogue_build.gd")
const PORT := 24931
var s: TideSession
var server := false
var stage := 0
var age := 0.0
var checks := 0
var failures := 0
var account := {"ashes":100,"growth":{}}
var config: Dictionary
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func run() -> void:
	server="--server" in OS.get_cmdline_user_args()
	s=TideSession.new(); s.name="Session"; root.add_child(s)
	var tree := {"coin_purse":2,"hunt_instinct":2} if server else {"coin_purse":1,"scholar":3,"ash_vein":1}
	config={"name":"Host" if server else "Client","hero":0,"mode":"roguelike","rogue_growth":tree,"ready":true}
	account.growth=tree; s.set_meta("profile_data",account); s.finished.connect(done)
	if server:
		s.solo(config)
		var peer := ENetMultiplayerPeer.new()
		check(peer.create_server(PORT,3)==OK,"Server listens")
		s.multiplayer.multiplayer_peer=peer; s.online=true
	else: check(s.join("127.0.0.1",config,PORT)==OK,"Client connects")
func _process(dt: float) -> bool:
	age+=dt
	if age>25: check(false,"Network timeout stage "+str(stage)); quit(1); return false
	if not s.running:
		if server and stage==0 and s.players.size()==2:
			for p in s.players.values():
				if not p.ready: return false
			check(s.launch(false,9181),"Authority launches with per-player trees")
			s.raid.phase="rogue_exit"; s.raid.variant=""
			for p in s.players.values():
				p.rogue_selection={}; p.build_reward_queue=[]; p.build_attribute_points=1
			check(s.players[1].rogue_gold==110,"Host gets own +50 coins")
			for p in s.players.values():
				if p.id!=1:
					check(p.rogue_gold==85,"Client gets own +25 coins")
					check(s.rogue_mods(p).player_damage==0,"Host damage growth doesn't leak to client")
				s.raid.growth_net_stage=1; stage=1
		elif not server and stage==0 and not s.players.is_empty():
			if not s.players.get(s.my_id(),{}).get("ready",false): s.configure(config)
		return false
	if not server and stage==0 and s.raid.get("growth_net_stage",0)==1:
		var p: Dictionary=s.players[s.my_id()]
		check(p.rogue_gold==85 and p.rogue_growth.get("scholar",0)==3,"Snapshot carries client growth and gold")
		check(is_equal_approx(s.rogue_mods(p).xp_gain,.3),"Client reads same personal growth as authority")
		s.action("rogue_build",{"verb":"attribute","id":"mind","version":p.rogue_inventory_revision}); stage=1
	if server and stage==1:
		var remote: Dictionary={}
		for p in s.players.values():
			if p.id!=1: remote=p
		if remote.build_attributes.get("mind",0)!=1: return false
		check(true,"Client input round trip settled on authority")
		s.enemies.clear(); s.raid.cleared=2; s.raid.floor=1
		for p in s.players.values():
			p.status="extracted"
			s.roguelike.apply_room_delta(s,p,{"ash":30 if p.id==1 else 50})
		stage=2; s.roguelike.settle(s)
	return false
func done() -> void:
	var own: Dictionary=s.results.get(s.my_id(),{})
	check(not own.is_empty() and own.has("ashes"),"Reliable settlement includes personal ash amount")
	if server:
		check(own.ashes==234,"Host base plus room ash")
		check(account.ashes==334,"Host bank credited only own reward")
	else:
		check(own.ashes==274,"Client personal ash bonus plus room ash")
		check(account.ashes==100,"Authority does not mutate remote local account")
		check(s.players[s.my_id()].rogue_ash_run==274,"Client final roster matches payout")
	print("GROWTH NETWORK FIXES %s: %d checks, %d failures" % ["HOST" if server else "CLIENT",checks,failures])
	await create_timer(.5).timeout
	quit(1 if failures else 0)
