extends RefCounted
## Presentation reads real attack geometry and spell payloads, never icon motifs.
static func normal_role(index: int) -> String:
	var weapon := Catalog.weapon(index)
	var family := Catalog.weapon_family(index)
	if family==0: return "release_bow" if weapon.get("spell","")=="arrow" else "muzzle_fire"
	if family==3: return cast_role(index)
	match str(weapon.get("pattern","")):
		"thrust": return "motion_thrust"
		"spin": return "motion_spin" if family==1 else "motion_heavy_spin"
		"quake": return "motion_quake"
	if index==603: return "motion_double_slash"
	if index==621: return "motion_narrow_sweep"
	if index in [20,622]: return "motion_scythe"
	return "motion_slash" if family==1 else "motion_heavy_slash"

static func strike_role(index: int, data: Dictionary) -> String:
	if not data.has("attack_kind"): return normal_role(index)
	match str(data.attack_kind):
		"thrust": return "motion_thrust"
		"circle":
			if index in [2,15]: return "motion_quake" # Campaign arts explicitly slam the ground.
			return "motion_spin" if Catalog.weapon_family(index)==1 else "motion_heavy_spin"
		"cone": return "motion_heavy_overhead" if index==19 else "motion_heavy_slash"
		"volley": return "release_bow" if Catalog.weapon(index).get("spell","")=="arrow" else "muzzle_fire" if Catalog.weapon_family(index)==0 else cast_role(index)
		"beam", "burst": return cast_role(index)
	return normal_role(index)

static func cast_role(index: int) -> String:
	if index==646: return "cast_soul"
	if index==647: return "cast_bell"
	match str(Catalog.weapon(index).get("spell","star")):
		"needle": return "cast_ice"
		"meteor", "scatter": return "cast_fire"
		"chain": return "cast_storm"
		"moon", "eclipse": return "cast_moon"
		"prism": return "cast_light"
		"vortex": return "cast_void"
	return "cast_star"

static func projectile_role(index: int, spell: String) -> String:
	if Catalog.weapon_family(index)==0:
		return "projectile_arrow" if Catalog.weapon(index).get("spell","")=="arrow" else "projectile_bullet"
	# The ice staff's art uses scatter's pellet rules, but remains five ice needles.
	if index in [5,638] and spell=="scatter": return "projectile_needle"
	if index==646 and spell=="vortex": return "projectile_soul"
	match spell:
		"bullet": return "projectile_bullet"
		"arrow": return "projectile_arrow"
		"needle": return "projectile_needle"
		"meteor": return "projectile_meteor"
		"chain": return "projectile_lightning"
		"moon": return "projectile_moon"
		"scatter": return "projectile_feather"
		"eclipse": return "projectile_eclipse"
		"vortex": return "projectile_vortex"
	return "projectile_star"

static func burst_role(index: int, spell: String) -> String:
	if index==646: return "burst_soul"
	if index==647: return "burst_bell"
	if index==645: return "burst_blood"
	match spell:
		"meteor", "scatter": return "burst_fire"
		"chain": return "burst_lightning"
		"vortex": return "burst_void"
		"moon": return "burst_moon"
	return "burst_star"

static func beam_role(spell: String) -> String:
	return "beam_eclipse" if spell=="eclipse" else "beam_moon" if spell=="moon" else "beam_light"

static func body_centered(role: String) -> bool:
	return role in ["motion_spin","motion_heavy_spin","motion_quake"]

static func projectile_size(role: String, index: int = -1) -> Vector2:
	match role:
		"projectile_bullet": return Vector2(22,3)
		"projectile_arrow": return Vector2(32,6) if index in [626,634] else Vector2(46,8)
		"projectile_needle": return Vector2(48,7)
		"projectile_meteor": return Vector2(64,34)
		"projectile_moon": return Vector2(26,34)
		"projectile_feather": return Vector2(30,9)
		"projectile_eclipse": return Vector2(66,12)
		"projectile_lightning": return Vector2(30,13)
	return Vector2(32,32)

static func projectile_thickness(role: String) -> float:
	match role:
		"projectile_bullet": return 5.0
		"projectile_arrow": return 8.0
		"projectile_needle": return 10.0
		"projectile_feather": return 11.0
		"projectile_eclipse": return 14.0
		"projectile_lightning": return 16.0
	return 0.0
