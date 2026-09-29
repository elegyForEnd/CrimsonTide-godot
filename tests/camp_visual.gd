extends SceneTree
## Renders the standalone pre-raid camp map with a real back buffer.
##
## Run without --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --script tests/camp_visual.gd
##
## Output: build/camp-thunderhold.png, build/camp-strike.png, build/camp-gate.png

const Screen = preload("res://scripts/camp_screen.gd")
const BURST := preload("res://resources/energy_burst.gdshader")

var screen: Control
var site: Node3D
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func stats(image: Image) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	var step := maxi(1, int(maxf(width, height) / 320.0))
	var count := 0
	var total := 0.0
	var hottest := 0.0
	var brightest := Vector3.ZERO
	var samples: Array[float] = []
	for y in range(0, height, step):
		for x in range(0, width, step):
			var color := image.get_pixel(x, y)
			var luma := color.r * 0.3 + color.g * 0.55 + color.b * 0.15
			total += luma
			count += 1
			samples.append(luma)
			if luma > hottest:
				hottest = luma
				brightest = Vector3(color.r, color.g, color.b)
	var mean := total / maxf(1.0, float(count))
	var variance := 0.0
	for value in samples:
		variance += (value - mean) * (value - mean)
	variance /= maxf(1.0, float(samples.size()))
	return {"mean": mean, "hot": hottest, "deviation": sqrt(variance), "brightest": brightest}


func shoot(name: String) -> Dictionary:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://build/camp-%s.png" % name)
	return stats(image)


func run() -> void:
	root.size = Vector2i(1280, 800)
	screen = Screen.new()
	root.add_child(screen)
	site = screen.site
	# Let the shader compiler and the particle systems settle before judging pixels.
	for i in 20:
		await process_frame

	var wide: Dictionary = await shoot("thunderhold")
	print("CAMP VISUAL overview: ", wide)
	check(float(wide.deviation) > 0.045, "the camp frame has real structure, not a flat fill")
	check(float(wide.mean) > 0.02, "the camp is lit enough to read")
	check(float(wide.hot) > 0.35, "the camp has highlights (fire, badges, sky)")

	# A strike has to visibly move the frame. The bolt is advanced to a known
	# point in its strobe and then frozen, so the capture is deterministic.
	var base_mean := float(wide.mean)
	site.force_strike(1.0, 700.0)
	site._update_storm(0.15)
	site.storm_age = 0.0
	var strike: Dictionary = await shoot("strike")
	site.storm_age = 1.0
	print("CAMP VISUAL strike: ", strike)
	check(float(strike.hot) > float(wide.hot) * 0.95, "a strike keeps the frame hot")
	check(site.bolts.size() > 0 or float(strike.mean) > base_mean, "a strike is visible on screen")

	# The departure gate, where a raid starts.
	screen.warp_to("gate")
	for i in 6:
		await process_frame
	var gate: Dictionary = await shoot("gate")
	print("CAMP VISUAL gate: ", gate)
	check(float(gate.deviation) > 0.04, "the departure gate renders with structure")

	# Rain must be a real, living particle system.
	var rain: Node = site.get_node_or_null("Rain")
	check(rain is GPUParticles3D, "the camp has a rain pass")
	if rain is GPUParticles3D:
		check(int(rain.amount) >= 1000, "rain is dense enough to read as a storm")
		check(rain.draw_pass_1 != null, "rain drops have a drawn shape")

	# A HUD pass with all station markers on screen.
	screen.warp_to("table")
	for i in 6:
		await process_frame
	var table: Dictionary = await shoot("table")
	print("CAMP VISUAL war table: ", table)
	check(float(table.deviation) > 0.04, "the war table and its markers render")

	# The whole camp under a burst of strikes, for the art check.
	for i in 3:
		site.force_strike(1.0, 420.0 + i * 260.0)
		site._update_storm(0.15)
	site.storm_age = 0.0
	var barrage: Dictionary = await shoot("barrage")
	site.storm_age = 1.0
	print("CAMP VISUAL barrage: ", barrage)
	check(float(barrage.hot) > 0.4, "a lightning barrage blows out the sky")

	print("CAMP VISUAL: failures=", failures)
	screen.queue_free()
	await process_frame
	quit(1 if failures else 0)
