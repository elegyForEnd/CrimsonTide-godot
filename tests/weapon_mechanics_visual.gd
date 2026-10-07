extends SceneTree
const FX=preload("res://scripts/stylized_vfx.gd")
class DummyField extends Node2D:
	var camera := Vector2.ZERO
class ProjectileRenderer extends CombatVisuals:
	var bullet := {"p":Vector2(210,210),"v":Vector2.RIGHT*700,"weapon_index":625,"owner":1,"spell":"arrow","height":0}
	func _process(_dt: float) -> void: pass
	func draw_spells() -> void: pass
	func _draw() -> void: draw_run_projectile(self,bullet,false)
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func capture(viewport: SubViewport) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func visible_bounds(img: Image) -> Rect2i:
	var first := Vector2i(img.get_width(),img.get_height())
	var last := Vector2i(-1,-1)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x,y).a>.08:
				first=first.min(Vector2i(x,y)); last=last.max(Vector2i(x,y))
	return Rect2i(first,last-first+Vector2i.ONE)
func bright_pixels(img: Image) -> int:
	var count := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x,y)
			if c.a>.2 and c.r>.8: count+=1
	return count
func run() -> void:
	var viewport := SubViewport.new(); viewport.size=Vector2i(420,420); viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var field := DummyField.new(); viewport.add_child(field)
	var projectile := ProjectileRenderer.new(); projectile.field=field; viewport.add_child(projectile)
	for pair in [[625,"arrow"],[626,"arrow"],[638,"needle"],[637,"meteor"],[640,"moon"],[642,"scatter"],[644,"eclipse"]]:
		projectile.bullet.weapon_index=pair[0]; projectile.bullet.spell=pair[1]; projectile.queue_redraw()
		var img: Image=await capture(viewport)
		var bounds := img.get_used_rect()
		check(bounds.has_area(),"Actual projectile draws visible pixels")
		if int(pair[0]) in [625,626,638,644]: check(bounds.size.x>bounds.size.y*3,"Arrow, needle and lance remain narrow in actual flight renderer")
		if int(pair[0]) in [625,626,638]: check(visible_bounds(img).size.y>=6,"Flying arrows and needles have a readable thick body")
		if int(pair[0])==640: check(bounds.size.y>bounds.size.x,"Moon blade remains an upright crescent in flight")
		check(bounds.size.x<100 and bounds.size.y<70,"One projectile never becomes a broad wave")
	projectile.queue_free(); await process_frame
	var fx := FX.new(); viewport.add_child(fx)
	fx.socket_provider=func(_id): return {"tip":Vector2(330,210),"aim":Vector2.RIGHT,"active":true}
	fx.event({"kind":"strike","p":Vector2(210,210),"aim":Vector2.RIGHT,"weapon":1,"weapon_index":602,"reach":75,"combo":0,"id":1})
	fx.particles.reset(); fx.shards.clear(); fx.advance(.05)
	var img: Image=await capture(viewport)
	check(visible_bounds(img).get_center().distance_to(Vector2(210,210))<8,"Ring surrounds body center even when weapon tip is far away")
	check(img.get_pixel(210,210).a<.05,"Circular swing has an empty center, never a filled impact disc")
	fx.reset()
	fx.event({"kind":"strike","p":Vector2(210,210),"aim":Vector2.RIGHT,"weapon":1,"weapon_index":602,"reach":75,"combo":0,"id":1,"height":60})
	fx.particles.reset(); fx.shards.clear(); fx.advance(.05)
	img=await capture(viewport)
	check(visible_bounds(img).get_center().distance_to(Vector2(210,150))<8,"Airborne circle rises with actual player height")
	fx.reset()
	fx.event({"kind":"strike","p":Vector2(210,210),"aim":Vector2.RIGHT,"weapon":1,"weapon_index":600,"reach":80,"combo":0,"id":1})
	fx.particles.reset(); fx.shards.clear(); fx.advance(.12)
	img=await capture(viewport)
	var bright := bright_pixels(img)
	check(bright>50,"Slash keeps a strong visible red core through its contact frame")
	# Same captured attack and frame: only turn off body expansion for comparison.
	fx.material.set_shader_parameter("stroke_pixels",0.0)
	var thin: Image=await capture(viewport)
	check(bright>bright_pixels(thin)*1.35,"Thicker slash has at least 35 percent more bright body pixels than the thin stroke")
	fx.material.set_shader_parameter("stroke_pixels",1.8)
	fx.reset()
	fx.event({"kind":"spell_burst","p":Vector2(110,300),"aim":Vector2.RIGHT,"weapon_index":637,"spell":"meteor","radius":60,"id":1})
	fx.particles.reset(); fx.shards.clear(); fx.advance(.07)
	img=await capture(viewport)
	check(img.get_used_rect().get_center().distance_to(Vector2(110,300))<10,"Meteor explosion appears at captured target, not weapon tip")
	fx.reset()
	fx.event({"kind":"spell_beam","p":Vector2(100,210),"aim":Vector2.RIGHT,"weapon_index":641,"spell":"prism","reach":250,"width":24,"id":1})
	fx.particles.reset(); fx.shards.clear(); fx.advance(.07)
	img=await capture(viewport)
	var before := img.get_used_rect()
	fx.position=Vector2(18,12); fx.queue_redraw(); fx.light.queue_redraw()
	img=await capture(viewport)
	check((img.get_used_rect().position-before.position).distance_to(Vector2(18,12))<2,"Both beam endpoints remain in captured world space when camera transform changes")
	viewport.queue_free(); await process_frame; await process_frame
	print("WEAPON MECHANICS VISUAL ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
