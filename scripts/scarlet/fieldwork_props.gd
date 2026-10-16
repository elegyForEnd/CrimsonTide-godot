extends Node3D
## Lightweight physical quest objects; animation reads saved work, never changes it.
var world
var campaign
var objects: Dictionary={}
var definitions: Dictionary={}
var materials: Dictionary={}
var signature:=""
var age:=0.0
var bursts: Array=[]
const WOOD:=Color("66503e")
const IRON:=Color("536767")
const BRASS:=Color("b49765")
const PAPER:=Color("d4c9a7")
const GLOW:=Color("81bfae")

func _ready() -> void:
	for q in campaign.content.quests.values():
		for n in q.nodes:
			if campaign.fieldwork.supports(n):
				var item: Dictionary=n.duplicate(true); item.qid=q.id; definitions[n.id]=item

func material(tone: Color,glow: bool=false) -> StandardMaterial3D:
	var key:=str(tone)+str(glow)
	if materials.has(key): return materials[key]
	var mat:=StandardMaterial3D.new(); mat.albedo_color=tone; mat.roughness=.77
	if tone==BRASS or tone==IRON: mat.metallic=.55; mat.roughness=.45
	if glow: mat.emission_enabled=true; mat.emission=tone; mat.emission_energy_multiplier=1.25
	materials[key]=mat; return mat
func mesh(parent: Node3D,shape: Mesh,at: Vector3,tone: Color,glow: bool=false) -> MeshInstance3D:
	var node:=MeshInstance3D.new(); node.mesh=shape; node.position=at; node.material_override=material(tone,glow); parent.add_child(node); return node
func box(parent: Node3D,at: Vector3,extent: Vector3,tone: Color) -> MeshInstance3D:
	var shape:=BoxMesh.new(); shape.size=extent; return mesh(parent,shape,at,tone)
func cylinder(parent: Node3D,at: Vector3,radius: float,height: float,tone: Color) -> MeshInstance3D:
	var shape:=CylinderMesh.new(); shape.top_radius=radius; shape.bottom_radius=radius; shape.height=height; shape.radial_segments=16
	return mesh(parent,shape,at,tone)
func ring(parent: Node3D,at: Vector3,radius: float,tone: Color) -> MeshInstance3D:
	var shape:=TorusMesh.new(); shape.inner_radius=radius*.84; shape.outer_radius=radius; shape.rings=16; shape.ring_segments=8
	return mesh(parent,shape,at,tone)

func create_object(item: Dictionary) -> Dictionary:
	var root:=Node3D.new(); root.name="Field_"+str(item.id).replace(":","_"); add_child(root)
	# Offset a little behind the interaction anchor so the hero never stands inside a prop.
	var native: Vector2=campaign.terrain().native(item.p)+Vector2(48,-46)
	for offset in [Vector2(48,-46),Vector2(-48,-46),Vector2(48,0),Vector2(-48,0),Vector2.ZERO]:
		var candidate: Vector2=campaign.terrain().native(item.p)+offset
		if campaign.terrain().original.walkable(candidate,18): native=candidate; break
	var at: Vector2=campaign.terrain().local(native)
	root.position=world.point(at)
	var kind: String=campaign.fieldwork.profiles[item.id].prop
	var moving:=Node3D.new(); root.add_child(moving)
	var light: OmniLight3D
	match kind:
		"cart":
			for x in [-.55,.55]:
				for z in [-.35,.35]:
					var wheel:=cylinder(moving,Vector3(x,.3,z),.26,.09,IRON); wheel.rotation.z=PI/2
			box(moving,Vector3(0,.65,0),Vector3(1.1,.6,.85),WOOD)
			for x in [-.56,.56]: box(moving,Vector3(x,.66,0),Vector3(.06,.68,.92),BRASS)
			box(moving,Vector3(0,.91,0),Vector3(1.16,.08,.9),WOOD)
		"lock":
			for x in [-.65,.65]: box(root,Vector3(x,.82,0),Vector3(.12,1.64,.18),WOOD)
			box(root,Vector3(0,1.6,0),Vector3(1.4,.12,.2),BRASS)
			moving.position=Vector3(-.58,0,0)
			for x in 6: box(moving,Vector3(x*.23,.8,0),Vector3(.055,1.5,.055),IRON)
			for y in [.2,1.25]: box(moving,Vector3(.56,y,0),Vector3(1.17,.08,.08),IRON)
			box(moving,Vector3(.88,.83,-.08),Vector3(.18,.26,.12),BRASS)
		"valve":
			box(root,Vector3(0,.22,0),Vector3(1.3,.35,.44),IRON)
			cylinder(root,Vector3(0,.65,0),.14,1.05,IRON)
			moving.position=Vector3(0,1.14,0)
			var wheel:=ring(moving,Vector3.ZERO,.52,BRASS); wheel.rotation.x=PI/2
			for i in 6:
				var spoke:=box(moving,Vector3.ZERO,Vector3(.055,.92,.055),IRON); spoke.rotation.z=i*PI/3
			cylinder(moving,Vector3.ZERO,.09,.12,BRASS).rotation.x=PI/2
			var dial:=cylinder(root,Vector3(.44,.93,0),.17,.06,PAPER); dial.rotation.x=PI/2
		"rope":
			for x in [-.65,.65]:
				box(root,Vector3(x,.6,0),Vector3(.15,1.2,.15),WOOD)
				ring(root,Vector3(x,1.05,0),.18,BRASS).rotation.x=PI/2
			for i in 9:
				var coil:=ring(root,Vector3(.25,.07+i*.025,.35),.28-i*.012,BRASS); coil.rotation.z=.08
			for i in 12: box(moving,Vector3(-.6+i*.1,.92-sin(i*PI/11)*.25,0),Vector3(.115,.035,.035),BRASS)
		"lamp","crystal":
			cylinder(root,Vector3(0,.17,0),.43,.34,IRON)
			cylinder(root,Vector3(0,.48,0),.09,.48,BRASS)
			moving.position.y=.85
			if kind=="crystal":
				var shape:=PrismMesh.new(); shape.size=Vector3(.5,.92,.45)
				mesh(moving,shape,Vector3(0,.25,0),Color("bd617c"),true).rotation.z=.12
			else:
				for x in [-.25,.25]:
					for z in [-.25,.25]: box(moving,Vector3(x,.22,z),Vector3(.035,.64,.035),BRASS)
				cylinder(moving,Vector3(0,-.1,0),.38,.08,IRON)
				cylinder(moving,Vector3(0,.56,0),.38,.1,BRASS)
				var bulb:=SphereMesh.new(); bulb.radius=.16; bulb.height=.5; mesh(moving,bulb,Vector3(0,.2,0),GLOW,true)
			light=OmniLight3D.new(); light.light_color=GLOW if kind=="lamp" else Color("dc759a"); light.omni_range=3; light.light_energy=.7; moving.add_child(light)
		"trace":
			for i in 5:
				box(root,Vector3((i%2)*.3-.2,.025,i*.18-.4),Vector3(.13,.02,.22),Color("514e45")).rotation.y=.2
			box(root,Vector3(.68,.08,0),Vector3(.08,.08,1.3),PAPER)
			for i in 8: box(root,Vector3(.67,.13,-.5+i*.14),Vector3(.1,.015,.025),IRON)
			box(moving,Vector3(0,.07,0),Vector3(.9,.02,.025),GLOW)
		_:
			for x in [-.55,.55]:
				for z in [-.34,.34]: box(root,Vector3(x,.34,z),Vector3(.09,.68,.09),WOOD)
			box(root,Vector3(0,.7,0),Vector3(1.35,.12,.95),WOOD)
			if kind=="medical":
				box(root,Vector3(0,.9,0),Vector3(.9,.32,.55),IRON)
				moving.position=Vector3(0,1.05,.27)
				box(moving,Vector3(0,0,-.27),Vector3(.94,.06,.6),WOOD)
				for x in [-.28,0,.28]: cylinder(root,Vector3(x,1.1,-.1),.07,.2,GLOW)
			elif kind=="document":
				for i in 3: box(moving,Vector3(i*.13-.12,.79+i*.014,0),Vector3(.65,.012,.65),PAPER).rotation.y=-.15+i*.2
				for i in 6: box(moving,Vector3(.03,.84,-.2+i*.07),Vector3(.35,.007,.012),IRON)
				cylinder(root,Vector3(.44,.87,.18),.075,.15,Color("8e4d57"))
			else:
				ring(moving,Vector3(0,.84,0),.3,BRASS)
				box(moving,Vector3(0,.87,0),Vector3(.6,.08,.06),IRON).rotation.y=.55
	return {"root":root,"moving":moving,"light":light,"kind":kind,"value":0.0,"base":moving.position}

func sync(dt: float) -> void:
	age+=dt
	var desired: Dictionary={}
	for item in campaign.objective_nodes():
		if campaign.fieldwork.supports(item): desired[item.id]=item
	# Completed mechanisms and investigated objects remain in the world on return visits.
	for id in campaign.state.get("fieldwork",{}):
		if not definitions.has(id) or definitions[id].zone!=campaign.state.zone: continue
		var item: Dictionary=definitions[id].duplicate(true)
		item.p=campaign.place(Vector2(item.at[0],item.at[1])); desired[id]=item
	for id in objects.keys():
		if not desired.has(id): objects[id].root.queue_free(); objects.erase(id)
	for id in desired:
		if not objects.has(id): objects[id]=create_object(desired[id])
		var data: Dictionary=objects[id]
		var active: bool=campaign.fieldwork.active.get("id","")==id
		var receipt: Dictionary=campaign.fieldwork.record(id)
		var value: float=receipt.done.size()/3.0
		if active and not campaign.fieldwork.selected in receipt.done: value+=campaign.fieldwork.progress/3.0
		data.value=move_toward(float(data.value),value,dt*1.5)
		var part: Node3D=data.moving; var amount: float=data.value
		match data.kind:
			"cart": part.position.x=amount*.68
			"lock": part.rotation.y=-amount*1.35
			"valve": part.rotation.z=amount*TAU*1.5
			"rope": part.scale.y=1.0-amount*.22
			"lamp": part.rotation.z=sin(age*2)*(.035 if active else .008)
			"crystal": part.position.y=.85+sin(age*1.7)*.055; part.rotation.y=age*.18
			"medical": part.rotation.x=-sin(amount*PI)*1.5
			"trace": part.position.z=sin(age*1.7)*.5 if active else 0
			"document": part.position.y=sin(age*2)*.015 if active else 0
			_: part.rotation.y=amount*.45
		if is_instance_valid(data.light): data.light.light_energy=(.6+amount*.5)*(1.0+sin(age*3)*.08)
	for burst in bursts:
		burst.age+=dt
		burst.root.scale=Vector3.ONE*(1.0+burst.age*.6)
		for i in burst.bits.size():
			var bit: Node3D=burst.bits[i]; var a: float=i*TAU/burst.bits.size()
			bit.position=Vector3(cos(a)*burst.age*.6,.3+burst.age*(.7+i%3*.2),sin(a)*burst.age*.6)
			bit.scale=Vector3.ONE*maxf(0,1.0-burst.age/1.3)
		if burst.age>1.3: burst.root.queue_free()
	bursts=bursts.filter(func(b): return b.age<=1.3)

func celebrate(at: Vector2) -> void:
	var root:=Node3D.new(); root.position=world.point(at); add_child(root)
	var bits: Array=[]
	for i in 12: bits.append(box(root,Vector3.ZERO,Vector3(.035,.08,.035),GLOW if i%2 else BRASS))
	bursts.append({"root":root,"bits":bits,"age":0.0})

func clear() -> void:
	for data in objects.values(): data.root.queue_free()
	objects.clear()
	for burst in bursts: burst.root.queue_free()
	bursts.clear()
