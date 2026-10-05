class_name RogueDaily
extends RefCounted

## R11 轮：每日挑战种子 / 种子分享串 / 每日记录（纯函数数据层）。
## 契约见 `output/ROGUE-CONTRACTS.md` §5（冻结签名）、§6.2（禁止全局随机）、§9（通用纪律）。
##
## 本模块是**纯逻辑**：
##   * 不读会话、不写会话、不消耗 `s.rng`、不使用全局 `randi()/randf()`；
##   * 所有输出都是 JSON 可序列化类型；
##   * `seed_for()` 只依赖**日期字符串**本身，所以"同一天 → 同一种子"在任何进程/任何时区都成立。
##
## 时区语义（契约 §5 与派单口径的裁决，见 `output/R11-DAILY-SEED.md`）：
##   * `today()`     —— 契约原文："房主本地时间"的 `YYYY-MM-DD`（`Time.get_date_string_from_system(false)`）。
##   * `utc_today()` —— 追加：UTC 的 `YYYY-MM-DD`。用它算出的"全球每日"在所有时区一致。
##   * 无论用哪一个，**种子都必须由房主算好，随 `begin` RPC 下发**；
##     客户端只接收 `seed_value`，绝不各自按本地日期/时区计算（契约 §1「seed_value 必须全队一致」）。
##
## 分享串格式（冻结）：
##   `CT-XXXXXXXX-C`
##     * `CT`  固定前缀；
##     * `XXXXXXXX` 8 位**大写十六进制**（种子取低 31 位，恒不为 0）；
##     * `C`   1 位校验字符，取自 `ALPHABET`（Crockford base32，去掉易混的 I/L/O/U）。
##   解析容忍：大小写、首尾空白、中间空格；也接受直接粘贴的十进制种子（如 `1234567`）。
##   任何非法输入一律返回 `0`（= "无有效种子"，不得崩溃）。

## 分享串前缀。
const PREFIX := "CT-"
## 校验字符表（32 字符；`I/L/O/U` 被剔除，避免与 `1/0` 混淆）。
const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
## 分享串里十六进制位数。
const HEX_DIGITS := 8
## 种子上限（31 位正数；`launch()` 里 `fixed_seed == 0` 表示"随机"，所以合法种子必须恒 > 0）。
const MAX_SEED := 0x7FFFFFFF
## 校验字符的加盐常数（固定值，改它就等于作废所有已发出的分享串）。
const CHECK_SALT := 7
## 日期合法性范围。
const MIN_YEAR := 1970
const MAX_YEAR := 9999
## 每日记录里日期键的前缀。
const RECORD_PREFIX := "daily:"
## `streak_ending_at()` 默认最多向前回溯的天数。
const MAX_LOOKBACK := 400

# ---------------------------------------------------------------- 日期与今日

## 房主**本地**日期的 `"YYYY-MM-DD"`（契约 §5 原文）。
static func today() -> String:
	return Time.get_date_string_from_system(false)

## **UTC** 日期的 `"YYYY-MM-DD"`（追加）。
## 用它派生的"全球每日挑战"不受本地时区影响，但仍须由房主算好并随 `begin` 下发。
static func utc_today() -> String:
	return Time.get_date_string_from_system(true)

## 把各种写法规整成 `"YYYY-MM-DD"`；无法规整成合法日期 → `""`。
## 容忍：首尾空白、`/` 与 `.` 分隔符、个位数月/日（`2026-1-5`）、ISO 时间戳前缀（截前 10 字符）。
static func normalize_date(text: String) -> String:
	var t := text.strip_edges()
	if t == "":
		return ""
	t = t.replace("/", "-").replace(".", "-")
	if t.length() > 10:
		# 只容忍 ISO 时间戳（`...T13:00:00`）与"日期 + 空格 + 时间"，其余尾随垃圾一律判非法。
		var tail := t[10]
		if tail != "T" and tail != " ":
			return ""
		t = t.substr(0, 10)
	var parts := t.split("-", false)
	if parts.size() != 3:
		return ""
	for part in parts:
		if not _is_digits(part):
			return ""
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if year < MIN_YEAR or year > MAX_YEAR:
		return ""
	if month < 1 or month > 12:
		return ""
	if day < 1 or day > _days_in_month(year, month):
		return ""
	return "%04d-%02d-%02d" % [year, month, day]

## 是否是（可规整的）合法日期串。
static func is_date_string(text: String) -> bool:
	return normalize_date(text) != ""

# ---------------------------------------------------------------- 种子

## `"YYYY-MM-DD"` → 稳定种子（纯函数：同一天同值、跨天不同值、跨进程/跨平台一致）。
## 非法输入 → `0`。合法返回值恒落在 `[1, MAX_SEED]`。
static func seed_for(date_string: String) -> int:
	var key := normalize_date(date_string)
	if key == "":
		return 0
	var raw := _fnv1a32("crimson-tide-daily:" + key)
	var value := raw & MAX_SEED
	if value == 0:
		value = 1
	return value

## 房主"今日（本地）"的每日种子（追加）。**必须由房主算好随 `begin` 下发**。
static func host_daily_seed() -> int:
	return seed_for(today())

## "今日（UTC）"的每日种子（追加）。跨时区一致的每日挑战用这个；同样由房主下发。
static func global_daily_seed() -> int:
	return seed_for(utc_today())

## 种子 → 可复制粘贴的分享串；越界或非正种子 → `""`（不可分享）。
static func encode(seed: int) -> String:
	if seed <= 0 or seed > MAX_SEED:
		return ""
	var hex := "%08X" % seed
	return PREFIX + hex + "-" + _check_char(hex)

## 分享串（或十进制种子）→ 种子；任何非法输入 → `0`。**不崩、不抛。**
static func parse_seed(text: String) -> int:
	var t := _normalize_share(text)
	if t == "":
		return 0
	if _matches_share(t):
		var body := t.substr(PREFIX.length(), HEX_DIGITS)
		var value := 0
		for i in body.length():
			value = value * 16 + _hex_value(body[i])
		return value if value > 0 else 0
	# 容忍直接粘贴十进制种子。
	var digits := t
	if digits.begins_with("#"):
		digits = digits.substr(1)
	if not _is_digits(digits):
		return 0
	var dec := int(digits)
	if dec <= 0 or dec > MAX_SEED:
		return 0
	return dec

## 分享串是否合法（校验位必须正确）。
static func is_valid(text: String) -> bool:
	return _matches_share(_normalize_share(text))

# ---------------------------------------------------------------- 每日记录（纯函数）

## 日期在记录字典里的键；非法日期 → `""`。
static func record_key(date_string: String) -> String:
	var key := normalize_date(date_string)
	if key == "":
		return ""
	return RECORD_PREFIX + key

## 把任意脏输入规整成记录 `{"best":int,"plays":int}`；无法识别 → `{}`。
static func normalize_record(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value
	var best := 0
	var plays := 0
	if source.has("best"):
		var raw_best: Variant = source["best"]
		if raw_best is int or raw_best is float:
			best = maxi(0, int(raw_best))
	if source.has("plays"):
		var raw_plays: Variant = source["plays"]
		if raw_plays is int or raw_plays is float:
			plays = maxi(0, int(raw_plays))
	if not source.has("best") and not source.has("plays"):
		return {}
	return {"best": best, "plays": plays}

## 记录字典里某天是否打过。
static func played_on(records: Variant, date_string: String) -> bool:
	var key := record_key(date_string)
	if key == "" or not (records is Dictionary):
		return false
	var rec := normalize_record((records as Dictionary).get(key, {}))
	if rec.is_empty():
		return false
	return int(rec.get("plays", 0)) > 0

## 记录字典里某天的最高分；没有记录 → `0`。
static func best_on(records: Variant, date_string: String) -> int:
	var key := record_key(date_string)
	if key == "" or not (records is Dictionary):
		return 0
	var rec := normalize_record((records as Dictionary).get(key, {}))
	return int(rec.get("best", 0))

## 记一次成绩，返回**新的**记录字典（纯函数：不改传入的字典）。
## 非法日期 → 原样返回一份拷贝。
static func apply_result(records: Variant, date_string: String, score: int) -> Dictionary:
	var out: Dictionary = {}
	if records is Dictionary:
		out = (records as Dictionary).duplicate(true)
	var key := record_key(date_string)
	if key == "":
		return out
	var rec := normalize_record(out.get(key, {}))
	var safe_score := maxi(0, score)
	out[key] = {
		"best": maxi(int(rec.get("best", 0)), safe_score),
		"plays": int(rec.get("plays", 0)) + 1,
	}
	return out

## 以 `date_string` 结尾的连续打卡天数；该天没打 → `0`。
## `max_lookback` 防止脏数据把循环拖死。
static func streak_ending_at(records: Variant, date_string: String, max_lookback: int = MAX_LOOKBACK) -> int:
	if not (records is Dictionary):
		return 0
	if not played_on(records, date_string):
		return 0
	var cursor := normalize_date(date_string)
	var streak := 0
	var budget := maxi(1, max_lookback)
	while streak < budget and cursor != "" and played_on(records, cursor):
		streak += 1
		cursor = shift_date(cursor, -1)
	return streak

## 日期 ± 天数 → `"YYYY-MM-DD"`；非法输入 → `""`。
static func shift_date(date_string: String, days: int) -> String:
	var key := normalize_date(date_string)
	if key == "":
		return ""
	var stamp := Time.get_unix_time_from_datetime_string(key + "T00:00:00")
	if stamp <= 0:
		return ""
	return Time.get_date_string_from_unix_time(stamp + int(days) * 86400)

# ---------------------------------------------------------------- 内部工具

## 32 位 FNV-1a（自己实现，避免依赖 `hash()` 的跨版本稳定性）；逐字符取码点，跨平台一致。
static func _fnv1a32(text: String) -> int:
	var h := 0x811C9DC5
	for i in text.length():
		h = (h ^ text.unicode_at(i)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	return h

static func _check_char(hex: String) -> String:
	var sum := 0
	for i in hex.length():
		sum += _hex_value(hex[i])
	return ALPHABET[(sum + CHECK_SALT) % ALPHABET.length()]

static func _hex_value(c: String) -> int:
	if c >= "0" and c <= "9":
		return c.unicode_at(0) - 48
	if c >= "A" and c <= "F":
		return c.unicode_at(0) - 55
	return 0

static func _is_digits(text: String) -> bool:
	if text == "":
		return false
	for i in text.length():
		var c := text[i]
		if c < "0" or c > "9":
			return false
	return true

## 只做大小写与空白规整，不做语法校验。
static func _normalize_share(text: String) -> String:
	var t := text.strip_edges().to_upper()
	t = t.replace(" ", "").replace("\t", "").replace("\u3000", "")
	return t

## 规整后的字符串是否严格符合 `CT-{8 hex}-{check}` 且校验位正确。
static func _matches_share(text: String) -> bool:
	if text.length() != PREFIX.length() + HEX_DIGITS + 2:
		return false
	if not text.begins_with(PREFIX):
		return false
	var body := text.substr(PREFIX.length(), HEX_DIGITS)
	for i in body.length():
		var c := body[i]
		if not (c >= "0" and c <= "9") and not (c >= "A" and c <= "F"):
			return false
	if text[PREFIX.length() + HEX_DIGITS] != "-":
		return false
	var check := text[PREFIX.length() + HEX_DIGITS + 1]
	if ALPHABET.find(check) < 0:
		return false
	return check == _check_char(body)

static func _is_leap(year: int) -> bool:
	if year % 4 != 0:
		return false
	if year % 100 != 0:
		return true
	return year % 400 == 0

static func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap(year) else 28
	return 0
