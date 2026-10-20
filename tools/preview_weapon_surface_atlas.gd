extends SceneTree
## Presentation of unchanged originals for visual QA; no source pixels edited.
const Art=preload("res://scripts/weapon_image_art.gd")
const OUT="res://build/vfx-3d/"
class Board extends Node2D:
	var entries: Array=[]
	var page := 0
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,1500),Color("0c1420"))
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(20,35),"逐把武器专属原图 · %d / 2 · 原始 PNG 保留透明度" % (page+1),HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("e1edf5"))
		for i in entries.size():
			var entry: Dictionary=entries[i]
			var at := Vector2((i%4)*360,58+(i/4)*200)
			draw_rect(Rect2(at+Vector2(8,8),Vector2(344,184)),Color("152131"))
			var ink: Rect2=entry.ink
			var box := Vector2(324,132)
			var factor := minf(box.x/ink.size.x,box.y/ink.size.y)
			var size := ink.size*factor
			draw_texture_rect_region(entry.texture,Rect2(at+Vector2(18,18)+(box-size)*.5,size),ink)
			draw_string(font,at+Vector2(18,174),"%d · %s" % [entry.weapon,entry.name],HORIZONTAL_ALIGNMENT_LEFT,324,19,Color("dce9ef"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,1500); root.content_scale_size=root.size
	var weapons: Array=range(600,648)+range(17,21)
	for page in 2:
		var board := Board.new(); board.page=page
		for weapon in weapons.slice(page*28,mini((page+1)*28,weapons.size())):
			var source := "weapon_%d_surface_v5" % weapon
			board.entries.append({"weapon":weapon,"name":Catalog.weapon(weapon).name,"texture":Art.mechanic_texture(source),"ink":Art.mechanic_ink(source)})
		root.add_child(board)
		for frame in 3: await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"weapon-surface-atlas-%d.png" % page)
		board.queue_free(); await process_frame
	quit()
