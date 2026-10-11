extends SceneTree
## Uses the actual campaign screen; preview progress and read flags never persist.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,900); root.content_scale_size=root.size
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.profile.path="user://galgame-preview-profile.json"
	app.go_story("user://galgame-preview-campaign.json")
	var screen=app.story_screen
	screen.campaign.save_enabled=false; screen.campaign.state=screen.campaign.new_state(); screen.campaign.enter(1,0)
	screen.campaign.hero_at=screen.campaign.map.npc_at[0]+Vector2(0,90); screen.world.focus=screen.campaign.hero_at
	screen.show_npc(0)
