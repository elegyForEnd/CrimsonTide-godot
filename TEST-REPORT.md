# 验证记录

## 2026-10-07 全部69把武器逐项验收

- 逐页人工查看 21 把远征、48 把闯关武器，四角色 × 八类展示项，共 2208 格；实际有特效的 1908 项独立 GPU 检查先隐藏角色，避免角色像素掩盖空特效。69 页与 coverage.json 位于 build/weapon-full-audit，浏览器索引 index.html，逐把结论见 WEAPON-FULL-AUDIT.md。
- weapon_full_matrix：17664 个释放组合（69×4角色×8方向×4阶段×2模式），每组合三个播放时刻；另3520个普攻/战技弹体组合。151375 检查，0 failures。验证真实挂点、地面投影、接触像素、可见性、细长弹体速度轴及真实战技姿势；最终日志 build/weapon-full-matrix-complete.log。
- 全量验收发现并修复：重刃白色主体遮挡角色；震地缺少落地冲击轮廓；巨锤/石槌误用剑刃圆斩；战技沿用上次普攻前摇；16把重武器的精确出手边界因归一化浮点比较被判回前摇。内置 ImageGen 重绘重刃 v3 和震地 v2，50张原始RGBA审计0 failures。
- 配套复跑：weapon_mechanics 429、weapon_mechanic_contact 506、weapon_mechanics_visual 30、weapon_vfx_identity 553、weapon_stroke_stability 196、rogue_build_rules 565，全部0 failures。
- 新版 build/CrimsonTide-WeaponTipFixed.exe 已重新导出（2084617104 字节）。通过 --main-pack 加载内嵌资源，接触像素506、机制429，共935检查，0 failures。图页测试退出无资源泄漏错误；加载主场景的矩阵仍有既有的4个ObjectDB退出警告。
- 项目路牌610锚点：OK405 / DRIFT0 / WRONG0 / HINT205；git diff --check 通过。

## 2026-10-07 真实剑尖、方向与素材修复

- 九组共 11839 检查，0 failures：weapon_stroke_directions 6872（四角色、全部远征/闯关近战、八方向、两模式）、weapon_mechanic_contact 505（真实 GPU 接触像素）、all_weapon_mounts 2568、weapon_stroke_stability 196、weapon_mechanics 429、weapon_vfx_identity 553、weapon_contact_particles 654、weapon_vfx_progression 32、weapon_mechanics_visual 30。渲染测试使用开窗 Godot，存档全部放在工作区 .testappdata。
- ImageGen 新生成双刃 v3、重刃终结 v2，原始 RGBA 直接复制入项目。48 张素材通过透明背景、SHA256、提示词与轮廓审计，0 failures。新素材接入后重跑接触像素、GPU 机制、武器身份与释放稳定性检查，全部通过。
- 八动作四方向角色预览 build/weapon-mount-repaired.png 已实际渲染并逐行检查。
- Windows 单文件 build/CrimsonTide-WeaponTipFixed.exe 导出成功（2083330232 字节）。引擎通过 --main-pack 加载该 exe 内嵌资源，接触像素 505、实际机制 429 共 934 项检查，0 failures。项目路牌 610 锚点：OK406 / DRIFT0 / WRONG0 / HINT204。

环境：Windows，项目内 Godot 4.7.2 stable，OpenGL Compatibility，NVIDIA RTX 3080 Ti。

## 2026-10-06 营地行囊面板 + 15×15 网格仓库 + 装备持久化

按 `CAMP-BACKPACK-WAREHOUSE-HANDOFF.md` 规格落地（该交接文件已在本轮完成后删除）。四块改动：

- **仓库变真网格**：`data.warehouse` 从扁平数组改成 15×15 容器（`Catalog.WAREHOUSE_GRID`），格满时**手动存入整件拒绝**（`Profile.bank_item()` 快照回滚），**结算自动入库则溢出到 `warehouse_spill`**（绝不吞掉已获得的战利品）。旧档自动升级：`apply_data()` 把旧数组直接交给 `sanitize_warehouse()` 逐件 row-major 落格，落不下的进溢出区。溢出项与网格项共用一套索引空间，`withdraw_item`/`sell_items`/`product_count`/`spend_product` 都已改为走这套。
- **装备持久化**：`profile.data.loadout`（主手/护甲×3/饰品×2/快捷栏×3）随存档保存，`storage_from_config()` 读回、`make_player()` 用存盘主手武器而非临时武器。**撤离保留穿着**（`saved_loadout()` 写回，`loot` 不再重复计装备价值，也不再拆下来入库）；**阵亡照旧散落并写回空 loadout**。旧档无 `loadout` 键时按空处理。
- **营地 Tab 行囊（`camp_pack.gd` + `camp_storage.gd`）**：同屏三栏——左穿戴栏（6 槽 + 快捷 3 + 当前背包 + 背包柜）、中随身背包/次元口袋、右 15×15 仓库，全方向拖拽互转。营地 `session.running==false` 时 `perform()` 是空操作，因此营地编辑集中在 `camp_storage.gd`，并且**只复用 session 的纯 `p` 变更函数**（`move_between`/`equip_item`/`clear_worn_slot`/`slot_put`/`resolve_drop`），每次接受改动**即时 `save_profile()`**。背包可以脱下来变成可存可卖的普通物品（内容先腾进口袋/仓库，装不下就拒绝）。对局与营地共用一套格子渲染 `item_tile.gd`。新背板 `assets/ui/camp-pack-vault-v1.png` 是用旧面板素材拼的**占位图**（`tools/make_camp_pack_backdrop.gd`），待正式美术替换。
- **整备台改付费买断**：三件出战装备价格 180/420/300（`Catalog.GEAR_PRICES`），换装按差价结算（换贵扣钱、换便宜退钱）、旧件销毁、钱不够不改动并弹**屏幕居中偏上**提示（`notice_popup()`）；`data.gear=-1` = 未装备；新增号从无装备开始。营地 F 键不再直达整备台（只保留拾取地上产物）。交易行保持独立窗口但列表换成**同一套 15×15 网格 + 溢出暂存行**，点格多选、二次确认出售。

**回归（全部 headless）**：`tests/systems` **10812 检查 0 失败**；`tests/economy` 139、`tests/camp_storage` 51、`tests/camp_pack` 21、`tests/camp_flow` 32、`tests/economy_ui` 0 失败、`tests/inventory_panels` 14（本轮新增，补上对局面板在无窗口下的接线覆盖）、`tests/homestead` 62、`tests/camp_activities` 89、`tests/homestead_ui` 53、`tests/collectibles` 451、`tests/attributes` 204、`tests/hidden_ending` 100、`tests/combat_envelope` 89、`tests/rogue_profile_migration` 115、`tests/rogue_wiring` 122 均 0 失败。路牌 `verify_anchors` **505 锚点全过（OK 384 / DRIFT 0 / WRONG 0）**。

**未跑/不适用**：`tests/ui.gd`、`tests/extraction_inventory.gd` 属开窗截图测试，headless 下必然挂起（本项目一贯约定：画面测试去掉 `--headless` 手动跑），本轮未在真窗口下出图。

**已知与本轮无关的失败**：`tests/balance` 6 项失败（`Attack delivery scales once for species 4`、Boss 30 秒出招 10 < 11），在**恢复旧装备基线（`gear:0`）下同样 6 项失败**，与仓库/装备改动无关，属既有基线问题，未在本轮处理。

**测试环境注**：本轮工作区沙箱不允许进程写 `assets/`、`tests/` 等既有子目录，且拦 `user://`（AppData）。无头测试改为 `$env:APPDATA=<工作区>\.testappdata` 后再跑（`.testappdata/` 已进 `.gitignore`），实测存档往返正常、与全放开访问结果一致；`tests/systems.gd` 里写在 `res://tests/` 的临时存档一并改到 `user://`（顺带不再往仓库里丢临时文件）。

## 2026-10-06 种植/钓鱼产物改为格子掉落物并入背包

- **产物即掉落物**：六类收获物（晨光麦 / 赤霞萝卜 / 月露草 / 银鳞鲫 / 月纹鲈 / 金冠锦鲤）在 `catalog.gd` 注册为 1×1、可堆叠（≤6）真实物品，价值沿用旧售价，图标复用 `home_art.gd` 现有图集（无缺失、无需占位图）。`home.sell()` 退役，出售改走营地交易行（读仓库实例）。
- **自动入包 + 溢出落地**：收获（`homestead.gd` tend 分支）与钓获（`catch_fish`）改调 `profile.receive_product()`——先塞远征背包 `bags[0]`，再塞次元口袋 `pocket`；装不下的量记入 `take_overflow()`，由 `camp_activities.gd` 在动画收尾 `finish()` 时 `spill_overflow()` 落地为 Sprite3D 掉落物（billboard，落在产出点附近）。走近按 **F 优先拾取脚下掉落物**，无掉落时 F 回落到料理台；`camp_screen.gd` marker 与操作指南同步更新 F 的新用途提示。
- **烹饪/交易看真实实例**：`profile.product_count()` 按实例 `count` 累加（背包+口袋+仓库，修掉了“一叠 6 件被当 1”的计数 bug），`cook()` 与厨房面板食材进度、`spend_product()` 均真扣实例。旧 `home.stock` 计数由 `profile.migrate_home_stock()` 在 `apply_data()` 末尾一次性迁进仓库。
- **死亡清空随身产物**为既有对局结算逻辑（口袋安全保全、阵亡丢背包）的自然结果，无需额外隔离代码。
- **回归**：`tests/homestead` 62、`tests/camp_activities` 89、`tests/homestead_ui` 53、`tests/camp_flow` 25、`tests/economy` 84 检查均 0 失败；`tests/systems` 全量 **10812 检查 0 失败**。`verify_anchors` 443 锚点全部通过。
- **测试环境注**：headless 运行需向 Godot `user://`（AppData）写读存档，普通工作区沙箱会拦此目录导致 save/load 假失败；本次在放开文件系统访问下实测存档往返与产物持久化一致。

## 2026-09-23 区域数值、Boss 机动与五分钟探索日

- 区域难度统一控制怪物生命、伤害、追击速度、掉落概率和装备品质；覆盖全部 17 类敌人的实际伤害路径。高难清剿增加补给，大型精英保证掉落。详见 `BALANCE.md`。
- 三天主 Boss 基础生命调整为 1500 / 2700 / 4800，增加追击、后撤、侧移和遇墙绕行，缩短出招间隔；预警位置与方向仍锁定。王城骑士同步提升生命、伤害、移动速度并缩短收招。主 Boss 增加装备、遗物与结算奖励。
- 探索日统一 300 秒，第 180 秒开始缩圈并关闭王城，第 300 秒生成 Boss；营地、HUD、手册及联机同步一致，第三天保持直接决战。
- 自动规则检查共 **6176 项，0 失败**：balance 159、expedition 48、area_rewards 3612、ecology 1169、city 37、systems 583、enemies 23、nocturne 135、combat 78、movement 83、map 201、boss_art 48。
- 专项覆盖圈在第 180 / 240 / 300 秒的状态、四档随机掉落保底与抽样收益、Boss 在 30 秒内的攻击次数和移动、预警不追踪、长帧碰撞与圈界、Boss 奖励完整装箱。固定样本各 Boss 各阶段出招 11–13 次。
- 两组本机双进程联机均通过：远征验证 300 秒日长、合作 Boss 生命、危险区、独立撤离及最终结算；生态验证 12 种区域敌人和难度 / 伤害 / 移速字段同步。日志位于 `build/balance-expedition_network-{server,client}.log` 和 `build/balance-ecology_network-{server,client}.log`。
- 修正旧测试夹具：夜行种伤害断言改为按所属区域计算；武器战斗测试改在独立空房间生成靶子，避免攻击后栖息地锁定导致后续靶子不生成。没有放宽实战的禁止增援规则。
- 编辑器扫描发现用户现有 `pv` 目录两份 WAV 格式不受支持；游戏主场景提前强制退出会报告资源尚在使用。本轮没有修改这些音视频或导出 EXE；上述规则与联机测试独立完成，未将完整图形 UI 回归、发布包或真人通关体验记为通过。

## 2026-09-23 武器改为战利品，角色改用临时武器

- **去掉自由换武器**：删除 `weapon_0..weapon_3` 四个输入动作与 `_unhandled_input` 里的 1～4 循环，`perform` 的 `"weapon"` 分支整体移除；营地从未预设武器，`make_player` 现在完全不读 `config["weapon"]`。四把武器（守夜步枪 / 绯红单手剑 / 破晓双手剑 / 星辉法杖）保留为纯战利品，只能捡进背包后经「装备」握在手里。
- **角色临时武器**：`Catalog.STARTER_WEAPONS` 追加三把角色专属武器（黑铁短剑 / 祭祀短杖 / 破碎大剑），索引接在四把局内武器之后，`STARTER_BASE` 与 `WEAPONS.size()` 由系统测试断言保持一致。新增 `Catalog.starter_index` / `is_starter` / `weapon` / `weapon_name` / `weapon_family`，战斗、动画与音效统一按「四类武器族」取用，临时武器只借用同族素材。临时武器不可拾取、不可掉落、不享受品质加成，且每一项伤害与射程都严格低于它所模仿的局内武器（13 < 38、15 < 46、30 < 88）。卸下或阵亡时 `restore_issue_weapon` 自动把临时武器放回手上，任何时刻都有武器可用。
- **战斗事件改为按武器族广播**：`windup` / `strike` / `impact` / `skill` / `ultimate-start` 与弹道里的 `weapon` 字段现在是 0～3 的武器族编号，战斗特效、刀光、命中音与语音路由无需改动即可继续工作；攻击、装填、重武器减速、弹速与三段连击判定全部改写为族判定。
- **界面**：HUD 左上武器名后标注「· 临时」，武器图标随当前武器族实时切换；空着的武器槽改画灰字临时武器名与「临时」状态并附说明 tooltip；右侧「本局装备」在尚无加成时显示手持武器。营地、守则与 README 的按键说明同步去掉 1～4 换武器。
- **验证**：`tests/systems.gd` 583 项、0 失败（新增 22 项临时武器表、索引与威力上限断言）；`tests/combat.gd` 78 项、0 失败（重写为「临时武器威力上限 + 只能装备后换用 + 1～4 失效」）；`tests/movement.gd` 83 项、`tests/city.gd` 37 项、`tests/enemies.gd` 23 项、`tests/map.gd` 537 项均 0 失败。`tests/ui.gd`、`tests/audio.gd`、`tests/network.gd`、`tests/combat_visual.gd` 已按新规则改写（热键失效、装备武器取消装填、双方各自装备战利品并同步、临时武器动作截图），本次未在图形窗口与多进程环境复跑，交由实际游玩验证。
- 说明：本轮未调整掉落表，箱子出武器的概率仍为 16%、赤月狐卫为 45%。若实际体感过紧，可只调这两个概率。

## 2026-09-22 普攻发力声与大招力度调整

- 重新合成 12 条普攻发力声、9 条大招语音；其余 30 条 WAV 哈希保持一致。普攻均为短语气词，时长 0.22～0.56 秒。51 条语音的来源、波形、峰值、哈希及 CG 时长检查通过。
- 所有普通攻击按实际角色播放发力声，包括双手剑与法杖。角色语音行为检查增至 87 项、0 失败，覆盖三角色 × 四武器的路由，以及播完报招、暂停、跳过和联机短喊。既有音频行为 138 项、0 失败。
- 重新按语音长度构建演出音效，单人 CG 总长约 5.43 / 5.95 / 5.95 秒。113 条 WAV 与环境 OGG 的音效素材检查通过。
- 实际 Godot 混音 33.11 秒，峰值 -3.55 dBFS，削波样本 0；左右方位与距离衰减检查通过。纯人声试听为 `build/MiniMax-Firm-Voice-Preview.mp3`，完整混音为 `build/MiniMax-Game-Preview.mp3`。以上为信号和行为检查，表演听感以实际试听为准。
- 当前检查日志为 `build/firm-voices-test.log`、`build/firm-audio-test.log`、`build/firm-mix-test.log`。此轮未重复进行网络与全部系统规则验证。
- 已重新导出 PCK，并从 `dist` 加载实际发布包复跑 87 项角色语音检查，0 失败；日志为 `build/firm-pack-test.log`。

## 2026-09-22 MiniMax 日语角色语音与二次元音效

- 新版音效素材检查通过：113 条 WAV 和 44 秒环境 OGG。独立语音检查：51 条 MiniMax `speech-2.8-hd` 生成的 48 kHz 单声道 WAV，校验模型、三套日语 voice_id、请求 trace_id、哈希、起止包络、过采样峰值、双语文本与奥义时间全部通过。
- 角色语音行为：76 项、0 失败，覆盖重复限流、受伤打断、低优先级不能抢话、距离剔除、战斗事件按角色选声线、自动压低音效、语音静音、三人的完整奥义、暂停继续发声、网络短片结束不截句、跳过与换页清理。
- 既有音频行为 138 项、系统规则 261 项全部通过。四人 ENet 房主与三个客户端事件回归结果见 `build/anime-network4-*.log`。
- CG 图形检查 0 失败，已检查三名角色中日字幕、爆发字幕、语音设置与署名页面截图。字幕在闪光和叠加光效上方显示。
- MiniMax 版本导出 PCK 后，在 `dist` 目录通过 `--main-pack` 加载发布资源，76 项角色语音行为检查再次全部通过；日志为 `build/minimax-pack-test.log`。便携包包含音效 / 语音来源清单和署名，不包含 API 凭据及生成缓存。
- Godot 实际混音与语音生成分别验证，30.28 秒试听峰值 -3.93 dBFS、削波样本 0。最新混音结果记录在 `build/minimax-mix-test.log`，试听为 `build/MiniMax-Game-Preview.mp3`。此处为信号和行为验证，不将其作为真人试听评价。

## 2026-09-22 音效素材升级

- 113 条不同的 48 kHz 立体声 WAV 与 1 条环境 OGG，共 114 条音频；起音、尾音、过采样峰值、重复文件、配方来源关联全部通过。44 秒氛围循环首尾差值为 0.001778；97 份原始素材 SHA-256 均与来源清单匹配。
- 音频行为检查：138 项、0 失败，覆盖声部上限、优先级、距离剔除、武器切换取消装填、单人暂停 / 跳过、联机短版、移动与堵墙。新增间歇位置快照和 120 Hz 渲染的脚步回归。
- Godot 实际混音：左右方位与距离衰减检查 0 失败。23.59 秒试听录音峰值 −8.32 dBFS，削波样本为 0；试听输出 `build/CrimsonTide-audio-preview.mp3`。
- 本轮已有战斗 30 项、移动 83 项、系统 261 项全部通过；三角色 CG 检查 0 失败。音频素材和代码续接后另行复核，见 `build/library-*-test.log`。
- 2 人联机已通过音效事件同步，4 人房主与三个客户端复核全部 PASS，记录见 `build/library-network4-*.log`。网络验证限本机独立进程。
- 新版 PCK 已导出，在 `dist` 目录通过 `--main-pack` 加载，138 项音频行为检查再次全部通过；验证实际发布资源而非源码目录中的资源。测试脚本位于包外，不随包发布。
- 声音的主观音质需要实际试听判断，信号和行为检查不代替听感评价。

## 已通过

- 系统测试：466 检查、0 失败。六档背包品质尺寸、容器网格、越界与重叠、消费与价值、换包装配（含换包时堆叠数量 / 武器编号 / 散装背包品质的全字段保全）、死亡散落背包与口袋保全、撤离带走、存档往返与损坏存档修复；搜索计时与逐件浮出、未搜格保护、走开暂停、地面秒拾、双向拖拽与越界落位、整叠搬运不丢件；**武器与装备的六档加成、穿戴与卸下、使用消耗品、旋转、局内强度变化、阵亡掉落装备**；30 种地图的种子一致性和封印/撤离可达性；搜刮、燃晶、治疗、救援、独立撤离、全员离场结算、共享奖励、标准/长局与重复开局、时限死亡、成长存取。
- UI 集成：0 失败。在真实图形窗口运行标题、营地、战斗、背包、搜索窗口、地图、手册、结果、再次开局；通过 Input.parse_input_event 注入 Tab / M / F / R 键，并验证状态改变。覆盖次元口袋选中、六档品质逐一切换后网格实时变化、搜索自动浮出、拖拽入包、包内调位、地面秒拾，以及**背包内 R 旋转、面板使用急救针、装备武器与护甲、卸下装备、搜索窗口快捷使用**；另用 `Input.warp_mouse` 校准后注入真实鼠标移动 / 按下 / 松开，覆盖单击选中、双击装备、拖拽到装备槽与背包槽、面板上松手取消、拖拽中旋转 1×2 与 2×2 且落位两两不相交、从物资箱拖 2×2 遗物入口袋。截图位于 build/ui-*.png，已视觉检查。
- 2 人独立进程 ENet：房主和客户端均 PASS。
- 4 人独立进程 ENet：房主和三个客户端均 PASS。
- 联机断言包括：准备与出发、相同种子、持续收到带战利品和目标进度的状态快照（含次元口袋内容同步）、技能事件同步、客户端先撤离而房主继续行动、全队最终个人/共享结算一致。最后一轮 net2/net4 错误日志均为 0 字节。
- 已修复大于 MTU 的未压缩不可靠快照警告，改为独立通道压缩可靠快照；已修复初版动态解压方式不兼容错误。

## 2026-09-22 装备槽、真实占格与拖拽旋转修复

- **装备栏 / 背包槽插槽化**：右侧「战利品档案 / 装备」面板新增四个装备槽（武器 / 护甲 / 瞄具 / 轻靴）与「背包柜」里的背包槽，都是可投放的插槽。把背包里的武器、装备或散装背包拖到对应槽上松手即穿上，**双击物品**同样直接装备；槽内显示名称与加成，并附「卸」按钮随时卸下。拖到面板空白处松手视为取消，不会把物品丢到地上。
- **搜索窗按真实占格渲染**：物资箱里的卡片现在按物品实际尺寸占格（月蚀遗物与武器 2×2、废料 2×1、药品 1×2……），未翻开的格子保留封印占位；命中检测从单格索引改为按矩形，抓住 2×2 卡片的任意一角都能拖走，拖起时幽灵框与落点预览同样是 2×2。
- **拖拽中按 R 的三个 bug**：贴图在放下前消失，根因是 R 触发面板重建时把常驻的拖拽幽灵框与落点预览一起 `queue_free` 了，现在重建前先摘出、重建后挂回并强制重量尺寸；2×2 遗物旋转后预览变 2×1，根因是预览尺寸沿用了拖起时的缓存值，现在每帧按当前朝向重算（2×2 旋转后仍是 2×2，只转贴图）；落位与邻格重叠与上同源，预览与落位共用 `resolve_drop`，尺寸修正后重叠消失，并新增 UI 不变量断言：任意容器内物品两两 Rect2i 不相交。
- **换包丢数据的隐患**：`Catalog.swap_bags` 重建搬运条目时只带 kind/x/y/rot，换一次包就会把一叠晶簇压成单件、抹掉武器编号与品质、散装背包品质；现在按 `SAVED_ITEM_KEYS` 全字段搬运，系统测试新增 8 项断言覆盖堆叠数量、武器编号 / 品质、散装背包品质与换包后的网格尺寸。
- 系统测试 458 → 466 检查、0 失败；UI 集成 0 失败。截图 build/ui-equip-sockets.png、build/ui-mouse-*.png、build/ui-loot-relic-*.png 已视觉检查：装备槽空 / 满两态、拖拽中旋转的 2×2 预览与落位、物资箱 2×2 遗物卡片与拖入口袋后的空箱均符合预期。

## 2026-09-22 背包使用、旋转与武器装备系统

- **旋转改为 R 键**：背包内拖动中或选中物品后按 `R` 旋转（右键同效）。此前 R 只在「已选中且未拖动」时生效，拖动中只能靠右键；现在两条路径共用同一个权威动作 `bag_rotate`——转身后仍放得下就原地保留，放不下就吸附到最近的合法格，全满时明确提示拒绝（原先会静默失败）。
- **修复背包内无法使用物品**：根因是 `F` 同时绑定「拾取/搜索」与「急救」，而拾取分支先 `return`，导致急救针永远无法通过按键使用，背包面板上也没有任何使用入口。现在 F 先尝试拾取/搜索，没有可捡可搜时才回落到急救（倒地一定优先自救），并且背包面板顶部新增「使用」按钮、搜索窗口右下角新增「快捷使用」条（急救针 / 血晶 / 弹药匣），搜刮过程中也能用药。使用动作精确消耗被点选的那一件，满血时拒绝且不消耗。
- **武器与装备系统**：新增两类可搜刮战利品——武器（2×2，对应四把武器之一）与装备（1×2，护甲 / 瞄具 / 轻靴），沿用背包的六档品质颜色。点「装备」立刻换到手上并写入装备栏：武器提供伤害 +0%~+72%、攻速 +0%~+28%（只在手持该武器时生效），护甲 / 瞄具 / 轻靴分别提供生命 +12~+78、火力 +5%~+30%、移速 +8~+46。换下的旧装备自动回到背包，背包也满则掉在脚边；装备栏可随时卸下。箱子、精英「血香猎手」与普通怪都会掉落武器与装备，品质随局内深度提升。
- **风险对等**：身上装备只在局内生效、撤离不带回，阵亡时连同背包一起散落成可拾取的地面掉落；HUD 右侧新增「本局装备 N/4」与加成汇总，武器名后显示强化百分比。
- **顺带修复存档与搬运的三处信息丢失**：`Catalog.clean_container` 此前只保留 kind/x/y/rot，读档会丢掉堆叠数量、散装背包品质、免费物资标记；「存入次元口袋 / 放回角色背包」按钮此前按类型重建物品，会把一叠 6 个晶簇变成 1 个、把散装背包品质和武器品质清零；`Catalog.tidy` 在每次从箱子取物后重排时同样只按类型重建。现在三处统一保留物品自身的字段（数量 / 品质 / 武器编号 / 装备槽 / 品质等级 / 免费标记），并且拖一叠物品进箱子只交接放得下的部分，不会凭空销毁。另外 `Catalog.container_grid` 现在同时认玩家容器的 gw/gh 与地图容器的 grid，5×5 的深处教堂箱子终于真的按 25 格装箱。
- 新增 `assets/icons/sword.svg`、`heavy.svg`、`staff.svg`、`sight.svg`，武器与装备按类型与品质显示各自图标与颜色。测试从 361 项扩到 458 项（系统）并扩展 UI 断言，两套均为 0 失败；2 人 / 4 人联机复测 PASS。

## 2026-09-22 背包面板实测反馈修复（第二轮）

- **物资箱界面关不掉**：整套背包/物资箱面板直接画在 overlay 上，而 `close_bag()` 只改了 `inventory_open`，从未清理 overlay，所以按 TAB、点“关闭 TAB”或按 ESC 后面板原样留在屏幕上。现在关闭时会清空 overlay 与网格索引，并把搜索窗引用归零（箱子搜索进度保留，站回去按 F 可再开）；同时给 `show_inventory()` 加了“已关闭就不绘制”的守卫，延迟重建也不会把面板画回来。
- **贴图不跟着旋转**：旋转只换了占位（`item_size` 交换宽高），美术贴图仍然正着画，看起来像没转。现在 `GothicButton` 带 `rotated` 标记，旋转后连同贴图一起转 90°（拖动时跟随鼠标的幽灵框图标同样旋转）。
- **物品看起来比格子大**：`Button` 的最小尺寸会被自身文字撑开，`金色 守夜护甲` 这种长名字把 1×2 的格子顶宽，图标与文字因此溢出到隔壁格。现在 `GothicButton` 一律 `clip_text=true`，文字不再参与尺寸计算；名称改为压在格子底部的半透明条里，超宽自动截断加省略号，格子太矮时只留图标。
- **拖动会把已旋转的物品转回去**：拖动状态里存的是“是否旋转过”的布尔增量，松手时又当作最终朝向写回，所以横放的物品一移动就变回竖放；旋转两次也会得到错误结果。现在统一以“最终朝向”（`drag.rot`）为准，拖动、落点预览、尺寸计算与写回全部一致。
- **图标尺寸**：图标改为按 `min(格子宽,格子高)-6` 铺满格子（旧算法在横放物品上只剩 10px，几乎看不见），并改为赋值即加载贴图，重建网格时不再先画一帧空图标。

## 2026-09-22 格子尺寸根因（第三轮，实测复现）

- 上一轮把 `clip_text=true` 放进了 `_ready()`，但 `button()` 是**先设 `text`/`size`、最后才 `add_child`**，而 `Control.set_size()` 会被当前最小尺寸钳住：`text` 一赋值的瞬间最小宽度就是文字宽度，`size` 于是被锁死在 72/109/125px，之后 `_ready` 里的 `clip_text` 只能让最小尺寸变小，**不会把已经撑大的 size 缩回去**。同时 Button 主题样式盒的 content margin（18/10）也计入了最小高度，1×2 旋转成 2×1 时高度被撑到 43 而非 37。
- 实测复现（1×2 银鸦护符）：`size=72×95`、图标盒 66px，比 43px 的格子宽 29px，**压到隔壁格**；相邻格子的底板又画在后面，于是被压住的那件物品看起来“贴图消失”——这正是“旋转后贴图不见”的真正原因。
- 修复：把 `clip_text` 与空样式盒一起挪到 `GothicButton._init()`（在任何 `text`/`size` 赋值之前生效），并给 `button()` 增加 `font_size` 参数，让字号在 `size` 之前设定。复现结果变为 1×2 = 43×95、2×2 = 95×95、旋转后 2×1 = 95×43，图标盒 37px，完全落在格子内。
- 窄格子的名称改用短名（去掉品质前缀，如“守夜护甲”而非“红色 守夜护甲”）并把字号降到 9，仍有品质色描边与提示框兜底；实测标题页、营地页、战斗背包、搜索窗、装备栏渲染均正常。


## 验证边界

- 网络验证为同一台机器的多个独立进程，不代表公网、高延迟、拥塞、丢包条件已测试。
- 没有进行数小时人工游玩或完整数值平衡评估。
- 部分快速关闭运行偶有 Godot ObjectDB 实例清理警告；未出现对应游戏运行错误。
- 当前是完整循环的首版，角色与怪物精灵加程序动作，建筑程序绘制结合地面材质，非完整逐帧/骨骼动作系统。

## 2026-09-22 储物系统改版回归

- 背包改为两层：固定 4×4 次元口袋（写入存档、死亡不掉落）与随品质变大的角色背包（白 3×3 → 红 8×8、死亡掉落）。
- 系统测试从 261 项扩到 328 项，新增品质尺寸、容器自由格、换包拒绝、倒地散落、口袋跨局保全、存档修复等断言；UI 集成新增双网格与六档换装覆盖。三套测试均为 0 失败。
- 打包版已删除：本机未安装 Godot 导出模板，`dist/` 无法重建，改为由 `Launch-Game.cmd` 从源码启动。

## 2026-09-22 拖拽反馈强化

- 修复关键缺陷：拖拽图标此前由 `show_inventory()` 绘制，而它只在背包内容变化时才重建（每 0.1 秒判断一次），导致图标只在起始位置画一次、**不会跟随鼠标**。改为把幽灵框做成常驻 overlay 节点，由 `_process` 每帧调用 `sync_drag()` 更新位置与落点预览。
- 拖动时同时给出三种反馈：原格子留下**虚线挖空轮廓**、光标下方按实际尺寸显示**落点预览**（精确命中金框 / 需吸附的落点加外发光 / 完全放不下时红框加斜纹）、被拖起的图标**放大 10% 并带品质色底板、描边与名称数量标签**（旋转后尺寸实时变化）。
- 新增 `Session.resolve_drop()`：光标只是指针，物品优先落在光标所在格，放不下则吸附到最近的合法格，全满才拒绝。预览与实际落位共用这一个函数，因此**看到哪格就落到哪格**，不会再出现"预览一处、落位另一处"。
- 修掉原来的静默重排：此前拖到占用格会被悄悄挪到第一个空格，与红色预览自相矛盾。
- 已实测跟随精度：鼠标移到 4 个不同位置，幽灵框中心与鼠标误差均为 **0.00 px**，且每帧保持可见。
- 已重新导出 exe 并实测启动正常。

## 2026-09-22 搜刮与拖拽改版

- 交互改为：`F` 单击开始搜索容器，物品每 1.2 秒浮出一件（普通箱 4×4 / 深处教堂 5×5）；地上掉落物 `F` 秒拾，不再需要长按。
- 搜索框与背包同屏：搜出的物品用鼠标拖进角色背包或次元口袋；背包内也可拖拽调位；支持拖到框外丢弃。
- 数据结构改动：地面掉落与阵亡掉包统一为「格状容器」（`world_drops`），随机快照改为 10 元组；搜索进度存在容器上并随快照同步。
- 系统测试扩到 361 项（新增搜索计时、搜出数量、未搜格不可拿、走开暂停、地面秒拾、双向拖拽、越界拖拽落位等）；UI 集成新增搜索窗口开启、自动浮出、拖拽入包与包内调位、地面秒拾。
- 修复三处实现错误：`chest_loot` 返回的背包条目被当作字符串（导致容器里塞进一个 JSON 文本）；E 通道每帧清空搜索计时器，导致搜索永远无法推进（改为独立 `search` 计时器）；拖拽出容器时传了 `-1` 而非搜索引用，导致永远返回失败。
- exe 已重新导出并实测启动正常。

## 2026-09-22 视觉改版回归

- 更换纵向主菜单、三角色立绘营地、图标装备/背包、战斗 HUD、怪物精灵、地面材质与角饰地图。
- 扩展 UI 测试截图：首页默认/切换选中状态，三名角色营地，填充背包与选中物品详情，战斗、地图、手册、结算与再次出征。
- 图形 UI 集成 0 失败；系统测试 261 检查 0 失败。未改动联机与战斗规则，不重复宣称新增公网验证。


## 2026-09-22 免费真人角色语音替换

- 使用すぱらんど 30 条日语真人录音，覆盖三名角色 45 个语音槽；同角色不混用其他角色录音，部分事件有意复用。旧 MiniMax 录音已退出运行时资源。
- 资源验证通过：固定来源哈希、三角色音色分组、十类事件覆盖、字幕一致性、48 kHz 单声道 PCM16、起音、首尾淡化、过采样峰值及大招时长。
- Godot 角色语音：81 检查，0 失败；音效行为：138 检查，0 失败。
- 图形大招测试：0 失败；检查了新版署名页与雪璃大招字幕截图，无截断。
- WASAPI 实际混音：0 失败，验证左右方位和距离衰减；录音仅留在本地 build/free-voice-game-mix.wav。
- 素材只做静音修剪、采样格式转换、增益和首尾淡化，不进行变调、合成或 AI 训练。源文件、条款核查缓存、旧语音与旧试听均留在忽略的 build/free-voices。
- 主观听感尚未经人工试听评审；本轮未修改战斗或网络规则，未重复进行公网测试。

- 便携 PCK 独立资源复测：角色语音 81 检查、0 失败。实际混音 23.32 秒，峰值 -3.30 dBFS，无削波样本。


## 选人语音

- 营地人物按钮播放三名角色各自的选人台词；复用同角色真人录音，总录音仍为 30 条，事件槽增至 48 个。
- 快速切换只保留最新角色，重复点击不重启当前台词；大厅数据刷新不中断选人语音，重复点击当前角色不清除准备状态。退出营地或进入战斗停止播放，静音时不排队播放。
- 选人集成测试 21 检查、0 失败；原角色语音测试 84 检查、0 失败；资源来源、波形、字幕、时长验证通过。
- Windows 便携包已重新导出，使用 WASAPI 对打包资源复测选人功能，21 检查、0 失败。Dummy 音频驱动在快速结束测试时报告旧 UI/环境音资源清理警告；真实 WASAPI 驱动下退出无此警告。


## 原版大招文字恢复

- 三角色蓄力、爆发与联机短版恢复最初的中日咏唱文字；显示文本独立于真人录音元数据。语音文件和播放时长未改动。
- 现有图形大招测试 0 失败；雪璃爆发截图确认恢复「聖域展開、暁の祈り！／圣域展开——拂晓之祈！」且完整显示。便携 PCK 已重新导出。

## 2026-09-22 Suno 背景音乐

- 接入《营地守望》（162.90 秒）与《血潮废墟》（127.31 秒）：本地 Ogg 循环、1.8 秒场景交叉淡化、语音与奥义期间压低音乐，以及独立音乐音量设置。
- 便携 PCK 在 `dist` 目录使用 WASAPI 复测，测试脚本位于包外：音乐 10 检查、音效 138 检查，均为 0 失败；退出无资源清理错误。日志：`build/music-pack-test.log`、`build/music-pack-audio-test.log`。
- 两首成品与清单 SHA-256 一致，便携包附带的音乐清单与项目清单一致。44.1 kHz 立体声解码有效，无非有限采样或削波；营地与废墟采样峰值分别为 -6.12 dBFS、-3.50 dBFS。
- 设置界面已检查；信号和播放行为验证不代替人工听感评审。生成提示词、接口实际返回型号、来源与制作说明见 `MUSIC.md`。

- 图形 UI 集成 0 失败；系统测试 261 检查 0 失败（该轮数字，储物改版后为 328）。未改动联机与战斗规则，不重复宣称新增公网验证。

## 2026-09-22 启动方式变更

- 删除旧的 `dist/`（未内嵌 PCK 的 exe + 独立 pck，共约 230 MB）与旧的 `Start-Game.cmd`。
- 中途试过 cmd + PowerShell 启动器方案，最终按需求改为直接交付 exe，相关脚本（`Launch-Game.cmd`、`Create-Desktop-Shortcut.cmd`、`tools/launch.ps1`、`tools/make-shortcut.ps1`）已删除。

## 2026-09-22 导出独立 exe

- 导出模板：本机无模板且 GitHub DNS 不可达，改用 `downloads.godotengine.org` 的 S3 直链；读 ZIP 尾部 EOCD 取得中央目录，再用 HTTP Range 只取
  `templates/windows_release_x86_64.exe`（37.9 MB 原始 deflate 流，解压 109,268,480 字节）与 `templates/version.txt`，避免下载 1.2 GB 整包。模板已装到 `%APPDATA%/Godot/export_templates/4.7.2.stable/`。
- `export_presets.cfg` 改为 `binary_format/embed_pck=true`、`export_path="dist/CrimsonTide.exe"`、`script_export_mode=2`（二进制 `.gdc`）、`application/icon` + 产品名/公司名/版本。
- 产物 `dist/CrimsonTide.exe`：单文件 162.4 MB，含用户版本信息（公司 Crimson Tide / 产品 血潮守望 · Crimson Tide / 文件版本 1.0.0.0）。
- 已验证：在项目内双击可正常出窗口；复制到 `%TEMP%` 下的空目录后单独运行同样正常，确认不依赖源码目录或旁边的 pck；运行后写入 `%APPDATA%/Godot/app_userdata/血潮守望 · Crimson Tide/profile.json`，存档可用。
- 已验证脚本保护：exe 内以 `.gdc` 字节码存放，全文检索不到 `scripts/main.gd` 中的明文语句（如“背包空间不足：先腾空当前背包内的物资。”）。
- 已知未解：`--capture` 截图路径（`RenderingServer.frame_post_draw`）在本机窗口模式下会一直挂起不退出，这是储物改版前就存在的问题，与本次导出无关，未修。

## 2026-10-06 新关卡夜景材质与道路验收

- 内置 ImageGen 按纯文字生成 43 张 flat-night-v7 地图；保留 7 张此前指定保留图，原 a1-a5 的 25 张背景与地面数据保持不变。
- 50 张新增地图均已选入 ground-manifest.json，五层的诅咒、事件、工坊、赌徒、镜像各有独立背景；50 个图面边界叠图已逐张检查。
- tests/roguelike_smooth_maps.gd：1065 项 / 0 失败；tests/roguelike_geometry.gd：986 项 / 0 失败；tests/roguelike_routes.gd：5220 项 / 0 失败；tests/roguelike_seven_rooms.gd：11797 项 / 0 失败（合计 19068 项）。
- 保留战斗主路中央连续通道，避免窄图边缘装饰物占住中线；分叉回归按清单曲线行走，替换过时的固定 UV 路标。
- 四/五层后续战斗图加宽；已完成图不重新生成。素材审计：tools/audit_rogue_final_maps.py，50/50 通过。
- 实机预览：build/final-map-audit/gameplay-*.png；边界叠图与日志同目录；提示词与选图 SHA-256：output/rogue-final-night/。
- 导出 dist/CrimsonTide-Rogue-Night.exe，排除旧 final-night-v5/v6、safe/seven-night-v1 等未选用版本；内嵌 PCK。
- 打包后再由控制台引擎加载 exe 内嵌资源包执行同一地图测试：1065 项 / 0 失败，确认 50 张选定地图、专用房间映射及道路数据实际存在于导出包。

### 2026-10-06 ComfyUI 3 倍图接入

50 张最终地图切换为 VOSR2 放大图，长宽均为原图精确 3 倍；75 组归一化碰撞轮廓与出口未变。原 a1–a5 图保留。工具优先选择 3 倍图，Windows 导出排除同名原分辨率图。

验证：smooth_maps 1115、geometry 986、routes 5220、seven_rooms 11797，均为 0 failures；素材审计确认 50 张尺寸与 SHA256。实际主场景截图验证地图加载。

Windows 成品 dist/CrimsonTide-Rogue-Night.exe（1,919,859,472 字节）已重建；通过 --main-pack 加载成品资源后运行 smooth_maps，1115 checks / 0 failures，确认全部 50 张 3 倍图可加载且保持原始导入尺寸。

## 2026-10-06 具体武器与连段特效

- 69 把具体武器统一身份编排；闯关 48 把武器不再合并到基础类别特效。三段攻击、四类派生、角色确认连招与飞行弹体使用对应形状/元素，取消重复的通用法杖光球。
- 相关检查共 5332 项通过：weapon_vfx_identity 535（真实 GPU：48 武器像素唯一、69 武器三段差异、四类派生、角色连招、蓄力跟随/取消、闪避与清理上限）、weapon_vfx_battle 45（实际主场景事件/挂点/确认派生）、standalone_vfx 119、weapon_stroke_stability 200、all_weapon_mounts 2672、weapon_contact_particles 654、combat_particles 384、rogue_build_system 440、combat 78、spells 106、roguelike_vfx 99，均为 0 failures。
- 编辑器导入和 Windows 导出成功；build/CrimsonTide-WeaponVFX.exe 为单文件内嵌 PCK（1,919,875,912 字节）。导出包再次运行 standalone_vfx 119、weapon_vfx_identity 535、weapon_vfx_battle 45，均为 0 failures，确认新编排与几何存在于成品中。
- 预览：build/weapon-vfx-48.png、build/weapon-vfx-combos.png；9 张实际主场景截图 build/weapon-vfx-battle-*.png 已检查。没有更改伤害、命中范围、法力消耗与冷却。
- 已知基线问题：weapon_effect_direction 122 项中 6 项失败，均为旧 14 号断潮巨刃原 PNG 的朝左/朝上半平面像素占比。已从 git HEAD 恢复七个原始脚本到隔离的 build/weapon-vfx-baseline，再运行同一测试，得到完全相同的 6 项失败；不是本次新增回归。新版的实际挂点检查和具体武器像素检查通过。

## 2026-10-06 武器 ImageGen 方图与真实强化

- 完成 74 张内置 ImageGen 生成的原始透明方图：52 个武器主图、绯红剑额外两段、8 张类别连段图层、12 张实际核心触发图。48 把闯关武器各自保持独立主图，同名远征/闯关武器共享对应画面；运行时不使用被否决的 1:3 长图。原始 RGBA、SHA256 和完整提示词存于 assets/combat/imagegen-square。
- 强化/品质在出手时冻结；+2/+4 核心档位、+3/+5 角色连招依据现有规则。核心只在真实机制执行后播图，旧弹丸换装后仍保留出手状态。修补飞行弹丸从快照读取强化光强；不更改命中范围、伤害倍率、冷却或解锁规则。
- 13 组相关回归共 6100 检查，0 failures：weapon_square_art 718、weapon_vfx_progression 32、weapon_vfx_identity 553（真实 GPU；含强化光强不扩范围和十二核心两档像素差异）、weapon_vfx_battle 45、standalone_vfx 119、weapon_stroke_stability 200、all_weapon_mounts 2672、rogue_build_system 440、combat 78、spells 106、roguelike_vfx 99、weapon_contact_particles 654、combat_particles 384。
- tools/audit_weapon_square_art.py：74 个原始 RGBA、0 failures；Godot 编辑器导入成功。最初加载检查失败是新增素材尚未完成导入，导入后通过。48 武器对照、八组三段对照、+0/+2/+3/+4/+5 实际核心触发对照及九张主场景截图已生成并检查代表性武器画面。
- build/CrimsonTide-WeaponImageVFX.exe Windows 单文件导出成功（2,003,072,008 字节，内嵌 PCK，包含当前工作区资源）。成品中再次运行 weapon_square_art 718、weapon_vfx_progression 32、weapon_vfx_identity 553、weapon_vfx_battle 45、standalone_vfx 119，共 1467 检查、0 failures。
- 更新 PROJECT-GUIDE.md §2/§4.K/§5/§8/§10/§11/§12.6，以及 README.md、VFX-REWORK.md、WEAPON-IMAGE-VFX.md。路牌审计 441 个锚点：OK 344 / DRIFT 0 / WRONG 0 / HINT 97。

## 2026-10-07 实际武器机制与特效加厚

- 续接完成 32 张按动作、飞行、范围爆发分工的原始 ImageGen 方图；素材审计 32 项，0 failures。修正空中圆斩高度、光束相机稳定性和远程派生多余画面。
- 按“太细、太弱”的反馈，在运行时加厚刀光主体、突刺与弹体亮芯，加强边缘辉光，增大枪焰/法杖出手/命中闪光，延后刀光淡出。原始图片像素不变，伤害与碰撞规则不变。
- 本轮源码 9 组共 4621 检查，0 failures：weapon_mechanics 429、weapon_mechanics_visual 29、weapon_vfx_identity 553、weapon_stroke_stability 196、weapon_vfx_battle 41、all_weapon_mounts 2568、weapon_vfx_progression 32、weapon_contact_particles 654、standalone_vfx 119。
- 新增 GPU 检查：同一捕获刀光、同一帧，启用加厚后的亮像素较关闭扩展增加至少 35%；箭/冰针在飞行中有至少 6 像素可见厚度；圆斩保持空心和身体中心。中心检查采用 alpha > 0.08 的可见轮廓，避免极淡辉光像素干扰测量。命中闪光检查同步为半径不超过 40、时间不超过 0.18 秒，继续检查位置、去重和碎片数量。
- 编辑器导入和 Windows 单文件导出成功：build/CrimsonTide-WeaponMechanics.exe，2,076,241,536 字节。使用引擎 --main-pack 加载 exe 内嵌资源，在空目录运行外部测试脚本；五组共 1162 检查，0 failures（机制 429、GPU 29、身份 553、强化 32、独立特效 119）。
- 更新并检查 build/weapon-mechanics-comparison.png、build/weapon-mechanics-motion.gif 和代表性主场景截图 build/weapon-vfx-battle-603.png；GIF 由 viewport 帧直接编码。项目路牌 609 个锚点：OK 405 / DRIFT 0 / WRONG 0 / HINT 204。

## 2026-10-07 ImageGen 原图重新制作

- 用户澄清要求重新用 ImageGen 绘制不理想的素材，重新生成14张透明方图：8种动作轨迹（轻刃、双刃、突刺、重刃、轻/重圆斩、仪镰、战戟窄扫）、5种弹体（箭、冰针、子弹、雷弹、月刃）和弓弦出手。保留旧图供对照，现46张原始RGBA通过哈希、透明度、长宽比和圆斩透明中心审计，0 failures。
- 新图统一为 _v2，weapon_image_art.gd 的 REDRAWN 映射实际攻击及关联施法出手；原始图片直接复制，完整提示词与生成原始路径在 assets/combat/imagegen-mechanics/prompts 和 manifest.json。没有对像素加工。删除上轮 weapon_body 扩边shader，取消横截面拉厚，普通贴图按自然比例显示。
- 本轮源码9组共4622检查，0 failures：weapon_mechanics 429、weapon_mechanics_visual 30、weapon_vfx_identity 553、weapon_stroke_stability 196、weapon_vfx_battle 41、all_weapon_mounts 2568、weapon_vfx_progression 32、weapon_contact_particles 654、standalone_vfx 119。
- GPU原图比较不使用扩边或辉光shader：相同绘制尺寸下，旧轻刃原图亮像素140，新原图1675，通过新增的至少50%主体增量检查。实际飞行渲染中长弓箭和短弩箭可见高度6，冰针10；圆斩中心/空心/空中高度及光束相机稳定性通过。前后对照首次捕获中的白块来自预览临时纹理过早释放，已通过持续持有纹理修复；第二次绘制等待字体图集稳定，14组对照已完整检查。
- build/CrimsonTide-WeaponImageRedraw.exe 导出成功，2,082,811,544字节；引擎从空目录以 --main-pack 加载 exe 内嵌资源，五组1163检查，0 failures（机制429、GPU30、身份553、强化32、独立特效119）。
- 原图对照 build/weapon-imagegen-redraw.png、招式对照 build/weapon-mechanics-comparison.png、动态 build/weapon-mechanics-motion.gif 与实战截图 build/weapon-vfx-battle-603.png 已更新并检查。项目路牌609锚点：OK405 / DRIFT0 / WRONG0 / HINT204。


## 2026-10-08 Boss 固定顺序与特效身份修正

- 远征主线固定主教→猎王→女王→无名赤月→条件终局。隐藏战等无名赤月倒下后再触发；已结算隐藏战不再重复推进普通终局。魔境五层恢复古王→暴君→女皇→舰长→剑圣，额外三身份素材与招式保留。
- 蓄力、阶段、死亡和旧招式释放事件显式携带实际 art_key；缺省 art_key 时以 boss_art 恢复身份。阶段与死亡音效按身份选择，死亡清除旧蓄力/阶段演出；远征死亡事件携带 raid_boss，避免额外普通怪死亡粒子。
- 九组逻辑套件共 11954 项，零失败：expedition 79、hidden_ending 103、map_boss_roster 984、boss_full_effect_coverage 4675、boss_attack_intent 1592、rogue_boss_phase2 406、rogue_boss_pool 2340、boss_vfx 425、boss_choreography 1350。覆盖全部 104 招、20 张招式表，以及缺失身份字段/敌人已移除后的死亡特效。
- GPU 实机可视测试：五层 25 招各预警/释放 50 张、五张小怪场景、远征 13 张演出截图，已检查代表画面。修正旧可视夹具直接写 area=5 进入镜中挑战的错误，改为真实图节点的 Boss 房间，避免 UI 遮挡。
- Boss VFX 双进程联机房主与客户端通过，四主题释放与危险区快照、蓄力、招架、破防、阶段、死亡事件均收到。旧联机测试误要求危险区主题总数为 3，而当前骑士也有主题 3；修为验证完整四主题，并增加 RPC 身份一致性断言。演出夹具按 actor_id 定位 Boss，不再误将敌人列表最后的女王机关当成骑士发送死亡事件。
- 旧 boss_redesign 素材审计仍有 3/744 失败（Native HD art、No shared reskin source、Seventeen bosses each have four original effects）。单独加载 HEAD 修改前 boss_effect_art.gd 复跑得到完全相同的三项失败；本轮未修改 PNG、图集清单或纹理映射。该套件亦有原有退出资源泄漏警告。新专项及主场景脚本未出现解析错误。
- 项目路牌 727 锚点：OK 471 / DRIFT 0 / WRONG 0 / HINT 256；git diff --check 通过。本轮修正在源码，旧导出 EXE 尚未重新打包。


## 2026-10-09 魔境地图顺序与战斗密度重平衡

- 调整源码 `rogue_graph.gd`、`roguelike.gd`、`rogue_build.gd`：每层 8～9 房、每条路线最少 6 场战斗（含守层者），前两场战斗后进入圣坛，第三场战斗后进入补给，长层后段可选特殊服务。取消会话二次覆盖生成图，保留镜像出现保底、分支与确定性。
- 同批调整每波数量、后期普通怪生命、前四场战斗补瓶、精英/首领奖励，以及连接中 active/down 玩家的人数预算。数值表与边界写入 `BALANCE.md`、`ROGUELIKE.md`、`ROGUE-BUILD-IMPLEMENTATION.md`。
- 新增 `tests/rogue_map_balance.gd`：209619 项、0 失败，穷举 100 种子×5 层所有路线，无连续服务房；实际生成五层普通/精英三波、地面合法性、补瓶去重和上限、风险奖励与离场人数均通过。
- 相关回归：rogue_graph 146223/0、rogue_build_progression 956/0（单人/四人五层、天赋核心、修为/锻造、XP/属性守恒）、rogue_hooks_roguelike 178/0、rogue_build_growth 4066/0、roguelike 194/0、rogue_effect_fixes 65/0、roguelike_spawn_spacing 4924/0、rogue_build_system 440/0、roguelike_seven_rooms 18581/0、rogue_rooms 1198/0、rogue_growth 6886/0。均为无头逻辑验证，不等同于真人操作通关。
- 正确启动双进程 `rogue_growth_network_fixes`：房主 9/0、客户端 7/0，成长、联机状态与结算通过。
- `final_e2e_roguelike` 120 项仍有 3 失败：诅咒减伤池、镜像首次确认、镜像二次确认。将本次三个逻辑文件临时替换为 HEAD 原版、运行后原样还原，得到完全相同的 3 项失败，非本次引入；没有修改夹具压低失败数。
- 200 种子×5 层比较实际旧图（含 dress_floor）与新图：平均每层房数 7.984→8.608、平均战斗 4.102→6.304、最少战斗 3→6。各门等概率均值，未计可跳过镜像为战斗；结果 `output/map-route-statistics.json`。本轮没有实测真人通关率，也未重新导出 EXE。
- 项目路牌已同步，锚点校验 766 项：DRIFT 0 / WRONG 0；`git diff --check` 通过。工作区原有和同时出现的武器特效、地图移动等改动未覆盖。

## 2026-10-09 手柄与强烈震动

- `tests/controller.gd`：37 项 / 0 失败；标准映射、死区、两种战斗模式的真实蓄力/释放、菜单隔离、虚拟拖拽释放、键鼠切换、OS光标回送保护、本地玩家震动过滤与包络优先级。
- `tests/weapon_hold_attack.gd`：1056 项 / 0 失败。
- `tests/rogue_panel_close.gd`：45 项 / 0 失败。
- `tests/item_bar_shortcuts.gd`：12 项 / 0 失败。
- `tests/camp_collision.gd`：35 项 / 1 失败，`right input restores hero`；用 HEAD 的 `camp_screen.gd` 副本运行同一测试，仍为相同 1 失败，属于既有角色朝向问题。
- 无头测试未验证实物手柄马达、驱动兼容性和实际菜单拖拽手感；验收操作见 `CONTROLLER.md`。未重新导出 EXE。

### 2026-10-09 手柄菜单与提示补修

`tests/controller_ui.gd`：21 项 / 0 失败，覆盖原始手柄事件→主界面 `_input()`→真实按钮回调：开始游戏进入营地、菜单方向选择、设置滑杆、B 返回、窗口光标点击、实际三选一卡牌选择及领取。`tests/controller.gd` 继续验证战斗与震动 37 项。窗口预览 `tests/controller_ui_visual.gd` 生成并检查标题/设置/营地/战斗截图；底部按键提示、焦点框和键鼠切换已接入。未重新导出 EXE。

### 2026-10-09 RB/RT 与 B 长短按

`tests/controller_layout.gd`：30 项 / 0 失败；两种模式 RB 立即普通攻击、RT 点按恰好一次重击与长按蓄满、B 短按松开闪避、长按奔跑不闪避、停止奔跑、面板/失焦取消、已有魔境 A 跳跃。`tests/controller.gd` 更新为 36 项 / 0 失败；`tests/weapon_hold_attack.gd` 原有键鼠蓄力机制 1056 项 / 0 失败。按键与长短按阈值同步于 `CONTROLLER.md`。

### 2026-10-10 故事连续地图与分层探索

`tests/story_geography.gd` 647项、`story_campaign.gd` 180项、`story_integration.gd` 12项、`story_visual.gd` 10项，合计849项、0失败。覆盖六幕连续野外、实际任务点与NPC通路、楼梯高度、双向分层入口与12层可选洞窟、寻路、宝箱去重、探索与传送激活保存、73任务和角色装备、进屋隐藏/离开恢复屋顶、缩放投影。OpenGL实际截图覆盖各幕营地和首图、楼梯、洞口、地下层、书库、墓室、女王和地图。最新独立EXE导出完成，标题故事入口冒烟检查退出0，日志 `STORY_READY quests=73 act=1 stage=0 npc_asset=true`。未人工连续游玩完整六幕。

集成测试保留原 rogue_build_preview 的UI锚点警告。路牌全量审计仍有46项既有DRIFT、无WRONG；本轮新故事锚点按实际行号添加，没有把旧工程锚点审计报告成全绿。


## 2026-10-10 Forward+开场样板与地面重叠修复

- 源码默认Forward+，实际4K输出、FSR2/FSR1/原生与三档画质；三个样板区域有实际GI烘焙、PBR材质、局部雾、渐进遮挡和区域缓存。完整范围见docs/rpg/FORWARDPLUS-ART-PIPELINE.md。
- 闭合原创部件面朝向1979项、战役180项、连续地图647项、故事集成12项均通过。植被为开放表面，在GPU画面中单独验证。
- 实际GPU覆盖：营地画面0失败、模式入口10项0失败、远征攻击/奥义21帧、104个Boss招式416张状态画面、肉鸽页面及攻击/奥义特效。旧夹具的NPC坐标、屋顶等待时间、准备费用、冻结蓝量与守层者初始化按当前规则修正，没有改变游戏费用或技能逻辑。
- 用户反馈平台闪烁：基础地形和平台顶面同高重叠，已精确裁去平台/楼梯区域，并裁切营地外延与区域连接面。97项裁切/小树阻挡检查（含实际SCN三角面检查）、647项地理回归、42项4K图形、39项素材显示及10项故事图形均通过。装饰小树和细枯树不再阻挡移动。
- Compatibility移除不支持的雾资源与实例参数，单独缓存的专项39项0失败，日志无Shader错误。异步预载资源加入释放逻辑，头less集成已无错误RID；部分GPU图形脚本退出时仍有纹理RID警告，原营地UI也有既存anchors尺寸警告，不等于全仓库零警告。
- 长测按用户最新要求暂缓；首轮在约4分钟时停止，未完成三轮行走/三轮战斗验收。短测及首次加载数据不代表最终稳定4K60；详见docs/rpg/PERFORMANCE-4K.md。
- 新版独立文件dist/CrimsonTide-ForwardPlus-4K.exe已导出；Vulkan实机启动进入故事模式，73任务、NPC资源载入成功，退出码0。旧EXE保留。

## 2026-10-10 开场场所制作续作

- Blender master新增12类家具，模型总数82（80原创、2许可植被），闭合部件朝向2098项0失败。六栋服务建筑移除同款原型桌子，分别布置值守、疗养、生产、档案、仓储和生活用途；44处增量摆放包含18处带统一占地的室内家具。
- `tests/story_workplaces.gd`：无头139项0失败；Forward+实机187项0失败，涵盖模型存在、家具阻挡、六门实际进出、台基高度、场景与逻辑占地一致、根网格淡出材质、Side/Front/Roof排除固定GI、六张真实3840×2160截图。Compatibility使用独立缓存151项0失败，修正测试夹具错误读取Forward+缓存后，日志无雾Shader错误。
- 回归：地图647项、战役180项、集成12项、地面互斥97项、4K渲染42项均0失败。集成仍有既有rogue_build_preview UI锚点警告，Forward+图形退出仍有7纹理RID警告；未宣称全仓库零警告或重跑长时间性能验收。
- 三个场景实际重烘焙并更新普通/兼容压缩缓存。烘焙工具新增互斥锁，编辑器插件校验目标文件修改时间，防止旧资源被误报为烘焙成功。新增JSON列入导出include_filter，避免源码可读、独立包缺少碰撞数据。
- 独立文件 `dist/CrimsonTide-ForwardPlus-v2.exe`（2,912,035,256字节）已导出，保留旧版。Vulkan实际启动、故事73任务与NPC载入成功，最终日志无脚本/资源错误；兼容启动脚本指向新版。路牌782锚点：DRIFT 0 / WRONG 0。样板后续和其他五幕继续精制，未宣称整部游戏达到重制版精度。

## 2026-10-10 室外地编、不规则洞窟与灰棘旧堡

- 新增16个原创Blender模块，模型库98个（96原创、2许可植被）；闭合部件朝向2541项0失败。共享补充摆放增至111处，营地/原野/驿路/洞窟/旧堡分别为40/23/5/15/28处。原有PV提示词未修改。
- 洞窟多边形边界共享给地面裁切、洞壁、移动、寻路与探索地图；删除两套重复支撑。第一幕第九区新增64×64米灰棘旧堡，包含双向入口、东西翼、回廊、拱顶大厅、升高领主厅、三个宝箱、守堡者与可激活传送阵。存档校验和阶段上限改从实际章节地图数量读取，原有ID保留。
- `tests/story_outdoor_castle.gd`：无头153项0失败，实际沿洞窟支路执行移动/高度判定，验证旧堡入口往返、奖励去重、存档第九区、传送往返、实际缓存中的111处摆放和洞窟地面三角面与边界一致。Forward+实机166项0失败；Compatibility实机162项0失败。输出各9张3840×2160截图，build/story-expansion-*.png和story-expansion-compat-*.png。修正GL检查夹具：LightmapGI需要有效3D场景，离树资源检查会引出lightmap空RID，接入场景后最终日志无此错误。
- 回归：地理660、战役180、室内189、表面互斥97、故事集成12项均0失败；模型朝向2541项0失败。未重跑全仓库门禁和长时间性能测试。782个路牌锚点：OK508 / DRIFT0 / WRONG0 / HINT274。
- 实际烘焙营地、原野、洞窟与旧堡；最后台基材质修正后的1/7/9三区烘焙耗时24.1/19/21秒（含编辑器启动），普通和兼容缓存已更新。编辑器插件等待资源扫描和场景恢复稳定，不重复打开已恢复场景，防止烘焙中根节点被替换；未知场景的批处理参数现在立即失败。部分编辑器ReflectionProbe在关闭阶段仍报告scenario空参数，重烘焙前旧路径警告在完成后消失；最终游戏GPU日志没有脚本/资源错误，Forward+图形脚本退出仍有7个Texture RID泄漏警告。
- 修正生成台基的贴图密度：世界坐标三向平铺，地形/平台几何与碰撞不改变。修正节点级材质覆盖遮挡淡出，运行时洞壁根网格确实使用淡出ShaderMaterial。
- 独立文件`dist/CrimsonTide-ForwardPlus-v3.exe`，2,927,753,356字节，旧版本保留；兼容启动脚本指向v3。release实际Vulkan进入故事模式：STORY_READY quests=73 act=1 stage=0 npc_asset=true；直接加载内嵌PCK的旧堡冒烟：PACKED_CASTLE_READY maps=9 dressing=28。原版任务依旧73项。
- 范围见docs/rpg/OUTDOOR-CASTLE.md。本轮只扩展开场样板和一座独立城堡；第二至第六幕没有逐幕精制。4K截图不等于4K60验收，完整人工战斗录像、时间超分残影与长测仍未完成。

- 最后校准领主厅两盏灯具及光源的台基高度，四处位置均与逻辑地面对应；旧堡重新烘焙21.1秒。无头集成禁用GPU资源的线程预载，消除DummyMesh错误RID，真实游戏继续异步预载。最终集成只保留既有UI锚点警告。

## 2026-10-10 建筑室内地面分流

- 修正v3的遗漏：城堡、墓室、礼拜堂/大教堂、书库不再复用野外soil/road地面混合。独立story_floor_palette和story_interior_floor shader忽略道路顶点色，采用石板、暗色磨损石板、木地板、中央礼仪带与领主厅铺砖；天然洞窟/矿坑保留岩土。
- 新增三套完整2K PBR、九张PNG，合计十三套/39张颜色、OpenGL法线、ORM。源自Poly Haven CC0，作者、下载URL、MD5/SHA256合并至material-sources.json，所有新贴图统一mipmap和VRAM压缩。书库使用已有旧木PBR。
- 原位修改旧堡地面、台阶和台基，保留网格/UV2/地编/碰撞；传送阵石柱保持独立材质。第九区实际重新烘焙，最终25.2秒（含编辑器启动），普通/兼容缓存同步。原有非目标区域SCN的重序列化噪声已还原。
- tests/story_architectural_floors.gd：无头384项0失败，Forward+实机394项0失败，Compatibility实机394项0失败。覆盖六幕全部建筑布局的材质分流及PBR、旧堡实际缓存中的建筑地面/台阶；实际4K照片覆盖城堡大厅/领主厅、墓室、礼拜堂、书库。材质检查夹具不创建额外LightmapGI，最终GL日志无lightmap空RID错误。
- 地理660项0失败、故事集成12项0失败，集成只保留既有UI锚点警告；路牌782锚点DRIFT0/WRONG0。未重跑长时间性能测试或全仓库门禁。
- 最新试玩dist/CrimsonTide-ForwardPlus-v4.exe，旧EXE保留，兼容启动脚本指向v4。制作与资源来源见docs/rpg/INTERIOR-FLOORS.md。原有PV提示词未修改。
- v4独立包2,961,320,962字节；实际Vulkan启动故事模式STORY_READY quests=73 act=1 stage=0 npc_asset=true。内嵌PCK直接载入旧堡检查：PACKED_ARCHITECTURAL_FLOORS_READY count=16，新贴图资源在包内存在，最终日志无脚本/资源错误。

## 2026-10-10 第二至第六幕独立美术扩展（v5）

- 新增84个原创GLB（每幕16个基础模块和4个专用设施），模型库总计182项；合计180原创+2许可植被。独立acts-2-6-master.blend保留第一幕源文件；五幕新模型合计546628三角。17套新2K PBR/51张贴图；总计30套/90图，来源、许可、作者及校验和记录完整。
- 覆盖五个营地与40个区域，15份室外地形高度采样；45个TSCN、45个Forward+ SCN、45个Compatibility SCN、45个实际lmbake/EXR。实际编辑器烘焙日志确认BAKE_BATCH all complete count=45；烘焙错误日志为空。
- 逻辑专项2837/0；缓存/GI/摆放专项7053/0；Forward+连续45区渲染7158/0；Compatibility连续45区渲染7158/0。后两者包含30栋服务房屋的真实屋顶/正面/侧墙进入隐藏与退出恢复，分别生成45张3840×2160画面。原始日志output/story-later-{tests-final,packed,gpu-all45,compat-all45}.log，截图build/story-act<act>-<stage>[-compat].png。
- 最初连续截图在第四幕后停滞，单独第五幕通过；修正story_world跨幕清空前幕kit/Floor材质/异步场景缓存后，两种渲染器连续全45区均完成。该检查没有记录正式P95/P99/独占显存，因此不把资源释放修正当成性能验收结果。
- 配套回归：地图地理685/0、战役180/0、实际入口集成12/0、建筑铺地414/0、工作场所189/0、地表覆盖97/0；闭合网格绕序10672/0。资源内容与HEAD比较：全部地图ID和73个任务内容一致；只更新额外副本名称/美术题材。
- 临时美术试玩检查PASS：显式预览第五幕第七区、46个传送目的地、保存禁用。正式存档入口不受该CLI路径影响。集成用例仍有既有rogue_build_preview容器锚点警告，0失败；两种美术GPU专项日志无SCRIPT ERROR/ERROR。
- v5单文件导出（最终大小及包内验证见下方）；实际内嵌PCK重新运行7053项检查，0失败；PCK临时试玩检查PASS。发布版本启动结果另记下方。旧v4与更早EXE保留，dist/Start-Compatibility.cmd指向v5。
- 此轮未跑全仓库门禁、未跑用户已暂缓的十分钟×三长跑；没有声称达到4K60、9GB预算或商业重制版雕刻精度。环境设施目前为场景叙事道具，未新写独立解谜/五幕Boss机制。制作/剩余边界见docs/rpg/ACTS-2-6-ART.md。

- 发布EXE实际Forward+启动并退出码0：STORY_READY quests=73 act=6 stage=7 npc_asset=true；90张实机截图尺寸逐文件核对均为3840×2160。路牌788锚点OK514/DRIFT0/WRONG0/HINT274；git diff --check通过。

- 最终精修增加4个房间专用设施，更新11个室内中央设施；缓存实际模型身份1654项核对通过，包内也1654/0。增量工具逐项检查GI用户路径，确认设施未被烘焙，保留45个有效GI资源。最终84新模型/182总模型/546628新三角；绕序10672/0。补充压顶宽度拼接修正、转角隅柱与同源碰撞；更新后地图685/0、缓存7053/0、集成12/0、Forward+45区7158/0，原始日志story-later-*-joins.log。

- 压顶/隅柱最终版本Compatibility45区也7158/0；最终EXE为3354416448字节，内嵌缓存/GI专项7053/0、临时试玩PASS，正式Forward+发布启动/退出码0。数据与角色移动检查均不替代正式性能验收。

## 2026-10-10 副本探索、分区高差与有机边界（v6）

- 只读用户指定的旧包和重制包：新增25个DS1和33个HD副本模板检查，0解析错误，Levels/LvlMaze/LvlPrest数据另存reference-dungeon-inspection.json。没有导入游戏原素材，没有声称反编译闭源生成器或完整逐关试玩。
- 重做30个室内区域：80×108米包络、15个功能空间、3—4个中央不可走核心、主题设施、环路与四个奖励宝箱；实际可走面积2649.1—3580.7平方米。共3471处副本地编，34个新原创GLB/58944三角，模型库216项；dungeon-master.blend独立保存，原两个源文件保留。
- 19个室外区域使用不规则轮廓与侵蚀坡脚，孤立台地改成连续坡肩和次级起伏；渲染、通行、导航、探索图使用共同数据。室内改为四段贯穿空间的高程变化，踏面、立面与人物脚底一致。敌人按房间布置；地图ID、73任务和层间目标保持，宝箱原索引保留追加奖励。小树继续非阻挡。
- 初始扩展检出门户附近导航切角、功能设施中心占地与复杂凹洞顶点判定问题；保留36逻辑单位的导航余量，增加实际门户脚座占地、设施绕行空间，使用半开射线和双精度标量判定。最终逻辑检查2429/0，地理748/0，旧堡/洞窟337/0；实际通过移动/高度判定走到房间和目标，非仅检查存在一个AStar路径。
- 配套检查：后五幕8246/0（中心调整后的实际数据）；战役180/0、入口集成12/0、建筑地面1018/0、表面互斥73/0、模型绕序11321/0。临时预览PASS，55个目的地、存档禁用；正式存档入口保留。集成仍有既有rogue_build_preview UI锚点警告。
- 扩展遮挡件首次达到默认65536字节的实例Shader缓冲上限，正式配置改1048576字节。自动烘焙初期恢复55个旧场景标签造成启动超时；工具临时隔离并还原编辑器恢复列表、保存后关闭场景解决该问题，烘焙成功需要lmbake时间更新及非空GI数据。
- 最终烘焙、实机截图、缓存/PCK与发布冒烟结果见后续补充；本轮仍未跑全仓库门禁、十分钟×三的长时间测试或4K60正式验收。部分设施与材质仍跨区域复用，未新增五层高塔任务、独立谜题或Boss招式；商业重制级雕刻/材质精修仍有差距。

- 49区实际烘焙完成，分批日志exploration-bake-act1.log / exploration-bake-act2.log / exploration-bake-3-6.log分别确认9、8、32场完成；烘焙错误日志为空，GI资源总计55（包含原六个营地）。32场批处理结束后修正两处天然洞壁的连续顶部UV与收口，部件明确排除固定GI；静态地面及其烘焙用户未替换。
- 实机截图发现第一幕野外画面被MultiMesh遮住。定位为Dummy渲染器序列化的实例缓冲含0或异常1e38浮点数；改为story_ground_cover明确保存CPU Transform3D，实际进入场景再重建缓冲，制作与兼容打包使用0实例的安全资源。更新五个第一幕室外缓存，预检查植被无GI用户；草地变成簇状并缩小蕨叶。新增缓存变换范围检查和截图空间色差检查，防止仅凭退出码或图片尺寸误报视觉成功。
- Forward+与Compatibility实际各12张3840×2160截图、各36项检查均0失败；覆盖洞室、墓室、城堡、后五幕主题大厅与两种室外坡肩。Forward+退出仍有已知7个Texture RID警告，Compatibility最终退出日志无此警告；未宣称全仓库零警告。

- 最终缓存/GI/地编/真实移动/植被CPU变换专项7549项0失败；后五幕普通与兼容缓存的实际模型身份6912项0失败；入口集成12/0、临时预览PASS。24张PNG逐文件检查3840×2160，路牌788锚点DRIFT0/WRONG0。最终原始日志exploration-{packed-delivery,model-identity,integration-final,preview-final,forward-final,gl-final}.log。

- v6单文件3493534630字节；直接从内嵌PCK载入30个副本的房间数据/地面/有效GI/全部道具模型，PACKED_EXPLORATION_READY dungeons=30 quests=73 explicit_json=true；内嵌PCK临时预览PASS。实际发布版Forward+进入第一幕洞窟、Compatibility进入第五幕船坞、Forward+进入第一幕室外，均STORY_READY quests=73且正常退出0，未出现脚本/资源错误。洞窟和GL标准错误为空；Forward+室外退出仍报告已知7个Texture RID警告。日志exploration-release-{forward,gl,outdoor}-verified.log；dist/Start-Compatibility.cmd与两个预览脚本指向v6，旧版本保留。

- 最终路牌补齐植被缓存契约后789锚点OK515/DRIFT0/WRONG0/HINT274，git diff --cached --check通过；参考原始JSON、离线工具依赖及日志错误流加入明确忽略目录，PV提示词保持未跟踪且未修改。没有参考原资源进入提交或发布包。

## 2026-10-10 副本空间类型与边界语言（v7）

- 替换30副本的统一15房间格状骨架：22种空间类型、30份不同地面/空洞轮廓、13种包络，每区10—14功能空间，实际可走面积3705.0—9102.5平方米。墓甬道、天然岩腔、城堡庭院/翼楼、十字中殿、环形塔廊、扇形剧场、设备大厅及水槽跨桥采用不同结构。材料与模型仍使用已有原创库，未把模块复用包装成新雕刻资产。
- 新增逐边edge_styles、X/Y高差轴、水平槽水与外围基岩；看台缓升至舞台，庭院摆放调整为活动组合。逻辑数据、地板、碰撞、导航、分区敌群和探索图同源；新模型缓存带layout_family/layout_revision标记。19室外与6营地延续已有场景。
- 逻辑真实行走2646项0失败（story-identity-story_exploration.log），空间类型159/0（story-identity-logic-final.log），地图地理与全部层间入口748/0（story-identity-geography.log），战役180/0、集成12/0、CLI临时预览PASS。集成仍有既有rogue_build_preview锚点警告。旧测试的固定15房、80×108包络及四段高差断言改为新内容契约；剧场的共享座位模型明确进入许可清单。实际行走检查继续逐一走到每个功能空间与玩法目标。
- 30场LightmapGI实际重新烘焙，exploration-bake.log确认BAKE_BATCH all complete count=30，标准错误为空。打包和发布包检查另记下方。烘焙工具支持-DungeonsOnly，保留19室外/6营地已有GI；原PV文件保持未跟踪且未修改。
- 未运行全仓库门禁、长时间帧率/显存/加载验收或完整人工战斗录像；不声称4K60或商业重制美术质量。塔型为单地图环廊，未新增跨层桥、五层高塔剧情、解谜或专属Boss动作。制作范围见docs/rpg/DUNGEON-IDENTITIES.md。

- 最终地板/GI/地编/真实移动/植被缓存8529/0（story-identity-packed-story_exploration.log）；空间类型与实际边样式2725/0（story-identity-spatial-packed.log），含水面水平度、基岩不覆盖通路检查；后五幕缓存34362/0（story-identity-later-packed-final.log）、旧堡/矿洞465/0、建筑铺地1105/0。补光仅修改两场明确无静态GI用户的外围/中央岩体材质，保留烘焙地板；BEDROCK_MATERIAL_PATCH两场各3处确认GI_preserved=true。
- Forward+与Compatibility最终各12张3840×2160图片，各48项0失败（story-identity-{forward,compat}-grounded.log），两者标准错误为空。检查实际空间色差、正确缓存加载和队伍站在可走地面；手工检查洞腔、庭院、剧场、水槽截图。24张图片逐文件检查尺寸无异常。正常游戏相机尺度未变，比较照片使用48米视野，方便观察空间结构；不是运行性能统计。
- v7导出3497014376字节。内嵌PCK检查PACKED_IDENTITIES_READY dungeons=30 quests=73 model_identities=8408 forward_and_compat=true；8408为4204处摆放在普通/兼容两份缓存中的身份检查。包内CLI临时试玩PASS，原预览保存禁用/55个传送目的地保持。对应story-identity-{pck-final,pck-preview}.log。具体地图试玩脚本与兼容入口指向v7，旧EXE保留。
- 实际v7发布版Forward+进入第一幕旧堡、Compatibility进入第五幕船坞，均STORY_READY quests=73、正确幕/关、正常退出0，标准错误为空（story-identity-release-{castle,shipyard-compat}.log）。没有遗留本轮Godot/试玩进程；路牌789锚点OK515/DRIFT0/WRONG0/HINT274。副本场景改动仅涉及30区，未重写19室外与六营地缓存。

## 2026-10-10 地形边界、桥头与岸线（v8）

- 19室外静态陆地/岸壁重新生成并实际烘焙；exploration-bake.log确认all complete count=19。25场（包含六营地）的非通行衬底与水面安全更新，检查无静态GI用户，原营地GI保留。30个副本轮廓、任务及存档没有改动；小树继续非实体。
- 部分淹水网格精确裁切，道路按真实区域轮廓扣除重叠部分，补齐侧面/下封面；水面移到区域世界位置，岸线按地面网格交点采样。修复Packed数组别名造成道路计算误改移动轮廓的问题；修改前必须duplicate。背景覆盖最大21米正常视野及倾斜投影，邻区32米预载/44米卸载。
- 最终普通与GL缓存各881项0失败，真实接缝顶点10878个；检查实际高度、无地表叠面、背景排除固定GI、水面世界位置、桥头覆盖、营地背景及轮廓保护（boundary-packed-final.log、boundary-packed-compat-final.log）。最终源码生成六幕代表场景36/0（boundary-generated.log）；表面互斥/小树73/0、地图地理748/0。探索/缓存/实际通行8529/0，后五幕34362/0，原始日志boundary-exploration.log / boundary-later-acts.log。
- 制作中检出UV2展开状态、未索引Mesh测试及局部水面偏移问题；室外按单场进程展开，生成期间不流送/淡出邻区，索引测试支持未索引网格。中间照片也检出未封闭道路侧面、背景范围不足及营地虚拟边缘抢占原野高度，修正后重新更新背景/兼容缓存并核验真实接点。中间失败日志不作为最终验收数据。
- Forward+与Compatibility最终各10张3840×2160实机图，在正常最大21米视野检查六幕边缘，各20/0（boundary-forward-final.log、boundary-compat-final.log）；人工检查第一幕连接桥头及第五幕岸线。截图build/boundary-<act>-<stage>.png和-compat.png。两轮截图退出仍有既有7个Texture RID警告；不宣称全工程零警告。
- v8导出3533042066字节；内嵌PCK实际网格881/0（boundary-pck-geometry.log），包内同时核验30副本/8408摆放身份/73任务及19室外+六营地的两套缓存（boundary-pck-release.log）。实际EXE Forward+第一幕道路、GL第五幕海岸均STORY_READY、退出0（boundary-release-forward.log / boundary-release-compat.log）。Forward+退出有既有7个Texture RID警告，GL冒烟标准错误为空。
- Preview-Boundaries.cmd、旧副本/后五幕预览与dist兼容入口指向v8；旧EXE保留。预览保存禁用，PV提示词保持原样。路牌789锚点OK515/DRIFT0/WRONG0/HINT274。未运行长时间跑分、全仓库门禁或完整人工六幕流程；不声明4K60、加载时间/显存达标或商业重制美术质量。

## 2026-10-10 实地外景、南门河道与道路衔接（v9）

- 采用用户最终明确的实地要求：25场（19室外+六营地）新增起伏外景和5988处树/岩/植被摆放；第一幕南门增加曲折河道、桥体、低栏、桥台和河岸装饰。原可走轮廓/73任务/传送目标保持，小树仍非实体。外景仅补足非通行空间，不覆盖连接路与原静态地面。
- 连接材质改为两端PBR沿长度混合，路心/路肩分开；跨河段保留石板桥面，落地接泥路。营地旧地面扩张裁回包络、UV2重新展开并实际烘焙六场；exploration-bake.log确认all complete count=6。室外静态地面与GI保留；外景明确GI_MODE_DISABLED，新增植被不作为不可隐藏的烘焙遮挡。
- 最终普通/兼容缓存几何各950项0失败，实际接点10362个（landscape-packed-final.log / landscape-packed-compat-final.log）；真实源码生成81/0（landscape-generated-final.log），含六幕出口实际移动、路肩顶点色、端点材质、南门桥体；地图地理748/0（void-geography.log），表面互斥/小树73/0，探索/缓存/真实通行8529/0（landscape-exploration-final.log）。直接卸载未进树的GL缓存仍触发Godot material=null清理诊断；实际入树的截图和游戏启动另测，不能把计数0失败写成所有错误流为空。
- 六营地烘焙保存时发现编辑器重建MultiMesh缓冲会进入SCN，插件保存前调用prepare_capture，只保存CPU变换；配套pack_story_boundary_scenes规范化25场，最终植被缓存检查通过。新GLB装饰保存初版同时保留scene_file_path与拥有子节点，实例化产生孤立Mesh；清除GLB路径后赋owner、重建自身外景分组解决。最终实机已没有本次新增的孤立Mesh/Shader/Material/Instance泄漏；Forward+仍有既有7个Texture RID退出警告。
- Forward+与GL最终各12次1920×1080实机拍摄，各36项0失败（landscape-{forward,compat}-photos-final.log）；正常15米视野，包含营地南门、原野入口、横向道路连接、桥、后五幕边界。补拍两种渲染器入口，各6/0；同一地图的两个机位分别保存-entry，最终24个PNG逐文件检查1920×1080。Forward+标准错误仅既有7个Texture RID退出警告，GL实机截图标准错误为空。手工检查南门河桥、第一幕横向连接、第五幕河岸；不是概念图或长时间性能报告。
- v9最终单文件3685776242字节，导出无脚本/资源错误（landscape-export-v9.log）。包内实际网格950/0（landscape-pck-geometry.log），同时检查30副本/8408摆放身份/73任务和25份外景的双渲染缓存（landscape-pck-release.log）。批量GL缓存卸载存在上述material=null诊断；包内所有对象身份和GI检查完成。
- 实际发布EXE Forward+及Compatibility均进入第一幕营地，STORY_READY quests=73 act=1 stage=0、退出0（landscape-release-{forward,compat}.log）。Forward+仍有既有7个Texture RID退出警告，GL发布启动标准错误为空。Preview-Boundaries从营地开始查看南门河桥，其他预览与兼容入口同步指向v9，临时预览不保存战役进度。
- 没有全仓库门禁、长时间帧率/显存/加载验收、完整六幕人工战斗录像或商业重制质量声明。新增摆放使用现有模型库与已许可植被，未新增雕刻模型或网络下载素材。制作流程见docs/rpg/BOUNDARY-SURFACES.md。
