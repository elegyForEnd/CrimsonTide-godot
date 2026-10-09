extends "res://scripts/world_3d.gd"
## Same upright sprite/depth contract as the shipped 2.5D world.
const Heroes = preload("res://scripts/character_frames.gd")
const Foes = preload("res://scripts/enemy_frames.gd")
const Bosses = preload("res://scripts/boss_frames.gd")
var hero_frames = Heroes.new()
var enemy_frames = Foes.new()
var boss_frames = Bosses.new()
var campaign
var focus := Vector2.ZERO
var npc_models: Array=[]
var quest_models: Dictionary={}
var quest_signature := ""
var npc_sheet: Texture2D
const TONES := [Color("617065"),Color("77727d"),Color("627184"),Color("766579"),Color("4a6e79"),Color("6a576c")]

var environment_builder = preload("res://scripts/story_environment.gd").new()
var geometry_key := ""
var zoom := 15.0

func build_story(c) -> void:
	campaign=c
	var signature := "%d:%d" % [c.state.act,c.map.layer]
	if geometry_key!=signature:
		geometry_key=signature
		if scenery:
			remove_child(scenery); scenery.queue_free()
		scenery=Node3D.new(); scenery.name="StoryScenery"; add_child(scenery)
		quest_models.clear(); quest_signature=""
		environment_builder.build(self)
		focus=c.hero_at
		for child in get_children():
			if child is DirectionalLight3D:
				child.rotation_degrees=Vector3(-52,-35,0)
				child.light_color=Color("e6d5b0"); child.light_energy=.75 if c.map.layer==0 else .20
			if child is WorldEnvironment:
				child.environment.ambient_light_color=Color("9ba7b6")
				child.environment.ambient_light_energy=.48 if c.map.layer==0 else .28
				child.environment.background_color=Color("171b20")
	sync_story(Vector2(1440,900),0)

func project(p: Vector2) -> Vector2:
	return view_camera.unproject_position(point(p,campaign.map.height_at(p)))

func unproject(screen: Vector2) -> Vector2:
	var height: float=campaign.map.height_at(campaign.hero_at)*UNIT
	var at: Vector2=campaign.hero_at
	for i in 4:
		var hit: Variant=Plane(Vector3.UP,height).intersects_ray(view_camera.project_ray_origin(screen),view_camera.project_ray_normal(screen))
		if hit==null: return at
		at=Vector2(hit.x,hit.z)/UNIT; height=campaign.map.height_at(at)*UNIT
	return at

func submit_sprite(texture: Texture2D, rect: Rect2, region: Rect2, tint: Color, pose: Transform2D) -> void:
	super.submit_sprite(texture,rect,region,tint,pose)
	sprites[used-1].position.y=(campaign.map.height_at(pose.origin)+2)*UNIT

func sync_story(screen: Vector2, dt: float) -> void:
	if campaign==null: return
	focus=focus.lerp(campaign.hero_at,1.0-exp(-8.0*dt)) if dt>0 else campaign.hero_at
	view_camera.size=zoom
	var target := point(focus,campaign.map.height_at(focus))
	view_camera.position=target+Vector3(12,24,19)
	view_camera.look_at(target)
	environment_builder.sync(focus)
	begin_sprites()
	for i in 3:
		var data: Dictionary
		if i==int(campaign.state.hero) and campaign.attack_time>0:
			data=hero_frames.attack_frame(i,3 if i==1 else 1,mini(3,int((0.38-campaign.attack_time)/0.10)))
		elif campaign.moving:
			data=hero_frames.motion_frame(i,"walk",campaign.clock*8,0)
		else: data=hero_frames.idle_frame(i,3 if i==1 else 1,0)
		var rect: Rect2=data.rect
		rect.position-=CharacterMetrics.FOOT_OFFSET
		var transform := Transform2D(0,campaign.hero_at if i==int(campaign.state.hero) else campaign.allies[i])
		if campaign.facing.x<0: transform.x.x=-1
		var tint := Color.WHITE if campaign.hurt_time<=0 or i!=campaign.state.hero else Color("ec9aaf")
		submit_sprite(data.texture,rect,Rect2(),tint,transform)
	if campaign.map.layer==0 and ResourceLoader.exists("res://assets/story/npc-atlas-v1.png"):
		if npc_sheet==null: npc_sheet=load("res://assets/story/npc-atlas-v1.png")
		var cell := npc_sheet.get_size()/Vector2(3,2)
		for i in 6:
			var face_index: int=0 if int(campaign.state.act)==6 and i==5 else i
			var region := Rect2(Vector2(face_index%3,int(face_index/3))*cell,cell)
			var extent := Vector2(115*cell.x/cell.y,115)
			submit_sprite(npc_sheet,Rect2(Vector2(-extent.x/2,-extent.y*.99),extent),region,Color.WHITE,Transform2D(0,campaign.map.npc_at[i]))
	for e in campaign.enemies:
		var rect: Rect2
		var region: Rect2
		var tex: Texture2D
		var frame := 11 if e.hp<=0 else 10 if e.flash>0 else 5 if e.windup>0 else 1+int(campaign.clock*6)%3
		if e.boss:
			var idx := Bosses.KEYS.find(e.art)
			if idx>=0:
				tex=boss_frames.sheets[idx]; rect=boss_frames.sprite_rect(idx)
			else:
				idx=Bosses.SPECIAL_KEYS.find(e.art)
				tex=boss_frames.special_sheet(idx); rect=boss_frames.special_sprite_rect(idx)
			region=Bosses.region(frame)
		else:
			tex=enemy_frames.sheets[int(e.type)]; rect=Foes.sprite_rect(int(e.type)); region=enemy_frames.region(frame)
		submit_sprite(tex,rect,region,Color("ffaaaa") if e.flash>0 else Color.WHITE,Transform2D(0,e.p))
	end_sprites()
	sync_quest_objects()

func sync_quest_objects() -> void:
	var nodes: Array=campaign.objective_nodes()
	var signature := ""
	for node in nodes: signature+=node.id+str(node.step)
	if signature==quest_signature: return
	quest_signature=signature
	for holder in quest_models.values(): holder.queue_free()
	quest_models.clear()
	for node in nodes:
		var text: String=node.label
		var model := "halloween/shrine_candles"
		var dimensions := Vector3(85,70,70)
		if "取" in text or "找" in text or "箱" in text:
			model="dungeon/chest_gold"; dimensions=Vector3(75,55,60)
		elif "记录" in text or "证" in text or "图" in text:
			model="dungeon/table_long_decorated_A"; dimensions=Vector3(100,60,70)
		elif "修" in text or "关闭" in text or "校准" in text:
			model="dungeon/pillar_decorated"; dimensions=Vector3(60,90,60)
		quest_models[node.id]=prop(model,node.p,dimensions,Color("b9ad96"),Color.WHITE,0,campaign.map.height_at(node.p))
