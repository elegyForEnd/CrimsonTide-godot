extends Node3D
## World-space effect instance. No projected CanvasItem geometry. Release paths,
## lingering ribbons, detached motes and density cards have independent clocks.
const Builder=preload("res://scripts/weapon_vfx_mesh_3d.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
const SEGMENTS=28
const MAX_PARTICLES=36
# Presentation balance: strengthen the authored solid contour over density cards.
const BODY_WIDTH_GAIN := 1.35
const SMOKE_SIZE_GAIN := .78
const SMOKE_OPACITY_GAIN := .82
var data: Dictionary={}
var profile: Dictionary={}
var camera: Camera3D
var ribbon: MeshInstance3D
var debris: MeshInstance3D
var smoke: MeshInstance3D
var body_material: ShaderMaterial
var smoke_material: ShaderMaterial
var age := 0.0
var life := .6
var origin := Vector3.ZERO
var ground := Vector3.ZERO
var aim := Vector3.RIGHT
var reach := 1.5
var width := .3
var color := Color.WHITE
var kind := "release"
var motion := "sweep"
var reverse := 1.0
var charged := false
var emission_time := .14
var tail_time := .22
var layers := 2
var bounds := AABB()
var detail := 0
var mesh_clock := 0.0
var beam_end := Vector3.ZERO
var action := "normal"
var smoke_ink_aspect := 1.0
var bound: RefCounted
var painted_release_active := false
var authored: RefCounted
var contact_hold := 0.0

func _ready() -> void:
	profile=data.profile
	action=str(data.get("action","normal"))
	kind=str(data.get("vfx_kind","release")); motion=str(profile.motion)
	origin=data.origin; ground=data.ground; aim=data.aim
	reach=maxf(float(data.get("reach",150))*.01,.12)
	beam_end=data.get("beam_end",origin+aim*reach)
	width=clampf(float(data.get("width",30))*.01,.035,1.6)
	color=data.color; charged=bool(data.get("charged",false))
	reverse=-1.0 if int(data.get("combo",0))%2 else 1.0
	emission_time=clampf(float(profile.attack.peak)*1.25,.18,.32)
	tail_time=clampf(float(profile.attack.tail)*1.15,.30,.58)
	if action=="heavy": emission_time=maxf(.28,emission_time); tail_time=maxf(.44,tail_time)
	elif action=="art": emission_time=maxf(.25,emission_time); tail_time=maxf(.50,tail_time)
	if data.has("swing_remaining"): emission_time=clampf(float(data.swing_remaining),emission_time,.48)
	layers=clampi(int(profile.attack.layers),1,3)
	if kind=="beam": motion="beam"; emission_time=.018; tail_time=maxf(.18,tail_time)
	if kind=="release" and profile.family in ["ranged","magic"]:
		# Release flashes stay at the weapon; flight/beam events own travel range.
		reach=.28 if action=="normal" else .40 if action=="heavy" else .55
		width=.08 if action=="normal" else .12 if action=="heavy" else .16
		layers=1
	if kind=="impact": emission_time=.045
	if kind=="charge": emission_time=maxf(.08,float(data.get("windup",.3))); tail_time=.12
	life=emission_time+tail_time+.45
	if kind=="charge" and str(data.get("source_event",{}).get("kind",""))=="hold_charge": life=INF
	if charged: life+=.08
	if preload("res://scripts/weapon_batch_art.gd").enabled(int(profile.canonical)):
		ribbon=mesh_node(null); debris=mesh_node(null); smoke=mesh_node(null)
		authored=preload("res://scripts/weapon_batch01_vfx.gd").new()
		authored.setup(self)
		return
	if int(data.weapon_index)==606:
		ribbon=mesh_node(null); debris=mesh_node(null); smoke=mesh_node(null)
		authored=preload("res://scripts/weapon_606_reference_vfx.gd").new()
		authored.setup(self)
		return
	if kind!="charge":
		# Reference pictures never enter this path. Curves, surfaces and particles
		# are constructed in the engine from the weapon's authored design.
		ribbon=mesh_node(null); debris=mesh_node(null); smoke=mesh_node(null)
		var canonical := preload("res://scripts/weapon_motion_design.gd").identity(int(data.weapon_index))
		if canonical==600 and action=="art":
			authored=preload("res://scripts/weapon_crystal_cut.gd").new()
		else:
			authored=preload("res://scripts/weapon_sample_design.gd").new() if canonical==600 else preload("res://scripts/weapon_hybrid_design.gd").new()
		authored.setup(self)
		return
	body_material=ShaderMaterial.new(); body_material.shader=preload("res://resources/weapon_vfx_3d.gdshader")
	body_material.set_shader_parameter("flow",float(profile.flow))
	body_material.set_shader_parameter("shear",float(profile.shear))
	body_material.set_shader_parameter("edge",float(profile.attack.edge))
	body_material.set_shader_parameter("material_kind",1 if profile.material in ["frost","stone","mirror"] else 2 if profile.material=="storm" else 0)
	var flow_source := str(profile.ribbon_source)
	var flow_texture := Art.mechanic_texture(flow_source)
	if flow_texture!=null:
		var ink := Art.mechanic_ink(flow_source)
		var tex_size := flow_texture.get_size()
		body_material.set_shader_parameter("flow_texture",flow_texture)
		body_material.set_shader_parameter("flow_rect",Vector4(ink.position.x/tex_size.x,ink.position.y/tex_size.y,ink.size.x/tex_size.x,ink.size.y/tex_size.y))
	body_material.set_shader_parameter("flow_vertical",bool(profile.ribbon_vertical))
	body_material.set_shader_parameter("flow_repeat",float(profile.ribbon_repeat))
	var blade_source := str(profile.blade_source)
	var blade_texture := Art.mechanic_texture(blade_source)
	if blade_texture!=null:
		var ink := Art.mechanic_ink(blade_source)
		var tex_size := blade_texture.get_size()
		body_material.set_shader_parameter("blade_texture",blade_texture)
		body_material.set_shader_parameter("blade_rect",Vector4(ink.position.x/tex_size.x,ink.position.y/tex_size.y,ink.size.x/tex_size.x,ink.size.y/tex_size.y))
	ribbon=mesh_node(body_material); debris=mesh_node(body_material)
	smoke_material=ShaderMaterial.new(); smoke_material.shader=preload("res://resources/weapon_smoke_3d.gdshader")
	var source := str(profile.get("smoke_source",profile.density_source))
	var texture := Art.mechanic_texture(source)
	if texture!=null:
		var ink := Art.mechanic_ink(source)
		smoke_ink_aspect=ink.size.x/maxf(1.0,ink.size.y)
		smoke_material.set_shader_parameter("density",texture)
		smoke_material.set_shader_parameter("ink_origin",ink.position/texture.get_size())
		smoke_material.set_shader_parameter("ink_size",ink.size/texture.get_size())
	smoke_material.set_shader_parameter("flow",float(profile.flow))
	smoke_material.set_shader_parameter("vertical_art",bool(profile.smoke_vertical))
	smoke_material.set_shader_parameter("smoke_kind",["wind","dust","cold","heat","blood","soul","void","ion","incense"].find(str(profile.smoke_type)))
	smoke=mesh_node(smoke_material)
	rebuild()

func mesh_node(mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	add_child(node); return node

func sideways() -> Vector3: return Vector3(-aim.z,0,aim.x)*reverse

func path(u: float,lane: int=0) -> Vector3:
	var v := clampf(u,0,1)
	var ease := 1-pow(1-v,2.0)
	var side := sideways()
	var variation := float(profile.shear)
	var phase := float(lane)*.11
	if action=="heavy": phase=float(lane)*.055
	elif action=="art": phase=float(lane)*.24
	if kind=="beam":
		return origin.lerp(beam_end,v)+side*sin(v*PI*3+lane)*width*.08*lane+Vector3.UP*sin(v*PI*4+lane)*width*.05*lane
	if kind in ["impact","burst"] or str(profile.role)=="motion_quake":
		var a := float(lane)*2.39996+variation
		var axis := aim.rotated(Vector3.UP,a)
		return ground+Vector3.UP*.035+axis*reach*(.08+ease*.80)+Vector3.UP*sin(v*PI)*reach*(.10 if kind=="impact" else .22)
	if painted_release_active and kind=="release":
		return bound.smoke_point(v)
	if kind=="release" and str(profile.role)!="motion_quake":
		return authored_path(v,lane)
	if motion=="chop":
		# A continuous blade-tip orbit around the grip. No clamped flat bottom.
		var angle := lerpf(-1.12,.54,ease)
		var radius := reach*.78
		return origin+aim*cos(angle)*radius-Vector3.UP*sin(angle)*minf(radius,maxf(.12,origin.y-ground.y)*1.75)+side*phase*reach*.18
	if motion=="crosscut":
		var t := pow(v,.72 if lane%2==0 else 1.4)
		var sign_x := 1.0 if lane%2==0 else -1.0
		return origin+aim*reach*(.24+sin(t*PI)*.54)+side*reach*(t-.5)*1.20*sign_x+Vector3.UP*reach*(.48-t*.65)*sign_x
	if motion=="weave":
		return origin+aim*reach*(.08+ease*.78)+side*sin(v*PI*1.4+lane*2.1)*reach*.24*v+Vector3.UP*sin(v*PI+lane)*reach*.20*v
	if motion in ["sweep","spin","hook","wave"]:
		var arc := TAU*.87 if motion=="spin" else PI*1.12 if motion=="hook" else PI*.82
		if action=="normal" and motion!="spin": arc*=.72
		if action=="art" and lane==1: ease=pow(v,.65)
		var theta := (-arc*.51+arc*ease)*reverse+phase
		var radius := reach*(.82-lane*.055+.07*sin(v*PI))
		var lift := sin(v*PI+phase)*reach*(.12+absf(variation)*.15)
		if action=="heavy": lift-=ease*reach*.20
		elif action=="art": lift+=sin(v*PI*2+lane)*reach*.10*lane
		if profile.material=="tide": lift+=sin(v*PI*2)*reach*.08
		if profile.material=="storm": lift+=sin(v*38)*reach*.016
		return origin+aim.rotated(Vector3.UP,theta)*radius+Vector3.UP*lift
	if motion in ["thrust","recoil"]:
		return origin+aim*reach*(.05+ease*(.4 if motion=="recoil" else .87))+side*phase*reach*.3+Vector3.UP*sin(v*PI)*reach*.035
	var bend := float(lane-1)*.38+variation*.2
	if action=="heavy": bend=float(lane)*.07
	var out := aim.rotated(Vector3.UP,bend)
	var curl := sin(v*PI)*reach*.20
	if action=="heavy": curl*=.25
	return origin+out*reach*(.06+ease*.67)+side*curl+Vector3.UP*(curl*.7+v*reach*.06)

# Per-weapon centreline choreography. These curves define the main luminous body,
# not optional decorations. Action changes its attack grammar before material work.
func authored_path(v: float,lane: int) -> Vector3:
	var side := sideways()
	var t := 1-pow(1-v,2.0)
	var style := str(profile.attack.style)
	var phase := lane*.13
	var local := Vector3.ZERO # x: forward, y: height, z: across
	var sig: Dictionary=profile.signature
	var opening := float(sig.opening)
	var bias := float(sig.bias)
	match style:
		"viscous_cut": local=Vector3(.28+sin(t*PI)*.55,.08*sin(t*PI),lerpf(-.58,.50,t))
		"beak_pierce": local=Vector3(.06+t*.90,sin(t*PI)*.025,0)
		"folded_silk":
			var a := t*PI*1.42-.8
			local=Vector3(cos(a)*(.80-.28*t),sin(t*TAU)*.12,sin(a)*(.80-.28*t))
		"paired_thorn": local=Vector3(.25+sin(t*PI)*.50,(t-.5)*.20*(1 if lane%2 else -1),(t-.5)*1.12*(1 if lane%2 else -1))
		"silver_reflection": local=Vector3(.34+sin(t*PI)*.60,sin(t*PI)*.04,lerpf(-.40,.44,t))
		"wick_membrane": local=Vector3(.15+t*.63,sin(t*PI)*.24,sin(t*PI*2)*.075)
		"thin_ice_plane": local=Vector3(.20+t*.58,.30-t*.38,lerpf(-.46,.35,t)+floor(t*5)*.018)
		"late_arc_cut": local=Vector3(.25+sin(t*PI)*.48,sin(t*31)*.025,lerpf(-.48,.52,t)+sin(t*39)*.035)
		"broken_seal": local=Vector3(.40+sin(t*PI)*.36,.20-t*.24,lerpf(-.44,.48,t))
		"offset_mirrors": local=Vector3(.30+sin(t*PI)*.44+lane*.08,.08+lane*.055,lerpf(-.48,.54,t)+lane*.16)
		"bronze_vibration": local=Vector3(.30+sin(t*PI)*.46,sin(t*PI*6)*.032,lerpf(-.38,.48,t))
		"obsidian_wedge": local=Vector3(.22+t*.60,.24-t*.32,(-.48+t*.90) if t<.6 else .06+(t-.6)*.46)
		"sunsteel_drop": local=Vector3(cos(lerpf(-1.1,.5,t))*.80,-sin(lerpf(-1.1,.5,t))*.52,(t-.5)*.12)
		"heavy_water_sheet": local=Vector3(.38+sin(t*PI)*.48,sin(t*PI)*.25+sin(t*TAU)*.07,lerpf(-.64,.60,t))
		"broken_earth_ridge": local=Vector3(.15+t*.75,.44-t*.62,lerpf(-.28,.36,t))
		"molten_hammer": local=Vector3(.30+sin(t*PI*.5)*.43,.70-t*.94,sin(t*PI)*.08)
		"thick_bone_ice": local=Vector3(.22+sin(t*PI*.8)*.62,.50-t*.66,lerpf(-.56,.32,t))
		"weighted_late_thunder": local=Vector3(.26+t*.52,.56-t*.76,lerpf(.34,-.38,t)+sin(t*27)*.023)
		"falling_blood_membrane": local=Vector3(.54+sin(t*PI)*.12,.82-t*1.12,lerpf(-.09,.10,t))
		"starrock_drop": local=Vector3(.62+sin(t*PI)*.06,.96-t*1.28,-.16*(1-t))
		"charcoal_wall_shear": local=Vector3(.46+t*.30,.40-t*.52,lerpf(-.66,.52,t))
		"folded_wind_banner": local=Vector3(.10+t*.88,sin(t*PI)*.10,sin(t*PI)*.16)
		"soul_inner_hook":
			var a := lerpf(-1.6,1.9,t)
			local=Vector3(.22+cos(a)*(.68-t*.25),sin(t*PI)*.18,sin(a)*(.68-t*.25))
		"old_crown_steel": local=Vector3(.28+sin(t*PI)*.58,.66-t*.86,lerpf(-.32,.24,t))
		"rifle_gas_kick": local=Vector3(.05+t*.40,sin(t*PI)*.03,0)
		"long_feather_release": local=Vector3(.10+t*.70,sin(t*PI)*.18,sin(t*PI)*.24)
		"barbed_bolt_release": local=Vector3(.05+t*.82,.03,((lane%2)*2-1)*.12*t)
		"blunt_hot_pellet": local=Vector3(.08+sin(t*PI*.5)*.48,sin(t*PI)*.16,lerpf(-.18,.22,t))
		"frost_shaft_release": local=Vector3(.05+t*.88,sin(t*PI)*.08,-sin(t*PI)*.13)
		"charged_short_core": local=Vector3(.04+t*.52,sin(t*29)*.028,sin(t*21)*.04)
		"heavy_obsidian_core": local=Vector3(.12+t*.58,.12-t*.10,0)
		"offset_twin_muzzles": local=Vector3(.08+t*.66,lane*.07,(lane*2-1)*.14)
		"light_feather_flick": local=Vector3(.08+t*.76,sin(t*PI)*.10,sin(t*PI)*-.28)
		"sabot_core_release": local=Vector3(.04+t*.96,0,0)
		"bronze_vane_release": local=Vector3(.08+t*.64,sin(t*PI*3)*.045,sin(t*PI)*.12)
		"warm_signal_puff": local=Vector3(.06+t*.42,t*.30,sin(t*PI)*.14)
		"star_grit_compress": local=Vector3(.08+t*.67,sin(t*PI)*.22,sin(t*PI*2)*.24)
		"molten_rock_birth": local=Vector3(.12+t*.56,.70-t*.88,sin(t*PI)*.12)
		"ice_needle_freeze": local=Vector3(.04+t*.94,0,(-.5+lane)*.085)
		"intermittent_charge": local=Vector3(.06+t*.82,sin(t*35)*.075,sin(t*27)*.11)
		"moon_plane_flip": local=Vector3(.16+sin(t*PI)*.64,sin(t*PI)*.16,lerpf(-.55,.55,t))
		"prism_alignment": local=Vector3(.04+t*.92,(-1+lane)*.10*(1-t),(-1+lane)*.16*(1-t))
		"charred_feather_birth": local=Vector3(.08+t*.73,sin(t*PI)*.28,sin(t*PI)*(.28 if lane%2 else -.28))
		"asymmetric_space_fold":
			var a := t*TAU*.78+lane*2.1
			local=Vector3(.44+cos(a)*(.58-t*.46),sin(a)*(.28-t*.18),sin(a)*(.58-t*.46))
		"dark_shell_compress": local=Vector3(.06+t*.91,sin(t*PI)*-.07,sin(t*PI*2)*.06)
		"ink_page_fold": local=Vector3(.12+t*.64,absf(t-.5)*.42,lerpf(-.40,.40,t))
		"layered_soul_cloth": local=Vector3(.08+t*.61,sin(t*PI*1.5+lane)*.24,sin(t*TAU+lane)*.20)
		"warm_prayer_fold": local=Vector3(.14+t*.52,sin(t*PI)*.42,lerpf(-.38,.38,t))
		"short_iron_cut": local=Vector3(.25+sin(t*PI)*.34,.06,lerpf(-.30,.36,t))
		"small_prayer_star": local=Vector3(.12+t*.43,sin(t*PI)*.18,sin(t*PI*2)*.12)
		"broken_steel_drop": local=Vector3(.28+t*.45,.48-t*.67,lerpf(-.20,.18,t))
		"small_soul_hook": local=Vector3(.22+cos(t*PI)*.42,sin(t*PI)*.12,sin(t*PI)*.48)
		_: local=Vector3(t*.8,sin(t*PI)*.12,0)
	# Every action has a different movement grammar, preserving the weapon shape.
	if action=="normal":
		local.y*=.70
	elif action=="heavy":
		if profile.family in ["blade","great"]:
			local.z*=.42
			local.y+=cos(t*PI)*(.20+opening*.22)
		else:
			local.z*=.30; local.y*=.35
			local.x=lerpf(.04,.92,pow(v,.55))
	else:
		if profile.family in ["blade","great"] and not bool(profile.ground_break):
			local.z*=1.0 if lane%2==0 else -1.0
			local.y+=sin(t*PI+lane)*.18*lane
		elif profile.family=="magic":
			var angle := (lane-1)*(.28+opening*.24)
			local=local.rotated(Vector3.UP,angle)
		elif profile.family=="ranged": local.z+=(lane-1)*(.12+opening*.22)*t
	local.z+=phase*(.22 if action=="heavy" else .55 if action=="art" else .08)
	if action=="art" and bool(profile.ground_break):
		# Hammer/earth arts travel as separated ground eruptions, not extra swings.
		return Vector3(origin.x,ground.y+.045,origin.z)+aim*reach*(.20+t*.70)+side*reach*sin(lane*2.4)*t*.45+Vector3.UP*sin(t*PI)*reach*(.15+.06*lane)
	# Match ground contact to landing without flattening a long terminal segment.
	var vertical_scale := minf(reach,maxf(.35,origin.y-ground.y)*1.45) if profile.family=="great" else reach
	return origin+aim*local.x*reach+Vector3.UP*local.y*vertical_scale+side*local.z*reach

func draw_release(builder) -> void:
	var head := minf(1,age/emission_time)
	var strip_life := tail_time
	# The body lingers through a readable tail instead of a second short cap.
	if painted_release_active: return
	var start := maxf(0,(age-strip_life)/emission_time)
	if age<=0 or start>=head: return
	var fans: int=[4,3,2][detail] if kind=="burst" or str(profile.role)=="motion_quake" else mini(layers,[2,2,1][detail])
	var segments: int=[28,18,10][detail]
	if fans>=7 and action=="normal": segments=22
	if kind=="impact": return
	for lane in fans:
		var previous := Vector3.ZERO
		var previous_n := Vector3.ZERO
		var previous_alpha := 0.0
		for i in segments+1:
			var u := lerpf(start,head,float(i)/segments)
			var sampled_u := u
			if action=="art": sampled_u=clampf(u-float(lane)*.055,0,1)
			var p := path(sampled_u,lane)
			var tangent := (path(minf(1,u+.002),lane)-path(maxf(0,u-.002),lane)).normalized()
			var normal := tangent.cross(Vector3.UP).normalized()
			if motion in ["sweep","hook","spin","wave"]:
				normal=(p-origin).normalized()
			elif motion in ["chop","crosscut"]: normal=tangent.cross(sideways()).normalized()
			elif camera!=null: normal=tangent.cross(camera.global_basis.z).normalized()
			if normal.length_squared()<.01: normal=Vector3.UP
			var strip_width := reach*(.13+float(profile.spread)*.23)/(1+lane*.65)
			if motion in ["chop","crosscut"]: strip_width*=.55
			if charged: strip_width*=1.22
			if action=="heavy": strip_width*=1.30
			elif action=="normal": strip_width*=.78
			if profile.material in ["metal","storm"]: strip_width*=.72
			if profile.material in ["soul","tide","cloth"]: strip_width*=1.16
			if profile.material in ["frost","stone","mirror"]:
				# The dedicated RGBA painting already owns the broken edge. Do not
				# serrate every mesh segment into another repeated comb over it.
				strip_width*=.96+.045*sin(u*PI*2+lane*1.7)
			if motion in ["thrust","recoil","beam"]: strip_width=width*(.75 if lane==0 else .35)
			if kind=="burst" or str(profile.role)=="motion_quake": strip_width*=.45
			var style := str(profile.attack.style)
			if style in ["beak_pierce","ice_needle_freeze","sabot_core_release","dark_shell_compress"]: strip_width*=.34
			elif style in ["thin_ice_plane","silver_reflection","long_feather_release"]: strip_width*=.54
			elif style in ["molten_hammer","starrock_drop"]: strip_width*=.75+.70*u
			elif style=="charcoal_wall_shear": strip_width*=1.25
			var taper := pow(maxf(0,sin(PI*(float(i)/segments))),.6)*.90+.025
			var n := normal*strip_width*taper*.5*BODY_WIDTH_GAIN*float(data.get("body_gain",1.0))
			var alpha := pow(maxf(0,1-(age-u*emission_time)/strip_life),1.10)*smoothstep(0,.008,age)*(1.48 if lane==0 else .48)
			if lane>0 and profile.material in ["frost","mirror","feather"]:
				alpha*=.25 if (i+lane*3)%7 in [0,1] else 1.0
			if style in ["broken_seal","obsidian_wedge","thin_ice_plane"] and i%8 in [0,1]: alpha*=.08
			if charged: alpha*=1.12
			# The painted leading tip follows the current attack head. Using the
			# absolute timeline as U would crop off that tip during short normals.
			if i>0: builder.quad(previous-previous_n,previous+previous_n,p-n,p+n,Color(color,alpha),float(i-1)/segments,float(i)/segments,previous_alpha,1.0)
			previous=p; previous_n=n; previous_alpha=alpha

func draw_particles(builder) -> void:
	if kind=="release": return
	var count := mini(MAX_PARTICLES,int(profile.impact.fragments)*5+(8 if charged else 0))
	if kind=="impact": count=mini(10,int(profile.impact.fragments)*2)
	else:
		# Release debris is an accent; contact owns the dense fragment burst.
		count=mini(count,5 if action=="normal" else 9 if action=="heavy" else 12)
	count=mini(count,[36,18,8][detail])
	var right := camera.global_basis.x if camera!=null else Vector3.RIGHT
	var up := camera.global_basis.y if camera!=null else Vector3.UP
	# Contact's readable peak is a compact high-energy face. Detached debris
	# outlives it; the white center never washes the whole smoke volume white.
	if kind=="impact" and age>0 and age<.095:
		var flash := smoothstep(0,.007,age)*pow(1-age/.095,1.6)
		var size := minf(.34,reach*.6)*(.75+age*4)
		builder.quad(origin-right*size-up*size*.65,origin-right*size+up*size*.65,origin+right*size-up*size*.65,origin+right*size+up*size*.65,Color(color.lerp(Color.WHITE,.75),flash))
	for i in count:
		var u := .08+.84*fposmod(float(i)*.61803398875+.27,1.0)
		var birth := u*emission_time*.85
		if kind=="impact": birth*=.13
		var elapsed := age-birth
		var lifetime := tail_time*(.80+fposmod(i*.618,.6))+.09
		if elapsed<=0 or elapsed>=lifetime: continue
		var direction := aim.rotated(Vector3.UP,sin(i*2.399)*1.7)
		var at := path(u,i%layers)
		if kind=="impact": at=origin
		var speed := (.7+fposmod(i*.73,1.4))*(1.6 if kind=="impact" else .6)
		var velocity := direction*speed+Vector3.UP*(.5+fposmod(i*.37,1.3))
		if profile.material in ["soul","void","feather"]: velocity=direction*.35+Vector3.UP*.65
		var gravity := 4.5 if profile.material in ["stone","metal","frost","mirror"] else 1.0
		var point := at+velocity*elapsed-Vector3.UP*gravity*elapsed*elapsed*.5
		point.y=maxf(ground.y+.025,point.y)
		var fade := pow(1-elapsed/lifetime,1.6)*smoothstep(0,.008,elapsed)
		var size := (.026+fposmod(i*.037,.055))*(1-elapsed/lifetime*.75)
		var axis := (velocity-Vector3.UP*gravity*elapsed).normalized()
		var a := axis*size*(2.5 if profile.material in ["storm","metal"] else 1.2)
		var across := axis.cross(camera.global_basis.z if camera else Vector3.FORWARD).normalized()
		if across.length_squared()<.01: across=right
		var b := across*size*(.36 if profile.material in ["metal","storm"] else .62)
		var tint := Color(color.lerp(Color.WHITE,.12),fade*(.9 if kind=="impact" else .36))
		# Two tapered triangles follow velocity, with no billboard rectangle.
		builder.quad(point-a,point-a,point-b,point+b,tint)
		builder.quad(point-b,point+b,point+a,point+a,tint)

func draw_smoke(builder) -> void:
	if age<=.012: return
	var right := camera.global_basis.x if camera!=null else Vector3.RIGHT
	var up := camera.global_basis.y if camera!=null else Vector3.UP
	var smoke_type := str(profile.smoke_type)
	var count := 5 if smoke_type in ["dust","soul","void"] else 3 if smoke_type in ["cold","ion","blood"] else 4
	count=mini(count,1 if action=="normal" else 2)
	if kind=="impact": count=1
	for i in count:
		var u := (float(i)+.5)/count
		var elapsed := age-u*emission_time*.85
		var lifetime := (tail_time+.48)*float({"blood":.90,"ion":.72,"cold":.94,"dust":1.0,"heat":1.0,"wind":.95,"soul":1.12,"void":1.0,"incense":1.18}[smoke_type])
		if elapsed<=0 or elapsed>=lifetime: continue
		var progress := elapsed/lifetime
		var point: Vector3=bound.smoke_point(u) if painted_release_active else path(u,i%layers)
		if kind=="impact": point=origin+sideways()*(u-.5)*.22
		var tangent := path(minf(1,u+.02),i%layers)-path(maxf(0,u-.02),i%layers)
		var projected := Vector2(tangent.dot(right),tangent.dot(up))
		var angle := projected.angle() if projected.length_squared()>.0001 else 0.0
		angle+=sin(i*2.399)*.38
		var size := (maxf(.50,bound.weapon_length*.85) if painted_release_active else reach*(.23+elapsed*.30))*SMOKE_SIZE_GAIN*(1+elapsed*.45)
		var aspect := Vector2(.90+float(profile.spread)*.18,.68+.12*cos(i*1.7))
		var gain := 1.0
		var tint := color.lerp(Color("717781"),.55)
		match smoke_type:
			"dust":
				if kind=="release" and action!="normal":
					var contact_time := age-emission_time*.78
					if contact_time<=0: continue
					point=Vector3(origin.x,ground.y+.05,origin.z)+aim*reach*.58+aim.rotated(Vector3.UP,(u-.5)*2.8)*minf(reach*.40,contact_time*reach*1.8)
				point+=Vector3.UP*elapsed*.15
				angle=sin(i*2.399)*.35; aspect=Vector2(1.12,.45); size*=1.0+progress*.22
				tint=color.lerp(Color("777062"),.72)
			"cold":
				point+=Vector3.UP*(.04-elapsed*.12)-aim*elapsed*.10
				size*=.70; aspect=Vector2(1.08,.48); gain=.70
				tint=color.lerp(Color("b2c8d3"),.55)
			"heat":
				point+=Vector3.UP*(elapsed*.62+progress*progress*.10)+sideways()*sin(progress*4+i)*elapsed*.12
				angle=sin(progress*3+i)*.13; aspect=Vector2(.85,1.0); size*=.82
				tint=color.lerp(Color("514b50"),.68)
			"blood":
				point+=tangent.normalized()*elapsed*.40-Vector3.UP*progress*progress*.15
				size*=.90; aspect=Vector2(.82,.68); gain=.92
				tint=color.lerp(Color("ba6274"),.25)
			"soul":
				point+=Vector3.UP*elapsed*.48+sideways()*sin(progress*5+i)*elapsed*.24
				angle=sin(progress*4+i)*.22; aspect=Vector2(.90,1.0); size*=.86
			"void":
				var center := origin+aim*reach*.44
				point=point.lerp(center,smoothstep(0,1,progress)*.76)
				point+=sideways()*sin(progress*5+i)*.10
				angle-=progress*1.8; aspect=Vector2(1.0,.40); size*=.88*(1-progress*.55)
			"ion":
				point-=aim*elapsed*.25; point+=Vector3.UP*elapsed*.12
				aspect=Vector2(1.30,.23); size*=.62; gain=.52
			"incense":
				point+=Vector3.UP*elapsed*.36+sideways()*sin(progress*4+i)*elapsed*.09
				angle=sin(progress*3+i)*.12; aspect=Vector2(.90,1.0); size*=.70; gain=.72
			_: # Wind stretches behind the stroke, then rapidly disperses.
				point-=tangent.normalized()*elapsed*.35
				aspect=Vector2(1.34+progress*.24,.36); size*=.84
		if kind=="impact": size=minf(.65*SMOKE_SIZE_GAIN,size)
		# Preserve the painting's native proportions before the small physical
		# stretch. Tall plumes rise upright; elongated dust remains a low skirt.
		var native := Vector2(smoke_ink_aspect,1.0)
		native/=maxf(native.x,native.y)
		if bool(profile.smoke_vertical): aspect*=native
		else: aspect=Vector2(aspect.x,lerpf(aspect.y,native.y,.45))
		var card_x := right*cos(angle)+up*sin(angle)
		var card_y := -right*sin(angle)+up*cos(angle)
		var variation := .88+.18*sin(i*2.399+1.1)
		var x := card_x*size*aspect.x*variation
		var y := card_y*size*aspect.y
		var alpha := smoothstep(0,.020,elapsed)*pow(1-progress,.9)*minf(.64,maxf(.40,float(profile.smoke_gain)*2.0))*SMOKE_OPACITY_GAIN*gain
		builder.quad(point-x-y,point-x+y,point+x-y,point+x+y,Color(tint,alpha))

func draw_charge(builder) -> void:
	var progress := clampf(age/emission_time,0,1)
	var right := camera.global_basis.x if camera else Vector3.RIGHT
	var up := camera.global_basis.y if camera else Vector3.UP
	var sites: Array=data.get("charge_sites",[])
	var ready := bool(data.get("ready",false)) or progress>=1
	var pulse := .85+.15*sin(age*9) if ready else 1.0
	var count := 28 if action=="heavy" else 12
	for i in count:
		var u := fposmod(age*.9+i*.618,1)
		var a := float(i)*2.39996+float(profile.signature.bias)
		var anchor: Vector3=origin
		if not sites.is_empty(): anchor=sites[i%sites.size()]
		var offset := (-aim*.55+right*cos(a)*.45+up*sin(a)*.55)*(1-u)*(.18+progress*.40)
		if profile.family=="great": offset=sideways()*cos(a)*.18*(1-u)+Vector3.UP*(1-u)*(.22+progress*.40)
		elif profile.family=="ranged": offset=-aim*(1-u)*(.30+progress*.55)+right*cos(a)*.10*(1-u)+up*sin(a)*.10*(1-u)
		elif profile.family=="magic": offset=(right*cos(a+age*2)+up*sin(a+age*2))*(1-u)*(.16+progress*.35)
		var point := anchor+offset
		var direction := (-offset).normalized()
		var across := direction.cross(camera.global_basis.z if camera else Vector3.FORWARD).normalized()
		if across.length_squared()<.01: across=right
		var size := .016+.028*progress
		var along := direction*size*2.6
		var narrow := across*size*.32
		builder.quad(point-along-narrow,point-along+narrow,point+along-narrow,point+along+narrow,Color(color.lerp(Color.WHITE,.25+progress*.25),smoothstep(0,.1,u)*(1-u)*(.65+progress*.5)*pulse))
	if action!="heavy": return
	if sites.size()<2: sites=[origin,origin+aim*.45]
	for track: Array in data.get("charge_paths",[sites]):
		for i in track.size()-1:
			var from: Vector3=track[i]; var to: Vector3=track[i+1]
			var axis := (to-from).normalized()
			var side := axis.cross(camera.global_basis.z if camera else Vector3.FORWARD).normalized()
			if side.length_squared()<.01: side=right
			var width := (.009+progress*.026)*pulse
			builder.quad(from-side*width,from+side*width,to-side*width,to+side*width,Color(color.lerp(Color.WHITE,.30+progress*.40),(.25+.65*progress)*pulse))
	if data.has("ready_age"):
		var elapsed := age-float(data.ready_age)
		if elapsed>=0 and elapsed<.16:
			var point: Vector3=sites.back()
			var extent := .08+.15*elapsed/.16
			builder.quad(point-right*extent-up*extent*.35,point-right*extent+up*extent*.35,point+right*extent-up*extent*.35,point+right*extent+up*extent*.35,Color(color.lerp(Color.WHITE,.85),1-elapsed/.16))

func rebuild() -> void:
	if ribbon==null: return
	if authored!=null:
		authored.rebuild()
		return
	body_material.set_shader_parameter("phase",age/maxf(.01,emission_time))
	body_material.set_shader_parameter("dissolve",0.0 if kind=="charge" else smoothstep(emission_time,emission_time+tail_time,age))
	smoke_material.set_shader_parameter("phase",age/maxf(.01,life))
	var main=Builder.new(); var motes=Builder.new(); var mist=Builder.new()
	if kind=="charge": draw_charge(main)
	else:
		draw_release(main); draw_particles(motes); draw_smoke(mist)
		if not painted_release_active and profile.family in ["blade","great"]: draw_signature(main)
		draw_ground_break(motes,motes)
	main.commit(ribbon); motes.commit(debris); mist.commit(smoke)
	if bound!=null: bound.rebuild()

# Small tapered strips compose authored silhouettes, rather than rectangular flashes.
func stroke(builder,a: Vector3,b: Vector3,size: float,tint: Color,on_ground: bool=false) -> void:
	var axis := (b-a).normalized()
	var normal := axis.cross(Vector3.UP if on_ground else camera.global_basis.z if camera else Vector3.FORWARD).normalized()
	if normal.length_squared()<.01: normal=sideways()
	var middle := a.lerp(b,.56)
	builder.quad(a,a,middle-normal*size,middle+normal*size,tint)
	builder.quad(middle-normal*size,middle+normal*size,b,b,tint)

func draw_signature(builder) -> void:
	if kind in ["charge","impact"]: return
	var sig: Dictionary=profile.signature
	var count := int(sig.count)
	if action=="normal": count=mini(2,count)
	elif action=="heavy": count=maxi(1,count-1)
	count=mini(count,[6,4,2][detail])
	var fade := smoothstep(0,.016,age)*pow(maxf(0,1-age/(emission_time+tail_time)),1.6)
	if fade<.01: return
	var side := sideways()
	var opening := float(sig.opening)
	var bias := float(sig.bias)
	var scale := minf(reach,3.0)*(.09 if action=="normal" else .18 if action=="heavy" else .28)*1.18
	var tint := Color(color.lerp(Color.WHITE,.18),fade*(.58 if action=="normal" else .90))
	if action=="heavy":
		var tip := path(clampf(age/emission_time,0,1))
		var cut_axis := (path(.99)-path(.97)).normalized()
		if cut_axis.length_squared()<.01: cut_axis=aim
		var cut_side := cut_axis.cross(camera.global_basis.z if camera else Vector3.FORWARD).normalized()
		stroke(builder,tip-cut_axis*scale*.65-cut_side*scale*.06,tip+cut_axis*scale*.25,scale*.035,Color(color.lerp(Color.WHITE,.65),fade))
		stroke(builder,tip-cut_axis*scale*.45+cut_side*scale*.06,tip+cut_axis*scale*.25,scale*.025,Color(color.lerp(Color.WHITE,.45),fade*.65))
	for i in count:
		var t := clampf(age/emission_time-float(i)*(.08 if action=="art" else .025),0,1)
		var sample_u := minf(t,.10+.82*(float(i)+.5)/count)
		var center := path(sample_u,i%layers)
		var tangent := (path(minf(1,sample_u+.01),i%layers)-path(maxf(0,sample_u-.01),i%layers)).normalized()
		if tangent.length_squared()<.01: tangent=aim
		var offset := (float(i)-float(count-1)*.5)*scale*opening
		center+=side*offset*.40+Vector3.UP*sin(i*2.4)*scale*.12
		var axis := tangent
		var across := axis.cross(camera.global_basis.z if camera else Vector3.FORWARD).normalized()
		if across.length_squared()<.01: across=side
		var motif := str(sig.motif)
		if motif in ["moon","water","silk","soul","void","wick"]:
			var previous := center-axis*scale
			for j in 9:
				var u := float(j+1)/9
				var bend := sin(u*PI)*(1 if motif!="void" else -1)*opening
				var point := center+axis*scale*(u*2-1)+across*scale*bend+Vector3.UP*scale*sin(u*PI*2+i)*(.6 if motif in ["soul","wick"] else .15)
				stroke(builder,previous,point,scale*(.032 if motif=="silk" else .065)*sin(u*PI+.02),tint)
				previous=point
		elif motif=="lightning":
			var previous := center-axis*scale
			for j in 5:
				var point := center+axis*scale*(float(j+1)/2.5-1)+across*scale*(.24 if j%2 else -.24)*opening
				stroke(builder,previous,point,scale*.035,tint); previous=point
		elif motif in ["feather","thorn","blood_fang","beak"]:
			var tip := center+axis*scale*(.8+bias)
			stroke(builder,center-axis*scale*.4,tip,scale*.035,tint)
			for j in (3 if motif=="feather" else 1):
				var base := center-axis*scale*float(j)*.25
				stroke(builder,base-across*scale*opening,tip-axis*scale*j*.27,scale*.10,tint)
				if motif!="beak": stroke(builder,base+across*scale*opening,tip-axis*scale*j*.27,scale*.08,tint)
		elif motif in ["star","sunray","chime","crown"]:
			var rays: int=5 if motif=="star" else 3 if motif=="crown" else 2
			for j in rays:
				var angle: float=float(j)*TAU/rays+age*(.5 if motif=="chime" else 0)
				var out := (side*cos(angle)+Vector3.UP*sin(angle))*scale
				stroke(builder,center+out*.22,center+out,scale*.04,tint)
		else:
			# Ice needles, split seals, sabot jackets, prism and obsidian facets.
			var length := scale*(.7+bias)
			var broad := scale*opening*.30
			var point := center+axis*length
			# A tapered facet follows the stroke, never a row of horizontal diamonds.
			var middle := center-axis*length*.10
			builder.quad(center-axis*length*.6,center-axis*length*.6,middle-across*broad,middle+across*broad,tint)
			builder.quad(middle-across*broad,middle+across*broad,point,point,tint)
			if action=="art": stroke(builder,center+across*broad*1.7,point+across*broad*1.7,scale*.025,tint)

func draw_ground_break(builder,rocks) -> void:
	if not bool(profile.get("ground_break",false)) or kind in ["charge","impact"]: return
	# The fissure starts after the head lands; heavy is a forward fault,
	# art forks sideways, while normal only chips the contact point.
	var elapsed := age-emission_time*.78
	if elapsed<=0: return
	var progress := clampf(elapsed/.14,0,1)
	var fade := pow(maxf(0,1-elapsed/(tail_time+.14)),1.4)
	var intensity := .26 if action=="normal" else 1.0
	var center := Vector3(origin.x,ground.y+.025,origin.z)+aim*reach*.58
	var branches := 2 if action=="normal" else 3 if action=="heavy" else 4
	branches=mini(branches,[7,5,3][detail])
	for branch in branches:
		var angle := (float(branch)-float(branches-1)*.5)*(.22 if action=="heavy" else .68)
		var direction := aim.rotated(Vector3.UP,angle)
		var distance := reach*(.22 if action=="normal" else .47)*progress
		var previous := center
		for j in 5:
			var point := center+direction*distance*float(j+1)/5+sideways()*sin(j*2.7+branch)*distance*.10
			var thickness := reach*.014*intensity*(1-float(j)/6)
			stroke(builder,previous,point,thickness,Color(color,fade*.85),true)
			if j==2 or j==4:
				var lift := sin(clampf(elapsed/.40,0,1)*PI)*reach*.12*intensity
				var foot := point+Vector3.UP*lift
				var half := sideways()*reach*.035*intensity
				rocks.quad(foot-half,foot+half,foot+Vector3.UP*reach*.075*intensity,foot+Vector3.UP*reach*.075*intensity,Color(color.darkened(.48),fade))
			previous=point

func advance(dt: float) -> void:
	if contact_hold>0:
		var held := minf(maxf(0,dt),contact_hold)
		contact_hold-=held; dt-=held
	age+=maxf(0,dt); mesh_clock+=maxf(0,dt)
	# Full quality updates every frame. Under saturation, event time stays
	# continuous while secondary geometry has a bounded 30 Hz rebuild rate.
	if detail==2 and mesh_clock<1.0/30 and age<life: return
	mesh_clock=0; rebuild()

