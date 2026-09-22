extends SceneTree
## Capture the actual Godot mixer, including spatial panning and the buses.
var failures := 0
func _initialize() -> void:
	call_deferred("run")

func rms(data: PackedByteArray, channel: int) -> float:
	var power := 0.0
	var count := data.size()/4
	for frame in count:
		var value := data.decode_s16(frame*4+channel*2)/32768.0
		power+=value*value
	return sqrt(power/maxi(count,1))

func capture(sound: TideSound, at: Vector2) -> PackedByteArray:
	var record := AudioEffectRecord.new()
	record.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,record)
	record.set_recording_active(true)
	sound.last_played.clear()
	sound.play("step",0,at,14.0)
	await create_timer(.42).timeout
	record.set_recording_active(false)
	var stream := record.get_recording()
	var data := stream.data
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	return data

func run() -> void:
	var sound := TideSound.new()
	root.add_child(sound)
	sound.ambience.stop()
	AudioServer.set_bus_volume_db(0,0)
	var left: PackedByteArray=await capture(sound,Vector2(-400,0))
	var right: PackedByteArray=await capture(sound,Vector2(400,0))
	var center: PackedByteArray=await capture(sound,Vector2.ZERO)
	var l := Vector2(rms(left,0),rms(left,1))
	var r := Vector2(rms(right,0),rms(right,1))
	var c := Vector2(rms(center,0),rms(center,1))
	print("Actual mixer RMS: left=",l," right=",r," center=",c)
	if l.x<=l.y or r.y<=r.x or c.length()<=l.length() or c.length()<.001:
		failures+=1
		push_error("Spatial mixer must be audible, pan toward the source and attenuate distance")
	var record := AudioEffectRecord.new()
	record.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,record)
	record.set_recording_active(true)
	# Fixed choices make review renders reproducible; regular gameplay randomizes variants.
	for combo in 3:
		sound.dialogue.play_line(0,"attack",1,Vector2.ZERO,Vector2.ZERO)
		sound.play("slash",combo*2,Vector2.ZERO)
		await create_timer(.10).timeout
		sound.play("hit",combo,Vector2.ZERO)
		await create_timer(.36).timeout
	await create_timer(.4).timeout
	sound.play("heavy",0,Vector2.ZERO)
	sound.dialogue.play_line(2,"attack",1,Vector2.ZERO,Vector2.ZERO)
	await create_timer(.12).timeout
	sound.play("impact-heavy",0,Vector2.ZERO)
	await create_timer(1.0).timeout
	for i in 3:
		sound.play("shot",i,Vector2.ZERO)
		await create_timer(.25).timeout
	await create_timer(.5).timeout
	sound.play("magic-windup",0)
	await create_timer(.22).timeout
	sound.play("magic",0,Vector2.ZERO)
	sound.dialogue.play_line(1,"attack",1,Vector2.ZERO,Vector2.ZERO)
	await create_timer(.30).timeout
	sound.play("impact-magic",0,Vector2(150,0))
	await create_timer(1.2).timeout
	for kind in ["step","run","dash","land","hurt","equip","reload","reload-end","loot","heal","bell"]:
		sound.play(kind,0)
		await create_timer(1.5 if kind in ["reload","heal","bell"] else .55).timeout
	for hero in 3:
		sound.begin_cinematic(hero,false)
		paused=true
		await create_timer(float(sound.dialogue.metadata.heroes[hero].charge_time)).timeout
		sound.burst_cinematic(hero)
		await create_timer(float(sound.dialogue.metadata.heroes[hero].burst_time)).timeout
		paused=false
		sound.end_cinematic()
		await create_timer(.30).timeout
	record.set_recording_active(false)
	var stream := record.get_recording()
	stream.save_to_wav("res://build/minimax-game-mix.wav")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	sound.queue_free()
	await create_timer(.15).timeout
	print("MIXER TESTS: ",failures," failures; actual game mix saved")
	quit(1 if failures else 0)
