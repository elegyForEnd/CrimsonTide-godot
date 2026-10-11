extends SceneTree
const Finish=preload("res://scripts/combat_finish.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
var checks := 0
var failures := 0
class Reveal extends Node2D:
	var amount := 1.0
	var original := false
	func _draw() -> void:
		draw_set_transform(Vector2(150,150))
		if original: Art.stamp_mechanic(self,"motion_slash",Vector2(220,220),Color.WHITE)
		else: Art.reveal_mechanic(self,"motion_slash",Vector2(220,220),Color.WHITE,amount,"sweep")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func pixels(vp: SubViewport) -> Image:
	await process_frame; RenderingServer.force_draw(false)
	return vp.get_texture().get_image()
func run() -> void:
	var vp := SubViewport.new(); vp.size=Vector2i(300,300); vp.transparent_bg=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var reveal := Reveal.new(); vp.add_child(reveal)
	reveal.amount=0; reveal.queue_redraw()
	var im: Image=await pixels(vp)
	check(not im.get_used_rect().has_area(),"No complete full-image stamp at birth")
	reveal.amount=.35; reveal.queue_redraw(); var partial: Image=await pixels(vp)
	reveal.amount=1.0; reveal.queue_redraw(); var full: Image=await pixels(vp)
	check(partial.get_used_rect().has_area() and partial.get_data()!=full.get_data(),"Birth actually reveals different pixels")
	reveal.original=true; reveal.queue_redraw(); var original: Image=await pixels(vp)
	check(full.get_data()==original.get_data(),"Apex preserves exact original aspect, UV and contact pixels")
	reveal.hide()
	var fx=FX.new(); vp.add_child(fx)
	# Actual renderer pixels must be independent of weapon sprite length.
	var socket := {"tip":Vector2(160,150),"grip":Vector2(150,150),"aim":Vector2.RIGHT,"active":true}
	fx.socket_provider=func(_id): return socket
	var event := {"kind":"strike","p":Vector2(150,150),"aim":Vector2.RIGHT,"id":1,"weapon":1,"weapon_index":602,"reach":65.0,"attack_kind":"circle"}
	fx.event(event); fx.particles.reset(); fx.shards.clear(); fx.advance(.08)
	var small: Image=await pixels(vp)
	fx.reset(); socket.tip=Vector2(390,150); fx.event(event); fx.particles.reset(); fx.shards.clear(); fx.advance(.08)
	var large: Image=await pixels(vp)
	check(small.get_data()==large.get_data(),"Circular visual cannot grow or move with sprite blade length")
	fx.hide()
	var finish=Finish.new(); vp.add_child(finish)
	for weapon in [0,1,5,4,20,15]:
		finish.reset()
		finish.event({"kind":"impact","p":Vector2(150,180),"contact_p":Vector2(150,140),"aim":Vector2.RIGHT,"weapon_index":weapon,"damage":20,"heavy":true})
		finish.advance(.04); var hit: Image=await pixels(vp)
		check(hit.get_used_rect().has_area(),"Material-specific real contact visible: "+str(weapon))
		finish.advance(.17); var residue: Image=await pixels(vp)
		check(residue.get_used_rect().has_area() and hit.get_data()!=residue.get_data(),"Impact changes into moving residue rather than fixed fading stamp")
		finish.advance(1); var expired: Image=await pixels(vp)
		check(not expired.get_used_rect().has_area(),"Dust and splinters disappear without permanent decals")
	var orphan_count := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var flights=preload("res://tests/weapon_full_visual_audit.gd").Flights.new(); vp.add_child(flights)
	flights.queue_free(); await process_frame; await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==orphan_count,"Custom projectile preview leaves no newly allocated unowned finish layer")
	vp.queue_free(); await process_frame; await process_frame
	print("COMBAT FINISH VISUAL RULES ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
