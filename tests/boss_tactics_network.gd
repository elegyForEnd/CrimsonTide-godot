extends SceneTree
const T = preload("res://scripts/boss_tactics.gd")
var s: TideSession
var server := false
var age := 0.0
var launched := false
var seen_guard := false
var seen_break := false
var seen_reaction := false
var seen_combo := false
var sent_hit := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	server="--server" in OS.get_cmdline_user_args()
	s=TideSession.new()
	s.name="Session"
	root.add_child(s)
	var error: Error=s.host({"hero":0}) if server else s.join("127.0.0.1",{"hero":0,"ready":true})
	if error!=OK: quit(1)

func _process(dt: float) -> bool:
	age+=dt
	if age>16:
		push_error("Tactics network timeout")
		quit(1)
	if not s: return false
	if server:
		if not launched and s.players.size()==2:
			for p in s.players.values(): p.ready=true
			s.launch(false,1729)
			s.enemies.clear()
			s.raid.kind=1
			s.expedition.spawn_boss(s)
			var e: Dictionary=s.enemies.back()
			T.start_guard(e,Vector2.RIGHT)
			T.update_guard(e,0.33)
			for p in s.players.values():
				p.p=e.p+Vector2(80,0)
				p.invuln=100
				Catalog.place_item(p.backpack,Catalog.make_equipment("weapon",2,0))
				s.equip_item(p,"backpack",p.backpack.items.size()-1)
			# Keep the live guard up while the network client sends a real attack.
			launched=true
			age=0
		if launched:
			var e: Dictionary=s.enemies.back()
			if age<2 and e.get("guard_time",0)>0: e.guard_time=0.65
			if age>2 and age<3:
				e.reaction={"kind":"reload","target":1,"point":s.players[1].p,"wait":0.2,"expires":1.0}
				e.cd=1
			if age>3 and not seen_combo:
				e.reaction={}
				s.expedition.cast_boss(s,e,s.players[1],"feint",Vector2.RIGHT,s.players[1].p)
				seen_combo=true
			if age>6:
				print("BOSS TACTICS NETWORK HOST PASS")
				s.disconnect_room()
				quit()
	elif s.running:
		for e in s.enemies:
			if not e.get("raid_boss",false): continue
			if e.get("guard_time",0)>0 and e.has("guard_aim"):
				seen_guard=true
				if not sent_hit:
					s.local_input={"move":Vector2.ZERO,"aim":Vector2.LEFT,"fire":true,"interact":false,"sprint":false}
					sent_hit=true
			if e.get("stagger",0)>0 and e.get("move_name","")=="架势崩解 · 趁机进攻":
				seen_break=true
				s.local_input.fire=false
			if not e.get("reaction",{}).is_empty(): seen_reaction=true
			if e.get("move_id","")=="feint" and e.get("attack_marks",[]).size()==2 and s.raid.hazards.size()>=2:
				seen_combo=true
		if seen_guard and seen_break and seen_reaction and seen_combo:
			print("BOSS TACTICS NETWORK CLIENT PASS: actual client heavy attack breaks host guard; reaction and combo replicate")
			s.disconnect_room()
			quit()
	return false
