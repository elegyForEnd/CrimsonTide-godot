extends RefCounted
## Authoritative presentation events share the combat RPC with ordinary attacks.
const KEYS := ["bell", "thorn", "queen", "knight"]

static func theme(e: Dictionary) -> int:
	return int(e.boss_kind) if e.get("raid_boss",false) else 3

static func send(s, e: Dictionary, action: String, extra: Dictionary = {}) -> void:
	var event := {"kind":"boss-vfx","action":action,"boss_kind":theme(e),"id":e.id,
		"p":e.p,"aim":e.get("attack_aim",Vector2.RIGHT),"move":e.get("move_id",e.get("move_name","")),
		"phase":e.get("phase",1)}
	event.merge(extra,true)
	s.broadcast_combat(event)

static func cue(data: Dictionary) -> String:
	var action: String=data.action
	var suffix := "charge"
	if action in ["guard","break","fall"]: suffix=action
	elif action in ["entrance","phase"]: suffix="ritual"
	elif action=="release":
		var shape: String=data.get("shape","circle")
		if shape=="line": suffix="lance"
		elif float(data.get("total",1.0))<=0.7: suffix="quick"
		elif shape=="cone": suffix="sweep"
		else: suffix="burst"
	return KEYS[clampi(int(data.boss_kind),0,3)]+"-"+suffix
