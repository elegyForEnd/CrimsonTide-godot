class_name EnemyFrames
extends RefCounted

const NAMES := ["血晶食尸兔", "哀钟幽灵", "蔷薇刑偶", "赤月灾狐", "失乡骑士", "丧钟夜蛾", "禁卷鸦枭", "枯月骨鹿", "血棘妖", "雾汐冥水母", "腐羽狮鹫", "墓翼石像鬼", "溺钟怨灵", "提灯刽子手", "月碑巨像", "沉钟巨骸", "血棺守卫"]
const FILES := ["crystal-hare-nocturne", "moonbell-spirit-nocturne", "rose-armiger-nocturne", "redmoon-fox-nocturne", "banished-knight", "windbell-moth-nocturne", "archive-owl-nocturne", "mooncrystal-stag-nocturne", "thorn-bloom-nocturne", "mist-jelly-nocturne", "royal-griffin-nocturne", "grave-gargoyle", "drowned-bell-wraith", "lantern-executioner", "moon-monolith-colossus", "sunken-bell-carcass", "blood-coffin-warden"]
const HEIGHTS := [82.0, 104.0, 116.0, 120.0, 150.0, 94.0, 98.0, 118.0, 112.0, 106.0, 126.0, 138.0, 128.0, 150.0, 178.0, 172.0, 182.0]
# Pale telegraph accents stay legible against the desaturated night palette.
const COLORS := [Color("c87a83"), Color("a99cc8"), Color("bda387"), Color("c47780"), Color("e6cba2"), Color("b8b6a0"), Color("c6a77d"), Color("aa9bc9"), Color("bc798d"), Color("88afa9"), Color("c0967c"), Color("b3accc"), Color("91b8af"), Color("d6b88c"), Color("a58fc9"), Color("77aaa2"), Color("bd8578")]
var sheets: Array[Texture2D] = []

func _init() -> void:
	for file in FILES:
		sheets.append(load("res://assets/enemies/"+file+".png"))

static func pose(e: Dictionary, clock: float) -> int:
	if float(e.get("hp",1))<=0:
		return 11
	if float(e.get("stagger",0))>0 or float(e.get("flash",0))>0:
		return 10
	if int(e.type)==4 and e.get("choreo_cast",false) and float(e.get("attack_time",0))>0:
		if float(e.get("guard_time",0))>0: return 5
		# Cell 6 has a baked giant slash. Use the clean raised / extended / recovery
		# body poses; the socket renderer supplies the correctly aimed weapon path.
		return [4,4,4,4,5,5,7,7][int(preload("res://scripts/boss_attack_design.gd").beat(e).frame)]
	if float(e.get("guard_time",0))>0: return 5
	if float(e.get("attack_time",0))>0:
		var elapsed: float=float(e.attack_total)-float(e.attack_time)
		if e.get("raid_boss",false):
			return 5 if elapsed<e.attack_total-0.65 else 6
		if int(e.type)==4:
			var name: String=e.get("move_name","combo")
			var marks: Array=e.get("attack_marks",preload("res://scripts/boss_tactics.gd").KNIGHT_MOVES.get(name,preload("res://scripts/boss_tactics.gd").KNIGHT_MOVES.combo).marks)
			for mark in marks:
				if elapsed<float(mark): return 5
				if elapsed<float(mark)+0.18: return 6
			return 7
		var windup: float=Ecology.WINDUP[int(e.type)]
		if int(e.type)==11 and elapsed>=windup:
			return 6 if elapsed<windup+0.48 else 7
		if elapsed<windup*0.35:
			return 4
		if elapsed<windup:
			return 5
		return 6 if elapsed<windup+0.14 else 7
	if e.get("moving",false):
		return posmod(int(e.get("motion_phase",0)),4)
	return 8+posmod(int(clock*2+float(e.id)),2)

func region(index: int) -> Rect2:
	return Rect2((index%4)*256,(index/4)*256,256,256)

static func sprite_rect(kind: int) -> Rect2:
	var height: float=HEIGHTS[kind]
	if kind==4: return Rect2(-height*0.75,-height+12,height*1.5,height*1.5)
	# New atlases share a precise foot anchor at pixel 210 of their 256px cells.
	return Rect2(-height*0.75,8-height*1.5*210.0/256.0,height*1.5,height*1.5)
