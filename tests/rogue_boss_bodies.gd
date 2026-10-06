extends SceneTree
## 守层者身体立绘按「身份」取帧（R14 池扩容的收尾验收）。
##
## 池会从 8 个身份里抽 5 个，但立绘原先按楼层取帧，抽到新身份时会回落成该层
## 原守层者的身体。本用例锁死三件事：每个身份都用自己的图集、只知楼层的调用方
## 仍回落到楼层图集、施法姿态也走身份自己的招式图集。

const RogueArt = preload("res://scripts/rogue_art.gd")
const BossArt = preload("res://scripts/boss_effect_art.gd")
const Body = preload("res://scripts/enemy_body.gd")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("ERROR: ",message)

func sheet(pose: Dictionary) -> String:
	var texture: Texture2D=pose.get("texture")
	if texture==null or texture.atlas==null: return ""
	return texture.atlas.resource_path.get_file()

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var art=RogueArt.new()
	for identity in BossArt.ROGUE.size():
		for frame in 48:
			var drawn := sheet(art.boss_animation(identity,frame,0))
			check(drawn.begins_with("boss-hd-%d" % identity),
				"identity %d frame %d draws its own sheet (got '%s')" % [identity,frame,drawn])
	check(sheet(art.boss_animation(2,0)).begins_with("boss-hd-2"),
		"a caller that only knows the floor keeps the floor sheet")
	check(sheet(art.boss_animation(99,0,3)).begins_with("boss-hd-3"),
		"an unknown identity falls back to the supplied floor")
	var last: int = BossArt.ROGUE.size()-1
	var body=Body.new()
	var pooled := {"rogue_guardian":true,"rogue_skin":0,"boss_art":last,"id":1,"moving":false,"attack_time":0.0}
	check(sheet(body.pose(pooled,0.0,true)).begins_with("boss-hd-%d" % last),
		"the live guardian body follows boss_art, not the floor")
	var no_pool := {"rogue_guardian":true,"rogue_skin":4,"id":1,"moving":false,"attack_time":0.0}
	check(sheet(body.pose(no_pool,0.0,true)).begins_with("boss-hd-4"),
		"a guardian without boss_art still follows its floor")
	var casting := {"rogue_guardian":true,"rogue_skin":0,"boss_art":5,"id":1,"moving":false,
		"attack_time":0.4,"attack_total":1.0,"boss_skill":3,"boss_windup":0.55}
	check(sheet(body.pose(casting,0.0,true)).begins_with("boss-hd-5-skill-3"),
		"a pooled guardian casts with its own skill sheet")
	print("ROGUE BOSS BODIES %d checks / %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
