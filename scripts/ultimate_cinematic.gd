class_name UltimateCinematic
extends Control
## Independent viewport layer: never inherits the HUD's fixed-size letterboxing.
## Original cinematic text is independent of the licensed spoken recordings.
const INVOCATIONS := [
	{
		"charge":{"ja":"紅き月よ、我が刃に宿れ！","zh":"绯红之月，寄宿于我刃！"},
		"burst":{"ja":"奥義、紅蓮月華！","zh":"奥义——红莲月华！"},
		"short":{"ja":"紅蓮月華！","zh":"红莲月华！"}
	},
	{
		"charge":{"ja":"星の祝福よ、この夜を照らせ！","zh":"群星的祝福，照亮此夜！"},
		"burst":{"ja":"聖域展開、暁の祈り！","zh":"圣域展开——拂晓之祈！"},
		"short":{"ja":"暁の祈り！","zh":"拂晓之祈！"}
	},
	{
		"charge":{"ja":"終焉を告げる、黒き翼よ！","zh":"宣告终焉的漆黑羽翼！"},
		"burst":{"ja":"禁式解放、夜鴉断罪！","zh":"禁式解放——夜鸦断罪！"},
		"short":{"ja":"夜鴉断罪！","zh":"夜鸦断罪！"}
	},
	{
		"charge":{"ja":"冥府の炎よ、我が名を刻め！","zh":"冥府之炎，刻下我的名字！"},
		"burst":{"ja":"死霊奥義、冥火剣雨！","zh":"死灵奥义——冥火剑雨！"},
		"short":{"ja":"冥火剣雨！","zh":"冥火剑雨！"}
	}
]
signal burst
signal ended(interrupted: bool)
signal began(hero: int, online: bool)
var age := 0.0
var duration := 0.85
var hero := 0
var active := false
var owns_pause := false
var fired := false
var art: Array[AtlasTexture] = []
var face: Font = preload("res://assets/NotoSerifSC.ttf")
var fx: Texture2D = preload("res://assets/combat/vfx-atlas.png")
var light: Node2D
var captions: Node2D
var voice_info: Array = []
var impact_time := 1.872

func _ready() -> void:
	voice_info=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voices/voice-manifest.json")).heroes
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents=true
	var sheet: Texture2D=load("res://assets/combat/ultimate-cg.png")
	# One cut-in row per hero in the catalog; the sheet grows a row per recruit.
	var row := sheet.get_height()/float(maxi(1,Catalog.HEROES.size()))
	for i in Catalog.HEROES.size():
		var frame := AtlasTexture.new()
		frame.atlas=sheet
		frame.region=Rect2(0,i*row+2,sheet.get_width(),row-4)
		frame.filter_clip=true
		art.append(frame)
	light=Node2D.new()
	var additive := ShaderMaterial.new()
	additive.shader=preload("res://resources/combat_glow.gdshader")
	light.material=additive
	light.draw.connect(draw_light)
	add_child(light)
	captions=Node2D.new()
	captions.z_index=2
	captions.draw.connect(draw_captions)
	add_child(captions)
	visible=false

func play(character: int, online: bool) -> void:
	if active:
		return
	hero=clampi(character,0,Catalog.HEROES.size()-1)
	# A hero whose lines are a silent placeholder has no recorded length to hold
	# the cut-in for, so its own charge and burst times read as zero and the same
	# short cut-in the online path uses is played instead. The subtitles still
	# show; nothing is spoken.
	var charge := _voice_time("charge_time")
	var burst := _voice_time("burst_time")
	var spoken := charge+burst>0.05
	duration=TideSession.ONLINE_ULTIMATE_DURATION if (online or not spoken) else charge+burst
	impact_time=.612 if (online or not spoken) else charge
	age=0.0
	fired=false
	active=true
	visible=true
	owns_pause=not online and not get_tree().paused
	if owns_pause:
		get_tree().paused=true
	began.emit(hero,online)
	queue_redraw()
	light.queue_redraw()
	captions.queue_redraw()

# The recorded length of one of this hero's lines, or 0 when the manifest has
# nothing to measure — either no entry at all or a placeholder bank.
func _voice_time(key: String) -> float:
	if hero<0 or hero>=voice_info.size():
		return 0.0
	var entry=voice_info[hero]
	if not entry is Dictionary or not bool(entry.get("voice_ready",true)):
		return 0.0
	return float(entry.get(key,0.0))

func stop(interrupted: bool = true) -> void:
	var was_active := active
	active=false
	visible=false
	if owns_pause:
		get_tree().paused=false
	owns_pause=false
	if was_active:
		ended.emit(interrupted)

func _exit_tree() -> void:
	if owns_pause:
		get_tree().paused=false

func _input(event: InputEvent) -> void:
	if not active:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		stop()
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not active:
		return
	age+=dt
	if age>=impact_time and not fired:
		fired=true
		burst.emit()
	if age>=duration:
		stop(false)
	queue_redraw()
	light.queue_redraw()
	captions.queue_redraw()

func visual_progress() -> float:
	return .72*age/impact_time if age<=impact_time else .72+.28*(age-impact_time)/maxf(.01,duration-impact_time)

func _draw() -> void:
	if not active:
		return
	var t := visual_progress()
	var fade := 1.0-smoothstep(0.86,1.0,t)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.008,0.004,0.02,fade))
	var tex := art[hero]
	var base := maxf(size.x/tex.get_width(),size.y/tex.get_height())
	var zoom := 1.12-0.10*smoothstep(0,0.72,t)+0.06*smoothstep(0.72,1,t)
	var extent := tex.get_size()*base*zoom
	var shake := Vector2(sin(age*82),cos(age*67))*8*exp(-absf(t-0.73)*45)
	var origin := (size-extent)*0.5+Vector2(42*(1-smoothstep(0,0.18,t)),0)+shake
	draw_texture_rect(tex,Rect2(origin,extent),false,Color(1,1,1,fade))
	# Iris-like opening and cinematic bars frame the portrait without cropping atlas rows.
	var bars := size.y*lerpf(0.48,0.055,smoothstep(0,0.13,t))
	draw_rect(Rect2(0,0,size.x,bars),Color(0.008,0.004,0.015,fade))
	draw_rect(Rect2(0,size.y-bars,size.x,bars),Color(0.008,0.004,0.015,fade))
	var flash := 0.48*exp(-absf(t-0.035)*100)+0.65*exp(-absf(t-0.74)*95)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.85,0.92,1,flash*fade))

func draw_captions() -> void:
	if not active:
		return
	var t := visual_progress()
	var fade := 1.0-smoothstep(0.86,1.0,t)
	var tint := Catalog.HEROES[hero].color as Color
	var reveal := smoothstep(0.10,0.26,t)*fade
	var unit := minf(size.x/1440,size.y/900)
	var at := Vector2(size.x*0.065-35*(1-reveal),size.y*0.77)
	var title := str(Catalog.HEROES[hero].skill)
	# Dialogue is above additive VFX and the flash, with a quiet readable backing.
	captions.draw_rect(Rect2(size*Vector2(.048,.655),size*Vector2(.55,.28)),Color(.012,.008,.025,.72*reveal))
	captions.draw_string(face,at+Vector2(3,4),title,HORIZONTAL_ALIGNMENT_LEFT,-1,int(66*unit),Color(0.02,0,0.03,reveal))
	captions.draw_string(face,at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,int(66*unit),Color(1,0.96,0.91,reveal))
	captions.draw_string(face,at-Vector2(0,70*unit),str(Catalog.HEROES[hero].name)+"  /  奥义解放",HORIZONTAL_ALIGNMENT_LEFT,-1,int(22*unit),Color(tint, reveal))
	var dialogue: Dictionary=INVOCATIONS[hero]["burst" if fired else "charge"]
	if duration<1.0:
		dialogue=INVOCATIONS[hero]["short"]
	captions.draw_string(face,Vector2(size.x*.067,size.y*.86),str(dialogue.ja),HORIZONTAL_ALIGNMENT_LEFT,-1,int(25*unit),Color(1,.97,.93,reveal))
	captions.draw_string(face,Vector2(size.x*.067,size.y*.905),str(dialogue.zh),HORIZONTAL_ALIGNMENT_LEFT,-1,int(20*unit),Color(.85,.88,.96,reveal))
	captions.draw_string(face,Vector2(size.x-240*unit,size.y-22*unit),"任意键 / 点击跳过",HORIZONTAL_ALIGNMENT_LEFT,-1,int(16*unit),Color(0.9,0.9,1,fade*0.75))

func stamp(cell: int, at: Vector2, extent: Vector2, angle: float, tint: Color) -> void:
	var unit := fx.get_size()/3.0
	light.draw_set_transform(at,angle)
	light.draw_texture_rect_region(fx,Rect2(-extent/2,extent),Rect2(Vector2(cell%3,cell/3)*unit+Vector2.ONE*4,unit-Vector2.ONE*8),tint)
	light.draw_set_transform(Vector2.ZERO)

func draw_light() -> void:
	if not active:
		return
	var t := visual_progress()
	var envelope := smoothstep(0,0.12,t)*(1-smoothstep(0.8,1,t))
	var color: Color=Catalog.HEROES[hero].color
	var unit := size.x/1440
	# Textured moving layers add depth beyond the painted CG: rotating sigil,
	# expanding shockwave, sweeping flares, drifting embers and an impact bloom.
	stamp(3,size*Vector2(0.72,0.48),Vector2.ONE*size.y*0.95,age*0.12,Color(color,0.16*envelope))
	stamp(7,size*0.5,Vector2(size.x*1.8,size.y*1.3)*lerpf(0.3,1.5,t),-0.2,Color(color,0.3*envelope))
	for i in 42:
		var phase := fposmod(i*0.618+age*(0.09+0.015*(i%5)),1.0)
		var at := Vector2(fposmod(i*197.3+age*40,size.x),size.y*(1-phase))
		stamp(5,at,Vector2(16+float(i%4)*7,9)*unit,-0.6,Color(color,envelope*sin(phase*PI)*0.7))
	for i in 3:
		stamp(2,Vector2(size.x*(t*1.6-0.3),size.y*(0.25+i*0.26)),Vector2(size.x*0.85,36*unit),-0.22,Color(color,0.35*envelope))
	var impact := exp(-absf(t-0.74)*28)
	stamp(4,size*Vector2(0.66,0.46),Vector2.ONE*size.y*(0.9+t),age*0.2,Color(color,impact*0.8))
