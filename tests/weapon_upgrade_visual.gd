extends SceneTree
const Build=preload("res://scripts/rogue_build.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
var received: Array=[]
class Board extends Node2D:
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,900),Color("0c111b"))
		draw_string(font,Vector2(28,40),"武器强化 · 图片与实际核心触发",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("e3eaf8"))
		var names := ["绯红单手剑 · 血缝","雷骸重剑 · 雷槌","霜针短杖 · 霜烬"]
		var levels := [0,2,3,4,5]
		for row in 3:
			for column in 5:
				var at := Vector2(22+column*283,76+row*270)
				draw_rect(Rect2(at,Vector2(275,254)),Color("172131"))
				draw_string(font,at+Vector2(12,29),"+%d · %s" % [levels[column],"基础" if column==0 else "核心 I" if column<3 else "核心 II"],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("dbe6f6"))
				draw_string(font,at+Vector2(12,233),names[row],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("b3c4dc"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900); root.content_scale_size=root.size
	var board := Board.new(); root.add_child(board)
	var s := TideSession.new(); root.add_child(s)
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729); s.set_physics_process(false)
	s.combat_event.connect(func(data): received.append(data.duplicate(true)))
	var p: Dictionary=s.players[1]
	var weapons := [600,617,638]
	var cores := ["WC002","WC006","WC011"]
	var levels := [0,2,3,4,5]
	for row in 3:
		for column in 5:
			s.roguelike.equip(s,p,Build.Content.make_weapon(weapons[row]-600,0))
			p.build_forge_bound=str(p.equipped.weapon.instance_id)
			p.build_forge_level=levels[column]; p.build_core=cores[row]
			p.build_cd={}; p.build_counts={}; p.combo=2
			s.enemies.clear(); s.spawn_enemy(p.p+Vector2(50,0),0)
			var enemy: Dictionary=s.enemies.back(); enemy.hp=9999; enemy.max_hp=9999
			var ctx := Build.context(s,p,"art" if row==2 else "attack")
			ctx.combo=2; ctx.height=60.0 if row>0 else 0.0
			received.clear()
			Build.hit_event(s,p,enemy,1,false,ctx)
			var fx := FX.new(); board.add_child(fx)
			var at := Vector2(98+column*283,205+row*270)
			fx.event({"kind":"strike","p":at,"aim":Vector2.RIGHT,"weapon":Catalog.weapon_family(weapons[row]),"weapon_index":weapons[row],"combo":2,"reach":64,"vfx":ctx.vfx},0)
			for data in received:
				if data.kind!="weapon_core": continue
				var display: Dictionary=data.duplicate(); display.p=at+Vector2(58,24)
				fx.event(display,0)
			fx.advance(.07)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-image-upgrades.png")
	print("WEAPON UPGRADE VISUAL captured actual +0/+2/+3/+4/+5 core triggers")
	s.queue_free(); board.queue_free(); await process_frame; await process_frame
	quit()
