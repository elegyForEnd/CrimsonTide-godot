extends SceneTree
## Production fields, real attacks, temporary test state. No campaign/profile writes.
var app
var mode := -1
var tick := 0.0
var sequence := 0
var hero := 0
var hint: Label
var elapsed := 0.0
var target: Dictionary={}
const WEAPONS := [600,638,612,625,637,646,614,619,624,603,639]
var captures := false
var capture_clock := -1.0
var shot_count := 0
var failed := false
class Keys extends Node:
	var receive: Callable
	func _input(e: InputEvent) -> void:
		if receive.is_valid(): receive.call(e)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900); root.content_scale_size=root.size
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.profile.path="user://combat-finish-preview-profile.json"
	app.set_process_unhandled_input(false); app.set_process_input(false)
	app.set_process(false)
	var keys := Keys.new(); keys.receive=_input; root.add_child(keys)
	var canvas := CanvasLayer.new(); canvas.layer=30; root.add_child(canvas)
	hint=Label.new(); hint.position=Vector2(280,790); hint.size=Vector2(1000,70)
	hint.add_theme_font_override("font",load("res://assets/NotoSansSC.ttf"))
	hint.add_theme_font_size_override("font_size",19)
	hint.add_theme_color_override("font_shadow_color",Color.BLACK); hint.add_theme_constant_override("shadow_outline_size",6)
	canvas.add_child(hint)
	captures="--capture-vfx" in OS.get_cmdline_user_args()
	change_mode(0)
func change_mode(value: int) -> void:
	if mode==value: return
	app.show_title(); app.session.running=false
	mode=value; sequence=0; tick=0; elapsed=0; shot_count=0; capture_clock=-1
	if mode==0:
		app.go_story("user://combat-finish-preview-story.json")
		var c=app.story_screen.campaign; c.save_enabled=false
		c.state=c.new_state(); c.enter(1,1)
		app.story_screen.set_physics_process(false); app.story_screen.set_process_unhandled_input(false)
		c.hero_at=Vector2(1250,2580); c.allies=[c.hero_at,c.hero_at+Vector2(-80,-65),c.hero_at+Vector2(80,-65)]
		c.enemies.clear()
		target={"id":"vfx-preview","p":c.hero_at+Vector2(165,50),"hp":9999999.0,"maxhp":9999999.0,"flash":0.0,"boss":false,"type":0,"windup":0.0,"shape":"circle","radius":100,"target":Vector2.ZERO}
		c.enemies.append(target)
	else:
		app.session.solo({"hero":0,"mode":"roguelike" if mode==1 else "expedition"})
		app.session.launch(false,20261011); app.session.set_physics_process(false)
		var first: Dictionary=app.session.enemies[0].duplicate(true) if not app.session.enemies.is_empty() else {}
		app.session.enemies.clear(); app.session.bullets.clear()
		var p: Dictionary=app.session.players[1]
		p.aim=Vector2.RIGHT; p.strike_aim=Vector2.RIGHT; p.height=0
		if mode==1:
			p.p=Vector2(720,575); app.rogue_field.camera_x=0; app.rogue_field.camera_y=0
		var e: Dictionary=first
		e.p=p.p+Vector2(135,0); e.hp=9999999.0; e.max_hp=9999999.0
		target=e; app.session.enemies=[target]
		app.session.raid.phase="rogue_combat" if mode==1 else "border"
		app.close_modal(); app.overlay.hide(); app.modal=false; paused=false
	if hint: update_hint()
func update_hint() -> void:
	var identity: String=["赤晶剑 / 晨星霜术 / 夜鸦曲刃","11 种武器与真实战技","11 种武器与真实战技"][mode]
	hint.text="特效实景预览 · "+["故事原野","魔境闯关","三日远征"][mode]+" · "+identity+"\n1 故事  /  2 闯关  /  3 搜打撤  ·  自动轮播攻击与技能  ·  ESC 关闭  ·  临时数据不保存"
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE: quit()
		if event.keycode in [KEY_1,KEY_2,KEY_3]: change_mode(event.keycode-KEY_1)
func fire() -> void:
	if mode==0:
		var c=app.story_screen.campaign
		hero=(sequence/3)%3; c.switch_hero(hero)
		c.attack_cd=0; c.skill_cd=0; c.ultimate_cd=0
		c.attack((Vector2(target.p)-c.hero_at).normalized(),sequence%3)
	else:
		var s=app.session; var p: Dictionary=s.players[1]
		var weapon: int=WEAPONS[(sequence/2)%WEAPONS.size()]
		p.weapon=weapon; p.combo=2 if sequence%2 else 0
		p.swing_time=.22; p.swing_total=.45; p.cast_time=0; p.strike_aim=Vector2.RIGHT; p.aim=Vector2.RIGHT
		p.build_strike_context=preload("res://scripts/rogue_build.gd").context(s,p,"attack" if sequence%2==0 else "art") if mode==1 else {}
		s.bullets.clear()
		if sequence%2==0:
			if mode==1: preload("res://scripts/rogue_actions.gd").normal(s,p)
			else: s.release_strike(p)
		else:
			var move := WeaponArts.of(weapon)
			p.swing_time=0; p.attack=0; p.art_cd=0; p.mana=999
			if mode==1: preload("res://scripts/rogue_actions.gd").resolve_art(s,p,{"move":move,"ctx":p.build_strike_context,"aim":Vector2.RIGHT,"damage":10.0},1.0)
			else: s.release_weapon_art(p)
		# Actual damage_enemy path supplies a real contact, not a staged visual event.
		s.damage_enemy(target,15,1,Vector2.RIGHT,0,0,-1,p.build_strike_context)
		var field=app.rogue_field if mode==1 else app.field
		if field.combat.finish.contacts.is_empty(): failed=true; push_error("No contact in actual mode "+str(mode))
	sequence+=1
func _process(dt: float) -> bool:
	if app==null or mode<0: return false
	elapsed+=dt; tick+=dt
	if tick>1.3:
		tick=0; fire(); capture_clock=0
	if mode>0:
		for bullet in app.session.bullets:
			bullet.p+=bullet.v*dt; bullet.life-=dt
		app.session.bullets=app.session.bullets.filter(func(b): return b.life>0)
	else: app.story_screen.campaign.attack_time=maxf(0,app.story_screen.campaign.attack_time-dt)
	if capture_clock>=0:
		capture_clock+=dt
		if captures and capture_clock>.07:
			capture_clock=-1
			RenderingServer.force_draw(false)
			var path := "res://build/combat-finish-%s-%02d.png" % [["story","rogue","expedition"][mode],shot_count]
			root.get_texture().get_image().save_png(path)
			shot_count+=1
			if shot_count>= (9 if mode==0 else 14):
				if mode<2: change_mode(mode+1)
				else:
					print("COMBAT FINISH VISUAL 37 real-scene captures, failures=",int(failed)); app.queue_free(); quit(1 if failed else 0)
	return false
