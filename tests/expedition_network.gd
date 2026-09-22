extends SceneTree
var s: TideSession
var server := false
var age := 0.0
var stage := 0
var client_saw_boss := false
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	server="--server" in OS.get_cmdline_user_args()
	s=TideSession.new()
	s.name="Session"
	root.add_child(s)
	s.finished.connect(done)
	var err: Error=s.host({"hero":0}) if server else s.join("127.0.0.1",{"hero":1,"ready":true})
	if err!=OK: quit(1)
func _process(dt: float) -> bool:
	age+=dt
	if age>18:
		push_error("EXPEDITION NETWORK timeout stage %d" % stage)
		quit(1)
	if not s: return false
	if server:
		if stage==0 and s.players.size()==2:
			for p in s.players.values(): p.ready=true
			s.launch(false,472)
			s.enemies.clear()
			s.expedition.prepare_day(s,2)
			s.raid.time=s.duration
			s.expedition.spawn_boss(s)
			for p in s.players.values():
				p.p=s.safe_center()+Vector2(140,0)
				p.invuln=100
			s.enemies.back().cd=0
			stage=1
		elif stage==1 and age>3:
			s.enemies.back().hp=0
			stage=2
		elif stage==2 and s.raid.phase=="choice":
			s.action("raid_choice",{"choice":"continue"})
			stage=3
		elif stage==3 and s.raid.day==3:
			if s.raid.phase!="boss" or s.enemies.back().max_hp!=3600:
				push_error("Final encounter did not scale to remaining host")
				quit(1)
			stage=4
		elif stage==4 and age>6:
			s.enemies.back().hp=0
			stage=5
		elif stage==5 and s.raid.phase=="complete":
			s.action("raid_choice",{"choice":"extract"})
			stage=6
	elif s.running:
		if s.raid.day==2 and s.raid.phase=="boss" and not s.raid.hazards.is_empty():
			client_saw_boss=true
		if s.raid.phase=="choice" and stage==0:
			if not client_saw_boss:
				push_error("Client missed boss and hazard replication")
				quit(1)
			s.action("raid_choice",{"choice":"extract"})
			stage=1
	return false
func done() -> void:
	var valid := s.results.size()==2
	for r in s.results.values(): valid=valid and r.escaped
	if not server: valid=valid and client_saw_boss
	print("EXPEDITION NETWORK ","HOST" if server else "CLIENT"," PASS" if valid else " FAIL")
	# Give reliable results a frame to reach the other peer.
	await create_timer(0.5).timeout
	s.disconnect_room()
	quit(0 if valid else 1)
