extends Control
var campaign
func _draw() -> void:
	if campaign==null: return
	var map=campaign.map
	var bounds := Rect2(map.regions[map.floors[0]].origin,map.regions[map.floors[0]].extent)
	for s in map.floors: bounds=bounds.merge(Rect2(map.regions[s].origin,map.regions[s].extent))
	var factor := minf(size.x/bounds.size.x,size.y/bounds.size.y)*.90
	var shift := size*.5-bounds.get_center()*factor
	for s in map.floors:
		var r=map.regions[s]
		var rect := Rect2(r.origin*factor+shift,r.extent*factor)
		draw_rect(rect,Color("252a2b")); draw_rect(rect,Color("555c5b"),false,1)
		if "%d:%d" % [map.act,s] in campaign.state.discovered:
			var name: String=campaign.act_data().camp if s==0 else campaign.act_data().maps[s-1].name
			draw_string(get_theme_default_font(),rect.position+Vector2(6,18),name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c7bba3"))
		var waypoint: Vector2=(r.origin+r.waypoint)*factor+shift
		if "%d:%d" % [map.act,s] in campaign.state.get("waypoints",[]): draw_circle(waypoint,5,Color("74c3c6"))
	for cell in campaign.explored:
		var parts: PackedStringArray=cell.split(":")
		if parts.size()!=4 or int(parts[0])!=map.act or int(parts[1])!=map.layer: continue
		var p := Vector2(int(parts[2])*240,int(parts[3])*240)
		var sector: int=map.region_at(p+Vector2.ONE*120)
		if sector<0: continue
		var r=map.regions[sector]
		var local: Vector2=p+Vector2.ONE*120-r.origin
		var inside: bool=not r.indoor or r.floor_contains(local)
		if inside: draw_rect(Rect2(p*factor+shift,Vector2.ONE*240*factor),Color("727669") if r.indoor else Color("5f6d58"))
		for trail in r.trails:
			for i in range(trail.size()-1):
				var a: Vector2=trail[i]+r.origin; var b: Vector2=trail[i+1]+r.origin
				var count := maxi(1,int(a.distance_to(b)/80))
				for j in count:
					var point: Vector2=a.lerp(b,float(j)/count)
					if Rect2(p,Vector2.ONE*240).has_point(point): draw_circle(point*factor+shift,1.5,Color("bea077"))
	for c in map.connectors:
		if map.layer==0: draw_line(c.a*factor+shift,c.b*factor+shift,Color("8d7a5e"),3,true)
	for door in map.entrances():
		if door.kind=="exit" or campaign.explored.has("%d:%d:%d:%d" % [map.act,map.layer,int(floor(door.p.x/240)),int(floor(door.p.y/240))]): draw_circle(door.p*factor+shift,5,Color("d9b978"))
	for node in campaign.objective_nodes(): draw_circle(node.p*factor+shift,4,Color("e0c389"))
	draw_circle(campaign.hero_at*factor+shift,6,Color("ef6d87"))
