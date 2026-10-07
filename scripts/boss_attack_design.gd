extends RefCounted
## Attack intent is authored first. Collision and warning are consumers of it.
## Slots match BossChoreography.MOVES; mixed moves select delivery per contact.
const PLANS := {
	"bell":["pendulum","resonance","resonance","resonance"],
	"thorn":["seed","root","whip","root"],
	"queen":["fall","projectile","sigil","fall"],
	"knight":["blade","blade","blade","thrust"],
	"hidden":["root","root","projectile","impact"],
	"mirror":["projectile","thread","sigil","fall"],
	"ember":["flame","projectile","flame","flame"],
	"moon":["beam","projectile","tide","tide"],
	"earth":["fault","fault","fall","projectile"],
	"storm":["projectile","lightning","wind","lightning"],
	"abyss":["bite","teeth","tide","bite"],
	"dragon":["breath","frost","claw","fall"],
	"grove":["root","seed","root","fault","root","cloud","root"],
	"furnace":["chain","projectile","vent","chain","vent","chain","vent"],
	"astral":["projectile","projectile","fall","sigil","projectile","projectile","sigil"],
	"wing":["wind","projectile","wind","impact","lightning","wind","wind"],
	"obsidian":["thrust","fall","sigil","thrust","thrust","thrust","thrust"],
	"rq_bell":["pendulum","resonance","resonance","resonance","resonance","resonance","resonance"],
	"rq_earth":["fault","fault","fall","projectile","fault","fault","fall"],
	"rq_abyss":["bite","teeth","tide","bite","tide","tide","impact"]}
const PHYSICAL := ["blade","whip","claw","bite","thrust"]
const WARNING_IDS := {"area":0,"gesture":1,"path":2,"shadow":3,"crack":4,"ripple":5}

static func primary(key: String, slot: int) -> String:
	return str(PLANS[key][clampi(slot,0,PLANS[key].size()-1)]) if PLANS.has(key) else "sigil"

static func contact(key: String, slot: int, h: Dictionary, caster: Vector2) -> Dictionary:
	var kind := primary(key,slot)
	var role := str(h.get("vfx_role",""))
	var shape := str(h.shape)
	# A single move can contain a physical strike AND a distant spell / decoy.
	if h.get("preview_only",false): kind="projectile"
	elif shape=="cone":
		kind={"knight":"blade","thorn":"whip","dragon":"claw","abyss":"bite","rq_abyss":"bite"}.get(key,"blade")
	elif shape in ["ring","gap_ring"] or float(h.get("inner",0))>0 and shape=="circle":
		kind="wind" if key in ["storm","wing"] else "tide" if key in ["abyss","rq_abyss","moon"] else "resonance"
	elif key=="knight" and shape=="circle": kind="shadow"
	elif shape=="circle":
		if key in ["abyss","rq_abyss"] and role=="maw": kind="teeth"
		elif key in ["furnace"]: kind="slam" if h.p.distance_to(caster)<105 and role=="hammer" else "vent"
		elif key in ["storm","wing"] and role in ["chain","return"]: kind="lightning"
		elif role in ["sabres","crown","stalactite","starfall","rain","drop","glass"]: kind="fall"
		elif role in ["root","roots","bramble","ribcage","hands","bloom","mycelium"]: kind="root"
		elif role in ["furrow","plate","fault"]: kind="fault"
		elif role in ["frost","icicle"]: kind="frost"
		elif kind in PHYSICAL: kind="sigil"
	elif shape in ["lane","line"] and kind in PHYSICAL: kind="thrust"
	var warning := "area"
	if kind in PHYSICAL: warning="gesture"
	elif kind in ["fall","pendulum","impact","slam","teeth"]: warning="shadow"
	elif kind in ["root","fault","frost","vent"]: warning="crack"
	elif kind in ["resonance","tide","wind"]: warning="ripple"
	elif shape in ["lane","line"]: warning="path"
	var result := {"delivery":kind,"warning_style":WARNING_IDS[warning],"warning_lead":.65 if warning in ["shadow","crack"] else .50}
	if kind in ["breath","beam","chain","thread"]:
		var attached: bool=h.p.distance_to(caster)<50
		result["stream_lift"]={"breath":90.0,"beam":150.0,"chain":135.0,"thread":65.0}[kind] if attached else 0.0
		result["stream_forward"]={"breath":80.0,"beam":50.0,"chain":100.0,"thread":20.0}[kind] if attached else 0.0
	if kind in PHYSICAL:
		var height: float={"knight":55.0,"thorn":80.0,"dragon":40.0,"abyss":180.0,"rq_abyss":180.0,"obsidian":70.0}.get(key,42.0)
		var forward: float={"thorn":20.0,"dragon":25.0,"abyss":15.0,"rq_abyss":15.0}.get(key,0.0)
		result.merge({"strike_duration":.18,"linger":.18,"socket_height":height,"socket_forward":forward})
		if shape=="cone": result["sweep"]=kind=="blade"
	return result

## All renderers use the same local attack beat; no idle pose during a cast.
## Movement and remote aftershocks do not restart the actor's swing animation.
static func beat(e: Dictionary) -> Dictionary:
	var elapsed := maxf(0.0,float(e.get("attack_total",0))-float(e.get("attack_time",0)))
	var beats: Array=e.get("body_marks",e.get("attack_marks",[float(e.get("windup",.8))]))
	if beats.is_empty(): beats=[float(e.get("windup",.8))]
	var start := 0.0
	for i in beats.size():
		var mark: float=beats[i]
		var end: float=minf(mark+.34,float(e.get("attack_total",mark+.34)))
		if elapsed<=end:
			return {"frame":GeneratedAttacks.timeline_frame(elapsed-start,end-start,mark-start),"elapsed":elapsed,"impact":mark,"start":start,"end":end,"index":i}
		start=end
	return {"frame":7,"elapsed":elapsed,"impact":float(beats.back()),"start":start,"end":float(e.get("attack_total",start)),"index":beats.size()-1}
