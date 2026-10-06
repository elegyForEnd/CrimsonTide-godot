extends Node3D
## Actions live in the world. Inventory commits only when an action completes.
const Rules = preload("res://scripts/homestead.gd")
const Art = preload("res://scripts/home_art.gd")
const ItemArt = preload("res://scripts/ui_art.gd")
var camp: Control
var home
## Where a picked-up floor item goes. `main.gd` sets it to its own route into the
## character's carried backpack, so the camp floor behaves exactly like picking loot up
## in a raid; a return of false means "no room", and the piece stays on the floor.
var item_receiver: Callable = Callable()
var selected_crop := "wheat"
var action := ""
var elapsed := 0.0
var duration := 1.2
var plot_index := -1
var origin := Vector2.ZERO
var target := Vector2.ZERO
var fishing_phase := ""
var wait_time := 3.0
var bite_time := 0.0
var quality := 0.0
var rng := RandomNumberGenerator.new()
var tools_root := Node3D.new()
var effects_root := Node3D.new()
var drops_root := Node3D.new()
var tool: Node3D
var rod_tip := Vector3.ZERO
var bobber: MeshInstance3D
var fishing_line: MeshInstance3D
var caught: Sprite3D
var highlight := Node3D.new()
var caption := Label3D.new()
var particles: Array = []
var rings: Array = []
var catch_roll := 0.0
var outcome := ""
var outcome_age := 0.0
# Surplus produce that had no room in the bag or pocket, lying on the ground for
# the player to pick up by hand with F. Each entry is a Sprite3D plus how many
# units it still carries, so a half-empty stack stays on the floor.
var drops: Array = []

func _ready() -> void:
	rng.randomize()
	tools_root.name = "ActivityTools"
	effects_root.name = "ActivityEffects"
	add_child(tools_root)
	add_child(effects_root)
	add_child(drops_root)
	drops_root.name = "ActivityDrops"
	add_child(highlight)
	var mat := paint(Color("a9db96"),true)
	for edge in [Vector3(2.12,0.025,0.04),Vector3(2.12,0.025,0.04),Vector3(0.04,0.025,1.98),Vector3(0.04,0.025,1.98)]:
		box(highlight,edge,Vector3.ZERO,mat)
	highlight.get_child(0).position.z = -0.97
	highlight.get_child(1).position.z = 0.97
	highlight.get_child(2).position.x = -1.05
	highlight.get_child(3).position.x = 1.05
	caption.font = load("res://assets/NotoSansSC.ttf")
	caption.font_size = 25
	caption.pixel_size = 0.006
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.outline_size = 7
	caption.modulate = Color("fff2c6")
	caption.no_depth_test = true
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.width = 420
	add_child(caption)

func context(profile: Profile) -> void:
	cancel()
	home = Rules.new(profile)

func busy() -> bool:
	return not action.is_empty()

func paint(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if glow: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func mesh(parent: Node3D, shape: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent,shape,at,mat)

func ball(parent: Node3D, radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius*2
	return mesh(parent,shape,at,paint(color))

func segment(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = maxf(0.001,start.distance_to(end))
	var node := mesh(parent,shape,(start+end)*0.5,mat)
	node.quaternion = Quaternion(Vector3.UP,(end-start).normalized())
	return node

func nearest_plot(at: Vector2, within: float = 155.0) -> int:
	var best := -1
	var distance := within
	for i in 9:
		var d: float = at.distance_to(camp.site.garden_at(i))
		if d<distance:
			distance = d
			best = i
	return best

func at_pier() -> bool:
	return camp.site.DOCK.has_point(camp.site.hero_at) and camp.site.hero_at.distance_to(Vector2(3460,2390))<240

func cycle_seed() -> void:
	if busy(): return
	var keys: Array = Rules.CROPS.keys()
	selected_crop = keys[(keys.find(selected_crop)+1)%keys.size()]
	camp.say("手持种子：%s ×%d" % [Rules.CROPS[selected_crop].name,home.state().seeds[selected_crop]] if home else "请先进入家园。")

func plot_hint(index: int) -> String:
	if not home: return ""
	if index>=home.state().beds: return "尚未开垦 · 去商店扩建"
	var plot: Dictionary = home.state().plots[index]
	if str(plot.crop).is_empty(): return "[E] 播种%s ×%d  [Q] 换种子" % [Rules.CROPS[selected_crop].name,home.state().seeds[selected_crop]]
	if home.remaining(index)==0: return "[E] 收获%s ×3" % Rules.CROPS[plot.crop].name
	return "[E] 浇水 · %s %d秒" % [Rules.CROPS[plot.crop].name,home.remaining(index)] if not plot.watered else "已浇水 · %s %d秒成熟" % [Rules.CROPS[plot.crop].name,home.remaining(index)]

func interact() -> bool:
	if busy():
		if action=="fish": reel()
		return true
	if not home: return false
	var index := nearest_plot(camp.site.hero_at)
	if index>=0: farm(index); return true
	if at_pier(): cast(); return true
	return false

func farm(index: int) -> void:
	if busy() or not home: return
	if index<0 or index>=home.state().beds:
		camp.say("土地尚未开垦，去家园商店扩建。")
		return
	if camp.site.hero_at.distance_to(camp.site.garden_at(index))>155:
		camp.say("走近这块田畦，再按 E 操作。")
		return
	var plot: Dictionary = home.state().plots[index]
	var kind := "plant" if str(plot.crop).is_empty() else ("harvest" if home.remaining(index)==0 else "water")
	if kind=="plant" and home.state().seeds[selected_crop]<=0:
		camp.say("%s种子不足，按 Q 换种子或去商店购买。" % Rules.CROPS[selected_crop].name)
		return
	if kind=="water" and plot.watered:
		camp.say(plot_hint(index))
		return
	start(kind,camp.site.garden_at(index))
	plot_index = index
	duration = 1.45 if kind=="water" else 1.2
	make_tool(kind)

func start(kind: String, at: Vector2) -> void:
	action = kind
	elapsed = 0
	origin = camp.site.hero_at
	target = at
	camp.site.hero_walking = false
	camp.site.hero_facing = 1.0 if at.x>=origin.x else -1.0
	clear_tools()

func make_tool(_kind: String) -> void:
	# The new character frames include the hoe, can, gloves and basket.
	# This invisible pivot is used only as the origin for emitted water drops.
	tool = Node3D.new()
	tools_root.add_child(tool)

func cast() -> void:
	if busy() or not home: return
	if not at_pier(): camp.say("走上月湾栈桥，按 E 或 Space 抛竿。"); return
	var message: String = home.cast()
	if not message.is_empty(): camp.say(message); return
	start("fish",Vector2(3750,2150))
	fishing_phase = "cast"
	wait_time = rng.randf_range(2.3,4.2)
	quality = 0
	tool = Node3D.new()
	tools_root.add_child(tool)
	bobber = ball(tools_root,0.085,Vector3.ZERO,Color("f2c18a"))
	ball(bobber,0.047,Vector3(0,0.09,0),Color("cf5156"))
	fishing_line = MeshInstance3D.new()
	tools_root.add_child(fishing_line)
	camp.say("抛竿……等待浮漂下沉。")
	camp.home_changed.emit()

func fishing_value() -> float:
	return (sin(bite_time*2.6-PI/2)*0.5+0.5)*100

func reel(forced_miss: bool = false) -> void:
	if action!="fish" or fishing_phase=="reel": return
	quality = 0
	if fishing_phase=="bite" and not forced_miss:
		var value := fishing_value()
		var low := 35.0 if home.state().rod==2 else 48.0
		var high := 90.0 if home.state().rod==2 else 82.0
		if value>=low and value<=high: quality = clampf(1.0-absf(value-65)/50.0,0.1,1)
	fishing_phase = "reel"
	elapsed = 0
	if quality>0:
		caught = Sprite3D.new()
		catch_roll = rng.randf()
		var tex: AtlasTexture = Art.icon(Rules.fish_key(quality,catch_roll,int(home.state().rod)))
		caught.texture = tex.atlas
		caught.region_enabled = true
		caught.region_rect = tex.region
		caught.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caught.pixel_size = 0.0022
		tools_root.add_child(caught)
	splash(camp.site.point(target,7))

func clear_tools() -> void:
	for child in tools_root.get_children():
		tools_root.remove_child(child)
		child.queue_free()
	tool = null
	bobber = null
	fishing_line = null
	caught = null

func cancel() -> void:
	if home: home.cancel_cast()
	action = ""
	fishing_phase = ""
	clear_tools()
	if camp and camp.site:
		camp.site.hero_activity = ""
		camp.site.hero_activity_progress = 0

func finish(message: String) -> void:
	outcome = message
	outcome_age = 2.5
	spill_overflow()
	cancel()
	camp.site.refresh_crops(home.state())
	camp.say(message)
	camp.home_changed.emit()

# Anything the harvest or catch left behind because both containers were full gets
# its own billboard on the ground, within reach of F at the spot that produced it.
func spill_overflow() -> void:
	var surplus: Dictionary = home.take_overflow()
	if surplus.is_empty(): return
	var units := int(surplus.units)
	var kind := str(surplus.kind)
	while units>0:
		var batch := mini(6,units)
		drop_item(kind,batch,Vector2(rng.randf_range(-42,42),rng.randf_range(-30,30)))
		units-=batch

func drop_item(kind: String, units: int, offset: Vector2) -> void:
	var at: Vector2 = camp.site.safe_position(origin+offset)
	var node := drop_node(Art.icon(kind),at)
	drops.append({"node":node,"kind":kind,"units":units,"at":at})

## What the camp floor keeps of the newest dropped items: past that the oldest simply
## goes away. The data is tiny, but every drop is also a Sprite3D in the tree, and a
## camp that slows down for loot nobody picked up is worse than one that forgets it.
const GROUND_ITEM_CAP := 60

## An item on the camp floor, dropped by the player out of the bag panel. The record
## carries the whole entry, so a tier-5 sword on the ground is still a tier-5 sword
## when it is picked back up.
func drop_entry(entry: Dictionary, offset: Vector2) -> void:
	var at: Vector2 = camp.site.safe_position(origin+offset)
	var node := drop_node(ItemArt.icon(Catalog.item_icon(entry)),at)
	drops.append({"node":node,"entry":entry.duplicate(true),"at":at})
	trim_drops()

## Keeps the newest `GROUND_ITEM_CAP` dropped items; produce is left alone (it arrives
## from harvesting and thins out on its own as the player picks it up).
func trim_drops() -> void:
	var kept: Array = []
	var items := 0
	for i in range(drops.size()-1,-1,-1):
		var drop: Dictionary=drops[i]
		if drop.has("entry"):
			items+=1
			if items>GROUND_ITEM_CAP:
				free_drop_node(drop)
				continue
		kept.push_front(drop)
	drops=kept

## One Sprite3D for one drop: the shared shape of both kinds of floor loot.
func drop_node(icon: Texture2D, at: Vector2) -> Sprite3D:
	var node := Sprite3D.new()
	if icon is AtlasTexture:
		node.texture=icon.atlas
		node.region_enabled=true
		node.region_rect=icon.region
	else:
		node.texture=icon
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.pixel_size = 0.0035
	node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	node.no_depth_test = false
	node.position = camp.site.point(at,camp.site.ground_height(at)+22)
	drops_root.add_child(node)
	return node

func free_drop_node(drop: Dictionary) -> void:
	var node = drop.get("node")
	if node and is_instance_valid(node): node.queue_free()
	drop.erase("node")

## Leaving the camp parks the floor loot as **data only**: the nodes are freed and
## rebuilt on the way back, so a raid never pays for loot lying in a camp it cannot
## see. The records stay in memory, which is exactly the "closing the game loses it,
## the raid does not" bargain the camp floor is kept under.
func stash_drops() -> void:
	for drop in drops: free_drop_node(drop)
	drops_root.visible=false

func restore_drops() -> void:
	drops_root.visible=true
	for drop in drops:
		if drop.has("node"): continue
		var at: Vector2=drop.get("at",origin)
		if drop.has("entry"):
			drop["node"]=drop_node(ItemArt.icon(Catalog.item_icon(drop.entry)),at)
		else:
			drop["node"]=drop_node(Art.icon(str(drop.get("kind",""))),at)

func has_drop_near(at: Vector2, within: float = 120.0) -> bool:
	for drop in drops:
		if at.distance_to(drop.at)<within: return true
	return false

func nearest_drop(at: Vector2, within: float = 120.0) -> int:
	var best := -1
	var distance := within
	for i in drops.size():
		var d: float = at.distance_to(drops[i].at)
		if d<distance:
			distance = d
			best = i
	return best

# F at a ground stack: pull it back through the same container routing the harvest
# used, so a picked-up fish joins the bag then the pocket. Refuses when there is
# still no room, leaving the stack exactly where it is.
func pick_up_nearby() -> bool:
	var i := nearest_drop(camp.site.hero_at)
	if i<0: return false
	var drop: Dictionary = drops[i]
	# A dropped item asks the panel's owner (the character's backpack, the same
	# containers a raid uses); a refusal keeps it on the floor.
	if drop.has("entry"):
		if not item_receiver.is_valid(): return false
		if not bool(item_receiver.call(drop.entry)): return false
		camp.say("拾取 %s。" % Catalog.item_name(drop.entry))
		free_drop_node(drop)
		drops.remove_at(i)
		return true
	if home.profile.receive_product(str(drop.kind),int(drop.units))>0:
		camp.say("背包和次元口袋都满了，先腾出空间再拾取。")
		return false
	camp.say("拾取 %s ×%d。" % [Rules.CROPS.get(str(drop.kind),Rules.FISH.get(str(drop.kind),{})).name,int(drop.units)])
	free_drop_node(drop)
	drops.remove_at(i)
	return true

func particle(at: Vector3, velocity: Vector3, color: Color, life: float = 0.6) -> void:
	var node := ball(effects_root,0.035,at,color)
	particles.append({"node":node,"v":velocity,"age":0.0,"life":life})

func splash(at: Vector3) -> void:
	for i in 12:
		var angle := i*TAU/12
		particle(at,Vector3(cos(angle)*0.6,0.8,sin(angle)*0.6),Color("a0e1da"))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.16
	ring.outer_radius = 0.19
	var node := mesh(effects_root,ring,at,paint(Color("a8ded0"),true))
	rings.append({"node":node,"age":0.0})

func draw_line(start: Vector3, end: Vector3) -> void:
	var surface := ImmediateMesh.new()
	surface.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,paint(Color("e4ddbf"),true))
	for i in 17:
		var t := float(i)/16
		var at := start.lerp(end,t)
		at.y -= sin(t*PI)*0.22
		surface.surface_add_vertex(at)
	surface.surface_end()
	fishing_line.mesh = surface

func step(dt: float) -> void:
	outcome_age = maxf(0,outcome_age-dt)
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary = particles[i]
		p.age += dt
		p.v.y -= dt*2.8
		p.node.position += p.v*dt
		p.node.scale = Vector3.ONE*(1.0-p.age/p.life)
		if p.age>=p.life: p.node.queue_free(); particles.remove_at(i)
	for i in range(rings.size()-1,-1,-1):
		var r: Dictionary = rings[i]
		r.age += dt
		r.node.scale = Vector3.ONE*(1+r.age*3)
		if r.age>0.8: r.node.queue_free(); rings.remove_at(i)
	update_highlight()
	if not busy(): return
	if camp.input_blocked or not camp.visible or camp.site.hero_at.distance_to(origin)>30:
		cancel()
		return
	elapsed += dt
	if action=="fish": update_fishing(dt); return
	var t := clampf(elapsed/duration,0,1)
	var bend := sin(t*PI)
	camp.site.hero_activity = action
	camp.site.hero_activity_progress = t
	var direction: Vector2 = (target-origin).normalized()
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	tool.position = camp.site.point(origin+direction*45,35+camp.site.ground_height(origin)+bend*12)
	tool.rotation.z = -camp.site.hero_facing*(0.3+sin(t*TAU)*0.75) if action=="plant" else -camp.site.hero_facing*bend*0.65
	if action=="water" and t>0.25 and t<0.82:
		for i in 2:
			particle(tool.position+Vector3(direction.x*0.36,0.15,direction.y*0.36),Vector3(direction.x*0.8,-0.4,direction.y*0.8),Color("89d7e5"),0.5)
	if action=="plant" and t>0.35 and t<0.6:
		particle(camp.site.point(target,18),Vector3(rng.randf_range(-0.3,0.3),0.7,rng.randf_range(-0.3,0.3)),Color("ab8256"))
	if elapsed>=duration:
		var message: String
		if action=="plant": message = home.plant(plot_index,selected_crop)
		elif action=="water" and home.remaining(plot_index)==0:
			message = "作物已经成熟，按 E 播放收获动作。"
		else: message = home.tend(plot_index)
		if action=="harvest":
			for i in 16: particle(camp.site.point(target,45),Vector3(rng.randf_range(-0.7,0.7),1.1,rng.randf_range(-0.7,0.7)),Color("e8cd85"))
		finish(message)

func update_highlight() -> void:
	var index := nearest_plot(camp.site.hero_at)
	highlight.visible = index>=0 and not camp.input_blocked
	caption.visible = highlight.visible or busy() or outcome_age>0
	if index>=0:
		highlight.position = camp.site.point(camp.site.garden_at(index),24)
		caption.position = camp.site.point(camp.site.garden_at(index),145)
		caption.text = plot_hint(index)
	if busy():
		caption.position = camp.site.point(target,155)
		caption.text = {"plant":"翻土 · 播种","water":"倾壶 · 浇水","harvest":"俯身 · 收获","fish":"抛竿 · 等待咬钩"}[action]
	elif outcome_age>0:
		caption.position = camp.site.point(origin,155)
		caption.text = outcome

func update_fishing(dt: float) -> void:
	var height: float = camp.site.ground_height(origin)
	tool.position = camp.site.point(origin+Vector2(30,-10),height+52)
	var angle := 0.8
	var water: Vector3 = camp.site.point(target,7)
	if fishing_phase=="cast":
		var t := clampf(elapsed/0.85,0,1)
		angle = lerpf(-0.6,0.95,t)
		bobber.position = tool.position.lerp(water,t)+Vector3(0,sin(t*PI)*1.4,0)
		camp.site.hero_activity = "cast"
		camp.site.hero_activity_progress = t
		if t>=1:
			fishing_phase = "wait"
			elapsed = 0
			splash(water)
	elif fishing_phase=="wait":
		camp.site.hero_activity = "cast"
		camp.site.hero_activity_progress = 1.0
		bobber.position = water+Vector3(0,sin(elapsed*3)*0.025,0)
		caption.text = "浮漂轻摇……等待咬钩  [Esc] 收起"
		if elapsed>=wait_time:
			fishing_phase = "bite"
			bite_time = 0
			splash(water)
			camp.say("鱼咬钩了！观察浮漂旁的绿色区域，Space / E 收竿。")
	elif fishing_phase=="bite":
		bite_time += dt
		bobber.position = water+Vector3(0,-0.09+sin(bite_time*12)*0.055,0)
		angle = 0.85+sin(bite_time*14)*0.08
		caption.text = "鱼咬钩！  [Space / E] 收竿"
		if bite_time>=6: reel(true)
	elif fishing_phase=="reel":
		var t := clampf(elapsed/1.1,0,1)
		angle = lerpf(0.85,-0.3,t)
		bobber.position = water.lerp(tool.position,t)+Vector3(0,sin(t*PI)*1.6,0)
		if caught:
			caught.position = bobber.position+Vector3(0,0.22,0)
			caught.rotation.z = sin(t*12)*0.35
		camp.site.hero_activity = "reel"
		camp.site.hero_activity_progress = t
		caption.text = "拉紧鱼线 · 收竿"
		if t>=1:
			finish(home.catch_fish(quality,catch_roll))
			return
	tool.rotation.z = -angle
	rod_tip = camp.site.point(origin+Vector2(55,0),height+70)
	draw_line(to_local(rod_tip),bobber.position)

func _process(dt: float) -> void:
	if not camp.visible: return
	step(minf(dt,0.05))
