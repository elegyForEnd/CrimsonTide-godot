extends RefCounted
const Roster=preload("res://scripts/scarlet/enemy_roster.gd")
static func open(screen) -> void:
	var panel=screen.panel("遭遇手册 · 已见敌人与应对  [B]")
	var list=screen.column(panel,Vector2(25,90),Vector2(350,580))
	var detail=screen.column(panel,Vector2(410,90),Vector2(785,580))
	screen.prose(detail,"在战斗中见过的敌人会记入手册。招式在起手时锁定方向或落点，留意预警与收招。",20)
	for group in [Roster.data().minions,Roster.data().bosses]:
		for key in group:
			if not screen.campaign.state.world.get("enemy_seen:"+key,false): continue
			var info: Dictionary=group[key]
			var title: String=info.get("name",screen.campaign.content.bosses.get(key,{}).get("name",key))
			screen.row(list,title,func(): show_entry(screen,detail,key,title))
static func show_entry(screen,detail: VBoxContainer,key: String,title: String) -> void:
	for child in detail.get_children(): detail.remove_child(child); child.queue_free()
	var info:=Roster.profile(key)
	screen.prose(detail,title,27)
	var frames:=preload("res://scripts/scarlet/enemy_frames.gd").prepare(key)
	if not frames.is_empty():
		var picture=preload("res://scripts/scarlet/enemy_portrait.gd").new()
		picture.frame=frames[0]; picture.custom_minimum_size=Vector2(620,230)
		detail.add_child(picture)
	screen.prose(detail,info.get("lore",info.get("identity","")))
	if info.has("counter"): screen.prose(detail,"应对："+info.counter)
	else: screen.prose(detail,"遭遇地点："+info.arena)
	for phase in (info.phases.size() if info.has("phases") else 1):
		if info.has("phases"): screen.prose(detail,"阶段 %d" % (phase+1),21)
		for move in Roster.moves(key,phase): screen.prose(detail,"「%s」 %s" % [move.name,move.hint],17)
