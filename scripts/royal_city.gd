class_name RoyalCity
extends Ruins

const GATE := Vector2(1400,1920)
const BOSS := Vector2(1400,610)

func generate(value: int) -> void:
	map_seed=value
	extent=Vector2(2800,2200)
	interior=true
	walls.clear()
	sites.clear()
	chests.clear()
	shrines.clear()
	exits.clear()
	decor.clear()
	regions.clear()
	regions.append({"name":"晨曦王城","polygon":PackedVector2Array([Vector2.ZERO,Vector2(2800,0),extent,Vector2(0,2200)]),"color":Color("baa996")})
	for spec in [["王座大厅",Rect2(740,220,1320,840)],["白蔷回廊",Rect2(260,1120,2280,380)],["晨钟前庭",Rect2(780,1540,1240,480)]]:
		var area: Rect2=spec[1]
		sites.append({"name":spec[0],"rect":area,"p":area.get_center(),"tier":2,"biome":5,"prop":5})
	# Crosswalls leave broad central doors; side galleries connect into the nave.
	walls.assign([Rect2(120,120,2560,40),Rect2(120,120,40,1960),Rect2(2640,120,40,1960),Rect2(120,2040,2560,40),Rect2(160,1010,1060,40),Rect2(1580,1010,1060,40),Rect2(160,1510,1060,40),Rect2(1580,1510,1060,40)])
	for x in [640,2160]:
		for y in [380,700,1210,1740]:
			walls.append(Rect2(x-32,y-32,64,64))
	for pos in [Vector2(460,1280),Vector2(2340,1280)]:
		chests.append({"p":pos,"key":"container","items":[],"open":false,"searched":0,"bonus":true,"class":2})
	decor.append({"p":Vector2(1400,360),"type":5,"size":240.0,"landmark":true})
	for x in [930,1870]:
		decor.append({"p":Vector2(x,1790),"type":3,"size":165.0,"landmark":true})

func blocked(pos: Vector2, radius: float = 15.0) -> bool:
	if not Rect2(Vector2(160,160),Vector2(2480,1880)).grow(-radius).has_point(pos): return true
	for wall in walls:
		if wall.grow(radius).has_point(pos): return true
	return false
