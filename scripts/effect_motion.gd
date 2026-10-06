extends RefCounted
## One original image per entity. Reveal changes coverage, never source aspect or anchor.
const Library=preload("res://scripts/vfx_library.gd")
const FORMS=["center","sweep","rise","center","rise","forward","sweep","sweep","forward","forward","center","forward","forward","radial","sweep","rise","forward","sweep","center","sweep","sweep"]
const BIRTH=[.025,.045,.085,.070,.095,.028,.042,.070,.060,.040,.105,.090,.050,.075,.095,.100,.040,.050,.085,.090,.085]
static func profile(key: String, kind: String) -> Dictionary:
	var index := Library.source_weapon(key)
	var visual := Catalog.visual_weapon_index(index) if index>=0 else -1
	var form := str(FORMS[visual]) if visual>=0 else "center"
	var birth := float(BIRTH[visual]) if visual>=0 else .075
	if kind in ["slash","echo","spin"]: form="sweep" if kind!="spin" else "radial"
	if kind in ["charge","vortex","blessing"]: form="radial"; birth=.10
	if kind in ["eruption","soul","judgment"]: form="rise"; birth=.11
	if kind in ["lance","dash"]: form="forward"
	if kind in ["impact","muzzle"]: form="center"; birth=.018 if kind=="impact" else .025
	return {"form":form,"birth":birth,"index":index}
static func coverage(age: float, life: float, birth: float) -> float:
	return smoothstep(0.0,minf(birth,life*.40),maxf(0.0,age))
static func draw(target: CanvasItem, texture: Texture2D, rect: Rect2, amount: float, form: String, tint: Color, reverse: bool=false) -> void:
	var k := clampf(amount,0.0,1.0)
	if k<=.001: return
	if k>=.999:
		target.draw_texture_rect(texture,rect,false,tint); return
	if form in ["radial","sweep"]:
		var center := rect.get_center()
		var uv_center := Vector2.ONE*.5
		var start := -PI*.5 if form=="radial" else -PI
		var opening := TAU*k
		var radius := rect.size.length()*.5
		var wedge := PackedVector2Array([center])
		var steps := maxi(2,ceili(k*32))
		for i in steps+1:
			var angle := start+opening*i/steps*(-1.0 if reverse else 1.0)
			wedge.append(center+Vector2.from_angle(angle)*radius)
		var clipped := Geometry2D.intersect_polygons(wedge,PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]))
		for polygon in clipped:
			var uv := PackedVector2Array()
			for point in polygon: uv.append((point-rect.position)/rect.size)
			target.draw_polygon(polygon,PackedColorArray([tint]),uv,texture)
		return
	var uv_rect := Rect2(0,0,1,1)
	if form=="rise": uv_rect.position.y=1.0-k; uv_rect.size.y=k
	elif form=="forward": uv_rect.size.x=k; uv_rect.position.x=1.0-k if reverse else 0.0
	else: uv_rect=Rect2(Vector2.ONE*(1.0-k)*.5,Vector2.ONE*k)
	var destination := Rect2(rect.position+uv_rect.position*rect.size,uv_rect.size*rect.size)
	target.draw_texture_rect_region(texture,destination,Rect2(uv_rect.position*texture.get_size(),uv_rect.size*texture.get_size()),tint)
