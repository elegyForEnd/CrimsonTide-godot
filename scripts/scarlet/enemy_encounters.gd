extends RefCounted
## Optional field fights; no extra quest or mandatory ending dependency.
const PATROLS={
	"1:2":{"label":"清理巷口晶兽","at":Vector2(1320,810),"types":["tide_hound","crystal_husk","tide_hound"]},
	"2:4":{"label":"解除档案庭封卷队","at":Vector2(1290,790),"types":["royal_pikeman","archive_scribe","royal_arbalist"]},
	"3:3":{"label":"驱离废矿潜猎兽","at":Vector2(1320,880),"types":["crystal_stalker","crystal_husk","crystal_stalker"]},
	"4:2":{"label":"停下失控手术偶","at":Vector2(1280,850),"types":["suture_puppet","suture_puppet","archive_scribe"]},
	"5:3":{"label":"解除舷梯登船队","at":Vector2(1330,850),"types":["anchor_raider","royal_arbalist","anchor_raider"]},
	"6:3":{"label":"突破王庭封锁队","at":Vector2(1280,860),"types":["royal_pikeman","archive_scribe","suture_puppet"]}}
static func nodes(c) -> Array:
	if not PATROLS.has(c.state.zone) or c.combat.running or not c.escort_group.is_empty() or not c.state.trial_task.is_empty() or c.state.ending_seen: return []
	var key: String="patrol:"+c.state.zone
	if c.state.world.get("cleared:"+key,false): return []
	var info: Dictionary=PATROLS[c.state.zone]
	return [{"id":key,"kind":"enemy_patrol","label":info.label+" · 可选战斗 [E]","p":c.place(info.at)}]
static func use(c,n: Dictionary) -> bool:
	var available:=nodes(c)
	if available.is_empty() or n.id!=available[0].id or c.hero_at.distance_to(available[0].p)>c.INTERACT_RADIUS: return false
	var info: Dictionary=PATROLS[c.state.zone]
	c.combat.start("",n.id,"",info.types.size(),false,info.types)
	c.combat.context.patrol=n.id
	c.combat.context.anchor=[available[0].p.x,available[0].p.y]
	c.combat.place_patrol(available[0].p)
	c.save_campaign()
	c.notice.emit("可选遭遇："+info.label+"。起手有预警，收招可反击；按 B 查看已见敌人。")
	return true
