extends RefCounted
## One geometry contract for damage, warning, animated texture clipping and tests.
const IDS := {"circle":0,"aura":0,"ring":1,"cone":2,"line":3,"lane":4,"gap_ring":5,"arc":6,"projectile":0,"capsule":7}
static func aim(h: Dictionary) -> Vector2: return h.get("aim",h.get("direction",Vector2.RIGHT))
static func contains(h: Dictionary, point: Vector2) -> bool:
	var v: Vector2=(point-h.p).rotated(-aim(h).angle())
	var radius := float(h.radius)
	var inner := float(h.get("inner",0))
	match str(h.shape):
		"capsule": return Vector2(v.x-clampf(v.x,0,radius),v.y).length()<=inner
		"line": return v.x>=-22 and v.x<=radius and absf(v.y)<=44
		"lane": return v.x>=0 and v.x<=radius and absf(v.y)<=inner
		"cone": return v.length()<=radius and absf(v.angle())<=float(h.get("arc",1.05))
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
	return {"shape":IDS.get(str(h.shape),0),"extent":rect.size,"center":rect.get_center(),"radius":float(h.radius),"inner":float(h.get("inner",0)),"arc":float(h.get("arc",1.05)),"gap":float(h.get("gap",.5))}

static func art_fit(h: Dictionary, native_size: Vector2) -> Vector2:
	var extent := bounds(h).size
	return native_size*minf(extent.x/native_size.x,extent.y/native_size.y)
