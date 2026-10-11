extends Node3D
## Bounded shadow-free transient illumination. Pure presentation, shared across modes.
const CAPACITY := 8
var flashes: Array[Dictionary]=[]
var pool: Array[OmniLight3D]=[]
var height_at: Callable
func _ready() -> void:
	for i in CAPACITY:
		var light := OmniLight3D.new(); light.shadow_enabled=false
		light.omni_range=3.6; light.omni_attenuation=2.5
		light.light_bake_mode=Light3D.BAKE_DISABLED
		light.hide(); add_child(light); pool.append(light)
func pulse(p: Vector2, color: Color, strength: float, life: float) -> void:
	if pool.is_empty(): return
	var index := -1
	for i in pool.size():
		if not pool[i].visible: index=i; break
	if index<0:
		# Saturated scenes retain existing flashes instead of replacing every frame.
		return
	var ground := float(height_at.call(p)) if height_at.is_valid() else 0.0
	pool[index].position=Vector3(p.x*.01,ground*.01+.65,p.y*.01)
	pool[index].light_color=color; pool[index].light_energy=strength
	pool[index].show()
	flashes.append({"index":index,"age":0.0,"life":life,"energy":strength})
func advance(dt: float) -> void:
	for i in range(flashes.size()-1,-1,-1):
		var fx: Dictionary=flashes[i]; fx.age+=dt
		pool[int(fx.index)].light_energy=float(fx.energy)*pow(maxf(0,1-float(fx.age)/float(fx.life)),2)
		if fx.age>=fx.life: pool[int(fx.index)].hide(); flashes.remove_at(i)
func reset() -> void:
	flashes.clear()
	for light in pool: light.hide()
