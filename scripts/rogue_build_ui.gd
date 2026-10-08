extends Control
const Build = preload("res://scripts/rogue_build.gd")
const Content = preload("res://scripts/rogue_content.gd")
const Art = preload("res://scripts/rogue_build_art.gd")
const PAPER := Color("e9e0d3")
const GOLD := Color("d9b578")
const MUTED := Color("9ea6bc")
static var section := "talents"
static var scroll_positions: Dictionary={}
static var codex_category := "weapons"
var host
var player: Dictionary
var body: Control
var safe := false
var scroll: ScrollContainer
var built_section := ""
var restoring_scroll := true

func remember_scroll() -> void:
	if is_instance_valid(scroll) and not restoring_scroll:
		scroll_positions[built_section]=scroll.scroll_vertical

func restore_scroll(value: int) -> void:
	# Container ranges are calculated after the content is laid out.
	await get_tree().process_frame
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	scroll.scroll_vertical=value
	restoring_scroll=false
	remember_scroll()

func _exit_tree() -> void:
	remember_scroll()

func text(parent: Node, value: String, at: Vector2, dimensions: Vector2, size: int = 18, color: Color = PAPER) -> Label:
	var label: Label=host.label(parent,value,at,size,color,dimensions)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.size.y=maxf(dimensions.y,label.get_theme_font("font").get_height(size)+4)
	return label

func button(parent: Node, title: String, at: Vector2, dimensions: Vector2, callback: Callable, disabled: bool = false) -> Button:
	var result: Button=host.button(parent,title,at,dimensions,callback,false,16)
	result.disabled=disabled
	return result

func command(verb: String, id: String = "", index: int = -1) -> void:
	remember_scroll()
	host.session.action("rogue_build",{"verb":verb,"id":id,"index":index,"version":int(player.rogue_inventory_revision)})

func row(at: Vector2, dimensions: Vector2) -> Panel:
	var result: Panel=host.rect(body,at,dimensions,Color("131d2b"),Color("4c4852"))
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

func build(app, p: Dictionary) -> void:
	host=app; player=p; safe=Build.safe(host.session,p)
	built_section=section
	var saved_scroll := int(scroll_positions.get(built_section,0))
	size=Vector2(1440,900)
	host.overlay.add_child(self)
	host.rect(self,Vector2.ZERO,size,Color(.012,.016,.027,.98))
	text(self,"守 夜 人 · 构 筑",Vector2(65,40),Vector2(720,48),30,GOLD)
	text(self,"修为 %d / %d   ·   天赋 %d / 8   ·   魔晶 %d   ·   %s" % [Build.talent_cost(p),p.build_cultivation,p.build_talents.size(),p.rogue_gold,"休整中，可调整" if safe else "战斗中，配置已锁定"],Vector2(67,96),Vector2(1230,34),17,MUTED)
	button(self,"返回行囊",Vector2(1220,40),Vector2(150,44),func(): host.rogue_inventory.selected_tab="reserve"; host.show_inventory())
	var keys := ["talents","attributes","forge","combos","codex"]
	for i in keys.size():
		var key: String=keys[i]
		var b := button(self,["天赋与流派","七属性","武器锻造","连招手册","构筑图鉴"][i],Vector2(67+i*254,150),Vector2(238,45),func(): remember_scroll(); section=key; host.show_inventory())
		if key==section: b.modulate=GOLD
	scroll=ScrollContainer.new()
	scroll.position=Vector2(66,214); scroll.size=Vector2(1305,607)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	body=Control.new(); body.custom_minimum_size=Vector2(1280,607)
	scroll.add_child(body)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value): remember_scroll())
	match section:
		"talents": talents()
		"attributes": attribute_sheet()
		"forge": forge()
		"combos": combos()
		"codex": codex()
	# Seed the correct range immediately, avoiding a visible frame at the top.
	var vertical_bar := scroll.get_v_scroll_bar()
	vertical_bar.max_value=body.custom_minimum_size.y
	vertical_bar.page=scroll.size.y
	scroll.scroll_vertical=saved_scroll
	restore_scroll.call_deferred(saved_scroll)
	text(self,"F 喝血瓶 · Space 闪避 · C 跃起 · 左键攻击 · 右键战技 · Q 角色奥义",Vector2(68,841),Vector2(1290,30),16,MUTED)

func talents() -> void:
	text(body,"激活最多8项、1个流派核心。普通/进阶每级1修为，核心3修为。进阶需同流派普通；核心需同流派投入2点。",Vector2(8,0),Vector2(1210,55),17,MUTED)
	text(body,"获取：每层1～2座灵契圣坛，每座两轮三选一；第二层首座另有核心选择。",Vector2(8,56),Vector2(1210,35),17,GOLD)
	if player.build_library.is_empty():
		text(body,"天赋来自灵契圣坛，每层1～2座，每座两轮三选一。完成区域另获修为；收藏不消耗修为。",Vector2(35,130),Vector2(1080,100),24,GOLD)
		return
	var ids: Array=player.build_library.duplicate()
	# Keep acquisition order so upgrading a row does not move it under the cursor.
	for i in ids.size():
		var id: String=ids[i]
		var def := Content.entry(id)
		var y := 100+i*136
		var level := int(player.build_talents.get(id,0))
		var box := row(Vector2(0,y),Vector2(1255,125))
		host.rogue_icon(box,Art.icon(id),Vector2(17,22),Vector2(78,78))
		text(box,"%s  ·  %s  ·  %d / %d级" % [def.name,Content.SCHOOLS[int(def.school)],level,def.max_rank],Vector2(115,9),Vector2(810,30),22,GOLD if level>0 else MUTED)
		text(box,Content.player_text(str(def.text)),Vector2(115,47),Vector2(810,64),16,PAPER)
		var proposed: Dictionary=player.build_talents.duplicate(true); proposed[id]=level+1
		var plus := button(box,"+ 激活 / 升级",Vector2(1000,14),Vector2(235,42),func(): command("talent_up",id),not safe or not Build.legal_talents(proposed,int(player.build_cultivation)))
		plus.name="TalentActivate_"+id
		plus.tooltip_text=Build.activation_reason(player,id)
		var minus := button(box,"− 降级" if level>0 else "遗忘收藏",Vector2(1000,69),Vector2(235,40),func(): command("talent_down" if level>0 else "forget",id),not safe)
		minus.name="TalentRemove_"+id
	body.custom_minimum_size.y=100+ids.size()*136

func attribute_sheet() -> void:
	var values := Build.attributes(player)
	text(body,"局内 Lv.%d　经验 %d / %d　·　可分配属性点 %d" % [player.build_level,player.build_xp,Build.xp_needed(int(player.build_level)),player.build_attribute_points],Vector2(15,0),Vector2(1210,38),23,GOLD)
	text(body,"每升一级+2点；普通怪2 / 精英6 / 首领20经验，全队共享。宝箱20%（首领50%）掉1点，每层最多掉2次。\n局内加点到本局结束；40 / 70后成长降低，增加生命/蓝量上限不补当前资源。",Vector2(15,44),Vector2(1220,55),17,MUTED)
	for i in WatcherAttributes.KEYS.size():
		var key: String=WatcherAttributes.KEYS[i]
		var y := 105+i*68
		var box := row(Vector2(0,y),Vector2(1255,61))
		text(box,WatcherAttributes.NAMES[i],Vector2(20,10),Vector2(150,36),22,GOLD)
		text(box,str(values[key]),Vector2(180,10),Vector2(74,36),25)
		text(box,"初始 %d + 永久 %d + 本局 %d" % [Build.HERO_BASE[player.hero][i],int(player.attributes.get(key,10))-10,int(player.build_attributes.get(key,0))],Vector2(280,14),Vector2(390,30),17,MUTED)
		text(box,WatcherAttributes.DESCRIPTIONS[i],Vector2(680,15),Vector2(430,28),16)
		button(box,"+1",Vector2(1138,9),Vector2(93,43),func(): command("attribute",key),not safe or player.build_attribute_points<=0 or values[key]>=99)
	button(body,"重置本局属性（每层一次）",Vector2(0,610),Vector2(360,45),func(): command("respec"),not safe or player.build_respec_floor==int(host.session.raid.floor))
	text(body,"武器补正："+Catalog.scaling_text(int(player.weapon),Build.grades(player,int(player.weapon)))+"\n当前武器属性加成：+%.1f%%　·　角色奥义属性加成：+%.1f%%" % [host.session.weapon_scaling(player)*100,WatcherAttributes.scaling(values,Build.HERO_GRADES[int(player.hero)])*100],Vector2(400,610),Vector2(835,76),18,GOLD)
	body.custom_minimum_size.y=710

func forge() -> void:
	var level := int(player.build_forge_level)
	var bound_level := Build.forge_level(player)
	text(body,"%s　+%d　·　锻造点 %d" % [Catalog.weapon_name(int(player.weapon)),bound_level,player.build_forge_points],Vector2(10,0),Vector2(1150,44),27,GOLD)
	text(body,"+1闪避派生　+2武器核心　+3空中/角色连招与补正分支　+4核心进阶　+5角色终式。每级攻击+3%。",Vector2(10,55),Vector2(1220,55),18,MUTED)
	var cost: int=Build.FORGE_COST[level] if level<5 else 0
	button(body,"升级 +%d · %d锻造点" % [mini(5,level+1),cost] if level<5 else "已达到 +5",Vector2(10,119),Vector2(340,46),func(): command("forge"),not safe or player.equipped.weapon.is_empty() or level>=mini(5,int(host.session.raid.floor)) or player.build_forge_points<cost)
	button(body,"转移锻造到当前武器",Vector2(380,119),Vector2(310,46),func(): command("bind"),not safe or player.equipped.weapon.is_empty() or str(player.equipped.weapon.get("instance_id",""))==str(player.build_forge_bound))
	text(body,"锻造等级上限为当前层数。转移免费；旧武器回到+0，需要重新选择核心与补正。",Vector2(715,122),Vector2(530,63),16,MUTED)
	var family := Catalog.weapon_family(int(player.weapon))
	var index := 0
	for def in Content.data.cores:
		if int(def.family)!=family: continue
		var id: String=def.id
		var box := row(Vector2(0,211+index*120),Vector2(1255,110))
		host.rogue_icon(box,Art.icon(id),Vector2(18,18),Vector2(77,77))
		text(box,str(def.name),Vector2(114,10),Vector2(810,30),23,GOLD)
		text(box,Content.player_text(str(def.text)),Vector2(114,48),Vector2(810,51),16)
		button(box,"已激活" if player.build_core==id else "选择核心",Vector2(1000,31),Vector2(233,43),func(): command("core",id),not safe or bound_level<2 or player.build_core==id)
		index+=1
	text(body,"+3 补正分支（任选一项）",Vector2(10,595),Vector2(1130,35),22,GOLD)
	var options: Array=["steady"]
	for key in ["strength","dexterity","intelligence","arcane"]:
		if Catalog.weapon(int(player.weapon)).get("scaling",{}).get(key,"-") not in ["-","S"]: options.append(key)
	for i in options.size():
		var key: String=options[i]
		var title: String="稳锋 · 普攻/战技+4%" if key=="steady" else WatcherAttributes.NAMES[WatcherAttributes.KEYS.find(key)]+"补正提升一级"
		button(body,title+(" ✓" if player.build_temper==key else ""),Vector2((i%3)*422,645+floori(i/3.0)*55),Vector2(403,46),func(): command("temper",key),not safe or bound_level<3)
	text(body,"铭刻（35魔晶，仅休整可替换）",Vector2(10,775),Vector2(1200,35),23,GOLD)
	for i in Content.data.engravings.size():
		var n: int=i
		var def: Dictionary=Content.data.engravings[i]
		# 铭刻：`command("engrave","",n)` 的第三个实参 `n` 进的是 **`index`**，服务端
		# `Build.management()` 的 `"engrave"` 分支读的正是 `payload.get("index",-1)`
		# （`rogue_build.gd:866`：`var n := int(payload.get("index",-1))`，随后
		# `p.equipped.weapon.rogue_id=n`）。链条：本按钮 → `command()`（本文件 :29）
		# → `host.session.action("rogue_build",{verb,id,index,version})`
		# → `roguelike.choose()` → `Build.management()` → `"engrave"`。
		# `id` 必须留空：铭刻的符文序号走 `index`，不走 `id`。
		var b := button(body,str(def.name)+(" ✓" if Build.engraving(player,i+1) else ""),Vector2((i%6)*211,825+floori(i/6.0)*57),Vector2(195,46),func(): command("engrave","",n),not safe or player.equipped.weapon.is_empty() or player.rogue_gold<35 or Build.engraving(player,i+1))
		b.icon=Art.icon(str(def.id)); b.expand_icon=true; b.add_theme_constant_override("icon_max_width",32)
		b.tooltip_text=Content.player_text(str(def.text))
	body.custom_minimum_size.y=1068

func combos() -> void:
	text(body,"A=左键攻击　D=Space闪避　S=右键战技　U=Q奥义　J=C跃起",Vector2(10,0),Vector2(1200,43),24,GOLD)
	text(body,"短按衔接动作，每次按键只计入一段。重武器允许更长衔接间隔。战技与奥义需要实际蓝量和冷却就绪。",Vector2(10,52),Vector2(1230,53),18,MUTED)
	var route: int=[1,2,0,3].find(Catalog.weapon_family(int(player.weapon)))
	for i in 4:
		# P3 · 解锁门槛与名字都跟 `rogue_build.gd` 的**权威表**对齐：
		#   * 门槛 = `:609` 的 `[0,1,3,3] if family==1 else [0,1,0,3]`（本文件原来把
		#     "折返派生 ADS（实际 +3）"写成了"需要 +1"，文案与真实门槛不符）；
		#   * 名字 = `:612` 的 `["闪避追击","折返派生","升空 / 跃击","落地连段"]`（本文件原来把
		#     第 2、3 段写反了）。两份实现必须逐字一致，否则玩家照着 UI 练招会被误导。
		var family := Catalog.weapon_family(int(player.weapon))
		var gate: int=[0,1,3,3][i] if family==1 else [0,1,0,3][i]
		var unlocked: bool=Build.forge_level(player)>=gate
		var box := row(Vector2(0,128+i*76),Vector2(1255,67))
		text(box,["闪避追击","折返派生","升空 / 跃击","落地连段"][i],Vector2(20,12),Vector2(270,35),22,GOLD)
		text(box," → ".join(Build.CM_ROUTES[route][i].split("")),Vector2(310,13),Vector2(730,34),24)
		text(box,"已解锁" if unlocked else "需要 +%d" % gate,Vector2(1080,15),Vector2(165,30),17,GOLD if unlocked else MUTED)
	text(body,Catalog.HEROES[player.hero].name+" · 角色派生",Vector2(10,475),Vector2(1200,38),26,GOLD)
	for i in 4:
		var box := row(Vector2(0,529+i*76),Vector2(1255,67))
		text(box,["追击式","凌空式","奥义式","终式"][i],Vector2(20,12),Vector2(270,35),22,GOLD)
		text(box," → ".join(Build.HC_ROUTES[player.hero][i].split("")),Vector2(310,13),Vector2(730,34),24)
		text(box,"已解锁" if Build.forge_level(player)>=3 else "需要 +3",Vector2(1080,15),Vector2(165,30),17,MUTED)
	text(body,"角色派生共享8秒冷却。跃起可越过贴地危险；普通攻击仍能命中空中角色。空中最多两次普攻、一次战技与一次闪避。",Vector2(12,861),Vector2(1200,80),18,MUTED)
	body.custom_minimum_size.y=965

func codex() -> void:
	var categories := ["weapons","gear","talents","engravings","cores"]
	for i in categories.size():
		var key: String=categories[i]
		button(body,["48武器","72装备","96天赋","24铭刻","12核心"][i],Vector2(i*251,0),Vector2(231,42),func(): codex_category=key; host.show_inventory())
	var entries: Array=Content.data[codex_category]
	for i in entries.size():
		var def: Dictionary=entries[i]
		var box := row(Vector2((i%2)*638,69+floori(i/2.0)*171),Vector2(616,160))
		text(box,"%s · %s" % [def.id,def.name],Vector2(18,8),Vector2(580,31),22,GOLD)
		host.rogue_icon(box,Art.icon(str(def.id)),Vector2(15,51),Vector2(83,83))
		var desc: String=str(def.get("text",def.get("desc","")))
		if codex_category=="weapons": desc+="\n伤害 %.0f · 周期 %.2fs · 战技 %s\n%s" % [def.damage,def.rate,def.art.name,Catalog.scaling_text(600+i)]
		text(box,Content.player_text(desc),Vector2(114,48),Vector2(480,100),16,PAPER)
	body.custom_minimum_size.y=69+ceili(entries.size()/2.0)*171
