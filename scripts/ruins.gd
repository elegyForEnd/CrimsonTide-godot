class_name Ruins
extends RefCounted

const SIZE := Vector2(2800,2200)
const CENTER := SIZE/2
var walls: Array[Rect2] = []
var sites: Array = []
var chests: Array = []
var shrines: Array = []
var exits: Array = []
var decor: Array = []
var rng := RandomNumberGenerator.new()
var map_seed := 0

func generate(value: int) -> void:
	map_seed=value
	rng.seed=value
	walls.clear()
	sites.clear()
	chests.clear()
	shrines.clear()
	exits = [Vector2(240,1100),Vector2(2560,1100),Vector2(1400,260)]
	decor.clear()
	var names := ["灰烬诊所","失落书库","圣血大教堂","钟楼工坊","鸦羽庭院","月蚀宝库"]
	for row in 2:
		for col in 3:
			var i := row*3+col
			var pos := Vector2(520+col*860,600+row*1000)+Vector2(rng.randf_range(-65,65),rng.randf_range(-70,70))
			var room_size := Vector2(rng.randi_range(440,550),rng.randi_range(360,460))
			var rect := Rect2(pos-room_size/2,room_size)
			sites.append({"p":pos,"rect":rect,"name":names[i],"tier":2 if col==2 else 1})
			# Two generous doorways keep every room reachable from the roads.
			walls.append(Rect2(rect.position,Vector2(18,room_size.y)))
			walls.append(Rect2(rect.position+Vector2(room_size.x-18,0),Vector2(18,room_size.y)))
			var shoulder := (room_size.x-160)/2
			for dx in [0,shoulder+160]:
				walls.append(Rect2(rect.position+Vector2(dx,0),Vector2(shoulder,18)))
				walls.append(Rect2(rect.position+Vector2(dx,room_size.y-18),Vector2(shoulder,18)))
			for j in 3:
				# Contents are rolled the first time a chest is searched. The grid
				# is roomier in the deeper tier, so those runs carry more loot.
				chests.append({"p":pos+Vector2(-130+j*130,rng.randf_range(-90,90)),"key":"container","items":[],"open":false,"searched":0,"bonus":col==2 or rng.randf()<0.2,"class":2 if col==2 else 1})
			if i in [1,2,4]:
				shrines.append({"p":pos+Vector2(0,125),"done":false,"progress":0.0})
	for i in 230:
		decor.append({"p":Vector2(rng.randf_range(70,2730),rng.randf_range(70,2130)),"r":rng.randf_range(2,7),"type":rng.randi_range(0,2)})

func blocked(pos: Vector2, radius: float = 15.0) -> bool:
	if pos.x<40 or pos.y<40 or pos.x>SIZE.x-40 or pos.y>SIZE.y-40:
		return true
	for wall in walls:
		if wall.grow(radius).has_point(pos):
			return true
	return false

func move(from: Vector2, velocity: Vector2) -> Vector2:
	var result := from
	# Substeps prevent dashes from tunnelling through thin room walls.
	var steps := maxi(1,int(ceil(velocity.length()/9.0)))
	var step := velocity/steps
	for i in steps:
		var x := result+Vector2(step.x,0)
		if not blocked(x):
			result=x
		var y := result+Vector2(0,step.y)
		if not blocked(y):
			result=y
	return result

func clear_line(a: Vector2,b: Vector2) -> bool:
	var steps := maxi(1,int(a.distance_to(b)/12.0))
	for i in range(1,steps+1):
		if blocked(a.lerp(b,float(i)/steps),2):
			return false
	return true
