extends Node2D

var field: Control

func _ready() -> void:
	show_behind_parent=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _draw() -> void:
	if field==null or not field.session.roguelike.active(field.session): return
	var r=field.session.ruins
	var texture: Texture2D=field.art.region_background(int(field.session.raid.floor)-1,int(field.session.raid.area),str(field.session.raid.room))
	draw_set_transform(-field.camera_offset())
	for patch in r.backdrop_quads():
		draw_polygon(patch.points,PackedColorArray([Color.WHITE]),patch.uv,texture)
