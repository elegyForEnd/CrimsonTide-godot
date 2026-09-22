extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(description)

func run() -> void:
	var sound := TideSound.new()
	root.add_child(sound)
	var music: TideMusic=sound.music
	for player: AudioStreamPlayer in music.players.values():
		check(player.stream is AudioStreamOggVorbis and player.stream.loop and player.stream.get_length()>60,"Full-length offline music loop imports")
	check(music.active_cue=="camp" and music.players.camp.playing,"Title starts sanctuary theme")
	await create_timer(2.0).timeout
	var position: float=music.players.camp.get_playback_position()
	sound.set_scene("camp")
	check(music.players.camp.get_playback_position()>=position,"Camp does not restart the title theme")
	sound.set_scene("game")
	await create_timer(.3).timeout
	check(music.players.camp.playing and music.players.ruins.playing,"Scene transition crossfades both themes")
	sound.set_scene("title")
	await create_timer(2.0).timeout
	check(music.players.camp.playing and not music.players.ruins.playing,"Reversed transition stops outgoing music")
	sound.set_scene("game")
	await create_timer(2.0).timeout
	sound.cinema_active=true
	paused=true
	await create_timer(.5).timeout
	check(music.duck_db<=-11.5 and music.players.ruins.playing,"Paused cinematic keeps music playing and ducks it")
	sound.cinema_active=false
	paused=false
	await create_timer(1.7).timeout
	check(is_zero_approx(music.duck_db),"Music level recovers after cinematic")
	music.set_process(false)
	music.speaking=true
	music._process(.2)
	check(music.duck_db<=-6.0,"Dialogue ducks music")
	var bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(bus,true)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Dialogue")),"Music mute leaves dialogue enabled")
	AudioServer.set_bus_mute(bus,false)
	sound.queue_free()
	await process_frame
	await create_timer(.2).timeout
	print("MUSIC TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
