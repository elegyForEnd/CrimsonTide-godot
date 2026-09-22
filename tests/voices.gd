extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(title)

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var sound: TideSound=app.sound
	var voice: HeroVoice=sound.dialogue
	app.set_voice_volume(1.0)
	for hero in 3:
		for kind in voice.banks[hero]:
			for stream in voice.banks[hero][kind]:
				check(stream is AudioStreamWAV and stream.get_length()>.1,"Japanese voice imports: %d %s" % [hero,kind])
	check(voice.play_line(0,"attack",1,Vector2.ZERO,Vector2.ZERO),"Initial attack voice plays")
	check(not voice.play_line(0,"attack",1,Vector2.ZERO,Vector2.ZERO),"Rapid attack does not overlap or restart dialogue")
	check(voice.play_line(0,"hurt",1,Vector2.ZERO,Vector2.ZERO),"Damage interrupts lower priority attack voice")
	check(not voice.play_line(0,"attack",1,Vector2.ZERO,Vector2.ZERO),"Attack cannot interrupt damage reaction")
	check(not voice.play_line(2,"heavy",99,Vector2(900,0),Vector2.ZERO),"Distant voices are culled")
	await create_timer(.2).timeout
	check(sound.dialogue_duck< -4.0,"Dialogue ducks combat and cinematic effects")
	app.set_voice_volume(0.0)
	await create_timer(.5).timeout
	check(is_zero_approx(sound.dialogue_duck),"Muted dialogue does not duck the effects")
	app.set_voice_volume(1.0)
	voice.stop_all()
	voice.play_line(0,"attack",1,Vector2.ZERO,Vector2.ZERO)
	var first: int=voice.previous["1:attack"]
	for speaker in voice.speakers:
		speaker.stop()
	voice.next_allowed.clear()
	voice.play_line(0,"attack",1,Vector2.ZERO,Vector2.ZERO)
	check(voice.previous["1:attack"]!=first,"Consecutive attack variations avoid repetition")
	app.session.solo(app.config())
	app.session.launch(false,1729)
	var player: Dictionary=app.session.players[app.session.my_id()]
	for hero in 3:
		player.hero=hero
		for weapon in Catalog.WEAPONS.size():
			voice.stop_all()
			player.weapon=weapon
			app.on_combat_audio({"kind":"strike","weapon":weapon,"combo":0,"id":player.id,"p":player.p})
			var routed := false
			for speaker in voice.speakers:
				if speaker.playing and speaker.get_meta("hero",-1)==hero and speaker.get_meta("cue","")=="attack":
					routed=true
			check(routed,"Every hero/weapon normal strike uses a grunt: %d/%d" % [hero,weapon])
	for hero in 3:
		app.ultimate.play(hero,false)
		check(paused and voice.narrator.playing and not voice.narrator.stream_paused,"Full CG dialogue continues during pause")
		check(voice.narrator.stream==voice.banks[hero]["ultimate-charge"][0],"CG starts the correct hero invocation")
		await create_timer(app.ultimate.impact_time+.06).timeout
		check(voice.narrator.stream==voice.banks[hero]["ultimate-burst"][0] and voice.narrator.playing,"Burst switches to the licensed battle call")
		await create_timer(float(voice.metadata.heroes[hero].burst_time)+.08).timeout
		check(not paused and not app.ultimate.active and not voice.narrator.playing,"Full voice completes before the CG resumes play")
	app.ultimate.play(1,true)
	check(not paused,"Online narration does not pause the world")
	await create_timer(.87).timeout
	check(not app.ultimate.active and voice.narrator.playing,"Natural online cut-in end lets its short callout finish")
	app.ultimate.play(0,true)
	app.ultimate.stop()
	check(not voice.narrator.playing,"Explicit skip stops remaining voice")
	app.ultimate.play(2,true)
	await create_timer(.87).timeout
	app.show_title()
	check(not voice.narrator.playing and not voice.is_speaking(),"Leaving combat stops an online voice tail")
	app.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("CHARACTER VOICE TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
