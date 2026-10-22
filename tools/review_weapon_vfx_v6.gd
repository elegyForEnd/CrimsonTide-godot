extends "res://tools/preview_weapon_world_vfx.gd"
## Real production renderer, three actions x four times, every independent weapon.
const REVIEW="res://build/vfx-v6/"
func run() -> void:
	full_preview=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW))
	root.size=Vector2i(1920,1110); root.content_scale_size=root.size
	var selected: Array=[600,613,615,624,636]
	if "--all" in OS.get_cmdline_user_args(): selected=range(600,648)+[17,18,19,20]
	var manifest: Array=[]
	for weapon in selected:
		var board := Board.new(); root.add_child(board)
		board.caption="%d %s · 上：普攻 / 中：蓄力重击 / 下：战技 · 各行 20 / 70 / 150 / 350 ms" % [weapon,Catalog.weapon(weapon).name]
		tiles.clear()
		for row in 3:
			for column in 4:
				var tile := create_tile(weapon,row*4+column,board)
				strike(tile,row==2,row==1)
				var at: float=[.02,.07,.15,.35][column]
				for i in ceili(at/.01): step(tile,minf(.01,at-i*.01))
				tile.mode=["普攻","蓄力重击","战技"][row]+" · %d ms" % roundi(at*1000)
				tiles.append(tile)
		for frame in 4:
			board.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
		var target := REVIEW+"weapon-%d.png" % weapon
		var rendered := root.get_texture().get_image()
		if rendered==null: push_error("Use an actual renderer for visual review"); quit(1); return
		rendered.save_png(target)
		manifest.append({"weapon":weapon,"name":Catalog.weapon(weapon).name,"file":target})
		for tile in tiles: tile.view.queue_free()
		board.queue_free(); await process_frame
		print("DESIGN RESTORATION REVIEW ",weapon)
	FileAccess.open(REVIEW+"coverage.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	quit()
