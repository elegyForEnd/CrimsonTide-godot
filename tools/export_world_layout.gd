extends SceneTree
func _initialize() -> void:
	var world := Ruins.new()
	world.generate(1729)
	var data := {"size":[Ruins.SIZE.x,Ruins.SIZE.y],"coast":points(world.coast),"river":points(world.river),"regions":[],"roads":[],"features":[],"sites":[],"bridges":[],"decor":[]}
	for r in world.regions: data.regions.append({"polygon":points(r.polygon)})
	for r in world.roads: data.roads.append(points(r))
	for r in world.features: data.features.append({"polygon":points(r.polygon),"kind":r.kind})
	for r in world.sites: data.sites.append({"p":[r.p.x,r.p.y],"rect":[r.rect.position.x,r.rect.position.y,r.rect.size.x,r.rect.size.y],"tier":r.tier,"prop":r.prop})
	for r in world.bridges: data.bridges.append([r.position.x,r.position.y,r.size.x,r.size.y])
	for r in world.decor: data.decor.append({"p":[r.p.x,r.p.y],"type":r.type,"size":r.size})
	var file := FileAccess.open("res://output/world-layout.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	quit()
func points(poly: PackedVector2Array) -> Array:
	var result: Array=[]
	for p in poly: result.append([p.x,p.y])
	return result
