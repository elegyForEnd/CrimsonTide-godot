extends RefCounted
## Small held accents reuse each weapon's authored colors and silhouette.
const Art=preload("res://scripts/weapon_image_art.gd")
const Mechanics=preload("res://scripts/weapon_mechanics.gd")
static func sample(pose: Dictionary, seconds: float) -> Dictionary:
	var accents := samples(pose,seconds)
	return {} if accents.is_empty() else accents[0]

static func samples(pose: Dictionary, seconds: float) -> Array[Dictionary]:
	var accents: Array[Dictionary]=[]
	if not pose.get("weapon_atlas",false) or str(pose.get("state","")) not in ["idle","walk","run","dodge"]: return accents
	var weapon := int(pose.weapon_identity)
	var family := Catalog.weapon_family(weapon)
	var role := Mechanics.normal_role(weapon)
	var source := Art.release_source(weapon,role,0)
	# Keep body-centered strike paintings confined to the held tip.
	if Mechanics.body_centered(role): source="weapon_%d_release" % weapon
	var texture := Art.mechanic_texture(source)
	if texture==null: return accents
	var ink := Art.mechanic_ink(source)
	var unit := clampf(float(pose.get("standing_height",140))/140.0,.6,1.25)
	var period := 1.7+float(weapon%7)*.11
	var phase := seconds*TAU/period+float(weapon%11)*.57
	var breath := .5+.5*sin(phase)
	var extent := (14.0 if family==3 else 10.0 if family==0 else 12.0)*unit
	var scale := extent*(.92+.08*breath)/maxf(ink.size.x,ink.size.y)
	var tip := CharacterMetrics.FOOT_OFFSET+Vector2(pose.socket)
	accents.append({"texture":texture,"rect":Rect2(tip-ink.get_center()*scale,texture.get_size()*scale),"tint":Color(1,1,1,.19+.12*breath),"source":source})
	# Spell heads shed one faint wisp; metal and firearm tips only breathe in place.
	if family==3:
		var travel := fposmod(seconds/(1.1+float(weapon%5)*.13)+float(weapon%7)*.14,1.0)
		var offset := Vector2(sin(phase)*1.8,-travel*7.0)*unit
		var wisp_scale := scale*(.38-.12*travel)
		accents.append({"texture":texture,"rect":Rect2(tip+offset-ink.get_center()*wisp_scale,texture.get_size()*wisp_scale),"tint":Color(1,1,1,sin(travel*PI)*.17),"source":source})
	return accents
