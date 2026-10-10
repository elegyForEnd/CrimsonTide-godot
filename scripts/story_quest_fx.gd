extends Control
## UI-only celebration. Never grants rewards or triggers a task transition.
const UISkin = preload("res://scripts/story_ui_skin.gd")
var screen
var queue: Array=[]
var current: Dictionary={}
var elapsed := 0.0
var duration := 3.4
var world_at := Vector2.ZERO
var region := ""
func _ready() -> void:
	size=Vector2(1440,900); mouse_filter=MOUSE_FILTER_IGNORE
func show_event(kind: String, id: String) -> void:
	if not screen.campaign.content.quests.has(id): return
	var q: Dictionary=screen.campaign.content.quests[id]
	var packet := {"kind":kind,"id":id,"title":q.title,"reward":screen.campaign.rewards(q),"steps":screen.campaign.step_count(q),"total":q.steps.size()}
	if queue.size()>=4: queue.pop_front()
	queue.append(packet)
	if current.is_empty(): next()
func next() -> void:
	current=queue.pop_front() if not queue.is_empty() else {}; elapsed=0
	world_at=screen.campaign.hero_at; region=screen.campaign.key()
	duration=1.6 if current.get("kind")=="progress" else 2.5 if current.get("kind")=="accepted" else 3.8
func clear() -> void: queue.clear(); current.clear(); elapsed=0; queue_redraw()
func _process(dt: float) -> void:
	if not screen.active or current.is_empty(): return
	elapsed+=dt
	if elapsed>=duration: next()
	queue_redraw()
func _draw() -> void:
	if current.is_empty() or not screen.active: return
	var alpha := minf(clampf(elapsed/0.22,0,1),clampf((duration-elapsed)/0.45,0,1))
	var completed: bool=current.kind=="completed"
	var color := Color("efc97d") if completed else Color("99d5e9")
	color.a=alpha
	var pop := 1-pow(1-clampf(elapsed/0.45,0,1),3)
	var origin := Vector2(390,173+16*(1-pop))
	draw_set_transform(origin)
	var frame: StyleBoxTexture=UISkin.frame(5).duplicate(); frame.modulate_color=Color(1,1,1,alpha)
	draw_style_box(frame,Rect2(0,0,660,130))
	var seal := Vector2(58,62)
	draw_arc(seal,33,elapsed*0.6,elapsed*0.6+TAU*0.87,48,color,2,true)
	draw_arc(seal,26,-elapsed*0.7,-elapsed*0.7+TAU*0.75,48,color,1,true)
	var diamond := PackedVector2Array([seal+Vector2(0,-21),seal+Vector2(17,0),seal+Vector2(0,21),seal+Vector2(-17,0),seal+Vector2(0,-21)])
	draw_polyline(diamond,color,2,true)
	if completed: draw_polyline(PackedVector2Array([seal+Vector2(-9,0),seal+Vector2(-2,7),seal+Vector2(11,-8)]),color,3,true)
	else: draw_line(seal+Vector2(0,-10),seal+Vector2(0,5),color,3); draw_circle(seal+Vector2(0,11),2,color)
	var font := get_theme_default_font()
	draw_string(font,Vector2(106,31),{"accepted":"委托已接取","completed":"任务完成","progress":"目标已推进"}[current.kind],HORIZONTAL_ALIGNMENT_LEFT,515,17,color)
	draw_string(font,Vector2(106,64),current.title,HORIZONTAL_ALIGNMENT_LEFT,515,25,Color(1,0.96,0.87,alpha))
	var reward: Dictionary=current.reward
	var line: String="+%d 银币    +%d 经验    +%d 铁料" % [reward.coins,reward.xp,reward.materials] if completed else "%d / %d · 已记录于旅程日志" % [current.steps,current.total]
	draw_string(font,Vector2(107,100),line,HORIZONTAL_ALIGNMENT_LEFT,510,17,color)
	# Brief horizontal light sweep and rising sparks, bounded to the notification.
	var sweep := clampf(elapsed/0.65,0,1)
	var light := Color(color,alpha*(1-sweep)*0.7)
	draw_line(Vector2(17,117),Vector2(17+626*sweep,117),light,3,true)
	for i in 18:
		var phase := fmod(elapsed*0.4+i*0.061,1)
		var p := Vector2(26+((i*97)%605),112-phase*82)
		var spark := Color(color,alpha*sin(phase*PI)*0.55)
		draw_line(p-Vector2(0,2),p+Vector2(0,2),spark,1,true)
	draw_set_transform(Vector2.ZERO)
	# A short pulse at the actual character feet. Captured location, no camera-space drift.
	if region==screen.campaign.key() and elapsed<1.0 and not screen.modal:
		var ground: Transform2D=screen.ground_transform()
		ground.origin=screen.project(world_at)
		draw_set_transform_matrix(ground)
		var pulse := Color(color,alpha*(1-elapsed)*0.65)
		draw_arc(Vector2.ZERO,35+elapsed*100,0,TAU,64,pulse,3,true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
