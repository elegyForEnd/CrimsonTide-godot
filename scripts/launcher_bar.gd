extends Control
## 启动器进度条的画法：**程序化**描金边框 + 血红→金的渐变填充。
##
## 为什么不用贴图（用户原本建议用背包界面的边框素材）：这条进度条恰恰出现在
## "资源还没导入"的那一刻——首次下载时 `.godot/imported` 是空的，一张 PNG 都
## 加载不出来，用真素材必然是一片空白。色值抄自 `gothic_button.gd` / `camp_pack.gd`
## （金 `#cbb087`、血红、永夜黑），所以风格和游戏内面板同源。

const GOLD := Color("cbb087")
const INK := Color("ede5d8")
const TRACK := Color("0d0a12")
const BLOOD := Color("6d0f1c")

var ratio := 0.0
var pulse := 0.0

func set_ratio(value: float) -> void:
	ratio=clampf(value,0.0,1.0)
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
	# 底板 + 双层描金
	draw_rect(Rect2(Vector2.ZERO,size),Color(TRACK,0.94),true)
	draw_rect(Rect2(Vector2(1.5,1.5),size-Vector2(3.0,3.0)),Color(GOLD,0.9),false,3.0)
	draw_rect(Rect2(Vector2(7.0,7.0),size-Vector2(14.0,14.0)),Color(GOLD,0.26),false,1.0)
	# 四角菱形（与哥特按钮的菱形装饰同源）
	var r := 7.0
	for corner in [Vector2(1.5,1.5),Vector2(w-1.5,1.5),Vector2(1.5,h-1.5),Vector2(w-1.5,h-1.5)]:
		draw_polyline(PackedVector2Array([
			corner+Vector2(0.0,-r),corner+Vector2(r,0.0),corner+Vector2(0.0,r),
			corner+Vector2(-r,0.0),corner+Vector2(0.0,-r)]),Color(GOLD,0.95),1.6,true)
	# 内槽
	var track := Rect2(Vector2(11.0,11.0),Vector2(maxf(0.0,w-22.0),maxf(0.0,h-22.0)))
	draw_rect(track,Color(0.03,0.02,0.04,0.85),true)
	if track.size.x<=0.0:
		return
	# 填充：血红 → 金 的渐变切片 + 呼吸
	var steps := 120
	var glow := 0.84+0.16*sin(pulse)
	for i in steps:
		var t := float(i)/float(steps)
		if t>ratio:
			break
		var color := BLOOD.lerp(GOLD,clampf(0.12+t*0.98,0.0,1.0))
		color.a=glow
		draw_rect(Rect2(track.position.x+t*track.size.x,track.position.y,
			track.size.x/float(steps)+1.0,track.size.y),color,true)
	# 前端高光
	if ratio>0.002:
		var x := track.position.x+ratio*track.size.x
		draw_rect(Rect2(x-1.5,track.position.y-1.0,3.0,track.size.y+2.0),Color(INK,0.7),true)
