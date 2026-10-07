extends RefCounted
## One geometry contract for damage, warning, animated texture clipping and tests.
const IDS := {"circle":0,"aura":0,"ring":1,"cone":2,"line":3,"lane":4,"gap_ring":5,"arc":6,"projectile":0,"capsule":7}
# Contact paths are authored against frame 4 (contact) and 5 (follow-through),
# in units of the painted reach. Warning shapes never define these movements.
const CONTACT_PATHS := {
	"whip":[[Vector2.ZERO,Vector2(.30,-.12),Vector2(.65,-.07),Vector2(1,-.15)],
		[Vector2.ZERO,Vector2(.30,-.08),Vector2(.60,.08),Vector2(.77,.20)]],
	"claw":[[Vector2.ZERO,Vector2(.5,-.10),Vector2(1,-.28)],
		[Vector2.ZERO,Vector2(.5,.02),Vector2(.94,.10)]],
	"bite":[[Vector2(.35,0),Vector2(1,0)],[Vector2(.35,0),Vector2(.96,0)]]}
static func aim(h: Dictionary) -> Vector2: return h.get("aim",h.get("direction",Vector2.RIGHT))
static func strike_age(h: Dictionary) -> float:
	return maxf(0.0,-float(h.time)) if h.has("time") else maxf(0.0,float(h.get("age",0)))
static func thrust_reach(h: Dictionary) -> float:
	return float(h.radius)*clampf(strike_age(h)/maxf(.01,float(h.get("strike_duration",.18)))*1.7,.18,1.0)
static func sweep_interval(h: Dictionary) -> Vector2:
	var arc := float(h.get("arc",1.05))
	var age := strike_age(h)
	var duration := maxf(.01,float(h.get("strike_duration",.18)))
	var head := lerpf(-arc,arc,clampf(age/duration,0,1))
	var previous := lerpf(-arc,arc,clampf((age-float(h.get("contact_dt",.035)))/duration,0,1))
	var interval := Vector2(maxf(-arc,previous-.12),minf(arc,head+.12))
	return Vector2(-interval.y,-interval.x) if h.get("sweep_reverse",false) else interval
static func contains(h: Dictionary, point: Vector2) -> bool:
	var v: Vector2=(point-h.p).rotated(-aim(h).angle())
	var radius := float(h.radius)
	var inner := float(h.get("inner",0))
	if h.has("strike_duration") and h.get("fired",h.get("active",false)):
		if strike_age(h)>float(h.strike_duration): return false
		if str(h.get("delivery",""))=="thrust": radius=thrust_reach(h)
		var delivery := str(h.get("delivery",""))
		if CONTACT_PATHS.has(delivery):
			var frame := 0 if strike_age(h)<float(h.strike_duration)*.5 else 1
			var path: Array=CONTACT_PATHS[delivery][frame]
			var width := maxf(10.0,radius*(.15 if delivery=="claw" else .12 if delivery=="bite" else .055))
			for i in path.size()-1:
				if Geometry2D.get_closest_point_to_segment(v,path[i]*radius,path[i+1]*radius).distance_to(v)<=width: return true
			return false
	match str(h.shape):
		"capsule": return Vector2(v.x-clampf(v.x,0,radius),v.y).length()<=inner
		"line": return v.x>=-22 and v.x<=radius and absf(v.y)<=44
		"lane": return v.x>=float(h.get("stream_forward",0)) and v.x<=radius and absf(v.y)<=inner
		"cone":
			if h.get("sweep",false) and h.get("fired",h.get("active",false)):
				var interval := sweep_interval(h)
				return v.length()<=radius and v.angle()>=interval.x and v.angle()<=interval.y
			return v.length()<=radius and absf(v.angle())<=float(h.get("arc",1.05))
		"arc": return v.length()<=radius and v.length()>=inner and absf(v.angle())<=float(h.get("arc",1.05))
		"gap_ring": return v.length()<=radius and v.length()>=inner and absf(v.angle())>float(h.get("gap",.5))
	return v.length()<=radius and v.length()>=inner
static func bounds(h: Dictionary) -> Rect2:
	if h.shape=="capsule": return Rect2(-float(h.inner),-float(h.inner),float(h.radius)+float(h.inner)*2,float(h.inner)*2)
	if h.shape=="line": return Rect2(-22,-44,float(h.radius)+22,88)
	if h.shape=="lane": return Rect2(0,-float(h.inner),float(h.radius),float(h.inner)*2)
	return Rect2(Vector2.ONE*-float(h.radius),Vector2.ONE*float(h.radius)*2)
static func shader_data(h: Dictionary) -> Dictionary:
	var rect := bounds(h)
	return {"shape":IDS.get(str(h.shape),0),"extent":rect.size,"center":rect.get_center(),"radius":float(h.radius),"inner":float(h.get("inner",0)),"arc":float(h.get("arc",1.05)),"gap":float(h.get("gap",.5)),"source_x":float(h.get("stream_forward",0))}

static func art_fit(h: Dictionary, native_size: Vector2) -> Vector2:
	var extent := bounds(h).size
	return native_size*minf(extent.x/native_size.x,extent.y/native_size.y)
