class_name EnemyFrames
extends RefCounted

const NAMES := ["血晶兔灵", "月铃浮灵", "蔷薇甲偶", "赤月狐卫", "失乡骑士"]
const FILES := ["crystal-hare", "moonbell-spirit", "rose-armiger", "redmoon-fox", "banished-knight"]
const HEIGHTS := [72.0, 82.0, 96.0, 112.0, 150.0]
const COLORS := [Color("f29aa9"), Color("c2b5ff"), Color("efd59b"), Color("ff8b9e"), Color("e6cba2")]
var sheets: Array[Texture2D] = []

func _init() -> void:
	for file in FILES:
		sheets.append(load("res://assets/enemies/"+file+".png"))

static func pose(e: Dictionary, clock: float) -> int:
	if float(e.get("hp",1))<=0:
		return 11
	if float(e.get("stagger",0))>0 or float(e.get("flash",0))>0:
		return 10
	if float(e.get("attack_time",0))>0:
		var elapsed: float=float(e.attack_total)-float(e.attack_time)
		if int(e.type)==4:
			var name: String=e.get("move_name","combo")
			var marks: Array=[0.65,1.10,1.65] if name=="combo" else ([0.85] if name=="thrust" else [1.15])
			for mark in marks:
				if elapsed<float(mark): return 5
				if elapsed<float(mark)+0.18: return 6
			return 7
		var windup: float=[0.26,0.42,0.56,0.32][int(e.type)]
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
