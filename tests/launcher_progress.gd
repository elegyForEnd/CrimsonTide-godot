extends SceneTree

## 启动器进度条（主条 + 分阶段子条）回归。
##
## 钉住的是四件事：
##   ① 条目折算系数：**实测** 7248 条目 / 4138 资源 = 1.75。旧值 2.1 会把主条
##      压到最多 83% 再跳 100%（"结尾猛跳"），这个数必须钉死。
##   ② `entry_counts_by_type()` 真能按扩展名分组（子条的数据源）。
##   ③ 阶段切换：哪个阶段在动就显示哪个；55 张 HDR 背景走完 12/55 时子条必须
##      是 0.218，而不是一直停在 0 —— 这是"卡在 1%"那个投诉的正解。
##   ④ 框内布局：主条 + 子条必须装得进同一个描金框（`Bar.needed_height()`）。
##
## 只读，不写工程里的任何文件；`boot.gd` 的实例不挂进树、不拉子进程。

var checks := 0
var failures := 0

const Env = preload("res://scripts/launcher_env.gd")
const Bar = preload("res://scripts/launcher_bar.gd")
const Boot = preload("res://scripts/boot.gd")

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	_test_entry_counts()
	_test_progress_math()
	_test_bar_layout()
	_test_phase_flow()
	_test_flavor_tone()
	_test_layout_scales()
	print("launcher_progress: %d checks, %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)

## `~` 只给轻松/日常/氛围句；预言、威胁、死亡意象不带（用户 2026-10-19 第 2 轮）。
## 这里用 XOR 钉：带 `~` 的不能出现在严肃清单里，严肃清单里的必须不带。
func _test_flavor_tone() -> void:
	var serious := [
		"鸦羽说，斩血潮者必先沾血",
		"血香散出去之后，异兽总会来",
		"白骨王座上的钟摆，有人正在拨动",
	]
	check(Boot.FLAVOR.size()==15,"文案应当还是 15 句，实际 %d" % Boot.FLAVOR.size())
	for line in Boot.FLAVOR:
		var text := str(line)
		check(text.ends_with("~") != serious.has(text),
			"轻松句必须带 ~、严肃句必须不带：「%s」" % text)

## 布局必须跟着**画布**走：工程是 canvas_items + expand，大屏/宽屏下画布比 1440 宽，
## 写死 1440 就会"PV 铺满、进度条缩在左边"（用户 2026-10-19 第 3 轮报的就是这个）。
func _test_layout_scales() -> void:
	for canvas in [Vector2(1440,900),Vector2(1467,900),Vector2(1600,900),Vector2(1920,900)]:
		var layout := Boot.launcher_layout(canvas)
		var bar_size: Vector2 = layout["bar_size"]
		check(absf(bar_size.x/canvas.x-760.0/1440.0)<0.02,
			"条子宽度应恒占画布 %.3f，%s 下是 %.3f" % [760.0/1440.0,canvas,bar_size.x/canvas.x])
		var bar_pos: Vector2 = layout["bar_pos"]
		check(absf(bar_pos.x+bar_size.x*0.5-canvas.x*0.5)<0.5,
			"%s 下条子必须水平居中（偏了 %.1f）" % [canvas,bar_pos.x+bar_size.x*0.5-canvas.x*0.5])
		# 静音按钮贴右上角，右边距恒为 30×scale（不再是一个固定的 1440 框里的位置）
		var mute_size: Vector2 = layout["mute_size"]
		var mute_pos: Vector2 = layout["mute_pos"]
		var scale: float = layout["scale"]
		check(absf(canvas.x-(mute_pos.x+mute_size.x)-30.0*scale)<0.5,
			"%s 下静音按钮右边距不对（差 %.1f）" % [canvas,canvas.x-(mute_pos.x+mute_size.x)-30.0*scale])
		check(absf(mute_pos.y-30.0*scale)<0.5,"静音按钮上边距应随 scale 走")
	# 窄窗：scale 有下限，条子不能被压没
	var narrow := Boot.launcher_layout(Vector2(720,900))
	check(float((narrow["bar_size"] as Vector2).x)/720.0>=0.5,"窄窗下条子仍要占过半宽度")

func _test_entry_counts() -> void:
	var counts := Env.entry_counts_by_type()
	check(counts.has("ctex"),"`.godot/imported` 里应当有 .ctex 条目（本仓库已导入）")
	check(int(counts.get("ctex",0))>1000,"贴图条目上不了千说明列目录/扩展名解析坏了")
	var total := 0
	for key in counts:
		total+=int(counts[key])
	check(total>5000,"总条目数应大于 5000（实测 7248），拿到 %d" % total)
	check(not counts.has(""),"不该出现没有扩展名的裸文件分组（.md5 之外）")

func _test_progress_math() -> void:
	check(is_equal_approx(Env.entries_per_asset(),1.75),"折算系数必须是实测的 1.75")
	# 4138 资源 × 1.75 = 7248 条目 → 满格（clamp 到 0.98，收尾那一下留给 _finish_compile）
	var report := {"total_assets":4138}
	var full := {"ctex":5672,"scn":612,"sample":782,"oggvorbisstr":66,"fontdata":6}
	check(is_equal_approx(Env.progress(report,full),0.98),"7248 条目应当顶到 0.98")
	var half := {"ctex":3624}
	check(absf(Env.progress(report,half)-0.5)<0.01,
		"3624 条目应当约 50%%，实际 %.3f" % Env.progress(report,half))

func _test_bar_layout() -> void:
	var need := Bar.needed_height()
	check(need<=62.0,"两行条必须装得进 62px 的框（现在要 %.0f）" % need)
	check(Bar.MAIN_H>Bar.SUB_H,"主条要比子条粗，否则分不清主次")
	check(Boot.bar_frame_ok(),"`boot.gd` 的 BAR_SIZE 装不下主条+子条（两份布局常量对不上）")

func _test_phase_flow() -> void:
	var boot = load("res://scripts/boot.gd").new()
	boot.bar=Bar.new()
	boot.bar.size=Vector2(760,62)
	boot.sub_label=Label.new()
	# 造一份"还缺 55 张 HDR 背景 + 8 张贴图"的清单（不起子进程、不碰盘）。
	var pending: Array = []
	for i in 55:
		pending.append("res://.godot/imported/hdr%d.bptc.ctexarray" % i)
	for i in 8:
		pending.append("res://.godot/imported/tex%d.s3tc.ctex" % i)
	boot.env_report={"total_assets":4200,"pending":pending}
	boot._prepare_phases()
	check(boot.phases.size()==2,"阶段表应当拆成 ctexarray + ctex 两组，实际 %d" % boot.phases.size())

	# 模拟：主条几乎不动（总条目数只涨了 12），但 HDR 背景在推进。
	var base := Env.entry_counts_by_type()
	var base_total := 0
	for key in base:
		base_total+=int(base[key])
	var counts := base.duplicate()
	counts["ctexarray"]=int(base.get("ctexarray",0))+12
	counts["ctex"]=int(base.get("ctex",0))+8
	# 条目数要比基线多，才测得出"剩余时间"（速率 0 时界面故意不写 ETA）；
	# `total_assets` 按真实条目数反推，否则 ETA 会被算成"已经超额完成"→ 只显示"即将完成"。
	boot.env_report["total_assets"]=int(float(base_total+400)/Env.entries_per_asset())
	boot._update_sub_progress(counts,base_total+12,0.35,true)
	check(boot.phase_pick=="ctexarray","正在动的是 HDR 环境贴图这一组")
	check(absf(boot.bar.sub_ratio-12.0/55.0)<0.001,
		"子条应当是 12/55 = 0.218，实际 %.3f" % boot.bar.sub_ratio)
	check(boot.sub_label.text.contains("12/55"),"小字要写出 12/55，实际「%s」" % boot.sub_label.text)
	check(boot.sub_label.text.contains("剩余"),"有速率时要给剩余时间，实际「%s」" % boot.sub_label.text)

	# 走满：子条到 1.0，且不再把这一组当"在动"
	counts["ctexarray"]=int(base.get("ctexarray",0))+55
	boot._update_sub_progress(counts,base_total+55,0.35,true)
	check(is_equal_approx(boot.bar.sub_ratio,1.0),"55/55 之后子条满格")

	# 子进程退出：两条都满，小字换成"资源已就绪"
	boot._update_sub_progress(counts,base_total+55,0.35,false)
	check(is_equal_approx(boot.bar.sub_ratio,1.0),"子进程结束后子条满格")
	check(boot.sub_label.text=="资源已就绪","结束文案应当是「资源已就绪」，实际「%s」" % boot.sub_label.text)
	# 这个用例自己造了三个节点、没挂进树，退出前收干净（否则引擎报 RID 泄漏）。
	boot.bar.free()
	boot.sub_label.free()
	boot.free()
