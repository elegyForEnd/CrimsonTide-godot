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
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var sound: TideSound=app.sound
	for kind in sound.clips:
		for clip in sound.clips[kind]:
			check(clip is AudioStreamWAV and clip.get_length()>.05,"Imported sample exists: "+kind)
	check(sound.ambience.stream is AudioStreamOggVorbis and sound.ambience.stream.loop,"Offline ambience loops")
	check(AudioServer.get_bus_effect_count(0)>0 and AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter,"Crowded combat has master peak protection")
	for combo in 3:
		sound.last_played.clear()
		sound.play("slash",combo)
		check(sound.previous.slash==combo,"Three combo strikes select distinct samples")
	var count := playing(sound)
	for i in 50:
		sound.play("hit")
	check(playing(sound)<=count+1,"Same-frame crowd impacts do not stack 50 voices")
	for i in 80:
		sound.last_played.clear()
		sound.play("heavy",i%3)
	check(playing(sound)==24 and sound.voices.size()==24,"Polyphony is bounded; occupied voices are reused")
	app.session.solo(app.config())
	app.session.launch(false,1729)
	app.session.action("skill")
	check(paused and app.ultimate.active,"Accepted skill starts cinematic")
	check(sound.cinema_charge.playing and not sound.cinema_charge.stream_paused,"Charge continues while battle is paused")
	await create_timer(.20).timeout
	check(sound.ambience.volume_db< -30,"Cinematic ducks ambience even when paused")
	await create_timer(1.75).timeout
	check(sound.cinema_burst.playing and not sound.cinema_burst.stream_paused,"Burst plays at cinematic impact while paused")
	app.ultimate.stop()
	check(not sound.cinema_charge.playing and not sound.cinema_burst.playing,"Skip stops both cinematic voices")
	check(not paused,"Skip resumes battle")
	await create_timer(.20).timeout
	check(is_equal_approx(sound.ambience.volume_db,-24.0),"Skip restores ambience")
	for hero in 3:
		app.ultimate.play(hero,true)
		check(not paused and sound.cinema_charge.stream==sound.short_charges[hero],"Online selects separate short charge without speeding pitch")
		check(sound.cinema_charge.pitch_scale==1.0,"Online maintains original sound pitch")
		await create_timer(.66).timeout
		check(sound.cinema_burst.stream==sound.short_bursts[hero] and sound.cinema_burst.playing,"Each hero has online burst")
		app.ultimate.stop()
	app.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("AUDIO TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func playing(sound: TideSound) -> int:
	var count := 0
	for voice in sound.voices:
		if voice.playing:
			count+=1
	return count
