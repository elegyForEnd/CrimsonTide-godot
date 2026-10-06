extends SceneTree

const Map = preload("res://scripts/rogue_map.gd")
var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for f in 5:
		for kind in ["shop","talent","treasure","a6","a7","curse","event","forge","gamble","mirror"]:
			var room: String="combat" if kind.begins_with("a") else kind
			var area: int=2 if kind=="a6" else 4
			var map=Map.new(); map.generate(1729); map.configure(f,area,room=="combat",room)
			var key: String=Map.region_key(f,area,room)
			var path: String=Map.texture_path(key)
			check(path.ends_with("-smooth-night-v2-3x.png") or path.ends_with("-flat-night-v7-3x.png"),"ComfyUI 3x artwork selected: "+key)
			check(key=="f%d-%s" % [f+1,kind],"Dedicated artwork for each room kind: "+key)
			var texture: Texture2D=load(path)
			# Native generated panoramas vary slightly in pixel dimensions (up to 2%).
			check(texture!=null and absf(float(texture.get_width())/texture.get_height()-3.0)<.06,"Original panoramic proportions: "+key)
			check(texture!=null and texture.get_width()>=6400 and texture.get_height()>=2100,"Full 3x resolution imported: "+key)
			var peer=Map.new(); peer.generate(1729); peer.configure(f,area,room=="combat",room)
			check(peer.floor_polygon==map.floor_polygon,"Identical peer boundary: "+key)
			check(not map.blocked(Vector2(330,map.lane_center(330)),20),"Entrance clear: "+key)
			check(map.blocked(Vector2(map.width*.5,map.extent.y*.93),20),"Foreground excluded: "+key)
			for prop in map.obstacles: check(map.footprint_on_ground(prop.p,prop.radius),"Prop on road: "+key)
			if room!="combat": check(map.obstacles.is_empty() and map.terrain_hazards.is_empty(),"Safe room has no hazards")
			for exit_index in 2:
				check(not map.blocked(map.exit_position(exit_index),25),"Exit clear: "+key)
				var at := Vector2(map.width*.70,map.lane_center(map.width*.70))
				var points: Array=[]
				if exit_index==0:
					for x in [.75,.80,.85,.90,.95]: points.append(Vector2(map.width*x,map.lane_center(map.width*x)))
				else:
					var b: Array=map.region.branch
					points.append(map.uv_point([b[0][0],(b[0][1]+b[-1][1])/2]))
					for i in range(1,5): points.append(map.uv_point([b[i][0],(b[i][1]+b[11-i][1])/2]))
				points.append(map.exit_position(exit_index))
				for waypoint in points:
					at=map.move(at,waypoint-at,20)
					check(at.distance_to(waypoint)<1,"Fork continuously walkable: "+key)
	print("SMOOTH MAPS ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
