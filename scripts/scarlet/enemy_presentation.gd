extends Node2D
## Non-modal enemy tells, safe-ring fills and attack impacts. Uses exact rule geometry.
const Roster=preload("res://scripts/scarlet/enemy_roster.gd")
var screen
var impacts: Array=[]
func _ready() -> void:
	screen.campaign.combat_event.connect(event)
	screen.campaign.location_changed.connect(func(): impacts.clear())
func event(data: Dictionary) -> void:
	if data.kind=="enemy_release":
		impacts.append({"p":data.p,"aim":data.direction,"shape":data.shape,"radius":data.radius,"age":0.0})
func advance(dt: float) -> void:
	for impact in impacts: impact.age+=dt
	impacts=impacts.filter(func(x): return x.age<.38)
	queue_redraw()
func polygon(points: Array,tint: Color) -> void:
	var projected:=PackedVector2Array()
	for p in points: projected.append(screen.project(p))
	if projected.size()>2: draw_colored_polygon(projected,tint)
func ring(h: Dictionary,tint: Color) -> void:
	for i in 48:
		var a:=Vector2.RIGHT.rotated(i*TAU/48)
		var b:=Vector2.RIGHT.rotated((i+1)*TAU/48)
		polygon([h.p+a*float(h.inner),h.p+a*float(h.radius),h.p+b*float(h.radius),h.p+b*float(h.inner)],tint)
func _draw() -> void:
	if not screen.active or screen.modal or screen.photo_mode or screen.campaign.state.is_empty(): return
	var c=screen.campaign
	var font: Font=screen.theme.default_font
	for h in c.combat.hazards:
		var progress:=clampf(1.0-float(h.delay)/maxf(.01,float(h.total)),0,1)
		var tint:=Color(.95,.31,.39,.045+progress*.12) if h.delay>0 else Color(1,.7,.4,.26)
		if h.shape=="ring": ring(h,tint)
		else: polygon(screen.hazard_polygon(h),tint)
		if h.delay>0:
			var at: Vector2=screen.project(h.p)
			draw_arc(at,8,-PI*.5,-PI*.5+TAU*progress,32,Color("ffd7b0"),2,true)
	for e in c.enemies:
		if e.hp<=0: continue
		var at: Vector2=screen.project(e.p)
		if not e.boss:
			draw_string(font,at+Vector2(-44,-131),e.name,HORIZONTAL_ALIGNMENT_LEFT,180,13,Color("eddbbf"))
			if e.key=="royal_pikeman" and e.windup<=0 and e.recover<=0 and e.stagger<=0:
				var shield:=PackedVector2Array()
				for i in 17:
					shield.append(screen.project(Vector2(e.p)+Vector2(e.aim).rotated(lerpf(-1.1,1.1,i/16.0))*85*c.terrain().speed_scale()))
				draw_polyline(shield,Color("c9b78b"),2,true)
		if e.windup>0:
			var width:=clampf(float(e.windup)/maxf(.01,float(e.recover)),0,1)*72
			draw_rect(Rect2(at+Vector2(-36,-145),Vector2(72,3)),Color("3b2b33"))
			draw_rect(Rect2(at+Vector2(-36,-145),Vector2(width,3)),Color("f0bb87"))
		if e.boss:
			var label: String=""
			if e.windup>0: label=e.skill+"  ·  "+e.skill_hint
			elif e.recover>0: label="收招破绽 · 可反击"
			if label!="":
				var extent:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,18)
				draw_style_box(preload("res://scripts/scarlet/art.gd").frame(Color(.06,.04,.08,.9)),Rect2(Vector2(720-extent.x*.5-14,704),Vector2(extent.x+28,37)))
				draw_string(font,Vector2(720-extent.x*.5,729),label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe0b8"))
	for impact in impacts:
		var at: Vector2=screen.project(impact.p)
		var t: float=impact.age/.38
		var alpha:=1.0-t
		draw_arc(at,12+t*42,0,TAU,40,Color(1,.76,.53,alpha*.6),2,true)
		for i in 6:
			var direction:=Vector2.RIGHT.rotated(i*TAU/6+.25)
			draw_line(at+direction*(8+t*22),at+direction*(18+t*42),Color(1,.86,.68,alpha),1.4,true)
