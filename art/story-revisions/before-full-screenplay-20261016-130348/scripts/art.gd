extends RefCounted
## Asset access only; no old story presentation or rules are instantiated.
static var manifest: Dictionary={}
static var cache: Dictionary={}
static var cache_order: Array=[]
static func texture(path: String) -> Texture2D:
	if path=="": return null
	if cache.has(path): return cache[path]
	var result: Texture2D
	if ResourceLoader.exists(path): result=load(path)
	elif FileAccess.file_exists(path):
		var img:=Image.load_from_file(path)
		if img: result=ImageTexture.create_from_image(img)
	if result:
		cache[path]=result; cache_order.append(path)
		while cache_order.size()>8: cache.erase(cache_order.pop_front())
	return result
static func portrait(actor: String,expression: String="neutral",pose: String="front",costume: String="regular") -> Texture2D:
	if actor=="": return null
	if actor in ["feiyue","xueli","yayu"]:
		if manifest.is_empty(): manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/vn-full-v3/manifest.json"))
		var entry: Dictionary=manifest.heroes[actor].portraits
		if not entry.has(costume): costume="regular"
		if not entry[costume].has(pose): pose="front"
		if not entry[costume][pose].has(expression): expression="neutral"
		return texture(entry[costume][pose][expression])
	if actor=="queen":
		var variant: String="res://assets/story/scarlet/npc/queen-"+expression+".png"
		return texture(variant if FileAccess.file_exists(variant) else "res://assets/bosses/blood-queen-portrait.png")
	if actor=="physician": return texture("res://assets/story/scarlet/npc/physician-v2.png")
	var variant: String="res://assets/story/scarlet/npc/"+actor+"-"+expression+".png"
	return texture(variant if FileAccess.file_exists(variant) else "res://assets/story/scarlet/npc/"+actor+".png")
static func cg(id: String) -> Texture2D:
	return texture("res://assets/story/cg-scarlet-v1/"+id+".png") if id!="" else null
static func frame(color: Color=Color("161724"),border: Color=Color("8d755b"),radius: int=8) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=color
	style.border_color=border; style.set_border_width_all(1); style.set_corner_radius_all(radius)
	style.content_margin_left=14; style.content_margin_right=14; style.content_margin_top=9; style.content_margin_bottom=9
	return style
static func theme() -> Theme:
	var t:=Theme.new(); t.default_font=load("res://assets/NotoSansSC.ttf"); t.default_font_size=18
	t.set_stylebox("normal","Button",frame(Color("242232")))
	t.set_stylebox("hover","Button",frame(Color("49354b"),Color("e0c28a")))
	t.set_stylebox("pressed","Button",frame(Color("543647"),Color("f0d7a5")))
	t.set_stylebox("focus","Button",frame(Color(0,0,0,0),Color("e7c594")))
	t.set_stylebox("disabled","Button",frame(Color("191923"),Color("45414b")))
	t.set_color("font_color","Button",Color("eee1cf")); t.set_color("font_disabled_color","Button",Color("827b86"))
	t.set_color("font_color","Label",Color("eee1cf")); t.set_color("default_color","RichTextLabel",Color("eee1cf"))
	t.set_stylebox("panel","Panel",frame()); return t
