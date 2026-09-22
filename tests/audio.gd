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
		sound.attack(1,combo,Vector2.ZERO,1)
		check(sound.previous.slash in [combo*2,combo*2+1],"Three combo strikes select separate pairs of variations")
	var count := playing(sound)
	for i in 50:
		sound.play("hit")
	check(playing(sound)<=count+1,"Same-frame crowd impacts do not stack 50 voices")
	for i in 80:
		sound.last_played.clear()
		sound.play("heavy",i%3)
	check(playing_kind(sound,"heavy")==4 and sound.voices.size()==24,"Heavy effects are limited to four simultaneous layers")
	for kind in ["step","run","magic","hit","shot"]:
		for i in 10:
			sound.last_played.clear()
			sound.play(kind)
	sound.play("hurt")
	check(playing(sound)<=24 and playing_kind(sound,"hurt")==1,"Player damage stays audible when low priority voices fill the pool")
	sound.set_scene("game")
	var moving := {"id":99,"p":Vector2.ZERO,"status":"active","motion":"walk","swing_time":0.0,"cast_time":0.0,"dodge_time":0.0}
	sound.update_world(Vector2.ZERO,{99:moving},.3)
	var sequence: int=sound.sequence
	for i in 5:
		sound.update_world(Vector2.ZERO,{99:moving},.3)
	check(sound.sequence==sequence,"Holding movement against a wall produces no footsteps")
	moving.p=Vector2(55,0)
	sound.update_world(Vector2.ZERO,{99:moving},.3)
	check(playing_kind(sound,"step")==1,"Actual walking displacement produces stone footsteps")
	moving.motion="run"
	moving.p+=Vector2(65,0)
	sound.update_world(Vector2.ZERO,{99:moving},.2)
	check(playing_kind(sound,"run")==1,"Running selects a distinct heavier footstep bank")
	moving.p+=Vector2(500,0)
	sequence=sound.sequence
	sound.update_world(Vector2.ZERO,{99:moving},.4)
	check(sound.sequence==sequence,"Teleport corrections do not produce footsteps")
	sound.set_scene("game")
	moving.p=Vector2.ZERO
	moving.motion="walk"
	sound.update_world(Vector2.ZERO,{99:moving},0.0)
	sequence=sound.sequence
	for frame in 60:
		if frame%6==0:
			moving.p+=Vector2(12,0)
		sound.last_played.clear()
		sound.update_world(Vector2.ZERO,{99:moving},1.0/60.0)
	check(sound.sequence>=sequence+2,"Spaced network snapshots retain footstep cadence between stationary render frames")
	sequence=sound.sequence
	for frame in 30:
		sound.last_played.clear()
		sound.update_world(Vector2.ZERO,{99:moving},1.0/60.0)
	check(sound.sequence==sequence,"Stale walking snapshots produce no footsteps without fresh displacement")
	check(sound.motion_state[99].distance==0.0,"Prolonged movement gaps clear accumulated stride distance")
	sound.set_scene("game")
	moving.p=Vector2.ZERO
	moving.motion="run"
	sound.update_world(Vector2.ZERO,{99:moving},0.0)
	sequence=sound.sequence
	for frame in 120:
		if frame%2==0:
			moving.p+=Vector2(3,0)
		sound.last_played.clear()
		sound.update_world(Vector2.ZERO,{99:moving},1.0/120.0)
	check(sound.sequence>=sequence+4,"120 Hz rendering with 60 Hz physics keeps running footsteps audible")
	sound.play("reload",0,Vector2.ZERO,0.0,99)
	sound.stop_cue("reload",99)
	check(playing_kind(sound,"reload")==0,"Interrupted reload audio stops for its emitter")
	sequence=sound.sequence
	sound.play("shot",0,Vector2(1200,0),0.0,99)
	check(sound.sequence==sequence,"Offscreen distant sounds are culled")
	sound.set_scene("game")
	app.session.solo(app.config())
	app.session.launch(false,1729)
	var player: Dictionary=app.session.players[app.session.my_id()]
	player.weapon=0
	player.ammo=0
	app.session.action("reload")
	check(playing_kind(sound,"reload")==1,"Accepted reload emits the recorded magazine sound")
	app.session.action("weapon",{"index":1})
	check(playing_kind(sound,"reload")==0 and player.reload==0.0,"Switching weapon cancels its active reload sound through game events")
	app.session.action("skill")
	check(paused and app.ultimate.active,"Accepted skill starts cinematic")
	check(sound.cinema_charge.playing and not sound.cinema_charge.stream_paused,"Charge continues while battle is paused")
	check(playing(sound)==0,"Solo CG clears battle tails rather than replaying them after the pause")
	await create_timer(.20).timeout
	check(sound.ambience.volume_db< -30,"Cinematic ducks ambience even when paused")
	await create_timer(app.ultimate.impact_time-.20+.08).timeout
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

func playing_kind(sound: TideSound, kind: String) -> int:
	var count := 0
	for voice in sound.voices:
		if voice.playing and voice.get_meta("cue","")==kind:
			count+=1
	return count
