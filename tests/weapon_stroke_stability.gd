extends SceneTree
const FX=preload("res://scripts/stylized_vfx.gd")
var socket := {"tip":Vector2(295,245),"aim":Vector2.RIGHT,"active":true}
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(500,500)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var fx := FX.new()
	viewport.add_child(fx)
	fx.socket_provider=func(_id): return socket
	for weapon in 21:
		for combo in 3:
			fx.reset()
			fx.transform=Transform2D(Vector2.RIGHT,Vector2(0,.78),Vector2(8,19))
			socket={"tip":Vector2(295,245),"aim":Vector2.RIGHT,"active":true}
			fx.event({"kind":"strike","p":Vector2(200,250),"aim":Vector2.RIGHT,"weapon":Catalog.weapon_family(weapon),"weapon_index":weapon,"reach":Catalog.weapon(weapon).reach,"pattern":Catalog.weapon(weapon).get("pattern",""),"combo":combo,"id":1},0)
			fx.shards.clear()
			# Recover before a delayed echo first becomes visible.
			var captured := []
			for effect in fx.effects:
				if effect.has("socket_local"): captured.append(effect.socket_local)
			socket={"tip":Vector2(160,125),"aim":Vector2.UP,"active":false}
			fx.advance(.085)
			await process_frame
			await RenderingServer.frame_post_draw
			var initial := viewport.get_texture().get_image().get_data()
			socket={"tip":Vector2(385,355),"aim":Vector2.LEFT,"active":true}
			fx.queue_redraw(); fx.light.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(initial==viewport.get_texture().get_image().get_data(),"Release pixels stay fixed across movement, recovery and next attack: weapon%d combo%d"%[weapon,combo])
			var index := 0
			for effect in fx.effects:
				if not effect.has("socket_local"): continue
				check(effect.socket_local==captured[index],"Delayed effects keep the original stroke location")
				index+=1
			check(index>0,"Weapon stroke captures its location at emission")
	# Charges alone follow the moving weapon until release/cancel.
	fx.reset()
	fx.event({"kind":"windup","p":Vector2(200,250),"aim":Vector2.RIGHT,"weapon":3,"weapon_index":3,"windup":.5,"id":1})
	fx.advance(.05)
	await process_frame
	await RenderingServer.frame_post_draw
	var first: Vector2=fx.effects[0].socket_local
	socket.tip+=Vector2(40,-20)
	fx.queue_redraw(); fx.light.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(fx.effects[0].socket_local.distance_to(first)>30,"Charge follows the weapon, independently of fixed release stamps")
	viewport.queue_free()
	await process_frame
	print("WEAPON STROKE STABILITY ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
