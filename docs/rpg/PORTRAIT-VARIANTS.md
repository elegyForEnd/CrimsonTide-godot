# 三位守望者 · 4K 立绘差分 v13

以用户提供的 `feiyue.png`、`xueli.png`、`yayu.png` 为人物设计依据，制作绯月、雪璃、鸦羽各十种表情与四套衣装。全部生成请求使用 Rolldek、`gpt-image-2.5-sunburst`、`quality=max`、`2160x3840`、透明 PNG、高参考保真度，省略 n 与 response_format。

| 表情 | 衣装 |
|---|---|
| 平静、微笑、喜悦、害羞、担忧、悲伤、生气、坚定、惊讶、疲惫 | 常服、旅行披风、营地休息服、庆典礼装 |

交付 39 张经过注册的完整4K PNG：每人十张常服表情与三张额外衣装。游戏使用12张4K身体与27张表情贴片，两层独立组合为120种表现。表情改变眉眼、嘴型与面颊，不重绘身体；服装保留同一头部，脚底对齐到各自常服的实际底边。

## 体验和资源

- `Preview-Portraits.cmd`：在真实故事场景中体验。1/2/3切角色，左右方向键切衣装，点击/空格逐句查看十种表情。临时进度及衣装不保存。
- `Start-Portraits-v13.cmd`：正式入口。对话右下角“衣装”或 C 打开三人的衣装选择；不改变装备、属性、金币或任务。
- `art/story-portraits/exports/{hero}/`：39张完整4K PNG，具备透明通道。
- `assets/story/portraits/`：实际游戏身体、面部贴片与 manifest。
- `art/story-portraits/masters/`：未经覆盖的 API 原图、请求参数、响应摘要、usage和SHA256。
- `art/story-portraits/prompts/` 与 `masks/`：完整提示词与参考编辑蒙版。生成方式为用户授权的自定义渠道脚本，不是内置图片工具。

任意组合可导出完整PNG：

```powershell
python tools/export_portrait_variant.py --hero xueli --costume rest --expression shy --out output/xueli-rest-shy-4k.png
```

## 制作与接入

`rolldek_portrait_edit.py` 从环境变量读取密钥，参数与记录不包含密钥，不自动重试付费POST。实际接口返回图片URL时只用无鉴权GET取得图片；GET下载允许重试。雪璃喜悦原图遇到一次下载TLS故障，恢复了已生成的同一文件，没有再次提交生成。

`prepare_portrait_jobs.py` 固定每人的脸部矩形并生成九表情、三衣装的提示词/蒙版。`build_portrait_layers.py` 按逐张确认的双眼坐标校准编辑图，再分别合成眉眼、面颊和嘴部，保留原有脸部轮廓、头发与领口；个别被接口蒙版裁坏的嘴部采用同一人物另一张有效表情的嘴部，来源写入layer-build-report。原图均保留。衣装锁定原始头部并校准脚底。原始API图不被覆盖，Godot只导入游戏资源，作者目录有`.gdignore`。

`story_portrait_art.gd` 提供有上限的共享资源缓存；`story_portrait_view.gd` 把两层放在同一图片缩放与锚点上。`story_dialogue_ui.gd` 读取明确的expression/left_expression/right_expression和衣装；`story_dialogue_data.gd` 为十个明确台词以及营地回复设置表情。没有给全部73篇剧情逐句人工标注情绪，也不根据未署名引号猜说话者。

衣装选择单独保存于战役旁的`.dialogue-outfits.json`，不是人物装备存档。回看与衣装窗口互斥，打开时暂停打字和自动推进；退出故事清除立绘缓存。现有战斗精灵、NPC岗位立绘和其他模式的装备数值保留。

## 发布和复建

v13 EXE与以下四个资源文件同放dist：v9地图底包EXE、Combat-v11.pck、Dialogue-v12.pck、Portraits-v13.pck。前一版本入口保留。

复建顺序：完成原图和注册配置 → `python tools/build_portrait_layers.py` → Godot编辑器导入 → `python tools/build_story_portrait_release.py`。官方Godot导出器编译脚本，`pack_story_portraits.gd`仅抽取六份表现脚本、manifest、图片导入记录与纹理缓存，不把API密钥、制作工具、试制记录或3D Boss实验装进发布包。

## 已知接口事实

平台消耗日志把max/high都显示为standard，并未在图片响应返回quality；用户明确同意继续按max参数制作。因此记录区分“请求max”和“服务端实际档位未回报”，不将日志问题改写成已验证max。图片返回本身已检查为2160×3840，不是本地放大低分辨率图。

早先直接查看RGBA的RGB预览像有柔光；以真实Alpha叠到深色背景后，透明区的RGB没有进入画面。验收以实际合成与游戏截图为准，不把透明像素里的颜色当作可见背景。

本轮为静态表情与衣装差分，没有新增眨眼口型动画、完整配音或CG；没有做长时间跑分，也不据立绘检查声明4K60。
