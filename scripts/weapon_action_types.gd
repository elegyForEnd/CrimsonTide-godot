extends RefCounted
## Shared physical poses; effects and hit geometry keep the concrete weapon ID.
const Art=preload("res://scripts/weapon_image_art.gd")
const NAMES := {"sword":"单手剑", "thrust":"刺剑", "dual":"双刃", "greatsword":"重剑", "hammer":"巨锤", "axe":"战斧", "polearm":"长柄武器", "scythe":"镰刀", "bow":"弓弩", "firearm":"枪械", "dual_firearm":"双枪", "staff":"法杖"}

static func type_for(weapon: int) -> String:
	var identity := Art.canonical(weapon)
	if identity==603: return "dual"
	if identity==631: return "dual_firearm"
	if identity in [615,619]: return "hammer"
	if identity in [616,618]: return "axe"
	if identity==621: return "polearm"
	if identity in [20,622]: return "scythe"
	var data := Catalog.weapon(weapon)
	match Catalog.weapon_family(weapon):
		0: return "bow" if str(data.get("spell",""))=="arrow" else "firearm"
		1: return "thrust" if str(data.get("pattern",""))=="thrust" else "sword"
		2: return "greatsword"
	return "staff"
