class_name MapValidate
extends RefCounted
## Public validation facade. The checks live in MapGen.p10_validate() together
## with the generation metrics; this class is the stable entry point for tools.

static func check(t: TerrainMap, options: Dictionary = {}) -> Dictionary:
	return MapGen.p10_validate(t, options)
