extends SceneTree
## Readability contract for enemy projectiles, checked without booting the game.
##
## The art constants are assertions, not decoration: if any of them drifts back
## toward an invisible bolt, this fails.  Nothing here touches damage, speed,
## counts or the 18px sweep - it only measures what the eye is shown.
const Visuals=preload("res://scripts/combat_visuals.gd")
const Staging=preload("res://scripts/boss_effect_staging.gd")
const Semantics=preload("res://scripts/effect_semantics.gd")
const ShapeShader=preload("res://resources/boss_damage_shape.gdshader")
const BirthShader=preload("res://resources/boss_entity_birth.gdshader")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL ",label)
	else:
		print("ok   ",label)
func run() -> void:
	# --- ordinary enemy bolts -------------------------------------------------
	var box := Vector2(65,34)
	var old_size := box
	var bolt_size := box*Visuals.ENEMY_BOLT_SCALE
	check(Visuals.ENEMY_BOLT_SCALE>=1.6 and Visuals.ENEMY_BOLT_SCALE<=1.8,
		"enemy bolt scale stays inside the requested 1.6-1.8 band (%.2f)" % Visuals.ENEMY_BOLT_SCALE)
	check(bolt_size.x>old_size.x and bolt_size.y>old_size.y,
		"drawn box grows in both axes (%.0fx%.0f -> %.0fx%.0f)" % [old_size.x,old_size.y,bolt_size.x,bolt_size.y])
	print("     drawn extent ratio %.2f x %.2f" % [bolt_size.x/old_size.x,bolt_size.y/old_size.y])
	# The source silhouette inside common_2, measured with tools/measure_alpha_bbox.py:
	# 1024x1024 native, 412x800 ink, 391x419 bright core.  fitted_size() is 1:1
	# here (square art in a square-ish box), so the visible core is the measured
	# fraction of the drawn box.
	var native := 1024.0
	var core := Vector2(391.0,419.0)/native*bolt_size
	print("     visible core at scale %.2f: %.1fx%.1f px (hit diameter %.1f)" % [
		Visuals.ENEMY_BOLT_SCALE,core.x,core.y,18.0*2.0])
	check(minf(core.x,core.y)>=18.0,"visible bolt core covers the 18px hit radius across its narrow axis")
	check(minf(core.x,core.y)<=18.0*2.4,"visible core does not oversell the hit circle")
	check(Visuals.ENEMY_BOLT_TRAIL>=1 and Visuals.ENEMY_BOLT_TRAIL<=3,"short trail is one to three segments")
	var tint := Visuals.ENEMY_BOLT_TINT
	check(maxf(tint.r,maxf(tint.g,tint.b))-minf(tint.r,minf(tint.g,tint.b))>0.35,
		"bolt tint is a saturated danger colour, not a pastel (%s)" % tint)
	check(tint.a==1.0,"bolt tint is drawn at full alpha, never a small coefficient")
	# --- the layer that answers to the hit circle -----------------------------
	# Exactly one layer is the size of the damage circle; everything else is
	# either inside it or a deliberately faint shell outside it.
	var hit := Visuals.ENEMY_BOLT_HIT_RADIUS
	check(is_equal_approx(hit,18.0),"the core layer still uses the same 18.0 default as session.gd")
	var halo_r := Visuals.bolt_extent()*0.5*Visuals.ENEMY_BOLT_HALO
	print("     layers: core disc d=%.1f | halo inner d=%.1f (a=%.2f) | halo outer d=%.1f (a=%.2f) | sprite box %.1f (a=%.2f)" % [
		hit*2.0, Visuals.bolt_extent()*Visuals.ENEMY_BOLT_HALO_INNER, Visuals.ENEMY_BOLT_HALO_INNER_ALPHA,
		halo_r*2.0, Visuals.ENEMY_BOLT_HALO_ALPHA, Visuals.bolt_extent(), Visuals.ENEMY_BOLT_BODY_ALPHA])
	check(halo_r*2.0<=hit*2.0*2.2,"no halo layer balloons past 2.2x the damage circle (got %.2fx)" % (halo_r*2.0/(hit*2.0)))
	check(Visuals.ENEMY_BOLT_HALO_ALPHA<=0.12,"the outer halo stays a whisper (%.2f)" % Visuals.ENEMY_BOLT_HALO_ALPHA)
	check(Visuals.ENEMY_BOLT_BODY_ALPHA<1.0 and Visuals.ENEMY_BOLT_BODY_ALPHA>0.3,
		"the sprite is a highlight over the solid core, not a replacement (%.2f)" % Visuals.ENEMY_BOLT_BODY_ALPHA)
	# --- the corrected causal record -----------------------------------------
	# HEAD's enemy branch called stamp(), which draws at full coverage; the only
	# Motion.coverage() site was - and remains - the player's own bullet.  The
	# enemy branch must therefore contain no coverage() call and no age field.
	var source := FileAccess.get_file_as_string("res://scripts/combat_visuals.gd")
	var body_start := source.find("func draw_enemy_bolt")
	var body_end := source.find("func _draw()")
	var bolt_body := source.substr(body_start,body_end-body_start)
	check(not bolt_body.contains("visual_age"),"the enemy bolt reads no per-bullet age field")
	check(not bolt_body.contains("coverage("),"the enemy bolt never slices its own sprite while it forms")
	check(bolt_body.contains("draw_circle(at,ENEMY_BOLT_HIT_RADIUS"),
		"the solid core disc is drawn from the hit radius, so the two cannot drift")
	check(not source.contains("stamp(2,"),"ordinary enemy bolts no longer use the old common_2 stamp")
	var stale := source.find("faded in only after")
	check(stale<0,"no stale 'fades in on contact' claim survives in the source")
	# --- bullet_visual: the deep-abyss variant factor -------------------------
	# Absent = 1.0 and pixel-identical; [1.0, 3.0] like RogueCombat; it grows the
	# drawn shell monotonically and never moves the hit radius.
	var neutral := Visuals.bolt_layers()
	var plain := Visuals.bolt_layers(Visuals.bolt_visual({}))
	print("     no key      -> sprite %.1f  halo_in %.1f  halo_out %.1f  core %.1f" % [
		neutral.sprite_box,neutral.halo_inner,neutral.halo_outer,neutral.core])
	check(is_equal_approx(neutral.sprite_box,plain.sprite_box) and is_equal_approx(neutral.halo_outer,plain.halo_outer),
		"a bolt with no bullet_visual draws exactly like one carrying 1.0")
	check(is_equal_approx(Visuals.bolt_visual({}),1.0),"the default factor is exactly 1.0")
	var tiers := [1.0,1.25,1.5]
	var widths: Array=[]
	for tier in tiers:
		var layers := Visuals.bolt_layers(Visuals.bolt_visual({"bullet_visual":tier}))
		widths.append(layers.halo_outer)
		print("     bullet_visual %.2f -> sprite %.1f  halo_in %.1f  halo_out %.1f  core %.1f  tail %.1f" % [
			tier,layers.sprite_box,layers.halo_inner,layers.halo_outer,layers.core,layers.trail_head])
		check(is_equal_approx(layers.core,18.0*2.0),
			"bullet_visual %.2f leaves the solid core at the hit circle's 36.0" % tier)
	check(widths[0]<widths[1] and widths[1]<widths[2],
		"the drawn envelope grows monotonically across 1.0 < 1.25 < 1.5")
	check(is_equal_approx(Visuals.bolt_visual({"bullet_visual":0.25}),1.0),
		"a hostile bolt can never be drawn smaller than 1.0")
	check(is_equal_approx(Visuals.bolt_visual({"bullet_visual":9.0}),3.0),
		"the factor is clamped to RogueCombat's upper bound of 3.0")
	# The mirror realm reads the same key with the same defaults.
	check(is_equal_approx(Semantics.visual_of({}),1.0),"mirror-realm bolts default to 1.0")
	check(is_equal_approx(Semantics.visual_of({"bullet_visual":1.25}),1.25)
		and is_equal_approx(Semantics.visual_of({"bullet_visual":9.0}),3.0),
		"mirror-realm bolts clamp the same way")
	# The boss staging path scales its sprite and only its sprite.
	var boss_base := {"shape":"capsule","p":Vector2.ZERO,"aim":Vector2.RIGHT,"radius":0.0,"inner":18.0,
		"fired":true,"time":-0.1,"linger":1.0,"art_key":"knight","vfx_role":"lance"}
	var plain_boss := Staging.pose(boss_base,0.2,0.1)
	var fog_boss := Staging.pose({"shape":"capsule","p":Vector2.ZERO,"aim":Vector2.RIGHT,"radius":0.0,"inner":18.0,
		"fired":true,"time":-0.1,"linger":1.0,"art_key":"knight","vfx_role":"lance","bullet_visual":1.25},0.2,0.1)
	check(is_equal_approx(plain_boss.size,45.0),"a boss bolt with no factor keeps its 2.5x sprite")
	check(fog_boss.size>plain_boss.size and is_equal_approx(fog_boss.size,45.0*1.25),
		"bullet_visual grows the staged boss sprite (%.1f -> %.1f)" % [plain_boss.size,fog_boss.size])
	# --- boss projectiles -----------------------------------------------------
	var hazard := {"shape":"capsule","p":Vector2.ZERO,"aim":Vector2.RIGHT,"radius":0.0,"inner":18.0,
		"fired":true,"time":-0.1,"linger":1.0,"art_key":"knight","vfx_role":"lance"}
	var pose := Staging.pose(hazard,0.2,0.1)
	check(pose.kind=="projectile","capsule hazard still births as a projectile")
	check(is_equal_approx(pose.size,45.0),"boss bolt sprite grows to 2.5x its 18px inner radius (%.1f)" % pose.size)
	var shader := ShapeShader.code
	check(shader.contains("halo_strength"),"boss footprint shader carries a halo parameter")
	check(shader.contains("float(sd>0.0)"),"halo is painted strictly outside the damage footprint")
	var birth := BirthShader.code
	check(birth.contains("rim_strength"),"boss sprite shader carries an outline parameter")
	# --- mirrored (rogue) shots -----------------------------------------------
	check(Semantics.SHOT_SCALE>=1.8,"mirror-realm vectors are scaled up (%.1f)" % Semantics.SHOT_SCALE)
	var scaled := Semantics.shot([Vector2(-19,1),Vector2(9,0)])
	check(scaled.size()==2 and is_equal_approx(scaled[0].x,-38.0),"mirror-realm vertex list scales uniformly")
	check(Semantics.SHOT_HALO>0.0,"mirror-realm shots draw a halo")
	print("ENEMY BOLT READABILITY ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
