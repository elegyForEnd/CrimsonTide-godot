extends SceneTree
const Content = preload("res://scripts/rogue_content.gd")
const Build = preload("res://scripts/rogue_build.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func claim(s, p: Dictionary) -> void:
	var selection: Dictionary=p.rogue_selection
	if selection.is_empty(): return
	var kind := "rogue_selection_bank" if selection.get("category","") in ["talent","core"] else "rogue_selection_take"
	s.perform(p.id,kind,{"id":selection.id,"version":selection.version,"index":0})
func run() -> void:
	var s := TideSession.new(); root.add_child(s); s.set_physics_process(false)
	for count in [1,4]:
		s.solo({"hero":0,"mode":"roguelike"})
		for id in range(2,count+1):
			s.players[id]=s.make_player(id,{"hero":id-1,"mode":"roguelike"}); s.players[id].ready=true
		check(s.launch(false,813),"Launch party of%d" % count)
		for p in s.players.values(): claim(s,p)
		s.roguelike.tick(s,.01)
		var rooms := 0
		var sanctuary_counts: Dictionary={}
		var talent_choices := 0
		var core_choices := 0
		var attribute_shards := 0
		var guard := 0
		while s.running and guard<150:
			guard+=1
			if s.raid.area==1:
				check(s.raid.exits.size()==1 and s.raid.exits[0].room=="talent","Every possible route must enter the first sanctuary")
			elif s.raid.area==2:
				check(s.raid.exits.all(func(exit): return exit.room in ["combat","elite"]),"Two combat areas remain guaranteed")
			elif s.raid.area==3:
				check(s.raid.exits[0].room in ["shop","treasure"] and s.raid.exits[1].room=="talent","Fourth area offers supplies or a second sanctuary")
			if s.raid.room=="talent":
				var floor_index: int=s.raid.floor
				sanctuary_counts[floor_index]=int(sanctuary_counts.get(floor_index,0))+1
				check(s.enemies.is_empty() and s.raid.reward_chest.is_empty(),"Dedicated sanctuary has no enemies or equipment chest")
				for p in s.players.values():
					var personal_talents := 0
					var personal_cores := 0
					while not p.rogue_selection.is_empty():
						if p.rogue_selection.category=="talent": personal_talents+=1
						elif p.rogue_selection.category=="core": personal_cores+=1
						claim(s,p)
					check(personal_talents==2,"Two personal talent choices per sanctuary")
					check(personal_cores==(1 if floor_index==2 and s.raid.area==2 else 0),"Core offered only in floor-two first sanctuary")
					talent_choices+=personal_talents; core_choices+=personal_cores
					var cultivation: int=p.build_cultivation
					Build.award(s,p)
					check(p.build_cultivation==cultivation and p.build_reward_queue.is_empty(),"Sanctuary cannot award twice")
				check(s.raid.phase=="rogue_exit","Personal sanctuary choices release exit")
				rooms+=1
			elif s.raid.phase in ["rogue_combat","rogue_reward"]:
				if s.raid.phase=="rogue_combat":
					for wave in range(1,4):
						for enemy in s.enemies:
							enemy.hp=0; Build.enemy_experience(s,enemy)
						s.enemies.clear()
						if wave<3: s.raid.wave+=1; s.roguelike.spawn_wave(s)
					s.roguelike.clear_room(s)
				for p in s.players.values():
					check(p.rogue_selection.is_empty() and p.build_reward_queue.is_empty(),"Ordinary rooms do not grant talents")
					while not p.rogue_selection.is_empty(): claim(s,p)
				check(s.raid.phase=="rogue_reward" and not s.raid.reward_chest.opened,"Talent choice does not bypass unopened chest")
				var opener: Dictionary=s.players[1]; opener.p=s.raid.reward_chest.p; s.perform(1,"rogue_loot"); s.elapsed+=2
				attribute_shards+=s.raid.reward_drops.filter(func(drop): return drop.category=="attribute").size()
				check(s.raid.reward_drops.filter(func(drop): return drop.category in ["weapon","gear"]).size()==count*2,"Everyone receives personal weapon and gear packets")
				# Another player cannot claim a personal packet before its owner chooses it.
				if count==4:
					var own: Dictionary=s.raid.reward_drops[0]
					s.players[2].p=own.p; s.perform(2,"rogue_loot")
					check(s.raid.reward_drops.any(func(drop): return drop.id==own.id),"Reject another player's personal pickup")
					claim(s,s.players[2])
				var attempts := 0
				while not s.raid.reward_drops.is_empty() and attempts<50:
					attempts+=1
					var drop: Dictionary=s.raid.reward_drops[0]
					var p: Dictionary=s.players[int(drop.owner)]
					p.rogue_stash=[]; p.p=drop.p
					s.perform(p.id,"rogue_loot"); claim(s,p)
				check(s.raid.phase=="rogue_exit","All choices release exit for%d players" % count)
				rooms+=1
			elif s.raid.phase=="rogue_shop":
				for p in s.players.values():
					check(p.rogue_shop_offers.size()==6,"Shop has six personal offers")
					check(not p.rogue_shop_offers.any(func(offer): return offer.has("talent_id")),"Shop cannot sell talents")
				rooms+=1
			elif s.raid.phase=="rogue_shop_reward":
				for p in s.players.values():
					while not p.rogue_selection.is_empty(): claim(s,p)
				continue
			else: check(false,"Unexpected phase "+str(s.raid.phase)); break
			var exit_index := 1 if s.raid.area==3 and s.raid.floor%2==0 else 0
			for p in s.players.values(): p.p=s.ruins.exit_position(exit_index)
			s.perform(1,"rogue_next",{"revision":s.raid.revision,"index":exit_index})
		check(rooms==25 and s.raid.cleared==25 and not s.running,"Five complete floors /25 rooms")
		for floor_index in range(1,6): check(sanctuary_counts.get(floor_index,0)==(2 if floor_index%2==0 else 1),"Every floor has one or two sanctuaries")
		check(talent_choices==14*count and core_choices==count,"Dedicated-room total choices are personal")
		for p in s.players.values():
			check(p.build_cultivation==18 and p.build_forge_points==8,"Each player keeps guaranteed cultivation and forge growth")
			check(p.build_level==s.players[1].build_level and p.build_xp_total==s.players[1].build_xp_total and p.build_level>=9,"All players gain the full shared kill XP")
			check(p.rogue_stash.size()<=12,"Reserve bounded")
			check(s.results.has(p.id) and s.results[p.id].escaped,"Party settles once per player")
		var points := 0
		for p in s.players.values(): points+=int(p.build_attribute_points)
		check(points==(int(s.players[1].build_level)-1)*2*count+attribute_shards,"All points come from levels and actually collected chest shards: %d vs %d" % [points,(int(s.players[1].build_level)-1)*2*count+attribute_shards])
	print("BUILD PROGRESSION: %d checks, %d failures" % [checks,failures])
	s.queue_free(); quit(1 if failures>0 else 0)
