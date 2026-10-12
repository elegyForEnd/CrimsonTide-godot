# 三位守望者 · 完整立绘差分 v14

本轮采用用户最后确定的整张生成方式。每人三套服饰、三个姿势、八种表情，共216张独立完整立绘；脸、头发、身体与服饰一同保存在每张PNG中，游戏一次显示一张完整图片。

216张资源已经导出并接入正式剧情与鉴赏界面。验收结果记录在根目录 TEST-REPORT.md；本轮未进行长时间性能跑分。

双击根目录 `Preview-VN-Full.cmd` 打开立绘鉴赏；`Start-VN-Full-v14.cmd` 启动带新立绘的游戏。剧情中使用右下角“立绘”或C切换衣装与姿势。

| 服饰 | 姿势 | 表情 |
|---|---|---|
| 常服、家居服、旅行装 | 正面闲立、轻侧抚领、轻侧抱臂 | 平静、微笑、喜悦、害羞、担忧、悲伤、生气、惊讶 |

服饰保持三人原画的配色和饰物特征。家居服采用柔软衣裙、针织外套与室内便鞋；绯月的旅行装为外套、裙装和行囊，雪璃与鸦羽的旅行装采用衬衫、外套和长裤，使三套服饰有不同轮廓。轻侧姿势按用户Galgame截图调整为约15–25度，脸自然朝向玩家。

## 资源与提示词

- `art/vn-full-v3/masters/`：216张内置 imagegen 原稿及逐图JSON，记录原始像素尺寸、来源、SHA256与完整提示词。
- `art/vn-full-v3/prompts/`：216份独立生成提示词。
- `art/vn-full-v3/jobs.json`：逐图台账。
- `assets/story/vn-full-v3/{hero}/`：2160×3840透明PNG工作画布，供游戏加载与外部使用。
- `art/vn-full-v3/build-report.json`：整图缩放及原稿分辨率记录。
- `build/vn-full-*-masters.png`、`*-expressions.png`、`*-faces.png`：检查用九宫格、全身对照和面部放大对照。对照图仅用于检查。

内置工具实际输出多数为887×1774。工作画布采用整图Lanczos缩放与透明留白，保留整幅内容、统一脚底位置；2160×3840是放大导出尺寸，原生生成分辨率在每张JSON中另行记录。

## 游戏显示

立绘鉴赏以角色、服饰、姿势、表情分别切换：1/2/3角色，A/D服饰，W/S姿势，左右箭头表情，Z观看距离。每次选择加载相应完整PNG，共享纹理缓存上限10。

剧情对话保留原有打字、自动、已读快进、回看与明确选项。右下角“立绘”或C可选择三人的服饰和姿势；服饰保存到战役旁的`.dialogue-outfits.json`，姿势保留于当前对话。姿势与衣装不改变装备、货币、任务或战斗属性。页面可以明确设置`pose`、`left_pose`、`right_pose`；表情按原有剧情表达选取。

对话采用上半身构图：1440×900逻辑画布下，立绘基准y=304，说话时y=298，头部到腰部露在对话框上方。初始位置和过渡共享同一基准；独立立绘鉴赏继续展示完整身姿。

旧剧情中的determined/tired分别映射到平静/担忧；原NPC及女王立绘继续显示。原人物设计、战斗精灵和战役进度文件保持原资源及格式。

## 制作和复建

`prepare_vn_full_jobs.py`准备216份规格；`register_vn_full_source.py`从内置工具默认保存目录复制独立原图并记录来源；`build_vn_full_portraits.py`进行整图画布处理。原图不重绘，不拆分或移植五官，不把不同图片的身体与头部组合。

早期过大侧转和过于接近常服的旅行服原稿已移入作者目录的废稿子目录，不进入216张最终资源。之前眉眼拼接方案被用户否定，保留在`art/vn-portraits-v2`作为制作历史。

v14沿用v9地图底包、v11战斗补丁、v12对话补丁与v13资源，并挂载VN-Full-v14增量。构建脚本只发布五份表现脚本与216张纹理，制作提示词、原稿记录、废稿与3D Boss实验不进入运行包。

`dist`需保持以下六个文件同目录：`CrimsonTide-ForwardPlus-v14.exe`、`CrimsonTide-VN-Full-v14.pck`、`CrimsonTide-Portraits-v13.pck`、`CrimsonTide-Dialogue-v12.pck`、`CrimsonTide-Combat-v11.pck`及`CrimsonTide-ForwardPlus-v9.exe`。实际补丁文件名以 `scripts/vn_full_patch_boot.gd` 的挂载清单为准。

复建使用 `python tools/build_vn_full_release.py`。源工程表现检查为Forward+478项、Compatibility478项、原剧情210项，均0失败；Python五组验证包括216张独立原稿、透明输出、完整组合、整图导出和提示词来源。
