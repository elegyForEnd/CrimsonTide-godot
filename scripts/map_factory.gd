class_name MapFactory
extends RefCounted
## Single entry point for creating a raid world. Generated maps are opt-in so
## the hundreds of existing tests that call session.launch() keep the legacy
## fixed map unless they explicitly ask for generated terrain.

static func create(seed_value: int, options: Dictionary = {}) -> Ruins:
	var generated: bool = bool(options.get("generated", false))
	if not generated:
		var legacy := Ruins.new()
		legacy.generate(seed_value)
		return legacy
	var extent: Vector2 = options.get("extent", Ruins.SIZE)
	var world := MapWorld.new()
	world.extent = extent
	world.generate(seed_value)
	if world.generated:
		return world
	# MapGen exhausted its retries: fall back to the legacy fixed map.
	var fallback := Ruins.new()
	fallback.generate(seed_value)
	return fallback

static func create_legacy(seed_value: int) -> Ruins:
	var legacy := Ruins.new()
	legacy.generate(seed_value)
	return legacy
