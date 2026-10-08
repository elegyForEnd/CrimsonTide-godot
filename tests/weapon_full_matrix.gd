extends SceneTree
## Live field sockets plus isolated production GPU rendering for every combination.
const FX=preload("res://scripts/stylized_vfx.gd")
const M=preload("res://scripts/weapon_mechanics.gd")
const Actions=preload("res://scripts/rogue_actions.gd")
const Atlas=preload("res://tests/weapon_full_visual_audit.gd")
var checks := 0
var failures := 0
var cases := 0
var flight_cases := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.profile.path="user://full-weapon-matrix.json"
	var batch: Array=[]
	for slot in 32:
		var viewport := SubViewport.new(); viewport.size=Vector2i(280,280); viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		var fx := FX.new(); viewport.add_child(fx)
		var flights := Atlas.Flights.new(); viewport.add_child(flights); flights.hide(); flights.spell_light.hide()
		batch.append({"viewport":viewport,"fx":fx,"flights":flights})
	for mode in ["expedition","roguelike"]:
		app.session.solo({"hero":0,"mode":mode}); app.session.launch(false,1729); app.session.set_physics_process(false); app.session.enemies.clear()
		var field=app.field if mode=="expedition" else app.rogue_field
		await create_timer(.12).timeout
		field.set_process(false); field.combat.set_process(false)
		var projection: Transform2D=field.ground_transform()
		app.field.hide(); app.rogue_field.hide()
		var p: Dictionary=app.session.players[1]
		for weapon in range(21)+range(600,648):
			p.weapon=weapon
			p.erase("build_strike_windup")
			var spec := Catalog.weapon(weapon)
			var move := WeaponArts.of(weapon)
			var art_windup := float(spec.windup)
			if mode=="roguelike":
				app.session.raid.phase="rogue_combat"
				p.art_cd=0; p.reload=0; p.swing_time=0; p.cast_time=0; p.attack=0; p.dodge_time=0; p.flask_time=0; p.height=0; p.mana=1000; p.air_art=false; p.aim=Vector2.RIGHT
				check(Actions.start_art(app.session,p),"Actual art starts: w%d"%weapon)
				art_windup=float(p.build_pending_art.remaining)
				check(CharacterFrames.ranged_pose_frame(p)==1 if Catalog.weapon_family(weapon)==0 else CharacterFrames.attack_pose_frame(p)==1,"Actual art aiming pose: w%d"%weapon)
				p.swing_time=p.swing_total-art_windup; p.cast_time=p.swing_time; p.build_pending_art.remaining=0
				Actions.tick(app.session,p,0.0)
				check(CharacterFrames.ranged_pose_frame(p)==2 if Catalog.weapon_family(weapon)==0 else CharacterFrames.attack_pose_frame(p)==2,"Actual art contact pose: w%d"%weapon)
				app.session.bullets.clear(); p.erase("build_pending_art_tail")
			for stage in 4:
				p.erase("build_strike_windup")
				for hero in 4:
					p.hero=hero; p.swing_total=1.5; p.swing_time=1.5-float(spec.windup)-.03; p.cast_time=0.0
					if stage==3 and mode=="roguelike": p["build_strike_windup"]=art_windup; p.swing_total=art_windup+.12; p.swing_time=.10
					for direction in 8:
						var item: Dictionary=batch[hero*8+direction]
						var fx=item.fx
						fx.show(); item.flights.hide(); item.flights.spell_light.hide()
						p.strike_aim=Vector2.from_angle(direction*PI/4); p.aim=p.strike_aim
						var socket: Dictionary=field.weapon_effect_socket(1)
						item.label="%s w%d h%d d%d stage%d"%[mode,weapon,hero,direction,stage]
						check(socket.tip.is_finite() and socket.tip.distance_to(socket.stroke_tip)<.001,"Real blade endpoint: "+item.label)
						check(socket.aim.dot(projection.basis_xform(p.strike_aim).normalized())>.9999,"Projected direction: "+item.label)
						fx.reset(); fx.transform=projection
						var socket_copy := socket.duplicate(); socket_copy.tip=Vector2(140,140); socket_copy.stroke_tip=socket_copy.tip
						fx.socket_provider=func(_id): return socket_copy
						var body: Vector2=projection.affine_inverse()*(Vector2(140,140)-(socket.tip-projection*p.p))
						var data := {"kind":"strike","p":body,"aim":p.strike_aim,"weapon":Catalog.weapon_family(weapon),"weapon_index":weapon,"reach":spec.reach,"pattern":spec.get("pattern",""),"combo":mini(stage,2),"id":1}
						if stage==3: data["attack_kind"]=move.kind; data.reach=move.reach
						fx.event(data,hero); fx.particles.reset(); fx.shards.clear()
						item.contact=fx.effects[0].art_role.begins_with("motion_") and not M.body_centered(fx.effects[0].art_role)
						check(fx.effects[0].identity.weapon==weapon,"Concrete weapon: "+item.label)
						for effect in fx.effects:
							if effect.has("socket_local"): check((projection*effect.socket_local).distance_to(Vector2(140,140))<.001,"Captured socket: "+item.label)
						cases+=1
				for step in [.03,.05,.06]:
					for item in batch: item.fx.advance(step)
					await process_frame; await process_frame; RenderingServer.force_draw(false)
					for item in batch:
						var img: Image=item.viewport.get_texture().get_image()
						check(img.get_used_rect().has_area(),"Visible effect: "+item.label)
						if item.contact:
							var alpha := 0.0
							for y in range(138,143):
								for x in range(138,143): alpha=maxf(alpha,img.get_pixel(x,y).a)
							check(alpha>.15,"Actual contact pixel: "+item.label)
			if Catalog.weapon_family(weapon) in [0,3]:
				var spells := []
				if spec.get("spell","star")!="prism": spells.append(str(spec.get("spell","star")))
				if move.kind=="volley": spells.append(str(move.get("spell","star")))
				for spell in spells:
					for index in batch.size():
						var item: Dictionary=batch[index]
						item.fx.hide(); item.flights.show(); item.flights.spell_light.show()
						var flights=item.flights
						flights.transform=projection
						var at: Vector2=projection.affine_inverse()*Vector2(140,140)
						var aim := Vector2.from_angle((index%8)*PI/4)
						flights.field.camera=at
						flights.bullets=[{"p":at,"v":aim*700,"weapon_index":weapon,"owner":1,"spell":spell,"height":0}]
						flights.queue_redraw(); flights.spell_light.queue_redraw()
						item.direction=projection.basis_xform(aim).normalized()
						item.role=M.projectile_role(weapon,spell)
					await process_frame; await process_frame; RenderingServer.force_draw(false)
					for item in batch:
						var img: Image=item.viewport.get_texture().get_image()
						check(img.get_used_rect().has_area(),"Actual projectile visible: w%d %s"%[weapon,item.role])
						if item.role in ["projectile_arrow","projectile_bullet","projectile_needle","projectile_eclipse"]:
							var along := 0.0
							var across := 0.0
							for y in range(90,191,2):
								for x in range(90,191,2):
									var alpha := img.get_pixel(x,y).a
									var delta := Vector2(x+.5,y+.5)-Vector2(140,140)
									along+=pow(delta.dot(item.direction),2)*alpha
									across+=pow(delta.cross(item.direction),2)*alpha
							if along<=across*3:
								print("FLIGHT AXIS ",mode," w",weapon," ",item.role," along=",along," across=",across)
								img.save_png("res://build/flight-axis-%s-%d.png"%[mode,weapon])
							check(along>across*3,"Projectile axis follows projected velocity: w%d %s"%[weapon,item.role])
						flight_cases+=1
			print("FULL MATRIX ",mode," weapon ",weapon," checked")
	for item in batch: item.viewport.queue_free()
	app.queue_free(); await process_frame
	print("FULL WEAPON MATRIX ",cases," release cases + ",flight_cases," flight cases, ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
