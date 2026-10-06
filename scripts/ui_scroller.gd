extends RefCounted
## The one vertical scroll recipe the panels share.
##
## Godot's `ScrollContainer` does not resize its non-container children — it only ever
## *overlaps* the scroll bar on top of them — so a hand-placed grid (the cell art comes
## from `item_tile.gd`, which positions every tile itself) cannot be wrapped in one and
## have its right-hand column stay clickable. `ui_skin` found the same wall the same way
## and settled on the recipe this module now keeps in one place: put a plain `Control` of
## the full content height inside the container, let the container scroll it, and keep the
## bar at `x = content width + 1` so it sits in the frame's margin instead of on the tiles.
##
## The two callers are the places a storage grid is bigger than the window that shows it:
## `extraction_inventory.gd` (the raid/camp panel's backpack, which may be 8x8) and
## `economy_screen.gd` (the exchange's 15x15 vault and the carried backpack).
##
## The *behaviour* — where a click lands once the content has scrolled — stays with each
## panel: the raid panel reads its grid through the drag controller's registration, the
## exchange through a mouse filter on the content node. Only the construction and the
## look are shared here.
const BAR_WIDTH := 14.0

## Builds a scrolling viewport of `viewport_size` at `at` under `parent` and returns it
## with the bar styled. The caller adds its own content node (a plain `Control`, or a
## grid that reports clicks) as a child and sizes it to the full content — never the
## other way round.
##
## Building fresh is the point: an earlier version *reparented* a node that the caller had
## already drawn into, while the bar was added to the same node it wrapped, so Godot saw a
## node inside its own child and refused the tree with a cyclic dependency. A container is
## only ever the parent of the thing it scrolls, and it is created exactly once here so a
## redraw can clear its children instead of moving the container itself.
static func make(parent: Node, at: Vector2, viewport_size: Vector2) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.position=at
	scroll.size=viewport_size
	# Height-only, auto: a grid never needs a sideways scrollbar, and AUTO keeps the bar
	# out of the way entirely while the content still fits.
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter=Control.MOUSE_FILTER_PASS
	parent.add_child(scroll)
	style(scroll.get_v_scroll_bar())
	return scroll

## A content node sized to `size`, ready to be dropped into a `make()` container. Plain
## `Control` so the container honours the full height (a container child would be
## squeezed), and `PASS` so a click still reaches a grid that sits underneath for the
## scroll wheel to keep working.
static func content(size: Vector2) -> Control:
	var node := Control.new()
	node.custom_minimum_size=size
	node.mouse_filter=Control.MOUSE_FILTER_PASS
	return node

## The panel skin for a scroll bar, in the gold-on-ink palette every panel already uses.
static func style(bar: VScrollBar) -> void:
	bar.custom_minimum_size.x=BAR_WIDTH
	for key in ["scroll","scroll_focus"]:
		var track := StyleBoxFlat.new()
		track.bg_color=Color("100d12")
		track.border_color=Color("65523a")
		track.set_border_width_all(1)
		track.set_corner_radius_all(5)
		track.content_margin_left=5
		track.content_margin_right=5
		bar.add_theme_stylebox_override(key,track)
	for key in ["grabber","grabber_highlight","grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color=Color("ad9163") if key=="grabber" else Color("dbc18e")
		grip.border_color=Color("e4cb98")
		grip.set_border_width_all(1)
		grip.set_corner_radius_all(4)
		grip.content_margin_top=12
		grip.content_margin_bottom=12
		grip.content_margin_left=4
		grip.content_margin_right=4
		bar.add_theme_stylebox_override(key,grip)
	var blank := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([Color.TRANSPARENT,Color.TRANSPARENT])
	blank.gradient=gradient
	blank.width=1
	blank.height=1
	for key in ["increment","increment_highlight","increment_pressed","decrement","decrement_highlight","decrement_pressed"]:
		bar.add_theme_icon_override(key,blank)
