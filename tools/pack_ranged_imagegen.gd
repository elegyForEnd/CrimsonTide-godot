extends SceneTree
## Cut the generated atlases at transparent gutters and register planted feet.
const ROOT := "res://assets/combat/ranged-imagegen/"
func gutter(im: Image, expected: int, radius: int, horizontal: bool, start: int, end: int) -> int:
	var best := expected
	var score := INF
	for axis in range(maxi(1,expected-radius),mini((im.get_height() if horizontal else im.get_width())-1,expected+radius)):
		var count := 0
		for cross_axis in range(start,end):
			var pixel := im.get_pixel(cross_axis,axis) if horizontal else im.get_pixel(axis,cross_axis)
			if pixel.a>.15: count+=1
		var candidate := count*1000.0+absf(axis-expected)
		if candidate<score: score=candidate; best=axis
	return best
func _initialize() -> void:
	var manifest := {}
	for action in ["bow","rifle"]:
		var source := Image.load_from_file(ROOT+action+("-v2.png" if action=="bow" else "-v1.png"))
		var ys := [0]
		for row in range(1,4): ys.append(gutter(source,source.get_height()*row/4,42,true,0,source.get_width()))
		ys.append(source.get_height())
		for hero in 4:
			var isolated: bool=hero==3 and action=="bow"
			var input := Image.load_from_file(ROOT+"muyu-bow-v1.png") if isolated else source
			var xs := [0]
			for col in range(1,4): xs.append(gutter(source,source.get_width()*col/4,72,false,ys[hero],ys[hero+1]))
			xs.append(source.get_width())
			var images: Array[Image]=[]
			var anchors: Array[Vector2i]=[]
			var origins: Array=[]
			var union := Rect2i()
			for col in 4:
				var cell := Rect2i(xs[col],ys[hero],xs[col+1]-xs[col],ys[hero+1]-ys[hero])
				if isolated: cell=Rect2i((col%2)*input.get_width()/2,(col/2)*input.get_height()/2,input.get_width()/2,input.get_height()/2)
				origins.append([cell.position.x,cell.position.y])
				var im := input.get_region(cell)
				var box := im.get_used_rect()
				var sole := box.end.y
				var left := im.get_width()
				var right := 0
				for y in range(maxi(0,sole-12),sole):
					for x in im.get_width():
						if im.get_pixel(x,y).a>.5: left=mini(left,x); right=maxi(right,x)
				var anchor := Vector2i((left+right)/2,sole)
				images.append(im); anchors.append(anchor)
				var relative := Rect2i(box.position-anchor,box.size)
				union=relative if col==0 else union.merge(relative)
			union=union.grow(20)
			var pivot := -union.position
			# Crown excludes the tall bow; measurements are audited on opening art.
			var crowns: Array=[70,338,589,850] if action=="bow" else [32,291,550,804]
			var standing := float(anchors[0].y+ys[hero]-int(crowns[hero]))
			if isolated: standing=float(anchors[0].y-96)
			var scale := 90.0/standing
			var directory: String=ROOT+"hero-%d/" % hero+action
			DirAccess.make_dir_recursive_absolute(directory)
			for col in 4:
				var canvas := Image.create(union.size.x,union.size.y,false,Image.FORMAT_RGBA8)
				canvas.blit_rect(images[col],Rect2i(Vector2i.ZERO,images[col].get_size()),pivot-anchors[col])
				canvas.save_png(directory+"/%03d.png" % col)
			var spec := {"path":directory,"frame_count":4,"pivot":[pivot.x,pivot.y],"standing_height":90.0,"rect":[-pivot.x*scale,16-pivot.y*scale,union.size.x*scale,union.size.y*scale],"source_rows":ys,"source_columns":xs,"source_origins":origins,"source_anchors":anchors.map(func(a): return [a.x,a.y])}
			if isolated: spec["source_sockets"]=[[615,193],[1290,190],[650,701],[1284,756]]
			manifest["heroes/hero-%d/%s" % [hero,action]]=spec
	var file := FileAccess.open(ROOT+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	print("Packed 8 ranged animations / 32 registered frames")
	quit()
