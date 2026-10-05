extends SceneTree
const Motion=preload("res://scripts/effect_motion.gd")
const Renderer=preload("res://scripts/boss_damage_visual.gd")
const Geometry=preload("res://scripts/boss_geometry.gd")
const Combat=preload("res://scripts/rogue_combat.gd")
var checks := 0
var failures := 0
class Board extends Node2D:
	var texture: Texture2D
	var coverage := 1.0
	var form := "center"
	func _draw() -> void:
		if texture: Motion.draw(self,texture,Rect2(10,10,180,180),coverage,form,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	for weapon in 21:
		for kind in ["slash","spin","lance","cast","charge","eruption","dash","impact"]:
			var profile := Motion.profile("weapon_%02d_release"%weapon,kind)
			check(Motion.coverage(0,.3,profile.birth)==0,"No first-frame complete stamp")
			check(Motion.coverage(.15,.3,profile.birth)>.999,"Full original silhouette reaches apex")
			check(Motion.coverage(.02,.3,profile.birth)<=Motion.coverage(.05,.3,profile.birth),"Birth progresses without flicker")
	var combat=Combat.new()
	for floor_index in 5:
		for shape in ["line","cone","ring","circle","cyclone"]:
			var fx={"source":1,"floor":floor_index,"shape":shape,"p":Vector2(37,23),"end":Vector2(225,97),"direction":Vector2.from_angle(.37),"radius":80.0,"inner":45.0,"age":.1,"delay":.2,"windup":.5,"total":.7,"active":false}
			var h := Renderer.minion_hazard(fx)
			check(h.time==fx.delay and h.fired==false,"Minion anticipation uses host delay")
			for x in range(-150,350,13):
				for y in range(-150,250,13):
					var point := Vector2(x+.123,y+.321)
					check(combat.contains(fx,point)==Geometry.contains(h,point),"Minion visual mask includes exact old collision padding: "+shape)
			fx.active=true
			check(Renderer.minion_hazard(fx).time==-fx.age,"Active effect clock follows authoritative age")
	var viewport := SubViewport.new()
	viewport.size=Vector2i(200,200); viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board=Board.new(); viewport.add_child(board)
	for weapon in 21:
		board.texture=Motion.Library.texture("weapon_%02d_release"%weapon)
		board.form=Motion.profile("weapon_%02d_release"%weapon,"cast").form
		var masses: Array=[]
		for coverage in [.0,.35,1.0]:
			board.coverage=coverage; board.queue_redraw()
			await process_frame; await RenderingServer.frame_post_draw
			var im=viewport.get_texture().get_image()
			var mass := 0.0
			for y in range(0,200,2):
				for x in range(0,200,2): mass+=im.get_pixel(x,y).a
			masses.append(mass)
		check(masses[0]<.001 and masses[2]>1.0,"Native artwork actually appears at apex for weapon%d"%weapon)
		check(masses[1]<=masses[2]+.01,"Birth reveals coverage without stretching weapon%d"%weapon)
	viewport.queue_free(); await process_frame
	print("ALL EFFECT STAGING ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
