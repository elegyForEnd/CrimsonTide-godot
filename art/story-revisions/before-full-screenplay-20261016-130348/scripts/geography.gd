extends RefCounted
## Spatial bridge to the project's authored maps. Meshes and collision retain
## their original scale; Scarlet's authored event coordinates are only an index.
const OriginalMap=preload("res://scripts/story_map.gd")
const SOURCES={
	"1:0":0,"1:1":1,"1:2":2,"1:3":3,"1:4":5,"1:5":9,"1:6":6,
	"2:0":0,"2:1":1,"2:2":2,"2:3":3,"2:4":4,"2:5":5,"2:6":6,
	"3:0":0,"3:1":1,"3:2":2,"3:3":3,"3:4":4,"3:5":7,"3:6":6,
	"4:0":0,"4:1":1,"4:2":2,"4:3":3,"4:4":4,"4:5":5,"4:6":6,
	"5:0":0,"5:1":7,"5:2":2,"5:3":3,"5:4":4,"5:5":5,"5:6":6,
	"6:0":0,"6:1":7,"6:2":1,"6:3":3,"6:4":4,"6:5":2,"6:6":6,"6:7":1}
const CELL=20.0
static var maps: Dictionary={}
static var grids: Dictionary={}
var key:=""
var original
var region
var ratio:=Vector2.ONE
var reachable: Dictionary={}
var placements: Dictionary={}
var cells: Array[Vector2]=[]

static func source_stage(zone: String) -> int:
	return int(SOURCES.get(zone,int(zone.get_slice(":",1))-100))

static func zone_for(act: int,stage: int) -> String:
	for zone in SOURCES:
		if int(zone.get_slice(":",0))==act and source_stage(zone)==stage: return zone
	return "%d:%d" % [act,100+stage]

static func install(content: Dictionary) -> void:
	var original_content: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/story_content.json"))
	for act in original_content.acts:
		for index in range(0,act.maps.size()+1):
			var zone:=zone_for(int(act.id),index)
			var name: String=act.camp if index==0 else act.maps[index-1].name
			if not content.zones.has(zone):
				content.zones[zone]={"id":zone,"act":int(act.id),"stage":int(zone.get_slice(":",1)),"name":name,"layout":act.maps[index-1].layout,"ambient":"829ab7","blocks":[],"props":[],"exploration":true}
			content.zones[zone].source_name=name
	for zone in content.zones:
		if not content.zones[zone].has("source_name"):
			var a:=int(zone.get_slice(":",0)); var stage:=source_stage(zone)
			content.zones[zone].source_name=original_content.acts[a-1].maps[stage-1].name

func select(zone: String) -> void:
	if key==zone:
		original.activate(source_stage(zone)); return
	key=zone
	var act:=int(zone.get_slice(":",0))
	if not maps.has(act):
		var m=OriginalMap.new(); m.build(act,source_stage(zone),""); maps[act]=m
	original=maps[act]; original.activate(source_stage(zone)); region=original.regions[source_stage(zone)]
	ratio=region.extent/1800.0
	placements.clear()
	if grids.has(zone):
		reachable=grids[zone].reachable; cells=grids[zone].cells; return
	reachable={}; cells=[]
	# The same floor/shore/wall authority as the original map, without the
	# replacement 18-metre rectangle or its arbitrary cover boxes.
	var open: Dictionary={}
	for y in range(1,90):
		for x in range(1,90):
			var p:=Vector2(x,y)*CELL
			if original.walkable(native(p),24.0): open[Vector2i(x,y)]=true
	var seed:=Vector2i((region.spawn/ratio/CELL).round())
	if not open.has(seed):
		var best:=INF
		for cell in open:
			var distance: float=Vector2(cell).distance_squared_to(seed)
			if distance<best: best=distance; seed=cell
	var todo: Array[Vector2i]=[seed]; reachable[seed]=true
	var index:=0
	while index<todo.size():
		var cell:=todo[index]; index+=1; cells.append(Vector2(cell)*CELL)
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+direction
			if not open.has(next) or reachable.has(next): continue
			# Reject a grid edge cutting through a narrow wall or a shoreline.
			if not original.walkable(native((Vector2(cell)+Vector2(direction)*.5)*CELL),24.0): continue
			reachable[next]=true; todo.append(next)

	grids[zone]={"reachable":reachable,"cells":cells}

func native(p: Vector2) -> Vector2: return region.origin+p*ratio
func local(p: Vector2) -> Vector2: return (p-region.origin)/ratio
func height(p: Vector2) -> float: return original.height_at(native(p))*.01
func speed_scale() -> float: return 1.0/maxf(ratio.x,ratio.y)
func walkable(p: Vector2,radius: float=22.0) -> bool:
	return original.walkable(native(p),minf(radius,24.0/maxf(ratio.x,ratio.y))*maxf(ratio.x,ratio.y))

func place(p: Vector2) -> Vector2:
	if placements.has(p): return placements[p]
	var near:=Vector2i((p/CELL).round())
	if reachable.has(near) and walkable(p): placements[p]=p; return p
	var result:=Vector2.ZERO; var distance:=INF
	for candidate in cells:
		var d: float=candidate.distance_squared_to(p)
		if d<distance: distance=d; result=candidate
	placements[p]=result
	return result

func spawn() -> Vector2: return place(region.spawn/ratio)
func scene_path(compat: bool) -> String:
	return "res://scenes/story/"+("opening-%d" % region.stage if region.act==1 else "act%d-%d" % [region.act,region.stage])+("-compat.scn" if compat else ".scn")
