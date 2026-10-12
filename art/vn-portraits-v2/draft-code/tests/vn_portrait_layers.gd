extends SceneTree
const Art = preload("res://scripts/story_portrait_art.gd")
const View = preload("res://scripts/story_portrait_view.gd")
const Screen = preload("res://scripts/story_screen.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	for hero in 3:
		check(Art.description(hero).get("bases",{}).size()==3,"three costumes for each hero")
		for clothing in Art.COSTUMES:
			for pose in Art.POSES:
				var base: Texture2D=Art.layers(hero,"neutral",clothing,pose).body
				for expression in Art.EXPRESSIONS:
					var data := Art.layers(hero,expression,clothing,pose)
					check(data.body==base and base.get_size()==Vector2(2160,3840),"same blank base across expressions "+str(hero)+clothing+pose+expression)
					check(data.overlays.size()==3 and data.overlays[0].kind=="blush" and data.overlays[1].kind=="eyes" and data.overlays[2].kind=="mouth","isolated native features "+expression)
		check(Art.textures.size()<=Art.CACHE_LIMIT,"bounded cache")
	var view := View.new();view.size=Vector2(500,800);root.add_child(view)
	view.set_actor("hero:0",null,"neutral","regular","relaxed")
	check(view.blush.visible and view.face.visible and view.mouth.visible,"default faint blush remains on neutral face")
	var base_id := view.texture.get_instance_id();var at := view.body.position
	view.set_actor("hero:0",null,"shy","regular","relaxed")
	check(view.texture.get_instance_id()==base_id and view.body.position==at,"no whole-head substitution or base redraw")
	view.blank=true;view.set_actor("hero:0",null)
	check(not view.face.visible and not view.mouth.visible and not view.blush.visible,"blank substrate inspection")
	view.blank=false;view.blush_enabled=false;view.set_actor("hero:0",null)
	check(not view.blush.visible and view.face.visible and view.mouth.visible,"blush independent switch")
	view.queue_free();await process_frame
	var screen=Screen.new();root.add_child(screen);screen.campaign.save_enabled=false;screen.start("user://vn-layer-fixture.json");screen.set_physics_process(false)
	var c=screen.campaign;c.state=c.new_state();c.enter(1,0);c.save_enabled=false
	var before := JSON.stringify(c.state)
	for hero in 3:
		var actor := "hero:%d" % hero
		screen.show_dialogue("分层立绘验证",[{"speaker":["绯月","雪璃","鸦羽"][hero],"text":"灯还亮着。我们一起回去。","actor":actor,"left":actor,"right":"","expression":"shy","pose":"clasped"}])
		var ui=screen.dialogue;ui.set_process(false);ui.reveal_all()
		check(ui.left.pose=="clasped" and ui.left.expression=="shy","authored dialogue gesture and emotion")
		ui.choose_costume(actor,"travel");ui.choose_pose(actor,"crossed")
		check(ui.left.pose=="crossed" and ui.left.costume=="travel" and ui.left.expression=="shy","pose and clothing independent from expression")
		ui.toggle_wardrobe();ui._process(100);ui.advance();check(ui.index==0,"selector pauses reading")
		ui.toggle_wardrobe();await process_frame
		if "--capture-vn-dialogue" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://build/vn-dialogue-"+Art.HERO_KEYS[hero]+".png")==OK,"actual layered dialogue capture")
	check(JSON.stringify(c.state)==before,"art changes cannot alter campaign/economy")
	check(not FileAccess.file_exists(c.path+".dialogue-outfits.json"),"preview never writes clothing preferences")
	screen.set_active(false);check(Art.textures.is_empty(),"story exit releases layer cache")
	screen.free();for i in 5:await process_frame
	print("VN portrait layers: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
