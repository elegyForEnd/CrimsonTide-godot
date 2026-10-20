extends SceneTree
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
const Mechanics=preload("res://scripts/weapon_mechanics.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func validate(p: Dictionary) -> void:
	check(p.motion in ["sweep","thrust","spin","chop","wave","hook","recoil","cast","beam"],"Motion has a supported physical meaning")
	check(p.material in ["blood","metal","cloth","frost","storm","tide","stone","feather","void","bell","sun","star","mirror","soul"],"Material is explicit")
	check(p.density_source in Profiles.DENSITIES,"Density uses one of four authored grayscale textures")
	check(float(p.smoke_gain)>=0 and float(p.smoke_gain)<=1,"Smoke is bounded")
	check(absf(float(p.flow))<=2 and absf(float(p.shear))<=1,"Flow and shear stay local and bounded")
	check(float(p.spread)>0 and float(p.spread)<=1,"Internal spread never expands hit radius")
	check(p.attack.layers>=1 and p.attack.layers<=3 and p.attack.edge>0 and p.attack.edge<=1,"Attack layer and edge budgets are bounded")
	check(p.attack.lead>0 and p.attack.peak>0 and p.attack.tail>0 and p.attack.lead+p.attack.peak+p.attack.tail<=1,"Attack phases fit normalized lifetime")
	check(p.impact.compression>0 and p.impact.compression<=1 and p.impact.fragments>=1 and p.impact.fragments<=5 and p.impact.decay>0 and p.impact.decay<=.5,"Impact accents remain short and bounded")
func run() -> void:
	var signatures := {}
	var surface_sources := {}
	var surface_hashes := {}
	Art.load_mechanic_manifest()
	for index in range(600,648)+range(17,21):
		var p := Profiles.profile(index)
		var source := str(p.blade_source)
		var entry: Dictionary=Art.mechanics.get(source,{})
		check(not surface_sources.has(source),"Each independent weapon has its own physical texture source: "+str(index))
		surface_sources[source]=true
		check(entry.get("weapon",-1)==index and entry.get("vfx_version","")=="weapon-v5","Surface provenance belongs to the actual weapon")
		var digest := str(entry.get("sha256",""))
		check(digest.length()==64 and not surface_hashes.has(digest),"Weapon originals are distinct pixel files, not aliases")
		surface_hashes[digest]=true
		check(Art.mechanic_texture(source)!=null,"Dedicated surface imports into the game")
	check(surface_sources.size()==52,"All 48 run weapons and four independent story weapons are covered")
	for index in range(600,648):
		var p := Profiles.profile(index)
		check(p.name==Catalog.weapon(index).name,"Explicit descriptor names the actual weapon")
		validate(p)
		var signature := p.duplicate(true)
		for key in ["index","canonical","name","role"]: signature.erase(key)
		signature.attack.erase("style"); signature.impact.erase("style")
		signatures[JSON.stringify(signature)]=true
		var move := WeaponArts.of(index)
		var roles := [Mechanics.normal_role(index),Mechanics.strike_role(index,{"attack_kind":move.kind}),Mechanics.projectile_role(index,str(Catalog.weapon(index).get("spell","star"))),Mechanics.burst_role(index,str(move.get("spell","star"))),Mechanics.beam_role(str(move.get("spell","star")))]
		for role in roles:
			var selected := Profiles.profile(index,role)
			check(selected.role==role and selected.motion==Profiles.role_motion(role,p.motion),"Actual role controls motion without replacing weapon material")
			check(selected.material==p.material,"Role preserves independent material identity")
	check(signatures.size()==48,"48 distinct behavioral descriptors remain after names, IDs and style labels are removed")
	for index in 17:
		var canonical: int=Profiles.CAMPAIGN_MAP[index]
		var a := Profiles.profile(index); var b := Profiles.profile(canonical)
		a.erase("index"); b.erase("index")
		check(a==b,"Same-name campaign weapon inherits the canonical material behavior")
	for index in 21:
		var art := WeaponArts.of(index)
		var held := preload("res://scripts/weapon_hold_attack.gd").profile(index)
		for role in [Mechanics.normal_role(index),Mechanics.strike_role(index,{"attack_kind":art.kind}),Mechanics.strike_role(index,{"attack_kind":held.kind})]:
			var p := Profiles.profile(index,role)
			check(p.role==role and p.motion==Profiles.role_motion(role,Profiles.profile(index).motion),"Every actual campaign normal, art and held role is honored")
			check(p.spread>0 and p.spread<=1,"Campaign role overrides stay inside the fill budget")
	for index in range(17,21):
		var p := Profiles.profile(index)
		check(p.name==Catalog.weapon(index).name and p.canonical==index,"Starter descriptor has its own identity")
		validate(p)
	check(Profiles.profile(2,"motion_quake").motion=="chop" and Profiles.profile(2,"motion_quake").attack.style=="ground_fault_slam","Campaign dawn quake remains a ground slam")
	check(Profiles.profile(612,"motion_heavy_slash").motion=="chop" and Profiles.profile(612,"motion_heavy_slash").attack.style=="sunsteel_drop","Run dawn cone retains its own heavy cut")
	check(Profiles.profile(15,"motion_quake").motion=="chop" and Profiles.profile(614,"motion_heavy_spin").motion=="spin","Campaign earth quake and run earth spin remain distinct")
	var edited := Profiles.profile(600)
	edited.attack.style="changed"; edited.impact.fragments=99; edited.spread=9
	var fresh := Profiles.profile(600)
	check(fresh.attack.style=="viscous_cut" and fresh.impact.fragments==3 and fresh.spread<=1,"Descriptors are deep independent copies")
	print("WEAPON EFFECT PROFILES ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
