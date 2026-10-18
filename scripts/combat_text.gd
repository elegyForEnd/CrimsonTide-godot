extends Node2D
## Floating combat text shared by every battle mode.
##
## The font is a real 10px pixel font (Fusion Pixel, OFL-1.1) rendered at
## integer multiples only: 20px for ordinary hits, 30px for heavy/critical
## hits.  The glyph itself never scales or rotates; only three things move:
##   * the whole line floats up and fades (normal hit feedback),
##   * two afterimage copies trail the line while they fade (optional),
##   * the fill flashes white for a few frames on heavy/crit/heal (optional).
##
## The two options are read from the local `GraphicsQuality` autoload on every
## draw, so toggling them in 画面设置 takes effect immediately, even mid-run.
## No background box or underline is drawn: the styling lives entirely in the
## glyph outline.  Heavy hits carry a full 1px ink ring plus a 1px category
## tint ring (the double outline of style B); ordinary 20px hits keep the ink
## ring and wear the tint as a tight 1px shadow so their counters stay open.

const FONT_PATH := "res://assets/fonts/fusion-pixel-10px-proportional-zh_hans.ttf"
const INK := Color("0a070c")
const LIFE := 0.7
const DOT_LIFE := 0.55
const RISE := 46.0
const SIZE_NORMAL := 20
const SIZE_HEAVY := 30
const COLORS := {
	"damage": Color("f2e3c6"),
	"hurt": Color("ff4d5f"),
	"heal": Color("86e8b0"),
	"dot": Color("ff9a4d"),
}
const HEAVY_COLOR := Color("ffc65c")

var entries: Array = []
var projector: Callable = Callable()
var font: Font

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_font()
	set_process(true)

func _ensure_font() -> void:
	if font != null:
		return
	var loaded: Variant = load(FONT_PATH)
	if loaded is Font:
		font = loaded
	else:
		font = ThemeDB.fallback_font

func reset() -> void:
	entries.clear()
	queue_redraw()

## Route the authoritative combat events into floating text.  Unknown kinds
## (visual-only events, audio cues) are ignored.
func on_event(data: Dictionary) -> void:
	var kind := str(data.get("kind", ""))
	var at: Vector2 = data.get("p", Vector2.ZERO)
	match kind:
		"impact", "hit":
			var tag := str(data.get("damage_tag", ""))
			if tag == "dot" or tag == "burn":
				push("dot", at - Vector2(0, 58), float(data.get("damage", 0.0)))
			else:
				push("damage", at - Vector2(0, 62), float(data.get("damage", 0.0)),
					{"heavy": bool(data.get("heavy", false))})
		"hurt":
			push("hurt", at - Vector2(0, 96), float(data.get("damage", 0.0)))
		"heal":
			push("heal", at - Vector2(0, 96), float(data.get("amount", data.get("damage", 0.0))))
		"burn":
			push("dot", at - Vector2(0, 58), float(data.get("damage", 0.0)))

## One floating entry.  `amount` is already the authoritative, clamped number
## (heals pass the HP actually restored, not the raw item value).
func push(kind: String, at: Vector2, amount: float, opts: Dictionary = {}) -> void:
	if amount <= 0.0:
		return
	var heavy := bool(opts.get("heavy", false))
	var colour: Color = COLORS.get(kind, COLORS["damage"])
	var text := str(roundi(amount))
	var size := SIZE_NORMAL
	match kind:
		"hurt":
			text = "-" + text
		"heal":
			text = "+" + text
		"damage":
			if heavy:
				size = SIZE_HEAVY
				colour = HEAVY_COLOR
		"dot":
			pass
		_:
			pass
	# Keep simultaneous hits legible: count recent entries at the same anchor,
	# then fan them out horizontally and stagger them vertically.  A lone hit
	# stays centred (lane 0 -> slot 1).
	var lane := 0
	for old in entries:
		if float(old["age"]) < 0.22 and Vector2(old["p"]).distance_to(at) < 90.0:
			lane += 1
	var slot := (lane + 1) % 3
	entries.append({
		"kind": kind,
		"value": text,
		"p": at,
		"age": 0.0,
		"life": DOT_LIFE if kind == "dot" else LIFE,
		"heavy": heavy,
		"color": colour,
		"size": size,
		"drift": float(opts.get("drift", (slot - 1) * 48.0 + randf_range(-2.0, 2.0))),
		"rise": RISE + slot * 4.0,
		"lift": float((lane % 2) * 12),
		"flash": kind == "heal" or (kind == "damage" and heavy),
	})
	if is_visible_in_tree():
		queue_redraw()

func _process(dt: float) -> void:
	advance(dt)

func advance(dt: float) -> void:
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		entry["age"] = float(entry["age"]) + dt
		if float(entry["age"]) >= float(entry["life"]):
			entries.remove_at(i)
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	if entries.is_empty():
		return
	_ensure_font()
	if font == null:
		return
	var ghost := _option("damage_ghost", true)
	var flash_on := _option("damage_flash", true)
	for entry in entries:
		var t: float = clampf(float(entry["age"]) / maxf(0.01, float(entry["life"])), 0.0, 1.0)
		var fade: float = 1.0 - smoothstep(0.55, 1.0, t)
		if fade <= 0.001:
			continue
		var ease: float = 1.0 - pow(1.0 - t, 2.0)
		var at: Vector2 = entry["p"]
		if projector.is_valid():
			at = projector.call(at)
		var pos: Vector2 = at + Vector2(float(entry["drift"]), -float(entry["rise"]) * ease + float(entry["lift"]))
		var text := str(entry["value"])
		var size := int(entry["size"])
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var origin := pos - Vector2(width * 0.5, 0.0)
		var base: Color = entry["color"]
		var flash := 0.0
		if flash_on and bool(entry["flash"]):
			flash = clampf(1.0 - float(entry["age"]) / 0.07, 0.0, 1.0)
		var fill: Color = base.lerp(Color.WHITE, flash * 0.85)
		fill.a = fade
		if ghost and entry["kind"] != "dot":
			var ghost_t: float = clampf(float(entry["age"]) / 0.18, 0.0, 1.0)
			var offset := Vector2(1.5 + 2.0 * ghost_t, 2.0 + 3.0 * ghost_t)
			var ghost_colour := Color(base)
			ghost_colour.a = 0.20 * fade * (1.0 - ghost_t)
			draw_string(font, origin + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ghost_colour)
			ghost_colour.a = 0.10 * fade * (1.0 - ghost_t)
			draw_string(font, origin + offset * 1.7, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ghost_colour)
		var rim := base.darkened(0.55)
		rim.a = 0.95 * fade
		if size >= SIZE_HEAVY:
			# 30px keeps full counters, so it can carry the complete 1px tint
			# ring outside the 1px ink ring (the double outline of style B).
			_draw_ring(origin, text, size, rim, 2)
		else:
			# At 20px a full tint ring eats the 2px counters; keep the ink ring
			# and put the category colour on a tight 1px shadow instead.
			draw_string(font, origin + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, rim)
		_draw_ring(origin, text, size, Color(INK, fade), 1)
		draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)

## A hard pixel rim: every glyph is stamped on the ring around its base
## position.  radius 2 = category tint outside, radius 1 = ink inside.
func _draw_ring(origin: Vector2, text: String, size: int, colour: Color, radius: int) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			if maxi(absi(dx), absi(dy)) != radius:
				continue
			draw_string(font, origin + Vector2(dx, dy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)

func _option(key: String, fallback: bool) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return fallback
	var graphics: Node = tree.root.get_node_or_null("GraphicsQuality")
	if graphics == null:
		return fallback
	return bool(graphics.get(key))
