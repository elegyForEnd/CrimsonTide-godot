class_name TideSound
extends Node

## Offline, edited Suno samples. No generated waveform fallback.
const VARIANTS := {"shot":2,"hit":3,"loot":1,"skill":1,"dash":2,"bell":1,
	"hurt":1,"slash":3,"heavy":3,"magic":3,"impact-heavy":2}
const LEVELS := {"shot":-14.0,"hit":-14.0,"loot":-17.0,"skill":-9.0,"dash":-12.0,
	"bell":-11.0,"hurt":-10.0,"slash":-9.0,"heavy":-8.0,"magic":-11.0,"impact-heavy":-11.0}
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var ambience: AudioStreamPlayer
var cinema_charge: AudioStreamPlayer
var cinema_burst: AudioStreamPlayer
var charges: Array[AudioStream] = []
var bursts: Array[AudioStream] = []
var short_charges: Array[AudioStream] = []
var short_bursts: Array[AudioStream] = []
var cinema_online := false
var previous: Dictionary = {}
var last_played: Dictionary = {}
var voice_cursor := 0
var ambience_fade: Tween

func make_voice(always: bool = false) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	if always:
		voice.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(voice)
	return voice

func _ready() -> void:
	for i in 24:
		voices.append(make_voice())
	for kind in VARIANTS:
		var variants: Array[AudioStream] = []
		for i in int(VARIANTS[kind]):
			variants.append(load("res://assets/audio/%s-%d.wav" % [kind,i]))
		clips[kind]=variants
	for hero in 3:
		charges.append(load("res://assets/audio/ultimate-charge-%d.wav" % hero))
		bursts.append(load("res://assets/audio/ultimate-burst-%d.wav" % hero))
		short_charges.append(load("res://assets/audio/ultimate-charge-short-%d.wav" % hero))
		short_bursts.append(load("res://assets/audio/ultimate-burst-short-%d.wav" % hero))
	cinema_charge=make_voice(true)
	cinema_burst=make_voice(true)
	ambience=make_voice(true)
	var loop: AudioStreamOggVorbis=load("res://assets/audio/ambient.ogg")
	loop.loop=true
	ambience.stream=loop
	ambience.volume_db=-24.0
	ambience.play()

func play(kind: String, variant: int = -1) -> void:
	if not clips.has(kind):
		return
	# A cleave may report many impacts in the same frame. Keep its transient clean.
	var now := Time.get_ticks_msec()
	var cooldown := 45 if kind in ["hit","impact-heavy","hurt"] else 18
	if now-int(last_played.get(kind,-1000))<cooldown:
		return
	last_played[kind]=now
	var samples: Array=clips[kind]
	var index := posmod(variant,samples.size()) if variant>=0 else randi_range(0,samples.size()-1)
	if variant<0 and samples.size()>1 and index==int(previous.get(kind,-1)):
		index=(index+1)%samples.size()
	previous[kind]=index
	var voice: AudioStreamPlayer
	for candidate in voices:
		if not candidate.playing:
			voice=candidate
			break
	if not voice:
		voice=voices[voice_cursor]
		voice_cursor=(voice_cursor+1)%voices.size()
		voice.stop()
	voice.stream=samples[index]
	voice.pitch_scale=randf_range(.98,1.02)
	voice.volume_db=float(LEVELS.get(kind,-12.0))
	voice.play()

func begin_cinematic(hero: int, online: bool) -> void:
	end_cinematic()
	cinema_online=online
	cinema_charge.stream=(short_charges if online else charges)[clampi(hero,0,2)]
	cinema_charge.pitch_scale=1.0
	cinema_charge.volume_db=-8.0
	cinema_charge.play()
	duck_ambience(-33.0)

func burst_cinematic(hero: int) -> void:
	cinema_charge.stop()
	cinema_burst.stream=(short_bursts if cinema_online else bursts)[clampi(hero,0,2)]
	cinema_burst.pitch_scale=1.0
	cinema_burst.volume_db=-7.0
	cinema_burst.play()

func end_cinematic() -> void:
	if cinema_charge:
		cinema_charge.stop()
	if cinema_burst:
		cinema_burst.stop()
	if ambience:
		duck_ambience(-24.0)

func duck_ambience(level: float) -> void:
	if ambience_fade:
		ambience_fade.kill()
	ambience_fade=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ambience_fade.tween_property(ambience,"volume_db",level,.16)

func _exit_tree() -> void:
	if ambience_fade:
		ambience_fade.kill()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null
	clips.clear()
	charges.clear()
	bursts.clear()
	short_charges.clear()
	short_bursts.clear()
