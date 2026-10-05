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
	check(music.active_cue=="title" and music.players.title.playing,"Title starts its dedicated theme")
	sound.set_scene("camp")
	await create_timer(2.0).timeout
	await create_timer(2.0).timeout
	var position: float=music.players.camp.get_playback_position()
	sound.set_scene("camp")
	check(music.players.camp.get_playback_position()>=position,"Camp does not restart the title theme")
	sound.set_scene("game")
	await create_timer(.3).timeout
	check(music.players.camp.playing and music.players.ruins.playing,"Scene transition crossfades both themes")
	sound.set_scene("camp")
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
	music.set_scene("home")
	check(music.active_cue=="home","Walkable homestead uses home theme")
	music.set_result(true)
	check(music.active_cue=="victory","Successful extraction uses victory theme")
	music.set_result(false)
	check(music.active_cue=="defeat","Failed run uses defeat theme")
	music.set_scene("game")
	for floor_number in range(1,6):
		var raid := {"mode":"roguelike","floor":floor_number,"room":"combat"}
		music.set_world("rogue",raid,[],Vector2.ZERO)
		var floor_cue := "floor_%d" % floor_number
		check(music.active_cue==floor_cue,"Floor %d exploration selects its dedicated music" % floor_number)
		music.set_world("rogue",raid,[{"rogue_guardian":true,"hp":100}],Vector2.ZERO)
		var guardian_cue := "guardian_%d" % floor_number
		check(music.active_cue==guardian_cue,"Floor %d guardian switches to dedicated music" % floor_number)
		music.set_world("rogue",raid,[],Vector2.ZERO)
		check(music.encounter_cue.is_empty(),"Defeated guardian releases encounter override")
	for room in ["shop","talent","treasure"]:
		music.set_world("rogue",{"mode":"roguelike","floor":3,"room":room},[],Vector2.ZERO)
		check(music.active_cue==("sanctuary" if room=="talent" else room),"Safe room music overrides exploration")
	for kind in 3:
		music.set_world("border",{},[{"raid_boss":true,"boss_kind":kind,"hp":100}],Vector2.ZERO)
		check(music.active_cue==["bishop","hunter","queen"][kind],"Campaign boss has dedicated theme")
	for flag in ["hidden_final","final_form","abyss_final"]:
		var enemy := {"raid_boss":true,"boss_kind":2,"hp":100}
		enemy[flag]=true
		music.set_world("border",{},[enemy],Vector2.ZERO)
		check(music.active_cue=={"hidden_final":"hidden","final_form":"final","abyss_final":"abyss"}[flag],"Final encounter override %s" % flag)
	music.set_world("city",{},[{"type":4,"p":Vector2.ZERO,"hp":100}],Vector2.ZERO)
	check(music.active_cue=="knight","Nearby city knight overrides city exploration")
	music.set_world("city",{},[{"type":4,"p":Vector2(900,0),"hp":100}],Vector2.ZERO)
	check(music.active_cue=="city","Distant knight restores city exploration")
	music.set_scene("title")
	check(music.encounter_cue.is_empty() and music.active_cue=="title","Leaving game clears encounter context")
	sound.queue_free()
	await process_frame
	await create_timer(.2).timeout
	print("MUSIC TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
