extends SceneTree

var session: TideSession
var p2p: TideP2P
var role := ""
var age := 0.0
var reported := false
var expected := 2
var expected_server := false
var fallback_after_connect := false
var fallback_triggered := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := {}
	for item in OS.get_cmdline_user_args():
		var text := str(item)
		if text.begins_with("--") and text.contains("="):
			var pair := text.substr(2).split("=",false,1)
			args[pair[0]]=pair[1]
	role=str(args.get("role",""))
	expected=int(args.get("expected","2"))
	expected_server=str(args.get("expected_mode","DIRECT"))=="SERVER"
	fallback_after_connect=str(args.get("fallback_after_connect",""))=="1"
	var game := Node.new()
	game.name="CrimsonTide"
	root.add_child(game)
	var api := OnlineService.new()
	game.add_child(api)
	api.api_url=str(args.get("api",""))
	session=TideSession.new()
	session.name="Session"
	game.add_child(session)
	p2p=TideP2P.new()
	game.add_child(p2p)
	p2p.setup(api,session)
	p2p.status.connect(func(message: String): print("P2P STATUS ",role,": ",message))
	var config := {"name":"Host" if role=="host" else "Guest","hero":0}
	var reply: Dictionary
	if role=="host":
		reply=await p2p.create_room(config)
	else:
		reply=await p2p.join_room(str(args.get("code","")),config)
	if not reply.ok:
		push_error("P2P setup: "+str(reply.get("error","unknown")))
		quit(1)
		return
	if role=="guest" and str(args.get("force_public",""))=="1":
		p2p.local_ips.clear()
	if role=="guest" and str(args.get("force_fallback",""))=="1":
		p2p.fallback_to_server()
	if role=="host":
		var file := FileAccess.open(str(args.get("code_file","")),FileAccess.WRITE)
		if file:
			file.store_string(str(reply.code))
			file.close()
	print("P2P ROOM ",reply.code)

func _process(dt: float) -> bool:
	age+=dt
	if age>30.0:
		push_error("P2P timeout: "+role+" stage "+p2p.stage)
		quit(1)
	if (fallback_after_connect and not fallback_triggered and session and session.online
			and session.players.size()==expected and not session.server_room):
		fallback_triggered=true
		p2p.fallback_to_server()
	if (not reported and session and session.players.size()==expected and session.online
			and session.server_room==expected_server):
		reported=true
		print("P2P ",role.to_upper()," MODE ","SERVER" if session.server_room else "DIRECT"," PASS")
		await create_timer(0.6).timeout
		quit(0)
	return false
