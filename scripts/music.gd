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
var world_cue := "ruins"
const EXPLORATION := ["ruins","city","floor_1","floor_2","floor_3","floor_4","floor_5"]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/music-manifest.json"))
	for cue in manifest.tracks:
		var player := AudioStreamPlayer.new()
		player.bus="Music"
		var stream: AudioStreamOggVorbis=load("res://assets/audio/music/%s" % manifest.tracks[cue].file)
		stream.loop=true
		player.stream=stream
		player.volume_linear=0.0
		add_child(player)
		players[cue]=player
	set_scene("title")

func set_scene(scene: String) -> void:
	scene_kind=scene
	encounter_cue=""
	world_cue="ruins"
	select_cue()

func set_encounter(cue: String) -> void:
	if cue==encounter_cue: return
	encounter_cue=cue if players.has(cue) else ""
	select_cue()

## Local presentation only: authoritative world state also works for network peers.
func set_world(map_id: String, raid: Dictionary, enemies: Array, at: Vector2) -> void:
	if scene_kind!="game": return
	world_cue="city" if map_id=="city" else "ruins"
	var encounter := ""
	if raid.get("mode","")=="roguelike":
		var floor_number := clampi(int(raid.get("floor",1)),1,5)
		world_cue="floor_%d" % floor_number
		var room: String=str(raid.get("room","combat"))
		if room in ["shop","treasure","talent"]:
			world_cue={"shop":"shop","treasure":"treasure","talent":"sanctuary"}[room]
		if raid.get("phase","")=="rogue_prepare": world_cue="sanctuary"
		for enemy in enemies:
			if enemy.get("rogue_guardian",false) and float(enemy.get("hp",0))>0:
				encounter="guardian_%d" % floor_number
				break
	else:
		var closest := 850.0
		for enemy in enemies:
			if float(enemy.get("hp",0))<=0: continue
			if enemy.get("raid_boss",false):
				encounter="abyss" if enemy.get("abyss_final",false) else "hidden" if enemy.get("hidden_final",false) else "final" if enemy.get("final_form",false) else ["bishop","hunter","queen"][clampi(int(enemy.get("boss_kind",0)),0,2)]
				break
			var distance: float=enemy.p.distance_to(at)
			if distance>=closest: continue
			if enemy.get("mini_boss",false):
				encounter="dragon" if enemy.get("dragon_boss",false) else ("earth" if int(enemy.get("wild_kind",0))==0 else "storm") if enemy.get("wild_boss",false) else "mirror" if int(enemy.get("mini_kind",0))==0 else "ember"
				closest=distance
			elif map_id=="city" and int(enemy.get("type",0))==4:
				encounter="knight"
				closest=distance
	encounter_cue=encounter if players.has(encounter) else ""
	select_cue()

func set_result(escaped: bool) -> void:
	set_scene("victory" if escaped else "defeat")

func select_cue() -> void:
	var cue: String=(encounter_cue if not encounter_cue.is_empty() else world_cue) if scene_kind=="game" else {"title":"title","ground":"home","home":"home","rogue_setup":"sanctuary","victory":"victory","defeat":"defeat"}.get(scene_kind,"camp")
	if not players.has(cue): cue="ruins" if scene_kind=="game" else "camp"
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
		player.volume_linear=mix*db_to_linear((-8.0 if cue in ["camp","home","title"] else -12.0 if cue in EXPLORATION else -11.0)+duck_db)
		if mix==0.0 and cue!=active_cue and player.playing:
			player.stop()

func _exit_tree() -> void:
	for player: AudioStreamPlayer in players.values():
		player.stop()
		player.stream=null
	players.clear()
