extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	var preview=preload("res://scripts/story_portrait_preview.gd").new(); preview.app=app; root.add_child(preview)
