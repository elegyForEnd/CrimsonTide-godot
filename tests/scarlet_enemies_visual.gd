extends SceneTree
const Roster=preload("res://scripts/scarlet/enemy_roster.gd")
const Frames=preload("res://scripts/scarlet/enemy_frames.gd")
var screen
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	screen=preload("res://scripts/scarlet/screen.gd").new(); root.add_child(screen)
	var c=screen.campaign; c.state=c.new_state(); c.save_enabled=false
	screen.set_active(true); screen.set_physics_process(false); screen.set_process(false)
	for key in Roster.data().bosses:
		var act: int={"inquisitor":1,"judge":2,"vein":3,"surgeon":4,"admiral":5,"queen":6,"beast":3,"warden":6}[key]
		c.combat.clear(); c.state.pending={}; c.state.act=act; c.state.stage=6; c.state.zone="%d:6" % act
		screen.world.build(); c.combat.start("R-%d-06" % act,"fixture",key,1)
		var e: Dictionary=c.enemies[0]
		for pose in 3:
			e.windup=1.0 if pose==1 else 0.0; e.release=.2 if pose==2 else 0.0
			screen.world.sync(0)
			var texture: Texture2D=Frames.prepare(key)[pose].texture
			check(screen.world.original.sprites.any(func(sprite): return sprite.visible and sprite.texture==texture),"real renderer submits authored boss pose "+key+str(pose))
	# Mixed chapter-four pack is both actionable and visible on the map.
	c.combat.clear(); c.state.act=4; c.state.stage=2; c.state.zone="4:2"; screen.world.build()
	c.state.completed=[]
	for qid in c.content.main_order:
		if qid=="R-4-03": break
		c.state.completed.append(qid)
	c.state.accepted=["R-4-03"]; c.state.steps["R-4-03"]=1
	var marker: Dictionary=preload("res://scripts/scarlet/enemy_encounters.gd").nodes(c)[0]
	c.hero_at=marker.p; c.use(marker)
	screen.world.original.focus=c.terrain().native(c.hero_at)
	screen.speech_time=0; screen.toast_time=0; screen.world.sync(0)
	for e in c.enemies:
		var texture: Texture2D=Frames.prepare(e.key)[0].texture
		check(screen.world.original.sprites.any(func(sprite): return sprite.visible and sprite.texture==texture),"real map uses new small-enemy art "+str(e.key))
	c.combat.opening_grace=0; c.combat.attack_pattern(c.enemies[0]); screen.world.sync(0); screen.refresh(); screen.queue_redraw()
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png("res://output/rpg-minions-final.png")==OK,"field battle screenshot saved")
	screen.close_panel(); preload("res://scripts/scarlet/bestiary.gd").open(screen)
	var panel: Control=screen.overlay.get_child(screen.overlay.get_child_count()-1)
	var detail: VBoxContainer=panel.get_child(panel.get_child_count()-1).get_child(0)
	preload("res://scripts/scarlet/bestiary.gd").show_entry(screen,detail,"surgeon",c.content.bosses.surgeon.name)
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
	check(screen.modal,"bestiary safely pauses gameplay")
	check(root.get_texture().get_image().save_png("res://output/rpg-bestiary-final.png")==OK,"bestiary screenshot saved")
	screen.close_panel(); check(not screen.modal,"bestiary closes back into encounter")
	print("SCARLET_ENEMIES_VISUAL ",checks," checks, ",failures," failures")
	screen.queue_free(); await process_frame; quit(1 if failures else 0)
