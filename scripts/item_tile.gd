extends RefCounted
## The one cell look shared by every bag panel.
##
## `extraction_inventory.gd` (the raid panel) and `camp_pack.gd` (the camp panel) draw
## the very same socket artwork, quality lining, rotation and stack badge. Keeping the
## implementation here means a change to the look lands in both places at once instead
## of drifting apart.
##
## `host` is the screen that owns the overlay: it must provide `overlay`, `item_icon()`
## and `label()` (that is `main.gd`).
const Socket := preload("res://scripts/extraction_inventory_socket.gd")

const GOLD := Color("cbb087")
## The stack count's own colour: bright enough to read over the quality lining and the
## artwork behind it. Kept apart from GOLD so the badge can change without touching
## every other label that shares the palette.
const STACK_TINT := Color("ff9000")
# How much of a cell the artwork fills. The gaps keep a rotated 2x1 readable as two
# separate cells rather than one wide smear.
const INSET := 9.0

static func tile(host, at: Vector2, size: Vector2, item: Dictionary = {}, tone: Color = GOLD, secure: bool = false) -> Control:
	var node := Socket.new()
	node.position=at
	node.size=size
	node.tone=Catalog.item_color(item) if not item.is_empty() else tone
	if str(item.get("kind",""))=="backpack":
		node.tone=Catalog.tier(Catalog.bag_key_of_item(item)).color
	node.occupied=not item.is_empty()
	node.secure=secure
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	host.overlay.add_child(node)
	if not item.is_empty():
		var icon_size := size-Vector2(INSET*2,INSET*2)
		var icon=host.item_icon(node,Catalog.item_icon(item),Vector2(INSET,INSET),icon_size)
		icon.pivot_offset=icon.size*0.5
		if bool(item.get("rot",false)):
			icon.size=Vector2(icon_size.y,icon_size.x)
			icon.pivot_offset=icon.size*0.5
			icon.position=(size-icon.size)*0.5
			icon.rotation=PI*0.5
		var count := int(item.get("count",1))
		if count>1:
			# The stack badge sits in the cell's own bottom-right corner and in the game's
			# stack orange: the old muted gold at the cell's middle-left read as part of
			# the quality lining instead of as a count.
			host.label(node,"×%d" % count,Vector2(size.x-32,size.y-22),13,STACK_TINT,Vector2(28,20)).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	return node
