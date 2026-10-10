extends RefCounted
## Ground, stairs and collision are authored together.
var act := 1
var stage := 0
var layout := "field"
var extent := Vector2(4800,4800)
var origin := Vector2.ZERO
var indoor := false
var spawn := Vector2(2400,320)
var waypoint := Vector2(2400,640)
var anchors: Array=[]
var side_anchors: Array=[]
var trails: Array=[]
var props: Array=[]
var obstacles: Array[Rect2]=[]
var rooms: Array[Rect2]=[]
var buildings: Array=[]
var stairs: Array=[]
var water: Array[Rect2]=[]
var chests: Array=[]
var ports: Array[Vector2]=[]
var noise := FastNoiseLite.new()
var npc_at: Array=[]
var shorelines: Array[PackedVector2Array]=[]
var terrain_samples: Dictionary={}
var dressing: Array=[]
var floor_polygon := PackedVector2Array()
var structural_obstacles: Array[Rect2]=[]
const Dressing=preload("res://scripts/story_set_dressing.gd")
const NPC_AT := [Vector2(850,580),Vector2(1500,590),Vector2(630,1020),Vector2(1640,1040),Vector2(730,1430),Vector2(1530,1440)]

func build(a: int, s: int, shape: String, inside: bool) -> void:
	act=a; stage=s; layout=shape; indoor=inside
	noise.seed=a*301+s*71; noise.frequency=0.0011; noise.fractal_octaves=3
	load_authored_terrain()
	if s==0:
		extent=Vector2(2200,2000); spawn=Vector2(1100,850); waypoint=Vector2(1100,1150)
		npc_at=NPC_AT.duplicate()
		if a==1: npc_at=[Vector2(720,410),Vector2(1570,470),Vector2(600,960),Vector2(1590,1040),Vector2(650,1460),Vector2(1530,1570)]
		if a==2: npc_at=[Vector2(820,440),Vector2(1540,490),Vector2(520,980),Vector2(1690,1030),Vector2(770,1500),Vector2(1530,1460)]
		elif a==3: npc_at=[Vector2(760,540),Vector2(1400,490),Vector2(490,1020),Vector2(1750,1170),Vector2(790,1500),Vector2(1580,1480)]
		elif a==4: npc_at=[Vector2(820,530),Vector2(1560,510),Vector2(530,1070),Vector2(1670,1040),Vector2(750,1530),Vector2(1460,1450)]
		elif a==5: npc_at=[Vector2(880,500),Vector2(1430,570),Vector2(770,1010),Vector2(1640,1050),Vector2(710,1450),Vector2(1480,1460)]
		elif a==6: npc_at=[Vector2(780,520),Vector2(1500,560),Vector2(650,990),Vector2(1650,1060),Vector2(730,1540),Vector2(1560,1460)]
		trails=[PackedVector2Array([Vector2(1100,150),Vector2(1100,1000),Vector2(1100,2000)]),PackedVector2Array([Vector2(430,950),Vector2(1750,950)]),PackedVector2Array([Vector2(520,1410),Vector2(1700,1410)])]
		for i in 6:
			var at: Vector2=npc_at[i]+Vector2(-210 if i%2==0 else 210,-100)
			var size := Vector2(260+30*(i%3),200+30*(i%2))
			buildings.append({"rect":Rect2(at-size*.5,size),"style":a,"height":180.0+25*(i%3),"door":at+Vector2(0,size.y*.5),"role":i})
			add_prop("halloween/lantern_standing",npc_at[i]+Vector2(58,15),Vector3(20,72,20))
		ports=[Vector2(1100,2000)]
		if a in [1,6]:
			for x in [220,650,1550,1980]: add_prop("dungeon/wall_broken",Vector2(x,1810),Vector3(280,110,65),true)
		elif a==2:
			for at in [Vector2(400,300),Vector2(1820,320)]: add_prop("dungeon/pillar_decorated",at,Vector3(100,300,100),true)
		elif a==3:
			for at in [Vector2(170,320),Vector2(1890,260)]: add_prop("medieval/rock_single_B",at,Vector3(230,280,190),true)
		elif a==4:
			for at in [Vector2(220,290),Vector2(1850,240)]: add_prop("nature/tree_3",at,Vector3(230,390,210),true)
		elif a==5: water=[Rect2(0,0,240,2000)]
		camp_landmarks()
		if a==1:
			for b in buildings:
				var role: int=b.role
				var key: String=["cargo","canopy","anvil","bookshelf","cargo","handcart"][role]
				var at: Vector2=b.rect.get_center()+Vector2(-b.rect.size.x*.5-65,35)
				add_prop("kit/"+key,at,Vector3(90,120,100),true)
				if role in [2,4,5]: add_prop("kit/rope_coil",b.door+Vector2(-115,70),Vector3(60,15,60))
				if role==2: add_prop("kit/tool_rack",b.rect.get_center()+Vector2(105,-35),Vector3(100,125,35),true)
		load_authored_terrain()
		dressing=Dressing.entries(self)
		return
	anchors=[Vector2(1700,1700),Vector2(3100,2850),Vector2(2400,4080)]
	side_anchors=[Vector2(900,1200),Vector2(3900,2450),Vector2(900,3800)]
	if a==1 and s==4: anchors=[Vector2(2400,3150),Vector2(3450,3900),Vector2(3450,3900)]
	if indoor:
		build_dungeon()
		if a==1 and s==7:
			var cave: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/story-cave-footprint.json"))
			for p in cave.boundary: floor_polygon.append(Vector2(p[0],p[1]))
		load_authored_terrain(); dressing=Dressing.entries(self); return
	var bend := -1.0 if (a+s)%2==0 else 1.0
	trails=[PackedVector2Array([spawn,Vector2(2400+bend*450,980),anchors[0],Vector2(2400-bend*600,2200),anchors[1],Vector2(2400+bend*350,3500),anchors[2],Vector2(2400,4800)]),PackedVector2Array([anchors[0],side_anchors[0],side_anchors[2],anchors[2]]),PackedVector2Array([anchors[0],Vector2(3800,1600),side_anchors[1],anchors[1]])]
	var shift := Vector2.ZERO if a==1 and s==1 else Vector2(float((a+s)%3-1)*260,float(s%3)*180)
	stairs.append({"rect":Rect2(Vector2(3230,1390)+shift,Vector2(300,420)),"top":125.0+float((a+s)%3)*22,"north":true,"terrace":Rect2(Vector2(2850,690)+shift,Vector2(1060,700))})
	trails.append(PackedVector2Array([anchors[0],Vector2(3380,1920)+shift,Vector2(3380,1000)+shift]))
	chests.append(Vector2(3360,1020)+shift)
	if layout in ["bridge","coast","canal"]:
		if layout=="bridge":
			water=[Rect2(0,2530,2130,450),Rect2(2670,2530,2130,450)]
			if a!=1: anchors[1]=Vector2(2400,2940)
			trails.append(PackedVector2Array([Vector2(2400,2200),Vector2(2400,3300)]))
			for x in [2130,2670]: add_prop("dungeon/barrier",Vector2(x,2755),Vector3(22,85,480),true)
		else: water=[Rect2(0,0,440,4800)]
	if layout in ["street","courtyard","village","garden"]:
		for i in 5:
			var at := Vector2(560 if i%2==0 else 4240,650+int(i/2)*1450)
			buildings.append({"rect":Rect2(at-Vector2(210,180),Vector2(420,360)),"style":a,"height":320.0,"door":at+Vector2(0,180)})
	chests.append(side_anchors[2]+Vector2(120,0))
	var rng := RandomNumberGenerator.new(); rng.seed=a*1000+s
	for i in 230:
		var at := Vector2(rng.randf_range(100,4700),rng.randf_range(100,4700))
		if not clear_placement(at,160): continue
		var kind := i%9
		var key := "nature/tree_1" if kind<5 else "medieval/rock_single_B" if kind<7 else "halloween/tree_dead_medium" if kind==7 else "dungeon/rubble_large"
		if a in [2,6] and kind<5: key="halloween/tree_dead_large"
		if a==5 and kind<5: key="medieval/waterplant_A"
		var h := rng.randf_range(260,420) if kind<5 else rng.randf_range(70,180)
		if key=="medieval/waterplant_A": h=rng.randf_range(60,125)
		add_prop(key,at,Vector3(h*.65,h,h*.55),true,rng.randf()*TAU)
	if a==1 and s==1: opening_details()
	load_authored_terrain()
	dressing=Dressing.entries(self)

func load_authored_terrain() -> void:
	if act!=1 or stage not in [0,1,7]: return
	var path := "res://resources/story-terrain-%d.json" % stage
	if not FileAccess.file_exists(path): return
	terrain_samples=JSON.parse_string(FileAccess.get_file_as_string(path))
	shorelines.clear()
	for points in terrain_samples.get("shorelines",[]):
		var poly := PackedVector2Array()
		for p in points: poly.append(Vector2(p[0],p[1]))
		shorelines.append(poly)

func authored_height(p: Vector2) -> float:
	var spacing: float=terrain_samples.spacing
	var width: int=terrain_samples.width
	var x := clampf(p.x/spacing,0,width-1); var y := clampf(p.y/spacing,0,int(terrain_samples.depth)-1)
	var ix := mini(int(x),width-2); var iy := mini(int(y),int(terrain_samples.depth)-2)
	var values: Array=terrain_samples.heights
	return lerpf(lerpf(float(values[iy*width+ix]),float(values[iy*width+ix+1]),x-ix),lerpf(float(values[(iy+1)*width+ix]),float(values[(iy+1)*width+ix+1]),x-ix),y-iy)

func submerged(p: Vector2) -> bool:
	for poly in shorelines:
		if Geometry2D.is_point_in_polygon(p,poly): return true
	for rect in water:
		if rect.has_point(p): return true
	return false

func opening_details() -> void:
	for p in [Vector2(760,1510),Vector2(660,1690),Vector2(950,1850),Vector2(2100,1200),Vector2(2350,1550),Vector2(2210,1740),Vector2(3350,2140),Vector2(3580,2380),Vector2(3300,2540)]:
		if not submerged(p): add_prop("nature/tree_1",p,Vector3(240,420,240),true,p.x*.013)
	# Roadside landmarks share the same collision authority as the other props.
	for p in [Vector2(1420,820),Vector2(1280,2420),Vector2(3510,3290)]:
		add_prop("story/rubble",p,Vector3(140,60,90))
		for offset in [-140,140]:
			add_prop("story/pier",p+Vector2(offset,-75),Vector3(40,115 if offset<0 else 180,40),true)
	for y in [650,850,1050]: add_prop("story/fence",Vector2(2810,y),Vector3(14,75,160),true)
	for p in [Vector2(1200,700),Vector2(3650,3500),Vector2(880,3000)]: add_prop("kit/handcart",p,Vector3(110,100,150),true)
	for p in [Vector2(1240,2280),Vector2(1060,2300)]: add_prop("kit/tool_rack",p,Vector3(100,125,45),true)
	add_prop("kit/arcade_broken",Vector2(1350,2450),Vector3(200,230,140),true)
	for p in [Vector2(720,1150),Vector2(610,3540),Vector2(4040,2500)]: add_prop("kit/tree_root",p,Vector3(120,30,120))

func camp_landmarks() -> void:
	match act:
		1:
			add_prop("medieval/building_castle_red",Vector2(1110,150),Vector3(520,540,300),true)
			for at in [Vector2(210,180),Vector2(1980,180)]: add_prop("medieval/building_tower_A_red",at,Vector3(180,410,170),true)
		2:
			for x in [500,800,1100,1400,1700]: add_prop("dungeon/wall_arched",Vector2(x,190),Vector3(290,310,45),true)
			add_prop("halloween/shrine_candles",Vector2(1840,350),Vector3(160,140,100),true)
		3:
			add_prop("medieval/building_mine_red",Vector2(1110,150),Vector3(450,380,270),true)
			for at in [Vector2(320,1430),Vector2(1880,600)]: add_prop("medieval/tent",at,Vector3(160,160,130),true)
		4:
			for at in [Vector2(350,250),Vector2(1900,250),Vector2(280,1510),Vector2(1860,1690)]: add_prop("nature/tree_3",at,Vector3(200,360,190),true)
			add_prop("halloween/shrine_candles",Vector2(1110,150),Vector3(310,260,140),true)
		5:
			add_prop("medieval/building_tower_A_red",Vector2(1920,230),Vector3(200,600,180),true)
		6:
			for at in [Vector2(400,190),Vector2(1850,220)]: add_prop("dungeon/wall_broken",at,Vector3(340,240,65),true)
			add_prop("halloween/crypt",Vector2(1110,150),Vector3(420,420,240),true)

func build_dungeon() -> void:
	if layout=="castle":
		build_castle(); return
	var shift := 240.0 if stage%2==0 else -240.0
	rooms=[Rect2(1950,0,900,850),Rect2(1950,700,900,850),Rect2(610+shift,1140,3000,760),Rect2(700+shift,1750,1000,1640),Rect2(1550+shift,2760,2050,630),Rect2(2050,3220,850,1580),Rect2(2870+shift,1550,650,1510),Rect2(600+shift,3320,1100,960)]
	anchors=[Vector2(1200+shift,1530),Vector2(3050+shift,2550),Vector2(2460,4170)]
	side_anchors=[Vector2(1000+shift,2300),Vector2(1130+shift,3750),Vector2(2900+shift,3100)]
	if layout in ["cathedral","chapel"]:
		rooms=[Rect2(1900,0,1000,1200),Rect2(1550,1100,1700,2500),Rect2(450,1500,3900,1000),Rect2(650,2850,1000,700),Rect2(3150,2850,1000,700),Rect2(1900,3500,1100,1300)]
		anchors=[Vector2(1050,1950),Vector2(3620,1950),Vector2(2460,4170)]
		side_anchors=[Vector2(1100,3200),Vector2(3600,3200),Vector2(2300,2800)]
	elif layout=="mine":
		rooms=[Rect2(2100,0,600,1350),Rect2(850,1050,1850,650),Rect2(750,1550,700,1350),Rect2(750,2650,2950,650),Rect2(3050,1600,650,1400),Rect2(2300,1600,1000,650),Rect2(2100,3150,750,1100),Rect2(1700,3700,1900,1100)]
		anchors=[Vector2(1100,1350),Vector2(3350,2550),Vector2(2460,4170)]
		side_anchors=[Vector2(1100,2300),Vector2(2700,1940),Vector2(3300,4210)]
	elif layout=="crypt":
		rooms=[Rect2(2100,0,600,4800),Rect2(550,1000,3550,600),Rect2(550,2500,3550,600),Rect2(550,3900,3550,800),Rect2(550,1000,850,1400),Rect2(3250,2500,850,1350)]
		anchors=[Vector2(1000,1300),Vector2(3680,2840),Vector2(2460,4170)]
		side_anchors=[Vector2(1100,2080),Vector2(3700,3550),Vector2(1000,4260)]
	elif layout=="library":
		rooms=[Rect2(2100,0,700,1300),Rect2(600,900,3650,850),Rect2(650,1650,650,1700),Rect2(1250,2600,2450,800),Rect2(3050,1700,650,1000),Rect2(2000,3250,950,1550),Rect2(600,3350,1450,900)]
		anchors=[Vector2(1100,1350),Vector2(3370,2300),Vector2(2460,4170)]
		side_anchors=[Vector2(1000,2280),Vector2(1000,3800),Vector2(2300,3100)]
	stairs.append({"rect":Rect2(2180,3500,440,420),"top":105.0,"north":false,"terrace":Rect2(2100,3920,750,880)})
	trails=[PackedVector2Array([spawn,Vector2(2400,1530),anchors[0],Vector2(1200+shift,3030),Vector2(3050+shift,3030),anchors[1],Vector2(3050+shift,1530),Vector2(2400,1530)]),PackedVector2Array([Vector2(2400,3030),anchors[2]])]
	for at in [Vector2(2040,1100),Vector2(2760,1100),Vector2(2100,4040),Vector2(2820,4040)]: add_prop("dungeon/pillar_decorated",at,Vector3(100,320,100),true)
	chests=[side_anchors[1]+Vector2(130,0)]
	if layout=="library":
		for y in [1030,1650,2750,3270]:
			for x in [1500,1900,2300,2700]: add_prop("dungeon/shelf_small_candles",Vector2(x,y),Vector3(150,160,55),true)
	dungeon_furniture()

func build_castle() -> void:
	# Gate court, great hall and two wings, connected by an encircling gallery.
	extent=Vector2(6400,6400); spawn=Vector2(3200,350); waypoint=Vector2(3200,920)
	rooms=[Rect2(2700,0,1000,1600),Rect2(1500,1300,3400,1700),Rect2(2500,2750,1400,2850),Rect2(650,2100,1100,2600),Rect2(4650,2100,1100,2600),Rect2(650,4100,5100,650),Rect2(1750,2050,2900,500),Rect2(2450,5200,1500,1200)]
	anchors=[Vector2(1250,2800),Vector2(5200,3300),Vector2(3200,5820)]
	side_anchors=[Vector2(1200,4450),Vector2(5250,4450),Vector2(3200,3400)]
	stairs=[{"rect":Rect2(2920,4780,560,420),"top":120.0,"north":false,"terrace":Rect2(2450,5200,1500,1200)}]
	trails=[PackedVector2Array([spawn,Vector2(3200,2100),Vector2(1200,2300),Vector2(1200,4450),Vector2(5200,4450),Vector2(5200,2300),Vector2(3200,2300),Vector2(3200,5820)])]
	chests=[Vector2(1200,4600),Vector2(5250,4600),Vector2(3450,5800)]
	# Footprints match the authored tower cores, vault piers and gateway piers.
	for p in [Vector2(1570,1410),Vector2(4830,1410),Vector2(710,2180),Vector2(5690,2180),Vector2(2510,5300),Vector2(3890,5300)]: structural_obstacles.append(Rect2(p-Vector2.ONE*110,Vector2.ONE*220))
	for y in [2950,3750,4400]:
		for x in [3013,3387]: structural_obstacles.append(Rect2(x-22,y-22,44,44))
	for x in [2990,3410]: structural_obstacles.append(Rect2(x-58,1250-43,116,86))

func dungeon_furniture() -> void:
	var items: Array=[]
	if layout in ["chapel","cathedral"]:
		for y in [1150,1580,2450,2850,3200]:
			for x in [1750,3020]:
				items.append({"key":"halloween/bench_decorated","p":Vector2(x,y),"size":Vector3(170,70,65)})
		items.append({"key":"dungeon/table_long_decorated_A","p":anchors[-1]+Vector2(0,-300),"size":Vector3(190,90,80)})
	elif layout=="crypt":
		for y in [1150,2700,4050]:
			for x in [710,1320,3300,3970]: items.append({"key":"halloween/crypt","p":Vector2(x,y),"size":Vector3(145,95,75)})
	elif layout=="library":
		for p in [Vector2(850,1050),Vector2(3750,1150),Vector2(1500,2800),Vector2(2800,3150)]: items.append({"key":"dungeon/table_long_decorated_A","p":p,"size":Vector3(145,70,75)})
	for item in items:
		if not walkable(item.p,70): continue
		var near := false
		for p in anchors+side_anchors+chests+[waypoint]:
			if p.distance_to(item.p)<160: near=true; break
		if not near: add_prop(item.key,item.p,item.size,true)

func add_prop(key: String, at: Vector2, size: Vector3, blocking: bool = false, angle: float = 0.0) -> void:
	if (key.begins_with("nature/tree") or "tree_dead" in key or key=="kit/woodland_tree") and size.y<=450: blocking=false
	props.append({"key":key,"p":at,"size":size,"angle":angle,"blocking":blocking})
	if blocking: obstacles.append(Rect2(at-Vector2(size.x,size.z)*.32,Vector2(size.x,size.z)*.64))

func path_distance(p: Vector2) -> float:
	var best := INF
	for trail in trails:
		for i in range(trail.size()-1): best=minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,trail[i],trail[i+1])))
	return best

func clear_placement(p: Vector2, margin: float) -> bool:
	if submerged(p): return false
	for poly in shorelines:
		for i in poly.size():
			if Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()]).distance_to(p)<margin+40: return false
	if path_distance(p)<margin+110: return false
	for at in anchors+side_anchors+[waypoint,spawn]+chests+ports:
		if p.distance_to(at)<margin+160: return false
	for item in stairs:
		if item.rect.grow(margin).has_point(p) or item.terrace.grow(margin).has_point(p): return false
	for item in buildings:
		if item.rect.grow(margin+130).has_point(p): return false
	for rect in water:
		if rect.grow(margin).has_point(p): return false
	return true

func height_at(p: Vector2) -> float:
	# The 6 cm foundation is the actual interior floor, including the threshold.
	if act==1 and stage==0:
		for building in buildings:
			if building.rect.has_point(p): return 6.0
	for item in stairs:
		if item.terrace.has_point(p): return item.top
		if item.rect.has_point(p):
			var progress: float=(p.y-item.rect.position.y)/item.rect.size.y
			return item.top*(1.0-progress if item.north else progress)
	return base_height_at(p)

func base_height_at(p: Vector2) -> float:
	if not terrain_samples.is_empty(): return authored_height(p)
	if indoor or stage==0: return 0.0
	var edge := minf(minf(p.x,extent.x-p.x),minf(p.y,extent.y-p.y))
	return noise.get_noise_2d(p.x,p.y)*48.0*smoothstep(0,350,edge)*smoothstep(80,420,path_distance(p))

func walkable(p: Vector2, radius: float = 24.0) -> bool:
	if not Rect2(Vector2.ZERO,extent).has_point(p): return false
	if indoor:
		if not floor_contains(p,radius): return false
	for rect in obstacles+water+structural_obstacles:
		if rect.grow(radius).has_point(p): return false
	for item in dressing:
		if item.has("footprint") and item.rect.grow(radius).has_point(p): return false
	for poly in shorelines:
		if Geometry2D.is_point_in_polygon(p,poly): return false
		for i in poly.size():
			if Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()]).distance_to(p)<radius: return false
	for item in buildings:
		for wall in building_walls(item.rect):
			if wall.grow(radius).has_point(p): return false
	for item in stairs:
		var r: Rect2=item.terrace
		if r.grow(radius).has_point(p) and not r.grow(-radius).has_point(p) and not item.rect.grow(radius+6).has_point(p): return false
	return true

func floor_contains(p: Vector2, radius: float = 0.0) -> bool:
	if not floor_polygon.is_empty():
		if not Geometry2D.is_point_in_polygon(p,floor_polygon): return false
		for i in floor_polygon.size():
			if Geometry2D.get_closest_point_to_segment(p,floor_polygon[i],floor_polygon[(i+1)%floor_polygon.size()]).distance_to(p)<radius: return false
		return true
	for room in rooms:
		if room.grow(-radius).has_point(p): return true
	return false

func building_walls(r: Rect2) -> Array[Rect2]:
	return [Rect2(r.position,Vector2(r.size.x,28)),Rect2(r.position.x,r.position.y,28,r.size.y),Rect2(r.end.x-28,r.position.y,28,r.size.y),Rect2(r.position.x,r.end.y-28,r.size.x*.5-55,28),Rect2(r.get_center().x+55,r.end.y-28,r.size.x*.5-55,28)]
