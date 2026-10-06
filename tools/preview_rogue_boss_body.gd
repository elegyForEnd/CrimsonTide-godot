extends SceneTree
## Screenshot of the pooled guardians' bodies on the live mirror-realm field.
##
## Floor 0 used to draw ``boss-hd-0`` no matter which identity the pool picked.
## This stages identities 0 (the old floor art) plus the three generated ones
## (5 bell, 6 earth, 7 abyss) side by side, all through the real renderer, so the
## difference is visible in one frame.
const Combat=preload("res://scripts/rogue_combat.gd")
const Art=preload("res://scripts/boss_effect_art.gd")

func _initialize() -> void: call_deferred("run")

func seed_for(identity: int) -> int:
	for candidate in range(1,20000):
		if Combat.boss_art_for(candidate,0)==identity: return candidate
	return 1

func run() -> void:
	var session=load("res://scripts/session.gd").new()
	root.add_child(session)
	session.solo({"hero":0,"mode":"roguelike"})
	session.launch(false,seed_for(7))
	session.set_physics_process(false)
	var field: Control=load("res://scripts/rogue_field.gd").new()
	field.session=session
	root.add_child(field)
	session.enemies.clear()
	session.bullets.clear()
	var home: Vector2=field.camera
	var identities := [0,5,6,7]
	for index in identities.size():
		var e := {}
		session.roguelike.combat.setup_boss(e,0,session)
		e["boss_art"]=identities[index]
		e["art_key"]=Art.rogue_key(identities[index])
		e["boss_name"]=Combat.NAMES[identities[index]]
		e["id"]=100+index
		e["p"]=home+Vector2(-345.0+float(index)*230.0,10.0)
		e["moving"]=false
		e["attack_time"]=0.0
		e["facing"]=1.0
		e["hp"]=e["max_hp"]
		session.enemies.append(e)
	session.elapsed=0.0
	print("PREVIEW: staged identities ",identities," around ",home)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	image.save_png("res://build/rogue-boss-bodies.png")
	print("PREVIEW SAVED res://build/rogue-boss-bodies.png ",image.get_size())
	quit()
