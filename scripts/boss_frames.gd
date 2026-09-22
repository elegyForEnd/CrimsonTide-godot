class_name BossFrames
extends RefCounted

const KEYS := ["bell-hierophant","thorn-huntsman","blood-queen"]
const HEIGHTS := [185.0,185.0,215.0]
const TITLES := ["葬钟圣座","荆棘王誓","永夜月冠"]
const COLORS := [Color("bb9deb"),Color("ed7c91"),Color("f1c174")]
const PHASES := [["葬钟","月蚀"],["猎誓","断誓"],["月冠","血潮","永夜"]]
# Normalized coordinates in the generated 2172 x 724 UI textures.
const TRACKS := [Rect2(0.251,0.454,0.630,0.080),Rect2(0.241,0.483,0.638,0.087),Rect2(0.257,0.454,0.610,0.082)]
var sheets: Array[Texture2D]=[]
var portraits: Array[Texture2D]=[]
var headers: Array[Texture2D]=[]
var footprints: Array=[]

func _init() -> void:
	for key in KEYS:
		sheets.append(load("res://assets/bosses/"+key+"-atlas.png"))
		portraits.append(load("res://assets/bosses/"+key+"-portrait.png"))
		headers.append(load("res://assets/bosses/"+key+"-hud.png"))
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bosses/atlas-layout.json"))
	for key in KEYS:
		footprints.append(float(data[key].packed_height))

func sprite_rect(kind: int) -> Rect2:
	var factor: float=HEIGHTS[kind]/footprints[kind]
	return Rect2(Vector2(-256,-460)*factor,Vector2(512,512)*factor)

static func region(index: int) -> Rect2:
	return Rect2((index%4)*512,(index/4)*512,512,512)

static func pose(e: Dictionary, clock: float) -> int:
	if float(e.get("hp",1))<=0: return 11
	if float(e.get("attack_time",0))>0:
		var passed: float=e.attack_total-e.attack_time
		var windup: float=e.get("windup",1.15)
		if passed<windup*0.35: return 4
		if passed<windup: return 5
		if passed<windup+0.28: return 6
		return 7
	if float(e.get("flash",0))>0: return 10
	if e.get("moving",false): return posmod(int(e.get("motion_phase",0)),4)
	return 8+posmod(int(clock*2+float(e.id)),2)
