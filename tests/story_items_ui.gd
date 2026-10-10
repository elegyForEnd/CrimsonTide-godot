extends SceneTree
const Screen = preload("res://scripts/story_screen.gd")
const Items = preload("res://scripts/story_inventory.gd")
var checks := 0
var failures := 0
var screen
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func item_ui(): return screen.overlay.get_child(1)
func capture(name: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/story-items-"+name+".png")==OK,"real UI screenshot "+name)
func click(at: Vector2) -> void:
	Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new(); motion.position=at; Input.parse_input_event(motion)
	await process_frame
	var down := InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.position=at; down.pressed=true; Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new(); up.button_index=MOUSE_BUTTON_LEFT; up.position=at; up.pressed=false; Input.parse_input_event(up)
	await process_frame
func run() -> void:
	root.size=Vector2i(1440,900)
	DisplayServer.window_set_size(Vector2i(1440,900))
	screen=Screen.new(); root.add_child(screen); screen.campaign.save_enabled=false
	screen.start("user://story-item-ui-fixture.json"); screen.campaign.save_enabled=false
	screen.campaign.state=screen.campaign.new_state(); screen.campaign.inventory.initialize(); screen.campaign.enter(1,0)
	screen.set_physics_process(false)
	var c=screen.campaign; var inv=c.inventory
	c.state.coins=1800; c.state.materials=40; c.state.xp=225
	for base in Items.BASES:
		inv.receive(inv.make(base,2,1 if Items.BASES[base].slot in Items.SLOTS else 0,3 if base in ["potion","scrap","crystal"] else 1))
	for hero in 3:
		for slot in Items.SLOTS:
			for item in c.state.bag.duplicate():
				if inv.can_equip("bag",item.uid,hero,slot): inv.equip("bag",item.uid,hero,slot); break
	for base in ["sword","plate","staff","robe","raven","frost"]: inv.receive(inv.make(base,2,2))
	screen.show_bag(); await process_frame
	var ui=item_ui(); var grid=ui.grids[0]
	check(screen.modal and ui.tab=="bag" and ui.grids.size()==4,"inventory opens actual grid and three equipment slots")
	var uid: String=c.state.bag[0].uid
	var item: Dictionary=inv.item_at("bag",uid)
	await click(ui.position+grid.position+Vector2(item.x,item.y)*grid.cell+Vector2(25,25))
	check(ui.selected_uid==uid and ui.detail_title.text.contains(item.name),"real mouse click selects item and details")
	# Native drag starts from a real pressed mouse and crosses to an empty exact cell.
	var from: Vector2=ui.position+grid.position+Vector2(item.x,item.y)*grid.cell+Vector2(25,25)
	var to: Vector2=ui.position+grid.position+Vector2(9,5)*grid.cell+Vector2(25,25)
	var down := InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.position=from; down.pressed=true; Input.parse_input_event(down); await process_frame
	Input.warp_mouse(from+Vector2(18,0))
	var motion := InputEventMouseMotion.new(); motion.position=from+Vector2(18,0); motion.relative=Vector2(18,0); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(motion); await process_frame
	motion=InputEventMouseMotion.new(); motion.position=to; motion.relative=to-from; motion.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(motion); await process_frame
	Input.warp_mouse(to)
	await process_frame
	check(root.gui_is_dragging(),"actual mouse gesture starts Godot native drag")
	var release := InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.position=to; release.pressed=false; Input.parse_input_event(release); await process_frame
	check(inv.item_at("bag",uid).x==9 and inv.item_at("bag",uid).y==5,"actual mouse drop commits exact cell")
	# Rotate a long item while the native drag is active, then place on the last row.
	ui=item_ui(); grid=ui.grids[0]
	var long_item: Dictionary={}
	for candidate in c.state.bag:
		if candidate.base=="sword": long_item=candidate; break
	from=ui.position+grid.position+Vector2(long_item.x,long_item.y)*grid.cell+Vector2(20,20)
	to=ui.position+grid.position+Vector2(3,5)*grid.cell+Vector2(20,20)
	Input.warp_mouse(from); await process_frame
	down=InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.position=from; down.pressed=true; Input.parse_input_event(down); await process_frame
	Input.warp_mouse(from+Vector2(18,0))
	motion=InputEventMouseMotion.new(); motion.position=from+Vector2(18,0); motion.relative=Vector2(18,0); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(motion); await process_frame
	var key := InputEventKey.new(); key.keycode=KEY_R; key.pressed=true; Input.parse_input_event(key); await process_frame
	check(root.gui_is_dragging() and root.gui_get_drag_data().rotated,"R rotates the actual native drag payload")
	Input.warp_mouse(to); motion=InputEventMouseMotion.new(); motion.position=to; motion.relative=to-from; motion.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(motion); await process_frame
	release=InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.position=to; release.pressed=false; Input.parse_input_event(release); await process_frame
	check(inv.item_at("bag",long_item.uid).rotated and inv.item_at("bag",long_item.uid).y==5,"rotated footprint placed by real mouse gesture")
	ui=item_ui(); ui.select("bag",c.state.bag[-1].uid); await capture("inventory")
	var frozen: Vector2=c.hero_at; screen._physics_process(0.5)
	check(c.hero_at==frozen,"modal freezes game movement and combat")
	screen.show_growth(); await process_frame; ui=item_ui(); check(ui.tab=="character","C / character route")
	var card_count := 0
	for node in ui.content.get_children():
		if node is Panel and node.clip_contents:
			card_count+=1
			for child in node.get_children():
				if child is TextureRect: check(Rect2(Vector2.ZERO,node.size).encloses(Rect2(child.position,child.size)),"stat icon stays inside its graphical card")
	check(card_count==6,"character sheet has six graphical attribute cards")
	await capture("character")
	# Actual UI callbacks for skill allocation.
	var points: int=c.skill_points()
	await click(ui.position+Vector2(491,482)); check(c.skill_points()==points-1,"visible plus button learns real specialty")
	screen.show_npc(5); await process_frame; ui=item_ui(); check(ui.tab=="stash","storage NPC opens two real containers")
	uid=c.state.bag[-1].uid; ui.select("bag",uid); ui.quick_action("bag",uid)
	check(not inv.item_at("stash",uid).is_empty(),"storage quick action transfers real instance")
	ui.select("stash",uid); await capture("warehouse")
	# Invalid and valid drops through the same native interface used by mouse input.
	var vault_grid=ui.grids[1]
	var payload := {"story_item":true,"source":"bag","uid":str(c.state.bag[0].uid),"offset":Vector2i.ZERO,"rotated":false}
	check(not vault_grid._can_drop_data(Vector2(-20,-20),payload),"native grid refuses outside cells")
	check(vault_grid._can_drop_data(Vector2(425,365),payload),"native warehouse accepts exact free cell")
	vault_grid._drop_data(Vector2(425,365),payload)
	check(inv.item_at("stash",payload.uid).x==10 and inv.item_at("stash",payload.uid).y==9,"native warehouse drop preserves requested position")
	screen.show_npc(4); await process_frame; ui=item_ui(); check(ui.tab=="shop","merchant NPC route")
	await click(ui.position+Vector2(200,269)); check(ui.selected_product!="","actual mouse selects product")
	var gold: int=c.state.coins
	await click(ui.position+Vector2(740,698)); check(c.state.coins<gold,"actual buy button deducts money and creates item")
	ui=item_ui(); await capture("shop")
	uid=c.state.bag[-1].uid; ui.select("bag",uid); await click(ui.position+Vector2(740,698))
	check(not inv.item_at("buyback",uid).is_empty(),"actual sell button moves instance to buyback")
	ui=item_ui(); ui.buyback=true; ui.selected_product=uid; ui.render(); await capture("buyback")
	screen.show_npc(2); await process_frame; ui=item_ui(); check(ui.tab=="forge","blacksmith opens real forge")
	var worn: Dictionary=c.state.equipment[0].blade; uid=worn.uid; ui.select("equipped:0:blade",uid)
	gold=c.state.coins
	await click(ui.position+Vector2(700,698)); check(int(worn.upgrade)==1 and c.state.coins<gold,"actual forge button strengthens equipped item")
	ui=item_ui(); ui.select("equipped:0:blade",uid); await capture("forge")
	await click(ui.position+Vector2(925,698)); check(worn.socket,"actual socket button consumes crystal")
	ui=item_ui(); var crafted: int=c.state.bag.size()
	await click(ui.position+Vector2(166,374)); check(c.state.bag.size()==crafted+1,"actual craft recipe produces item")
	ui=item_ui(); ui.select("bag",c.state.bag[-1].uid); ui.confirm_salvage(); await process_frame
	check(ui.confirmation.visible,"irreversible dismantle opens confirmation")
	ui.confirmation.canceled.emit(); await process_frame
	check(c.state.bag.size()==crafted+1,"canceling dismantle retains item")
	# Other heroes' portraits and independent gear are visible.
	for hero in [1,2]:
		c.switch_hero(hero); screen.show_bag(); await process_frame; await capture("hero-%d" % hero)
	for page in ["npc","journal","atlas","pause"]:
		match page:
			"npc": screen.show_npc(0)
			"journal": screen.show_journal()
			"atlas": screen.show_atlas()
			"pause": screen.show_menu()
		check(screen.modal and (screen.overlay.get_child(1).get_script()==preload("res://scripts/story_quest_ui.gd") if page=="journal" else screen.overlay.get_child(1).get_theme_stylebox("panel") is StyleBoxTexture),"story page uses material skin "+page)
		await capture(page)
	c.enter(1,1); screen.show_bag(); await process_frame; ui=item_ui()
	var disabled_count := 0
	for node in ui.content.get_children():
		if node is Button and node.disabled and node.text in ["仓库","交易 / 商店","锻造"]: disabled_count+=1
	check(disabled_count==3,"camp services visibly disabled while exploring")
	# All controls remain within authored logical screen at output resolutions.
	for output in [Vector2i(1920,1080),Vector2i(3840,2160)]:
		root.size=output; screen.scale=Vector2.ONE*minf(output.x/1440.0,output.y/900.0)
		check((screen.get_global_transform_with_canvas()*Vector2(1368,830)).x<output.x,"UI fits output width %d" % output.x)
		check((screen.get_global_transform_with_canvas()*Vector2(1368,830)).y<output.y,"UI fits output height %d" % output.y)
		await capture("output-%d" % output.x)
	screen.close_panel(); screen.set_active(false); screen.free()
	for i in 8: await process_frame
	print("story item UI: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
