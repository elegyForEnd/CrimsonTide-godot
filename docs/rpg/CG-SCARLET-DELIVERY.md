# 赤月遗书 CG 插画交付

2026-10-16 正文更新：CG-01 改读私人召回信与封存令，CG-03 第二封信改为拨药、撤越权并继续催归。图像构图仍可用，现有平图未重画；可读字层按 [女王新版](SCARLET-QUEEN-REWRITE.md) 排版。CG-15 未签移交书若需入画仍须另做分层，不在本轮伪称已补画。

2026-10-15。按用户指定的 `assets/feiyue.png`、`assets/xueli.png`、`assets/yayu.png` 三视图生成，女王沿用项目原画像。使用内置 image_gen，不使用外部付费接口或 CLI 生成。

## 文件

- 成图：`assets/story/cg-scarlet-v1/cg-*.png`，19 张，全部 3840×2160。
- 图片索引：`assets/story/cg-scarlet-v1/gallery.html`，点击查看完整图。
- 总览：`assets/story/cg-scarlet-v1/contact-sheet.png`。
- 清单：`assets/story/cg-scarlet-v1/manifest.json`，包括剧情触发位置、原始尺寸、成图尺寸、处理方式和 SHA-256。
- 生成原图：`art/story-cg-scarlet/masters`；初版港口明亮天光图另存 `variants`，不覆盖丢弃。
- 提示词与修订：`art/story-cg-scarlet/prompts.json`、`revisions.json`；生成来源记录为 `generation-results.json`。
- 导出工具：`tools/package_scarlet_cg.ps1`，将生成结果登记、保留原图、整图放大与制作预览，不调用图像生成接口。

## 尺寸与制作边界

本批内置工具返回原图为 1672×941。成图使用整张高质量双三次重采样输出 3840×2160，保留完整构图；**这是 4K 尺寸交付，不是原生 4K 细节生成**。没有用重新生成的局部细节伪装原画分辨率。

当前为完整平面插画，不包含可独立眨眼／换表情／拆人物的分层源文件，也未制作动画。纸面留白供游戏叠加信件文字，图纸仅保留示意线条。CG-01 的两次阅读、CG-16 的两个结局分别输出，共19张。

19 个动画节点的21个版本只登记为 `reserved`，`path=null`；`cinematics` 目录留空位，不放空壳视频。全部插画已绑定赤月遗书独立ADV与鉴赏，新旧存档隔离。

## 视觉核对

逐张核对人物与用户三视图、出场人数、服饰／发饰、绯月尾巴、角色武器、剧情时点、结局断剑与女王卸冠状态。已针对两封信的相同蜡印缺口和第五章尚未迎来黎明的港口天光做内置图像编辑修订，并查看最终总览。

运行接入以 [全流程触发表](STORY-FLOW-ADV.md) 与 [CG制作表](STORY-CG-PRODUCTION.md) 的节点为准，先接平面 CG；人物表情分层、轻动画和正式视频另做，不将当前素材描述成已有完整演出系统。

2026-10-15接入更新：新ADV、差分、NPC与背景、任务、战斗和结局已实现；视频与CG分层仍另做，见SCARLET-IMPLEMENTATION.md。
