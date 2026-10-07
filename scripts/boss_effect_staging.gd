extends RefCounted
const Language=preload("res://scripts/boss_effect_language.gd")
## Birth language is authored by identity and motif, not just palette.
const GROUND := ["bramble","root","roots","furrow","plate","ribcage","tomb","hands","mycelium","bloom","pyre","kiln","frost","icicle"]
const FALL := ["sabres","regalia","crown","stalactite","starfall","rain","rivets","hammer","drop","fracture"]
static func style(key: String, role: String, shape: String) -> String:
	if shape=="capsule": return "projectile"
	if shape in ["lane","line"]: return "stream"
	if shape in ["cone","arc"]: return "sweep"
	if shape in ["ring","gap_ring"]: return "orbit"
	if role in FALL: return "fall"
	if role in GROUND: return "grow"
	if key=="bell": return "pendulum"
	if key in ["hidden","mirror","obsidian","astral"]: return "portal"
	if key in ["storm","wing","abyss","moon"]: return "vortex"
	return "bloom"
static func stream_style(key: String) -> int:
	if key=="storm": return 1
	if key in ["ember","dragon","furnace"]: return 2
	if key in ["wing","abyss"]: return 3
	if key in ["earth","thorn","grove"]: return 4
	if key in ["mirror","bell"]: return 5
	return 0
static func pose(h: Dictionary, first_seen: float, impact_age: float, tail: float = 0.0) -> Dictionary:
	var key := Language.Art.identity(h)
	var role := str(h.get("vfx_role","slash"))
	var kind := str(h.get("birth_style",style(key,role,str(h.shape))))
	var active: bool=h.get("fired",h.get("active",false))
	if str(h.get("delivery","")) in ["blade","whip","claw","bite","thrust"]:
		return physical_pose(h,impact_age,tail)
	var remaining := float(h.get("time",h.get("delay",0.0)))
	var lead := clampf(1.0-remaining/maxf(.01,float(h.get("windup",h.get("total",.60)))),0.0,1.0)
	var release := clampf(impact_age/.16,0.0,1.0) if active else 0.0
	var size := clampf(float(h.radius)*1.65,64.0,230.0)
	var angle := 0.0
	var lift := size*.27
	var reveal := 1.0
	var alpha := smoothstep(0.0,.16,first_seen)*lead
	var offset := Vector2.ZERO
	if kind=="stream":
		size=clampf(float(h.get("inner",44))*2.4,48.0,100.0); alpha=lead*.55
		lift=0.0; angle=h.get("aim",Vector2.RIGHT).angle()
	elif kind=="projectile":
		# `inner` is the bolt's hit radius and stays untouched; `bullet_visual` is
		# the presentation-only variant factor (1.0 whenever absent), applied here
		# so the deep-abyss fog/surge bolts read as larger without lying about the
		# circle that hurts.  Bounds match RogueCombat.BULLET_VISUAL_BOUNDS.
		size=float(h.get("inner",18))*2.5*clampf(float(h.get("bullet_visual",1.0)),1.0,3.0)
		lift=0.0; alpha=1.0; angle=h.get("aim",Vector2.RIGHT).angle()
	elif kind=="fall":
		lift+=pow(1.0-lead,2.0)*230.0
		alpha=smoothstep(0.0,.16,first_seen)*smoothstep(0.0,.20,lead)*.85
	elif kind=="grow":
		reveal=lerpf(.04,.32,lead) if not active else lerpf(.32,1.0,release)
		alpha=lead*.55 if not active else 1.0
	elif kind=="pendulum":
		offset.x=sin((1.0-lead)*PI*.65)*size*.65
		lift+=(1.0-lead)*95.0
		angle=(1.0-lead)*-.7
	elif kind=="sweep":
		angle=h.get("aim",Vector2.RIGHT).angle()+lerpf(-.85,.55,release)
		offset=Vector2.from_angle(h.get("aim",Vector2.RIGHT).angle())*float(h.radius)*.40
		size=clampf(float(h.radius)*1.5,100.0,360.0); lift=0.0
		alpha=lead*.16 if not active else lerpf(.16,1.0,smoothstep(0.0,.03,impact_age))*pow(1.0-clampf(impact_age/.40,0.0,1.0),.6)
	elif kind in ["orbit","vortex"]:
		angle=first_seen*.55
		lift=0.0
		if float(h.get("inner",0))>0: alpha=0.0 # The continuous annulus keeps its safe center empty.
	elif kind=="portal":
		angle=(1.0-lead)*-.40
		reveal=lead if not active else 1.0
	if active and kind!="sweep": alpha=lerpf(.55,1.0,smoothstep(0.0,.06,impact_age)) if kind=="grow" else (1.0 if kind not in ["stream","orbit"] else .75)
	if h.get("construct_only",false):
		var age := float(h.get("construct_age",first_seen))
		size=110.0
		alpha=smoothstep(0.0,.25,age)*smoothstep(0.0,.30,float(h.get("construct_life",1.0)))
		if kind=="fall": lift=size*.27+pow(1.0-lead,2.0)*175.0
		elif kind in ["grow","portal"]: reveal=smoothstep(0.0,.40,age); lift=size*.27
		else: lift=size*.27+maxf(0.0,1.0-age/.35)*30.0
	if key in ["storm","wing"] and kind in ["orbit","vortex"]: alpha=0.0 # Wind and lightning are moving fields, never spinning objects.
	if key=="storm" and role in ["chain","eye","plume"] and not h.get("construct_only",false): alpha=0.0
	if not Language.body_allowed(key,role,str(h.shape),bool(h.get("construct_only",false))): alpha=0.0
	if str(h.get("delivery",""))=="shadow": alpha=0.0
	var sprite := Language.sprite_role(key,role,str(h.shape),str(h.get("move","")))
	if sprite in ["thunder_impact","flame_vent"] and not h.get("construct_only",false):
		# Actual vertical emission, contact pivot at the ground. Never spins or grows a crest.
		kind="strike" if sprite=="thunder_impact" else "vent"
		size=clampf(float(h.radius)*2.2,100.0,240.0)
		lift=0.0; offset=Vector2.ZERO; angle=0.0; reveal=1.0
		alpha=0.0 if not active else smoothstep(0,.018,impact_age)*exp(-impact_age*(8.0 if kind=="strike" else 3.0))
		if kind=="vent": reveal=smoothstep(0,.13,impact_age)
	if key=="furnace" and role=="kiln" and h.get("construct_only",false):
		kind="vent_source"; angle=0.0; lift=0.0; offset=Vector2.ZERO; size=80.0
		var burning: bool=h.get("vent_active",false)
		reveal=smoothstep(0,.25,float(h.get("construct_age",0)))
		alpha=.90 if burning else .65
	if tail>0: alpha*=pow(maxf(0.0,1.0-tail/.32),1.8); lift+=tail*22.0
	return {"kind":kind,"size":size,"angle":angle,"lift":lift,"offset":offset,"reveal":reveal,"alpha":alpha,"flash":exp(-impact_age*19.0)*.45 if active else 0.0,"from_ground":kind in ["grow","portal","vent","vent_source"]}

## Original painted art owns the silhouette. No warning-shaped crop or geometry stamp.
static func physical_pose(h: Dictionary, age: float, tail: float) -> Dictionary:
	var active: bool=h.get("fired",h.get("active",false))
	var duration := float(h.get("strike_duration",.18))
	var phase := clampf(age/maxf(.01,duration),0,1)
	var kind := str(h.delivery)
	var size := float(h.radius)*2.0
	var offset := Vector2.ZERO
	var pivot := Vector2.ZERO
	var angle := 0.0
	var alpha := (1.0-smoothstep(duration*.7,duration+.07,age))*smoothstep(0,.018,age) if active else 0.0
	if kind=="thrust":
		size=float(h.radius)*clampf(phase*1.7,.18,1.0)
		pivot=Vector2(-.46,0.0) # The painted lance points right; tail begins at the weapon.
	elif kind=="claw":
		size=float(h.radius)*1.16
		pivot=Vector2(-.42,0) # Dedicated three-stroke art travels to the right from the claw.
		angle=lerpf(-float(h.get("arc",.55)),float(h.get("arc",.55)),phase)
	elif kind=="whip":
		size=float(h.radius)*1.08
		pivot=Vector2(-.46,0) # Dedicated single vine, held at its left grip.
		angle=lerpf(-float(h.get("arc",.75)),float(h.get("arc",.75)),phase)*(-1.0 if h.get("sweep_reverse",false) else 1.0)
	elif kind=="bite":
		size=float(h.radius)*1.28
		pivot=Vector2(-.40,0)
		alpha*=.85
	if tail>0: alpha*=maxf(0.0,1.0-tail/.12)
	return {"kind":"attached","size":size,"angle":angle,"lift":float(h.get("socket_height",42)),"offset":offset,"pivot":pivot,"reveal":1.0,"alpha":alpha,"flash":exp(-age*30)*.12,"from_ground":false,"stroke_mode":kind=="blade","stroke_phase":phase,"stroke_arc":float(h.get("arc",1.05)),"stroke_reverse":bool(h.get("sweep_reverse",false))}
