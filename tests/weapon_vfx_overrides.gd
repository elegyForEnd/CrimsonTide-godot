extends SceneTree
const Art=preload("res://scripts/weapon_image_art.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	Art.load_overrides(); Art.load_mechanic_manifest()
	var configured: Dictionary=Art.overrides.duplicate(true)
	# In-memory fixtures exercise rule semantics without rewriting production metadata.
	Art.overrides={"releases":[
		{"weapon":612,"role":"motion_quake","source":"canonical_quake","scope":"canonical"},
		{"weapon":2,"role":"motion_quake","source":"campaign_quake","scope":"exact","weapon_art":true},
		{"weapon":613,"role":"motion_heavy_slash","source":"renewal_heavy","scope":"canonical"}],
		"payloads":[{"weapon":638,"payload":"projectile","source":"canonical_needle","scope":"canonical"},
		{"weapon":5,"payload":"projectile","source":"campaign_needle","scope":"exact"}]}
	check(Art.release_source(2,"motion_quake",0,true)=="campaign_quake","Exact campaign action takes priority regardless of rule order")
	check(Art.release_source(2,"motion_quake",0,false)=="canonical_quake","Optional weapon_art filter does not leak into another action")
	check(Art.release_source(612,"motion_quake",0,true)=="canonical_quake","Exact campaign rule does not replace the run action")
	check(Art.release_source(14,"motion_heavy_slash",2,true)=="renewal_heavy","Canonical rule covers same-name campaign weapon and all combo stages")
	check(Art.release_source(613,"motion_heavy_slash",0,false)=="renewal_heavy","Omitted weapon_art filter covers normal release")
	check(Art.override_source("releases",613,"motion_thrust").is_empty(),"Different semantic role does not match")
	check(Art.payload_source(5,"projectile","projectile_needle")=="campaign_needle","Exact payload takes priority")
	check(Art.payload_source(638,"projectile","projectile_needle")=="canonical_needle","Canonical payload applies to run weapon")
	check(Art.override_source("payloads",638,"burst").is_empty(),"Projectile override does not replace an explosion")
	var source := "renewal_manifest_fixture"
	var fixture: Dictionary=Art.mechanics.authored_624_projectile.duplicate(true)
	fixture.ink=[10,20,110,70]
	Art.mechanics[source]=fixture
	var texture := Art.mechanic_texture(source)
	check(texture!=null and texture.resource_path==Art.MECHANICS_BASE+str(fixture.file),"Arbitrary manifest key resolves its registered file")
	check(Art.mechanic_ink(source)==Rect2(10,20,100,50),"Arbitrary manifest key uses registered ink bounds")
	check(Art.mechanic_texture(source)==texture,"Custom source retains the existing texture cache")
	Art.mechanics.erase(source); Art.cells.erase("mechanic:"+source)
	Art.overrides=configured
	var config_entries := 0
	for category in ["releases","payloads"]:
		for rule in configured.get(category,[]):
			config_entries+=1
			check(rule is Dictionary and rule.has("weapon") and rule.has("source"),"Configured rule declares weapon and source")
			check(str(rule.get("scope","exact")) in ["exact","canonical"],"Configured rule declares a supported scope")
			var selected := str(rule.source)
			check(Art.mechanic_texture(selected)!=null,"Configured override texture exists: "+selected)
			var ink := Art.mechanic_ink(selected)
			check(ink.size.x>0 and ink.size.y>0,"Configured override has non-empty ink: "+selected)
	print("WEAPON VFX OVERRIDES ",checks," checks, ",failures," failures; ",config_entries," production rules")
	quit(1 if failures else 0)
