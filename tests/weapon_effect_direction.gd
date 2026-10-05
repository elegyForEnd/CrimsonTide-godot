extends SceneTree
const Library = preload("res://scripts/vfx_library.gd")
const FX = preload("res://scripts/stylized_vfx.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	for i in 21:
		var key := Library.weapon_key(i)
		var fit := Library.fitted_size(key,Vector2(210,90))
		var native := Library.texture(key).get_size()
		check(absf(fit.x/native.x-fit.y/native.y)<.000001,"No stretched weapon effect")
		check(Library.facing_scale(key)==Library.facing_scale(Library.weapon_key(i,"finisher")),"Same source direction across combo phases")
	for cell in 8:
		check(Library.facing_scale("spell_%d"%cell)==Library.facing_scale(Library.weapon_key(Library.SPELL_WEAPONS[cell])),"Spell projectile shares source correction")
	var viewport := SubViewport.new()
	viewport.size=Vector2i(400,400)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var fx := FX.new()
	viewport.add_child(fx)
	for weapon in [1,2,7,14,17,19]:
		for combo in 3:
			for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
				fx.reset()
				fx.current_texture=Library.weapon_key(weapon)
				fx.emit("slash",Vector2(200,200),direction,Color.WHITE,110,.3,-1 if combo==1 else 1)
				fx.advance(.07)
				await process_frame
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				var forward := 0.0
				var back := 0.0
				for y in range(65,336,3):
					for x in range(65,336,3):
						var dot := (Vector2(x+.5,y+.5)-Vector2(200,200)).dot(direction)
						var alpha := image.get_pixel(x,y).a
						if dot>0: forward+=alpha
						else: back+=alpha
				check(forward>back*1.15,"Blade faces attack: weapon %d combo %d direction %s" % [weapon,combo,direction])
	viewport.queue_free()
	await process_frame
	print("WEAPON DIRECTION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
