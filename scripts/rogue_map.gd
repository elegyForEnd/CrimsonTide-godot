extends Ruins

var floor_polygon := PackedVector2Array()
var top_edge := PackedVector2Array()
var bottom_edge := PackedVector2Array()
var obstacles: Array=[]
var terrain_hazards: Array=[]
var width := 3600.0
var layout := 0
var fork_polygons: Array[PackedVector2Array]=[]
var fork_start := 0.0
# Profiles are measured from the finished artwork in normalized coordinates.
const PROFILE_X := [.06,.20,.38,.55,.70,.80]
var ground_top: Array=[]
var ground_lower: Array=[]
var ground_bottom := .82
var region: Dictionary={}
var ground_regions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/rogue/regions/ground-manifest.json"))

func ground_y(uv_y: float) -> float:
	return uv_y*extent.y

func ground_limits(x: float) -> Vector2:
	var uv_x := x/width
	for i in PROFILE_X.size()-1:
		if uv_x<=PROFILE_X[i+1]:
			var t := clampf(inverse_lerp(PROFILE_X[i],PROFILE_X[i+1],uv_x),0,1)
			return Vector2(ground_y(lerpf(ground_top[i],ground_top[i+1],t)),ground_y(lerpf(ground_lower[i],ground_lower[i+1],t)))
	var previous := Vector3(.80,ground_top[-1],ground_lower[-1])
	for sample in region.right_profile:
		var current := Vector3(sample[0],sample[1],sample[2])
		if uv_x<=current.x:
			var t := clampf(inverse_lerp(previous.x,current.x,uv_x),0,1)
			return Vector2(ground_y(lerpf(previous.y,current.y,t)),ground_y(lerpf(previous.z,current.z,t)))
		previous=current
	return Vector2(ground_y(previous.y),ground_y(previous.z))

func lane_center(x: float) -> float:
	var bounds := ground_limits(x)
	return (bounds.x+bounds.y)*.5

func generate(value: int) -> void:
	map_seed=value
	interior=true
	extent=Vector2(width,width/3.0)

func uv_point(at: Array) -> Vector2:
	return Vector2(float(at[0])*width,ground_y(float(at[1])))

static func region_key(floor_index: int, area: int, room: String = "") -> String:
	if room in ["shop","treasure","talent"]:
		return "f%d-%s" % [floor_index+1,room]
	var artwork_area: int=area if room.is_empty() and area<=5 else [1,6,2,7,3,4,5][clampi(area-1,0,6)]
	return "f%d-a%d" % [floor_index+1,artwork_area]

static func texture_path(key: String) -> String:
	var suffix := "-original-wide-3x.png"
	if key.ends_with("-a6") or key.ends_with("-a7"): suffix="-seven-night-v1.png"
	elif not "-a" in key: suffix="-safe-night-v1.png"
	if suffix!="-original-wide-3x.png":
		var hd_path := "res://assets/rogue/regions/"+key+suffix.trim_suffix(".png")+"-3x.png"
		if ResourceLoader.exists(hd_path): return hd_path
	return "res://assets/rogue/regions/"+key+suffix

func configure(floor_index: int, area: int, long_room: bool, room: String = "") -> void:
	obstacles.clear()
	terrain_hazards.clear()
	fork_polygons.clear()
	width=3600.0 if long_room else 3000.0
	extent=Vector2(width,width/3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed=map_seed*7919+area*104729
	layout=area-1
	region=ground_regions[region_key(floor_index,area,room)]
	ground_top=region.top
	ground_lower=region.bottom
	ground_bottom=ground_lower.max()
	fork_start=width*.8
	var top: Array=[]
	var bottom: Array=[]
	for i in PROFILE_X.size():
		top.append(Vector2(width*PROFILE_X[i],ground_y(ground_top[i])))
		bottom.append(Vector2(width*PROFILE_X[i],ground_y(ground_lower[i])))
	for sample in region.right_profile:
		top.append(uv_point([sample[0],sample[1]]))
		bottom.append(uv_point([sample[0],sample[2]]))
	top_edge=PackedVector2Array(top)
	bottom_edge=PackedVector2Array(bottom)
	bottom.reverse()
	floor_polygon=PackedVector2Array(top+bottom)
	var diagonal := PackedVector2Array()
	for point in region.branch: diagonal.append(uv_point(point))
	fork_polygons.append(diagonal)
	var joined: Array[PackedVector2Array]=Geometry2D.merge_polygons(floor_polygon,diagonal)
	assert(joined.size()==1,"Both level paths must join the same floor")
	floor_polygon=joined[0]
	if not long_room: return
	for i in 6:
		var x: float=width*(.20+i*.095)+rng.randf_range(-40,40)
		var radius := Vector2(rng.randf_range(32,49),rng.randf_range(19,22))
		var bounds := ground_limits(x)
		var y: float=bounds.x+radius.y+35 if (i+layout)%2==0 else bounds.y-radius.y-35
		var at := Vector2(x,y)
		if footprint_on_ground(at,radius+Vector2(2,2)):
			obstacles.append({"p":at,"radius":radius,"icon":floor_index*2+(i%2)})
	if floor_index==1:
		for i in 3:
			var x := width*(.28+i*.18)+rng.randf_range(-40,40)
			var at := Vector2(x,lane_center(x))
			terrain_hazards.append({"p":at,"radius":Vector2(82,34),"damage":14.0,"kind":"lava"})

func exit_position(index: int) -> Vector2:
	return uv_point(region.exits[index])

func inside_floor(pos: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(pos,floor_polygon)

func footprint_on_ground(pos: Vector2, radius: Vector2) -> bool:
	for i in 32:
		if not inside_floor(pos+Vector2.from_angle(i*TAU/32)*radius): return false
	return true

func blocked(pos: Vector2, radius: float = 15.0) -> bool:
	if not inside_floor(pos): return true
	# Circle-to-edge distance matches the rendered edge, including diagonal corners.
	for i in floor_polygon.size():
		var edge_point := Geometry2D.get_closest_point_to_segment(pos,floor_polygon[i],floor_polygon[(i+1)%floor_polygon.size()])
		if pos.distance_squared_to(edge_point)<radius*radius: return true
	for prop in obstacles:
		var d: Vector2=(pos-prop.p)/(prop.radius+Vector2.ONE*radius)
		if d.length_squared()<1.0: return true
	return false

func move(from: Vector2, velocity: Vector2, radius: float = 15.0) -> Vector2:
	# Advance only to valid positions. Contact rejects the remaining movement,
	# without projecting, sliding, or moving the actor back toward a safe point.
	var result := from
	var steps := maxi(1,int(ceil(velocity.length()/4.0)))
	var step := velocity/steps
	for i in steps:
		var candidate := result+step
		if blocked(candidate,radius): break
		result=candidate
	return result

func safe_point(at: Vector2, clearance: float = 20.0) -> Vector2:
	if not blocked(at,clearance): return at
	for ring in range(1,20):
		for i in 16:
			var candidate: Vector2=at+Vector2.from_angle(i*TAU/16)*ring*14
			if not blocked(candidate,clearance): return candidate
	return Vector2(330,lane_center(330))

func on_lava(pos: Vector2) -> bool:
	for pool in terrain_hazards:
		var d: Vector2=(pos-pool.p)/pool.radius
		if d.length_squared()<1.0: return true
	return false


func backdrop_quads() -> Array:
	# Uniform UVs preserve the generated camera perspective and image proportions.
	var points := PackedVector2Array([Vector2.ZERO,Vector2(width,0),extent,Vector2(0,extent.y)])
	return [{"points":points,"uv":PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)])}]
