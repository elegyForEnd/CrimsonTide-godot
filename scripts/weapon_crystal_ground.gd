extends Node2D
## Reflected light in the flat roguelike's painted floor, below actors and props.
var field: Control
func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://resources/weapon_crystal_ground.gdshader")
	material=mat
func _draw() -> void:
	if not is_instance_valid(field) or not is_instance_valid(field.combat): return
	draw_set_transform(-field.camera_offset())
	for flash in field.combat.crystal_reflections:
		var fade := 1-smoothstep(.025,.30,float(flash.age))
		var at: Vector2=flash.p
		var radius := Vector2(float(flash.get("radius",105)),float(flash.get("radius",105))*.43)*(1+float(flash.age)*.6)
		var points := PackedVector2Array([at-radius,at+Vector2(radius.x,-radius.y),at+radius,at+Vector2(-radius.x,radius.y)])
		var tone: Color=flash.get("color",Color(.95,.23,.52))
		draw_polygon(points,PackedColorArray([Color(tone,fade*.32)]),PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]))
