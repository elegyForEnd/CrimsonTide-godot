extends Control
## Code-native close-up diagrams: animated mechanisms, specimen details and tools.
var activity
var age := 0.0
const INK := Color("71624e")
const GOLD := Color("cca96a")
const TEAL := Color("88cbbf")
const PAPER := Color("d4c5a1")

func _ready() -> void: mouse_filter=MOUSE_FILTER_IGNORE
func _process(dt: float) -> void:
	age+=dt; queue_redraw()
func line(a: Vector2,b: Vector2,color: Color=INK,width: float=2) -> void: draw_line(a,b,color,width,true)
func circle(p: Vector2,r: float,color: Color=GOLD,width: float=2) -> void: draw_arc(p,r,0,TAU,64,color,width,true)
func block(rect: Rect2,color: Color,border: Color=INK) -> void:
	draw_rect(rect,color); draw_rect(rect,border,false,2)
func polygon(points: Array,color: Color) -> void: draw_colored_polygon(PackedVector2Array(points),color)

func _draw() -> void:
	if activity==null or activity.active.is_empty(): return
	var kind: String=activity.profile().prop
	var done: int=activity.done().size()
	var amount: float=(done+activity.progress*(0 if activity.selected in activity.done() else 1))/3.0
	var origin:=Vector2(300,225)
	# Fine ruled grid and survey coordinates stay subdued beneath the specimen.
	for x in range(24,600,24): line(Vector2(x,10),Vector2(x,438),Color(.75,.67,.49,.035),1)
	for y in range(10,440,24): line(Vector2(12,y),Vector2(596,y),Color(.75,.67,.49,.035),1)
	draw_set_transform(origin)
	draw_ellipse_shadow(Vector2(0,99),Vector2(145,28))
	if kind=="document":
		polygon([Vector2(-131,-120),Vector2(116,-134),Vector2(142,110),Vector2(-122,125)],PAPER)
		line(Vector2(-112,-100),Vector2(92,-111)); line(Vector2(-110,-91),Vector2(-42,-95))
		for i in 11:
			var y: float=-65+i*14
			line(Vector2(-100,y),Vector2(90-(i%3)*19,y-9),Color("8b7c61"),2)
		if activity.active.get("fact","")=="ledger":
			for i in 4: line(Vector2(-107,-11+i*5),Vector2(91,-19+i*5),Color("343238"),4)
			if done>0: draw_rect(Rect2(-113,-40,221,68),Color(.89,.76,.45,.24+.07*sin(age*2)))
		else:
			circle(Vector2(62,67),23,Color("9c4e51"),5)
			line(Vector2(45,52),Vector2(78,81),Color("9c4e51"))
		line(Vector2(117,-133),Vector2(94,-110)); line(Vector2(94,-110),Vector2(120,-111))
	elif kind=="valve":
		block(Rect2(-160,21,320,46),Color("434e52"),Color("7d8b87"))
		block(Rect2(-36,-54,72,122),Color("39484b"),GOLD)
		var angle: float=-amount*TAU+sin(age*4)*activity.progress*.045
		circle(Vector2(0,-40),90,Color("6b8a81"),13); circle(Vector2(0,-40),95,GOLD,2)
		for i in 6:
			var v:=Vector2.RIGHT.rotated(angle+i*TAU/6)
			line(Vector2(0,-40)+v*13,Vector2(0,-40)+v*84,GOLD,7)
		circle(Vector2(0,-40),15,GOLD,7)
		circle(Vector2(128,-95),32,PAPER,4)
		line(Vector2(128,-95),Vector2(128,-95)+Vector2.RIGHT.rotated(-2.5+amount*2)*24,TEAL,3)
	elif kind=="rope":
		block(Rect2(-153,-75,55,181),Color("554338"),GOLD)
		block(Rect2(98,-75,55,181),Color("554338"),GOLD)
		for j in 3:
			var points:=PackedVector2Array()
			for i in 50:
				var t: float=i/49.0
				points.append(Vector2(lerpf(-125,125,t),-25+sin(t*PI)*(62-amount*52)+sin(t*TAU*14+j*2)*2+j*4))
			draw_polyline(points,GOLD,2,true)
		circle(Vector2(-125,-30),25,GOLD,7); circle(Vector2(125,-30),25,GOLD,7)
		for i in 6: circle(Vector2(25+i*3,83),28-i*2,Color("98815a"),2)
	elif kind=="lamp":
		draw_set_transform(origin,(activity.alignment-.5)*.35 if activity.calibration() else 0)
		var glow: float=.12+amount*.18+sin(age*2)*.025
		for i in 6: draw_circle(Vector2(0,-15),84+i*8,Color(.69,.86,.73,glow/(i+3)))
		polygon([Vector2(-63,-84),Vector2(63,-84),Vector2(47,84),Vector2(-47,84)],Color(.44,.68,.63,.23))
		for x in [-1,1]: line(Vector2(x*63,-84),Vector2(x*47,84),GOLD,7)
		block(Rect2(-64,-95,128,16),Color("716049"),GOLD); block(Rect2(-55,81,110,16),Color("716049"),GOLD)
		circle(Vector2(0,-112),26,GOLD,4)
		polygon([Vector2(0,-50-sin(age*3)*4),Vector2(-18,34),Vector2(0,50),Vector2(18,34)],TEAL)
		line(Vector2(-13,0),Vector2(8,-32),PAPER,2)
	elif kind=="crystal":
		for i in 4: circle(Vector2.ZERO,101+i*10,Color(.8,.45,.54,.08),1)
		var bob: float=sin(age*1.8)*5
		polygon([Vector2(0,-121+bob),Vector2(53,-25+bob),Vector2(25,88+bob),Vector2(-22,105+bob),Vector2(-57,-12+bob)],Color("a04d69"))
		polygon([Vector2(0,-121+bob),Vector2(7,10+bob),Vector2(53,-25+bob)],Color("dc92a0"))
		polygon([Vector2(7,10+bob),Vector2(25,88+bob),Vector2(-22,105+bob)],Color("743f69"))
		line(Vector2(0,-121+bob),Vector2(7,10+bob),Color("f3c1be"))
		circle(Vector2.ZERO,131,GOLD,1)
	elif kind=="trace":
		polygon([Vector2(-159,-85),Vector2(116,-106),Vector2(168,87),Vector2(-113,121)],Color("343638"))
		for i in 6:
			var p:=Vector2(-80+(i%2)*73,-60+i*25)
			draw_ellipse_shadow(p,Vector2(14,24)); block(Rect2(p+Vector2(-12,17),Vector2(24,9)),Color("58524a"),Color("6e6452"))
		line(Vector2(-135,-65),Vector2(94,112),Color("817258"),3)
		line(Vector2(128,-89),Vector2(153,87),PAPER,7)
		for i in 10: line(Vector2(126+i*2,-75+i*15),Vector2(138+i*2,-77+i*15),INK,1)
	elif kind=="medical":
		block(Rect2(-146,-13,285,115),Color("554036"),GOLD)
		block(Rect2(-146,-96,285,80),Color("493b35"),GOLD)
		line(Vector2(-25,-58),Vector2(25,-58),PAPER,10); line(Vector2(0,-82),Vector2(0,-34),PAPER,10)
		for i in 3:
			var p:=Vector2(-94+i*75,20)
			block(Rect2(p,Vector2(38,64)),Color("597c78"),TEAL)
			block(Rect2(p+Vector2(5,-10),Vector2(28,13)),Color("ba9c71"),GOLD)
			block(Rect2(p+Vector2(3,21),Vector2(32,20)),PAPER,INK)
	elif kind=="lock":
		for x in range(-128,129,64): block(Rect2(x,-111,14,221),Color("515958"),Color("939786"))
		block(Rect2(-143,-103,286,18),Color("3c4648"),GOLD)
		block(Rect2(-143,74,286,18),Color("3c4648"),GOLD)
		block(Rect2(-82+amount*90,-12,164,18),GOLD,INK)
		circle(Vector2(0,-20),39,GOLD,5)
		block(Rect2(-39,0,78,58),Color("8b7753"),GOLD)
		draw_circle(Vector2(0,22),7,INK); line(Vector2(0,25),Vector2(0,40),INK,5)
	elif kind=="cart":
		var x: float=amount*55
		block(Rect2(-142+x,-88,242,145),Color("5f4737"),GOLD)
		for i in 5: line(Vector2(-124+x+i*48,-80),Vector2(-124+x+i*48,45),Color("8b7150"),3)
		for side in [-1,1]:
			var p:=Vector2(side*90+x,72)
			circle(p,36,GOLD,7)
			for i in 6: line(p,p+Vector2.RIGHT.rotated(i*TAU/6+amount*3)*31,GOLD,3)
	else:
		block(Rect2(-150,-48,300,121),Color("5e493a"),GOLD)
		for i in 6: line(Vector2(-143,-37+i*19),Vector2(143,-37+i*19),Color("7d6347"),1)
		circle(Vector2(0,-18),61,GOLD,6)
		for i in 8:
			var v:=Vector2.RIGHT.rotated(i*TAU/8+amount*2)
			line(v*47+Vector2(0,-18),v*75+Vector2(0,-18),GOLD,10)
		line(Vector2(-108,49),Vector2(106,-81),TEAL,7)
	# Inspection sweep and a lens follow the selected detail instead of a floating icon.
	if activity.selected>=0:
		var spots: Array=[Vector2(-60,-60),Vector2(63,-5),Vector2(-25,66)]
		var at: Vector2=spots[activity.selected]
		circle(at,38,TEAL if activity.selected in activity.done() else GOLD,2)
		circle(at,43,Color(.53,.8,.75,.2),4)
		line(at+Vector2(29,28),at+Vector2(55,58),GOLD,6)
		if activity.progress>0:
			draw_arc(at,48,-PI/2,-PI/2+TAU*activity.progress,48,TEAL,3,true)
	draw_set_transform(Vector2.ZERO)
	var leaders: Array=[PackedVector2Array([Vector2(229,55),Vector2(244,55),Vector2(248,149)]),PackedVector2Array([Vector2(378,55),Vector2(363,55),Vector2(363,193)]),PackedVector2Array([Vector2(259,398),Vector2(275,398),Vector2(275,318)])]
	for i in 3:
		var color:=Color(.53,.8,.75,.55) if i in activity.done() else Color(.71,.63,.46,.28)
		draw_polyline(leaders[i],color,1,true)

func draw_ellipse_shadow(at: Vector2,extent: Vector2) -> void:
	var points:=PackedVector2Array()
	for i in 48: points.append(at+Vector2(cos(i*TAU/48)*extent.x,sin(i*TAU/48)*extent.y))
	draw_colored_polygon(points,Color(0,0,0,.22))
