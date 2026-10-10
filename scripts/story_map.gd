extends RefCounted
## One act is a continuous overworld; interiors have reciprocal entrances.
const Region = preload("res://scripts/story_region.gd")
const NPC_AT = Region.NPC_AT
var act := 1
var stage := 0
var layer := 0
var layout := "camp"
var extent := Vector2(14400,16400)
var spawn := Vector2.ZERO
var waypoint := Vector2.ZERO
var anchors: Array=[]
var side_anchors: Array=[]
var regions: Dictionary={}
var outdoor: Array=[]
var portals: Array=[]
var connectors: Array=[]
var floors: Array=[]
var layouts: Array=[]
var npc_at: Array=[]
var navigation: Dictionary={}

func configure(a: int, shapes: Array) -> void:
	if act==a and not regions.is_empty() and layouts==shapes: return
	act=a; layouts=shapes.duplicate(); regions.clear(); outdoor=[0]; portals.clear(); connectors.clear(); navigation.clear()
	var camp=Region.new(); camp.build(a,0,"camp",false); regions[0]=camp
	var last := 0; var order := 0
	for s in range(1,shapes.size()+1):
		var shape: String=shapes[s-1]
		var inside: bool=shape in ["hall","library","crypt","cathedral","mine","chapel","castle"]
		var r=Region.new(); r.build(a,s,shape,inside); regions[s]=r
		if inside:
			var source: int=s-1 if s>1 and regions[s-1].indoor else last
			if s==7: source=1
			if a==1 and shape=="castle": source=2
			var parent=regions[source]
			var at: Vector2=parent.origin+(Vector2(900,2200) if s==7 else parent.anchors[-1]+Vector2(0,160) if parent.indoor else Vector2(3100,3300) if source>0 else Vector2(1100,1600))
			if shape=="castle": at=parent.origin+Vector2(1050,2100)
			var count := 0
			for door in portals:
				if door.source==source: count+=1
			at+=Vector2(-count*650,0)
			portals.append({"source":source,"stage":s,"p":at,"label":"进入灰棘旧堡" if shape=="castle" else "进入遗迹","kind":"entrance","architecture":shape})
			parent.ports.append(at-parent.origin)
			parent.trails.append(PackedVector2Array([parent.anchors[-1] if source>0 else parent.spawn,at-parent.origin]))
		else:
			var parent=regions[last]
			var east: bool=order>0 and (order+a)%3==0
			r.origin=parent.origin+Vector2(parent.extent.x+500,0) if east else parent.origin+Vector2((parent.extent.x-r.extent.x)*.5,parent.extent.y+500)
			var from: Vector2=parent.origin+(Vector2(parent.extent.x,parent.extent.y*.5) if east else Vector2(parent.extent.x*.5,parent.extent.y))
			var to: Vector2=r.origin+(Vector2(0,r.extent.y*.5) if east else Vector2(r.extent.x*.5,0))
			connectors.append({"rect":Rect2(from.min(to)-Vector2(200,200),(from-to).abs()+Vector2(400,400)),"from":last,"to":s,"a":from,"b":to})
			parent.ports.append(from-parent.origin); r.ports.append(to-r.origin)
			parent.trails.append(PackedVector2Array([parent.anchors[-1] if last>0 else Vector2(1100,1600),from-parent.origin]))
			r.trails.append(PackedVector2Array([to-r.origin,r.anchors[0]]))
			last=s; outdoor.append(s); order+=1
	for s in regions:
		var r=regions[s]
		# A coastal boundary crossing uses a causeway instead of landing in water.
		for port in r.ports:
			if port.x>50: continue
			var kept: Array[Rect2]=[]
			for rect in r.water:
				if not rect.grow(1).has_point(port): kept.append(rect); continue
				if port.y-230>rect.position.y: kept.append(Rect2(rect.position,Vector2(rect.size.x,port.y-230-rect.position.y)))
				if port.y+230<rect.end.y: kept.append(Rect2(rect.position.x,port.y+230,rect.size.x,rect.end.y-port.y-230))
			r.water=kept
		var retained: Array=[]; r.obstacles.clear()
		for item in r.props:
			if item.blocking and r.path_distance(item.p)<190: continue
			retained.append(item)
			if item.blocking: r.obstacles.append(Rect2(item.p-Vector2(item.size.x,item.size.z)*.32,Vector2(item.size.x,item.size.z)*.64))
		r.props=retained

func build(a: int, s: int, _shape: String) -> void:
	if regions.is_empty() or act!=a:
		var content: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/story_content.json"))
		var shapes: Array=[]
		for m in content.acts[a-1].maps: shapes.append(m.layout)
		configure(a,shapes)
	activate(s)

func activate(s: int) -> void:
	stage=s; layout=regions[s].layout; layer=s if regions[s].indoor else 0
	var r=regions[s]
	spawn=r.origin+r.spawn; waypoint=r.origin+r.waypoint
	anchors=[]; side_anchors=[]; npc_at=regions[0].npc_at.duplicate()
	for p in r.anchors: anchors.append(r.origin+p)
	for p in r.side_anchors: side_anchors.append(r.origin+p)
	floors=[s] if layer>0 else outdoor.duplicate()

func region_at(p: Vector2) -> int:
	if layer>0: return stage
	for s in outdoor:
		var r=regions[s]
		if Rect2(r.origin,r.extent).has_point(p): return s
	return -1

func height_at(p: Vector2) -> float:
	var s := region_at(p)
	return regions[s].height_at(p-regions[s].origin) if s>=0 else 0.0

func walkable(p: Vector2, radius: float = 24.0) -> bool:
	var s := region_at(p)
	if s>=0:
		var r=regions[s]; var local: Vector2=p-r.origin
		if not r.walkable(local,radius): return false
		if layer==0 and minf(minf(local.x,r.extent.x-local.x),minf(local.y,r.extent.y-local.y))<100:
			for c in connectors:
				if c.rect.grow(-radius).has_point(p): return true
			return false
		return true
	if layer==0:
		for c in connectors:
			if c.rect.grow(-radius).has_point(p): return true
	return false

func move(from: Vector2, motion: Vector2) -> Vector2:
	var result := from
	var count := maxi(1,int(ceil(motion.length()/12.0)))
	var step := motion/float(count)
	for i in count:
		var next := result+Vector2(step.x,0)
		if walkable(next) and absf(height_at(next)-height_at(result))<20: result.x=next.x
		next=result+Vector2(0,step.y)
		if walkable(next) and absf(height_at(next)-height_at(result))<20: result.y=next.y
	return result

func sight(from: Vector2, to: Vector2) -> bool:
	var count := maxi(1,int(ceil(from.distance_to(to)/18.0)))
	for i in range(1,count):
		if not walkable(from.lerp(to,float(i)/count),1): return false
	return true

func entrances() -> Array:
	var result: Array=[]
	if layer>0: result.append({"kind":"exit","stage":stage,"p":spawn,"label":"楼梯 · 返回上一层"})
	for door in portals:
		if (layer==0 and door.source in outdoor) or (layer>0 and door.source==stage): result.append(door)
	return result

func return_door(s: int) -> Dictionary:
	for p in portals:
		if p.stage==s: return p
	return {}

func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var s := region_at(from)
	if s<0 or s!=region_at(to): return PackedVector2Array([to])
	var r=regions[s]
	if not navigation.has(s):
		var grid := AStarGrid2D.new()
		grid.region=Rect2i(0,0,int(r.extent.x/60),int(r.extent.y/60))
		grid.cell_size=Vector2.ONE*60; grid.offset=Vector2.ONE*30
		grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for y in grid.region.size.y:
			for x in grid.region.size.x:
				# Extra clearance keeps diagonal steps away from concave wall/prop corners.
				grid.set_point_solid(Vector2i(x,y),not r.walkable(Vector2(x,y)*60+Vector2.ONE*30,36))
		navigation[s]=grid
	var nav: AStarGrid2D=navigation[s]
	var first := Vector2i((from-r.origin)/60)
	var last := Vector2i((to-r.origin)/60)
	if not nav.is_in_boundsv(first) or not nav.is_in_boundsv(last): return PackedVector2Array()
	# Dynamic actors can stand between grid centers beside a wall; use the nearest cell.
	if nav.is_point_solid(first): first=near_open(nav,first)
	if nav.is_point_solid(last): last=near_open(nav,last)
	var points: PackedVector2Array=nav.get_point_path(first,last,true)
	for i in points.size(): points[i]+=r.origin
	return points

func near_open(nav: AStarGrid2D, cell: Vector2i) -> Vector2i:
	for distance in range(1,4):
		for y in range(-distance,distance+1):
			for x in range(-distance,distance+1):
				var at := cell+Vector2i(x,y)
				if nav.is_in_boundsv(at) and not nav.is_point_solid(at): return at
	return cell
