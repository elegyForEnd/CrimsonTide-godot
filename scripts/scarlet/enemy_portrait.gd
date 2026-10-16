extends Control
## Reuse combat UV partitions so neighboring poses never leak into the handbook.
var frame: Dictionary={}
func _draw() -> void:
	if frame.is_empty(): return
	var extent: Vector2=frame.region.size
	var factor:=minf(size.x/extent.x,size.y/extent.y)
	var origin: Vector2=(size-extent*factor)*.5
	for piece: Dictionary in frame.pieces:
		var target:=Rect2(origin+(Vector2(piece.region.position)-Vector2(frame.region.position))*factor,Vector2(piece.region.size)*factor)
		draw_texture_rect_region(frame.texture,target,piece.region)
