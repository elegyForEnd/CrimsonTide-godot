extends Control
## One TextureRect renders one ENTIRE independently generated character portrait.
const Art = preload("res://scripts/story_portrait_art.gd")
var texture: Texture2D:
	set(value):
		texture=value
		if is_instance_valid(body):body.texture=value
var body: TextureRect
var actor := ""
var expression := "neutral"
var costume := "regular"
var pose := "front"

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	body=TextureRect.new();body.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	body.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;body.mouse_filter=MOUSE_FILTER_IGNORE;add_child(body)
	body.texture=texture;resized.connect(layout);layout()

func set_actor(value: String, fallback: Texture2D, emotion: String = "neutral", clothing: String = "regular", gesture: String = "front") -> void:
	actor=value;expression=Art.normalized_expression(emotion);costume=clothing;pose=gesture
	if not is_instance_valid(body):return
	texture=Art.layers(int(value.get_slice(":",1)),expression,clothing,gesture).body if value.begins_with("hero:") else fallback
	visible=texture!=null;layout()

func layout() -> void:
	if not is_instance_valid(body):return
	body.position=Vector2.ZERO;body.size=size
