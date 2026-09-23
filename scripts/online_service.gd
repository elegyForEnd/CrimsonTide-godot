class_name OnlineService
extends Node

signal status(text: String)
var api_url := "https://example.com"
var timeout := 12.0
var token := ""
var account_id := ""
var account_name := "游客"
var guest := true
var syncing := false
var revision := 0
var dirty := false
var busy := false
var retry_in := 0.0
var profile: Profile

func _ready() -> void:
	var cfg := ConfigFile.new()
	var location := "res://game.cfg" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("game.cfg")
	if cfg.load(location)!=OK:
		cfg.load("res://game.cfg")
	api_url=str(cfg.get_value("server","api_url",api_url)).trim_suffix("/")
	timeout=clampf(float(cfg.get_value("server","request_timeout",12.0)),1.0,60.0)

func request(route: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}) -> Dictionary:
	# Only permit plaintext HTTP for a local development service.
	if not api_url.begins_with("https://") and not (api_url.begins_with("http://127.0.0.1:") or api_url.begins_with("http://localhost:")):
		return {"ok":false,"error":"服务器地址必须使用 HTTPS（本机测试除外）。"}
	var http := HTTPRequest.new()
	http.timeout=timeout
	http.body_size_limit=1048576
	http.max_redirects=0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty(): headers.append("Authorization: Bearer "+token)
	var err := http.request(api_url+route,headers,method,JSON.stringify(body) if method!=HTTPClient.METHOD_GET else "")
	if err!=OK:
		http.queue_free()
		return {"ok":false,"error":"无法发起网络请求。"}
	var result: Array = await http.request_completed
	http.queue_free()
	var parsed = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if result[0]!=HTTPRequest.RESULT_SUCCESS or not parsed is Dictionary:
		return {"ok":false,"error":"服务器不可用，进度仍保存在本机。"}
	parsed["ok"]=int(result[1])>=200 and int(result[1])<300
	parsed["http_status"]=int(result[1])
	return parsed

func authenticate(username: String, password: String, register_account: bool) -> Dictionary:
	var reply := await request("/v1/auth/"+("register" if register_account else "login"),HTTPClient.METHOD_POST,{"username":username,"password":password})
	if reply.ok:
		token=reply.token
		account_id=reply.user.id
		account_name=reply.user.username
		guest=false
	return reply

func ensure_session() -> Dictionary:
	if not token.is_empty(): return {"ok":true}
	var reply := await request("/v1/auth/guest",HTTPClient.METHOD_POST)
	if reply.ok: token=reply.token
	return reply

func watch(value: Profile) -> void:
	profile=value
	profile.saved.connect(func(): dirty=true; retry_in=1.5)

func _process(dt: float) -> void:
	retry_in-=dt
	if syncing and dirty and not busy and retry_in<=0:
		upload()

func upload() -> Dictionary:
	if busy: return {"ok":false,"error":"正在同步，请稍候。"}
	busy=true
	var snapshot := profile.data.duplicate(true)
	var reply := await request("/v1/profile",HTTPClient.METHOD_PUT,{"revision":revision,"data":snapshot})
	busy=false
	if reply.ok:
		revision=int(reply.revision)
		dirty=JSON.stringify(snapshot)!=JSON.stringify(profile.data)
		status.emit("云端同步完成")
	else:
		retry_in=30.0
		if int(reply.get("http_status",0)) in [401,409]: syncing=false
		status.emit(str(reply.get("error","同步失败，本地存档已保留。")))
	return reply
