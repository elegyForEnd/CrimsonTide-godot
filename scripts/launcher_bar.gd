extends Control
## 启动器进度条的画法：**程序化**描金边框 + 血红→金的渐变填充。
##
## 为什么不用贴图（用户原本建议用背包界面的边框素材）：这条进度条恰恰出现在
## "资源还没导入"的那一刻——首次下载时 `.godot/imported` 是空的，一张 PNG 都
## 加载不出来，用真素材必然是一片空白。色值抄自 `gothic_button.gd` / `camp_pack.gd`
## （金 `#cbb087`、血红、永夜黑），所以风格和游戏内面板同源。
##
## 2026-10-19：改成**一个框、两行条**（用户要求："原来的大的进度条在上并且位置不变，
## 子进度条在下面适当间距，不用单独给子进度条加边框，就放在原边框里面把边框大小
## 适配新的布局"）。所以框高从 36 变成 62：主条 25px 在上，子条 8px 在下，
## 共用同一圈描金边框与四角菱形——子条自己不带任何边框。

const GOLD := Color("cbb087")
const INK := Color("ede5d8")
const TRACK := Color("0d0a12")
const BLOOD := Color("6d0f1c")

## 框内布局。⚠️ 与 `boot.gd` 的 `BAR_SIZE`（760×62）是一套，改一边必须改另一边：
## 11(上留白) + 25(主条) + 6(行距) + 8(子条) = 50，剩下 12 是下留白。
const PAD := 11.0
const MAIN_H := 25.0
const GAP := 6.0
const SUB_H := 8.0

var ratio := 0.0
## 子条：当前正在推进的那一个导入阶段（见 `boot.gd: _update_sub_progress()`）。
var sub_ratio := 0.0
var pulse := 0.0

## 这个框"至少要这么高"才装得下两行：11(上留白)+25(主条)+6(行距)+8(子条)+12(下留白)。
## `boot.gd` 的 `BAR_SIZE.y` 必须 ≥ 它（回归测试 `tests/launcher_progress.gd` 钉住）。
static func needed_height() -> float:
	return PAD+MAIN_H+GAP+SUB_H+12.0

func set_ratio(value: float) -> void:
	ratio=clampf(value,0.0,1.0)
	queue_redraw()

func set_sub_ratio(value: float) -> void:
	sub_ratio=clampf(value,0.0,1.0)
	queue_redraw()

func _process(dt: float) -> void:
	# 只有加载页会挂这个控件：给填充一点呼吸，别让它看起来像卡住了。
	pulse=fmod(pulse+dt*0.9,TAU)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w<=0.0 or h<=0.0:
		return
	# 底板 + 双层描金（整框只画这一圈：主条和子条都在它里面）
	draw_rect(Rect2(Vector2.ZERO,size),Color(TRACK,0.94),true)
	draw_rect(Rect2(Vector2(1.5,1.5),size-Vector2(3.0,3.0)),Color(GOLD,0.9),false,3.0)
	draw_rect(Rect2(Vector2(7.0,7.0),size-Vector2(14.0,14.0)),Color(GOLD,0.26),false,1.0)
	# 四角菱形（与哥特按钮的菱形装饰同源）
	var r := 7.0
	for corner in [Vector2(1.5,1.5),Vector2(w-1.5,1.5),Vector2(1.5,h-1.5),Vector2(w-1.5,h-1.5)]:
		draw_polyline(PackedVector2Array([
			corner+Vector2(0.0,-r),corner+Vector2(r,0.0),corner+Vector2(0.0,r),
			corner+Vector2(-r,0.0),corner+Vector2(0.0,-r)]),Color(GOLD,0.95),1.6,true)
	var inner_w := maxf(0.0,w-PAD*2.0)
	var main := Rect2(Vector2(PAD,PAD),Vector2(inner_w,MAIN_H))
	var sub := Rect2(Vector2(PAD,PAD+MAIN_H+GAP),Vector2(inner_w,SUB_H))
	draw_rect(main,Color(0.03,0.02,0.04,0.85),true)
	draw_rect(sub,Color(0.03,0.02,0.04,0.9),true)
	if inner_w<=0.0:
		return
	var glow := 0.84+0.16*sin(pulse)
	# 主条：血红 → 金 的渐变切片 + 呼吸
	var steps := 120
	for i in steps:
		var t := float(i)/float(steps)
		if t>ratio:
			break
		var color := BLOOD.lerp(GOLD,clampf(0.12+t*0.98,0.0,1.0))
		color.a=glow
		draw_rect(Rect2(main.position.x+t*main.size.x,main.position.y,
			main.size.x/float(steps)+1.0,main.size.y),color,true)
	# 主条前端高光
	if ratio>0.002:
		var x := main.position.x+ratio*main.size.x
		draw_rect(Rect2(x-1.5,main.position.y-1.0,3.0,main.size.y+2.0),Color(INK,0.7),true)
	# 子条：细、暗金、跟着大框走（不单独描边）；它存在的意义是"主条不动的时候还在动"
	var sub_color := GOLD
	sub_color.a=0.5+0.14*sin(pulse*1.7)
	if sub_ratio>0.004:
		draw_rect(Rect2(sub.position,Vector2(maxf(1.5,sub.size.x*sub_ratio),sub.size.y)),sub_color,true)
		var sx := sub.position.x+sub.size.x*sub_ratio
		draw_rect(Rect2(sx-1.0,sub.position.y-1.0,2.0,sub.size.y+2.0),Color(INK,0.55),true)
