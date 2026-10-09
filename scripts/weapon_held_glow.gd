extends RefCounted
## Quiet surface light, independent of released attack paintings.
static var light: GradientTexture2D
static var surfaces: Dictionary={}
static var charge_anchors: Dictionary={}
static var charge_surfaces: Dictionary={}
static var reviewed_guides: Dictionary={}
static var reviewed_surfaces: Dictionary={}
static var reviewed_tracks: Dictionary={}
static var guides_loaded := false

static func surface_light() -> GradientTexture2D:
	if light==null:
		var gradient := Gradient.new()
		gradient.offsets=PackedFloat32Array([0,.25,.65,1])
		gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.6),Color(1,1,1,.12),Color(1,1,1,0)])
		light=GradientTexture2D.new()
		light.gradient=gradient
		light.width=32
		light.height=32
		light.fill=GradientTexture2D.FILL_RADIAL
		light.fill_from=Vector2(.5,.5)
		light.fill_to=Vector2(1,.5)
	return light

static func sample(pose: Dictionary, seconds: float) -> Dictionary:
	var accents := samples(pose,seconds)
	return {} if accents.is_empty() else accents[0]

static func surface_points(pose: Dictionary) -> Array[Dictionary]:
	var texture: Texture2D=pose.get("texture")
	if texture==null: return []
	var key := texture.get_instance_id()
	if surfaces.has(key): return surfaces[key]
	var image := texture.get_image()
	var rect: Rect2=pose.rect
	var tip := CharacterMetrics.FOOT_OFFSET+Vector2(pose.socket)
	var grip := CharacterMetrics.FOOT_OFFSET+Vector2(pose.get("grip",pose.socket))
	var family := Catalog.weapon_family(int(pose.weapon_identity))
	var points: Array[Dictionary]=[]
	# Melee light travels along the real blade; ranged light stays at its head.
	for i in range(9 if family in [1,2] else 6):
		var at := grip.lerp(tip,.35+float(i)*.075) if family in [1,2] else tip.lerp(grip,float(i)*.04)
		var pixel := (at-rect.position)/rect.size*texture.get_size()
		var best := 0.0
		var selected := Vector2.ZERO
		var color := Color.WHITE
		# Only illuminate existing opaque weapon pixels, never empty air.
		for y in range(-2,3):
			for x in range(-2,3):
				var p := Vector2i(pixel)+Vector2i(x,y)
				if p.x<0 or p.y<0 or p.x>=image.get_width() or p.y>=image.get_height(): continue
				var c := image.get_pixelv(p)
				var value := c.a*(.2+c.s)*c.v/(1+float(x*x+y*y)*.2)
				if c.a>.7 and value>best:
					best=value
					selected=Vector2(p)+Vector2(.5,.5)
					color=c
		if best>.03:
			points.append({"at":selected/texture.get_size(),"color":Color.from_hsv(color.h,color.s*.8,maxf(.65,color.v))})
			if family in [0,3]: break
	surfaces[key]=points
	return points

static func samples(pose: Dictionary, seconds: float) -> Array[Dictionary]:
	var accents: Array[Dictionary]=[]
	if not pose.get("weapon_atlas",false) or str(pose.get("state","")) not in ["idle","walk","run","dodge"]: return accents
	var weapon := int(pose.weapon_identity)
	var family := Catalog.weapon_family(weapon)
	var phase := seconds*TAU/(1.7+float(weapon%7)*.11)+float(weapon%11)*.57
	var unit := clampf(float(pose.get("standing_height",140))/140.0,.6,1.25)
	var points := surface_points(pose)
	for i in points.size():
		var point: Dictionary=points[i]
		var breath := .5+.5*sin(phase-float(i)*.55)
		var radius := (4.0 if family==3 else 2.4)*unit
		var tint: Color=point.color
		tint.a=.09+.13*breath
		var rect: Rect2=pose.rect
		var center: Vector2=rect.position+point.at*rect.size
		accents.append({"texture":surface_light(),"rect":Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2),"tint":tint,"source":"held_surface","center":center})
	return accents

## Select an opaque colored blade point; white hair must not own the charge light.
static func reviewed_points(pose: Dictionary) -> Array:
	if not pose.get("weapon_atlas",false): return []
	var texture: Texture2D=pose.texture
	if not texture is AtlasTexture: return []
	if not guides_loaded:
		guides_loaded=true
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://resources/weapon_charge_guides.json"))
		if data is Dictionary: reviewed_guides=data.get("entries",{})
	var region: Rect2=texture.region
	var key := "%s|%d,%d,%d,%d" % [texture.atlas.resource_path,region.position.x,region.position.y,region.size.x,region.size.y]
	if not reviewed_guides.has(key): return []
	if reviewed_surfaces.has(key): return reviewed_surfaces[key]
	var image := texture.get_image()
	var dimensions := Vector2(image.get_size())
	var paths: Array=reviewed_guides[key].get("paths",[reviewed_guides[key].guide])
	var result: Array=[]
	var tracks: Array=[]
	for guide: Array in paths:
		var track: Array=[]
		for segment in range(guide.size()-1):
			var first := Vector2(guide[segment][0],guide[segment][1])*dimensions
			var last := Vector2(guide[segment+1][0],guide[segment+1][1])*dimensions
			for i in 5:
				var desired := first.lerp(last,float(i)/4)
				var best := INF
				var chosen := Vector2.ZERO
				for y in range(-8,9):
					for x in range(-8,9):
						var pixel := Vector2i(desired)+Vector2i(x,y)
						if pixel.x<0 or pixel.y<0 or pixel.x>=image.get_width() or pixel.y>=image.get_height(): continue
						var color := image.get_pixelv(pixel)
						if color.a<.7: continue
						var point := Vector2(pixel)+Vector2(.5,.5)
						var distance := point.distance_squared_to(desired)
						if distance<best: best=distance; chosen=point/dimensions
				if best<INF and (track.is_empty() or Vector2(track.back()).distance_to(chosen)>.002): track.append(chosen)
		if not track.is_empty(): tracks.append(track); result.append_array(track)
	reviewed_tracks[key]=tracks
	reviewed_surfaces[key]=result
	return result

static func charge_anchor(pose: Dictionary) -> Vector2:
	var reviewed := reviewed_points(pose)
	if not reviewed.is_empty():
		var rect: Rect2=pose.rect
		return rect.position+Vector2(reviewed.back() if Catalog.weapon_family(int(pose.weapon_identity))==3 else reviewed[reviewed.size()/2])*rect.size-CharacterMetrics.FOOT_OFFSET
	var grip := Vector2(pose.get("grip",pose.get("socket",Vector2.ZERO)))
	if not pose.get("weapon_atlas",false): return Vector2(pose.get("socket",grip))
	var key: int=pose.texture.get_instance_id()
	var rect: Rect2=pose.rect
	if not charge_anchors.has(key):
		var image: Image=pose.texture.get_image()
		var best := -1.0
		var selected: Dictionary={}
		for point in surface_points(pose):
			var pixel := Vector2i(Vector2(point.at)*Vector2(image.get_size()))
			pixel=pixel.clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE)
			var color := image.get_pixelv(pixel)
			if color.a<.7 or color.s<.30: continue
			var score := color.s*color.v
			if score>best: best=score; selected=point
		if selected.is_empty():
			# Some old anticipation landmarks sit outside their packed cell.
			# Find the nearest colored opaque surface instead of glowing in empty air.
			var reference := (grip+CharacterMetrics.FOOT_OFFSET-rect.position)/rect.size*Vector2(image.get_size())
			var distance := INF
			for y in range(0,image.get_height(),2):
				for x in range(0,image.get_width(),2):
					var color := image.get_pixel(x,y)
					if color.a<.85 or color.s<.4 or color.v<.25: continue
					var pixel := Vector2(x+.5,y+.5)
					var score := pixel.distance_squared_to(reference)
					if score<distance:
						distance=score
						selected={"at":pixel/Vector2(image.get_size())}
		charge_anchors[key]=selected
	var selected: Dictionary=charge_anchors[key]
	return grip if selected.is_empty() else rect.position+Vector2(selected.at)*rect.size-CharacterMetrics.FOOT_OFFSET

static func charge_sites(pose: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2]=[]
	var reviewed := reviewed_points(pose)
	if not reviewed.is_empty():
		var rect: Rect2=pose.rect
		for point in reviewed: result.append(rect.position+Vector2(point)*rect.size-CharacterMetrics.FOOT_OFFSET)
		return result
	if not pose.get("weapon_atlas",false): return [charge_anchor(pose)]
	var texture: Texture2D=pose.texture
	var key := texture.get_instance_id()
	var rect: Rect2=pose.rect
	if not charge_surfaces.has(key):
		var image := texture.get_image()
		var dimensions := Vector2(image.get_size())
		var seed := Vector2i((charge_anchor(pose)+CharacterMetrics.FOOT_OFFSET-rect.position)/rect.size*dimensions)
		var visited: Dictionary={}
		var queue: Array[Vector2i]=[seed]
		var component: Array[Vector2]=[]
		var cursor := 0
		# Follow the connected colored metal/blade, excluding white hair and skin.
		while cursor<queue.size() and cursor<24000:
			var pixel: Vector2i=queue[cursor]; cursor+=1
			if visited.has(pixel): continue
			visited[pixel]=true
			if pixel.x<0 or pixel.y<0 or pixel.x>=image.get_width() or pixel.y>=image.get_height(): continue
			var c := image.get_pixelv(pixel)
			if c.a<.65 or c.s<.25 or c.v<.18: continue
			component.append(Vector2(pixel)+Vector2(.5,.5))
			for delta in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2),Vector2i(2,2),Vector2i(-2,-2),Vector2i(2,-2),Vector2i(-2,2)]:
				if not visited.has(pixel+delta): queue.append(pixel+delta)
		var points: Array[Vector2]=[]
		if not component.is_empty():
			var first := component[0]
			for pixel in component:
				if pixel.distance_squared_to(Vector2(seed))>first.distance_squared_to(Vector2(seed)): first=pixel
			var last := first
			for pixel in component:
				if pixel.distance_squared_to(first)>last.distance_squared_to(first): last=pixel
			# Sample across the whole connected weapon, in blade order.
			for i in 12:
				var desired := first.lerp(last,float(i)/11)
				var selected := component[0]
				for pixel in component:
					if pixel.distance_squared_to(desired)<selected.distance_squared_to(desired): selected=pixel
				if points.is_empty() or points.back().distance_to(selected/dimensions)> .002: points.append(selected/dimensions)
		charge_surfaces[key]=points
	for point in charge_surfaces[key]:
		result.append(rect.position+Vector2(point)*rect.size-CharacterMetrics.FOOT_OFFSET)
	if result.is_empty(): result.append(charge_anchor(pose))
	return result

static func charge_paths(pose: Dictionary) -> Array:
	var reviewed := reviewed_points(pose)
	if reviewed.is_empty(): return [charge_sites(pose)]
	var texture: AtlasTexture=pose.texture
	var region := texture.region
	var key := "%s|%d,%d,%d,%d" % [texture.atlas.resource_path,region.position.x,region.position.y,region.size.x,region.size.y]
	var result: Array=[]
	var rect: Rect2=pose.rect
	for track: Array in reviewed_tracks.get(key,[]):
		var points: Array[Vector2]=[]
		for uv in track: points.append(rect.position+Vector2(uv)*rect.size-CharacterMetrics.FOOT_OFFSET)
		result.append(points)
	return result
