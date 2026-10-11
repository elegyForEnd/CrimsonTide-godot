extends SceneTree
## 开发者判定框覆盖层（`scripts/dev_ranges.gd`）的契约回归（无头）。
##
## 覆盖 2026-10-11 第 5 批修掉/新增的四件事：
##   ① 开关：只有 `CRIMSON_DEV_RANGES` 有值才开（正式游玩连节点都不建）。
##   ② 勾选树：每个 key 唯一、非空（面板靠它驱动 `toggles`）。
##   ③ 灵体门控：没有活着的灵体时 `soul_focus` **不写**（覆盖层因此不会误报"主人索敌圈"）；
##      最后一只灵体消失时把残留的 `soul_focus` 清掉。
##   ④ 故事交互的几何契约：门只画当前区域、宝箱/任务物都在当前区域内、建筑墙块与判定同源，
##      以及"台阶上的宝箱有高度"——这正是圆环必须逐点投影、不能用三点仿射拟合的原因。
const Build = preload("res://scripts/rogue_build.gd")
const DevRanges = preload("res://scripts/dev_ranges.gd")
const Campaign = preload("res://scripts/story_campaign.gd")

var s: TideSession
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

# ---------------------------------------------------------------- 魔境：灵体门控

func launch_rogue(hero: int) -> Dictionary:
	s = TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero": hero, "mode": "roguelike"})
	s.launch(false, 731)
	var p: Dictionary = s.players[1]
	var selection: Dictionary = p.rogue_selection
	if not selection.is_empty():
		s.perform(p.id, "rogue_selection_take", {"id": selection.id, "version": selection.version, "index": 0})
	s.enemies.clear()
	return p

## 一只不会还手的木桩（坐标取通道中心线，`spawn_enemy` 对不可走点会静默拒绝）。
func dummy(p: Dictionary) -> Dictionary:
	var before := s.enemies.size()
	s.spawn_enemy(Vector2(p.p.x + 200.0, s.ruins.lane_center(p.p.x + 200.0)), 0)
	if s.enemies.size() == before:
		check(false, "木桩没生成：起点不可走")
		return {}
	var e: Dictionary = s.enemies.back()
	s.roguelike.combat.setup_minion(e, 0, 0, false, s.rng)
	e.hp = 400000; e.max_hp = 400000; e.stagger = 9999.0
	e.rogue_shield = 0.0; e.guard_time = 0.0; e.buff_time = 0.0
	return e

func soul_gate() -> void:
	# ① 非召唤系主角（hero 0）：打中怪也不该写 soul_focus —— 这就是"没词条却画出主人索敌圈"的真因。
	var p: Dictionary = launch_rogue(0)
	var e: Dictionary = dummy(p)
	if not e.is_empty():
		Build.hit_event(s, p, e, 10.0, false, Build.context(s, p, "attack"))
		check(p.get("build_summons", []).is_empty(), "① 非召唤系主角没有灵体")
		check(int(p.get("soul_focus", -1)) == -1, "① 没有灵体时打中怪**不写** soul_focus（覆盖层不再误报主人索敌圈）")
	# ② 真有灵体时，指令照旧记录。
	p = launch_rogue(0)
	e = dummy(p)
	if not e.is_empty():
		Build.summon(s, p, 20.0, .06)
		Build.hit_event(s, p, e, 10.0, false, Build.context(s, p, "attack"))
		check(int(p.get("soul_focus", -1)) == int(e.id), "② 有灵体时打中怪仍然记成索敌指令")
		# ③ 最后一只灵体到期 → 残留的指令一并清掉（否则下次召唤会先追一只过期目标）。
		for soul in p.build_summons:
			soul.time = 0.001
		Build.tick(s, p, 0.05)
		check(p.get("build_summons", []).is_empty(), "③ 灵体到期后被清空")
		check(int(p.get("soul_focus", -1)) == -1, "③ 最后一只灵体消失时 soul_focus 一并清掉")

# ---------------------------------------------------------------- 故事：交互几何契约

func story_contract() -> void:
	var c = Campaign.new()
	c.save_enabled = false
	c.load_campaign("user://story-unit-unused.json")
	var overlay = DevRanges.new()          # 不挂树：只用纯函数（不建面板）
	var saved_stage := int(c.state.stage)

	# ① 门：`story_map.entrances()` 在户外会把别的户外区域的门也返回，覆盖层必须过滤掉。
	var removed := 0
	for stage in c.map.regions.size():
		c.state.stage = stage
		var all: Array = c.map.entrances()
		var local: Array = overlay._local_entrances(c)
		check(local.size() <= all.size(), "① 门过滤只会变少（stage %d：%d→%d）" % [stage, all.size(), local.size()])
		removed += all.size() - local.size()
		var region = c.map.regions[stage]
		var box := Rect2(region.origin, region.extent).grow(400.0)
		for door in local:
			check(box.has_point(door.p), "① 只画当前区域的门（stage %d）" % stage)
		# ② 宝箱圈必须落在当前区域内（跨区域的世界坐标会画到水里/远处）。
		var chest_box := Rect2(region.origin, region.extent).grow(200.0)
		for chest in c.nearby_chests():
			check(chest_box.has_point(chest.p), "② 宝箱圈在当前区域内（stage %d）" % stage)
	check(removed > 0, "① 确实存在被过滤掉的跨区域门（否则这条规则是空转，测试没有意义）")

	# ③ 建筑碰撞箱：墙块由公开函数 `building_walls(rect)` 现算，与 `story_environment` 摆的墙同源。
	var camp_region = c.map.regions[0]
	check(camp_region.buildings.size() >= 6, "③ 营地有 6 座服务建筑（实际 %d）" % camp_region.buildings.size())
	for building in camp_region.buildings:
		var rect: Rect2 = building.rect
		var walls: Array = camp_region.building_walls(rect)
		check(walls.size() == 5, "③ building_walls 给 5 段墙（实际 %d）" % walls.size())
		for wall in walls:
			check(rect.grow(1.0).encloses(wall), "③ 墙块落在建筑占地内（与判定同源）")
		if walls.size() == 5:
			var gap: float = float(walls[4].position.x) - float(walls[3].end.x)
			check(is_equal_approx(gap, 110.0), "③ 南墙留 110 宽门洞（实际 %.0f）" % gap)

	# ④ 高度：台阶上的宝箱有非零高度，而世界原点高度为 0 —— 这正是"三点仿射拟合"会把圈
	#    压下约屏高 11% 的原因，也是营地/故事必须逐点投影的原因。
	var raised := 0
	var sample := 0.0
	for stage in range(1, c.map.regions.size()):
		var region = c.map.regions[stage]
		for chest in region.chests:
			var height: float = c.map.height_at(region.origin + chest)
			if height > 50.0:
				raised += 1
				sample = maxf(sample, height)
	check(is_zero_approx(c.map.height_at(Vector2.ZERO)), "④ 世界原点高度为 0（仿射拟合的基准点）")
	check(raised > 0, "④ 存在台阶上的宝箱（高度 %.0f）——逐点投影与仿射拟合必须分开" % sample)
	c.state.stage = saved_stage
	overlay.free()

# ---------------------------------------------------------------- 开关与勾选树

func switches() -> void:
	OS.set_environment("CRIMSON_DEV_RANGES", "")
	check(not DevRanges.enabled(), "不设变量时覆盖层关闭（正式游玩连节点都不建）")
	OS.set_environment("CRIMSON_DEV_RANGES", "0")
	check(not DevRanges.enabled(), "0/off/false/no 都当关")
	OS.set_environment("CRIMSON_DEV_RANGES", "all")
	check(DevRanges.enabled(), "设 all 时覆盖层打开")
	OS.set_environment("CRIMSON_DEV_RANGES", "")
	var keys := {}
	for group in DevRanges.PANEL_TREE:
		check(str(group.get("mode", "")) != "", "每个模式分组都有名字")
		for section in group.groups:
			check(str(section.get("name", "")) != "", "每个大类都有名字")
			for item in section.items:
				var key := str(item[0])
				check(key != "", "勾选项 key 非空")
				check(not keys.has(key), "勾选项 key 唯一：%s" % key)
				check(str(item[1]) != "", "勾选项有标签：%s" % key)
				keys[key] = true
	check(keys.size() >= 25, "勾选项数量足够覆盖四批次（%d）" % keys.size())

func run() -> void:
	switches()
	soul_gate()
	story_contract()
	print("dev_ranges: %d checks, %d failures" % [checks, failures])
	if failures > 0:
		quit(1)
	else:
		quit(0)
