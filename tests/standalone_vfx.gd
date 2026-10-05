extends SceneTree
const Library = preload("res://scripts/vfx_library.gd")
const VFX = preload("res://scripts/stylized_vfx.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(reason)
func run() -> void:
	var fx := VFX.new()
	root.add_child(fx)
	var paths := {}
	for index in Catalog.WEAPONS.size()+Catalog.STARTER_WEAPONS.size():
		var key: String=Library.weapon_key(index)
		var texture: Texture2D=Library.texture(key)
		check(texture!=null and not texture is AtlasTexture,"Weapon %d uses an individual texture" % index)
		check(texture.get_width()>=1024 and texture.get_height()>=1024,"Weapon %d retains native HD resolution" % index)
		check(texture.resource_path.begins_with(Library.IMAGE_BASE),"Weapon %d uses final ImageGen artwork" % index)
		paths[texture.resource_path]=true
		fx.reset()
		fx.event({"kind":"strike","p":Vector2.ZERO,"weapon":Catalog.weapon_family(index),"weapon_index":index,"combo":2,"reach":100.0,"pattern":Catalog.weapon(index).get("pattern","")},0)
		check(not fx.effects.is_empty(),"Weapon %d plays a release effect" % index)
		check(fx.effects[0].texture==Library.weapon_key(index,"finisher"),"Finisher keeps the exact weapon identity")
	check(paths.size()==21,"All 21 weapons resolve to different source PNGs")
	for hero in 4:
		fx.reset()
		fx.event({"kind":"skill","p":Vector2.ZERO,"hero":hero},hero)
		check(fx.effects[0].texture=="hero_%d_ultimate" % hero,"Ultimate uses hero-specific art")
	fx.reset()
	for i in 200:
		fx.event({"kind":"impact","p":Vector2.ZERO,"weapon_index":i%21,"heavy":true},0)
	check(fx.effects.size()<=fx.MAX_EFFECTS and fx.shards.size()<=fx.MAX_SHARDS,"Crowded combat stays bounded")
	fx.advance(2.0)
	check(fx.effects.is_empty() and fx.shards.is_empty(),"Effects and shards expire completely")
	fx.event({"kind":"dodge","p":Vector2.ZERO},0)
	fx.reset()
	check(fx.effects.is_empty() and fx.shards.is_empty(),"Scene transitions clear all VFX")
	var session := TideSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.solo({"hero":0})
	session.launch(false,1729)
	session.enemies.clear()
	var player: Dictionary=session.players[1]
	player.weapon=15
	player.attack=0.0
	player.swing_time=0.0
	player.cast_time=0.0
	player.dodge_time=0.0
	player.reload=0.0
	session.attack(player)
	check(player.combo_timeout>player.swing_total+.4,"Slow greatswords retain the combo window")
	player.pending_strike=false
	player.attack=.1
	player.swing_time=.1
	session.attack(player)
	check(float(player.get("attack_buffer",0))>0,"Late recovery click is buffered")
	player.invuln=1000
	session.spawn_timer=9999
	session.inputs.clear()
	session.simulate(.11)
	check(player.pending_strike and player.combo==1 and float(player.get("attack_buffer",0))==0,"A buffered click starts exactly the next combo stage after recovery")
	player.pending_strike=false
	player.attack=.1
	player.swing_time=.1
	session.attack(player)
	session.perform(1,"dash")
	check(float(player.get("attack_buffer",0))==0,"Dodge cancels the queued attack")
	var captured: Array=[]
	session.combat_event.connect(func(event): captured.append(event.duplicate()))
	session.broadcast_combat({"kind":"strike","p":player.p,"id":1,"weapon":2})
	check(captured.back().weapon_index==15,"Network presentation carries the exact item index")
	session.spawn_enemy(player.p+Vector2(20,0),0)
	var enemy: Dictionary=session.enemies.back()
	player.weapon=1
	session.damage_enemy(enemy,1.0,1,Vector2.RIGHT,0,3,5)
	check(captured.back().weapon_index==5,"A travelling ice shot keeps its original item after a swap")
	fx.queue_free()
	session.queue_free()
	await process_frame
	await process_frame
	print("STANDALONE VFX: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
