# ComfyUI 3 倍地图

使用本机 ComfyUI（http://127.0.0.1:8188/）中已配置的 VOSR2 图像工作流制作。
输入为 `output/rogue-final-night/artwork-audit.json` 最终选用的 50 张地图。
原图与游戏资源保持原样，放大结果另存此目录；ComfyUI 自身也保存到 `output/CrimsonTide-3x/`。

- `workflow-api.json`：导出的图像分支，倍数 3，种子 666。
- `results.json`：每张完成图的输入与输出尺寸、任务编号、SHA256。
- `run_batch.py`：顺序执行及断点续做脚本，仅依赖 Python 标准库与 Pillow。
- `current.json`：当前任务。

参数沿用当前工作流：quality_profile=speed、tile_strategy=auto、tile_size=512、tile_overlap=32、color_alignment=wavelet。
每张完成后验证长宽为原图的 3 倍（容许模型对齐误差最多 16 像素）。
此批为超分辨率放大，不重画路线或重新生成关卡。

完成状态：50/50。全部 PNG 可解码，输出长宽均为输入的精确 3 倍，输入文件 SHA256 与原始清单完全一致。五层预览已检查，ComfyUI 队列已空闲。
