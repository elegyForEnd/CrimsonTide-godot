class_name HeroVoice
extends Node

## Licensed prerecorded Japanese performances; see VOICE-CREDITS.txt.
const PRIORITIES := {"attack":1,"dash":1,"heavy":2,"magic":2,"heal":3,"hurt":3,"down":4,"ultimate-short":5}
var metadata: Dictionary
var banks: Array[Dictionary] = []
# Per hero: does this manifest entry have real recordings behind it? A hero with
# placeholder files is deliberately mute rather than quietly silent.
var ready_flags: Array[bool] = []
var speakers: Array[AudioStreamPlayer2D] = []
var narrator: AudioStreamPlayer
var previous: Dictionary = {}
var next_allowed: Dictionary = {}
var narrator_online := false
var narrator_hero := 0
var local_id := 1

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	metadata=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voices/voice-manifest.json"))
	for hero in metadata.heroes:
		var bank: Dictionary = {}
		for kind in hero.lines:
			var clips: Array[AudioStream] = []
			for line in hero.lines[kind]:
				# A manifest may list a line whose recording was never shipped;
				# the empty slot is skipped rather than crashing the whole bank.
				var path := "res://assets/audio/voices/"+str(line.file)
				var clip: AudioStream=load(path) if ResourceLoader.exists(path) else null
				if clip and not line.get("placeholder",false):
					clips.append(clip)
			if not clips.is_empty():
				bank[kind]=clips
		banks.append(bank)
		# Absent means "recorded": the three shipped heroes predate the flag.
		ready_flags.append(bool(hero.get("voice_ready",true)))
	for i in 4:
		var speaker := AudioStreamPlayer2D.new()
		speaker.process_mode=Node.PROCESS_MODE_PAUSABLE
		speaker.bus="Dialogue"
		speaker.max_distance=720.0
		speaker.attenuation=1.6
		speaker.panning_strength=.65
		add_child(speaker)
		speakers.append(speaker)
	narrator=AudioStreamPlayer.new()
	narrator.bus="Dialogue"
	narrator.volume_db=-2.0
	add_child(narrator)

# A hero index is only ever as good as the manifests that back it: a recruit
# with no recordings at all keeps every caller silent instead of faulting.
#
# A placeholder recording is worse than none: playing one would still duck the
# music, still count as "speaking" and still hold the centred narrator, so a hero
# whose manifest marks voice_ready false is treated as having no voice at all.
# The ultimate cut-in then shows its subtitle and plays nothing.
func is_voiced(hero: int) -> bool:
	if ready_flags.is_empty():
		return true
	return ready_flags[clampi(hero,0,ready_flags.size()-1)]

func bank_for(hero: int) -> Dictionary:
	if banks.is_empty():
		return {}
	var at := clampi(hero,0,banks.size()-1)
	return banks[at] if banks[at] is Dictionary else {}

func line_for(hero: int, kind: String) -> AudioStream:
	if not is_voiced(hero):
		return null
	var bank := bank_for(hero)
	var clips = bank.get(kind,null)
	if clips is Array and not clips.is_empty():
		return clips[0]
	return null

func has_line(hero: int, kind: String) -> bool:
	return line_for(hero,kind)!=null

func play_line(hero: int, kind: String, emitter: int, at: Vector2, listener_at: Vector2) -> bool:
	hero=clampi(hero,0,maxi(0,banks.size()-1))
	if not has_line(hero,kind) or at.distance_to(listener_at)>720 or get_tree().paused:
		return false
	if emitter==local_id and narrator.playing:
		return false
	var now := Time.get_ticks_msec()
	var rank: int=PRIORITIES.get(kind,1)
	var state: Dictionary=next_allowed.get(emitter,{"at":0,"rank":0})
	if now<int(state.at) and rank<=int(state.rank):
		return false
	var voice: AudioStreamPlayer2D
	for candidate in speakers:
		if int(candidate.get_meta("emitter",-1))==emitter:
			voice=candidate
			break
	if voice and voice.playing and int(voice.get_meta("rank",0))>=rank:
		return false
	if not voice:
		for candidate in speakers:
			if not candidate.playing:
				voice=candidate
				break
	if not voice:
		return false
	var choices: Array=bank_for(hero)[kind]
	var key := "%d:%s" % [emitter,kind]
	var index := randi_range(0,choices.size()-1)
	if choices.size()>1 and index==int(previous.get(key,-1)):
		index=(index+1)%choices.size()
	previous[key]=index
	voice.stop()
	voice.stream=choices[index]
	voice.global_position=at
	voice.pitch_scale=1.0
	voice.volume_db=-4.0 if emitter==local_id else -9.0
	voice.set_meta("emitter",emitter)
	voice.set_meta("rank",rank)
	voice.set_meta("cue",kind)
	voice.set_meta("hero",hero)
	voice.play()
	var gap := 1.15 if kind in ["attack","dash"] else 1.8 if kind=="hurt" else .4
	next_allowed[emitter]={"at":now+int((voice.stream.get_length()+gap)*1000),"rank":rank}
	return true

func play_selection(hero: int) -> bool:
	hero=clampi(hero,0,maxi(0,banks.size()-1))
	var bus := AudioServer.get_bus_index("Dialogue")
	if AudioServer.is_bus_mute(bus) or AudioServer.get_bus_volume_db(bus)< -55.0:
		return false
	if narrator.playing and narrator.get_meta("cue","")=="select" and narrator_hero==hero:
		return false
	var line := line_for(hero,"select")
	if line==null:
		return false
	# A single centered voice follows the latest clicked portrait, without overlap.
	narrator.stop()
	narrator_hero=hero
	narrator.set_meta("cue","select")
	narrator.stream=line
	narrator.play()
	return true

func begin_ultimate(hero: int, online: bool) -> void:
	narrator.stop()
	narrator.set_meta("cue","ultimate")
	narrator_hero=clampi(hero,0,maxi(0,banks.size()-1))
	narrator_online=online
	for speaker in speakers:
		if not online or int(speaker.get_meta("emitter",-1))==local_id:
			speaker.stop()
	var line := line_for(narrator_hero,"ultimate-short" if online else "ultimate-charge")
	if line==null:
		return
	narrator.stream=line
	narrator.play()

func burst_ultimate() -> void:
	if narrator_online:
		return
	var line := line_for(narrator_hero,"ultimate-burst")
	if line==null:
		return
	narrator.stop()
	narrator.stream=line
	narrator.play()

func end_ultimate(interrupted: bool) -> void:
	# The network cut-in is short; its natural end must not chop the invocation.
	if interrupted:
		narrator.stop()

func is_speaking() -> bool:
	var bus := AudioServer.get_bus_index("Dialogue")
	if AudioServer.is_bus_mute(bus) or AudioServer.get_bus_volume_db(bus)< -55.0:
		return false
	if narrator.playing:
		return true
	for speaker in speakers:
		if speaker.playing:
			return true
	return false

func stop_all() -> void:
	narrator.stop()
	for speaker in speakers:
		speaker.stop()
	previous.clear()
	next_allowed.clear()

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
			child.stream=null
	banks.clear()
