extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	# Visible lower flagstone samples recorded during the 25-image audit.
	# Keep these independent of the collision manifest so an inward boundary
	# regression cannot silently pass by moving the expected point with it.
	var lower_samples := [
		[.785,.83,.81,.85,.80],
		[.81,.81,.79,.76,.82],
		[.78,.79,.79,.82,.80],
		[.78,.78,.81,.78,.81],
		[.86,.81,.85,.79,.86],
	]
	for floor_index in 5:
		for area in range(1,6):
			var audited=preload("res://scripts/rogue_map.gd").new()
			audited.generate(1729)
			audited.configure(floor_index,area,true)
			var expected := Vector2(audited.width*.55,audited.ground_y(lower_samples[floor_index][area-1]))
			var lane := Vector2(expected.x,audited.lane_center(expected.x))
			var walked: Vector2=audited.move(lane,expected-lane,15)
			check(walked.distance_to(expected)<1,"Audited lower paving reachable: f%d-a%d" % [floor_index+1,area])
	# First woodland room: the lower flagstones in the reported screenshot
	# must be reachable, while the foreground vegetation stays outside.
	var woodland=preload("res://scripts/rogue_map.gd").new()
	woodland.generate(1729)
	woodland.configure(0,1,true)
	var lower_flagstones := Vector2(woodland.width*.38,woodland.ground_y(.785))
	var start_on_lane := Vector2(lower_flagstones.x,woodland.lane_center(lower_flagstones.x))
	var reached: Vector2=woodland.move(start_on_lane,lower_flagstones-start_on_lane,15)
	check(reached.distance_to(lower_flagstones)<1,"Lower woodland flagstones are reachable")
	check(woodland.blocked(Vector2(lower_flagstones.x,woodland.ground_y(.825)),15),"Foreground foliage remains outside the road")
	for floor_index in 5:
		for area in range(1,6):
			for long_room in [false,true]:
				var map=preload("res://scripts/rogue_map.gd").new()
				map.generate(3162920)
				map.configure(floor_index,area,long_room)
				for x in range(330,int(minf(map.fork_start,map.fork_polygons[0][0].x))-100,100):
					var start := Vector2(x,map.lane_center(x))
					if map.blocked(start,15): continue
					var stopped: Vector2=map.move(start,Vector2(0,-map.extent.y),15)
					check(stopped.y>=map.ground_y(map.ground_top.min())+14,"Upward movement stops before background")
					check(not map.blocked(stopped,15),"Movement ends on valid ground")
					var down: Vector2=map.move(start,Vector2(0,map.extent.y),15)
					check(down.y<=map.ground_y(map.ground_lower.max())-14,"Downward movement stops before foreground scenery")
					check(not map.blocked(down,15),"Downward movement ends on ground")
				for prop in map.obstacles:
					for i in 32:
						var footprint: Vector2=prop.p+Vector2.from_angle(i*TAU/32)*prop.radius
						check(map.inside_floor(footprint),"Entire obstacle footprint stays on visible ground")
				# Flood the actual collision space to catch narrow bottlenecks caused
				# by props after tightening the ground bounds, including both forks.
				var step := 10
				var origin := Vector2(180,0)
				var start := Vector2i(roundi((330-origin.x)/step),roundi((map.lane_center(330)-origin.y)/step))
				var visited := {start:true}
				var queue: Array[Vector2i]=[start]
				var head := 0
				while head<queue.size():
					var cell: Vector2i=queue[head]
					head+=1
					for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
						var next: Vector2i=cell+direction
						if visited.has(next): continue
						var at: Vector2=origin+Vector2(next)*step
						if map.blocked(at,20): continue
						visited[next]=true
						queue.append(next)
				for index in 2:
					var reachable := false
					for cell in visited:
						if (origin+Vector2(cell)*step).distance_to(map.exit_position(index))<20: reachable=true; break
					check(reachable,"Ground route f%d a%d long=%s exit=%d" % [floor_index+1,area,long_room,index])
	print("ROGUE GROUND ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
