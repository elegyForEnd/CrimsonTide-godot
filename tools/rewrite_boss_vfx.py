from pathlib import Path
p=Path('scripts/boss_vfx.gd')
s=p.read_text(encoding='utf-8')
s=s.replace('## Original art + moving shader volumes + textured particles + timed cut-ins.','## Independent painted boss effects; authoritative hazard geometry stays readable.')
s=s.replace('var sheets: Array=[]','const Art = preload("res://scripts/boss_effect_art.gd")')
start=s.index('\tfor key in Presentation.KEYS:')
end=s.index('\nfunc reset()',start)
s=s[:start]+s[end:]
s=s.replace('\n\tsheets.clear()','')
start=s.index('func region(')
end=s.index('func hazard(',start)
s=s[:start]+'''func stamp(target: CanvasItem, data: Dictionary, role: String, at: Vector2, size: Vector2, angle: float, opacity: float) -> void:
	var tex := Art.texture(Art.identity(data),role)
	if tex==null: return
	set_target_transform(target,at,angle)
	var fitted := tex.get_size()*minf(size.x/tex.get_width(),size.y/tex.get_height())
	target.draw_texture_rect(tex,Rect2(-fitted*.5,fitted),false,Color(1,1,1,clampf(opacity,0,1)))
	set_target_transform(target)

## Circumscribed sprites fit entirely inside an annulus and outside its safe gap.
func ring_points(fx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var radius := float(fx.get("radius",150))
	var inner := float(fx.get("inner",0))
	var mid := (radius+inner)*.5
	var diameter := minf(100,(radius-inner)*.62)
	if diameter<=0 or mid<=0: return result
	var margin := asin(clampf(diameter*.7072/mid,0,1))
	var shape := str(fx.get("shape","ring"))
	var aim: Vector2=fx.get("aim",Vector2.RIGHT)
	var start := 0.0
	var end := TAU
	if shape=="gap_ring":
		start=float(fx.get("gap",.5))+margin
		end=TAU-float(fx.get("gap",.5))-margin
	elif shape=="arc":
		start=-float(fx.get("arc",1.05))+margin
		end=float(fx.get("arc",1.05))-margin
	if end<=start: return result
	var count := clampi(ceili((end-start)*mid/100),3,24)
	for i in count:
		var angle := lerpf(start,end,(i+.5)/count)+(aim.angle() if shape!="ring" else 0.0)
		result.append({"p":Vector2.from_angle(angle)*mid,"size":diameter,"angle":angle+PI*.5})
	return result

''' +s[end:]
start=s.index('\tvar theme_color: Color=')
end=s.index('\tvar color :=',start)
s=s[:start]+'\tvar theme_color: Color=Art.color(h if kind<0 else with_theme(h,kind))\n'+s[end:]
# The caller's explicit knight theme must persist without losing special identities.
s=s.replace('kind=int(h.get("boss_kind",0)) if kind<0 else kind','var art_data := with_theme(h,int(h.get("boss_kind",0)) if kind<0 else kind)')
s=s.replace('Art.color(h if kind<0 else with_theme(h,kind))','Art.color(art_data)')
s=s.replace('stamp(target,kind,3 if kind==2 else 12,','stamp(target,art_data,"crest",')
s=s.replace('stamp(target,kind,5,','stamp(target,art_data,"burst",')
start=s.index('func _draw()')
end=s.index('func set_target_transform(',start)
s=s[:start]+'''func with_theme(data: Dictionary, kind: int) -> Dictionary:
	var copy := data.duplicate()
	copy["boss_kind"]=kind
	return copy

func _draw() -> void:
	for e in field.session.enemies:
		if not e.get("raid_boss",false) and not e.get("mini_boss",false) and int(e.type)!=4: continue
		if e.p.distance_to(field.camera)>1150: continue
		if float(e.get("guard_time",0))>0:
			var direction: Vector2=e.get("guard_aim",Vector2.RIGHT)
			stamp(self,e,"crest",e.p+direction*42-Vector2(0,28),Vector2.ONE*110,0,.55)
	for fx in effects:
		var t: float=fx.age/fx.duration
		var fade := pow(1-t,1.6)
		var at: Vector2=fx.p
		var aim: Vector2=fx.get("aim",Vector2.RIGHT)
		match str(fx.action):
			"release":
				var shape: String=fx.get("shape","circle")
				var radius: float=fx.get("radius",150.0)
				if shape in ["line","lane"]:
					var width := float(fx.get("inner",44)) if shape=="lane" else 44.0
					for segment in clampi(ceili(radius/160),1,12):
						var travel := minf(radius-30,70+segment*150+t*45)
						stamp(self,fx,"lance",at+aim*travel,Vector2.ONE*minf(210,width*4),aim.angle(),fade*.9)
				elif shape=="cone":
					var travel := 1-pow(1-t,2.4)
					var turn := -.12 if int(fx.get("part",0))%2==0 else .12
					stamp(self,fx,"slash",at+aim*radius*lerpf(.30,.56,travel),Vector2.ONE*radius*1.35,aim.angle()+turn*(1-t),fade*.92)
				elif shape in ["ring","gap_ring","arc"]:
					for point in ring_points(fx):
						stamp(self,fx,"lance",at+point.p,Vector2.ONE*point.size,point.angle,fade*.85)
				else:
					stamp(self,fx,"burst",at-Vector2(0,radius*.48),Vector2.ONE*radius*2.0*(1+t*.10),0,fade*.92)
			"charge":
				var charged := sin(t*PI*.5)
				stamp(self,fx,"crest",at-Vector2(0,65),Vector2.ONE*(85+charged*25),-t*.18,charged*.65)
			"guard", "break":
				stamp(self,fx,"crest" if fx.action=="guard" else "burst",at-Vector2(0,35),Vector2.ONE*(100 if fx.action=="guard" else 175)*(1+t*.2),t*.12,fade*.9)
			"entrance", "phase":
				stamp(self,fx,"crest",at-Vector2(0,120),Vector2.ONE*(240+sin(t*PI)*45),t*.25,sin(t*PI)*.72)
				if t<.4: stamp(self,fx,"burst",at-Vector2(0,70),Vector2.ONE*270,0,(1-t/.4)*.55)
			"fall":
				stamp(self,fx,"crest",at-Vector2(0,95+t*70),Vector2.ONE*(180+t*180),-t*.2,fade*.7)
				stamp(self,fx,"burst",at-Vector2(0,60+t*100),Vector2.ONE*(210+t*180),0,sin(t*PI)*.75)

func animate_event(fx: Dictionary) -> void:
	var action := str(fx.action)
	var at: Vector2=fx.p
	var col := Art.color(fx)
	var source := int(fx.id)
	if action in ["release","break","fall"]: energy.cancel_charge(source)
	# Painted bodies carry the attack; a few brief particles accent the apex.
	if action in ["entrance","phase","fall"]:
		cinematic.play(fx)
		energy.particles(at-Vector2(0,45),col,18,Vector2.UP,100,.6)
	elif action=="release" and fx.get("shape","") not in ["ring","gap_ring","arc"]:
		energy.particles(at-Vector2(0,15),col,6,fx.get("aim",Vector2.RIGHT),25,.35)
	elif action=="break":
		energy.particles(at-Vector2(0,30),col,12,Vector2.UP,120,.5)

''' +s[end:]
s=s.replace('"release":0.7','"release":0.48').replace('if effects.size()>=100','if effects.size()>=96')
p.write_text(s,encoding='utf-8')
