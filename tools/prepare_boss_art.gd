extends SceneTree
# Import-stage packing only: preserve generated pixels/alpha, crop poses and
# resize them uniformly into 512px cells with a common foot anchor.
func _initialize() -> void:
	var path := "res://assets/bosses/atlas-layout.json"
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for key in manifest:
		var entry: Dictionary=manifest[key]
		var source := Image.load_from_file(entry.source)
		var frames: Array[Image]=[]
		var max_width := 0
		var max_height := 0
		for box in entry.boxes:
			var frame := source.get_region(Rect2i(box[0],box[1],box[2],box[3]))
			frames.append(frame)
			max_width=maxi(max_width,frame.get_width())
			max_height=maxi(max_height,frame.get_height())
		var factor := minf(472.0/max_width,420.0/max_height)
		var atlas := Image.create(2048,1536,false,Image.FORMAT_RGBA8)
		for i in frames.size():
			var frame := frames[i]
			frame.resize(maxi(1,roundi(frame.get_width()*factor)),maxi(1,roundi(frame.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
			var dest := Vector2i((i%4)*512+(512-frame.get_width())/2,(i/4)*512+460-frame.get_height())
			atlas.blit_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),dest)
		atlas.save_png("res://assets/bosses/"+key+"-atlas.png")
		entry.packed_height=max_height*factor
		print(key," packed ",frames.size()," frames; height ",entry.packed_height)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	quit()
