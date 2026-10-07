extends SceneTree
## 引魂灵体索敌的**可视化预览**（要真窗口，命名 `*_visual`）。
## 出图：build/rogue-summons-1-idle.png / -2-seek.png / -3-command.png / -4a-cd.png / -4b-relock.png
## 半径覆盖层由 `SHOW_RANGES` 控制，**默认 false**：正式对局不显示任何判定圈。
## 打开时：青圈 = 主人大圈 300，紫圈 = 灵体自己的低优先圈 166.7，黄圈 = 灵体射程 150，
## 细红线 = 这只灵体当前锁定的目标。
const Build = preload("res://scripts/rogue_build.gd")
## 半径覆盖层只在**开发预览**里画，默认关闭：正式对局（搜打撤/魔境）里一个判定圈都不显示。
## 想让这张图帮你核对半径时把它改成 true 再跑（出图仅开发用，见工作区上一层的 任务.md）。
const SHOW_RANGES := false
var app
var caption: Label

class Ranges extends Node2D:
	var field
	func _process(_dt: float) -> void: queue_redraw()
	func _draw() -> void:
		if not SHOW_RANGES: return
		var s=field.session
		draw_set_transform(-field.camera_offset())
		var font := ThemeDB.fallback_font
		for actor in s.players.values():
			var souls: Array=actor.get("build_summons",[])
			if souls.is_empty(): continue
			draw_arc(actor.p,Build.SOUL_SEEK,0,TAU,96,Color(.45,.85,1,.55),2.0,true)
			draw_string(font,actor.p+Vector2(-60,Build.SOUL_SEEK+22),"主人大圈 600",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(.6,.9,1,.9))
			for soul in souls:
				draw_arc(soul.p,Build.SOUL_NEAR,0,TAU,72,Color(.8,.6,1,.42),1.5,true)
				draw_arc(soul.p,Build.SOUL_RANGE,0,TAU,64,Color(1,.92,.45,.34),1.0,true)
				var e: Dictionary=Build.enemy_by_id(s,int(soul.get("target",-1)))
				if not e.is_empty(): draw_line(soul.p,e.p,Color(1,.42,.42,.75),2.0)
				draw_string(font,soul.p+Vector2(-52,-64),str(soul.get("tier","")),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(.85,.85,1,.95))

func _initialize() -> void: call_deferred("run")

func dummy(x: float) -> Dictionary:
	var before: int=app.session.enemies.size()
	app.session.spawn_enemy(Vector2(x,app.session.ruins.lane_center(x)),0)
	var e: Dictionary=app.session.enemies.back()
	app.session.roguelike.combat.setup_minion(e,0,0,false,app.session.rng)
	e.hp=4000.0; e.max_hp=4000.0; e.stagger=9999.0
	return e

func shoot(path: String, text: String, settle: float = 0.08) -> void:
	caption.text=text
	await create_timer(settle).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("SHOT ",path)
	dump(text)

## 每张图都打一行状态，免得只靠眼睛判断"它到底锁了谁"。
func dump(tag: String) -> void:
	var p: Dictionary=app.session.players[1]
	var rows: Array=[]
	for e in app.session.enemies:
		rows.append("#%d x=%.0f hp=%.0f" % [int(e.id),float(e.p.x),float(e.hp)])
	var souls: Array=[]
	for soul in p.build_summons:
		souls.append("[slot %d target %d %s sw=%.2f]" % [int(soul.get("slot",-1)),int(soul.get("target",-1)),str(soul.get("tier","")),float(soul.get("switch",0.0))])
	print("  t=%.2f focus=%d  %s  | %s  | %s" % [app.session.elapsed,int(p.soul_focus),str(souls),str(rows),tag])

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-summons-preview.json"
	root.add_child(app)
	await process_frame
	app.session.solo({"hero":3,"mode":"roguelike"})
	app.session.launch(false,1729)
	# 注意：这里**不能** `set_physics_process(false)` —— 灵体是在 `session.simulate()` 里
	# 每帧 `RogueBuild.tick()` 推的，冻住物理进程它们就一格都不动（本预览第一版就踩了这个）。
	app.session.raid.floor=1
	app.session.raid.area=1
	app.session.roguelike.new_floor(app.session)
	app.session.roguelike.enter(app.session)
	app.session.enemies.clear()
	var p: Dictionary=app.session.players[1]
	var map=app.session.ruins
	p.p=Vector2(900,map.lane_center(900))
	p.invuln=999
	var ranges := Ranges.new()
	ranges.field=app.rogue_field
	app.rogue_field.add_child(ranges)
	caption=Label.new()
	caption.add_theme_font_size_override("font_size",26)
	caption.add_theme_color_override("font_color",Color(1,.95,.85))
	caption.position=Vector2(36,116)
	caption.size=Vector2(900,40)
	app.add_child(caption)
	await create_timer(.4).timeout

	# ① 静默待命：两个灵体守在主人两侧
	Build.summon(app.session,p,60.0,.06)
	Build.summon(app.session,p,60.0,.10)
	await create_timer(.8).timeout
	await shoot("res://build/rogue-summons-1-idle.png","① 静默待命：两个灵体守在主人两侧（待命槽 左/右）")

	# ② 主人大圈内出现 3 只怪 → 灵体自己追上去，到位开火
	var mobs: Array=[]
	for x in [1050.0,1120.0,1190.0]: mobs.append(dummy(x))
	await create_timer(3.2).timeout
	await shoot("res://build/rogue-summons-2-seek.png","② 主人大圈(300)内 3 只怪：灵体主动追击、到射程 85% 停下开火")

	# ③ 主人点名**最远**那只 → 两只灵体一起集火它（证明不是"谁近打谁"）
	Build.hit_event(app.session,p,mobs[2],10.0,false,Build.context(app.session,p,"attack"))
	await shoot("res://build/rogue-summons-3-command.png","③ 主人打了最远那只 → 两只灵体集火它（更近的那两只被无视）",0.25)

	# ④ 0.5 秒内又改点中间那只：先不跟；过了 CD 才一起转火
	var locked: int=int(p.build_summons[0].get("target",-1))
	Build.hit_event(app.session,p,mobs[1],10.0,false,Build.context(app.session,p,"attack"))
	await shoot("res://build/rogue-summons-4a-cd.png","④a 紧接着改点中间那只：还在 0.5 秒索敌 CD 里，仍咬着最远那只",0.15)
	print("CD 判定：4a 仍锁 #%d（期望 #%d）→ %s  ·  elapsed=%.2f  switch=%.2f" % [
		int(p.build_summons[0].get("target",-1)),locked,
		"OK" if int(p.build_summons[0].get("target",-1))==locked else "FAIL",
		app.session.elapsed,float(p.build_summons[0].get("switch",0.0))])
	await shoot("res://build/rogue-summons-4b-relock.png","④b CD 过后：两只灵体一起转火到中间那只",0.80)
	app.queue_free()
	await process_frame
	print("SUMMONS PREVIEW DONE")
	quit()
