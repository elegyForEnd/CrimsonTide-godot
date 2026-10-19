class_name WorldArt
extends RefCounted

var materials: Array[Texture2D]=[]
var landmarks: Array[Texture2D]=[]
var chunks: Array[Texture2D]=[]
var chart: Texture2D
var candle_glow: GradientTexture2D
var _land_world: Ruins
var _land_texture: ImageTexture

func candle_positions() -> Array[Vector2]:
	var points: Array[Vector2]=[]
	for x in [1140,1660]:
		for y in [420,750,1050,1450,1750,1950]: points.append(Vector2(x,y))
	for x in [420,780,2020,2380]: points.append(Vector2(x,1310))
	return points

func _init() -> void:
	var gradient := Gradient.new()
	gradient.offsets=PackedFloat32Array([0.0,0.18,0.5,1.0])
	gradient.colors=PackedColorArray([Color(1,0.73,0.38,0.38),Color(1,0.65,0.28,0.25),Color(1,0.53,0.20,0.10),Color(1,0.48,0.18,0)])
	candle_glow=GradientTexture2D.new()
	candle_glow.gradient=gradient
	candle_glow.width=256
	candle_glow.height=256
	candle_glow.fill=GradientTexture2D.FILL_RADIAL
	candle_glow.fill_from=Vector2(0.5,0.5)
	candle_glow.fill_to=Vector2(1,0.5)
	for i in 6: materials.append(load("res://assets/world/terrain-%d.png" % i))
	for i in 9: landmarks.append(load("res://assets/world/landmark-%d.png" % i))

	for y in 3:
		for x in 4: chunks.append(load("res://assets/world/ground-%d-%d.jpg" % [x,y]))
	chart=load("res://assets/world/atlas.jpg")

func terrain(f: Node2D, world: Ruins, camera: Vector2, time: float) -> void:
	if world.interior:
		city_terrain(f,world,camera,time)
		return
	for y in 3:
		for x in 4:
			var rect := Rect2(Vector2(x,y)*1600*Ruins.MAP_SCALE,Vector2.ONE*1600*Ruins.MAP_SCALE)
			if rect.grow(1000).has_point(camera): f.draw_texture_rect(chunks[y*4+x],rect,false)
	if not world.generated:
		for y in range(maxi(0,int(camera.y-650)),mini(int(world.extent.y),int(camera.y+650)),42):
			var p := Vector2(Ruins.river_x(y),y)
			f.draw_line(p+Vector2(-65+sin(time+y)*12,0),p+Vector2(55+sin(time+y)*12,-5),Color(0.75,0.91,0.89,0.25),2)
	if world.generated:
		for river in world.rivers:
			var points: PackedVector2Array=river.get("points",PackedVector2Array())
			var width: float=float(river.get("width",40.0))
			for i in range(points.size()-1):
				if points[i].distance_to(camera)>1400 and points[i+1].distance_to(camera)>1400: continue
				f.draw_line(points[i],points[i+1],Color(0.75,0.91,0.89,0.25),maxf(2.0,width*0.16))
	for bridge in world.bridges:
		f.draw_rect(bridge.grow(9),Color("777578"))
		f.draw_rect(bridge,Color("d5ccb4"))
		for x in range(int(bridge.position.x),int(bridge.end.x),32):
			f.draw_line(Vector2(x,bridge.position.y),Vector2(x,bridge.end.y),Color("a1978a"),2)
		for y in [bridge.position.y,bridge.end.y]:
			f.draw_line(Vector2(bridge.position.x,y),Vector2(bridge.end.x,y),Color("f1e4c7"),12)
			for x in [bridge.position.x,bridge.end.x]: f.draw_circle(Vector2(x,y),14,Color("eee1c8"))
	for site in world.sites:
		if site.p.distance_to(camera)>1200: continue
		var rect: Rect2=site.rect
		f.draw_arc(site.p,98,0,TAU,64,Color("c9b58e"),3,true)
		f.draw_arc(site.p,89,0,TAU,64,Color(0.76,0.64,0.43,0.35),1,true)
	for wall in world.walls:
		if wall.get_center().distance_to(camera)>1150: continue
		f.draw_rect(Rect2(wall.position+Vector2(5,6),wall.size+Vector2(5,13)),Color(0.08,0.08,0.13,0.24))
		f.draw_rect(wall,Color("8b8090"))
		f.draw_texture_rect(materials[1],Rect2(wall.position-Vector2(0,14),wall.size),true,Color("c4c4bc"))
		f.draw_rect(Rect2(wall.position-Vector2(0,14),wall.size),Color("f3e2c6"),false,2)
	# Blood moon grades scenery before interactables and combat are drawn.
	f.draw_rect(Rect2(Vector2.ZERO,world.extent),Color(0.13,0.025,0.085,0.63))
	var moon := world.center if world.generated else Vector2(Ruins.river_x(2400*Ruins.MAP_SCALE),2400*Ruins.MAP_SCALE)
	if moon.distance_to(camera)<1100:
		f.draw_texture_rect(candle_glow,Rect2(moon-Vector2(140,220),Vector2(280,440)),false,Color(1,0.22,0.25,0.65))
		for stripe in range(-54,55,4):
			var half_width := sqrt(maxf(0,54.0*54.0-stripe*stripe))*0.75
			var ripple := sin(time*1.8+stripe*0.2)*6
			f.draw_line(moon+Vector2(-half_width+ripple,stripe),moon+Vector2(half_width+ripple,stripe),Color(0.94,0.22,0.25,0.38),2,true)

func plaza_style(deep: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color("a89c8b") if deep else Color("999d8d")
	style.set_corner_radius_all(44)
	style.border_color=Color("d7c8a3")
	style.set_border_width_all(3)
	return style

func prop(f: Node2D, item: Dictionary, camera: Vector2, player: Vector2, time: float) -> void:
	var at: Vector2=item.p
	if at.distance_to(camera)>1150: return
	var tex: Texture2D=landmarks[item.type]
	var height: float=item.size
	var width := height*tex.get_width()/tex.get_height()
	var alpha := 0.38 if player.distance_to(at-Vector2(0,height*0.4))<height*0.65 else 1.0
	var rect := Rect2(at-Vector2(width/2,height-14),Vector2(width,height))
	if item.type in [1,4]: rect.position.x+=sin(time*0.7+at.x)*1.6
	f.draw_set_transform(f.offset+at,0,Vector2(1,0.32))
	f.draw_circle(Vector2.ZERO,width*0.36,Color(0.07,0.09,0.13,0.22))
	f.draw_set_transform(f.offset)
	var tint := Color(0.65,0.43,0.57,alpha)
	if f.session.ruins.interior:
		tint=Color(0.38,0.38,0.51,alpha)
		var light := 0.0
		for candle in candle_positions(): light=maxf(light,clampf(1.0-at.distance_to(candle)/360.0,0,1))
		tint=tint.lerp(Color(0.91,0.72,0.48,alpha),light)
	f.draw_texture_rect(tex,rect,false,tint)

func _generated_atlas(f: Node2D, world: Ruins, rect: Rect2, big: bool) -> void:
	var scale := rect.size/world.extent
	f.draw_rect(rect,Color("16242d"))
	if not world.coast.is_empty():
		_land_fill(f,world,rect)
	for region in world.regions:
		var polygon: PackedVector2Array=region.get("polygon",PackedVector2Array())
		if polygon.size()<3: continue
		var color := MapMinimap.region_color(str(region.get("type","explore")))
		color.a=0.35
		var screen_polygon := _screen_polygon(polygon,rect,scale)
		if Geometry2D.triangulate_polygon(screen_polygon).is_empty(): continue
		f.draw_colored_polygon(screen_polygon,color)
	for lake in world.lakes:
		var polygon: PackedVector2Array=lake.get("polygon",PackedVector2Array())
		if polygon.size()>=3:
			var screen_polygon := _screen_polygon(polygon,rect,scale)
			if not Geometry2D.triangulate_polygon(screen_polygon).is_empty():
				f.draw_colored_polygon(screen_polygon,Color("2b5a6e"))
			var outline := screen_polygon.duplicate()
			outline.append(outline[0])
			f.draw_polyline(outline,Color(0.52,0.76,0.74,0.5),1.0,true)
	for river in world.rivers:
		var points: PackedVector2Array=river.get("points",PackedVector2Array())
		var width: float=float(river.get("width",40.0))
		for i in range(points.size()-1):
			var a := rect.position+points[i]*scale
			var b := rect.position+points[i+1]*scale
			f.draw_line(a,b,Color("356a7c"),maxf(2.0,width*scale.x))
			f.draw_line(a,b,Color("5d939c"),maxf(0.8,width*scale.x*0.35))
	for bridge in world.bridges:
		var bridge_rect := Rect2(rect.position+bridge.position*scale,bridge.size*scale)
		f.draw_rect(bridge_rect,Color("9a8d72"))
	for road in world.roads:
		var points: PackedVector2Array=road
		for i in range(points.size()-1):
			f.draw_line(rect.position+points[i]*scale,rect.position+points[i+1]*scale,Color(0.74,0.66,0.48,0.55),1.5)
	if big:
		for region in world.regions:
			if not bool(region.get("named",false)): continue
			var at: Vector2=rect.position+region.center*scale
			f.label(at-Vector2(36,0),str(region.name),13,Color("eadfc8"))

func _screen_polygon(points: PackedVector2Array, rect: Rect2, scale: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		var screen := rect.position+point*scale
		if not out.is_empty() and out[out.size()-1].is_equal_approx(screen):
			continue
		out.append(screen)
	while out.size() > 2 and out[out.size()-1].is_equal_approx(out[0]):
		out.remove_at(out.size()-1)
	return out

## Coast fill from the land mask instead of the contour polygon: the 32px contour
## can touch itself at one-cell bridges, and `draw_colored_polygon()` then fails
## triangulation for the whole island (map showed no land at all). One cached
## 300x225 texture per generated world is cheaper and always exact.
func _land_fill(f: Node2D, world: Ruins, rect: Rect2) -> void:
	var t: Variant = world.terrain
	if t == null or not (t is TerrainMap):
		return
	var grid: TerrainMap = t
	if _land_texture == null or _land_world != world:
		var image := Image.create(grid.cols, grid.rows, false, Image.FORMAT_RGBA8)
		var land_color := Color("5c6a57")
		for i in grid.land.size():
			if grid.land[i] != 0:
				image.set_pixel(i % grid.cols, i / grid.cols, land_color)
		_land_texture = ImageTexture.create_from_image(image)
		_land_world = world
	f.draw_texture_rect(_land_texture, rect, false)

func atlas(f: Node2D, world: Ruins, rect: Rect2, big: bool) -> void:
	if world.generated:
		_generated_atlas(f,world,rect,big)
		return
	var scale := rect.size/world.extent
	if world.interior:
		f.draw_rect(rect,Color("383344"))
		for site in world.sites:
			f.draw_rect(Rect2(rect.position+site.rect.position*scale,site.rect.size*scale),Color("ac9c87"))
		for wall in world.walls:
			f.draw_rect(Rect2(rect.position+wall.position*scale,wall.size*scale),Color("eee0bd"))
		return
	f.draw_texture_rect(chart,rect,false,Color.WHITE)
	for site in world.sites:
		var at: Vector2=rect.position+site.p*scale
		var tex: Texture2D=landmarks[site.prop]
		var height := 36.0 if big else 8.0
		if site.prop==8: height*=1.7
		var width := height*tex.get_width()/tex.get_height()
		f.draw_texture_rect(tex,Rect2(at-Vector2(width/2,height),Vector2(width,height)),false,Color(0.85,0.8,0.66,0.8))
	if big:
		for i in 6:
			var centers := [Vector2(1100,380),Vector2(3200,1120),Vector2(5200,380),Vector2(1050,4630),Vector2(3230,4630),Vector2(5400,4630)]
			f.label(rect.position+centers[i]*Ruins.MAP_SCALE*scale-Vector2(45,0),world.regions[i].name,17,Color("e2d8c4"))
		for x in 9:
			var at := rect.position+Vector2(x*rect.size.x/8,0)
			f.draw_line(at,at+Vector2(0,rect.size.y),Color(0.94,0.88,0.75,0.055),1)
			if x<8: f.label(at+Vector2(8,16),str(x+1),10,Color("c1b59b"))
		for y in 7:
			var at := rect.position+Vector2(0,y*rect.size.y/6)
			f.draw_line(at,at+Vector2(rect.size.x,0),Color(0.94,0.88,0.75,0.055),1)

func city_terrain(f: Node2D, world: Ruins, camera: Vector2, time: float) -> void:
	f.draw_rect(Rect2(Vector2.ZERO,world.extent),Color("252936"))
	f.draw_texture_rect(materials[5],Rect2(160,160,2480,1880),true,Color("ddd5dc"))
	for site in world.sites:
		f.draw_rect(site.rect,Color(0.92,0.88,0.8,0.32))
		f.draw_rect(site.rect.grow(-12),Color("ead9b3"),false,3)
		f.draw_rect(site.rect.grow(-22),Color("9b897e"),false,2)
	for x in range(160,2640,100):
		f.draw_line(Vector2(x,160),Vector2(x,2040),Color(0.3,0.3,0.37,0.16),1)
	for y in range(160,2040,100):
		f.draw_line(Vector2(160,y),Vector2(2640,y),Color(0.3,0.3,0.37,0.16),1)
	f.draw_rect(Rect2(1280,370,240,1580),Color("804859"))
	for x in [1285,1300,1500,1515]:
		f.draw_line(Vector2(x,370),Vector2(x,1950),Color("dec39a"),3,true)
	for y in range(420,1910,120):
		f.draw_arc(Vector2(1400,y),30,0,TAU,6,Color("bb8b84"),2,true)
	for radius in [250,263,282]:
		f.draw_arc(RoyalCity.BOSS,radius,0,TAU,96,Color("e6cc98"),3,true)
	for i in 12:
		var dir := Vector2.from_angle(i*TAU/12)
		f.draw_line(RoyalCity.BOSS+dir*250,RoyalCity.BOSS+dir*282,Color("e6cc98"),4,true)
	for wall in world.walls:
		f.draw_rect(Rect2(wall.position+Vector2(8,12),wall.size),Color(0.1,0.1,0.15,0.3))
		f.draw_rect(wall,Color("827b8e"))
		f.draw_rect(Rect2(wall.position-Vector2(0,14),wall.size),Color("e0d4bc"))
		f.draw_rect(Rect2(wall.position-Vector2(0,14),wall.size),Color("f9e9c3"),false,3)
	f.draw_rect(Rect2(Vector2.ZERO,world.extent),Color(0.025,0.03,0.085,0.76))
	for at in candle_positions():
		if at.distance_to(camera)>1200: continue
		var pulse := 1.0+sin(time*3.1+at.y)*0.025+sin(time*7.7+at.x)*0.015
		var radius := 290.0*pulse
		f.draw_texture_rect(candle_glow,Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2),false)
		f.draw_circle(at+Vector2(5,7),17,Color(0.01,0.01,0.025,0.5))
		f.draw_circle(at,12,Color("80654a"))
		f.draw_line(at,at-Vector2(0,27),Color("c39859"),4,true)
		f.draw_line(at-Vector2(13,23),at+Vector2(13,-23),Color("c39859"),3,true)
		for dx in [-12,0,12]:
			var tip := at+Vector2(dx,-29 if dx!=0 else -37)
			f.draw_line(tip+Vector2(0,9),tip,Color("e9d5a4"),4,true)
			f.draw_texture_rect(candle_glow,Rect2(tip-Vector2(30,30),Vector2(60,60)),false)
			f.draw_circle(tip-Vector2(0,3),4.5*pulse,Color("ffb653"))
			f.draw_circle(tip-Vector2(sin(time*5+at.x)*0.8,4),2.3,Color("fff4cf"))
