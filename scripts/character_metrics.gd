class_name CharacterMetrics
extends RefCounted
## Authored landmarks in the 1448 x 1086 source sheets. Each Vector3 is
## (ground pivot x, ground pivot y, crown-to-chin height). Exclude hats,
## ponytails, hair ornaments, weapons and glow from the head measurement.
## A ground pivot may sit below airborne feet; never stretch a crouched pose.
const SOURCE_SIZE := Vector2(1448,1086)
const HEAD_PIXELS := 26.0
const FOOT_OFFSET := Vector2(0,16)
const ATTACK = [
	[
		[Vector3(195,335,78),Vector3(550,335,87),Vector3(902,335,83),Vector3(1285,335,86)],
		[Vector3(185,675,85),Vector3(551,675,94),Vector3(894,675,93),Vector3(1268,675,91)],
		[Vector3(180,1030,80),Vector3(545,1030,85),Vector3(900,1030,78),Vector3(1277,1030,82)]
	],
	[
		[Vector3(218,350,87),Vector3(568,350,85),Vector3(904,350,85),Vector3(1248,350,85)],
		[Vector3(240,696,87),Vector3(533,696,88),Vector3(892,696,88),Vector3(1258,696,86)],
		[Vector3(228,1039,86),Vector3(558,1039,85),Vector3(897,1039,84),Vector3(1252,1039,87)]
	],
	[
		[Vector3(167,341,96),Vector3(528,341,91),Vector3(872,341,91),Vector3(1252,341,92)],
		[Vector3(179,695,96),Vector3(533,695,93),Vector3(880,695,93),Vector3(1260,695,96)],
		[Vector3(182,1034,95),Vector3(551,1034,92),Vector3(891,1034,91),Vector3(1277,1034,94)]
	],
	[
		[Vector3(181,345,104),Vector3(543,345,103),Vector3(905,345,104),Vector3(1267,345,103)],
		[Vector3(181,707,104),Vector3(543,707,103),Vector3(905,707,104),Vector3(1267,707,103)],
		[Vector3(181,1069,104),Vector3(543,1069,103),Vector3(905,1069,104),Vector3(1267,1069,103)]
	]
]
const MOVEMENT = [
	[
		[Vector3(219,368,115),Vector3(577,368,112),Vector3(940,368,115),Vector3(1295,368,113)],
		[Vector3(189,724,113),Vector3(569,724,109),Vector3(920,724,113),Vector3(1290,724,110)],
		[Vector3(205,1038,111),Vector3(555,1038,115),Vector3(929,1038,110),Vector3(1292,1038,113)]
	],
	[
		[Vector3(210,371,102),Vector3(580,371,101),Vector3(940,371,102),Vector3(1300,371,102)],
		[Vector3(220,711,108),Vector3(578,711,105),Vector3(940,711,108),Vector3(1300,711,106)],
		[Vector3(225,1021,109),Vector3(589,1021,107),Vector3(941,1021,109),Vector3(1297,1021,109)]
	],
	[
		[Vector3(221,369,110),Vector3(580,369,108),Vector3(940,369,109),Vector3(1301,369,110)],
		[Vector3(211,709,111),Vector3(573,709,109),Vector3(939,709,110),Vector3(1297,709,109)],
		[Vector3(213,1047,113),Vector3(567,1047,111),Vector3(945,1047,112),Vector3(1300,1047,112)]
	],
	[
		[Vector3(181,345,104),Vector3(543,345,103),Vector3(905,345,104),Vector3(1267,345,103)],
		[Vector3(181,707,104),Vector3(543,707,103),Vector3(905,707,104),Vector3(1267,707,103)],
		[Vector3(181,1069,100),Vector3(543,1069,99),Vector3(905,1069,100),Vector3(1267,1069,99)]
	]
]

static func layout(region: Rect2, source_size: Vector2, landmark: Vector3) -> Rect2:
	var resolution := source_size/SOURCE_SIZE
	var pivot := Vector2(landmark.x,landmark.y)*resolution-region.position
	var scale := HEAD_PIXELS/(landmark.z*resolution.y)
	return Rect2(FOOT_OFFSET-pivot*scale,region.size*scale)
