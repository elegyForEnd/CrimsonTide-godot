extends "res://tools/preview_weapon_world_vfx.gd"
## Renderer evidence: same geometry, real blade alpha versus a neutral white map.
func run() -> void:
	root.size=Vector2i(1440,1470); root.content_scale_size=root.size
	var board := Board.new(); root.add_child(board)
	board.caption="刀光贴图验证 · 左：纯白对照 / 中：实际刀光贴图层 / 右：完整效果"
	var blank := Image.create(4,4,false,Image.FORMAT_RGBA8); blank.fill(Color.WHITE)
	var neutral := ImageTexture.create_from_image(blank)
	for row in 4:
		var weapon: int=[600,612,613,606][row]
		for column in 3:
			var tile := create_tile(weapon,0,board)
			tile.at=Vector2(column*480,54+row*350)
			tile.fx.camera.size*=.72
			strike(tile,false,true); step(tile,.12)
			var effect=tile.fx.effects[0]
			if column<2:
				effect.smoke.hide(); effect.debris.hide()
				var mesh=preload("res://scripts/weapon_vfx_mesh_3d.gd").new()
				effect.draw_release(mesh); mesh.commit(effect.ribbon)
			if column==0: effect.body_material.set_shader_parameter("blade_texture",neutral)
			tile.mode=["纯白对照 · 不含刀光原图轮廓","刀光原图 · RGBA 刃面与镂空","实际完整效果 · 主体 / 碎片 / 烟雾"][column]
			tiles.append(tile)
	for frame in 4:
		board.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"blade-texture-layers.png")
	quit()
