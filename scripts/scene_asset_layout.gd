extends RefCounted
## Shared by simulation and rendering: dimensions are in simulation pixels.
## Keep building footprints compact enough to leave each ruin's four exits open.

static func building(item: Dictionary) -> Dictionary:
	if not item.landmark: return {}
	var model := ""
	match int(item.type):
		0: model="medieval/building_church_red"
		2: model="medieval/building_mine_red"
		6: model="medieval/building_market_red"
		7: model="medieval/building_tower_A_red"
		8: model="medieval/building_castle_red"
	if model.is_empty(): return {}
	var width: float=item.size*0.72
	var depth: float=minf(item.size*0.40,145.0)
	return {"model":model,"rect":Rect2(item.p-Vector2(width,depth)/2,Vector2(width,depth)),"height":float(item.size)*0.88}
