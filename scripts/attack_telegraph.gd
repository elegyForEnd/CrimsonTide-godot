extends RefCounted
## Enemy attack telegraphs, painted loud enough to read at a glance.
##
## The simulation owns the footprint; this file owns how loudly it shouts.
## Enemy identity colours stay pale for nameplates and health bars, while the
## windup is repainted in a saturated danger hue that survives the desaturated
## night palette. Layers, painted back to front:
##   1. a ground bloom so the shape separates from the terrain,
##   2. a hazard hatch that keeps the fill readable on any biome,
##   3. a charge fill that grows to exactly the footprint at release,
##   4. a four-pass edge (bloom / mid / core / white-hot) that never gets lost,
##   5. charge sparks converging as the windup runs out,
##   6. an upright ring plus countdown above the attacker,
##   7. a white-hot lock flash over the last fifth,
##   8. a released burst once the attack actually fires.
const Ecology = preload("res://scripts/ecology.gd")

## Danger pass, indexed exactly like EnemyFrames.COLORS and Ecology.WINDUP so a
## biome keeps its identity while the readability budget goes up.
const TINT := [Color("ff2e63"), # 0  血晶食尸兔
	Color("a86bff"), # 1  哀钟幽灵
	Color("ffb03a"), # 2  蔷薇刑偶
	Color("ff3b30"), # 3  赤月灾狐
	Color("ffd24a"), # 4  失乡骑士
	Color("b8ff3d"), # 5  丧钟夜蛾
	Color("ff8a2b"), # 6  禁卷鸦枭
	Color("c46bff"), # 7  枯月骨鹿
	Color("ff4d9e"), # 8  血棘妖
	Color("28e6ff"), # 9  雾汐冥水母
	Color("ff7a3d"), # 10 腐羽狮鹫
	Color("5cc8ff"), # 11 墓翼石像鬼
	Color("2ff5c0"), # 12 溺钟怨灵
	Color("ffbe2e"), # 13 提灯刽子手
	Color("b46bff"), # 14 月碑巨像
	Color("2fe0c8"), # 15 沉钟巨骸
	Color("ff5a3c")] # 16 血棺守卫
const HOT := Color(1.0, 0.98, 0.94)
const HATCH_DIR := Vector2(0.70710678, 0.70710678)
const HATCH_PERP := Vector2(-0.70710678, 0.70710678)
const BURST_WINDOW := 0.26
const MELEE_REACH := 58.0

static func tint(kind: int) -> Color:
	return TINT[clampi(kind, 0, TINT.size() - 1)]

static func windup(kind: int) -> float:
	return float(Ecology.WINDUP[clampi(kind, 0, Ecology.WINDUP.size() - 1)])

## Radius of the burst flash, kept in step with the real damage footprint.
static func footprint(kind: int) -> float:
	if kind < 4: return MELEE_REACH
	match kind:
		7: return 110.0
		8: return 76.0
		9: return 85.0
		10: return 100.0
		11: return 60.0
		12: return 110.0
		13: return 130.0
		14: return 135.0
		15: return 145.0
		16: return 145.0
	return 80.0

## Brightness beat: lazy while the windup opens, frantic right before release.
static func beat(clock: float, progress: float, kind: int) -> float:
	return 0.5 + 0.5 * sin(clock * (4.5 + 16.0 * progress) + float(kind) * 1.9)

static func circle_points(centre: Vector2, radius: float, count: int, closed: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(centre + Vector2.from_angle(float(i) / float(count) * TAU) * radius)
	if closed: points.append(points[0])
	return points

static func arc_points(centre: Vector2, radius: float, from_angle: float, to_angle: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count + 1:
		points.append(centre + Vector2.from_angle(lerpf(from_angle, to_angle, float(i) / float(count))) * radius)
	return points

static func sector_points(centre: Vector2, radius: float, from_angle: float, to_angle: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array([centre])
	for i in count + 1:
		points.append(centre + Vector2.from_angle(lerpf(from_angle, to_angle, float(i) / float(count))) * radius)
	return points

static func band_points(from: Vector2, to: Vector2, half_width: float) -> PackedVector2Array:
	var side := (to - from).normalized().orthogonal() * half_width
	return PackedVector2Array([from - side, to - side, to + side, from + side])

## The four-pass edge. A single line can vanish behind scenery; this stack keeps
## a dark bloom, a saturated body and a white-hot spine on screen at all times.
func edge(target: CanvasItem, points: PackedVector2Array, colour: Color, alpha: float, width: float) -> void:
	if points.size() < 2: return
	target.draw_polyline(points, Color(colour, 0.12 * alpha), width * 5.2, true)
	target.draw_polyline(points, Color(colour, 0.32 * alpha), width * 2.6, true)
	target.draw_polyline(points, Color(colour.lightened(0.32), 0.94 * alpha), width * 1.15, true)
	target.draw_polyline(points, Color(HOT, 0.92 * alpha), maxf(1.4, width * 0.5), true)

## Closed edges are polylines; fills must not repeat the first point.
func outline(points: PackedVector2Array) -> PackedVector2Array:
	var loop := points.duplicate()
	if not loop.is_empty(): loop.append(loop[0])
	return loop

func hatch(target: CanvasItem, centre: Vector2, radius: float, colour: Color, alpha: float, spacing: float, phase: float) -> void:
	var offset := -radius + fposmod(phase, spacing)
	while offset < radius:
		var half := sqrt(maxf(0.0, radius * radius - offset * offset))
		var mid := centre + HATCH_PERP * offset
		target.draw_line(mid - HATCH_DIR * half, mid + HATCH_DIR * half, Color(colour, alpha), 3.0, true)
		offset += spacing

## Charge motes that fall inward: they read as "this is nearly done".
func sparks(target: CanvasItem, centre: Vector2, radius: float, colour: Color, clock: float, progress: float, alpha: float) -> void:
	var reach := radius * (1.75 - 0.66 * progress)
	for i in 8:
		var angle := clock * 2.4 + float(i) * TAU / 8.0
		var direction := Vector2.from_angle(angle)
		var tail := centre + direction * (reach + 36.0 + 14.0 * sin(clock * 6.0 + float(i) * 2.1))
		var head := centre + direction * reach
		target.draw_line(tail, head, Color(colour, 0.7 * alpha), 2.4, true)
		target.draw_circle(head, 4.2, Color(HOT, 0.92 * alpha))

## Shared body: bloom, hatch, loading fill, edge, sparks and lock flash.
func disc(target: CanvasItem, centre: Vector2, radius: float, colour: Color, alpha: float, progress: float, pulse: float, lock: float, clock: float) -> void:
	var segments := 48 if radius >= 110.0 else 32
	var ring := circle_points(centre, radius, segments)
	target.draw_circle(centre, radius * 1.14, Color(colour, 0.24 * alpha))
	target.draw_circle(centre, radius, Color(colour, (0.27 + 0.16 * pulse) * alpha))
	hatch(target, centre, radius, colour, (0.34 + 0.20 * pulse) * alpha, 24.0, clock * 26.0)
	if progress > 0.02:
		target.draw_circle(centre, radius * progress, Color(colour, (0.34 + 0.20 * pulse) * alpha))
		target.draw_circle(centre, radius * progress * 0.5, Color(HOT, (0.10 + 0.10 * pulse) * alpha))
		edge(target, circle_points(centre, radius * progress, segments), HOT, alpha * (0.34 + 0.50 * progress), 2.8)
	edge(target, circle_points(centre, radius, segments, true), colour, alpha * (0.68 + 0.32 * progress), 3.2)
	sparks(target, centre, radius, colour, clock, progress, alpha)
	if lock > 0.0:
		var flash := lock * (0.45 + 0.55 * pulse)
		target.draw_circle(centre, radius, Color(HOT, 0.13 * flash * alpha))
		edge(target, circle_points(centre, radius, segments, true), HOT, flash * alpha, 4.8)

## Released flash: an expanding shock ring, radial spikes and a white core.
func burst(target: CanvasItem, centre: Vector2, radius: float, colour: Color, age: float) -> void:
	if age < 0.0 or age > BURST_WINDOW: return
	var k := age / BURST_WINDOW
	var fade := 1.0 - k
	var reach := radius * (0.55 + 1.25 * k)
	edge(target, circle_points(centre, reach, 40, true), colour, 0.95 * fade, 3.0)
	target.draw_circle(centre, radius * 0.55 * fade, Color(HOT, 0.42 * fade))
	for i in 10:
		var direction := Vector2.from_angle(float(i) * TAU / 10.0 + 0.31)
		target.draw_line(centre + direction * (reach * 0.9), centre + direction * (reach * 1.42), Color(colour.lightened(0.25), 0.9 * fade), 3.2, true)

## Upright ring plus a live countdown so the release moment is explicit.
func countdown(target: CanvasItem, ground: Transform2D, font: Font, attacker: Vector2, height: float, colour: Color, remaining: float, progress: float, alpha: float, pulse: float) -> void:
	target.draw_set_transform_matrix(Transform2D(0.0, ground * attacker - attacker))
	var centre := attacker + Vector2(0, -height)
	var left := clampf(1.0 - progress, 0.0, 1.0)
	target.draw_arc(centre, 15.0, 0.0, TAU, 28, Color(0.04, 0.02, 0.04, 0.72 * alpha), 6.0, true)
	target.draw_arc(centre, 15.0, -PI / 2, -PI / 2 + TAU * left, 28, Color(colour, 0.95 * alpha), 4.0, true)
	target.draw_arc(centre, 15.0, -PI / 2, -PI / 2 + TAU * left, 28, Color(HOT, 0.8 * alpha), 1.6, true)
	target.draw_circle(centre + Vector2.from_angle(-PI / 2 + TAU * left) * 15.0, 2.6 + 1.4 * pulse, Color(HOT, 0.95 * alpha))
	var text := "%.1f" % remaining
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var at := centre - Vector2(size.x * 0.5, -5.0)
	target.draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.05, 0.02, 0.03, 0.85 * alpha))
	target.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(colour.lightened(0.45), alpha))
	target.draw_set_transform_matrix(ground)

## Full telegraph for one ordinary enemy. Every footprint mirrors the damage
## rule that will actually fire, so a player who reads the paint is never lied to.
func paint(target: CanvasItem, ground: Transform2D, font: Font, e: Dictionary, kind: int, clock: float) -> void:
	var length := maxf(0.01, windup(kind))
	var passed := float(e.get("attack_total", length)) - float(e.get("attack_time", 0.0))
	var progress := clampf(passed / length, 0.0, 1.0)
	var remaining := clampf((1.0 - progress) * length, 0.0, 9.9)
	var colour := tint(kind)
	var aim: Vector2 = e.get("attack_aim", Vector2.RIGHT)
	var pos: Vector2 = e.p
	var point: Vector2 = e.get("attack_point", pos)
	var height := float(EnemyFrames.HEIGHTS[clampi(kind, 0, EnemyFrames.HEIGHTS.size() - 1)]) + 46.0
	if e.get("attack_released", false):
		burst(target, release_centre(e, kind, pos, aim, point), footprint(kind), colour, passed - length)
		return
	var alpha := smoothstep(0.0, 0.10, progress)
	if alpha <= 0.001: return
	var pulse := beat(clock, progress, kind)
	var lock := smoothstep(0.74, 1.0, progress)

	match kind:
		1:
			# Ranged bolt: a lane along the shot that loads from the caster out.
			var reach := 245.0
			var half_width := 26.0
			var band := band_points(pos, pos + aim * reach, half_width)
			target.draw_colored_polygon(band, Color(colour, (0.25 + 0.16 * pulse) * alpha))
			var steps := 9
			for i in steps:
				var across := band_points(pos + aim * (reach * float(i) / float(steps)), pos + aim * (reach * float(i + 1) / float(steps)), half_width)
				target.draw_line(across[0], across[3], Color(colour, (0.32 + 0.20 * pulse) * alpha), 2.0, true)
			if progress > 0.02:
				target.draw_colored_polygon(band_points(pos, pos + aim * reach * progress, half_width * progress), Color(colour, (0.34 + 0.20 * pulse) * alpha))
				edge(target, outline(band_points(pos, pos + aim * reach * progress, half_width * progress)), HOT, alpha * (0.30 + 0.45 * progress), 2.6)
			edge(target, outline(band), colour, alpha * (0.62 + 0.38 * progress), 3.0)
			sparks(target, pos + aim * reach * 0.3, 64.0, colour, clock, progress, alpha)
			countdown(target, ground, font, pos, height, colour, remaining, progress, alpha, pulse)
			return
		0, 2, 3:
			# Light melee: the disc reaches exactly the contact radius at release.
			var radius := 24.0 + progress * (MELEE_REACH - 24.0)
			disc(target, pos, radius, colour, alpha, progress, pulse, lock, clock)
			countdown(target, ground, font, pos, height, colour, remaining, progress, alpha, pulse)
			return
		7:
			# Piercing lance: a long lane that loads from the caster outward.
			var reach := 235.0
			var half_width := 32.0
			var band := band_points(pos, pos + aim * reach, half_width)
			target.draw_colored_polygon(band, Color(colour, (0.16 + 0.09 * pulse) * alpha))
			var steps := 9
			for i in steps:
				var across := band_points(pos + aim * (reach * float(i) / float(steps)), pos + aim * (reach * float(i + 1) / float(steps)), half_width)
				target.draw_line(across[0], across[3], Color(colour, (0.32 + 0.20 * pulse) * alpha), 2.0, true)
			if progress > 0.02:
				target.draw_colored_polygon(band_points(pos, pos + aim * reach * progress, half_width * progress), Color(colour, (0.34 + 0.20 * pulse) * alpha))
				edge(target, outline(band_points(pos, pos + aim * reach * progress, half_width * progress)), HOT, alpha * (0.30 + 0.45 * progress), 2.6)
			edge(target, outline(band), colour, alpha * (0.62 + 0.38 * progress), 3.0)
			sparks(target, pos + aim * reach * 0.3, 70.0, colour, clock, progress, alpha)
			countdown(target, ground, font, pos, height, colour, remaining, progress, alpha, pulse)
			return
		12:
			# Triple fork: three lanes, all loading together.
			for offset in [-0.5, 0.0, 0.5]:
				var lane: Vector2 = aim.rotated(offset)
				var band := band_points(pos, pos + lane * 195.0, 15.0)
				target.draw_colored_polygon(band, Color(colour, (0.24 + 0.15 * pulse) * alpha))
				if progress > 0.02: target.draw_colored_polygon(band_points(pos, pos + lane * 195.0 * progress, 15.0 * progress), Color(colour, (0.34 + 0.20 * pulse) * alpha))
				edge(target, outline(band), colour, alpha * (0.58 + 0.42 * progress), 2.6)
			countdown(target, ground, font, pos, height, colour, remaining, progress, alpha, pulse)
			return
		13:
			# Wide sweep: the sector footprint is the real arc, not a decoration.
			var radius := 190.0
			var sweep := outline(sector_points(pos, radius, aim.angle() - 1.05, aim.angle() + 1.05, 26))
			target.draw_colored_polygon(sector_points(pos, radius, aim.angle() - 1.05, aim.angle() + 1.05, 26), Color(colour, (0.25 + 0.16 * pulse) * alpha))
			if progress > 0.02:
				target.draw_colored_polygon(sector_points(pos, radius * progress, aim.angle() - 1.05, aim.angle() + 1.05, 26), Color(colour, (0.34 + 0.20 * pulse) * alpha))
				edge(target, arc_points(pos, radius * progress, aim.angle() - 1.05, aim.angle() + 1.05, 26), HOT, alpha * (0.30 + 0.45 * progress), 2.6)
			edge(target, sweep, colour, alpha * (0.62 + 0.38 * progress), 3.0)
			for angle in [-1.05, 1.05]: target.draw_line(pos, pos + aim.rotated(angle) * radius, Color(colour, 0.8 * alpha), 3.0, true)
			sparks(target, pos, radius * 0.5, colour, clock, progress, alpha)
			countdown(target, ground, font, pos, height, colour, remaining, progress, alpha, pulse)
			return
		14:
			# Colossus ground pound: disc plus twelve falling spokes.
			disc(target, pos, 135.0, colour, alpha, progress, pulse, lock, clock)
			for n in 12:
				var direction := Vector2.from_angle(float(n) * TAU / 12.0 + clock * 0.35)
				target.draw_line(pos + direction * (55.0 + 80.0 * (1.0 - progress)), pos + direction * lerpf(55.0, 135.0, progress), Color(colour, (0.45 + 0.35 * pulse) * alpha), 2.6, true)
			countdown(target, ground, font, pos, height, colour, remaining, progress, alpha, pulse)
			return
		15:
			# Double ring: the footprint is an annulus, so the safe hole stays visible.
			var outer := 145.0
			var inner := 85.0
			target.draw_circle(pos, outer, Color(colour, (0.24 + 0.15 * pulse) * alpha))
			target.draw_circle(pos, inner, Color(0.02, 0.012, 0.03, 0.62 * alpha))
			edge(target, circle_points(pos, outer, 48, true), colour, alpha * (0.62 + 0.38 * progress), 3.4)
			edge(target, circle_points(pos, inner, 40, true), colour, alpha * (0.42 + 0.4 * progress), 2.6)
			if progress > 0.02: edge(target, circle_points(pos, lerpf(inner, outer, progress), 44, true), HOT, alpha * (0.30 + 0.5 * progress), 3.0)
			sparks(target, pos, outer * 0.65, colour, clock, progress, alpha)
			countdown(target, ground, font, pos, height, colour, remaining, progress, alpha, pulse)
			return

	# 5, 6, 8, 9, 10, 11 and 16 all land on a locked point, some with a tether.
	var centre: Vector2 = point if kind in [8, 10, 11, 16] else pos
	var radius := footprint(kind)
	disc(target, centre, radius, colour, alpha, progress, pulse, lock, clock)
	if kind == 16:
		var tether := band_points(pos, centre, 5.0)
		target.draw_colored_polygon(tether, Color(colour, (0.26 + 0.16 * pulse) * alpha))
		edge(target, outline(tether), colour, alpha * 0.85, 2.6)
	elif kind == 11:
		edge(target, band_points(pos, centre, 4.0), colour, alpha * 0.7, 2.2)
	countdown(target, ground, font, pos, height, colour, remaining, progress, alpha, pulse)

static func release_centre(e: Dictionary, kind: int, pos: Vector2, aim: Vector2, point: Vector2) -> Vector2:
	if kind < 4: return pos
	if kind == 7: return pos + aim * 120.0
	if kind in [8, 10, 11, 16]: return point
	return pos
