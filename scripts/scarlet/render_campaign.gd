extends RefCounted
## Read-only native-coordinate view for the unchanged original StoryWorld.
signal combat_event(event: Dictionary)
signal location_changed
var owner_ref: WeakRef
var source:
	get: return owner_ref.get_ref()
var map:
	get: return source.terrain().original
var state: Dictionary:
	get:
		var result: Dictionary=source.state.duplicate()
		result.stage=map.stage
		return result
var hero_at: Vector2:
	get: return source.terrain().native(source.hero_at)
var allies: Array:
	get:
		var result: Array=[]
		for i in 3: result.append(source.terrain().native(source.allies[i]) if i in source.state.party else Vector2(-100000,-100000))
		return result
var clock: float:
	get: return source.clock
var moving: bool:
	get: return source.moving
var facing: Vector2:
	get: return source.facing
var attack_time: float:
	get: return source.action_time
var hurt_time: float:
	get: return source.hurt_time
var enemies: Array:
	get:
		var result: Array=[]
		var arts: Array=["bell-hierophant","ashen-vesper","thorn-huntsman","mirror-weaver","moon-leviathan","blood-queen"]
		for enemy in source.enemies:
			var e: Dictionary=enemy.duplicate()
			e.p=source.terrain().native(enemy.p); e.type=4; e.target=hero_at
			e.art=arts[int(source.state.act)-1] if e.boss else ""
			if e.key=="beast": e.art="earthsplitter"
			if e.key=="warden": e.art="bell-hierophant"
			e.phase=source.combat.phase; e.corpse_time=2.0
			for hazard in source.combat.hazards:
				if hazard.owner==e.id and hazard.delay>0: e.windup=hazard.delay; break
			result.append(e)
		return result
func _init(c): owner_ref=weakref(c)
func enemy_pose(e: Dictionary) -> Dictionary:
	return preload("res://scripts/scarlet/enemy_frames.gd").pose(e,source.clock)
func hero_pose(frames, hero: int) -> Dictionary:
	var actor: Dictionary=source.hero_actor(hero)
	if actor.swing_time>0: return frames.equipped_attack_frame(actor)
	if actor.motion=="idle": return frames.held_idle_frame(hero,int(actor.weapon),source.clock)
	return frames.held_motion_frame(actor,actor.motion,source.move_phase,float(actor.dodge_time)*TideSession.DODGE_DURATION/.24)

func hero_actor(hero: int) -> Dictionary: return source.hero_actor(hero)
func objective_nodes() -> Array:
	var result: Array=[]
	for item in source.objective_nodes():
		if source.fieldwork.supports(item): continue
		var node: Dictionary=item.duplicate(); node.p=source.terrain().native(item.p); node.step=0
		result.append(node)
	return result
