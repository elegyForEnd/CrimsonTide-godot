extends SceneTree
## 故事台词逐字节奏器的无头回归：只喂 dt，不依赖窗口、音频或存档。
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func make_reveal(text: String, cps: float, seed_value: int):
	var typer=load("res://scripts/type_reveal.gd").new()
	typer.begin(text,text.length(),cps,seed_value)
	return typer

func timeline(text: String, cps: float, seed_value: int) -> Array:
	var typer=make_reveal(text,cps,seed_value)
	var times: Array=[]
	# GDScript 的 lambda 按值捕获局部变量；用单元素数组当可变时钟。
	var clock := [0.0]
	typer.on_char=func(_index: int,_glyph: String):
		times.append(clock[0])
	for step in 4000:
		clock[0]+=0.001
		typer.tick(0.001)
		if typer.finished: break
	return times

func run() -> void:
	# --- one character at a time, never a whole line in one frame --------------
	var typer=make_reveal("血潮。第二行",30.0,1234)
	check(typer.total==6,"CJK text counts one character per glyph")
	check(typer.revealed==0 and not typer.finished and typer.shown()==0,"a page starts empty")
	check(typer.ratio()==0.0,"start ratio is zero")
	check(typer.tick(0.0)==0,"zero dt reveals nothing")
	check(typer.tick(0.05)==0,"the small start delay keeps the first glyph back")
	check(typer.tick(0.03)==1,"the first glyph lands once the delay elapses")
	check(typer.shown()==1,"visible_characters follows the state machine")
	var ticks:=0
	while not typer.finished and ticks<2000:
		typer.tick(0.005); ticks+=1
	check(typer.finished,"the page eventually completes")
	check(typer.revealed==typer.total,"every glyph is revealed")
	check(typer.shown()==-1,"a finished page asks RichTextLabel for the full text")
	check(typer.tick(1.0)==0,"a finished page ignores further dt")

	# --- callbacks: exactly one per glyph, no sound flood on click -------------
	var seen: Array=[]
	var done := [0]
	var cb=make_reveal("灯火还在。",40.0,99)
	cb.on_char=func(index: int,glyph: String): seen.append([index,glyph])
	cb.on_done=func(): done[0]+=1
	var frame:=0
	while not cb.finished and frame<1000:
		cb.tick(0.004); frame+=1
	check(seen.size()==cb.total,"on_char fires once per revealed glyph")
	check(done[0]==1,"on_done fires exactly once")
	check(seen[0][0]==0 and seen[0][1]=="灯","the callback carries the real glyph index and text")
	check(seen[seen.size()-1][0]==cb.total-1,"the last callback is the final glyph")
	var last_count:=seen.size()
	cb.tick(1.0)
	check(seen.size()==last_count,"finished pages do not re-emit glyphs")

	var skipped=make_reveal("这一整页都会在一瞬间放完。",30.0,5)
	var skipped_calls: Array=[]
	skipped.on_char=func(index: int,_glyph: String): skipped_calls.append(index)
	skipped.tick(0.1)
	skipped.finish()
	check(skipped.finished and skipped.shown()==-1,"finish() jumps to the fully visible state")
	var after_skip:=skipped_calls.size()
	skipped.tick(2.0)
	check(skipped_calls.size()==after_skip,"a click-to-finish does not replay all remaining glyphs")

	# --- punctuation and line breaks are pauses, not extra characters ---------
	var plain=timeline("甲乙丙丁",20.0,7)
	var paused=timeline("甲，乙丙丁",20.0,7)
	check(plain.size()==4 and paused.size()==5,"punctuation stays a real glyph")
	check(paused.size()>=3,"the comma page produces a timeline")
	check(paused[2]-paused[1]>(plain[2]-plain[1])*1.4,"a comma holds longer than an ordinary glyph")
	var broken=timeline("甲乙\n丙丁",20.0,7)
	check(broken[3]-broken[2]>broken[2]-broken[1],"a line break holds longer than an ordinary glyph")

	# --- deterministic per page: re-reading the same page has the same rhythm --
	var a=timeline("同一页应该有一致的节奏。",25.0,4242)
	var b=timeline("同一页应该有一致的节奏。",25.0,4242)
	check(a==b,"the same seed reproduces the same reveal timeline")
	var c=timeline("同一页应该有一致的节奏。",25.0,4243)
	check(a!=c,"a different page seed may breathe differently")

	# --- edge cases -----------------------------------------------------------
	var empty=make_reveal("",0,0)
	check(empty.finished and empty.shown()==-1,"an empty page is complete immediately")
	check(empty.tick(1.0)==0,"an empty page never emits glyphs")
	var slow=timeline("字",5.0,1)
	check(slow.size()==1,"a single glyph is still delivered")

	print("TYPE_REVEAL %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
