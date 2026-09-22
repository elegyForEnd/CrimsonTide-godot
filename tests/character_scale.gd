extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var frames := CharacterFrames.new()
	for group in [frames.attacks,frames.movement]:
		for hero in group:
			for row in hero:
				for pose in row:
					var region: Rect2=pose.texture.region
					var rect: Rect2=pose.rect
					var mark: Vector3=pose.landmark
					var ratio := rect.size/region.size
					check(is_equal_approx(ratio.x,ratio.y),"Never squash or stretch a pose")
					check(absf(mark.z*ratio.y-26.0)<0.01,"Shared head size across all actions")
					var foot := rect.position+(Vector2(mark.x,mark.y)-region.position)*ratio
					check(foot.distance_to(Vector2(0,16))<0.01,"Frame uses the same ground origin")
	# Crop dimensions can change when gutters or transparent padding change.
	# The anatomical origin and scale must remain independent of those bounds.
	var mark := Vector3(200,330,80)
	for region in [Rect2(0,0,360,360),Rect2(20,40,310,305),Rect2(-25,-30,420,410)]:
		var rect := CharacterMetrics.layout(region,Vector2(1448,1086),mark)
		var ratio: Vector2=rect.size/region.size
		check((rect.position+(Vector2(200,330)-region.position)*ratio).distance_to(Vector2(0,16))<0.01,"Padding does not move the foot pivot")
		check(is_equal_approx(ratio.y,26.0/80.0),"Padding does not change body size")
	var full := CharacterMetrics.layout(Rect2(0,0,360,360),Vector2(1448,1086),mark)
	var doubled := CharacterMetrics.layout(Rect2(0,0,720,720),Vector2(2896,2172),mark)
	check(full.is_equal_approx(doubled),"Higher resolution art retains world-space dimensions")
	print("CHARACTER SCALE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
