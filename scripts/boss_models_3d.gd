extends Node3D
## Bounded live model set. Scene logic, save IDs and enemy dictionaries stay intact.
const Actor := preload("res://scripts/boss_actor_3d.gd")
const MAX_MODELS := 12
var actors: Dictionary={}
var death_snapshots: Dictionary={}
var mode := "expedition"
var height_at: Callable
var anchor := Vector2.ZERO

func reset() -> void:
	for actor in actors.values(): actor.queue_free()
	actors.clear(); death_snapshots.clear()

func sync(enemies: Array, dt: float, clock: float, focus: Vector2) -> void:
	var live: Dictionary={}
	for e: Dictionary in enemies:
		if not Actor.supports(e,mode): continue
		var key: String=str(e.id)
		if Vector2(e.p).distance_to(focus)>1250: continue
		if float(e.get("hp",1))<=0 and actors.has(key) and actors[key].death_age>2.6: continue
		live[key]=true
		if not actors.has(key):
			if actors.size()>=MAX_MODELS or float(e.get("hp",1))<=0: continue
			var instance := Actor.new(); instance.name="Knight_"+key.validate_node_name(); add_child(instance)
			instance.set_variant(mode=="rogue"); actors[key]=instance
			instance.target_scale=.88 if mode=="story" and e.get("boss",false) else .68
		var actor: Node3D=actors[key]
		var h := float(height_at.call(e.p)) if height_at.is_valid() else 0.0
		actor.position=Vector3(e.p.x*.01,h*.01,e.p.y*.01)
		actor.sync(e,dt,clock,mode=="story")
		death_snapshots[key]=e.duplicate(true)
	for key in actors.keys():
		if live.has(key): continue
		var old: Dictionary=death_snapshots.get(key,{})
		if not old.is_empty() and Vector2(old.p).distance_to(focus)<1250 and actors[key].death_age<2.6:
			old.hp=0.0; actors[key].sync(old,dt,clock,mode=="story")
		else:
			actors[key].queue_free(); actors.erase(key); death_snapshots.erase(key)

func draws(e: Dictionary) -> bool:
	return actors.has(str(e.get("id","")))
