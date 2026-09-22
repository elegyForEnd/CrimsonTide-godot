class_name TideSound
extends Node

var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var ambience: AudioStreamPlayer

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream=null
	if ambience:
		ambience.stop()
		ambience.stream=null
	clips.clear()

func _ready() -> void:
	for i in 12:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for type in ["shot","hit","loot","skill","dash","bell","hurt","slash","heavy","magic"]:
		clips[type] = synth(type)
	ambience=AudioStreamPlayer.new()
	add_child(ambience)
	ambience.stream=synth("ambient")
	ambience.volume_db=-17
	ambience.play()

func play(type: String) -> void:
	if not clips.has(type):
		return
	for v in voices:
		if not v.playing:
			v.stream=clips[type]
			v.pitch_scale=randf_range(0.94,1.06)
			v.volume_db=-12 if type=="shot" else -7
			v.play()
			return

func synth(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var length := 0.18
	if kind in ["skill","bell"]:
		length=1.2
	if kind=="ambient":
		length=8.0
	var bytes := PackedByteArray()
	bytes.resize(int(rate*length)*2)
	var rng := RandomNumberGenerator.new()
	rng.seed=77
	for i in int(rate*length):
		var t := float(i)/rate
		var env := pow(maxf(0.0,1.0-t/length),2)
		var sample := 0.0
		match kind:
			"shot": sample=(sin(TAU*(180*t-330*t*t))*0.4+rng.randf_range(-0.5,0.5))*env
			"hit","hurt": sample=(rng.randf_range(-0.6,0.6)+sin(TAU*85*t)*0.3)*env
			"loot": sample=sin(TAU*(660+int(t*20)*110)*t)*env*0.45
			"slash": sample=(rng.randf_range(-0.65,0.65)*sin(PI*t/length)+sin(TAU*(420*t-850*t*t))*0.2)*env
			"heavy": sample=(sin(TAU*(95*t-100*t*t))*0.65+rng.randf_range(-0.35,0.35))*env
			"magic": sample=(sin(TAU*(480*t+650*t*t))*0.3+sin(TAU*960*t)*0.15+rng.randf_range(-0.15,0.15))*env
			"dash": sample=rng.randf_range(-0.5,0.5)*sin(PI*t/length)*env
			"skill","bell": sample=(sin(TAU*220*t)+0.45*sin(TAU*553*t)+0.25*sin(TAU*887*t))*env*0.4
			"ambient": sample=(sin(TAU*55*t)*0.35+sin(TAU*82.5*t)*0.16+sin(TAU*110*t)*0.12)*(0.7+0.3*cos(TAU*t/8))*0.4
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*26000))
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate
	stream.data=bytes
	if kind=="ambient":
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_end=int(rate*length)
	return stream
