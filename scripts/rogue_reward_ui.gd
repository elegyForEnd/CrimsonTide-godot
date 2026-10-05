extends Control
## Typography uses the actual painted inset bounds, measured from the v2 art.
const ALTAR = preload("res://assets/ui/rewards/treasure-altar-v2.png")
const Equipment = preload("res://scripts/rogue_equipment.gd")
const PAPER := Color("eee2cb")
const MUTED := Color("aaa9b6")
const GOLD := Color("dfbd79")
const QUALITY_NAMES := ["普通","精良","稀有","史诗","传说","神话"]
const CENTERS := [338.0,768.0,1198.0]
var host
var selected := -1
var selection: Dictionary
var markers: Array[Panel]=[]
var statuses: Array[Label]=[]
var portraits: Array[TextureRect]=[]
var take: Button
var share: Button
var caption: Label

func text(parent: Control, value: String, box: Rect2, font_size: int, color: Color = PAPER, centered: bool = false, serif: bool = false) -> Label:
	var node := Label.new()
	# Set wrapping/font before text and dimensions; long names must not widen cards.
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.clip_text=true
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.add_theme_constant_override("line_spacing",2)
	if serif: node.add_theme_font_override("font",host.title_font)
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.text=value
	node.position=box.position
	node.size=box.size
	parent.add_child(node)
	# Noto SC has tall ascenders. Godot clips the entire line when a label's
	# box is shorter than its font height, even if the glyphs appear to fit.
	node.size.y=maxf(box.size.y,node.get_theme_font("font").get_height(font_size))
	while font_size>16 and node.get_theme_font("font").get_height(font_size)*node.get_line_count()+2*maxi(0,node.get_line_count()-1)>node.size.y:
		font_size-=1
		node.add_theme_font_size_override("font_size",font_size)
	return node

func action_button(parent: Control, title: String, box: Rect2, callback: Callable) -> Button:
	var node := Button.new()
	node.clip_text=true
	node.add_theme_font_size_override("font_size",24)
	node.add_theme_font_override("font",host.title_font)
	for state in ["normal","hover","pressed","focus","disabled"]:
		node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	node.add_theme_color_override("font_color",PAPER)
	node.add_theme_color_override("font_hover_color",Color.WHITE)
	node.add_theme_color_override("font_pressed_color",GOLD)
	node.add_theme_color_override("font_disabled_color",Color("666675"))
	node.text=title
	node.position=box.position
	node.size=box.size
	node.focus_mode=Control.FOCUS_NONE
	node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	node.pressed.connect(func(): host.sound.play("ui"); callback.call())
	parent.add_child(node)
	return node

func choose(index: int) -> void:
	selected=index
	for i in markers.size():
		markers[i].visible=i==index
		statuses[i].text="已选中" if i==index else "点击卡牌选择"
		statuses[i].modulate=Color.WHITE if i==index else Color(1,1,1,0.7)
		portraits[i].scale=Vector2.ONE*(1.06 if i==index else 1.0)
	take.disabled=false
	share.disabled=false
	caption.text="收藏后可在构筑页分配修为" if selection.get("category","") in ["talent","core"] else "领取装备 · 或丢出后队友拾取"

func submit(kind: String) -> void:
	if selected<0: return
	host.session.action(kind,{"id":selection.id,"version":selection.version,"index":selected})

func card_body(parent: Control, offer: Dictionary, center: float) -> void:
	var left := center-137
	if offer.has("item"):
		var item: Dictionary=offer.item
		var row := 0
		for stat in ["hp","mana","damage","defense","speed","rate"]:
			var amount: float=Equipment.value(item,stat)
			if amount<=0: continue
			var x: float=left+(row%2)*145
			var y: float=576+floori(row/2.0)*32
			var percentage: bool=stat in ["damage","defense","rate"]
			var name: String={"hp":"生命","mana":"法力","damage":"攻击","defense":"减伤","speed":"移速","rate":"攻速"}[stat]
			text(parent,name,Rect2(x,y,60,27),20,MUTED)
			text(parent,"+%d%s" % [roundi(amount*100 if percentage else amount),"%" if percentage else ""],Rect2(x+59,y,70,27),21,GOLD)
			row+=1
		text(parent,"独特被动",Rect2(left,649,274,25),18,GOLD)
		var description: String=preload("res://scripts/rogue_content.gd").player_text(Equipment.description(item))
		if "：" in description: description=description.substr(description.find("：")+1)
		var body := text(parent,description,Rect2(left,679,274,94),16,PAPER)
		body.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	else:
		var body := text(parent,preload("res://scripts/rogue_content.gd").player_text(str(offer.desc)),Rect2(left,578,274,118),18,GOLD)
		body.vertical_alignment=VERTICAL_ALIGNMENT_TOP
		text(parent,"收藏天赋 · 行囊中激活\n未满足前置时可先收藏",Rect2(left,703,274,60),18,PAPER)

func build(owner, data: Dictionary) -> void:
	host=owner
	selection=data
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color=Color(0.005,0.006,0.014,0.9)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var holder := Control.new()
	holder.position=Vector2(90,30)
	holder.size=Vector2(1260,840)
	holder.pivot_offset=holder.size/2
	add_child(holder)
	var stage := Control.new()
	stage.size=Vector2(1536,1024)
	stage.scale=Vector2.ONE*(1260.0/1536.0)
	holder.add_child(stage)
	var backdrop: TextureRect=host.rogue_icon(stage,ALTAR,Vector2.ZERO,stage.size)
	backdrop.stretch_mode=TextureRect.STRETCH_SCALE
	var tier: int=selection.tier
	var quality: Color=Catalog.BAG_TIERS[tier].color
	var heading_title: String={"gear":"装 备 抉 择","weapon":"武 器 抉 择","boon":"天 赋 抉 择","talent":"灵 契 圣 坛","core":"核 心 灵 契"}.get(selection.get("category","gear"),"秘 藏 抉 择")
	text(stage,heading_title,Rect2(530,75,476,47),36,PAPER,true,true)
	caption=text(stage,"%s秘藏 · 选中卡牌后领取或分享" % QUALITY_NAMES[tier],Rect2(490,127,556,27),19,MUTED,true)
	if selection.get("category","") in ["talent","core"]: caption.text="选中天赋收藏 · Tab进入构筑配置"
	for i in selection.offers.size():
		var index: int=i
		var offer: Dictionary=selection.offers[i]
		var center: float=CENTERS[i]
		var hit := action_button(stage,"",Rect2(center-177,255,354,580),func(): choose(index))
		hit.tooltip_text=offer.desc
		hit.name="RewardCard%d" % i
		var marker := Panel.new()
		marker.position=hit.position
		marker.size=hit.size
		marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var border := StyleBoxFlat.new()
		border.bg_color=Color(0,0,0,0)
		border.border_color=Color(quality,0.6)
		border.set_border_width_all(2)
		border.set_corner_radius_all(24)
		border.shadow_color=Color(quality,0.12)
		border.shadow_size=12
		marker.add_theme_stylebox_override("panel",border)
		stage.add_child(marker)
		marker.hide()
		markers.append(marker)
		var picture: TextureRect=host.rogue_icon(stage,host.rogue_field.art.offer_icon(offer),Vector2(center-60,294),Vector2(120,120))
		picture.pivot_offset=Vector2(60,60)
		portraits.append(picture)
		var title: String=offer.name
		var category := "天赋"
		var subtitle := ""
		var preview := ""
		if offer.has("item"):
			var item: Dictionary=offer.item
			var definition: Dictionary=Equipment.definition(item)
			if item.kind=="weapon":
				title=Catalog.weapon(int(item.weapon)).name
				category="武器"
				subtitle="%s铭刻" % definition.name if not definition.is_empty() else "属性补正武器"
				var player: Dictionary=host.session.players[host.session.my_id()]
				var after: Dictionary=player.duplicate(true)
				after.equipped.weapon=item; after.weapon=int(item.weapon)
				preview="伤害 %.1f → %.1f\n%s" % [host.session.weapon_damage(player),host.session.weapon_damage(after),Catalog.scaling_text(int(item.weapon))]
			else:
				title=definition.get("name",Catalog.item_name(item))
				category=Catalog.gear_slot_name(item)
		else: subtitle="收藏 / 修为分配" if offer.has("talent_id") else "本局加成"
		var name_label := text(stage,title,Rect2(center-136,449,272,48),29,PAPER,true,true)
		name_label.name="RewardName%d" % i
		var metadata := "%s · %s" % [QUALITY_NAMES[tier],category]
		if not subtitle.is_empty(): metadata+=" · "+subtitle
		text(stage,metadata,Rect2(center-137,539,274,31),19,quality,true)
		if not preview.is_empty(): text(stage,preview,Rect2(center-137,576,274,64),16,PAPER)
		card_body(stage,offer,center)
		statuses.append(text(stage,"点击卡牌选择",Rect2(center-137,784,274,31),21,MUTED,true,true))
		picture.modulate.a=0.0
		create_tween().tween_property(picture,"modulate:a",1.0,0.3).set_delay(0.12+i*0.08)
	var payload := {"id":selection.id,"version":selection.version}
	var cards: int=host.session.players[host.session.my_id()].rogue_rerolls
	var reroll := action_button(stage,"刷新 · %d 张" % cards,Rect2(119,898,270,48),func(): host.session.action("rogue_selection_reroll",payload))
	reroll.disabled=cards<=0
	take=action_button(stage,"收藏天赋" if selection.get("category","") in ["talent","core"] else "领取奖励",Rect2(468,898,270,48),func(): submit("rogue_selection_take"))
	share=action_button(stage,"跳过本轮" if selection.get("category","") in ["talent","core"] else "丢给队友",Rect2(803,898,270,48),func():
		if selection.get("category","") in ["talent","core"]: host.session.action("rogue_selection_bank",payload)
		else: submit("rogue_selection_drop")
	)
	var back := action_button(stage,"放回秘藏",Rect2(1147,898,270,48),func(): host.session.action("rogue_selection_return",payload))
	back.disabled=selection.get("personal",false)
	take.disabled=true
	share.disabled=selection.get("category","") not in ["talent","core"]
	var burst := CPUParticles2D.new()
	burst.position=Vector2(768,208)
	burst.texture=preload("res://scripts/effect_semantics.gd").mote_texture()
	burst.amount=18
	burst.lifetime=0.7
	burst.one_shot=true
	burst.explosiveness=1.0
	burst.direction=Vector2(0,-1)
	burst.spread=160
	burst.initial_velocity_min=60
	burst.initial_velocity_max=180
	burst.gravity=Vector2(0,40)
	burst.scale_amount_min=0.008
	burst.scale_amount_max=0.018
	burst.color=Color(quality,0.55)
	stage.add_child(burst)
	holder.scale=Vector2.ONE*0.92
	holder.modulate.a=0.0
	var opening := create_tween().set_parallel(true)
	opening.tween_property(holder,"scale",Vector2.ONE,0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	opening.tween_property(holder,"modulate:a",1.0,0.2)
