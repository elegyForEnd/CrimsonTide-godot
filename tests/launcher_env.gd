extends SceneTree

## 启动器自检（`scripts/launcher_env.gd`）回归。
##
## 这一份是"玩家侧"的类缓存/导入状态判定，与 `tools/check_class_cache.ps1` 同口径。
## 钉住的是四件事：
##   ① 在**已经导入好**的本仓库上，精确自检必须说"不用导入"（否则每次启动都白等）
##   ② **源文件已被删除的 `.import` 残留不能算进"缺产物"**——那会让启动器陷入
##      "导入 → 复查还缺 → 再导入"的死循环（本仓库实测有 9 个这种残留）
##   ③ 指纹快通道：一致就采信、任一项变了就不采信、目录 mtime 拿不到时不参与比较
##   ④ 解析器本身：class_name 抽取、`.import` 的源文件与 dest_files 抽取、进度折算
##
## 只读 + 只写 `user://launcher-import.stamp`（跑完删掉），不碰工程里的任何文件。

var checks := 0
var failures := 0

const Env = preload("res://scripts/launcher_env.gd")

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# 先清掉快通道戳，保证第一次一定是精确路径。
	if FileAccess.file_exists(Env.STAMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Env.STAMP_PATH))

	var exact := Env.scan(true)
	print("精确自检: ", exact.elapsed_ms, "ms  assets=", exact.total_assets,
		"  pending=", exact.pending_count, "  need_import=", exact.need_import,
		"  editor_feature=", OS.has_feature("editor"))
	check(exact.cached == false, "exact=true 走的是精确路径")
	check(exact.duplicates.is_empty(), "本仓库没有重复声明的 class_name")
	check(exact.ok, "本仓库没有导入修不好的问题")
	check(exact.need_import == false, "已导入好的仓库不该被判成需要导入（实测 pending=%d missing_classes=%d）" % [exact.pending_count, exact.missing_classes.size()])
	check(exact.pending_count == 0, "源文件还在的资源全都导入好了（实测缺 %d）" % exact.pending_count)
	check(exact.total_assets > 1000, "资源总数被数出来了（实测 %d）" % exact.total_assets)

	# 快通道：指纹没变就该采信上次结论，并且明显更快。
	var fast := Env.scan()
	print("快通道: ", fast.elapsed_ms, "ms  cached=", fast.cached)
	check(fast.cached, "第二次自检走快通道")
	check(fast.need_import == false, "快通道给出的结论同样是'不用导入'")
	check(fast.elapsed_ms * 4 < exact.elapsed_ms, "快通道明显更快（%dms vs %dms）" % [fast.elapsed_ms, exact.elapsed_ms])

	# 解析器：`.import` 的源文件 + 产物
	var entry := Env.import_entry_of("res://assets/NotoSerifSC.ttf.import")
	check(str(entry.get("source","")) == "res://assets/NotoSerifSC.ttf", "抽到源文件路径：%s" % str(entry.get("source","")))
	check(entry.get("dests",[]).size() == 1, "字体一条产物")
	check(str(entry["dests"][0]).ends_with(".fontdata"), "字体产物是 .fontdata：%s" % str(entry["dests"][0]))
	check(FileAccess.file_exists(str(entry["dests"][0])), "该产物确实在磁盘上")
	var not_import := Env.import_entry_of("res://scripts/boot.gd")
	check(str(not_import.get("source","")).is_empty() and not_import.get("dests",[]).is_empty(), "不是 .import 的文件抽不出源文件与产物")

	# 源文件已删的残留：必须能识别出来（②号契约）
	var stale := Env.import_entry_of("res://assets/rogue/3x-crystal.png.import")
	check(str(stale.get("source","")).ends_with("3x-crystal.png"), "残留 .import 的源文件路径抽得到")
	check(not FileAccess.file_exists(str(stale.get("source",""))), "该残留的源文件确实已经不在（所以不能算进缺产物）")

	# 解析器：类名抽取
	var gothic := Env.class_names_in("res://scripts/gothic_button.gd")
	check(gothic == ["GothicButton"], "class_name 抽取：gothic_button.gd -> %s" % str(gothic))
	check(Env.class_names_in("res://scripts/boot.gd").is_empty(), "没有 class_name 的脚本返回空表")

	# 进度折算：按 `.godot/imported` 的条目数估算（不逐条查产物，见 progress() 的注释）
	check(Env.count_pending([]) == 0, "空列表没有待办")
	check(Env.count_pending(["res://.godot/imported/definitely-missing.ctex"]) == 1, "不存在的产物计入待办")
	var estimate := Env.progress({"total_assets":2945})
	check(estimate > 0.0 and estimate <= 0.98, "有产物时进度按目录条目数估算且封顶 0.98（实测 %.3f）" % estimate)
	check(Env.progress({"total_assets":999999}) < 0.05, "资源总数远大于已导入条目数时进度接近 0")
	check(Env.entry_count() > 1000, "`.godot/imported` 条目数数得出来（实测 %d）" % Env.entry_count())
	# 首次下载时这个目录还不存在：必须返回 0，不能报错（否则启动器连进度条都起不来）
	check(Env.entry_count("res://.godot/definitely-not-here") == 0, "导入目录不存在时条目数为 0")

	# 指纹比对（③号契约）
	var fp := {"import_count":1,"imported_entries":2,"script_count":3,"script_mtime":4,"cache_size":5,"cache_mtime":6}
	var same := fp.duplicate()
	same["ok"]=true
	check(not Env._stamp_matches({},fp), "没有戳就不采信")
	check(not Env._stamp_matches({"ok":false},fp), "上次结论是失败就不采信")
	check(Env._stamp_matches(same,fp), "指纹逐项一致就采信")
	var diff := same.duplicate()
	diff["import_count"]=2
	check(not Env._stamp_matches(diff,fp), "任一指纹项变了就不采信")
	var missing := same.duplicate()
	missing.erase("cache_size")
	check(not Env._stamp_matches(missing,fp), "指纹项缺失就不采信")

	if FileAccess.file_exists(Env.STAMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Env.STAMP_PATH))
	await process_frame
	print("LAUNCHER ENV ", checks, " checks / ", failures, " failures")
	quit(1 if failures else 0)
