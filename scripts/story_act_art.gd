extends RefCounted
## Authored regional layout and art identity; does not change map/save IDs.
const PATH := "res://resources/story-later-acts.json"
static var data: Dictionary={}
static var terrains: Dictionary={}
static func terrain(region) -> Dictionary:
	if terrains.is_empty(): terrains=JSON.parse_string(FileAccess.get_file_as_string("res://resources/story-later-terrain.json"))
	return terrains.get("%d:%d" % [region.act,region.stage],{})
static func palette(act: int) -> Dictionary:
	if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return data.acts[str(act)]
static func settings(region) -> Dictionary:
	return palette(region.act).regions[str(region.stage)]
static func configure(region) -> void:
	if region.act<2: return
	var s := settings(region)
	region.art_theme=s.theme
	if not region.indoor:
		if region.stage==0:
			region.props.clear(); region.obstacles.clear()
			for b in region.buildings:
				var center: Vector2=b.rect.get_center()
				var role: int=b.role
				if role in [0,5]: region.structural_obstacles.append(Rect2(center+Vector2(-93,-58),Vector2(65,65)))
				elif role==1:
					for x in [-65,65]: region.structural_obstacles.append(Rect2(center+Vector2(x-25,-85),Vector2(50,100)))
				elif role==2: region.structural_obstacles.append(Rect2(center+Vector2(-108,-63),Vector2(85,55)))
				elif role==4:
					for x in [-65,65]: region.structural_obstacles.append(Rect2(center+Vector2(x-28,-83),Vector2(56,66)))
			for p in [Vector2(350,1850),Vector2(1850,1850)]: region.structural_obstacles.append(Rect2(p-Vector2.ONE*35,Vector2.ONE*70))
		return
	region.props.clear(); region.obstacles.clear(); region.structural_obstacles.clear()
	region.rooms.clear(); region.floor_polygon.clear()
	# All authored pieces are connected; one polygon defines render + movement.
	var pending: Array[PackedVector2Array]=[]
	for raw in s.polygons:
		var poly := PackedVector2Array()
		for p in raw: poly.append(Vector2(p[0],p[1]))
		pending.append(poly)
	region.floor_polygon=pending.pop_front()
	for pass_index in s.polygons.size():
		for poly in pending.duplicate():
			if Geometry2D.intersect_polygons(region.floor_polygon,poly).is_empty(): continue
			var joined := Geometry2D.merge_polygons(region.floor_polygon,poly)
			# Courtyards have solid floors; close enclosed service voids deliberately.
			var best := 0.0
			for outline in joined:
				var area := 0.0
				for i in outline.size(): area+=outline[i].cross(outline[(i+1)%outline.size()])
				if absf(area)>best: best=absf(area); region.floor_polygon=outline
			pending.erase(poly)
	assert(pending.is_empty(),"Disconnected authored floor: "+region.art_theme)
	# Quoins cover the physical corner of the two wall caps. The same 70cm
	# footprint prevents a character from walking into those visual columns.
	for p in region.floor_polygon: region.structural_obstacles.append(Rect2(p-Vector2.ONE*35,Vector2.ONE*70))
	region.anchors.clear(); region.side_anchors.clear(); region.chests.clear()
	for p in s.anchors: region.anchors.append(Vector2(p[0],p[1]))
	for p in s.side_anchors: region.side_anchors.append(Vector2(p[0],p[1]))
	for p in s.chests: region.chests.append(Vector2(p[0],p[1]))
	region.stairs=[{"rect":Rect2(2180,3500,440,420),"top":105.0,"north":false,"terrace":Rect2(2100,3920,750,880)}]
	region.trails=[PackedVector2Array([region.spawn,Vector2(2400,1650),Vector2(2400,3250),region.anchors[-1]])]
static func entries(region) -> Array:
	var s := settings(region)
	var source: Array=s.interior_dressing if region.indoor else s.dressing
	var result: Array=[]
	for raw in source:
		var item: Dictionary=raw.duplicate(true)
		var p := Vector2(item.at[0],item.at[1]); item.position=p
		if item.get("footprint")==null: item.erase("footprint")
		var size: Array=item.get("footprint",[0,0])
		item.rect=Rect2(p-Vector2(size[0],size[1])*.5,Vector2(size[0],size[1]))
		var blocked: bool=region.submerged(p)
		if region.indoor and not region.floor_contains(p,maxf(size[0],size[1])*.6): blocked=true
		for target in region.anchors+region.side_anchors+region.chests+[region.waypoint,region.spawn]+region.ports:
			if item.rect.grow(120).has_point(target): blocked=true
		for stair in region.stairs:
			if item.rect.intersects(stair.rect.grow(40)) or item.rect.intersects(stair.terrace.grow(40)): blocked=true
		if not region.indoor:
			for b in region.buildings:
				if b.rect.grow(110).has_point(p): blocked=true
			if region.path_distance(p)<180: blocked=true
		if not blocked: result.append(item)
	return result
