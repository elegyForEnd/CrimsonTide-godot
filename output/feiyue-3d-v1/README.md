# 绯月：3 渲 2 首轮验证
> 已按用户要求回退游戏至原精灵图版本。以下 3D 实验素材保留原处；当前游戏请运行 ../../dist/CrimsonTide.exe。
当前免费动作适配版已经完成：使用 KayKit 免费 CC0 动作，已修正握剑、双手握持和脚底接触。主文件 `feiyue-character.blend`，预览 `feiyue-animation-preview.gif`，游戏 `../../dist/CrimsonTide-feiyue-3d.exe`。旧程序动画主文件保存在 `feiyue-procedural-backup.blend`。
完整开发记录、动作播放范围与验证结果见 [DEVELOPMENT.md](DEVELOPMENT.md)。下文保留最初图生 3D 的操作说明。

## 本次交付
- feiyue-turnaround.png：三视图总览。
- feiyue-front.png、feiyue-left.png、feiyue-back.png：分别上传的正面、角色左侧面、背面。696 × 836，同一缩放，纯白背景。
- generation.prompt.txt：内置 imagegen 的实际生成提示词。
参考原始绯月攻击图，采用无武器 A 姿势，保留银白发、红眼、黑白裙、红色蝴蝶结；简化细碎装饰。这是概念参考，三视图并非严格由同一个 3D 模型投影，生成后仍需检查一致性。
## 用户现在操作
1. 打开 https://3d.hunyuan.tencent.com/ ，选择图生 3D。如有多视图入口，主图上传 front，补充左侧上传 left，背面上传 back。不要将整张三视图拼图作为单图上传，可能生成多个角色。若账号仅支持单图，先使用 front。
2. 首轮选带纹理的生成。若有拓扑/低多边形选项可以试用，但减面不等于已经得到适合变形的拓扑。先使用默认质量验证轮廓，无需追求最高面数或写实 PBR。
3. 查看旋转预览：脸有没有变形，后脑是否完整，头发/手臂是否粘连，两脚是否分开，裙子有无洞、贴图是否明显拉伸。保留完整且像绯月的结果。
4. 下载 GLB（如果提供）。若仅提供 OBJ，下载模型、MTL 和全部贴图并保留相对目录，打包 ZIP。放入本目录下 incoming 文件夹，或在对话中上传模型/压缩包。
5. 反馈下载的文件名和所在路径；如果网页效果不好，同时给正面/侧面截图，便于判断应修模型还是重生。
## 模型拿到后的协作流程
1. Blender 导入，检查比例、法线、UV、洞和粘连，必要时重拓扑，拆分身体/头发/裙摆。复杂网格的清理和重拓扑工作量需在实际检查后确定。
2. 基础骨骼和权重，先做待机和一次挥剑；剑单独建模、挂到手部骨骼，确保直刃与握持。
3. 制作简单二档明暗卡通材质与描边；固定正交相机、灯光、脚底原点。避免将贴图中的强阴影再叠加成脏脸。
4. 嘴部先用少量表情贴图或形态键做闭嘴/攻击张嘴。不会默认增加声音。
5. Blender 渲染透明 PNG 动画帧，统一画布、角色尺寸和脚底锚点，接入当前 Godot 2D 动画流程。先验证待机和挥剑，再扩展其余动作。
6. 如果之后需要实时 3D，可导出骨骼与动画 GLB 到 Godot；Blender 自定义卡通节点不会自动完整转成 Godot 的等效效果，需在 Godot 重建卡通 shader。
## 官方资料
- 腾讯混元 3D 产品能力：https://cloud.tencent.com/document/product/1804/120696
- 腾讯多视图视角说明：https://cloud.tencent.com/document/api/1804/120828
- Blender glTF 导出：https://docs.blender.org/manual/en/latest/addons/scene_gltf2.html
- Godot 3D 格式：https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html

