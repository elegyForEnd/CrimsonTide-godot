extends RefCounted
const Art = preload("res://scripts/boss_effect_art.gd")
## Authoritative presentation events share the combat RPC with ordinary attacks.
const KEYS := ["bell", "thorn", "queen", "knight"]
## The hidden encounter reuses the queen's art and audio theme but is drawn with
## its own colour, so the telegraphs read as a different fight.
const HIDDEN_KIND := 2
const HIDDEN_COLOR := Color("c07ae0")

static func theme(e: Dictionary) -> int:
	return int(e.boss_kind) if e.get("raid_boss",false) or e.get("mini_boss",false) else 3

## The colour every telegraph and VFX layer tints this encounter with.
static func theme_color(kind: int, hidden: bool = false) -> Color:
	if hidden:
		return HIDDEN_COLOR
	var palette: Array=COLORS
	return palette[clampi(kind,0,palette.size()-1)]

const COLORS := [Color("c8a8ff"),Color("f987a4"),Color("ffe5ad"),Color("c4e9ff")]

static func send(s, e: Dictionary, action: String, extra: Dictionary = {}) -> void:
	var event := {"kind":"boss-vfx","action":action,"boss_kind":theme(e),"id":e.id,
		"art_key":Art.identity(e),
		"p":e.p,"aim":e.get("attack_aim",Vector2.RIGHT),"move":e.get("move_id",e.get("move_name","")),
		"phase":e.get("phase",1),"mini_boss":e.get("mini_boss",false),
		"mini_kind":e.get("mini_kind",-1),"final_form":e.get("final_form",false),
		"wild_boss":e.get("wild_boss",false),"wild_kind":e.get("wild_kind",-1),"abyss_final":e.get("abyss_final",false),
		"dragon_boss":e.get("dragon_boss",false),"hidden_final":e.get("hidden_final",false)}
	event.merge(extra,true)
	s.broadcast_combat(event)

static func cue(data: Dictionary) -> String:
	var action: String=data.action
	var suffix := "charge"
	if action in ["guard","break","fall"]: suffix=action
	elif action in ["entrance","phase"]: suffix="ritual"
	elif action=="release":
		var shape: String=data.get("shape","circle")
		if shape in ["line","lane"]: suffix="lance"
		elif float(data.get("total",1.0))<=0.7: suffix="quick"
		elif shape in ["cone","arc"]: suffix="sweep"
		else: suffix="burst"
	if data.get("wild_boss",false) and action=="break": suffix="quick"
	var wild_kind: int=int(data.get("wild_kind",-1))
	var prefix: String="dragon" if data.get("dragon_boss",false) else ["earth","storm","abyss"][clampi(wild_kind,0,2)] if data.get("wild_boss",false) else "moon" if data.get("final_form",false) else ("mirror" if int(data.get("mini_kind",-1))==0 else "ember" if int(data.get("mini_kind",-1))==1 else KEYS[clampi(int(data.boss_kind),0,KEYS.size()-1)])
	return prefix+"-"+suffix
