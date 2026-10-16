extends SceneTree
var screen
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	screen=preload("res://scripts/scarlet/screen.gd").new(); root.add_child(screen)
	screen.campaign.save_enabled=false; screen.campaign.state=screen.campaign.new_state()
	screen.set_active(true); screen.world.build()
	var scene_id:="00-08"; var zone_id:="1:0"; var target:="output/scarlet-adv.png"
	var battle:=""
	var phase:=0
	var page:=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): scene_id=arg.trim_prefix("--scene=")
		if arg.begins_with("--zone="): zone_id=arg.trim_prefix("--zone=")
		if arg.begins_with("--shot="): target=arg.trim_prefix("--shot=")
		if arg.begins_with("--battle="): battle=arg.trim_prefix("--battle=")
		if arg.begins_with("--phase="): phase=int(arg.trim_prefix("--phase="))
		if arg.begins_with("--page="): page=int(arg.trim_prefix("--page="))
	screen.campaign.state.unlocked.append(zone_id); screen.campaign.enter_zone(zone_id)
	if battle!="":
		var qid: String="R-%d-06" % int(screen.campaign.state.act)
		for id in screen.campaign.content.main_order:
			if id==qid: break
			screen.campaign.state.completed.append(id)
		var q: Dictionary=screen.campaign.content.quests[qid]
		var boss_index:=0
		for i in q.nodes.size():
			if q.nodes[i].kind=="boss": boss_index=i; break
		screen.campaign.state.steps[qid]=boss_index; screen.campaign.state.pending={}
		screen.campaign.combat.start(qid,q.nodes[boss_index].id,battle,1)
		if phase>0: screen.campaign.combat.resume_phase(phase)
	elif scene_id!="none": screen.campaign.request_scene(scene_id,{})
	for i in 60: await process_frame
	if screen.dialogue and scene_id!="none":
		screen.dialogue.index=clampi(page,0,screen.dialogue.event.pages.size()-1); screen.dialogue.show_page()
		await process_frame
	if battle!="":
		for i in 200: await physics_frame
	if screen.dialogue and scene_id!="none": screen.dialogue.body.visible_characters=-1; screen.dialogue.revealed=screen.dialogue.body.get_total_character_count()
	for i in 2: await process_frame
	RenderingServer.force_draw(false)
	var error:=root.get_texture().get_image().save_png(target)
	print("SCARLET_PREVIEW shot=",target," error=",error)
	screen.queue_free(); await process_frame; quit()
