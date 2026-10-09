extends SceneTree

const Graph = preload("res://scripts/rogue_graph.gd")
const Build = preload("res://scripts/rogue_build.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(why)

# Enumerate actual paths, rather than counting fights on unvisited branches.
func audit_path(graph: Dictionary, id: String, fights: int, safe_streak: int) -> void:
	var info: Dictionary=Graph.node(graph,id)
	var fight: bool=info.kind in ["combat","elite","boss"]
	fights+=1 if fight else 0
	safe_streak=0 if fight else safe_streak+1
	check(safe_streak<=1,"No path chains service rooms")
	if info.kind=="boss":
		check(fights>=6,"Every path has at least six fights")
		return
	for next_id in info.next: audit_path(graph,str(next_id),fights,safe_streak)

func run() -> void:
	for seed_value in 100:
		for floor_number in range(1,6):
			var graph: Dictionary=Graph.build(seed_value,floor_number)
			for id in graph.order:
				var info: Dictionary=Graph.node(graph,str(id))
				if info.depth in [1,2]: check(info.kind=="combat","Two opening combat rooms")
				elif info.depth==3: check(info.kind=="talent","Growth after the opening battles")
				elif info.depth==5: check(info.kind in ["shop","treasure"],"Supplies after three battles")
			audit_path(graph,str(graph.entry),0,0)
	var s := TideSession.new()
	root.add_child(s); s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,914)
	var p: Dictionary=s.players[1]
	p.rogue_selection={}; p.build_reward_queue=[]
	s.raid.variant=""; s.raid.build_enemy_hp=1.0; s.raid.build_enemy_damage=1.0
	# Real spawning: density remains bounded and all monsters fit on the map.
	for floor_number in range(1,6):
		for room in ["combat","elite"]:
			s.raid.floor=floor_number; s.raid.area=4; s.raid.room=room
			s.roguelike.enter(s) # Explicit route override below uses the normal entry path.
			s.raid.route[3]=room; s.roguelike.enter(s)
			for wave in range(1,4):
				s.enemies.clear(); s.raid.wave=wave; s.roguelike.spawn_wave(s)
				var expected: int=[6,6,7,7,8][floor_number-1]+(2 if room=="elite" else 0)
				check(s.enemies.size()==expected,"Encounter density for floor %d/%s" % [floor_number,room])
				for e in s.enemies: check(not s.ruins.blocked(e.p,20),"Spawn stays on traversable ground")
	# More fights pay more refills, with a finite per-floor allowance and no repeat award.
	p.flask=0.0; p.flask_combat_awards=0; p.flask_elite_award=false; p.build_awards={}
	s.raid.floor=1; s.raid.room="combat"
	for area in range(1,7):
		s.raid.area=area; Build.award(s,p); Build.award(s,p)
	check(is_equal_approx(p.flask,40),"Four fights refund forty charge exactly once")
	s.raid.area=7; s.raid.room="elite"; Build.award(s,p)
	check(is_equal_approx(p.flask,45),"First elite adds five charge")
	for floor_number in range(1,6):
		s.raid.floor=floor_number; s.raid.challenge=false
		s.raid.room="combat"; var normal: int=s.roguelike.room_gold(s)
		s.raid.room="elite"; check(s.roguelike.room_gold(s)==normal+15,"Elite risk pays extra")
		s.raid.room="boss"; check(s.roguelike.room_gold(s)==normal+30,"Guardian pays extra")
		s.raid.room="event"; check(s.roguelike.room_gold(s)<normal,"Service entry earns less than combat")
	# Disconnected/dead peers do not keep inflating enemies; downed allies can be rescued.
	s.raid.floor=1; s.raid.variant=""
	s.players[2]={"connected":false,"status":"active"}
	s.players[3]={"connected":true,"status":"dead"}
	var enemy := {"role":"front","hp":1.0}
	Build.enemy_budget(s,enemy)
	check(is_equal_approx(enemy.hp,150),"Only participating allies scale enemy HP")
	s.players[2].connected=true; s.players[2].status="down"
	Build.enemy_budget(s,enemy)
	check(is_equal_approx(enemy.hp,150*1.65),"Rescuable allies remain in combat budget")
	print("ROGUE MAP BALANCE %d checks / %d failures" % [checks,failures])
	s.queue_free(); quit(1 if failures else 0)
