extends SceneTree

const HEAVY_4K := ["grave-gargoyle","drowned-bell-wraith","lantern-executioner","moon-monolith-colossus","sunken-bell-carcass","blood-coffin-warden"]

func _initialize() -> void:
	var files := ["crystal-hare-nocturne","moonbell-spirit-nocturne","rose-armiger-nocturne","redmoon-fox-nocturne","windbell-moth-nocturne","archive-owl-nocturne","mooncrystal-stag-nocturne","thorn-bloom-nocturne","mist-jelly-nocturne","royal-griffin-nocturne","grave-gargoyle","drowned-bell-wraith","lantern-executioner","moon-monolith-colossus","sunken-bell-carcass","blood-coffin-warden"]
	for file in files:
		var generated_4k: String="res://output/imagegen/nocturne-heavy-4k/"+file+"-4k.png"
		var source_path: String=generated_4k if file in HEAVY_4K and FileAccess.file_exists(generated_4k) else "res://output/imagegen/"+file+"-raw.png"
		var source := Image.load_from_file(source_path)
		assert(source!=null and not source.is_empty())
		source.convert(Image.FORMAT_RGBA8)
		if file in HEAVY_4K:
			# This compatible image endpoint paints a light checkerboard when asked
			# for transparency. Clear only the bright neutral region connected to the
			# outer canvas, so pale stone, bone and metal inside the silhouettes stay.
			clear_checker_backdrop(source)
			# The provider's 4:3 high-resolution tier returns 3264x2448 even when
			# 4096x3072 is requested. Preserve the generated detail, then normalize
			# the transparent production master to an exact 4K 4:3 grid (1024/cell).
			if source.get_size()!=Vector2i(4096,3072):
				source.resize(4096,3072,Image.INTERPOLATE_LANCZOS)
			assert(source.save_png("res://output/imagegen/"+file+"-raw.png")==OK)
		var cells: Array[Image]=[]
		var scale_factor := 1.0
		for frame in 12:
			var x := frame%4
			var y := frame/4
			var start := Vector2i(x*source.get_width()/4,y*source.get_height()/3)
			var end := Vector2i((x+1)*source.get_width()/4,(y+1)*source.get_height()/3)
			var cell := source.get_region(Rect2i(start,end-start))
			# Image generators occasionally let a neighbouring pose cross the implied
			# grid line.  Those fragments become a second sprite after slicing (for
			# example the purple crescent to the left of the colossus).  Remove only
			# disconnected components which touch the crop edge; the main connected
			# creature/effect is preserved even when it reaches an edge.
			remove_neighbour_spill(cell)
			var bounds := cell.get_used_rect()
			assert(bounds.has_area(),"Empty frame: "+file)
			cell=cell.get_region(bounds)
			cells.append(cell)
			# Keep all slash light and particles, then scale the complete cell content
			# into a 176 px safe box. This guarantees 40 px horizontal gutters.
			scale_factor=minf(scale_factor,minf(176.0/cell.get_width(),176.0/cell.get_height()))
		var atlas := Image.create(1024,768,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for frame in 12:
			var cell := cells[frame]
			cell.resize(maxi(1,roundi(cell.get_width()*scale_factor)),maxi(1,roundi(cell.get_height()*scale_factor)),Image.INTERPOLATE_LANCZOS)
			# Lanczos can leave a fully transparent row around the resized content.
			# Anchor the actual alpha bounds, not the image allocation, so every pose
			# lands on the same 210px baseline without drifting sideways.
			var resized_bounds := cell.get_used_rect()
			var anchor := Vector2i((frame%4)*256+128-resized_bounds.get_center().x,(frame/4)*256+210-resized_bounds.end.y)
			atlas.blit_rect(cell,Rect2i(Vector2i.ZERO,cell.get_size()),anchor)
		assert(atlas.save_png("res://assets/enemies/"+file+".png")==OK)
		print("Prepared ",file)
	quit()

func clear_checker_backdrop(image: Image) -> void:
	var size := image.get_size()
	var visited := PackedByteArray()
	visited.resize(size.x*size.y)
	var queue: Array[Vector2i]=[]
	for x in size.x:
		queue.append(Vector2i(x,0))
		queue.append(Vector2i(x,size.y-1))
	for y in range(1,size.y-1):
		queue.append(Vector2i(0,y))
		queue.append(Vector2i(size.x-1,y))
	var cursor := 0
	while cursor<queue.size():
		var point := queue[cursor]
		cursor+=1
		var index := point.y*size.x+point.x
		if visited[index]: continue
		visited[index]=1
		var pixel := image.get_pixelv(point)
		var high := maxf(pixel.r,maxf(pixel.g,pixel.b))
		var low := minf(pixel.r,minf(pixel.g,pixel.b))
		# Generated checker squares vary slightly, but remain bright and neutral.
		if low<0.70 or high-low>0.10: continue
		image.set_pixelv(point,Color(pixel.r,pixel.g,pixel.b,0.0))
		if point.x>0: queue.append(point+Vector2i.LEFT)
		if point.x<size.x-1: queue.append(point+Vector2i.RIGHT)
		if point.y>0: queue.append(point+Vector2i.UP)
		if point.y<size.y-1: queue.append(point+Vector2i.DOWN)

func remove_neighbour_spill(cell: Image) -> void:
	var size := cell.get_size()
	var labels := PackedInt32Array()
	labels.resize(size.x*size.y)
	var areas: Array[int]=[0]
	var touches_edge: Array[bool]=[false]
	var component := 0
	for y in size.y:
		for x in size.x:
			var index := y*size.x+x
			if labels[index]!=0 or cell.get_pixel(x,y).a<=0.02: continue
			component+=1
			areas.append(0)
			touches_edge.append(false)
			var queue: Array[Vector2i]=[Vector2i(x,y)]
			labels[index]=component
			var cursor := 0
			while cursor<queue.size():
				var point := queue[cursor]
				cursor+=1
				areas[component]+=1
				if point.x==0 or point.y==0 or point.x==size.x-1 or point.y==size.y-1:
					touches_edge[component]=true
				for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
					var next: Vector2i=point+offset
					if next.x<0 or next.y<0 or next.x>=size.x or next.y>=size.y: continue
					var next_index: int=next.y*size.x+next.x
					if labels[next_index]!=0 or cell.get_pixelv(next).a<=0.02: continue
					labels[next_index]=component
					queue.append(next)
	var primary := 0
	for id in range(1,areas.size()):
		if primary==0 or areas[id]>areas[primary]: primary=id
	for y in size.y:
		for x in size.x:
			var id := labels[y*size.x+x]
			if id>0 and id!=primary and touches_edge[id]:
				cell.set_pixel(x,y,Color.TRANSPARENT)
