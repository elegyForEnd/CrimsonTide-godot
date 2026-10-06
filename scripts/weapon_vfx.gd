extends RefCounted
## Authored weapon identities and screen-space geometry. Presentation only.
## Run weapons intentionally keep their own identity instead of the icon mapping.
const CAMPAIGN := [
	["ballistic","ffd795",0], ["blood","ff426c",0], ["sun","ffba65",0],
	["star","9be3ff",0], ["ember","ff713d",0], ["frost","85f0ff",0],
	["storm","a9adff",0], ["moon","d5b6ff",0], ["sun","fff0a3",1],
	["feather","ffae6c",1], ["void","b57cff",0], ["oath","ed86d2",1],
	["feather","ece1ff",0], ["moon","ff87af",1], ["tide","71d6ec",0],
	["stone","ffcc8a",0], ["wind","b7dfaa",0], ["oath","e1a0b0",0],
	["bell","9ee8d9",0], ["feather","c1a5ef",2], ["soul","d771ff",0]]
const ROGUE := [
	["blood","ff426c",0], ["feather","d8dcff",0], ["moon","ff94ba",1],
	["blood","f34374",2], ["moon","c9d7ff",0], ["ember","ffb46b",1],
	["frost","87e8ff",0], ["storm","bcafff",0], ["oath","dfb993",0],
	["mirror","f0b6ed",1], ["bell","94ecdc",0], ["void","af99e9",2],
	["sun","ffc973",0], ["tide","6bdfef",0], ["stone","e6b584",0],
	["ember","ff8749",2], ["frost","c5eeff",2], ["storm","a8b5ff",2],
	["blood","f15d87",1], ["star","9abaff",2], ["ember","eab482",0],
	["wind","9ee6de",2], ["soul","b8a1ff",2], ["oath","ffe3a5",2],
	["ballistic","ffd795",0], ["feather","b7dfaa",0], ["blood","fa7c99",2],
	["ember","ff9c60",0], ["frost","a5e8ff",1], ["storm","b2bfff",1],
	["void","ccafef",0], ["mirror","ecc8ff",2], ["wind","a9ead9",0],
	["oath","f4ce9b",1], ["bell","92e4dd",1], ["sun","ffe9a2",2],
	["star","9be3ff",0], ["ember","ff713d",0], ["frost","85f0ff",0],
	["storm","a9adff",0], ["moon","d5b6ff",0], ["sun","fff0a3",1],
	["feather","ffae6c",1], ["void","b57cff",0], ["oath","ed86d2",1],
	["blood","fa7ca8",1], ["soul","a99aff",1], ["bell","a9f3df",2]]
const STYLES := {"blood":"petal", "sun":"star", "star":"star", "ember":"ember",
	"frost":"ice", "storm":"electric", "moon":"star", "void":"soul",
	"oath":"spark", "feather":"feather", "tide":"water", "stone":"stone",
	"wind":"feather", "bell":"star", "mirror":"ice", "soul":"soul", "ballistic":"spark"}

static func profile(index: int) -> Dictionary:
	var run_weapon := index>=600 and index<648
	var row: Array=ROGUE[index-600] if run_weapon else CAMPAIGN[clampi(index,0,20)]
	return {"weapon":index,"motif":str(row[0]),"color":Color(row[1]),"detail":int(row[2]),
		"style":str(STYLES[row[0]]),"run":run_weapon,"procedural":run_weapon and not preload("res://scripts/weapon_image_art.gd").available(index),"family":Catalog.weapon_family(index)}

static func stroke(combo: int, family: int, detail: int) -> Dictionary:
	var stage := clampi(combo,0,2)
	return {"scale":[.83,.96,1.12][stage],"life":[.19,.24,.34][stage]+(.045 if family==2 else 0.0),
		"opening":[1.45,2.15,2.85][stage],"width":[.085,.115,.16][stage]*(1.35 if family==2 else 1.0),
		"layers":2 if detail==2 or stage==2 else 1,"stage":stage}

static func line(target: CanvasItem, points: PackedVector2Array, color: Color, width: float, glow: bool) -> void:
	if points.size()<2: return
	if glow:
		target.draw_polyline(points,Color(color,color.a*.10),width*3.5,true)
		target.draw_polyline(points,Color(color.lerp(Color.WHITE,.55),color.a*.38),maxf(.7,width*.45),true)
	else:
		target.draw_polyline(points,color,maxf(.7,width),true)

static func ribbon(target: CanvasItem, radius: float, start: float, opening: float, width: float,
		progress: float, color: Color, glow: bool, flatten: float = 1.0) -> void:
	if progress<.001 or radius<.01 or color.a<.001: return
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var edge := PackedVector2Array()
	for i in 33:
		var u := float(i)/32
		var angle := start+opening*u*progress
		var taper := pow(sin(u*PI),.7)
		var r := radius*(.84+.16*u)
		var tip := Vector2(cos(angle),sin(angle)*flatten)
		outer.append(tip*(r+width*taper*.3))
		inner.append(tip*(r-width*taper))
		edge.append(tip*(r+width*taper*.32))
	if not glow:
		inner.reverse()
		var polygon := outer+inner
		target.draw_colored_polygon(polygon,Color(color,color.a*.65))
	line(target,edge,Color(color.lerp(Color.WHITE,.38),color.a*.85),1.25,glow)

static func gem(target: CanvasItem, at: Vector2, length: float, angle: float, color: Color, glow: bool) -> void:
	var forward := Vector2.from_angle(angle)*length
	var side := forward.orthogonal()*.22
	var points := PackedVector2Array([at-forward*.6,at-side,at+forward,at+side,at-forward*.6])
	if not glow: target.draw_colored_polygon(points,Color(color,color.a*.60))
	line(target,points,Color(color.lerp(Color.WHITE,.55),color.a),.9,glow)

static func sigil(target: CanvasItem, r: float, progress: float, color: Color, motif: String, detail: int, glow: bool) -> void:
	var sides := 6 if motif=="frost" else 3 if motif=="sun" else 4 if motif=="mirror" else 8
	for band in 2:
		var radius := r*(1.0 if band==0 else .66)
		for i in sides:
			var a := TAU*i/sides+progress*.35*(1 if band==0 else -1)
			var points := PackedVector2Array()
			for j in 6: points.append(Vector2.from_angle(a+float(j)/5*TAU/sides*.70)*radius)
			line(target,points,Color(color,color.a*(.70 if band==0 else .35)),1,glow)
	for i in sides:
		var a := TAU*i/sides+progress*.35
		gem(target,Vector2.from_angle(a)*r,r*.10,a+PI*.5,color,glow)
	if detail==2:
		for i in 3:
			var a := i*TAU/3-progress*.5
			line(target,PackedVector2Array([Vector2.from_angle(a)*r*.50,Vector2.from_angle(a+TAU/3)*r*.50]),Color(color,color.a*.45),1,glow)

static func draw(target: CanvasItem, fx: Dictionary, glow: bool) -> void:
	var identity: Dictionary=fx.identity
	var motif: String=identity.motif
	var detail: int=identity.detail
	var family: int=identity.family
	var stage: int=fx.stage
	var t := clampf(float(fx.age)/float(fx.life),0,1)
	var birth := smoothstep(0.0,.045 if family!=2 else .07,float(fx.age))
	var fade := pow(1.0-t,1.35)*smoothstep(0,.012,float(fx.age))
	var color := Color(identity.color,fade*.88)
	var r: float=fx.radius
	var kind: String=fx.kind
	if birth<.001 and kind!="charge": return
	if kind=="charge":
		color.a=smoothstep(0,.15,t)*(1.0-smoothstep(.85,1,t))*.60
		sigil(target,r*(.85-.25*t),t,color,motif,detail,glow)
		var art := preload("res://scripts/weapon_image_art.gd").texture(int(identity.weapon),0)
		if art:
			var size := Vector2.ONE*r*1.6
			target.draw_texture_rect(art,Rect2(-size*.5,size),false,Color(1,1,1,color.a*(.08 if glow else .38)))
		return
	if kind=="impact":
		gem(target,Vector2.ZERO,r*.72,0,Color(color.lerp(Color.WHITE,.7),fade),glow)
		gem(target,Vector2.ZERO,r*.42,PI*.5,Color(color,fade*.55),glow)
		if motif in ["frost","storm","mirror"]:
			for i in 3: gem(target,Vector2.from_angle(i*TAU/3)*r*t,r*.22,i*TAU/3,color,glow)
		return
	if kind=="core":
		var art := preload("res://scripts/weapon_image_art.gd").core_texture(int(fx.get("core_id",0)))
		if art:
			var size := Vector2.ONE*r*2
			target.draw_texture_rect(art,Rect2(-size*.5,size),false,Color(1,1,1,fade*(.12 if glow else .86)))
		return
	if kind in ["beam","chain"]:
		var points := PackedVector2Array()
		for i in 21:
			var sideways := sin(i*2.7)*7 if kind=="chain" and i>0 and i<20 else 0.0
			points.append(Vector2(r*i/20*birth,sideways))
		line(target,points,color,3.0 if kind=="beam" else 1.8,glow)
		if kind=="beam":
			for side in [-1,1]:
				line(target,PackedVector2Array([Vector2(0,side*9),Vector2(r*.4,side*5),Vector2(r,0)]),Color(color,color.a*.35),1,glow)
		gem(target,Vector2(r*birth,0),14,0,color,glow)
		var focus := preload("res://scripts/weapon_image_art.gd").texture(int(identity.weapon),2)
		if focus: target.draw_texture_rect(focus,Rect2(Vector2(r*birth-28,-28),Vector2(56,56)),false,Color(1,1,1,fade*(.12 if glow else .8)))
		return
	if preload("res://scripts/weapon_image_art.gd").available(int(identity.weapon)) and kind not in ["route","hero_combo"]:
		return # The painted asset owns the silhouette; simulation supplies only sparks.
	if kind=="detonation":
		var grow := .65+t*.5
		cast_shape(target,identity,r*grow,birth,color,glow)
		if motif=="ember":
			for i in 7: gem(target,Vector2.from_angle(i*TAU/7)*r*t,r*.15,-PI*.5,color,glow)
		else:
			for i in 3: ribbon(target,r*(.5+i*.2)*grow,i*2.1,1.5,r*.055,birth,Color(color,color.a*.45),glow)
		return
	if kind=="route":
		var route: int=fx.route
		if route==0: # Dodge pursuit: two long, tapered forward wakes.
			for side in [-1,1]:
				line(target,PackedVector2Array([Vector2(-r*.85,side*r*.23),Vector2(-r*.35,side*r*.12),Vector2(r*.3,0)]),color,2.0*(1-t),glow)
		elif route==1: # Returning route: two opposed curved wakes.
			for side in [-1,1]: ribbon(target,r*.65,side*1.6,-side*2.8,7,birth,color,glow,.6)
		elif route==2: # Rising route: crystals climb out of a vertical wake.
			for i in 3: gem(target,Vector2(i*8-r*.10,-r*(.25+float(i)*.3)*birth),r*.17,-PI*.5,color,glow)
		else: # Landing route: broken horizontal shock front.
			for side in [-1,1]: ribbon(target,r*(.5+t*.5),side*.15,side*1.1,r*.06,birth,color,glow,.35)
		return
	if kind=="hero_combo":
		var art := preload("res://scripts/weapon_image_art.gd").hero_texture(int(fx.hero),detail)
		if art:
			var size := art.get_size()*minf(r*2/art.get_width(),r*2/art.get_height())
			var higher: bool=int(fx.get("upgrade",{}).get("forge",0))>=5
			target.draw_texture_rect(art,Rect2(-size*.5,size),false,Color(1,1,1,fade*(.14 if glow and higher else .09 if glow else .92)))
			if detail==3:
				var ending := preload("res://scripts/weapon_image_art.gd").overlay(int(identity.weapon),2)
				if ending: target.draw_texture_rect(ending,Rect2(-size*.45,size*.9),false,Color(color,fade*(.08 if glow else .42)))
		match motif:
			"blood":
				for i in 2: ribbon(target,r*(.65+i*.22),-1.4+i*.25,2.8,r*.13,birth,color,glow)
			"frost":
				for i in 5: gem(target,Vector2.from_angle(-1.1+i*.55)*r*.45,r*.24,-PI*.5,color,glow)
				sigil(target,r*.6,birth,Color(color,color.a*.4),motif,detail,glow)
			"feather":
				for i in 5: gem(target,Vector2.from_angle(-1.1+i*.55)*r*.55,r*.28,-1.1+i*.55,color,glow)
			"soul":
				cast_shape(target,identity,r,birth,color,glow)
		return
	var spec := stroke(stage,family,detail)
	if identity.procedural:
		if kind in ["slash","echo","spin"]:
			var opening: float=spec.opening if kind!="spin" else TAU*.92
			for layer in int(spec.layers):
				var rr := r*(1.0-layer*.19)
				var cc := Color(color,color.a*(1.0-layer*.40))
				if motif=="storm":
					var points := PackedVector2Array()
					for j in 19:
						var a := -opening*.5+opening*j/18*birth
						points.append(Vector2.from_angle(a)*rr*(1.0+(.07 if j%2==0 else -.07)))
					line(target,points,cc,2.4 if family==2 else 1.6,glow)
				elif motif=="frost":
					for j in 7+stage*2:
						var u := float(j)/(6+stage*2)
						var a := -opening*.5+opening*u*birth
						gem(target,Vector2.from_angle(a)*rr,rr*(.11+.06*sin(u*PI)),a+PI*.5,cc,glow)
				elif kind=="spin" and motif in ["stone","ember","star"]:
					# Hammers send a broken shock front outwards, rather than a sword crescent.
					for j in 7+detail:
						var a := j*TAU/(7+detail)
						var points := PackedVector2Array([Vector2.from_angle(a)*rr*.4,Vector2.from_angle(a+.08)*rr*.62,Vector2.from_angle(a-.03)*rr*.85,Vector2.from_angle(a+.04)*rr])
						line(target,points,cc,1.8,glow)
						ribbon(target,rr,a,.40,rr*.12,birth,cc,glow,.6)
				else:
					var flatten := .64 if motif=="tide" else .85 if family==2 else 1.0
					var width: float=r*float(spec.width)*(1.35 if motif in ["tide","moon","soul"] else 1)
					var skew := .24 if motif=="blood" and detail==2 and layer==1 else 0.0
					ribbon(target,rr,-opening*.5+skew,opening,width,birth,cc,glow,flatten)
					if motif=="ember":
						for j in 5: gem(target,Vector2.from_angle(-opening*.4+j*opening*.2)*rr,rr*.17,-PI*.5,cc,glow)
		elif kind=="lance":
			var length := r*1.15*birth
			gem(target,Vector2(length*.25,0),length,0,color,glow)
			for side in [-1,1]: line(target,PackedVector2Array([Vector2(-r*.38,side*r*.09),Vector2(r*.20,side*r*.025),Vector2(length,0)]),color,1.2,glow)
		elif family==0:
			projectile_shape(target,identity,r,birth,color,glow)
		else:
			cast_shape(target,identity,r,birth,color,glow)
			if stage==2: sigil(target,r*.72,-birth,Color(color,color.a*.25),motif,detail,glow)
	# Elemental accents have actual geometry, not an identical ring recolored.
	var count := 3+detail+(2 if stage==2 else 0)
	for i in count:
		var u := float(i)/maxi(1,count-1)
		var a := lerpf(-1.05,1.05,u)
		var at := Vector2.from_angle(a)*r*(.82+t*.15)
		var size := r*(.065+.025*sin(u*PI))*(1-t*.55)
		match motif:
			"frost", "mirror", "stone": gem(target,at,size*(1.5 if motif=="frost" else 1),a+(PI*.25 if motif=="mirror" else 0),color,glow)
			"blood":
				gem(target,at,size,a+PI*.5,color,glow)
				if detail==2: gem(target,at+Vector2(0,r*.10),size*.8,a+PI*.5,color,glow)
			"feather", "wind":
				var end := at+Vector2.from_angle(a+PI*.6)*size*3
				line(target,PackedVector2Array([at,end]),color,1,glow)
				for j in 3:
					var base := at.lerp(end,float(j)/3)
					line(target,PackedVector2Array([base-Vector2(size*.7,size*.3),base,base+Vector2(size*.6,-size*.25)]),Color(color,color.a*.65),.8,glow)
			"storm":
				var points := PackedVector2Array()
				for j in 6: points.append(at+Vector2(j*size*.65,sin(j*2.7+i)*size*.8))
				line(target,points,color,1.3,glow)
			"ember": gem(target,at+Vector2(0,-t*r*.15),size*1.6,-PI*.5+a*.2,color,glow)
			"star", "sun", "bell":
				gem(target,at,size,0,color,glow)
				gem(target,at,size*.7,PI*.5,color,glow)
			"oath":
				line(target,PackedVector2Array([at+Vector2(-size,0),at+Vector2(size,0)]),color,1.2,glow)
				line(target,PackedVector2Array([at+Vector2(0,-size*1.5),at+Vector2(0,size)]),color,1.2,glow)
			"tide", "moon":
				ribbon(target,r*(.64+u*.20),a-.2,.48,size*.6,birth,Color(color,color.a*.4),glow)
			"void", "soul":
				ribbon(target,size*2,a+t*2,4.4,size*.30,birth,color,glow)
			_: gem(target,at,size*.5,a,color,glow)

static func projectile_shape(target: CanvasItem, identity: Dictionary, r: float, birth: float, color: Color, glow: bool) -> void:
	var motif: String=identity.motif
	var bow: bool=Catalog.weapon(int(identity.weapon)).get("spell","")=="arrow"
	if bow:
		var opening := 1.7
		ribbon(target,r*.50,-opening*.5,opening,r*.04,birth,color,glow)
		line(target,PackedVector2Array([Vector2(r*.33,-r*.37),Vector2(-r*.2,0),Vector2(r*.33,r*.37)]),Color(color,color.a*.50),1,glow)
		gem(target,Vector2(r*.25,0),r*.7*birth,0,color,glow)
		return
	match motif:
		"mirror":
			for side in [-1,1]: gem(target,Vector2(r*.22,side*r*.13),r*.65*birth,0,color,glow)
		"storm":
			for side in [-1,1]: line(target,PackedVector2Array([Vector2(-r*.2,0),Vector2(r*.15,side*r*.20),Vector2(r*.35,side*r*.05),Vector2(r*.8,side*r*.13)]),color,2,glow)
		"ember":
			for i in 3: gem(target,Vector2(r*.16,-r*.2+i*r*.2),r*(.65 if i==1 else .42)*birth,(-1+i)*.2,color,glow)
		"sun":
			for i in 5: gem(target,Vector2.from_angle(i*TAU/5)*r*.24,r*.32*birth,i*TAU/5,color,glow)
		"void", "oath":
			gem(target,Vector2(r*.3,0),r*.9*birth,0,color,glow)
			for i in 3: gem(target,Vector2(-i*r*.18,0),r*.08,PI*.5,color,glow)
		_:
			gem(target,Vector2(r*.2,0),r*.7*birth,0,color,glow)
			for side in [-1,1]: gem(target,Vector2(r*.03,side*r*.15),r*.24,side*.65,color,glow)

static func cast_shape(target: CanvasItem, identity: Dictionary, r: float, birth: float, color: Color, glow: bool) -> void:
	var motif: String=identity.motif
	match motif:
		"ember":
			for i in 5:
				var u := float(i)/4
				gem(target,Vector2(lerpf(-r*.35,r*.35,u),-r*.15),r*(.32+.34*sin(u*PI))*birth,-PI*.5+(u-.5)*.8,color,glow)
			ribbon(target,r*.55,0,PI,r*.13,birth,color,glow,.45)
		"frost":
			for i in 5: gem(target,Vector2.ZERO,r*(.8-absf(i-2)*.15)*birth,(i-2)*.27,color,glow)
		"storm":
			for side in [-1,0,1]:
				var points := PackedVector2Array()
				for i in 8: points.append(Vector2(i*r*.11,sin(i*2.2)*r*.08+side*i*r*.035)*birth)
				line(target,points,color,1.8,glow)
		"moon", "blood":
			ribbon(target,r*.65,-1.6,3.2,r*.19,birth,color,glow)
			if motif=="blood": ribbon(target,r*.45,-1.3,2.6,r*.11,birth,color,glow)
		"sun", "oath":
			gem(target,Vector2(r*.12,0),r*.85*birth,0,color,glow)
			for side in [-1,1]: gem(target,Vector2(-r*.12,side*r*.15),r*.33,0,Color(color,color.a*.5),glow)
		"feather":
			for i in 5: gem(target,Vector2.ZERO,r*.65*birth,(i-2)*.27,color,glow)
		"void", "soul":
			for i in 3: ribbon(target,r*(.25+i*.16),i*1.8+birth*.6,4.7,r*.085,birth,Color(color,color.a*(1-i*.16)),glow)
			if motif=="soul":
				for i in 3: gem(target,Vector2(-r*.2+i*r*.2,-r*.4),r*.22,-PI*.5,color,glow)
		"bell":
			sigil(target,r*.50,birth,color,motif,int(identity.detail),glow)
			for i in 3: gem(target,Vector2(-r*.25+i*r*.25,0),r*.23,-PI*.5,color,glow)
		_:
			for i in 4: gem(target,Vector2.ZERO,r*(.72 if i%2==0 else .4)*birth,i*PI*.5,color,glow)
			for i in 3: gem(target,Vector2(r*.55,-r*.22+i*r*.22),r*.10,0,color,glow)
