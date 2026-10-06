extends SceneTree
const Build=preload("res://scripts/rogue_build.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var s := TideSession.new(); root.add_child(s)
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729)
	s.set_physics_process(false); s.enemies.clear()
	var p: Dictionary=s.players[1]
	s.roguelike.equip(s,p,Build.Content.make_weapon(0,4))
	p.build_forge_bound=str(p.equipped.weapon.instance_id)
	p.build_core="WC002"; p.build_temper="dexterity"
	for level in 6:
		p.build_forge_level=level
		var state := Build.visual_state(p)
		check(state.forge==level,"Only the actually bound forge level is exposed")
		check(state.quality==4 and is_equal_approx(state.quality_factor,1.32),"Run rarity uses its actual 1.32 damage multiplier")
		check(state.core_rank==(0 if level<2 else 1 if level<4 else 2),"Core tier follows actual +2 and +4 unlocks")
		check((state.temper!="")== (level>=3),"Tempering starts at +3")
	p.build_forge_level=5; p.build_forge_bound="other-instance"
	check(Build.visual_state(p).forge==0 and Build.visual_state(p).core_rank==0,"An unbound weapon cannot borrow another item's upgrades")
	p.build_forge_bound=str(p.equipped.weapon.instance_id)
	p.build_core="WC006"
	check(Build.visual_state(p).core_rank==0,"A mismatched-family core is not presented as active")
	p.build_core="WC002"; p.build_forge_level=4
	var received: Array=[]
	s.combat_event.connect(func(data): received.append(data.duplicate(true)))
	var ctx := Build.context(s,p,"attack")
	ctx.combo=2
	var captured: Dictionary=ctx.vfx.duplicate(true)
	s.spawn_enemy(p.p+Vector2(45,0),0)
	var enemy: Dictionary=s.enemies.back(); enemy.hp=9999; enemy.max_hp=9999
	Build.hit_event(s,p,enemy,40,false,ctx)
	check(received.any(func(data): return data.kind=="weapon_core" and data.core_id==2 and data.core_rank==2),"Third-hit bleeding core plays only after a confirmed eligible hit")
	var before := received.filter(func(data): return data.kind=="weapon_core").size()
	Build.hit_event(s,p,enemy,40,false,ctx)
	check(received.filter(func(data): return data.kind=="weapon_core").size()==before,"Same root hit does not duplicate the core effect")
	s.roguelike.equip(s,p,Build.Content.make_weapon(38,0))
	check(ctx.vfx==captured,"Existing projectiles keep the pre-swap forge/core/rarity snapshot")
	s.damage_enemy(enemy,1,1,Vector2.RIGHT,0,1,600,ctx)
	check(received.back().kind=="impact" and received.back().vfx==captured and received.back().weapon_index==600,"Delayed impact uses its original weapon and original progression")
	p.hero=0; p.build_hero_cd=0; p.build_forge_level=2
	p.build_forge_bound=str(p.equipped.weapon.instance_id)
	var hero_ctx := Build.context(s,p,"attack"); hero_ctx.hero_route=0
	before=received.size(); Build.hero_effect(s,p,enemy,hero_ctx)
	check(received.size()==before,"Hero combo art cannot appear before +3")
	p.build_forge_level=3; hero_ctx=Build.context(s,p,"attack"); hero_ctx.hero_route=0
	Build.hero_effect(s,p,enemy,hero_ctx)
	check(received.any(func(data): return data.kind=="hero_combo" and int(data.vfx.forge)==3),"Hero combo art reflects the actual +3 unlock")
	s.queue_free(); await process_frame; await process_frame
	print("WEAPON VFX PROGRESSION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
