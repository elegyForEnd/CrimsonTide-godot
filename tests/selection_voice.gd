extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func select_hero(app: Node, hero: int) -> void:
	for child in app.page.get_children():
		if child is Button and child.text==Catalog.HEROES[hero].name:
			child.pressed.emit()
			return
	check(false,"Character button exists")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-selection-voice-profile.json"
	app.profile.data.hero=0
	app.set_voice_volume(1.0)
	app.session.solo(app.config())
	var voice: HeroVoice=app.sound.dialogue
	check(not voice.narrator.playing,"Camp refresh does not auto-play a selection")
	for hero in 3:
		select_hero(app,hero)
		check(voice.narrator.playing and voice.narrator.stream==voice.banks[hero]["select"][0],"Portrait click plays its cast line: %d" % hero)
		check(app.profile.data.hero==hero and app.session.players[1].hero==hero,"Selection still updates the lobby")
	check(voice.narrator.bus=="Dialogue","Selection follows the character voice volume")
	await create_timer(.2).timeout
	var position := voice.narrator.get_playback_position()
	select_hero(app,2)
	check(voice.narrator.get_playback_position()>=position-.03,"Repeated clicks do not restart a playing line")
	app.ready_local=true
	select_hero(app,2)
	check(app.ready_local,"Replaying the current hero does not clear readiness")
	app.session.configure(app.config())
	check(voice.narrator.playing and voice.narrator.get_playback_position()>=position-.03,"Lobby refresh preserves the selection voice")
	select_hero(app,0)
	check(not app.ready_local and voice.narrator_hero==0,"Rapid switch follows the latest hero and resets readiness")
	for speaker in voice.speakers:
		check(not speaker.playing,"Selection does not create overlapping spatial voices")
	await create_timer(voice.narrator.stream.get_length()+.1).timeout
	select_hero(app,0)
	check(voice.narrator.playing,"Clicking again after completion replays the line")
	app.show_title()
	check(not voice.narrator.playing,"Leaving camp stops selection playback")
	app.show_camp()
	app.set_voice_volume(0.0)
	select_hero(app,1)
	check(not voice.narrator.playing,"Muted selection does not queue a delayed line")
	app.set_voice_volume(1.0)
	select_hero(app,1)
	check(voice.narrator.playing,"Unmuted portrait can play normally")
	app.session.launch(false,1729)
	check(not voice.narrator.playing,"Entering combat stops selection playback")
	app.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("SELECTION VOICE TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
