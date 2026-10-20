extends RefCounted
## 启动器的"现在能不能进游戏"自检：全局类缓存 + 资源导入产物。
##
## 与 `tools/check_class_cache.ps1` 是同一套规则的两份实现：
##   - 那份给**开发机/CI**用，全目录扫描（连 build/ 那种快照副本也扫，专门用来抓
##     "同一 class_name 被两份脚本声明"的遮蔽事故），并且每次启动都真跑一遍导入；
##   - 这份给**玩家用的启动器**，按 Godot 自己的口径跳过带 `.gdignore` 的目录，
##     并且带一个"指纹没变就别重算"的快通道。
## 两份的**判定口径必须成对改**：什么叫"缓存过期"、什么叫"重复类名"，改一边就
## 改另一边；`tests/launcher_env.gd` 钉住这份的行为。
##
## 本文件必须零依赖：不写 `class_name`、不 preload 别的脚本、不碰贴图。原因是它要
## 在**首次下载**时跑起来——那一刻 `.godot/` 还是空的，任何依赖全局类名或导入产物
## 的代码都可能解析失败，而它正是用来判断"要不要先导入"的那一个。
##
## 为什么要有快通道（实测数据，本机 NVMe）：
##   全量精确自检 = 遍历 188ms + 读 524 个 .gd 393ms + **读 2945 个 .import 2477ms**
##   （逐条 file_exists 只要 247ms，列一次 `.godot/imported` 只要 16ms）。
##   也就是说 3.4 秒里 2.5 秒花在"打开 2945 个小文件"上——在玩家机器上（更慢的盘、
##   更凶的杀毒）只会更久，而这是每次启动都要付的。所以：把一次**精确**自检的结论
##   连同当时的指纹写进 `user://`，下次启动先比指纹（遍历 188ms + 若干次 stat +
##   列一次目录 ≈ 250ms），指纹没变就直接采信上次的结论；指纹变了再走精确路径。
##
## 指纹覆盖：`.import` 数量、`.godot/imported` 条目数与目录 mtime、`.gd` 数量与最新
## mtime、类缓存文件的大小与 mtime。**已知覆盖不到的一种情况**：把一张已经导入过的
## 图"原地改内容、文件名不变"（条目数与目录 mtime 都不变）——那种情况归开发机的
## `Start-Game.cmd`（它每次都真跑导入）管，玩家侧不追。

const CACHE_PATH := "res://.godot/global_script_class_cache.cfg"
const IMPORT_DIR := "res://.godot/imported"
const LOG_PATH := "user://launcher-import.log"
const STAMP_PATH := "user://launcher-import.stamp"

## `scan()` 的返回：
##   ok             bool        能不能继续（false = 有导入修不好的问题）
##   need_import    bool        需要跑一次资源导入
##   duplicates     Dictionary  class_name -> [声明它的脚本]，重复声明（导入修不好）
##   missing_classes Array      缓存里没有的 class_name
##   missing_assets int         产物不在磁盘上的资源数
##   total_assets   int         需要导入的资源总数（进度条分母）
##   pending        Array       还缺的产物路径（收尾判定用）
##   pending_count  int         `pending` 的初始长度
##   cached         bool        这一份是快通道采信上次结论得来的（诊断用）
##   elapsed_ms     int         自检耗时（诊断/回归用）
static func scan(exact: bool = false) -> Dictionary:
	var started := Time.get_ticks_msec()
	var scripts: Array = []
	var imports: Array = []
	_walk("res://",scripts,imports)
	var fingerprint := _fingerprint(scripts,imports)

	if not exact:
		var remembered := _read_stamp()
		if _stamp_matches(remembered,fingerprint):
			return {
				"ok":bool(remembered.get("ok",true)),"need_import":false,
				"duplicates":{},"missing_classes":[],"missing_assets":0,
				"total_assets":imports.size(),"pending":[],"pending_count":0,
				"cached":true,"elapsed_ms":Time.get_ticks_msec()-started,
			}

	var out := _exact(scripts,imports)
	out["cached"]=false
	out["elapsed_ms"]=Time.get_ticks_msec()-started
	# ⚠️ 戳里记的必须是"这次精确自检的结论是**没事可做**"，不能只记 `ok`：
	# `ok` 只表示"没有导入修不好的问题"，需要导入时它同样是 true。记错了下次启动
	# 就会拿它当"不用导入"，直接带着空的类缓存进主场景（黑屏）。
	_write_stamp(fingerprint,bool(out["ok"]) and not bool(out["need_import"]))
	return out

## 精确路径：读脚本类名 + 读每份 `.import` 的产物路径并逐条查存在性。
static func _exact(scripts: Array, imports: Array) -> Dictionary:
	var out := {
		"ok":true,"need_import":false,"duplicates":{},"missing_classes":[],
		"missing_assets":0,"total_assets":imports.size(),"pending":[],"pending_count":0,
		"cached":false,"elapsed_ms":0,
	}
	# ① 谁声明了哪些全局类名。重复声明是导入修不好的：Godot 只会挑一个赢家，另一个
	#    被静默遮蔽，所以这一条必须让人看见（§11 的类缓存守卫就是这么来的）。
	var claims := {}
	for path in scripts:
		for name in class_names_in(path):
			if not claims.has(name):
				claims[name]=[]
			if not claims[name].has(path):
				claims[name].append(path)
	var duplicates := {}
	for name in claims:
		if claims[name].size()>1:
			duplicates[name]=claims[name]
	out["duplicates"]=duplicates

	# ② 缓存里有没有这些类名（口径与 .ps1 一致：整份缓存文本里出现过这个字符串）。
	var cache_text := ""
	if FileAccess.file_exists(CACHE_PATH):
		cache_text=FileAccess.get_file_as_string(CACHE_PATH)
	var missing: Array = []
	for name in claims:
		if not cache_text.contains("\"%s\"" % name):
			missing.append(name)
	missing.sort()
	out["missing_classes"]=missing

	# ③ 每个 `.import` 指到的产物还在不在。`dest_files` 是 JSON 数组，直接读出来逐条
	#    查存在性——**不**用"数一数 .godot/imported 有多少文件"那种估算，因为一次
	#    导入可能产出多个文件（.ctex 旁边还有 .md5），估算必错。
	#
	#    ⚠️ 源文件已经被删掉的 `.import` 残留必须跳过：它们**导入也修不好**
	#    （没有源可导），算进去就会让启动器陷入"导入 → 复查还缺 → 再导入"的死循环。
	#    本仓库实测就有 9 个这种残留（4 个 ultimate-*.wav、3 个 muyu 语音、
	#    2 张 3x-crystal*.png），源文件都不在了。
	var pending: Array = []
	for path in imports:
		var entry := import_entry_of(path)
		var source := str(entry.get("source",""))
		if not source.is_empty() and not FileAccess.file_exists(source):
			continue
		for dest in entry.get("dests",[]):
			if not FileAccess.file_exists(dest):
				pending.append(dest)
	out["pending"]=pending
	out["pending_count"]=pending.size()
	out["missing_assets"]=pending.size()

	# ④ 结论。缓存文件整个不存在（首次下载）也算过期。
	out["need_import"]=cache_text.is_empty() or not missing.is_empty() or not pending.is_empty()
	out["ok"]=duplicates.is_empty()
	return out

## 每个资源平均产出多少个 `.godot/imported` 条目。
##
## **实测**（2026-10-19 一次完整首导，4138 个资源）：7248 条目 / 4138 = **1.75**。
## 构成：贴图/音频/字体各产 1 份产物 + 1 份 `.md5`；`.glb`/`.fbx` 产 `.scn` + 一份
## 编辑器 folding `.cfg`。旧值 2.1（来自更早一次 6195/2945 的抽样）把分母撑大 20%，
## 结果是主进度条最多只爬到 **83%** 然后跳到 100%——"结尾猛跳一下"的真因。
const ENTRIES_PER_ASSET := 1.75

static func entries_per_asset() -> float:
	return ENTRIES_PER_ASSET

## 进度条用：0..1。
## ⚠️ 这里刻意**不**逐条查产物（`count_pending`）：首次下载时 pending 有近 3000 条，
## 一轮存在性检查实测 247ms，而轮询是每 0.35s 一次——那会把循环播放的 PV 卡成
## 幻灯片。改成列一次 `.godot/imported` 数条目（实测 16ms/7.2k 条）。进度条只要大致准，
## 真正的判定留给收尾那一次精确的 `count_pending`。
##
## `counts` 可以把 `entry_counts_by_type()` 的结果递进来，避免一次轮询列两遍目录。
static func progress(report: Dictionary, counts := {}) -> float:
	var total := maxf(1.0,float(report.get("total_assets",1)))
	if counts.is_empty():
		counts=entry_counts_by_type()
	var entries := 0
	for key in counts:
		entries+=int(counts[key])
	return clampf(float(entries)/ENTRIES_PER_ASSET/total,0.0,0.98)

## 子进度条用：一次列目录，返回"扩展名 → 条目数"（实测 16ms / 7.2k 条，0.35s 轮询负担得起）。
##
## 为什么要按类型分：首次导入的耗时**极不均匀**。实测 55 个 `.ctexarray`
## （1024×4096×2 切片、HDR BPTC 编码）串行跑了 **6.4 分钟**，占全程 11 分钟的 **58%**，
## 而它们只占资源总数的 **1.3%**——只按总条目数算进度时，主条在这 6 分钟里
## 从 0% 爬到 1.2%，玩家看到的就是"卡在 1%"。子条按阶段显示，才有可见的位移。
static func entry_counts_by_type(path: String = IMPORT_DIR) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(path)
	if dir==null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir():
			var ext := name.get_extension()
			out[ext]=int(out.get(ext,0))+1
		name=dir.get_next()
	dir.list_dir_end()
	return out

## 还缺的产物里"现在已经有了"的那些剔掉，返回剩下的数量。只对传进来的那一小份
## 列表做存在性检查，所以可以每半秒调一次。
static func count_pending(pending: Array) -> int:
	var left := 0
	for dest in pending:
		if not FileAccess.file_exists(dest):
			left+=1
	return left

## `.godot/imported` 里的条目数（一次目录列举，实测 16ms/6195 条）。
## `path` 可覆盖：回归测试用它验证"首次下载时这个目录还不存在"必须返回 0 而不是报错。
static func entry_count(path: String = IMPORT_DIR) -> int:
	var dir := DirAccess.open(path)
	if dir==null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		count+=1
		name=dir.get_next()
	dir.list_dir_end()
	return count

## 导入子进程：只有编辑器二进制能导入（`--import` 在 `--help` 里标的是 E）。
## 返回 pid，失败返回 -1；日志写到 `user://launcher-import.log`，失败时给玩家看尾巴。
static func start_import() -> int:
	var args := PackedStringArray([
		"--headless","--path",ProjectSettings.globalize_path("res://"),
		"--editor","--import",
		"--log-file",ProjectSettings.globalize_path(LOG_PATH),
	])
	return OS.create_process(OS.get_executable_path(),args)

## 导入日志的最后几行（给"导入失败"那张卡片用）。
static func log_tail(lines: int = 6) -> String:
	if not FileAccess.file_exists(LOG_PATH):
		return ""
	var all := FileAccess.get_file_as_string(LOG_PATH).split("\n")
	var out := PackedStringArray()
	for i in range(maxi(0,all.size()-1-lines),all.size()):
		var line: String = all[i].strip_edges()
		if not line.is_empty():
			out.append(line)
	return "\n".join(out)

## 读一个 `.import`，一次拿到源文件与产物清单：
##   {"source": "res://…", "dests": ["res://.godot/imported/…", …]}
## 只读一遍文件（精确自检 2.5 秒里绝大部分就是这个读，别读第二遍）。
static func import_entry_of(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var out := {"source":"","dests":[]}
	var at := text.find("source_file=")
	if at>=0:
		out["source"]=_json_line(text,at+12)
	at=text.find("dest_files=")
	if at>=0:
		var parsed = _json_line(text,at+11)
		if parsed is Array:
			out["dests"]=parsed
	return out

static func _json_line(text: String, from: int):
	var line := text.substr(from)
	var stop := line.find("\n")
	if stop>=0:
		line=line.substr(0,stop)
	return JSON.parse_string(line.strip_edges())

## 一份脚本里声明的全局类名（一行一个，可能有多个）。
static func class_names_in(path: String) -> Array:
	var out: Array = []
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return out
	for line in text.split("\n"):
		var found := _class_regex().search(line)
		if found:
			out.append(found.get_string(1))
	return out

static var _regex: RegEx

static func _class_regex() -> RegEx:
	if _regex==null:
		_regex=RegEx.new()
		_regex.compile("^\\s*class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	return _regex

# --- 指纹与快通道 -------------------------------------------------------------
# 指纹里每一项都是"变了就可能让上次结论失效"的东西：新增/删除资源（`.import` 数量、
# 导入目录条目数）、导入目录被动过（目录 mtime）、脚本增删改（`.gd` 数量与最新
# mtime）、类缓存被删/被重建（大小与 mtime）。

static func _fingerprint(scripts: Array, imports: Array) -> Dictionary:
	var newest_script := 0
	for path in scripts:
		newest_script=maxi(newest_script,FileAccess.get_modified_time(path))
	return {
		"import_count":imports.size(),
		"imported_entries":entry_count(),
		"script_count":scripts.size(),
		"script_mtime":newest_script,
		"cache_size":FileAccess.get_size(CACHE_PATH),
		"cache_mtime":FileAccess.get_modified_time(CACHE_PATH),
	}

static func _stamp_matches(remembered: Dictionary, fingerprint: Dictionary) -> bool:
	if remembered.is_empty() or not bool(remembered.get("ok",false)):
		return false
	for key in fingerprint:
		if not remembered.has(key):
			return false
		if int(remembered[key])!=int(fingerprint[key]):
			return false
	return true

static func _read_stamp() -> Dictionary:
	if not FileAccess.file_exists(STAMP_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STAMP_PATH))
	return parsed if parsed is Dictionary else {}

static func _write_stamp(fingerprint: Dictionary, ok: bool) -> void:
	var out := fingerprint.duplicate()
	out["ok"]=ok
	out["written_at"]=Time.get_unix_time_from_system()
	var file := FileAccess.open(STAMP_PATH,FileAccess.WRITE)
	if file==null:
		return
	file.store_string(JSON.stringify(out))
	file.close()

## 递归收集 `*.gd` 与 `*.import`。带 `.gdignore` 的目录整个跳过（Godot 自己也是这么
## 做的），隐藏目录（`.godot` / `.testappdata`）同样跳过。
static func _walk(dir_path: String, scripts: Array, imports: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir==null:
		return
	if dir.file_exists(".gdignore"):
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name=dir.get_next()
			continue
		var path := dir_path.path_join(name)
		if dir.current_is_dir():
			_walk(path,scripts,imports)
		elif name.ends_with(".gd"):
			scripts.append(path)
		elif name.ends_with(".import"):
			imports.append(path)
		name=dir.get_next()
	dir.list_dir_end()
