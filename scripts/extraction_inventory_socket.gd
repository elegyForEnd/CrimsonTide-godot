extends Control
## Image-generated quality linings share fixed-width, nine-sliced borders.
var tone := Color("b5a688")
var occupied := false
var secure := false
var selected := false
static var frames: Array[Texture2D]=[]
static var quality_frames: Array[Texture2D]=[]

func _ready() -> void:
	if frames.is_empty():
		var source: Texture2D=load("res://assets/ui/extraction-slot-atlas-v1.png")
		for rect in [Rect2(0,0,625,586),Rect2(631,0,621,586)]:
			frames.append(atlas_frame(source,rect))
	if quality_frames.is_empty():
		var source: Texture2D=load("res://assets/ui/extraction-quality-slots-v2.png")
		for rect in [Rect2(0,0,508,480),Rect2(516,0,508,480),Rect2(0,485,508,479),Rect2(516,485,508,479),Rect2(0,974,508,506),Rect2(516,974,508,506)]:
			quality_frames.append(atlas_frame(source,rect))
	queue_redraw()

func atlas_frame(source: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas=source
	atlas.region=region
	atlas.filter_clip=true
	return atlas

func quality_index() -> int:
	var best := 0
	var distance := INF
	for i in Catalog.BAG_TIERS.size():
		var colour: Color=Catalog.BAG_TIERS[i].color
		var delta := Vector3(tone.r-colour.r,tone.g-colour.g,tone.b-colour.b).length_squared()
		if delta<distance:
			distance=delta
			best=i
	return best

func _draw() -> void:
	if frames.is_empty() or quality_frames.is_empty(): return
	if occupied:
		draw_quality_frame(quality_frames[quality_index()])
	else:
		draw_texture_rect(frames[1 if secure else 0],Rect2(Vector2.ZERO,size),false,Color(0.8,0.8,0.8,0.40))
	if selected:
		for corner in [Vector2(2,2),Vector2(size.x-2,2),Vector2(2,size.y-2),size-Vector2(2,2)]:
			var direction := Vector2(1 if corner.x<size.x*0.5 else -1,1 if corner.y<size.y*0.5 else -1)
			draw_line(corner,corner+Vector2(direction.x*8,0),Color("e3c38a"),2,true)
			draw_line(corner,corner+Vector2(0,direction.y*8),Color("e3c38a"),2,true)

func draw_quality_frame(frame: AtlasTexture) -> void:
	var region := frame.region
	var border := 8.0
	var source_x := [region.position.x,region.position.x+region.size.x*0.19,region.end.x-region.size.x*0.19,region.end.x]
	var source_y := [region.position.y,region.position.y+region.size.y*0.19,region.end.y-region.size.y*0.19,region.end.y]
	var target_x := [0.0,border,size.x-border,size.x]
	var target_y := [0.0,border,size.y-border,size.y]
	for y in 3:
		for x in 3:
			var target := Rect2(target_x[x],target_y[y],target_x[x+1]-target_x[x],target_y[y+1]-target_y[y])
			var source := Rect2(source_x[x],source_y[y],source_x[x+1]-source_x[x],source_y[y+1]-source_y[y])
			draw_texture_rect_region(frame.atlas,target,source,Color(0.88,0.88,0.88,1))
