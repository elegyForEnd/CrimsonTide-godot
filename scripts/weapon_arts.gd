class_name WeaponArts
extends RefCounted

# Catalog weapon order, including the four temporary weapons at the end.
# damage is a multiplier of the current weapon damage, including scaling/quality.
const MOVES := [
	{"name":"银鸦齐射", "kind":"volley", "mana":16.0, "cooldown":4.0, "damage":0.85, "reach":760.0, "count":5, "spell":"bullet", "desc":"发射五枚扇形灵能弹，不消耗弹药。"},
	{"name":"绯红回旋", "kind":"circle", "mana":16.0, "cooldown":4.0, "damage":2.0, "reach":170.0, "desc":"环斩周身敌人。"},
	{"name":"破晓震荡", "kind":"circle", "mana":24.0, "cooldown":6.0, "damage":2.2, "reach":240.0, "desc":"砸地震伤并击退周围敌人。"},
	{"name":"星辉贯流", "kind":"beam", "mana":18.0, "cooldown":4.5, "damage":2.0, "reach":780.0, "width":38.0, "spell":"prism", "desc":"星光贯穿前方直线上的敌人。"},
	{"name":"赤陨坠星", "kind":"burst", "mana":28.0, "cooldown":7.0, "damage":1.7, "reach":340.0, "radius":185.0, "spell":"meteor", "desc":"在瞄准方向召下大范围陨爆。"},
	{"name":"霜针暴雨", "kind":"volley", "mana":14.0, "cooldown":3.0, "damage":0.9, "reach":780.0, "count":7, "spell":"needle", "desc":"瞬发七枚扇形高速冰针。"},
	{"name":"鸣雷连锁", "kind":"volley", "mana":22.0, "cooldown":5.5, "damage":1.0, "reach":720.0, "count":3, "spell":"chain", "desc":"三道雷弹各自连锁附近敌人。"},
	{"name":"月弧三叠", "kind":"volley", "mana":20.0, "cooldown":5.0, "damage":1.0, "reach":800.0, "count":3, "spell":"moon", "pierce":4, "desc":"三道月刃各自贯穿四名敌人。"},
	{"name":"曦光裁决", "kind":"beam", "mana":26.0, "cooldown":6.0, "damage":2.1, "reach":900.0, "width":65.0, "spell":"prism", "desc":"释放宽幅远距贯穿光束。"},
	{"name":"烬羽燎原", "kind":"volley", "mana":20.0, "cooldown":4.5, "damage":1.2, "reach":650.0, "count":9, "spell":"scatter", "desc":"九枚火羽覆盖扇面；同目标后续羽毛伤害递减。"},
	{"name":"虚涡塌缩", "kind":"burst", "mana":24.0, "cooldown":6.0, "damage":2.0, "reach":280.0, "radius":210.0, "pull":85.0, "spell":"vortex", "desc":"远处虚涡爆发，将范围内敌人拉向中心。"},
	{"name":"蚀月破界", "kind":"beam", "mana":32.0, "cooldown":8.0, "damage":1.8, "reach":1050.0, "width":45.0, "spell":"eclipse", "desc":"重型魔枪贯穿前方长直线。"},
	{"name":"鸦喙穿心", "kind":"thrust", "mana":14.0, "cooldown":3.5, "damage":2.4, "reach":300.0, "width":32.0, "desc":"长距离直线穿刺。"},
	{"name":"回环风轮", "kind":"circle", "mana":18.0, "cooldown":4.0, "damage":2.3, "reach":205.0, "desc":"以旋风刀轮扫清周身。"},
	{"name":"断潮开山", "kind":"cone", "mana":26.0, "cooldown":6.5, "damage":2.4, "reach":300.0, "desc":"重刃横扫宽阔扇面，强力击退。"},
	{"name":"裂地崩震", "kind":"circle", "mana":28.0, "cooldown":7.0, "damage":2.5, "reach":285.0, "desc":"释放巨大的周身裂地冲击。"},
	{"name":"暮羽追魂", "kind":"volley", "mana":18.0, "cooldown":4.0, "damage":1.05, "reach":950.0, "count":3, "pierce":3, "spell":"arrow", "desc":"射出三枚贯穿三人的灵箭，不消耗弹药。"},
	{"name":"黑铁突刺", "kind":"thrust", "mana":10.0, "cooldown":3.0, "damage":1.8, "reach":150.0, "width":26.0, "desc":"短剑向前突刺。"},
	{"name":"祭火星芒", "kind":"volley", "mana":12.0, "cooldown":4.0, "damage":0.8, "reach":600.0, "count":3, "spell":"star", "desc":"短杖放出三枚祈愿星芒。"},
	{"name":"残刃重砸", "kind":"cone", "mana":14.0, "cooldown":5.0, "damage":1.6, "reach":185.0, "desc":"以破碎大剑重砸前方。"},
	{"name":"湮魂冥环", "kind":"circle", "mana":16.0, "cooldown":4.5, "damage":2.0, "reach":180.0, "spell":"vortex", "desc":"以魂镰切出冥火环斩。"}
]

static func of(index: int) -> Dictionary:
	var build: Dictionary=preload("res://scripts/rogue_content.gd").weapon(index)
	if not build.is_empty(): return build.art
	return MOVES[clampi(index,0,MOVES.size()-1)]

static func text(index: int) -> String:
	var move := of(index)
	return "战技 · %s [右键] · 蓝耗 %d · 冷却 %.1fs。%s" % [move.name,move.mana,move.cooldown,move.desc]
