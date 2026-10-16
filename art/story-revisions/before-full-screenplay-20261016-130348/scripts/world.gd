extends Node3D
## The original renderer owns the camera, actors, shadows, environment, PBR,
## streaming, terrain, NPCs and map details. This file only adapts new story data.
const OriginalWorld=preload("res://scripts/story_world.gd")
const View=preload("res://scripts/scarlet/render_campaign.gd")
const Art=preload("res://scripts/scarlet/art.gd")
const TONES=[Color("ef607f"),Color("94dbef"),Color("b99ae8")]
var campaign
var original: Node3D
var facade
var view_camera: Camera3D
var extras: Node3D
var mother_crystal: MeshInstance3D
var trial_boat: Node3D
var mechanism_key:=""
var mechanisms: Node3D
var combat_fx: Node2D
var field_props: Node3D
var zoom: float=15.0:
	set(value):
		zoom=value
		if is_instance_valid(original): original.zoom=value
func _ready() -> void:
	original=OriginalWorld.new(); original.name="OriginalStoryRenderer"; add_child(original)
	view_camera=original.view_camera
	facade=View.new(campaign)
	combat_fx=preload("res://scripts/story_combat_vfx.gd").new()
	combat_fx.screen=preload("res://scripts/scarlet/render_fx_host.gd").new(self)
	get_parent().add_child(combat_fx)
	campaign.combat_event.connect(original_combat_event)
	extras=Node3D.new(); extras.name="StoryAdditions"; add_child(extras)
	mechanisms=Node3D.new(); extras.add_child(mechanisms)
	field_props=preload("res://scripts/scarlet/fieldwork_props.gd").new(); field_props.world=self; field_props.campaign=campaign; extras.add_child(field_props)
	mother_crystal=MeshInstance3D.new(); var mesh:=SphereMesh.new(); mesh.radius=.9; mesh.height=2.8; mesh.radial_segments=6; mesh.rings=3
	mother_crystal.mesh=mesh
	var material:=StandardMaterial3D.new(); material.albedo_color=Color("d54c79"); material.emission_enabled=true; material.emission=Color("d54c79")
	mother_crystal.material_override=material; extras.add_child(mother_crystal); mother_crystal.hide()
	trial_boat=Node3D.new(); extras.add_child(trial_boat)
	box(trial_boat,Vector3(0,.03,0),Vector3(1.6,.4,2.7),Color("796351"))
	box(trial_boat,Vector3(0,.7,-.5),Vector3(.1,1.6,.1),Color("534337"))
func point(p: Vector2,y: float=0) -> Vector3:
	var geo=campaign.terrain(); var native: Vector2=geo.native(p)
	return Vector3(native.x*.01,geo.height(p)+y,native.y*.01)
func project(p: Vector2) -> Vector2: return original.project(campaign.terrain().native(p))
func unproject(p: Vector2) -> Vector2: return campaign.terrain().local(original.unproject(p))
func box(parent: Node3D,at: Vector3,extent: Vector3,color: Color) -> MeshInstance3D:
	var node:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=extent; node.mesh=mesh; node.position=at
	var material:=StandardMaterial3D.new(); material.albedo_color=color; material.roughness=.85; node.material_override=material
	parent.add_child(node); return node
func build() -> void:
	if campaign.state.is_empty(): return
	if not campaign.walkable(campaign.hero_at): campaign.hero_at=campaign.spawn_at()
	facade.location_changed.emit()
	original.build_story(facade)
	mechanism_key=""
	field_props.clear()
	for child in extras.get_children():
		if child not in [mother_crystal,trial_boat,mechanisms,field_props]: extras.remove_child(child); child.queue_free()
	if not campaign.state.trial_task.is_empty():
		var water:=ShaderMaterial.new(); water.shader=preload("res://resources/story_water.gdshader")
		var mesh:=PlaneMesh.new(); mesh.size=Vector2(24,52)
		var sea:=MeshInstance3D.new(); sea.mesh=mesh; sea.material_override=water; sea.position=point(Vector2(-330,900),-.24); extras.add_child(sea)
	if campaign.state.zone=="6:7":
		original.environment_builder.kit.instance("watch_map_table",extras,point(campaign.place(Vector2(900,650))),Vector3.ONE)
	if campaign.state.zone=="5:6":
		original.environment_builder.kit.instance("rope_coil",extras,point(campaign.place(Vector2(300,650))),Vector3.ONE)
func sync(dt: float) -> void:
	if campaign.state.is_empty() or facade==null: return
	original.sync_story(Vector2(1440,900),dt)
	combat_fx.advance(dt)
	field_props.sync(dt)
	# The unchanged sprite submission includes the original foot anchoring,
	# terrain-height contact shadows and nearby-light tint for escorted people.
	for i in campaign.escort_group.size():
		var person: Dictionary=campaign.escort_group[i]
		var sheet: Texture2D=Art.texture("res://assets/story/npc-atlas-v1.png")
		var cell: Vector2=sheet.get_size()/Vector2(3,2)
		original.submit_sprite(sheet,Rect2(Vector2(-55,-114),Vector2(110,115)),Rect2(Vector2(i%3,(i/3)%2)*cell,cell),Color.WHITE if person.hp>0 else Color("977484"),Transform2D(0,campaign.terrain().native(person.p)))
	original.end_sprites()
	trial_boat.visible=not campaign.state.trial_task.is_empty()
	if trial_boat.visible: trial_boat.position=point(campaign.hero_at,-.04); trial_boat.rotation.y=-campaign.facing.angle()+PI*.5
	mother_crystal.visible=campaign.combat.running and campaign.combat.context.get("boss","")=="queen" and campaign.combat.phase==2
	if mother_crystal.visible: mother_crystal.position=point(campaign.enemies[0].p,1.4); mother_crystal.rotation.y=campaign.clock*.3
	var signature:=str(campaign.combat.barriers())
	if signature!=mechanism_key:
		mechanism_key=signature
		for child in mechanisms.get_children(): mechanisms.remove_child(child); child.queue_free()
		for b in campaign.combat.barriers():
			for part in range(0,int(b[2]+b[3]),20):
				var x: float=b[0]+b[2]*.5 if b[2]<b[3] else b[0]+minf(part,b[2])
				var y: float=b[1]+minf(part,b[3]) if b[2]<b[3] else b[1]+b[3]*.5
				box(mechanisms,point(Vector2(x,y),.75),Vector3(.13,1.5,.13),Color("775b80"))
func effect(event: Dictionary) -> void:
	if event.kind=="fieldwork_complete": field_props.celebrate(event.p)

func original_combat_event(event: Dictionary) -> void:
	var fx: Dictionary=event.duplicate()
	fx.p=campaign.terrain().native(event.get("p",campaign.hero_at))
	fx.aim=event.get("direction",campaign.facing)
	if event.kind=="attack":
		fx.kind="story_attack"; fx.radius=float(event.radius)*maxf(campaign.terrain().ratio.x,campaign.terrain().ratio.y)
	elif event.kind=="hit":
		var hero := int(event.get("hero",0))
		fx.kind="impact"; fx.weapon_index=campaign.action_weapon if hero==int(campaign.state.hero) and campaign.action_time>0 else campaign.equipped_weapon(hero)
	facade.combat_event.emit(fx)
