class_name TideMusic
extends Node

## Offline Suno score. Linear crossfades also handle rapidly reversed scene changes.
var players: Dictionary = {}
var active_cue := ""
var scene_kind := "title"
var encounter_cue := ""
var duck_db := 0.0
var cinematic := false
var speaking := false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	for cue in ["camp","ruins","mirror","ember","final","earth","storm","abyss","dragon"]:
		var player := AudioStreamPlayer.new()
		player.bus="Music"
		var stream: AudioStreamOggVorbis=load("res://assets/audio/music/%s.ogg" % cue)
		stream.loop=true
		player.stream=stream
		player.volume_linear=0.0
		add_child(player)
		players[cue]=player
	set_scene("title")

func set_scene(scene: String) -> void:
	scene_kind=scene
	if scene!="game": encounter_cue=""
	select_cue()

func set_encounter(cue: String) -> void:
	if cue==encounter_cue: return
	encounter_cue=cue if cue in ["mirror","ember","final","earth","storm","abyss","dragon"] else ""
	select_cue()

func select_cue() -> void:
	var cue := (encounter_cue if not encounter_cue.is_empty() else "ruins") if scene_kind=="game" else "camp"
	if cue==active_cue:
		return
	active_cue=cue
	if not players[cue].playing:
		players[cue].play()

func _process(dt: float) -> void:
	var target_duck := -12.0 if cinematic else -6.0 if speaking else 0.0
	duck_db=move_toward(duck_db,target_duck,dt*(40.0 if target_duck<duck_db else 8.0))
	for cue in players:
		var player: AudioStreamPlayer=players[cue]
		var mix: float=move_toward(float(player.get_meta("mix",0.0)),1.0 if cue==active_cue else 0.0,dt/1.8)
		player.set_meta("mix",mix)
		player.volume_linear=mix*db_to_linear((-8.0 if cue=="camp" else -12.0 if cue=="ruins" else -11.0)+duck_db)
		if mix==0.0 and cue!=active_cue and player.playing:
			player.stop()

func _exit_tree() -> void:
	for player: AudioStreamPlayer in players.values():
		player.stop()
		player.stream=null
	players.clear()
