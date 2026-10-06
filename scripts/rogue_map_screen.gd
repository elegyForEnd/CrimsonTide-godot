extends Control
## P1 · 魔境「节点路线图」界面（只读视图）。
##
## 数据来源全是本地已有状态，**不新增任何同步字段、不消耗 `s.rng`、不改玩家状态**：
##   * `s.rogue_graph`（`roguelike.new_floor()` 里由 `rogue_graph.build(seed_value,floor)`
##     纯函数生成，房主与客户端各自本地重建得到逐字段相同的图）；
##   * `s.raid.node` / `s.raid.depth`（= 图里当前节点的 id 与它的 depth；`enter()` 同时把
##     深度写进 `raid.area`）；
##   * `s.raid.exits`（= `roguelike.exit_choices(s)`，即当前节点在图上真实的 1~2 个后继）。
## 节点类型一律读图（`graph.nodes[id].kind`），**不读** `s.raid.route`：`route` 是按深度
## 索引的"房间模板"，图上每个节点的类型本来就是确定性的，读图比读模板少一层间接。
## 房间中文名取 `s.roguelike.ROOM_NAMES`（`roguelike.gd:25`，与增补表 `rogue_rooms.gd:27`）。
##
## 因此它天然是"只读"的：两端的图、当前节点、已走路线、可选分支都由同一份确定性数据
## 推出，非权威端不可能算出与房主不同的东西，也不可能产生任何 authoritative 变更。
##
## 渲染风格与工程一致：`extends Control` + 自绘 `_draw()`（同 `rogue_field.gd:157-325`、
## `battlefield.gd:168`、`boss_hud.gd:11`），文字统一走 `get_theme_default_font()` +
## `draw_string()`（同 `rogue_field.gd:187`），背景/描边走 `draw_rect()`，
## 颜色沿用 `main.gd` 的同名 HUD 常量（GOLD/INK/MUTED/RED，`main.gd:39-42`）。
##
## 布局对外可见、可断言（`layout()`），绘制只是把布局画出来：
##   `rogue_map_screen.gd` 的 `layout()` 是纯函数（只读 session），可被 headless 测试直接调用。

const NodeGraph := preload("res://scripts/rogue_graph.gd")

# 与 main.gd:39-42 同一套 HUD 色。
const GOLD := Color("c5a67b")
const INK := Color("e7dfd5")
const MUTED := Color("969aaa")
const RED := Color("ad4056")
const DIM := Color("5b6070")          # 已走路线变灰
const AVAILABLE := Color("8fd6b4")    # 当前可选出口
## `ROOM_NAMES` 里查不到的类型（正常不该出现）走这条兜底，不显示空标签。
const UNKNOWN_NAME := "未知区域"

# 1440x900 的 HUD 设计分辨率（`main.gd` 的 `root.size=Vector2(1440,900)`）。
const MAP_RECT := Rect2(0,0,1440,900)

var session: TideSession
var clock := 0.0

func _ready() -> void:
	# 只画不点：跟 `page` / `overlay` 一样忽略鼠标，地图上没有任何可交互控件。
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	visible=false

func _process(dt: float) -> void:
	if not visible:
		return
	# 当前节点有脉冲高亮，所以开着的时候每帧重绘；关掉时一帧都不画。
	clock+=dt
	queue_redraw()

func _draw() -> void:
	if not visible or session==null:
		return
	if not session.roguelike.active(session):
		return
	draw_map(self,session,clock)

# ------------------------------------------------------------------ 布局（纯函数）

## 节点图的只读视图模型。返回：
##   title/subtitle/floor/depth/boss_depth/current_node/exit_nodes/legend/edges/nodes
## 每个 node：id/depth/index/kind/name/mark/desc/at/state/current/visited/available/locked/on_path/next
## 只读取 session，不写任何字段。
static func layout(tide: TideSession) -> Dictionary:
	var view := {
		"depth_count": 1,
		"floor": 1,
		"depth": 1,
		"current_node": "",
		"boss_depth": 0,
		"exit_nodes": [],
		"current_room": "",
		"nodes": [],
		"edges": [],
		"legend": legend(),
		"title": "魔境路线图",
		"subtitle": "",
	}
	if tide == null:
		return view
	view["floor"]=int(tide.raid.get("floor",1))
	view["depth"]=int(tide.raid.get("depth",1))
	view["current_node"]=str(tide.raid.get("node",""))
	view["current_room"]=str(tide.raid.get("room",""))
	var graph: Dictionary = tide.rogue_graph if tide.rogue_graph is Dictionary else {}
	var order: Array = graph.get("order",[]) as Array
	var names: Dictionary = {}
	if tide.roguelike != null:
		names = tide.roguelike.ROOM_NAMES
	var depths := 1
	for id in order:
		depths=maxi(depths,int(_field(graph,str(id),"depth",1)))
	view["depth_count"]=depths
	var boss_id := str(graph.get("boss",""))
	var boss_depth := int(_field(graph,boss_id,"depth",depths)) if boss_id!="" else depths
	view["boss_depth"]=boss_depth
	# `raid.route`（每层按"深度 - 1"索引的房间模板）在本视图里不再需要单独解析：
	# 每条路线所在列的"是否已走"完全由图深度与当前节点深度决定，见下方 visited_depths。
	# 当前所在节点：`raid.node` 解析出的深度定位列；`raid.depth` 是它的冗余镜像
	# （`roguelike.enter()` 同时写 `raid.depth` 与 `raid.area`，两者都是节点深度）。
	var current_depth := _depth_of(graph,order,str(view["current_node"]))
	if current_depth<=0:
		current_depth=clampi(int(view["depth"]),1,depths)
	var exits: Array = tide.raid.get("exits",[]) as Array
	var exit_nodes := PackedStringArray()
	for destination in exits:
		if destination is Dictionary and str(destination.get("node",""))!="":
			exit_nodes.append(str(destination["node"]))
	view["exit_nodes"]=exit_nodes
	# 已走路线：图是分层 DAG、层与层全连，所以"深度比当前节点浅的整列"必然都已经被越过，
	# 每个更浅的深度各有一个节点属于走过的路线（入口行只有 1 个节点）。
	var visited_depths := PackedInt32Array()
	for depth in range(1,current_depth):
		visited_depths.append(depth)
	# 路径高亮：从当前节点往后，每列取第一个能一路接到当前节点的节点。
	var on_path := {str(view["current_node"]): true}
	for depth in range(current_depth-1,0,-1):
		var pick := ""
		var ids := _ids_in_depth(graph,order,depth)
		# 上一列里"其后继包含已确定在路径上的那个节点"的节点，才是玩家走过的那一个。
		for id in ids:
			var follows := NodeGraph.neighbors(graph,str(id)) as Array
			for target in follows:
				if on_path.has(str(target)):
					pick=str(id)
					break
			if pick!="":
				break
		if pick=="":
			# 只有唯一后继的列（入口行）天然在路径上：直接取该列唯一的节点。
			if ids.size()==1:
				pick=str(ids[0])
		if pick=="":
			break
		on_path[pick]=true
	# 逐节点组装视图。
	var nodes: Array = []
	for id in order:
		var node_id := str(id)
		var depth := int(_field(graph,node_id,"depth",1))
		var kind := str(_field(graph,node_id,"kind","combat"))
		var state := "locked"
		if node_id==str(view["current_node"]):
			state="current"
		elif exit_nodes.has(node_id):
			state="available"
		elif visited_depths.has(depth):
			state="visited"
		# 说明行：`DESCS` 与 `ROOM_NAMES` 大部分同名，同名就不再重复写一遍（只留房间名）。
		var entry := {
			"id": node_id,
			"depth": depth,
			"index": _index_in_depth(graph,order,node_id,depth),
			"kind": kind,
			"name": _room_name(names,kind),
			"mark": _room_mark(kind),
			"desc": _kind_desc(kind),
			"at": Vector2.ZERO,
			"state": state,
			"current": state=="current",
			"visited": state=="visited",
			"available": state=="available",
			"locked": state=="locked",
			"on_path": on_path.has(node_id),
			"next": (NodeGraph.neighbors(graph,node_id) as Array).duplicate(),
		}
		if str(entry["desc"])==str(entry["name"]) or str(entry["desc"])==kind:
			entry["desc"]=""
		nodes.append(entry)
	# 分列布局：列 = 深度，行 = 同深度内的序号；单列内按行居中。
	var columns := {}
	for node in nodes:
		var depth := int((node as Dictionary)["depth"])
		if not columns.has(depth):
			columns[depth]=[]
		columns[depth].append(node)
	var row_step := ROW_STEP
	if depths>1:
		var tallest := 1
		for depth in columns:
			tallest=maxi(tallest,(columns[depth] as Array).size())
		var room_for_rows := float(ROWS_TOP-ROWS_BOTTOM)/float(tallest-1)
		row_step=minf(ROW_STEP,room_for_rows)
	var left := COLUMN_MARGIN
	var step := (MAP_RECT.size.x-2.0*COLUMN_MARGIN)/float(maxi(1,depths-1))
	for depth in columns:
		var column: Array = columns[depth]
		var top := (ROWS_BOTTOM+ROWS_TOP)/2.0-(column.size()-1)*row_step/2.0
		for i in column.size():
			var node: Dictionary = column[i]
			node["at"]=Vector2(left+(depth-1)*step,top+i*row_step)
	# 边：只画图上真实存在的邻接（一层到下一层全连）。
	var edges: Array = []
	for node in nodes:
		for target in node["next"]:
			var edge := {
				"from": str(node["id"]),
				"to": str(target),
				"on_path": bool(on_path.has(str(node["id"]))) and bool(on_path.has(str(target))),
			}
			edges.append(edge)
	view["nodes"]=nodes
	view["edges"]=edges
	view["subtitle"]="第 %d 层 · 深度 %d / %d · 当前 %s" % [
		int(view["floor"]), current_depth, depths,
		_room_name(names,str(tide.raid.get("room",""))) if str(tide.raid.get("room",""))!="" else UNKNOWN_NAME,
	]
	return view

## 节点在"它自己那一列"里的行号（0-based）；同深度内按 `order` 的先后排列。
static func _index_in_depth(graph: Dictionary, order: Array, node_id: String, depth: int) -> int:
	var ids := _ids_in_depth(graph,order,depth)
	var index := 0
	for i in ids.size():
		if str(ids[i])==node_id:
			index=i
			break
	return index

static func _ids_in_depth(graph: Dictionary, order: Array, depth: int) -> Array:
	var out: Array = []
	for id in order:
		if int(_field(graph,str(id),"depth",0))==depth:
			out.append(str(id))
	return out

static func _depth_of(graph: Dictionary, order: Array, node_id: String) -> int:
	if node_id=="":
		return 0
	return int(_field(graph,node_id,"depth",0))

static func _field(graph: Dictionary, id: String, key: String, fallback: Variant) -> Variant:
	if id=="":
		return fallback
	var found: Dictionary = NodeGraph.node(graph,id)
	if found.is_empty():
		return fallback
	return found.get(key,fallback)

# ------------------------------------------------------------------ 房间类型显示

static func _room_name(names: Dictionary, kind: String) -> String:
	if kind=="":
		return UNKNOWN_NAME
	var found := str(names.get(kind,""))
	return found if found!="" else kind

## 节点里的单字标记。P1 只做形状 + 中文名：`rogue_art.gd` / `rogue_build_art.gd` 的图标表
## 是"物品/道具"图集，没有逐房间类型的图，硬套会把商人和宝箱画成同一个东西；
## 单字标记既不用新美术资源，也不会有认错的风险。要换图标时改这一个函数即可。
static func _room_mark(kind: String) -> String:
	return str(MARKS.get(kind,"?"))

## 一行说明，与 `roguelike.gd` 的 `ROOM_DESCS` 同调，但不去读那份字典（它是 rl 模块
## 的私有常量），这里只给地图用的短句。
static func _kind_desc(kind: String) -> String:
	return str(DESCS.get(kind,""))

const MARKS := {
	"combat": "战", "elite": "精", "shop": "商", "treasure": "宝", "talent": "坛",
	"curse": "咒", "event": "事", "forge": "炉", "gamble": "赌", "mirror": "镜", "boss": "王",
}
const DESCS := {
	"combat": "魔物围猎", "elite": "精英试炼", "shop": "游商营火", "treasure": "遗落宝藏",
	"talent": "灵契圣坛", "curse": "诅咒祭坛", "event": "幽暗异事", "forge": "游方锻炉",
	"gamble": "赌徒营帐", "mirror": "镜中挑战", "boss": "守层者",
}

## 图例（颜色 = 状态）。供绘制与测试共用。
static func legend() -> Array:
	return [
		{"key": "current", "color": GOLD, "label": "当前"},
		{"key": "visited", "color": DIM, "label": "已走路线"},
		{"key": "available", "color": AVAILABLE, "label": "可选出口"},
		{"key": "locked", "color": MUTED, "label": "未探索"},
	]

# ------------------------------------------------------------------ 绘制

## 把布局画到 `canvas`（`Control`/`Node2D` 都可以，用 `draw_*` 接口）。
## 纯绘制：不改任何状态，不读 `rng`，因此可以在任何一端安全调用。
## `phase` 只用于"当前节点"脉冲动画的相位（本节点的 `clock`），不参与任何模拟。
static func draw_map(canvas: CanvasItem, tide: TideSession, phase: float = 0.0) -> void:
	if canvas==null:
		return
	var view := layout(tide)
	var font := _theme_font(canvas)
	# 满屏底：alpha 必须足够高，否则下面的 HUD 文字会透上来和节点标签叠字
	# （P1 首轮截图实测：0.94 时「魔物围猎 · 可撤离」等 HUD 行会穿过地图）。
	canvas.draw_rect(MAP_RECT,Color(0.02,0.015,0.035,0.995),true)
	# 标题与图例说明。
	_text(canvas,font,Vector2(56,54),str(view["title"]),28,GOLD,220)
	_text(canvas,font,Vector2(56,88),str(view["subtitle"]),17,INK,520)
	var hint := "M 关闭地图 · 地图是只读视图：不改变任何进度 · 只显示本层节点图"
	var hint_width := _text_width(hint,15)
	_text(canvas,font,Vector2(MAP_RECT.size.x-56.0-hint_width,54),hint,15,MUTED,hint_width+2.0)
	# 深度表头。
	var depths := int(view["depth_count"])
	var step := (MAP_RECT.size.x-2.0*COLUMN_MARGIN)/float(maxi(1,depths-1))
	for depth in range(1,depths+1):
		var at := Vector2(COLUMN_MARGIN+(depth-1)*step,RIBBON_Y)
		var title := "%d 区" % depth
		if depth==1:
			title="入口 · "+title
		elif depth==int(view["boss_depth"]):
			title="守层者 · "+title
		_text(canvas,font,at-Vector2(_text_width(title,15)*0.5,0),title,15,MUTED,_text_width(title,15)+4.0)
	# 边：先画全部连线，再把"已走过"的那条盖上去加亮。
	var by_id := {}
	for node in view["nodes"]:
		by_id[str((node as Dictionary)["id"])]=node
	for node in view["nodes"]:
		var from := Vector2((node as Dictionary)["at"])
		for target in (node as Dictionary)["next"]:
			var other: Dictionary = by_id.get(str(target),{})
			if other.is_empty():
				continue
			var to := Vector2(other["at"])
			canvas.draw_line(from,to,Color(0.32,0.34,0.40,0.45),1.5,true)
	for edge in view["edges"]:
		if not bool((edge as Dictionary)["on_path"]):
			continue
		var a: Dictionary = by_id.get(str((edge as Dictionary)["from"]),{})
		var b: Dictionary = by_id.get(str((edge as Dictionary)["to"]),{})
		if a.is_empty() or b.is_empty():
			continue
		canvas.draw_line(Vector2(a["at"]),Vector2(b["at"]),Color(GOLD,0.75),3.0,true)
	# 节点。
	for node in view["nodes"]:
		_draw_node(canvas,font,node,phase)
	# 图例（左下）。
	var legend_row := legend()
	var legend_x := 56.0
	for row in legend_row:
		var tone := Color((row as Dictionary)["color"])
		canvas.draw_circle(Vector2(legend_x,LEGEND_Y),6.0,tone)
		canvas.draw_arc(Vector2(legend_x,LEGEND_Y),6.0,0.0,TAU,20,tone,1.5,true)
		var label := str((row as Dictionary)["label"])
		_text(canvas,font,Vector2(legend_x+14.0,LEGEND_Y+6.0),label,15,MUTED,_text_width(label,15)+4.0)
		legend_x+=26.0+_text_width(label,15)+34.0
	_text(canvas,font,Vector2(legend_x,LEGEND_Y+6.0),"节点 = 房间类型 · 绿圈 = 现在能走的出口",15,DIM,460.0)

static func _draw_node(canvas: CanvasItem, font: Font, node: Dictionary, clock: float) -> void:
	var at := Vector2(node["at"])
	var state := str(node["state"])
	var kind := str(node["kind"])
	var tone := MUTED
	var fill := Color(0.09,0.10,0.14,0.92)
	if state=="visited":
		tone=DIM
		fill=Color(0.08,0.09,0.12,0.9)
	elif state=="available":
		tone=AVAILABLE
		fill=Color(0.07,0.13,0.12,0.95)
	elif state=="current":
		tone=GOLD
		fill=Color(0.14,0.12,0.09,0.98)
	if kind=="boss":
		if state=="current" or state=="available":
			tone=RED
			fill=Color(0.16,0.07,0.10,0.98)
		elif state=="locked":
			tone=Color(RED,0.75)
	# 当前节点的脉冲光环。
	if state=="current":
		canvas.draw_circle(at,RADIUS+8.0+sin(clock*3.0)*2.5,Color(GOLD,0.16))
		canvas.draw_arc(at,RADIUS+8.0+sin(clock*3.0)*2.5,0.0,TAU,36,Color(GOLD,0.55),2.0,true)
	canvas.draw_circle(at,RADIUS,fill)
	canvas.draw_arc(at,RADIUS,0.0,TAU,36,tone,2.4 if state=="current" else 1.8,true)
	# 可选出口：外圈再套一层，和"当前"的实心高亮区分开。
	if state=="available":
		canvas.draw_arc(at,RADIUS+5.0,0.0,TAU,32,Color(AVAILABLE,0.85),2.0,true)
	# 单字标记（房间类型）。基线 = 圆心 + 半个字高（`draw_string` 的 `at` 是文本基线，
	# 不是一个盒子的左上角），这样单字才真的落在圆心里。
	var mark := str(node["mark"])
	var mark_width := _text_width(mark,18)
	_text(canvas,font,Vector2(at.x-mark_width*0.5,at.y+9.0),mark,18,tone if state!="locked" else Color(MUTED,0.85),mark_width+4.0)
	# 房间名 + 说明（当前/可选的节点写得最亮，未探索的最暗）。
	var label_tone := MUTED
	if state=="current":
		label_tone=GOLD
	elif state=="available":
		label_tone=Color("cfe9d9")
	elif state=="visited":
		label_tone=DIM
	var name := str(node["name"])
	var name_width := _text_width(name,15)
	var name_x := at.x-name_width*0.5
	name_x=clampf(name_x,4.0,float(MAP_RECT.size.x)-name_width-4.0)
	_text(canvas,font,Vector2(name_x,at.y+RADIUS+22.0),name,15,label_tone,name_width+4.0)
	var desc := str(node["desc"])
	var desc_width := _text_width(desc,12)
	var desc_x := at.x-desc_width*0.5
	desc_x=clampf(desc_x,4.0,float(MAP_RECT.size.x)-desc_width-4.0)
	_text(canvas,font,Vector2(desc_x,at.y+RADIUS+40.0),desc,12,Color(label_tone,0.6),desc_width+4.0)

# ------------------------------------------------------------------ 绘制小工具

## 字体来源：`Control` 走它自己的主题默认字体（与 `rogue_field.gd` 的
## `get_theme_default_font()` 同一份）；`Node2D` 没有这个方法，回落到引擎的默认字体。
## （本模块自己 `extends Control`，但 `draw_map()` 允许任何 `CanvasItem` 当画布 ——
## 探针就是用 `Node2D` 画的，所以这里必须两个都兜住。）
static func _theme_font(canvas: CanvasItem) -> Font:
	if canvas is Control:
		var found: Font = (canvas as Control).get_theme_default_font()
		if found!=null:
			return found
	return ThemeDB.fallback_font

## `draw_string()` 不换行：宽度必须显式给，否则长串会按默认行为铺开。
static func _text_width(text: String, size: int) -> float:
	if text=="":
		return 0.0
	return maxf(12.0,float(text.length())*float(size)*0.98)

static func _text(canvas: CanvasItem, font: Font, at: Vector2, text: String, size: int, color: Color, width: float) -> void:
	if font==null or text=="":
		return
	canvas.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)

# ------------------------------------------------------------------ 布局常量

const COLUMN_MARGIN := 120.0   # 首/末列距屏幕边缘
const ROW_STEP := 96.0         # 同一深度内相邻节点的行距
const RADIUS := 24.0           # 节点半径
const ROWS_TOP := 330.0        # 单列多节点时最上一行的中心
const ROWS_BOTTOM := 610.0     # 最下一行的中心
const RIBBON_Y := 132.0        # 深度表头基线
const LEGEND_Y := 862.0        # 图例中心线
