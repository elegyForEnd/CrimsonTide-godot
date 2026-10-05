class_name WatcherAttributes
extends RefCounted

# Shared permanent allocation; base hero health and the existing talents remain.
const KEYS := ["vigor", "mind", "endurance", "strength", "dexterity", "intelligence", "arcane"]
const NAMES := ["生命", "集中力", "耐力", "力量", "灵巧", "智力", "感应"]
const DESCRIPTIONS := ["提高最大生命", "提高蓝条上限，法术与奥义消耗蓝量", "提高受击抗性与理智抗性，不消耗体力", "提高力量补正武器的伤害", "提高灵巧补正武器的伤害", "提高智力补正武器的伤害", "提高击杀掉率与感应补正武器的伤害"]
const BASE := 10
const CAP := 99
const INITIAL_POINTS := 5
const GRADES := {"S":0.025, "A":0.020, "B":0.015, "C":0.010, "D":0.006, "E":0.003, "-":0.0}

static func point_budget(xp: int) -> int:
	return INITIAL_POINTS+maxi(0,xp)/180

static func clean(value: Variant, budget: int = 623) -> Dictionary:
	var result: Dictionary = {}
	var remaining := maxi(0,budget)
	for key in KEYS:
		var raw: Variant=value.get(key,BASE) if value is Dictionary else BASE
		var amount := clampi(int(raw),BASE,CAP) if raw is int or raw is float else BASE
		var spent := mini(amount-BASE,remaining)
		result[key]=BASE+spent
		remaining-=spent
	return result

static func spent(value: Dictionary) -> int:
	var total := 0
	for key in KEYS:
		total+=maxi(0,int(value.get(key,BASE))-BASE)
	return total

# Marginal gains halve after 40 and fall to one fifth after 70.
static func growth(value: int) -> float:
	var points := clampi(value,BASE,CAP)-BASE
	return minf(points,30)+clampf(points-30,0,30)*0.5+maxf(0,points-60)*0.2

static func bonus(value: Dictionary, key: String) -> float:
	return growth(int(value.get(key,BASE)))

static func hp_bonus(value: Dictionary) -> float:
	return 8.0*bonus(value,"vigor")

static func max_mana(value: Dictionary) -> float:
	return 80.0+4.0*bonus(value,"mind")

static func resistance(value: Dictionary) -> float:
	return minf(0.30,0.005*bonus(value,"endurance"))

static func discovery(value: Dictionary) -> float:
	return 100.0+2.0*bonus(value,"arcane")

static func scaling(value: Dictionary, grades: Dictionary) -> float:
	var total := 0.0
	for key in ["strength", "dexterity", "intelligence", "arcane"]:
		total+=bonus(value,key)*float(GRADES.get(str(grades.get(key,"-")),0.0))
	return total
