extends SceneTree

# Rasterises assets/icon.svg into a Windows .ico plus PNG copies, so the launcher
# can give the desktop shortcut a real game icon without external image tooling.
# Run: Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/make_icon.gd

const SOURCE := "res://assets/icon.svg"
const ICO_PATH := "res://tools/crimson-tide.ico"
const PNG_PATH := "res://tools/crimson-tide.png"
# Each entry is one image stored inside the .ico container.
const ICO_IMAGES := [
	{"size": 16, "png": false},
	{"size": 32, "png": false},
	{"size": 64, "png": false},
	{"size": 256, "png": true},
]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not ResourceLoader.exists(SOURCE):
		push_error("missing "+SOURCE)
		quit(1)
		return
	var texture: Texture2D=load(SOURCE)
	if texture==null:
		push_error("cannot load "+SOURCE)
		quit(1)
		return
	var image: Image=texture.get_image()
	if image==null:
		push_error("cannot read pixels from "+SOURCE)
		quit(1)
		return
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)

	var big := scaled(image,256)
	var err: Error=big.save_png(PNG_PATH)
	print("ICON ",PNG_PATH," -> ",error_string(err))

	var blobs: Array = []
	for entry in ICO_IMAGES:
		var frame := scaled(image,int(entry.size))
		blobs.append(frame.save_png_to_buffer() if bool(entry.png) else bmp_frame(frame))
	err=write_ico(blobs)
	print("ICON ",ICO_PATH," -> ",error_string(err))
	print("ICON DONE")
	quit(0 if err==OK else 1)

func scaled(source: Image, size: int) -> Image:
	var copy := source.duplicate()
	if copy.get_width()!=size:
		copy.resize(size,size,Image.INTERPOLATE_LANCZOS)
	return copy

# A classic .ico frame: a BITMAPINFOHEADER whose height is doubled to make room
# for the XOR colour rows followed by the AND mask (1 bit per pixel).
func bmp_frame(image: Image) -> PackedByteArray:
	var size := image.get_width()
	var header := PackedByteArray()
	header.resize(40)
	header.encode_u32(0,40)
	header.encode_s32(4,size)
	header.encode_s32(8,size*2)
	header.encode_u16(12,1)
	header.encode_u16(14,32)
	header.encode_u32(20,size*size*4)
	var rows := PackedByteArray()
	rows.resize(size*size*4)
	var mask_stride := ((size+31)/32)*4
	var mask := PackedByteArray()
	mask.resize(mask_stride*size)
	for y in size:
		var target_y := size-1-y
		for x in size:
			var colour: Color=image.get_pixel(x,y)
			var at := (target_y*size+x)*4
			var alpha := int(round(colour.a*255.0))
			# .ico colour data is premultiplied by its own alpha channel.
			rows[at]=int(round(colour.b*255.0*colour.a))
			rows[at+1]=int(round(colour.g*255.0*colour.a))
			rows[at+2]=int(round(colour.r*255.0*colour.a))
			rows[at+3]=alpha
			if alpha<128:
				var bit := target_y*mask_stride*8+x
				mask[bit/8]|=1<<(7-(bit%8))
	return header+rows+mask

func write_ico(blobs: Array) -> Error:
	var header := PackedByteArray()
	header.resize(6)
	header.encode_u16(0,0)
	header.encode_u16(2,1)
	header.encode_u16(4,blobs.size())
	var directory := PackedByteArray()
	directory.resize(16*blobs.size())
	var offset := 6+16*blobs.size()
	for i in blobs.size():
		var blob: PackedByteArray=blobs[i]
		var size := int(ICO_IMAGES[i].size)
		var at := i*16
		directory[at]=0 if size>=256 else size
		directory[at+1]=0 if size>=256 else size
		directory[at+2]=0
		directory[at+3]=0
		directory.encode_u16(at+4,1)
		directory.encode_u16(at+6,32)
		directory.encode_u32(at+8,blob.size())
		directory.encode_u32(at+12,offset)
		offset+=blob.size()
	var file := FileAccess.open(ICO_PATH,FileAccess.WRITE)
	if file==null:
		return FileAccess.get_open_error()
	file.store_buffer(header)
	file.store_buffer(directory)
	for blob in blobs:
		file.store_buffer(blob)
	file.close()
	return OK
