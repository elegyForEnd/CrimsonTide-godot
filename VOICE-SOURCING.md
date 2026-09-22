# 现成日语角色语音选材

核查日期：2026-09-22。用户选择免费方案后，已接入すぱらんど的 30 条真人录音，覆盖 48 个事件槽；绯月＝少女元気め，雪璃＝少女おとなしめ，鸦羽＝少女クール。字幕、署名与演出时长已同步，原 MiniMax 音频备份在 build/free-voices/backup-*。当前选角依据作者标注与台词语义；音频信号、播放行为检查不代表主观听感已评审。

实际素材映射：`tools/free_voice_cast.json`；重建入口：`tools/prepare_free_voices.py`。以下保留初次候选调研，付费方案未采用。

## 项目对应关系

依据 `scripts/catalog.gd`、`tools/voice_dialogue.json`、`tools/feiyue_voice_design.json` 和现有 voice-manifest：三名日语女角色，每人 17 条，共 51 条。事件为 attack、heavy、magic、dash、hurt、heal、down、ultimate-charge、ultimate-burst、ultimate-short。

| 角色 | 选角方向 | 免费库候选分类 | 付费包候选分类 |
| --- | --- | --- | --- |
| 绯月／赤刃守夜姬 | 明亮、勇敢、有爆发力的少女剑士 | 少女元気め | TSUKAERU BATTLE female vol.2 的 Normal，或第一卷少女角色 |
| 雪璃／晨钟祈愿者 | 清澈温柔，施法时坚定，礼貌而有力量 | 少女おとなしめ、女性おしとやか | vol.2 的 Polite 1/2 |
| 鸦羽／黑羽处刑人 | 中低音女声、冷厉、命令感，重击要有力度 | 女性クール；少女クール作为备选 | vol.2 的 Commander 1/2 |

这些匹配是根据项目设定与作者分类推断，最终应听同角色的攻击、受伤、大招三类录音后定角，避免跨角色混用音色。

## 优先候选：TSUKAERU BATTLE female vol.2

- [产品与试听](https://gamedevmarket.net/asset/voice-assets-10-character-girls-voice-tsukaeru-battle-female-vol-2)
- [官方 SoundCloud 试听列表](https://soundcloud.com/mitsugetsueight/sets/demo_voice-assets-10-character-girls-voice-tsukaeru-battle-female-vol2)
- 页面标价 US$100，税费另计；10 个角色，1077 个文件（含效果变体），48 kHz / 24-bit，单声道，WAV/OGG/MP3。
- 明确列出真人声优。分 battle、skill、system_etc；Commander 对应骑士/士兵的冷峻命令口吻，Polite 对应文雅礼貌角色。
- 适合优先筛选的原因：同包可挑三种角色，战斗与技能语音分组，比日常萌系短句包更贴合项目。
- 页面允许商业游戏使用，禁止素材独立再分发；具体采用购买平台的许可证。

第一卷同样 US$100，1160 个文件（含变体），带中日英台词表与 53 MB 免费 Beta 包入口。第一卷声优包括夢咲ミルク、Tanoshii、橘茜、うらのうらおもて、komiya hairu。

- [第一卷与免费 Demo 入口](https://mitsugetsu-eight.itch.io/voice-assets-10-character-girls-voice-tsukaeru-battle-female)
- [作者提供的系列 Beta 包目录](https://drive.google.com/drive/folders/1F5chqqP4umzhq97uW_aZfiYq-pApL14c?usp=sharing)

Beta 用于评估；不能仅凭免费入口推断与正式包完全相同的发布许可，接入前看包内说明。

## 免费候选：フリーボイス素材屋すぱらんど

- [攻击／必杀／魔法，逐句试听和下载](https://soalunashosya.jimdofree.com/戦闘系/)
- [受伤／胜利／败北](https://soalunashosya.jimdofree.com/戦闘系2/)
- [大魔法咏唱](https://soalunashosya.jimdofree.com/戦闘系3-大魔法系/)
- [使用条款，2026-04-30 更新](https://soalunashosya.jimdofree.com/利用規約/)

具体试听定位：绯月先听「少女元気め」的「とりゃ！」「たあ！」及对应受伤；雪璃先听「少女おとなしめ」的「えい！」「あたってください」；鸦羽先听「女性クール」的「逃がさないよ」「大いなる力、我に示せ！」。这是试听候选，不是已批准的最终事件映射。

该站允许免费商用、编辑、嵌入游戏发布；署名和报告可选。禁止素材单独再分发、冒称作者及用作 AI 训练。建议保留署名：フリーボイス素材屋すぱらんど。/すぱるな瀟洒。

免费库的短板是各角色事件覆盖不均，尚不能确认完整替换 51 条。大魔法页作者还明确提示咏唱片段衔接不佳；不推荐为了拼出技能名而硬接片段。

## 小预算备选

- [ANIME VOICE vol.1](https://gamedevmarket.net/asset/voice-assets-for-japanese-girl-characters-anime-voice-vol1-komiyahairu)：US$10，113 条，komiya hairu，48 kHz / 24-bit WAV 和 OGG，附日英文本。
- [ANIME VOICE vol.3](https://gamedevmarket.net/asset/voice-assets-for-japanese-female-characters-anime-voice-vol3-komiyahairu)：US$16，297 条，其中 Female 187 条；也包含其他角色类型，不能视为 297 条女角色战斗语音。页面试听从 0:35 开始为 Female 部分。

两者适合少量补充，三名角色完整且一致的事件覆盖尚待核对。

## 实际接入注意点

1. 现成包未确认含「红莲月华／拂晓之祈／夜鸦断罪」三个原创技能名。建议保留画面技能名，录音使用语义合适的通用喊招，字幕如实翻译实际录音。
2. 同一角色整组使用同一套演绎；优先干声，混响交给游戏，避免普通攻击自带过长尾音。
3. `scripts/hero_voice.gd` 已通过 manifest 加载资源，播放层无需因提供方改变而重写。替换后重新统计 length、sha256、charge_time、burst_time，并更新日语文本、中文字幕和来源署名。
4. `tests/voice_assets.py` 当前写死 MiniMax、trace_id、voice_id 和原台词集合，正式替换时需改为真人素材来源及实际台词校验，保留波形、时长、哈希和演出计时检查。
5. 付费/受限素材不可作为裸音频公开进源码库；游戏构建中的使用与素材独立分发应按相应许可证处理。


选人语音：绯月「任せてください！」（交给我吧），雪璃「がんばります！」（我会努力的），鸦羽「いきましょう。」（出发吧）。复用对应演员的既有录音，点击时播放，遵循角色语音音量设置。


大招画面文字按用户要求恢复最初的原创中日咏唱，定义在 `scripts/ultimate_cinematic.gd` 的 `INVOCATIONS`；真人录音及其来源台词仍由 voice-manifest 管理。
