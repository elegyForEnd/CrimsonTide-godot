extends RefCounted
## Resolve the next physical entrance, rather than pointing through other floors.
var campaign
var target: Dictionary={}
var path := PackedVector2Array()
var grid := AStarGrid2D.new()
var grid_key := ""
var remaining := 0.0

func refresh(dt: float=1.0) -> void:
	remaining-=dt
	if remaining>0: return
	remaining=.4
	target=resolve(); path=PackedVector2Array()
	if target.is_empty(): return
	var signature: String=campaign.terrain().key+str(campaign.combat.barriers())+str(campaign.state.trial_task)
	if signature!=grid_key:
		grid_key=signature
		grid.region=Rect2i(-36,0,127,91); grid.cell_size=Vector2(20,20)
		grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES; grid.update()
		for y in range(0,91):
			for x in range(-36,91): grid.set_point_solid(Vector2i(x,y),not campaign.walkable(Vector2(x,y)*20))
	var start := nearest(Vector2i((campaign.hero_at/20).round()))
	var end := nearest(Vector2i((Vector2(target.p)/20).round()))
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(end): return
	path=grid.get_point_path(start,end)
	if path.size()>1: path[0]=campaign.hero_at

func nearest(cell: Vector2i) -> Vector2i:
	if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell): return cell
	for ring in range(1,8):
		for y in range(-ring,ring+1):
			for x in range(-ring,ring+1):
				var p := cell+Vector2i(x,y)
				if grid.is_in_boundsv(p) and not grid.is_point_solid(p): return p
	return cell

func resolve() -> Dictionary:
	if not campaign.state.trial_task.is_empty():
		return campaign.objective_nodes()[0].duplicate()
	if not campaign.escort_group.is_empty(): return {"p":campaign.receive_at(),"label":"护送同行者到接收点","zone":campaign.state.zone}
	if campaign.combat.running:
		var gadgets: Array=campaign.combat.gadgets()
		if not gadgets.is_empty():
			gadgets.sort_custom(func(a,b): return campaign.hero_at.distance_squared_to(a.p)<campaign.hero_at.distance_squared_to(b.p))
			return gadgets[0].duplicate()
		for enemy in campaign.enemies:
			if enemy.hp>0: return {"p":enemy.p,"label":"击败 · "+str(enemy.name),"fight":true}
	var q: Dictionary=campaign.tracked()
	var n: Dictionary=campaign.current_node(q)
	if n.is_empty(): return {}
	if n.zone==campaign.state.zone:
		return {"p":campaign.place(Vector2(n.at[0],n.at[1])),"label":n.label,"zone":n.zone,"qid":q.id}
	var geo=campaign.terrain()
	if int(n.zone.get_slice(":",0))!=int(campaign.state.act):
		return {"p":campaign.place(Vector2(900,260)) if campaign.state.stage==0 else campaign.gate_at(),"label":"前往第%d章 · %s" % [int(n.zone.get_slice(":",0)),campaign.content.zones[n.zone].name],"zone":n.zone,"transfer":true}
	var goal: int=geo.source_stage(n.zone)
	var start: int=geo.region.stage
	var edges: Dictionary={}
	for connector in geo.original.connectors:
		link(edges,int(connector.from),int(connector.to),connector.a)
		link(edges,int(connector.to),int(connector.from),connector.b)
	for door in geo.original.portals:
		link(edges,int(door.source),int(door.stage),door.p)
		link(edges,int(door.stage),int(door.source),geo.original.regions[int(door.stage)].origin+geo.original.regions[int(door.stage)].spawn)
	var todo: Array=[start]; var seen: Dictionary={start:true}; var first: Dictionary={}
	while not todo.is_empty():
		var stage: int=todo.pop_front()
		for edge in edges.get(stage,[]):
			if seen.has(edge.to): continue
			seen[edge.to]=true; first[edge.to]=edge if stage==start else first[stage]
			if edge.to==goal:
				var step: Dictionary=first[goal]
				var next_zone: String=geo.zone_for(int(campaign.state.act),int(step.to))
				# Boundary targets remain inside the current region's navigation grid.
				return {"p":campaign.place(geo.local(step.p)),"label":"经由 "+campaign.content.zones[next_zone].name,"zone":n.zone,"transfer":true,"boundary":not geo.original.regions[int(step.to)].indoor and not geo.region.indoor}
			todo.append(edge.to)
	return {"p":campaign.gate_at(),"label":"路标旅行 · "+campaign.content.zones[n.zone].name,"zone":n.zone,"transfer":true}

func link(edges: Dictionary, a: int, b: int, p: Vector2) -> void:
	if not edges.has(a): edges[a]=[]
	edges[a].append({"to":b,"p":p})

func distance_text() -> String:
	if target.is_empty(): return ""
	if campaign.hero_at.distance_to(target.p)<=campaign.INTERACT_RADIUS:
		if target.get("boundary",false): return "已到出口附近 · 沿道路继续前行"
		if target.get("fight",false): return "进入攻击距离 · 注意敌人招式"
		return "已到附近 · 按 E 交互"
	if path.size()<2:
		return "路线暂不可达 · 查看地图"
	var distance := 0.0
	var scale: Vector2=campaign.terrain().ratio
	for i in range(1,path.size()): distance+=((path[i]-path[i-1])*scale).length()*.01
	return "沿路 %.0f 米" % distance
