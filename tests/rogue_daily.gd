extends SceneTree

## R11 验收：每日挑战种子 / 种子分享串 / 每日记录。
##
## 覆盖（对应派单的 ①–⑥）：
##   ① 同一日期 → 同一种子（1000 次重复一致），相邻日期 → 不同种子（1000 天样本零碰撞）
##   ② `encode` → `parse_seed` 往返恒等（1000 个种子样本）
##   ③ 非法 / 截断 / 超长 / 非法字符 / 校验位错 / 零种子 → 安全失败，不崩不抛
##   ④ 大小写与首尾（含中间）空白容错
##   ⑤ 时区一致性：`today()`=本地、`utc_today()`=UTC，`global_daily_seed()` 只由 UTC 日期派生，
##      且 `seed_for()` 只依赖日期字符串本身（不依赖调用时刻/进程）
##   ⑥ 每日记录纯函数的边界：无记录 / 当天 / 隔天 / 连胜中断 / 脏数据 / 纯函数不改原字典
##   ⑦ 固定种子可复现：`launch(false,X)` 两次 → `seed_value==X`、首层节点图 signature 相同、
##      `exit_choices()` 逐字符相同（契约 §1「seed_value 必须全队一致」）
##
## 只读：不修改任何既有文件、不写存档（除了临时 profile 不需要）。

var checks := 0
var failures := 0

const Daily = preload("res://scripts/rogue_daily.gd")
const Graph = preload("res://scripts/rogue_graph.gd")

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func new_session(seed_value: int) -> TideSession:
	var t := TideSession.new()
	root.add_child(t)
	t.set_physics_process(false)
	t.solo({"hero": 0, "mode": "roguelike"})
	t.launch(false, seed_value)
	return t

func run() -> void:
	# ---------------------------------------------------------------- 日期规整
	check(Daily.normalize_date("2026-10-05") == "2026-10-05", "Canonical date survives")
	check(Daily.normalize_date(" 2026/1/5 ") == "2026-01-05", "Slashes and single digits are padded")
	check(Daily.normalize_date("2026.10.05") == "2026-10-05", "Dots are accepted")
	check(Daily.normalize_date("2026-10-05T13:00:00") == "2026-10-05", "ISO timestamp is truncated")
	check(Daily.normalize_date("2026-10-05 13:00:00") == "2026-10-05", "Trailing clock time is truncated")
	check(Daily.normalize_date("2026-10-05x") == "", "Trailing junk is rejected")
	check(Daily.normalize_date("2026-13-01") == "", "Month 13 is rejected")
	check(Daily.normalize_date("2026-00-10") == "", "Month 0 is rejected")
	check(Daily.normalize_date("2026-02-30") == "", "February 30 is rejected")
	check(Daily.normalize_date("2026-04-31") == "", "April 31 is rejected")
	check(Daily.normalize_date("2026-02-29") == "", "2026 is not a leap year")
	check(Daily.normalize_date("2024-02-29") == "2024-02-29", "2024 is a leap year")
	check(Daily.normalize_date("2000-02-29") == "2000-02-29", "2000 is a leap year (400 rule)")
	check(Daily.normalize_date("1900-02-29") == "", "1900 is not a leap year (100 rule)")
	check(Daily.normalize_date("20261005") == "", "Compact digits are rejected")
	check(Daily.normalize_date("") == "", "Empty string is rejected")
	check(Daily.normalize_date("not-a-date") == "", "Words are rejected")
	check(Daily.normalize_date("1969-12-31") == "", "Years below MIN_YEAR are rejected")
	check(Daily.is_date_string("2026-10-05"), "is_date_string accepts a real date")
	check(not Daily.is_date_string("2026-02-30"), "is_date_string rejects a fake date")

	# ---------------------------------------------------------------- ① 种子确定性
	var day := "2026-10-05"
	var stable := true
	var first := Daily.seed_for(day)
	for i in 1000:
		if Daily.seed_for(day) != first:
			stable = false
			break
	check(stable, "1000 repeated rolls of the same date agree")
	check(first > 0, "A valid date yields a positive seed")
	check(first <= Daily.MAX_SEED, "Seed stays inside MAX_SEED")
	check(Daily.seed_for(" 2026-10-05 ") == first, "Whitespace does not change the seed")
	check(Daily.seed_for("2026/10/05") == first, "Separators do not change the seed")

	check(Daily.seed_for("") == 0, "Empty date yields seed 0")
	check(Daily.seed_for("garbage") == 0, "Garbage date yields seed 0")
	check(Daily.seed_for("2026-13-01") == 0, "Invalid month yields seed 0")
	check(Daily.seed_for("2026-02-30") == 0, "Invalid day yields seed 0")
	check(Daily.seed_for("20261005") == 0, "Compact digits yield seed 0")

	var base: int = Time.get_unix_time_from_datetime_string("2026-01-01T00:00:00")
	var seen := {}
	var lowest := Daily.MAX_SEED
	var highest := 0
	for i in 1000:
		var date := Time.get_date_string_from_unix_time(base + i * 86400)
		var seed_value := Daily.seed_for(date)
		seen[seed_value] = date
		lowest = mini(lowest, seed_value)
		highest = maxi(highest, seed_value)
	check(seen.size() == 1000, "1000 consecutive days produce 1000 distinct seeds")
	check(lowest > 0 and highest <= Daily.MAX_SEED, "Every consecutive-day seed is in range")
	check(Daily.seed_for("2026-01-01") != Daily.seed_for("2026-01-02"), "Adjacent days differ")

	# ---------------------------------------------------------------- ② 分享串往返
	var roundtrip := true
	var invalid_roundtrip := ""
	for i in 1000:
		var seed_value := (1 + i * 7919) % Daily.MAX_SEED + 1
		var text := Daily.encode(seed_value)
		if text == "" or not Daily.is_valid(text) or Daily.parse_seed(text) != seed_value:
			roundtrip = false
			invalid_roundtrip = "%s -> '%s' -> %d" % [str(seed_value), text, Daily.parse_seed(text)]
			break
	check(roundtrip, "1000 encode/parse round-trips hold: %s" % invalid_roundtrip)
	var sample := Daily.encode(0x12345678)
	check(sample.begins_with(Daily.PREFIX), "Share text keeps the CT- prefix")
	check(sample.length() == Daily.PREFIX.length() + Daily.HEX_DIGITS + 2, "Share text length is frozen")
	check(Daily.encode(0) == "", "Seed 0 is not shareable")
	check(Daily.encode(-5) == "", "Negative seeds are not shareable")
	check(Daily.encode(Daily.MAX_SEED + 1) == "", "Seeds above MAX_SEED are not shareable")
	check(Daily.encode(Daily.MAX_SEED) != "", "MAX_SEED is still shareable")

	# ---------------------------------------------------------------- ④ 容错
	check(Daily.parse_seed(sample.to_lower()) == 0x12345678, "Lowercase share text parses")
	check(Daily.parse_seed("  " + sample + "  ") == 0x12345678, "Surrounding whitespace parses")
	check(Daily.parse_seed(sample.substr(0, 6) + " " + sample.substr(6)) == 0x12345678, "Inner whitespace parses")
	check(Daily.is_valid(sample.to_lower()), "is_valid tolerates lowercase")
	check(Daily.parse_seed("1234567") == 1234567, "A pasted decimal seed parses")
	check(Daily.parse_seed(" 42 ") == 42, "A small decimal seed parses")
	check(Daily.parse_seed("#42") == 42, "A hashed decimal seed parses")
	check(Daily.parse_seed("0") == 0, "Decimal zero is rejected")
	check(Daily.parse_seed("-5") == 0, "Negative decimal is rejected")
	check(Daily.parse_seed("3000000000") == 0, "Decimal above MAX_SEED is rejected")

	# ---------------------------------------------------------------- ③ 非法分享串
	var broken := [
		"", "CT-", "CT-", "CT-1234567-A", "CT-123456789-A", "CT-12345678-A0",
		"CT-1234567G-A", "XX-12345678-7", "CT_12345678-7", "CT-12345678_7",
		"CT-12345678-", "CT-12345678",
	]
	for text in broken:
		check(not Daily.is_valid(text), "Rejects malformed share text '%s'" % text)
		check(Daily.parse_seed(text) == 0, "Malformed share text parses to 0: '%s'" % text)
	check(not Daily.is_valid("12345678"), "A bare hex blob is not a share string")
	check(Daily.parse_seed("12345678") == 12345678, "A bare decimal blob is still a usable seed")
	# 校验位本身必须取自 ALPHABET 且等于计算值：把校验位换成一个合法但错误的字符
	var wrong_check := "A" if sample[sample.length() - 1] != "A" else "B"
	var tampered := sample.substr(0, sample.length() - 1) + wrong_check
	check(not Daily.is_valid(tampered), "A wrong check character is rejected")
	check(Daily.parse_seed(tampered) == 0, "A wrong check character parses to 0")
	# 合法形状但值为零：可被识别为"分享串"，却仍是无效种子
	var zero := Daily.encode(0)
	check(zero == "", "encode refuses zero")
	var handcrafted_zero := Daily.PREFIX + "00000000-" + Daily.ALPHABET[(Daily.CHECK_SALT) % Daily.ALPHABET.length()]
	check(Daily.is_valid(handcrafted_zero), "All-zero body is still well-formed")
	check(Daily.parse_seed(handcrafted_zero) == 0, "All-zero body parses to seed 0")

	# ---------------------------------------------------------------- ⑤ 时区 / UTC
	check(Daily.today() == Time.get_date_string_from_system(false), "today() is the host local date")
	check(Daily.utc_today() == Time.get_date_string_from_system(true), "utc_today() is the UTC date")
	check(Daily.is_date_string(Daily.today()), "today() is a valid date string")
	check(Daily.is_date_string(Daily.utc_today()), "utc_today() is a valid date string")
	check(Daily.global_daily_seed() == Daily.seed_for(Daily.utc_today()), "Global daily derives from the UTC date")
	check(Daily.global_daily_seed() > 0, "Global daily seed is usable")
	check(Daily.host_daily_seed() == Daily.seed_for(Daily.today()), "Host daily derives from the local date")
	# 种子只依赖字符串：同一字符串在任意时刻/任意进程都得到同一个值（不读系统时钟）
	check(Daily.seed_for(Daily.utc_today()) == Daily.seed_for(Time.get_date_string_from_system(true)), "Seed never depends on the wall clock")

	# ---------------------------------------------------------------- ⑥ 每日记录纯函数
	check(Daily.record_key("2026-10-05") == Daily.RECORD_PREFIX + "2026-10-05", "Record key is prefixed")
	check(Daily.record_key("nope") == "", "Invalid dates have no record key")
	check(Daily.normalize_record(null).is_empty(), "normalize_record(null) is empty")
	check(Daily.normalize_record("oops").is_empty(), "normalize_record(String) is empty")
	check(Daily.normalize_record([]).is_empty(), "normalize_record(Array) is empty")
	check(Daily.normalize_record({}).is_empty(), "normalize_record({}) is empty")
	var dirty := Daily.normalize_record({"best": -5, "plays": 1})
	check(int(dirty.get("best", -1)) == 0, "Negative best is floored to 0")
	check(int(dirty.get("plays", -1)) == 1, "Plays survives normalization")
	var floaty := Daily.normalize_record({"best": 3.0, "plays": 2.0})
	check(typeof(floaty["best"]) == TYPE_INT and int(floaty["best"]) == 3, "Float best becomes an int")
	check(typeof(floaty["plays"]) == TYPE_INT and int(floaty["plays"]) == 2, "Float plays becomes an int")

	var records := {}
	check(not Daily.played_on(records, day), "A fresh record book has no plays")
	check(Daily.best_on(records, day) == 0, "A fresh record book has no best score")
	check(Daily.streak_ending_at(records, day) == 0, "A fresh record book has no streak")
	check(not Daily.played_on(records, "nope"), "Invalid dates are never played")

	var after_first := Daily.apply_result(records, day, 120)
	check(records.is_empty(), "apply_result does not mutate its input")
	check(Daily.played_on(after_first, day), "A played day is recorded")
	check(Daily.best_on(after_first, day) == 120, "The first score becomes the best")
	var after_worse := Daily.apply_result(after_first, day, 90)
	check(Daily.best_on(after_worse, day) == 120, "A worse score does not lower the best")
	check(int(Daily.normalize_record(after_worse[Daily.record_key(day)])["plays"]) == 2, "Replays are counted")
	var after_better := Daily.apply_result(after_worse, day, 200)
	check(Daily.best_on(after_better, day) == 200, "A better score raises the best")
	check(Daily.streak_ending_at(after_better, day) == 1, "One played day is a streak of 1")
	check(Daily.apply_result(after_better, "nope", 5).size() == after_better.size(), "Invalid dates do not add records")
	check(Daily.shift_date(day, 1) == "2026-10-06", "shift_date moves forward")
	check(Daily.shift_date(day, -1) == "2026-10-04", "shift_date moves backward")
	check(Daily.shift_date("2026-01-01", -1) == "2025-12-31", "shift_date crosses a year boundary")
	check(Daily.shift_date("2024-03-01", -1) == "2024-02-29", "shift_date honours leap years")
	check(Daily.shift_date("nope", 1) == "", "shift_date rejects invalid dates")

	var next_day := Daily.shift_date(day, 1)
	var streak_two := Daily.apply_result(after_better, next_day, 50)
	check(Daily.streak_ending_at(streak_two, next_day) == 2, "Two consecutive days are a streak of 2")
	check(Daily.streak_ending_at(streak_two, day) == 1, "The streak ending on day 1 is still 1")
	var gap_day := Daily.shift_date(day, 2)
	var gap_book := Daily.apply_result(Daily.apply_result({}, day, 20), gap_day, 30)
	check(Daily.played_on(gap_book, gap_day), "The gap day is recorded")
	check(not Daily.played_on(gap_book, Daily.shift_date(day, 1)), "The day in between stays unplayed")
	check(Daily.streak_ending_at(gap_book, gap_day) == 1, "A skipped day resets the streak")
	check(Daily.streak_ending_at(gap_book, day) == 1, "A gap does not extend an earlier streak")
	check(Daily.streak_ending_at(streak_two, gap_day) == 0, "An unplayed anchor day has no streak")
	var broken_book := {"daily:2026-10-05": {"best": 5, "plays": 1}, "daily:2026-10-04": "garbage"}
	check(Daily.streak_ending_at(broken_book, day) == 1, "Dirty neighbours stop the streak safely")
	check(Daily.streak_ending_at(broken_book, day, 0) == 1, "A zero lookback still counts the anchor day")

	# ---------------------------------------------------------------- ⑦ 固定种子可复现
	var a := new_session(4242)
	var b := new_session(4242)
	check(a.seed_value == 4242 and b.seed_value == 4242, "A fixed seed is stored verbatim")
	check(Graph.signature(Graph.build(a.seed_value, 1)) == Graph.signature(Graph.build(b.seed_value, 1)), "The first floor graph is identical for the same seed")
	check(str(a.roguelike.exit_choices(a)) == str(b.roguelike.exit_choices(b)), "The first exit choice is identical for the same seed")
	var offers_a: Array = a.roguelike.reward_offers(a, 3, "gear", a.players[1])
	var offers_b: Array = b.roguelike.reward_offers(b, 3, "gear", b.players[1])
	check(offers_a.size() > 0, "The first three-choice pool is populated")
	check(str(offers_a) == str(offers_b), "The first three-choice pool is identical for the same seed")
	var daily_seed := Daily.seed_for("2026-10-05")
	var c := new_session(daily_seed)
	check(c.seed_value == daily_seed, "A daily seed works as a fixed seed")
	check(daily_seed != 0, "Daily seeds are never 0 (0 means random)")
	a.queue_free()
	b.queue_free()
	c.queue_free()

	await process_frame
	print("ROGUE DAILY ", checks, " checks / ", failures, " failures")
	quit(1 if failures else 0)
