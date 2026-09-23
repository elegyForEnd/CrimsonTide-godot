extends SceneTree

var session: TideSession
var host_mode := false
var stage := 0
var age := 0.0
var started_at := 0.0
var got_effect := false
var local_sent := false
var local_skilled := false
var saw_independent := false
var expected := 4
var saw_snapshot := false
var saw_pocket := false
var got_combat := false
var saw_weapon := false
var saw_running := false
var got_audio := false
var pickup_requested := false
var pickup_confirmed := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	host_mode="--server" in args
	if "--two" in args:
		expected=2
	session=TideSession.new()
	session.name="Session"
	root.add_child(session)
	session.effect.connect(func(_kind: String,_pos: Vector2): got_effect=true)
	session.combat_event.connect(func(data: Dictionary):
		if data.kind=="audio" and data.id!=session.my_id() and data.get("cue","")=="equip":
			got_audio=true
		if data.kind=="skill" and data.id!=session.my_id():
			got_combat=true
	)
	session.started.connect(func(): stage=2; started_at=age)
	session.finished.connect(done)
	var err: Error
	if host_mode:
		err=session.host({"name":"Host","hero":0})
	else:
		err=session.join("127.0.0.1",{"name":"Client","hero":1})
	if err!=OK:
		push_error("NETWORK setup failed")
		quit(1)
	stage=1

func _process(dt: float) -> bool:
	age+=dt
	if age>24:
		push_error("NETWORK timeout stage %d roster %d" % [stage,session.players.size()])
		quit(1)
	if stage==1:
		if host_mode and session.players.size()==expected:
			var all_ready := true
			for p in session.players.values():
				all_ready=all_ready and p.ready
			if all_ready:
				session.launch(false,54321)
				session.expedition.prepare_day(session,2)
				# A weapon can only be used after it has been found and equipped,
				# so every Watcher is handed one piece of field loot to put on.
				for p in session.players.values():
					# Fit the 2x2 test weapon and relic alongside the free medicine.
					p.backpack=Catalog.clean_container(p.backpack,Vector2i(4,4))
					p.backpack.key="green"
					Catalog.place_item(p.backpack,Catalog.make_equipment("weapon",2,2))
				session.enemies.clear()
				session.spawn_timer=999
				for p in session.players.values():
					p.p=session.ruins.exits[0]
					Catalog.add_item(p.backpack,"relic")
					Catalog.add_item(p.pocket,"scrap")
					if expected==2 and p.id!=1:
						for index in p.backpack.items.size():
							if p.backpack.items[index].kind=="relic":
								p.backpack.items.remove_at(index)
								break
						session.world_drops.append(session.ground_drop(p.p,"relic"))
				session.objectives=2
		elif not host_mode and session.players.has(session.my_id()) and not session.players[session.my_id()].ready:
			session.configure({"name":"Client","hero":1,"ready":true})
	if stage==2:
		var since_start := age-started_at
		if since_start<0.65:
			session.local_input={"move":Vector2.RIGHT if since_start<0.32 else Vector2.LEFT,"aim":Vector2.RIGHT,"sprint":true}
		for ally in session.players.values():
			if ally.id!=session.my_id() and ally.motion=="run":
				saw_running=true
		if session.players[session.my_id()].weapon==2:
			saw_weapon=true
		if expected==2 and not host_mode and since_start>0.7 and not pickup_requested and not session.world_drops.is_empty():
			pickup_requested=true
			session.action("pickup")
		if expected==2 and since_start>1.0 and session.world_drops.is_empty():
			for recipient in session.players.values():
				if recipient.id!=1 and Catalog.container_count(recipient.backpack,"relic")+Catalog.container_count(recipient.pocket,"relic")==1:
					pickup_confirmed=true
		if not host_mode and session.elapsed>1 and session.objectives==2:
			var me: Dictionary=session.players[session.my_id()]
			if Catalog.container_value(me.backpack)==125 or expected==2 and Catalog.container_count(me.backpack,"relic")+Catalog.container_count(me.pocket,"relic")==1:
				saw_snapshot=true
		if not host_mode and session.elapsed>1 and Catalog.container_count(session.players[session.my_id()].pocket,"scrap")==1:
			saw_pocket=true
		if age-started_at>0.8 and not local_sent:
			# Every peer equips the looted weapon sitting in its own backpack; the
			# other peers must see the change of hand and hear the equip cue.
			var me: Dictionary=session.players.get(session.my_id(),{})
			var items: Array=Catalog.container_items(me.get("backpack",{}))
			for i in items.size():
				if str(items[i].kind)=="weapon":
					local_sent=true
					session.action("equip",{"slot":"backpack","index":i})
					break
		if age-started_at>0.95 and not local_skilled:
			local_skilled=true
			session.action("skill")
		if (not host_mode and since_start>0.65) or age-started_at>6:
			session.local_input={"move":Vector2.ZERO,"aim":Vector2.RIGHT,"fire":false,"interact":true}
		elif host_mode and since_start>=0.65:
			session.local_input={"move":Vector2.ZERO,"aim":Vector2.RIGHT}
		if host_mode:
			for p in session.players.values():
				if p.id!=1 and p.status=="extracted" and session.players[1].status=="active":
					saw_independent=true
	return false

func done() -> void:
	stage=3
	var pass_test := session.results.size()==expected and session.seed_value==54321 and got_effect and got_combat and got_audio and saw_weapon and saw_running
	for reward in session.results.values():
		# 125 from the relic in the backpack plus 32 from the scrap in the pocket.
		pass_test=pass_test and reward.escaped and reward.shared==110 and reward.loot==157
	if host_mode:
		pass_test=pass_test and saw_independent
	else:
		pass_test=pass_test and saw_snapshot and saw_pocket
	if expected==2:
		pass_test=pass_test and pickup_confirmed and (host_mode or pickup_requested)
	print("NETWORK %s %d PLAYERS: %s" % ["HOST" if host_mode else "CLIENT",expected,"PASS" if pass_test else "FAIL"])
	if not pass_test:
		print("NETWORK DETAILS: ",{"results":session.results,"seed":session.seed_value,"effect":got_effect,"combat":got_combat,"audio":got_audio,"weapon":saw_weapon,"running":saw_running,"snapshot":saw_snapshot,"independent":saw_independent,"pickup":pickup_confirmed})
	await create_timer(0.6).timeout
	session.disconnect_room()
	quit(0 if pass_test else 1)
