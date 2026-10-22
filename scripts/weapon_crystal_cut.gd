extends "res://scripts/weapon_motion_design.gd"
## One trial: weapon 600 art. Painted components bend/fly on native trajectories.
const CRYSTAL=preload("res://resources/weapon_crystal_cut.gdshader")
const PAINTED=preload("res://resources/weapon_crystal_painted.gdshader")
# ⚠️ 贴图**不能** preload（2026-10-22 实测事故，见 PROJECT-GUIDE §11.99）：
# 刚 pull 下来、还没导入的素材会让 `preload()` 在解析期报 "Could not preload
# resource file"，连带 combat_visuals.gd / main.gd 一起编译失败，游戏连启动都起不来。
# 改成首次使用时 load；拿不到就给纯 shader 表现，既不崩也不会画出白块。
const RIBBON_PATH := "res://assets/combat/crystal-cut-v1/ribbon.png"
const SHARD_PATH := "res://assets/combat/crystal-cut-v1/shard.png"
static var _ribbon_art: Texture2D
static var _shard_art: Texture2D
var target := Vector3.ZERO
var glow: MeshInstance3D
var glow_material: ShaderMaterial

func ribbon_art() -> Texture2D:
	if _ribbon_art==null and ResourceLoader.exists(RIBBON_PATH): _ribbon_art=load(RIBBON_PATH)
	return _ribbon_art

func shard_art() -> Texture2D:
	if _shard_art==null and ResourceLoader.exists(SHARD_PATH): _shard_art=load(SHARD_PATH)
	return _shard_art

func crystal_material(ribbon_mode: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); mat.shader=CRYSTAL
	mat.set_shader_parameter("ribbon_mode",ribbon_mode)
	return mat

func painted_material(texture: Texture2D,is_ribbon: bool) -> ShaderMaterial:
	# 贴图缺件时退回纯水晶 shader：否则 painted_texture 为 null，shader 的默认白图
	# 会被画成一整片白块（用户 2026-10-22 报"特效变成白色方块"）。
	if texture==null: return crystal_material(is_ribbon)
	var mat := ShaderMaterial.new(); mat.shader=PAINTED
	mat.set_shader_parameter("painted_texture",texture)
	mat.set_shader_parameter("ribbon_mode",is_ribbon)
	return mat

func setup(effect: Node3D) -> void:
	super.setup(effect)
	target=captured+axis*span*.82-across*span*.06
	host.body_material=painted_material(ribbon_art(),true); host.ribbon.material_override=host.body_material
	trail_material=crystal_material(false); trail.material_override=trail_material
	host.debris.material_override=painted_material(shard_art(),false)
	trail_material.render_priority=2
	glow_material=ShaderMaterial.new()
	glow_material.shader=preload("res://resources/weapon_crystal_glow.gdshader")
	glow=host.mesh_node(glow_material)
	host.emission_time=.075; host.tail_time=.18; host.life=.55
	rebuild()

func triangle(builder,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
	builder.quad(a,b,c,c,tint)

func variation(seed: float) -> float:
	return fposmod(sin(seed*127.13+71.7)*43758.5453,1.0)

func facet(builder,at: Vector3,direction: Vector3,size: float,seed: int,fade: float) -> void:
	var perpendicular := (axis*-direction.dot(across)+across*direction.dot(axis)).normalized()
	var length := size*(1.15+.17*(seed%3))
	var side := perpendicular*size*.48
	var along := direction*length
	builder.quad(at-along-side,at-along+side,at+along-side,at+along+side,Color(1,1,1,fade))

func arc(t: float,lane: int,end: Vector3) -> Vector3:
	# Two open opposing sweeps converge at the target, with clear space around the actor.
	var start := captured-axis*span*.72+across*span*(.07 if lane==0 else -.02)
	var a := start+axis*span*.24+across*span*(.42 if lane==0 else -.36)
	var b := end-axis*span*.06+across*span*(.50 if lane==0 else -.34)
	var s := 1-t
	return start*s*s*s+a*3*s*s*t+b*3*s*t*t+end*t*t*t

func cut(body,edges,fragments,halo) -> void:
	var age: float=host.age
	if age<=0: return
	var end: Vector3=host.data.get("crystal_contact",target)
	var fade := 1-smoothstep(.10,.29,age)
	for lane in 2:
		var h := 1-pow(1-clampf((age-lane*.016)/.080,0,1),2.0)
		var s := clampf((age-.10-lane*.016)/.16,0,1)
		if h<=s: continue
		var previous := arc(s,lane,end)
		var old_normal := across
		var old_width := 0.0
		for i in 49:
			var t := lerpf(s,h,float(i)/48)
			var at := arc(t,lane,end)
			var tangent := (arc(minf(1,t+.003),lane,end)-arc(maxf(0,t-.003),lane,end)).normalized()
			var normal := (axis*-tangent.dot(across)+across*tangent.dot(axis)).normalized()
			var width := span*(.17+.043*sin(t*11+lane))*pow(maxf(0,sin(t*PI)),.65)
			if i>0:
				body.quad(previous-old_normal*old_width,previous+old_normal*old_width,at-normal*width,at+normal*width,Color(1,1,1,fade*.94),lerpf(s,h,float(i-1)/48),t)
				var thin := span*.0025
				edges.quad(previous+old_normal*old_width,previous+old_normal*(old_width+thin),at+normal*width,at+normal*(width+thin),Color("fff0f8",fade*.94))
				# A separate tapered filament, with breaks rather than a closed outline.
				if (i+lane*3)%13<9:
					var offset := span*(.028+.026*sin(t*9+lane))
					edges.quad(previous-old_normal*offset,previous-old_normal*(offset+thin*.5),at-normal*offset,at-normal*(offset+thin*.5),Color("fbb6d9",fade*.60))
				var w := normal*span*.065
				halo.quad(previous-w,previous+w,at-w,at+w,Color("ee60a8",fade*.14))
			previous=at; old_normal=normal; old_width=width
		for i in 15:
			var t := .06+i*.062
			if t>h or t<s: continue
			var at := arc(t,lane,end)
			var tangent := (arc(minf(1,t+.02),lane,end)-at).normalized()
			var normal := (axis*-tangent.dot(across)+across*tangent.dot(axis)).normalized()
			at+=normal*span*sin(i*2.1+lane)*(.025+.015*(i%3))
			facet(fragments,at,(tangent+normal*sin(i*4.1)*.35).normalized(),span*(.050+.026*(i%4)),i+lane*17,fade*.90)
			if i%3==0:
				facet(fragments,at+normal*span*.12,tangent,span*.024,i+61,fade*.68)

func shatter(fragments,edges,halo) -> void:
	var age: float=host.age
	if age<=0 or age>.38: return
	var fade := 1-smoothstep(.11,.38,age)
	var growth := 1-exp(-age*80)
	var size := 1.35 # independent of the tiny contact-radius field
	for i in 32:
		var r := variation(i+2.0); var q := variation(i+31.0)
		var angle := lerpf(-.85,2.75,r)
		var direction := (axis*cos(angle)+across*sin(angle)).normalized()
		var travel := (.08+q*.62)*growth+age*(.35+.80*q)
		var at := captured+direction*travel-across*.10-across*age*age*1.5
		var length := size*(.060+.15*variation(i+57.0))*(1-age*.55)
		var orientation := (direction+axis*(variation(i+91.0)-.5)*1.6).normalized()
		facet(fragments,at,orientation,length,i,fade)
		if i%7==0:
			var w := across*.002
			edges.quad(captured-w,captured+w,at-w*.2,at+w*.2,Color("ffc9e8",fade*.32))
	# Irregular impact needles: bright center, dark gaps, no opaque white disk.
	for i in 5:
		var dir := (axis*cos(i*2.39996)+across*sin(i*2.39996)).normalized()
		var side := (axis*-dir.dot(across)+across*dir.dot(axis)).normalized()
		var at := captured+dir*(.13+.025*(i%3))*growth
		triangle(edges,captured-side*.014,captured+side*.014,at,Color("fff1f6",fade*.85))
	for i in 5:
		var radius := .09+float(i)*.065
		var a := axis*radius; var b := across*radius
		var contact_peak := 1-smoothstep(.035,.14,age)
		halo.quad(captured-a-b,captured-a+b,captured+a-b,captured+a+b,Color("ff9dcb",fade*(.022+contact_peak*.075)))

func rebuild() -> void:
	var body=Builder.new(); var edges=Builder.new(); var fragments=Builder.new(); var halo=Builder.new()
	if host.kind=="impact": shatter(fragments,edges,halo)
	elif host.kind=="release": cut(body,edges,fragments,halo)
	body.commit(host.ribbon); fragments.commit(host.debris); edges.commit(trail)
	if glow: halo.commit(glow)
	if host.body_material: host.body_material.set_shader_parameter("phase",float(host.age))
