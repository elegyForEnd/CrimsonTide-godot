class_name CharacterFrames
extends RefCounted
## Atlas regions are clipped independently; padding belongs to the source art.
var attacks: Array = []
var movement: Array = []
const USE_GENERATED_HERO_ANIMATIONS := false
var generated: GeneratedAttacks
var animation_preview: GeneratedAttacks
var walk_heights: Dictionary = {}
# The 3D experiment is retained on disk; the game uses the previous sprite art.
const USE_FEIYUE_3D := false
var feiyue: GeneratedAttacks
var feiyue_idle: Dictionary = {}
var generated_idle = preload("res://scripts/character_idle_frames.gd").new()
var rogue_jump = preload("res://scripts/rogue_jump_frames.gd").new()
var ranged := GeneratedAttacks.new("res://assets/combat/ranged-imagegen/manifest.json")
var ranged_poses: Dictionary = {}

func _init() -> void:
	if USE_GENERATED_HERO_ANIMATIONS:
		generated=GeneratedAttacks.new()
		animation_preview=GeneratedAttacks.new("res://assets/combat/hero-animation-preview/manifest.json")
	# One atlas pair per hero in the catalog, so recruiting a fourth hero is a
	# catalog entry plus two PNGs rather than a code change here.
	for hero in Catalog.HEROES.size():
		attacks.append(read_sheet("res://assets/combat/attack-clean-%d.png" % hero,CharacterMetrics.ATTACK[hero]))
		movement.append(read_sheet("res://assets/combat/movement-%d.png" % hero,CharacterMetrics.MOVEMENT[hero]))
		if not USE_GENERATED_HERO_ANIMATIONS: continue
		for row in 3:
			var replacement := generated.frames("heroes/hero-%d/%s" % [hero,["sword","heavy","staff"][row]])
			if not replacement.is_empty():
				match_walk_size(hero,replacement)
				attacks[hero][row]=replacement
		# Cache the original gameplay height before replacing locomotion art.
		walk_height(hero)
		for row in 3:
			var attack_key := "heroes/hero-%d/%s" % [hero,["sword","heavy","staff"][row]]
			var replacement := animation_preview.frames(attack_key)
			if not replacement.is_empty():
				match_walk_size(hero,replacement)
				attacks[hero][row]=replacement
			var motion_key := "heroes/hero-%d/%s" % [hero,["walk","run","dodge"][row]]
			replacement=animation_preview.frames(motion_key)
			if not replacement.is_empty():
				match_walk_size(hero,replacement)
				movement[hero][row]=replacement
	if USE_FEIYUE_3D:
		feiyue=GeneratedAttacks.new("res://assets/combat/feiyue-3d/manifest.json")
		# Cache the established gameplay height before replacing the walking art.
		walk_height(0)
		for row in 3:
			var action: String=["sword","heavy","staff"][row]
			var poses := feiyue.frames("heroes/hero-0/"+action)
			if not poses.is_empty():
				match_walk_size(0,poses)
				attacks[0][row]=poses
			poses=feiyue.frames("heroes/hero-0/"+["walk","run","dodge"][row])
			if not poses.is_empty():
				match_walk_size(0,poses)
				movement[0][row]=poses
		for weapon in 4:
			var action: String=["idle","idle_sword","idle_heavy","idle_staff"][weapon]
			var poses := feiyue.frames("heroes/hero-0/"+action)
			if not poses.is_empty():
				match_walk_size(0,poses)
				feiyue_idle[weapon]=poses

func walk_height(hero: int) -> float:
	if walk_heights.has(hero): return walk_heights[hero]
	var height := 0.0
	for pose in movement[hero][0]:
		var texture: Texture2D=pose.texture
		var rect: Rect2=pose.rect
		var source := texture.get_image()
		var mark: Vector3=pose.landmark
		var center: float=mark.x-texture.region.position.x
		var foot: float=mark.y-texture.region.position.y
		var run := 0
		var longest := 0
		# Ignore faint edge pixels and fragments from neighboring atlas rows.
		# The main continuous body occupies the central head/torso/foot strip.
		for y in mini(int(foot),source.get_height()):
			var occupied := 0
			for x in range(maxi(0,int(center-mark.z*0.8)),mini(source.get_width(),int(center+mark.z*0.8))):
				if source.get_pixel(x,y).a>0.5: occupied+=1
			run=run+1 if occupied>=3 else 0
			longest=maxi(longest,run)
		height+=longest*rect.size.y/texture.get_height()
	walk_heights[hero]=height/float(movement[hero][0].size())
	return walk_heights[hero]

func match_walk_size(hero: int, poses: Array) -> void:
	# Opening crown-to-sole height is recorded independently of raised weapons.
	# Apply one factor to all frames around the ground pivot, never per-pose bounds.
	var target := walk_height(hero)
	var factor: float=target/float(poses[0].get("standing_height",90.0))
	for pose in poses:
		var rect: Rect2=pose.rect
		pose.rect=Rect2(CharacterMetrics.FOOT_OFFSET+(rect.position-CharacterMetrics.FOOT_OFFSET)*factor,rect.size*factor)
		var landmark: Vector3=pose.landmark
		landmark.z/=factor
		pose.landmark=landmark
		pose.standing_height=target

func read_sheet(path: String, landmarks: Array) -> Array:
	var sheet: Texture2D=load(path)
	var cell := Vector2i(sheet.get_size()/Vector2(4,3))
	var source := sheet.get_image()
	var rows: Array=[]
	# Generated sheets are not mathematically perfect grids. Locate real empty
	# gutters so a boot or weapon near the nominal boundary stays in its frame.
	var ys := [0,find_gutter(source,cell.y,cell.y,true,0,source.get_width()),find_gutter(source,cell.y*2,cell.y,true,0,source.get_width()),source.get_height()]
	for row in 3:
		var frames: Array=[]
		var xs := [0,find_gutter(source,cell.x,cell.x,false,ys[row],ys[row+1]),find_gutter(source,cell.x*2,cell.x,false,ys[row],ys[row+1]),find_gutter(source,cell.x*3,cell.x,false,ys[row],ys[row+1]),source.get_width()]
		var bounds: Array[Rect2i]=[]
		for column in 4:
			var region := Rect2i(xs[column],ys[row],xs[column+1]-xs[column],ys[row+1]-ys[row])
			bounds.append(region)
		for column in 4:
			var texture := AtlasTexture.new()
			texture.atlas=sheet
			texture.region=Rect2(bounds[column])
			texture.filter_clip=true
			var landmark: Vector3=landmarks[row][column]
			frames.append({"texture":texture,"rect":CharacterMetrics.layout(texture.region,sheet.get_size(),landmark),"landmark":landmark})
		rows.append(frames)
	return rows

func find_gutter(source: Image, expected: int, cell_size: int, horizontal: bool, start: int, end: int) -> int:
	var radius := int(cell_size*0.22)
	var best := expected
	var longest := 0
	var run := 0
	for axis in range(expected-radius,expected+radius):
		var occupied := false
		for cross_axis in range(start,end):
			var pixel := source.get_pixel(cross_axis,axis) if horizontal else source.get_pixel(axis,cross_axis)
			if pixel.a>0.08:
				occupied=true
				break
		run=0 if occupied else run+1
		if run>longest:
			longest=run
			best=axis-run/2
	return best

func attack_frame(hero: int, weapon: int, frame: int) -> Dictionary:
	var poses: Array=attacks[hero][clampi(weapon-1,0,2)]
	return poses[clampi(frame,0,poses.size()-1)]

## Blade endpoints audited on attack-clean sheets, in their 1448x1086 canvas.
## These belong to the upright sprite, not the ground-plane attack direction.
const BLADE_TIPS := [
	[[Vector2(70,319),Vector2(415,82),Vector2(1072,205),Vector2(1380,326)],
	 [Vector2(331,674),Vector2(714,545),Vector2(1076,678),Vector2(1395,673)]],
	[[Vector2(70,333),Vector2(507,55),Vector2(1096,304),Vector2(1395,319)],
	 [Vector2(55,681),Vector2(702,538),Vector2(1096,685),Vector2(1405,683)]],
	[[Vector2(333,326),Vector2(615,53),Vector2(1086,309),Vector2(1419,319)],
	 [Vector2(338,688),Vector2(434,420),Vector2(1086,695),Vector2(1426,695)]]
]

func blade_tip(hero: int, family: int, frame: int) -> Vector2:
	var pose := attack_frame(hero,family,frame)
	var mark: Vector3=pose.landmark
	return (BLADE_TIPS[hero][family-1][clampi(frame,0,3)]-Vector2(mark.x,mark.y))*CharacterMetrics.HEAD_PIXELS/mark.z

const STAFF_TIPS := [
	[Vector2(234,776),Vector2(627,751),Vector2(1050,874),Vector2(1325,812)],
	[Vector2(217,813),Vector2(462,739),Vector2(982,839),Vector2(1315,834)],
	[Vector2(266,848),Vector2(489,751),Vector2(995,809),Vector2(1298,852)]
]
# Muyu's current sprites wield a floating rune focus rather than a steel blade.
const RUNE_TIPS := [
	[Vector2(274,159),Vector2(688,97),Vector2(1025,185),Vector2(1410,86)],
	[Vector2(293,541),Vector2(677,470),Vector2(998,552),Vector2(1407,472)],
	[Vector2(314,838),Vector2(690,790),Vector2(1025,921),Vector2(1390,834)]
]

func weapon_tip(hero: int, family: int, frame: int) -> Vector2:
	frame=clampi(frame,0,3)
	family=maxi(1,family)
	if hero<3 and family in [1,2]: return blade_tip(hero,family,frame)
	var pose := attack_frame(hero,family,frame)
	var mark: Vector3=pose.landmark
	var point: Vector2=RUNE_TIPS[family-1][frame] if hero==3 else STAFF_TIPS[hero][frame]
	return (point-Vector2(mark.x,mark.y))*CharacterMetrics.HEAD_PIXELS/mark.z

static func attack_pose_frame(p: Dictionary) -> int:
	if float(p.get("swing_time",0))>0:
		var total: float=maxf(.001,p.swing_total)
		var progress := 1.0-float(p.swing_time)/total
		var windup: float=Catalog.weapon(p.weapon).windup/total
		return 1 if progress<windup else 2 if progress<windup+.23 else 3
	if float(p.get("cast_time",0))>0:
		return 1 if p.cast_time>.55 else 2 if p.cast_time>.2 else 3
	return 0

func ranged_hand_tip(hero: int) -> Vector2:
	# The campaign's family-zero art is sentinels.png, anchored by its hands.
	# Hero 1's lowered rifle muzzle is the endpoint at x=620,y=562 in that sheet.
	return [Vector2(20,-43),Vector2(-29,-28),Vector2(-28,-5),Vector2(24,-42)][hero]

func has_generated(hero: int, weapon: int) -> bool:
	return weapon>0 and attacks[hero][clampi(weapon-1,0,2)].size()==8

func motion_frame(hero: int, mode: String, phase: float, dodge_time: float) -> Dictionary:
	if mode=="idle":
		return idle_frame(hero,0,phase*2.0)
	var row := 2 if mode=="dodge" else 1 if mode=="run" else 0
	var count: int=movement[hero][row].size()
	# Phase was authored for four poses: preserve cycle cadence with eight poses.
	var frame := clampi(int((1.0-dodge_time/TideSession.DODGE_DURATION)*count),0,count-1) if row==2 else posmod(int(phase*count/4.0),count)
	return movement[hero][row][frame]

func jump_frame(hero: int, velocity: float, height: float = 50.0, landing_time: float = 0.0) -> Dictionary:
	return rogue_jump.frame(hero,walk_height(hero),velocity,height,landing_time)

func has_rendered_hero(hero: int) -> bool:
	return hero==0 and feiyue_idle.has(0)

func idle_frame(hero: int, weapon: int, phase: float) -> Dictionary:
	if has_rendered_hero(hero):
		var poses: Array=feiyue_idle[clampi(weapon,0,3)]
		return poses[posmod(int(phase),poses.size())]
	return attack_frame(hero,maxi(1,weapon),0)

func held_idle_frame(hero: int, weapon: int, seconds: float = 0.0) -> Dictionary:
	var pose: Dictionary=generated_idle.frame(hero,weapon,walk_height(hero),seconds)
	# The idle library has separate bow, rifle and empty-hand run-weapon clips.
	if not pose.is_empty(): return pose
	if Catalog.weapon_family(weapon)==0: return ranged_frame(hero,weapon,0)
	return idle_frame(hero,Catalog.weapon_family(weapon),0.0)

func ranged_frame(hero: int, weapon: int, frame: int) -> Dictionary:
	var action := "bow" if str(Catalog.weapon(weapon).get("spell",""))=="arrow" else "rifle"
	var key := "heroes/hero-%d/%s" % [hero,action]
	if not ranged_poses.has(key):
		var poses := ranged.frames(key)
		match_walk_size(hero,poses)
		ranged_poses[key]=poses
	return ranged_poses[key][clampi(frame,0,3)]

static func ranged_pose_frame(p: Dictionary) -> int:
	if float(p.get("swing_time",0))<=0 and float(p.get("cast_time",0))<=0: return 0
	if float(p.get("swing_time",0))<=0: return 1 if float(p.get("cast_time",0))>.2 else 2
	var total := maxf(.001,float(p.get("swing_total",.23)))
	var elapsed := total-float(p.get("swing_time",0))
	var hit := float(p.get("build_strike_windup",Catalog.weapon(int(p.weapon)).windup))
	if p.has("build_pending_art"): hit=elapsed+float(p.build_pending_art.remaining)
	if elapsed+.00001<hit: return 1
	return 2 if elapsed-hit<minf(.10,maxf(.001,total-hit)*.45) else 3

func equipped_attack_frame(p: Dictionary) -> Dictionary:
	if Catalog.weapon_family(int(p.weapon))==0:
		return ranged_frame(int(p.hero),int(p.weapon),ranged_pose_frame(p))
	return attack_frame(int(p.hero),maxi(1,Catalog.weapon_family(int(p.weapon))),attack_pose_frame(p))

const BOW_SOCKETS := [
	[Vector2(290,146),Vector2(653,145),Vector2(993,154),Vector2(1344,196)],
	[Vector2(289,421),Vector2(669,404),Vector2(1035,412),Vector2(1366,462)],
	[Vector2(291,689),Vector2(680,677),Vector2(1038,680),Vector2(1380,720)],
	[Vector2(303,946),Vector2(680,902),Vector2(1061,915),Vector2(1380,948)]
]
const RIFLE_SOCKETS := [
	[Vector2(302,222),Vector2(694,114),Vector2(1038,104),Vector2(1404,236)],
	[Vector2(300,480),Vector2(699,356),Vector2(1053,354),Vector2(1403,480)],
	[Vector2(305,740),Vector2(703,630),Vector2(1055,624),Vector2(1409,740)],
	[Vector2(316,986),Vector2(695,871),Vector2(1052,867),Vector2(1397,991)]
]

func ranged_weapon_tip(p: Dictionary) -> Vector2:
	var frame := ranged_pose_frame(p)
	var action := "bow" if str(Catalog.weapon(int(p.weapon)).get("spell",""))=="arrow" else "rifle"
	var pose := ranged_frame(int(p.hero),int(p.weapon),frame)
	var spec: Dictionary=ranged.manifest["heroes/hero-%d/%s" % [p.hero,action]]
	var point: Vector2=(BOW_SOCKETS if action=="bow" else RIFLE_SOCKETS)[int(p.hero)][frame]
	if spec.has("source_sockets"): point=Vector2(spec.source_sockets[frame][0],spec.source_sockets[frame][1])
	var cell := Vector2(spec.source_origins[frame][0],spec.source_origins[frame][1])
	var anchor := Vector2(spec.source_anchors[frame][0],spec.source_anchors[frame][1])
	return (point-cell-anchor)*pose.rect.size.y/pose.texture.get_height()
