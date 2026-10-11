> 状态更新（2026-10-12）：用户批准按max继续，制作已完成。最终资源、接入与验收以 [PORTRAIT-VARIANTS.md](PORTRAIT-VARIANTS.md) 为准；下文保留此前试制/接口排查历史。

# 三位角色立绘差分 · 制作中

用户授权使用 Rolldek 的 `gpt-image-2.5-sunburst`，4K、quality=max，并授权新增渠道调用脚本。原 imagegen 技能脚本保持原样；当前专用适配器为 `tools/rolldek_portrait_edit.py`，密钥仅从调用进程的 `ROLLDEK_API_KEY` 读取，未写入项目。

参考是用户提供的 `assets/feiyue.png`、`assets/xueli.png`、`assets/yayu.png`。计划每人十种表情（平静、微笑、喜悦、害羞、担忧、悲伤、生气、坚定、惊讶、疲惫）与四套衣装（常服、旅行披风、营地休息服、庆典礼装）。采用固定4K身体与局部表情贴片，保证同一身体、脸部锚点与脚底位置稳定；目前没有完成差分或接入游戏。

## 已完成的接口排查

- 两次 multipart 编辑请求明确发送 max、2160x3840、transparent、png，省略 n 与 response_format；其中雪璃请求未得到预期 b64_json，没有保存图像。最早的绯月请求进程也已结束，未保存图像。没有自动重试这些请求。
- 一次 JSON 对照同样明确发送 max，取得绯月试制 PNG：2160×3840、RGBA、alpha 0～254、7,808,287 字节。路径 `art/story-portraits/masters/feiyue-regular-neutral-json.png`，完整提示词及请求、响应摘要、usage、SHA256一起保留。
- JSON 实际返回 `data[].url`，不是文档描述的 `b64_json`；适配器已支持下载这类实际生成资产，不会把 API 密钥转发给图片下载地址。
- 密钥的只读 `/api/log/token/` 接口显示三次调用均记录为“品质 standard”。JSON 响应没有 quality 字段，因此无法证明 max 已在服务端生效，也不能直接断言服务端实际降档。诊断记录在 `art/story-portraits/api-quality-diagnostics.json`，没有密钥。
- 试制图有明显柔光边缘，尚未通过游戏透明边缘的美术验收，不是最终成品。后续必须处理边缘并复核眼睛、首饰与姿态一致性。

## 当前状态

暂停新的批量付费请求，等待用户选择：先由平台确认品质字段，或继续显式发送max并以实际图像评审质量。未更换模型、未使用低分辨率再放大冒充4K、未修改原有立绘或v12正式对话包。

`tests/test_rolldek_portrait_edit.py` 的六个离线检查通过，包括 JSON/multipart 参数、拒绝把明确 standard 当作max、保留异常响应摘要、不覆盖旧文件与密钥不写入记录。离线测试不会调用付费 API。`prepare_portrait_jobs.py` 用于后续人工确认脸部矩形后生成表情/服装提示词和蒙版；尚未运行生产批量。

渠道文档：`https://www.rolldek.com/docs/#/img25`。文档列出的4K竖版为2160x3840、Sunburst允许max，与服务端日志的standard仍待核实。


## 用户要求的 high 对照（2026-10-11）

只新增一次 JSON 请求，参考图、提示词、model、size、透明背景保持不变，仅quality改为high。实际生成 `art/story-portraits/masters/feiyue-regular-neutral-high.png`，2160×3840 RGBA，8,056,667字节，约117秒。返回仍无quality字段，最新消耗日志仍标standard；请求与响应摘要、只读日志分别保存为对应request/generation/response-summary和high-quality-log-check.json。

输出token：本次high为16243，前次max为33408。两次返回用量不同，但单张随机生成的token差异不能独立证明quality参数被正确执行。两图均有柔光边缘，尚未通过最终透明立绘美术验收。对照图在build/portrait-quality-max-vs-high.png，包含两张原图的同一坐标脸部裁切，标签指请求档位。

调用脚本现在支持显式--quality，默认仍max，不会自动将整个差分批量改成high。六项离线合同检查通过，包含high覆盖及核验；本轮没有继续付费批量，没有改变游戏或发布包。
