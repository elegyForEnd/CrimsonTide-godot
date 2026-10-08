extends SceneTree
const Art=preload("res://scripts/weapon_image_art.gd")
class Board extends Node2D:
	var font: Font=load("res://assets/NotoSansSC.ttf")
	var names := ["轻刃挥击","双刃交叉","直线突刺","重刃扇斩","轻刃圆斩","重刃圆斩","仪镰钩斩","战戟窄扫","飞行月刃","弓箭","冰针","子弹","雷弹","弓弦出手"]
	var entries: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Art.MECHANICS_BASE+"manifest.json")).assets
	var textures: Dictionary={}
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,1320),Color("0b111b"))
		draw_string(font,Vector2(24,36),"14 张 ImageGen 原图重做 · 每组左旧 / 右新 · 相同尺寸，保持原图比例，无扩边着色器",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e5edf8"))
		for i in Art.REDRAWN.size():
			var group := i/7
			var row := i%7
			for version in 2:
				var role: String=Art.REDRAWN[i]+("_v2" if version==1 else "")
				var at := Vector2(18+group*714+version*350,58+row*178)
				draw_rect(Rect2(at,Vector2(340,170)),Color("162232"))
				var entry: Dictionary=entries[role]
				if not textures.has(role): textures[role]=load(Art.MECHANICS_BASE+str(entry.file))
				var art: Texture2D=textures[role]
				var ink: Array=entry.ink
				var bounds := Rect2(ink[0],ink[1],ink[2]-ink[0],ink[3]-ink[1])
				var scale := minf(260/bounds.size.x,125/bounds.size.y)
				draw_texture_rect(art,Rect2(at+Vector2(170,72)-bounds.get_center()*scale,art.get_size()*scale),false)
				draw_string(font,at+Vector2(12,158),names[i]+(" · 新原图" if version==1 else " · 旧原图"),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("bacde3"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,1320); root.content_scale_size=root.size
	var board := Board.new(); root.add_child(board)
	await process_frame; await RenderingServer.frame_post_draw
	board.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-imagegen-redraw.png")
	board.queue_free(); await process_frame; quit()
