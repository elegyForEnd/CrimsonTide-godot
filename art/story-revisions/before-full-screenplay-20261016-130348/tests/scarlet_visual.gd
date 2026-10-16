extends SceneTree
var screen
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	screen=preload("res://scripts/story_screen.gd").new(); root.add_child(screen)
	screen.campaign.state=screen.campaign.new_state(); screen.campaign.save_enabled=false; screen.set_active(true)
	var samples: Array=[]
	for z in screen.campaign.content.zones:
		screen.campaign.state.pending={}
		if not z in screen.campaign.state.unlocked: screen.campaign.state.unlocked.append(z)
		screen.campaign.enter_zone(z)
		for i in 3: await process_frame
		if z in ["1:0","2:4","3:3","4:6","5:6","6:6","6:7"]:
			RenderingServer.force_draw(false)
			var target: String="res://output/scarlet-zone-"+z.replace(":","-")+".png"
			root.get_texture().get_image().save_png(target); samples.append(target)
	screen.campaign.state.pending={}; screen.show_map()
	for i in 3: await process_frame
	RenderingServer.force_draw(false); root.get_texture().get_image().save_png("res://output/scarlet-local-map.png")
	print("SCARLET_VISUAL zones=",screen.campaign.content.zones.size()," captures=",samples.size()+1)
	screen.queue_free(); await process_frame; quit()
