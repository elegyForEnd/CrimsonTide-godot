class_name TideSound
extends Node

## Stylized anime combat and separately credited Japanese character voices.
const VARIANTS := {"shot":3,"hit":5,"loot":3,"skill":3,"dash":4,"bell":2,
	"hurt":3,"down":2,"slash":6,"heavy":4,"magic":4,"impact-heavy":4,
	"impact-metal":4,"impact-magic":4,"magic-windup":4,"step":8,"run":8,"land":4,
	"ui":3,"ui-open":2,"ui-close":2,"equip":4,"reload":2,"reload-end":2,
	"heal":2,"burn":2,"death":3,"enemy-cast":2,"chest":2,
	"search-open":1,"search-reveal":6}
const LEVELS := {"shot":-12.0,"hit":-10.0,"loot":-14.0,"skill":-5.0,"dash":-11.0,
	"bell":-10.0,"hurt":-8.0,"down":-7.0,"slash":-8.0,"heavy":-7.0,"magic":-10.0,
	"impact-heavy":-7.0,"impact-metal":-13.0,"impact-magic":-11.0,"magic-windup":-17.0,
	"step":-17.0,"run":-14.0,"land":-13.0,"ui":-14.0,"ui-open":-17.0,"ui-close":-17.0,
	"equip":-12.0,"reload":-13.0,"reload-end":-12.0,"heal":-11.0,"burn":-12.0,
	"death":-16.0,"enemy-cast":-14.0,"chest":-13.0,
	"search-open":-16.0,"search-reveal":-13.0}
const UI_CUES := ["ui","ui-open","ui-close"]
var voices: Array[AudioStreamPlayer2D] = []
var ui_voices: Array[AudioStreamPlayer] = []
var listener: AudioListener2D
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
var ambience_fade: Tween
var motion_state: Dictionary = {}
var cinema_active := false
var scene_kind := "title"
var sequence := 0
const BossPresentation = preload("res://scripts/boss_presentation.gd")
var dialogue: HeroVoice
var dialogue_duck := 0.0
var music: TideMusic

func _process(dt: float) -> void:
	if music:
		music.cinematic=cinema_active
		music.speaking=dialogue and dialogue.is_speaking()
	var target := -5.0 if dialogue and dialogue.is_speaking() else 0.0
	dialogue_duck=move_toward(dialogue_duck,target,dt*(45.0 if target<dialogue_duck else 14.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Combat"),-1.5+dialogue_duck)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Cinematic"),dialogue_duck)

func make_voice(always: bool = false) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	if always:
		voice.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(voice)
	return voice

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	dialogue=HeroVoice.new()
	add_child(dialogue)
	listener=AudioListener2D.new()
	add_child(listener)
	listener.make_current()
	for i in 24:
		var voice := AudioStreamPlayer2D.new()
		voice.process_mode=Node.PROCESS_MODE_PAUSABLE
		voice.bus="Combat"
		voice.max_distance=900.0
		voice.attenuation=1.5
		voice.panning_strength=0.8
		add_child(voice)
		voices.append(voice)
	for i in 4:
		var voice := make_voice(true)
		voice.bus="Interface"
		ui_voices.append(voice)
	for kind in VARIANTS:
		var variants: Array[AudioStream] = []
		for i in int(VARIANTS[kind]):
			variants.append(load("res://assets/audio/%s-%d.wav" % [kind,i]))
		clips[kind]=variants
	# Every boss theme borrows the queen's take for an action it does not ship,
	# so a new encounter only needs the recordings it really uses and a missing
	# file can never leave a null stream in the cue table. Guard and break only
	# exist for the two encounters that can actually parry.
	const GUARDED := ["thorn","knight"]
	for key in BossPresentation.KEYS+["mirror","ember","moon","earth","storm","abyss","dragon"]:
		for action in ["charge","quick","sweep","burst","lance","ritual","fall","guard","break"]:
			if action in ["guard","break"] and key not in GUARDED: continue
			var cue: String=key+"-"+action
			var direct := "res://assets/audio/bosses/"+cue+".wav"
			clips[cue]=[load(direct) if ResourceLoader.exists(direct) else load("res://assets/audio/bosses/queen-"+action+".wav")]
	# One ultimate jingle per hero in the catalog. A hero whose lines are not
	# recorded yet has no jingle of their own either; the first hero's take stands
	# in, so the cut-in still has music under it.
	for hero in Catalog.HEROES.size():
		charges.append(_load_or_first("res://assets/audio/ultimate-charge-%d.wav",hero,charges))
		bursts.append(_load_or_first("res://assets/audio/ultimate-burst-%d.wav",hero,bursts))
		short_charges.append(_load_or_first("res://assets/audio/ultimate-charge-short-%d.wav",hero,short_charges))
		short_bursts.append(_load_or_first("res://assets/audio/ultimate-burst-short-%d.wav",hero,short_bursts))
	cinema_charge=make_voice(true)
	cinema_burst=make_voice(true)
	cinema_charge.bus="Cinematic"
	cinema_burst.bus="Cinematic"
	ambience=make_voice(true)
	ambience.bus="Ambience"
	var loop: AudioStreamOggVorbis=load("res://assets/audio/ambient.ogg")
	loop.loop=true
	ambience.stream=loop
	ambience.volume_db=-24.0
	ambience.play()
	music=TideMusic.new()
	add_child(music)

# The ultimate jingle for one hero, or the first hero's take when this recruit
# has no recording of their own. Keeps the per-hero arrays indexable.
func _load_or_first(pattern: String, hero: int, so_far: Array[AudioStream]) -> AudioStream:
	var path := pattern % hero
	if ResourceLoader.exists(path):
		return load(path)
	return so_far[0] if not so_far.is_empty() else null

func priority(kind: String) -> int:
	if kind.contains("-") and kind.get_slice("-",0) in BossPresentation.KEYS+["mirror","ember","moon","earth","storm","abyss","dragon"]: return 92
	if kind=="skill": return 95
	if kind in ["hurt","down","bell"]: return 90
	if kind in ["slash","heavy","magic","shot"]: return 70
	if kind in ["step","run","land","death"]: return 15
	return 50

func play(kind: String, variant: int = -1, at: Vector2 = Vector2.INF, gain: float = 0.0, emitter: int = 0) -> void:
	if not clips.has(kind):
		return
	var is_ui := kind in UI_CUES
	if cinema_active and not cinema_online and not is_ui:
		return
	var position := listener.global_position if not at.is_finite() else at
	if not is_ui and position.distance_to(listener.global_position)>900:
		return
	# A cleave can hit a crowd in one simulation tick. Bound its combined loudness.
	var now := Time.get_ticks_msec()
	var cooldown := 45 if kind in ["hit","impact-heavy","impact-metal","impact-magic"] else 130 if kind=="hurt" else 18
	var key := "%s:%d" % [kind,emitter]
	if now-int(last_played.get(key,-1000))<cooldown:
		return
	last_played[key]=now
	var samples: Array=clips[kind]
	var index := posmod(variant,samples.size()) if variant>=0 else randi_range(0,samples.size()-1)
	if variant<0 and samples.size()>1 and index==int(previous.get(kind,-1)):
		index=(index+1)%samples.size()
	previous[kind]=index
	if is_ui:
		var ui_voice: AudioStreamPlayer=ui_voices[0]
		for candidate in ui_voices:
			if not candidate.playing:
				ui_voice=candidate
				break
		ui_voice.stream=samples[index]
		ui_voice.pitch_scale=1.0
		ui_voice.volume_db=float(LEVELS[kind])+gain
		ui_voice.play()
		return
	var voice: AudioStreamPlayer2D
	var oldest: AudioStreamPlayer2D
	var same_count := 0
	for candidate in voices:
		if candidate.playing and candidate.get_meta("cue","")==kind:
			same_count+=1
			if not oldest or int(candidate.get_meta("sequence",0))<int(oldest.get_meta("sequence",0)):
				oldest=candidate
		if not candidate.playing and not voice:
			voice=candidate
	var limit := 4 if kind in ["step","run","heavy","magic","impact-heavy","death"] else 6
	if same_count>=limit:
		voice=oldest
	if not voice:
		for candidate in voices:
			if int(candidate.get_meta("priority",0))<=priority(kind):
				if not voice or int(candidate.get_meta("priority",0))<int(voice.get_meta("priority",0)) or (candidate.get_meta("priority")==voice.get_meta("priority") and int(candidate.get_meta("sequence"))<int(voice.get_meta("sequence"))):
					voice=candidate
	if not voice:
		return
	sequence+=1
	voice.stop()
	voice.set_meta("cue",kind)
	voice.set_meta("priority",priority(kind))
	voice.set_meta("sequence",sequence)
	voice.set_meta("emitter",emitter)
	voice.global_position=position
	voice.stream=samples[index]
	voice.pitch_scale=randf_range(.97,1.03) if kind not in ["heal","bell","skill","reload"] else 1.0
	voice.volume_db=float(LEVELS.get(kind,-12.0))+gain
	voice.play()

func stop_cue(kind: String, emitter: int) -> void:
	for voice in voices:
		if voice.get_meta("cue","")==kind and int(voice.get_meta("emitter",0))==emitter:
			voice.stop()

func boss(data: Dictionary) -> void:
	var cue := BossPresentation.cue(data)
	var emitter := int(data.id)
	var prefix: String=cue.get_slice("-",0)
	if data.action in ["release","fall","break"]:
		stop_cue(prefix+"-charge",emitter)
	# Radial volleys share one cue per source and tick; play() de-duplicates them.
	var gain: float={"charge":1.0,"release":6.0,"phase":7.0,"entrance":5.0,"guard":2.0,"break":6.0,"fall":5.0}.get(data.action,0.0)
	play(cue,0,data.p,gain,emitter)
	if data.action=="release" and data.get("shape","")=="cone" and float(data.get("total",0))>=1.4:
		play(prefix+"-burst",0,data.p,1.0,emitter)

func attack(weapon: int, combo: int, at: Vector2, emitter: int, spell: String = "star") -> void:
	var kind: String="slash" if spell=="arrow" else ["shot","slash","heavy","magic"][clampi(weapon,0,3)]
	var variant := clampi(combo,0,2)*2+randi_range(0,1) if weapon==1 else -1
	play(kind,variant,at,1.5 if weapon==1 and combo==2 else 0.0,emitter)

func set_scene(value: String) -> void:
	# Lobby updates rebuild the camp UI; let an ongoing selection line finish.
	if value=="camp" and scene_kind=="camp":
		return
	scene_kind=value
	music.set_scene(value)
	dialogue.stop_all()
	motion_state.clear()
	last_played.clear()
	for voice in voices:
		voice.stop()
	duck_ambience(-24.0 if value=="game" else -29.0)

func update_world(camera: Vector2, players: Dictionary, dt: float) -> void:
	listener.global_position=camera
	for id in motion_state.keys():
		if not players.has(id): motion_state.erase(id)
	for id in players:
		var p: Dictionary=players[id]
		var state: Dictionary=motion_state.get(id,{"p":p.p,"time":0.0,"distance":0.0,"still":0.0,"dodge":false})
		var moved: float=state.p.distance_to(p.p)
		state.p=p.p
		var dodging: bool=p.get("dodge_time",0.0)>0
		if state.dodge and not dodging and p.status=="active":
			play("land",-1,p.p,-2.0,id)
		state.dodge=dodging
		state.still=0.0 if moved>.05 else float(state.still)+dt
		# Physics ticks and network snapshots can leave several render frames stationary.
		# Keep cadence across short gaps, but require fresh displacement to sound a step.
		if p.status=="active" and not dodging and p.get("motion","idle") in ["walk","run"] and state.still<=.20 and moved<160 and p.get("swing_time",0.0)<=0 and p.get("cast_time",0.0)<=0:
			state.time+=dt
			state.distance+=moved
			var running_now: bool=p.motion=="run"
			if moved>.05 and state.time>=(2.0/11.5 if running_now else 2.0/7.0) and state.distance>=16.0:
				play("run" if running_now else "step",-1,p.p,0.0,id)
				state.time=0.0
				state.distance=0.0
		else:
			state.time=0.0
			state.distance=0.0
		motion_state[id]=state

func begin_cinematic(hero: int, online: bool) -> void:
	end_cinematic()
	dialogue.begin_ultimate(hero,online)
	cinema_active=true
	cinema_online=online
	if not online:
		for voice in voices:
			voice.stop()
	cinema_charge.stream=(short_charges if online else charges)[clampi(hero,0,charges.size()-1)]
	cinema_charge.pitch_scale=1.0
	cinema_charge.volume_db=-8.0
	cinema_charge.play()
	duck_ambience(-33.0)

func burst_cinematic(hero: int) -> void:
	dialogue.burst_ultimate()
	cinema_charge.stop()
	cinema_burst.stream=(short_bursts if cinema_online else bursts)[clampi(hero,0,bursts.size()-1)]
	cinema_burst.pitch_scale=1.0
	cinema_burst.volume_db=-7.0
	cinema_burst.play()

func end_cinematic(interrupted: bool = true) -> void:
	cinema_active=false
	if dialogue:
		dialogue.end_ultimate(interrupted)
	if cinema_charge:
		cinema_charge.stop()
	if cinema_burst:
		cinema_burst.stop()
	if ambience:
		duck_ambience(-24.0 if scene_kind=="game" else -29.0)

func duck_ambience(level: float) -> void:
	if ambience_fade:
		ambience_fade.kill()
	ambience_fade=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ambience_fade.tween_property(ambience,"volume_db",level,.16)

func _exit_tree() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Combat"),-1.5)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Cinematic"),0.0)
	if ambience_fade:
		ambience_fade.kill()
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
			child.stream=null
	clips.clear()
	charges.clear()
	bursts.clear()
	short_charges.clear()
	short_bursts.clear()
