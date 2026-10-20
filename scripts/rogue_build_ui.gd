extends Control
const Build = preload("res://scripts/rogue_build.gd")
const Abilities = preload("res://scripts/rogue_abilities.gd")
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
	text(self,"修为 %d / %d   ·   天赋 %d / 8   ·   雷霆 %d / 36   ·   魔晶 %d   ·   %s" % [Build.talent_cost(p),p.build_cultivation,p.build_talents.size(),Abilities.total_rank(p),p.rogue_gold,"休整中，可调整" if safe else "战斗中，配置已锁定"],Vector2(67,96),Vector2(1230,34),17,MUTED)
	button(self,"返回行囊",Vector2(1220,40),Vector2(150,44),func(): host.rogue_inventory.selected_tab="reserve"; host.show_inventory())
	var keys := ["abilities","talents","attributes","codex"]
	for i in keys.size():
		var key: String=keys[i]
		var b := button(self,["雷霆能力","天赋与流派","七属性","构筑图鉴"][i],Vector2(67+i*315,150),Vector2(300,45),func(): remember_scroll(); section=key; host.show_inventory())
		if key==section: b.modulate=GOLD
	scroll=ScrollContainer.new()
	scroll.position=Vector2(66,214); scroll.size=Vector2(1305,607)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	body=Control.new(); body.custom_minimum_size=Vector2(1280,607)
	scroll.add_child(body)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value): remember_scroll())
	match section:
		"abilities": abilities()
		"talents": talents()
		"attributes": attribute_sheet()
		"codex": codex()
	# Seed the correct range immediately, avoiding a visible frame at the top.
	var vertical_bar := scroll.get_v_scroll_bar()
	vertical_bar.max_value=body.custom_minimum_size.y
	vertical_bar.page=scroll.size.y
	scroll.scroll_vertical=saved_scroll
	restore_scroll.call_deferred(saved_scroll)
	text(self,"F 喝血瓶 · Space 闪避 · C 跃起 · 左键攻击 · 右键战技 · Q 角色奥义",Vector2(68,841),Vector2(1290,30),16,MUTED)

func abilities() -> void:
	text(body,"雷霆十二式：每 3 级三选一；同名最多获取 3 次（1 解锁 + 2 次强化），满 3 次后移出池。全局无获取上限。",Vector2(8,0),Vector2(1220,38),19,GOLD)
	text(body,"当前总阶位 %d / %d。能力不占天赋槽、不耗修为，本局结束清除；宝箱不再出能力。" % [Abilities.total_rank(player),Abilities.MAX_RANK*Abilities.TRACKS.size()],Vector2(8,42),Vector2(1220,34),17,MUTED)
	for i in Abilities.TRACKS.size():
		var entry: Dictionary=Abilities.TRACKS[i]
		var key := str(entry.key)
		var level := Abilities.rank(player,key)
		var column := i%2
		var line := floori(i/2.0)
		var box := row(Vector2(column*638,86+line*176),Vector2(616,164))
		host.rogue_icon(box,Art.icon(str(entry.icon)),Vector2(16,18),Vector2(62,62))
		text(box,"%s · %s" % [str(entry.name),str(entry.action)],Vector2(92,8),Vector2(330,30),21,GOLD if level>0 else MUTED)
		text(box,Abilities.pips(player,key),Vector2(430,8),Vector2(150,30),20,Color(str(entry.color)) if level>0 else Color("5f6273"))
		var current_text := Abilities.rank_text(key,level) if level>0 else "尚未获取"
		text(box,"当前："+current_text,Vector2(92,43),Vector2(500,58),14,PAPER if level>0 else MUTED)
		var next := Abilities.offer_for(player,key)
		text(box,"下一阶："+str(next.get("desc","")) if not next.is_empty() else "已满 3 次 · 不再出现",Vector2(92,105),Vector2(500,50),14,GOLD if not next.is_empty() else MUTED)
	body.custom_minimum_size.y=86+6*176

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
	text(body,"局内 Lv.%d　经验 %d / %d　·　升级待选 %d　·　额外属性点 %d" % [player.build_level,player.build_xp,Build.xp_needed(int(player.build_level)),int(player.get("build_pending_levels",0)),player.build_attribute_points],Vector2(15,0),Vector2(1210,38),23,GOLD)
	text(body,"每升一级弹出七属性选择，选 1 项 +1；每 3 级额外弹出雷霆能力三选一。普通怪2 / 精英6 / 首领20经验，全队共享。\n局内加点到本局结束；40 / 70后成长降低，增加生命/蓝量上限不补当前资源。",Vector2(15,44),Vector2(1220,55),17,MUTED)
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

func codex() -> void:
	var categories := ["weapons","gear","talents"]
	for i in categories.size():
		var key: String=categories[i]
		button(body,["48武器","72装备","96天赋"][i],Vector2(i*260,0),Vector2(240,42),func(): codex_category=key; host.show_inventory())
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
