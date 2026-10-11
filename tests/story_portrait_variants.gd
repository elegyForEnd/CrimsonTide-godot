extends SceneTree
const Screen = preload("res://scripts/story_screen.gd")
const Art = preload("res://scripts/story_portrait_art.gd")
var checks := 0
var failures := 0
var screen
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func click(at: Vector2) -> void:
	Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new();motion.position=at;Input.parse_input_event(motion);await process_frame
	var down := InputEventMouseButton.new();down.position=at;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down);await process_frame
	var up := InputEventMouseButton.new();up.position=at;up.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(up);await process_frame
func capture(name: String) -> void:
	if not "--capture-portraits" in OS.get_cmdline_user_args(): return
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/portrait-ui-"+name+".png")==OK,"actual portrait UI capture "+name)
func run() -> void:
	root.size=Vector2i(1440,900); DisplayServer.window_set_size(root.size)
	screen=Screen.new();root.add_child(screen);screen.campaign.save_enabled=false;screen.start("user://portrait-fixture.json");screen.set_physics_process(false)
	var c=screen.campaign;c.state=c.new_state();c.enter(1,0);c.save_enabled=false
	for hero in 3:
		check(Art.description(hero).get("ready",false),"all authored assets ready for "+Art.HERO_KEYS[hero])
		for costume in Art.COSTUMES:
			for expression in Art.EXPRESSIONS:
				var data := Art.layers(hero,expression,costume)
				check(data.body!=null and data.body.get_size()==Vector2(2160,3840),"native 4K body "+str(hero)+costume+expression)
				check(expression=="neutral" or data.face!=null and data.face.get_size()==data.face_rect.size,"registered expression layer "+str(hero)+costume+expression)
	check(Art.textures.size()<=Art.CACHE_LIMIT,"resource cache bounded after inspecting 120 combinations")
	for hero in 3:
		var pages: Array=[]
		for i in 10: pages.append({"speaker":["绯月","雪璃","鸦羽"][hero],"text":"灯还亮着，我们一起回去。","actor":"hero:%d" % hero,"left":"hero:%d" % hero,"right":"","expression":Art.EXPRESSIONS[i]})
		screen.show_dialogue("灯下的回声",pages)
		var ui=screen.dialogue;ui.set_process(false);ui.reveal_all()
		var at: Vector2=ui.left.position;var bounds: Vector2=ui.left.size
		var before := JSON.stringify(c.state)
		ui.index=4;ui.show_page();ui.reveal_all();await process_frame
		check(ui.left.expression=="worried" and ui.left.face.texture!=null,"real dialogue selects worried facial art")
		check(ui.left.position.distance_to(at)<8 and ui.left.size==bounds,"expression preserves portrait bounds")
		await capture(Art.HERO_KEYS[hero]+"-worried")
		ui.toggle_wardrobe();var page: int=ui.index;ui._process(100);ui.advance()
		check(ui.index==page,"wardrobe pauses auto and text advance")
		await click(ui.wardrobe.global_position+Vector2(155+182+86,122+82*hero+23))
		check(ui.left.costume=="travel" and screen.dialogue_outfits.get("hero:%d" % hero)=="travel","native wardrobe button selects the intended hero and clothing")
		ui.choose_costume("hero:%d" % hero,"ceremony");ui.toggle_wardrobe();await process_frame
		check(ui.left.costume=="ceremony" and ui.left.expression=="worried","clothing changes independently of facial emotion")
		check(JSON.stringify(c.state)==before,"wardrobe cannot equip gear, charge coins or modify campaign state")
		await capture(Art.HERO_KEYS[hero]+"-ceremony")
		ui.toggle_wardrobe();ui.toggle_log();check(ui.wardrobe==null and ui.log_view!=null,"backlog replaces wardrobe without stacking modals")
		ui.toggle_log();ui.index=2;ui.show_page();ui.reveal_all()
		check(ui.left.costume=="ceremony" and ui.left.expression=="joy","next line keeps outfit while changing expression")
		check(Art.textures.size()<=Art.CACHE_LIMIT,"live switch cache stays bounded")
	screen.save_dialogue_outfits();check(not FileAccess.file_exists(c.path+".dialogue-outfits.json"),"transient preview never saves clothes")
	c.save_enabled=true;screen.save_dialogue_outfits();c.save_enabled=false;var prefs: Dictionary=screen.dialogue_outfits.duplicate();screen.load_dialogue_read()
	check(screen.dialogue_outfits==prefs,"wardrobe choice persists outside campaign save schema")
	DirAccess.remove_absolute(c.path+".dialogue-outfits.json")
	screen.set_active(false);check(screen.dialogue==null and Art.textures.is_empty(),"leaving story releases portrait cache")
	screen.free();for i in 5:await process_frame
	print("story portrait variants: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
