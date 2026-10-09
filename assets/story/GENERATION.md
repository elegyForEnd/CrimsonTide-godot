# 原创 NPC 图集

工具：内置 image_gen，生成后进行一次背景清除编辑。原输出保留在 Codex generated_images，本项目使用 npc-atlas-v1.png。RGBA，1536×1024，3列2行。六类角色形象复用于六幕对应功能席位；人物姓名和对话分别来自战役表，并非33套独立角色美术。

生成提示：Create one transparent 3×2 atlas of six original full-body gothic fantasy anime town NPCs: a weary commander with dispatch; a hooded healer with cyan cathedral lantern; an older blacksmith with hammer; a woman archivist with open ledger; a travelling merchant with pouches; an older warehouse caretaker with keys and chest. Equal cells, upright three-quarter view, muted burgundy/slate/antique gold, planted feet, clear gutters, no text, no scenery, no crowns or wings.

编辑提示：Preserve exactly the six characters and layout. Remove the smoky gradient backdrop around and behind every character. Outside silhouettes alpha must be zero; character edges clean. Transparent PNG for a Sprite3D atlas.

检查：外部空白采样alpha为0，约59.7%像素全透明。底部锚点为每格高度的99%。角色与场景使用真实深度遮挡。
