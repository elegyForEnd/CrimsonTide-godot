extends SceneTree

var app: Node
var failures := 0
var test_path := ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, text: String) -> void:
	if not value:
		failures+=1
		push_error("ONLINE UI FAIL: "+text)

func press(text: String) -> void:
	for child in app.page.get_children():
		if child is Button and child.text==text and not child.disabled:
			child.pressed.emit()
			return
	check(false,"missing button "+text)

func idle() -> void:
	while app.online_ui_busy or app.online_service.busy:
		await process_frame
	await process_frame

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.online_service.api_url=OS.get_cmdline_user_args()[0]
	check(app.page_name=="account","first entry account gate")
	press("游客登录 · 离线也能玩")
	check(app.page_name=="title" and app.online_service.guest,"offline guest entry")
	app.show_account()
	await app.account_submit("ui_watcher","password123",true)
	check(app.page_name=="storage" and not app.online_service.guest,"register account and choose storage")
	test_path=app.profile.path
	app.profile.data.coins=555
	app.profile.save_profile()
	await app.inspect_cloud()
	press("上传本地 · 替换云端并同步")
	await idle()
	check(app.page_name=="title" and app.online_service.syncing,"initial cloud upload")
	app.profile.data.coins=777
	app.profile.save_profile()
	await create_timer(2.0).timeout
	await idle()
	var remote: Dictionary=await app.online_service.request("/v1/profile")
	check(int(remote.data.coins)==777,"save signal triggers auto upload")
	# Another device advances the cloud revision.
	var result: Dictionary=await app.online_service.request("/v1/profile",HTTPClient.METHOD_PUT,{"revision":int(remote.revision),"data":remote.data})
	check(result.ok,"second device upload")
	app.profile.data.coins=888
	app.profile.save_profile()
	await app.online_service.upload()
	check(not app.online_service.syncing and app.profile.data.coins==888,"conflict stops sync and preserves local")
	app.show_storage()
	await app.inspect_cloud()
	press("使用云端 · 替换本地并同步")
	check(app.profile.data.coins==777 and app.online_service.syncing,"download selected cloud")
	check(FileAccess.file_exists(test_path+".backup"),"download backs up local")
	app.show_storage()
	press("使用本地 · 进入游戏")
	check(not app.online_service.syncing,"local mode disables upload")
	app.show_server_rooms()
	await app.connect_server_room("",false)
	check(not app.session.online,"empty room code does not create a room")
	app.show_account()
	app.online_service.api_url="http://127.0.0.1:1"
	await app.account_submit("ui_watcher","password123",false)
	check(app.page_name=="account","server failure leaves guest path available")
	press("游客登录 · 离线也能玩")
	check(app.page_name=="title","offline fallback after server failure")
	DirAccess.remove_absolute(test_path)
	DirAccess.remove_absolute(test_path+".backup")
	print("ONLINE UI + CLOUD: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
