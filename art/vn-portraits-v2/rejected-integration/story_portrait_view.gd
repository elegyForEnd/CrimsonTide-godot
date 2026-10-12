extends Control
## Unchanged blank base + cheek tint + eye/brow ink + mouth ink; no facial backplates.
const Art = preload("res://scripts/story_portrait_art.gd")
var texture: Texture2D:
	set(value):
		texture=value
		if is_instance_valid(body): body.texture=value; layout()
var body: TextureRect
var face: TextureRect
var mouth: TextureRect
var blush: TextureRect
var face_rect := Rect2()
var overlay_data: Array=[]
var actor := ""
var expression := "neutral"
var costume := "regular"
var pose := "relaxed"
var blush_enabled := true
var blank := false
var inspection := "all"

func layer() -> TextureRect:
	var node := TextureRect.new()
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	body=layer(); blush=layer(); face=layer(); mouth=layer()
	body.texture=texture; resized.connect(layout); layout()

func set_actor(value: String, fallback: Texture2D, emotion: String = "neutral", clothing: String = "regular", gesture: String = "relaxed") -> void:
	actor=value; expression=emotion; costume=clothing; pose=gesture
	if not is_instance_valid(body): return
	var data: Dictionary=Art.layers(int(value.get_slice(":",1)),emotion,clothing,gesture,blush_enabled,blank) if value.begins_with("hero:") else {"body":fallback,"face":null,"face_rect":Rect2()}
	texture=data.body; face_rect=data.face_rect; overlay_data=data.get("overlays",[])
	for node in [blush,face,mouth]: node.texture=null
	if not data.has("overlays"): face.texture=data.face
	for info in overlay_data:
		var node: TextureRect={"eyes":face,"mouth":mouth,"blush":blush}[info.kind]
		node.texture=info.texture; node.modulate.a=info.opacity
	visible=texture!=null; layout()

func layout() -> void:
	if not is_instance_valid(body) or not is_instance_valid(face): return
	body.position=Vector2.ZERO; body.size=size; body.visible=inspection in ["all","base"]
	for node in [blush,face,mouth]: node.visible=false
	if texture==null or texture.get_size().x<=0 or texture.get_size().y<=0: return
	var scale_factor := minf(size.x/texture.get_width(),size.y/texture.get_height())
	var offset := (size-texture.get_size()*scale_factor)*.5
	if overlay_data.is_empty():
		face.visible=face.texture!=null and inspection in ["all","eyes"]
		face.position=offset+face_rect.position*scale_factor; face.size=face_rect.size*scale_factor
	else:
		for info in overlay_data:
			var node: TextureRect={"eyes":face,"mouth":mouth,"blush":blush}[info.kind]
			node.position=offset+info.rect.position*scale_factor; node.size=info.rect.size*scale_factor
			node.visible=node.texture!=null and inspection in ["all",info.kind]
