extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("FAIL: "+description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var bag: Array=[]
	for i in 24:
		check(Catalog.insert(bag,"crystal"),"fill cell %d" % i)
	check(not Catalog.insert(bag,"crystal"),"reject full bag")
	check(Catalog.bag_value(bag)==432,"bag value")
	check(Catalog.consume(bag,"crystal"),"consume exists")
	check(not Catalog.insert(bag,"relic"),"large item cannot fit single gap")
	bag.clear()
	check(Catalog.insert(bag,"relic"),"insert relic")
	check(not Catalog.can_place(bag,{"kind":"medicine","rot":false},Vector2i(1,1)),"reject overlapping item")
	check(Catalog.can_place(bag,{"kind":"medicine","rot":true},Vector2i(4,3)),"rotated item at edge")
	check(not Catalog.can_place(bag,{"kind":"medicine","rot":false},Vector2i(4,3)),"vertical item crosses edge")
	for seed_value in range(1,31):
		var map := Ruins.new()
		var twin := Ruins.new()
		map.generate(seed_value)
		twin.generate(seed_value)
		check(str(map.chests)==str(twin.chests),"deterministic loot seed %d" % seed_value)
		var visited: Dictionary={}
		var queue: Array[Vector2i]=[Vector2i(6,27)]
		visited[queue[0]]=true
		var cursor := 0
		while cursor<queue.size():
			var cell := queue[cursor]
			cursor+=1
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i=cell+delta
				if next.x<1 or next.y<1 or next.x>68 or next.y>53 or visited.has(next):
					continue
				if not map.blocked(Vector2(next)*40):
					visited[next]=true
					queue.append(next)
		for shrine in map.shrines:
			check(visited.has(Vector2i((shrine.p/40).round())),"reachable objective %d" % seed_value)
		for exit_pos in map.exits:
			check(visited.has(Vector2i((exit_pos/40).round())),"reachable extraction %d" % seed_value)
	var session := TideSession.new()
	session.name="Session"
	root.add_child(session)
	session.set_physics_process(false)
	session.solo({"name":"Test","hero":0,"talents":[0,0,0]})
	check(session.launch(false,12345),"solo launches")
	check(session.duration==480,"standard duration")
	var p: Dictionary=session.players[1]
	check(Catalog.bag_value(p.bag)==0,"free supplies cannot generate silver")
	session.enemies.clear()
	session.spawn_timer=999
	p.p=session.ruins.chests[0].p
	var before: int=p.bag.size()
	session.interact(p,true,0.7)
	check(p.bag.size()>before,"search chest yields loot")
	p.scent=50
	Catalog.insert(p.bag,"crystal")
	session.perform(1,"burn")
	check(p.scent==25,"burn reduces scent")
	p.hp=25
	session.perform(1,"heal")
	check(p.hp==70,"medkit restores 45")
	p.p=session.ruins.shrines[0].p
	session.interact(p,true,3.1)
	check(session.objectives==1,"complete shared objective")
	session.players[2]=session.make_player(2,{"name":"Ally","hero":1})
	session.players[2].p=p.p
	session.down(session.players[2])
	session.interact(p,true,3.1)
	check(session.players[2].status=="active","revive downed teammate")
	p.p=session.ruins.exits[0]
	session.interact(p,true,4.1)
	check(p.status=="extracted","independent extraction")
	check(session.running,"party remains in run after one extraction")
	session.players[2].status="dead"
	session.enemies.clear()
	session.simulate(0.02)
	check(not session.running,"all terminal players settle")
	check(session.results[1].loot>0,"extracted player preserves loot")
	check(session.results[2].loot==0,"dead player loses loot")
	check(session.results[1].shared==session.results[2].shared,"shared reward equal")
	session.return_to_camp()
	check(not session.players[2].ready,"client must ready again")
	session.players.erase(2)
	check(session.launch(true,42),"replay long expedition")
	check(session.duration==900 and session.objectives==0,"new run resets objectives and timer")
	session.enemies.clear()
	session.elapsed=899.99
	session.simulate(0.1)
	check(not session.running and not session.results[1].escaped,"deadline kills unextracted player")
	var save := Profile.new()
	save.path="user://test-profile.json"
	save.data.coins=987
	save.data.talents=[2,3,1]
	save.save_profile()
	var restored := Profile.new()
	restored.path=save.path
	restored.load_profile()
	check(restored.data.coins==987 and restored.data.talents==[2,3,1],"save/load preserves progression")
	DirAccess.remove_absolute(save.path)
	session.queue_free()
	print("SYSTEM TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
