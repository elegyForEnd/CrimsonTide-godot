extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := TideSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.solo({"hero":0})
	session.launch(false,1729)
	session.enemies.clear()
	session.ruins.walls.clear()
	var p: Dictionary=session.players[1]
	var origin := Vector2(1200,1100)
	p.p=origin
	session.move_player(p,Vector2.RIGHT,false,0.1,220)
	check(p.motion=="walk" and is_equal_approx(p.p.x-origin.x,22.0),"Walk uses base speed")
	p.p=origin
	session.move_player(p,Vector2(1,1),true,0.1,220)
	check(p.motion=="run" and is_equal_approx(p.p.distance_to(origin),31.9),"Sprint uses capped diagonal speed")
	session.move_player(p,Vector2.ZERO,true,0.1,220)
	check(p.motion=="idle","Shift alone cannot play a running cycle")
	p.p=origin
	session.inputs[1]={"move":Vector2.RIGHT}
	session.attack(p)
	check(p.pending_strike,"Attack starts with windup")
	session.perform(1,"dash")
	check(p.p==origin and p.dodge_time>0,"Dodge is continuous, not instantaneous teleport")
	check(not p.pending_strike and p.swing_time==0,"Dodge cancels pending attack")
	var old_weapon: int=p.weapon
	session.perform(1,"weapon",{"index":3})
	check(p.weapon==old_weapon and Catalog.is_starter(old_weapon),"The removed weapon hotkey leaves the issue weapon in hand")
	for i in 12:
		session.move_player(p,Vector2.LEFT,true,0.02,220)
	check(is_equal_approx(p.p.x-origin.x,145.0),"Dodge covers exactly 145 pixels and ignores movement reversal")
	check(p.dodge_time<=0.00001,"Dodge ends after 240ms")
	p.p=origin
	p.dash=0.0
	session.ruins.walls.append(Rect2(1260,1020,18,160))
	session.perform(1,"dash")
	session.move_player(p,Vector2.ZERO,false,0.5,220)
	check(p.p.x<1246 and p.p.x>origin.x,"Dodge cannot tunnel through a wall even on a long frame")
	p.dash=0.0
	session.perform(1,"dash")
	session.down(p)
	check(p.dodge_time==0 and p.motion=="idle","Downing ends locomotion")
	var library := CharacterFrames.new()
	for sheets in [library.attacks,library.movement]:
		for sheet in sheets:
			for row in sheet:
				for pose in row:
					var texture: AtlasTexture=pose.texture
					var pixels := texture.get_image()
					var border_clear := true
					for x in pixels.get_width():
						border_clear=border_clear and pixels.get_pixel(x,0).a<0.08 and pixels.get_pixel(x,pixels.get_height()-1).a<0.08
					for y in pixels.get_height():
						border_clear=border_clear and pixels.get_pixel(0,y).a<0.08 and pixels.get_pixel(pixels.get_width()-1,y).a<0.08
					check(border_clear,"Every animation frame has transparent isolation borders: "+str(texture.region))
	print("MOVEMENT / FRAME TESTS: %d checks, %d failures" % [checks,failures])
	session.queue_free()
	quit(1 if failures else 0)
