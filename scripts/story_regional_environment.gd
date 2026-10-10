extends RefCounted
## Five original regional model kits, authored layouts and distinct light colours.
const Art=preload("res://scripts/story_act_art.gd")
static func ground(builder, mat: ShaderMaterial, r) -> void:
	var base: String="a%d_" % r.act
	mat.set_shader_parameter("use_pbr",true)
	for prefix in ["ground","road"]:
		var role: String=base+("ground" if prefix=="ground" else "floor")
		for channel in ["albedo","normal","orm"]:
			mat.set_shader_parameter(prefix+"_"+("tex" if channel=="albedo" else channel),load(builder.kit.BASE+"pbr/"+role+"_"+channel+".png"))
	mat.set_shader_parameter("earth",Color("e0e4df")); mat.set_shader_parameter("road",Color("e9e5df"))
	mat.set_shader_parameter("paving",.55 if r.stage==0 else 0.0)
static func house(builder, r, b: Dictionary) -> void:
	var role: int=int(b.get("role",r.stage%6))
	var rect: Rect2=Rect2(b.rect.position+r.origin,b.rect.size)
	var node: Node3D=builder.kit.instance("a%d_service_%d" % [r.act,role],builder.world.scenery,builder.world.point(rect.get_center(),r.base_height_at(b.rect.get_center())))
	# Camp buildings match the Blender dimensions; larger field villas scale X/Z.
	if r.stage!=0: node.scale=Vector3(rect.size.x/(260+30*(role%3)),1,rect.size.y/(200+30*(role%2)))
	var roof: Node3D=node.find_child("Roof*",true,false); var front: Node3D=node.find_child("Front*",true,false); var side: Node3D=node.find_child("Side*",true,false)
	for part in [roof,front,side]:
		if part: builder.kit.prepare_reveal(part)
	node.set_meta("building_rect",rect)
	builder.roofs.append({"roof":roof,"front":front,"side":side,"rect":rect,"amount":1.0,"inside":false})
static func walls(builder, r) -> void:
	var group := Node3D.new(); group.name="RegionalArchitecture"; builder.world.scenery.add_child(group)
	var points: PackedVector2Array=r.floor_polygon
	for i in points.size():
		var a: Vector2=points[i]; var b: Vector2=points[(i+1)%points.size()]
		var distance := a.distance_to(b); var count := maxi(1,int(ceil(distance/300)))
		for j in count:
			var start := a.lerp(b,float(j)/count); var finish := a.lerp(b,float(j+1)/count); var at: Vector2=(start+finish)*.5+r.origin
			var node: Node3D=builder.kit.instance("a%d_wall" % r.act,group,builder.world.point(at),Vector3(start.distance_to(finish)/300,1,1),(b-a).angle()*-1)
			builder.kit.prepare_reveal(node)
			node.set_meta("occluder",{"p":at,"height":250.0}); builder.occluders.append({"node":node,"p":at,"height":250.0})
	for at in r.anchors+r.side_anchors:
		var light := OmniLight3D.new(); light.position=builder.world.point(r.origin+at,r.height_at(at)+190)
		light.light_color=Color(Art.palette(r.act).lamp); light.light_energy=.95; light.omni_range=6.0
		light.shadow_enabled=false; light.light_bake_mode=Light3D.BAKE_DYNAMIC
		group.add_child(light); builder.lights.append(light)
static func camp(builder, r) -> void:
	for x in [200,500,1700,2000]:
		builder.kit.instance("a%d_wall" % r.act,builder.world.scenery,builder.world.point(Vector2(x,1850)),Vector3(1,.5,1))
	for at in [Vector2(150,200),Vector2(2050,200),Vector2(150,1660),Vector2(2050,1660)]:
		builder.kit.instance("a%d_rock" % r.act,builder.world.scenery,builder.world.point(at),Vector3.ONE*.8)
	for x in [120,2080]:
		for y in [600,1200]: builder.kit.instance("a%d_wall_broken" % r.act,builder.world.scenery,builder.world.point(Vector2(x,y)),Vector3(.7,.55,1),PI*.5)
static func atmosphere(world) -> void:
	var act: int=world.campaign.state.act
	if act<2: return
	var p := Art.palette(act)
	var open_sky: bool=world.campaign.map.regions[world.campaign.map.stage].exploration_plan.get("sky_open",false)
	for child in world.get_children():
		if child is DirectionalLight3D:
			child.light_color=Color(p.sun); child.light_energy=.72 if world.campaign.map.layer==0 else .56 if open_sky else .26
		elif child is WorldEnvironment:
			child.environment.ambient_light_color=Color(p.ambient)
			child.environment.ambient_light_energy=.34 if world.campaign.map.layer==0 or open_sky else .28
			child.environment.background_color=Color.BLACK
static func feature_lights(builder, r, parent: Node3D) -> void:
	if not r.exploration_plan.is_empty(): return
	if not r.indoor:
		if r.act in [3,4,5] and RenderingServer.get_current_rendering_method()=="forward_plus" and DisplayServer.get_name()!="headless":
			for at in [Vector2(600,1600),Vector2(700,3400)]:
				var fog := FogVolume.new(); fog.name="RegionalGroundMist"; parent.add_child(fog)
				fog.position=builder.world.point(r.origin+at,r.height_at(at)+40); fog.size=Vector3(5,1.3,7)
				var mat := ShaderMaterial.new(); mat.shader=preload("res://resources/story_mist.gdshader"); fog.material=mat
				fog.add_to_group("quality_fog",true)
				if builder.world.has_node("/root/GraphicsQuality"): fog.visible=builder.world.get_node("/root/GraphicsQuality").quality==0
		return
	var group := Node3D.new(); group.name="RegionalFeatureLights"; parent.add_child(group)
	for at in [Vector2(2400,2200),Vector2(850,1800),Vector2(3700,2600),Vector2(2400,4250)]:
		var light := OmniLight3D.new(); group.add_child(light)
		light.position=builder.world.point(r.origin+at,r.height_at(at)+160)
		light.light_color=Color("ffcf9f") if r.act in [3,5] else Color("f6c4a0")
		light.light_energy=.65; light.omni_range=4.8; light.shadow_enabled=false
		light.light_bake_mode=Light3D.BAKE_DISABLED; builder.lights.append(light)
static func wall_joints(builder, r, parent: Node3D) -> void:
	if not r.exploration_plan.is_empty(): return
	if parent.has_node("RegionalCornerQuoins"): return
	# The exported wall cap is 3.10m wide. Space its actual silhouette, not
	# the nominal 3m brickwork: this removes coplanar cap overlap at each join.
	for node in parent.find_children("*","Node3D",true,false):
		if node.get_meta("story_model","")=="a%d_wall" % r.act: node.scale.x*=300.0/310.0
	var group := Node3D.new(); group.name="RegionalCornerQuoins"; parent.add_child(group)
	var points: Array=[]
	if r.indoor:
		for p in r.floor_polygon: points.append(p)
	elif r.stage==0: points=[Vector2(350,1850),Vector2(1850,1850)]
	else: return
	var mesh := CylinderMesh.new(); mesh.radial_segments=12
	mesh.top_radius=.35; mesh.bottom_radius=.35; mesh.height=2.85 if r.indoor else 1.50
	var material: StandardMaterial3D=builder.kit.pbr("a%d_wall" % r.act,Color("d1d1c8")).duplicate()
	material.uv1_scale=Vector3(.85,1.8,1)
	for at in points:
		var holder := Node3D.new(); group.add_child(holder)
		holder.position=builder.world.point(r.origin+at,r.height_at(at))
		var body := MeshInstance3D.new(); holder.add_child(body); body.mesh=mesh; body.material_override=material
		body.position.y=mesh.height*.5; body.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		builder.kit.prepare_reveal(holder)
		holder.set_meta("occluder",{"p":r.origin+at,"height":mesh.height*100})
		builder.occluders.append({"node":holder,"p":r.origin+at,"height":mesh.height*100})
