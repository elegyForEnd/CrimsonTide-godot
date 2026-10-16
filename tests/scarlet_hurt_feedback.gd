extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=preload("res://scripts/scarlet/campaign.gd").new()
	c.state=c.new_state(); c.save_enabled=false; c.inventory.initialize(); c.hero_at=c.spawn_at()
	var view=preload("res://scripts/scarlet/render_campaign.gd").new(c)
	check(c.dodge(Vector2.RIGHT),"dodge begins")
	check(c.invulnerable>0 and view.hurt_time==0,"dodge immunity does not tint hero red")
	c.take_damage(30,"physical",.65)
	check(view.hurt_time>0,"actual damage enables hurt tint")
	for i in 4: c.update(.05,Vector2.ZERO)
	check(view.hurt_time==0 and c.invulnerable>0,"hurt tint expires independently of immunity")
	c.equipment_combat.barrier=100
	var before: float=c.state.hp
	c.take_damage(20,"physical",.65)
	check(c.state.hp==before and view.hurt_time==0,"fully absorbed hit does not tint hero red")
	c.hurt_time=.18; c.combat.retry()
	check(c.hurt_time==0 and c.invulnerable>0,"retry protection does not tint hero red")
	print("SCARLET_HURT_FEEDBACK %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
