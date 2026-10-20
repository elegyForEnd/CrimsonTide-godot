extends Control
## 升级弹窗：每级 1 点属性；每 3 级一次「雷霆十二式」三选一。
## 独立于 `rogue_panel` 的 HUD 树：只在有待选项时出现，选完自动收起。
const Abilities = preload("res://scripts/rogue_abilities.gd")
const Build = preload("res://scripts/rogue_build.gd")
const PAPER := Color("eee2cb")
const MUTED := Color("a6abbc")
const GOLD := Color("dfbd79")
const CYAN := Color("83dcff")
var host
var mode := ""
var player: Dictionary

func text(parent: Control, value: String, at: Vector2, size: Vector2, font_size: int, color: Color = PAPER, centered: bool = false) -> Label:
	var node := Label.new()
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.clip_text=true
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.add_theme_constant_override("line_spacing",2)
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.text=value
	node.position=at
	node.size=size
	parent.add_child(node)
	node.size.y=maxf(size.y,node.get_theme_font("font").get_height(font_size))
	return node

func act(kind: String, payload: Dictionary) -> void:
	var live: Dictionary=host.session.players.get(host.session.my_id(),{})
	if live.is_empty(): return
	payload["revision"]=int(host.session.raid.revision)
	payload["version"]=int(live.get("rogue_inventory_revision",0))
	host.session.action(kind,payload)

func build(owner, p: Dictionary) -> void:
	host=owner; player=p
	mode="attributes" if int(p.get("build_pending_levels",0))>0 else "ability"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	for child in get_children(): child.queue_free()
	var veil := ColorRect.new()
	veil.color=Color(0.004,0.006,0.012,0.82)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var holder := Control.new()
	holder.position=Vector2(250,150)
	holder.size=Vector2(940,600)
	add_child(holder)
	var panel := Panel.new()
	panel.position=Vector2.ZERO
	panel.size=holder.size
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.028,0.022,0.040,0.98)
	style.border_color=Color(CYAN if mode=="ability" else GOLD,0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color=Color(CYAN if mode=="ability" else GOLD,0.16)
	style.shadow_size=24
	panel.add_theme_stylebox_override("panel",style)
	holder.add_child(panel)
	var title := "升 级 · 选 择 属 性" if mode=="attributes" else "雷 能 获 取 · 三 选 一"
	text(panel,title,Vector2(30,24),Vector2(880,52),34,PAPER,true)
	if mode=="attributes":
		text(panel,"Lv.%d · 本级 +1 点 · 还需选择 %d 次" % [int(p.build_level),int(p.build_pending_levels)],Vector2(30,78),Vector2(880,30),18,GOLD,true)
		var values := Build.attributes(p)
		for i in WatcherAttributes.KEYS.size():
			var key: String=WatcherAttributes.KEYS[i]
			var column := i%2
			var row := floori(i/2.0)
			var at := Vector2(55+column*455,132+row*92)
			var button := Button.new()
			button.position=at; button.size=Vector2(415,76)
			button.text="%s   %d   →   +1" % [WatcherAttributes.NAMES[i],int(values[key])]
			button.add_theme_font_size_override("font_size",22)
			button.add_theme_color_override("font_color",PAPER)
			button.add_theme_color_override("font_hover_color",Color.WHITE)
			button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
			button.add_theme_stylebox_override("normal",_style(Color(0.06,0.05,0.08,0.95),Color(GOLD,0.35)))
			button.add_theme_stylebox_override("hover",_style(Color(0.10,0.08,0.11,1.0),Color(GOLD,0.9)))
			button.pressed.connect(func(): act("rogue_level_choice",{"stat":key}))
			panel.add_child(button)
		text(panel,"选择后立即生效 · 本局有效 · 每级只能加 1 点",Vector2(30,528),Vector2(620,26),16,MUTED)
		_later_button(panel)
	else:
		var offers: Array=p.get("build_ability_offers",[])
		text(panel,"待选 %d 次 · 每次从 3 个不同能力中选 1 个" % int(p.build_pending_abilities),Vector2(30,78),Vector2(880,30),17,GOLD,true)
		for i in mini(3,offers.size()):
			var offer: Dictionary=offers[i]
			var key := str(offer.get("ability_key",""))
			var center := 170.0+i*300.0
			var card := Button.new()
			card.position=Vector2(center-135,128)
			card.size=Vector2(270,380)
			card.add_theme_stylebox_override("normal",_style(Color(0.05,0.045,0.075,0.98),Color(str(offer.get("color","83dcff")),0.45)))
			card.add_theme_stylebox_override("hover",_style(Color(0.08,0.07,0.11,1.0),Color(str(offer.get("color","83dcff")),0.95)))
			var index := i
			card.pressed.connect(func(): act("rogue_ability_choice",{"index":index}))
			panel.add_child(card)
			var icon: TextureRect=host.rogue_icon(panel,host.rogue_field.art.offer_icon(offer),Vector2(center-48,152),Vector2(96,96))
			icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
			text(panel,str(offer.get("name","")),Vector2(center-130,260),Vector2(260,38),26,PAPER,true)
			text(panel,"%s · %s" % [str(offer.get("ability_action","")),Abilities.pips(p,key)],Vector2(center-130,300),Vector2(260,28),17,CYAN,true)
			text(panel,"当前："+Abilities.rank_text(key,Abilities.rank(p,key)) if Abilities.rank(p,key)>0 else "尚未获取",Vector2(center-122,338),Vector2(244,44),15,MUTED,true)
			text(panel,"下一阶："+str(offer.get("desc","")),Vector2(center-122,390),Vector2(244,96),16,GOLD,true)
		if offers.is_empty():
			text(panel,"正在结算雷能……",Vector2(30,250),Vector2(880,40),24,GOLD,true)
		text(panel,"同名能力最多 3 次 · 满 3 次后不再出现",Vector2(30,528),Vector2(620,26),16,MUTED)
		_later_button(panel)

func _later_button(panel: Control) -> void:
	var later := Button.new()
	later.position=Vector2(700,522)
	later.size=Vector2(210,38)
	later.text="稍后再说 · L 打开"
	later.add_theme_font_size_override("font_size",16)
	later.add_theme_color_override("font_color",PAPER)
	later.add_theme_color_override("font_hover_color",Color.WHITE)
	later.add_theme_stylebox_override("normal",_style(Color(0.06,0.05,0.08,0.95),Color(CYAN,0.35)))
	later.add_theme_stylebox_override("hover",_style(Color(0.10,0.08,0.11,1.0),Color(CYAN,0.9)))
	later.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	later.pressed.connect(func(): host.rogue_level_defer())
	panel.add_child(later)

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
