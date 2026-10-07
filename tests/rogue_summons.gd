extends SceneTree
## 引魂灵体的索敌回归（无头）。覆盖 2026-10-07 定下的三级索敌：
##   ① 主人的指令（普攻/战技/技能打中过的那只 → 集火；高→高 转火有 0.5 秒内置 CD，
##      从低优先升上来可立刻抢占；出圈也继续打完）
##   ② 主人大圈（600，圆心＝主人）→ ③ 灵体小圈（500，圆心＝灵体，低优先自保）
##   → ④ 都没有则回主人身边的待命位（每个灵体一个固定偏移）
## 并守住设计契约（ROGUE-BUILD-SYSTEM-DESIGN §7.12）：射程是一半/三分之后的 150、最多 2 个实体、
## 总预算 0.16P 按实体比例分配 —— 这几条一个都不许被这次改动动到。
const Build = preload("res://scripts/rogue_build.gd")

var s: TideSession
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

## 墓煜（hero 3）是召唤系主角；起一局魔境、清空场上怪，只留测试自己摆的。
func launch() -> Dictionary:
	s = TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":3,"mode":"roguelike"})
	s.launch(false,731)
	var p: Dictionary=s.players[1]
	var selection: Dictionary=p.rogue_selection
	if not selection.is_empty():
		s.perform(p.id,"rogue_selection_take",{"id":selection.id,"version":selection.version,"index":0})
	s.enemies.clear()
	return p

## 一只不动、不会还手、受击吸收全关的木桩（让灵体的伤害原样穿过）。
## 坐标一律取「地面通道中心线」上的点：`spawn_enemy` 对 radius 25 不通的位置会**静默拒绝**，
## 随手写个偏移会让两次 spawn 落到同一格、后一次直接不生成（那正是本用例第一版踩的坑）。
func dummy(x: float, hp: float = 400000.0) -> Dictionary:
	var before := s.enemies.size()
	var e := {"id": -1}
	s.spawn_enemy(Vector2(x,s.ruins.lane_center(x)),0)
	if s.enemies.size()==before:
		check(false,"木桩没生成：x=%.0f 不在可走地面上" % x)
		return {}
	e=s.enemies.back()
	s.roguelike.combat.setup_minion(e,0,0,false,s.rng)
	e.hp=hp; e.max_hp=hp; e.stagger=9999.0
	e.rogue_shield=0.0; e.guard_time=0.0; e.buff_time=0.0
	return e

func step(p: Dictionary, dt: float, frames: int) -> void:
	for i in frames:
		s.elapsed += dt
		Build.tick(s,p,dt)

## 主人打一下（普攻命中）——这就是"索敌指令"的入口。
func order(p: Dictionary, e: Dictionary) -> void:
	if e.is_empty():
		check(false,"order() 收到空目标：木桩没生成")
		return
	Build.hit_event(s,p,e,10.0,false,Build.context(s,p,"attack"))

func run() -> void:
	# ① 静默待命 + 槽位 + 上限
	var p := launch()
	Build.summon(s,p,20.0,.06)
	step(p,0.1,12)
	var soul: Dictionary=p.build_summons[0]
	check(soul.tier=="idle","① 没有敌人时是静默待命（tier=%s）" % soul.tier)
	check(soul.p.distance_to(Build.soul_idle_point(p,soul))<25.0,"① 灵体走回主人身边的待命位")
	Build.summon(s,p,20.0,.06)
	check(p.build_summons.size()==2 and int(p.build_summons[0].slot)!=int(p.build_summons[1].slot),"① 两个灵体占不同待命槽（不叠在一起）")
	Build.summon(s,p,20.0,.06)
	check(p.build_summons.size()==2,"① 上限仍然是 2 个实体（设计契约）")

	# ② 主人大圈里索敌、追到停靠距离、到位就开火
	p = launch()
	var far: Dictionary=dummy(p.p.x+250.0)
	check(s.enemies.size()==1,"② 木桩在场（场上只有它）")
	Build.summon(s,p,20.0,.06)
	step(p,0.1,10)
	var hunter: Dictionary=p.build_summons[0]
	check(hunter.tier=="seek","② 主人大圈内（%.0f≤%.0f）的怪会被主动索敌（tier=%s）" % [hunter.p.distance_to(p.p),Build.SOUL_SEEK,hunter.tier])
	check(int(hunter.target)==int(far.id),"② 目标就是那只怪")
	var gap: float=hunter.p.distance_to(far.p)
	step(p,0.1,40)
	gap=hunter.p.distance_to(far.p)
	check(gap<=Build.SOUL_KEEP+15.0,"② 追到停靠距离（%.0f）就停下" % gap)
	check(far.hp<far.max_hp,"② 到位后真的在打（木桩掉血 %d）" % int(far.max_hp-far.hp))

	# ①+③ 主人点名谁就集火谁，期间绝不碰别人
	p = launch()
	var a: Dictionary=dummy(p.p.x+160.0)
	var b: Dictionary=dummy(p.p.x+210.0)
	Build.summon(s,p,20.0,.06)
	order(p,b)
	step(p,0.1,3)
	var focus: Dictionary=p.build_summons[0]
	check(int(p.soul_focus)==int(b.id),"③ 主人打中的那只被记成索敌指令")
	check(focus.tier=="command" and int(focus.target)==int(b.id),"③ 灵体改打主人点名的那只（tier=%s target=%d）" % [focus.tier,int(focus.target)])
	var b_hp: float=b.hp
	var a_hp: float=a.hp
	step(p,0.1,25)
	check(b.hp<b_hp,"③ 伤害确实落在主人点名的 B 身上")
	check(is_equal_approx(a.hp,a_hp),"③ 集火期间一点都没碰 A（决策③的集火语义）")

	# ④ 高→高 转火要等 0.5 秒内置 CD；低优先升到高优先可以立刻抢占
	p = launch()
	var first: Dictionary=dummy(p.p.x+160.0)
	var second: Dictionary=dummy(p.p.x+210.0)
	Build.summon(s,p,20.0,.06)
	order(p,first)
	step(p,0.1,2)
	var lock: Dictionary=p.build_summons[0]
	check(int(lock.target)==int(first.id),"④ 先咬住主人点名的 first")
	var switched_at: float=float(lock.get("switch",-1.0))
	order(p,second)
	step(p,0.1,2)
	check(int(lock.target)==int(first.id),"④ CD 内（%.2fs）不跟新指令" % (s.elapsed-switched_at))
	step(p,0.1,4)
	check(int(lock.target)==int(second.id),"④ 过了 0.5 秒才转火 second")

	# ⑤ 主人撤出大圈：已点名的打完 → 灵体自己的小圈清杂 → 都没了回主人身边
	p = launch()
	var marked: Dictionary=dummy(p.p.x+260.0,200000.0)
	Build.summon(s,p,60.0,.06)
	order(p,marked)
	step(p,0.1,3)
	var lonely: Dictionary=p.build_summons[0]
	check(lonely.tier=="command" and int(lonely.target)==int(marked.id),"⑤ 先咬住被点名的怪")
	p.p = Vector2(p.p.x+1500.0,s.ruins.lane_center(p.p.x+1500.0))
	var stray: Dictionary=dummy(lonely.p.x+140.0)
	step(p,0.1,5)
	check(int(lonely.target)==int(marked.id),"⑤ 目标跑出主人 600 大圈也继续打（指令优先于圈）")
	marked.hp=0.0
	step(p,0.1,3)
	check(lonely.tier=="near" and int(lonely.target)==int(stray.id),"⑤ 点名的那只死了 → 用灵体自己的小圈清杂（tier=%s）" % lonely.tier)
	stray.hp=0.0
	var distance_before: float=lonely.p.distance_to(Build.soul_idle_point(p,lonely))
	step(p,0.1,25)
	check(lonely.tier=="idle","⑤ 小圈也没怪 → 回静默待命")
	check(lonely.p.distance_to(Build.soul_idle_point(p,lonely))<distance_before-100.0,"⑤ 而且确实在往主人身边移动")

	# ⑤b 指令接收是**全局**的：灵体跑到很远的地方追怪时，主人换点名仍然立刻生效（无距离门槛、无牵引）
	p = launch()
	var runner: Dictionary=dummy(p.p.x+240.0,200000.0)
	Build.summon(s,p,60.0,.06)
	step(p,0.1,10)
	var roam: Dictionary=p.build_summons[0]
	check(roam.tier=="seek" and int(roam.target)==int(runner.id),"⑤b 先在主人圈内咬住一只怪")
	order(p,runner)
	step(p,0.1,5)
	# 把主人挪到很远（灵体因此会被留在原地继续追 runner），再放一只新的怪并点名它
	p.p = Vector2(p.p.x+900.0,s.ruins.lane_center(p.p.x+900.0))
	step(p,0.1,20)
	check(roam.p.distance_to(p.p)>300.0,"⑤b 灵体此时已经离主人很远（%.0f，超过大圈 300）" % roam.p.distance_to(p.p))
	var newcomer: Dictionary=dummy(p.p.x+120.0,200000.0)
	order(p,newcomer)
	step(p,0.1,3)
	check(int(roam.target)==int(newcomer.id) and roam.tier=="command","⑤b 远处的灵体也立刻改打主人新点名的怪（tier=%s target=%d）" % [roam.tier,int(roam.target)])
	var before: float=roam.p.distance_to(newcomer.p)
	step(p,0.1,25)
	check(roam.p.distance_to(newcomer.p)<before-100.0,"⑤b 并且真的从远处往新目标赶（不许有牵引距离拦着）")

	# ⑥ 红线：射程 450、按实体比例分配、总预算 0.16P
	check(is_equal_approx(Build.SOUL_RANGE,150.0) and is_equal_approx(Build.SOUL_SEEK,300.0) and is_equal_approx(Build.SOUL_NEAR,166.7),"⑥ 半径 = 二轮拍板值：大圈 300（旧值一半）、射程 150 与小圈 166.7（旧值的 1/3）")
	p = launch()
	var post: Dictionary=dummy(p.p.x+200.0)
	Build.summon(s,p,60.0,.06)
	step(p,0.1,3)
	var single: float=Build.unit(s,p)*.06
	var deltas: Array=[]
	var last: float=post.hp
	for i in 25:
		step(p,0.1,1)
		if post.hp<last:
			deltas.append(last-post.hp)
			last=post.hp
	check(not deltas.is_empty(),"⑥ 单灵体每秒结算了一次")
	var exact: bool=true
	for d in deltas:
		if absf(float(d)-single)>single*.02: exact=false
	check(exact,"⑥ 单灵体（ratio .06）每次结算正好是 0.06P（%s vs %.1f）" % [str(deltas),single])
	Build.summon(s,p,60.0,.10)
	step(p,0.1,3)
	var small: float=Build.unit(s,p)*.06
	var big: float=Build.unit(s,p)*.10
	var both: Array=[]
	last=post.hp
	for i in 25:
		step(p,0.1,1)
		if post.hp<last:
			both.append(last-post.hp)
			last=post.hp
	var sum_ok: bool=true
	for d in both:
		if absf(float(d)-small)>small*.02 and absf(float(d)-big)>big*.02: sum_ok=false
	check(sum_ok,"⑥ 两只灵体（.06+.10）各按自己的比例结算，总和不超 0.16P（%s）" % str(both))
	check(both.size()>=2,"⑥ 两只灵体都在开火")
	check(p.build_summons.size()==2,"⑥ 依然只有 2 个实体")

	s.queue_free()
	await process_frame
	print("ROGUE SUMMONS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
