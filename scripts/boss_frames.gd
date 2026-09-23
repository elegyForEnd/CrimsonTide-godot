class_name BossFrames
extends RefCounted

const KEYS := ["bell-hierophant","thorn-huntsman","blood-queen"]
const HEIGHTS := [185.0,185.0,215.0]
const SPECIAL_KEYS := ["mirror-weaver","ashen-vesper","nameless-moon","earthsplitter","storm-roc-v2","moon-leviathan","frostbone-dragon"]
const SPECIAL_HEIGHTS := [185.0,185.0,245.0,210.0,210.0,275.0,240.0]
const TITLES := ["葬钟圣座","荆棘王誓","永夜月冠"]
const COLORS := [Color("bb9deb"),Color("ed7c91"),Color("f1c174")]
const PHASES := [["葬钟","月蚀"],["猎誓","断誓"],["月冠","血潮","永夜"]]
# Normalized coordinates in the generated 2172 x 724 UI textures.
const TRACKS := [Rect2(0.251,0.454,0.630,0.080),Rect2(0.241,0.483,0.638,0.087),Rect2(0.257,0.454,0.610,0.082)]
var sheets: Array[Texture2D]=[]
var portraits: Array[Texture2D]=[]
var headers: Array[Texture2D]=[]
var footprints: Array=[]
var special_sheets: Array[Texture2D]=[]
var special_footprints: Array=[]
var special_paths: Array[String]=[]

func _init() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/bosses/motion-atlas.json"))
	for key in KEYS:
		sheets.append(load("res://assets/bosses/"+key+"-atlas.png"))
		portraits.append(load("res://assets/bosses/"+key+"-portrait.png"))
		headers.append(load("res://assets/bosses/"+key+"-hud.png"))
		footprints.append(float(data[key].packed_height))
	special_sheets.resize(SPECIAL_KEYS.size())
	for key in SPECIAL_KEYS:
		special_paths.append(str(data[key].path))
		special_footprints.append(float(data[key].packed_height))

func special_sheet(index: int) -> Texture2D:
	if special_sheets[index]==null:
		special_sheets[index]=load(special_paths[index])
	return special_sheets[index]

func sprite_rect(kind: int) -> Rect2:
	var factor: float=HEIGHTS[kind]/footprints[kind]
	return Rect2(Vector2(-480,-685)*factor,Vector2(960,720)*factor)

func special_sprite_rect(index: int) -> Rect2:
	var factor: float=SPECIAL_HEIGHTS[index]/special_footprints[index]
	return Rect2(Vector2(-480,-685)*factor,Vector2(960,720)*factor)

static func region(index: int) -> Rect2:
	return Rect2((index%4)*960,(index/4)*720,960,720)

static func pose(e: Dictionary, clock: float) -> int:
	if float(e.get("hp",1))<=0: return 11
	if float(e.get("stagger",0))>0: return 10
	if float(e.get("guard_time",0))>0: return 5
	if float(e.get("attack_time",0))>0:
		var passed: float=e.attack_total-e.attack_time
		if e.has("attack_marks"):
			for mark in e.attack_marks:
				if passed<float(mark)-0.22: return 5
				if passed<float(mark): return 4
				if passed<float(mark)+0.20: return 6
			return 7
		var windup: float=e.get("windup",1.15)
		if passed<windup*0.35: return 4
		if passed<windup: return 5
		if passed<windup+0.28: return 6
		return 7
	if float(e.get("flash",0))>0: return 10
	if e.get("moving",false): return posmod(int(e.get("motion_phase",0)),4)
	return 8+posmod(int(clock*2+float(e.id)),2)
