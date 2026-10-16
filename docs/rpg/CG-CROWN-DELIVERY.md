# 《王冠与空城》新增静态 CG 交付

2026-10-16。使用内置 image_gen，7 张新增静态 CG 已保存并接入剧情；所有动画继续留空。

- 运行图片：[素材目录与尺寸记录](../../assets/story/cg-scarlet-v2/manifest.json)。7 张 PNG 均为 3840×2160。
- 预览：[本地画廊](../../assets/story/cg-scarlet-v2/gallery.html) · [总览图](../../assets/story/cg-scarlet-v2/contact-sheet.png)。
- 完整提示词、参考图角色及来源：[prompts.json](../../art/story-cg-crown-v2/prompts.json)。
- 生成原稿：`art/story-cg-crown-v2/masters/`；均为 1672×941。交付图是整图高质量重采样，没有伪称原生4K细节或已分层。

| 图片 | 实际触发 |
|---|---|
| cg-n01 | 00-01，居民等水的三句；宫廷对白前切回背景 |
| cg-n02 | 04-06，十年前撤运档案 |
| cg-n03 | 05-06，母亲请求绯月留下 |
| cg-n04 | 06-09，鸦羽实际发现工区仍住人 |
| cg-a01 | A-02，自愿接受后的移交准备；尚未戴冠 |
| cg-a02 | A-06，第一道晶纹与雪璃监护 |
| cg-a03 | A-07，三人在家居服中写回信，桌上三张船票 |

旧19张保留，无覆盖。7张新增图在对白时使用完整上方画框，避免文本挡住握手、晶纹与船票；小头像按对白切差分。按 H 可隐藏对白看图。它们是静态插画，图内角色没有嘴型或表情动画。

`resources/scarlet/campaign.json` 的24个影片路径均为 null，未制作新影片。`tools/package_scarlet_crown_cg.ps1` 可从保留的原稿重建交付与尺寸记录。
