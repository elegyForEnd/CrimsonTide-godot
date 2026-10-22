# 肉鸽 Boss · Tripo 多视图参考图

共 8 位 Boss，每位 4 张独立 PNG，总计 32 张；每张只有一个角色、一个视角。使用内置 image_gen 生成。

## 文件夹

| 文件夹 | Boss |
|---|---|
| 01-grove | 幽蕈古王 |
| 02-furnace | 熔炉暴君 |
| 03-astral | 星镜女皇 |
| 04-wing | 雷翼舰长 |
| 05-obsidian | 黑曜剑圣 |
| 06-bell | 暮钟司祭 |
| 07-earth | 岩窟冢主 |
| 08-abyss | 湮潮之主 |

每个文件夹中：

- front.png：正面。
- left.png：左侧面，角色朝画面右侧。
- back.png：背面。
- three-quarter.png：前侧斜视图（约 45°；前四位沿用先前生成的独立斜视图）。

上传同一 Boss 文件夹中的独立图片作为建模参考。不同 Boss 的图片分开使用。以 front.png 为主要设计依据；这些是 AI 生成的参考图，局部饰件、布料和视角会存在差异，并非同一实际 3D 模型的严格正交渲染。

## 造型依据

依据项目 assets/rogue/animations/boss-hd-0.png 至 boss-hd-7.png 及名称/技能设定。暮钟司祭、岩窟冢主、湮潮之主保留项目当前换色造型，分别沿用女皇、暴君、剑圣的身体剪影。

## 其他文件

prompts/ 保存本次生成和修正使用的提示词。single/ 保留最初四张独立斜视图。turnaround-prompts.md 是早期拼版尝试提示词，最终图片包使用 views/ 中的独立图片。

