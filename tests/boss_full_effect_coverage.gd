extends SceneTree
const Choreo=preload("res://scripts/boss_choreography.gd")
const Art=preload("res://scripts/boss_effect_art.gd")
const Language=preload("res://scripts/boss_effect_language.gd")
const Sequence=preload("res://scripts/boss_effect_sequence.gd")
const Visual=preload("res://scripts/boss_damage_visual.gd")
var checks := 0
var failures := 0
var s: TideSession
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func fixture(key: String) -> Dictionary:
	var art_key: String=Choreo.TIMELINE_BASE.get(key,key)
	var e := {"id":900,"p":s.players[1].p+Vector2(100,0),"hp":5000.0,"max_hp":5000.0,"type":4,"last":1,"phase":2,"sequence":0,"cd":0.0,"stagger":0.0,"attack_time":0.0,"attack_total":0.0,"facing":1.0,"flash":0.0,"motion_phase":0.0,"art_key":art_key,"moving":false,"guard_time":0.0}
	if key in ["grove","furnace","astral","wing","obsidian","rq_bell","rq_earth","rq_abyss"]:
		e.merge({"rogue_guardian":true,"rogue_skin":0,"boss_art":Art.ROGUE.find(art_key),"boss_skill":0,"choreo_key":key})
	else: e["boss_kind"]=Art.KEYS.find(art_key)
	s.enemies=[e]
	return e
func record(h: Dictionary, label: String) -> void:
	if h.get("preview_only",false): return
	var fallback := Language.sprite_role(str(h.art_key),str(h.vfx_role),str(h.shape),str(h.get("move","")),str(h.get("delivery","")))
	var role := Sequence.resolve(h,fallback)
	check(Sequence.has(role),label+" has an animated image, not just a planned description")
	if not Sequence.has(role): return
	var spec: Dictionary=Sequence.specs()[role]
	check(spec.columns==3 and spec.rows==3 and spec.frames.size()==9,label+" uses independent 3x3 atlas")
	for state in ["prepare","contact","sustain","recover"]:
		check(spec.states.has(state),label+" contains state "+state)
	var texture: Texture2D=Sequence.frame(role,2).texture
	check(texture!=null and texture is AtlasTexture and texture.atlas!=null,label+" actually loads its frame texture")
	var normal := Visual.render_record(h)
	normal.erase("construct_only")
	normal.fired=false; normal.time=.1
	check(Sequence.state(normal,0,role).name=="prepare",label+" anticipates without contact")
	normal.fired=true; normal.time=-.02
	check(Sequence.state(normal,.02,role).name=="contact",label+" contact selects release frame")
	check(Sequence.state(normal,.7,role,.12).name=="recover",label+" server removal enters non-damaging collapse")
func run() -> void:
	s=TideSession.new(); root.add_child(s); s.solo({"hero":0}); s.launch(false,1729); s.set_physics_process(false)
	s.raid.floor=1
	var moves := 0
	var identities: Dictionary={}
	var sheets: Dictionary={}
	for key in Choreo.MOVES:
		for slot in Choreo.MOVES[key].size():
			s.enemies=[]; s.raid.hazards=[]; s.bullets=[]; s.roguelike.combat.reset()
			var e := fixture(key)
			e["boss_skill"]=slot
			var label: String=key+" / "+str(Choreo.MOVES[key][slot])
			check(Choreo.start(s,e,str(Choreo.MOVES[key][slot]),Vector2.RIGHT,e.p+Vector2(180,0)),label+" can start")
			moves+=1; identities[key]=true
			var records: Array=s.raid.hazards.duplicate(); records.append_array(s.roguelike.combat.effects)
			for h in records: record(h,label)
			for action in e.choreo_steps:
				if action.op=="projectile": record({"art_key":e.art_key,"vfx_role":action.role,"shape":"capsule","p":action.p,"radius":10.0,"inner":18.0,"aim":action.aim,"fired":true,"time":-.20,"linger":2.0},label+" flight")
				if action.op=="construct": record({"art_key":e.art_key,"vfx_role":action.role,"shape":"circle","p":action.p,"radius":65.0,"inner":0.0,"aim":Vector2.RIGHT,"fired":true,"construct_only":true,"construct_age":.6,"construct_life":2.0,"time":-.20},label+" construct")
	for key in Art.KEYS:
		for role in Art.MOTIFS[key]:
			var id: String=key+"_"+str(role)+"_v3"
			check(Sequence.has(id),id+" all original motifs have optimized state artwork")
			if Sequence.has(id): sheets[Sequence.specs()[id].file]=true
	check(moves==104 and identities.size()==20,"Every battle and all eight challenge guardians, including phase two, are covered")
	check(sheets.size()==68,"68 independently generated 3x3 images, no crowded multi-effect sheets")
	var warning: Dictionary={"shape":"lane","p":Vector2.ZERO,"aim":Vector2.RIGHT,"radius":350.0,"inner":25.0,"art_key":"furnace","vfx_role":"chain","fired":true,"time":-.6,"linger":1.5}
	var role := Sequence.resolve(warning,"chain")
	var a := Sequence.state(warning,.60,role); var b := Sequence.state(warning,.70,role)
	check(a.name=="sustain" and b.name=="sustain" and a.frame!=b.frame,"Continuous effects animate multiple real sustained frames")
	print("BOSS FULL EFFECT COVERAGE ",checks," checks / ",failures," failures; ",moves," moves / ",identities.size()," tables / ",sheets.size()," atlases")
	s.queue_free(); await process_frame; quit(1 if failures else 0)
