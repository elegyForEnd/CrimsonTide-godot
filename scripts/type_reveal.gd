extends RefCounted
## 故事台词逐字显示的节奏器（纯状态机，不碰节点与音频）。
##
## 为什么单独抽出来：
## - 旧写法是 `revealed += dt * speed` 后取整，一帧可能跳 0 或 2 个字，音效没法与
##   “落下的那一个字”对齐；这里保证**每次只放出一个字**，主人再把它抄进
##   `RichTextLabel.visible_characters`。
## - 标点停顿、换行停顿与轻微的人类节奏抖动都在这里算，测试可以喂 dt 精确断言。
## - 声音只是 `on_char(index, ch)` 回调，开关/音量由调用方决定，节奏器本身不依赖音频。

const START_DELAY := 0.07          ## 页面刚出现时先给画面一点反应时间
const JITTER_LOW := 0.92           ## 逐字间隔的抖动下界（模拟手打，不是节拍器）
const JITTER_HIGH := 1.10
const PAUSE_PERIOD := 3.4          ## 。！？… 之后的停顿倍数
const PAUSE_COMMA := 1.9           ## ，、；： 之后的停顿倍数
const PAUSE_BREAK := 4.0           ## 换行后的停顿倍数
const PAUSE_SPACE := 0.55          ## 空格本身不占停顿，反而略快过去

var text := ""
var total := 0
var revealed := 0
var finished := true
var cps := 35.0
var on_char: Callable = Callable()   ## (index: int, ch: String) 每个新字回调一次
var on_done: Callable = Callable()   ## 整页放完后回调一次

var _clock := 0.0
var _next := 0.0
var _rng := RandomNumberGenerator.new()

## 开始一页。`count` 用 RichTextLabel.get_total_character_count()，这样 BBCode
## 之类的不可见字符不会算进节奏；`seed_value` 固定后同一页每次重读的抖动一致。
func begin(value: String, count: int, speed: float, seed_value: int = 0) -> void:
	text=value
	total=maxi(0,count)
	revealed=0
	cps=clampf(speed,1.0,200.0)
	finished=total==0
	_clock=0.0
	_next=START_DELAY
	_rng.seed=seed_value

## 推进 dt 秒，返回本帧真正“落下”的字数（0/1/2…）。主人据此更新 visible_characters，
## 需要的话还能做每字一次的红点/呼吸之类的小反馈。
func tick(dt: float) -> int:
	if finished or dt<=0.0: return 0
	_clock+=dt
	var steps:=0
	while not finished and _clock>=_next:
		_clock-=_next
		var index:=revealed
		revealed+=1
		steps+=1
		if on_char.is_valid() and index<text.length():
			on_char.call(index,text.substr(index,1))
		if revealed>=total:
			finished=true
			_next=INF
			if on_done.is_valid(): on_done.call()
			break
		_next=_interval_after(text.substr(revealed-1,1))
	return steps

## 点击/空格/快进：立刻放完，不再逐字回调（否则一次点击会刷满一串音效）。
func finish() -> void:
	revealed=total
	finished=true
	_next=INF
	_clock=0.0

## 给 RichTextLabel.visible_characters 用：-1 = 全显。
func shown() -> int:
	return -1 if finished else revealed

func ratio() -> float:
	if total<=0: return 1.0
	return clampf(float(revealed)/float(total),0.0,1.0)

func _interval_after(previous: String) -> float:
	var base:=1.0/cps
	if previous.contains("\n"):
		base*=PAUSE_BREAK
	elif previous.contains("。") or previous.contains("！") or previous.contains("？") or previous.contains("…"):
		base*=PAUSE_PERIOD
	elif previous.contains("，") or previous.contains("、") or previous.contains("；") or previous.contains("："):
		base*=PAUSE_COMMA
	elif previous==" ":
		base*=PAUSE_SPACE
	return base*_rng.randf_range(JITTER_LOW,JITTER_HIGH)
