extends SceneTree

var session: TideSession
var folder := ""
var age := 0.0
var empty_age := 0.0
var tick := 0.0
var pending: Dictionary = {}

func _initialize() -> void:
	call_deferred("start_room")

func start_room() -> void:
	var port := 24900
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): port=int(arg.trim_prefix("--port="))
		if arg.begins_with("--room-dir="): folder=arg.trim_prefix("--room-dir=")
	if folder.is_empty():
		quit(1)
		return
	# RPC node paths must match the game scene: /root/CrimsonTide/Session.
	var game := Node.new()
	game.name="CrimsonTide"
	root.add_child(game)
	session=TideSession.new()
	session.name="Session"
	game.add_child(session)
	session.ticket_file=folder.path_join("tickets.json")
	if session.host_dedicated(port)!=OK:
		quit(1)
		return
	root.multiplayer.peer_connected.connect(func(id: int): pending[id]=Time.get_ticks_msec())
	root.multiplayer.peer_disconnected.connect(func(id: int): pending.erase(id))
	session.changed.connect(write_state)
	session.started.connect(write_state)
	session.finished.connect(write_state)
	write_state()

func write_state() -> void:
	var file := FileAccess.open(folder.path_join("state.tmp"),FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"players":session.players.size(),"running":session.running}))
		file.close()
		DirAccess.rename_absolute(folder.path_join("state.tmp"),folder.path_join("state.json"))

func _process(dt: float) -> bool:
	if session==null: return false
	age+=dt
	tick+=dt
	if tick>1.0:
		tick=0.0
		for id in pending.keys():
			if session.players.has(id): pending.erase(id)
			elif Time.get_ticks_msec()-int(pending[id])>10000:
				root.multiplayer.multiplayer_peer.disconnect_peer(id)
				pending.erase(id)
		write_state()
	# Empty rooms expire; active rooms have a six-hour absolute lifetime.
	var connected := false
	for player in session.players.values():
		connected=connected or bool(player.connected)
	empty_age=0.0 if connected else empty_age+dt
	if empty_age>90.0 or age>21600.0: quit()
	return false
