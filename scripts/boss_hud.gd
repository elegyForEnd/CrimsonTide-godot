extends Node2D
var field: Battlefield
func _process(_dt: float) -> void:
	visible=field.visible
	if visible: queue_redraw()

func label(at: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(field.font,at+Vector2(1,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0.03,0.01,0.03,color.a))
	draw_string(field.font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	if not field.visible or not field.session.running or field.map_open: return
	var size := get_viewport_rect().size
	var session: TideSession=field.session
	var boss_frames: BossFrames=field.boss_frames
	var boss_health: Dictionary=field.boss_health
	var boss_seen: Dictionary=field.boss_seen
	var clock: float=field.clock
	var font: Font=field.font
	for e in session.enemies:
		if e.get("mini_boss",false):
			if e.p.distance_to(field.camera)>850: continue
			var mini_color: Color=Color("9ce9ff") if e.get("dragon_boss",false) else [Color("d9aa68"),Color("87dfff")][clampi(int(e.get("wild_kind",0)),0,1)] if e.get("wild_boss",false) else Color("a8dbff") if int(e.mini_kind)==0 else Color("ff8d66")
			var mini_width := minf(490,size.x-130)
			var mini_at := Vector2(size.x/2-mini_width/2,125)
			draw_rect(Rect2(mini_at-Vector2(18,12),Vector2(mini_width+36,91)),Color(0.025,0.015,0.035,0.87))
			draw_rect(Rect2(mini_at-Vector2(18,12),Vector2(mini_width+36,91)),Color(mini_color,0.65),false,2)
			label(mini_at,str(e.boss_name),20,Color("fff2e6"))
			label(mini_at+Vector2(0,25),str(e.get("move_name","守卫苏醒 · 留意地面预警")),14,mini_color)
			draw_rect(Rect2(mini_at+Vector2(0,45),Vector2(mini_width,13)),Color("302731"))
			draw_rect(Rect2(mini_at+Vector2(0,45),Vector2(mini_width*clampf(float(e.hp)/float(e.max_hp),0,1),13)),mini_color)
			continue
		if not e.get("raid_boss",false): continue
		var kind: int=e.boss_kind
		var color: Color=Color("b86bff") if e.get("abyss_final",false) else Color("ff4a70") if e.get("final_form",false) else BossFrames.COLORS[kind]
		var width := minf(700,size.x-490)
		var art_size := Vector2(width,width/3.0)
		var at := Vector2(size.x/2-width/2,44)
		# Generated frame has translucent panels; a local dark backing keeps
		# runtime text legible over VFX, terrain and pale character costumes.
		draw_rect(Rect2(at+art_size*Vector2(0.25,0.25),art_size*Vector2(0.625,0.46)),Color(0.025,0.018,0.038,0.88))
		draw_texture_rect(boss_frames.headers[kind],Rect2(at,art_size),false)
		var normalized: Rect2=BossFrames.TRACKS[kind]
		var track := Rect2(at+normalized.position*art_size,normalized.size*art_size)
		var ratio: float=clampf(e.hp/e.max_hp,0,1)
		var lag: float=boss_health.get(e.id,ratio)
		draw_rect(Rect2(track.position,Vector2(track.size.x*lag,track.size.y)),color.darkened(0.35))
		draw_rect(Rect2(track.position,Vector2(track.size.x*ratio,track.size.y)),color.darkened(0.08))
		draw_rect(Rect2(track.position,Vector2(track.size.x*ratio,2)),color.lightened(0.55))
		for threshold in ([0.6,0.3] if kind==2 else [0.6]):
			var x: float=track.position.x+track.size.x*threshold
			draw_line(Vector2(x,track.position.y),Vector2(x,track.end.y),Color(0.12,0.05,0.09,0.7),2)
		var phase: int=clampi(int(e.get("phase",1))-1,0,BossFrames.PHASES[kind].size()-1)
		var title_at := at+Vector2(0.27,0.35)*art_size
		label(title_at,str(e.boss_name),20,Color("fff2de"))
		var phase_name: String=["潜潮","吞月","无光"][phase] if e.get("abyss_final",false) else ["血月","潮源","破晓"][phase] if e.get("final_form",false) else BossFrames.PHASES[kind][phase]
		label(at+Vector2(0.72,0.35)*art_size,"%s · %s" % [["I","II","III"][phase],phase_name],15,color)
		label(at+Vector2(0.27,0.655)*art_size,str(e.get("move_name","黎明降临 · 观察地面预警")),15,Color("fff0e1"))
		var value := "%d / %d" % [maxi(0,int(ceil(e.hp))),int(e.max_hp)]
		var value_width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		label(track.get_center()+Vector2(-value_width/2,4),value,12,Color("fff5e8"))
		# A brief portrait entrance leaves movement and combat fully responsive.
		var age: float=clock-float(boss_seen.get(e.id,clock))
		if age<3.0 and not field.map_open and not field.boss_fx.cinematic.active:
			var alpha := minf(clampf(age/0.25,0,1),clampf((3.0-age)/0.6,0,1))
			var portrait_size := Vector2(210,315)
			var portrait_at := Vector2(18-(1-alpha)*45,size.y-440)
			var portrait: Texture2D=field.special_boss_art[5] if e.get("abyss_final",false) else field.special_boss_art[2] if e.get("final_form",false) else boss_frames.portraits[kind]
			draw_texture_rect(portrait,Rect2(portrait_at,portrait_size),false,Color(1,1,1,alpha))
			label(portrait_at+Vector2(12,333),("吞月渊蛇" if e.get("abyss_final",false) else "无名赤月" if e.get("final_form",false) else BossFrames.TITLES[kind])+" · 降临",18,Color(color,alpha))
	if session.players.get(session.my_id(),{}).get("status","")!="active": return
	if session.raid.get("phase","") in ["choice","complete"]:
		var at := Vector2(size.x/2-320,245)
		draw_rect(Rect2(at-Vector2(18,35),Vector2(676,190)),Color(0.08,0.04,0.11,0.94))
		var complete: bool=session.raid.phase=="complete"
		label(at,("终夜已破 · 深渊退潮" if session.raid.get("abyss_spawned",false) else "终夜已破 · 无名赤月消散") if complete else "第二日黎明 · 带走战利品，还是挑战血潮女王？",22,Color("f7dca1"))
		label(at+Vector2(0,33),"[N] 安全撤离 · 可先拾取女王遗赠" if complete else "[Y] 就绪进入第三天    [N] 直接撤离    [U] 取消就绪",18,Color("f3e8db"))
		var ready: bool=session.raid.get("choices",{}).get(session.my_id(),false)
		label(at+Vector2(0,66),"已就绪 · 等待其他存活队友选择" if ready else "可先整理补给、拾取遗赠；全体留下的队友就绪后出发",15,Color("b8aabb"))
