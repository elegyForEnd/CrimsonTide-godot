extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	root.add_child(preload("res://scripts/vn_full_gallery.gd").new())
