extends SceneTree

func _initialize() -> void:
	var kinds: Array=[]
	for biome in Catalog.BIOME_COLLECTIBLES: kinds.append_array(biome)
	kinds.append_array(Catalog.BOSS_COLLECTIBLES)
	kinds.append_array(Catalog.ROYAL_COLLECTIBLES)
	kinds.append_array(Catalog.NEW_COLLECTIBLES)
	var sheet := Image.create_empty(576,864,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("22202b"))
	for i in kinds.size():
		var source: Texture2D=TideUIArt.icon(str(kinds[i]))
		if source==null: continue
		var icon := source.get_image()
		icon.resize(72,72,Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(icon,Rect2i(Vector2i.ZERO,icon.get_size()),Vector2i((i%6)*96+12,(i/6)*96+12))
	sheet.save_png("res://build/collectibles-preview.png")
	quit()
