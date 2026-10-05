extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var frames := CharacterFrames.new()
	var preview := Image.create(880,1440,false,Image.FORMAT_RGBA8)
	preview.fill(Color("232430"))
	for hero in 4:
		for weapon in [16,0]:
			var first := frames.ranged_frame(hero,weapon,0)
			var row := hero*2+(1 if weapon==0 else 0)
			for frame in 4:
				var pose := frames.ranged_frame(hero,weapon,frame)
				var texture: AtlasTexture=pose.texture
				var scale: Vector2=pose.rect.size/texture.get_size()
				check(is_equal_approx(scale.x,scale.y),"No stretched sprite")
				check(pose.rect==first.rect,"One canvas and scale for each action")
				check((pose.rect.position+Vector2(pose.landmark.x,pose.landmark.y)*scale).is_equal_approx(CharacterMetrics.FOOT_OFFSET),"Registered feet remain grounded")
				check(is_equal_approx(pose.standing_height,frames.walk_height(hero)),"Body scale matches existing movement")
				var image := texture.get_image()
				check(image.get_pixel(0,0).a==0,"Real transparent padding")
				var used := image.get_used_rect()
				check(used.position.x>=19 and used.position.y>=19 and image.get_width()-used.end.x>=19 and image.get_height()-used.end.y>=19,"Complete isolated frames have safe padding")
				var draw_size := Vector2i(pose.rect.size*1.4)
				image.resize(draw_size.x,draw_size.y,Image.INTERPOLATE_LANCZOS)
				var at := Vector2i(frame*220+110,row*180+155)+Vector2i((pose.rect.position-CharacterMetrics.FOOT_OFFSET)*1.4)
				preview.blend_rect(image,Rect2i(Vector2i.ZERO,draw_size),at)
			var p := {"hero":hero,"weapon":weapon,"swing_total":Catalog.weapon(weapon).rate,"swing_time":Catalog.weapon(weapon).rate,"cast_time":0.0}
			check(CharacterFrames.ranged_pose_frame(p)==(1 if weapon==16 else 2),"Bow draws before release; zero-windup rifle fires immediately")
			p.swing_time=p.swing_total-Catalog.weapon(weapon).windup
			check(CharacterFrames.ranged_pose_frame(p)==2,"Release pose agrees with damage time")
			check(frames.equipped_attack_frame(p).texture.atlas.resource_path.contains("ranged-imagegen"),"Ranged attack never uses a sword sheet")
			check(frames.ranged_weapon_tip(p).x>0 and frames.ranged_weapon_tip(p).y<0,"Muzzle / bow release socket faces forward above ground")
			p.swing_time=.01
			check(CharacterFrames.ranged_pose_frame(p)==3,"Recovery follows release")
			p.swing_time=0
			check(CharacterFrames.ranged_pose_frame(p)==0,"Completed action returns to guard")
		for weapon in [624,625]:
			var p := {"hero":hero,"weapon":weapon,"swing_total":.6,"swing_time":.5,"cast_time":0.0,"build_strike_windup":.3}
			check(CharacterFrames.ranged_pose_frame(p)==1,"Build-specific windup controls aiming")
			p.swing_time=.3
			check(CharacterFrames.ranged_pose_frame(p)==2,"Build release timing controls impact")
			p.build_pending_art={"remaining":.1}
			check(CharacterFrames.ranged_pose_frame(p)==1,"Pending weapon art keeps aiming")
			p.erase("build_pending_art")
			check(frames.equipped_attack_frame(p).texture.atlas.resource_path.contains("/bow/" if weapon==625 else "/rifle/"),"Rogue equipment chooses its own ranged animation")
	DirAccess.make_dir_recursive_absolute("res://output/ranged-animation")
	preview.save_png("res://output/ranged-animation/contact.png")
	print("RANGED ANIMATIONS: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
