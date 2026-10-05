extends RefCounted
## Presentation-only joint motion. Grounded boots never translate or scale.
const COLS := 12
const ROWS := 18
# period, breath, weight shift, wrist rotation, occasional ready gesture.
# Every campaign/issue weapon has its own authored timing and stance.
const PROFILES := [
	[3.4,.65,.35,.012,.035], # rifle: steady two-hand guard
	[2.8,1.05,.75,.025,.065], # sword: loosen wrist
	[4.2,1.2,.42,.016,-.04], # greatsword: settle weight
	[3.8,.85,.48,.022,.055], # star staff: gentle lift
	[4.8,1.15,.35,.018,.075], # meteor: deliberate reset
	[2.5,.6,.65,.035,.04], # needle: light forward readiness
	[2.9,.72,.52,.03,-.06], # lightning: short wrist check
	[4.1,.9,.8,.032,.045], # moon: circular wrist roll
	[4.5,.65,.25,.012,.085], # prism: upright precision
	[3.1,.95,.6,.027,-.045], # ember: relaxed outward lift
	[5.2,1.1,.65,.04,.06], # vortex: slow wrist circle
	[5.6,1.25,.28,.013,-.055], # eclipse: brace long focus
	[2.7,.7,.45,.02,.09], # rapier: forward guard check
	[3.3,.9,1.05,.038,-.075], # sabre: side weight shift
	[4.6,1.35,.62,.02,.035], # tide cleaver: shoulder settle
	[5.0,1.4,.3,.012,-.045], # quake: planted heavy guard
	[3.9,.8,.5,.018,.065], # bow: steady grip
	[2.6,.85,.68,.03,.05], # black iron: compact guard
	[4.0,.75,.4,.024,-.035], # ritual staff: measured breath
	[4.7,1.1,.55,.019,.045], # broken blade: weight adjustment
	[4.9,1.0,.78,.035,-.065], # scythe: slow grip roll
]
static var profile_cache: Dictionary={}
var states: Dictionary = {}

static func active(p: Dictionary) -> bool:
	return p.get("status","active")=="active" and p.get("motion","idle")=="idle" and float(p.get("swing_time",0))<=0 and float(p.get("cast_time",0))<=0 and float(p.get("dodge_time",0))<=0 and float(p.get("height",0))<=0 and float(p.get("build_landing_time",0))<=0

static func profile(weapon: int) -> Array:
	if weapon>=0 and weapon<PROFILES.size(): return PROFILES[weapon]
	if profile_cache.has(weapon): return profile_cache[weapon]
	# Run weapons inherit the handling of their own weight/rate/school, rather
	# than sharing one timing just because they share a sprite family.
	var w := Catalog.weapon(weapon)
	var family := Catalog.weapon_family(weapon)
	var n := maxi(0,weapon-600)
	var result: Array=[2.5+float(w.rate)*1.4+float(n%4)*.17,.65+float(w.windup)*.7,.3+float(n%7)*.09,.012+float(n%5)*.005,(-1.0 if n%2 else 1.0)*(.035+float(n%6)*.008)] if family!=2 else [4.0+float(w.windup)+float(n%4)*.19,1.1,.3+float(n%5)*.08,.014+float(n%3)*.004,-.035-float(n%4)*.009]
	profile_cache[weapon]=result
	return result

func tick(p: Dictionary, dt: float) -> void:
	var id: int=int(p.id)
	var state: Dictionary=states.get(id,{"time":0.0,"blend":0.0,"weapon":p.weapon,"hero":p.hero})
	if not active(p) or state.weapon!=p.weapon or state.hero!=p.hero:
		state.time=0.0; state.blend=0.0
	else:
		state.time+=dt
		state.blend=smoothstep(0.0,.28,float(state.time))
	state.weapon=p.weapon; state.hero=p.hero
	states[id]=state

func sample(p: Dictionary) -> Dictionary:
	return states.get(int(p.id),{"time":0.0,"blend":0.0})

static func displacement(at: Vector2, foot: Vector2, weapon: int, time: float, blend: float, side: float = 1.0) -> Vector2:
	var spec := profile(weapon)
	var phase := time*TAU/float(spec[0])
	var h := maxf(0.0,foot.y-at.y)
	var planted := smoothstep(9.0,36.0,h)
	var upper := smoothstep(22.0,65.0,h)
	var breath := sin(phase)*float(spec[1])
	var shift := sin(phase*.5)*float(spec[2])
	var out := Vector2(shift*upper,-breath*upper)
	# Head stays calm; sleeves, grip and blade/focus share the arm gesture.
	var hand := foot+Vector2(side*14,-42)
	var wrist_weight := smoothstep(6.0,28.0,side*(at.x-foot.x))*(1.0-smoothstep(58.0,79.0,h))
	var gesture_phase := fmod(time,float(spec[0])*2.0)/(float(spec[0])*2.0)
	var gesture := sin(smoothstep(.58,.78,gesture_phase)*PI)*float(spec[4])
	if gesture_phase>.78: gesture=0.0
	var angle := (sin(phase+.6)*float(spec[3])+gesture)*blend
	out+=(hand+(at-hand).rotated(angle)-at)*wrist_weight
	# Hair/cape have a delayed, very small secondary motion, not a body bob.
	var fringe := smoothstep(18.0,38.0,absf(at.x-foot.x))*smoothstep(38.0,65.0,h)
	out.x+=sin(phase-.7)*.45*fringe
	return out*planted*blend

static func geometry(pose: Dictionary, weapon: int, time: float, blend: float, side: float = 1.0) -> Dictionary:
	var texture: Texture2D=pose.texture
	var source: Texture2D=texture.atlas if texture is AtlasTexture else texture
	var region: Rect2=texture.region if texture is AtlasTexture else Rect2(Vector2.ZERO,texture.get_size())
	var rect: Rect2=pose.rect
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y in ROWS+1:
		for x in COLS+1:
			var uv := Vector2(float(x)/COLS,float(y)/ROWS)
			var at := rect.position+rect.size*uv
			points.append(at+displacement(at,CharacterMetrics.FOOT_OFFSET,weapon,time,blend,side))
			uvs.append((region.position+Vector2(.5,.5)+(region.size-Vector2.ONE)*uv)/source.get_size())
	for y in ROWS:
		for x in COLS:
			var cell := Rect2(rect.size*Vector2(float(x)/COLS,float(y)/ROWS),rect.size/Vector2(COLS,ROWS))
			var hidden := false
			for excluded: Array in pose.get("exclude",[]):
				var pixels := Rect2(excluded[0],excluded[1],excluded[2],excluded[3])
				var local := Rect2(pixels.position*rect.size/region.size,pixels.size*rect.size/region.size)
				if cell.intersects(local): hidden=true; break
			if hidden: continue
			var a := y*(COLS+1)+x
			indices.append_array(PackedInt32Array([a,a+COLS+1,a+1,a+1,a+COLS+1,a+COLS+2]))
	return {"points":points,"uvs":uvs,"indices":indices,"texture":source}

static func mesh(data: Dictionary, upright: bool = false, vertical_projection: float = 1.0, facing: float = 1.0) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for point: Vector2 in data.points:
		var at := point-CharacterMetrics.FOOT_OFFSET if upright else point
		vertices.append(Vector3(at.x*facing,-at.y/maxf(.1,vertical_projection),0)*.01 if upright else Vector3(at.x,at.y,0))
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=data.uvs; arrays[Mesh.ARRAY_INDEX]=data.indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
