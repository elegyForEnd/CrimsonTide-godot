extends RefCounted
## Ordered triangles, including Godot's 1.25 px line antialias fringe.
## Keeping primitive order preserves alpha compositing between particles.
var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
func quad(a: Vector2,b: Vector2,c: Vector2,d: Vector2,ca: Color,cb: Color,cc: Color,cd: Color) -> void:
	var base := points.size()
	points.append(a); points.append(b); points.append(c); points.append(d)
	colors.append(ca); colors.append(cb); colors.append(cc); colors.append(cd)
	indices.append(base); indices.append(base+1); indices.append(base+2)
	indices.append(base); indices.append(base+2); indices.append(base+3)
func polygon(vertices: PackedVector2Array,color: Color) -> void:
	var base := points.size()
	points.append_array(vertices)
	for i in vertices.size(): colors.append(color)
	for i in range(1,vertices.size()-1):
		indices.append(base); indices.append(base+i); indices.append(base+i+1)
func line(a: Vector2,b: Vector2,color: Color,width: float) -> void:
	# Godot 4.7 compensates thin antialiased strokes before constructing fringes.
	# All particle strokes are 1.0 or 1.3 px, within its half-width branch.
	width*=.5
	var direction := (a-b).normalized()
	var normal := direction.orthogonal()
	var half_width := normal*(width*.5)
	var feather := 1.25*minf(1.0,width)
	var side := normal*feather
	var cap := direction*feather
	var al := a+half_width; var ar := a-half_width
	var bl := b+half_width; var br := b-half_width
	var clear := Color(color,0)
	quad(al,ar,br,bl,color,color,color,color)
	quad(al,al+side,bl+side,bl,color,clear,clear,color)
	quad(ar,ar-side,br-side,br,color,clear,clear,color)
	quad(al,al+cap,ar+cap,ar,color,clear,clear,color)
	quad(bl,bl-cap,br-cap,br,color,clear,clear,color)
	quad(al,al+cap,al+side+cap,al+side,color,clear,clear,clear)
	quad(ar,ar+cap,ar-side+cap,ar-side,color,clear,clear,clear)
	quad(bl,bl-cap,bl+side-cap,bl+side,color,clear,clear,clear)
	quad(br,br-cap,br-side-cap,br-side,color,clear,clear,clear)
func flush(target: CanvasItem) -> void:
	if points.is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(target.get_canvas_item(),indices,points,colors)
	points.clear(); colors.clear(); indices.clear()
