extends RefCounted
## Shared authored placements: visuals and movement read the same footprints.
const DATA_PATH := "res://resources/story-opening-dressing.json"
static var source: Dictionary={}
static func entries(region) -> Array:
	if region.act!=1: return []
	if source.is_empty(): source=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var result: Array=[]
	for raw in source.regions.get(str(region.stage),[]):
		var item: Dictionary=raw.duplicate(true)
		var p := Vector2(item.at[0],item.at[1])
		if item.has("role"):
			p+=region.buildings[int(item.role)].rect.get_center()
		item.position=p
		var size := Vector2(item.get("footprint",[0,0])[0],item.get("footprint",[0,0])[1])
		item.rect=Rect2(p-size*.5,size)
		result.append(item)
	return result
