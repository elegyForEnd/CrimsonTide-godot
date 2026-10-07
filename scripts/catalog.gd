class_name Catalog
extends RefCounted

# The three heroes the game shipped with. Everything past this index is a
# hidden recruit who only appears once a profile has earned them.
const BASE_ROSTER := 3

const HEROES = [
	{"name":"绯月", "title":"赤刃守夜姬", "desc":"黑铁短剑：攻击距离短、攻速快、伤害低。红莲月华贯穿近处敌群。", "color":Color("da6474"), "hair":Color("e8dce0"), "hp":110.0, "speed":220.0, "damage":23.0, "rate":0.23, "clip":16, "skill":"红莲月华"},
	{"name":"雪璃", "title":"晨钟祈愿者", "desc":"祭祀短杖：远程法术攻击，伤害低，释放前需要短暂吟唱。拂晓之祈治疗附近的所有队友。", "color":Color("70c4bc"), "hair":Color("c9e0ef"), "hp":95.0, "speed":230.0, "damage":32.0, "rate":0.42, "clip":10, "skill":"拂晓之祈"},
	{"name":"鸦羽", "title":"黑羽处刑人", "desc":"破碎大剑：攻速慢、伤害略高、范围大。夜鸦断罪清除周围敌人并短暂护身。", "color":Color("b397de"), "hair":Color("56516e"), "hp":130.0, "speed":250.0, "damage":42.0, "rate":0.36, "clip":0, "skill":"夜鸦断罪"},
	# The hidden recruit. Her row only appears once the hidden ending has been
	# reached, so every table indexed by hero index has to carry a fourth entry
	# whether or not the profile has unlocked her.
	{"name":"墓煜", "title":"冥火死灵法师", "desc":"湮魂之镰：伤害高、范围中等、攻速偏慢。冥火剑雨轰击前方矩形区域，随后留下持续灼烧的紫色冥火。", "color":Color("c07ae0"), "hair":Color("e6e2ee"), "hp":100.0, "speed":225.0, "damage":38.0, "rate":0.48, "clip":0, "skill":"冥火剑雨"}
]
const ITEMS = {
	"crystal":{"name":"血晶", "size":Vector2i(1,1), "value":18, "color":Color("e45c74"), "desc":"拾取后直接计入血晶数量，不占背包格子；靠近即可自动吸附。"},
	"scrap":{"name":"古城零件", "size":Vector2i(2,1), "value":32, "color":Color("b0b6c5"), "desc":"晨钟城工坊急需的机械零件。"},
	"relic":{"name":"月蚀遗物", "size":Vector2i(2,2), "value":125, "color":Color("d2ac66"), "desc":"占据四格的珍贵遗物；双击收纳时和其他白色物资一样先进背包，金色与红色的高品质装备才会优先沉入次元口袋。"},
	"medicine":{"name":"急救针", "size":Vector2i(1,2), "value":25, "color":Color("78cbb5"), "desc":"按 F 消耗一支，恢复 45 生命；倒地时可用于自救。"},
	"charm":{"name":"银鸦护符", "size":Vector2i(1,2), "value":70, "color":Color("b79ade"), "desc":"装备到饰品栏后，本局伤害提高 12%；可装备两枚。放在背包、次元口袋或道具栏时不生效。"},
	"ammo":{"name":"弹药匣", "size":Vector2i(2,1), "value":20, "color":Color("c4ad82"), "desc":"按 F 优先治疗；弹药不足时自动消耗弹药匣补充 48 发。"},
	"backpack":{"name":"背包", "size":Vector2i(1,1), "value":40, "color":Color("cfc6bb"), "desc":"可背在身上的独立储物空间，本身就是一件装备：双击或 Ctrl+左键即可换装，换下的旧包进背包柜。紫色及以上品质的包占 2×2 格。"},
	"weapon":{"name":"武器", "size":Vector2i(2,2), "value":85, "color":Color("c9a06a"), "desc":"战场上捡到的武器。只有装备到武器槽后才会握在手里；拿着它攻击时获得品质加成。阵亡会掉落。"},
	"gear":{"name":"装备", "size":Vector2i(1,2), "value":55, "color":Color("8fb6d8"), "desc":"护甲 / 瞄具 / 轻靴。装备到对应槽位后本局提升生命、火力或移速。阵亡会掉落。"},
	# The hidden-ending key. It is a red 1x1 trinket worth 666 and nothing else:
	# no stat line, no slot, no use. It only matters that it is in the backpack
	# when the third morning bell has been lit.
	"amulet":{"name":"骑士的护身符", "size":Vector2i(1,1), "value":666, "color":Color("dd6c7c"), "desc":"失乡骑士身上剥下的猩红护符，内侧刻着一行没人认得的祷文。三个晨钟封印全部点亮后，它会开始发烫。", "tier":5, "rarity":"红色"}
	,"wind_chime":{"name":"逆风铃芯", "size":Vector2i(1,1), "value":28, "color":Color("b9d3b6"), "tier":0, "desc":"风铃原野的风总向月亮吹去。铃芯却固执地指向归途。"}
	,"rabbit_bell":{"name":"兔灵葬铃", "size":Vector2i(1,2), "value":44, "color":Color("d8c6dc"), "tier":1, "desc":"食尸兔灵颈间的银铃。摇响三次，据说能听见死者在第四次回答。"}
	,"oath_banner":{"name":"巡礼者断誓旗", "size":Vector2i(2,1), "value":61, "color":Color("c7b5a0"), "tier":2, "desc":"旗面只剩一句血书：若黎明背弃我，我便亲手升起黑夜。"}
	,"forbidden_page":{"name":"禁书灰页", "size":Vector2i(1,1), "value":36, "color":Color("d3c4ad"), "tier":0, "desc":"白垩旧城的禁书残页。字迹每到午夜就自行变成读者的名字。"}
	,"reverse_hand":{"name":"逆时钟针", "size":Vector2i(1,2), "value":53, "color":Color("c9bdaf"), "tier":1, "desc":"从晨钟塔拆下的钟针。它记录的不是时间，而是尚未发生的死亡。"}
	,"absolution_mask":{"name":"无罪者的铁面", "size":Vector2i(2,1), "value":72, "color":Color("bfc4cd"), "tier":2, "desc":"审判庭宣称戴上它便能洗清罪孽。面具内侧刻满了认罪书。"}
	,"moon_core":{"name":"月髓棱晶", "size":Vector2i(1,1), "value":45, "color":Color("b8b2e5"), "tier":0, "desc":"月晶高地的矿脉结晶。暗处仍映着一轮不存在的第二月亮。"}
	,"antler_star":{"name":"骨鹿星角", "size":Vector2i(1,2), "value":64, "color":Color("d6d0e9"), "tier":1, "desc":"骨鹿遗下的星形断角。每道裂纹都对应一条被抹去的星轨。"}
	,"star_lens":{"name":"星陨观测镜", "size":Vector2i(2,1), "value":84, "color":Color("bfcce8"), "tier":2, "desc":"观星高塔的镜片。透过它，只看得见世界坠落后的天空。"}
	,"blood_rose":{"name":"血棘永生花", "size":Vector2i(1,1), "value":56, "color":Color("df8297"), "tier":0, "desc":"蔷薇庭域的花从不凋谢；它们只是等下一位主人流血。"}
	,"mirror_shard":{"name":"镜墓碎面", "size":Vector2i(1,2), "value":76, "color":Color("cbb2d3"), "tier":1, "desc":"镜墓残片。映出的影子总比持有者慢半拍微笑。"}
	,"thorn_crown":{"name":"眠姬荆冠", "size":Vector2i(2,1), "value":98, "color":Color("d6a1ad"), "tier":2, "desc":"昔日花眠庭院的冠冕。荆棘仍在替沉睡的公主守夜。"}
	,"drowned_clapper":{"name":"溺钟铜舌", "size":Vector2i(1,1), "value":68, "color":Color("94c3bf"), "tier":0, "desc":"沉钟遗迹的钟舌。浸在水中多年，敲击时却会落下灰烬。"}
	,"undersea_ticket":{"name":"冥潮船票", "size":Vector2i(1,2), "value":89, "color":Color("a8d0cb"), "tier":1, "desc":"月舟码头的单程船票。终点一栏写着乘客最后的梦。"}
	,"silent_tide":{"name":"无声潮汐瓶", "size":Vector2i(2,1), "value":114, "color":Color("85b9ba"), "tier":2, "desc":"封着一寸不会退去的潮水。靠近耳边，连心跳也会沉默。"}
	,"sacred_goblet":{"name":"圣血琉璃杯", "size":Vector2i(1,1), "value":81, "color":Color("e3aaaf"), "tier":0, "desc":"圣血大教堂的祭杯。杯底残留的红色比誓言更难洗净。"}
	,"verdict_seal":{"name":"断罪王印", "size":Vector2i(1,2), "value":106, "color":Color("e5c18b"), "tier":1, "desc":"王庭以此钤下最终判词。印泥是赤月降临时凝成的血。"}
	,"empty_crown":{"name":"空王座碎冠", "size":Vector2i(2,1), "value":135, "color":Color("e4c4a3"), "tier":2, "desc":"无人继承的王冠碎片。每一枚都在等待自己的失乡骑士。"}
	,"mirror_thread":{"name":"千镜命丝", "size":Vector2i(2,2), "value":210, "color":Color("d8b6e6"), "tier":4, "desc":"镜墓纺女最后一缕命线。它缝合破镜，也缝合不该存在的倒影。"}
	,"ember_heart":{"name":"末祷烬芯", "size":Vector2i(2,2), "value":235, "color":Color("e7aa81"), "tier":4, "desc":"余烬司祭熄灭后仍在低语的心火：愿我的终末，成为你们的黎明。"}
	,"fault_scale":{"name":"地脉逆鳞", "size":Vector2i(2,2), "value":230, "color":Color("c7aaa0"), "tier":4, "desc":"裂地钻兽脊背上的逆鳞，里面封着整条断层的怒吼。"}
	,"storm_feather":{"name":"风暴心羽", "size":Vector2i(2,2), "value":260, "color":Color("afc9e7"), "tier":4, "desc":"雷骸巨鸟心口的一根羽毛。羽轴有雷光循着死者脉搏流动。"}
	,"frost_teardrop":{"name":"永冻龙泪", "size":Vector2i(2,2), "value":310, "color":Color("b6dced"), "tier":5, "desc":"霜骨古龙失去天空时落下的泪。握住它，能听见冰封前的最后一声龙吟。"}
	,"abyss_shedding":{"name":"无光蛇蜕", "size":Vector2i(2,2), "value":370, "color":Color("9da1c7"), "tier":5, "desc":"吞月渊蛇褪下的旧夜。展开后，星光会从它的鳞缝里消失。"}
	,"royal_diadem":{"name":"失乡者的冕环", "size":Vector2i(2,1), "value":180, "color":Color("e6c394"), "tier":4, "desc":"失乡骑士所守的王冠内环。没有名字的君王，仍拥有最忠诚的守卫。"}
	,"twilight_edict":{"name":"永夜敕令", "size":Vector2i(1,2), "value":205, "color":Color("d6adb9"), "tier":4, "desc":"晨曦王城最后的诏书：命令太阳在今夜之后不得升起。"}
	,"dawn_testament":{"name":"破晓遗书", "size":Vector2i(1,1), "value":245, "color":Color("ebd6a9"), "tier":5, "desc":"信纸上只写着一句话：倘若你读到这里，说明我们仍有明天。"}
	,"fog_chime":{"name":"雾钟引魂签", "size":Vector2i(1,1), "value":34, "color":Color("adcac6"), "tier":0, "desc":"写着亡者乳名的薄铜签。雾潮升起时，钟声会替它寻找主人。"}
	,"nightwatch_pin":{"name":"断羽巡夜徽", "size":Vector2i(1,2), "value":57, "color":Color("b5c2bb"), "tier":1, "desc":"巡夜人把折断的使魔羽翎别在胸口，提醒自己天亮前不可回头。"}
	,"weightless_oathstone":{"name":"失重誓石", "size":Vector2i(2,1), "value":79, "color":Color("c5bca9"), "tier":2, "desc":"被宣誓者抛入风铃原野的石头。至今仍停在坠落之前。"}
	,"hourless_token":{"name":"斩时铜令", "size":Vector2i(1,1), "value":43, "color":Color("c7b594"), "tier":0, "desc":"晨钟旧卫的通行令。令牌上的时刻永远停在钟声响起前一息。"}
	,"last_mass_leaf":{"name":"终祷残篇", "size":Vector2i(1,2), "value":68, "color":Color("c8b9ae"), "tier":1, "desc":"灰烬司祭的祷文残页。最后一行不是祈求，而是对神明的宣判。"}
	,"mute_judgement":{"name":"噤声裁判牌", "size":Vector2i(2,1), "value":91, "color":Color("c2c0bd"), "tier":2, "desc":"宣判者以此令全庭禁声。牌面凹痕像一张被缝住的嘴。"}
	,"seer_eye":{"name":"观星者遗瞳", "size":Vector2i(1,1), "value":52, "color":Color("b8b7d8"), "tier":0, "desc":"高塔学徒留下的星晶义眼，瞳孔里还有一场尚未发生的流星雨。"}
	,"silver_stag_bell":{"name":"银骨鹿铃", "size":Vector2i(1,2), "value":74, "color":Color("d0cbdc"), "tier":1, "desc":"骨鹿角间的古铃。摇响后，附近所有影子都会转向北方。"}
	,"meteor_core":{"name":"陨星兽核", "size":Vector2i(2,1), "value":102, "color":Color("bcc6e0"), "tier":2, "desc":"石像巨兽胸腔中的星核，仍在重复坠入月晶高地的最后一瞬。"}
	,"sleeping_veil":{"name":"花眠公主的黑纱", "size":Vector2i(1,1), "value":63, "color":Color("d1a0b0"), "tier":0, "desc":"罩在空王冠上的黑纱。每一根丝线都记得一个无人赴约的春天。"}
	,"blood_vow_clasp":{"name":"血誓嫁衣扣", "size":Vector2i(1,2), "value":86, "color":Color("d88799"), "tier":1, "desc":"蔷薇庭域的赤金衣扣，背面刻着一对永不相见的姓名。"}
	,"thorn_heart":{"name":"荆棘之心", "size":Vector2i(2,1), "value":118, "color":Color("dc8994"), "tier":2, "desc":"跳动的黑蔷薇心核。每一次搏动，都替沉睡者拒绝一次黎明。"}
	,"moonbone_flute":{"name":"泡月骨笛", "size":Vector2i(1,1), "value":75, "color":Color("a5c9c5"), "tier":0, "desc":"从水底捞出的骨笛。吹奏时，雾汐上会浮起一轮倒悬的月亮。"}
	,"sunken_lantern":{"name":"沉舟魂灯", "size":Vector2i(1,2), "value":98, "color":Color("91b9b4"), "tier":1, "desc":"引渡沉船亡魂的铜灯。灯火不是火焰，而是一只睁开的青色眼睛。"}
	,"abyssal_rite_drum":{"name":"海渊祈潮盘", "size":Vector2i(2,1), "value":128, "color":Color("81b4b5"), "tier":2, "desc":"古祭司召唤逆潮的仪盘。盘面浮雕全都朝着深海张口。"}
	,"redmoon_betrothal":{"name":"赤月婚约", "size":Vector2i(1,1), "value":89, "color":Color("df9c9d"), "tier":0, "desc":"王庭在血月之夜订下的盟约。新郎、新娘和证婚人都没有留下名字。"}
	,"weeping_cairn":{"name":"王庭哭泣石", "size":Vector2i(1,2), "value":115, "color":Color("d7b4a7"), "tier":1, "desc":"旧王庭墙基中的红色石英。切开后，每一层都凝着一滴眼泪。"}
	,"nameless_standard":{"name":"无名旗首", "size":Vector2i(2,1), "value":144, "color":Color("d8adb1"), "tier":2, "desc":"没有徽记的军旗顶饰。旗帜已经烧尽，握旗之人的誓言仍未熄灭。"}
	,"mirror_fate_ledger":{"name":"镜界命谱", "size":Vector2i(2,2), "value":285, "color":Color("d3b5e2"), "tier":4, "desc":"镜墓纺女织成的命运底稿。上面有你的名字，但每一笔都在倒退。"}
	,"vesper_last_page":{"name":"末日弥撒篇", "size":Vector2i(2,2), "value":305, "color":Color("e0a988"), "tier":4, "desc":"余烬司祭的最后一页弥撒：愿焚尽我的神，换你们活过长夜。"}
	,"fault_pulse_fossil":{"name":"断层圣髓", "size":Vector2i(2,2), "value":320, "color":Color("c99f8d"), "tier":4, "desc":"裂地钻兽体内凝结的地脉核心。捧在手中，脚下的大地会回应你的心跳。"}
	,"thunder_coffin_nail":{"name":"雷骸镇魂钉", "size":Vector2i(2,2), "value":335, "color":Color("b5c8dc"), "tier":4, "desc":"曾钉入雷骸巨鸟王冠的镇魂钉。拔出后，沉睡的雷暴开始寻找天空。"}
	,"frostbone_king_remains":{"name":"霜骨龙皇遗骸", "size":Vector2i(3,3), "value":920, "color":Color("e38e9b"), "tier":5, "desc":"霜骨龙皇最后的王骸，九格寒光封存着失落龙庭。红色传世珍宝，占据整片 3×3 格。"}
	,"storm_roc_sunheart":{"name":"雷骸天帝之心", "size":Vector2i(3,3), "value":980, "color":Color("e4828d"), "tier":5, "desc":"风暴巨鸟王的赤色心核。握住它，万雷会齐声呼唤你的真名。3×3 格红色传世珍宝。"}
	,"bloodmoon_nightwomb":{"name":"赤月终焉王胎", "size":Vector2i(3,3), "value":1080, "color":Color("eb7588"), "tier":5, "desc":"终焉赤月尚未诞生的王胎。它在三日血潮尽头等待一位新的弑神者。3×3 格红色传世珍宝。"}
	,"abyssal_motherheart":{"name":"无光海母之心", "size":Vector2i(3,3), "value":1260, "color":Color("d982a0"), "tier":5, "desc":"吞月渊蛇腹中沉眠的海母之心。带走它的人，也将带走海底最后的黑夜。3×3 格红色传世珍宝。"}
	,"eternal_night_thronecore":{"name":"永夜王座核心", "size":Vector2i(3,3), "value":1150, "color":Color("e8a0a0"), "tier":5, "desc":"晨曦王城王座深处的赤色核心。它不是王权的象征，而是王权活着的原因。3×3 格红色传世珍宝。"}
	# Homestead produce: crops and fish are ordinary 1x1 stackable loot now, so a
	# harvest or a catch enters the carried backpack (and the safe pocket when it
	# is full) the same way a scrap does. The value mirrors the old sell price.
	,"wheat":{"name":"晨光麦", "size":Vector2i(1,1), "value":9, "color":Color("e8c678"), "desc":"湖畔菜园收获的麦穗，可入交易行出售或下厨。"}
	,"carrot":{"name":"赤霞萝卜", "size":Vector2i(1,1), "value":14, "color":Color("e99856"), "desc":"湖畔菜园收获的萝卜，可入交易行出售或下厨。"}
	,"herb":{"name":"月露草", "size":Vector2i(1,1), "value":21, "color":Color("94d8bf"), "desc":"湖畔菜园收获的月露草药，可入交易行出售或下厨。"}
	,"silver":{"name":"银鳞鲫", "size":Vector2i(1,1), "value":16, "color":Color("c0cbd6"), "desc":"月湾栈桥钓上的银鳞鲫，可入交易行出售或下厨。"}
	,"moon":{"name":"月纹鲈", "size":Vector2i(1,1), "value":32, "color":Color("cdd6f2"), "desc":"月湾栈桥钓上的月纹鲈，可入交易行出售或下厨。"}
	,"gold":{"name":"金冠锦鲤", "size":Vector2i(1,1), "value":65, "color":Color("e8c25a"), "desc":"月湾栈桥钓上的金冠锦鲤，可入交易行出售或下厨。"}
	# Shop goods. The home trade post sells seeds and bait as real grid-occupying
	# entities like every other good: bought units land in the vault first, spill into
	# the carried backpack when the vault is full, and whatever neither can hold is
	# dropped on the camp floor with a notice (never lost, never silently swallowed).
	# They get planted or cast one at a time and can be handed back to the exchange.
	# Their resale value sits below the shop price on purpose, so buying from the post
	# and instantly dumping there is a loss rather than a money pump.
	,"wheat_seed":{"name":"晨光麦种", "size":Vector2i(1,1), "value":6, "color":Color("d8b96a"), "desc":"家园商店购入的麦种。每份可播种一块田畦。"}
	,"carrot_seed":{"name":"赤霞萝卜种", "size":Vector2i(1,1), "value":9, "color":Color("d4823f"), "desc":"家园商店购入的萝卜种。每份可播种一块田畦。"}
	,"herb_seed":{"name":"月露草种", "size":Vector2i(1,1), "value":13, "color":Color("7fbfa4"), "desc":"家园商店购入的月露草种。每份可播种一块田畦。"}
	,"bait":{"name":"鱼饵", "size":Vector2i(1,1), "value":2, "color":Color("b9a48f"), "desc":"家园商店购入的钓饵。每次抛竿消耗一份，收竿失败不返还。"}
}
const BIOME_COLLECTIBLES := [
	["wind_chime","rabbit_bell","oath_banner"],
	["forbidden_page","reverse_hand","absolution_mask"],
	["moon_core","antler_star","star_lens"],
	["blood_rose","mirror_shard","thorn_crown"],
	["drowned_clapper","undersea_ticket","silent_tide"],
	["sacred_goblet","verdict_seal","empty_crown"]
]
const ROYAL_COLLECTIBLES := ["royal_diadem","twilight_edict","dawn_testament"]
const BOSS_COLLECTIBLES := ["mirror_thread","ember_heart","fault_scale","storm_feather","frost_teardrop","abyss_shedding"]
const BIOME_COLLECTIBLES_II := [
	["fog_chime","nightwatch_pin","weightless_oathstone"],
	["hourless_token","last_mass_leaf","mute_judgement"],
	["seer_eye","silver_stag_bell","meteor_core"],
	["sleeping_veil","blood_vow_clasp","thorn_heart"],
	["moonbone_flute","sunken_lantern","abyssal_rite_drum"],
	["redmoon_betrothal","weeping_cairn","nameless_standard"]
]
const BOSS_COLLECTIBLES_II := ["mirror_fate_ledger","vesper_last_page","fault_pulse_fossil","thunder_coffin_nail","frostbone_king_remains","storm_roc_sunheart"]
const ROYAL_COLLECTIBLES_II := ["bloodmoon_nightwomb","abyssal_motherheart","eternal_night_thronecore"]
const NEW_COLLECTIBLES := [
	"fog_chime","nightwatch_pin","weightless_oathstone","hourless_token","last_mass_leaf","mute_judgement",
	"seer_eye","silver_stag_bell","meteor_core","sleeping_veil","blood_vow_clasp","thorn_heart",
	"moonbone_flute","sunken_lantern","abyssal_rite_drum","redmoon_betrothal","weeping_cairn","nameless_standard",
	"mirror_fate_ledger","vesper_last_page","fault_pulse_fossil","thunder_coffin_nail","frostbone_king_remains",
	"storm_roc_sunheart","bloodmoon_nightwomb","abyssal_motherheart","eternal_night_thronecore"
]

static func biome_collectible(biome: int, variant: int) -> String:
	return BIOME_COLLECTIBLES[clampi(biome,0,BIOME_COLLECTIBLES.size()-1)][clampi(variant,0,2)]

static func collectible_index(kind: String) -> int:
	var index := 0
	for biome in BIOME_COLLECTIBLES:
		for collectible in biome:
			if collectible==kind: return index
			index+=1
	for collectible in BOSS_COLLECTIBLES+ROYAL_COLLECTIBLES:
		if collectible==kind: return index
		index+=1
	for collectible in NEW_COLLECTIBLES:
		if collectible==kind: return index
		index+=1
	return -1

static func biome_collectible_set(biome: int) -> Array:
	var index := clampi(biome,0,BIOME_COLLECTIBLES.size()-1)
	return BIOME_COLLECTIBLES[index]+BIOME_COLLECTIBLES_II[index]
const TALENTS = ["生命强化", "火力校准", "轻装步伐"]
# Field weapons are loot and nothing else: a
# Watcher can only ever hold one of them by finding it and putting it on, so the
# index below is also the index a looted weapon stores in its "weapon" field.
const WEAPONS = [
	{"name":"守夜步枪", "rate":0.23, "windup":0.0, "damage":31.0, "reach":680.0, "knock":9.0, "scaling":{"strength":"D","dexterity":"B","intelligence":"-","arcane":"-"}, "mana_cost":0},
	{"name":"绯红单手剑", "rate":0.38, "windup":0.10, "damage":38.0, "reach":112.0, "knock":20.0, "scaling":{"strength":"C","dexterity":"B","intelligence":"-","arcane":"-"}, "mana_cost":0},
	{"name":"破晓双手剑", "rate":0.88, "windup":0.34, "damage":88.0, "reach":158.0, "knock":58.0, "scaling":{"strength":"A","dexterity":"D","intelligence":"-","arcane":"-"}, "mana_cost":0},
	{"name":"星辉法杖", "rate":0.62, "windup":0.22, "damage":55.0, "reach":700.0, "knock":16.0, "scaling":{"strength":"-","dexterity":"-","intelligence":"B","arcane":"-"}, "mana_cost":5},
	{"name":"赤陨法杖", "family":3, "spell":"meteor", "desc":"陨石命中后爆炸，波及附近敌人。", "rate":1.38, "windup":0.72, "damage":145.0, "reach":650.0, "knock":48.0, "speed":430.0, "scaling":{"strength":"D","dexterity":"-","intelligence":"A","arcane":"-"}, "mana_cost":12},
	{"name":"霜针短杖", "family":3, "spell":"needle", "desc":"短吟唱高速连射冰针，单发伤害低。", "rate":0.20, "windup":0.045, "damage":21.0, "reach":690.0, "knock":5.0, "speed":1050.0, "scaling":{"strength":"-","dexterity":"D","intelligence":"B","arcane":"-"}, "mana_cost":2},
	{"name":"鸣雷之杖", "family":3, "spell":"chain", "desc":"雷击命中后向最多三名附近敌人跳跃。", "rate":0.68, "windup":0.27, "damage":60.0, "reach":660.0, "knock":16.0, "speed":700.0, "scaling":{"strength":"-","dexterity":"C","intelligence":"B","arcane":"-"}, "mana_cost":6},
	{"name":"月弧法杖", "family":3, "spell":"moon", "desc":"月刃穿过最多四名敌人。", "rate":0.76, "windup":0.30, "damage":66.0, "reach":720.0, "knock":12.0, "speed":700.0, "scaling":{"strength":"-","dexterity":"D","intelligence":"A","arcane":"C"}, "mana_cost":6},
	{"name":"曦光棱镜杖", "family":3, "spell":"prism", "desc":"释放瞬间贯穿直线上的所有敌人。", "rate":0.96, "windup":0.45, "damage":86.0, "reach":640.0, "knock":25.0, "scaling":{"strength":"-","dexterity":"-","intelligence":"A","arcane":"-"}, "mana_cost":7},
	{"name":"烬羽散华杖", "family":3, "spell":"scatter", "desc":"一次射出五枚扇形火羽，近距可集中命中；同次攻击的后续火羽对同一目标造成 12% 伤害。", "rate":0.55, "windup":0.16, "damage":50.0, "reach":550.0, "knock":8.0, "speed":670.0, "scaling":{"strength":"-","dexterity":"C","intelligence":"B","arcane":"-"}, "mana_cost":4},
	{"name":"虚涡法杖", "family":3, "spell":"vortex", "desc":"制造范围爆发，并将附近敌人卷向中心。", "rate":1.08, "windup":0.46, "damage":93.0, "reach":570.0, "knock":0.0, "speed":390.0, "scaling":{"strength":"-","dexterity":"-","intelligence":"B","arcane":"B"}, "mana_cost":8},
	{"name":"蚀月长枪杖", "family":3, "spell":"eclipse", "desc":"漫长蓄力后发射贯穿最多五名敌人的重型魔枪。", "rate":1.58, "windup":0.95, "damage":175.0, "reach":850.0, "knock":65.0, "speed":920.0, "scaling":{"strength":"C","dexterity":"-","intelligence":"S","arcane":"-"}, "mana_cost":14},
	{"name":"鸦喙刺剑", "family":1, "pattern":"thrust", "desc":"狭长突刺，贯穿前方一线敌人。", "rate":0.42, "windup":0.13, "damage":42.0, "reach":174.0, "knock":24.0, "scaling":{"strength":"E","dexterity":"A","intelligence":"-","arcane":"-"}, "mana_cost":0},
	{"name":"回环弯刀", "family":1, "pattern":"spin", "desc":"旋身环斩，命中身边所有敌人。", "rate":0.64, "windup":0.23, "damage":51.0, "reach":118.0, "knock":20.0, "scaling":{"strength":"D","dexterity":"A","intelligence":"-","arcane":"-"}, "mana_cost":0},
	{"name":"断潮巨刃", "family":2, "pattern":"cleave", "desc":"向前横扫宽阔扇面，击退敌群。", "rate":1.02, "windup":0.39, "damage":105.0, "reach":192.0, "knock":72.0, "scaling":{"strength":"S","dexterity":"E","intelligence":"-","arcane":"-"}, "mana_cost":0},
	{"name":"裂地重剑", "family":2, "pattern":"quake", "desc":"蓄力砸地，震伤周身敌人。", "rate":1.24, "windup":0.56, "damage":122.0, "reach":140.0, "knock":85.0, "scaling":{"strength":"S","dexterity":"-","intelligence":"-","arcane":"-"}, "mana_cost":0},
	{"name":"暮羽长弓", "family":0, "spell":"arrow", "desc":"拉弓射出贯穿两名敌人的箭矢；消耗弹药。", "rate":0.56, "windup":0.18, "damage":58.0, "reach":820.0, "knock":24.0, "speed":1050.0, "scaling":{"strength":"D","dexterity":"A","intelligence":"-","arcane":"-"}, "mana_cost":0}
]
# The temporary weapon every hero sets out with, one per hero, appended after the
# field weapons so the whole game keeps addressing a weapon by a single int.
# They exist so a Watcher can fight on the way to their first pickup and nothing
# more: each one is strictly weaker than the field weapon it imitates, it can
# never be found, never drops and never takes a quality bonus. "family" names the
# field weapon whose attack art, slash VFX and impact audio it borrows.
#
# STARTER_BASE is the first issue index. GDScript will not fold WEAPONS.size()
# into a constant, so this literal has to track the table above; tests/systems.gd
# asserts the two stay equal.
const STARTER_BASE := 17
const STARTER_WEAPONS = [
	{"name":"黑铁短剑", "rate":0.30, "windup":0.05, "damage":13.0, "reach":84.0, "knock":10.0, "family":1, "scaling":{"strength":"E","dexterity":"D","intelligence":"-","arcane":"-"}, "mana_cost":0},
	{"name":"祭祀短杖", "rate":0.58, "windup":0.20, "damage":22.0, "reach":520.0, "knock":8.0, "family":3, "scaling":{"strength":"-","dexterity":"-","intelligence":"D","arcane":"-"}, "mana_cost":3},
	{"name":"破碎大剑", "rate":0.98, "windup":0.34, "damage":37.0, "reach":150.0, "knock":40.0, "family":2, "scaling":{"strength":"D","dexterity":"E","intelligence":"-","arcane":"-"}, "mana_cost":0},
	{"name":"湮魂之镰", "rate":0.62, "windup":0.22, "damage":18.0, "reach":110.0, "knock":16.0, "family":1, "icon":"soul_scythe", "scaling":{"strength":"E","dexterity":"-","intelligence":"C","arcane":"D"}, "mana_cost":0}
]
const GEAR = [
	{"name":"守夜护甲", "desc":"最大生命 +20，受击伤害 -5%", "hp":20.0,"defense":0.05,"damage":0.0,"speed":0.0},
	{"name":"血月瞄具", "desc":"武器伤害 +15%", "hp":0.0,"damage":0.15,"speed":0.0},
	{"name":"渡鸦轻靴", "desc":"移动速度 +20", "hp":0.0,"damage":0.0,"speed":20.0}
]
# The camp issue gear is bought, not picked: one piece is worn at a time and the
# three are unordered in kind (armour / sight / boots), so the price list — not the
# index order — decides what an upgrade costs. EXCHANGING settles the difference:
# a dearer piece is paid for, a cheaper one refunds, and the piece left behind is
# destroyed. `Profile.data.gear` is -1 while nothing is worn.
const GEAR_PRICES := [180,420,300]

# Safe read of the camp issue gear: -1 (nothing bought yet) and any hand-edited
# index answer with an empty dictionary instead of crashing the stat maths.
static func gear_of(index: int) -> Dictionary:
	if index<0 or index>=GEAR.size():
		return {}
	return GEAR[index]

static func gear_price(index: int) -> int:
	if index<0 or index>=GEAR_PRICES.size():
		return 0
	return GEAR_PRICES[index]
# In-run loot uses the same six qualities as the backpacks. A weapon only pays
# out while the player is actually holding that weapon; the three gear slots
# (armour / sight / boots) always pay out.
const QUALITY_KEYS := ["white","green","blue","purple","gold","red"]
const WEAPON_DAMAGE_BONUS := [0.0,0.10,0.22,0.36,0.52,0.72]
const WEAPON_RATE_BONUS := [0.0,0.05,0.10,0.15,0.21,0.28]
const GEAR_HP := [12.0,20.0,30.0,42.0,58.0,78.0]
const GEAR_DEFENSE := [0.03,0.05,0.07,0.09,0.12,0.15]
const GEAR_DAMAGE := [0.05,0.08,0.12,0.17,0.23,0.30]
const GEAR_SPEED := [8.0,13.0,19.0,26.0,35.0,46.0]
const WEAPON_ICONS := ["rifle","sword","heavy","staff","staff_meteor","staff_needle","staff_chain","staff_moon","staff_prism","staff_scatter","staff_vortex","staff_eclipse","sword_thrust","sword_spin","heavy_cleave","heavy_quake","bow"]
const GEAR_ICONS := ["armor","sight","boots"]
# Keys that must survive a JSON save round trip. Items other than the six loot
# kinds stay inert; without this list a reload would drop stack counts, backpack
# quality and every weapon/gear field. `valued` is the "already counted towards the
# lifetime loot total" stamp: it travels with the instance so banking the same piece
# twice (withdraw, then store again) can never pay the tally twice.
const SAVED_ITEM_KEYS := ["count","quality","provision","weapon","gear","tier","valued"]

# The dimensional pocket is a permanent 4x4 container: it is written into the
# save file and its contents never drop, no matter how the expedition ends.
const POCKET_GRID := Vector2i(4,4)
const POCKET_NAME := "次元口袋"
# The camp vault is a real grid container too, so a deposit can be refused instead
# of the list growing without bound. 15x15 = 225 cells.
const WAREHOUSE_GRID := Vector2i(15,15)
const WAREHOUSE_NAME := "守夜人仓库"
# Backpack quality decides the size of the extra, droppable storage grid.
const BAG_TIERS = [
	{"key":"white", "name":"破损背包", "quality":"白色", "grid":Vector2i(3,3), "color":Color("cfc6bb")},
	{"key":"green", "name":"巡林背包", "quality":"绿色", "grid":Vector2i(4,4), "color":Color("8fc39a")},
	{"key":"blue", "name":"守夜背包", "quality":"蓝色", "grid":Vector2i(5,5), "color":Color("8fb6d8")},
	{"key":"purple", "name":"秘仪背包", "quality":"紫色", "grid":Vector2i(6,6), "color":Color("b48fd4")},
	{"key":"gold", "name":"圣血背包", "quality":"金色", "grid":Vector2i(7,7), "color":Color("dcbd7e")},
	{"key":"red", "name":"血月背包", "quality":"红色", "grid":Vector2i(8,8), "color":Color("dd6c7c")}
]
const DEFAULT_BAG_KEY := "white"

static func tier_index(key: String) -> int:
	for i in BAG_TIERS.size():
		if BAG_TIERS[i].key==key:
			return i
	return 0

static func tier(key: String) -> Dictionary:
	return BAG_TIERS[tier_index(key)]

static func bag_key(bag: Dictionary) -> String:
	var key := str(bag.get("key",DEFAULT_BAG_KEY))
	return key if has_tier(key) else DEFAULT_BAG_KEY

static func has_tier(key: String) -> bool:
	for entry in BAG_TIERS:
		if entry.key==key:
			return true
	return false

static func bag_grid(bag: Dictionary) -> Vector2i:
	return tier(bag_key(bag)).grid

static func bag_name(bag: Dictionary) -> String:
	return tier(bag_key(bag)).name

static func bag_quality(bag: Dictionary) -> String:
	return tier(bag_key(bag)).quality

static func bag_color(bag: Dictionary) -> Color:
	return tier(bag_key(bag)).color

# --- the weapon in hand ------------------------------------------------------
# One int addresses every weapon a player can hold: 0..STARTER_BASE-1 are field weapons a
# raid can hand out, STARTER_BASE.. are the three temporary issue weapons. Every
# combat, animation and audio consumer reads stats through weapon() and reads the
# four-way art/effect family through weapon_family(), so a hero issue weapon
# behaves like the field weapon it imitates without ever being one.
static func starter_index(hero: int) -> int:
	return STARTER_BASE+clampi(hero,0,STARTER_WEAPONS.size()-1)

static func is_starter(index: int) -> bool:
	return index>=STARTER_BASE and index<STARTER_BASE+STARTER_WEAPONS.size()

static func weapon(index: int) -> Dictionary:
	var build: Dictionary=preload("res://scripts/rogue_content.gd").weapon(index)
	if not build.is_empty(): return build
	if is_starter(index):
		return STARTER_WEAPONS[index-STARTER_BASE]
	return WEAPONS[clampi(index,0,WEAPONS.size()-1)]

static func scaling_text(index: int) -> String:
	var grades: Dictionary=weapon(index).get("scaling",{})
	var parts: Array[String] = []
	for key in ["strength","dexterity","intelligence","arcane"]:
		var at := WatcherAttributes.KEYS.find(key)
		parts.append("%s %s" % [WatcherAttributes.NAMES[at],str(grades.get(key,"-"))])
	return "补正 · "+" / ".join(parts)

static func weapon_name(index: int) -> String:
	return str(weapon(index).name)

static func weapon_family(index: int) -> int:
	if is_starter(index):
		return clampi(int(weapon(index).family),0,3)
	return int(weapon(index).get("family",clampi(index,0,3)))

static func roll_weapon(rng: RandomNumberGenerator) -> int:
	var category := rng.randf()
	var choices: Array[int] = []
	for index in WEAPONS.size():
		var family := weapon_family(index)
		if (category<0.30 and family==1) or (category>=0.30 and category<0.60 and family==2) or (category>=0.60 and category<0.78 and family==0) or (category>=0.78 and family==3):
			choices.append(index)
	return choices[rng.randi_range(0,choices.size()-1)]

# --- weapons and gear found in the field ------------------------------------
# Quality index 0..5 follows BAG_TIERS. A looted weapon remembers which of the
# four weapons it upgrades, a looted gear piece which of the three slots it fills.
static func tier_of(value: int) -> int:
	return clampi(value,0,QUALITY_KEYS.size()-1)

static func quality_name(value: int) -> String:
	return BAG_TIERS[tier_of(value)].quality

static func quality_color(value: int) -> Color:
	return BAG_TIERS[tier_of(value)].color

static func is_equipment(kind: String) -> bool:
	return kind=="weapon" or kind=="gear"

static func is_wearable(kind: String) -> bool:
	return is_equipment(kind) or kind=="charm"

# Which kinds the item bar's interact key can actually operate. A lootable relic,
# a stack of scrap or a blood crystal is treasure and nothing else, so a socket
# holding one is deliberately inert: the key falls through to whatever else it
# does rather than swallowing the press for no effect.
static func slot_operable(kind: String) -> bool:
	return is_wearable(kind) or kind=="backpack" or kind=="medicine" or kind=="ammo"

# A piece of loot is always one of the four field weapons: the hero issue weapons
# have no item form and can neither be found nor dropped.
static func make_equipment(kind: String, index: int, tier: int) -> Dictionary:
	if kind=="weapon":
		return {"kind":"weapon","weapon":clampi(index,0,WEAPONS.size()-1),"tier":tier_of(tier),"x":0,"y":0,"rot":false}
	return {"kind":"gear","gear":clampi(index,0,GEAR.size()-1),"tier":tier_of(tier),"x":0,"y":0,"rot":false}

static func weapon_bonus(item: Dictionary) -> float:
	if item.has("rogue_id"): return 0.0 # Run attributes are summed across all slots.
	return WEAPON_DAMAGE_BONUS[tier_of(int(item.get("tier",0)))]

static func weapon_rate_bonus(item: Dictionary) -> float:
	if item.has("rogue_id"): return preload("res://scripts/rogue_equipment.gd").value(item,"rate")
	return WEAPON_RATE_BONUS[tier_of(int(item.get("tier",0)))]

static func gear_slot(item: Dictionary) -> int:
	return clampi(int(item.get("gear",0)),0,GEAR.size()-1)

static func gear_bonus(item: Dictionary) -> float:
	if item.has("rogue_id"): return 0.0
	var table: Array = [GEAR_HP,GEAR_DAMAGE,GEAR_SPEED][gear_slot(item)]
	return table[tier_of(int(item.get("tier",0)))]

static func gear_defense(item: Dictionary) -> float:
	if item.has("rogue_id"): return 0.0
	return GEAR_DEFENSE[tier_of(int(item.get("tier",0)))] if gear_slot(item)==0 else 0.0

static func gear_desc(item: Dictionary) -> String:
	if item.has("rogue_id"): return preload("res://scripts/rogue_equipment.gd").description(item)
	var bonus := gear_bonus(item)
	match gear_slot(item):
		0: return "最大生命 +%d、受击伤害 -%d%%" % [int(round(bonus)),int(round(gear_defense(item)*100.0))]
		1: return "武器伤害 +%d%%" % int(round(bonus*100.0))
		_: return "移动速度 +%d" % int(round(bonus))

static func gear_slot_name(item: Dictionary) -> String:
	return ["护甲","瞄具","轻靴"][gear_slot(item)]

static func item_name(item: Dictionary) -> String:
	if item.has("rogue_id"):
		var info: Dictionary=preload("res://scripts/rogue_equipment.gd").definition(item)
		if not info.is_empty():
			return "%s %s%s" % [quality_name(int(item.get("tier",0))),info.name," · "+str(weapon(int(item.get("weapon",0))).name) if item.get("kind","")=="weapon" else ""]
	var kind := str(item.get("kind",""))
	if kind=="weapon":
		return "%s %s" % [quality_name(int(item.get("tier",0))),weapon(int(item.get("weapon",0))).name]
	if kind=="gear":
		return "%s %s" % [quality_name(int(item.get("tier",0))),GEAR[gear_slot(item)].name]
	return str(ITEMS.get(kind,{"name":kind}).name)

# The same name without the quality prefix, for cells too narrow to show it. The
# quality is already carried by the slot colour and the border.
static func item_short_name(item: Dictionary) -> String:
	if item.has("rogue_id"): return str(preload("res://scripts/rogue_equipment.gd").definition(item).get("name","装备"))
	var kind := str(item.get("kind",""))
	if kind=="weapon":
		return weapon(int(item.get("weapon",0))).name
	if kind=="gear":
		return GEAR[gear_slot(item)].name
	return item_name(item)

static func item_desc(item: Dictionary) -> String:
	if item.has("rogue_id"): return preload("res://scripts/rogue_equipment.gd").description(item)
	var kind := str(item.get("kind",""))
	if kind=="weapon":
		var info: Dictionary=weapon(int(item.get("weapon",0)))
		var rhythm := "前摇 %.2f 秒 · 周期 %.2f 秒 · 基础伤害 %d。" % [float(info.windup),float(info.rate),int(info.damage)]
		return str(info.get("desc",""))+rhythm+WeaponArts.text(int(item.get("weapon",0)))+" "+scaling_text(int(item.get("weapon",0)))+"。蓝耗 %d。" % int(info.get("mana_cost",0))+"持有时伤害 +%d%%、攻速 +%d%%。" % [int(round(weapon_bonus(item)*100.0)),int(round(weapon_rate_bonus(item)*100.0))]
	if kind=="gear":
		return "装备到%s槽：本局%s。" % [gear_slot_name(item),gear_desc(item)]
	return str(ITEMS.get(kind,{"desc":""}).desc)

# Quality raises the sale value of field equipment, so a red weapon is worth
# carrying home as well as wearing.
static func item_value(item: Dictionary) -> int:
	var kind := str(item.get("kind",""))
	var info: Dictionary=ITEMS.get(kind,{"value":0})
	if kind=="backpack":
		return int(round(float(info.value)*(1.0+0.65*tier_index(bag_key_of_item(item)))))
	if is_equipment(kind):
		return int(round(float(info.value)*(1.0+0.45*float(tier_of(int(item.get("tier",0)))))))
	return int(info.value)

static func market_value(item: Dictionary) -> int:
	if item.get("provision",false): return 0
	# Priced by what the pile really holds, not by its ceiling: see `units_of_item()`.
	var quantity := units_of_item(item)
	return item_value(item)*quantity

static func market_total(items: Array) -> int:
	var total := 0
	for item in items: total+=market_value(item)
	return total

static func item_color(item: Dictionary) -> Color:
	var kind := str(item.get("kind",""))
	if is_equipment(kind):
		return quality_color(int(item.get("tier",0)))
	if kind=="backpack":
		return tier(bag_key(item)).color
	# A trinket may declare a quality of its own: the knight's amulet is red
	# because it carries a tier, not because it is equipment.
	if item.has("tier"):
		return quality_color(int(item.get("tier",0)))
	return ITEMS[kind].color

static func item_icon(item: Dictionary) -> String:
	var kind := str(item.get("kind",""))
	if kind=="weapon":
		return weapon_icon(int(item.get("weapon",0)))
	if kind=="gear":
		return GEAR_ICONS[gear_slot(item)]
	return kind

# A field weapon always uses its family's icon; an issue weapon may ship its own
# art, which is what lets a recruit carry a visibly different starter.
static func weapon_icon(index: int) -> String:
	if index>=600: return WEAPON_ICONS[visual_weapon_index(index)]
	if is_starter(index):
		var starter: Dictionary=STARTER_WEAPONS[clampi(index-STARTER_BASE,0,STARTER_WEAPONS.size()-1)]
		return str(starter.get("icon",WEAPON_ICONS[clampi(weapon_family(index),0,WEAPON_ICONS.size()-1)]))
	return WEAPON_ICONS[clampi(index,0,WEAPON_ICONS.size()-1)]

# Icons for a bare kind, used by the code that preloads one texture per item
# kind; a concrete weapon or gear item resolves through item_icon() instead.
static func visual_weapon_index(index: int) -> int:
	if index<600: return clampi(index,0,20)
	var info: Dictionary=weapon(index)
	if int(info.family)==0: return 16 if info.spell=="arrow" else 0
	if int(info.family)==1: return 12 if info.pattern=="thrust" else 13 if info.pattern=="spin" else 1
	if int(info.family)==2: return 15 if info.pattern=="spin" else 14
	return {"star":3,"meteor":4,"needle":5,"chain":6,"moon":7,"prism":8,"scatter":9,"vortex":10,"eclipse":11}.get(info.spell,3)

static func kind_icon(kind: String) -> String:
	if kind=="weapon":
		return WEAPON_ICONS[0]
	if kind=="gear":
		return GEAR_ICONS[0]
	return kind

static func slot_count(key: String) -> int:
	var grid: Vector2i=tier(key).grid
	return grid.x*grid.y

# Raw grid calls with no size fall back to the original 6x4 field backpack so a
# stray call can never silently inherit some tier's size.
const LEGACY_GRID := Vector2i(6,4)

static func pocket_grid(pocket: Dictionary) -> Vector2i:
	return Vector2i(int(pocket.get("gw",POCKET_GRID.x)),int(pocket.get("gh",POCKET_GRID.y)))

static func grid_of(grid: Vector2i) -> Vector2i:
	return LEGACY_GRID if grid==Vector2i.ZERO else grid

static func make_bag(key: String = DEFAULT_BAG_KEY) -> Dictionary:
	return {"key":key if not key.is_empty() else DEFAULT_BAG_KEY,"items":[],"next":1}

# A loose backpack is a piece of equipment the player can wear, so it occupies
# cells like one: the roomier packs are physical objects rather than a 1x1 token.
# Purple is where they start taking a 2x2 block.
const BULKY_BAG_TIER := 3

static func backpack_cells(key: String) -> Vector2i:
	return Vector2i(2,2) if tier_index(key)>=BULKY_BAG_TIER else Vector2i(1,1)

# A bag on the floor or in a container remembers its quality in "quality"; the
# equipped one keeps it in "key". Reading both is what makes a loose purple pack
# really take its 2x2 block instead of claiming a single cell.
static func bag_key_of_item(item: Dictionary) -> String:
	return bag_key({"key":str(item.get("quality",item.get("key",DEFAULT_BAG_KEY)))})

static func item_size(item: Dictionary) -> Vector2i:
	if str(item.get("kind",""))=="backpack":
		return backpack_cells(bag_key_of_item(item))
	var s: Vector2i = ITEMS[item.kind].size
	return Vector2i(s.y,s.x) if item.get("rot",false) else s

# Two items overlap when they share a cell. This is spelled out as four integer
# comparisons rather than handed to Rect2i.intersects(), which in this build
# answers false for rectangles that plainly share cells — a 1x2 beside a 1x2,
# and a 2x1 scrap lying across the top of one. The whole packing rule stands on
# this one answer, so it is computed here and nowhere else.
static func overlaps(at: Vector2i, size: Vector2i, other: Dictionary) -> bool:
	var other_at := Vector2i(int(other.x),int(other.y))
	var other_size := item_size(other)
	if at.x+size.x <= other_at.x or other_at.x+other_size.x <= at.x:
		return false
	if at.y+size.y <= other_at.y or other_at.y+other_size.y <= at.y:
		return false
	return true

static func can_place(bag: Array, item: Dictionary, at: Vector2i, ignore: int = -1, grid: Vector2i = Vector2i.ZERO) -> bool:
	var dims := grid_of(grid)
	var s := item_size(item)
	if at.x < 0 or at.y < 0 or at.x+s.x > dims.x or at.y+s.y > dims.y:
		return false
	for i in bag.size():
		if i != ignore and overlaps(at,s,bag[i]):
			return false
	return true

static func insert(bag: Array, kind: String, grid: Vector2i = Vector2i.ZERO) -> bool:
	var item := {"kind":kind,"x":0,"y":0,"rot":false}
	var dims := grid_of(grid)
	for rotate in [false,true]:
		item.rot = rotate
		for y in dims.y:
			for x in dims.x:
				if can_place(bag,item,Vector2i(x,y),-1,grid):
					item.x=x
					item.y=y
					bag.append(item)
					return true
	return false

# --- container helpers -------------------------------------------------------
# A "container" is a grid dictionary: {"items":[...], "gw":w, "gh":h}.
# The equipped backpack stores its quality in "key"; the pocket uses 4x4.

static func make_container(items: Array = [], grid: Vector2i = POCKET_GRID, key: String = DEFAULT_BAG_KEY) -> Dictionary:
	return {"key":key,"items":items,"gw":grid.x,"gh":grid.y,"next":1}

static func container_items(container: Dictionary) -> Array:
	return container.get("items",[])

static func container_grid(container: Dictionary) -> Vector2i:
	# Player containers carry their size as gw/gh; a loot container on the map
	# carries it as "grid". Reading both keeps the packing rules honest: a small
	# drop stays small and the 5x5 cathedral chest really does have 25 cells.
	var grid = container.get("grid",null)
	if grid is Vector2i:
		return grid
	return Vector2i(int(container.get("gw",POCKET_GRID.x)),int(container.get("gh",POCKET_GRID.y)))

static func container_free(container: Dictionary) -> int:
	var total := container_grid(container).x*container_grid(container).y
	for item in container_items(container):
		var size := item_size(item)
		total-=size.x*size.y
	return total

static func clean_container(container: Dictionary, grid: Vector2i) -> Dictionary:
	var list: Array = container.get("items",[])
	var result: Array = []
	for entry in list:
		if not entry is Dictionary:
			continue
		var kind := str(entry.get("kind",""))
		if not ITEMS.has(kind):
			continue
		var item := {"kind":kind,"x":int(entry.get("x",0)),"y":int(entry.get("y",0)),"rot":bool(entry.get("rot",false))}
		for key in SAVED_ITEM_KEYS:
			if entry.has(key):
				item[key]=entry[key]
		clamp_entry(item)
		if can_place(result,item,Vector2i(item.x,item.y),-1,grid):
			result.append(item)
	if container.has("key"):
		container["key"]=bag_key(container)
	container["items"]=result
	# Player storage is sized by gw/gh only: a stray "grid" left in a hand-edited
	# save must not be able to resize a backpack.
	container.erase("grid")
	container["gw"]=grid.x
	container["gh"]=grid.y
	container["next"]=maxi(int(container.get("next",1)),1)
	return container

# One item, validated exactly the way a container's contents are. The saved loadout
# and the item bar hold entries that have no grid position of their own, so they use
# this instead of a container round trip — a hand-edited save cannot smuggle an
# unknown kind or a weapon index past the live tables through either path.
static func clean_slot_entry(entry) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var kind := str(entry.get("kind",""))
	if not ITEMS.has(kind):
		return {}
	var item := {"kind":kind}
	for key in SAVED_ITEM_KEYS:
		if entry.has(key):
			item[key]=entry[key]
	return clamp_entry(item)

# The kind-specific fields a saved item carries, clamped to the live tables.
static func clamp_entry(item: Dictionary) -> Dictionary:
	var kind := str(item.get("kind",""))
	# Bound a pile's stored count here, at the one gate every saved entry passes through.
	# Only present keys are touched, so equipment entries gain nothing.
	if item.has("count"):
		item["count"]=clampi(int(item["count"]),1,STACK_ENTRY_CAP)
	if kind=="weapon":
		item["weapon"]=clampi(int(item.get("weapon",0)),0,WEAPONS.size()-1)
		item["tier"]=tier_of(int(item.get("tier",0)))
	elif kind=="gear":
		item["gear"]=clampi(int(item.get("gear",0)),0,GEAR.size()-1)
		item["tier"]=tier_of(int(item.get("tier",0)))
	elif kind=="backpack":
		item["quality"]=bag_key({"key":item.get("quality",DEFAULT_BAG_KEY)})
	return item

# The worn kit as it is stored in the save file: one weapon, three gear pieces, two
# charms and the three quick sockets. The shape matches `TideSession.empty_equipment()`
# plus `empty_item_slots()`, so the save file and the live player dictionary can be
# copied between without a translation layer.
static func empty_loadout() -> Dictionary:
	return {"weapon":{},"gear":[{},{},{}],"charm":[{},{}],"slots":[{},{},{}]}

# A saved loadout, validated: an unknown kind, a weapon in the armour slot or a
# hand-edited index is dropped rather than worn. Shared by the profile (on load and
# save) and by the session (when a raid is configured), so both agree on the shape.
static func clean_loadout(raw) -> Dictionary:
	var clean := empty_loadout()
	if not raw is Dictionary:
		return clean
	var weapon := clean_slot_entry(raw.get("weapon",{}))
	if not weapon.is_empty() and str(weapon.get("kind",""))=="weapon":
		clean["weapon"]=weapon
	clean["gear"]=clean_slot_list(raw.get("gear",[]),3,"gear")
	clean["charm"]=clean_slot_list(raw.get("charm",[]),2,"charm")
	# The item bar takes any item at all, so its sockets are only checked against
	# the catalog.
	clean["slots"]=clean_slot_list(raw.get("slots",[]),3,"")
	return clean

# A fixed-length list of validated sockets: a missing or malformed entry leaves the
# socket empty. `kind` is the only item kind the socket accepts ("" = anything).
static func clean_slot_list(raw, size: int, kind: String) -> Array:
	var source: Array = raw if raw is Array else []
	var list: Array = []
	for i in size:
		var entry: Dictionary=clean_slot_entry(source[i]) if i<source.size() else {}
		if not kind.is_empty() and not entry.is_empty() and str(entry.get("kind",""))!=kind:
			entry={}
		list.append(entry)
	return list

static func add_item(container: Dictionary, kind: String) -> bool:
	var list: Array = container.get("items",[])
	if not insert(list,kind,container_grid(container)):
		return false
	list.back()["id"]=int(container.get("next",1))
	container["next"]=int(container.get("next",1))+1
	return true

# Which container should receive a piece of loot: high quality is worth the safe
# pocket, everything else fills the backpack the player is carrying. The quality
# is read from the fields loot really carries — a weapon or a gear piece stores
# it in "tier", a loose backpack in "quality" — so plain supplies such as
# crystals, scrap and relics are white by default and go to the bag.
const POCKET_TIER := 4

static func item_tier(item: Dictionary) -> int:
	if item.has("tier"):
		return tier_of(int(item.get("tier",0)))
	if str(item.get("kind",""))=="backpack":
		return tier_index(str(item.get("quality",DEFAULT_BAG_KEY)))
	return tier_of(int(ITEMS.get(str(item.get("kind","")),{}).get("tier",0)))

static func high_quality(item: Dictionary) -> bool:
	return item_tier(item)>=POCKET_TIER

# Which container field loot belongs in: valuable relics are sunk into the safe
# pocket, everything else stays in the backpack it was found with. Unchanged by
# the quality rule below, which only steers the double click in the search
# window.
static func prefers_pocket(kind: String) -> bool:
	return kind=="relic" or int(ITEMS.get(kind,{}).get("tier",0))>=4

# Loot containers are searched, and their contents are laid out as a tidy grid
# instead of being packed wherever they fit.
static func chest_grid(class_index: int) -> Vector2i:
	return Vector2i(5,5) if class_index>=2 else Vector2i(4,4)

# How many units of one kind fit in a single pile. This table is the single source
# of truth: a kind that is absent is a plain object whose ceiling is 1, which is
# exactly what "not stackable" means. `stacks()` is derived from it, so the ceiling
# and the question "does this kind stack" can never drift apart.
#
# Field medicine and ammo boxes are the deliberately tightest piles: they are the
# things a raid is supposed to run out of, so the player has to come back for them.
const STACK_LIMITS := {
	"medicine":3, "ammo":3,
	"crystal":5, "scrap":5, "charm":5, "bait":5,
	"wheat":5, "carrot":5, "herb":5, "silver":5, "moon":5, "gold":5,
	"wheat_seed":5, "carrot_seed":5, "herb_seed":5,
}

static func max_stack(kind: String) -> int:
	return int(STACK_LIMITS.get(kind,1))

# A hard bound on any single pile's count, applied when an entry is cleaned. It exists so
# a hand-edited save cannot ask the splitter to seat a million units at once. The ceiling
# table above is what governs how piles are *built*; this cap is many times every ceiling,
# so it only ever bites a count that was never a real pile.
const STACK_ENTRY_CAP := 99

# The units a pile really holds. The ceiling never applies to reading: clamping the read
# would under-count a pile that predates a ceiling change, and the units it hid could never
# be sold or cooked again. `clean_slot_entry()` is what keeps a stored count sane.
static func units_of_item(item: Dictionary) -> int:
	return maxi(1,int(item.get("count",1)))

# A stackable kind shows a count badge; a ceiling of 1 never does. Derived from
# `STACK_LIMITS`, so adding a row there makes a kind stackable everywhere at once.
static func stacks(kind: String) -> bool:
	return max_stack(kind)>1

# Places one unit of loot in the first free cell of a row-major layout. Stackable
# kinds grow their counter in place, which keeps a searched chest readable.
static func place_loot(container: Dictionary, kind: String) -> bool:
	var list: Array = container.get("items",[])
	if stacks(kind):
		for item in list:
			if item.kind==kind and int(item.get("count",1))<max_stack(kind):
				item["count"]=int(item.get("count",1))+1
				return true
	return place_item(container,{"kind":kind,"rot":false,"count":1})

# --- aiming one unit at one cell ---------------------------------------------
# The right-button hand sets a single unit down at a time, on the cell the player
# aimed at. That is a different question from the one `resolve_drop()` answers:
# a whole-drag landing is allowed to look for a nearby hole so the drag always
# ends somewhere, while a single aimed unit has to say "here, or not at all" and
# let the caller decide whether to fall back.

# Whether `item`'s footprint already covers `cell`.
static func covers(item: Dictionary, cell: Vector2i) -> bool:
	var s := item_size(item)
	return cell.x>=int(item.x) and cell.x<int(item.x)+s.x and cell.y>=int(item.y) and cell.y<int(item.y)+s.y

# Index of the pile sitting on `cell` that would take one more unit of `kind`, or -1.
static func stack_at(items: Array, kind: String, cell: Vector2i) -> int:
	for i in items.size():
		var item = items[i]
		if not item is Dictionary: continue
		if str(item.get("kind",""))!=kind: continue
		if int(item.get("count",1))>=max_stack(kind): continue
		if not covers(item,cell): continue
		return i
	return -1

# Puts exactly one unit of `kind` **at `cell`** and nowhere else: it grows the pile
# already standing on that cell when that pile is the same kind with room, and
# otherwise starts a new one-unit pile whose footprint still contains that cell.
# `blank` carries the fields that are not about quantity (provision, valued, a
# backpack's key), because a fresh pile has to keep them.
#
# Returns the cell the unit landed on, or (-1,-1) when that cell cannot take it.
static func add_unit_at(container: Dictionary, kind: String, cell: Vector2i, blank: Dictionary, rot: bool = false) -> Vector2i:
	if not ITEMS.has(kind):
		return Vector2i(-1,-1)
	var items: Array=container_items(container)
	if stacks(kind):
		var pile := stack_at(items,kind,cell)
		if pile>=0:
			items[pile]["count"]=int(items[pile].get("count",1))+1
			return cell
	var one: Dictionary=blank.duplicate(true)
	one["kind"]=kind
	one["count"]=1
	one["rot"]=rot
	var dims := item_size(one)
	var grid := container_grid(container)
	# The aimed cell has to be *inside* the new footprint, so a 2x2 piece aimed at
	# its bottom-right corner is still allowed to land: walk the corners around the
	# cell rather than insisting the cell is the top-left one.
	for oy in range(-(dims.y-1),1):
		for ox in range(-(dims.x-1),1):
			var at := Vector2i(cell.x+ox,cell.y+oy)
			if not can_place(items,one,at,-1,grid): continue
			one["x"]=at.x
			one["y"]=at.y
			items.append(one)
			return at
	return Vector2i(-1,-1)

# Where an entry actually lands when placed at a cell: the cell itself when it fits,
# otherwise the nearest free cell, and (-1,-1) only when nothing is free. This is the
# pure core of `Session.resolve_drop()`, shared with the per-unit placement below so a
# whole drag and a single aimed unit agree on what "nearby" means.
static func nearest_fit(items: Array, grid: Vector2i, entry: Dictionary, at: Vector2i, skip: int = -1) -> Vector2i:
	if can_place(items,entry,at,skip,grid):
		return at
	var origin := at
	if at.x>=grid.x:
		origin=Vector2i(grid.x-1,at.y)
	if origin.y>=grid.y:
		origin=Vector2i(origin.x,grid.y-1)
	origin=Vector2i(maxi(0,origin.x),maxi(0,origin.y))
	var best := Vector2i(-1,-1)
	var best_distance := 1.0e12
	for y in grid.y:
		for x in grid.x:
			var cell := Vector2i(x,y)
			if not can_place(items,entry,cell,skip,grid):
				continue
			var distance := Vector2(cell-origin).length()
			if distance<best_distance:
				best_distance=distance
				best=cell
	return best

# Puts `units` of `kind` into one container, aimed at `cell`.
#
# The aimed cell is asked first and answered exactly: a same-kind pile with room
# standing on that cell grows, an empty cell starts a new pile there. Only when the aim
# cannot take the unit does the search widen — same-kind piles with room first, then the nearest free cell — which is what makes one left-click of the right-button hand
# land somewhere sensible instead of doing nothing.
#
# Deliberately **no** `compact_arrivals()`: repacking the grid straight after an aimed
# unit would move the very cell the player just aimed at. That is the promise behind the
# hand's "locked" cell — what it placed stays put until the gesture ends.
#
# Returns {"placed":units_that_fit,"cell":first_cell_used(-1,-1 when nothing fit)}.
static func place_units_in(container: Dictionary, kind: String, units: int, cell: Vector2i, blank: Dictionary, rot: bool = false) -> Dictionary:
	var result := {"placed":0,"cell":Vector2i(-1,-1)}
	if container.is_empty() or units<=0 or not ITEMS.has(kind):
		return result
	var items: Array=container_items(container)
	var grid: Vector2i=container_grid(container)
	var one: Dictionary=blank.duplicate(true)
	one["kind"]=kind
	one["count"]=1
	one["rot"]=rot
	var left := units
	# 1) The cell the player aimed at, answered strictly.
	var aimed := add_unit_at(container,kind,cell,blank,rot)
	if aimed.x>=0:
		result["cell"]=aimed
		result["placed"]=1
		left-=1
	# 2) Any same-kind pile that still has room, nearest to the aim first: a stackable
	# unit fills a pile up before it starts another one, which is what "top it up" means.
	while left>0:
		var best := -1
		var best_distance := 1.0e12
		for i in items.size():
			if not items[i] is Dictionary: continue
			if str(items[i].get("kind",""))!=kind: continue
			if int(items[i].get("count",1))>=max_stack(kind): continue
			var distance := Vector2(Vector2i(int(items[i].x),int(items[i].y))-cell).length()
			if distance<best_distance:
				best_distance=distance
				best=i
		if best<0: break
		if int(result.placed)==0: result["cell"]=Vector2i(int(items[best].x),int(items[best].y))
		items[best]["count"]=int(items[best].get("count",1))+1
		result["placed"]=int(result.placed)+1
		left-=1
	# 3) The nearest free cell, for whatever is left: the only step that grows the layout,
	# so it comes last.
	while left>0:
		var at := nearest_fit(items,grid,one,cell)
		if at.x<0: break
		var landed := add_unit_at(container,kind,at,blank,rot)
		if landed.x<0: break
		if int(result.placed)==0: result["cell"]=landed
		result["placed"]=int(result.placed)+1
		left-=1
	if int(result.placed)>0:
		container["next"]=maxi(int(container.get("next",1)),1)+1
	return result

# Splits every pile that sits above its ceiling into extra piles of the same kind,
# so lowering a ceiling can never destroy what a save already holds.
#
# Loss-proof by construction: the pile is trimmed to its ceiling, the units that fit are
# rehoused inside the grid, and every unit that does not fit is appended to `into_spill`
# (as a clean one-kind entry) so the caller can park it somewhere real. Nothing is ever
# destroyed, and nothing is ever counted twice. Splitting respects
# provenance: a camp-issued pile only ever grows into camp-issued piles.
#
# Returns how many units went to `into_spill`.
static func split_over_limit(container: Dictionary, into_spill: Array = []) -> int:
	var items: Array=container_items(container)
	var over: Array=[]
	for item in items:
		if not item is Dictionary: continue
		var kind := str(item.get("kind",""))
		if kind.is_empty(): continue
		var have := int(item.get("count",1))
		var limit := max_stack(kind)
		if have>limit: over.append(item)
	var spilled := 0
	for item in over:
		var kind := str(item.get("kind",""))
		var blank: Dictionary=item.duplicate(true)
		var extra := int(item.get("count",1))-max_stack(kind)
		var placed := 0
		while placed<extra:
			var grown := false
			for existing in items:
				if existing==item or not existing is Dictionary: continue
				if str(existing.get("kind",""))!=kind: continue
				if bool(existing.get("provision",false))!=bool(blank.get("provision",false)): continue
				if int(existing.get("count",1))>=max_stack(kind): continue
				existing["count"]=int(existing.get("count",1))+1
				grown=true
				break
			if not grown:
				var one: Dictionary=blank.duplicate(true)
				one.erase("valued")
				one["count"]=1
				if not place_item(container,one):
					break
			placed+=1
		# Trimmed to its ceiling either way: what could not be rehoused inside the grid is
		# handed to the caller in `into_spill`, which is a real place for it. The units are
		# moved, never duplicated and never destroyed.
		item["count"]=max_stack(kind)
		if placed<extra:
			var rest: Dictionary=blank.duplicate(true)
			rest["count"]=extra-placed
			into_spill.append(rest)
			spilled+=extra-placed
	return spilled

# Places an already-built item entry, keeping every field it carries: without
# this a re-tidy would quietly strip a weapon's quality, its weapon index or a
# loose backpack's colour.
static func place_item(container: Dictionary, entry: Dictionary) -> bool:
	var grid := container_grid(container)
	var list: Array = container.get("items",[])
	var probe: Dictionary=entry.duplicate()
	probe["rot"]=bool(entry.get("rot",false))
	for y in grid.y:
		for x in grid.x:
			if can_place(list,probe,Vector2i(x,y),-1,grid):
				probe["x"]=x
				probe["y"]=y
				list.append(probe)
				container["next"]=int(container.get("next",1))+1
				return true
	return false

# Rearranges every item into row-major order, so a searched container looks
# tidy and new arrivals always have somewhere obvious to go. Stackable kinds are
# merged back together, everything else keeps its own fields.
static func tidy(container: Dictionary) -> void:
	var pending: Array = []
	for item in container_items(container):
		var kind := str(item.kind)
		if stacks(kind):
			for i in int(item.get("count",1)):
				pending.append(kind)
		else:
			pending.append(item.duplicate())
	container["items"]=[]
	for entry in pending:
		if entry is String:
			place_loot(container,entry)
		else:
			place_item(container,entry)

## Repacks a container with one piece **seated first**: the item the player asked to
## turn gets the freed grid before anything else, so a rotation can never be the thing
## that loses its seat. Everything else is laid back down the way `tidy()` does it, and
## the entries that no longer fit are returned in the order they lost their seats — the
## caller decides where they go (the vault, the bar, the ground) or rolls the whole
## thing back. Nothing is ever dropped on the floor by this function itself.
static func tidy_around(container: Dictionary, focus: Dictionary) -> Array:
	var rest: Array = []
	for item in container_items(container):
		var kind := str(item.kind)
		if stacks(kind):
			for i in int(item.get("count",1)):
				rest.append(kind)
		else:
			rest.append(item.duplicate())
	container["items"]=[]
	var spill: Array = []
	if not place_item(container,focus):
		spill.append(focus)
	for entry in rest:
		var seated := place_loot(container,entry) if entry is String else place_item(container,entry)
		if not seated:
			spill.append({"kind":entry,"count":1} if entry is String else entry)
	return spill

static func can_hold(container: Dictionary, kind: String) -> bool:
	if not ITEMS.has(kind):
		return false
	var probe: Array = container_items(container).duplicate()
	return insert(probe,kind,container_grid(container))

# Swaps the equipped backpack with a spare from the cabinet. Items already in the
# equipped backpack must still fit, otherwise the swap is refused (not destroyed).
static func swap_bags(p: Dictionary, index: int) -> bool:
	var cabinet: Array = p.get("bags",[])
	if index<0 or index>=cabinet.size():
		return false
	var current: Dictionary = p.get("backpack",make_bag())
	var candidate: Dictionary = cabinet[index]
	var space: Array = current.get("items",[])
	candidate["gw"]=bag_grid(candidate).x
	candidate["gh"]=bag_grid(candidate).y
	var moved: Array = []
	for item in space:
		# Everything the save file knows about an item travels with it: rebuilding
		# the entry from only kind/x/y/rot used to strip stack counts and every
		# equipment field, so swapping bags quietly destroyed loot.
		var entry: Dictionary = {}
		for field in SAVED_ITEM_KEYS:
			if item.has(field):
				entry[field]=item[field]
		entry["kind"]=str(item.get("kind",""))
		entry["x"]=int(item.get("x",0))
		entry["y"]=int(item.get("y",0))
		entry["rot"]=bool(item.get("rot",false))
		if not can_place(moved,entry,Vector2i(entry.x,entry.y),-1,bag_grid(candidate)):
			return false
		moved.append(entry)
	candidate["items"]=moved
	candidate["next"]=maxi(int(candidate.get("next",1)),1)
	current["items"]=[]
	current["next"]=maxi(int(current.get("next",1)),1)
	cabinet[index]=current
	p["backpack"]=candidate
	p["bags"]=cabinet
	return true

static func count(bag: Array, kind: String) -> int:
	var n := 0
	for item in bag:
		if item.kind == kind:
			n += 1
	return n

static func container_count(container: Dictionary, kind: String) -> int:
	return count(container_items(container),kind)

static func consume(bag: Array, kind: String) -> bool:
	var removed := false
	for i in range(bag.size()-1,-1,-1):
		if bag[i].kind == kind:
			bag.remove_at(i)
			removed=true
	return removed

static func consume_container(container: Dictionary, kind: String, limit: int = 0) -> bool:
	var list: Array = container.get("items",[])
	var removed := false
	for i in range(list.size()-1,-1,-1):
		if list[i].kind == kind and (limit<=0 or removed==false):
			list.remove_at(i)
			removed=true
	return removed

static func bag_value(bag: Array) -> int:
	var value := 0
	for item in bag:
		if not item.get("provision",false):
			value += item_value(item)
	return value

static func container_value(container: Dictionary) -> int:
	return bag_value(container_items(container))

# A fingerprint of where every item sits. A tidy that turns out not to help is
# rolled back to this exact layout, so a refusal never leaves a half-sorted bag
# behind — comparing the fingerprint is how the caller sees that it changed.
static func container_state(container: Dictionary) -> String:
	var text := ""
	for item in container_items(container):
		text+=str(item)
	return text

# --- auto storage ------------------------------------------------------------
# One search rules every automatic placement in the game: the first cell that
# fits when the grid is read top to bottom, left to right. An item is measured
# upright first and only then turned, so a shape that would fit either way keeps
# the orientation it was found in. This differs from can_place() by taking the
# raw item list every caller already holds.
static func first_cell(bag: Array, item: Dictionary, grid: Vector2i) -> Vector2i:
	var dims := grid_of(grid)
	for y in dims.y:
		for x in dims.x:
			var at := Vector2i(x,y)
			if can_place(bag,item,at,-1,dims):
				return at
	return Vector2i(-1,-1)

static func empty_cells(grid: Vector2i) -> Array:
	var taken: Array = []
	taken.resize(grid.x*grid.y)
	taken.fill(false)
	return taken

# Throws a placed item over every cell it covers.
static func mark_cells(taken: Array, grid: Vector2i, entry: Dictionary, at: Vector2i) -> void:
	var size := item_size(entry)
	for y in range(at.y,at.y+size.y):
		for x in range(at.x,at.x+size.x):
			taken[y*grid.x+x]=true

# The first free cells of a given shape, scanning top to bottom and left to
# right. This is the single placement rule every automatic fill is built on.
static func first_cell_in(taken: Array, grid: Vector2i, size: Vector2i) -> Vector2i:
	for y in range(0,grid.y-size.y+1):
		for x in range(0,grid.x-size.x+1):
			var free := true
			for cy in range(y,y+size.y):
				for cx in range(x,x+size.x):
					if taken[cy*grid.x+cx]:
						free=false
						break
				if not free:
					break
			if free:
				return Vector2i(x,y)
	return Vector2i(-1,-1)

# Where one item would sit: the first free cells it fits, or the same cells
# turned. Returns {at, rot}, or an empty dictionary when it cannot be seated at
# all. Everything below works in these plain positions, so a fill that runs out
# of room never leaves a stray coordinate on a real item.
static func find_seat(taken: Array, grid: Vector2i, kind: String) -> Dictionary:
	var base: Vector2i=ITEMS[kind].size
	for rotate in [false,true]:
		var size := Vector2i(base.y,base.x) if rotate else base
		var spot := first_cell_in(taken,grid,size)
		if spot.x>=0:
			return {"at":spot,"rot":rotate}
	return {}

# Seats one item where find_seat() says it goes, and covers those cells.
static func seat_item(taken: Array, grid: Vector2i, entry: Dictionary) -> bool:
	var seat := find_seat(taken,grid,str(entry.kind))
	if seat.is_empty():
		return false
	entry["x"]=seat.at.x
	entry["y"]=seat.at.y
	entry["rot"]=seat.rot
	mark_cells(taken,grid,entry,seat.at)
	return true

# Can this arriving piece of loot still be squeezed in without moving anything?
# Returns where it would land, so the caller never has to search twice. Each
# orientation is confirmed against the real grid before the cell is answered
# with: two sizes can share a first free cell, and only one of them really fits.
static func fits(container: Dictionary, entry: Dictionary) -> Dictionary:
	var grid := container_grid(container)
	var list: Array=container_items(container)
	var probe: Dictionary=entry.duplicate()
	for rotate in [false,true]:
		probe["rot"]=rotate
		var spot := first_cell(list,probe,grid)
		if spot.x>=0 and can_place(list,probe,spot,-1,grid):
			return {"at":spot,"rot":rotate}
	return {}

# Working copies of a haul: every attempt is laid out on these, so a pass that
# runs out of room can never leave a stray coordinate on a real item.
static func layout_copies(items: Array) -> Array:
	var copies: Array = []
	for item in items:
		var copy: Dictionary=item.duplicate()
		copy["rot"]=bool(item.get("rot",false))
		copies.append(copy)
	return copies

# The same copies, in the order the fill works through them: largest shape
# first, so the piece that needs the most room reserves it before the small ones
# fill the gaps, and equal sizes keep the order they were recorded in.
static func layout_order(copies: Array) -> Array:
	var plan: Array = []
	for i in copies.size():
		var size := item_size(copies[i])
		plan.append({"index":i,"area":size.x*size.y})
	plan.sort_custom(func(a, b): return a.area>b.area if a.area!=b.area else a.index<b.index)
	var order: Array = []
	for step in plan:
		order.append(copies[int(step.index)])
	return order

# Writes a worked-out layout back onto the haul it came from, keeping every item
# exactly where the tidied grid showed it.
static func commit_layout(items: Array, copies: Array) -> void:
	for i in copies.size():
		items[i]["x"]=copies[i].x
		items[i]["y"]=copies[i].y
		items[i]["rot"]=copies[i].rot

# Pack a player's container after an arrival. Keep item order and every item's
# fields, and decline a layout that uses more rows than the current one. Manual
# drags within a container remain where the player put them.
static func compact_arrivals(container: Dictionary) -> void:
	var items: Array=container_items(container)
	if items.size()<2:
		return
	var grid := container_grid(container)
	var packed := fill(items,grid)
	if packed.size()==items.size() and (rows_used(packed)<rows_used(items) or occupied_score(packed,grid)<occupied_score(items,grid)):
		commit_layout(items,packed)

# Compare layouts by the cells their footprints occupy, so a fully packed first
# row stays where the player can find it even if the greedy fill picks a new
# order for equal-sized groups.
static func occupied_score(items: Array, grid: Vector2i) -> int:
	var score := 0
	for item in items:
		var size := item_size(item)
		for cy in size.y:
			for cx in size.x:
				score+=int(item.y+cy)*grid.x+int(item.x+cx)
	return score

# How far down the grid the haul reaches. A refill that does not beat this has
# left the haul spread out exactly as it was, which would only turn a tidy hole
# into scattered ones — so place_arrival() throws such a refill away.
static func rows_used(items: Array) -> int:
	var rows := 0
	for item in items:
		rows=maxi(rows,int(item.y)+item_size(item).y)
	return rows

# The whole haul, each item seated by size. An arriving item is laid out with it
# — "probe" is copied in at "reserve" if it is given one — so the caller can try a
# tidy with and without the newcomer without disturbing the container. "measure"
# receives the row count the fill reached, which is how the caller tells a refill
# that helped from one that merely reshuffled the same haul.
static func fill(items: Array, grid: Vector2i, probe: Dictionary = {}, reserve: Vector2i = Vector2i(-1,-1), measure: Dictionary = {}) -> Array:
	var copies := layout_copies(items)
	if not probe.is_empty():
		var copy: Dictionary=probe.duplicate()
		copy["x"]=reserve.x
		copy["y"]=reserve.y
		copies.append(copy)
	var taken := empty_cells(grid)
	for entry in layout_order(copies):
		if not seat_item(taken,grid,entry):
			return []
	measure["rows"]=rows_used(copies)
	return copies

# The counter-offer for a shape the greedy fill cannot seat: reserve every legal
# spot for the newcomer in turn and fill the haul around it, taking the first
# arrangement that holds. The newcomer is seated from its cell like any other
# item, so the room reserved for it is always the footprint it really covers.
# Row-major order means the spot nearest the top-left corner wins whenever
# several would work. No row budget is needed here: the fill either seats every
# item or it fails, and an arrangement that seats them all is by definition one
# that fits.
static func fill_reserving(items: Array, grid: Vector2i, probe: Dictionary) -> Array:
	# The footprint comes from item_size(), not from the kind's table entry: a
	# turned item, and a backpack whose quality decides its own shape, are both
	# only measurable through it. Reading the raw table here reserved the wrong
	# room — a turned 1x2 asked for a 1x2 — and could refuse an arrival the grid
	# could really hold.
	var base: Vector2i=item_size(probe)
	for rotate in [false,true]:
		var size := Vector2i(base.y,base.x) if rotate else base
		for y in range(0,grid.y-size.y+1):
			for x in range(0,grid.x-size.x+1):
				var seat: Dictionary=probe.duplicate()
				seat["rot"]=rotate
				var filled := fill(items,grid,seat,Vector2i(x,y))
				if not filled.is_empty():
					return filled
	return []

# Where the arriving item ended up in a fill that already seated it. Asking the
# fill itself is what makes a refill usable: searching the finished grid for a
# free hole only works when the hole still has the shape the item needs, which is
# exactly what a solidly packed grid never leaves behind.
static func seated_entry(copies: Array, probe: Dictionary) -> Dictionary:
	for entry in copies:
		if entry==probe:
			return entry
	return {}

# The one-shot tidy behind the double click. Free cells win outright; when
# nothing is free the whole container is refilled from scratch, largest item
# first, with the arriving item considered last, and — only if even that cannot
# house it — considered first with the haul packed around it. The haul keeps its
# slots when the call says no: nothing but a yes ever touches the container.
# Returns "ok":false when this container cannot take the item even after being
# tidied, which is the caller's signal to leave the item where it is.
static func place_arrival(container: Dictionary, entry: Dictionary) -> Dictionary:
	var grid := container_grid(container)
	var list: Array=container_items(container)
	var probe: Dictionary=entry.duplicate()
	# Free cells win outright, and the item keeps every field it was found with.
	var free := fits(container,probe)
	if not free.is_empty():
		probe["x"]=free.at.x
		probe["y"]=free.at.y
		probe["rot"]=free.rot
		return {"ok":true,"items":[],"seat":probe}
	# Pass one: refill the haul with the newcomer laid out last, so it takes what
	# the haul leaves over. A refill that leaves the haul spread exactly as wide as
	# it already is has bought nothing, so it is only adopted when it seats every
	# item within fewer rows than the haul already reaches — that is what turns a
	# grid scattered by a tidy back into a packed one. The frontier is the arrival
	# into an empty container, where "how far down" means nothing.
	var measure: Dictionary = {}
	var refilled := fill(list,grid,probe,Vector2i(-1,-1),measure)
	if not refilled.is_empty():
		var roomy := list.is_empty() or int(measure.get("rows",0))<=rows_used(list)
		if roomy:
			var seat := seated_entry(refilled,probe)
			if not seat.is_empty():
				return {"ok":true,"items":refilled.slice(0,refilled.size()-1),"seat":seat}
	# Pass two: reserve the newcomer's room first and fill the haul around it.
	var reserved := fill_reserving(list,grid,probe)
	if reserved.is_empty():
		return {"ok":false,"items":[],"seat":{}}
	# The fill lays the newcomer out with the haul as its last copy, so its seat
	# comes straight out of that layout.
	return {"ok":true,"items":reserved.slice(0,reserved.size()-1),"seat":reserved[reserved.size()-1]}

# Every item in this container that the arriving one outranks: strictly lower
# quality, and then the cheapest of those first, so a haul of white junk gives
# way before anything worth carrying. Equal quality is never listed, which is
# what keeps one relic from pushing out another.
static func eviction_order(container: Dictionary, entry: Dictionary) -> Array:
	var floor_tier := item_tier(entry)
	var losers: Array = []
	for item in container_items(container):
		var tier := item_tier(item)
		if tier>=floor_tier:
			continue
		losers.append({"tier":tier,"value":item_value(item),"kind":str(item.kind)})
	losers.sort_custom(func(a, b): return a.tier<b.tier if a.tier!=b.tier else a.value<b.value)
	return losers

static func restore_layout(container: Dictionary, snapshot: Array) -> void:
	container["items"]=snapshot
