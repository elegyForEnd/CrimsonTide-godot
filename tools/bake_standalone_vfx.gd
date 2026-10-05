extends SceneTree
## Run after build_standalone_vfx.py; uses Godot's own SVG rasterizer.
func _initialize() -> void:
	var base := "res://assets/combat/standalone/"
	var directory := DirAccess.open(base+"sources")
	var count := 0
	for file in directory.get_files():
		if not file.ends_with(".svg"): continue
		var image := Image.new()
		var error := image.load_svg_from_string(FileAccess.get_file_as_string(base+"sources/"+file))
		if error!=OK: quit(1); return
		image.save_png(base+file.get_basename()+".png")
		count+=1
	# Historical boss animation frames remain separate full-resolution files.
	for key in ["bell","thorn","queen","knight"]:
		var image := Image.load_from_file("res://assets/bosses/vfx/"+key+".png")
		var size := image.get_size()/4
		for cell in 16:
			image.get_region(Rect2i(Vector2i(cell%4,cell/4)*size+Vector2i.ONE,size-Vector2i(2,2))).save_png(base+"boss_%s_%02d.png" % [key,cell])
	# Preserve the hand-painted necromancer flame animation, one PNG per frame.
	var fire := Image.load_from_file("res://assets/combat/muyu-flames.png")
	var cell_size := Vector2i(fire.get_width()/5,fire.get_height())
	for cell in 5:
		fire.get_region(Rect2i(Vector2i(cell*cell_size.x,0)+Vector2i(3,3),cell_size-Vector2i(6,6))).save_png(base+"soul_fire_%d.png" % cell)
	print("BAKED ",count," original effects + 64 boss frames + 5 soul fire frames")
	quit()
