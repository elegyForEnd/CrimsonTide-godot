extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1920,1080)
	var canvas:=CanvasLayer.new(); root.add_child(canvas)
	var ui:=Control.new(); ui.size=Vector2(1440,900); canvas.add_child(ui)
	var screen=preload("res://scripts/story_screen.gd").new(); ui.add_child(screen)
	var c=screen.campaign
	c.state=c.new_state(); c.save_enabled=false; c.inventory.initialize(); screen.set_active(true)
	c.state.zone="1:1"; c.state.stage=1; c.state.pending={}; c.hero_at=c.spawn_at()
	screen.world.build()
	for i in 3: await process_frame
	screen.set_process(false); screen.set_physics_process(false)
	var fx=screen.world.combat_fx
	var original=screen.world.original
	var native: Vector2=c.terrain().native(c.hero_at)
	var layouts: Array=[Transform2D.IDENTITY,Transform2D(0,Vector2(1.2,1.2),0,Vector2(96,0)),Transform2D(0,Vector2(.85,.85),0,Vector2(210,90))]
	for layout in layouts:
		ui.scale=layout.get_scale(); ui.position=layout.origin
		for zoom in [11.0,15.0,21.0]:
			screen.world.zoom=zoom; screen.world.sync(0)
			for point in [native,native+Vector2(100,0),native+Vector2(0,100)]:
				var actual: Vector2=fx.get_global_transform_with_canvas()*fx.screen.project(point)
				check(actual.distance_to(original.project(point))<.01,"ground projection crosses UI boundary once")
			for weapon in [600,601,612,615,625,638,641]:
				var hero:=1 if Catalog.weapon_family(weapon)==3 else 2 if Catalog.weapon_family(weapon)==0 else 0
				c.state.hero=hero
				var item: Dictionary=c.inventory.make(["sword","staff","dagger"][hero],1,0)
				item.weapon_index=weapon; c.state.equipment[hero].blade=item
				c.action_weapon=weapon; c.action_total=float(Catalog.weapon(weapon).rate)
				c.action_windup=float(Catalog.weapon(weapon).windup); c.action_time=c.action_total-c.action_windup
				for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
					c.facing=direction; screen.world.sync(0); fx.reset()
					var expected: Dictionary=original.weapon_effect_socket(hero)
					var local: Dictionary=fx.screen.weapon_effect_socket(hero)
					for key in ["tip","grip","stroke_tip","stroke_pivot"]:
						var actual: Vector2=fx.get_global_transform_with_canvas()*Vector2(local[key])
						check(actual.distance_to(Vector2(expected[key]))<.01,"weapon socket matches viewport at every UI scale/zoom/direction")
					c.combat_event.emit({"kind":"attack","hero":hero,"p":c.hero_at,"direction":direction,"radius":float(Catalog.weapon(weapon).reach)*c.terrain().speed_scale(),"special":0,"weapon_index":weapon})
					var anchored:=false
					for effect in fx.primary.effects:
						if effect.has("socket_local"):
							var actual: Vector2=fx.primary.get_global_transform_with_canvas()*Vector2(effect.socket_local)
							check(actual.distance_to(Vector2(expected.stroke_tip))<.02,"released slash stays on captured weapon mount")
							anchored=true; break
					check(anchored,"shared effect captures actual mount")
					if layout.origin==Vector2(96,0) and zoom==15 and direction==Vector2.RIGHT and weapon in [600,615]:
						screen.world.sync(.06)
						for i in 2: await process_frame
						if DisplayServer.get_name()!="headless":
							RenderingServer.force_draw(false)
							root.get_texture().get_image().save_png("res://output/scarlet-aligned-%d.png" % weapon)
	ui.queue_free(); await process_frame
	print("SCARLET_VFX_ALIGNMENT %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
