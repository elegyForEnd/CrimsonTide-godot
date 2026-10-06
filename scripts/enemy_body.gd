extends RefCounted
## Upright sprite bounds expressed in the authoritative simulation coordinates.
## Walking radii remain ground footprints; they are not combat hurtboxes.
const GROUND_Y := 24.0 / sqrt(24.0 * 24.0 + 19.0 * 19.0)
var enemies: EnemyFrames
var bosses: BossFrames
var rogue_art: RefCounted
var crops: Dictionary = {}

func pose(e: Dictionary, clock: float, rogue: bool) -> Dictionary:
	var facing := float(e.get("facing",1))
	if rogue and (e.get("rogue_minion",false) or e.get("rogue_guardian",false)):
		if rogue_art==null: rogue_art=preload("res://scripts/rogue_art.gd").new()
		var big: bool=e.get("rogue_guardian",false)
		var height := 255.0 if big else 78.0+(int(e.get("rogue_variant",0))%4)*3.0
		var index := int(clock*5+e.id)%4
		if e.get("moving",false): index=4+int(e.motion_phase)%4
		if e.get("attack_time",0)>0 and not e.get("choreo_cast",false):
			var passed: float=e.attack_total-e.attack_time
			var windup: float=e.get("boss_windup",e.get("minion_windup",.55))
			var half := 4 if big else 2
			var step: int=mini(half-1,int(passed/maxf(.01,windup)*half)) if passed<windup else half+mini(half-1,int((passed-windup)/maxf(.01,e.attack_total-windup)*half))
			index=(8+int(e.boss_skill)*8 if big else 8+int(e.get("minion_skill",0))*4)+step
		var frame: Dictionary=rogue_art.boss_animation(int(e.get("boss_art",e.rogue_skin)),index,int(e.rogue_skin)) if big else rogue_art.minion_animation(int(e.rogue_skin),int(e.get("rogue_variant",0)),index)
		var texture: Texture2D=frame.texture
		var h := height*float(frame.get("scale_ratio",1))
		var w := h*texture.get_width()/texture.get_height()
		return {"texture":texture,"rect":Rect2(-w/2,-h,w,h),"region":Rect2(),"facing":facing,
			"hover":sin(clock*9+e.id)*2 if e.get("moving",false) else 0.0}
	if e.get("raid_boss",false) or e.get("mini_boss",false):
		if bosses==null: bosses=BossFrames.new()
		var special: bool=e.get("mini_boss",false) or e.get("final_form",false) or e.get("abyss_final",false)
		var index: int=6 if e.get("dragon_boss",false) else 3+clampi(int(e.get("wild_kind",0)),0,2) if e.get("wild_boss",false) else 2 if e.get("final_form",false) else clampi(int(e.get("mini_kind",0)),0,1)
		if not special: index=clampi(int(e.boss_kind),0,2)
		var key: String=BossFrames.SPECIAL_KEYS[index] if special else BossFrames.KEYS[index]
		var attack: Dictionary=bosses.attack_sprite(key,e)
		if not attack.is_empty(): return {"texture":attack.texture,"rect":attack.rect,"region":Rect2(),"facing":facing*float(attack.facing),"hover":0.0}
		return {"texture":bosses.special_sheet(index) if special else bosses.sheets[index],
			"rect":bosses.special_sprite_rect(index) if special else bosses.sprite_rect(index),
			"region":BossFrames.region(BossFrames.pose(e,clock)),"facing":facing,
			"hover":sin(clock*(2.2 if index==2 else 3.1)+int(e.id))*(5 if index==0 else 2) if special else sin(clock*2.6)*3.0 if index!=1 else 0.0}
	if enemies==null: enemies=EnemyFrames.new()
	var kind := clampi(int(e.type),0,EnemyFrames.HEIGHTS.size()-1)
	var hover := sin(clock*4+e.id)*3 if kind in [1,5,6,9,12] else 0.0
	if kind==11 and float(e.get("attack_time",0))>0:
		var progress := clampf((e.attack_total-e.attack_time-Ecology.WINDUP[kind])/.48,0,1)
		hover=-sin(progress*PI)*44
	return {"texture":enemies.sheets[kind],"rect":EnemyFrames.sprite_rect(kind),
		"region":enemies.region(EnemyFrames.pose(e,clock)),"facing":facing,"hover":hover}

func bounds(e: Dictionary, clock: float, rogue: bool) -> Rect2:
	if e.get("boss_construct",false):
		var radius := float(e.get("rogue_radius",20))
		return Rect2(e.p-Vector2.ONE*radius,Vector2.ONE*radius*2)
	var visual := pose(e,clock,rogue)
	var texture: Texture2D=visual.texture
	var region: Rect2=visual.region
	var key := str(texture.get_instance_id())+str(region)
	if not crops.has(key):
		var source: Image=texture.get_image()
		if region.size!=Vector2.ZERO: source=source.get_region(Rect2i(region))
		crops[key]={"size":Vector2(source.get_size()),"used":Rect2(source.get_used_rect())}
	var crop: Dictionary=crops[key]
	var rect: Rect2=visual.rect
	var used: Rect2=crop.used
	var factor: Vector2=rect.size/crop.size
	var body := Rect2(rect.position+used.position*factor,used.size*factor)
	if float(visual.facing)<0: body.position.x=-body.end.x
	var projection := 1.0 if rogue else GROUND_Y
	body.position.y/=projection
	body.size.y/=projection
	# Hover in the 3D field is a ground displacement; sprite pixels are upright.
	body.position+=e.p+Vector2(0,float(visual.hover)-float(e.get("height",0))/projection-(0.0 if rogue else 2.0*19.0/24.0))
	return body

static func corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

static func projectile_clear_line(world: Ruins, from: Vector2, to: Vector2, rogue: bool) -> bool:
	if not rogue: return world.clear_line(from,to)
	# The walkable floor's edge cannot block an upright boss's head. Solid
	# walls and props still block player shots; enemy shots keep ground rules.
	for wall in world.walls:
		if wall.has_point(from) or wall.has_point(to): return false
		var points := corners(wall)
		for i in 4:
			if Geometry2D.segment_intersects_segment(from,to,points[i],points[(i+1)%4])!=null: return false
	for prop in world.obstacles:
		var start: Vector2=(from-prop.p)/(prop.radius+Vector2.ONE*2)
		var end: Vector2=(to-prop.p)/(prop.radius+Vector2.ONE*2)
		if Geometry2D.get_closest_point_to_segment(Vector2.ZERO,start,end).length_squared()<1: return false
	return true

func segment_hit(e: Dictionary, from: Vector2, to: Vector2, clock: float, rogue: bool, padding: float = 0.0) -> bool:
	var rect := bounds(e,clock,rogue).grow(padding)
	if rect.has_point(from) or rect.has_point(to): return true
	var points := corners(rect)
	for i in 4:
		if Geometry2D.segment_intersects_segment(from,to,points[i],points[(i+1)%4])!=null: return true
	return false

func attack_hit(e: Dictionary, origin: Vector2, aim: Vector2, reach: float, clock: float, rogue: bool,
		shape: String = "cone", width: float = 26.0, cosine: float = -0.1, height: float = 0.0) -> bool:
	origin-=Vector2(0,height/(1.0 if rogue else GROUND_Y))
	var rect := bounds(e,clock,rogue)
	var points := PackedVector2Array()
	if shape in ["thrust","beam"]:
		var side := aim.orthogonal()*width
		points=PackedVector2Array([origin-side,origin+aim*reach-side,origin+aim*reach+side,origin+side])
	else:
		var half := PI if shape in ["circle","burst","spin","quake"] else acos(clampf(cosine,-1,1))
		if half<PI: points.append(origin)
		for i in 49: points.append(origin+aim.rotated(lerpf(-half,half,i/48.0))*reach)
	return not Geometry2D.intersect_polygons(corners(rect),points).is_empty()
