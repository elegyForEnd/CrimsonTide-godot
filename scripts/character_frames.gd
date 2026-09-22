class_name CharacterFrames
extends RefCounted
## Atlas regions are clipped independently; padding belongs to the source art.
var attacks: Array = []
var movement: Array = []

func _init() -> void:
	for hero in 3:
		attacks.append(read_sheet("res://assets/combat/attack-clean-%d.png" % hero))
		movement.append(read_sheet("res://assets/combat/movement-%d.png" % hero))

func read_sheet(path: String) -> Array:
	var sheet: Texture2D=load(path)
	var cell := Vector2i(sheet.get_size()/Vector2(4,3))
	var source := sheet.get_image()
	var rows: Array=[]
	# Generated sheets are not mathematically perfect grids. Locate real empty
	# gutters so a boot or weapon near the nominal boundary stays in its frame.
	var ys := [0,find_gutter(source,cell.y,cell.y,true,0,source.get_width()),find_gutter(source,cell.y*2,cell.y,true,0,source.get_width()),source.get_height()]
	var reference := source.get_region(Rect2i(0,0,cell.x,ys[1])).get_used_rect()
	var scale := 90.0/maxf(1,reference.size.y)
	for row in 3:
		var frames: Array=[]
		var baseline := 0.0
		var xs := [0,find_gutter(source,cell.x,cell.x,false,ys[row],ys[row+1]),find_gutter(source,cell.x*2,cell.x,false,ys[row],ys[row+1]),find_gutter(source,cell.x*3,cell.x,false,ys[row],ys[row+1]),source.get_width()]
		var bounds: Array[Rect2i]=[]
		for column in 4:
			var region := Rect2i(xs[column],ys[row],xs[column+1]-xs[column],ys[row+1]-ys[row])
			var used := source.get_region(region).get_used_rect()
			baseline=maxf(baseline,used.end.y)
			bounds.append(region)
		for column in 4:
			var texture := AtlasTexture.new()
			texture.atlas=sheet
			texture.region=Rect2(bounds[column])
			texture.filter_clip=true
			var extent := Vector2(bounds[column].size)
			frames.append({"texture":texture,"rect":Rect2(Vector2(-extent.x*0.5,-baseline)*scale+Vector2(0,16),extent*scale)})
		rows.append(frames)
	return rows

func find_gutter(source: Image, expected: int, cell_size: int, horizontal: bool, start: int, end: int) -> int:
	var radius := int(cell_size*0.22)
	var best := expected
	var longest := 0
	var run := 0
	for axis in range(expected-radius,expected+radius):
		var occupied := false
		for cross_axis in range(start,end):
			var pixel := source.get_pixel(cross_axis,axis) if horizontal else source.get_pixel(axis,cross_axis)
			if pixel.a>0.08:
				occupied=true
				break
		run=0 if occupied else run+1
		if run>longest:
			longest=run
			best=axis-run/2
	return best

func attack_frame(hero: int, weapon: int, frame: int) -> Dictionary:
	return attacks[hero][clampi(weapon-1,0,2)][clampi(frame,0,3)]

func motion_frame(hero: int, mode: String, phase: float, dodge_time: float) -> Dictionary:
	var row := 2 if mode=="dodge" else 1 if mode=="run" else 0
	var frame := clampi(int((1.0-dodge_time/TideSession.DODGE_DURATION)*4.0),0,3) if row==2 else posmod(int(phase),4)
	return movement[hero][row][frame]
