extends SceneTree
const Campaign=preload("res://scripts/scarlet/campaign.gd")
const InventoryUI=preload("res://scripts/story_items_ui.gd")
var checks := 0
var failures := 0
var screen
var ui
class FixtureScreen extends Control:
	var campaign=Campaign.new()
	func close_panel() -> void: pass
	func refresh() -> void: pass
	func npc_name(_id: int) -> String: return "营地铁匠"
	func label(parent, value, at, extent, font=18):
		var node := Label.new(); node.text=value; node.position=at; node.size=extent; node.add_theme_font_size_override("font_size",font); parent.add_child(node); return node
	func button(parent, value, at, extent, action):
		var node := Button.new(); node.text=value; node.position=at; node.size=extent; node.pressed.connect(action); parent.add_child(node); return node
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func dialog() -> AcceptDialog:
	for child in ui.get_children():
		if child is AcceptDialog and not child.is_queued_for_deletion(): return child
	return null
func find_button(node: Node, prefix: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text.begins_with(prefix): return child
		var found := find_button(child,prefix)
		if found: return found
	return null
func capture(name: String) -> void:
	for i in 4: await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/rpg-equipment-"+name+".png")==OK,"rendered equipment UI "+name)
func run() -> void:
	root.size=Vector2i(1440,900); root.content_scale_size=Vector2i(1440,900)
	root.gui_embed_subwindows=true
	screen=FixtureScreen.new(); screen.size=Vector2(1440,900); screen.theme=preload("res://scripts/scarlet/art.gd").theme(); root.add_child(screen)
	var c=screen.campaign
	c.save_enabled=false; c.state=c.new_state(); c.inventory.initialize(); c.loot_rng.seed=5380
	c.state.act=5; c.state.coins=15000; c.state.materials=300
	for slot in c.inventory.SLOTS: c.state.equipment[0][slot]=c.inventory.make_loot(0,5,3,c.loot_rng,slot)
	c.inventory.sync_gear()
	var rare: Dictionary=c.inventory.make_loot(0,5,2,c.loot_rng,"blade"); c.inventory.receive(rare)
	c.inventory.receive(c.inventory.make_loot(1,4,4,c.loot_rng,"blade"))
	for base in ["crystal","gem_ember","gem_rime","gem_gale"]: c.inventory.receive(c.inventory.make(base,1,0,5))
	ui=InventoryUI.new(); ui.screen=screen; ui.position=Vector2(72,70); ui.tab="forge"; screen.add_child(ui)
	ui.select("bag",rare.uid)
	check(find_button(ui.content,"词缀 / 比较")!=null,"visible detail entry exists")
	await capture("forge")
	find_button(ui.content,"词缀 / 比较").pressed.emit(); await process_frame
	check(dialog()!=null,"real button opens a scrollable description window")
	check(find_button(dialog(),"重铸所选数值")!=null,"rare detail exposes reforge control")
	await capture("comparison")
	var gold: int=c.state.coins
	find_button(dialog(),"重铸所选数值").pressed.emit(); await process_frame
	check(c.state.coins<gold and c.inventory.item_at("bag",rare.uid).reforges==1,"real dialog button reforges owned item")
	find_button(dialog(),"镶嵌 / 替换").pressed.emit(); await process_frame
	check(c.inventory.item_at("bag",rare.uid).socket,"dialog button inscribes actual crystal")
	find_button(dialog(),"锁定装备").pressed.emit(); await process_frame
	check(c.inventory.item_at("bag",rare.uid).locked and find_button(dialog(),"重铸所选数值").disabled,"lock callback protects item and disables reforge")
	dialog().queue_free(); await process_frame
	ui.show_equipment_codex(); await process_frame
	check(dialog()!=null and find_button(dialog(),"打造主手")!=null,"codex has actual targeted recipes")
	var scroll: ScrollContainer=dialog().get_child(0).get_child(0)
	check(scroll.get_child(0).size.x<=scroll.size.x,"codex content and recipe rows fit the visible width")
	await capture("codex")
	var crafted: int=c.state.item_serial
	find_button(dialog(),"打造主手").pressed.emit(); await process_frame
	check(c.state.item_serial==crafted+1,"real codex recipe creates one persistent instance")
	dialog().queue_free(); await process_frame
	ui.select("equipped:0:armor",c.state.equipment[0].armor.uid); ui.show_equipment_details(); await process_frame
	await capture("set")
	dialog().queue_free(); await process_frame
	for item in c.state.bag:
		if int(item.quality)==4: ui.select("bag",item.uid); break
	ui.show_equipment_details(); await process_frame
	check(find_button(dialog(),"重铸所选数值")==null,"unique powers cannot be reforged")
	await capture("unique")
	dialog().queue_free(); await process_frame
	# All new materials render through the existing atlas without a missing-description key.
	for item in c.state.bag:
		if str(item.base).begins_with("gem_"):
			ui.select("bag",item.uid); check(ui.details.text.contains("特殊晶石"),"special gem has a valid UI description")
	screen.free()
	print("RPG_EQUIPMENT_UI %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
