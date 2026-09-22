extends SceneTree

func _initialize() -> void:
	for file in ["windbell-moth","archive-owl","mooncrystal-stag","thorn-bloom","mist-jelly","royal-griffin"]:
		var source := Image.load_from_file("res://output/imagegen/"+file+".png")
		assert(source!=null and not source.is_empty())
		source.convert(Image.FORMAT_RGBA8)
		# Standardize generated grid dimensions for the existing 256 px frame reader.
		source.resize(1024,768,Image.INTERPOLATE_LANCZOS)
		assert(source.save_png("res://assets/enemies/"+file+".png")==OK)
	quit()
