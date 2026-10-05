extends Node2D
## Bounded transient shader layers. Uses event time, never changes combat timing.
const SHADER = preload("res://resources/energy_burst.gdshader")
var bursts: Array[Dictionary] = []
var emitters: Array[CPUParticles2D] = []
const Library = preload("res://scripts/vfx_library.gd")
var spark: Texture2D
var particle_styles: Array[Texture2D]=[]

func _ready() -> void:
	spark=preload("res://scripts/effect_semantics.gd").mote_texture()
	for cell in [6,1,5,2,0]:
		particle_styles.append(spark)

func particles(at: Vector2, color: Color, count: int = 28, direction: Vector2 = Vector2.UP, spread: float = 180.0, power: float = 1.0, style: int = -1) -> void:
	for i in range(emitters.size()-1,-1,-1):
		if not is_instance_valid(emitters[i]): emitters.remove_at(i)
	if emitters.size()>=24:
		emitters[0].queue_free()
		emitters.pop_front()
	var node := CPUParticles2D.new()
	node.position=at
	node.local_coords=true
	node.texture=particle_styles[clampi(style,0,4)] if style>=0 else spark
	node.amount=clampi(roundi(count*.65),3,40)
	node.lifetime=.35+power*.16
	node.one_shot=true
	node.explosiveness=.96
	node.randomness=.5
	node.direction=direction
	node.spread=spread
	node.initial_velocity_min=100*power
	node.initial_velocity_max=280*power
	node.gravity=Vector2(0,100) if spread>90 else Vector2.ZERO
	node.damping_min=45
	node.damping_max=100
	node.scale_amount_min=.006
	node.scale_amount_max=.016*sqrt(power)
	node.angular_velocity_min=-160
	node.angular_velocity_max=160
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,.94,1))
	gradient.add_point(.22,color)
	gradient.set_color(1,Color(color,0))
	node.color_ramp=gradient
	var additive := CanvasItemMaterial.new()
	additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	node.material=additive
	add_child(node)
	emitters.append(node)
	node.finished.connect(node.queue_free)
	node.emitting=true

func spawn(at: Vector2, extent: Vector2, color: Color, form: int, duration: float, angle: float = 0.0, inner: float = 0.0, opening: float = 1.05, source: int = -1) -> void:
	if bursts.size()>=64:
		bursts[0].mount.queue_free()
		bursts.pop_front()
	var mount := Node2D.new()
	mount.position=at
	mount.rotation=angle
	var node := ColorRect.new()
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.size=extent
	node.position=-extent*.5
	var mat := ShaderMaterial.new()
	mat.shader=SHADER
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("form",form)
	mat.set_shader_parameter("life",duration)
	mat.set_shader_parameter("inner",inner)
	mat.set_shader_parameter("opening",opening)
	mat.set_shader_parameter("seed",float(source%97))
	node.material=mat
	mount.add_child(node)
	add_child(mount)
	bursts.append({"node":node,"mount":mount,"age":0.0,"life":duration,"source":source,"form":form})

func cancel_charge(source: int) -> void:
	for i in range(bursts.size()-1,-1,-1):
		if bursts[i].source==source and bursts[i].form==4:
			bursts[i].mount.queue_free()
			bursts.remove_at(i)

func reset() -> void:
	for fx in bursts: fx.mount.queue_free()
	bursts.clear()
	for node in emitters:
		if is_instance_valid(node): node.queue_free()
	emitters.clear()

func advance(dt: float) -> void:
	for i in range(bursts.size()-1,-1,-1):
		var fx: Dictionary=bursts[i]
		fx.age+=dt
		if fx.age>=fx.life:
			fx.mount.queue_free()
			bursts.remove_at(i)
		else: fx.node.material.set_shader_parameter("age",fx.age)
