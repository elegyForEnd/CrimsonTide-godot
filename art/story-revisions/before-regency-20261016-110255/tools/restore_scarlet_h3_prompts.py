"""Rebuild the original delivered shot text with verified 39-frame H3 timing."""
from pathlib import Path
import copy
import csv
import hashlib
import io
import json
import math
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/scarlet-video-prompts'
BASE = ROOT / 'art/scarlet-h3-baseline/original-delivery.zip'
DOC = ROOT / 'docs/rpg/SCARLET-H3-DIRECTOR-PROMPTS.md'
TIMING = ROOT / 'docs/rpg/SCARLET-H3-TIMING.md'
FPS, OVERLAP = 24, 39


def action(prompt):
    return prompt.split('detailed_description: ', 1)[1].split('\n', 1)[0].split('，', 1)[1]


def main():
    with zipfile.ZipFile(BASE) as z:
        original = json.loads(z.read('Scarlet-H3-Prompts/manifest.json'))
        original_doc = z.read('Scarlet-H3-Prompts/完整逐镜提示词.md').decode('utf-8').replace('\r\n', '\n')
        # Only overwrite files present in the original delivery. Later versions remain in backups.
        for entry in z.infolist():
            rel = Path(entry.filename).relative_to('Scarlet-H3-Prompts')
            if rel.name == '完整逐镜提示词.md':
                continue
            target = (OUT / rel).resolve()
            assert target.is_relative_to(OUT.resolve())
            target.parent.mkdir(parents=True, exist_ok=True)
            if not entry.is_dir():
                target.write_bytes(z.read(entry))
    data = copy.deepcopy(original)
    assert data['version'] == 1 and data['shot_count'] == 83
    data.update(version='1-restored-overlap39', overlapFrames=OVERLAP,
                restored_from_sha256=hashlib.sha256(BASE.read_bytes()).hexdigest(),
                timing_basis='24 fps; length=5+17*n; incoming overlap=39 after first segment')
    table = ['cinematic,segment,startFrame,endFrameExclusive,lengthFrames,overlapFrames,startSeconds,endSeconds,generationSeconds,netNewSeconds']
    timing = '''# MiniMax H3 导演台：原版镜头＋39 帧重复区

已回退到最初交付的 21 个过场／83 镜，镜头内容和顺序保持原版，仅适配当前导演台的接续与时长。后续改稿已备份到 `art/scarlet-h3-rollback-backups/`。

## 重复帧怎样计算

本机插件 `ComfyUI-MiniMaxH3-TimelineDirector-main/js/segment_windows.mjs` 与 `minimax_h3_finite_segments.py` 已核对：段窗口是 `[起帧,终帧)`；每段生成帧数须为 `5＋17×n`。用户工作流相邻段实际重叠 **39 帧＝1.625 秒（24 fps）**。

- 第一段从 0 帧开始，无重叠。后段起帧＝前段终帧−39。
- 后段最初 39 帧承接前段末尾的真实连续画面，不是静止重复同一张图片，也不重演一次前段动作。
- 插件合并输出会丢掉后段开头这 39 帧；因此生成段长包含重复区，净新增时长不包含。**拿到 Merged Frames 生成的成片后不要再扣一次。**只有独立导出每段原始视频、手动外部拼接时才自行去掉后一段头部重复区。
- 例如 GEN1 `[0,175)`，GEN2 `[136,311)`，各生成 175 帧／7.291667 秒；合并是 311 帧／12.958333 秒。

## 怎么填导演台

每支 CIN 单独一份时间轴，CreateVideo 保持 24 fps。清空原 MV 图、歌曲及旧时间选区；按下面帧表设置每段窗口，复核界面吸附后的帧数。原版 `timeline.csv` 是剪辑预算；**实际生成设置用 `h3-overlap39.csv`**。提示词中的局部时间与全片窗口不要混用。

每段 TXT 的原版人物、画风、动作、运镜、音效均保留。首段没有上下文；后段在原动作前只加接续说明，前 1.625 秒承接上镜，新内容在重复区结束后进入。原有独立镜头之间在此处切镜；同场景镜头若希望连续运镜，可在导演台保持前段运动方向。跨地点硬切若被模型生成为变形过渡，则独立生成新镜头并外部剪接。

参考图仍按每片 README 顺序绑定。如果平台每段实际可承载的参考图有限，跨镜新增人物不要被带进重复区；用同一版场景关键帧辅助换镜，不能让三视图排版变成多个人物。请以实际审片为准，文本约束不保证每次生成都成功。

下面按累计剪辑预算向上对齐合法帧数；成片可能多出不足 17 帧的余量，最终在静止片尾裁剪或微调停顿。19 张插画循环单独生成 124 帧／5.166667 秒，无跨片重复区，先验证首尾，再需要时重定时为 5 秒。

## 逐段生成设置

| 影片 | 段 | 起帧 | 终帧（不含） | 生成帧数 | 重叠 | 生成秒数 | 净新增秒数 |
|---|---:|---:|---:|---:|---:|---:|---:|
'''
    plans = []
    for old, film in zip(original['cinematics'], data['cinematics']):
        previous = 0
        windows = []
        for i, (source, segment) in enumerate(zip(old['segments'], film['segments'])):
            end = 5 + 17 * math.ceil((source['end'] * FPS - 5) / 17)
            overlap = OVERLAP if i else 0
            start = previous - overlap
            length = end - start
            assert length > overlap and (length - 5) % 17 == 0
            window = dict(startFrame=start, endFrame=end, lengthFrames=length,
                          overlapFrames=overlap, generation_seconds=length / FPS,
                          net_new_seconds=(end - previous) / FPS)
            segment['h3_window'] = window
            windows.append(dict(shot=i+1, **window))
            prompt = source['prompt']
            original_action = action(prompt)
            prefix, rest = prompt.split('detailed_description: ', 1)
            _, suffix = rest.split('\n', 1)
            # The previous shot may include characters absent from the new shot.
            prefix = prefix.replace('本镜头实际可见角色：', '重复区结束后的新镜头可见角色：')
            prefix = prefix.replace('未列出的参考人物不额外出现在本镜头。', '未列出的参考人物不额外出现在新镜头；重复区只保留上一镜实际出现的人物。')
            prefix = re.sub(r'时长 \d+ 秒。', f'原剪辑预算 {source["duration"]} 秒；本段生成 {length/FPS:.6f} 秒（{length} 帧）。', prefix)
            if i:
                # Keep the final original action sentence as the spatial anchor, not a new shot plan.
                tail = '。'.join(action(old['segments'][i-1]['prompt']).rstrip('。').split('。')[-2:]) + '。'
                carried = (f'[Shot 1] 局部 0.000000—1.625000 秒（第 0—38 帧）承接上一段最后 39 帧的真实连续画面：{tail}'
                           '保持上一段人物站位、道具、光线、相机路径与声音；不要重新做一遍上一镜动作，也不要把末帧冻结复制 39 次。'
                           '该重复区由合并器自动去重，不提前让下一镜人物或地点进入。\n'
                           f'[Shot 2] 局部 1.625000—{length/FPS:.6f} 秒（第 39 帧起），重复区结束后切入原版下一镜：{original_action}')
            else:
                carried = f'[Shot 1] 局部 0.000000—{length/FPS:.6f} 秒，无前段重复区：{original_action}'
            suffix = suffix.replace('这是一个独立连续镜头，不自行插入蒙太奇、闪回、转场或额外切镜。',
                                    '以上新内容保持原版单一连续镜头；除重复区后的指定切镜，不新增蒙太奇、闪回或其他切镜。')
            if i:
                suffix = suffix.replace('overall_soundscape: ', 'overall_soundscape: 前 1.625 秒保持上一段末尾声音；重复区结束后才进入本镜声音：')
            prompt = prefix + 'detailed_description: ' + carried + '\n' + suffix
            assert original_action in prompt and '\ufffd' not in prompt
            segment['prompt'] = prompt
            (ROOT / segment['prompt_file']).write_text(prompt, encoding='utf-8')
            table.append(f'{film["id"]},{i+1},{start},{end},{length},{overlap},{start/FPS:.6f},{end/FPS:.6f},{length/FPS:.6f},{(end-previous)/FPS:.6f}')
            timing += f'| {film["id"]} | {i+1} | {start} | {end} | {length} | {overlap} | {length/FPS:.6f} | {(end-previous)/FPS:.6f} |\n'
            previous = end
        assert sum(w['lengthFrames'] - w['overlapFrames'] for w in windows) == previous
        plans.append(dict(id=film['id'],budget=film['duration'],outputFrames=previous,outputSeconds=previous/FPS,windows=windows))
        readme = OUT / film['id'] / 'README.txt'
        with readme.open('a', encoding='utf-8') as h:
            h.write('\n原版恢复＋39 帧接续：下列为实际生成窗口（终帧不含），原剪辑秒数不直接作为生成时长。\n')
            for w in windows:
                h.write(f'GEN{w["shot"]}: [{w["startFrame"]},{w["endFrame"]})，生成 {w["lengthFrames"]} 帧／{w["generation_seconds"]:.6f} 秒，重复 {w["overlapFrames"]} 帧。\n')
    for loop in data['loops']:
        loop.update(generation_frames=124,generation_seconds=124/FPS)
        prompt = loop['prompt'].replace('生成 5 秒固定机位', '独立生成 124 帧、24 fps、5.166667 秒固定机位')
        prompt = prompt.replace('第 0 秒与第 5 秒', '第 0 秒与第 5.166667 秒')
        loop['prompt'] = prompt
        (ROOT / loop['prompt_file']).write_text(prompt, encoding='utf-8')
    # Preserve original page structure and all shot text; replace prompts and timing headings only.
    doc = original_doc
    for old, film in zip(original['cinematics'],data['cinematics']):
        for s, current in zip(old['segments'], film['segments']):
            assert s['prompt'] in doc
            doc = doc.replace(s['prompt'],current['prompt'],1)
    for old, loop in zip(original['loops'],data['loops']):
        doc = doc.replace(old['prompt'],loop['prompt'],1)
    doc = doc.replace('每张 5 秒，一个固定镜头。', '每张独立生成 124 帧／5.166667 秒，一个固定镜头，无跨片重复区。')
    doc = doc.replace('原示例的相邻分段有 39 帧重叠。本包 CSV 的帧号则是最终剪辑的连续区间',
                      '相邻生成段按 39 帧重叠设置，实际生成请用 h3-overlap39.csv。本包 timeline.csv 的帧号只是最终剪辑的连续区间')
    doc = doc.replace('连续运镜可在导演台保留其实际要求的接续上下文，并在剪辑时裁掉重复部分；',
                      '连续运镜保留接续上下文，插件合并输出已自动去重，无需在剪辑时重复裁掉；')
    banner = ('\n> 已回退至最初交付的镜头内容；只补 39 帧重复区与 H3 合法帧长设置。'
              '实际生成时长以 [逐段帧表](SCARLET-H3-TIMING.md) 为准，下面镜头标题秒数保留原剪辑预算。'
              '合并输出自动去重，不重复裁去 1.625 秒。\n')
    doc = doc.replace('\n', '\n'+banner,1)
    DOC.write_text(doc,encoding='utf-8')
    TIMING.write_text(timing,encoding='utf-8')
    (OUT/'H3-时长与重叠设置.md').write_text(timing,encoding='utf-8')
    (OUT/'h3-overlap39.csv').write_text('\n'.join(table)+'\n',encoding='utf-8-sig')
    (OUT/'h3-overlap39.json').write_text(json.dumps(dict(fps=FPS,overlapFrames=OVERLAP,films=plans),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (OUT/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (OUT/'README.md').write_text('# 原版恢复＋39 帧接续\n\n'+banner+'\n\n'+timing.split('## 逐段生成设置')[0],encoding='utf-8')
    archive = ROOT/'output/Scarlet-H3-Prompts-restored-overlap39.zip'
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as z:
        for p in sorted(OUT.rglob('*')):
            if p.is_file() and not p.name.startswith('.'):
                z.write(p,'Scarlet-H3-Prompts/'+p.relative_to(OUT).as_posix())
        z.write(DOC,'Scarlet-H3-Prompts/完整逐镜提示词.md')
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
    report = dict(base_version=original['version'],films=len(plans),shots=sum(len(f['windows']) for f in plans),
                  loops=len(data['loops']),overlapFrames=OVERLAP,original_actions_preserved=True,
                  legal_windows=True,archive_ok=True,game_files_modified=False)
    (ROOT/'output/scarlet-h3-restored-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))


if __name__ == '__main__':
    main()
