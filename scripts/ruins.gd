class_name Ruins
extends RefCounted

const SIZE := Vector2(6400,4800)
const CENTER := SIZE/2
const SPAWN := Vector2(560,2400)
const EXIT_NAMES := ["西境驿站","东岸渡口","北境钟门","晨钟归途"]
const BIOME_NAMES := ["风铃原野","白垩旧城","月晶高地","蔷薇庭域","雾汐湿地","圣血王庭"]
const COLORS := [Color("809d83"),Color("b1a28c"),Color("9990b5"),Color("ae7f8c"),Color("689c9b"),Color("c9b99c")]
const WILDERNESS_CHESTS := 6
# One cache in each biome. Its loot grade is fixed when the map is generated,
# so changing backpacks or the order in which players search cannot improve it.
const CACHE_TIERS := [0,1,2,2,3,4]
var extent := SIZE
var interior := false
var walls: Array[Rect2] = []
var sites: Array = []
var chests: Array = []
var shrines: Array = []
var exits: Array = []
var decor: Array = []
var regions: Array = []
var roads: Array = []
var river := PackedVector2Array()
var bridges: Array[Rect2] = []
var rng := RandomNumberGenerator.new()
var map_seed := 0
var wall_cells: Dictionary = {}
var indexed_wall_count := 0
var coast := PackedVector2Array()
var features: Array=[]

func generate(value: int) -> void:
	map_seed=value
	rng.seed=value
	walls.clear()
	sites.clear()
	chests.clear()
	shrines.clear()
	decor.clear()
	regions.clear()
	roads.clear()
	bridges.clear()
	wall_cells.clear()
	features.clear()
	coast=PackedVector2Array([Vector2(350,500),Vector2(760,180),Vector2(1410,290),Vector2(1910,120),Vector2(2480,270),Vector2(2920,130),Vector2(3500,160),Vector2(4110,310),Vector2(4510,130),Vector2(5100,240),Vector2(5690,140),Vector2(6110,490),Vector2(5980,1010),Vector2(6250,1530),Vector2(6170,2000),Vector2(6300,2480),Vector2(6110,3050),Vector2(6280,3630),Vector2(6070,4300),Vector2(5620,4620),Vector2(5190,4500),Vector2(4740,4680),Vector2(4200,4490),Vector2(3710,4710),Vector2(3100,4520),Vector2(2670,4700),Vector2(2210,4510),Vector2(1710,4690),Vector2(1170,4500),Vector2(680,4620),Vector2(240,4150),Vector2(390,3640),Vector2(180,3090),Vector2(260,2650),Vector2(160,2100),Vector2(320,1630),Vector2(180,1110)])
	exits=[Vector2(420,2400),Vector2(6010,2400),Vector2(3650,380),Vector2(3330,2400)]
	# Six irregular contiguous regions, sharing the same boundaries in world and atlas.
	var outlines := [
		[Vector2(0,0),Vector2(2130,0),Vector2(2310,1150),Vector2(1980,2190),Vector2(2160,2620),Vector2(0,2580)],
		[Vector2(2130,0),Vector2(4260,0),Vector2(4140,1280),Vector2(4410,2270),Vector2(3860,2520),Vector2(2160,2620),Vector2(1980,2190),Vector2(2310,1150)],
		[Vector2(4260,0),Vector2(6400,0),Vector2(6400,2480),Vector2(4410,2270),Vector2(4140,1280)],
		[Vector2(0,2580),Vector2(2160,2620),Vector2(2390,3600),Vector2(2060,4800),Vector2(0,4800)],
		[Vector2(2160,2620),Vector2(3860,2520),Vector2(4090,3540),Vector2(4400,4800),Vector2(2060,4800),Vector2(2390,3600)],
		[Vector2(3860,2520),Vector2(4410,2270),Vector2(6400,2480),Vector2(6400,4800),Vector2(4400,4800),Vector2(4090,3540)]]
	for i in 6:
		regions.append({"polygon":PackedVector2Array(outlines[i]),"color":COLORS[i],"name":BIOME_NAMES[i]})
	river.clear()
	for y in range(0,4801,80):
		river.append(Vector2(river_x(y)-105,y))
	for y in range(4800,-1,-80):
		river.append(Vector2(river_x(y)+105,y))
	for y in [950,2400,3850]:
		bridges.append(Rect2(river_x(y)-220,y-105,440,210))
	# Landmark placements are intentional; seed varies supplies and peripheral props.
	var specs := [
		["风铃驿站",Vector2(950,2100),0,1,6],["巡礼礼拜堂",Vector2(1000,780),0,1,0],["白花营地",Vector2(1770,1520),0,1,7],
		["失落书库",Vector2(2620,780),1,1,0],["晨钟大桥",Vector2(2760,2370),1,1,3],["晨曦王城",Vector2(3860,1680),1,2,8],
		["月晶矿场",Vector2(4830,730),2,2,2],["观星高塔",Vector2(5570,1490),2,2,7],["银月营地",Vector2(4840,2050),2,1,2],
		["蔷薇温室",Vector2(920,3270),3,1,3],["花眠庭院",Vector2(1700,4140),3,1,1],["红棘修道院",Vector2(1820,3060),3,2,0],
		["雾汐药圃",Vector2(2630,3240),4,1,4],["沉钟遗迹",Vector2(3750,4160),4,2,0],["月舟码头",Vector2(3800,2990),4,1,6],
		["圣血大教堂",Vector2(4770,3240),5,2,0],["白蔷王庭",Vector2(5590,4080),5,2,5],["月蚀宝库",Vector2(5560,2790),5,2,7]]
	for i in specs.size():
		var spec: Array=specs[i]
		var pos: Vector2=spec[1]
		var room := Vector2(500,400) if i not in [5,15] else Vector2(780,620)
		var rect := Rect2(pos-room/2,room)
		sites.append({"p":pos,"rect":rect,"name":spec[0],"biome":spec[2],"tier":spec[3],"prop":spec[4],"engaged":false,"cleared":false,"defeated":0})
		# Open ruins have four entrances; no sealed rectangular rooms.
		if i%3!=2:
			for side in [-1,1]:
				for end in [-1,1]:
					walls.append(Rect2(pos+Vector2(side*room.x/2-12,end*room.y/2-75),Vector2(24,150)))
					walls.append(Rect2(pos+Vector2(end*room.x/2-100,side*room.y/2-12),Vector2(200,24)))
		if i in [3,10,15]:
			shrines.append({"p":pos+Vector2(0,145),"done":false,"progress":0.0})
		decor.append({"p":pos+Vector2(0,-110),"type":spec[4],"size":510.0 if i==5 else (290.0 if i==15 else 210.0),"landmark":true})
	# Three east-west crossings and a loop on both banks create route choices.
	for y in [950,2400,3850]:
		roads.append(PackedVector2Array([Vector2(420,y),Vector2(1900,y+100 if y!=2400 else y),Vector2(river_x(y)-240,y),Vector2(river_x(y)+240,y),Vector2(4560,y-90 if y!=2400 else y),Vector2(6010,y)]))
	roads.append(PackedVector2Array([Vector2(850,500),Vector2(620,950),Vector2(600,2400),Vector2(850,3850),Vector2(1700,4400),Vector2(2400,3850),Vector2(2500,2400),Vector2(2250,950),Vector2(2700,400),Vector2(3650,380)]))
	roads.append(PackedVector2Array([Vector2(3650,380),Vector2(3900,500),Vector2(4150,950),Vector2(4320,2400),Vector2(4450,3850),Vector2(5530,4400),Vector2(5800,3850),Vector2(6010,2400),Vector2(5760,950),Vector2(5400,500)]))
	for r in roads.size():
		var curved := PackedVector2Array()
		var road: PackedVector2Array=roads[r]
		for j in range(road.size()-1):
			var a: Vector2=road[j]
			var b: Vector2=road[j+1]
			var normal := (b-a).normalized().orthogonal()
			var steps := maxi(2,int(a.distance_to(b)/110))
			for k in steps:
				var t := float(k)/steps
				var point := a.lerp(b,t)
				var bend := sin(t*PI)*sin(j*2.3+r+0.8)*100
				if absf(point.x-river_x(point.y))>350: point+=normal*bend
				curved.append(point)
		curved.append(road[-1])
		roads[r]=curved
	for site in sites:
		var closest := Vector2.ZERO
		var distance := INF
		for road in roads:
			for j in range(road.size()-1):
				var point := Geometry2D.get_closest_point_to_segment(site.p,road[j],road[j+1])
				if point.distance_squared_to(site.p)<distance:
					distance=point.distance_squared_to(site.p)
					closest=point
		roads.append(PackedVector2Array([site.p,closest]))
	# Off-route water basins and cliff plateaus leave every designed road open.
	var terrain_rng := RandomNumberGenerator.new()
	terrain_rng.seed=99127
	for i in 480:
		var center := Vector2(terrain_rng.randf_range(500,5900),terrain_rng.randf_range(500,4300))
		var radius := terrain_rng.randf_range(95,210)
		if near_road(center,radius+140) or absf(center.x-river_x(center.y))<radius+180: continue
		var close := false
		for site in sites:
			if site.rect.grow(radius+100).has_point(center): close=true; break
		for feature in features:
			if center.distance_to(feature.p)<radius+feature.radius+90: close=true; break
		if close: continue
		var poly := PackedVector2Array()
		for j in 18:
			var angle := TAU*j/18.0
			poly.append(center+Vector2(cos(angle),sin(angle))*radius*terrain_rng.randf_range(0.8,1.15))
		features.append({"p":center,"radius":radius,"polygon":poly,"kind":"lake" if features.size()%3==0 else "cliff"})
	for wall in walls:
		for x in range(int(wall.position.x/200)-1,int(wall.end.x/200)+2):
			for y in range(int(wall.position.y/200)-1,int(wall.end.y/200)+2):
				var key := Vector2i(x,y)
				if not wall_cells.has(key): wall_cells[key]=[]
				wall_cells[key].append(wall)
	for i in 600:
		var pos := Vector2(rng.randf_range(100,SIZE.x-100),rng.randf_range(100,SIZE.y-100))
		if blocked(pos,60) or near_road(pos,100): continue
		var close := false
		for site in sites:
			if site.rect.grow(110).has_point(pos): close=true; break
		if close: continue
		var biome := biome_at(pos)
		var kind: int=[1,3,2,1,4,5][biome]
		decor.append({"p":pos,"type":kind,"size":rng.randf_range(95,175),"landmark":false})
	indexed_wall_count=walls.size()
	# One sparse cache per biome, outside every habitat. Keep caches near the
	# connected road network so a random lake or cliff cannot strand supplies.
	var cache_rng := RandomNumberGenerator.new()
	cache_rng.seed=value+1307
	for biome in WILDERNESS_CHESTS:
		for attempt in 2500:
			var at := Vector2(cache_rng.randf_range(400,SIZE.x-400),cache_rng.randf_range(400,SIZE.y-400)).snapped(Vector2(40,40))
			if biome_at(at)!=biome or blocked(at,45) or not near_road(at,100): continue
			var close := false
			for site in sites:
				if site.rect.grow(220).has_point(at): close=true; break
			for chest in chests:
				if chest.p.distance_to(at)<700: close=true; break
			if close: continue
			chests.append({"p":at,"key":"container","items":[],"open":false,"searched":0,"bonus":false,"class":1,"cache_tier":CACHE_TIERS[biome],"title":"野外遗落物资箱 · %d档" % (CACHE_TIERS[biome]+1)})
			break

static func river_x(y: float) -> float:
	return 3200+sin(y/610.0)*170

func biome_at(pos: Vector2) -> int:
	for i in regions.size():
		if Geometry2D.is_point_in_polygon(pos,regions[i].polygon): return i
	return 0

func near_road(pos: Vector2, distance: float) -> bool:
	for road in roads:
		for i in range(road.size()-1):
			if Geometry2D.get_closest_point_to_segment(pos,road[i],road[i+1]).distance_to(pos)<distance: return true
	return false

func blocked(pos: Vector2, radius: float = 15.0) -> bool:
	if pos.x<40+radius or pos.y<40+radius or pos.x>SIZE.x-40-radius or pos.y>SIZE.y-40-radius: return true
	if not coast.is_empty() and not Geometry2D.is_point_in_polygon(pos,coast): return true
	for feature in features:
		if pos.distance_to(feature.p)>feature.radius*1.2+radius: continue
		if Geometry2D.is_point_in_polygon(pos,feature.polygon): return true
		for i in feature.polygon.size():
			if Geometry2D.get_closest_point_to_segment(pos,feature.polygon[i],feature.polygon[(i+1)%feature.polygon.size()]).distance_to(pos)<radius: return true
	if absf(pos.x-river_x(pos.y))<105+radius:
		var crossing := false
		for bridge in bridges:
			if bridge.grow(-radius).has_point(pos): crossing=true; break
		if not crossing: return true
	# Keep the authoritative wall list mutable for combat arenas and tests.
	if not walls.is_empty():
		for wall in (wall_cells.get(Vector2i(pos/200),[]) if walls.size()==indexed_wall_count else walls):
			if wall.grow(radius).has_point(pos): return true
	return false

func move(from: Vector2, velocity: Vector2, radius: float = 15.0) -> Vector2:
	var result := from
	var steps := maxi(1,int(ceil(velocity.length()/9.0)))
	var step := velocity/steps
	for i in steps:
		var x := result+Vector2(step.x,0)
		if not blocked(x,radius): result=x
		var y := result+Vector2(0,step.y)
		if not blocked(y,radius): result=y
	return result

func clear_line(a: Vector2,b: Vector2) -> bool:
	var steps := maxi(1,int(a.distance_to(b)/12.0))
	for i in range(1,steps+1):
		if blocked(a.lerp(b,float(i)/steps),2): return false
	return true
