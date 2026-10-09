extends SceneTree
const Art=preload("res://scripts/weapon_image_art.gd")
class Gallery extends Node2D:
	var first := 600
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,2000,1500),Color("142031"))
		for i in 12:
			var id := first+i
			var at := Vector2((i%4)*500,(i/4)*500)
			draw_rect(Rect2(at+Vector2(12,12),Vector2(476,476)),Color("1d2b3c"))
			draw_string(font,at+Vector2(26,48),"%d · %s" % [id,Catalog.weapon(id).name],HORIZONTAL_ALIGNMENT_LEFT,450,23,Color.WHITE)
			var source := "charged_%d_v1" % id
			Art.load_mechanic_manifest()
			if not Art.mechanics.has(source): continue
			draw_set_transform(at+Vector2(250,265))
			Art.stamp_mechanic(self,source,Vector2(426,356),Color.WHITE)
			draw_set_transform(Vector2.ZERO)
			var entry: Dictionary=Art.mechanics[source]
			var description: String={"release":"蓄力斩击","projectile":"蓄力弹体","beam":"蓄力光束","burst":"蓄力爆发"}.get(entry.payload,entry.payload)
			if str(entry.get("style","")).begins_with("clean"): description+=" · 连续干净轮廓"
			draw_string(font,at+Vector2(26,470),description,HORIZONTAL_ALIGNMENT_LEFT,450,20,Color("c1ccd8"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/weapon-charged-audit/")
	root.size=Vector2i(2000,1500); root.content_scale_size=root.size
	var pages: Array=range(4)
	var args := OS.get_cmdline_user_args()
	if args.size()>0: pages=[int(args[0])]
	for page in pages:
		var gallery := Gallery.new(); gallery.first=600+page*12; root.add_child(gallery)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/weapon-charged-audit/originals-%d.png" % page)
		gallery.queue_free(); await process_frame
	print("CHARGED ORIGINAL GALLERIES saved"); quit()
