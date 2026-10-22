extends RefCounted
## Actual moving objects, sculpted from facets; never a cropped concept picture.
const Builder=preload("res://scripts/weapon_vfx_mesh_3d.gd")
const Motion=preload("res://scripts/weapon_motion_design.gd")

static func panel(builder,center: Vector3,x: Vector3,y: Vector3,points: Array,tint: Color) -> void:
	var a: Array=points[0]; var b: Array=points[1]; var c: Array=points[2]
	var d: Array=points[3] if points.size()>3 else points[2]
	builder.quad(center+x*a[0]+y*a[1],center+x*b[0]+y*b[1],center+x*c[0]+y*c[1],center+x*d[0]+y*d[1],tint)

static func draw(flight: Dictionary,forward: Vector3,side: Vector3,up: Vector3,gain: float) -> void:
	var builder=Builder.new()
	var index := Motion.identity(int(flight.weapon_index))
	var center: Vector3=flight.p
	var size: Vector2=flight.body_size*gain
	var x := forward*size.x*.5
	var y := side*size.y*.5
	var tint: Color=flight.color
	var dark := tint.darkened(.58)
	var bright := tint.lerp(Color.WHITE,.30)
	var time := float(flight.age)
	if index in range(624,636):
		if str(flight.role)=="projectile_arrow":
			# A shaft, a physical head and tail vanes remain independently legible.
			panel(builder,center,x,y,[[-.75,-.08],[-.75,.08],[.62,-.08],[.62,.08]],Color("8f8574"))
			panel(builder,center,x,y,[[.42,-.30],[.42,.30],[1.0,0]],Color("b5c1c8"))
			for sign_y in [-1.0,1.0]:
				panel(builder,center,x,y,[[-.98,sign_y*.60],[-.90,sign_y*.13],[-.38,sign_y*.12],[-.62,sign_y*.56]],tint)
			if index==626:
				panel(builder,center,x,y,[[.13,-.42],[.44,-.13],[.54,.0]],dark)
				panel(builder,center,x,y,[[.13,.42],[.44,.13],[.54,.0]],dark)
		else:
			# Brass sabot and dark penetrator, no magical arrowhead or extra shot.
			var metal := Color("c9a773") if index in [624,633,635] else Color("a6b7c5")
			if index==630: metal=Color("40384c")
			panel(builder,center,x,y,[[-.80,-.40],[-.80,.40],[.45,-.33],[.45,.33]],metal.darkened(.12))
			panel(builder,center,x,y,[[.45,-.33],[.45,.33],[1.0,0]],Color("d9dce1") if index!=630 else bright.darkened(.35))
			panel(builder,center,x,y,[[-.70,-.15],[-.70,.02],[.45,-.15],[.45,.02]],metal.lightened(.18))
			if index in [628,629,631]:
				panel(builder,center,x,y,[[-.35,-.60],[-.55,-.25],[.34,-.35],[.05,-.50]],Color(tint,.60))
	elif index==637:
		# A dark meteor with hard planes; luminous fissure stays inside its mass.
		panel(builder,center,x,y,[[-.8,-.35],[-.6,.60],[.45,-.65],[.85,.12]],Color("4d3939"))
		panel(builder,center,x,y,[[-.6,.60],[.35,.72],[.85,.12],[.45,-.65]],Color("72504b"))
		panel(builder,center,x,y,[[-.45,.08],[-.3,.16],[.6,-.04],[.34,.10]],Color(tint,.85))
	elif index in [638,644,641]:
		panel(builder,center,x,y,[[-.95,-.13],[-.72,.28],[.95,0]],bright)
		panel(builder,center,x,y,[[-.95,-.13],[.0,-.38],[.95,0]],dark.lightened(.18))
	elif index==639:
		var previous := center-x
		for i in 7:
			var point := center+x*(float(i+1)/3.5-1)+y*sin(i*2.4+floor(time*20))*.42
			var width := y*.09
			builder.quad(previous-width,previous+width,point-width,point+width,bright)
			previous=point
	elif index in [640,20,622]:
		var previous := center-x*.40-y*.70
		for i in 14:
			var t := float(i+1)/14
			var point := center+x*(sin(t*PI)*.90-.40)+y*(t*1.4-.70)
			var width := x*sin(t*PI)*.15
			builder.quad(previous-width,previous+width,point-width,point+width,tint)
			previous=point
	elif index==642:
		panel(builder,center,x,y,[[-.9,-.22],[-.6,.32],[.98,.0]],dark.lightened(.20))
		for i in 4:
			var t := float(i)/4
			panel(builder,center-x*t*.9,x*.32,y,[[.0,-.65],[.2,-.09],[.90,.0]],Color(tint,.85))
	elif index==646:
		var wave := sin(time*6)*.08
		panel(builder,center,x,y,[[-.12,-.42],[-.20,.45],[.60,-.25],[.80,.12]],Color(tint,.82))
		for lane in 3:
			var shift := (lane-1)*.22
			panel(builder,center+y*shift,x,y,[[.16,-.13],[.11,.16],[-.98,-.30+wave],[-.66,.10+wave]],Color(tint,.35+lane*.10))
	elif index==647:
		var fold := sin(time*4)*.08
		panel(builder,center,x,y,[[-.78,-.28],[-.65,.35],[.18,-fold],[.15,.29]],Color(tint,.75))
		panel(builder,center,x,y,[[.18,-fold],[.15,.29],[.70,-.38],[.86,.13]],Color(tint.lightened(.16),.85))
		panel(builder,center,x,y,[[-.03,-.10],[-.08,.08],[.12,-.02]],Color("b99b63"))
	elif index==643:
		for lane in 3:
			var previous := center
			for i in 12:
				var t := float(i+1)/12
				var angle := t*4.3+lane*TAU/3-time*.8
				var radius := (.78-t*.56) if index==643 else sin(t*PI)*.72
				var point := center+x*(cos(angle)*radius-t*.35)+y*sin(angle)*radius
				var width := y*(1-t)*.11
				builder.quad(previous-width,previous+width,point-width,point+width,Color(tint,(1-t)*.70))
				previous=point
	elif index==645:
		var fold := .12+sin(time*5)*.08
		panel(builder,center,x,y,[[-.8,-.4],[-.65,.50],[.05,-fold],[.10,.42]],dark.lightened(.10))
		panel(builder,center,x,y,[[.05,-fold],[.10,.42],[.72,-.48],[.85,.20]],tint)
	else:
		# Compact starlight: unequal hard grit, not a symmetric decorative seal.
		for i in 5:
			var angle := i*2.39996+index*.12
			var at := center+x*cos(angle)*.40+y*sin(angle)*.44
			var a := x*(.22 if i else .46)
			var b := y*(.15 if i else .36)
			builder.quad(at-a,at-b,at+b,at+a,bright if i==0 else tint)
	builder.commit(flight.silhouette)
