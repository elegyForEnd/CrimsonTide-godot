extends SceneTree
## 资源引用体检：把「二进制场景/光照贴图里写死的 res:// 路径」「美术取图口会拼出来的
## 文件名」「所有武器特效原画」逐条查存在性。
##
## 为什么需要它（2026-10-22 的事故）：清理 55 个 `scenes/story/*.exr` 时，文本搜 uid 与
## `.exr` 都是 0 命中，看起来"没人用"；实际引用藏在二进制的 `.lmbake`（LightmapGIData）
## 里——删掉后 `.lmbake` → `.scn` → 整个故事模式切片全部加载失败，故事地图整块消失。
## `*.scn` / `*.lmbake` 是二进制，**永远别用"文本搜不到"当删除依据**，用这个测试兜底。
##
## 运行：
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/asset_refs.gd
## 退出码 0 = 全部命中；非 0 = 有缺件（缺件逐条打印成 MISSING）。

const HuntArt = preload("res://scripts/hunt/hunt_art.gd")
const HuntData = preload("res://scripts/hunt/hunt_data.gd")
const WeaponArt = preload("res://scripts/weapon_image_art.gd")

## 这些目录里的 res:// 字符串不是运行期依赖：构建产物、导出包、老截图、导入缓存。
const SKIP_DIRS := ["res://.godot", "res://build", "res://dist", "res://output",
	"res://generated", "res://.testappdata", "res://assets/vendor"]

## 只认到已知后缀为止：二进制字符串表里路径后面紧跟的字节可能是任意 ASCII，
## 见后缀就截断，避免把垃圾字节拼进路径造成假红。⚠️ `gdshader` 必须排在 `gd` 前面，
## 否则正则会把 `story_occlusion.gdshader` 截成 `story_occlusion.gd`（假红）。
const REF_PATTERN := "res://[A-Za-z0-9_./%-]+\\.(?:gdshader|png|jpg|jpeg|webp|svg|exr|scn|lmbake|tscn|tres|res|gd|ttf|otf|ogg|wav|json|cfg)"

## 脚本字面量只有当它以「已知后缀」结尾时才算静态资源引用；拼接用的前缀
## （`res://assets/audio/bosses/queen-`、`res://scripts` 这类目录名）留给运行期。
const KNOWN_EXT := ["gdshader", "png", "jpg", "jpeg", "webp", "svg", "exr", "scn", "lmbake",
	"tscn", "tres", "res", "gd", "ttf", "otf", "ogg", "wav", "json", "cfg"]

var checks := 0
var failures := 0
var missing: Array = []

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		missing.append(reason)
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check_binary_references()
	check_script_literals()
	check_hunt_art()
	check_weapon_art()
	check_story_slices()
	if failures > 0:
		print("--- MISSING (" + str(failures) + ") ---")
		for entry in missing:
			print("MISSING ", entry)
	print("ASSET REFS: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

# --- ① 二进制/文本资源里写死的路径 --------------------------------------------------

## `.scn`（烘焙场景）/`.lmbake`（光照贴图）/`.tscn`/`.tres` 里带 `res://` 的字符串都要
## 能落到磁盘上。二进制按 ASCII 扫：Godot 的字符串表是明文 UTF-8。
func check_binary_references() -> void:
	var re := RegEx.new()
	re.compile(REF_PATTERN)
	var files := scan_files("res://", [".scn", ".lmbake", ".tscn", ".tres", ".res"])
	check(files.size() >= 200, "binary/text resources scanned (" + str(files.size()) + ")")
	var refs := 0
	for path in files:
		var text := FileAccess.get_file_as_bytes(path).get_string_from_ascii()
		for found in re.search_all(text):
			var ref := found.get_string()
			if skip_reference(ref):
				continue
			refs += 1
			check(FileAccess.file_exists(ref), path + " -> " + ref)
	check(refs >= 1000, "binary/text references resolved (" + str(refs) + ")")
	print("[asset_refs] resources=", files.size(), " refs=", refs)

## 故事切片的 `.lmbake` 是这次事故的中心：缺一份光照贴图，整份 `.scn` 一起废。
func check_story_lightmaps() -> void:
	var bakes := scan_files("res://scenes/story", [".lmbake"])
	check(bakes.size() >= 50, "story lightmaps found (" + str(bakes.size()) + ")")
	for path in bakes:
		check(ResourceLoader.load(path) != null, "story lightmap loads: " + path)

# --- ② 脚本里写死的路径 -------------------------------------------------------------

func check_script_literals() -> void:
	var re := RegEx.new()
	re.compile("\"(res://[^\"]+)\"")
	var files := scan_files("res://scripts", [".gd"]) + scan_files("res://tests", [".gd"])
	check(files.size() > 200, "scripts scanned (" + str(files.size()) + ")")
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for found in re.search_all(text):
			var ref := found.get_string(1)
			# 动态拼出来的（`%d`/`%s`/数组下标）留给运行期，测试只钉死常量。
			if "%" in ref or "{" in ref or ref.ends_with("/") or skip_reference(ref):
				continue
			if not has_known_extension(ref):
				continue
			check(FileAccess.file_exists(ref), path + " -> " + ref)

# --- ③ 搜打撤美术取图口 -------------------------------------------------------------

## `hunt_art.gd` 是「kind → 路径」的唯一解析口；它拼出来的每一张都必须在。
## 2026-10-22 用户报「别人的电脑上搜打撤地图丢了」——地图、图标表、地区背景、敌人
## 立绘这里全部点名，缺哪张一眼看到。
func check_hunt_art() -> void:
	check(FileAccess.file_exists(HuntArt.HUNT + "map/region_map.png"), "hunt region map exists")
	for sheet in HuntArt.ICON_SHEETS:
		for kind in HuntArt.ICON_SHEETS[sheet]:
			check(FileAccess.file_exists(HuntArt.hunt_icon_path(str(kind))), "hunt icon: " + str(kind))
	for area in HuntData.AREAS:
		for phase in ["day", "dusk", "night"]:
			var path := "%s%s_%s.png" % [HuntArt.BG_DIR, str(area), phase]
			check(FileAccess.file_exists(path), "hunt background: " + path)
	for kind in HuntData.ENEMIES:
		var path := "%s%s_sheet_r1c1.png" % [HuntArt.ENEMY_DIR, str(kind)]
		check(FileAccess.file_exists(path), "hunt enemy art: " + str(kind))
	for name in ["search-probe_alpha.png", "rune-dial_alpha.png", "seal-success_alpha.png", "seal-fail_alpha.png"]:
		check(FileAccess.file_exists(HuntArt.UI_DIR + name), "hunt ui asset: " + name)

# --- ④ 武器特效原画 ----------------------------------------------------------------

## `weapon_image_art.gd` 的 `available(index)` 要求 `weapon_<id>_release.png` 在；
## 缺一张 = 那把武器没有任何特效原画（用户报「别的电脑上部分武器特效丢失」）。
func check_weapon_art() -> void:
	var ids: Array = []
	for i in range(600, 648):
		ids.append(i)
	for i in WeaponArt.CAMPAIGN_MAP:
		ids.append(int(i))
	for id in ids:
		var path := WeaponArt.BASE + "weapon_%d_release.png" % int(id)
		check(FileAccess.file_exists(path), "weapon release art: " + path)
	for hero in 4:
		for cue in ["dash", "charge", "ultimate"]:
			var path := "res://assets/combat/imagegen/hero_%d_%s.png" % [hero, cue]
			check(FileAccess.file_exists(path), "hero effect art: " + path)

# --- ⑤ 故事切片真的能加载 -----------------------------------------------------------

## 这是「故事模式地图丢失」最直接的一条：`.scn` 只要有一个 ext_resource 加载失败，
## 整份 PackedScene 就是 null（`story_environment.populate_chunk()` 现在会兜住并告警，
## 但地图已经没了）。所以这里逐份 load，再挑一份实例化数网格，确认真有几何体。
func check_story_slices() -> void:
	check_story_lightmaps()
	var slices := scan_files("res://scenes/story", [".scn"])
	check(slices.size() >= 40, "story slices found (" + str(slices.size()) + ")")
	for path in slices:
		var packed := ResourceLoader.load(path)
		check(packed != null, "story slice loads: " + path)
	var sample := ResourceLoader.load("res://scenes/story/opening-0.scn")
	if sample != null:
		var node: Node = sample.instantiate()
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() > 50, "story slice has geometry (" + str(meshes.size()) + ")")
		print("[asset_refs] slices=", slices.size(), " opening-0 meshes=", meshes.size())
		node.free()

# --- 工具 ---------------------------------------------------------------------------

func skip_reference(path: String) -> bool:
	if path.contains(".godot/") or path.contains("build/") or path.contains("output/") or path.contains("dist/"):
		return true
	return false

func has_known_extension(path: String) -> bool:
	return path.get_extension().to_lower() in KNOWN_EXT

## 递归列出 `dir` 下指定扩展名的文件（跳过 SKIP_DIRS 与隐藏目录）。
func scan_files(dir_path: String, exts: Array) -> Array:
	var out: Array = []
	for skip in SKIP_DIRS:
		if dir_path == skip or dir_path.begins_with(skip + "/"):
			return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var path := dir_path.path_join(name)
		if dir.current_is_dir():
			out.append_array(scan_files(path, exts))
		else:
			for ext in exts:
				if name.ends_with(str(ext)):
					out.append(path)
					break
		name = dir.get_next()
	dir.list_dir_end()
	return out
