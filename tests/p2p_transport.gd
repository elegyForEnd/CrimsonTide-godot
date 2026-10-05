extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures := 0
	var txid := PackedByteArray()
	txid.resize(12)
	var port := 4567 ^ 0x2112
	var reply := PackedByteArray([1,1,0,12,0x21,0x12,0xA4,0x42])
	reply.append_array(txid)
	reply.append_array(PackedByteArray([0,0x20,0,8,0,1,port>>8,port&255,
		127^0x21,0^0x12,0^0xA4,1^0x42]))
	var endpoint := TideP2P.parse_stun_response(reply,txid)
	if endpoint.get("host","")!="127.0.0.1" or int(endpoint.get("port",0))!=4567:
		failures+=1
		push_error("STUN XOR-MAPPED-ADDRESS decoding failed")
	if not TideP2P.parse_stun_response(reply,PackedByteArray([1,0,0,0,0,0,0,0,0,0,0,0])).is_empty():
		failures+=1
		push_error("STUN transaction mismatch was accepted")
	if load("res://scripts/main.gd")==null:
		failures+=1
		push_error("Main UI script failed to load")
	print("P2P TRANSPORT: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
