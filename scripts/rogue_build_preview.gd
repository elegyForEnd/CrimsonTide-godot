extends Control
## U1 · 构筑「派生链 / 组合路线」只读预览（`main.gd` 在 `overlay` 里挂一份）。
##
## 为什么要有它：`rogue_build.gd:8-9` 的 `CM_ROUTES` / `HC_ROUTES` 把"哪一串输入能派生出哪一招"
## 写死在数据里，玩家在构筑页只能看到 `rogue_build_ui.gd:151/157` 那一行箭头串，
## 没有任何地方告诉他"我现在解锁到哪、下一段要什么条件"。本文件只做**可视化**。
##
## 铁律（与 `rogue_map_screen.gd` 同一套约束）：
##   * **不消耗 `s.rng`**：只读静态表与本地已同步的玩家字段；
##   * **不写会话状态**：没有任何 `session.action()`、没有 `p[...] = ...`；
##   * **不新增同步字段**：读的全是 `rogue_build.gd:reset()` 已经写进快照的键
##     （`build_forge_level`/`build_core`/`build_temper`/`build_forge_points`/`build_talents`/
##     `build_cultivation`/`equipped.weapon`）。两端各自读同一份快照，不可能算出不同的东西。
##
## 数据来源（逐个可核验）：
##   * 派生链 / 组合路线   `rogue_build.gd:8` `CM_ROUTES`、`rogue_build.gd:9` `HC_ROUTES`；
##   * 路线解锁门槛        `rogue_build.gd:609` 的 `[0,1,3,3]`（轻刃）与 `[0,1,0,3]`（其它家族）；
##   * 路线名              `rogue_build.gd:612` 的 `build_combo_label` 四个名字；
##   * 家族路由顺序        `rogue_build.gd:584` `[1,2,0,3].find(family)` —— 与
##                         `rogue_build_ui.gd:146` 用的是同一个映射；
##   * 锻造 = 其余三件的前置：`rogue_build.gd:859`（核心需 `forge_level(p)>=2`）、
##                         `rogue_build.gd:862`（补正需 `>=3`）—— 本文件**不重写**这两条规则，
##                         只是把 `Build.forge_level(p)` 的结果和这两个门槛并排画出来；
##                         `rogue_build.gd:865` 的铭刻走 `p.equipped.weapon.rogue_id`、
##                         `rogue_build_ui.gd:138` 的 35 魔晶价；
##   * 修为线              `Build.talent_cost(p)` / `p.build_cultivation` / `p.build_talents`。
##
## 布局是**纯函数**（`layout()`），绘制只是把布局画出来（`draw_preview()`），与
## `rogue_map_screen.gd:68 layout()` / `:287 draw_map()` 同款写法，便于 headless 断言。

const Build := preload("res://scripts/rogue_build.gd")
const Content := preload("res://scripts/rogue_content.gd")

# 与 main.gd:39-42 同一套 HUD 色（加上地图界面在用的两个状态色）。
const GOLD := Color("c5a67b")
const INK := Color("e7dfd5")
const MUTED := Color("969aaa")
const ACTIVE := Color("c5a67b")       # 已激活
const AVAILABLE := Color("8fd6b4")    # 可激活（门槛已达到）
const LOCKED := Color("5b6070")       # 未满足
const PANEL := Color(0.035,0.025,0.07,0.96)

## 挂载坐标 `PANEL_RECT = (64,205) 468x517`（高度按内容自动收，见 `layout()` 末尾）。
## 逐项对照过的邻近控件：
##   * `toast`（`main.gd:254` 建，肉鸽下 `main.gd:1281` 把它挪到 y=157；x 230..1210，高 34）
##     → 本面板 y 从 205 起，在它下面 14px，不重叠；
##   * 构筑页的文字列（`rogue_build_ui.gd:42-43` 的标题/副标题在 x 65/67、y 40..130；
##     `:64` 的按键提示在 (68,841)；滚动区 `:51` 是 Rect2(66,214,1305,607)）
##     → 本面板 x 从 64 起，会压住左起约 468px 的那一小截（标题在 y<205，不受影响；
##       正文的头几十个字会被盖住）。这是刻意取舍：面板 `mouse_filter=IGNORE` 不吞事件，
##       下面的按钮照旧可点，而把它挪到 x=496 之外就会压到右下角那一片 HUD 提示。
##   * 屏幕左下 HUD 簇（`main.gd` 里 `fade(page,(15,776),(555,112))` / 血条框 y 776..888、
##     头像、生命/蓝量/理智文字 x 15..555）→ 面板下沿最高 205+517=722，仍在它上方 54px；
##   * `hud.prompt`（`main.gd` 里肉鸽下挪到 (335,739) 770x48，右缘 1105）
##     → 图例已收进面板头部的横带（`_legend_row()` 右对齐画在 y=217），不再画到面板外面，
##       所以它永远不会碰到 y 739 起的 prompt。
##   * 肉鸽右侧信息列（肉鸽下 x 1175..1427）→ 本面板 x 到 532，差 643px。
const PANEL_RECT := Rect2(64,205,468,517)
const PAD := 12.0
const LEFT := 76.0                # = PANEL_RECT.position.x + PAD
const RIGHT := 520.0              # = PANEL_RECT.position.x + PANEL_RECT.size.x - PAD
const COLUMN_GAP := 12.0
const COLUMN_WIDTH := (RIGHT-LEFT-COLUMN_GAP)*0.5   # 216
const RIGHT_COLUMN := LEFT+COLUMN_WIDTH+COLUMN_GAP  # 304
const ROW_H := 20.0
const ROW_GAP := 2.0
const SECTION_GAP := 8.0
const CHIP := 20.0
const CHIP_GAP := 6.0
const CHIP_PITCH := CHIP+CHIP_GAP
const ENGRAVING_COLUMNS := 6
const TITLE := "派生链 · 组合路线"
const HINT := "只读预览 · 不改变任何构筑 / 不消耗随机数"

## 四个连招段在 `CM_ROUTES` 里出现的先后，配 `rogue_build.gd:612` 的 `build_combo_label`。
const COMBO_NAMES := ["闪避追击","折返派生","升空 / 跃击","落地连段"]
## `[1,2,0,3]` 的位置 = 路由序号（`rogue_build.gd:584`），值 = `Catalog.weapon_family()`。
const ROUTE_FAMILIES := [1,2,0,3]
## 家族名：取 `rogue_build_ui.gd:148/152` 用过的四个字，够窄，能进 222px 的列。
const FAMILY_LABELS := ["轻刃","重刃","枪弓","法杖"]
## 角色四段的顺序取自 `HC_ROUTES` 的四段（`rogue_build_ui.gd:156` 的四个名字）。
const HERO_NAMES := ["追击式","凌空式","奥义式","终式"]
const TEMPER_NAMES := {"steady":"稳锋","strength":"力","dexterity":"敏","intelligence":"智","arcane":"奥"}

## 由 `main.gd:257-260` 挂载时注入（与 `rogue_map_screen.gd:40` 的 `var session` 同款）。
## 刻意**不**标 `TideSession`：本文件所有逻辑都走鸭子类型的 `layout(tide)`，
## 保持无类型可以让它也能被 headless 断言直接调用（传一个替身即可），
## 而 `main.gd` 传进来的本来就是真的 `TideSession`。
var session

## 图例独占面板里的一条横带（`LAYOUT_TOP` 以上就是它的），所以它永远不会溢出到面板外面
## 去和 `hud.prompt`（`main.gd:1280` 挪到 y=739 起）或左下 HUD 簇（y 776 起）打架。
##
## U1-b（2026-06 实机修复）· 抬头带从 248 加高到 272：多出来的这一行是「关闭 ×」自己的位置。
## 原来 43px 的抬头带里已经塞了标题（baseline 231）、图例（baseline 232）与副题（baseline 250），
## 最长的流派标题（`派生链 · 组合路线 · 重刃流派`）右缘已经顶到图例左缘，放不下第四个元素。
## 面板高度是按内容算的（本文件 `layout()` 末尾），内容高约 356 → 面板高约 435、下沿约 640，
## 离 `hud.prompt`（y 739）与左下 HUD 簇（y 776）都还有富余；即使触到
## `PANEL_RECT.size.y` 这层上限（517），下沿也仍旧是 722 < 739，既有安全边界没变。
const LAYOUT_TOP := 272.0

## U1-b · 「关闭 ×」按钮。面板是自绘的、根节点 `mouse_filter=IGNORE`（U-07 的"点击穿透"就靠它），
## 但 `IGNORE` 只作用于**节点自身**：子控件照旧参与命中测试，所以这里挂一个真正的 Button 子节点
## （`Button` 的默认 `mouse_filter` 就是 `STOP`）。它只吃掉自己这 60x26 一块，面板其余部分照旧
## 穿透到下面的构筑页按钮。
const CLOSE_SIZE := Vector2(60,26)
const CLOSE_HINT := "收起派生链预览 · 行囊内按 V 可再展开"

## 点「关闭 ×」时通知持有者（`main.gd` 挂载本面板时用 `connect("closed", …)` 接上）。
## 面板自己也会 `visible=false`，但真正"记住"这次收起的是 `main.gd` 的
## `_rogue_build_preview_hidden` —— 它每帧都会重算 `visible`，不知道这件事就会把面板又点亮。
signal closed

## 「关闭 ×」按钮（`_build_close_button()` 建，`_ready()` 里挂）。
var close_button: Button

func _ready() -> void:
	# 与 `page` / `overlay` / 地图界面一样只画不点：下面全是按钮，预览绝不允许吞事件。
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name="RogueBuildPreview"
	size=Vector2(1440,900)
	_build_close_button()


## U1-b · 面板里**唯一**吃鼠标的控件（面板自身与其它子节点一律 `IGNORE`）。
## 三态样式都用本文件的面板配色手写，免得默认主题的灰底盖在自绘面板上。
func _build_close_button() -> void:
	close_button=Button.new()
	close_button.name="RogueBuildPreviewClose"
	close_button.text="关闭 ×"
	close_button.tooltip_text=CLOSE_HINT
	# 贴在面板右缘、图例下面那条空带上：右缘 = `RIGHT`（520），底 = `LAYOUT_TOP` 上方 6px。
	close_button.position=Vector2(RIGHT-CLOSE_SIZE.x,LAYOUT_TOP-CLOSE_SIZE.y-6.0)
	close_button.size=CLOSE_SIZE
	close_button.focus_mode=Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size",13)
	close_button.add_theme_color_override("font_color",GOLD)
	close_button.add_theme_color_override("font_hover_color",INK)
	close_button.add_theme_color_override("font_pressed_color",GOLD)
	for state in ["normal","hover","pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color=Color(GOLD,0.10 if state=="normal" else (0.20 if state=="hover" else 0.30))
		box.border_color=Color(GOLD,0.80 if state=="normal" else 1.0)
		box.set_border_width_all(1)
		box.set_corner_radius_all(2)
		close_button.add_theme_stylebox_override(state,box)
	close_button.pressed.connect(_on_close_pressed)
	add_child(close_button)


## U1-b · 收起：先自己隐藏（按下去就没了），再发 `closed` 把这件事交给 `main.gd` 记住——
## 它 `_process()` 里每帧都会重算 `visible`，不知道就会在下一帧把面板又点亮。
func _on_close_pressed() -> void:
	visible=false
	closed.emit()

# ------------------------------------------------------------------ 布局（纯函数）

## 只读视图模型。返回 title/hint/panel/rows/chips/legend/weapon/hero/cultivation...
## 只读 session 与玩家字典，不写任何字段、不读 `s.rng`。
static func layout(tide) -> Dictionary:
	var view := {
		"title":TITLE, "hint":HINT, "panel":PANEL_RECT,
		"rows":[], "chips":[], "legend":legend(),
		"cultivation":0, "talent_cost":0, "engraving_count":0, "family":-1, "hero":0,
	}
	if tide==null or not tide.roguelike.active(tide):
		return view
	var p: Dictionary=tide.players.get(tide.my_id(),{})
	if p.is_empty():
		return view
	var family := int(_weapon_family(p))
	var hero := clampi(int(p.get("hero",0)),0,3)
	var bound := int(Build.forge_level(p))
	var core_id := str(p.get("build_core",""))
	var temper := str(p.get("build_temper",""))
	var weapon: Dictionary=p.get("equipped",{}).get("weapon",{})
	var engraving := int(weapon.get("rogue_id",-1))
	var route_index: int=ROUTE_FAMILIES.find(family)
	view["family"]=family
	view["hero"]=hero
	view["cultivation"]=int(p.get("build_cultivation",0))
	view["talent_cost"]=int(Build.talent_cost(p))
	view["engraving_count"]=engraving+1 if engraving>=0 else 0
	view["talent_lines"]=talent_lines(p)
	view["core"]={"count":int(_core_count(p,family)),"forged":bound>=2,"current":core_id}
	view["temper"]={"current":temper,"forged":bound>=3}

	# 左列：锻造 → 核心 / 补正 / 铭刻。锻造 +1..+5 就是其余三件的前置链条本身。
	var lines: Array=[]
	lines.append({"kind":"section","text":"武器锻造链（前置）"})
	for level in 5:
		var cost: int=0
		if level<int(Build.FORGE_COST.size()): cost=int(Build.FORGE_COST[level])
		var passed: bool=bound>=level+1
		var nxt: bool=(not passed) and bound==level
		var points := int(p.get("build_forge_points",0))
		var tail := "已点亮" if passed else ("可投入 · 需 %d 锻造点（现有 %d）" % [cost,points] if nxt else "需先到 +%d" % level)
		lines.append({"kind":"step","index":level,"state":"active" if passed else ("available" if nxt else "locked"),"text":tail})
	lines.append({"kind":"section","text":"核心 / 补正"})
	var core_ready: bool=bound>=2
	var core_text := "未选择 · 需锻造 +2"
	if core_id!="":
		core_text="已选 %s" % str(Content.entry(core_id).get("name",core_id))
	elif core_ready:
		core_text="可选择 · 需同流派投入 2 点"
	lines.append({"kind":"line","state":"active" if core_id!="" else ("available" if core_ready else "locked"),"text":"核心  "+core_text})
	var temper_ready: bool=bound>=3
	var temper_text := "未选择 · 需锻造 +3"
	if temper!="":
		temper_text="已选 %s" % str(TEMPER_NAMES.get(temper,temper))
	elif temper_ready:
		temper_text="可选择 · 稳锋 或 武器已有补正"
	lines.append({"kind":"line","state":"active" if temper!="" else ("available" if temper_ready else "locked"),"text":"补正  "+temper_text})
	lines.append({"kind":"line","state":"active" if engraving>=0 else "locked","text":"铭刻  第 %d 枚 / 共 %d（35 魔晶，仅休整）" % [engraving+1 if engraving>=0 else 0,Content.data.engravings.size()]})
	view["rows"]=lines

	# 右列：连招 4 段 + 角色 4 段。门槛表就是 `rogue_build.gd:609` 的那两个数组。
	var routes: Array=[]
	var cm: Array=Build.CM_ROUTES[clampi(route_index,0,3)]
	for i in 4:
		var gate: int=[0,1,0,3][i] if family!=1 else [0,1,3,3][i]
		routes.append({
			"name":COMBO_NAMES[i],
			"keys":_spaced(str(cm[i]) if i<cm.size() else ""),
			"gate":gate,
			"state":"active" if bound>=gate else "locked",
			"current":int(p.get("build_next_route",-1))==i,
		})
	var hc: Array=Build.HC_ROUTES[clampi(hero,0,3)]
	for i in 4:
		routes.append({
			"name":HERO_NAMES[i],
			"keys":_spaced(str(hc[i]) if i<hc.size() else ""),
			"gate":3,
			"state":"active" if bound>=3 else "locked",
			"current":int(p.get("build_next_hero",-1))==i,
		})
	view["routes"]=routes

	# 左列下段：铭刻 24 枚方块（6 列 x 4 行）。只标记"当前武器刻的是哪一枚"。
	var chips: Array=[]
	for n in 24:
		chips.append({"index":n+1,"state":"active" if engraving==n else "locked"})
	view["chips"]=chips
	# 面板高度按内容算：两条列各自的高度取大者，底板因此不会留一大块空白
	# （窗口上沿固定在 205，下沿随内容收，永远盖不到 y 775 起的左下 HUD 簇）。
	var left_height := 0.0
	for entry in lines:
		left_height+=(22.0+ROW_GAP) if str((entry as Dictionary).get("kind",""))=="step" else (ROW_H+ROW_GAP)
	left_height+=SECTION_GAP+ROW_H+ROW_GAP+ceilf(24.0/float(ENGRAVING_COLUMNS))*(CHIP+4.0)
	var right_height: float=ROW_H+ROW_GAP+float((view["talent_lines"] as Array).size())*(ROW_H+ROW_GAP)
	right_height+=SECTION_GAP+ROW_H+ROW_GAP+routes.size()*(ROW_H+ROW_GAP)
	view["panel"]=Rect2(PANEL_RECT.position,Vector2(PANEL_RECT.size.x,minf(PANEL_RECT.size.y,LAYOUT_TOP-PANEL_RECT.position.y+maxf(left_height,right_height)+PAD)))
	return view

## 修为 / 天赋槽 / 收藏数的只读摘要（`Build.talent_cost()` 与 `p.build_cultivation` 同源）。
static func talent_lines(p: Dictionary) -> Array:
	var talents: Dictionary=p.get("build_talents",{})
	var cores := 0
	for id in talents:
		if str(Content.entry(id).get("category",""))=="K": cores+=1
	return [
		"修为 %d / %d · 天赋 %d / 8 槽" % [int(Build.talent_cost(p)),int(p.get("build_cultivation",0)),talents.size()],
		"流派核心 %d / 1 · 已收藏 %d 项" % [cores,int(p.get("build_library",[]).size())],
	]

static func legend() -> Array:
	return [
		{"color":ACTIVE,"label":"已激活"},
		{"color":AVAILABLE,"label":"可激活"},
		{"color":LOCKED,"label":"未满足"},
	]

## 面板抬头：固定标题 + 当前手持武器的流派名（`FAMILY_LABELS` 就是给这里用的，
## 与 `rogue_build_ui.gd:148/152` 的家族名同一套字）。
static func title_line(view: Dictionary) -> String:
	var family := int(view.get("family",-1))
	if family<0 or family>=FAMILY_LABELS.size(): return TITLE
	return "%s · %s流派" % [TITLE,FAMILY_LABELS[family]]

## `Catalog.weapon_family()` 的只读包装：`index<0` 时退回玩家手上的武器，绝不写状态。
static func _weapon_family(p: Dictionary) -> int:
	var index := int(p.get("weapon",0))
	if index<=0 and not p.get("equipped",{}).get("weapon",{}).is_empty():
		index=int(p.equipped.weapon.get("weapon",0))
	return Catalog.weapon_family(index)

## `rogue_build.gd:61 core()` 的只读镜像：它按 `build_core` 命中返回 1/2，本文件只想知道"选没选"。
static func _core_count(p: Dictionary, family: int) -> int:
	var id := str(p.get("build_core",""))
	if id=="": return 0
	var def: Dictionary=Content.entry(id)
	return 2 if int(def.get("family",-1))==family else 0

## `AADA` -> `A → A → D → A`：`rogue_build_ui.gd:151` 用的是 `.split("")` 拼接，
## 本文件保留字符本身（包括 `>` / `<` 这两个"朝向"记号），只加箭头分隔。
static func _spaced(keys: String) -> String:
	var result := ""
	for i in keys.length():
		if i>0: result+=" → "
		result+=keys[i]
	return result

# ------------------------------------------------------------------ 绘制

func _process(_dt: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if not visible:
		return
	draw_preview(self,session)

## 把布局画到 `canvas`。纯绘制：不改任何状态、不读 rng，任何一端都可以安全调用。
static func draw_preview(canvas: CanvasItem, tide) -> void:
	if canvas==null or tide==null:
		return
	if not tide.roguelike.active(tide):
		return
	var font := _theme_font(canvas)
	var view := layout(tide)
	var area: Rect2=view["panel"]
	canvas.draw_rect(area,PANEL,true)
	canvas.draw_rect(area,Color(GOLD,0.55),false,1.4)
	var y := area.position.y+PAD
	_text(canvas,font,Vector2(LEFT,y+14.0),title_line(view),17,GOLD,COLUMN_WIDTH*2.0+COLUMN_GAP)
	y+=22.0
	_text(canvas,font,Vector2(LEFT,y+11.0),str(view["hint"]),11,MUTED,COLUMN_WIDTH*2.0+COLUMN_GAP)
	# 图例独占面板头部的那条横带（不画到面板外面去，避免和下面的 HUD/prompt 叠字）。
	_legend_row(canvas,font,area.position.x+area.size.x-PAD,area.position.y+PAD+15.0)
	# 两条列从 `LAYOUT_TOP` 起，上面留给标题/说明/图例。
	y=LAYOUT_TOP
	# 左列：锻造链 + 核心/补正 + 铭刻方块。
	_left_column(canvas,font,view,y)
	# 右列：修为摘要 + 8 条路线。
	_right_column(canvas,font,view,y)


## 图例：右对齐画在面板头部，`_legend_width()` 先量总宽再决定起点，
## 所以它既不会溢出面板左缘，也不会压到下面两条列。
static func _legend_row(canvas: CanvasItem, font: Font, right: float, baseline: float) -> void:
	var rows := legend()
	var total := _legend_width(font,rows)
	var lx := right-total
	for row in rows:
		var tone: Color=row["color"]
		canvas.draw_rect(Rect2(lx,baseline-9.0,10.0,10.0),Color(tone,0.25),true)
		canvas.draw_rect(Rect2(lx,baseline-9.0,10.0,10.0),tone,false,1.2)
		var label := str(row["label"])
		_text(canvas,font,Vector2(lx+15.0,baseline),label,11,MUTED,_text_width(font,label,11)+4.0)
		lx+=_legend_item_width(font,label)

static func _legend_item_width(font: Font, label: String) -> float:
	return 15.0+_text_width(font,label,11)+14.0

static func _legend_width(font: Font, rows: Array) -> float:
	var total := 0.0
	for row in rows:
		total+=_legend_item_width(font,str((row as Dictionary)["label"]))
	return total

## 左列：锻造 +1..+5 的链条、核心/补正/铭刻的状态行、24 枚铭刻方块。
static func _left_column(canvas: CanvasItem, font: Font, view: Dictionary, top: float) -> void:
	var y := top
	for row in view["rows"]:
		var entry: Dictionary=row
		if str(entry.get("kind",""))=="section":
			_text(canvas,font,Vector2(LEFT,y+13.0),str(entry["text"]),14,GOLD,COLUMN_WIDTH)
			y+=ROW_H+ROW_GAP
			continue
		if str(entry.get("kind",""))=="step":
			var level := int(entry.get("index",0))+1
			var at := Vector2(LEFT,y+2.0)
			_cell(canvas,at,str(level),str(entry["state"]),font)
			_text(canvas,font,Vector2(LEFT+CHIP+8.0,y+14.0),"+%d  %s" % [level,str(entry["text"])],12,_tone(str(entry["state"])),COLUMN_WIDTH-CHIP-8.0)
			y+=22.0+ROW_GAP
			continue
		if str(entry.get("kind",""))=="line":
			_text(canvas,font,Vector2(LEFT,y+13.0),str(entry["text"]),12,_tone(str(entry["state"])),COLUMN_WIDTH)
			y+=ROW_H+ROW_GAP
			continue
	y+=SECTION_GAP
	_text(canvas,font,Vector2(LEFT,y+13.0),"铭刻 %d / 24（当前武器）" % int(view["engraving_count"]),14,GOLD,COLUMN_WIDTH)
	y+=ROW_H+ROW_GAP
	var per_row := ENGRAVING_COLUMNS
	for chip in view["chips"]:
		var item: Dictionary=chip
		var index := int(item["index"])
		var slot := index-1
		var at := Vector2(LEFT+float(slot%per_row)*CHIP_PITCH,y+float(slot/per_row)*(CHIP+4.0))
		_cell(canvas,at,str(index),str(item["state"]),font)

## 右列：修为摘要 + 4 段武器连招 + 4 段角色派生（当前那一段加金色 "▶" 标注）。
static func _right_column(canvas: CanvasItem, font: Font, view: Dictionary, top: float) -> void:
	var y := top
	_text(canvas,font,Vector2(RIGHT_COLUMN,y+13.0),"累积（修为）",14,GOLD,COLUMN_WIDTH)
	y+=ROW_H+ROW_GAP
	for line in view.get("talent_lines",[]):
		_text(canvas,font,Vector2(RIGHT_COLUMN,y+13.0),str(line),12,INK,COLUMN_WIDTH)
		y+=ROW_H+ROW_GAP
	y+=SECTION_GAP
	_text(canvas,font,Vector2(RIGHT_COLUMN,y+13.0),"组合路线",14,GOLD,COLUMN_WIDTH)
	y+=ROW_H+ROW_GAP
	for route in view["routes"]:
		var row: Dictionary=route
		var tone := _tone(str(row["state"]))
		if bool(row["current"]):
			_text(canvas,font,Vector2(RIGHT_COLUMN-10.0,y+13.0),"▶",12,GOLD,12.0)
			tone=GOLD
		var keys := str(row["keys"])
		var keys_width := mini(_text_width(font,keys,12),COLUMN_WIDTH-136.0)
		_text(canvas,font,Vector2(RIGHT_COLUMN,y+13.0),str(row["name"]),12,tone,78.0)
		_text(canvas,font,Vector2(RIGHT_COLUMN+80.0,y+13.0),keys,12,tone,keys_width+4.0)
		var gate := int(row["gate"])
		var gate_text := "已解锁" if gate<=0 else ("已解锁 · 需锻造 +%d" % gate if str(row["state"])=="active" else "需锻造 +%d" % gate)
		_text(canvas,font,Vector2(RIGHT-64.0,y+13.0),gate_text,11,MUTED,66.0)
		y+=ROW_H+ROW_GAP

static func _cell(canvas: CanvasItem, at: Vector2, label: String, state: String, font: Font) -> void:
	var tone := _tone(state)
	var area := Rect2(at,Vector2(CHIP,CHIP))
	canvas.draw_rect(area,Color(tone,0.18 if state!="locked" else 0.07),true)
	canvas.draw_rect(area,Color(tone,0.9 if state!="locked" else 0.55),false,1.2)
	var width := _text_width(font,label,11)
	_text(canvas,font,Vector2(at.x+CHIP*0.5-width*0.5,at.y+CHIP-5.0),label,11,tone,width+4.0)

static func _tone(state: String) -> Color:
	if state=="active": return ACTIVE
	if state=="available": return AVAILABLE
	return LOCKED

# ------------------------------------------------------------------ 绘制小工具

## 字体来源与 `rogue_map_screen.gd:407` 一致：`Control` 走自己的主题默认字体。
static func _theme_font(canvas: CanvasItem) -> Font:
	var control := canvas as Control
	if control!=null:
		var font := control.get_theme_default_font()
		if font!=null:
			return font
	return ThemeDB.fallback_font

static func _text_width(font: Font, value: String, size: int) -> float:
	if font==null:
		return float(value.length()*size)*0.6
	return font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x

## `draw_string()` 不换行，所以所有调用点都给死宽度（`clip_w`）：宁可截断，也不让它压到邻列。
static func _text(canvas: CanvasItem, font: Font, at: Vector2, value: String, size: int, color: Color, width: float) -> void:
	if value=="":
		return
	if font==null:
		canvas.draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)
		return
	canvas.draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)
