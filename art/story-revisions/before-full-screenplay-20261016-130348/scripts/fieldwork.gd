extends RefCounted
## Authoritative, resumable field interactions. UI and models never advance quests.
signal opened
signal updated
signal closed
const DATA_PATH := "res://resources/scarlet/fieldwork.json"
const SCAN_SECONDS := .85
const WORK_SECONDS := 1.15
var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
var owner_ref: WeakRef
var campaign:
	get: return owner_ref.get_ref()
var active: Dictionary = {}
var selected := -1
var progress := 0.0
var clock := 0.0
var flash := 0.0
var feedback := ""
var feedback_good := false
var alignment := .08
var tension := .08
var was_holding := false

func _init(owner) -> void: owner_ref=weakref(owner)

func supports(node: Dictionary) -> bool:
	return profiles.has(str(node.get("id","")))

func record(id: String) -> Dictionary:
	return campaign.state.get("fieldwork",{}).get(id,{"done":[],"finished":false})

func start(node: Dictionary) -> bool:
	if not active.is_empty() or not supports(node): return false
	var qid: String=node.get("qid","")
	if not campaign.content.quests.has(qid): return false
	var canonical: Dictionary=campaign.current_node(campaign.content.quests[qid]).duplicate(true)
	if canonical.get("id","")!=node.get("id",""): return false
	canonical.qid=qid; canonical.p=campaign.place(Vector2(canonical.at[0],canonical.at[1]))
	if not valid_target(canonical): return false
	active=canonical; selected=-1; progress=0; clock=0; flash=0; alignment=.08; tension=.08; was_holding=false
	feedback="点击图中编号，或按 1 / 2 / 3 选择部位。已查明的细节可以随时回看。" if profile().mode=="survey" else "现场没有倒计时。先观察结构，再按安全顺序动手。"
	feedback_good=false
	campaign.moving=false; campaign.sprinting=false
	if campaign.hero_at.distance_to(canonical.p)>.01: campaign.facing=campaign.hero_at.direction_to(canonical.p)
	opened.emit(); return true

func valid_target(node: Dictionary) -> bool:
	var c=campaign
	if not c.state.pending.is_empty() or c.combat.running or c.action_time>0 or c.dodge_time>0: return false
	if not c.escort_group.is_empty() or not c.state.trial_task.is_empty(): return false
	var qid: String=node.get("qid","")
	if not c.content.quests.has(qid): return false
	var q: Dictionary=c.content.quests[qid]
	if q.kind!="main" and not qid in c.state.accepted: return false
	if q.kind=="main" and qid!=c.current_main().get("id",""): return false
	var current: Dictionary=c.current_node(q)
	var hero: int=int(current.get("hero",-1))
	if hero>=0 and int(c.state.hero)!=hero: return false
	if current.get("kind","")=="approach" and c.state.choices.get("palace_approach","front")!="side": return false
	if current.get("kind","")=="optional_boss" and not c.state.world.get("tide_ended",false): return false
	return c.available(q) and current.get("id","")==node.id and current.get("zone","")==c.state.zone and c.hero_at.distance_to(node.p)<=c.INTERACT_RADIUS

func profile() -> Dictionary: return profiles.get(str(active.get("id","")),{})
func done() -> Array: return record(str(active.get("id",""))).done
func ready() -> bool: return not active.is_empty() and done().size()==profile().parts.size()
func relaxed() -> bool: return bool(campaign.state.get("fieldwork_relaxed",false))
func set_relaxed(value: bool) -> void:
	campaign.state.fieldwork_relaxed=value; campaign.save_campaign(); updated.emit()
func needle() -> float:
	if challenge()=="alignment": return alignment
	if challenge()=="tension": return tension
	return .5+.48*sin(clock*(.9 if relaxed() else 1.7)-PI*.5)
func challenge() -> String: return str(profile().get("challenge","timing"))
func adjust(delta: float) -> void:
	if calibration() and challenge()=="alignment": alignment=clampf(alignment+delta,0,1)
func band() -> Vector2:
	var center: float=[.36,.64,.46][done().size()%3]
	var half: float=.23 if relaxed() else .13
	return Vector2(center-half,center+half)
func calibration() -> bool:
	return not active.is_empty() and selected>=0 and not selected in done() and int(profile().get("calibrate",-1))==selected

func select_part(index: int) -> bool:
	if active.is_empty() or index<0 or index>=profile().parts.size(): return false
	if index in done():
		selected=index; feedback=str(profile().parts[index].result); feedback_good=true; updated.emit(); return true
	if profile().mode!="survey" and index!=done().size():
		feedback=profile().hint+"\n先完成「"+str(profile().parts[done().size()].name)+"」。"
		feedback_good=false; flash=.4; campaign.audio_cue.emit("equip"); updated.emit(); return false
	selected=index; progress=0; was_holding=false; tension=.08; alignment=.08
	feedback="尚未读出的细节不会记入线索袋。" if profile().mode=="survey" else "已固定的工序会自动保留。暂离后，可以回到这里继续。"; feedback_good=false
	updated.emit(); return true

func press() -> bool:
	if not calibration() or flash>0 or not valid_target(active): return false
	if challenge()=="tension": return false
	var window:=band(); var position:=needle()
	if position<window.x or position>window.y:
		feedback="还未对准安全区。按 A / D 微调后再确认。" if challenge()=="alignment" else "还未对准安全区。等指针进入青色区间，再按 E 或点击校准。"
		feedback_good=false; flash=.35; updated.emit(); return false
	finish_part(); return true

func tick(dt: float, holding: bool) -> void:
	if active.is_empty(): return
	if not valid_target(active): cancel(); return
	dt=clampf(dt,0,.05); clock+=dt; flash=maxf(0,flash-dt)
	if selected<0 or selected in done() or ready(): return
	if calibration():
		if challenge()=="tension":
			if holding:
				tension+=dt*(.24 if relaxed() else .36)
				if tension>.98:
					tension=.08; flash=.35; feedback="受力过紧，绳索回弹。重新收紧，在青色区间松开。"; feedback_good=false; updated.emit()
			elif was_holding:
				var window:=band()
				if tension>=window.x and tension<=window.y: finish_part()
				else: feedback="张力尚未稳定。再试一次，在青色区间松开。"; feedback_good=false; updated.emit()
			if not holding: tension=maxf(.08,tension-dt*.3)
			was_holding=holding
		return
	if holding:
		progress=minf(1,progress+dt/(SCAN_SECONDS if profile().mode=="survey" else WORK_SECONDS))
		if progress>=1: finish_part()
	else: progress=maxf(0,progress-dt*.75)

func finish_part() -> void:
	if selected<0 or selected in done() or not valid_target(active): return
	var entry: Dictionary=record(active.id).duplicate(true)
	entry.done.append(selected)
	campaign.state.fieldwork[active.id]=entry
	feedback=str(profile().parts[selected].result); feedback_good=true; progress=1; flash=.45
	campaign.audio_cue.emit("equip" if profile().mode=="survey" else "reload-end")
	campaign.save_campaign(); updated.emit()

func submit() -> bool:
	if not ready() or not valid_target(active): return false
	var node:=active.duplicate(true)
	var entry: Dictionary=record(node.id).duplicate(true); entry.finished=true
	campaign.state.fieldwork[node.id]=entry
	active={}; closed.emit()
	campaign.audio_cue.emit("chest")
	campaign.combat_event.emit({"kind":"fieldwork_complete","p":node.p,"label":node.label})
	if node.kind=="clue":
		campaign.state.facts[node.fact]=true
		campaign.present({"kind":"scene","id":"clue:"+node.fact,"title":node.label,"pages":[{"speaker":"调查记录","actor":"","text":node.text,"expression":"neutral"}],"choices":[],"after":{"kind":"step","qid":node.qid,"node":node.id}})
	else: campaign.advance_step(node.qid,node.id)
	campaign.save_campaign(); return true

func cancel() -> void:
	if active.is_empty(): return
	active={}; selected=-1; progress=0; closed.emit()
	campaign.save_campaign()

func reset() -> void:
	active={}; selected=-1; progress=0; clock=0; flash=0

func summary(node: Dictionary) -> String:
	if not supports(node): return ""
	var p: Dictionary=profiles[node.id]
	return ("现场调查" if p.mode=="survey" else "分步操作")+" · "+str(record(node.id).done.size())+" / "+str(p.parts.size())
