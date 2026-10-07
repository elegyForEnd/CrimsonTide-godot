extends RefCounted
## Test driver for the actual world interaction sequence, with explicit landing time.
static func pick(s, p: Dictionary) -> void:
	if not s.raid.reward_chest.is_empty() and not s.raid.reward_chest.opened:
		p.p=s.raid.reward_chest.p
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
