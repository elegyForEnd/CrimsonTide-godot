class_name CombatVisuals
extends Node2D
## Textured additive effects; no dependency on renderer-specific 2D bloom.
var field: CanvasItem
const Motion = preload("res://scripts/effect_motion.gd")
const Library = preload("res://scripts/vfx_library.gd")
var stylized = preload("res://scripts/stylized_vfx.gd").new()
var extraction_vortex: Texture2D = preload("res://assets/world/landmarks/extraction-vortex.png")
const SPELL_CELLS := {"meteor":0,"needle":1,"chain":2,"moon":3,"prism":4,"scatter":5,"vortex":6,"eclipse":7}
var motes: Array = []
var extract_flashes: Array = []
# 澧撶厹's ultimate leaves two kinds of residue on the field: the rune-sword rain
# itself, and the patch of underworld fire it burns into the ground afterwards.
var rune_patches: Array = []
var flames: Array = []
var trauma := 0.0
var numbers: Array = []
var particles=preload("res://scripts/combat_particles.gd").new()
var enemy_particle_states: Dictionary={}
var last_particle_trail := 0.0
var elapsed := 0.0
var spell_light: Node2D
var energy = preload("res://scripts/energy_bursts.gd").new()
const SPELL_COLORS := [Color("ff8454"),Color("a7e9ff"),Color("c6a6ff"),Color("cfdbff"),Color("ffd7a0"),Color("ffb474"),Color("ac85ff"),Color("ed95de")]
# 澧撶厹's palette: a violet rune glow over a darker underworld flame.
const SOUL := Color("c07ae0")
const SOUL_FIRE := Color("a855f7")
# The ultimate's art, all of it from assets/combat/ with the rest of the hero
# sheets: the underworld flame strip (5 cells in one row), the curse sigil the
# cast opens with, the ring that stands in for the old purple outline, and the
# single rain blade that is laid inside it.
const FIRE_COLUMNS := 5
const FIRE_ROWS := 1
# Six blades and six flames, both spread over the ring rather than scattered: the
# count and the spacing are the whole look, so they are constants, not literals.
const RAIN_BLADES := 6
const RAIN_FLAMES := 6
const RAIN_TILT := 34.0         # degrees off upright, one way or the other
# How far a position may wander inside its own sector.  The sectors are 60 degrees
# apart, so the wander has to stay well under half of that or two neighbours can
# close the gap the even spread exists to keep.
const SPREAD_JITTER := 0.16
# How far out from the middle of the ring a blade or a flame may stand, as a
# fraction of the ring's own radius.  Inside 1.0, so nothing overhangs the edge
# that the damage test draws.
const SPREAD_RADIUS := 0.74
const FLAME_TILT := 12.0        # flames lean a little, and stay upright enough
var fire_art: Texture2D = null
var sigil_art: Texture2D = null
var ring_art: Texture2D = null
var blade_art: Texture2D = null

func _ready() -> void:
	var additive := ShaderMaterial.new()
	additive.shader=preload("res://resources/combat_glow.gdshader")
	material=additive
	z_index=1
	add_child(energy)
	add_child(particles)
	add_child(stylized)
	if field.has_method("weapon_effect_socket"):
		stylized.socket_provider=field.weapon_effect_socket
	spell_light=Node2D.new()
	var spell_material := CanvasItemMaterial.new()
	spell_material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	spell_light.material=spell_material
	add_child(spell_light)
	spell_light.draw.connect(draw_spells)

func reset() -> void:
	motes.clear()
	particles.reset()
	enemy_particle_states.clear()
	extract_flashes.clear()
	rune_patches.clear()
	flames.clear()
	energy.reset()
	stylized.reset()
	numbers.clear()
	trauma=0.0

# Loaded on first use: the necromancer's art is optional, so a missing file
# degrades to individual common textures if optional art is unavailable.
func soul_art() -> void:
	if fire_art==null and ResourceLoader.exists("res://assets/combat/muyu-flames.png"):
		fire_art=Library.texture("soul_fire_0")
	if sigil_art==null and ResourceLoader.exists("res://assets/combat/muyu-hex-ring.png"):
		sigil_art=load("res://assets/combat/muyu-hex-ring.png")
	if ring_art==null and ResourceLoader.exists("res://assets/combat/muyu-circle.png"):
		ring_art=load("res://assets/combat/muyu-circle.png")
	if blade_art==null and ResourceLoader.exists("res://assets/combat/muyu-sword.png"):
		blade_art=load("res://assets/combat/muyu-sword.png")

func necro_cell(sheet: Texture2D, columns: int, rows: int, index: int) -> Rect2:
	var unit := Vector2(sheet.get_width()/float(columns),sheet.get_height()/float(rows))
	var cell := Vector2i(index%columns,index/columns)
	return Rect2(Vector2(cell)*unit+Vector2.ONE*3,unit-Vector2.ONE*6)

func necro_stamp(sheet: Texture2D, columns: int, rows: int, index: int, at: Vector2,
		extent: Vector2, angle: float, tint: Color, target: CanvasItem = null) -> void:
	if target==null: target=spell_light
	if sheet==fire_art:
		if absf(target.get_global_transform().determinant())<.000001: return
		target.draw_set_transform_matrix(target.get_global_transform().affine_inverse()*Transform2D(angle,target.get_global_transform()*at))
		var key := "soul_fire_%d" % (index%5)
		var fitted := Library.fitted_size(key,extent)
		Motion.draw(target,Library.texture(key),Rect2(-fitted/2,fitted),clampf(float(tint.a)*1.4,0,1),"rise",tint)
		target.draw_set_transform(Vector2.ZERO)
		return
	target.draw_set_transform(at,angle)
	var region := necro_cell(sheet,columns,rows,index)
	var fitted := region.size*minf(absf(extent.x)/region.size.x,absf(extent.y)/region.size.y)
	target.draw_texture_rect_region(sheet,Rect2(-fitted*.5,fitted),region,tint)
	target.draw_set_transform(Vector2.ZERO)

# The rain: the curse sigil opens on the ground, then the patch itself brings in
# the ring and the six blades that stand in it (see draw_spells).  Host settles
# the damage; this is presentation only.
func necromancer_burst(at: Vector2, aim_angle: float) -> void:
	soul_art()
	var aim := Vector2.from_angle(aim_angle)
	spawn(7,at,Vector2(420,240),0.9,aim_angle,Color(SOUL,0.9))
	spawn(3,at,Vector2(300,300),1.0,0,Color(SOUL,0.55))
	if sigil_art:
		spawn(0,at,Vector2(430,430),1.1,0,Color(1,1,1,0.95),0.0,Vector2.ZERO)
		motes[motes.size()-1]["art"]=sigil_art
		motes[motes.size()-1]["columns"]=1
		motes[motes.size()-1]["rows"]=1
	energy.spawn(at+aim*200,Vector2(400,65),Color(SOUL_FIRE,.55),1,.6,aim_angle)
	spawn(6,at+aim*300,Vector2(72,72),.6,aim_angle,Color(SOUL_FIRE),.08,Vector2(0,-50))
	# The sigil mote above is rendered by _draw; combat events run outside drawing.

func spawn(cell: int, at: Vector2, size: Vector2, duration: float, angle: float = 0.0, tint: Color = Color.WHITE, delay: float = 0.0, velocity: Vector2 = Vector2.ZERO) -> void:
	if motes.size()>=240:
		motes.pop_front()
	motes.append({"cell":cell,"p":at,"size":size,"duration":duration,"age":-delay,"angle":angle,"tint":tint,"velocity":velocity})

func spell_fx(spell: String, at: Vector2, size: Vector2, duration: float, angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	if not SPELL_CELLS.has(spell):
		return
	spawn(int(SPELL_CELLS[spell]),at,size,duration,angle,tint)
	motes[motes.size()-1]["spell_art"]=true

func event(data: Dictionary) -> void:
	if field.has_method("ground_transform"): transform=field.ground_transform()
	var at: Vector2=data.p
	if at.distance_to(field.camera)>1100:
		return
	var aim_dir: Vector2=data.get("aim",Vector2.RIGHT)
	var angle := aim_dir.angle()
	var weapon := int(data.get("weapon",0))
	var spell := str(data.get("spell","star"))
	if data.kind=="enemy_defeated" and not data.get("rogue_guardian",false) and not data.get("raid_boss",false):
		var style: String=["stone","soul","ember","feather"][int(data.get("type",0))%4]
		particles.burst(at-Vector2(0,25),Vector2.UP,Color("c6a6a0"),style,20,.8,PI)
	var source_hero := int(data.get("hero",0))
	var source: Dictionary=field.session.players.get(int(data.get("id",-1)),{})
	if not data.has("hero") and not source.is_empty(): source_hero=int(source.get("hero",source_hero))
	var visual_data := data
	if data.kind=="impact":
		visual_data=data.duplicate()
		var radius := 20.0
		for enemy in field.session.enemies:
			if enemy.id==int(data.get("enemy_id",-1)):
				radius=float(enemy.get("rogue_radius",Ecology.RADIUS[clampi(int(enemy.type),0,16)])); break
		if absf(get_global_transform().determinant())>.000001:
			var screen_aim := get_global_transform().basis_xform(aim_dir).normalized()
			var contact := get_global_transform()*at-screen_aim*radius*.65-Vector2(0,26)
			visual_data["contact_p"]=get_global_transform().affine_inverse()*contact
	stylized.event(visual_data,source_hero)
	spell_energy(data,spell,at,aim_dir)
	match data.kind:
		"spell_beam":
			spell_fx("prism",at,Vector2.ONE*70,0.26,angle)
		"spell_arc":
			var target: Vector2=data.target
			var delta := target-at
			spell_fx("chain",target,Vector2.ONE*70,0.26,delta.angle())
		"spell_burst":
			spell_fx(spell,at,Vector2.ONE*(290 if spell=="meteor" else 260),0.65)
			trauma=maxf(trauma,0.38 if spell=="meteor" else 0.20)
		"dodge": pass
		"windup": pass
		"necromancer-cast":
			# The grimoire opens and a violet ward sigil hangs under her feet for
			# the whole cast, so the staff branch reads as a spell rather than a bow.
			spawn(8,at-Vector2(0,14),Vector2(132,132),maxf(0.32,float(data.get("windup",0.3)))*1.1,0,Color(SOUL,0.62))
			spawn(6,at+aim_dir*24-Vector2(0,30),Vector2(72,72),0.34,angle,Color(SOUL,0.8))
			motes.back()["socket_source"]=int(data.get("id",-1))
		"strike":
			if weapon==2: trauma=maxf(trauma,.3)
			if weapon in [0,3]:
				spawn(4,at,Vector2.ONE*18,.12,angle,Color.WHITE)
				motes.back()["launch_source"]=int(data.get("id",-1))
				if field.has_method("weapon_effect_socket") and absf(get_global_transform().determinant())>.000001:
					var socket: Dictionary=field.weapon_effect_socket(int(data.get("id",-1)))
					if not socket.is_empty(): motes.back()["launch_local"]=get_global_transform().affine_inverse()*socket.tip
		"impact":
			var heavy: bool=data.get("heavy",false)
			trauma=maxf(trauma,0.65 if heavy else 0.24)
			numbers.append({"p":at-Vector2(0,55),"age":0.0,"value":str(roundi(data.damage)),"heavy":heavy})
		"skill":
			trauma=maxf(trauma,.45)
			if int(data.hero)==TideSession.NECROMANCER:
				necromancer_burst(at,angle)
		"necromancer-fire":
			var forward := float(data.get("forward",480.0))
			var half := float(data.get("half",175.0))
			var patch_seed := blade_seed(at,aim_dir)
			rune_patches.append({"at":at,"aim":aim_dir,"age":0.0,
				"duration":float(data.get("duration",6.0)),"forward":forward,
				"half":half,"spawned":0.0,
				"blades":blade_layout(patch_seed,forward,half),
				"flames":flame_spots(patch_seed)})
			trauma=maxf(trauma,0.5)
		"burn":
			flames.append({"p":at,"age":0.0,"duration":0.42})

func legacy(kind: String, at: Vector2) -> void:
	if at.distance_to(field.camera)>1100:
		return
	match kind:
		"guard": spawn(4,at,Vector2(95,75),0.22,0,Color(0.55,0.88,1))
		"guard-break":
			spawn(4,at,Vector2(180,140),0.45,0,Color(1,0.76,0.35))
			trauma=maxf(trauma,0.2)
		"hit": pass # Authoritative impact owns the one contact flash.
		"hurt":
			spawn(7,at,Vector2(105,90),0.25)
			trauma=maxf(trauma,0.35)
		"dash": pass # The authoritative dodge event owns its painted trail.
		"bell": spawn(8,at-Vector2(0,100),Vector2(210,330),1.0)
		"extract":
			extract_flashes.append({"p":at,"age":0.0})
			spawn(8,at-Vector2(0,75),Vector2(235,360),0.9,0,Color(0.53,1.0,0.85))
			spawn(3,at-Vector2(0,10),Vector2(170,170),0.65,0,Color(0.55,1.0,0.9,0.8))
			energy.spawn(at-Vector2(0,75),Vector2(180,270),Color("8bf5d7"),0,0.72)
			energy.particles(at-Vector2(0,20),Color("a4ffe5"),26,Vector2.UP,130,0.75)
		"skill": spawn(3,at,Vector2(100,65),0.55,0,Color(0.6,1,0.8,0.5))
		"loot": spawn(5,at,Vector2(55,70),0.4)

func _process(dt: float) -> void:
	if not field.visible:
		return
	elapsed+=dt
	energy.advance(dt)
	for player in field.session.players.values():
		if player.status!="active" or player.dodge_time>0 or (not player.pending_strike and player.cast_time<=0):
			stylized.cancel_charge(int(player.id))
	stylized.advance(dt)
	observe_particles(dt)
	trauma=move_toward(trauma,0,dt*2.6)
	if field.has_method("ground_transform"):
		transform=field.ground_transform()
	else:
		position=field.offset
	if field.has_method("weapon_effect_socket"):
		for burst in energy.bursts:
			if not burst.has("socket_source"): continue
			var socket: Dictionary=field.weapon_effect_socket(int(burst.socket_source))
			if socket.is_empty(): continue
			if absf(energy.get_global_transform().determinant())<.000001: continue
			burst.mount.transform=energy.get_global_transform().affine_inverse()*Transform2D(0,socket.tip)
	for i in range(motes.size()-1,-1,-1):
		motes[i].age+=dt
		if motes[i].age>motes[i].duration:
			motes.remove_at(i)
	for i in range(extract_flashes.size()-1,-1,-1):
		extract_flashes[i].age+=dt
		if extract_flashes[i].age>0.9:
			extract_flashes.remove_at(i)
	for i in range(rune_patches.size()-1,-1,-1):
		rune_patches[i].age+=dt
		if rune_patches[i].age>rune_patches[i].duration:
			rune_patches.remove_at(i)
	for i in range(flames.size()-1,-1,-1):
		flames[i].age+=dt
		if flames[i].age>flames[i].duration:
			flames.remove_at(i)
	for i in range(numbers.size()-1,-1,-1):
		numbers[i].age+=dt
		if numbers[i].age>0.7:
			numbers.remove_at(i)
	queue_redraw()
	spell_light.queue_redraw()

func stamp(cell: int, at: Vector2, size: Vector2, angle: float, tint: Color) -> void:
	var extent := Library.fitted_size("common_%d" % cell,size)
	var mirror := Vector2(-1.0 if size.x<0 else 1.0,-1.0 if size.y<0 else 1.0)
	draw_set_transform(at,angle,mirror)
	Motion.draw(self,Library.texture("common_%d" % cell),Rect2(-extent/2,extent),clampf(tint.a*1.5,0,1),"center",tint)

func _draw() -> void:
	for player in field.session.players.values():
		if player.status!="active" or not str(player.get("target","")).begins_with("exit:") or float(player.get("channel",0))<=0:
			continue
		var progress: float=clampf(float(player.channel)/4.0,0,1)
		var at: Vector2=player.p
		var vortex_rect := Rect2(at-Vector2(73,191+sin(elapsed*2)*6),Vector2(146,205+progress*58))
		draw_texture_rect(extraction_vortex,vortex_rect,false,Color(1,1,1,0.12+progress*0.52))
		stamp(3,at+Vector2(0,5),Vector2.ONE*(105+progress*72),elapsed*0.42,Color(0.45,1.0,0.82,0.16+progress*0.20))
		stamp(8,at-Vector2(0,70),Vector2(95+progress*85,180+progress*130),0,Color(0.50,1.0,0.82,0.12+progress*0.27))
		for i in 6:
			var drift := fposmod(elapsed*(0.55+float(i%3)*0.13)+float(i)*0.17,1.0)
			var side := sin(float(i)*2.399+elapsed*1.8)*46.0*(1.0-drift*0.35)
			stamp(6,at+Vector2(side,-14-drift*125),Vector2(14,23)*(0.7+progress*0.5),0,Color(0.56,1.0,0.86,(0.12+progress*0.30)*(1.0-drift)))
	for flash in extract_flashes:
		var t: float=flash.age/0.9
		draw_texture_rect(extraction_vortex,Rect2(flash.p-Vector2(83+28*t,215+45*t),Vector2(166+56*t,245+62*t)),false,Color(1,1,1,0.95*(1.0-t)))
	for fx in motes:
		if fx.age<0:
			continue
		var t: float=fx.age/fx.duration
		var fade := minf(1,t*18)*pow(1-t,1.3)
		var tint: Color=fx.tint
		tint.a*=fade
		if fx.has("launch_source") and field.has_method("weapon_effect_socket"):
			var socket: Dictionary={"tip":get_global_transform()*fx.launch_local} if fx.has("launch_local") else {}
			if not socket.is_empty():
				var endpoint: Vector2=fx.p
				var closest := INF
				for bullet in field.session.bullets:
					if int(bullet.get("owner",-1))!=int(fx.launch_source): continue
					var distance: float=bullet.p.distance_squared_to(fx.p)
					if distance<closest: closest=distance; endpoint=bullet.p
				var end := get_global_transform()*endpoint
				# The short launch trail joins the upright muzzle to the ground trajectory.
				# Whole independent sparks are placed along it without stretching art.
				draw_set_transform_matrix(get_global_transform().affine_inverse())
				draw_line(socket.tip,end,Color(tint,tint.a*.35),1.6,true)
				draw_set_transform(Vector2.ZERO)
				continue
		if fx.has("socket_source") and field.has_method("weapon_effect_socket"):
			var socket: Dictionary=field.weapon_effect_socket(int(fx.socket_source))
			if not socket.is_empty():
				var screen_pose := Transform2D(socket.aim.angle(),socket.tip)
				draw_set_transform_matrix(get_global_transform().affine_inverse()*screen_pose)
				var key := "common_%d" % int(fx.cell)
				var extent := Library.fitted_size(key,fx.size)
				draw_texture_rect(Library.texture(key),Rect2(-extent*.5,extent),false,tint)
				draw_set_transform(Vector2.ZERO)
				continue
		if fx.has("art"):
			# A reference piece with its own sheet rather than a cell of the
			# independent effect textures.
			necro_stamp(fx.art,int(fx.get("columns",1)),int(fx.get("rows",1)),
				int(fx.get("index",0)),fx.p+fx.velocity*fx.age,
				fx.size*lerpf(0.72,1.18,t),fx.angle,tint,self)
		elif not fx.get("spell_art",false):
			stamp(fx.cell,fx.p+fx.velocity*fx.age,fx.size*lerpf(0.72,1.18,t),fx.angle,tint)
	for bullet in field.session.bullets:
		if bullet.get("boss_projectile",false): continue
		if bullet.has("rogue_tone"): continue
		var spell := str(bullet.get("spell","star"))
		if SPELL_CELLS.has(spell): continue
		if int(bullet.get("owner",0))>0:
			var index := int(bullet.get("weapon_index",field.session.players.get(bullet.owner,{}).get("weapon",0)))
			var extent := Vector2(65,30) if int(bullet.get("weapon",0))==3 else Vector2(42,18)
			var key := Library.weapon_key(index)
			extent=Library.fitted_size(key,Vector2.ONE*extent.x)
			draw_set_transform(bullet.p-Vector2(0,float(bullet.get("height",0))),bullet.v.angle(),Vector2(Library.facing_scale(key),1))
			Motion.draw(self,Library.texture(key),Rect2(-extent*.5,extent),Motion.coverage(float(bullet.get("visual_age",.1)),.3,.03),"forward",Color.WHITE,Library.facing_scale(key)<0)
		else:
			stamp(2,bullet.p,Vector2(65,34),bullet.v.angle(),Color(1,.5,.6))

	draw_set_transform(Vector2.ZERO)

# The patch's outline in its own frame: the caster sits at the origin, the
# rectangle runs from TideSession.FIRE_BACK behind her feet to `forward` ahead
# and `half` to each side. The damage test (TideSession.inside_reap) reads the
# same shape, so the purple box can only ever cover ground that really burns.
static func patch_local_rect(forward: float, half: float, grow: float = 1.0) -> Rect2:
	var back := TideSession.FIRE_BACK*grow
	return Rect2(Vector2(-back,-half*grow),Vector2(forward*grow+back,half*2.0*grow))

# --- the ring and the blades inside it ---------------------------------------
# The telemetry of the ultimate is a rectangle, but its art is a ring, so the
# ring is drawn across the rectangle's whole extent rather than inscribed in it:
# the ellipse touches all four edges and covers the corners' worth of ground the
# rectangle burns.  Nothing below feeds back into aim or damage - it is all
# presentation over the same constants.

enum { BLADE_CENTRE, BLADE_EXTENT, BLADE_ANGLE, BLADE_MIRROR }

static func spread_over_ring(rng: RandomNumberGenerator, count: int, rings: int,
		swirl: float, reach: float) -> Array:
	"""`count` positions spread evenly over the ring, not scattered in it.

	The ring is cut into equal sectors and each sector gets exactly one position,
	with the radius staggered ring by ring, so however the dice fall the positions
	stay apart: pure rejection sampling clumps, and a clump of six blades reads as
	one thick smear rather than as rain.  `swirl` turns the whole fan, so two
	sets can share the ring without lining up, and the inner radius keeps every
	position clear of the middle, where the caster is standing."""
	var step := TAU/float(count)
	var placed: Array = []
	for index in count:
		var band := index%rings
		var angle := swirl+step*(float(index)+rng.randf_range(-SPREAD_JITTER,SPREAD_JITTER))
		var radius := lerpf(0.40,reach,float(band)/float(maxi(1,rings-1)))
		placed.append(Vector2.from_angle(angle)*radius)
	return placed

static func blade_layout(seed_value: int, forward: float, half: float) -> Array:
	"""Six blades, fixed for the life of the patch, spread over the ring.

	Seeded from the patch's own position and aim, so every client lays out the
	same rain without sending a word about it.  Each blade is turned a little way
	from upright, half of them mirrored, and every one is small enough that its
	four corners fall inside the ring - the corners are checked here rather than
	trusted, because a blade that pokes out of the circle would draw a lie about
	which ground is on fire."""
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	# Blade size is set by the ring's *short* axis, not its long one: a blade sits
	# somewhere on the ring, and at a position off to the side the distance to the
	# edge is the half-width, not the half-length.  Sizing off the long axis makes
	# blades that only fit near the middle, and the fit-nudge then drags them in
	# there - which is exactly the clumping this layout exists to avoid.
	var height := half*0.42
	var width := height*0.49
	var placed: Array = []
	var spots := spread_over_ring(rng,RAIN_BLADES,2,0.0,SPREAD_RADIUS)
	for index in spots.size():
		var scale := rng.randf_range(0.85,1.12)
		var tilt := deg_to_rad(rng.randf_range(-RAIN_TILT,RAIN_TILT))
		var extent := Vector2(width,height)*scale
		var centre: Vector2=spots[index]*Vector2(half,forward*0.5)
		# Nudge inwards until every corner is inside the ring, so the fit is
		# guaranteed rather than hoped for.
		for attempt in 24:
			var fits := true
			for corner in 4:
				var offset := Vector2(-1.0 if corner<2 else 1.0,-1.0 if corner%2==0 else 1.0)*extent/2
				var at := centre+offset.rotated(tilt)
				if Vector2(at.x/half,at.y/(forward*0.5)).length()>0.96:
					fits=false
					break
			if fits:
				break
			centre*=0.9
		# Half the rain turns around, and which half alternates rather than being
		# drawn: a run of six identical blades, or six reversed ones, is a coin
		# flip away if the flag is random, and it does not read as rain at all.
		var mirrored := index%2==1
		if rng.randf()<0.25:
			mirrored=not mirrored
		placed.append([centre,extent,tilt,mirrored])
	return placed

static func flame_spots(seed_value: int) -> Array:
	"""Where the six flames stand: over the ring like the blades, but turned by
	half a sector so the two sets interleave instead of stacking up."""
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value+7717
	return spread_over_ring(rng,RAIN_FLAMES,2,PI/float(RAIN_FLAMES),SPREAD_RADIUS*0.9)

static func blade_seed(at: Vector2, aim: Vector2) -> int:
	return int(absf(at.x)*7.0)+int(absf(at.y)*13.0)+int((aim.angle()+PI)*1000.0)*31

static func stamp_blade(target: Node2D, art: Texture2D, blade: Array, at: Vector2,
		aim: Vector2, scale: float, tint: Color) -> void:
	var mirrored := float(-1 if blade[BLADE_MIRROR] else 1)
	var height: float=float(blade[BLADE_EXTENT].y)*scale
	var width: float=float(blade[BLADE_EXTENT].x)*scale
	var frame := Transform2D(aim.angle(),at)
	var centre: Vector2=frame*Vector2(blade[BLADE_CENTRE])
	centre.y-=pow(1.0-clampf(tint.a,0,1),2.0)*100.0
	var lean := aim.angle()+float(blade[BLADE_ANGLE])*(1.0 if mirrored>0.0 else -1.0)
	target.draw_set_transform(centre,lean,Vector2(mirrored,1))
	var native := art.get_size()
	var fitted := native*minf(width/native.x,height/native.y)
	target.draw_texture_rect(art,Rect2(-fitted*.5,fitted),false,tint)
	target.draw_set_transform(Vector2.ZERO)

func draw_spells() -> void:
	soul_art()
	for fx in motes:
		if not fx.get("spell_art",false) or fx.age<0: continue
		var t: float=fx.age/fx.duration
		var tint := Color(fx.tint,float(fx.tint.a)*minf(1,t*18)*pow(1-t,1.3))
		stamp_spell(fx.cell,fx.p+fx.velocity*fx.age,fx.size*lerpf(.72,1.18,t),fx.angle,tint)
	# 澧撶厹's lingering fire is drawn before her projectiles so a spell never hides
	# under the patch it was cast from.
	for patch in rune_patches:
		var age: float=float(patch.age)
		var duration: float=maxf(0.01,float(patch.duration))
		var forward: float=float(patch.forward)
		var half: float=float(patch.half)
		var aim: Vector2=patch.aim
		var grow := minf(1.0,age/0.35)
		var fade := clampf((duration-age)/1.1,0,1)
		if fade<=0.0: continue
		# The rectangle is the actual damage entity. No stretched ring decal.
		var rect := patch_local_rect(forward,half,1.0)
		spell_light.draw_set_transform(patch.at,aim.angle())
		var reveal := smoothstep(0.0,.16,age)
		spell_light.draw_rect(rect,Color(SOUL_FIRE,(.025+.055*reveal)*fade))
		spell_light.draw_rect(rect,Color(SOUL_FIRE,(.15+.25*reveal)*fade),false,1.6,true)
		var front := lerpf(rect.position.x,rect.end.x,grow)
		spell_light.draw_line(Vector2(front,-half),Vector2(front,half),Color(SOUL_FIRE,.35*(1.0-grow)*fade),2,true)
		if fire_art:
			# Six flames standing in the same ring as the blades, spread over it
			# the same way and turned half a sector so the two sets interleave
			# instead of stacking.  A flame's art is anchored by its base, so each
			# is stamped with that much offset to stand it on the ground rather
			# than in it.  They stay upright: they are billboards, not patch
			# decals, so the patch frame is resolved into world space by hand
			# instead of leaning on the rotated transform above.
			var flame_size := half*0.92
			var patch_frame := Transform2D(aim.angle(),patch.at)
			for spot in patch.get("flames",[]):
				var ground: Vector2=patch_frame*Vector2(spot)
				var index := int(fposmod(age*6.0+ground.x*0.05+ground.y*0.07,
					float(FIRE_COLUMNS*FIRE_ROWS)))
				necro_stamp(fire_art,FIRE_COLUMNS,FIRE_ROWS,index,
					ground+Vector2(0,-flame_size*0.45*grow),Vector2.ONE*flame_size,
					0.0,Color(SOUL_FIRE,0.86*fade))
		if blade_art:
			# The rain: the blades arrive with the ring and leave with it, so they
			# read as what the circle is made of rather than as a second effect.
			for blade in patch.get("blades",[]):
				stamp_blade(spell_light,blade_art,blade,patch.at,aim,
					1.0,Color(1,1,1,0.95*fade))
		spell_light.draw_set_transform(Vector2.ZERO)
	for flame in flames:
		var t: float=float(flame.age)/maxf(0.01,float(flame.duration))
		var fade := pow(1.0-t,1.4)
		if fire_art:
			necro_stamp(fire_art,FIRE_COLUMNS,2,int(fposmod(float(flame.age)*22.0,6.0)),
				flame.p,Vector2(94,120)*(1.0+t*0.4),0,Color(SOUL_FIRE,fade*0.9))
		stamp_spell(6,flame.p-Vector2(0,26),Vector2.ONE*66*(1+t*0.5),0,
			Color(SPELL_COLORS[6],fade*0.5))
	for bullet in field.session.bullets:
		if bullet.get("boss_projectile",false): continue
		if bullet.has("rogue_tone"): continue
		var spell := str(bullet.get("spell","star"))
		if not SPELL_CELLS.has(spell): continue
		if bullet.p.distance_to(field.camera)>1100: continue
		var cell := int(SPELL_CELLS[spell])
		var diameter := 90.0 if spell in ["meteor","vortex","eclipse"] else 65.0
		var at: Vector2=bullet.p-Vector2(0,float(bullet.get("height",0)))
		var tail: Vector2=at-bullet.v.normalized()*clampf(bullet.v.length()*.025,10,34)
		spell_light.draw_line(tail,at,Color(SPELL_COLORS[cell],.25),2,true)
		stamp_spell(cell,at,Vector2.ONE*diameter,bullet.v.angle(),Color.WHITE)

func stamp_spell(cell: int, at: Vector2, size: Vector2, angle: float, tint: Color) -> void:
	var key := "spell_%d" % cell
	spell_light.draw_set_transform(at,angle,Vector2(Library.facing_scale(key),1))
	var extent := Library.fitted_size(key,size)
	Motion.draw(spell_light,Library.texture(key),Rect2(-extent/2,extent),clampf(tint.a*1.5,0,1),"center",tint)
	spell_light.draw_set_transform(Vector2.ZERO)

func spell_energy(data: Dictionary, spell: String, at: Vector2, aim: Vector2) -> void:
	if not SPELL_CELLS.has(spell): return
	var col: Color=SPELL_COLORS[int(SPELL_CELLS[spell])]
	var source := int(data.get("id",-1))
	match str(data.kind):
		"spell_beam", "spell_arc":
			var end: Vector2=data.target if data.kind=="spell_arc" else at+aim*float(data.reach)
			var delta := end-at
			energy.spawn((at+end)*.5,Vector2(delta.length(),90),col,1,.32,delta.angle(),0,1.05,source)
			energy.particles(end,col,16,aim,70,.65)
		"spell_burst":
			if spell=="meteor":
				energy.spawn(at-Vector2(0,65),Vector2(240,320),col,0,.7,0,0,1.05,source)
			else:
				energy.spawn(at,Vector2.ONE*240,col,4,.55,0,0,1.05,source)
			energy.spawn(at,Vector2.ONE*270,col,2,.6,0,0,1.05,source)
			energy.particles(at,col,30,Vector2.UP,175,1)
		"windup":
			energy.spawn(at+aim*25-Vector2(0,28),Vector2.ONE*95,Color(col,.55),4,maxf(.1,float(data.get("windup",.25))),0,0,1.05,source)
			if field.has_method("weapon_effect_socket"): energy.bursts.back()["socket_source"]=source
		"strike":
			if int(data.get("weapon",0))==3:
				energy.particles(at+aim*35-Vector2(0,15),col,8 if spell=="needle" else 14,aim,35,.55)
				if field.has_method("weapon_effect_socket"):
					var socket: Dictionary=field.weapon_effect_socket(source)
					if not socket.is_empty() and absf(get_global_transform().determinant())>.000001: energy.emitters.back().position=get_global_transform().affine_inverse()*socket.tip

func observe_particles(dt: float) -> void:
	var seen: Dictionary={}
	if not field.session.roguelike.active(field.session):
		for e in field.session.enemies:
			if e.hp<=0 or e.get("choreo_cast",false) or e.get("boss_construct",false) or e.type==4 or e.get("raid_boss",false) or e.get("mini_boss",false) or e.get("wild_boss",false) or e.get("dragon_boss",false): continue
			if e.p.distance_to(field.camera)>1100: continue
			var key := "enemy:"+str(e.id)
			seen[key]=true
			if not enemy_particle_states.has(key): enemy_particle_states[key]={"charged":false,"released":false}
			var state: Dictionary=enemy_particle_states[key]
			var style: String=["stone","soul","ember","spark","spark","feather","soul","ice","ember","water","spark","ice","water","spark","ice","water","ember"][clampi(int(e.type),0,16)]
			var color: Color=EnemyFrames.COLORS[int(e.type)]
			var aim: Vector2=e.get("attack_aim",Vector2.RIGHT)
			var at: Vector2=e.p-Vector2(0,28)
			if float(e.get("attack_time",0))<=0:
				particles.stop(key); state.charged=false; state.released=false; continue
			if not e.get("attack_released",false) and not state.charged:
				state.charged=true
				particles.start(key,at,aim,color,style,"gather",Ecology.WINDUP[int(e.type)],24,25)
			particles.move(key,at)
			if e.get("attack_released",false) and not state.released:
				state.released=true; particles.stop(key)
				particles.burst(at+aim*24,aim,color,style,18 if int(e.type)>=7 else 11,.9,1.1)
	for key in enemy_particle_states.keys():
		if not seen.has(key): particles.stop(key); enemy_particle_states.erase(key)
	if elapsed-last_particle_trail>=.035:
		last_particle_trail=elapsed
		for b in field.session.bullets:
			if b.get("boss_projectile",false) or b.p.distance_to(field.camera)>1100: continue
			var index := int(b.get("weapon_index",field.session.players.get(b.get("owner",0),{}).get("weapon",3)))
			var style := particles.weapon_style(index)
			var color := Library.weapon_color(index)
			if b.has("rogue_tone"):
				style=preload("res://scripts/effect_semantics.gd").style(str(b.get("fx_move","")),int(b.rogue_tone))
				color=Color(["6cedce","ff9b56","bfa1ff","83dcff","ff638a"][clampi(int(b.rogue_tone),0,4)])
			particles.spawn(b.p,-b.v.normalized()*35,color,style,.65)
	particles.advance(dt)
