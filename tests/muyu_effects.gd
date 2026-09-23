extends SceneTree
## Checks the ultimate's new ring-and-blades presentation without a window.
##
##  * the ring is stretched across exactly the rectangle the damage test reads,
##    so the circle can never lie about which ground burns;
##  * six blades are laid out per patch, deterministic for a given patch, all of
##    them inside the ring and none of them crowding another;
##  * half of them come out mirrored, which is what makes the rain read as rain.

var checks := 0
var failures := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("  FAIL %s" % what)


func sector_gap(from: Vector2, to: Vector2) -> float:
	"""How far apart two positions are *around the ring*.

	Measuring the angle between the two position vectors is the wrong quantity:
	two points on opposite sides of the middle have position vectors pointing
	almost the same way, so that measure calls them neighbours.  What matters is
	the difference of their own polar angles."""
	if from.length_squared() < 0.0001 or to.length_squared() < 0.0001:
		return 0.0
	return absf(angle_difference(from.angle(), to.angle()))


func radial_angles(placed: Array, forward: float, half: float) -> Array:
	"""The polar angle of each blade, in the patch's own normalised frame."""
	var angles: Array = []
	for blade in placed:
		var centre: Vector2 = blade[CombatVisuals.BLADE_CENTRE]
		angles.append(Vector2(centre.x / half, centre.y / (forward * 0.5)).angle())
	return angles


func check_even_spread(angles: Array, expected: int, seed_value: int, what: String) -> void:
	"""Every sector of the ring must hold exactly one position.

	This is what "not clumped" means for a set spread over a ring: sorting the
	angles and walking the gaps shows whether the positions really do cover the
	circle or whether two of them landed in the same place.  Comparing them
	pairwise does not - two positions can be far apart on the ring and still have
	nearly the same angle relative to the middle."""
	check(angles.size() == expected, "seed %d lays out %d %ss" % [seed_value, expected, what])
	if angles.size() != expected:
		return
	var sorted := angles.duplicate()
	sorted.sort()
	var step := TAU / float(expected)
	var widest := 0.0
	for index in sorted.size():
		var nxt: float = sorted[(index + 1) % sorted.size()]
		var gap: float = fposmod(nxt - float(sorted[index]), TAU)
		widest = maxf(widest, gap)
	# With one position per sector the largest empty arc is at most two sectors;
	# a clump leaves a hole much wider than that.
	check(widest <= step * 2.15,
		"seed %d spreads the %ss around the ring (widest gap %.0f deg of %.0f)" % [
			seed_value, what, rad_to_deg(widest), rad_to_deg(step * 2.15)])


func _init() -> void:
	var forward := TideSession.FIRE_LENGTH
	var half := TideSession.FIRE_HALF_WIDTH
	var rect := CombatVisuals.patch_local_rect(forward, half)
	print("patch rect %s size %s" % [rect, rect.size])
	check(is_equal_approx(rect.end.y - rect.position.y, half * 2.0), "the ring spans the rectangle's width")
	check(is_equal_approx(rect.end.x - rect.position.x, forward + TideSession.FIRE_BACK), "the ring spans the rectangle's length")

	var seeds := [0, 1, 7, 12345, 999983, 424242]
	for seed_value in seeds:
		var blades := CombatVisuals.blade_layout(seed_value, forward, half)
		check(blades.size() == CombatVisuals.RAIN_BLADES,
			"seed %d lays out %d blades (got %d)" % [seed_value, CombatVisuals.RAIN_BLADES, blades.size()])
		var mirrored := 0
		for index in blades.size():
			var blade: Array = blades[index]
			var centre: Vector2 = blade[CombatVisuals.BLADE_CENTRE]
			var extent: Vector2 = blade[CombatVisuals.BLADE_EXTENT]
			var angle: float = blade[CombatVisuals.BLADE_ANGLE]
			if blade[CombatVisuals.BLADE_MIRROR]:
				mirrored += 1
			# Every corner of the blade has to sit inside the ring.
			for corner in 4:
				var offset := Vector2(-1.0 if corner < 2 else 1.0,
					-1.0 if corner % 2 == 0 else 1.0) * extent / 2.0
				var at: Vector2 = centre + offset.rotated(angle)
				var norm := Vector2(at.x / half, at.y / (forward * 0.5))
				check(norm.length() <= 0.97,
					"seed %d blade %d corner %d stays inside the ring (%.3f)" % [seed_value, index, corner, norm.length()])
			# And none of them stands on the caster.
			var norm_centre := Vector2(centre.x / half, centre.y / (forward * 0.5))
			check(norm_centre.length() >= 0.20,
				"seed %d blade %d stays off the caster (%.2f)" % [seed_value, index, norm_centre.length()])
		check(mirrored >= 1 and mirrored <= CombatVisuals.RAIN_BLADES - 1,
			"seed %d turns part of the rain around (%d of %d)" % [seed_value, mirrored, blades.size()])
		check_even_spread(radial_angles(blades, forward, half), CombatVisuals.RAIN_BLADES, seed_value, "blade")

		# The flames share the ring with the blades and must be spread too.
		var flames := CombatVisuals.flame_spots(seed_value)
		check(flames.size() == CombatVisuals.RAIN_FLAMES,
			"seed %d lays out %d flames (got %d)" % [seed_value, CombatVisuals.RAIN_FLAMES, flames.size()])
		for index in flames.size():
			var spot: Vector2 = flames[index]
			check(Vector2(spot.x, spot.y).length() <= 0.95,
				"seed %d flame %d stays inside the ring (%.2f)" % [seed_value, index, spot.length()])
			check(spot.length() >= 0.20,
				"seed %d flame %d stays off the caster (%.2f)" % [seed_value, index, spot.length()])
			for other in range(index + 1, flames.size()):
				var apart := sector_gap(spot, Vector2(flames[other]))
				check(apart >= TAU / float(CombatVisuals.RAIN_FLAMES) * 0.5,
					"seed %d flames %d and %d are not on top of each other (%.0f deg)" % [
						seed_value, index, other, rad_to_deg(apart)])
		var flame_angles: Array = []
		for spot in flames:
			flame_angles.append(Vector2(spot).angle())
		check_even_spread(flame_angles, CombatVisuals.RAIN_FLAMES, seed_value, "flame")

	# The same patch must lay out the same rain on every client.
	var a := CombatVisuals.blade_layout(CombatVisuals.blade_seed(Vector2(320, 180), Vector2.RIGHT), forward, half)
	var b := CombatVisuals.blade_layout(CombatVisuals.blade_seed(Vector2(320, 180), Vector2.RIGHT), forward, half)
	check(str(a) == str(b), "the same patch lays out the same rain twice")
	var c := CombatVisuals.blade_layout(CombatVisuals.blade_seed(Vector2(321, 180), Vector2.RIGHT), forward, half)
	check(str(a) != str(c), "a patch elsewhere lays out different rain")

	# The blades are anchored in the patch's own frame, so turning the aim turns
	# the rain with it and nothing leaves the circle.
	for aim in [Vector2.RIGHT, Vector2.UP, Vector2(-0.6, 0.8).normalized()]:
		var frame := Transform2D(aim.angle(), Vector2(100, 100))
		for blade in a:
			var world: Vector2 = frame * Vector2(blade[CombatVisuals.BLADE_CENTRE])
			var local := (world - Vector2(100, 100)).rotated(-aim.angle())
			check(Vector2(local.x / half, local.y / (forward * 0.5)).length() <= 0.97,
				"a blade stays in the ring after the aim turns")

	print("MUYU EFFECT TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
