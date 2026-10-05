extends SceneTree

# Atlas assembly only: artwork comes exclusively from ImageGen. Source files
# remain untouched. Component ownership isolates the source poses; a fresh cell
# reserves 64px on all four sides, independently of the generator's margins.
const DIR := "res://assets/rogue/animations/"
const PADDING := 64
var records: Array=[]
var errors := 0
var source_index: Dictionary={}
var hd := false
func _initialize() -> void: call_deferred("run")

func pack(record: Dictionary) -> void:
	var source := Image.load_from_file(DIR+("hd-sources/" if hd else "sources/")+str(record.get("source_file",record.file)))
	if source==null: push_error("Missing "+record.file); errors+=1; return
	if not source_index.has(record.file): push_error("Rejected missing/merged frames: "+record.file); errors+=1; return
	source.convert(Image.FORMAT_RGBA8)
	var columns: int=record.columns
	var rows: int=record.rows
	var used_rows: int=record.get("used_rows",rows)
	var indexed: Dictionary=source_index[record.file]
	var owners := FileAccess.get_file_as_bytes(indexed.ownership)
	var rgba := source.get_data()
	var frames: Array=[]
	var maximum := 0
	for index in indexed.frames.size():
		var b: Array=indexed.frames[index].bounds
		var area := Rect2i(b[0],b[1],b[2],b[3])
		var pixels := PackedByteArray()
		pixels.resize(area.size.x*area.size.y*4)
		for y in area.size.y:
			for x in area.size.x:
				var src: int=(area.position.y+y)*source.get_width()+area.position.x+x
				if owners[src]!=index+1: continue
				var dst: int=(y*area.size.x+x)*4
				for channel in 4: pixels[dst+channel]=rgba[src*4+channel]
		var frame := Image.create_from_data(area.size.x,area.size.y,false,Image.FORMAT_RGBA8,pixels)
		var bounds := Rect2i(Vector2i.ZERO,area.size)
		maximum=maxi(maximum,maxi(bounds.size.x,bounds.size.y))
		frames.append({"image":frame,"bounds":bounds,"source_cell":area})
	if frames.size()!=used_rows*columns: return
	var cell: int=int(ceil(float(maximum+PADDING*2)/64))*64
	var atlas := Image.create(cell*columns,cell*used_rows,false,Image.FORMAT_RGBA8)
	atlas.fill(Color(0,0,0,0))
	var manifest: Array=[]
	for index in frames.size():
		var frame: Dictionary=frames[index]
		var bounds: Rect2i=frame.bounds
		var local := Vector2i((cell-bounds.size.x)/2,cell-PADDING-bounds.size.y)
		if str(record.file).begins_with("effects-"): local.y=(cell-bounds.size.y)/2
		var origin := Vector2i((index%columns)*cell,(index/columns)*cell)
		atlas.blit_rect(frame.image,bounds,origin+local)
		manifest.append({"cell":[origin.x,origin.y,cell,cell],"content":[origin.x+local.x,origin.y+local.y,bounds.size.x,bounds.size.y],"source_cell":[frame.source_cell.position.x,frame.source_cell.position.y,frame.source_cell.size.x,frame.source_cell.size.y]})
	atlas.save_png(DIR+record.file)
	records.append({"file":record.file,"columns":columns,"rows":used_rows,"padding":PADDING,"cell_size":cell,"frames":manifest})
	print("Packed ",record.file," / ",frames.size()," frames / ",cell,"px cells / padding ",PADDING)

func run() -> void:
	hd="--hd" in OS.get_cmdline_user_args()
	var prefix := "hd-" if hd else ""
	var spec: Variant=JSON.parse_string(FileAccess.get_file_as_string(DIR+prefix+"source-manifest.json"))
	for record in JSON.parse_string(FileAccess.get_file_as_string(DIR+prefix+"source-components.json")): source_index[record.file]=record
	for record in spec.assets: pack(record)
	var file := FileAccess.open(DIR+prefix+"packed-manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"assets":records,"assembly_errors":errors},"\t"))
	print("ATLAS ASSEMBLY ",records.size()," sheets / ",errors," errors")
	quit(1 if errors else 0)
