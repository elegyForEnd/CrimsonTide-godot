class_name TideP2P
extends Node

# HTTPS carries authenticated room signalling. RFC 8489 Binding requests and
# punch packets leave the same UDP port that ENet will use for the game.
signal status(text: String)

var api: OnlineService
var session: TideSession
var code := ""
var role := ""
var stage := "idle"
var config: Dictionary = {}
var ticket := ""
var transaction := ""
var stun_host := ""
var stun_port := 0
var udp: PacketPeerUDP
var local_port := 0
var local_ips: Array = []
var guests: Array = []
var candidates: Array = []
var attempt_index := 0
var elapsed := 0.0
var poll_timer := 0.0
var stun_timer := 0.0
var punch_timer := 0.0
var poll_busy := false
var fallback_busy := false
var server_ticket: Dictionary = {}
var switch_wait := 0.0

func setup(service: OnlineService, game: TideSession) -> void:
	api=service
	session=game
	session.p2p_connect_failed.connect(_attempt_failed)
	session.changed.connect(_session_changed)
	session.started.connect(_game_started)

func active() -> bool:
	return not code.is_empty()

func _process(dt: float) -> void:
	if not active(): return
	elapsed+=dt
	if stage in ["host","probing","connecting"]:
		stun_timer-=dt
		if stun_timer<=0:
			stun_timer=2.0
			send_stun()
	if udp:
		while udp.get_available_packet_count()>0:
			var reply := parse_stun_response(udp.get_packet(),transaction.hex_decode())
			if not reply.is_empty():
				# The signalling service separately reports the observed endpoint.
				# Parsing the response also confirms that its STUN implementation
				# and our RFC 8489 transaction ID agree.
				break
	if role=="host" and stage=="host":
		punch_timer-=dt
		if punch_timer<=0:
			punch_timer=0.3
			punch_guests()
	if stage=="probing" and elapsed>12.0:
		fallback_to_server()
	if stage=="awaiting_switch":
		switch_wait+=dt
		if switch_wait>6.0: fallback_to_server()
	if stage in ["host","probing","connecting","connected","playing","awaiting_switch","waiting_server","server"]:
		poll_timer-=dt
		if poll_timer<=0 and not poll_busy:
			poll_timer=1.0
			poll_room()

func create_room(loadout: Dictionary) -> Dictionary:
	stop(true)
	var auth := await api.ensure_session()
	if not auth.ok: return auth
	var err := session.host(loadout)
	if err!=OK: return {"ok":false,"error":"无法监听 UDP 24872。"}
	var reply := await api.request("/v1/p2p/rooms",HTTPClient.METHOD_POST)
	if not reply.ok:
		session.disconnect_room()
		return reply
	code=str(reply.code)
	role="host"
	stage="host"
	config=loadout.duplicate(true)
	ticket=str(reply.ticket)
	transaction=str(reply.transaction)
	stun_host=str(reply.stun_host)
	stun_port=int(reply.stun_port)
	local_port=TideSession.PORT
	local_ips=private_addresses()
	if stun_host in ["127.0.0.1","localhost"] and local_ips.size()<8: local_ips.append("127.0.0.1")
	session.room_code=code
	session.p2p_room_code=code
	session.changed.emit()
	publish_candidate()
	send_stun()
	return {"ok":true,"code":code}

func join_room(room_code: String, loadout: Dictionary) -> Dictionary:
	stop(true)
	var auth := await api.ensure_session()
	if not auth.ok: return auth
	var reply := await api.request("/v1/p2p/rooms/"+room_code+"/join",HTTPClient.METHOD_POST)
	if not reply.ok: return reply
	udp=PacketPeerUDP.new()
	var err := udp.bind(0,"0.0.0.0")
	if err!=OK:
		udp=null
		return {"ok":false,"error":"无法分配用于 NAT 打洞的 UDP 端口。"}
	code=str(reply.code)
	role="guest"
	stage="probing"
	config=loadout.duplicate(true)
	ticket=str(reply.ticket)
	transaction=str(reply.transaction)
	stun_host=str(reply.stun_host)
	stun_port=int(reply.stun_port)
	local_port=udp.get_local_port()
	local_ips=private_addresses()
	if stun_host in ["127.0.0.1","localhost"] and local_ips.size()<8: local_ips.append("127.0.0.1")
	var published := await api.request("/v1/p2p/rooms/"+code+"/candidate",
		HTTPClient.METHOD_PUT,{"local_port":local_port,"local_ips":local_ips})
	if not published.ok:
		stop(false)
		return published
	send_stun()
	return {"ok":true,"code":code}

func publish_candidate() -> void:
	if not active(): return
	var reply := await api.request("/v1/p2p/rooms/"+code+"/candidate",
		HTTPClient.METHOD_PUT,{"local_port":local_port,"local_ips":local_ips})
	if not reply.ok: status.emit(str(reply.get("error","无法公布本地网络地址。")))

func send_stun() -> void:
	if transaction.length()!=24 or stun_port<=0: return
	var packet := PackedByteArray([0,1,0,0,0x21,0x12,0xA4,0x42])
	packet.append_array(transaction.hex_decode())
	if role=="host" and session.online and session.authority() and stage in ["host","playing"]:
		var peer := session.multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if peer: peer.host.socket_send(stun_host,stun_port,packet)
	elif udp:
		if udp.set_dest_address(stun_host,stun_port)==OK:
			udp.put_packet(packet)

static func parse_stun_response(packet: PackedByteArray, txid: PackedByteArray) -> Dictionary:
	if packet.size()<32 or txid.size()!=12 or packet[0]!=1 or packet[1]!=1:
		return {}
	if packet.slice(4,8)!=PackedByteArray([0x21,0x12,0xA4,0x42]) or packet.slice(8,20)!=txid:
		return {}
	var size := (int(packet[2])<<8)+int(packet[3])
	if size%4!=0 or size+20>packet.size(): return {}
	var offset := 20
	while offset+4<=20+size:
		var kind := (int(packet[offset])<<8)+int(packet[offset+1])
		var length := (int(packet[offset+2])<<8)+int(packet[offset+3])
		if offset+4+length>packet.size(): return {}
		if kind==0x0020 and length>=8 and packet[offset+5]==1:
			var port := ((int(packet[offset+6])<<8)+int(packet[offset+7])) ^ 0x2112
			var address := "%d.%d.%d.%d" % [packet[offset+8]^0x21,packet[offset+9]^0x12,
				packet[offset+10]^0xA4,packet[offset+11]^0x42]
			return {"host":address,"port":port}
		offset+=4+int(ceil(float(length)/4.0))*4
	return {}

func poll_room() -> void:
	if not active(): return
	poll_busy=true
	var current := code
	var reply := await api.request("/v1/p2p/rooms/"+current)
	poll_busy=false
	if current!=code: return
	if not reply.ok:
		if elapsed>12.0 and stage in ["probing","connecting"]:
			fallback_to_server()
		elif stage=="awaiting_switch":
			stop(false)
			status.emit("P2P 房主已退出房间。")
		return
	if str(reply.mode)=="server":
		if bool(reply.get("server_failed",false)):
			stage="failed"
			status.emit("专用服务器房间已退出，请重新创建房间。")
			return
		if stage not in ["waiting_server","server","switching"]:
			fallback_to_server()
		elif stage=="waiting_server" and (role=="host" or bool(reply.get("server_ready",false))):
			join_dedicated()
		return
	if role=="host":
		guests=reply.get("guests",[])
		for guest in guests:
			session.p2p_tickets[str(guest.get("ticket_hash",""))]=true
	elif stage=="probing" and bool(reply.get("host_ready",false)):
		var owner: Dictionary=reply.get("owner",{})
		prepare_candidates(owner)

func prepare_candidates(owner: Dictionary) -> void:
	var choices: Array=[]
	var port := int(owner.get("local_port",0))
	if port>0:
		for address in owner.get("local_ips",[]):
			for mine in local_ips:
				if same_subnet(str(address),str(mine)):
					choices.append({"host":str(address),"port":port,"lan":true})
					break
	var endpoint = owner.get("endpoint",null)
	if endpoint is Dictionary and int(endpoint.get("port",0))>0:
		choices.append({"host":str(endpoint.host),"port":int(endpoint.port),"lan":false})
	if choices.is_empty(): return
	candidates=choices
	attempt_index=0
	begin_attempt()

func begin_attempt() -> void:
	if stage in ["switching","waiting_server","server"]: return
	if attempt_index>=candidates.size():
		fallback_to_server()
		return
	if udp:
		for target in candidates:
			if udp.set_dest_address(str(target.host),int(target.port))==OK:
				for n in 3: udp.put_packet("CT-PUNCH".to_utf8_buffer())
		udp.close()
		udp=null
	var target: Dictionary=candidates[attempt_index]
	var payload := config.duplicate(true)
	payload["_p2p_ticket"]=ticket
	var err := session.join(str(target.host),payload,int(target.port),local_port,true)
	if err!=OK:
		attempt_index+=1
		call_deferred("begin_attempt")
		return
	session.room_code=code
	session.p2p_room_code=code
	session.connect_deadline=Time.get_ticks_msec()+(3000 if bool(target.lan) else 8000)
	stage="connecting"
	status.emit("正在尝试 P2P %s连接…" % ("局域网" if bool(target.lan) else "公网"))

func _attempt_failed() -> void:
	if stage!="connecting": return
	attempt_index+=1
	call_deferred("begin_attempt")

func _session_changed() -> void:
	if not active(): return
	if role=="guest" and stage=="connecting" and session.online and session.players.has(session.my_id()):
		stage="connected"
		status.emit("P2P 直连成功")
	elif role=="guest" and stage=="connected" and not session.online:
		stage="awaiting_switch"
		switch_wait=0.0
	elif stage in ["host","playing"] and not session.online:
		stop(true)
	elif stage=="server" and session.server_room and session.players.has(session.my_id()):
		stop(false)

func punch_guests() -> void:
	if not session.online or not session.authority(): return
	var peer := session.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not peer: return
	for guest in guests:
		var endpoint = guest.get("endpoint",null)
		if endpoint is Dictionary and int(endpoint.get("port",0))>0:
			peer.host.socket_send(str(endpoint.host),int(endpoint.port),"CT-PUNCH".to_utf8_buffer())
		var port := int(guest.get("local_port",0))
		if port<=0: continue
		for address in guest.get("local_ips",[]):
			for mine in local_ips:
				if same_subnet(str(address),str(mine)):
					peer.host.socket_send(str(address),port,"CT-PUNCH".to_utf8_buffer())
					break

func fallback_to_server() -> void:
	if fallback_busy or stage in ["playing","waiting_server","server","switching"]: return
	fallback_busy=true
	stage="switching"
	status.emit("P2P 打洞未成功，正在切换专用服务器…")
	if udp:
		udp.close()
		udp=null
	var current := code
	var reply := await api.request("/v1/p2p/rooms/"+current+"/fallback",HTTPClient.METHOD_POST)
	fallback_busy=false
	if current!=code: return
	if not reply.ok:
		stage="failed"
		status.emit(str(reply.get("error","专用服务器不可用。")))
		return
	server_ticket=reply
	stage="waiting_server"
	if role=="host": join_dedicated()

func join_dedicated() -> void:
	if stage!="waiting_server": return
	stage="server"
	var err := session.join_server(server_ticket,config)
	if err!=OK:
		stage="failed"
		status.emit("专用服务器连接失败。")
	else:
		status.emit("正在连接专用服务器房间 "+code+"…")

func _game_started() -> void:
	if not active() or stage not in ["host","connected","playing"]: return
	stage="playing"
	if role=="host":
		var reply := await api.request("/v1/p2p/rooms/"+code+"/started",HTTPClient.METHOD_POST)
		if not reply.ok: status.emit("无法更新 P2P 房间出发状态。")

func stop(close_room: bool = true) -> void:
	var old_code := code
	var old_role := role
	var old_stage := stage
	code=""
	role=""
	stage="idle"
	guests.clear()
	candidates.clear()
	server_ticket.clear()
	if udp:
		udp.close()
		udp=null
	if close_room and old_role=="host" and old_stage in ["host","playing","connected"]:
		api.request("/v1/p2p/rooms/"+old_code+"/close",HTTPClient.METHOD_POST)
	elif close_room and old_role=="guest" and old_stage in ["probing","connecting","connected","playing","awaiting_switch"]:
		api.request("/v1/p2p/rooms/"+old_code+"/leave",HTTPClient.METHOD_POST)

static func private_addresses() -> Array:
	var addresses: Array=[]
	for value in IP.get_local_addresses():
		var address := str(value)
		if not private_ipv4(address) or address in addresses: continue
		addresses.append(address)
		if addresses.size()>=8: break
	return addresses

static func private_ipv4(address: String) -> bool:
	var parts := address.split(".")
	if parts.size()!=4: return false
	for part in parts:
		if not part.is_valid_int() or int(part)<0 or int(part)>255: return false
	return parts[0]=="10" or (parts[0]=="192" and parts[1]=="168") or (parts[0]=="172" and int(parts[1])>=16 and int(parts[1])<=31)

static func same_subnet(a: String, b: String) -> bool:
	var left := a.split(".")
	var right := b.split(".")
	return left.size()==4 and right.size()==4 and left[0]==right[0] and left[1]==right[1] and left[2]==right[2]
