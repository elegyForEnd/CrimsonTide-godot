extends SceneTree
const M=preload("res://scripts/weapon_mechanics.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
class Board extends Node2D:
	var font: Font=load("res://assets/NotoSansSC.ttf")
	var weapons := [601,602,603,614,624,625,637,638,639,640,642,643]
	var sprites: Array=[]
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,1540),Color("0b111b"))
		draw_string(font,Vector2(26,40),"按实际招式选图 · 起手 / 飞行弹体 / 右键战技",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e5edf8"))
		for row in weapons.size():
			for col in 3:
				var at := Vector2(22+col*470,68+row*121)
				draw_rect(Rect2(at,Vector2(462,114)),Color("162232"))
				var middle := "飞行弹体" if Catalog.weapon_family(weapons[row]) in [0,3] else "动作轨迹"
				draw_string(font,at+Vector2(12,104),Catalog.weapon(weapons[row]).name+" · "+["普攻出手",middle,"战技"][col],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("bacde3"))
		for sprite in sprites:
			draw_set_transform(sprite.p,0)
			var thickness: float=M.projectile_thickness(sprite.role)*float(sprite.scale)
			var glow := Color(sprite.color)
			glow.v=1.7; glow.a=.4
			Art.stamp_mechanic(self,sprite.role,sprite.size,glow,thickness*1.65)
			var body := Color(sprite.color); body.v=1.7
			Art.stamp_mechanic(self,sprite.role,sprite.size,body,thickness)
		draw_set_transform(Vector2.ZERO)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,1540); root.content_scale_size=root.size
	var board := Board.new(); root.add_child(board)
	var fx := FX.new(); board.add_child(fx)
	for row in board.weapons.size():
		var index: int=board.weapons[row]
		var w := Catalog.weapon(index)
		var family := Catalog.weapon_family(index)
		var color: Color=preload("res://scripts/weapon_vfx.gd").profile(index).color.lerp(Color.WHITE,.28)
		var y := 118+row*121
		fx.event({"kind":"strike","p":Vector2(235,y if M.body_centered(M.normal_role(index)) else y+24),"aim":Vector2.RIGHT,"weapon":family,"weapon_index":index,"combo":0,"reach":46,"pattern":w.get("pattern","")})
		if family in [0,3]:
			var role := M.projectile_role(index,str(w.get("spell","star")))
			board.sprites.append({"p":Vector2(720,y),"role":role,"size":M.projectile_size(role,index)*2,"color":color,"scale":2.0})
		else:
			fx.event({"kind":"strike","p":Vector2(720,y if M.body_centered(M.normal_role(index)) else y+24),"aim":Vector2.RIGHT,"weapon":family,"weapon_index":index,"combo":0,"reach":46})
		var move := WeaponArts.of(index)
		fx.event({"kind":"strike","p":Vector2(1170,y if M.body_centered(M.strike_role(index,{"attack_kind":move.kind})) else y+24),"aim":Vector2.RIGHT,"weapon":family,"weapon_index":index,"attack_kind":move.kind,"combo":2,"reach":46})
		if move.kind=="beam": fx.event({"kind":"spell_beam","p":Vector2(1065,y+24),"aim":Vector2.RIGHT,"weapon_index":index,"spell":move.spell,"reach":230,"width":16})
		elif move.kind=="burst": fx.event({"kind":"spell_burst","p":Vector2(1210,y),"aim":Vector2.RIGHT,"weapon_index":index,"spell":move.spell,"radius":40})
		elif move.kind=="volley":
			for i in int(move.count):
				var role := M.projectile_role(index,str(move.spell))
				board.sprites.append({"p":Vector2(1190,y+(i-(int(move.count)-1)*.5)*14),"role":role,"size":M.projectile_size(role,index)*1.4,"color":color,"scale":1.4})
	fx.advance(.035)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-mechanics-comparison.png")
	if "--motion-preview" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://build/weapon-mechanics-frames")
		for frame in 20:
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/weapon-mechanics-frames/frame-%02d.png" % frame)
			fx.advance(.012)
	print("WEAPON MECHANICS PREVIEW actual release/projectile/art captured")
	board.queue_free(); await process_frame; await process_frame; quit()
