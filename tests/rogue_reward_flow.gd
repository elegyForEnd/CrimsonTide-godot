extends RefCounted
## Test driver for the actual world interaction sequence, with explicit landing time.
static func pick(s, p: Dictionary) -> void:
	# 非战斗房（灵契圣坛等）也会进 `rogue_reward`，那时 `reward_chest` 里既没有 `opened` 也没有 `p`；
	# 直接访问会抛运行期错误并让 `pick()` 提前返回（外面看起来只是"没捡到东西"）。统一安全取值。
	var chest: Dictionary=s.raid.get("reward_chest",{})
	if not bool(chest.get("opened",false)) and chest.has("p"):
		p.p=chest.p
		s.perform(p.id,"rogue_loot")
	s.elapsed+=2
	for packet in s.raid.reward_drops:
		if packet.offer.is_empty():
			p.p=packet.p
			break
	s.perform(p.id,"rogue_loot")

static func claim(s, p: Dictionary, index: int = 0) -> void:
	while s.raid.phase=="rogue_reward":
		pick(s,p)
		assert(not p.rogue_selection.is_empty())
		s.perform(p.id,"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":index})
