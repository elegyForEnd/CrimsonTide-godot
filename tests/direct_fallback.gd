extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := TideSession.new()
	root.add_child(session)
	var state := {"failed":false}
	session.direct_connect_failed.connect(func(): state.failed=true)
	var err: Error=session.join("127.0.0.2",{"name":"Probe","hero":0})
	if err!=OK:
		push_error("Cannot start direct connection test")
		quit(1)
		return
	session.connect_deadline=Time.get_ticks_msec()-1
	await create_timer(0.2).timeout
	var passed: bool=state.failed and not session.online
	print("DIRECT FALLBACK: ","PASS" if passed else "FAIL")
	if not passed: push_error("Direct timeout did not raise the fallback signal")
	quit(0 if passed else 1)
