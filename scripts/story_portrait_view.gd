extends Control
## Two native texture controls preserve a shared face/feet anchor across 40 variants.
const Art = preload("res://scripts/story_portrait_art.gd")
var texture: Texture2D:
	set(value):
		texture=value
		if is_instance_valid(body): body.texture=value; layout()
var body: TextureRect
var face: TextureRect
var face_rect := Rect2()
var actor := ""
var expression := "neutral"
var costume := "regular"

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	body=TextureRect.new(); body.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; body.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; body.mouse_filter=MOUSE_FILTER_IGNORE; add_child(body)
	face=TextureRect.new(); face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; face.stretch_mode=TextureRect.STRETCH_SCALE; face.mouse_filter=MOUSE_FILTER_IGNORE; add_child(face)
	body.texture=texture; resized.connect(layout); layout()

func set_actor(value: String, fallback: Texture2D, emotion: String = "neutral", clothing: String = "regular") -> void:
	actor=value; expression=emotion; costume=clothing
	if not is_instance_valid(body): return
	var data: Dictionary=Art.layers(int(value.get_slice(":",1)),emotion,clothing) if value.begins_with("hero:") else {"body":fallback,"face":null,"face_rect":Rect2()}
	texture=data.body; face.texture=data.face; face_rect=data.face_rect; visible=texture!=null; layout()

func layout() -> void:
	if not is_instance_valid(body) or not is_instance_valid(face): return
	body.position=Vector2.ZERO; body.size=size
	face.visible=face.texture!=null and texture!=null
	if texture==null or texture.get_size().x<=0 or texture.get_size().y<=0: return
	var scale_factor := minf(size.x/texture.get_width(),size.y/texture.get_height())
	var offset := (size-texture.get_size()*scale_factor)*.5
	face.position=offset+face_rect.position*scale_factor
	face.size=face_rect.size*scale_factor
