# 闯关事件补全（2026-10-08）

## 实际改动

- 镜像试炼由二次点击随机结算改为真实敌人战斗：复制角色与当前武器，按武器类型选择近战／远程预警攻击，每第三次攻击释放范围技能。击败后支付奖励，挑战者倒地或断线判失败。应战即消耗一次机会，重复点击不能领奖。敌人强度受楼层与伤害上限约束。
- 实现 CU08 迷雾的本地玩家视野遮罩，跟随相机；移除诅咒恢复视野。
- 修复 CU01／CU10 在没有减伤时不增加伤害的问题，允许同池负减伤，并保留增伤上限。
- 审核全部 9 个事件／25 个选项的实际落地；补上拾遗老树血瓶消耗门槛，拒绝重复诅咒换奖励，事件恢复遵守治疗减益和血瓶容量。新增实际到账提示和不可选原因。
- 进房清理旧事件、镜像及服务状态，事件报价跟随当前 revision 更新。

## 验证

| 测试 | 通过断言 |
| --- | ---: |
| rogue_events | 485 |
| rogue_event_completion | 194 |
| rogue_rooms | 1451 |
| rogue_curses | 218 |
| rogue_hooks_roguelike | 178 |
| rogue_hooks_session | 44 |
| rogue_room_ui | 32 |
| rogue_room_ui_visual | 14（5 张截图） |
| rogue_event_network | 房主 7，客户端 6 |

上述用例均为零失败。`git diff --check` 通过。

额外运行的旧回归仍有失败，未将其列为通过：`rogue_ui` 的路线总数断言将分支节点总数限制为路径长度范围；`roguelike_network` 的开局购买、武器刻印与旧奖励领取断言失败，随后超时。新双端用例独立验证了本次事件选择、镜像战斗和奖励同步。

截图位于 `build/rogue-room-mirror-active.png` 和 `build/rogue-room-mirror-mist.png`。双端日志位于 `build/rogue-event-network-{host,client}.log`。
