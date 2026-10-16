extends SceneTree
const Art=preload("res://scripts/scarlet/art.gd")
var checks:=0
var failures:=0
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(why)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var screen=preload("res://scripts/scarlet/screen.gd").new(); root.add_child(screen)
	var c=screen.campaign; c.state=c.new_state(); c.save_enabled=false; screen.world.build(); screen.set_active(true)
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/cg-scarlet-v2/manifest.json"))
	check(manifest.illustrations.size()==7,"seven new static CGs delivered")
	for item in manifest.illustrations:
		var picture:=Art.cg(item.id)
		check(picture!=null and picture.get_size()==Vector2(3840,2160),"runtime loads 4K CG "+str(item.id))
		check(not item.native_4k and int(item.source_size[0])==1672 and int(item.source_size[1])==941,"actual source resolution is disclosed "+str(item.id))
		for sid in item.scenes:
			var event: Dictionary=c.content.scenes[sid].duplicate(true); event.kind="scene"; event.page=0
			check(event.pages.any(func(page): return page.get("cg","")==item.id),"authored scene binds delivered CG "+str(sid))
			screen.play_replay(event)
			check(screen.dialogue.cg_view.texture!=null,"ADV displays the actual image "+str(sid))
			check(screen.dialogue.cg_fit_above_dialogue,"entire illustration stays above text "+str(sid))
			check(screen.dialogue.cg_view.position.y+screen.dialogue.cg_view.size.y<=screen.dialogue.text_panel.position.y,"dialogue cannot cover wrist, tickets or hand clasp")
			screen.dialogue.toggle_box(); check(not screen.dialogue.cg_fit_above_dialogue and not screen.dialogue.speaker_portrait.visible,"H shows clean full illustration")
			screen.dialogue.toggle_box(); check(screen.dialogue.cg_fit_above_dialogue and screen.dialogue.cg_view.scale==Vector2.ONE,"restoring dialogue restores complete CG framing")
			screen.dismiss_adv()
	check(c.content.scenes["00-01"].pages[0].cg=="cg-n01" and c.content.scenes["00-01"].pages[3].cg=="","street image ends before palace dialogue")
	check(c.content.scenes["06-02"].pages.all(func(page): return page.get("cg","")!="cg-n04"),"unconfirmed census does not reveal occupied-room discovery CG")
	check(c.content.cinematics.size()==24,"24 planned movie versions retained")
	for movie in c.content.cinematics.values(): check(movie.path==null,"movie remains empty: "+str(movie.id))
	check(Art.cg("cg-15")!=null,"existing CGs remain available")
	screen.queue_free(); await process_frame
	print("SCARLET_CG_DELIVERY %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
