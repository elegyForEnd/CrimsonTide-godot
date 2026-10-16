extends SceneTree
const Campaign=preload("res://scripts/scarlet/campaign.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false; c.state.started=true
	c.unlock_original_maps()
	check(c.content.zones.size()==56,"all 55 original maps plus the finale event view are retained")
	for a in range(1,7):
		c.state.act=a; c.state.zone="%d:0" % a; c.state.stage=0; c.state.pending={}; c.unlock_original_maps()
		var geo=c.terrain(); var original=geo.original
		for stage in original.regions:
			var key: String=geo.zone_for(a,stage)
			check(c.content.zones.has(key) and key in c.state.unlocked,"original map remains visitable "+key)
		for connector in original.connectors:
			var middle: Vector2=(connector.a+connector.b)*.5
			check(original.walkable(middle),"original connecting road has its original collision")
			c.state.zone=geo.zone_for(a,int(connector.from)); c.state.stage=int(c.state.zone.get_slice(":",1)); c.state.pending={}
			geo=c.terrain()
			check(c.walkable(geo.local(middle)),"Scarlet can walk original connecting road")
			var destination=original.regions[int(connector.to)]
			var native: Vector2=destination.origin+destination.spawn
			c.hero_at=geo.local(native); c.cross_original_boundary()
			check(c.state.zone==geo.zone_for(a,int(connector.to)),"crossing original boundary switches event area")
			check(c.terrain().native(c.hero_at).distance_to(native)<.01,"crossing preserves native world position")
		for door in original.portals:
			c.state.zone=geo.zone_for(a,int(door.source)); c.state.stage=int(c.state.zone.get_slice(":",1)); c.state.pending={}
			var target: String=geo.zone_for(a,int(door.stage)); var entry: Dictionary={}
			for node in c.objective_nodes():
				if node.kind=="original_portal" and node.target==target: entry=node
			check(not entry.is_empty(),"original dungeon entrance is interactive "+target)
			if entry.is_empty(): continue
			c.hero_at=entry.p; check(c.use(entry),"original entrance opens dungeon "+target)
			c.state.pending={}; var exit: Dictionary={}
			for node in c.objective_nodes():
				if node.kind=="original_portal" and node.id=="original-exit": exit=node
			check(not exit.is_empty(),"original dungeon has return entrance "+target)
			if not exit.is_empty():
				c.hero_at=exit.p; check(c.use(exit),"return from original dungeon "+target)
				check(c.state.zone==geo.zone_for(a,int(door.source)),"return leads to original parent map")
	for a in range(1,7):
		c.state.zone="%d:6" % a; c.state.act=a; c.state.stage=6; c.state.pending={}
		c.combat.start("R-%d-06" % a,"fixture",c.content.acts[a-1].boss,1)
		for phase in c.content.bosses[c.content.acts[a-1].boss].phases.size():
			c.combat.phase=phase; c.combat.spawn_phase()
			check(c.walkable(c.hero_at),"boss phase entry on original floor %d:%d" % [a,phase])
			check(c.walkable(c.enemies[0].p),"boss on original floor %d:%d" % [a,phase])
			for g in c.combat.gadgets(): check(c.walkable(g.p),"boss mechanism on original floor "+g.id)
		c.combat.clear()
	print("SCARLET_GEOGRAPHY %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
