extends Button
## 启动器右上角的**圆形**静音按钮：只关 PV 的音量，设置存本地（重启也记得）。
##
## 图标程序化画，理由与 `launcher_bar.gd` 相同：它要在"资源还没导入、一张贴图都
## 加载不出来"的那一刻就能画出来。`focus_mode` 必须是 NONE——否则空格/回车会被这个
## 按钮吃掉，玩家在"点击任意键开始游戏"那一步按空格就变成切换静音了。

var muted := false

func _init() -> void:
	focus_mode=Control.FOCUS_NONE
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())

func set_muted(value: bool) -> void:
	muted=value
	queue_redraw()

func _draw() -> void:
	var center := size*0.5
	var radius := minf(size.x,size.y)*0.5-2.0
	if radius<=0.0:
		return
	var hot := is_hovered()
	draw_circle(center,radius,Color(0.04,0.03,0.06,0.8))
	draw_arc(center,radius,0.0,TAU,64,Color("cbb087",0.98 if hot else 0.62),2.0,true)
	var ink := Color("ede5d8")
	var s := radius*0.46
	# 喇叭：方箱 + 圆锥（两个凸多边形，避开凹多边形三角化的坑）
	draw_colored_polygon(PackedVector2Array([
		center+Vector2(-s*1.0,-s*0.34),center+Vector2(-s*0.42,-s*0.34),
		center+Vector2(-s*0.42,s*0.34),center+Vector2(-s*1.0,s*0.34)]),ink)
	draw_colored_polygon(PackedVector2Array([
		center+Vector2(-s*0.42,-s*0.34),center+Vector2(s*0.22,-s*1.0),
		center+Vector2(s*0.22,s*1.0),center+Vector2(-s*0.42,s*0.34)]),ink)
	if muted:
		# 静音：一道红斜线 + 没有声波
		draw_line(center+Vector2(-s*1.15,s*1.15),center+Vector2(s*1.25,-s*1.25),Color("d2405c"),2.8,true)
	else:
		draw_arc(center+Vector2(s*0.42,0.0),s*0.62,-PI/3.4,PI/3.4,20,ink,2.0,true)
		draw_arc(center+Vector2(s*0.42,0.0),s*1.05,-PI/3.8,PI/3.8,24,Color(ink,0.66),1.6,true)
