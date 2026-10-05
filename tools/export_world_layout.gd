extends SceneTree
func _initialize() -> void:
	var world := Ruins.new()
	world.generate(1729)
	# Bake in texture coordinates. Runtime expands geometry and the 4x3 tiles
	# together, keeping terrain texture memory unchanged as the map grows.
	var data := {"size":[Ruins.BASE_SIZE.x,Ruins.BASE_SIZE.y],"coast":points(world.coast),"river":points(world.river),"regions":[],"roads":[],"features":[],"sites":[],"bridges":[],"decor":[]}
	for r in world.regions: data.regions.append({"polygon":points(r.polygon)})
	for r in world.roads: data.roads.append(points(r))
	for r in world.features: data.features.append({"polygon":points(r.polygon),"kind":r.kind})
	for r in world.sites: data.sites.append({"p":[r.p.x/Ruins.MAP_SCALE,r.p.y/Ruins.MAP_SCALE],"rect":rect_values(r.rect),"tier":r.tier,"prop":r.prop})
	for r in world.bridges: data.bridges.append(rect_values(r))
	for r in world.decor: data.decor.append({"p":[r.p.x/Ruins.MAP_SCALE,r.p.y/Ruins.MAP_SCALE],"type":r.type,"size":r.size/Ruins.MAP_SCALE})
	var file := FileAccess.open("res://output/world-layout.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	quit()
func points(poly: PackedVector2Array) -> Array:
	var result: Array=[]
	for p in poly: result.append([p.x/Ruins.MAP_SCALE,p.y/Ruins.MAP_SCALE])
	return result
func rect_values(rect: Rect2) -> Array:
	return [rect.position.x/Ruins.MAP_SCALE,rect.position.y/Ruins.MAP_SCALE,rect.size.x/Ruins.MAP_SCALE,rect.size.y/Ruins.MAP_SCALE]
