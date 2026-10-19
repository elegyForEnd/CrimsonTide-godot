class_name MapMinimap
extends RefCounted
## Small presentation facade for the procedural minimap. Terrain is drawn by
## WorldArt from the generated polygons; fog and region colours live here so UI
## code never needs its own copy of the type palette.

static func region_color(type: String) -> Color:
	match type:
		"newbie":
			return Color("6f9a6c")
		"fight":
			return Color("a86b4f")
		"trap":
			return Color("7e5fa0")
		"high":
			return Color("7e3f4a")
		_:
			return Color("8b8b6e")

static func fog_texture(fog: MapFog) -> Texture2D:
	if fog == null:
		return null
	return fog.texture()
