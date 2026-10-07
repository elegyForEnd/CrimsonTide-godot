extends SceneTree
## Builds the wide "远征行囊 / 守夜人仓库" backdrop placeholder out of the existing
## gothic panel art, so the camp bag panel can show the carried kit and the 15x15
## vault side by side.
##
## This is a **placeholder**: it recomposes `assets/ui/extraction-inventory-v2.png`
## (outer frame, gold rails, plain leather) into a three-column layout. Swap in a
## purpose-drawn image of the same 1536x1024 canvas later; the panel only cares about
## the file name, the canvas and the column positions listed below.
##
## The three columns are where `scripts/camp_pack.gd` draws its content, converted to
## the panel's on-screen space with `drawn = panel_origin + source * 1368/1536`:
##   portrait / worn kit : source x 145..470   -> drawn x 165..454
##   carried grids       : source x 524..806   -> drawn x 503..754
##   vault (15x15)       : source x 860..1396  -> drawn x 802..1280
##
## Usage:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/make_camp_pack_backdrop.gd

const SOURCE := "res://assets/ui/extraction-inventory-v2.png"
const TARGET := "res://assets/ui/camp-pack-vault-v1.png"

const TOP_BAND := 132
const BOTTOM_BAND := 176
const RAIL_LEFT := 145
const RAIL_RIGHT := 1398
const DIVIDER := 54
const DIVIDER_A := 470
const DIVIDER_B := 806
const VAULT_INSET := Rect2i(864,164,528,664)

var source_path := ""
var target_path := ""
var source: Image

func _initialize() -> void:
	# res:// is read-only for the PNG saver, so the tool works on native paths.
	source_path=ProjectSettings.globalize_path(SOURCE)
	target_path=ProjectSettings.globalize_path(TARGET)
	source=Image.load_from_file(source_path)
	if source == null:
		push_error("cannot read "+source_path)
		quit(1)
		return
	var width := source.get_width()
	var height := source.get_height()
	var interior := Rect2i(RAIL_LEFT,TOP_BAND,RAIL_RIGHT-RAIL_LEFT,height-TOP_BAND-BOTTOM_BAND)
	var out := source.duplicate() as Image
	# 1. Glaze the whole interior with plain leather: every ornament inside the frame
	#    is replaced so the three columns start from a clean surface.
	fill(out,interior)
	# 2. Put the frame back: the top and bottom rails already span the full width, so
	#    the corner gems survive untouched.
	blit(out,Rect2i(0,0,width,TOP_BAND),Vector2i.ZERO)
	blit(out,Rect2i(0,height-BOTTOM_BAND,width,BOTTOM_BAND),Vector2i(0,height-BOTTOM_BAND))
	blit(out,Rect2i(0,0,RAIL_LEFT,height),Vector2i.ZERO)
	blit(out,Rect2i(RAIL_RIGHT,0,width-RAIL_RIGHT,height),Vector2i(RAIL_RIGHT,0))
	# 3. Two copies of the source's gold rail separate the three columns.
	var strip := find_divider()
	var rail := Rect2i(strip-DIVIDER/2,TOP_BAND,DIVIDER,height-TOP_BAND-BOTTOM_BAND)
	blit(out,rail,Vector2i(DIVIDER_A,TOP_BAND))
	blit(out,rail,Vector2i(DIVIDER_B,TOP_BAND))
	# 4. A recessed inset so the vault region reads as a cabinet rather than bare wall.
	inset(out,VAULT_INSET)
	var error := out.save_png(target_path)
	if error != OK:
		push_error("cannot write "+target_path+" ("+str(error)+")")
		quit(1)
		return
	print("wrote ",TARGET,"  ",out.get_width(),"x",out.get_height(),"  divider source column ",strip)
	quit(0)

## A plain, ornament-free slab of the source's leather, tiled over the interior.
const PATCH := Rect2i(560,180,400,640)

func fill(out: Image, region: Rect2i) -> void:
	var patch := source.get_region(PATCH)
	var y := 0
	while y < region.size.y:
		var x := 0
		while x < region.size.x:
			var take := Vector2i(mini(PATCH.size.x,region.size.x-x),mini(PATCH.size.y,region.size.y-y))
			out.blit_rect(patch,Rect2i(Vector2i.ZERO,take),region.position+Vector2i(x,y))
			x += PATCH.size.x
		y += PATCH.size.y

func blit(out: Image, region: Rect2i, at: Vector2i) -> void:
	out.blit_rect(source,region,at)

## Draws a two-pixel inset rectangle, slightly darkened, around a region.
func inset(out: Image, region: Rect2i) -> void:
	for x in range(region.position.x,region.position.x+region.size.x):
		shade(out,Vector2i(x,region.position.y))
		shade(out,Vector2i(x,region.position.y+1))
		shade(out,Vector2i(x,region.position.y+region.size.y-2))
		shade(out,Vector2i(x,region.position.y+region.size.y-1))
	for y in range(region.position.y,region.position.y+region.size.y):
		shade(out,Vector2i(region.position.x,y))
		shade(out,Vector2i(region.position.x+1,y))
		shade(out,Vector2i(region.position.x+region.size.x-2,y))
		shade(out,Vector2i(region.position.x+region.size.x-1,y))

func shade(out: Image, at: Vector2i) -> void:
	if at.x<0 or at.y<0 or at.x>=out.get_width() or at.y>=out.get_height():
		return
	var colour := out.get_pixelv(at)
	out.set_pixelv(at,Color(colour.r*0.5,colour.g*0.46,colour.b*0.54,colour.a))

## The source draws one vertical gold rail between the carried grids and the search
## column. Its exact column drifts with any re-export, so it is located by looking
## for the warmest, brightest column in the middle of the panel.
func find_divider() -> int:
	var width := source.get_width()
	var best := int(width*0.64)
	var best_score := -1.0
	for x in range(int(width*0.45),int(width*0.8)):
		var score := 0.0
		for y in range(220,760,7):
			var colour := source.get_pixel(x,y)
			score += colour.r+colour.g*0.72+colour.b*0.35
		if score>best_score:
			best_score=score
			best=x
	return best
