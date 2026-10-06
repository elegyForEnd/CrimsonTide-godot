extends SceneTree
const FX=preload("res://scripts/stylized_vfx.gd")
class Board extends Node2D:
	var combos := false
	var font: Font=load("res://assets/NotoSansSC.ttf")
	var examples := [600,603,606,613,615,617,631,643]
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,1060),Color("0b101a"))
		draw_string(font,Vector2(26,38),"武器特效 · 起手 / 接斩 / 终结" if combos else "48 把闯关武器 · 专属轮廓与元素",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("e6edf7"))
		for i in 24 if combos else 48:
			var col := i%3 if combos else i%8
			var row := i/3 if combos else i/8
			var size := Vector2(510,120) if combos else Vector2(194,158)
			var at := Vector2(24+col*520,65+row*123) if combos else Vector2(20+col*197,70+row*162)
			draw_rect(Rect2(at,size),Color("141e2b"))
			var weapon: int=examples[row] if combos else 600+i
			var identity=preload("res://scripts/weapon_vfx.gd").profile(weapon)
			draw_line(at,at+Vector2(size.x,0),Color(identity.color,.45),1)
			var label: String=Catalog.weapon(weapon).name+" · "+["起手","接斩","终结"][col] if combos else Catalog.weapon(weapon).name
			draw_string(font,at+Vector2(12,size.y-13),label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c7d4e5"))
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size=Vector2i(1600,1060); root.content_scale_size=root.size
	var board := Board.new(); root.add_child(board)
	var fx := FX.new(); board.add_child(fx)
	for i in 48:
		var weapon := 600+i
		var at := Vector2(62+(i%8)*197,160+(i/8)*162)
		var spec := Catalog.weapon(weapon)
		fx.event({"kind":"strike","p":at,"aim":Vector2.RIGHT,"weapon":Catalog.weapon_family(weapon),"weapon_index":weapon,"combo":2,"reach":57,"pattern":spec.get("pattern","")},0)
	fx.advance(.085)
	await capture("res://build/weapon-vfx-48.png")
	fx.reset(); board.combos=true; board.queue_redraw()
	for row in 8:
		for combo in 3:
			var weapon: int=board.examples[row]
			var at := Vector2(220+combo*520,145+row*123)
			var spec := Catalog.weapon(weapon)
			fx.event({"kind":"strike","p":at,"aim":Vector2.RIGHT,"weapon":Catalog.weapon_family(weapon),"weapon_index":weapon,"combo":combo,"reach":40,"pattern":spec.get("pattern","")},0)
	fx.advance(.085)
	await capture("res://build/weapon-vfx-combos.png")
	print("WEAPON VFX PREVIEW captured 48 identities and eight three-stage sequences")
	quit()
