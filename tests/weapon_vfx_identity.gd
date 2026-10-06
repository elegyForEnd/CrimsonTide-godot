extends SceneTree
## GPU verification: concrete weapons, combo stages, socket stability and cleanup.
const FX=preload("res://scripts/stylized_vfx.gd")
const Identity=preload("res://scripts/weapon_vfx.gd")
var checks := 0
var failures := 0
var socket := {"tip":Vector2(220,150),"aim":Vector2.RIGHT,"active":true}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func attack(fx, weapon: int, combo: int, route: int = -1) -> void:
	var w := Catalog.weapon(weapon)
	fx.event({"kind":"strike","p":Vector2(150,150),"aim":Vector2.RIGHT,"id":1,
		"weapon":Catalog.weapon_family(weapon),"weapon_index":weapon,"reach":100,
		"pattern":w.get("pattern",""),"combo":combo,"combo_route":route},0)
	fx.shards.clear(); fx.particles.reset()
func pixels(viewport: SubViewport, fx) -> PackedByteArray:
	fx.queue_redraw(); fx.light.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image().get_data()
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(320,300)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var fx := FX.new(); viewport.add_child(fx)
	fx.socket_provider=func(_id): return socket
	var identities := {}
	var images := {}
	for weapon in range(600,648):
		var profile := Identity.profile(weapon)
		identities["%s:%s:%d" % [profile.motif,profile.color.to_html(),profile.detail]]=true
		var stages := {}
		for combo in 3:
			fx.reset(); attack(fx,weapon,combo); fx.advance(.065)
			check(fx.effects[0].identity.weapon==weapon,"Concrete run weapon identity is retained")
			check(fx.effects[0].has("socket_local"),"Native geometry captures the weapon socket")
			var data: PackedByteArray=await pixels(viewport,fx)
			var hash_value := hash(data)
			stages[hash_value]=true
			if combo==2: images[hash_value]=true
			check(viewport.get_texture().get_image().get_used_rect().has_area(),"Weapon produces visible GPU pixels")
		check(stages.size()==3,"Weapon %d has three visually different combo stages" % weapon)
	check(identities.size()==48,"48 authored run weapon identities")
	check(images.size()==48,"All 48 run weapons render differently")
	# Upgrade art must change rendered light without changing attack geometry.
	var upgrade_pixels := {}
	var upgrade_radius := 0.0
	for forge in [0,2,3,4,5]:
		fx.reset()
		fx.event({"kind":"strike","p":Vector2(150,150),"aim":Vector2.RIGHT,"id":1,"weapon":1,"weapon_index":600,"combo":0,"reach":70,"vfx":{"forge":forge,"quality":0}},0)
		if forge==0: upgrade_radius=float(fx.effects[0].radius)
		check(is_equal_approx(float(fx.effects[0].radius),upgrade_radius),"Forging preserves the attack's presentation reach")
		fx.advance(.065)
		upgrade_pixels[hash(await pixels(viewport,fx))]=true
	check(upgrade_pixels.size()==5,"Actual forge levels change GPU edge light")
	for core_id in range(1,13):
		var tiers := {}
		for rank in [1,2]:
			fx.reset()
			fx.event({"kind":"weapon_core","p":Vector2(150,150),"aim":Vector2.RIGHT,"id":1,"weapon_index":600,"core_id":core_id,"core_rank":rank},0)
			fx.advance(.065)
			tiers[hash(await pixels(viewport,fx))]=true
		check(tiers.size()==2,"Core %d has two visibly different unlocked tiers" % core_id)
	for weapon in 21:
		var stages := {}
		for combo in 3:
			fx.reset(); attack(fx,weapon,combo); fx.advance(.065)
			stages[hash(await pixels(viewport,fx))]=true
		check(stages.size()==3,"Campaign weapon %d has three different combo stages" % weapon)
	var routes := {}
	for route in 4:
		fx.reset(); attack(fx,600,1,route); fx.advance(.065)
		var found := false
		for effect in fx.effects:
			if effect.kind=="route": found=effect.route==route and effect.has("socket_local")
		check(found,"Derived combo %d reaches presentation" % route)
		routes[hash(await pixels(viewport,fx))]=true
	check(routes.size()==4,"All four derived routes render different silhouettes")
	# Delayed decorations must stay at the release location through recovery.
	fx.reset(); attack(fx,600,2,2); fx.advance(.09)
	var before: PackedByteArray=await pixels(viewport,fx)
	socket.tip=Vector2(65,60); socket.aim=Vector2.UP
	check(before==await pixels(viewport,fx),"Combo echoes and route decorations remain fixed after release")
	for hero in 4:
		var hero_stages := {}
		for route in 4:
			fx.reset()
			fx.event({"kind":"hero_combo","p":Vector2(150,150),"aim":Vector2.RIGHT,"id":1,"weapon_index":600,"hero_route":route},hero)
			check(fx.effects[0].kind=="hero_combo" and fx.effects[0].identity.motif==["blood","frost","feather","soul"][hero],"Confirmed hero combo has its character motif")
			fx.advance(.065)
			hero_stages[hash(await pixels(viewport,fx))]=true
		check(hero_stages.size()==4,"Each hero's four combo finishes render differently")
	socket.tip=Vector2(220,150); socket.aim=Vector2.RIGHT
	fx.reset()
	fx.event({"kind":"windup","p":Vector2(150,150),"aim":Vector2.RIGHT,"id":1,"weapon_index":636,"weapon":3,"windup":.5},0)
	check(fx.particles.emitters.has("charge:1"),"Replacing a charge does not cancel its new gather emitter")
	fx.advance(.08)
	var charge: PackedByteArray=await pixels(viewport,fx)
	socket.tip+=Vector2(30,0)
	check(charge!=await pixels(viewport,fx),"Charge geometry follows the live weapon focus")
	attack(fx,636,0)
	check(not fx.effects.any(func(effect): return effect.kind=="charge"),"Strike clears the previous charge immediately")
	fx.reset()
	fx.event({"kind":"dodge","p":Vector2(150,150),"aim":Vector2.RIGHT,"weapon_index":600},0)
	fx.advance(.065)
	await pixels(viewport,fx)
	check(viewport.get_texture().get_image().get_used_rect().has_area(),"Run weapon does not hide the character dodge effect")
	fx.reset()
	for i in 180: attack(fx,600+i%48,2,i%4)
	check(fx.effects.size()<=fx.MAX_EFFECTS and fx.shards.size()<=fx.MAX_SHARDS,"Combo effects stay bounded")
	fx.advance(2)
	check(fx.effects.is_empty() and fx.particles.particles.is_empty(),"Combo effects expire completely")
	fx.queue_free(); viewport.queue_free(); await process_frame
	print("WEAPON VFX IDENTITY ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
