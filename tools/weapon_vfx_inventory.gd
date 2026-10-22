extends SceneTree
## Read-only resource resolver audit; output is confined to build/.
const Art=preload("res://scripts/weapon_image_art.gd")
const Mechanics=preload("res://scripts/weapon_mechanics.gd")
const Hold=preload("res://scripts/weapon_hold_attack.gd")
var sources: Dictionary={}
func _initialize() -> void: call_deferred("run")
func asset(source: String) -> Dictionary:
	var path := (Art.BASE if source.begins_with("weapon_") else Art.MECHANICS_BASE)+source+".png"
	if Art.mechanics.has(source):
		path=Art.MECHANICS_BASE+str(Art.mechanics.get(source,{}).get("file",""))
	return {"source":source,"path":path,"exists":ResourceLoader.exists(path),"generic":not (source.begins_with("weapon_") or source.begins_with("identity_") or source.begins_with("authored_") or source.begins_with("audit_") or source.begins_with("charged_") or source.begins_with("renewal_"))}
func add_slot(record: Dictionary, slot: String, source: String, role: String) -> void:
	var info := asset(source); info["role"]=role
	record.slots[slot]=info
	if not sources.has(info.path): sources[info.path]=[]
	sources[info.path].append({"index":record.index,"name":record.name,"slot":slot})
func payload(record: Dictionary, slot: String, index: int, kind: String, spell: String, charged: bool=false) -> void:
	var role := Mechanics.projectile_role(index,spell) if kind=="projectile" else Mechanics.beam_role(spell) if kind=="beam" else Mechanics.burst_role(index,spell)
	var source := Art.payload_source(index,kind,role)
	if charged: source=Art.charged_source(index,kind,source)
	add_slot(record,slot,source,role)
func run() -> void:
	Art.load_mechanic_manifest()
	var records: Array=[]
	var indices: Array=[]
	for index in 21: indices.append(index)
	for index in range(600,648): indices.append(index)
	for index in indices:
		var weapon := Catalog.weapon(index)
		var canonical := Art.canonical(index)
		var normal := Mechanics.normal_role(index)
		var art := WeaponArts.of(index)
		var charged := Hold.profile(index)
		var family := Catalog.weapon_family(index)
		var spell := str(weapon.get("spell","bullet" if family==0 else "star"))
		var record := {"index":index,"name":weapon.name,"canonical":canonical,"canonical_name":Catalog.weapon(canonical).name,"same_name_as_canonical":weapon.name==Catalog.weapon(canonical).name,"family":family,"spell":spell,"pattern":weapon.get("pattern",""),"normal_role":normal,"art_name":art.name,"art_kind":art.kind,"charged_name":charged.name,"charged_kind":charged.kind,"charged_spell":charged.get("spell",spell),"slots":{}}
		for stage in 3: add_slot(record,"normal_release_%d" % stage,Art.release_source(index,normal,stage),normal)
		var art_role := Mechanics.strike_role(index,{"attack_kind":art.kind})
		add_slot(record,"art_release",Art.release_source(index,art_role,0,true),art_role)
		var charge_role := Mechanics.strike_role(index,{"attack_kind":charged.kind})
		add_slot(record,"charged_release",Art.charged_source(index,"release",Art.release_source(index,charge_role,0,true)),charge_role)
		if family in [0,3]:
			if spell=="prism": payload(record,"normal_beam",index,"beam",spell)
			else: payload(record,"normal_projectile",index,"projectile",spell)
			if spell in ["meteor","vortex"]: payload(record,"normal_burst",index,"burst",spell)
			if spell=="chain": payload(record,"normal_chain",index,"projectile",spell)
		for move_name in ["art","charged"]:
			var move: Dictionary=art if move_name=="art" else charged
			var move_spell := str(move.get("spell",spell))
			if move.kind in ["beam","burst","volley"]: payload(record,move_name+"_payload",index,"beam" if move.kind=="beam" else "burst" if move.kind=="burst" else "projectile",move_spell,move_name=="charged")
		records.append(record)
	var shared: Dictionary={}
	for path in sources:
		var unique := {}
		for entry in sources[path]: unique[entry.index]=true
		if unique.size()>1: shared[path]=sources[path]
	var report := {"weapons":records,"shared_paths":shared,"weapon_count":records.size(),"unique_paths":sources.size(),"notes":["Only reachable slot categories are listed; release flashes for clean charged ranged attacks may be suppressed by stylized_vfx.","Resolved source identity and generic classification are static evidence; incorrect silhouettes require visual review.","Campaign canonical sharing does not necessarily mean the same named item."]}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	FileAccess.open("res://build/weapon-vfx-inventory.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	var lines := ["index\tname\tcanonical\tcanonical_name\tslot\trole\tsource\tpath\texists\tgeneric"]
	for record in records:
		for slot in record.slots:
			var info: Dictionary=record.slots[slot]
			lines.append("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [record.index,record.name,record.canonical,record.canonical_name,slot,info.role,info.source,info.path,info.exists,info.generic])
	FileAccess.open("res://build/weapon-vfx-inventory.tsv",FileAccess.WRITE).store_string("\n".join(lines))
	print("WEAPON VFX INVENTORY ",records.size()," weapons, ",sources.size()," unique paths, ",shared.size()," shared paths")
	quit()
